# XTApp Studio MCP

English · [中文文档](README.zh-CN.md)

This is an agent-first, lightweight distribution repository. The portable
contract is a local stdio MCP named `xtapp_studio`. Any MCP-capable agent
can register it. Codex Desktop / Codex CLI additionally has a marketplace
**plugin** that bundles the same MCP plus skills and a status widget.

## Give this repository to an agent

Give Codex this instruction (MCP / Cursor prompts are in
[`AGENT_PROMPT.md`](AGENT_PROMPT.md)):

> Read `AGENTS.md` in this repository and install the XTApp plugin into
> Codex. Follow the Install into Codex lane, preserve existing
> configuration, keep the bundled `xtapp_studio` MCP, and report any
> XTApp Studio prerequisite. Use `region.json` for this region's GitHub
> source and Studio origin.

The detailed entrypoint is [`AGENTS.md`](AGENTS.md). After install, the
agent should ask the user to say the one create sentence in
[`AGENT_PROMPT.md`](AGENT_PROMPT.md).

## Architecture

The MCP is the product. It does not execute Lua and it is not the device
simulator. Codex plugin mode is a better packaging of that MCP:

```text
Any MCP agent: register xtapp_studio; user or host browser opens previewUrl
Codex plugin:  marketplace wraps the same MCP + skills + status widget
  -> XTApp Studio preview page
  -> Lua Worker / X4 Classic / X4 Pro simulator
```

Users write locally, then one official webpage runs the preview. Call
`run_xtapp_preview` with the current worktree path. That `previewUrl`
includes the plugin session. Do not open the bare
`/studio/preview?preview=1` page. Hosts with a browser MCP (Cursor) open
the URL in that browser and keep the tab there. Other hosts give the URL
to the user. If login appears, the user signs in and returns to the same
URL. Do not click the simulator DOM; use `send_xtapp_preview_touch` /
`send_xtapp_preview_input`. `need_login_or_open_page` / `not_connected`
is not success. The official page may already have another project open;
sync creates or reuses a plugin-owned project for this worktree instead
of overwriting it.

## Current package

- Baseline: local stdio MCP `xtapp_studio` (`node ./mcp/server.bundle.mjs`)
- Codex enhancement: Git marketplace plugin from `main`
- Marketplace / selector / Studio origin: `region.json` (this checkout is China; overseas is `xtapp-studio-mcp-intl`)
- Plugin: `xtapp-studio-mcp`
- Display name: `XTApp Studio`
- Plugin version: `0.1.5`
- Runtime: signed-in XTApp Studio
- Default preview: official Studio host; always use the `previewUrl` from `get_xtapp_preview_status`
- Skills: `xtapp-contracts`, `xtapp-open-preview` (portable; auto-loaded in Codex)
- Public knowledge: `knowledge/index.json` (schema 2, 24 entries)
- Public catalog: `catalog/index.json` (107 reviewed text templates)
- Widget: `widget/index.html` is Codex-only; shows preview status, not the simulator frame

## Direct installation

### Any MCP agent

From a checkout of this repository, print the stdio snippet and merge
only `mcpServers.xtapp_studio` into the host config:

```bash
node scripts/cursor-mcp-config.mjs
```

See [docs/INSTALL_MCP.md](docs/INSTALL_MCP.md). Cursor's built-in browser
can open `previewUrl`; that is still the MCP lane, not a second plugin.
See [docs/INSTALL_CURSOR.md](docs/INSTALL_CURSOR.md).

### Codex plugin

```bash
codex plugin marketplace add "$(node scripts/region-field.mjs githubSource)" --ref main --json
codex plugin add "$(node scripts/region-field.mjs pluginSelector)" --json
```

The plugin already ships `.mcp.json`. Do not invent a remote MCP URL or a
Studio source path. Verify:

```bash
codex plugin list --json
```

If the plugin is already installed, refresh the marketplace instead of
building a custom updater:

```bash
codex plugin marketplace upgrade "$(node scripts/region-field.mjs marketplaceName)" --json
codex plugin add "$(node scripts/region-field.mjs pluginSelector)" --json
```

Codex may also auto-upgrade this Git marketplace on plugin startup. Start
a new Codex task after install or upgrade so the MCP snapshot reloads.

If the preview is not open, give the user the exact `previewUrl` and ask
them to open it. If a login page appears, they should log in and return
to that URL. Keep it open. Then ask Codex to preview the current
worktree.

See [docs/INSTALL_CODEX.md](docs/INSTALL_CODEX.md) for isolated
validation and uninstall, or the [Chinese install guide](docs/INSTALL_CODEX.zh-CN.md).
Identity fields live in [`release-manifest.json`](release-manifest.json).

## Source and release boundary

This repository contains the portable MCP, optional Codex marketplace
payload, public knowledge, public templates, and installation
documentation. Other agents consume the same MCP. They are not a second
host directory. Lua execution, asset pipelines, and the device simulator
stay in XTApp Studio.

Product updates behind the stable `/preview/*` contract do not
automatically change this repository. Refresh the knowledge index and
catalog only from maintainer-local sources, and never publish those
source locations.

Knowledge refresh takes the source roots from environment variables, so
no checkout path is recorded here; `--check` fails when the committed
index no longer matches those sources, and skips with a notice when the
roots are not provided:

```bash
XTAPP_CONTRACT_DIR=<contracts-checkout> \
XTAPP_PUBLIC_KNOWLEDGE_DIR=<studio-content-documents>:<studio-content-public> \
npm run sync:knowledge

XTAPP_CONTRACT_DIR=<contracts-checkout> \
XTAPP_PUBLIC_KNOWLEDGE_DIR=<studio-content-documents>:<studio-content-public> \
npm run knowledge:check
```

This revision ships the Codex plugin payload at the repository root. Do
not nest it under `plugins/codex/`. Do not add `hosts/<name>/`.
