---
name: xtapp-open-preview
description: Open the official XTApp Studio preview for the current local worktree and keep it synchronized. Use when previewing XTApp Lua, running the X4 simulator, or calling run_xtapp_preview.
---

The user writes XTApp code locally. Preview is one official webpage. After local edits, that page updates. The simulator is on that page, not in a Codex widget.

## Every preview request

1. Call `run_xtapp_preview` with the **absolute XTApp project directory** in `projectDir` — the folder that contains `manifest.json`. After a cold start that is often `todo-list/`, not the parent workspace. Never omit it. Never preview whatever leftover project is already open on the official page.
2. Open the exact returned `previewUrl` (it includes the plugin session). Never open the bare `/studio/preview?preview=1` page.
3. If the tool returns `need_login_or_open_page` / `not_connected`, do not claim success. Open or re-open the **same** URL, then call `get_xtapp_preview_status`.
4. After code changes, call `run_xtapp_preview` again with the same `projectDir`. Do not assume the file watcher is still alive after an MCP or process restart. Preview sync batches assets internally; do not shrink the project to fit a transport cap.

Official Studio may already have another project open (for example 斗地主). Sync creates or reuses a plugin-owned project for **this** worktree. It must not overwrite the user's other Studio projects.

### How to open the page

**Cursor (built-in browser MCP):** do not ask the user to open Chrome. Use the host browser tools (`browser_tabs`, `browser_navigate`) to open `previewUrl` and **keep that tab on that URL**. The tab is the live simulator connection (EventSource). If a login page appears, **stop**. Ask the user to sign in in that same tab. Do not fill credentials, passkeys, or captchas. After they confirm, go back to the same `previewUrl` if the tab left it, then re-check status.

**Any MCP host without a browser MCP, including Codex:** give the user the exact `previewUrl` and ask them to open it. If a login page appears, they log in and return to that same URL. Keep it open. Codex may also show a status widget; that widget is not the simulator.

Do not click the simulator canvas with browser DOM tools (`browser_click` / `browser_type`). Device input is `send_xtapp_preview_input` and `send_xtapp_preview_touch`. Device PNG is `capture_xtapp_preview`. A browser screenshot may only confirm that the preview page is showing; it is not the simulator capture.

The app's folder on the preview storage card, `/AppFiles/<app_id>/` (what the app reads and writes with `ctx.files`), is not project source. To check what the app saved, or to set up test data before a run, use `list_xtapp_preview_app_files`, `read_xtapp_preview_app_file`, `write_xtapp_preview_app_file` and `delete_xtapp_preview_app_file` with the same projectDir. Do not guess its contents from the code.

Human statuses:

- `need_login_or_open_page`: the official page is not connected; open the same URL (Cursor: built-in browser; otherwise the user).
- `running`: the official page is showing this worktree.
- `timeout`: the page accepted the command but the run did not finish; confirm the same URL is still open, then retry.
- `page_open`: the page is connected but this worktree is not running yet; call `run_xtapp_preview`.

After MCP install or reload, start a **new agent conversation** before preview.

## Other tools

Use `get_xtapp_preview_status` to confirm the page. Use `watch_xtapp_preview` only to stop or restart the watcher. Use `sync_xtapp_preview_source` for a one-off source push. Use `tap_xtapp_preview_target` only when `/preview/targets` already lists a rectangle; if it is empty, capture a PNG and click coordinates. Do not add a Lua testing slot just to tap. Nested `domain/` Lua is synced. `restart_xtapp_preview` is a manual retry, and `stop_xtapp_preview` stops. Diagnose with `inspect_xtapp_preview_context` plus a contract search. Do not start a second preview server.
