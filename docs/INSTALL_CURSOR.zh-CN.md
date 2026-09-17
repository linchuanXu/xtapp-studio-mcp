# 在 Cursor 中安装

[English](INSTALL_CURSOR.md) · 中文

返回 [中文首页](../README.zh-CN.md)

Cursor 是 MCP 客户端，不是第二份 Codex marketplace 包。它和其他智能体一样
用**同一份**本地 `xtapp_studio` stdio MCP。多出来的宿主能力只在预览面：
Cursor 用**内置浏览器**打开 `previewUrl` 并保持该标签页。设备按键、点选和
截图仍走 `/preview/*`。

通用 MCP 安装：[INSTALL_MCP.zh-CN.md](INSTALL_MCP.zh-CN.md)。Codex 插件
增强：[INSTALL_CODEX.zh-CN.md](INSTALL_CODEX.zh-CN.md)。

## 支持的环境

- 带本地 MCP 和内置浏览器的 Cursor Desktop
- PATH 上有 Node.js（用来跑 `mcp/server.bundle.mjs`）
- 能找到 `mcp/server.bundle.mjs` 的一份检出
- 已登录的 XTApp Studio（登录发生在 Cursor 内置浏览器里）
- 预览地址以 `run_xtapp_preview` / `get_xtapp_preview_status` 返回的
  `previewUrl` 为准（带 session）。不要只打开
  `/studio/preview?preview=1`

不要跑 `codex plugin marketplace`。不要编造远程 MCP 地址，也不要再起一个
预览服务器。不要增加 `hosts/cursor` 这类宿主包。

## 注册自带 MCP

在本仓库根目录，只把 `mcpServers.xtapp_studio` 合并进
`~/.cursor/mcp.json`：

```bash
node scripts/cursor-mcp-config.mjs --write-user
```

`--write-user` 不删其他 server。在 Cursor Settings 里重载 MCP，然后**新开
一个 Agent 对话**。

如果本插件只是更大 Cursor 工作区里的子目录，要把 args 指到那个子目录，例如
`xtapp-studio-mcp/mcp/server.bundle.mjs`。

把 `skills/xtapp-contracts` 和 `skills/xtapp-open-preview` 符号链接到
`~/.cursor/skills/` 或项目的 `.cursor/skills/`。不要改写 skill 正文。

## 预览

1. `run_xtapp_preview` 必须带当前 worktree 绝对路径。
2. 用 Cursor 内置浏览器（`browser_tabs` / `browser_navigate`）打开返回的
   `previewUrl`，并保持在这条地址上。
3. 出现登录页就停下，请用户在这个标签页里登录。Agent 不填账号密码。然后再
   回到同一条 `previewUrl`。
4. 用 `get_xtapp_preview_status` 确认。`not_connected` 不是成功。
5. 点选和按键走 `send_xtapp_preview_touch`、`send_xtapp_preview_input`，不要
   去点模拟器 DOM。
6. 设备截图走 `capture_xtapp_preview`。

Cursor 里不会出现 Codex 右侧 widget，这是预期。

## 更新

拉取本仓库；若改过 MCP 源码先跑 `npm run build:mcp`，再跑
`node scripts/cursor-mcp-config.mjs --write-user`。然后新开 Agent 对话。

## 卸载

从 `~/.cursor/mcp.json` 或项目 MCP 配置里删掉 `xtapp_studio`。复制过的
skills 一并删掉。这不会卸载 XTApp Studio 或用户工程。
