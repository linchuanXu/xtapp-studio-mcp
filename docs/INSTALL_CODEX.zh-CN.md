# 在 Codex 中安装

[English](INSTALL_CODEX.md) · 中文

返回 [中文首页](../README.zh-CN.md)

Codex 是增强宿主：marketplace **插件**打包同一份 `xtapp_studio` MCP，再加上
skills 和状态 Widget。没有插件能力的智能体走
[INSTALL_MCP.zh-CN.md](INSTALL_MCP.zh-CN.md)。

## 支持的环境

- 带 `codex plugin marketplace` 的 Codex Desktop 或 Codex CLI
- 已登录的 XTApp Studio
- 插件选择器见 `region.json` 的 `pluginSelector`
- 自带 MCP 名称 `xtapp_studio`
- 预览页以 `get_xtapp_preview_status` 返回的 `previewUrl` 为准（需登录，带 session）
- 保持官网预览页打开

## 常规 Git marketplace 安装

```bash
codex plugin marketplace add "$(node scripts/region-field.mjs githubSource)" --ref main --json
codex plugin add "$(node scripts/region-field.mjs pluginSelector)" --json
```

如果预览页没有打开，把 `run_xtapp_preview` 或 `get_xtapp_preview_status`
返回的 `previewUrl` 原样交给用户。出现登录页就先登录，再回到同一条地址。
不要编造下载地址、clone 路径或安装脚本。

插件带有本地 `.mcp.json`，没有远程 MCP。

```bash
codex plugin list --json
```

期望的插件身份：

- 选择器：`region.json` 的 `pluginSelector`
- Marketplace：`region.json` 的 `marketplaceName`
- 版本：`release-manifest.json` 中的值
- MCP：自带 `xtapp_studio` stdio，命令 `node ./mcp/server.bundle.mjs`

安装后新开一个 Codex 任务，才会加载新的插件快照。然后对当前 worktree 调用
`run_xtapp_preview`，把返回的 `previewUrl`（需登录）交给用户并保持打开。
官网可能已经打开了别的项目；同步会为这个 worktree 新建或复用独立项目。

## 更新已安装的插件

更新由 Codex 宿主负责，插件不会自己下载覆盖自己。Codex 可能在插件启动或
`plugin/list` 时自动升级已配置的 Git 市场。要立刻刷新：

```bash
codex plugin marketplace upgrade "$(node scripts/region-field.mjs marketplaceName)" --json
codex plugin add "$(node scripts/region-field.mjs pluginSelector)" --json
```

TUI 的 `/plugins` 市场页也可以升级。缓存版本与 `release-manifest.json`
一致后，新开一个 Codex 任务。当前任务会继续用旧的 MCP。

## 已发布 Git marketplace 冒烟

可用隔离的 `CODEX_HOME` 验证包装，不碰日常 Codex 状态：

```bash
XTAPP_CODEX_PLUGIN_TEST_HOME="$(mktemp -d /tmp/xtapp-plugin-codex-home.XXXXXX)"
CODEX_HOME="$XTAPP_CODEX_PLUGIN_TEST_HOME" codex plugin marketplace add \
  "$(node scripts/region-field.mjs githubSource)" --ref main --json
CODEX_HOME="$XTAPP_CODEX_PLUGIN_TEST_HOME" codex plugin add \
  "$(node scripts/region-field.mjs pluginSelector)" --json
CODEX_HOME="$XTAPP_CODEX_PLUGIN_TEST_HOME" codex plugin list --json
```

只安装插件不会打开预览。完整冒烟需要先登录，打开
`get_xtapp_preview_status` 返回的 `previewUrl`（带 session），再对这个页面调用
插件工具。`get_xtapp_preview_status` 按返回值原样阅读。未登录、页没开或
session 不一致时必须保持 `not_connected`，不能改去猜另一个主机。

只删除这次冒烟创建的临时目录。

## 未发布候选冒烟

维护者可以把当前仓库根目录当作 Git 源：

```bash
XTAPP_AGENT_PLUGIN_REPO="$(git rev-parse --show-toplevel)"
XTAPP_CODEX_PLUGIN_TEST_HOME="$(mktemp -d /tmp/xtapp-plugin-candidate-home.XXXXXX)"
CODEX_HOME="$XTAPP_CODEX_PLUGIN_TEST_HOME" codex plugin marketplace add \
  "$XTAPP_AGENT_PLUGIN_REPO" --json
CODEX_HOME="$XTAPP_CODEX_PLUGIN_TEST_HOME" codex plugin add \
  "$(node scripts/region-field.mjs pluginSelector)" --json
CODEX_HOME="$XTAPP_CODEX_PLUGIN_TEST_HOME" codex plugin list --json
```

这条本地源只用于测试证据，不是普通用户的安装路径。

## Agent 完成报告

必须报告：

- marketplace / 插件是新装的还是已经存在；
- 已安装的插件 id 和版本；
- 自带的 `xtapp_studio` MCP 是否在；
- 是否到达 Studio 预览页；
- 预览运行是做完了还是仍在等待；
- 需要新开任务。

## 预览约定

只有人读状态是 `running`，或桥接结果是 `complete`，才能说运行成功。
`need_login_or_open_page` / `not_connected` 表示预览页连不上，或 URL 里的
session 对不上。`timeout` / `queued_timeout` 表示 Studio 已接收命令，但还没
返回执行结果。改完代码后再次调用 `run_xtapp_preview`；文件监听不会在 MCP
重启后自动恢复。

源码同步只读取用户传入的当前工作区路径，留在本机。快照范围以外的二进制素材
仍由 Studio 的素材管线管理。

## 卸载

```bash
codex plugin remove "$(node scripts/region-field.mjs pluginSelector)" --json
codex plugin marketplace remove "$(node scripts/region-field.mjs marketplaceName)" --json
```

卸载插件不会删除 XTApp Studio、IndexedDB 预览状态或用户的 App 项目。那些只在
用户另外明确要求时才删除。
