// 预览存储卡上本应用的文件夹 /AppFiles/<app_id>/（第 29 节 ctx.files）增删改查。
// Studio 那边按字节走 base64：读一次最多回 2 MiB，写一次最多 256 KiB，这里负责分段。
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, isAbsolute, resolve } from 'node:path'
import { isFailedCommand } from './previewBridgeClient.mjs'

export const APP_FILE_READ_CHUNK = 2 * 1024 * 1024
export const APP_FILE_WRITE_CHUNK = 256 * 1024
// 不带 savePath 时直接回给模型的上限；更大的文件请给 savePath 存到本地再看。
export const APP_FILE_INLINE_TEXT_MAX = 256 * 1024
export const APP_FILE_INLINE_BINARY_MAX = 48 * 1024
// 整个文件经插件搬运的上限，同预览文件夹上限。
export const APP_FILE_TRANSFER_MAX = 64 * 1024 * 1024

const utf8 = new TextDecoder('utf-8', { fatal: true })

function utf8Text(bytes) {
  try {
    return utf8.decode(bytes)
  } catch {
    return null
  }
}

/** send(body) 走 /preview/app_files 并等结果；Studio 没回报或报错时抛出可读的错误。 */
export async function appFilesCommand(send, body) {
  const result = await send(body)
  if (result?.appFiles && !isFailedCommand(result) && result.status === 'complete') return result.appFiles
  const reason = result?.message || result?.outcome?.error || result?.status || 'unknown'
  throw new Error(result?.status === 'not_connected'
    ? `Studio preview page is not connected: ${reason}`
    : `Studio did not finish the storage card file operation: ${reason}`)
}

const localPath = (projectDir, path) => (isAbsolute(path) ? path : resolve(projectDir, path))

export async function listAppFiles(send) {
  const listed = await appFilesCommand(send, { action: 'list' })
  const lines = (listed.files || []).map((file) => `${file.name}\t${file.size}${file.visible === false ? '\t(invalid name; the app cannot see it)' : ''}`)
  const head = `${listed.path} · ${listed.files?.length || 0} files · ${listed.bytes} bytes (preview limit ${listed.maxBytes})`
  return { ...listed, message: [head, ...lines].join('\n') }
}

/** 分段读完整个文件，返回 { name, size, bytes, path }。 */
export async function readWholeAppFile(send, name) {
  const parts = []
  let offset = 0
  let first
  do {
    const part = await appFilesCommand(send, { action: 'read', name, offset, length: APP_FILE_READ_CHUNK })
    first ||= part
    if (part.size > APP_FILE_TRANSFER_MAX) throw new Error(`"${part.name}" is ${part.size} bytes, over the plugin transfer limit of ${APP_FILE_TRANSFER_MAX}`)
    const bytes = Buffer.from(part.contentBase64 || '', 'base64')
    if (!bytes.length && part.end < part.size) throw new Error(`Studio returned an empty chunk while reading "${part.name}"`)
    parts.push(bytes)
    offset = part.end
    if (offset >= part.size) break
  } while (true)
  return { name: first.name, size: first.size, path: first.path, bytes: Buffer.concat(parts) }
}

/**
 * 读一个文件。给 savePath（相对 projectDir 或绝对路径）就原样存到本地；
 * 否则 UTF-8 文字直接回文字，小的二进制回 base64，大文件提示改用 savePath。
 */
export async function readAppFile(send, { name, savePath, projectDir }) {
  const file = await readWholeAppFile(send, name)
  const base = { name: file.name, size: file.size, appFilesPath: file.path }
  if (savePath) {
    const target = localPath(projectDir, savePath)
    await mkdir(dirname(target), { recursive: true })
    await writeFile(target, file.bytes)
    return { ...base, savedTo: target, message: `Saved ${file.path}/${file.name} (${file.size} bytes) to ${target}` }
  }
  const text = utf8Text(file.bytes)
  if (text !== null && file.size <= APP_FILE_INLINE_TEXT_MAX) return { ...base, encoding: 'text', content: text, message: text }
  if (text === null && file.size <= APP_FILE_INLINE_BINARY_MAX) {
    const contentBase64 = file.bytes.toString('base64')
    return { ...base, encoding: 'base64', contentBase64, message: `"${file.name}" is ${file.size} bytes and not UTF-8 text. base64:\n${contentBase64}` }
  }
  return { ...base, status: 'too_large_inline', message: `"${file.name}" is ${file.size} bytes, too large to return inline. Pass savePath to save it locally.` }
}

/** 内容三选一：content（文字，按 UTF-8 存）、contentBase64、sourcePath（本地文件）。 */
export async function appFileBytes({ content, contentBase64, sourcePath, projectDir }) {
  const given = [content, contentBase64, sourcePath].filter((value) => value !== undefined)
  if (given.length !== 1) throw new Error('Give exactly one of content, contentBase64, or sourcePath')
  if (content !== undefined) return Buffer.from(String(content), 'utf8')
  if (sourcePath !== undefined) return readFile(localPath(projectDir, sourcePath))
  const text = String(contentBase64).replace(/\s+/g, '')
  if (!/^[A-Za-z0-9+/_-]*={0,2}$/.test(text)) throw new Error('contentBase64 is not valid base64')
  return Buffer.from(text, 'base64')
}

/** 新建、覆盖或追加；超过 256 KiB 时先写第一段，其余按 append 接上。 */
export async function writeAppFile(send, { name, bytes, append = false }) {
  if (bytes.length > APP_FILE_TRANSFER_MAX) throw new Error(`Writing ${bytes.length} bytes exceeds the plugin transfer limit of ${APP_FILE_TRANSFER_MAX}`)
  let written
  let offset = 0
  do {
    const chunk = bytes.subarray(offset, offset + APP_FILE_WRITE_CHUNK)
    written = await appFilesCommand(send, {
      action: 'write', name: written?.name || name, contentBase64: chunk.toString('base64'), append: offset > 0 || append,
    })
    offset += chunk.length
  } while (offset < bytes.length)
  const verb = append ? 'Appended to' : 'Wrote'
  return { ...written, appended: append, message: `${verb} ${written.path}/${written.name}; it is now ${written.size} bytes. The running app can read it with ctx.files right away.` }
}

export async function deleteAppFile(send, { name }) {
  const removed = await appFilesCommand(send, { action: 'delete', name })
  return { ...removed, message: `Deleted ${removed.path}/${removed.name}.` }
}
