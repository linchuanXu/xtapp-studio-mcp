-- 《灯下促织》
-- 原创互动改编：仅取材自蒲松龄《聊斋志异·促织》的困境与题材，
-- 不复用原文台词；具体人物、分支、文案均为本项目原创。

local M = {}
M.title = "灯下促织"
M.start_id = "boot"
M.default_vars = { folk = 0, home = 0, proof = 0, cricket = 0 }
M.status_vars = { "folk", "home", "proof", "cricket" }
M.status_labels = { folk = "人心", home = "阿蘅", proof = "账证", cricket = "虫笼" }
M.status_meanings = {
  folk = "肯同你把话说到底的人",
  home = "阿蘅还愿不愿同你并肩",
  proof = "能把谎话钉在账上的凭据",
  cricket = "与县衙谈判的筹码",
}

M.nodes = {
  boot = {
    chapter = "第一夜 · 灯下",
    checkpoint = "第一夜",
    bg = "bg_village_night",
    title = "县令的竹笼",
    lines = {
      "差役把空竹笼搁在门槛上。",
      "“三日。交不上虫，你跟我走。”",
      "你说去年已经交过，他只笑了一声。",
      "里屋的阿蘅咳了两下，门闩轻响。",
      "风把灯火吹得一歪。",
    },
    choices = {
      { text = "关门，先问阿蘅：你听见了？", next = "home_first", effects = { vars = { home = 1 } } },
      { text = "按住竹笼：去年那只记谁账？", next = "footprints" },
    },
  },

  home_first = {
    chapter = "第一夜 · 灯下",
    bg = "bg_village_night",
    char = "char_aheng",
    speaker = "阿蘅",
    title = "灯芯将尽",
    effects = { flags = { "promised_home" } },
    lines = {
      "阿蘅没有先问差役说了什么。",
      "她把你的手按在灯边：“先暖一暖。”",
      "你想抽回去，她却摸到笼底的湿泥。",
      "“这泥在荒园西墙，不在县衙。”",
    },
    choices = {
      { text = "“你早知道他们会来？”", next = "home_debt" },
    },
  },

  footprints = {
    chapter = "第一夜 · 巷口", bg = "bg_village_night", title = "泥水脚印",
    lines = { "差役没答，只把手从竹笼上掰开。", "他转进巷子，脚印停在隔壁柴门前。", "门里压着哭声：“又轮到谁？”", "你抬手，里面忽然静了。" },
    choices = { { text = "敲门：是我，别把话咽回去。", next = "neighbor", effects = { vars = { folk = 1 } } }, { text = "先回屋，阿蘅比答案更要紧。", next = "home_first" } },
  },

  home_debt = {
    chapter = "第一夜 · 灯下", bg = "bg_village_night", char = "char_aheng", speaker = "阿蘅", title = "旧欠条",
    lines = { "阿蘅从米缸底摸出一张旧欠条。", "“去年交虫那天，我替你按过指印。”", "纸上写着已交，今年却又写了一遍。", "她把纸推来：“园丁见过这种红印。”" },
    choices = { { text = "收起欠条：去荒园问园丁。", next = "garden", effects = { vars = { home = 1 }, flags = { "old_debt" } } }, { text = "把欠条压回去：去市集看虫价。", next = "market", effects = { flags = { "old_debt" } } } },
  },

  neighbor = {
    chapter = "第一夜 · 隔壁", bg = "bg_village_night", title = "空竹笼",
    lines = { "门只开了一掌宽，孩子躲在身后。", "邻人递来断扣空笼：“去年交过。”", "“账上未销。可我们不能去县衙。”", "他看着你，等你把声音压低。" },
    choices = { { text = "接过空笼：名字和话都记下。", next = "home_first", effects = { vars = { folk = 1 }, flags = { "neighbor_word" } } }, { text = "“今夜别开门，我来想办法。”", next = "home_first", effects = { vars = { home = 1 } } } },
  },

  garden = {
    chapter = "第二夜 · 荒园",
    checkpoint = "荒园",
    bg = "bg_garden",
    char = "char_gardener",
    speaker = "老园丁",
    title = "墙缝里的鸣响",
    lines = {
      "西墙裂缝里传来一声虫鸣。",
      "你刚靠近，老园丁便横过锄柄。",
      "“手收回去。谁碰谁上名册。”",
      "他的袖口全是洗不掉的湿土。",
    },
    choices = {
      { text = "摊开欠条：这红印你认不认？", next = "gardener_trust", when = "old_debt" },
      { text = "不碰墙：你怕谁？", next = "gardener_fear" },
      { text = "拨开锄柄：我先替自己找一条路。", next = "wall_search" },
    },
  },

  gardener_trust = {
    chapter = "第二夜 · 荒园", bg = "bg_garden", char = "char_gardener", speaker = "老园丁", title = "同一笔墨",
    lines = { "园丁的拇指停在朱印上。", "“我认得。这是空笼的印。”", "他看向井台：“旧账在砖下。”", "“你要拿，就别问我怕不怕。”" },
    choices = { { text = "“带我去。账得亲手交我。”", next = "well_ledger", effects = { flags = { "gardener_trust" } } }, { text = "“先活过今夜。”转身去找虫。", next = "wall_search" } },
  },

  well_ledger = {
    chapter = "第二夜 · 井台", bg = "bg_garden", char = "char_gardener", speaker = "老园丁", title = "第三块砖",
    lines = {
      "园丁跪下去，第三块砖果然松了。",
      "油布里有本发潮的旧账。",
      "十七枚指印压在里面。",
      "他攥着账角：“烧不掉的是人。”",
      "你接过去，他的手半晌才松开。",
    },
    choices = {
      { text = "“账不能留井底。”带回村。", next = "ledger", effects = { vars = { proof = 1 }, flags = { "gardener_trust", "has_ledger" } } },
      { text = "把账贴身收好，先去裂缝找虫。", next = "wall_search", effects = { flags = { "has_ledger" } } },
    },
  },

  gardener_fear = {
    chapter = "第二夜 · 荒园", bg = "bg_garden", char = "char_gardener", speaker = "老园丁", title = "不敢作证",
    lines = { "园丁盯着鞋尖。", "“空笼都是我送的。”", "“不送，儿子就补进名单。”", "“我欠的人太多，没脸作证。”" },
    choices = { { text = "“别提孩子。替我守住。”", next = "wall_search", effects = { flags = { "gardener_silence" } } }, { text = "“有人留副账吗？”去市集。", next = "market", effects = { vars = { folk = 1 } } } },
  },

  wall_search = {
    chapter = "第二夜 · 西墙", bg = "bg_garden", title = "手背的土",
    lines = { "碎瓦划破手背。裂缝里滚出空笼。", "笼里伏着瘦虫，翅色还没长全。", "更深处，另一声虫鸣亮起来。", "园外像有人踩断了一根草。" },
    choices = { { text = "忍着疼追进去：要那头会叫的。", next = "caught", effects = { vars = { cricket = 1 } } }, { text = "收起空笼：今夜不押在虫上。", next = "empty_cage" } },
  },

  market = {
    chapter = "第二夜 · 市集",
    checkpoint = "市集",
    bg = "bg_market",
    char = "char_vendor",
    speaker = "虫贩",
    title = "价高如命",
    lines = {
      "虫贩把笼盖扣上：“带了整年粮吗？”",
      "你没答。他指了指笼底的县衙红签。",
      "“带不够，就别听这头虫叫。”",
      "虫鸣一响，空笼都跟着发颤。",
    },
    choices = {
      { text = "“你有虫，为什么不自己交？”", next = "vendor_ledger" },
      { text = "推过粮票：给句准话。", next = "caught", effects = { vars = { cricket = 1, home = -2 } } },
      { text = "收起粮票：不能只救我家。", next = "neighbor", effects = { vars = { folk = 1, home = -1 } } },
    },
  },

  vendor_ledger = {
    chapter = "第二夜 · 市集", bg = "bg_market", char = "char_vendor", speaker = "虫贩", title = "副账",
    lines = { "虫贩轻笑：“交了，明年还来。”", "他摊开一册沾油的薄账。", "“虫卖给县衙，债却没销。”", "“你敢对名字，我按指印。”" },
    choices = { { text = "“把账和指印都留下。”", next = "market_testimony", effects = { flags = { "vendor_ledger" } } }, { text = "“先救这一家。”拿粮换虫。", next = "caught", effects = { vars = { cricket = 1, home = -2 } } } },
  },

  market_testimony = {
    chapter = "第二夜 · 市集", bg = "bg_market", char = "char_vendor", speaker = "虫贩", title = "不署名的账",
    lines = {
      "虫贩把灯拨低，翻到末页。",
      "交虫的日期、价钱，一笔也没少。",
      "“他们买走虫，再叫人补交。”",
      "他按下指印：“账替我去。”",
    },
    choices = {
      { text = "收好副账：回去对名字。", next = "ledger", effects = { vars = { proof = 1 }, flags = { "vendor_ledger", "has_ledger" } } },
      { text = "收好副账：先回荒园找斗虫。", next = "wall_search", effects = { flags = { "vendor_ledger", "has_ledger" } } },
    },
  },

  ledger = {
    chapter = "第三夜 · 账册",
    checkpoint = "账册",
    bg = "bg_village_night",
    title = "灯下对账",
    lines = {
      "你回到灯下，把账页摊开。",
      "自家欠条与旧账，日期重了一次。",
      "翻到后面，十七户都写着“未交”。",
      "阿蘅问：“现在谁肯认？”",
    },
    choices = {
      { text = "拿空笼：先敲第一户的门。", next = "witnesses", effects = { vars = { folk = 1 } } },
      { text = "把账压好：先找虫给他们看。", next = "wall_search" },
    },
  },

  witnesses = {
    chapter = "第三夜 · 名字", bg = "bg_village_night", title = "十七户",
    lines = { "第一户看见名字，先说“不是我”。", "阿蘅递出欠条：“那这一张呢？”", "门里沉默，才有人拿出交虫牌。", "第二只空笼递出来。有人信了。" },
    choices = { { text = "“进我家灯下说。”", next = "lantern_circle", requires = { min_vars = { folk = 2, proof = 1 } } }, { text = "“我去找虫。别散。”", next = "wall_search" }, { text = "“今夜谁也别出门。”", next = "quiet_ending" } },
  },

  lantern_circle = {
    chapter = "第三夜 · 灯下", bg = "bg_village_night", char = "char_aheng", speaker = "阿蘅", title = "十七盏灯",
    lines = {
      "人挤进屋里，谁也没有先坐。",
      "阿蘅念一个名字，等一声回答。",
      "第一声很低。第二声从门外传进来。",
      "空笼一只只放到灯下。",
    },
    choices = {
      { text = "收起账：天亮一起去县衙。", next = "folk_ending" },
      { text = "“带笼回去，先护孩子。”", next = "quiet_ending", effects = { vars = { home = 1 } } },
    },
  },

  caught = {
    chapter = "第三夜 · 笼中",
    checkpoint = "得虫",
    bg = "bg_village_night",
    char = "char_aheng",
    speaker = "阿蘅",
    title = "一头好虫",
    lines = {
      "斗虫撞着笼扣，声音像小石子敲门。",
      "阿蘅看见血，也看见笼里的虫。",
      "“交出去，我们能活过这一次。”",
      "她推近账页：“活到哪一次？”",
    },
    choices = {
      { text = "“先活过这次。”扣紧笼。", next = "last_lamp", effects = { vars = { home = 1 }, set = { final_intent = "shelter" } } },
      { text = "“让他们先看虫，再看账。”", next = "last_lamp", requires = { min_vars = { proof = 1, folk = 1 } }, effects = { set = { final_intent = "truth" } } },
      { text = "“不开门。带它去渡口。”", next = "last_lamp", effects = { vars = { home = 1 }, set = { final_intent = "road" } } },
    },
  },

  last_lamp = {
    chapter = "第三夜 · 灯下", bg = "bg_village_night", char = "char_aheng", speaker = "阿蘅", title = "最后一次挑灯",
    lines = {
      "阿蘅没碰竹笼，只压住账页。",
      "“这次，你自己把话说完。”",
      "院外起了风，门缝一阵阵响。",
      "你伸手时，灯芯正好跳了一下。",
    },
    choices = {
      { text = "提着竹笼，去县衙。", next = "shelter_ending", requires = { equals = { final_intent = "shelter" } } },
      { text = "带着账页走向县衙", next = "truth_ending", requires = { equals = { final_intent = "truth" } } },
      { text = "背起包袱去渡口", next = "road_ending", requires = { equals = { final_intent = "road" } } },
    },
  },

  empty_cage = {
    chapter = "第三夜 · 空笼",
    bg = "bg_village_night",
    char = "char_aheng",
    speaker = "阿蘅",
    title = "还剩一夜",
    lines = {
      "你没带虫回来，只带回手背上的泥。",
      "阿蘅看了一眼空笼：“冷吗？”",
      "院外有人抱着孩子，也抱着空笼。",
      "他们等的不是虫，是有人肯先开口。",
    },
    choices = {
      { text = "开门：有账的人，先进来坐。", next = "neighbors_wait", requires = { min_vars = { proof = 1 } }, effects = { vars = { folk = 2 }, set = { final_intent = "together" } } },
      { text = "各自躲过这一夜", next = "neighbors_wait", effects = { vars = { home = 1 }, set = { final_intent = "shelter" } } },
    },
  },

  neighbors_wait = {
    chapter = "第三夜 · 灯下", bg = "bg_village_night", char = "char_aheng", speaker = "阿蘅", title = "门前的人",
    lines = {
      "阿蘅给每个人倒了半碗热水。",
      "有人问：“账真能让他们认吗？”",
      "没人替你答。空笼扣在膝上。",
      "灯火照着一排不敢先说的话。",
    },
    choices = {
      { text = "“大家记住。”去县衙。", next = "folk_ending", requires = { equals = { final_intent = "together" } } },
      { text = "关门守住这一夜", next = "quiet_ending", requires = { equals = { final_intent = "shelter" } } },
    },
  },

  quiet_ending = {
    chapter = "终章 · 微火",
    bg = "bg_yamen",
    title = "微火之下",
    ending = {
      name = "微火之下",
      image = "ending_micro_fire",
      summary = { "你保住了这一夜的屋檐。", "可叩门声仍会在别处响起。" },
      notes = {
        { text = "你没有向恐惧低头，只是先关上了门。" },
        { text = "账页还在，明天仍有别的选择。", requires = { min_vars = { proof = 1 } } },
        { text = "今夜无账可凭，你只能守住眼前。", requires = { max_vars = { proof = 0 } } },
      },
    },
    lines = {
      "你没有开门，门外的人也没有再催。",
      "阿蘅把余下的灯油倒进灯盏。",
      "这一夜，屋檐还在你们头上。",
      "可远处又响起了新的叩门声。",
    },
    choices = { { text = "重走这一夜", next = "__restart" } },
  },

  shelter_ending = {
    chapter = "终章 · 微火",
    bg = "bg_yamen",
    title = "微火之下",
    ending = {
      name = "微火之下",
      image = "ending_micro_fire",
      summary = { "你把斗虫交了出去。", "屋檐保住了，叩门声没有远去。" },
      notes = {
        { text = "活下去不是软弱，是你此刻的回答。" },
        { text = "你没有烧掉账页，路还没走死。", requires = { min_vars = { proof = 1 } } },
      },
    },
    lines = {
      "县令收下竹笼，终于划去你的名字。",
      "回家后，阿蘅没有问你值不值得。",
      "她只把灯添满，和你一起听天亮。",
      "巷子另一头，叩门声仍在继续。",
    },
    choices = { { text = "重走这一夜", next = "__restart" } },
  },

  truth_ending = {
    chapter = "终章 · 堂前",
    bg = "bg_yamen",
    title = "堂前斗鸣",
    ending = {
      name = "堂前斗鸣",
      image = "ending_truth",
      summary = { "斗虫只是引子，账册才是证词。", "这一回，堂上不能只收竹笼。" },
      notes = {
        { text = "你把一时的平安，押给了更长的明天。" },
        { text = "有人肯同你开口，账才有了分量。", requires = { min_vars = { folk = 2 } } },
        { text = "园丁的旧账，终于不必再躲着人。", when = "gardener_trust" },
      },
    },
    lines = {
      "斗虫振翅，邻人摊开账页。",
      "县令伸手要笼。",
      "阿蘅问：“那这一笔呢？”",
      "你推过指印，堂上开始核账。",
    },
    choices = { { text = "重走这一夜", next = "__restart" } },
  },

  folk_ending = {
    chapter = "终章 · 满街竹笼",
    bg = "bg_yamen",
    title = "满街竹笼",
    ending = {
      name = "满街竹笼",
      image = "ending_lanterns",
      summary = { "空笼里没有虫，却装着名字。", "这次，没有人独自站在堂前。" },
      notes = {
        { text = "你没有替众人说话，而是让众人开口。" },
        { text = "隔壁先递出空笼，也递出信任。", when = "neighbor_word" },
        { text = "园丁不必再替县衙送空笼。", when = "gardener_trust" },
      },
    },
    lines = {
      "空竹笼摆满台阶。隔壁先开口。",
      "阿蘅念到名字，就有人应一声。",
      "念到最后，县令说不出话。",
      "这一回，先低头的是堂上的人。",
    },
    choices = { { text = "重走这一夜", next = "__restart" } },
  },

  road_ending = {
    chapter = "终章 · 远路",
    bg = "bg_village_night",
    title = "向灯火之外",
    ending = {
      name = "向灯火之外",
      image = "ending_road",
      summary = { "你放走了虫，也离开了被安排的路。", "天未亮，渡口已有灯火。" },
      notes = {
        { text = "离开不是逃。你拒绝再替他们还债。" },
        { text = "你先听完阿蘅的话，才提离开。", requires = { min_vars = { home = 2 } } },
        { text = "账页随你上船，真相没有留下。", requires = { min_vars = { proof = 1 } } },
      },
    },
    lines = {
      "你打开竹笼，鸣声没入野草。",
      "阿蘅背起包袱，和你走向渡口。",
      "这不是胜利，只是一次离开。",
      "可这一次，路由你们自己选。",
    },
    choices = { { text = "重走这一夜", next = "__restart" } },
  },
}

return M
