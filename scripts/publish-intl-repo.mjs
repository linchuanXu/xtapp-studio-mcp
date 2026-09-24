import { execFileSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const args = process.argv.slice(2)
function flag(name, fallback = '') {
  const prefix = `--${name}=`
  const hit = args.find((item) => item.startsWith(prefix))
  if (hit) return hit.slice(prefix.length)
  const index = args.indexOf(`--${name}`)
  if (index >= 0 && args[index + 1]) return args[index + 1]
  return fallback
}

const dest = resolve(flag('dest', process.env.XTAPP_INTL_PLUGIN_DIR || join(root, '..', 'xtapp-studio-mcp-intl')))
const studioOrigin = String(flag('studio-origin', process.env.XTAPP_INTL_STUDIO_ORIGIN || '')).trim().replace(/\/$/, '')
const shouldPush = args.includes('--push')
const regionName = String(flag('region', process.env.XTAPP_INTL_REGION || 'intl'))
const intlBase = JSON.parse(readFileSync(join(root, 'regions', `${regionName}.json`), 'utf8'))
if (intlBase.pluginSelector?.split('@')[1] !== intlBase.marketplaceName) {
  throw new Error(`regions/${regionName}.json 自身不一致：pluginSelector 的 marketplace 必须等于 marketplaceName`)
}

if (!studioOrigin) {
  console.warn('publish-intl-repo: studioOrigin is empty; preview will fail until you republish with --studio-origin')
}

const skip = new Set(['.git', 'node_modules'])
if (existsSync(dest)) {
  for (const entry of ['mcp', 'skills', 'knowledge', 'catalog', 'docs', 'scripts', 'widget', '.codex-plugin', '.agents', 'regions']) {
    const path = join(dest, entry)
    if (existsSync(path)) rmSync(path, { recursive: true, force: true })
  }
} else {
  mkdirSync(dest, { recursive: true })
}

cpSync(root, dest, {
  recursive: true,
  filter(source) {
    const relative = source.slice(root.length).replace(/^[\\/]/, '')
    const top = relative.split(/[\\/]/)[0]
    return !skip.has(top)
  },
})

const region = { ...intlBase, studioOrigin }
writeFileSync(join(dest, 'region.json'), `${JSON.stringify(region, null, 2)}\n`)

// region.json 是发行身份的唯一来源：把同一身份同步到 Codex marketplace 与 release-manifest，
// 否则发行仓里会出现“region 说 A、manifest 说 B”，安装校验直接失败。
function rewriteJson(relative, mutate) {
  const file = join(dest, relative)
  if (!existsSync(file)) return
  const value = JSON.parse(readFileSync(file, 'utf8'))
  mutate(value)
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`)
}
rewriteJson('.agents/plugins/marketplace.json', (manifest) => {
  manifest.name = region.marketplaceName
  if (region.marketplaceDisplayName) {
    manifest.interface = { ...manifest.interface, displayName: region.marketplaceDisplayName }
  }
})
rewriteJson('release-manifest.json', (release) => {
  release.repositoryName = region.pluginRepo.split('/').pop()
  release.distributionRepository = region.pluginRepo
  release.marketplace = { ...release.marketplace, name: region.marketplaceName, gitSource: region.githubSource }
  release.plugin = { ...release.plugin, selector: region.pluginSelector }
})

execFileSync('npm', ['ci'], { cwd: dest, stdio: 'inherit' })
execFileSync('npm', ['run', 'build:mcp'], { cwd: dest, stdio: 'inherit' })

if (shouldPush) {
  if (!existsSync(join(dest, '.git'))) {
    execFileSync('git', ['init', '-b', 'main'], { cwd: dest, stdio: 'inherit' })
  }
  try {
    execFileSync('git', ['remote', 'get-url', 'origin'], { cwd: dest, stdio: 'pipe' })
  } catch {
    execFileSync('git', ['remote', 'add', 'origin', `${region.pluginRepo}.git`], { cwd: dest, stdio: 'inherit' })
  }
  execFileSync('git', ['add', '-A'], { cwd: dest, stdio: 'inherit' })
  try {
    execFileSync('git', ['commit', '-m', '✨ 发布：海外 XTApp 插件发行'], { cwd: dest, stdio: 'inherit' })
  } catch (error) {
    const text = `${error.stdout || ''}${error.stderr || ''}${error.message || ''}`
    if (!/nothing to commit/.test(text)) throw error
  }
  execFileSync('git', ['push', '-u', 'origin', 'HEAD:main'], { cwd: dest, stdio: 'inherit' })
}

console.log(JSON.stringify({ dest, region }, null, 2))
