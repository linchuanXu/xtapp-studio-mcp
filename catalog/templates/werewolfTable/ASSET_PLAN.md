# 美术槽位规范

故事美术已按提示词生成原创黑白线稿，并编码为 1bpp XIC。换稿时替换同名 PNG 后运行 `encode-werewolf-table-assets.mjs`。

| 槽位 | 尺寸 | 用途 |
| --- | --- | --- |
| `bg_table_day` | 480×600 | 白天圆桌与九张座椅 |
| `bg_table_night` | 480×600 | 夜晚闭合的圆桌与月影 |
| `bg_result` | 400×200 | 阵营胜利结算卡 |
| `event_card` | 176×264 | 无具体角色时的桌面事件舞台卡 |
| `char_*` | 36×36 | 九位桌上角色的座位头像（白底线稿） |
| `char_*_stage` | 176×264 | 当前发言者的舞台半身像；源图为 `raw/char_*_stage.png`，不能从 36px 座位图放大 |
| `ui_*` | 按组件尺寸 | 纯黑白界面 |

场景提示词见 `raw/bg_*.md`；座位头像见 `raw/char_*.png`；舞台像见 `raw/char_*_stage.png`；事件卡见 `raw/event_card.png`。
