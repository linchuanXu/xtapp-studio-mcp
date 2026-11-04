import assert from 'node:assert/strict'
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { parseProjectConfiguration, readProjectSnapshot, snapshotRevision } from './projectSnapshot.mjs'

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
    assert.match(first.warnings.join('\n'), /notes\/list\.json is not a syncable XTApp source path/)
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

test('docs/studio.configuration.json 作为安装前配置声明读出，并参与版本', async () => {
  const root = await mkdtemp(join(tmpdir(), 'xtapp-snapshot-config-'))
  try {
    await mkdir(join(root, 'docs'), { recursive: true })
    await writeFile(join(root, 'manifest.json'), '{"entry":"index.lua"}\n')
    await writeFile(join(root, 'index.lua'), 'local KEY = "__APP_CONFIG_API_KEY__"\n')
    const before = await readProjectSnapshot(root)
    assert.equal(before.configuration, null)
    await writeFile(join(root, 'docs', 'studio.configuration.json'), JSON.stringify({
      configurationFields: [{ key: 'API_KEY', label: '密钥', type: 'secret', required: true, help: '去后台取' }],
      configurationInjections: [{ key: 'API_KEY', file: 'index.lua', marker: '__APP_CONFIG_API_KEY__' }],
    }))
    const after = await readProjectSnapshot(root)
    assert.deepEqual(after.configuration, {
      configurationFields: [{ key: 'API_KEY', label: '密钥', type: 'secret', required: true, help: '去后台取' }],
      configurationInjections: [{ key: 'API_KEY', file: 'index.lua', marker: '__APP_CONFIG_API_KEY__' }],
    })
    assert.equal(after.files['docs/studio.configuration.json'], undefined)
    assert.notEqual(after.revision, before.revision)
    assert.deepEqual(after.warnings, [])
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test('配置声明不合规的项被丢弃并给出提示，secret 不留默认值', () => {
  const { configuration, warnings } = parseProjectConfiguration({
    configurationFields: [
      { key: 'TOKEN', type: 'secret', default: 'sk-leak' },
      { key: 'bad key', label: 'x' },
      { key: 'CITY', label: '城市', type: 'weird', default: 'Shanghai' },
    ],
    configurationInjections: [
      { key: 'TOKEN', file: 'index.lua', marker: '__APP_CONFIG_TOKEN__' },
      { key: 'MISSING', file: 'index.lua', marker: '__X__' },
    ],
  })
  assert.deepEqual(configuration.configurationFields, [
    { key: 'TOKEN', label: 'TOKEN', type: 'secret', required: false },
    { key: 'CITY', label: '城市', type: 'text', required: false, default: 'Shanghai' },
  ])
  assert.deepEqual(configuration.configurationInjections, [{ key: 'TOKEN', file: 'index.lua', marker: '__APP_CONFIG_TOKEN__' }])
  assert.equal(warnings.length, 4)
  assert.match(parseProjectConfiguration('{oops').warnings[0], /not valid JSON/)
  assert.equal(parseProjectConfiguration('{}').configuration, null)
})

test('拒绝相对项目路径', async () => {
  await assert.rejects(() => readProjectSnapshot('./project'), /must be absolute/)
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
