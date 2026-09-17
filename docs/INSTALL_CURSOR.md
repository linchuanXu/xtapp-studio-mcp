# Install in Cursor

English · [中文](INSTALL_CURSOR.zh-CN.md)

Cursor is an MCP client, not a second Codex marketplace package. It uses
the **same** bundled `xtapp_studio` stdio MCP as any other agent. The
extra host capability is the preview surface: Cursor opens `previewUrl`
in its **built-in browser** and keeps that tab open. Device input and
capture stay on `/preview/*` tools.

Generic MCP install: [INSTALL_MCP.md](INSTALL_MCP.md). Codex plugin
enhancement: [INSTALL_CODEX.md](INSTALL_CODEX.md).

## Supported environment

- Cursor Desktop with local MCP and the built-in browser
- Node.js on PATH (runs `mcp/server.bundle.mjs`)
- A checkout that contains `mcp/server.bundle.mjs`
- Signed-in XTApp Studio (login happens in the Cursor browser tab)
- Preview URL from `run_xtapp_preview` / `get_xtapp_preview_status`
  (includes session). Do not open the bare `/studio/preview?preview=1` page

Do not run `codex plugin marketplace`. Do not invent a remote MCP URL or a
second preview server. Do not add a `hosts/cursor` plugin payload.

## Register the bundled MCP

From this repository root, upsert only `mcpServers.xtapp_studio` into
`~/.cursor/mcp.json`:

```bash
node scripts/cursor-mcp-config.mjs --write-user
```

`--write-user` does not delete other servers. Reload MCP in Cursor
Settings, then start a **new Agent chat**.

If this plugin is a subdirectory of a larger Cursor workspace, point args
at that subdirectory instead, for example
`xtapp-studio-mcp/mcp/server.bundle.mjs`.

Symlink `skills/xtapp-contracts` and `skills/xtapp-open-preview` into
`~/.cursor/skills/` or the project's `.cursor/skills/`. Do not rewrite
the skill bodies.

## Preview

1. Call `run_xtapp_preview` with the absolute current worktree.
2. Open the returned `previewUrl` with Cursor's built-in browser
   (`browser_tabs` / `browser_navigate`). Keep that tab on that URL.
3. If a login page appears, stop. The user signs in in that tab. Do not
   fill credentials. Then return to the same `previewUrl`.
4. Confirm with `get_xtapp_preview_status`. `not_connected` is not success.
5. Click and keys go through `send_xtapp_preview_touch` and
   `send_xtapp_preview_input`. Do not click the simulator DOM.
6. Device PNG is `capture_xtapp_preview`.

The Codex widget will not appear. That is expected.

## Update

Pull this repository, run `npm run build:mcp` if MCP sources changed, then
run `node scripts/cursor-mcp-config.mjs --write-user` again so the absolute
path still points at this checkout. Start a new Agent chat.

## Uninstall

Remove the `xtapp_studio` entry from `~/.cursor/mcp.json` or the project
MCP config. Remove copied skills if you added them. This does not remove
XTApp Studio or the user's projects.
