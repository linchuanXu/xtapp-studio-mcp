-- 《雨夜画廊》：原创成人恋爱互动短章。
-- 所有台词已按 X4 竖屏对话框预折行；三条路线只改数据，不改文游引擎。

local M = {}

M.title = "雨夜画廊"
M.start_id = "opening"
M.default_vars = { yanxu = 0, chenyuan = 0, linyu = 0 }
M.status_vars = { "yanxu", "chenyuan", "linyu" }
M.status_labels = { yanxu = "严叙", chenyuan = "陈远", linyu = "林屿" }
M.status_meanings = {
  yanxu = "克制而清醒的默契",
  chenyuan = "轻快而直接的靠近",
  linyu = "安静而敏锐的共鸣",
}

M.nodes = {
  opening = {
    chapter = "第一夜 · 雨落之后",
    checkpoint = "画廊开场",
    scene = {
      bg = "bg_gallery_rain",
      cast = { { id = "suyue", asset = "char_suyue", slot = "center", expression = "watching" } },
    },
    speaker = "苏月",
    title = "闭馆后的来客",
    lines = {
      "雨把画廊困在夜色里。",
      "你正要关灯，门铃响了。",
      "三位来客隔着玻璃望向你。",
      "这一晚，似乎还没结束。",
      "你决定先听从自己的直觉。",
    },
    choices = {
      { text = "请风衣男人进来", next = "yanxu_meet" },
      { text = "替运动男孩撑伞", next = "chenyuan_meet" },
      { text = "询问长发画家", next = "linyu_meet" },
    },
  },

  yanxu_meet = {
    chapter = "第一夜 · 严叙",
    checkpoint = "遇见严叙",
    scene = {
      cast = { { id = "yanxu", asset = "char_yanxu", slot = "center", expression = "calm" } },
    },
    speaker = "严叙",
    title = "没带伞的人",
    effects = { flags = { "met_yanxu" }, vars = { yanxu = 1 } },
    lines = {
      "“我只是想再看一眼这幅画。”",
      "他说话很轻，像怕惊动夜雨。",
      "窗外的灯映进他的眼睛里。",
    },
    choices = {
      { text = "问他看见了什么", next = "yanxu_close", effects = { vars = { yanxu = 1 } } },
      { text = "替他倒一杯热茶", next = "yanxu_close" },
    },
  },

  chenyuan_meet = {
    chapter = "第一夜 · 陈远",
    checkpoint = "遇见陈远",
    scene = {
      cast = { { id = "chenyuan", asset = "char_chenyuan", slot = "center", expression = "warm" } },
    },
    speaker = "陈远",
    title = "被雨打乱的训练",
    effects = { flags = { "met_chenyuan" }, vars = { chenyuan = 1 } },
    lines = {
      "“抱歉，我把这里当成避雨处了。”",
      "他笑着收起湿透的伞。",
      "连沉默的展厅也亮了一点。",
    },
    choices = {
      { text = "请他挑一幅喜欢的画", next = "chenyuan_close", effects = { vars = { chenyuan = 1 } } },
      { text = "笑着说没关系", next = "chenyuan_close" },
    },
  },

  linyu_meet = {
    chapter = "第一夜 · 林屿",
    checkpoint = "遇见林屿",
    scene = {
      cast = { { id = "linyu", asset = "char_linyu", slot = "center", expression = "quiet" } },
    },
    speaker = "林屿",
    title = "画框前的陌生人",
    effects = { flags = { "met_linyu" }, vars = { linyu = 1 } },
    lines = {
      "“这幅画还没完成。”他忽然说。",
      "你顺着他的目光看向留白处。",
      "雨声里，有什么被轻轻说破。",
    },
    choices = {
      { text = "问他会怎样画完", next = "linyu_close", effects = { vars = { linyu = 1 } } },
      { text = "邀请他留下名字", next = "linyu_close" },
    },
  },

  yanxu_close = {
    chapter = "第一夜 · 回应",
    scene = { cast = { { id = "yanxu", asset = "char_yanxu", slot = "center", expression = "calm" } } },
    speaker = "严叙",
    title = "雨停之前",
    lines = {
      "“我看见一个愿意等人的人。”",
      "他把杯子放回桌上。",
      "“下次，我想在晴天来。”",
    },
    choices = { { text = "答应和他再见", next = "ending_yanxu" } },
  },

  chenyuan_close = {
    chapter = "第一夜 · 回应",
    scene = { cast = { { id = "chenyuan", asset = "char_chenyuan", slot = "center", expression = "warm" } } },
    speaker = "陈远",
    title = "雨停之前",
    lines = {
      "他挑了一幅最明亮的画。",
      "“下次我带你去看真的日出。”",
      "他伸出手，等你的回答。",
    },
    choices = { { text = "把手交给他", next = "ending_chenyuan" } },
  },

  linyu_close = {
    chapter = "第一夜 · 回应",
    scene = { cast = { { id = "linyu", asset = "char_linyu", slot = "center", expression = "quiet" } } },
    speaker = "林屿",
    title = "雨停之前",
    lines = {
      "“留白不是结束，是邀请。”",
      "他在票根背面写下一个地址。",
      "“如果愿意，就来看看我的画室。”",
    },
    choices = { { text = "收下那张票根", next = "ending_linyu" } },
  },

  ending_yanxu = {
    chapter = "终章 · 晴天再见",
    bg = "bg_gallery_rain",
    char = "char_yanxu",
    lines = { "雨停时，他没有立刻离开。", "你们约好，在晴天再见。" },
    ending = {
      name = "晴天再见",
      image = "ending_moonlit",
      summary = { "一段克制的默契，", "从雨夜开始有了下文。" },
    },
    choices = { { text = "从头开始", next = "__restart" } },
  },

  ending_chenyuan = {
    chapter = "终章 · 日出之前",
    bg = "bg_gallery_rain",
    char = "char_chenyuan",
    lines = { "他把伞向你倾斜。", "街灯外，天快要亮了。" },
    ending = {
      name = "日出之前",
      image = "ending_moonlit",
      summary = { "一份坦率的邀请，", "让雨夜有了新的方向。" },
    },
    choices = { { text = "从头开始", next = "__restart" } },
  },

  ending_linyu = {
    chapter = "终章 · 留白之处",
    bg = "bg_gallery_rain",
    char = "char_linyu",
    lines = { "票根被你放进了口袋。", "那片留白，等着下一次落笔。" },
    ending = {
      name = "留白之处",
      image = "ending_moonlit",
      summary = { "安静的共鸣没有说尽，", "却留下再见的理由。" },
    },
    choices = { { text = "从头开始", next = "__restart" } },
  },
}

return M
