# 卡牌游戏样例

这是一个可以直接试玩的 XTApp，同时也是卡牌游戏运行时的参考实现。内置「墨牌试局」只用于证明引擎接口，不代表引擎只支持血量制对战。

## 试玩规则

- 双方各有独立牌库、隐藏手牌和公开弃牌区。
- 每回合获得 3 点墨力，可以连续打出攻击、防御或抽牌牌。
- 点击「收笔」结束回合；先把对方生命降为 0 的一方获胜。

## 模块边界

```text
index.lua                    组合根，只连接 XTApp 生命周期与样例 Runtime
app/sample_runtime.lua       页面、输入、AI tick 与结果展示
ui/sample_layout.lua         纯布局与命中测试
ui/sample_view.lua           只读取信息安全的 View，不接触完整 Match
games/duel_cards.lua         样例牌定义
games/duel_rules.lua         样例规则插件
games/duel_ai.lua            只读取 AI 自己的投影视图
core/card_engine.lua         原子行动、插件调度、事件输出
core/card_state.lua          玩家、牌实例、区域、位置与不变量
core/card_projection.lua     公共/所有者/私有区域的信息隔离
core/card_rng.lua            可重放的确定性随机
```

## 核心契约

通用核心不内置以下概念：

- 扑克牌花色、点数或牌型
- UNO 的颜色匹配和功能牌
- 德州扑克的盲注、下注池和摊牌
- 炉石式生命、费用、随从和触发器
- 杀戮尖塔式能量、遗物、状态和路线

每款游戏通过规则插件提供：

```lua
rules.spec(options)             -- 初始参与者、回合和自定义数据
rules.setup(state, ctx)         -- 创建区域、牌实例和初始局面
rules.actions(state, actor)     -- 当前合法行动
rules.validate(state, action)   -- 行动校验，不修改状态
rules.reduce(state, action, ctx)-- 在事务草稿上执行并发出事件
rules.describe_card(def_id)     -- 可见牌的呈现数据
rules.project(state, view, who) -- 可选的公开投影扩展
```

`card_engine.apply` 会复制当前状态，在草稿上执行行动，验证每张牌只存在于一个区域、位置索引一致，再提交新修订。如果规则抛错或破坏不变量，旧状态保持不变。

`actions` 和 `validate` 也只接收状态副本；即使插件错误地在“查询合法行动”或“校验”阶段修改数据，也不会污染权威状态。对局自定义数据、区域元数据和玩家数据都明确分为 `public` / `private`，投影层只自动复制公开部分。

区域可见性有三档：

- `public`：所有观察者看到完整牌实例。
- `owner`：仅所属玩家看到完整内容，其他玩家只看到数量。
- `private`：任何玩家都只看到数量，供牌库、随机池等系统区域使用。

因此 AI 和 UI 可以只接收 `engine.view(state, viewer)`，不会意外偷看对手手牌或牌库顺序。

## 后续游戏的适配方向

| 游戏 | 规则插件需要新增的内容 | 核心是否需要改动 |
| --- | --- | --- |
| UNO 类 | 颜色/数字匹配、方向、跳过、摸牌堆 | 否 |
| 德州扑克 | 公共牌区、下注阶段、筹码池、牌型结算 | 否 |
| 炉石式对战 | 场上区域、目标选择、触发队列、持续效果 | 可能增加通用效果栈，但不应写进基础状态 |
| 杀戮尖塔式构筑 | 战斗外地图、永久牌组、遗物、敌人意图 | 战役元状态应作为独立层，不塞进单局引擎 |

只有两款以上游戏都需要、且语义一致的能力，才应从插件上提到核心层。
