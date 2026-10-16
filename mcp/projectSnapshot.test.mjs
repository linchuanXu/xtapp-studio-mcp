import assert from 'node:assert/strict'
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { readProjectSnapshot, snapshotRevision } from './projectSnapshot.mjs'

test('只读取允许的 XTApp 文本文件并为内容生成稳定版本', async () => {
  const root = await mkdtemp(join(tmpdir(), 'xtapp-snapshot-'))
  try {
    await mkdir(join(root, 'domain', 'rift'), { recursive: true })
    await mkdir(join(root, 'assets'))
    await mkdir(join(root, 'notes'))
    await writeFile(join(root, 'manifest.json'), '{"entry":"index.lua"}\n')
    await writeFile(join(root, 'index.lua'), 'function on_draw() end\n')
    await writeFile(join(root, 'domain', 'rift', 'state.lua'), 'return {}\n')
    await writeFile(join(root, 'notes', 'todo.lua'), 'return {}\n')
    await writeFile(join(root, 'notes', 'list.json'), '[]\n')
    await writeFile(join(root, 'assets', 'hero.xic'), 'binary')
    await writeFile(join(root, 'assets', 'icon.png'), 'png-bytes')
    const first = await readProjectSnapshot(root)
    assert.deepEqual(Object.keys(first.files).sort(), ['domain/rift/state.lua', 'index.lua', 'manifest.json', 'notes/todo.lua'])
    assert.match(first.warnings.join('\n'), /notes\/list\.json 不是可同步的 XTApp 源码路径/)
    assert.equal(first.manifest.entry, 'index.lua')
    assert.equal(first.assetCount, 2)
    assert.deepEqual(first.assets.map((item) => `${item.key}:${item.mime}`).sort(), [
      'hero:application/x-xic',
      'icon:image/png',
    ])
    assert.equal(first.assets.find((item) => item.key === 'hero').base64, Buffer.from('binary').toString('base64'))
    assert.equal(first.assets.find((item) => item.key === 'icon').bytes, 9)
    assert.equal(first.warnings.length, 1)
    assert.equal(first.revision, snapshotRevision(first.files, first.assets))
    await writeFile(join(root, 'index.lua'), 'function on_draw(ctx, g) g:clear(0) end\n')
    const second = await readProjectSnapshot(root)
    assert.notEqual(second.revision, first.revision)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test('磁盘绑定只作为 sidecar 读出，不会把整个 docs/ 当源码同步', async () => {
  const root = await mkdtemp(join(tmpdir(), 'xtapp-snapshot-bind-'))
  try {
    await mkdir(join(root, 'docs'), { recursive: true })
    await writeFile(join(root, 'manifest.json'), '{"entry":"index.lua"}\n')
    await writeFile(join(root, 'index.lua'), 'function on_draw() end\n')
    await writeFile(join(root, 'docs', 'notes.md'), '# notes\n')
    await writeFile(join(root, 'docs', 'studio.cloud.json'), '{"cloudProjectId":"9e97728c-1111-4111-8111-aaaaaaaaaaaa"}\n')
    const snapshot = await readProjectSnapshot(root)
    assert.equal(snapshot.cloudProjectId, '9e97728c-1111-4111-8111-aaaaaaaaaaaa')
    assert.equal(snapshot.files['docs/studio.cloud.json'], undefined)
    assert.equal(snapshot.files['docs/notes.md'], undefined)
    assert.deepEqual(Object.keys(snapshot.files).sort(), ['index.lua', 'manifest.json'])
    assert.equal(snapshot.revision, snapshotRevision(snapshot.files, snapshot.assets, snapshot.cloudProjectId))
    assert.notEqual(snapshot.revision, snapshotRevision(snapshot.files, snapshot.assets))
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test('拒绝相对项目路径', async () => {
  await assert.rejects(() => readProjectSnapshot('./project'), /绝对路径/)
})

test('采集超过 80 个素材时仍全部进入快照', async () => {
  const root = await mkdtemp(join(tmpdir(), 'xtapp-snapshot-many-'))
  try {
    await mkdir(join(root, 'assets'))
    await writeFile(join(root, 'manifest.json'), '{"entry":"index.lua"}\n')
    await writeFile(join(root, 'index.lua'), 'function on_draw() end\n')
    await Promise.all(Array.from({ length: 81 }, (_, index) => (
      writeFile(join(root, 'assets', `n${index}.xic`), `xic-${index}`)
    )))
    const snapshot = await readProjectSnapshot(root)
    assert.equal(snapshot.assetCount, 81)
    assert.equal(snapshot.warnings.length, 0)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
