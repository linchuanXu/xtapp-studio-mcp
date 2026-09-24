import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { delimiter, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

// 维护者车道：只在用户要求刷新/校验知识时运行，源目录一律由本机环境变量提供，
// 仓库内不写任何 checkout 路径。
//
//   XTAPP_CONTRACT_DIR         公司内部契约仓的根目录（可选，取其中固定的 7 个文件）
//   XTAPP_PUBLIC_KNOWLEDGE_DIR Studio 侧公开知识根目录，可用路径分隔符列多个（POSIX 为 ":"）；
//                              正文在 content/knowledge/generated/documents/，资产在 content/knowledge/public/
//
//   node scripts/sync-knowledge.mjs            重新生成 knowledge/index.json
//   node scripts/sync-knowledge.mjs --check    只校验已提交的索引是否与源一致（无源时跳过并说明）
const root = resolve(fileURLToPath(new URL('..', import.meta.url)))
const check = process.argv.includes('--check')
const contractDir = process.env.XTAPP_CONTRACT_DIR ? resolve(process.env.XTAPP_CONTRACT_DIR) : null
const knowledgeDirs = String(process.env.XTAPP_PUBLIC_KNOWLEDGE_DIR || '')
  .split(delimiter)
  .map((item) => item.trim())
  .filter(Boolean)
  .map((item) => resolve(item))
const configuredRoots = [...(contractDir ? [contractDir] : []), ...knowledgeDirs]
const sources = [
  ...(contractDir ? [
    join(contractDir, 'SPEC.md'), join(contractDir, 'README.md'), join(contractDir, 'api', 'runtime.md'),
    join(contractDir, 'api', 'input.md'), join(contractDir, 'api', 'graphics.md'), join(contractDir, 'api', 'ui-components.md'),
    join(contractDir, 'api', 'manifest.md'),
  ] : []),
  ...knowledgeDirs,
]

if (!check && configuredRoots.length === 0) {
  console.error('缺少知识源：请通过 XTAPP_CONTRACT_DIR / XTAPP_PUBLIC_KNOWLEDGE_DIR 指定本机目录后再生成索引。')
  process.exit(1)
}
if (check && configuredRoots.length === 0) {
  console.log('跳过知识索引新鲜度检查：未提供 XTAPP_CONTRACT_DIR / XTAPP_PUBLIC_KNOWLEDGE_DIR。')
  process.exit(0)
}
const missingRoots = configuredRoots.filter((item) => !existsSync(item))
if (missingRoots.length) {
  console.error(`知识源不存在，拒绝在缺输入的情况下生成索引：${missingRoots.join('、')}`)
  process.exit(1)
}
const studioPreviewKnowledge = join(root, 'knowledge', 'studio-preview.md')
const files = []

async function visit(path) {
  if (!existsSync(path)) return
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const child = join(path, entry.name)
    if (entry.isDirectory()) await visit(child)
    else if (/\.(md|jsonc?|lua)$/i.test(entry.name)) files.push(child)
  }
}

for (const source of sources) {
  if (knowledgeDirs.includes(source)) await visit(source)
  else if (existsSync(source)) files.push(source)
}

function topicFor(source, content) {
  const value = source.toLowerCase()
  if (value.includes('/input')) return 'input'
  if (value.includes('/graphics')) return 'graphics'
  if (value.includes('/runtime')) return 'runtime'
  if (value.includes('/manifest')) return 'manifest'
  if (value.includes('ui-components')) return 'ui'
  if (value.includes('studio-preview')) return 'studio-preview'
  if (value.includes('/assets')) return 'assets'
  if (value.includes('/network')) return 'network'
  if (/on_input|ctx\.input|semantic key/i.test(content)) return 'input'
  if (/g:(?:clear|line|rect|circle|text|image|layer)/i.test(content)) return 'graphics'
  return 'overview'
}

function apiFor(content, topic) {
  const patterns = {
    input: /\b(on_input|ctx\.input(?:\.caps)?|normalizeXtappInput)\b/i,
    graphics: /\b(g:(?:clear|line|rect|circle|text|image|layer|size))\b/i,
    runtime: /\b(ctx\.(?:state|screen|sys|longtask|perf)|on_(?:load|enter|tick|draw|leave|unload))\b/i,
    manifest: /\b(manifest(?:\.json)?|app_id|display\.orientation)\b/i,
    network: /\b(ctx\.net:(?:get|post|poll|cancel))\b/i,
    'studio-preview': /\b(?:run_xtapp_preview|preview bridge|Lua Worker|SSE)\b/i,
  }
  return patterns[topic]?.exec(content)?.[1] || null
}

function versionFor(content, source) {
  const match = content.match(/(?:契约版本|contract version|API version|apiVersion|version)\D{0,20}(\d+\.\d+)/i)
  if (match) return match[1]
  if (source.startsWith('contract/')) return '1.0'
  if (source.startsWith('studio/')) return '0.1'
  return '0.8'
}

function publicPath(path, contractDir, knowledgeDirs) {
  if (contractDir && (path === contractDir || path.startsWith(`${contractDir}/`))) return `contract/${path.slice(contractDir.length + 1)}`
  for (const dir of knowledgeDirs) {
    if (path === dir || path.startsWith(`${dir}/`)) return path.slice(dir.length + 1)
  }
  return path.split(/[/\\]/).slice(-2).join('/')
}

function exampleFor(content) {
  const match = content.match(/```(?:lua|json|javascript|js)?\s*\n([\s\S]*?)```/i)
  return match?.[1]?.trim().slice(0, 2400) || null
}

const entries = []
for (const path of files.sort()) {
  const content = await readFile(path, 'utf8')
  const sourcePath = publicPath(path, contractDir, knowledgeDirs)
  const source = sourcePath.startsWith('contract/') ? 'public-contract' : 'xtapp-studio'
  const topic = topicFor(sourcePath, content)
  entries.push({ topic, api: apiFor(content, topic), version: versionFor(content, sourcePath), source, sourcePath, content, example: exampleFor(content) })
}
if (existsSync(studioPreviewKnowledge)) {
  const content = await readFile(studioPreviewKnowledge, 'utf8')
  entries.push({ topic: 'studio-preview', api: apiFor(content, 'studio-preview'), version: '0.1', source: 'xtapp-studio', sourcePath: 'studio/preview.md', content, example: exampleFor(content) })
}

const hash = createHash('sha256').update(entries.map((entry) => `${entry.source}\0${entry.sourcePath}\0${entry.content}`).join('\0')).digest('hex')
const outputPath = join(root, 'knowledge', 'index.json')

if (check) {
  const previous = JSON.parse(await readFile(outputPath, 'utf8').catch(() => '{"entries":[]}'))
  if (previous.sourceHash !== hash) {
    // 报告差异，便于定位是哪些知识没同步。
    const before = new Map((previous.entries || []).map((entry) => [entry.sourcePath, entry.content]))
    const after = new Map(entries.map((entry) => [entry.sourcePath, entry.content]))
    const added = [...after.keys()].filter((key) => !before.has(key))
    const removed = [...before.keys()].filter((key) => !after.has(key))
    const changed = [...after.keys()].filter((key) => before.has(key) && before.get(key) !== after.get(key))
    const brief = (list) => (list.length ? list.slice(0, 8).join('、') + (list.length > 8 ? ` 等 ${list.length} 项` : '') : '无')
    console.error('知识索引已过期，请在有源目录的机器上运行 npm run sync:knowledge：')
    console.error(`  新增：${brief(added)}`)
    console.error(`  删除：${brief(removed)}`)
    console.error(`  改动：${brief(changed)}`)
    process.exit(1)
  }
  console.log(`知识索引是最新的：${entries.length} 条（${hash.slice(0, 12)}）。`)
  process.exit(0)
}

await mkdir(join(root, 'knowledge'), { recursive: true })
let generatedAt = new Date().toISOString()
if (existsSync(outputPath)) {
  try {
    const previous = JSON.parse(await readFile(outputPath, 'utf8'))
    if (previous.sourceHash === hash && typeof previous.generatedAt === 'string') generatedAt = previous.generatedAt
  } catch { /* rebuild malformed or legacy indexes */ }
}
await writeFile(outputPath, JSON.stringify({ schemaVersion: 2, generatedAt, sourceHash: hash, entries }, null, 2) + '\n')
console.log(`Generated ${entries.length} public knowledge entries (${hash.slice(0, 12)}).`)
