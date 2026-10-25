export const PLUGIN_VERSION = '0.1.7'
export const PREVIEW_RUN_WAIT_MS = 30_000
export const PREVIEW_QUICK_WAIT_MS = 4_000

export function requireProjectDir(projectDir) {
  const dir = String(projectDir || '').trim()
  if (!dir) throw new Error('必须提供当前 worktree 的绝对路径 projectDir，不能预览官网里已经打开的其他项目')
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
  const named = name ? `「${name}」` : '当前项目'
  if (connectedStatus === 'not_connected' || commandStatus === 'not_connected') {
    return {
      userStatus: 'need_login_or_open_page',
      displayName: name || null,
      previewUrl: url,
      message: `请打开这个预览页。如果出现登录页，先登录，再回到这个地址，并保持打开：${url}`,
    }
  }
  if (connectedStatus === 'timeout' || commandStatus === 'timeout') {
    return {
      userStatus: 'timeout',
      displayName: name || null,
      previewUrl: url,
      message: message || '官网预览桥没有及时响应。请确认预览页仍打开着同一条链接，然后重试。',
    }
  }
  if (commandStatus === 'queued_timeout') {
    return {
      userStatus: 'timeout',
      displayName: name || null,
      previewUrl: url,
      message: message || '官网已收到启动请求，但预览还没跑起来。请确认预览页仍打开着同一条链接，然后重试。',
    }
  }
  if (commandStatus === 'error' || connectedStatus === 'error') {
    return {
      userStatus: 'error',
      displayName: name || null,
      previewUrl: url,
      message: message || `${named}预览启动失败。`,
    }
  }
  if (connectedStatus === 'running' || connectedStatus === 'loading' || commandStatus === 'complete') {
    return {
      userStatus: 'running',
      displayName: name || null,
      previewUrl: url,
      message: `${named}已在官网预览页运行。模拟器在网页里，不在右侧面板。`,
    }
  }
  if (connectedStatus === 'stopped') {
    return {
      userStatus: 'stopped',
      displayName: name || null,
      previewUrl: url,
      message: `${named}预览已停止。可再次同步当前 worktree 并启动。`,
    }
  }
  return {
    userStatus: 'page_open',
    displayName: name || null,
    previewUrl: url,
    message: '预览页已打开。模拟器在网页里。同步当前 worktree 后才会显示这个本地项目。',
  }
}
