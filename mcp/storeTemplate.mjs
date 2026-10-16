import { readdir, readFile, stat } from 'node:fs/promises'
import { join, sep } from 'node:path'

const TEXT_FILE = /\.(lua|json|md|txt|tsv)$/i
const BINARY_FILE = /\.(xic|png|jpe?g|webp)$/i

export const TEMPLATE_GET_NOTE = '以上是文本源码和素材清单（不含二进制内容）。源码可能是 0.8。保留画面层级，调用改成 2.x（manifest.api 写成 2.2、ev.phase、ctx.package:image）。保留 ctx.state（2.2 自动存档）。不要保留 ev.state、ctx.longtask、ctx:save() 或 matte。'
export const TEMPLATE_COPY_NOTE = '公开目录只导出文本源码；缺图片/XIC 素材时需在 Studio 导入。源码可能是 0.8：保留画面层级，调用改成 2.x。保留 ctx.state（2.2 自动存档）。不要保留 ev.state、ctx.longtask、ctx:save() 或 matte。'

function posixRelative(prefix, name) {
  return [prefix, name].filter(Boolean).join('/').split(sep).join('/')
}

export async function readStoreTemplate(dir) {
  const files = {}
  const assets = []
  const walk = async (current, prefix = '') => {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      if (entry.name === '.git' || entry.name === 'node_modules') continue
      const relative = posixRelative(prefix, entry.name)
      const absolute = join(current, entry.name)
      if (entry.isDirectory()) {
        await walk(absolute, relative)
        continue
      }
      const info = await stat(absolute)
      if (BINARY_FILE.test(entry.name) || relative.startsWith('assets/') || relative.startsWith('raw/')) {
        assets.push({ path: relative, bytes: info.size })
        continue
      }
      if (TEXT_FILE.test(entry.name)) files[relative] = await readFile(absolute, 'utf8')
    }
  }
  await walk(dir)
  assets.sort((a, b) => a.path.localeCompare(b.path))
  let api = null
  try { api = JSON.parse(files['manifest.json']).api || null } catch { /* manifest 缺失或损坏时不报 api */ }
  return { dir, files, assets, api }
}
