import { readdir, readFile, stat } from 'node:fs/promises'
import { join, sep } from 'node:path'

const TEXT_FILE = /\.(lua|json|md|txt|tsv)$/i
const BINARY_FILE = /\.(xic|png|jpe?g|webp)$/i

export const TEMPLATE_GET_NOTE = 'Above are the text sources and the asset inventory (no binary contents). The templates are API 2.x source; build on them directly and keep manifest.api at the newest 2.x.'
export const TEMPLATE_COPY_NOTE = 'The public catalog exports text sources only; import missing image/XIC assets in Studio. The templates are API 2.x source; keep manifest.api at the newest 2.x.'

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
