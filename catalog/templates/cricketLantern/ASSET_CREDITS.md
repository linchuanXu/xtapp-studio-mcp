# 美术素材状态

《灯下促织》故事美术已按 `raw/*.md` 提示词生成原创水墨线稿，并编码为 1bpp XIC。

- `raw/bg_*.png` / `raw/char_*.png` / `raw/ending_*.png`：场景、立绘与结局卡原图。
- `raw/*.md`：各槽位尺寸、构图与生图提示词（可复现）。
- `assets/*.xic`：由 `encode-cricket-lantern-assets.mjs` 按 [PORTRAIT_PIPELINE.md](PORTRAIT_PIPELINE.md) 编码（背景/结局 50% 抖点；立绘背景透明）。
- UI 与应用图标仍来自 `raw/ui_*.svg` 与既有图标编码。

若需换稿：替换同名 PNG 后重新运行编码与 catalog 构建，再发布前端构建。
