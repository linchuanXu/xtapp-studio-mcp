import { snapshotRevision } from './projectSnapshot.mjs'
import { isRevisionConflict } from './previewBridgeClient.mjs'

export const SOURCE_ASSET_BATCH = 80
export const SOURCE_ASSET_BATCH_BYTES = 4 * 1024 * 1024
export const SOURCE_FILE_BATCH = 200
export const SOURCE_FILE_BATCH_BYTES = 4 * 1024 * 1024

const projectPushLocks = new Map()

export function withProjectPushLock(projectDir, fn) {
  const key = String(projectDir || '')
  const previous = projectPushLocks.get(key) || Promise.resolve()
  const run = previous.catch(() => {}).then(fn)
  projectPushLocks.set(key, run)
  return run
}

export function snapshotPushState(snapshot = {}, serverRevision = '') {
  return {
    revision: snapshot.revision,
    serverRevision,
    files: snapshot.files && typeof snapshot.files === 'object' ? { ...snapshot.files } : {},
    assetHashes: Object.fromEntries(
      (Array.isArray(snapshot.assets) ? snapshot.assets : [])
        .filter((item) => item?.key)
        .map((item) => [item.key, item.sha256]),
    ),
    cloudProjectId: String(snapshot.cloudProjectId || ''),
  }
}

function previousAssetHashes(previous = {}) {
  if (previous.assetHashes && typeof previous.assetHashes === 'object' && !Array.isArray(previous.assetHashes)) {
    return previous.assetHashes
  }
  return Object.fromEntries(
    (Array.isArray(previous.assets) ? previous.assets : [])
      .filter((item) => item?.key)
      .map((item) => [item.key, item.sha256]),
  )
}

export function splitAssetBatches(assets = [], {
  maxCount = SOURCE_ASSET_BATCH,
  maxBytes = SOURCE_ASSET_BATCH_BYTES,
} = {}) {
  const batches = []
  let current = []
  let bytes = 0
  for (const asset of assets) {
    const size = Number(asset?.bytes) || 0
    if (current.length && (current.length >= maxCount || bytes + size > maxBytes)) {
      batches.push(current)
      current = []
      bytes = 0
    }
    current.push(asset)
    bytes += size
  }
  if (current.length || !batches.length) batches.push(current)
  return batches
}

export function splitFileBatches(files = {}, {
  maxCount = SOURCE_FILE_BATCH,
  maxBytes = SOURCE_FILE_BATCH_BYTES,
} = {}) {
  const entries = Object.entries(files)
  if (!entries.length) return [{}]
  const batches = []
  let current = {}
  let count = 0
  let bytes = 0
  for (const [path, content] of entries) {
    const size = Buffer.byteLength(String(content ?? ''), 'utf8')
    if (count && (count >= maxCount || bytes + size > maxBytes)) {
      batches.push(current)
      current = {}
      count = 0
      bytes = 0
    }
    current[path] = content
    count += 1
    bytes += size
  }
  if (count) batches.push(current)
  return batches
}

export function diffSnapshots(previous = {}, next = {}) {
  const prevFiles = previous.files && typeof previous.files === 'object' ? previous.files : {}
  const nextFiles = next.files && typeof next.files === 'object' ? next.files : {}
  const files = {}
  const deleteFiles = []
  for (const [path, content] of Object.entries(nextFiles)) {
    if (prevFiles[path] !== content) files[path] = content
  }
  for (const path of Object.keys(prevFiles)) {
    if (!Object.hasOwn(nextFiles, path)) deleteFiles.push(path)
  }
  const prevAssets = previousAssetHashes(previous)
  const nextAssets = Array.isArray(next.assets) ? next.assets : []
  const assets = nextAssets.filter((item) => item?.key && prevAssets[item.key] !== item.sha256)
  const nextKeys = new Set(nextAssets.map((item) => item.key).filter(Boolean))
  const deleteAssets = Object.keys(prevAssets).filter((key) => !nextKeys.has(key))
  return {
    files,
    deleteFiles,
    assets,
    deleteAssets,
    fileKeys: Object.keys(nextFiles),
    assetKeys: nextAssets.map((item) => item.key).filter(Boolean),
  }
}

function catalogOf(snapshot = {}) {
  const files = snapshot.files && typeof snapshot.files === 'object' ? snapshot.files : {}
  const assets = Array.isArray(snapshot.assets) ? snapshot.assets : []
  return {
    fileKeys: Object.keys(files),
    assetKeys: assets.map((item) => item.key).filter(Boolean),
  }
}

export function sourcePushBodies(snapshot = {}) {
  const files = snapshot.files && typeof snapshot.files === 'object' ? snapshot.files : {}
  const assets = Array.isArray(snapshot.assets) ? snapshot.assets : []
  const { fileKeys, assetKeys } = catalogOf(snapshot)
  const fileBatches = splitFileBatches(files)
  const assetBatches = splitAssetBatches(assets)
  const bodies = []
  const firstFiles = fileBatches[0] || {}
  const firstAssets = assetBatches[0] || []
  bodies.push({
    projectDir: snapshot.projectDir,
    projectName: snapshot.projectName,
    pluginVersion: snapshot.pluginVersion,
    manifest: snapshot.manifest,
    files: firstFiles,
    assets: firstAssets,
    fileKeys,
    assetKeys,
    warnings: snapshot.warnings || [],
    fileCount: snapshot.fileCount,
    assetCount: snapshot.assetCount,
    capturedAt: snapshot.capturedAt,
    revision: snapshotRevision(firstFiles, firstAssets, snapshot.cloudProjectId),
    ...(snapshot.cloudProjectId ? { cloudProjectId: snapshot.cloudProjectId } : {}),
  })
  for (const batch of fileBatches.slice(1)) {
    bodies.push({
      projectDir: snapshot.projectDir,
      files: batch,
      assets: [],
      fileKeys,
      assetKeys,
      warnings: snapshot.warnings || [],
    })
  }
  for (const batch of assetBatches.slice(1)) {
    bodies.push({
      projectDir: snapshot.projectDir,
      files: {},
      assets: batch,
      fileKeys,
      assetKeys,
      warnings: snapshot.warnings || [],
    })
  }
  return bodies
}

function finishPush(snapshot, result) {
  return {
    ...result,
    projectDir: snapshot.projectDir,
    warnings: [...new Set([...(snapshot.warnings || []), ...(result?.warnings || [])])],
    fileCount: snapshot.fileCount,
    assetCount: snapshot.assetCount,
    assetBytes: snapshot.assetBytes,
  }
}

async function pushReplace(snapshot, request) {
  const bodies = sourcePushBodies(snapshot)
  const first = bodies[0]
  let result = await request('/preview/source', first)
  if (!result?.revision) return finishPush(snapshot, result)
  for (const body of bodies.slice(1)) {
    result = await request('/preview/source/patch', {
      baseRevision: result.revision,
      files: body.files,
      assets: body.assets,
      fileKeys: body.fileKeys,
      assetKeys: body.assetKeys,
      warnings: body.warnings,
    })
    if (!result?.revision) break
  }
  return finishPush(snapshot, result)
}

async function pushPatch(snapshot, previous, request) {
  const diff = diffSnapshots(previous, snapshot)
  const hasDeletes = diff.deleteFiles.length || diff.deleteAssets.length
  const bindingChanged = String(snapshot.cloudProjectId || '') !== String(previous.cloudProjectId || '')
  if (!Object.keys(diff.files).length && !diff.assets.length && !hasDeletes && !bindingChanged) {
    return finishPush(snapshot, {
      status: 'unchanged',
      revision: previous.serverRevision,
    })
  }
  const fileBatches = splitFileBatches(diff.files)
  const assetBatches = splitAssetBatches(diff.assets)
  const firstFiles = Object.keys(diff.files).length ? fileBatches[0] || {} : {}
  const restFiles = Object.keys(diff.files).length ? fileBatches.slice(1) : []
  const firstAssets = diff.assets.length ? assetBatches[0] || [] : []
  const restAssets = diff.assets.length ? assetBatches.slice(1) : []
  let revision = previous.serverRevision
  let result = await request('/preview/source/patch', {
    baseRevision: revision,
    files: firstFiles,
    assets: firstAssets,
    fileKeys: diff.fileKeys,
    assetKeys: diff.assetKeys,
    deleteFiles: diff.deleteFiles,
    deleteAssets: diff.deleteAssets,
    warnings: snapshot.warnings || [],
    ...(snapshot.cloudProjectId ? { cloudProjectId: snapshot.cloudProjectId } : {}),
  })
  if (!result?.revision) return finishPush(snapshot, result)
  revision = result.revision
  for (const batch of restFiles) {
    result = await request('/preview/source/patch', {
      baseRevision: revision,
      files: batch,
      assets: [],
      fileKeys: diff.fileKeys,
      assetKeys: diff.assetKeys,
      warnings: snapshot.warnings || [],
    })
    if (!result?.revision) return finishPush(snapshot, result)
    revision = result.revision
  }
  for (const batch of restAssets) {
    result = await request('/preview/source/patch', {
      baseRevision: revision,
      files: {},
      assets: batch,
      fileKeys: diff.fileKeys,
      assetKeys: diff.assetKeys,
      warnings: snapshot.warnings || [],
    })
    if (!result?.revision) return finishPush(snapshot, result)
    revision = result.revision
  }
  return finishPush(snapshot, result)
}

export async function pushProjectSnapshot(snapshot, request, { previous } = {}) {
  if (previous?.serverRevision && previous.revision === snapshot.revision) {
    return finishPush(snapshot, {
      status: 'unchanged',
      revision: previous.serverRevision,
    })
  }
  if (!previous?.serverRevision) return pushReplace(snapshot, request)
  try {
    return await pushPatch(snapshot, previous, request)
  } catch (error) {
    if (!isRevisionConflict(error)) throw error
    return pushReplace(snapshot, request)
  }
}
