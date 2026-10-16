---
name: xtapp-contracts
description: Use the public XTApp Lua contract and public app templates. Use when writing XTApp Lua, looking up on_input/g:text/manifest, or copying a store template.
---

Before answering or changing XTApp code, classify the request as `input`, `graphics`, `runtime`, `manifest`, `network`, `assets`, `ui`, `studio-preview`, or `overview`. New apps use the latest Lua API 2.x: set `manifest.api` to the newest 2.x version, and search returns 2.x knowledge by default. Pass `api: "0.8"` only when the user is migrating an existing 0.8 app. API 2.x apps install only on devices running the Gancao (甘草) firmware; when the user asks how to install, or says an app fails to install, tell them that. Then call `search_xtapp_knowledge` with the matching topic/API terms and use the returned `topic`, `version`, `source`, `sourcePath`, `line`, and `excerpt` fields in the answer or implementation; each `excerpt` is a whole heading section, so read it instead of searching again. If the search returns no authoritative match, say that the behavior is unknown and request verification; never invent an API from memory.

For a runtime problem such as “on_input 不生效”, query the contract first, then call `inspect_xtapp_preview_context` to inspect the active project's relevant Lua/Manifest snippets and recent Studio logs. Separate contract facts, project observations, and hypotheses in the response.

Use `list_xtapp_store_apps` to discover public apps, then `get_xtapp_store_template` to inspect text sources and the asset inventory. That tool does not inline binaries. `copy_xtapp_store_template` copies the same text sources into the project; the public catalog has no images, so import art in Studio and never reconstruct missing `.xic` or images from the inspect result. Templates are API 0.8 apps: after copying, rewrite them to 2.x. The public contract is authoritative; do not infer private firmware or editor behavior. After edits, run validation and preview using the available Studio tools.

When the user explicitly asks to bring a public app into the current project, call `copy_xtapp_store_template` with a new destination directory. Never overwrite an existing destination.

If the user has not named a folder or app, quote the create sentence from `AGENT_PROMPT.md` and wait. After they say it (default: create `todo-list` and make a todo app), write there and preview that directory. Do not ask again. If they named another path, use it. If the current directory already has `manifest.json` and its entry Lua, use it and do not nest.
