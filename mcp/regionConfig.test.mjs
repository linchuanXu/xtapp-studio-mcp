import assert from 'node:assert/strict'
import { mkdtemp, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { loadPluginRegion, resolveStudioOrigin } from './regionConfig.mjs'

test('CN region.json has a Studio origin and the China GitHub source', () => {
  const region = loadPluginRegion()
  assert.equal(region.id, 'cn')
  assert.equal(region.studioOrigin, 'https://xtapp-ai-dev.xteink.cn')
  assert.equal(region.githubSource, 'linchuanXu/xtapp-studio-mcp')
  assert.equal(resolveStudioOrigin({ env: {}, region }), 'https://xtapp-ai-dev.xteink.cn')
})

test('env XTAPP_STUDIO_CONTROL_URL overrides region.json', () => {
  assert.equal(
    resolveStudioOrigin({
      env: { XTAPP_STUDIO_CONTROL_URL: 'https://studio.example/' },
      region: { studioOrigin: 'https://xtapp-ai-dev.xteink.cn' },
    }),
    'https://studio.example',
  )
})

test('empty region origin without env is an error', () => {
  assert.throws(
    () => resolveStudioOrigin({ env: {}, region: { studioOrigin: '' } }),
    /studioOrigin is empty/,
  )
})

test('intl overlay keeps a distinct GitHub source', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'xtapp-region-'))
  const path = join(dir, 'region.json')
  await writeFile(path, JSON.stringify({
    id: 'intl',
    studioOrigin: 'https://studio.example',
    githubSource: 'linchuanXu/xtapp-studio-mcp-intl',
  }))
  const region = loadPluginRegion(path)
  assert.equal(region.githubSource, 'linchuanXu/xtapp-studio-mcp-intl')
  assert.equal(resolveStudioOrigin({ env: {}, region }), 'https://studio.example')
})
