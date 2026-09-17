# XTApp plugin distribution — agent entrypoint

This repository is designed to be operated by an agent. The portable
contract is a local stdio MCP named `xtapp_studio`. Any MCP-capable
agent can register it. Codex additionally has a marketplace **plugin**
that bundles the same MCP plus skills and a status widget.

This checkout is one regional distribution. Read `region.json` for
`pluginRepo`, `githubSource`, `marketplaceName`, `pluginSelector`, and
`studioOrigin`. Do not send preview traffic to another region's Studio.

## First decide the operation

Choose exactly one lane:

1. **Make an app** — the user wants a runnable XTApp and is not asking
   to install. Use this when `xtapp_studio` is already available.
2. **Install as MCP** — any agent that can run a local stdio MCP.
   Register `xtapp_studio`. No host plugin directory.
3. **Install into Codex** — Codex Desktop / Codex CLI with
   `codex plugin marketplace`. This is the enhanced path: plugin
   snapshot, skills, and widget around the same MCP.
4. **Inspect or explain** — read `README.md`, `release-manifest.json`,
   the marketplace manifest, and the plugin manifest. Do not change
   configuration.
5. **Uninstall** — MCP: `docs/INSTALL_MCP.md#uninstall`. Codex:
   `docs/INSTALL_CODEX.md#uninstall`. Cursor convenience:
   `docs/INSTALL_CURSOR.md#uninstall`.
6. **Refresh or release** — follow "Maintainer lane" below.

If the user wants to build or preview an app and did not ask to install,
use Make an app. If they have not named a folder or app yet, quote the
create sentence from `AGENT_PROMPT.md` and wait; do not invent a second
questionnaire. If they already sent that sentence, or named another
path, do not ask again. If `xtapp_studio` is missing, stop after pointing
at the matching install lane; do not write project files.

If the user names Codex for install, use the Codex lane. If they name
Cursor or another MCP host, use the MCP lane. Otherwise: Codex when
`codex plugin marketplace list --json` works; MCP for every other
install session.

Do not scan private product sources unless the selected lane explicitly
requires a maintainer refresh.

## Architecture to preserve

The MCP is the product. The Codex plugin is a better packaging of that
MCP. Neither replaces XTApp Studio:

```text
Any MCP agent: register xtapp_studio stdio; user or host browser opens previewUrl
Codex plugin:  marketplace wraps the same MCP + skills + status widget
  -> official Studio preview page (EventSource)
  -> Lua Worker / device simulator
```

Shared payload: `mcp/`, `skills/`, `knowledge/`, `catalog/`, `widget/`.
The MCP Apps widget is Codex-only. The simulator is always the official
preview page.

Call `run_xtapp_preview` with the absolute XTApp project directory as
`projectDir` (the folder that contains `manifest.json`, often `todo-list/`
after a cold start — not the parent workspace).
Use the exact `previewUrl`. Hosts with a browser MCP (Cursor) must open
that URL (`browser_tabs` / `browser_navigate`) and keep the tab there.
Other hosts give the URL to the user. If a login page appears, stop and
let the user sign in; do not fill credentials. Then return to the same
URL. Do not click the simulator DOM; use `send_xtapp_preview_input` and
`send_xtapp_preview_touch`. `need_login_or_open_page` / `not_connected`
is not success. After code changes, call `run_xtapp_preview` again.
Official Studio may already have another project open; sync creates or
reuses a plugin-owned project for this worktree and must not overwrite
the user's other apps. Nested `domain/` Lua is synced. Inspect templates
with `get_xtapp_store_template`, then copy with `copy_xtapp_store_template`.

## Make an app

The user-facing line is the one sentence in `AGENT_PROMPT.md`. This lane
authorizes writing an XTApp after the user says that sentence, or names
another folder or app. It does not authorize install changes, Git
pushes, or store publishing.

If the user only asked to install, or has not named a folder or app,
do not start this lane. Quote the create sentence and wait.

### 1. Choose the project directory

Default: a `todo-list` subdirectory of the current workspace. Create it
if needed. The user already said to create it; do not ask again.

Use another path only when the user names one, or says to use the
current directory. If the current directory already has `manifest.json`
and its entry Lua at the root, use the current directory and do not
nest. If `todo-list` already exists, keep using it; do not rename it or
empty it. Do not refuse because the parent folder already has other
projects.

`projectDir` for every preview call is that folder's absolute path.

### 2. Write a minimum app

Search the public contract before editing. Do not invent APIs. The
smoke example is a todo list that can add, complete, and delete tasks.
Classic must work with `up/down/left/right/ok/back`. Pro also supports
touch. Do not copy a store template unless the user asked for one.

### 3. Preview that folder

Call `run_xtapp_preview` with the todo (or named) directory. Open the
exact `previewUrl`. Login, host browser, and simulator rules are the
same as in the install lanes. `need_login_or_open_page` /
`not_connected` is not success.

### 4. Hand back

Report the project directory, whether preview is `running`, and that
login is still pending if it is. Never report success for a parent
workspace preview.

## Install as MCP

Any explicit request to install into Cursor or another MCP host uses
this lane. It authorizes merging `xtapp_studio` into that
host's MCP config. It does not authorize source edits, Git pushes, or
deleting unrelated MCP servers. It does not invent a host plugin format.

### 1. Preflight

Need Node.js on PATH and a checkout that contains `mcp/server.bundle.mjs`.
Do not invent a remote MCP URL. Do not start a second preview server.
Do not run Codex marketplace commands unless the user asked for Codex.

### 2. Register the bundled MCP

From this repository root, print the stdio snippet:

```bash
node scripts/cursor-mcp-config.mjs
```

Merge only `mcpServers.xtapp_studio` into the host MCP config. For Cursor
user config, this is authorized:

```bash
node scripts/cursor-mcp-config.mjs --write-user
```

That writes an absolute `node …/mcp/server.bundle.mjs` into
`~/.cursor/mcp.json` and leaves other servers untouched.

If this repository is a subdirectory of a larger workspace, point args at
`<plugin-dir>/mcp/server.bundle.mjs`.

Reload MCP. Start a **new** agent session.

### 3. Skills

If the host supports Agent Skills, symlink `skills/xtapp-contracts` and
`skills/xtapp-open-preview`. Do not rewrite the skill bodies. Hosts
without skills still use the MCP tools.

### 4. Open the official preview page

Call `run_xtapp_preview` with the absolute current worktree. Open the
exact `previewUrl`. If the host has a browser MCP (Cursor), use
`browser_navigate` and keep that tab on that URL. Otherwise give the URL
to the user. If a login page appears, stop and ask the user to sign in;
do not fill credentials. Then return to the same URL. Confirm with
`get_xtapp_preview_status`. Do not click the simulator DOM. The Codex
widget will not appear; that is expected.

### 5. Verify

The host lists enabled `xtapp_studio`. After a new session, a smoke is:
`run_xtapp_preview` → the `previewUrl` is open → `get_xtapp_preview_status`
is not `not_connected`.

### 6. Hand back

Report:

- which host MCP config was changed;
- that only `xtapp_studio` was changed;
- whether skills were linked;
- whether the preview URL was opened (host browser or by the user);
- whether login is still pending;
- that a new agent session is needed after MCP reload;
- the exact next sentence the user should send, quoted from
  `AGENT_PROMPT.md` (create `todo-list` and make the todo app).

Do not write the todo app in the install turn. Never report
"preview works" when only MCP registration was verified.

Cursor details: `docs/INSTALL_CURSOR.md`. Generic MCP:
`docs/INSTALL_MCP.md`.

## Install into Codex

An explicit request to install or set up authorizes changes to the user's
Codex plugin configuration. It does not authorize source edits, Git pushes,
silent Studio installation, deployment, publication, or deleting unrelated
configuration.

### 1. Preflight

```bash
XTAPP_AGENT_PLUGIN_SOURCE="$(node scripts/region-field.mjs githubSource)"
XTAPP_AGENT_PLUGIN_MARKETPLACE="$(node scripts/region-field.mjs marketplaceName)"
XTAPP_AGENT_PLUGIN_SELECTOR="$(node scripts/region-field.mjs pluginSelector)"
codex --version
git ls-remote "$(node scripts/region-field.mjs pluginRepo).git" main
```

Require a Codex build that supports `codex plugin marketplace`. If
`codex plugin marketplace list --json` fails, stop and report that the host
is too old. If the preview page is not open, ask the user to sign in and
open the `previewUrl` from `get_xtapp_preview_status`. Do not invent a
download URL, clone path, or install script. Do not substitute a remote
MCP URL.

### 2. Inspect before mutating

```bash
codex plugin marketplace list --json
codex plugin list --json
```

If the user asks to update the XTApp plugin, or says「升级 XTApp 插件」,
follow this upgrade path. Do not invent a download URL.

If marketplace `$XTAPP_AGENT_PLUGIN_MARKETPLACE` points at a different source,
stop and report the name collision. Never remove or overwrite unrelated
marketplaces, plugins, MCP servers, or auth state.

Codex may auto-upgrade this Git marketplace on plugin startup. Do not
build a custom updater. If the marketplace is already configured, refresh
it first, then install or refresh the plugin:

```bash
codex plugin marketplace upgrade "$XTAPP_AGENT_PLUGIN_MARKETPLACE" --json
codex plugin add "$XTAPP_AGENT_PLUGIN_SELECTOR" --json
```

If the marketplace is not configured yet, add it, then add the plugin.

### 3. Install or refresh the plugin

```bash
codex plugin marketplace add "$XTAPP_AGENT_PLUGIN_SOURCE" --ref main --json
codex plugin marketplace upgrade "$XTAPP_AGENT_PLUGIN_MARKETPLACE" --json
codex plugin add "$XTAPP_AGENT_PLUGIN_SELECTOR" --json
```

`alreadyAdded: true` is success. After a marketplace upgrade, still run
`plugin add` so the installed cache matches `release-manifest.json`.
Do not hand-edit Codex configuration or copy plugin files into a Codex
home. Start a new Codex task after install or upgrade so MCP reloads.

### 4. Open the official preview page

The plugin registers MCP `xtapp_studio` from `.mcp.json`. Do not run
`codex mcp login`. Do not invent a Studio source path or start a second
preview server.

Give the user the exact `previewUrl` from `run_xtapp_preview` or
`get_xtapp_preview_status`. Ask them to open it; if login appears, log
in and return to that URL. Keep the page open. After they confirm, poll
status. If it is still disconnected, stop and give the same URL again.
Do not invent a localhost control URL. Start a new Codex task after
plugin install before preview.

### 5. Verify

```bash
codex plugin list --json
```

Required evidence:

- plugin id equals `pluginSelector` in `region.json`;
- installed version equals `release-manifest.json`;
- marketplace name equals `marketplaceName` in `region.json`;
- no bearer token, API key, or `.env` value is embedded.

If the official preview page is open, a runtime smoke may additionally
call `get_xtapp_preview_status`. `not_connected` means the preview is not
reachable. Never report that a project is running when the status is
`not_connected`, `queued`, or `queued_timeout`.

### 6. Hand back

Report:

- whether installation was new or already present;
- installed plugin id and version;
- that MCP `xtapp_studio` is bundled by the plugin;
- whether the official Studio preview page was reached;
- that a new Codex task is needed to load the plugin snapshot;
- whether a preview run was tested or remains pending login/preview;
- that project files stay on the local machine;
- the exact next sentence the user should send, quoted from
  `AGENT_PROMPT.md` (create `todo-list` and make the todo app).

Do not write the todo app in the install turn. Never report
"preview works" when only package installation was verified.

## Safety boundaries

- Lua execution, asset pipelines, and device simulation belong in
  XTApp Studio.
- Treat `.codex-plugin/plugin.json` and
  `.agents/plugins/marketplace.json` as Codex distribution payloads.
- Other agents consume the same MCP. Cursor is one MCP client with a
  host browser, not a second host directory.
- Never expose or commit credentials, Codex auth state, plugin caches,
  logs, `.env`, or smoke-test artifacts.
- There is no remote MCP dependency or fallback.
- Do not change Git remotes, push, publish, create a PR, or create an
  issue without explicit authorization.

## Maintainer lane

Enter only when the user asks to refresh, validate, or release:

1. Read `README.md`, `release-manifest.json`,
   `docs/INSTALL_MCP.md`, `docs/INSTALL_CODEX.md#unpublished-candidate-smoke`,
   and `docs/INSTALL_CURSOR.md`.
2. Refresh only the reviewed public payload files when the user provides
   maintainer-local source directories through environment variables.
3. Run `npm run check` and `npm run build:mcp` when MCP sources change.
4. Overseas GitHub is a generated repo. From this source checkout:
   `npm run publish:intl -- --studio-origin <overseas-studio> --push`
   Do not hand-edit `xtapp-studio-mcp-intl`.
5. Keep changes unpushed unless publication was explicitly authorized.
6. Never write private source names, clone URLs, or checkout paths into
   this repository.

## Host directory convention

Codex marketplace payload stays at the repository root:

- `.codex-plugin/plugin.json`
- `.mcp.json`
- `skills/`
- `mcp/`
- `widget/`

Do not nest that payload under `plugins/codex/`. Do not add
`hosts/<name>/` or treat a host MCP config as a second plugin format.
Non-Codex install is MCP registration plus optional portable skills.

Add another host directory only when a validated host-specific package
exists. A host with no reviewed payload is refused rather than packaged
with guessed conventions. Codex is the only reviewed plugin host.
