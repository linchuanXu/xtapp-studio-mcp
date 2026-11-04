import { configurationRevisionTag, snapshotRevision } from './projectSnapshot.mjs'
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
    configuration: snapshot.configuration || null,
  }
}

// 本地有声明就带上；声明文件删了就发空列表，让 Studio 一并清掉。从没有过声明时不发，保留 Studio 里已有的。
function configurationBody(configuration) {
  return {
    configurationFields: configuration?.configurationFields || [],
    configurationInjections: configuration?.configurationInjections || [],
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

export function sourcePushBodies(snapshot = {}, { overwriteProjectId = '' } = {}) {
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
    revision: snapshotRevision(firstFiles, firstAssets, `${snapshot.cloudProjectId || ''}${configurationRevisionTag(snapshot.configuration)}${overwriteProjectId ? `|overwrite:${overwriteProjectId}` : ''}`),
    ...(snapshot.cloudProjectId ? { cloudProjectId: snapshot.cloudProjectId } : {}),
    ...(snapshot.configuration ? configurationBody(snapshot.configuration) : {}),
    ...(overwriteProjectId ? { overwriteProjectId } : {}),
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

async function pushReplace(snapshot, request, { overwriteProjectId = '' } = {}) {
  const bodies = sourcePushBodies(snapshot, { overwriteProjectId })
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
      // 分批的后续补丁也带上覆盖目标，否则代理会在整份推完前把它清掉。
      ...(overwriteProjectId ? { overwriteProjectId } : {}),
    })
    if (!result?.revision) break
  }
  return finishPush(snapshot, result)
}

async function pushPatch(snapshot, previous, request) {
  const diff = diffSnapshots(previous, snapshot)
  const hasDeletes = diff.deleteFiles.length || diff.deleteAssets.length
  const bindingChanged = String(snapshot.cloudProjectId || '') !== String(previous.cloudProjectId || '')
  const configurationChanged = JSON.stringify(snapshot.configuration || null) !== JSON.stringify(previous.configuration || null)
  if (!Object.keys(diff.files).length && !diff.assets.length && !hasDeletes && !bindingChanged && !configurationChanged) {
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
    ...(configurationChanged ? configurationBody(snapshot.configuration) : {}),
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

export async function pushProjectSnapshot(snapshot, request, { previous, overwriteProjectId = '' } = {}) {
  // 用户点名覆盖已有项目：整份推一次，Studio 据此清掉目标项目里本地没有的文件和图。
  if (overwriteProjectId) return pushReplace(snapshot, request, { overwriteProjectId })
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

// 覆盖后 Studio 沿用原项目的 app_id 和项目 id；本地还是旧的，下次同步就会改回去或另建项目。
export function overwriteNote(overwrite, { localAppId = '', localCloudProjectId = '' } = {}) {
  if (!overwrite?.projectId) return ''
  const steps = []
  if (overwrite.appId && String(localAppId || '').trim() !== overwrite.appId) {
    steps.push(`set "app_id" in manifest.json to "${overwrite.appId}"`)
  }
  if (String(localCloudProjectId || '').trim() !== overwrite.projectId) {
    steps.push(`write docs/studio.cloud.json as {"cloudProjectId": "${overwrite.projectId}"}`)
  }
  const tell = 'Tell the user: the project id, app_id and store listing link did not change; the "Before overwrite" snapshot in Studio History restores the old version; the store listing updates only after they save to the cloud and the review passes.'
  if (!steps.length) return `Studio overwrote the project; it kept its project id and app_id. ${tell}`
  return `Studio overwrote the project and kept its project id and app_id. In the local folder now ${steps.join(' and ')}; otherwise the next sync changes the app_id back or opens a different Studio project, and the store listing no longer matches. ${tell}`
}
