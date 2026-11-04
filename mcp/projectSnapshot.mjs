import { createHash } from 'node:crypto'
import { readFile, readdir, realpath, stat } from 'node:fs/promises'
import { basename, join, relative, sep } from 'node:path'
import { isInsideRoot, normalizeAbsolutePath } from './projectPath.mjs'

export const MAX_FILES = 2000
export const MAX_FILE_BYTES = 256 * 1024
export const MAX_ASSETS = 2000
export const MAX_ASSET_BYTES = 2 * 1024 * 1024
// 与 Proxy preview_bridge.SOURCE_PATH 同步：API 2.x 打包全部 .lua（点开头的目录除外）。
export const TEXT_FILE = /^(?:manifest\.json|[^/]+\.lua|(?:[A-Za-z0-9_-][A-Za-z0-9_.-]*\/)+[A-Za-z0-9_.-]+\.lua|(?:data|lang)\/[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*\.(?:tsv|txt|json))$/i
const ASSET_FILE = /^(?:assets|raw)\/[A-Za-z0-9_-]{1,23}\.(xic|png|jpe?g|webp)$/i
const LOOKS_LIKE_SOURCE = /\.(lua|tsv|txt|json)$/i
const SILENT_SKIP = /^(?:docs|tmp|prototypes|\.tmp)\//i
const CLOUD_BINDING_PATHS = ['docs/studio.cloud.json', 'studio.cloud.json']
// 安装前配置的声明（附录 D）：不进包，随同步写进 Studio 工程，让预览弹「运行前配置」。
export const CONFIGURATION_PATH = 'docs/studio.configuration.json'
export const MAX_CONFIGURATION_ITEMS = 64
const CONFIGURATION_KEY = /^[A-Z][A-Z0-9_]{0,63}$/
const CONFIGURATION_TYPES = new Set(['text', 'secret', 'number', 'boolean'])

export function snapshotRevision(files = {}, assets = [], extra = '') {
  const digest = createHash('sha256')
    .update(JSON.stringify(Object.entries(files).sort(([a], [b]) => a.localeCompare(b))))
    .update(JSON.stringify(
      assets
        .map(({ path, sha256, bytes }) => ({ path, sha256, bytes }))
        .sort((a, b) => String(a.path).localeCompare(String(b.path))),
    ))
  if (extra) digest.update(String(extra))
  return digest.digest('hex')
}

export function parseCloudProjectId(raw) {
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    return String(raw.cloudProjectId || '').trim()
  }
  if (typeof raw !== 'string' || !raw.trim()) return ''
  try {
    return parseCloudProjectId(JSON.parse(raw))
  } catch {
    return ''
  }
}

export async function readCloudProjectId(root) {
  for (const rel of CLOUD_BINDING_PATHS) {
    try {
      const raw = await readFile(join(root, ...rel.split('/')), 'utf8')
      const id = parseCloudProjectId(raw)
      if (id) return id
    } catch {
      /* missing or unreadable sidecar */
    }
  }
  return ''
}

// 声明也算进 revision：只改声明时插件照样推送。
export function configurationRevisionTag(configuration) {
  return configuration ? `|config:${JSON.stringify(configuration)}` : ''
}

function configText(value, max) {
  return typeof value === 'string' ? value.trim().slice(0, max) : ''
}

/** Validates the declaration file; returns the cleaned lists plus warnings for whatever was dropped. */
export function parseProjectConfiguration(raw) {
  const warnings = []
  let data = raw
  if (typeof raw === 'string') {
    try { data = JSON.parse(raw) } catch {
      return { configuration: null, warnings: [`${CONFIGURATION_PATH} is not valid JSON; the preview runs without configuration`] }
    }
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return { configuration: null, warnings: [`${CONFIGURATION_PATH} must be an object with configurationFields and configurationInjections`] }
  }
  const fields = []
  const keys = new Set()
  for (const item of Array.isArray(data.configurationFields) ? data.configurationFields.slice(0, MAX_CONFIGURATION_ITEMS) : []) {
    const key = configText(item?.key, 64)
    if (!CONFIGURATION_KEY.test(key) || keys.has(key)) {
      warnings.push(`${CONFIGURATION_PATH}: field "${key}" needs a unique key of capital letters, digits and underscores; skipped`)
      continue
    }
    const type = CONFIGURATION_TYPES.has(item.type) ? item.type : 'text'
    if (item.type && item.type !== type) warnings.push(`${CONFIGURATION_PATH}: field ${key} has unknown type "${item.type}"; using text`)
    const field = { key, label: configText(item.label, 120) || key, type, required: item.required === true }
    const help = configText(item.help, 500)
    if (help) field.help = help
    if (item.default !== undefined && item.default !== null && item.default !== '') {
      if (type === 'secret') warnings.push(`${CONFIGURATION_PATH}: secret field ${key} must not have a default; default dropped`)
      else field.default = String(item.default).slice(0, 500)
    }
    keys.add(key)
    fields.push(field)
  }
  const injections = []
  for (const item of Array.isArray(data.configurationInjections) ? data.configurationInjections.slice(0, MAX_CONFIGURATION_ITEMS) : []) {
    const key = configText(item?.key, 64)
    const file = configText(item?.file, 256)
    const marker = typeof item?.marker === 'string' ? item.marker.slice(0, 200) : ''
    if (!keys.has(key) || !file || !marker) {
      warnings.push(`${CONFIGURATION_PATH}: injection for "${key}" needs a declared key, file and marker; skipped`)
      continue
    }
    injections.push({ key, file, marker })
  }
  if (!fields.length) {
    return { configuration: null, warnings: [...warnings, `${CONFIGURATION_PATH} declares no configurationFields; the preview runs without configuration`] }
  }
  return { configuration: { configurationFields: fields, configurationInjections: injections }, warnings }
}

export async function readProjectConfiguration(root) {
  let raw
  try {
    raw = await readFile(join(root, ...CONFIGURATION_PATH.split('/')), 'utf8')
  } catch {
    return { configuration: null, warnings: [] }
  }
  return parseProjectConfiguration(raw)
}

function assetMime(path) {
  const lower = String(path || '').toLowerCase()
  if (lower.endsWith('.xic')) return 'application/x-xic'
  if (lower.endsWith('.png')) return 'image/png'
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg'
  if (lower.endsWith('.webp')) return 'image/webp'
  return 'application/octet-stream'
}

function assetKey(path) {
  const match = String(path || '').match(/(?:^|\/)([A-Za-z0-9_-]{1,23})\.(?:xic|png|jpe?g|webp)$/i)
  return match ? match[1] : basename(path).replace(/\.[^.]+$/, '')
}
const IGNORED_DIRS = new Set(['.git', 'node_modules', 'dist', 'build', '.vite'])

function assertProjectDir(value) {
  const raw = String(value || '').trim()
  if (!raw) throw new Error('Provide the absolute path of the XTApp project')
  const dir = normalizeAbsolutePath(raw)
  if (!dir) throw new Error(`Project path must be absolute: ${raw}`)
  return dir
}

function safeRelativePath(value) {
  const path = value.split(sep).join('/')
  if (!path || path.startsWith('/') || path.split('/').some((part) => !part || part === '.' || part === '..')) return null
  return path
}

async function collectFiles(root) {
  const files = {}
  const warnings = []
  let totalBytes = 0
  const assets = []
  let totalAssetBytes = 0
  const walk = async (dir) => {
    const entries = await readdir(dir, { withFileTypes: true })
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (!IGNORED_DIRS.has(entry.name)) await walk(join(dir, entry.name))
        continue
      }
      const absolute = join(dir, entry.name)
      const path = safeRelativePath(relative(root, absolute))
      if (!path) continue
      if (TEXT_FILE.test(path) && Object.keys(files).length >= MAX_FILES) { warnings.push(`More than ${MAX_FILES} text files; truncated`); continue }
      const target = await realpath(absolute).catch(() => null)
      if (!target || !isInsideRoot(root, target)) { warnings.push(`${path} links outside the project; skipped`); continue }
      const bytes = await readFile(target)
      if (ASSET_FILE.test(path)) {
        if (assets.length >= MAX_ASSETS) { warnings.push(`More than ${MAX_ASSETS} assets; truncated`); continue }
        if (bytes.length > MAX_ASSET_BYTES) { warnings.push(`${path} is over ${MAX_ASSET_BYTES} bytes; skipped`); continue }
        totalAssetBytes += bytes.length
        assets.push({ path, key: assetKey(path), mime: assetMime(path), bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), base64: bytes.toString('base64') })
        continue
      }
      if (!TEXT_FILE.test(path)) {
        if (LOOKS_LIKE_SOURCE.test(path) && !SILENT_SKIP.test(path)) {
          warnings.push(`${path} is not a syncable XTApp source path; skipped`)
        }
        continue
      }
      if (bytes.length > MAX_FILE_BYTES) { warnings.push(`${path} is over ${MAX_FILE_BYTES} bytes; skipped`); continue }
      totalBytes += bytes.length
      files[path] = bytes.toString('utf8')
    }
  }
  await walk(root)
  return { files, assets, warnings, totalBytes, assetBytes: totalAssetBytes }
}

/** Absolute, symlink-resolved project root: the one form every map key, session and Studio binding uses. */
export async function resolveProjectDir(projectDir) {
  const dir = assertProjectDir(projectDir)
  return realpath(dir).catch(() => dir)
}

export async function readProjectSnapshot(projectDir) {
  const root = await resolveProjectDir(projectDir)
  const info = await stat(root).catch(() => null)
  if (!info?.isDirectory()) throw new Error(`Project directory does not exist: ${root}`)
  const { files, assets, warnings, totalBytes, assetBytes } = await collectFiles(root)
  let manifest = null
  if (typeof files['manifest.json'] === 'string') {
    try { manifest = JSON.parse(files['manifest.json']) } catch { warnings.push('manifest.json is not valid JSON; the preview will show a validation error') }
  } else warnings.push('manifest.json not found')
  const cloudProjectId = await readCloudProjectId(root)
  const { configuration, warnings: configurationWarnings } = await readProjectConfiguration(root)
  warnings.push(...configurationWarnings)
  return {
    projectDir: root,
    projectName: basename(root),
    revision: snapshotRevision(files, assets, `${cloudProjectId}${configurationRevisionTag(configuration)}`),
    manifest,
    files,
    assets,
    warnings,
    fileCount: Object.keys(files).length,
    totalBytes,
    assetBytes,
    assetCount: assets.length,
    capturedAt: Date.now(),
    cloudProjectId,
    configuration,
  }
}
