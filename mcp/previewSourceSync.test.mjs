import assert from 'node:assert/strict'
import test from 'node:test'
import { snapshotRevision } from './projectSnapshot.mjs'
import {
  diffSnapshots,
  pushProjectSnapshot,
  snapshotPushState,
  sourcePushBodies,
  splitAssetBatches,
  splitFileBatches,
  withProjectPushLock,
} from './previewSourceSync.mjs'

function asset(index, bytes = 10) {
  return {
    path: `assets/n${index}.xic`,
    key: `n${index}`,
    mime: 'application/x-xic',
    bytes,
    sha256: `hash-${index}`,
    base64: 'WElDAA==',
  }
}

test('素材按 80 个和体积切批，单张超大也独占一批', () => {
  const many = Array.from({ length: 81 }, (_, index) => asset(index))
  const [first, second] = splitAssetBatches(many)
  assert.equal(first.length, 80)
  assert.equal(second.length, 1)
  assert.equal(second[0].key, 'n80')

  const heavy = [asset(1, 5 * 1024 * 1024), asset(2, 10)]
  const batches = splitAssetBatches(heavy)
  assert.equal(batches.length, 2)
  assert.deepEqual(batches[0].map((item) => item.key), ['n1'])
  assert.deepEqual(batches[1].map((item) => item.key), ['n2'])
})

test('文本文件按条数和体积切批', () => {
  const files = Object.fromEntries(Array.from({ length: 201 }, (_, index) => [`n${index}.lua`, 'ok']))
  const [first, second] = splitFileBatches(files)
  assert.equal(Object.keys(first).length, 200)
  assert.equal(Object.keys(second).length, 1)
})

test('首包带上磁盘绑定的 cloudProjectId，但不把 docs/ 当源码', () => {
  const files = { 'manifest.json': '{}', 'index.lua': 'function on_draw() end' }
  const bodies = sourcePushBodies({
    files,
    assets: [],
    fileCount: 2,
    assetCount: 0,
    warnings: [],
    projectDir: '/tmp/demo',
    cloudProjectId: '9e97728c-1111-4111-8111-aaaaaaaaaaaa',
  })
  assert.equal(bodies[0].cloudProjectId, '9e97728c-1111-4111-8111-aaaaaaaaaaaa')
  assert.equal(bodies[0].files['docs/studio.cloud.json'], undefined)
  assert.equal(bodies[0].revision, snapshotRevision(files, [], '9e97728c-1111-4111-8111-aaaaaaaaaaaa'))
})

test('首包 POST 全量文件，后续 PATCH 只补素材并带完整清单', () => {
  const files = { 'manifest.json': '{}', 'index.lua': 'function on_draw() end' }
  const assets = Array.from({ length: 81 }, (_, index) => asset(index))
  const bodies = sourcePushBodies({
    files,
    assets,
    fileCount: 2,
    assetCount: 81,
    warnings: [],
    projectDir: '/tmp/demo',
  })
  assert.equal(bodies.length, 2)
  assert.deepEqual(Object.keys(bodies[0].files).sort(), ['index.lua', 'manifest.json'])
  assert.equal(bodies[0].assets.length, 80)
  assert.equal(bodies[0].assetKeys.length, 81)
  assert.deepEqual(bodies[0].fileKeys.sort(), ['index.lua', 'manifest.json'])
  assert.equal(bodies[0].revision, snapshotRevision(files, bodies[0].assets))
  assert.equal(bodies[0].cloudProjectId, undefined)
  assert.deepEqual(bodies[1].files, {})
  assert.equal(bodies[1].assets.length, 1)
  assert.deepEqual(bodies[1].assetKeys, bodies[0].assetKeys)
  assert.deepEqual(bodies[1].fileKeys, bodies[0].fileKeys)
})

test('pushProjectSnapshot 先覆盖再按 revision 合并，不把 80 当成工程上限', async () => {
  const files = { 'index.lua': 'ok' }
  const assets = Array.from({ length: 81 }, (_, index) => asset(index))
  const calls = []
  const result = await pushProjectSnapshot({
    files,
    assets,
    fileCount: 1,
    assetCount: 81,
    assetBytes: 810,
    warnings: ['note'],
    projectDir: '/tmp/demo',
  }, async (path, body) => {
    calls.push({ path, body })
    if (path === '/preview/source') return { status: 'queued', revision: 'rev-1', assetCount: body.assets.length }
    return { status: 'queued', revision: 'rev-2', assetCount: 81, warnings: [] }
  })
  assert.equal(calls[0].path, '/preview/source')
  assert.equal(calls[1].path, '/preview/source/patch')
  assert.equal(calls[1].body.baseRevision, 'rev-1')
  assert.equal(calls[1].body.assets[0].key, 'n80')
  assert.equal(result.revision, 'rev-2')
  assert.equal(result.assetCount, 81)
  assert.equal(result.projectDir, '/tmp/demo')
  assert.deepEqual(result.warnings, ['note'])
})

test('revision 未变则跳过 HTTP', async () => {
  let called = 0
  const snapshot = {
    revision: 'abc',
    files: { 'index.lua': 'ok' },
    assets: [],
    projectDir: '/tmp/unchanged',
    fileCount: 1,
    assetCount: 0,
    warnings: [],
  }
  const result = await pushProjectSnapshot(snapshot, async () => {
    called += 1
    return { status: 'queued', revision: 'should-not' }
  }, {
    previous: { revision: 'abc', serverRevision: 'on-server', files: snapshot.files, assetHashes: {} },
  })
  assert.equal(called, 0)
  assert.equal(result.status, 'unchanged')
  assert.equal(result.revision, 'on-server')
})

test('有上次成功快照时只 PATCH 变更', async () => {
  const previous = snapshotPushState({
    revision: 'r1',
    files: { 'index.lua': 'v1', 'gone.lua': 'x' },
    assets: [{ key: 'bg', sha256: 'old' }, { key: 'drop', sha256: 'd' }],
  }, 'server-1')
  const snapshot = {
    revision: 'r2',
    files: { 'index.lua': 'v2', 'extra.lua': 'y' },
    assets: [{ key: 'bg', sha256: 'new', path: 'assets/bg.xic', bytes: 4, base64: 'WElDAA==' }],
    fileCount: 2,
    assetCount: 1,
    warnings: [],
    projectDir: '/tmp/demo-inc',
  }
  const calls = []
  const result = await pushProjectSnapshot(snapshot, async (path, body) => {
    calls.push({ path, body })
    return { status: 'queued', revision: 'server-2' }
  }, { previous })
  assert.equal(calls.length, 1)
  assert.equal(calls[0].path, '/preview/source/patch')
  assert.equal(calls[0].body.baseRevision, 'server-1')
  assert.deepEqual(calls[0].body.files, { 'index.lua': 'v2', 'extra.lua': 'y' })
  assert.deepEqual(calls[0].body.deleteFiles, ['gone.lua'])
  assert.deepEqual(calls[0].body.deleteAssets, ['drop'])
  assert.equal(calls[0].body.assets[0].key, 'bg')
  assert.deepEqual(calls[0].body.assetKeys, ['bg'])
  assert.deepEqual(calls[0].body.fileKeys.sort(), ['extra.lua', 'index.lua'])
  assert.equal(result.revision, 'server-2')
})

test('PATCH 修订冲突时回退全量 POST', async () => {
  const previous = snapshotPushState({
    revision: 'old',
    files: { 'index.lua': 'v1' },
    assets: [],
  }, 'server-old')
  const snapshot = {
    revision: 'new',
    files: { 'index.lua': 'v2' },
    assets: [],
    fileCount: 1,
    assetCount: 0,
    warnings: [],
    projectDir: '/tmp/demo-conflict',
  }
  const calls = []
  const result = await pushProjectSnapshot(snapshot, async (path) => {
    calls.push(path)
    if (path === '/preview/source/patch') {
      const error = new Error('修订冲突')
      error.code = 'REVISION_CONFLICT'
      throw error
    }
    return { status: 'queued', revision: 'rev-full' }
  }, { previous })
  assert.deepEqual(calls, ['/preview/source/patch', '/preview/source'])
  assert.equal(result.revision, 'rev-full')
})

test('diff 只报告变化的文件和素材', () => {
  const diff = diffSnapshots(
    {
      files: { 'index.lua': 'v1', 'keep.lua': 'same' },
      assetHashes: { bg: 'old', keep: 'same' },
    },
    {
      files: { 'index.lua': 'v2', 'keep.lua': 'same', 'new.lua': 'n' },
      assets: [{ key: 'bg', sha256: 'new' }, { key: 'keep', sha256: 'same' }],
    },
  )
  assert.deepEqual(diff.files, { 'index.lua': 'v2', 'new.lua': 'n' })
  assert.deepEqual(diff.deleteFiles, [])
  assert.deepEqual(diff.assets.map((item) => item.key), ['bg'])
  assert.deepEqual(diff.deleteAssets, [])
})

test('同一工程的推送串行执行', async () => {
  const order = []
  await Promise.all([
    withProjectPushLock('/tmp/lock-a', async () => {
      order.push('a1')
      await new Promise((resolve) => setTimeout(resolve, 20))
      order.push('a2')
    }),
    withProjectPushLock('/tmp/lock-a', async () => {
      order.push('b1')
      order.push('b2')
    }),
  ])
  assert.deepEqual(order, ['a1', 'a2', 'b1', 'b2'])
})
