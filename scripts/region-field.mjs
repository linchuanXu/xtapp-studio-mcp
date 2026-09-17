import { loadPluginRegion } from '../mcp/regionConfig.mjs'

const key = String(process.argv[2] || '').trim()
if (!key) {
  console.error('usage: node scripts/region-field.mjs <field>')
  process.exit(2)
}
const region = loadPluginRegion()
if (!Object.prototype.hasOwnProperty.call(region, key)) {
  console.error(`unknown region field: ${key}`)
  process.exit(1)
}
process.stdout.write(String(region[key] ?? ''))
