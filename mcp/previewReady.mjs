export const PLUGIN_VERSION = '0.1.12'
export const PREVIEW_RUN_WAIT_MS = 30_000
export const PREVIEW_QUICK_WAIT_MS = 10_000

export function requireProjectDir(projectDir) {
  const dir = String(projectDir || '').trim()
  if (!dir) throw new Error('projectDir must be the absolute path of the current worktree; this tool does not preview other projects already open in Studio')
  return dir
}

export function previewCommandWaitMs(path) {
  return path === '/preview/run' || path === '/preview/restart' ? PREVIEW_RUN_WAIT_MS : PREVIEW_QUICK_WAIT_MS
}

export function displayNameFromManifest(manifest, fallback = '') {
  return String(manifest?.display_name || fallback || '').trim()
}

export function describePreviewReady({
  connectedStatus = '',
  commandStatus = '',
  previewUrl = '',
  displayName = '',
  message = '',
} = {}) {
  const name = String(displayName || '').trim()
  const url = String(previewUrl || '').trim()
  const named = name ? `"${name}"` : 'The current project'
  if (connectedStatus === 'no_project' || commandStatus === 'no_project') {
    return {
      userStatus: 'no_project',
      displayName: name || null,
      previewUrl: url,
      message: message || 'No project selected yet: call run_xtapp_preview with the project\'s absolute path first.',
    }
  }
  if (connectedStatus === 'not_connected' || commandStatus === 'not_connected') {
    return {
      userStatus: 'need_login_or_open_page',
      displayName: name || null,
      previewUrl: url,
      message: `Open this preview page. If a sign-in page appears, sign in, return to this URL, and keep it open: ${url}`,
    }
  }
  if (connectedStatus === 'timeout' || commandStatus === 'timeout') {
    return {
      userStatus: 'timeout',
      displayName: name || null,
      previewUrl: url,
      message: message || 'The Studio preview bridge did not respond in time. Make sure the preview page is still open at the same URL, then retry.',
    }
  }
  if (commandStatus === 'queued_timeout') {
    return {
      userStatus: 'timeout',
      displayName: name || null,
      previewUrl: url,
      message: message || 'Studio received the start request, but the preview is not running yet. Make sure the preview page is still open at the same URL, then retry.',
    }
  }
  if (commandStatus === 'error' || connectedStatus === 'error') {
    return {
      userStatus: 'error',
      displayName: name || null,
      previewUrl: url,
      message: message || `${named} failed to start in the preview.`,
    }
  }
  if (connectedStatus === 'running' || connectedStatus === 'loading' || commandStatus === 'complete') {
    return {
      userStatus: 'running',
      displayName: name || null,
      previewUrl: url,
      message: `${named} is running on the Studio preview page. The simulator is in the web page, not in the side panel.`,
    }
  }
  if (connectedStatus === 'stopped') {
    return {
      userStatus: 'stopped',
      displayName: name || null,
      previewUrl: url,
      message: `${named} preview stopped. Sync the current worktree and start it again when needed.`,
    }
  }
  return {
    userStatus: 'page_open',
    displayName: name || null,
    previewUrl: url,
    message: 'The preview page is open. The simulator is in the web page. Sync the current worktree to show this local project.',
  }
}
