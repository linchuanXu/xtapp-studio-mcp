import assert from 'node:assert/strict'
import { mkdtemp, readFile, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import {
  APP_FILE_READ_CHUNK,
  APP_FILE_WRITE_CHUNK,
  appFileBytes,
  deleteAppFile,
  listAppFiles,
  readAppFile,
  writeAppFile,
} from './appFiles.mjs'

// 假 Studio：同 codexAppFiles.js 的回报形状，文件名不分大小写。
function fakeStudio(initial = {}) {
  const folder = new Map(Object.entries(initial).map(([name, text]) => [name, Buffer.from(text)]))
  const calls = []
  const where = { appId: 'demo', path: '/AppFiles/demo' }
  const key = (name) => [...folder.keys()].find((stored) => stored.toLowerCase() === String(name).toLowerCase())
  const send = async (body) => {
    calls.push(body)
    const done = (appFiles) => ({ status: 'complete', appFiles: { ...where, ...appFiles } })
    if (body.action === 'list') {
      const files = [...folder].map(([name, data]) => ({ name, size: data.length, visible: true }))
      return done({ files, bytes: files.reduce((sum, file) => sum + file.size, 0), maxBytes: 64 * 1024 * 1024 })
    }
    const stored = key(body.name)
    if (body.action === 'read') {
      if (!stored) return { status: 'error', message: `没有「${body.name}」` }
      const data = folder.get(stored)
      const end = Math.min(data.length, body.offset + body.length)
      return done({ name: stored, size: data.length, offset: body.offset, end, contentBase64: data.subarray(body.offset, end).toString('base64') })
    }
    if (body.action === 'write') {
      const chunk = Buffer.from(body.contentBase64, 'base64')
      const next = body.append && stored ? Buffer.concat([folder.get(stored), chunk]) : chunk
      if (stored) folder.delete(stored)
      const name = body.append && stored ? stored : body.name
      folder.set(name, next)
      return done({ name, size: next.length, created: !stored })
    }
    if (!stored) return { status: 'error', message: `没有「${body.name}」` }
    folder.delete(stored)
    return done({ name: stored })
  }
  return { folder, calls, send }
}

test('列出存储卡文件夹，带路径和字节数', async () => {
  const studio = fakeStudio({ 'save.json': '{"hp":3}' })
  const listed = await listAppFiles(studio.send)
  assert.deepEqual(listed.files.map((file) => file.name), ['save.json'])
  assert.match(listed.message, /\/AppFiles\/demo · 1 个文件/)
  assert.match(listed.message, /save\.json\t8/)
})

test('读文字文件直接回文字，名字不分大小写', async () => {
  const studio = fakeStudio({ 'Character.lua': 'return { name = "像素人" }' })
  const read = await readAppFile(studio.send, { name: 'character.lua' })
  assert.equal(read.name, 'Character.lua')
  assert.equal(read.encoding, 'text')
  assert.equal(read.content, 'return { name = "像素人" }')
})

test('大文件分段读完，并原样存到本地', async () => {
  const big = 'x'.repeat(APP_FILE_READ_CHUNK + 10)
  const studio = fakeStudio({ 'big.txt': big })
  const dir = await mkdtemp(join(tmpdir(), 'appfiles-'))
  const read = await readAppFile(studio.send, { name: 'big.txt', savePath: 'out/big.txt', projectDir: dir })
  assert.equal(studio.calls.filter((call) => call.action === 'read').length, 2)
  assert.equal(read.savedTo, join(dir, 'out/big.txt'))
  assert.equal(await readFile(read.savedTo, 'utf8'), big)
})

test('不带 savePath 时太大的文件不直接回', async () => {
  const studio = fakeStudio({ 'big.txt': 'y'.repeat(300 * 1024) })
  const read = await readAppFile(studio.send, { name: 'big.txt' })
  assert.equal(read.status, 'too_large_inline')
  assert.equal(read.content, undefined)
  assert.match(read.message, /savePath/)
})

test('写入超过一段时先覆盖再追加，结果同一份文件', async () => {
  const studio = fakeStudio({ 'DATA.bin': 'old' })
  const bytes = Buffer.alloc(APP_FILE_WRITE_CHUNK * 2 + 5, 7)
  const written = await writeAppFile(studio.send, { name: 'data.bin', bytes })
  const writes = studio.calls.filter((call) => call.action === 'write')
  assert.deepEqual(writes.map((call) => call.append), [false, true, true])
  assert.equal(written.size, bytes.length)
  assert.equal(studio.folder.size, 1)
  assert.deepEqual(studio.folder.get('data.bin'), bytes)
})

test('append 接在原文件后面', async () => {
  const studio = fakeStudio({ 'log.txt': 'a\n' })
  const written = await writeAppFile(studio.send, { name: 'log.txt', bytes: Buffer.from('b\n'), append: true })
  assert.equal(written.size, 4)
  assert.equal(studio.folder.get('log.txt').toString(), 'a\nb\n')
  assert.match(written.message, /已追加到/)
})

test('写入内容三选一：文字、base64 或本地文件', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'appfiles-'))
  await writeFile(join(dir, 'seed.json'), '{"lv":2}')
  assert.equal((await appFileBytes({ content: '你好' })).toString(), '你好')
  assert.equal((await appFileBytes({ contentBase64: Buffer.from('hi').toString('base64') })).toString(), 'hi')
  assert.equal((await appFileBytes({ sourcePath: 'seed.json', projectDir: dir })).toString(), '{"lv":2}')
  await assert.rejects(appFileBytes({}), /只给一个/)
  await assert.rejects(appFileBytes({ content: 'a', contentBase64: 'YQ==' }), /只给一个/)
  await assert.rejects(appFileBytes({ contentBase64: '不是base64' }), /不是合法的 base64/)
})

test('删除文件；Studio 报错或没连上时抛出原因', async () => {
  const studio = fakeStudio({ 'a.txt': '1' })
  const removed = await deleteAppFile(studio.send, { name: 'A.TXT' })
  assert.equal(removed.name, 'a.txt')
  assert.equal(studio.folder.size, 0)
  await assert.rejects(deleteAppFile(studio.send, { name: 'a.txt' }), /没有完成存储卡文件操作：没有「a\.txt」/)
  await assert.rejects(listAppFiles(async () => ({ status: 'not_connected', message: '预览页未打开' })), /没有连上：预览页未打开/)
})
