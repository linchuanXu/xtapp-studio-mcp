import { createHash, randomUUID } from 'node:crypto'
import { mkdir, readFile, realpath, writeFile } from 'node:fs/promises'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { normalizeAbsolutePath, pathKey } from './projectPath.mjs'

const SESSION_ID = /^[A-Za-z0-9:_-]{8,160}$/

export function defaultPreviewSessionPath() {
  const override = String(process.env.XTAPP_PREVIEW_SESSION_FILE || '').trim()
  return override || join(homedir(), '.xtapp', 'codex-preview-session')
}

// 每个工程目录一条独立 session：多个会话同时做不同游戏时，各自的预览页和命令互不串。
export async function previewSessionFileForProject(projectDir) {
  const raw = String(projectDir || '').trim()
  const root = normalizeAbsolutePath(raw) || resolve(raw)
  const real = await realpath(root).catch(() => root)
  const key = createHash('sha256').update(pathKey(real)).digest('hex').slice(0, 24)
  return join(previewSessionsDir(), key)
}

function previewSessionsDir() {
  return join(dirname(defaultPreviewSessionPath()), 'preview-sessions')
}

// 最近一次选中的工程 session：插件进程重启后，不带 projectDir 的工具（按键、截图、状态）先接着用它。
export function lastPreviewSessionPath() {
  return join(previewSessionsDir(), 'last')
}

export async function readLastPreviewSession(filePath = lastPreviewSessionPath()) {
  try {
    const existing = (await readFile(filePath, 'utf8')).trim()
    return SESSION_ID.test(existing) ? existing : ''
  } catch {
    return ''
  }
}

export async function rememberLastPreviewSession(sessionId, filePath = lastPreviewSessionPath()) {
  if (!SESSION_ID.test(String(sessionId || ''))) return
  await mkdir(dirname(filePath), { recursive: true })
  await writeFile(filePath, `${sessionId}\n`, 'utf8')
}

export async function loadOrCreatePreviewSession(filePath = defaultPreviewSessionPath()) {
  try {
    const existing = (await readFile(filePath, 'utf8')).trim()
    if (SESSION_ID.test(existing)) return existing
  } catch { /* missing or unreadable file starts a new stable session */ }
  const sessionId = randomUUID()
  await mkdir(dirname(filePath), { recursive: true })
  await writeFile(filePath, `${sessionId}\n`, 'utf8')
  return sessionId
}

export function previewRunPath(status) {
  return status === 'stopped' || status === 'error' ? '/preview/restart' : '/preview/run'
}
