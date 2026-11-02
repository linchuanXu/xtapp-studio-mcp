# 素材槽位与换稿说明

棋子与商店图标已按本清单生成原创黑白线稿，并编码为 1bpp XIC。换稿时替换 `raw/` 同名 PNG，再运行：

## 统一风格

- 设备：X4，480×800 竖屏，1bpp 黑白墨水屏。
- 画法：纯白底、粗黑钢笔线描、高对比、无灰阶渐变、无文字、无商标、无上游或现成游戏角色。
- 棋子：保留约 4px 内边距；外框由 `index.lua` 绘制。

## 槽位

| 槽位 | 尺寸 | 数量 | 用途 | 源文件 |
| --- | --- | ---: | --- | --- |
| `tile_leaf` … `tile_moon` | 54×64 | 9 | 九种棋子 | `raw/tile_*.png` |
| `app_icon_l` | 128×128 | 1 | 商店大图标 | `raw/app_icon.png` |
| `app_icon_s` | 64×64 | 1 | 商店小图标 | `raw/app_icon.png` |

棋子键名顺序（与 `TILE_KEYS` 一致）：`leaf`、`flower`、`fruit`、`bell`、`cloud`、`star`、`pot`、`umbrella`、`moon`。提示词见同名 `raw/*.md`。

## UI 线稿

`ui_logo`、`ui_menu_panel`、`ui_button`、`ui_level_cell`、`ui_tray_slot`、三种 `ui_tool_*` 与 `ui_state_panel` 已生成原创线稿并接入运行时。尺寸、生图提示词与换稿步骤见 [raw/UI_ASSET_PROMPTS.md](raw/UI_ASSET_PROMPTS.md)。
