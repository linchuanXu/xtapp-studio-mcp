import { createHash } from 'node:crypto'
import { mkdir, rm, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { TEXT_FILE } from './projectSnapshot.mjs'

// 把 Studio 里的文件和图拉回本地目录。Studio 上传或生成的图同步时不会被删，
// AI 可以拉回本地收进代码，或在用户同意后用 deleteAssets 删掉。

const ASSET_KEY = /^[A-Za-z0-9_-]{1,23}$/
export const EXPORT_BATCH_ITEMS = 200
export const EXPORT_BATCH_BYTES = 3 * 1024 * 1024

function sha256Text(text) {
  return createHash('sha256').update(String(text ?? ''), 'utf8').digest('hex')
}

// Studio reports the original image hash and the XIC hash; a pulled .xic matches the latter.
function sameAsset(hash, asset = {}) {
  return Boolean(hash) && (hash === asset.hash || hash === asset.contentHash)
}

/** Default pull: everything Studio has that the local worktree lacks. */
export function selectPullItems({ snapshot = {}, catalog = {}, paths, keys, overwrite = false } = {}) {
  const localFiles = snapshot.files || {}
  const localAssets = Object.fromEntries((snapshot.assets || []).filter((item) => item?.key).map((item) => [item.key, item.sha256]))
  const studioFiles = catalog.files || {}
  const studioAssets = new Map((catalog.assets || []).map((item) => [item.key, item]))
  const explicit = Array.isArray(paths) || Array.isArray(keys)
  const wantPaths = explicit ? (paths || []) : Object.keys(studioFiles)
  const wantKeys = explicit ? (keys || []) : [...studioAssets.keys()]
  const skipped = []
  const missing = []
  const pullPaths = []
  const pullKeys = []
  for (const path of wantPaths) {
    if (!Object.hasOwn(studioFiles, path)) { missing.push(path); continue }
    if (Object.hasOwn(localFiles, path)) {
      if (sha256Text(localFiles[path]) === studioFiles[path]) continue
      if (!overwrite) { skipped.push(path); continue }
    }
    pullPaths.push(path)
  }
  for (const key of wantKeys) {
    const asset = studioAssets.get(key)
    if (!asset) { missing.push(key); continue }
    if (Object.hasOwn(localAssets, key)) {
      if (sameAsset(localAssets[key], asset)) continue
      if (!overwrite) { skipped.push(key); continue }
    }
    pullKeys.push(key)
  }
  return { paths: pullPaths, keys: pullKeys, skipped, missing }
}

export function splitExportBatches({ paths = [], keys = [] } = {}, catalog = {}, {
  maxItems = EXPORT_BATCH_ITEMS,
  maxBytes = EXPORT_BATCH_BYTES,
} = {}) {
  const sizes = new Map((catalog.assets || []).map((item) => [item.key, Number(item.bytes) || 0]))
  const batches = []
  let current = { paths: [], keys: [] }
  let bytes = 0
  const push = (kind, value, size) => {
    const count = current.paths.length + current.keys.length
    if (count && (count >= maxItems || bytes + size > maxBytes)) {
      batches.push(current)
      current = { paths: [], keys: [] }
      bytes = 0
    }
    current[kind].push(value)
    bytes += size
  }
  for (const path of paths) push('paths', path, 0)
  for (const key of keys) push('keys', key, sizes.get(key) || 0)
  if (current.paths.length || current.keys.length) batches.push(current)
  return batches
}

function insideRoot(root, relativePath) {
  const target = resolve(root, relativePath)
  if (!target.startsWith(`${root}/`)) throw new Error(`导出路径越过项目目录：${relativePath}`)
  return target
}

/** Write exported Studio files into the worktree; an asset replaces any local file with the same key. */
export async function writeExportedItems(root, exported = {}, snapshot = {}) {
  const written = []
  for (const [path, content] of Object.entries(exported.files || {})) {
    if (!TEXT_FILE.test(path) || typeof content !== 'string') continue
    const target = insideRoot(root, path)
    await mkdir(dirname(target), { recursive: true })
    await writeFile(target, content, 'utf8')
    written.push(path)
  }
  for (const asset of exported.assets || []) {
    const key = String(asset?.key || '')
    if (!ASSET_KEY.test(key) || typeof asset.base64 !== 'string') continue
    const path = `assets/${key}.xic`
    for (const old of (snapshot.assets || []).filter((item) => item.key === key && item.path !== path)) {
      await rm(insideRoot(root, old.path), { force: true })
    }
    const target = insideRoot(root, path)
    await mkdir(dirname(target), { recursive: true })
    await writeFile(target, Buffer.from(asset.base64, 'base64'))
    written.push(path)
  }
  return written
}

/** Tell the agent which Studio images sync kept and which it deleted on request. */
export function describeStudioAssets({ keptAssets = [], deleted = [], deleteMissing = [] } = {}) {
  return [
    deleted.length ? `已删除 Studio 里的图：${deleted.join('、')}` : '',
    deleteMissing.length ? `Studio 里没有这些图，未删除：${deleteMissing.join('、')}` : '',
    keptAssets.length
      ? `Studio 里有 ${keptAssets.length} 张图本地没有（用户在 Studio 上传或生成的），同步时已保留：${keptAssets.join('、')}。如果用户之前没提过，告诉用户一声；要用就调用 pull_xtapp_studio_source 拉回本地，用户要删就在下次 run_xtapp_preview 带上 deleteAssets。`
      : '',
  ].filter(Boolean).join('\n')
}
