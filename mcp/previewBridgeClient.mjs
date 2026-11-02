export const PREVIEW_SOURCE_WAIT_MS = 120_000
export const PREVIEW_DEFAULT_WAIT_MS = 10_000

export function unwrapPreviewEnvelope(body) {
  if (body && body.ok === false) {
    const error = new Error(body.error?.message || 'Preview bridge request failed')
    error.code = body.error?.code
    error.details = body.error?.details
    error.status = body.error?.status
    throw error
  }
  if (body && body.ok === true && body.data && typeof body.data === 'object') return body.data
  throw new Error('Invalid preview bridge response')
}

export function classifyPreviewBridgeError(error, origin = '') {
  if (error?.cause?.code === 'ECONNREFUSED' || error?.code === 'ECONNREFUSED' || error?.cause?.code === 'ECONNRESET') {
    return { status: 'not_connected', message: `Cannot reach the Studio preview bridge: ${origin}` }
  }
  if (error?.name === 'AbortError') {
    return {
      status: 'timeout',
      code: 'PREVIEW_TIMEOUT',
      message: `Studio response timed out: ${origin}`,
    }
  }
  throw error
}

export function formatDroppedAssets(dropped = []) {
  if (!Array.isArray(dropped) || !dropped.length) return ''
  return `Not accepted: ${dropped.map((item) => `${item.path || item.key || 'unknown'} (${item.reason || 'unknown'})`).join('; ')}`
}

export function describeSourceSync(result = {}) {
  const dropped = formatDroppedAssets(result.dropped)
  if (result.status === 'not_connected') {
    return [result.message, dropped].filter(Boolean).join('\n')
  }
  if (result.status === 'timeout') {
    return [result.message || 'The Studio preview bridge timed out before the source finished uploading. Make sure the preview page is still open at the same URL, then retry.', dropped].filter(Boolean).join('\n')
  }
  if (result.status === 'unchanged') {
    return [`Source unchanged; revision ${result.revision || ''} is already on the preview bridge.`, dropped].filter(Boolean).join('\n')
  }
  const accepted = `Synced revision ${result.revision || ''}: accepted ${result.fileCount ?? result.accepted?.files?.length ?? 0} files and ${result.assetCount ?? result.accepted?.assets?.length ?? 0} assets.`
  return [accepted, dropped].filter(Boolean).join('\n')
}

export function isFailedCommand(result = {}) {
  return result.ok === false || result.status === 'error' || result.outcome?.status === 'error'
}

export function isRevisionConflict(error) {
  return error?.code === 'REVISION_CONFLICT'
}

export function previewRequestTimeoutMs(path) {
  return path === '/preview/source' || path === '/preview/source/patch' || path === '/preview/source/validate'
    ? PREVIEW_SOURCE_WAIT_MS
    : PREVIEW_DEFAULT_WAIT_MS
}
