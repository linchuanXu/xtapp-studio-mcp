import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { homedir } from 'node:os'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

export function cursorMcpServer(pluginRoot = ROOT) {
  return {
    command: 'node',
    args: [resolve(pluginRoot, 'mcp/server.bundle.mjs')],
  }
}

export function cursorUserMcpConfig(pluginRoot = ROOT) {
  return {
    mcpServers: {
      xtapp_studio: cursorMcpServer(pluginRoot),
    },
  }
}

/** Config when this plugin lives in a subdirectory of the Cursor workspace. */
export function cursorNestedWorkspaceMcpConfig(relativePluginDir = 'xtapp-studio-mcp') {
  const dir = String(relativePluginDir || 'xtapp-studio-mcp').replace(/\/+$/, '')
  return {
    mcpServers: {
      xtapp_studio: {
        command: 'node',
        args: [`${dir}/mcp/server.bundle.mjs`],
      },
    },
  }
}

export function mergeCursorMcp(existing, pluginRoot = ROOT) {
  const next = existing && typeof existing === 'object' && !Array.isArray(existing)
    ? structuredClone(existing)
    : {}
  const servers = next.mcpServers && typeof next.mcpServers === 'object' && !Array.isArray(next.mcpServers)
    ? next.mcpServers
    : {}
  next.mcpServers = {
    ...servers,
    xtapp_studio: cursorMcpServer(pluginRoot),
  }
  return next
}

export function userCursorMcpPath() {
  return resolve(homedir(), '.cursor/mcp.json')
}

async function readJsonObject(path) {
  try {
    const parsed = JSON.parse(await readFile(path, 'utf8'))
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {}
  } catch (error) {
    if (error && error.code === 'ENOENT') return {}
    throw error
  }
}

async function writeJson(path, value) {
  await mkdir(dirname(path), { recursive: true })
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`)
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const pluginRoot = ROOT
  if (process.argv.includes('--write-user')) {
    const path = userCursorMcpPath()
    const merged = mergeCursorMcp(await readJsonObject(path), pluginRoot)
    await writeJson(path, merged)
    process.stdout.write(`${path}\n`)
  } else {
    process.stdout.write(`${JSON.stringify(cursorUserMcpConfig(pluginRoot), null, 2)}\n`)
  }
}
