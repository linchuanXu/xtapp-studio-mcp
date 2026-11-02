-- Demo chapter inspired by the WebGAL public demo structure
-- (welcome → figure → choose branches → merge). Original Chinese copy for XTApp.
-- See NOTICE.md for WebGAL attribution (MPL-2.0 engine; this story is Studio-authored).

-- Story table contract for vn_runtime.create({ story = M }):
--   title, start_id, nodes               required
--   default_vars                         reset / missing-key defaults
--   status_vars                          ordered keys for the status panel
-- Keep each line ≤ ~18 Chinese chars for the 448-wide dialog slot.

local M = {}
M.title = "文游基座 Demo"
M.start_id = "boot"
M.default_vars = { curiosity = 0, met_guide = 0, met_visitor = 0, insight = 0, archive = 0 }
M.status_vars = { "curiosity", "met_guide", "met_visitor", "insight", "archive" }
M.status_labels = { curiosity = "探索", met_guide = "向导", met_visitor = "访客", insight = "线索", archive = "归档" }
M.status_meanings = {
  curiosity = "主动查看过的路径",
  met_guide = "是否与向导交谈",
  met_visitor = "是否体验多人舞台",
  insight = "可用于解锁的线索",
  archive = "保存的舞台笔记",
}

M.nodes = {
  boot = {
    chapter = "Demo · 开场",
    checkpoint = "Demo 开场",
    bg = "bg_campus",
    title = "链接已打开",
    lines = {
      "你好，欢迎来到文字游戏基座。",
      "没有花哨特效，只留常用演出层。",
      "背景、立绘、对话框、选项与变量。",
      "换剧本和素材，就能开新作。",
    },
    choices = {
      { text = "进入演示", next = "meet", effects = { vars = { curiosity = 1 } } },
    },
  },

  meet = {
    chapter = "Demo · 向导",
    checkpoint = "遇见向导",
    scene = {
      bg = "bg_classroom",
      cast = { { id = "guide", asset = "char_guide", slot = "center", expression = "calm" } },
    },
    speaker = "向导",
    title = "第一次见面",
    effects = { vars = { met_guide = 1 }, flags = { "met_guide" } },
    lines = {
      "我是示例向导，可改成你的角色名。",
      "点画面翻页；读完后出现选项。",
      "右上角图标可查看变量与记录。",
    },
    choices = {
      { text = "了解基座能做什么", next = "capabilities" },
      { text = "直接看分支示范", next = "branch_hub", effects = { vars = { curiosity = 1 } } },
    },
  },

  capabilities = {
    chapter = "Demo · 能力",
    bg = "bg_classroom",
    char = "char_guide",
    speaker = "向导",
    title = "作者合同",
    lines = {
      "节点填写：bg、char、",
      "lines、choices。",
      "场景 448×480，",
      "立绘 280×400 白底。",
      "按原生比例装槽，不要把图拉扁。",
    },
    choices = {
      { text = "看看双人舞台", next = "briefing" },
    },
  },

  briefing = {
    chapter = "Demo · 对谈",
    checkpoint = "两人对谈",
    scene = {
      bg = "bg_classroom",
      cast = {
        { id = "guide", asset = "char_guide", slot = "left", expression = "calm" },
        { id = "visitor", asset = "char_visitor", slot = "right", expression = "watching" },
      },
    },
    speaker = "访客",
    title = "舞台也能多人",
    effects = { flags = { "met_visitor" }, vars = { met_visitor = 1, insight = 1 } },
    lines = {
      "一张 scene 可放三名角色。",
      "角色各占固定槽位，",
      "换表情只替换对应 asset。",
      "先看完，再进入分支档案。",
    },
    choices = {
      { text = "进入分支档案", next = "branch_hub" },
    },
  },

  branch_hub = {
    chapter = "Demo · 分支",
    checkpoint = "选择分支",
    bg = "bg_campus",
    char = "char_guide",
    speaker = "向导",
    title = "两条了解路径",
    lines = {
      "选项拆成两条支线，再汇合结尾。",
      "choices 可挂 effects，",
      "改变量与 flag。",
    },
    choices = {
      { text = "发展历程（结构向）", next = "path_history", effects = { flags = { "saw_history" }, vars = { curiosity = 1 } } },
      { text = "冷知识（轻量向）", next = "path_trivia", effects = { flags = { "saw_trivia" }, vars = { curiosity = 1 } } },
      { text = "多人舞台笔记", next = "path_archive", effects = { flags = { "saw_archive" }, vars = { archive = 1 } }, requires = { all_flags = { "met_visitor" }, min_vars = { insight = 1 } } },
    },
  },

  path_history = {
    chapter = "Demo · 历程",
    bg = "bg_classroom",
    char = "char_guide",
    speaker = "向导",
    title = "为什么要有基座",
    lines = {
      "WebGAL 让人快速做出，",
      "网页视觉小说。",
      "这里目标一样：换剧本素材就能发。",
      "墨水屏优先可读、可点、可存。",
    },
    choices = {
      { text = "汇合到结尾", next = "ending" },
    },
  },

  path_trivia = {
    chapter = "Demo · 冷知识",
    bg = "bg_campus",
    char = "char_guide",
    speaker = "向导",
    title = "制作提示",
    lines = {
      "立绘用白底，才能叠在场景上。",
      "选项文案请预折行，勿靠自动换行。",
      "先跑通 20～30 节点，再扩长线。",
    },
    choices = {
      { text = "汇合到结尾", next = "ending" },
    },
  },

  path_archive = {
    chapter = "Demo · 档案",
    checkpoint = "多人舞台笔记",
    scene = {
      cast = {
        { id = "guide", asset = "char_guide", slot = "left", expression = "calm" },
        { id = "archivist", asset = "char_archivist", slot = "center", expression = "thinking" },
        { id = "visitor", asset = "char_visitor", slot = "right", expression = "noting" },
      },
    },
    speaker = "档案员",
    title = "可复用的场景",
    lines = {
      "角色可换 asset，",
      "不必改引擎或布局。",
      "书签会一并保存舞台、",
      "变量与分支位置。",
    },
    choices = {
      { text = "汇合到结尾", next = "ending" },
    },
  },

  ending = {
    chapter = "Demo · 终章",
    bg = "bg_campus",
    char = "char_guide",
    speaker = "向导",
    title = "可以开新作了",
    ending = {
      name = "基座已就绪",
      image = "ending_demo",
      summary = {
        "你完成了阅读、分支与回流。",
        "下一步只需替换 story 与素材。",
      },
      notes = {
        { text = "你已确认可保存分页进度。" },
        { text = "多人舞台已写入档案。", when = "met_visitor" },
        { text = "条件选项由变量与 flag 控制。", requires = { min_vars = { insight = 1 } } },
      },
    },
    lines = {
      "你走完了开场、立绘、分支、汇合。",
      "复制工程，改 story，",
      "与 assets 即可。",
      "点右上角图标可再确认变量。",
    },
    choices = {
      { text = "重看演示", next = "__restart" },
    },
  },
}

return M
