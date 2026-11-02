# 斗地主

面向 X4 Pro 的单机斗地主：1 真人 + 2 托管 AI，在 800×480 横屏墨水屏上完整打一局。

## 界面（横屏布局）

```
┌──────────────────────────────────────────────┐
│ 地主 / 底牌 / 倍数                         ··· │  ← 状态条与三点菜单
│  左家已出牌              本墩桌面              右家已出牌 │
│                  当前回合说明                    │
│                 出牌 / 不要 / 提示                │  ← 仅显示当前可用动作
│  ┌────────────────────────────┐              │
│  │ 人物在牌下层 · 你的手牌（横排大槽） │              │  ← 玩家手牌
│  └────────────────────────────┘              │
└──────────────────────────────────────────────┘
```

## 玩法

- **对手强度**：封面后可选新手、休闲、挑战，整局固定；三档都使用完整策略，但候选数量、残局搜索深度和拆牌容忍度逐档提高。
- **叫地主**：按座位轮流叫 1/2/3 分或过，3 分即定地主；AI 按手牌强度（王炸/炸弹/大牌加权）叫分。
- **出牌**：点按手牌选中（再点取消），「出牌」打出；「提示」一键选出能压上家的最小牌；无牌可压时只显示「不要」，不会保留无效选择。
- **规则**：全部核心牌型——单张、对子、三带一/二、顺子（≥5 不含 2 与王）、连对、飞机（带单/带对）、四带二、炸弹、王炸；王炸 > 炸弹 > 普通牌，同型同张数才可比。
- **结算**：任意一家出完即结束；炸弹、王炸、春天/反春都会真实累乘倍数，并用全屏局势宣告确认发生者与结果。
- **局势反馈**：每一墩的出牌与“不出”会保留在各自座位旁，直到下一墩领出才清空；定地主、炸弹、王炸、春天/反春、胜负依次以大字事件卡展示；AI 每次只推进一手，方便围桌观看。
- **牌型演出**：飞机、四带二等特效播放时会暂时收起操作区；演出结束后才恢复出牌、不要与提示，避免控件干扰画面。
- **暂停与重开**：真人可操作时点右上角三点，可继续当前牌局、查看快速规则、按当前难度重新开始或返回封面；暂停不会丢失手牌和回合。

## AI 公平边界

策略模块只接收当前 AI 自己的手牌与 `public_game_view`：公开身份、余牌数、当前待压牌、本墩动作、历史已出牌和已亮底牌。真人与另一位 AI 的隐藏手牌不会进入策略参数；挑战档的“记牌”只是统计公开牌，不会读取或定位隐藏牌。

## 目录结构

```
doudizhu/
├── manifest.json          # XTApp 2.x manifest
├── index.lua              # UI / 状态机 / 输入（menu→difficulty→bid→play↔pause→result）
├── domain/
│   ├── doudizhu_rules.lua          # 判型、比较、可压牌生成、合法性校验
│   ├── doudizhu_difficulty.lua     # 三档参数与能力开关
│   ├── doudizhu_public_view.lua    # 隐藏信息隔离与公开记牌
│   ├── doudizhu_hand_evaluator.lua # 候选枚举、手数与拆牌质量
│   ├── doudizhu_lead_strategy.lua  # 首出评分
│   ├── doudizhu_follow_strategy.lua# 压制、过牌与炸弹使用
│   ├── doudizhu_team_strategy.lua  # 地主目标与农民协作
│   ├── doudizhu_endgame_strategy.lua # 少牌有限搜索
│   └── doudizhu_ai.lua             # 发牌与对局状态推进
├── assets/                # 1bpp XIC 素材（encode-doudizhu-assets.mjs 生成）
└── raw/                   # 素材原始 SVG 与许可（见 ASSET_SOURCES.md）
```

## 测试

## 素材与许可

牌面素材来自 [hayeah/playing-cards-assets](https://github.com/hayeah/playing-cards-assets)（MIT，Howard Yeh 2018），
牌背来自 [tekeye.uk SVG Playing Cards](https://tekeye.uk/playing_cards/svg-playing-cards)（Public Domain）。
详细来源与转换说明见 `raw/ASSET_SOURCES.md`；MIT 许可原文见 `raw/hayeah-mit/LICENSE.txt`。

## 参考实现

规则与 AI 借鉴以下开源项目（均为思路借鉴，代码为原创 Lua 实现）：

- [donnki/ddz_skynet](https://github.com/donnki/ddz_skynet)（Lua 判型思路）
- [onestraw/doudizhu](https://github.com/onestraw/doudizhu)（MIT，枚举查表思路）
- [datamllab/rlcard](https://github.com/datamllab/rlcard)（MIT，`get_landlord_score` 叫分启发式）
- [ZhouWeikuan/DouDiZhu](https://github.com/ZhouWeikuan/DouDiZhu)（Apache-2.0，权重跟牌思路）
