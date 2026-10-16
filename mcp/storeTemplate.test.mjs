import assert from 'node:assert/strict'
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { readStoreTemplate, TEMPLATE_GET_NOTE } from './storeTemplate.mjs'

test('get 模板列出素材路径但不内联二进制', async () => {
  const root = await mkdtemp(join(tmpdir(), 'xtapp-template-'))
  try {
    await mkdir(join(root, 'assets'))
    await writeFile(join(root, 'manifest.json'), '{"entry":"index.lua"}\n')
    await writeFile(join(root, 'index.lua'), 'function on_draw() end\n')
    await writeFile(join(root, 'assets', 'hero.xic'), 'binary-xic')
    const template = await readStoreTemplate(root)
    assert.equal(template.files['index.lua'], 'function on_draw() end\n')
    assert.equal(template.files['assets/hero.xic'], undefined)
    assert.deepEqual(template.assets, [{ path: 'assets/hero.xic', bytes: 10 }])
    assert.match(TEMPLATE_GET_NOTE, /0\.8.*2\.x/)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
