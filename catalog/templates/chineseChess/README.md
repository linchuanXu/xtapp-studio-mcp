# XTApp Studio 项目备份

- 导出时间：2026-08-08T09:00:07.540Z
- 项目：中国象棋
- 格式：xtapp-studio-project-archive v1

可将此 ZIP 通过 Studio 的“导入项目 ZIP”恢复为一个新项目副本。
它是代码与素材快照：不包含 AI 对话、模型设置或临时运行状态。
项目源码位于 `project-files/`，原图与运行时 XIC 素材位于 `assets/`。

头像运行时素材保持为设备兼容的 1bpp XIC，并通过 4x4 有序网点表现四档明暗。修改 `raw/` 原图后，可在仓库根目录执行：

## 长任务看门狗

人机对弈的 AI 搜索在当前这次 `on_tick` 里同步完成。开始前延长当前回调的时间预算，请用返回值，不要假设失败会抛错：

```lua
local ok, err = ctx.budget:extend()
```

- 每次 `extend()` 把当前回调的截止时间推到 11 秒后，单个回调最长 30 秒；`extend` 只对当前回调有效。
- 本应用单次决策预算是 2 秒。单次同步 `on_tick` 墙钟建议不超过 10 秒。
- 文案含 `watchdog` 或 `time budget` 的错误必须原样再抛；禁止捕获后 `extend()` 再继续算。
- 正常算出结果只清理应用侧切片状态（`Watchdog.finish()`）。
