import path from 'node:path'

// 路径判断统一走这里，不写死 '/'：macOS、Linux、Windows（含 Git Bash 的 /d/... 写法）都按各自规则处理。
const MSYS_DRIVE = /^\/([A-Za-z])(?:\/|$)/

function pathApi(platform) {
  return platform === 'win32' ? path.win32 : path.posix
}

/** Turn a user-supplied project path into an absolute path, or '' when it is not absolute. */
export function normalizeAbsolutePath(value, platform = process.platform) {
  let raw = String(value || '').trim()
  if (!raw) return ''
  const api = pathApi(platform)
  if (platform === 'win32') {
    // Git Bash / MSYS 给出的 /d/proj 指 D:\proj；不转的话会落到当前盘的 \d\proj。
    const drive = raw.match(MSYS_DRIVE)
    if (drive) raw = `${drive[1].toUpperCase()}:\\${raw.slice(drive[0].length)}`
    // 只有盘符或 UNC 开头才算绝对路径；\proj 这种依赖当前盘，不接受。
    if (!/^[A-Za-z]:[\\/]/.test(raw) && !/^[\\/]{2}[^\\/]/.test(raw)) return ''
  } else if (!api.isAbsolute(raw)) {
    return ''
  }
  return api.resolve(raw)
}

/** Key for comparing two paths: Windows file names are case-insensitive. */
export function pathKey(value, platform = process.platform) {
  const text = String(value || '')
  return platform === 'win32' ? pathApi(platform).normalize(text).toLowerCase() : text
}

export function samePath(a, b, platform = process.platform) {
  return pathKey(a, platform) === pathKey(b, platform)
}

/** True when target is root itself or lies under it. */
export function isInsideRoot(root, target, platform = process.platform, { allowRoot = true } = {}) {
  const api = pathApi(platform)
  const rel = api.relative(pathKey(api.resolve(root), platform), pathKey(api.resolve(target), platform))
  if (!rel) return allowRoot
  return rel !== '..' && !rel.startsWith(`..${api.sep}`) && !api.isAbsolute(rel)
}

/** True when a project-relative destination is absolute on any system (/x, \x, D:\x, D:x). */
export function looksAbsolute(value) {
  const text = String(value || '')
  return path.posix.isAbsolute(text) || path.win32.isAbsolute(text) || /^[A-Za-z]:/.test(text)
}
