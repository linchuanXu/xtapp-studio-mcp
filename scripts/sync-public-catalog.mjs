import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(fileURLToPath(new URL('..', import.meta.url)))
const catalogSource = process.env.XTAPP_CATALOG_SOURCE_DIR
if (!catalogSource) throw new Error('XTAPP_CATALOG_SOURCE_DIR must point to a local catalog source')
const sourceRoot = resolve(catalogSource)
const outputRoot = join(root, 'catalog')
const templateRoot = join(outputRoot, 'templates')
const apps = []
const textExtensions = /\.(lua|json|md|txt|tsv)$/i
async function exportTextFiles(sourceDir, targetDir, prefix = '') {
  for (const entry of await readdir(sourceDir, { withFileTypes: true })) {
    const relative = join(prefix, entry.name)
    const source = join(sourceDir, entry.name)
    const target = join(targetDir, relative)
    if (entry.isDirectory()) {
      if (entry.name === 'assets' || entry.name === 'raw') continue
      await exportTextFiles(source, targetDir, relative)
    } else if (textExtensions.test(entry.name)) {
      await mkdir(join(targetDir, prefix), { recursive: true })
      await writeFile(target, await readFile(source, 'utf8'))
    }
  }
}
for (const entry of await readdir(sourceRoot, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue
  const sourceDir = join(sourceRoot, entry.name)
  const manifestPath = join(sourceDir, 'manifest.json')
  if (!existsSync(manifestPath)) continue
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
  apps.push({ id: entry.name, appId: manifest.app_id || entry.name, name: manifest.display_name || manifest.name || entry.name, version: manifest.version || null, api: manifest.api || null })
  await exportTextFiles(sourceDir, join(templateRoot, entry.name))
}
await mkdir(outputRoot, { recursive: true })
await writeFile(join(outputRoot, 'index.json'), JSON.stringify(apps.sort((a, b) => a.id.localeCompare(b.id)), null, 2) + '\n')
await mkdir(templateRoot, { recursive: true })
console.log(`Indexed ${apps.length} approved public apps. Source templates are exported separately into catalog/templates/.`)
