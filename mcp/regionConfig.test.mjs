import assert from 'node:assert/strict'
import { mkdtemp, writeFile } from 'node:fs/promises'
import { readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'
import { loadPluginRegion, resolveStudioOrigin } from './regionConfig.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

// 这条测试会随发行一起发布到国内/国外各一份，所以只能断言“任何发行都成立”的身份规则，
// 不能写死某一个区的取值（上一版写死 cn，导致国外发行仓里它一直是红的）。
test('region.json carries a complete identity for this distribution', () => {
  const region = loadPluginRegion()
  assert.match(region.id, /^(?:cn|intl)$/)
  assert.match(region.githubSource, /^[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/)
  assert.equal(region.pluginSelector.split('@')[1], region.marketplaceName)
  assert.equal(region.pluginSelector.split('@')[0], 'xtapp-studio-mcp')
  // 国内发行必须带可用的 Studio 源；国外发行的源由环境变量注入。
  if (region.id === 'cn') assert.match(resolveStudioOrigin({ env: {}, region }), /^https:\/\//)
})

// region.json 是发行身份的唯一来源：Codex marketplace 与 release-manifest 必须与它一致
// （AGENTS.md 的安装校验就依赖这一点）。
test('marketplace and release manifests carry the same identity as region.json', () => {
  const region = loadPluginRegion()
  const marketplace = JSON.parse(readFileSync(join(root, '.agents/plugins/marketplace.json'), 'utf8'))
  assert.equal(marketplace.name, region.marketplaceName)
  assert.equal(marketplace.plugins[0].name, region.pluginSelector.split('@')[0])
  const release = JSON.parse(readFileSync(join(root, 'release-manifest.json'), 'utf8'))
  assert.equal(release.marketplace.name, region.marketplaceName)
  assert.equal(release.marketplace.gitSource, region.githubSource)
  assert.equal(release.plugin.selector, region.pluginSelector)
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
