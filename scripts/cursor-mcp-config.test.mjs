import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'
import {
  cursorNestedWorkspaceMcpConfig,
  cursorUserMcpConfig,
  mergeCursorMcp,
} from './cursor-mcp-config.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

test('用户级 MCP 用绝对路径，合并时不删其他 server', () => {
  const config = cursorUserMcpConfig(ROOT)
  assert.match(config.mcpServers.xtapp_studio.args[0], /mcp\/server\.bundle\.mjs$/)
  const merged = mergeCursorMcp({
    mcpServers: { other: { command: 'echo' } },
  }, ROOT)
  assert.equal(merged.mcpServers.other.command, 'echo')
  assert.equal(merged.mcpServers.xtapp_studio.command, 'node')
})

test('Cursor 嵌套工作区 MCP 指向子目录 bundle', () => {
  const config = cursorNestedWorkspaceMcpConfig()
  assert.deepEqual(config.mcpServers.xtapp_studio.args, ['xtapp-studio-mcp/mcp/server.bundle.mjs'])
})

test('预览 skill 要求 Cursor 用内置浏览器打开，点选走 MCP', async () => {
  const skill = await readFile(resolve(ROOT, 'skills/xtapp-open-preview/SKILL.md'), 'utf8')
  assert.match(skill, /browser_navigate/)
  assert.match(skill, /send_xtapp_preview_touch/)
  assert.match(skill, /Do not click the simulator canvas/)
})

test('入口把 MCP 当基线，Codex 插件当增强', async () => {
  const agents = await readFile(resolve(ROOT, 'AGENTS.md'), 'utf8')
  const readme = await readFile(resolve(ROOT, 'README.md'), 'utf8')
  assert.match(agents, /Install as MCP/)
  assert.match(agents, /The MCP is the product/)
  assert.match(readme, /Any MCP agent/)
  assert.match(readme, /Codex plugin/)
})
