import { createHash, randomUUID } from 'node:crypto'
import { mkdir, readFile, realpath, writeFile } from 'node:fs/promises'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'

const SESSION_ID = /^[A-Za-z0-9:_-]{8,160}$/

export function defaultPreviewSessionPath() {
  const override = String(process.env.XTAPP_PREVIEW_SESSION_FILE || '').trim()
  return override || join(homedir(), '.xtapp', 'codex-preview-session')
}

// 每个工程目录一条独立 session：多个会话同时做不同游戏时，各自的预览页和命令互不串。
export async function previewSessionFileForProject(projectDir) {
  const root = resolve(String(projectDir || '').trim())
  const real = await realpath(root).catch(() => root)
  const key = createHash('sha256').update(real).digest('hex').slice(0, 24)
  return join(dirname(defaultPreviewSessionPath()), 'preview-sessions', key)
}

export async function loadOrCreatePreviewSession(filePath = defaultPreviewSessionPath()) {
  try {
    const existing = (await readFile(filePath, 'utf8')).trim()
    if (SESSION_ID.test(existing)) return existing
  } catch { /* missing or unreadable file starts a new stable session */ }
  const sessionId = randomUUID()
  await mkdir(dirname(filePath), { recursive: true })
  await writeFile(filePath, `${sessionId}\n`, 'utf8')
  return sessionId
}

export function previewRunPath(status) {
  return status === 'stopped' || status === 'error' ? '/preview/restart' : '/preview/run'
}
