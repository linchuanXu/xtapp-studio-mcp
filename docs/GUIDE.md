# Guide: what the plugin changes and where things live

English · [中文](GUIDE.zh-CN.md)

Back to [README](../README.md)

This page is for app authors. For installation see [INSTALL_MCP.md](INSTALL_MCP.md),
[INSTALL_CODEX.md](INSTALL_CODEX.md) and [INSTALL_CURSOR.md](INSTALL_CURSOR.md).
This page covers what happens after install: what the plugin does, where your work
is stored, and when it is actually saved.

## In one sentence

The plugin is an MCP server, `xtapp_studio`, running on your computer. It reads **the
app folder on your computer**, sends it to the XTApp Studio preview page to run, and
presses keys, taps and takes screenshots for the AI. It does not run Lua itself and
never saves to the cloud. The cloud copy is written only when you click Save in Studio.

## Connecting each AI tool

| Tool | How | Extras |
|---|---|---|
| Codex | Marketplace plugin | Same MCP plus two skills and a preview status panel on the right |
| Cursor | MCP | Opens the preview page in Cursor's built-in browser |
| WorkBuddy, Claude Code and other tools | Generic MCP | No panel; the AI gives you the preview link to open |

Every generic MCP host is set up the same way. In this repository run

```bash
node scripts/cursor-mcp-config.mjs
```

and merge the printed `mcpServers.xtapp_studio` into the tool's MCP config (in WorkBuddy,
add a local stdio server in its MCP settings with command `node` and the printed absolute
path to `mcp/server.bundle.mjs` as the argument). Reload and start a new conversation.
Node.js 18 or newer is required.

`region.json` at the repository root says which Studio this copy talks to.

## What happens during a preview

```text
your app folder ──plugin reads──▶ relay (temporary, expires after 15 idle minutes) ──▶ Studio preview page
                                                                                       │
                                                                  a project in your browser ──▶ simulator
```

1. The plugin reads `manifest.json`, `*.lua`, text files under `data/` and `lang/`, and
   images under `assets/` and `raw/`. It skips `docs/`, `tmp/`, `prototypes/` and `.tmp/`.
   Each text file can be up to 256KB, each image up to 2MB.
2. It sends them to Studio: everything the first time, only changes after that.
3. The Studio preview page writes them into a project **in your browser** and runs it in
   the simulator.
4. The AI gives you the preview link, which carries a session id. Open it and keep it
   open. If a sign-in page appears, sign in yourself; the AI does not and should not type
   your password. If two tabs open the same session, the last one opened takes over.

Previewing the same folder again returns to the same preview page and the same project.

## Where your work lives

| Where | What | Can it be lost? |
|---|---|---|
| **The app folder on your computer** | The master copy of your source. This is what the AI edits | Like any file. Use Git |
| The Studio project in your browser | The copy used for preview, plus images you uploaded or generated in Studio | Gone if you clear browser data or switch computers |
| Cloud workspace (your account) | The draft as of your last Save | No; sign in on any computer to open it |
| Simulator storage card `/AppFiles/<app_id>/` | Data your app saved at run time, not source | Stays with the preview device |
| `~/.xtapp/` | Which folder maps to which preview session | Deleting it only starts a new session |

Two rules:

- **Preview sync is not saving.** Each preview only updates the project in your browser.
  To open it on another computer, click Save in the Studio top bar (sign-in required). If
  the cloud has a newer copy, Studio asks before overwriting; it never merges.
- **Saving is not publishing.** A saved draft is visible only to you. Store publishing is
  in the account dashboard.

## Which Studio project a folder maps to

Studio looks in this order:

1. The folder has `docs/studio.cloud.json` containing `{"cloudProjectId": "…"}`: use that
   cloud project.
2. Last time it was this same folder: keep using it.
3. A project with the same name as `display_name` in `manifest.json`, or **exactly one**
   draft with that name in your account.
4. Nothing matches: create a new project.

Except when creating, Studio asks "Allow the local plugin to sync into “…”?" before
overwriting an existing project. Cancel if it is not the one you want.

**Continuing on another computer:** bring the app folder with you (Git, for example). If
your account has exactly one draft with that name, it is matched automatically. If there
are several, a new project is created, and when you Save, Studio asks which draft to
update and shows its cloud project id. To always match reliably, put that id in the
folder's `docs/studio.cloud.json`. The file only matters on your computer; it does not go
into the cloud draft or the store package.

**Starting a separate copy:** choose "Save as a new cloud project" in the Studio project
manager.

## Files and images: which side wins

| Case | Result |
|---|---|
| You changed or added files or images in the folder | Sent on the next preview |
| You deleted files or images the folder sent before | Deleted in Studio too |
| Images uploaded or generated in Studio | Kept on preview; the AI tells you once |
| Bring Studio images back into the folder | Ask the AI to pull them (`pull_xtapp_studio_source`); images are saved as `assets/<name>.xic`; differing local files are not overwritten by default |
| Delete an image that exists only in Studio | Tell the AI which one |

PNG, JPG and WebP are converted to the device format XIC when sent.

Note: code you edit directly in Studio does not flow back to the folder. On the next
preview the folder's version replaces it. Ask the AI to pull it first if you want to keep it.

## App data on the storage card

What your app saves with `ctx.files` lives on the simulator storage card under
`/AppFiles/<app_id>/`. The AI can list, read, write and delete files there to inspect
saves or prepare test data. This needs `manifest.api` 2.9 or later, an `app_id` in
`manifest.json`, and the preview page showing this project.

## Outdated plugin

When Studio sees an older plugin, it shows "XTApp plugin needs an update". Ask the AI to
upgrade the XTApp plugin:

- Codex: the AI upgrades through the Codex marketplace. Start a **new** task afterwards.
- Other tools: `git pull` in this repository, reload MCP, start a new conversation.

## FAQ

| Symptom | What to do |
|---|---|
| The preview page shows sign-in | Sign in, then return to the same preview link |
| The AI reports `not_connected` | The preview page is not open; open the link again |
| It synced into the wrong project | Cancel the confirm dialog, or put the right id in `docs/studio.cloud.json` |
| The project is empty on another computer | You never clicked Save in Studio. Preview again from the folder, then Save |
| Only Codex has the side panel | Expected; other tools have none |
| Storage card actions fail | Check `manifest.api` ≥ 2.9, an `app_id`, and that the preview shows this project |
