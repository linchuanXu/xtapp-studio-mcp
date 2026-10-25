import assert from 'node:assert/strict'
import { mkdtemp, readFile, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { loadOrCreatePreviewSession, previewRunPath, previewSessionFileForProject } from './previewSession.mjs'

test('预览 session 落盘后跨进程复用同一 id', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'xtapp-preview-session-'))
  const file = join(dir, 'session')
  const first = await loadOrCreatePreviewSession(file)
  const second = await loadOrCreatePreviewSession(file)
  assert.match(first, /^[0-9a-f-]{36}$/i)
  assert.equal(second, first)
  assert.equal((await readFile(file, 'utf8')).trim(), first)
})

test('损坏的 session 文件会换成新的合法 id', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'xtapp-preview-session-'))
  const file = join(dir, 'session')
  await writeFile(file, '??\n', 'utf8')
  const next = await loadOrCreatePreviewSession(file)
  assert.match(next, /^[A-Za-z0-9:_-]{8,160}$/)
  assert.notEqual(next, '??')
})

test('已停止或出错时 run 改走 restart', () => {
  assert.equal(previewRunPath('stopped'), '/preview/restart')
  assert.equal(previewRunPath('error'), '/preview/restart')
  assert.equal(previewRunPath('running'), '/preview/run')
  assert.equal(previewRunPath('ready'), '/preview/run')
  assert.equal(previewRunPath('not_connected'), '/preview/run')
})

test('不同工程目录用不同 session 文件，同一目录稳定复用', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'xtapp-preview-projects-'))
  process.env.XTAPP_PREVIEW_SESSION_FILE = join(dir, 'default')
  try {
    const a = await previewSessionFileForProject(join(dir, 'game-a'))
    const b = await previewSessionFileForProject(join(dir, 'game-b'))
    assert.notEqual(a, b)
    assert.equal(await previewSessionFileForProject(join(dir, 'game-a')), a)
    assert.notEqual(await loadOrCreatePreviewSession(a), await loadOrCreatePreviewSession(b))
  } finally {
    delete process.env.XTAPP_PREVIEW_SESSION_FILE
  }
})
