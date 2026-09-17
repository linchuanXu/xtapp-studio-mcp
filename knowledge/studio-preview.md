# Studio 预览桥

## 作用

用户在本地写 XTApp，打开一个官网预览页看效果，改本地代码后页面更新。Studio 是项目和 Lua Worker 的运行 authority。插件通过官网 `/preview/*` 排队命令。模拟器画面在官网预览页，不在 Codex 右侧 widget。

`run_xtapp_preview` 必须带当前 worktree 的绝对路径 `projectDir`。它会读取本机 Lua、Manifest、data、lang，以及 `assets|raw` 下 `.xic` 与 `.png/.jpg/.jpeg/.webp`。单次 HTTP 会限制素材条数，插件会自动分批 `POST` 再 `PATCH` 合并，工程可以有更多素材。不要为了预览桥去删图、改字模或拆工程。官网会为这个 worktree **新建或复用独立项目**，不会覆盖用户正在写的其他工程（例如斗地主）。不要说插件不读文件系统。不要省略 `projectDir` 去跑官网里已经打开的项目。

所有 `/preview/*` JSON 都是信封：`{ok,data}` 或 `{ok,false,error:{code,message,details}}`。`ok` 只表示这次 HTTP 调用是否按契约完成。预览页没开时仍是 `ok: true`，`data.status: "not_connected"`。

## 启动

1. 调用 `run_xtapp_preview`，拿到带插件 session 的 `previewUrl`。不要只打开 `region.json` 里 `studioOrigin` 的裸 `/studio/preview?preview=1`。
2. 打开这条 URL，并保持打开。打开方式取决于宿主：
   - **有浏览器 MCP 的宿主（Cursor）：** 用内置浏览器 MCP（`browser_tabs` / `browser_navigate`）打开 `previewUrl`，不要请用户另开 Chrome。出现登录页就停下，请用户在这个内置页里登录，Agent 不填账号密码。登录后再回到同一条 `previewUrl`。
   - **其他 MCP 宿主（含 Codex）：** 把 `previewUrl` 原样交给用户打开。出现登录页就先登录，再回到同一条地址。Codex 插件可能另有状态 Widget，那不是模拟器。
3. 再调 `get_xtapp_preview_status`。仍是 `need_login_or_open_page` 时，停下来，用同一条 URL 再打开一次。
4. 不要用浏览器去点模拟器 DOM。按键走 `send_xtapp_preview_input`，点选走 `send_xtapp_preview_touch`。设备截图走 `capture_xtapp_preview`。浏览器截图只能确认预览页已打开，不能代替模拟器截图。
5. MCP 重启后 session 复用本机 `~/.xtapp/codex-preview-session`，同一 URL 仍然有效。文件监听不会跨进程存活，每次预览都要再走一遍就绪检查。

`not_connected` / `need_login_or_open_page` 表示预览页没开、没登录，或打开的 URL 不是插件返回的那条。不要报成功。

人读状态：`need_login_or_open_page`、`running`、`timeout`、`page_open`。

## 素材

- 快照里每个素材都带 `key/path/mime/bytes/sha256/base64`。解析不出 key 的条目会出现在 `dropped`，不会被静默丢掉。
- 超过单次请求条数时，插件继续补发剩余素材；`assetKeys` 是工程完整清单。不要把 80 当成设备或工程上限。
- `.xic` 原样入库。`.png/.jpg/.webp` 由 Studio 转成 1bpp XIC 和配套 matte。Proxy 不转码。
- 工具返回文本里如果出现 `未接受：…`，必须告诉用户哪些文件没进去，不要假装同步成功。

## 能力

- `run_xtapp_preview`：检查连接 → 同步当前 worktree → 启动或刷新。页没开时只返回 URL。若状态是 `stopped` 或 `error`，改走 `restart`。同一 worktree 复用已有文件监听，不会把刚同步完的 revision 立刻再推一遍。
- `restart_xtapp_preview`：先同步当前 worktree，再强制重新拉起 Lua Worker。必须带 `projectDir`。
- `sync_xtapp_preview_source`：只同步源码和素材，不启动。注意返回里的 `dropped`。
- `input`：模拟 `up/down/left/right/ok/back`。
- `send_xtapp_preview_touch`：默认点击方式，用逻辑坐标点画面。不要为了点选去改 Lua 增加测试槽。
- `tap_xtapp_preview_target`：若当前帧公布了带矩形的目标，插件会取其圆心再走坐标点击；没有目标时会明确说明，改用坐标或截图。
- 嵌套的 `domain/`、`persistence/`、`scripts/` Lua，以及 `data/`、`lang/` 下的 tsv/txt/json 会同步。看起来像源码但路径不合法的文件会出现在 `warnings`，不会被静默丢掉。
- 同一工程的源码推送串行执行；内容没变会跳过 HTTP。有上次成功 revision 时只 PATCH 变化，冲突则回退全量 POST。
- `stop`：停止当前 Worker。
- `capture_xtapp_preview`：截当前模拟器 PNG；优先用命令结果里的 `screenshot.dataUrl`。
- `/preview/context`：回传受限 Manifest、Lua 片段和最近日志。

右侧 widget 只报连接、应用名和 previewUrl，不是模拟器。Cursor 内置浏览器里打开的是同一张官网预览页。

## 诊断

按键不生效时，先查 `topic=input`，再调用 `inspect_xtapp_preview_context`。不要把 `queued` / `queued_timeout` / `not_connected` / `need_login_or_open_page` / `error` 报成运行成功。装完插件或重载 MCP 后需要新开一轮对话才会加载工具。
