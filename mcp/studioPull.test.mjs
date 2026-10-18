import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { describeStudioAssets, selectPullItems, splitExportBatches, writeExportedItems } from './studioPull.mjs'

const sha = (text) => createHash('sha256').update(text).digest('hex')

test('pull picks Studio-only items and skips differing local files unless overwrite', () => {
  const snapshot = { files: { 'main.lua': 'local', 'same.lua': 's' }, assets: [{ key: 'icon', sha256: 'a' }, { key: 'logo', sha256: 'xic' }] }
  const catalog = {
    files: { 'main.lua': sha('studio'), 'same.lua': sha('s'), 'extra.lua': sha('e') },
    assets: [{ key: 'icon', hash: 'b' }, { key: 'photo', hash: 'p' }, { key: 'logo', hash: 'png', contentHash: 'xic' }],
  }
  assert.deepEqual(selectPullItems({ snapshot, catalog }), {
    paths: ['extra.lua'], keys: ['photo'], skipped: ['main.lua', 'icon'], missing: [],
  })
  assert.deepEqual(selectPullItems({ snapshot, catalog, paths: ['main.lua', 'nope.lua'], overwrite: true }), {
    paths: ['main.lua'], keys: [], skipped: [], missing: ['nope.lua'],
  })
})

test('export batches respect item and byte limits', () => {
  const catalog = { assets: [{ key: 'a', bytes: 6 }, { key: 'b', bytes: 6 }, { key: 'c', bytes: 1 }] }
  assert.deepEqual(splitExportBatches({ paths: ['x.lua'], keys: ['a', 'b', 'c'] }, catalog, { maxItems: 10, maxBytes: 10 }), [
    { paths: ['x.lua'], keys: ['a'] },
    { paths: [], keys: ['b', 'c'] },
  ])
  assert.equal(splitExportBatches({ paths: ['1', '2', '3'] }, {}, { maxItems: 2 }).length, 2)
})

test('exported items land in the worktree and replace same-key images', async () => {
  const root = await mkdtemp(join(tmpdir(), 'xtapp-pull-'))
  try {
    await mkdir(join(root, 'assets'))
    await writeFile(join(root, 'assets/photo.png'), 'old')
    const bytes = Buffer.from([1, 2, 3])
    const written = await writeExportedItems(root, {
      files: { 'ui/view.lua': 'return 1', '../escape.lua': 'x', 'bad.bin': 'x' },
      assets: [{ key: 'photo', base64: bytes.toString('base64') }, { key: '../bad', base64: '' }],
    }, { assets: [{ key: 'photo', path: 'assets/photo.png' }] })
    assert.deepEqual(written, ['ui/view.lua', 'assets/photo.xic'])
    assert.equal(await readFile(join(root, 'ui/view.lua'), 'utf8'), 'return 1')
    assert.deepEqual(await readFile(join(root, 'assets/photo.xic')), bytes)
    await assert.rejects(readFile(join(root, 'assets/photo.png')))
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test('kept and deleted Studio images are reported to the agent', () => {
  assert.equal(describeStudioAssets(), '')
  const text = describeStudioAssets({ keptAssets: ['photo'], deleted: ['bg'], deleteMissing: ['gone'] })
  assert.match(text, /已删除 Studio 里的图：bg/)
  assert.match(text, /未删除：gone/)
  assert.match(text, /已保留：photo/)
  assert.match(text, /deleteAssets/)
})
