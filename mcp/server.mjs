import { cp, readFile, readdir, stat } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { registerAppResource, registerAppTool, RESOURCE_MIME_TYPE } from '@modelcontextprotocol/ext-apps/server'
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'
import { PLUGIN_VERSION, describePreviewReady, displayNameFromManifest, previewCommandWaitMs, requireProjectDir } from './previewReady.mjs'
import { loadOrCreatePreviewSession, previewRunPath } from './previewSession.mjs'
import { readProjectSnapshot } from './projectSnapshot.mjs'
import { pushProjectSnapshot, snapshotPushState, withProjectPushLock } from './previewSourceSync.mjs'
import { tapPreviewTarget } from './previewTap.mjs'
import { resolveStudioOrigin } from './regionConfig.mjs'
import { readStoreTemplate, TEMPLATE_GET_NOTE } from './storeTemplate.mjs'
import {
  classifyPreviewBridgeError,
  describeSourceSync,
  formatDroppedAssets,
  isFailedCommand,
  previewRequestTimeoutMs,
  unwrapPreviewEnvelope,
} from './previewBridgeClient.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const CONTRACT_DIR = process.env.XTAPP_CONTRACT_DIR ? resolve(process.env.XTAPP_CONTRACT_DIR) : null
const STORE_DIR = process.env.XTAPP_CATALOG_SOURCE_DIR ? resolve(process.env.XTAPP_CATALOG_SOURCE_DIR) : join(ROOT, 'catalog', 'templates')
const CATALOG_INDEX = join(ROOT, 'catalog', 'index.json')
const KNOWLEDGE_INDEX = join(ROOT, 'knowledge', 'index.json')
const WIDGET_URI = 'ui://widget/xtapp/studio.html'
const sourceWatchers = new Map()
const lastPushed = new Map()

const server = new McpServer({ name: 'xtapp-studio', version: PLUGIN_VERSION }, {
  instructions: 'Use XTApp public contract knowledge before guessing APIs. If the user has not named a folder or app, quote this sentence and wait: 在当前文件夹新建 todo-list，做一款能添加、完成、删除的待办。Classic 用方向键和 OK，Pro 也能点。 After they say it, write ./todo-list (or the path they named). If the current directory is already an XTApp, use it. After project changes, call run_xtapp_preview with that folder\'s absolute path as projectDir, not the parent workspace. Open the exact previewUrl: Cursor must use its built-in browser MCP and keep that tab open; other hosts give the URL to the user. If a login page appears, stop and let the user sign in; do not fill credentials. Do not click the simulator DOM; use send_xtapp_preview_input and send_xtapp_preview_touch. Do not overwrite an unrelated Studio project. Public store tools inspect and copy only the checked-in standard app templates.'
})

function textResult(text, details = {}) {
  return { content: [{ type: 'text', text }], structuredContent: details }
}

function safeAppId(value) {
  const id = String(value || '').trim()
  if (!/^[A-Za-z0-9_-]+$/.test(id)) throw new Error('非法 XTApp 模板 id')
  return id
}

async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'))
}

async function publicApps() {
  if (!process.env.XTAPP_CATALOG_SOURCE_DIR && existsSync(CATALOG_INDEX)) return readJson(CATALOG_INDEX)
  if (!existsSync(STORE_DIR)) return []
  const entries = await readdir(STORE_DIR, { withFileTypes: true })
  const result = []
  for (const entry of entries) {
    if (!entry.isDirectory()) continue
    const dir = join(STORE_DIR, entry.name)
    const manifestPath = join(dir, 'manifest.json')
    if (!existsSync(manifestPath)) continue
    try {
      const manifest = await readJson(manifestPath)
      const readmePath = join(dir, 'README.md')
      result.push({
        id: entry.name,
        appId: manifest.app_id || entry.name,
        name: manifest.display_name || manifest.name || entry.name,
        version: manifest.version || null,
        description: existsSync(readmePath) ? (await readFile(readmePath, 'utf8')).split('\n').find(Boolean) || '' : '',
      })
    } catch { /* Ignore incomplete catalog entries. */ }
  }
  return result.sort((a, b) => a.id.localeCompare(b.id))
}

async function templateFiles(id) {
  const dir = join(STORE_DIR, safeAppId(id))
  const info = await stat(dir).catch(() => null)
  if (!info?.isDirectory()) throw new Error(`公开模板不存在：${id}`)
  return readStoreTemplate(dir)
}

function contractCandidates() {
  if (!CONTRACT_DIR) return []
  return [
    join(CONTRACT_DIR, 'SPEC.md'),
    join(CONTRACT_DIR, 'README.md'),
    join(CONTRACT_DIR, 'api', 'runtime.md'),
    join(CONTRACT_DIR, 'api', 'input.md'),
    join(CONTRACT_DIR, 'api', 'graphics.md'),
    join(CONTRACT_DIR, 'api', 'ui-components.md'),
    join(CONTRACT_DIR, 'api', 'manifest.md'),
  ]
}

async function contractSearch(query, limit = 6, topicFilter = '') {
  const needle = String(query || '').trim().toLowerCase()
  if (!needle) return []
  const terms = [...new Set(needle.split(/[^\p{L}\p{N}_.:]+/u).filter((term) => term.length >= 2))]
  const rows = []
  for (const path of contractCandidates()) {
    if (!existsSync(path)) continue
    const content = await readFile(path, 'utf8')
    const lines = content.split('\n')
    lines.forEach((line, index) => {
      const lower = line.toLowerCase()
      const score = needle.includes(' ') ? terms.reduce((total, term) => total + (lower.includes(term) ? 1 : 0), 0) : (lower.includes(needle) ? 1 : 0)
      if (score > 0) rows.push({ score, topic: topicForPath(path), api: apiForLine(line, topicForPath(path)), version: versionForPath(path, content), source: sourceForPath(path), sourcePath: path, line: index + 1, excerpt: line.trim().slice(0, 500) })
    })
  }
  if (!rows.length && existsSync(KNOWLEDGE_INDEX)) {
    const knowledge = await readJson(KNOWLEDGE_INDEX)
    for (const entry of knowledge.entries || []) {
      const content = String(entry.content || '')
      const lower = content.toLowerCase()
      const index = lower.indexOf(needle)
      const score = index >= 0 ? terms.length + 1 : terms.reduce((total, term) => total + (lower.includes(term) ? 1 : 0), 0)
      if (score > 0) {
        const firstTermIndex = index >= 0 ? index : Math.max(0, terms.map((term) => lower.indexOf(term)).filter((value) => value >= 0).sort((a, b) => a - b)[0] || 0)
        rows.push({ score, topic: entry.topic || 'overview', api: entry.api || null, version: entry.version || 'unknown', source: entry.source || 'unknown', sourcePath: entry.sourcePath || entry.source, line: entry.lineStart || 1, excerpt: content.slice(Math.max(0, firstTermIndex - 160), firstTermIndex + 340).replaceAll('\n', ' ') })
      }
    }
  }
  const filtered = topicFilter ? rows.filter((row) => row.topic === topicFilter) : rows
  return filtered.sort((a, b) => (b.score || 0) - (a.score || 0) || a.sourcePath.localeCompare(b.sourcePath) || a.line - b.line)
    .slice(0, Math.max(1, Math.min(10, limit))).map(({ score, ...row }) => row)
}

function topicForPath(path) {
  const value = String(path).toLowerCase()
  if (value.includes('/input')) return 'input'
  if (value.includes('/graphics')) return 'graphics'
  if (value.includes('/runtime')) return 'runtime'
  if (value.includes('/manifest')) return 'manifest'
  if (value.includes('ui-components')) return 'ui'
  if (value.includes('/network')) return 'network'
  return 'overview'
}

function apiForLine(line, topic) {
  const patterns = {
    input: /\b(on_input|ctx\.input(?:\.caps)?)\b/i,
    graphics: /\b(g:(?:clear|line|rect|circle|text|image|layer|size))\b/i,
    runtime: /\b(ctx\.(?:state|screen|sys|longtask|perf)|on_(?:load|enter|tick|draw|leave|unload))\b/i,
    manifest: /\b(manifest(?:\.json)?|app_id|display\.orientation)\b/i,
    network: /\b(ctx\.net:(?:get|post|poll|cancel))\b/i,
  }
  return patterns[topic]?.exec(line)?.[1] || null
}

function versionForPath(path, content) {
  const match = String(content).match(/(?:契约版本|contract version|API version|apiVersion|version)\D{0,20}(\d+\.\d+)/i)
  return match?.[1] || (String(path).includes('/contract/') ? '1.0' : 'unknown')
}

function sourceForPath(path) {
  return String(path).includes('/contract/') ? 'public-contract' : 'xtapp-studio'
}

registerAppResource(server, 'xtapp-studio-widget', WIDGET_URI, {
  title: 'XTApp Studio Preview',
  description: 'Live XTApp project preview and contract/store status.',
  _meta: {
    ui: { prefersBorder: true, csp: { connectDomains: [], resourceDomains: ['data:'] } },
    'openai/widgetDescription': 'Shows the current XTApp preview and its contract/store context.',
    'openai/widgetPrefersBorder': true,
    'openai/widgetCSP': { connect_domains: [], resource_domains: ['data:'] },
  },
}, async () => ({ contents: [{ uri: WIDGET_URI, mimeType: RESOURCE_MIME_TYPE, text: await readFile(join(ROOT, 'widget', 'index.html'), 'utf8') }] }))

registerAppTool(server, 'render_xtapp_studio_widget', {
  title: 'Render XTApp Studio Preview',
  description: 'Open or refresh the native right-side XTApp Studio preview widget for the active project.',
  inputSchema: { projectDir: z.string().trim().optional() },
  _meta: { ui: { resourceUri: WIDGET_URI, visibility: ['model', 'app'] }, 'openai/outputTemplate': WIDGET_URI, 'openai/widgetAccessible': true },
}, async (input = {}) => textResult('XTApp Studio preview widget ready.', { projectDir: input.projectDir ? resolve(input.projectDir) : null, widget: WIDGET_URI }))

server.registerTool('search_xtapp_knowledge', { description: 'Search the public XTApp Lua contract and API guides. Classify the question first and optionally filter by topic.', inputSchema: { query: z.string().min(1), topic: z.enum(['input', 'graphics', 'runtime', 'manifest', 'network', 'assets', 'ui', 'studio-preview', 'overview']).optional(), limit: z.number().int().min(1).max(10).optional() } }, async ({ query, topic, limit }) => {
  const results = await contractSearch(query, limit, topic)
  return textResult(JSON.stringify(results, null, 2), { query, topic: topic || null, count: results.length })
})

server.registerTool('list_xtapp_store_apps', { description: 'List public XTApp apps available as checked-in templates.', inputSchema: { query: z.string().optional() } }, async ({ query = '' }) => {
  const apps = await publicApps()
  const filtered = query ? apps.filter((app) => JSON.stringify(app).toLowerCase().includes(query.toLowerCase())) : apps
  return textResult(JSON.stringify(filtered, null, 2), { count: filtered.length, catalogIndexPresent: existsSync(CATALOG_INDEX), templateDirPresent: existsSync(STORE_DIR) })
})

server.registerTool('get_xtapp_store_template', { description: 'Inspect a public XTApp template: text sources plus an asset inventory without binary contents. A runnable copy with art requires copy_xtapp_store_template.', inputSchema: { id: z.string().min(1) } }, async ({ id }) => {
  const template = await templateFiles(id)
  const payload = { id, files: template.files, assets: template.assets, note: TEMPLATE_GET_NOTE }
  return textResult(JSON.stringify(payload, null, 2), {
    id,
    fileCount: Object.keys(template.files).length,
    assetCount: template.assets.length,
    assets: template.assets,
    sourceDir: template.dir,
    runnableCopy: 'copy_xtapp_store_template',
    note: TEMPLATE_GET_NOTE,
  })
})

server.registerTool('copy_xtapp_store_template', { description: 'Copy a complete public XTApp template, including binary assets, into a new directory inside the explicitly selected project. The destination must not already exist. Use this for a runnable copy; get_xtapp_store_template is inspect-only.', inputSchema: { id: z.string().min(1), projectDir: z.string().trim(), destination: z.string().trim().optional() } }, async ({ id, projectDir, destination }) => {
  const template = await templateFiles(id)
  const base = resolve(projectDir)
  const relativeDestination = String(destination || `templates/${safeAppId(id)}`).trim()
  if (!relativeDestination || relativeDestination.startsWith('/') || relativeDestination.includes('..')) throw new Error('模板目标必须是当前项目内的相对路径，且不能包含 ..')
  const target = resolve(base, relativeDestination)
  if (!target.startsWith(`${base}/`)) throw new Error('模板目标越过了项目目录边界')
  if (existsSync(target)) throw new Error(`模板目标已存在，为避免覆盖请换一个目录：${relativeDestination}`)
  await cp(template.dir, target, { recursive: true, force: false, errorOnExist: true })
  return textResult(`已复制公开模板 ${id} 到 ${relativeDestination}`, { id, destination: target, sourceDir: template.dir })
})

const previewSession = await loadOrCreatePreviewSession()

function studioOrigin() {
  return resolveStudioOrigin()
}

function previewSessionId() {
  return previewSession
}

function previewPageUrl() {
  return `${studioOrigin()}/studio/preview?preview=1&session=${encodeURIComponent(previewSessionId())}`
}

function withPreviewMeta(result = {}) {
  return { ...result, sessionId: result.sessionId || previewSessionId(), previewUrl: previewPageUrl() }
}

async function bridgeRequest(path, body = {}, method = 'POST', timeoutMs = previewRequestTimeoutMs(path.split('?')[0])) {
  const origin = studioOrigin()
  const sessionId = previewSessionId()
  const url = new URL(path, `${origin}/`)
  if (method === 'GET') url.searchParams.set('sessionId', sessionId)
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(url, { method, headers: { 'content-type': 'application/json' }, signal: controller.signal, ...(method === 'GET' ? {} : { body: JSON.stringify({ ...body, sessionId, pluginVersion: PLUGIN_VERSION }) }) })
    const payload = await response.json().catch(() => null)
    if (payload && typeof payload === 'object') {
      const data = unwrapPreviewEnvelope(payload)
      return withPreviewMeta(data)
    }
    if (!response.ok) throw new Error(`Studio preview bridge failed: HTTP ${response.status}`)
    throw new Error('预览桥响应无效')
  } catch (error) {
    return withPreviewMeta(classifyPreviewBridgeError(error, origin))
  } finally {
    clearTimeout(timeout)
  }
}

async function syncProjectSource(projectDir) {
  return withProjectPushLock(projectDir, async () => {
    const snapshot = await readProjectSnapshot(projectDir)
    const previous = lastPushed.get(snapshot.projectDir)
    const result = await pushProjectSnapshot(snapshot, (path, body) => bridgeRequest(path, body), { previous })
    if (result?.revision) {
      lastPushed.set(snapshot.projectDir, snapshotPushState(snapshot, result.revision))
      const watcher = sourceWatchers.get(snapshot.projectDir)
      if (watcher) watcher.lastRevision = snapshot.revision
    }
    return result
  })
}

async function awaitCommand(path, body = {}, waitMs = previewCommandWaitMs(path)) {
  const queued = await bridgeRequest(path, body)
  if (isFailedCommand(queued)) return queued
  if (!queued?.commandId || queued.status === 'not_connected') return queued
  const query = `/preview/result?commandId=${encodeURIComponent(queued.commandId)}`
  const deadline = Date.now() + waitMs
  while (Date.now() < deadline) {
    const result = await bridgeRequest(query, {}, 'GET')
    if (isFailedCommand(result) || result?.status === 'complete') return result
    await new Promise((resolveWait) => setTimeout(resolveWait, 100))
  }
  return { ...queued, status: 'queued_timeout', message: 'Studio 已接收命令，但尚未回传执行结果' }
}

function previewReadyResult(result, { displayName = '', commandStatus = result?.status } = {}) {
  const ready = describePreviewReady({
    connectedStatus: result?.outcome?.status || result?.status,
    commandStatus,
    previewUrl: previewPageUrl(),
    displayName,
    message: result?.message,
  })
  return { ...result, ...ready, displayName: ready.displayName }
}

async function ensurePreviewReady({ projectDir, device = 'x4_pro' }) {
  const root = requireProjectDir(projectDir)
  const snapshot = await readProjectSnapshot(root)
  const displayName = displayNameFromManifest(snapshot.manifest, snapshot.projectName)
  startSourceWatcher(snapshot.projectDir)
  const status = await bridgeRequest('/preview/status', {}, 'GET')
  if (status.status === 'not_connected' || status.status === 'timeout') {
    return previewReadyResult({ ...status, projectDir: snapshot.projectDir, watching: true }, { displayName, commandStatus: status.status })
  }
  const source = await syncProjectSource(snapshot.projectDir)
  const path = previewRunPath(status.status)
  const result = await awaitCommand(path, { projectDir: source.projectDir, revision: source.revision, device })
  return previewReadyResult({
    ...result,
    ...source,
    device,
    watching: true,
    commandPath: path,
  }, { displayName, commandStatus: result.status })
}

function stopSourceWatcher(projectDir) {
  const watcher = sourceWatchers.get(projectDir)
  if (!watcher) return false
  watcher.stopped = true
  clearInterval(watcher.timer)
  sourceWatchers.delete(projectDir)
  return true
}

function startSourceWatcher(projectDir) {
  const existing = sourceWatchers.get(projectDir)
  if (existing) return existing
  const watcher = { stopped: false, timer: null, lastRevision: lastPushed.get(projectDir)?.revision || '', cooldownUntil: 0 }
  watcher.timer = setInterval(async () => {
    if (watcher.stopped || watcher.busy) return
    if (watcher.cooldownUntil && Date.now() < watcher.cooldownUntil) return
    watcher.busy = true
    try {
      const result = await syncProjectSource(projectDir)
      if (result?.status === 'timeout') watcher.cooldownUntil = Date.now() + 8000
    } catch { /* The next polling cycle retries transient edits or bridge restarts. */ } finally {
      watcher.busy = false
    }
  }, 1000)
  watcher.timer.unref?.()
  sourceWatchers.set(projectDir, watcher)
  return watcher
}

server.registerTool('run_xtapp_preview', { description: 'Ensure the official Studio preview page is running the current local worktree. Requires the absolute projectDir. If the page is closed or needs login, returns the exact previewUrl instead of claiming success.', inputSchema: { projectDir: z.string().trim().min(1), device: z.enum(['x4_classic', 'x4_pro']).optional() } }, async ({ projectDir, device = 'x4_pro' }) => {
  const result = await ensurePreviewReady({ projectDir, device })
  return textResult([result.message || JSON.stringify(result), formatDroppedAssets(result.dropped)].filter(Boolean).join('\n'), result)
})

server.registerTool('sync_xtapp_preview_source', { description: 'Read the current local worktree source and make it available to the official Studio preview.', inputSchema: { projectDir: z.string().trim() } }, async ({ projectDir }) => {
  const result = await syncProjectSource(projectDir)
  return textResult(describeSourceSync(result), result)
})

server.registerTool('watch_xtapp_preview', { description: 'Watch a local worktree and automatically synchronize source changes to the official Studio preview.', inputSchema: { projectDir: z.string().trim(), enabled: z.boolean().optional() } }, async ({ projectDir, enabled = true }) => {
  const root = resolve(projectDir)
  if (!enabled) return textResult(JSON.stringify({ status: stopSourceWatcher(root) ? 'stopped' : 'not_watching', projectDir: root }), { status: 'stopped', projectDir: root })
  await syncProjectSource(root)
  startSourceWatcher(root)
  return textResult(`已开始监听 ${root}；保存 Lua/Manifest 后，Studio 会自动同步源码并刷新预览。`, { status: 'watching', projectDir: root, intervalMs: 1000 })
})

server.registerTool('get_xtapp_preview_status', { description: 'Read whether the official Studio preview page is open, which app it is showing, and the exact previewUrl to open.', inputSchema: {} }, async () => {
  const result = await bridgeRequest('/preview/status', {}, 'GET')
  let displayName = displayNameFromManifest(result.manifest)
  if (!displayName && result.status !== 'not_connected' && result.status !== 'timeout') {
    const context = await bridgeRequest('/preview/context', {}, 'GET')
    displayName = displayNameFromManifest(context.manifest)
  }
  const ready = previewReadyResult(result, { displayName, commandStatus: result.status === 'not_connected' ? 'not_connected' : '' })
  return textResult(ready.message || JSON.stringify(ready), ready)
})

server.registerTool('inspect_xtapp_preview_context', { description: 'Inspect the active Studio project manifest, Lua entry snippets and recent runtime logs for joint diagnosis.', inputSchema: { query: z.string().trim().optional() } }, async ({ query = '' }) => {
  const context = await bridgeRequest('/preview/context', {}, 'GET')
  if (context.status === 'not_connected') return textResult(JSON.stringify(context), context)
  const needle = String(query).toLowerCase()
  const files = Object.fromEntries(Object.entries(context.files || {}).filter(([path, content]) => !needle || path.toLowerCase().includes(needle) || String(content).toLowerCase().includes(needle)))
  const result = { projectId: context.projectId || null, manifest: context.manifest || null, files, logs: context.logs || [], updatedAt: context.updatedAt || null }
  return textResult(JSON.stringify(result, null, 2), { ...result, fileCount: Object.keys(files).length })
})

server.registerTool('send_xtapp_preview_input', { description: 'Send an X4 device key to the active Studio preview.', inputSchema: { key: z.enum(['up', 'down', 'left', 'right', 'ok', 'back']) } }, async ({ key }) => {
  const result = await awaitCommand('/preview/input', { key })
  return textResult(JSON.stringify(result), result)
})

server.registerTool('get_xtapp_preview_targets', { description: 'Read semantic interactive targets and the current frame revision from the active Studio preview.', inputSchema: {} }, async () => {
  const result = await bridgeRequest('/preview/targets', {}, 'GET')
  return textResult(JSON.stringify(result, null, 2), result)
})

server.registerTool('tap_xtapp_preview_target', { description: 'Tap a published preview target by converting its rectangle to a coordinate touch. If the current frame has no targets, use send_xtapp_preview_touch. Apps do not need a Lua testing slot.', inputSchema: { targetId: z.string().min(1).max(120), gesture: z.enum(['tap', 'double_tap', 'long', 'swipe_left', 'swipe_right', 'swipe_up', 'swipe_down']).optional() } }, async ({ targetId, gesture = 'tap' }) => {
  const result = await tapPreviewTarget({ targetId, gesture }, {
    getTargets: () => bridgeRequest('/preview/targets', {}, 'GET'),
    sendTouch: ({ x, y, gesture: nextGesture }) => awaitCommand('/preview/touch', { x, y, gesture: nextGesture }),
  })
  return textResult(JSON.stringify(result, null, 2), result)
})

server.registerTool('send_xtapp_preview_touch', { description: 'Default way to click the official Studio preview: send a touch gesture using logical device coordinates. Use this unless a published target already has a rectangle.', inputSchema: { x: z.number().finite(), y: z.number().finite(), gesture: z.enum(['tap', 'double_tap', 'long', 'swipe_left', 'swipe_right', 'swipe_up', 'swipe_down']).optional() } }, async ({ x, y, gesture = 'tap' }) => {
  const result = await awaitCommand('/preview/touch', { x, y, gesture })
  return textResult(JSON.stringify(result, null, 2), result)
})

server.registerTool('capture_xtapp_preview', { description: 'Capture the current Studio preview PNG and frame revision.', inputSchema: {} }, async () => {
  const command = await awaitCommand('/preview/capture', {})
  const screenshot = command.screenshot?.dataUrl
    ? command.screenshot
    : await bridgeRequest('/preview/screenshot', {}, 'GET')
  const result = { ...command, screenshot }
  return textResult(JSON.stringify(result), result)
})

server.registerTool('stop_xtapp_preview', { description: 'Stop the active Studio preview runtime.', inputSchema: {} }, async () => {
  const result = await awaitCommand('/preview/stop')
  return textResult(JSON.stringify(result), result)
})

server.registerTool('restart_xtapp_preview', { description: 'Restart the official Studio preview with the current local worktree. Syncs source first, then restarts the Lua worker.', inputSchema: { projectDir: z.string().trim().min(1), device: z.enum(['x4_classic', 'x4_pro']).optional() } }, async ({ projectDir, device }) => {
  const source = await syncProjectSource(requireProjectDir(projectDir))
  const result = await awaitCommand('/preview/restart', { projectDir: source.projectDir, revision: source.revision, device })
  return textResult(result.message || JSON.stringify(result), { ...result, ...source })
})

await server.connect(new StdioServerTransport())
