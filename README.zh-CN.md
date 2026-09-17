# XTApp Studio MCP

[English](README.md) · 中文

这是 XTApp 的轻量分发仓库，面向 agent 安装。可移植契约是本地 stdio MCP
`xtapp_studio`。任何能跑 MCP 的智能体都可以注册它。Codex Desktop /
Codex CLI 额外有 marketplace **插件**：同一份 MCP，再加上 skills 和状态
Widget。

## 把这个仓库交给 agent

把下面这段话发给 Codex（MCP / Cursor 提示词见 [`AGENT_PROMPT.md`](AGENT_PROMPT.md)）：

> 阅读
> [`AGENTS.md`](AGENTS.md)
> 并按 Install into Codex 车道把 XTApp 插件装进 Codex。保留已有配置，使用插件自带的
> `xtapp_studio` MCP，并报告 XTApp Studio 是否还缺前提。

详细入口是 [`AGENTS.md`](AGENTS.md)。装好之后，agent 要引导用户说出 [`AGENT_PROMPT.md`](AGENT_PROMPT.md) 里的那一句：在当前文件夹新建 `todo-list`，做个待办。

中文安装说明：[docs/INSTALL_MCP.zh-CN.md](docs/INSTALL_MCP.zh-CN.md)、
[docs/INSTALL_CODEX.zh-CN.md](docs/INSTALL_CODEX.zh-CN.md)、
[docs/INSTALL_CURSOR.zh-CN.md](docs/INSTALL_CURSOR.zh-CN.md)

## 架构

MCP 才是产品。它不执行 Lua，也不是设备模拟器。Codex 插件模式是这份 MCP
的更好包装：

```text
任意 MCP 智能体：注册 xtapp_studio；用户或宿主浏览器打开 previewUrl
Codex 插件：marketplace 包同一份 MCP + skills + 状态 Widget
  -> XTApp Studio 预览页
  -> Lua Worker / X4 Classic / X4 Pro 模拟器
```

用户在本地写代码，打开一个官网预览页看效果。调用 `run_xtapp_preview` 并带上
当前 worktree 路径。返回的 `previewUrl` 带 session。不要只打开
`/studio/preview?preview=1`。有浏览器 MCP 的宿主（Cursor）必须用内置
浏览器打开这条 URL 并保持标签页。其他宿主把 URL 交给用户。出现登录页就
停下，由用户登录后再回到同一条地址。不要用浏览器去点模拟器 DOM，点选和
按键走 `send_xtapp_preview_touch` / `send_xtapp_preview_input`。
`need_login_or_open_page` / `not_connected` 不是成功。官网可能已经打开了
别的项目；同步会为这个 worktree 新建或复用独立项目，不会覆盖用户其他工程。

## 当前包

- 基线：本地 stdio MCP `xtapp_studio`（`node ./mcp/server.bundle.mjs`）
- Codex 增强：从 `main` 发布的 Git marketplace 插件
- Marketplace / 选择器 / Studio 源：`region.json`（本仓是国内；国外是 `xtapp-studio-mcp-intl`）
- Plugin：`xtapp-studio-mcp`
- 显示名：`XTApp Studio`
- 插件版本：`0.1.5`
- 运行时：已登录的 XTApp Studio
- 默认预览：以 `get_xtapp_preview_status` 返回的 `previewUrl` 为准
- Skills：`xtapp-contracts`、`xtapp-open-preview`（可移植；Codex 会自动加载）
- 公开知识：`knowledge/index.json`（schema 2，22 条）
- 公开目录：`catalog/index.json`（107 个审核过的文本模板）
- Widget：`widget/index.html` 仅 Codex；显示预览状态，不是模拟器画面

## 直接安装

### 任意 MCP 智能体

在本仓库检出里打印 stdio 片段，只把 `mcpServers.xtapp_studio` 合并进
宿主配置：

```bash
node scripts/cursor-mcp-config.mjs
```

见 [docs/INSTALL_MCP.zh-CN.md](docs/INSTALL_MCP.zh-CN.md)。Cursor 可以用
内置浏览器打开 `previewUrl`，这仍是 MCP 车道，不是第二套插件。见
[docs/INSTALL_CURSOR.zh-CN.md](docs/INSTALL_CURSOR.zh-CN.md)。

### Codex 插件

```bash
codex plugin marketplace add "$(node scripts/region-field.mjs githubSource)" --ref main --json
codex plugin add "$(node scripts/region-field.mjs pluginSelector)" --json
```

插件已经带有 `.mcp.json`。不要编造远程 MCP 地址或 Studio 源码路径。验证：

```bash
codex plugin list --json
```

已经装过插件时，用市场升级，不要自己写更新器：

```bash
codex plugin marketplace upgrade "$(node scripts/region-field.mjs marketplaceName)" --json
codex plugin add "$(node scripts/region-field.mjs pluginSelector)" --json
```

Codex 也可能在插件启动时自动升级这个 Git 市场。安装或升级后新开一个
Codex 任务，才会加载新的 MCP。

如果预览页没有打开，把 `previewUrl` 原样给用户。出现登录页就先登录，再回到
同一条地址，并保持打开。然后再让 Codex 预览当前 worktree。

隔离验证和卸载见 [docs/INSTALL_CODEX.zh-CN.md](docs/INSTALL_CODEX.zh-CN.md)。
包身份在 [`release-manifest.json`](release-manifest.json)。

## 源码与发布边界

这个仓库只放可移植 MCP、可选的 Codex marketplace 包、公开知识、公开模板
和安装文档。其他智能体消费同一份 MCP，不是第二个宿主目录。Lua 执行、
素材管线和设备模拟器留在 XTApp Studio 里。

`/preview/*` 契约背后的产品更新不会自动改这个仓库。知识和模板只能从维护者
本机源刷新，并且不能把那些源位置写进本仓库。

这一版把 Codex 插件包放在仓库根目录。不要把它嵌到 `plugins/codex/` 下面，
也不要增加 `hosts/<name>/`。
