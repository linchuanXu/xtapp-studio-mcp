# Install as MCP

English · [中文](INSTALL_MCP.zh-CN.md)

Any agent that can run a local stdio MCP can use this repository. The
shared contract is `xtapp_studio`, not a host-specific plugin format.

Codex additionally supports a marketplace **plugin** that bundles this
same MCP plus skills and a status widget. That is an enhancement, not a
second protocol. See [INSTALL_CODEX.md](INSTALL_CODEX.md).

Cursor is one MCP client with a built-in browser. See
[INSTALL_CURSOR.md](INSTALL_CURSOR.md).

## Supported environment

- Node.js on PATH (runs `mcp/server.bundle.mjs`)
- A checkout that contains `mcp/server.bundle.mjs`
- An MCP host that can launch a local stdio server
- Signed-in XTApp Studio
- Preview URL from `run_xtapp_preview` / `get_xtapp_preview_status`
  (includes session). Do not open the bare `/studio/preview?preview=1` page

Do not invent a remote MCP URL. Do not start a second preview server.
Do not add a guessed `hosts/<name>/` plugin payload.

## Register the bundled MCP

Print the stdio snippet from this repository root:

```bash
node scripts/cursor-mcp-config.mjs
```

That prints:

```json
{
  "mcpServers": {
    "xtapp_studio": {
      "command": "node",
      "args": ["/absolute/path/to/mcp/server.bundle.mjs"]
    }
  }
}
```

Merge only `mcpServers.xtapp_studio` into the host's MCP config. Leave
other servers untouched. Reload MCP, then start a **new** agent session.

Skills are portable Markdown. Hosts that support Agent Skills may symlink
`skills/xtapp-contracts` and `skills/xtapp-open-preview`. Hosts that do
not still work: the MCP tools are the contract.

## Preview

1. Call `run_xtapp_preview` with the absolute current worktree.
2. Open the exact `previewUrl`.
   - Hosts with a browser MCP (Cursor): open it in that browser and keep
     the tab on that URL.
   - Other hosts: give the user the URL and ask them to keep it open.
3. If a login page appears, stop. The user signs in. Do not fill
   credentials. Then return to the same `previewUrl`.
4. Confirm with `get_xtapp_preview_status`. `not_connected` is not success.
5. Click and keys go through `send_xtapp_preview_touch` and
   `send_xtapp_preview_input`. Do not click the simulator DOM.
6. Device PNG is `capture_xtapp_preview`.
7. The app's folder on the preview card, `/AppFiles/<app_id>/` (what the app
   reads and writes with `ctx.files`), goes through
   `list_xtapp_preview_app_files`, `read_xtapp_preview_app_file`,
   `write_xtapp_preview_app_file` and `delete_xtapp_preview_app_file`: check what
   the app saved, or set up test data.

The Codex widget will not appear outside Codex. That is expected.

## Update

Pull this repository. Run `npm run build:mcp` if MCP sources changed.
Point the host config at the same `mcp/server.bundle.mjs`. Start a new
agent session.

## Uninstall

Remove the `xtapp_studio` entry from the host MCP config. Remove copied
skills if you added them. This does not remove XTApp Studio or the
user's projects.
