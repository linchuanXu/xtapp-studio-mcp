# 按 MCP 安装

[English](INSTALL_MCP.md) · 中文

返回 [中文首页](../README.zh-CN.md)

任何能跑本地 stdio MCP 的智能体都可以用这个仓库。共用契约是
`xtapp_studio`，不是某个宿主的插件格式。

Codex 额外支持 marketplace **插件**：同一份 MCP，再加上 skills 和状态
Widget。那是增强层，不是第二套协议。见
[INSTALL_CODEX.zh-CN.md](INSTALL_CODEX.zh-CN.md)。

Cursor 是带内置浏览器的一个 MCP 客户端。见
[INSTALL_CURSOR.zh-CN.md](INSTALL_CURSOR.zh-CN.md)。

## 支持的环境

- PATH 上有 Node.js（用来跑 `mcp/server.bundle.mjs`）
- 能找到 `mcp/server.bundle.mjs` 的一份检出
- 能拉起本地 stdio MCP 的宿主
- 已登录的 XTApp Studio
- 预览地址以 `run_xtapp_preview` / `get_xtapp_preview_status` 返回的
  `previewUrl` 为准（带 session）。不要只打开
  `/studio/preview?preview=1`

不要编造远程 MCP 地址，也不要再起一个预览服务器。不要猜测并增加
`hosts/<name>/` 这类宿主包。

## 注册自带 MCP

在本仓库根目录打印 stdio 片段：

```bash
node scripts/cursor-mcp-config.mjs
```

会打出：

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

只把 `mcpServers.xtapp_studio` 合并进宿主的 MCP 配置，不要动其他
server。重载 MCP，然后**新开**一轮 agent 对话。

Skills 是可移植的 Markdown。宿主如果支持 Agent Skills，可以把
`skills/xtapp-contracts` 和 `skills/xtapp-open-preview` 符号链接过去。
不支持 skills 的宿主仍然可用：MCP 工具才是契约。

## 预览

1. `run_xtapp_preview` 必须带当前 worktree 绝对路径。macOS / Linux 写 `/Users/...`，
   Windows 写 `D:\...`、`D:/...`、`\\server\share\...` 或 Git Bash 的 `/d/...` 都行。
2. 打开返回的 `previewUrl`。
   - 有浏览器 MCP 的宿主（Cursor）：用内置浏览器打开，并保持在这条地址。
   - 其他宿主：把 URL 交给用户，请他们保持打开。
3. 出现登录页就停下，由用户登录。Agent 不填账号密码。然后再回到同一条
   `previewUrl`。
4. 用 `get_xtapp_preview_status` 确认。`not_connected` 不是成功。
5. 点选和按键走 `send_xtapp_preview_touch`、`send_xtapp_preview_input`，
   不要去点模拟器 DOM。
6. 设备截图走 `capture_xtapp_preview`。
7. 存储卡上本应用的文件夹 `/AppFiles/<app_id>/`（应用用 `ctx.files` 读写）走
   `list_xtapp_preview_app_files`、`read_xtapp_preview_app_file`、
   `write_xtapp_preview_app_file`、`delete_xtapp_preview_app_file`：查看应用存下的数据、
   准备测试数据。

Codex 以外不会出现右侧 widget，这是预期。

## 更新

拉取本仓库；若改过 MCP 源码先跑 `npm run build:mcp`。宿主配置仍指向同一份
`mcp/server.bundle.mjs`。然后新开一轮 agent 对话。

## 卸载

从宿主 MCP 配置里删掉 `xtapp_studio`。复制过的 skills 一并删掉。这不会
卸载 XTApp Studio 或用户工程。
