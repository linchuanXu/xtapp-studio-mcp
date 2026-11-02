import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const defaultRegionPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'region.json')

export function loadPluginRegion(regionPath = defaultRegionPath) {
  return JSON.parse(readFileSync(regionPath, 'utf8'))
}

export function resolveStudioOrigin({
  env = process.env,
  region = loadPluginRegion(),
} = {}) {
  const fromEnv = String(env.XTAPP_STUDIO_CONTROL_URL || '').trim().replace(/\/$/, '')
  if (fromEnv) return fromEnv
  const fromRegion = String(region.studioOrigin || '').trim().replace(/\/$/, '')
  if (!fromRegion) {
    throw new Error('region.json studioOrigin is empty; set it or XTAPP_STUDIO_CONTROL_URL')
  }
  return fromRegion
}
