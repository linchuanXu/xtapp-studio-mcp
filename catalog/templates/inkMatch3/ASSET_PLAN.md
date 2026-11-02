# 果蔬消消乐素材计划

## 视觉原则

- 棋子使用常见水果和蔬菜的成熟图标：苹果、葡萄、樱桃、胡萝卜、玉米、蘑菇。
- 1bpp 设备上优先保留清楚的果蔬形状与特征；不依赖颜色、山水纹样或细碎纹理辨识。
- 果蔬与农夫保留彩色 PNG 原图；真机 XIC 在最后一步以抖动转为 1bpp，细节见 [raw/SOURCES.md](raw/SOURCES.md)。
- 游戏不使用《开心消消乐》的名称、角色、原画、音效、文案或关卡布局；只借鉴行业通行的交换三消规则。

## 素材槽位

| 类别 | Key | 官方 MDI 源 | 尺寸 |
|---|---|---|---:|
| 普通棋子 | `tile_apple` | Noto Emoji 彩色果蔬 | 52×52 |
| 普通棋子 | `tile_grape` | Noto Emoji 彩色果蔬 | 52×52 |
| 普通棋子 | `tile_cherry` | Noto Emoji 彩色果蔬 | 52×52 |
| 普通棋子 | `tile_carrot` / `tile_corn` / `tile_mushroom` | Noto Emoji 彩色果蔬 | 52×52 |
| 角色与场景 | `hero_farmer` / `prop_tomato` / `prop_water` | Noto Emoji / Free Farm Assets 2D 彩色原图 | 80–148 px |
| 特殊棋子 | `tile_row` / `tile_col` | 粗横向 / 纵向箭头 | 52×52 |
| 特殊棋子 | `tile_blast` / `tile_color` | `bomb` / `palette-swatch` | 52×52 |
| 障碍与目标 | `ui_ice` / `ui_lock` / `ui_rock` / `ui_weed` / `ui_basket` | 雪花、锁、宝石、草、篮子 | 52×52 |
| 道具与反馈 | `ui_hint` / `ui_shuffle` / `ui_star` / `ui_victory` / `ui_defeat` | 灯泡、重排、奖杯、幼苗 | 40–160 px |
| 品牌 | `ui_logo` / `app_icon_l` / `app_icon_s` / `splash` | 已下载果蔬 SVG 的位图合成 | 多尺寸 |

执行：在 XTApp Studio 中重新生成素材并检查预览。
