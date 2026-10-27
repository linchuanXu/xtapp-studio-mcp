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
    ? `Studio 预览页没有连上：${reason}`
    : `Studio 没有完成存储卡文件操作：${reason}`)
}

const localPath = (projectDir, path) => (isAbsolute(path) ? path : resolve(projectDir, path))

export async function listAppFiles(send) {
  const listed = await appFilesCommand(send, { action: 'list' })
  const lines = (listed.files || []).map((file) => `${file.name}\t${file.size}${file.visible === false ? '\t（名字不合规则，应用看不到）' : ''}`)
  const head = `${listed.path} · ${listed.files?.length || 0} 个文件 · ${listed.bytes} 字节（预览上限 ${listed.maxBytes}）`
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
    if (part.size > APP_FILE_TRANSFER_MAX) throw new Error(`「${part.name}」有 ${part.size} 字节，超过插件一次搬运的上限 ${APP_FILE_TRANSFER_MAX}`)
    const bytes = Buffer.from(part.contentBase64 || '', 'base64')
    if (!bytes.length && part.end < part.size) throw new Error(`读「${part.name}」时 Studio 回了空片段`)
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
    return { ...base, savedTo: target, message: `已把 ${file.path}/${file.name}（${file.size} 字节）存到 ${target}` }
  }
  const text = utf8Text(file.bytes)
  if (text !== null && file.size <= APP_FILE_INLINE_TEXT_MAX) return { ...base, encoding: 'text', content: text, message: text }
  if (text === null && file.size <= APP_FILE_INLINE_BINARY_MAX) {
    const contentBase64 = file.bytes.toString('base64')
    return { ...base, encoding: 'base64', contentBase64, message: `「${file.name}」${file.size} 字节，不是 UTF-8 文字，base64：\n${contentBase64}` }
  }
  return { ...base, status: 'too_large_inline', message: `「${file.name}」有 ${file.size} 字节，太大不直接回；带 savePath 存到本地再看。` }
}

/** 内容三选一：content（文字，按 UTF-8 存）、contentBase64、sourcePath（本地文件）。 */
export async function appFileBytes({ content, contentBase64, sourcePath, projectDir }) {
  const given = [content, contentBase64, sourcePath].filter((value) => value !== undefined)
  if (given.length !== 1) throw new Error('content、contentBase64、sourcePath 要给且只给一个')
  if (content !== undefined) return Buffer.from(String(content), 'utf8')
  if (sourcePath !== undefined) return readFile(localPath(projectDir, sourcePath))
  const text = String(contentBase64).replace(/\s+/g, '')
  if (!/^[A-Za-z0-9+/_-]*={0,2}$/.test(text)) throw new Error('contentBase64 不是合法的 base64')
  return Buffer.from(text, 'base64')
}

/** 新建、覆盖或追加；超过 256 KiB 时先写第一段，其余按 append 接上。 */
export async function writeAppFile(send, { name, bytes, append = false }) {
  if (bytes.length > APP_FILE_TRANSFER_MAX) throw new Error(`要写 ${bytes.length} 字节，超过插件一次搬运的上限 ${APP_FILE_TRANSFER_MAX}`)
  let written
  let offset = 0
  do {
    const chunk = bytes.subarray(offset, offset + APP_FILE_WRITE_CHUNK)
    written = await appFilesCommand(send, {
      action: 'write', name: written?.name || name, contentBase64: chunk.toString('base64'), append: offset > 0 || append,
    })
    offset += chunk.length
  } while (offset < bytes.length)
  const verb = append ? '已追加到' : '已写入'
  return { ...written, appended: append, message: `${verb} ${written.path}/${written.name}，现在 ${written.size} 字节。正在跑的应用马上能用 ctx.files 读到。` }
}

export async function deleteAppFile(send, { name }) {
  const removed = await appFilesCommand(send, { action: 'delete', name })
  return { ...removed, message: `已删除 ${removed.path}/${removed.name}。` }
}
