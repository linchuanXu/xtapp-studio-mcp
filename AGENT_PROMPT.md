# Agent prompts

The create line is **one sentence the user says**. Agents already know the
rest from `AGENTS.md`. Do not make the user paste a long instruction.

## The sentence to say

写死这一句。装好之后，agent 要原样念给用户，请用户在新对话里发送。
用户已经说出这句、或自己点名了别的目录/应用时，不要再问，直接做。

中文：

> 在当前文件夹新建 todo-list，做一款能添加、完成、删除的待办。Classic 用方向键和 OK，Pro 也能点。

English:

> Create todo-list in this folder and make a todo app that can add, complete, and delete. Classic uses d-pad and OK. Pro also supports touch.

## Install as MCP

Use this instruction in any host that can run a local stdio MCP:

> Read `AGENTS.md` in this repository.
> Install XTApp using the **Install as MCP** lane. From a checkout of
> this repository, run `node scripts/cursor-mcp-config.mjs` and merge only
> `mcpServers.xtapp_studio` into this host's MCP config without deleting
> other servers. If the host supports Agent Skills, symlink
> `skills/xtapp-contracts` and `skills/xtapp-open-preview`. Reload MCP.
> Do not invent a remote MCP URL, a second preview server, or a host
> plugin directory. Do not edit source, publish, or push unless I asked.
> Do not write a todo app in this turn. After reload, start a new session
> and tell me to send this exact sentence:
> 「在当前文件夹新建 todo-list，做一款能添加、完成、删除的待办。Classic 用方向键和 OK，Pro 也能点。」

## Install into Codex

Use this instruction in Codex Desktop or Codex CLI:

> Read `AGENTS.md` in this repository.
> Install the XTApp plugin into Codex using the **Install into Codex** lane.
> Preserve unrelated plugins, marketplaces, MCP servers, and auth state.
> Keep the bundled `xtapp_studio` MCP from this plugin. Do not invent a
> download URL, clone path, install script, remote MCP URL, or source
> checkout path. Do not edit source, publish, or push. Do not write a
> todo app in this turn. After a new Codex task, tell me to send this
> exact sentence:
> 「在当前文件夹新建 todo-list，做一款能添加、完成、删除的待办。Classic 用方向键和 OK，Pro 也能点。」

## Install into Cursor

Cursor has no plugin marketplace. It is the MCP lane plus a built-in
browser:

> Read `AGENTS.md` in this repository.
> Install XTApp using the **Install as MCP** lane. Run
> `node scripts/cursor-mcp-config.mjs --write-user` from a checkout of
> this repository so `~/.cursor/mcp.json` gets `xtapp_studio` without
> deleting other servers. Symlink `skills/xtapp-contracts` and
> `skills/xtapp-open-preview` into `~/.cursor/skills/` or this project's
> `.cursor/skills/`. Reload MCP. Do not invent a remote MCP URL or a
> second preview server. Do not edit source, publish, or push unless I
> asked. Do not write a todo app in this turn. After a new Agent chat,
> tell me to send this exact sentence:
> 「在当前文件夹新建 todo-list，做一款能添加、完成、删除的待办。Classic 用方向键和 OK，Pro 也能点。」
