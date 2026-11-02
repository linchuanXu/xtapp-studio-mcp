# 文游基座（WebGAL Kit）

面向 X4 Pro 的**可复用文字游戏基座 Demo**。交互分层借鉴 [WebGAL](https://github.com/OpenWebGAL/WebGAL)（背景 → 立绘 → 姓名框/对话框 → 选项 → 变量），在墨水屏上做可读、可点、可存的最小完备集。

本仓库**不是**任何橙光商用作品的移植；示例剧情为 Studio 原创短章，仅示范结构。

## 怎么玩

- **点舞台/对话框**：每页固定最多四行；读完节点才出现选项
- **点悬浮选项**：推进分支（最多 4 个，叠在画面中下部）
- **点右上角图标**：进入状态明细、逐页阅读记录与章节书签；再次点图标或点面板外返回。状态始终是一变量一行，超过 5 项可翻页，不会挤成一行。

布局借鉴橙光常见结构（底栏对话、角菜单、中浮选项），按竖屏墨水屏做了不透明化与比例适配。

## 模块边界（高内聚 / 低耦合）

```text
index.lua                 组合根：require 剧本 + VN.create
domain/story_*.lua        纯数据：节点图、default_vars、status_vars
domain/vn_runtime.lua     装配：create(opts) → boot / on_input / on_draw
domain/vn_engine.lua      会话：状态、效果、翻页、选项过滤、导航（不碰绘图）
domain/vn_view.lua        呈现：只读 engine 状态并绘制
domain/vn_layout.lua      几何：槽位尺寸、compute、命中测试
```

引擎**从不** `require` 具体剧本。换新作只改 `index.lua` 里的 Story 引用与 `state_key`。

## 开新游戏（换皮流程）

1. 复制本模板目录为新项目  
2. 改 `manifest.json` 的 `app_id` / `display_name`  
3. 新建 `domain/story_xxx.lua`（实现下方契约），在 `index.lua` 里 `require` 并传入 `VN.create`  
4. 按槽位替换 `raw/` 图并在 XTApp Studio 中重新编码 XIC  

`index.lua` 接线示例：

```lua
local Story = require("domain.story_xxx")
local VN = require("domain.vn_runtime")
local App = VN.create({ story = Story, state_key = "my_game" })
```

## 剧本契约

加载时会验证 `start_id`、每个 `next`、预折行台词、场景/角色字段、变量效果和选项结构。正文按固件固定 **20px** 字体保留左右安全区，单行最多约 **17 个中文宽度单位**；超宽台词、标题或选项会在启动时被拒绝。单个节点最多声明 **4 个**选项；错误的节点名、变量类型或超量选项会阻止应用启动，而不会在运行中静默跳回开场或丢掉内容。

旧作品继续使用 `bg` 与 `char`（居中单立绘）。新作品可使用 `scene`：`scene.bg` 仅在声明时切换背景，后续 `scene` 可继承它；`scene.cast` 替换舞台角色，最多三名，槽位只能是 `left` / `center` / `right` 且不可重复。每名角色以显式素材 `asset` 表达当前表情或姿态，`expression` 是供剧情与工具读取的语义标签。

运行时会自动保留最近 32 页已读内容，菜单中可逐页回看。节点可加 `checkpoint = true` 或短标签字符串来建立最多 6 个章节书签；书签保存当时的节点、页码、变量、旗标和阅读记录，恢复书签不会把之后分支的状态带回过去。所有内容仍只在宿主退出时由 `ctx.state` 持久化。

```lua
return {
  title = "游戏名",
  start_id = "boot",
  default_vars = { affection = 0 },   -- 重开 / 缺省补齐
  status_vars = { "affection" },      -- 状态面板展示顺序；可省略则按 default_vars 键名排序
  status_labels = { affection = "好感" }, -- 可选：状态面板的人类可读名称（单项一行，名称请保持简短）
  status_meanings = { affection = "影响部分结局反馈" }, -- 可选：状态项的短说明
  nodes = {
    boot = {
      chapter = "章名",
      checkpoint = "第一章",          -- 可选：true 或短标签；保存可恢复的章节快照
      -- 旧式单立绘：bg = "bg_campus", char = "char_guide"
      -- 新式静态舞台（与旧式 bg/char 二选一）：
      scene = {
        bg = "bg_classroom",           -- 后续 scene 未声明时继承
        cast = {
          { id = "guide", asset = "char_guide", slot = "left", expression = "calm" },
          { id = "visitor", asset = "char_visitor_smile", slot = "right", expression = "smile" },
        },
      },
      speaker = "向导",               -- 可选；有则画姓名框
      title = "小节标题",
      lines = { "预折行 1", "预折行 2" },
      effects = { flags = { "met" }, vars = { affection = 1 }, set = { affection = 3 } },
      choices = {
        {
          text = "选项",
          next = "other_node",        -- 或 "__restart" 清空并回 start_id
          effects = { … },
          when = "flag",              -- 需已点亮
          unless = "flag",            -- 已点亮则隐藏
          min_var = { affection = 2 },
          -- 新式组合条件；旧字段 when / unless / min_var 仍兼容：
          requires = {
            all_flags = { "met" },
            none_flags = { "refused" },
            any_flags = { "read_note", "asked_guide" },
            min_vars = { affection = 2 },
            max_vars = { suspicion = 3 },
            equals = { route = "guide" },
          },
        },
      },
    },
    ending = {
      chapter = "终章",
      lines = { "先让玩家读完这段收束。" },
      ending = {
        name = "雨后的站台",
        image = "ending_station", -- 400×200 的不透明结算卡
        summary = { "你把秘密留在了雨里。", "故事暂告一段落。" },
        notes = {
          { text = "你选择了相信对方。", when = "trusted" },
          { text = "线索收集完整。", requires = { min_vars = { clues = 3 } } },
        },
      },
      -- 结算页固定只保留一个重开入口；引擎会校验此约定。
      choices = { { text = "从头开始", next = "__restart" } },
    },
  },
}
```

## 素材槽位（原生尺寸，禁止拉扁）

| 类型 | 尺寸 | 说明 |
| --- | --- | --- |
| 场景 `bg_*` | **480×600** | 竖幅舞台；由编码器从原图预裁切，运行时不再依赖越界裁切 |
| 立绘 `char_*` | **280×400** | 透明背景原图；打包器保留透明通道，人物内部的白色保持不透明 |
| 结算卡 `ending_*` | **400×200** | 独立、不透明的结局插图；在节点 `ending.image` 引用并加入 `preload_assets` |
| `ui_menu` | 52×52 | 右上角无底卡的设置滑杆图标（触控热区仍为 52×52） |
| `ui_dialog` | 448×188 | 阅读态底栏对话框：固定四行正文，标题、正文、继续提示各自有安全区 |
| `ui_dialog_choice` | 448×188 | 选项态与阅读态等高；舞台不因翻页或选项出现而变形 |
| `ui_nameplate` | 148×34 | 姓名框 |
| `ui_choice` / `ui_choice_on` | 384×52 | 中浮选项；触控槽位 62 高 |
| `ui_panel` | 448×680 | 状态面板 |

前景立绘的透明背景处理与预览检查步骤见 [PORTRAIT_PIPELINE.md](PORTRAIT_PIPELINE.md)。背景和角色细节统一使用 **50%** 强度抖色。

最后一条会以 Lua token 读取声明式剧本（不会把注释或台词误判成字段），检查起点、跳转目标、不可达节点，以及剧本引用的背景/立绘/结算卡是否全部列入 `manifest.preload_assets`；它兼容 `M.xxx = ...; return M` 和上方的 `return { ... }` 两种写法。新作品可传入自己的 `domain/story_xxx.lua` 相对路径。
