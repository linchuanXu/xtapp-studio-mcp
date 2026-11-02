local PkgImage = require("pkg_image")
-- 《星野录》 / XTApp API 2.x
-- 原创怪兽收集 RPG 垂直切片：探索、遭遇、回合制战斗、捕获、治疗、图鉴与试炼。
-- 所有游戏状态保存在 ctx.state.starfield_monsters；不依赖外部素材或品牌数据。

local MAPS = {
  harbor = { title = "苔光小径", spawn = { 2, 2 }, wild = { "shroomwing", "reedling", "driftfin", "tinskip", "mossmantle", "gorgeotter" }, levels = { 2, 3 },
    rows = {
      "#################", "#..B.ggg..R.H.S.#", "#.###g###.###...#", "#...#ggg.....T..#", "#.g6#.#####.#####",
      "#.g...g...#R....#", "#.#####g.#.##...#", "#.....ggg.#..2..#", "#################",
    } },
  marsh = { title = "雾苔湿地", spawn = { 2, 2 }, wild = { "driftfin", "shroomwing", "pebblit", "paperfin", "pinepocket" }, levels = { 3, 5 },
    rows = {
      "#################", "#..2..ggg..R....#", "#.###g###.####..#", "#...#ggg.....T..#", "#.g.#.#####.#####",
      "#.g...g...#R....#", "#.#####g.#.##...#", "#.....gggC#..4..#", "#################",
    } },
  ridge = { title = "风化山坳", spawn = { 2, 2 }, wild = { "pebblit", "mossfox", "shroomwing", "brookit", "bramblet", "sandplover", "lanternheron" }, levels = { 4, 6 },
    rows = {
      "#################", "#..4....ggg.R...#", "#.#####g###.###.#", "#.....ggg....N..#", "#.######.#####..#",
      "#....H...g...T..#", "#.#########.##..#", "#............3..#", "#################",
    } },
  observatory = { title = "旧天文台径", spawn = { 2, 2 }, wild = { "pebblit", "mossfox", "driftfin", "tinskip", "mistbell", "weavemoth" }, levels = { 5, 7 },
    rows = {
      "#################", "#..3....ggg.R...#", "#.#####g###.###.#", "#.....ggg....T..#", "#.######.#####..#",
      "#....H...g...A..#", "#.#########.##..#", "#....R5.........#", "#################",
    } },
  vault = { title = "潮纹库湾", spawn = { 2, 2 }, wild = { "paperfin", "brookit", "tinskip", "driftfin", "mistbell", "driftcrab" }, levels = { 6, 8 },
    rows = {
      "#################", "#..5....ggg.R...#", "#.#####g###.###.#", "#.....ggg....T..#", "#.######.#####..#",
      "#....H...g...V..#", "#.#########.##..#", "#....R7.........#", "#################",
    } },
  grove = { title = "碎页林地", spawn = { 2, 2 }, wild = { "pinepocket", "sandplover", "bramblet", "gorgeotter", "lanternheron" }, levels = { 4, 5 },
    rows = {
      "#################", "#..1..ggg..R....#", "#.###g###.####..#", "#...#ggg.....L..#", "#.g.#.#####.#####",
      "#.g...g...#H....#", "#.#####g.#.##...#", "#.....ggg.#..4..#", "#################",
    } },
  shoal = { title = "镜潮堤岸", spawn = { 2, 2 }, wild = { "driftcrab", "weavemoth", "paperfin", "mistbell", "lanternheron" }, levels = { 7, 8 },
    rows = {
      "#################", "#..5..ggg..R....#", "#.###g###.####..#", "#...#ggg.....E..#", "#.g.#.#####.#####",
      "#.g...g...#H....#", "#.#####g.#.##...#", "#.....ggg.#......#", "#################",
    } },
}

-- 每个可交互设施都有署名；这些角色会在周次与试炼进度变化后给出不同职责提示。
local TRAINERS = {
  harbor = { name = "巡野员 沈禾", species = "reedling", level = 2 },
  marsh = { name = "巡野员 岑沫", species = "driftfin", level = 3 },
  ridge = { name = "巡野员 谷岚", species = "bramblet", level = 4 },
  observatory = { name = "巡野员 余昼", species = "pebblit", level = 3 },
  vault = { name = "巡野员 陶澜", species = "paperfin", level = 5 },
}
local BRIDGE_TRIAL = { name = "渡桥考官 陵桥", species = "lanternheron", level = 5, id = "bridge" }
local HEALERS = { harbor = "医师 白葵", marsh = "医师 绿澜", ridge = "医师 岩芷", observatory = "医师 望舒", vault = "医师 潮禾", grove = "医师 纸岚", shoal = "医师 镜湾" }

local MOVES = {
  seed_tap = { name = "种子拍击", element = "芽", power = 7 }, soft_guard = { name = "柔叶护", element = "芽", power = 5, ward = 2 },
  ripple_pat = { name = "涟漪拍", element = "潮", power = 8 }, rain_call = { name = "雨滴歌", element = "潮", power = 6, heal = 4 },
  glimmer_dash = { name = "微光突刺", element = "辉", power = 8 }, lantern_blink = { name = "灯影闪", element = "辉", power = 7, ward = 3 },
  spore_wind = { name = "孢子风", element = "芽", power = 7 }, cap_drift = { name = "伞盖滑翔", element = "芽", power = 6, ward = 1 },
  stone_swirl = { name = "石屑回旋", element = "辉", power = 7 }, star_shell = { name = "星壳撞", element = "辉", power = 8, ward = 2 },
  tide_orb = { name = "潮汐弹", element = "潮", power = 8 }, fin_turn = { name = "浮鳍转", element = "潮", power = 6, heal = 3 },
  river_roll = { name = "河石翻滚", element = "潮", power = 8 }, reed_spark = { name = "芦尖闪", element = "潮", power = 7, ward = 2 },
  bell_prick = { name = "铃刺碰", element = "芽", power = 8 }, fern_guard = { name = "蕨环守", element = "芽", power = 6, ward = 3 },
  fork_chime = { name = "叉音震", element = "辉", power = 9 }, tin_skip = { name = "铁叶跃", element = "辉", power = 6, ward = 1 },
  fold_slice = { name = "折舟切", element = "潮", power = 8 }, bead_drift = { name = "珠流漂", element = "潮", power = 7, heal = 5 },
  keel_charge = { name = "舷灯冲", element = "潮", power = 10 }, lantern_tide = { name = "灯潮幕", element = "潮", power = 7, ward = 4 },
  wake_shear = { name = "尾流切", element = "潮", power = 10 }, sail_ward = { name = "帆纹守", element = "潮", power = 7, heal = 6 },
  bark_nudge = { name = "树皮拱", element = "芽", power = 8 }, moss_rest = { name = "苔幕歇", element = "芽", power = 5, ward = 4 },
  chime_peck = { name = "铃音啄", element = "辉", power = 9 }, mist_hush = { name = "雾铃静", element = "辉", power = 6, heal = 5 },
  pebble_peck = { name = "砾羽啄", element = "辉", power = 9 }, plume_guard = { name = "芦翎护", element = "辉", power = 6, ward = 3 },
  cone_roll = { name = "针果滚", element = "芽", power = 8 }, pouch_nap = { name = "囊叶眠", element = "芽", power = 5, heal = 5 },
  oar_snap = { name = "桨钳夹", element = "潮", power = 10 }, hull_splash = { name = "壳舟溅", element = "潮", power = 6, ward = 3 },
  thread_glint = { name = "丝线闪", element = "辉", power = 9 }, loom_rest = { name = "织纹歇", element = "辉", power = 5, heal = 5 },
  crown_push = { name = "冠苔拱", element = "芽", power = 11 }, thicket_wall = { name = "丛幕守", element = "芽", power = 7, ward = 5 },
}

local SPECIES = {
  reedling = { name = "苇芽", element = "芽", hp = 26, power = 8, guard = 9, speed = 8, moves = { "seed_tap", "soft_guard" }, capture = 72, evolve_at = 5, evolves_to = "reedbloom" },
  glowtail = { name = "灯尾獭", element = "潮", hp = 30, power = 7, guard = 8, speed = 7, moves = { "ripple_pat", "rain_call" }, capture = 64, evolve_at = 6, evolves_to = "glowkeel" },
  mossfox = { name = "苔耳狐", element = "辉", hp = 24, power = 10, guard = 7, speed = 10, moves = { "glimmer_dash", "lantern_blink" }, capture = 58 },
  shroomwing = { name = "菌羽鸟", element = "芽", hp = 22, power = 9, guard = 7, speed = 11, moves = { "spore_wind", "cap_drift" }, capture = 68 },
  pebblit = { name = "砾星", element = "辉", hp = 34, power = 7, guard = 12, speed = 4, moves = { "stone_swirl", "star_shell" }, capture = 52 },
  driftfin = { name = "浮鳍", element = "潮", hp = 25, power = 9, guard = 7, speed = 9, moves = { "tide_orb", "fin_turn" }, capture = 55 },
  brookit = { name = "溪石螈", element = "潮", hp = 32, power = 8, guard = 11, speed = 5, moves = { "river_roll", "reed_spark" }, capture = 48 },
  bramblet = { name = "刺铃蕨", element = "芽", hp = 27, power = 10, guard = 8, speed = 8, moves = { "bell_prick", "fern_guard" }, capture = 51 },
  tinskip = { name = "铁鸣蟋", element = "辉", hp = 25, power = 11, guard = 7, speed = 12, moves = { "fork_chime", "tin_skip" }, capture = 46 },
  paperfin = { name = "纸舟鳐", element = "潮", hp = 29, power = 8, guard = 8, speed = 10, moves = { "fold_slice", "bead_drift" }, capture = 54, evolve_at = 7, evolves_to = "keelray" },
  glowkeel = { name = "光舷兽", element = "潮", hp = 43, power = 13, guard = 13, speed = 9, moves = { "keel_charge", "lantern_tide" }, capture = 0 },
  keelray = { name = "舟潮魟", element = "潮", hp = 45, power = 12, guard = 11, speed = 13, moves = { "wake_shear", "sail_ward" }, capture = 0 },
  mossmantle = { name = "苔铠獾", element = "芽", hp = 36, power = 8, guard = 13, speed = 5, moves = { "bark_nudge", "moss_rest" }, capture = 44, evolve_at = 8, evolves_to = "crownbadger" },
  mistbell = { name = "雾铃蜗", element = "辉", hp = 28, power = 10, guard = 9, speed = 7, moves = { "chime_peck", "mist_hush" }, capture = 47 },
  sandplover = { name = "拾砂鸻", element = "辉", hp = 27, power = 10, guard = 8, speed = 11, moves = { "pebble_peck", "plume_guard" }, capture = 49 },
  pinepocket = { name = "针果狸", element = "芽", hp = 31, power = 9, guard = 9, speed = 9, moves = { "cone_roll", "pouch_nap" }, capture = 50 },
  driftcrab = { name = "漂壳蟹", element = "潮", hp = 35, power = 10, guard = 12, speed = 6, moves = { "oar_snap", "hull_splash" }, capture = 43 },
  weavemoth = { name = "织星蛾", element = "辉", hp = 26, power = 11, guard = 7, speed = 12, moves = { "thread_glint", "loom_rest" }, capture = 45 },
  gorgeotter = { name = "峡风獭", element = "潮", hp = 28, power = 10, guard = 8, speed = 11, moves = { "ripple_pat", "fin_turn" }, capture = 49 },
  lanternheron = { name = "岩灯鹭", element = "辉", hp = 30, power = 11, guard = 9, speed = 9, moves = { "stone_swirl", "lantern_blink" }, capture = 42 },
  crownbadger = { name = "冠苔獾", element = "芽", hp = 49, power = 14, guard = 17, speed = 6, moves = { "crown_push", "thicket_wall" }, capture = 0 },
  reedbloom = { name = "苇花", element = "芽", hp = 39, power = 12, guard = 12, speed = 9, moves = { "seed_tap", "soft_guard" }, capture = 0 },
}

local STARTERS = { "reedling", "glowtail", "mossfox" }
local ELEMENT_BEATS = { ["芽"] = "潮", ["潮"] = "辉", ["辉"] = "芽" }
local QUESTS = {
  harbor_trial = { title = "苔光见习", kind = "trial", target = "harbor", need = 1, credits = 8, capsules = 1 },
  dew_samples = { title = "露珠样本", kind = "gather", target = "dew", need = 2, credits = 6, capsules = 0 },
  first_records = { title = "第一批记录", kind = "capture", need = 2, credits = 10, capsules = 1 },
}
local QUEST_ORDER = { "harbor_trial", "dew_samples", "first_records" }
local DEX_MILESTONES = {
  { need = 3, title = "初页装订", credits = 8, capsules = 1 },
  { need = 6, title = "路线总览", credits = 14, capsules = 2 },
  { need = 10, title = "星野全录", credits = 24, capsules = 3 },
}
local WEEKLY_RESEARCH = {
  capture = { title = "新物种采样", need = 4, credits = 14, capsules = 1 },
  battles = { title = "同行默契", need = 6, credits = 16, capsules = 1 },
  expeditions = { title = "星轨复测", need = 3, credits = 22, capsules = 2 },
  shards = { title = "星屑标本", need = 8, credits = 18, capsules = 2 },
}
local WEEKLY_ORDER = { "capture", "battles", "expeditions", "shards" }
local FIELD_CONTRACTS = {
  tide = { title = "潮线采样", note = "捕获 3 只潮属性伙伴", kind = "capture_element", target = "潮", need = 3, credits = 18, capsules = 2, shard = 1 },
  moss = { title = "苔域编目", note = "采集 5 份苔纤维", kind = "gather", target = "moss", need = 5, credits = 16, capsules = 1, tonic = 2 },
  glint = { title = "辉光默契", note = "完成 6 场战斗", kind = "battle", need = 6, credits = 20, capsules = 1, shard = 2 },
}
local FIELD_CONTRACT_ORDER = { "tide", "moss", "glint" }
local SURVEY_REGIONS = { harbor = "苔光小径", marsh = "雾苔湿地", grove = "碎页林地", ridge = "风化山坳", observatory = "旧天文台径", vault = "潮纹库湾", shoal = "镜潮堤岸" }
local SURVEY_ORDER = { "harbor", "marsh", "grove", "ridge", "observatory", "vault", "shoal" }
local GATHER_BY_REGION = { harbor = "dew", marsh = "moss", ridge = "shard", observatory = "shard", vault = "shard", grove = "moss", shoal = "shard" }
local OBSERVATORY_BOSS = { { species = "pebblit", level = 5 }, { species = "mossfox", level = 6 } }
local VAULT_BOSS = { species = "paperfin", level = 8 }
local EXPEDITIONS = {
  { title = "苔风回声", stages = { { species = "bramblet", level = 5 }, { species = "mossmantle", level = 6 } }, credits = 9, shards = 1 },
  { title = "河床折光", stages = { { species = "brookit", level = 6 }, { species = "paperfin", level = 7 } }, credits = 12, shards = 2 },
  { title = "失焦星图", stages = { { species = "mistbell", level = 7 }, { species = "tinskip", level = 8 } }, credits = 16, shards = 3 },
}
local DAILY_CYCLE = {
  { title = "第 1 日：晨露采样", kind = "gather", target = "dew", need = 3, credits = 8, extras = { { id = "battles", label = "胜场", kind = "battle", need = 2 }, { id = "captures", label = "捕获", kind = "capture", need = 1 } } },
  { title = "第 2 日：新记录", kind = "capture", need = 3, credits = 9, extras = { { id = "moss", label = "苔纤维", kind = "gather", target = "moss", need = 2 }, { id = "craft", label = "制作", kind = "craft", target = "tonic", need = 1 } } },
  { title = "第 3 日：后勤练习", kind = "craft", target = "tonic", need = 2, credits = 10, extras = { { id = "dew", label = "星露", kind = "gather", target = "dew", need = 2 }, { id = "battles", label = "胜场", kind = "battle", need = 3 } } },
  { title = "第 4 日：山坳巡野", kind = "trial", target = "ridge", need = 1, credits = 12, extras = { { id = "shard", label = "星屑", kind = "gather", target = "shard", need = 2 }, { id = "captures", label = "捕获", kind = "capture", need = 1 } } },
  { title = "第 5 日：苔纤维补给", kind = "gather", target = "moss", need = 3, credits = 11, extras = { { id = "battles", label = "胜场", kind = "battle", need = 3 }, { id = "captures", label = "捕获", kind = "capture", need = 1 } } },
  { title = "第 6 日：星轨远征", kind = "expedition", target = "observatory", need = 1, credits = 15, extras = { { id = "shard", label = "星屑", kind = "gather", target = "shard", need = 2 }, { id = "craft", label = "制作", kind = "craft", target = "tonic", need = 1 } } },
  { title = "第 7 日：星屑周报", kind = "gather", target = "shard", need = 3, credits = 14, extras = { { id = "captures", label = "捕获", kind = "capture", need = 2 }, { id = "battles", label = "胜场", kind = "battle", need = 3 } } },
}

local function clamp(n, lo, hi) if n < lo then return lo elseif n > hi then return hi end return n end
local function cell(rows, x, y) if y < 1 or y > #rows or x < 1 or x > #rows[y] then return "#" end return string.sub(rows[y], x, x) end
local function copy_map(id) local rows = {}; local source = MAPS[id].rows; for i = 1, #source do rows[i] = source[i] end return rows end
local function species(id) return SPECIES[id] end
local function hp_for(id, level) return species(id).hp + (level - 1) * 4 end
local function power_for(mon) return species(mon.species).power + mon.level * 2 end
local function guard_for(mon) return species(mon.species).guard + mon.level end

local function fresh()
  return {
    phase = "title", region = "harbor", rows = copy_map("harbor"), px = 2, py = 2, selected = 1, action = 1,
    party = {}, active_slot = 1, box = {}, dex = {}, capsules = 5, tonics = 1, charms = 0, credits = 0, steps = 0, menu = "dex", roster_selected = 1, dex_page = 1,
    resources = { dew = 0, moss = 0, shard = 0 }, gathered = {}, quests = { harbor_trial = 0, dew_samples = 0, first_records = 0 }, claimed_quests = {}, dex_rewards = {}, shop_selected = 1,
    week_day = 1, completed_weeks = 0, daily = { progress = 0, extra = {} }, weekly = { capture = 0, battles = 0, expeditions = 0, shards = 0, claimed = {} }, field_contract = { selected = false, progress = 0, completed = {}, choice = 1 }, survey = { progress = {}, completed = {} }, journal_page = 1,
    battle = nil, trials = { harbor = false, marsh = false, bridge = false, ridge = false, observatory = false, vault = false }, bosses = { observatory = false, vault = false }, expeditions = { cleared = 0, best = {} }, expedition_selected = 1, flags = {}, observatory_seen = false,
    message = "星港镇外的草地里，藏着会记录星光的生物。",
  }
end

local function state(ctx)
  if not ctx.state.starfield_monsters then ctx.state.starfield_monsters = fresh() end
  local s = ctx.state.starfield_monsters
  -- 存档演进：旧版切片没有资源、药物和委托字段，恢复时补齐而不清空进度。
  s.tonics = s.tonics or 0; s.charms = s.charms or 0; s.active_slot = clamp(s.active_slot or 1, 1, math.max(1, #s.party)); s.resources = s.resources or { dew = 0, moss = 0, shard = 0 }; s.gathered = s.gathered or {}; s.quests = s.quests or {}; s.claimed_quests = s.claimed_quests or {}; s.dex_rewards = s.dex_rewards or {}; s.shop_selected = clamp(s.shop_selected or 1, 1, 4); s.bosses = s.bosses or { observatory = false, vault = false }; s.bosses.vault = s.bosses.vault or false; s.expeditions = s.expeditions or { cleared = 0, best = {} }; s.expeditions.cleared = s.expeditions.cleared or 0; s.expeditions.best = s.expeditions.best or {}; s.expedition_selected = clamp(s.expedition_selected or 1, 1, #EXPEDITIONS); s.dex_page = clamp(s.dex_page or 1, 1, 4); s.journal_page = clamp(s.journal_page or 1, 1, 4); s.weekly = s.weekly or { capture = 0, battles = 0, expeditions = 0, shards = 0, claimed = {} }; s.weekly.claimed = s.weekly.claimed or {}; for id, _ in pairs(WEEKLY_RESEARCH) do s.weekly[id] = s.weekly[id] or 0 end; s.field_contract = s.field_contract or { selected = false, progress = 0, completed = {}, choice = 1 }; if s.field_contract.selected == nil then s.field_contract.selected = false end; s.field_contract.progress = s.field_contract.progress or 0; s.field_contract.completed = s.field_contract.completed or {}; s.field_contract.choice = clamp(s.field_contract.choice or 1, 1, #FIELD_CONTRACT_ORDER); s.survey = s.survey or { progress = {}, completed = {} }; s.survey.progress = s.survey.progress or {}; s.survey.completed = s.survey.completed or {}; s.flags = s.flags or {}; s.trials = s.trials or { harbor = false, marsh = false, bridge = false, ridge = false, observatory = false, vault = false }; s.trials.bridge = s.trials.bridge or false; s.trials.ridge = s.trials.ridge or false; s.trials.vault = s.trials.vault or false; s.week_day = clamp(s.week_day or 1, 1, #DAILY_CYCLE); s.completed_weeks = s.completed_weeks or 0; s.daily = s.daily or { progress = 0, extra = {} }; s.daily.progress = s.daily.progress or 0; s.daily.extra = s.daily.extra or {}
  if s.battle and s.battle.boss and not s.battle.boss_id then s.battle.boss_id = "observatory" end
  for id, _ in pairs(QUESTS) do s.quests[id] = s.quests[id] or 0 end
  return s
end

local function make_mon(id, level)
  return { species = id, level = level, hp = hp_for(id, level), xp = 0 }
end

local function active(s) return s.party[s.active_slot or 1] end
local function mon_name(mon) return species(mon.species).name end
local function max_hp(mon) return hp_for(mon.species, mon.level) end
local function seen(s, id) s.dex[id] = s.dex[id] or "seen" end
local function caught(s, id) s.dex[id] = "caught" end
local function caught_count(s) local count = 0; for _, value in pairs(s.dex) do if value == "caught" then count = count + 1 end end return count end

local function advance_quest(s, kind, target, amount)
  for id, quest in pairs(QUESTS) do
    if quest.kind == kind and (quest.target == nil or quest.target == target) and not s.claimed_quests[id] then
      s.quests[id] = math.min(quest.need, (s.quests[id] or 0) + (amount or 1))
    end
  end
end

local function advance_field_contract(s, kind, target, amount)
  local track = s.field_contract
  if not track or not track.selected then return end
  local contract = FIELD_CONTRACTS[track.selected]
  if contract and contract.kind == kind and (contract.target == nil or contract.target == target) then
    track.progress = math.min(contract.need, (track.progress or 0) + (amount or 1))
  end
end

local function accept_or_claim_field_contract(s)
  local track = s.field_contract
  if not track.selected then
    local id = FIELD_CONTRACT_ORDER[track.choice]
    if track.completed[id] then s.message = "这份田野课题已经归档，换一条路线吧。"; return end
    track.selected = id; track.progress = 0; s.message = "记录官陆卷登记了课题「" .. FIELD_CONTRACTS[id].title .. "」。"
    return
  end
  local contract = FIELD_CONTRACTS[track.selected]
  if track.progress < contract.need then s.message = "课题尚未完成：「" .. contract.note .. "。"; return end
  s.credits = s.credits + contract.credits; s.capsules = s.capsules + contract.capsules; s.resources.shard = (s.resources.shard or 0) + (contract.shard or 0); s.tonics = s.tonics + (contract.tonic or 0)
  track.completed[track.selected] = true; s.message = "课题归档「" .. contract.title .. "」：获得巡野印 " .. contract.credits .. "。"
  track.selected = false; track.progress = 0
end

local function advance_survey(s, kind)
  local region = s.region
  if not SURVEY_REGIONS[region] or s.survey.completed[region] then return end
  local marks = s.survey.progress[region] or {}
  if marks[kind] then return end
  marks[kind] = true; s.survey.progress[region] = marks
  local count = 0; for _, key in ipairs({ "gather", "battle", "capture" }) do if marks[key] then count = count + 1 end end
  if count == 3 then
    s.survey.completed[region] = true; s.credits = s.credits + 9; s.capsules = s.capsules + 1; s.resources.shard = (s.resources.shard or 0) + 1
    s.message = SURVEY_REGIONS[region] .. "地区调查归档：获得巡野印 9、捕获器与星屑。"
  end
end

local function daily_goal(s) return DAILY_CYCLE[s.week_day] end

local function advance_daily(s, kind, target, amount)
  local goal = daily_goal(s)
  if goal.kind == kind and (goal.target == nil or goal.target == target) then s.daily.progress = math.min(goal.need, s.daily.progress + (amount or 1)) end
  for i = 1, #(goal.extras or {}) do local extra = goal.extras[i]; if extra.kind == kind and (extra.target == nil or extra.target == target) then s.daily.extra[extra.id] = math.min(extra.need, (s.daily.extra[extra.id] or 0) + (amount or 1)) end end
end
local function advance_weekly(s, id, amount) if s.weekly and WEEKLY_RESEARCH[id] then s.weekly[id] = math.min(WEEKLY_RESEARCH[id].need, (s.weekly[id] or 0) + (amount or 1)) end end

local function daily_done(s)
  local goal = daily_goal(s)
  if s.daily.progress < goal.need then return false end
  for i = 1, #(goal.extras or {}) do local extra = goal.extras[i]; if (s.daily.extra[extra.id] or 0) < extra.need then return false end end
  return true
end

local function complete_daily(s)
  local goal = daily_goal(s)
  if not daily_done(s) then return false end
  s.credits = s.credits + goal.credits; s.gathered = {}; s.week_day = s.week_day + 1
  if s.week_day > #DAILY_CYCLE then s.week_day = 1; s.completed_weeks = s.completed_weeks + 1; s.weekly = { capture = 0, battles = 0, expeditions = 0, shards = 0, claimed = {} } end
  s.daily = { progress = 0, extra = {} }
  s.message = "周报目标完成，获得巡野印 " .. goal.credits .. "。采集点已重新生长。"
  return true
end

local function claim_quests(s)
  local claimed = 0
  for id, quest in pairs(QUESTS) do
    if (s.quests[id] or 0) >= quest.need and not s.claimed_quests[id] then
      s.claimed_quests[id] = true; s.credits = s.credits + quest.credits; s.capsules = s.capsules + quest.capsules; claimed = claimed + 1
    end
  end
  if claimed > 0 then s.message = "领取 " .. tostring(claimed) .. " 份委托报酬。" else s.message = "还没有完成的委托。" end
  local records, dex_claimed = caught_count(s), 0
  for i = 1, #DEX_MILESTONES do local reward, key = DEX_MILESTONES[i], "milestone_" .. tostring(i); if records >= reward.need and not s.dex_rewards[key] then s.dex_rewards[key] = true; s.credits = s.credits + reward.credits; s.capsules = s.capsules + reward.capsules; dex_claimed = dex_claimed + 1 end end
  if dex_claimed > 0 then s.message = "图鉴里程碑达成，领取 " .. tostring(dex_claimed) .. " 份记录报酬。" end
  local weekly_claimed = 0
  for i = 1, #WEEKLY_ORDER do local id, goal = WEEKLY_ORDER[i], WEEKLY_RESEARCH[WEEKLY_ORDER[i]]; if (s.weekly[id] or 0) >= goal.need and not s.weekly.claimed[id] then s.weekly.claimed[id] = true; s.credits = s.credits + goal.credits; s.capsules = s.capsules + goal.capsules; weekly_claimed = weekly_claimed + 1 end end
  if weekly_claimed > 0 then s.message = "领取 " .. tostring(weekly_claimed) .. " 份整周研究报酬。" end
  if complete_daily(s) then return end
end

local function gather(s)
  local key = s.region .. ":" .. tostring(s.px) .. ":" .. tostring(s.py)
  if s.gathered[key] then s.message = "这里的样本已采集，明天会重新生长。"; return end
  local resource = GATHER_BY_REGION[s.region]; s.gathered[key] = true; s.resources[resource] = (s.resources[resource] or 0) + 1; advance_quest(s, "gather", resource, 1); advance_daily(s, "gather", resource, 1); advance_field_contract(s, "gather", resource, 1); advance_survey(s, "gather"); if resource == "shard" then advance_weekly(s, "shards", 1) end
  s.message = "采到 1 份" .. ({ dew = "星露", moss = "苔纤维", shard = "星屑" })[resource] .. "。"
end

local function buy_at_shop(s)
  if s.shop_selected == 1 then
    if s.credits < 5 then s.message = "巡野印不足，需要 5 枚。"; return end
    s.credits = s.credits - 5; s.capsules = s.capsules + 1; s.message = "购入 1 个捕获器。"
  elseif s.shop_selected == 2 then
    if (s.resources.dew or 0) < 2 or (s.resources.moss or 0) < 1 then s.message = "需要 2 星露和 1 苔纤维。"; return end
    s.resources.dew = s.resources.dew - 2; s.resources.moss = s.resources.moss - 1; s.tonics = s.tonics + 1; advance_daily(s, "craft", "tonic", 1); s.message = "制作 1 瓶星露药。"
  elseif s.shop_selected == 3 then
    if (s.resources.shard or 0) < 3 then s.message = "需要 3 份星屑。"; return end
    s.resources.shard = s.resources.shard - 3; s.capsules = s.capsules + 2; s.message = "压制 2 个星纹捕获器。"
  else
    if (s.resources.shard or 0) < 2 or (s.resources.moss or 0) < 1 then s.message = "需要 2 份星屑和 1 苔纤维。"; return end
    s.resources.shard = s.resources.shard - 2; s.resources.moss = s.resources.moss - 1; s.charms = s.charms + 1; advance_daily(s, "craft", "charm", 1); s.message = "制作 1 枚星屑护符。"
  end
end

local function enter_region(s, id)
  s.region = id; s.rows = copy_map(id); s.px, s.py = MAPS[id].spawn[1], MAPS[id].spawn[2]
  s.message = "抵达" .. MAPS[id].title .. "。这里的星光有新的气味。"
end

local function scaled_level(s, base)
  return math.min(12, base + math.min(3, s.completed_weeks or 0))
end

local function wild_level(s)
  local range = MAPS[s.region].levels or { 2, 4 }
  return scaled_level(s, math.random(range[1], range[2]))
end

local function first_move(mon)
  return MOVES[species(mon.species).moves[1]]
end

local function move_for(mon, index)
  return MOVES[species(mon.species).moves[index or 1]] or first_move(mon)
end

local function effectiveness(attacker, defender)
  local a, d = species(attacker.species).element, species(defender.species).element
  if ELEMENT_BEATS[a] == d then return 2, "克制！" end
  if ELEMENT_BEATS[d] == a then return 1, "被克制。" end
  return 1, ""
end

local function deal(attacker, defender, move)
  local mult, note = effectiveness(attacker, defender)
  -- 小型 X4 切片不使用高膨胀数值：新伙伴在不刷等级的情况下也应能完成首场试炼。
  local raw = move.power + math.floor(power_for(attacker) / 2) - math.floor(guard_for(defender) / 3)
  local damage = math.max(2, raw) * mult
  if (defender.ward or 0) > 0 then damage = math.max(1, damage - defender.ward); note = note .. " 护幕抵消了 " .. tostring(defender.ward) .. " 点伤害。"; defender.ward = 0 end
  defender.hp = math.max(0, defender.hp - damage)
  return damage, note
end

local function apply_move_effect(mon, move)
  local notes = ""
  if move.heal then local before = mon.hp; mon.hp = math.min(max_hp(mon), mon.hp + move.heal); notes = notes .. " 恢复 " .. tostring(mon.hp - before) .. " 点体力。" end
  if move.ward then mon.ward = move.ward; notes = notes .. " 形成 " .. tostring(move.ward) .. " 点护幕。" end
  return notes
end

local function begin_battle(s, enemy, trainer, boss, trainer_name, trial_id)
  seen(s, enemy.species)
  s.battle = { enemy = enemy, trainer = trainer == true, trainer_name = trainer_name, trial_id = trial_id, boss = boss == true, boss_id = boss and "observatory" or nil, stage = 1, turn = "choose", note = boss and "天文台的记录守卫苏醒了。它有两段星相。" or (trainer and ((trainer_name or "巡野员") .. "：让我看看你和伙伴的默契。") or ("野生 " .. mon_name(enemy) .. " 出现了！")) }
  s.phase = "battle"; s.action = 1
end

local function begin_expedition(s, index)
  local expedition, stage = EXPEDITIONS[index], EXPEDITIONS[index].stages[1]
  begin_battle(s, make_mon(stage.species, scaled_level(s, stage.level)), true)
  s.battle.expedition = index
  s.battle.note = "星轨远征「" .. expedition.title .. "」开始：第 1 段观测到 " .. mon_name(s.battle.enemy) .. "。"
end

local function reward_win(s)
  local b, hero = s.battle, active(s)
  local gained = b.boss and 24 or (b.trainer and 10 or 6)
  hero.xp = hero.xp + gained
  if hero.xp >= hero.level * 12 then
    hero.xp = hero.xp - hero.level * 12; hero.level = hero.level + 1; hero.hp = max_hp(hero)
    b.note = b.note .. " " .. mon_name(hero) .. " 升到 Lv." .. tostring(hero.level) .. "！"
    local info = species(hero.species)
    if info.evolve_at and hero.level >= info.evolve_at then
      hero.species = info.evolves_to; hero.hp = max_hp(hero); caught(s, hero.species)
      b.note = b.note .. " 星光聚成新的轮廓：" .. mon_name(hero) .. " 出现了！"
    end
  else
    b.note = b.note .. " 获得 " .. tostring(gained) .. " 点成长。"
  end
  advance_weekly(s, "battles", 1); advance_daily(s, "battle", nil, 1); advance_field_contract(s, "battle", nil, 1); advance_survey(s, "battle")
  if b.expedition then
    local expedition = EXPEDITIONS[b.expedition]
    s.expeditions.cleared = s.expeditions.cleared + 1; s.expeditions.best["route_" .. tostring(b.expedition)] = true; s.credits = s.credits + expedition.credits; s.resources.shard = (s.resources.shard or 0) + expedition.shards
    advance_daily(s, "expedition", "observatory", 1); advance_weekly(s, "expeditions", 1); b.note = b.note .. " 完成「" .. expedition.title .. "」，获得巡野印 " .. expedition.credits .. " 与星屑 " .. expedition.shards .. "。"
  elseif b.boss_id == "vault" then s.bosses.vault = true; s.flags.vault_crest = true; s.credits = s.credits + 50; s.capsules = s.capsules + 3; s.resources.shard = (s.resources.shard or 0) + 5; b.note = b.note .. " 潮纹库湾交出终局潮印：巡野印 50、捕获器 3、星屑 5。"
  elseif b.boss then s.bosses.observatory = true; s.observatory_seen = true; s.credits = s.credits + 30; b.note = b.note .. " 天文台将星野周报的钥印交给了你。"
  elseif b.trainer then
    local trial_id = b.trial_id or s.region; local first_clear = not s.trials[trial_id]; s.trials[trial_id] = true; advance_daily(s, "trial", trial_id, 1)
    if first_clear then s.credits = s.credits + 12; advance_quest(s, "trial", s.region, 1); b.note = b.note .. " 获得一枚巡野印。" else s.credits = s.credits + 5; b.note = b.note .. " 复战完成，获得巡野印 5。" end
  end
  s.phase = "result"; s.message = b.note
end

local function advance_boss_stage(s)
  local b, stage = s.battle, OBSERVATORY_BOSS[2]
  b.stage = 2; b.enemy = make_mon(stage.species, stage.level); seen(s, stage.species)
  b.note = "记录守卫展开第二段星相：" .. mon_name(b.enemy) .. "！"
end

local function advance_expedition_stage(s)
  local b, expedition = s.battle, EXPEDITIONS[s.battle.expedition]
  b.stage = b.stage + 1; local stage = expedition.stages[b.stage]; b.enemy = make_mon(stage.species, scaled_level(s, stage.level)); seen(s, stage.species)
  b.note = "星轨远征进入第 " .. tostring(b.stage) .. " 段：" .. mon_name(b.enemy) .. " 出现了！"
end

local function enemy_turn(s)
  local b, hero = s.battle, active(s)
  if not b or b.enemy.hp <= 0 then return end
  local move = move_for(b.enemy, math.random(1, #species(b.enemy.species).moves))
  local effect = apply_move_effect(b.enemy, move); local damage, note = deal(b.enemy, hero, move)
  b.note = b.note .. "  对方使用 " .. move.name .. "，造成 " .. tostring(damage) .. " 点伤害。" .. effect .. note
  if hero.hp <= 0 then
    if #s.party > 1 then s.phase = "battle_switch"; b.note = mon_name(hero) .. " 失去体力。请选择同行伙伴。"
    else hero.hp = max_hp(hero); s.px, s.py = 2, 2; s.phase = "result"; s.message = mon_name(hero) .. " 被送回星港镇治疗。" end
  end
end

local function attack(s, move_index)
  local b, hero = s.battle, active(s)
  local move = move_for(hero, move_index)
  local effect = apply_move_effect(hero, move); local damage, note = deal(hero, b.enemy, move)
  b.note = mon_name(hero) .. " 使用 " .. move.name .. "，造成 " .. tostring(damage) .. " 点伤害。" .. effect .. note
  if b.enemy.hp <= 0 then if b.boss_id == "observatory" and b.stage == 1 then advance_boss_stage(s) elseif b.expedition and b.stage < #EXPEDITIONS[b.expedition].stages then advance_expedition_stage(s) else reward_win(s) end else enemy_turn(s) end
end

local function capture(s)
  local b = s.battle
  if b.trainer then b.note = "训练师的伙伴不能捕获。"; return end
  if s.capsules <= 0 then b.note = "捕获器用完了。"; return end
  s.capsules = s.capsules - 1
  local remaining = b.enemy.hp / max_hp(b.enemy)
  local chance = species(b.enemy.species).capture + math.floor((1 - remaining) * 25)
  if remaining <= 0.05 then chance = 100 end
  if math.random(1, 100) <= chance then
    caught(s, b.enemy.species); s.box[#s.box + 1] = b.enemy; advance_quest(s, "capture", b.enemy.species, 1); advance_daily(s, "capture", b.enemy.species, 1); advance_weekly(s, "capture", 1); advance_field_contract(s, "capture_element", species(b.enemy.species).element, 1); advance_survey(s, "capture")
    s.phase = "result"; s.message = "捕获成功！" .. mon_name(b.enemy) .. " 已记录进图鉴。"
  else
    b.note = "光环散开了，它挣脱了捕获器。"; enemy_turn(s)
  end
end

local function use_tonic(s)
  local b, hero = s.battle, active(s)
  if s.tonics <= 0 then b.note = "没有星露药。"; return end
  s.tonics = s.tonics - 1; hero.hp = math.min(max_hp(hero), hero.hp + 14); b.note = mon_name(hero) .. " 使用星露药，恢复了体力。"; enemy_turn(s)
end

local function use_charm(s)
  local b, hero = s.battle, active(s)
  if s.charms <= 0 then b.note = "没有星屑护符。"; return end
  s.charms = s.charms - 1; hero.ward = math.max(hero.ward or 0, 7); b.note = mon_name(hero) .. " 激活星屑护符，获得 7 点护幕。"; enemy_turn(s)
end

local function flee(s)
  local b = s.battle
  if b.trainer then b.note = "试炼中不能离开。"; return end
  if math.random(1, 100) <= 70 then s.phase = "explore"; s.message = "你和伙伴退回了草地。" else b.note = "没能逃开！"; enemy_turn(s) end
end

local function interact(s)
  local tile = cell(s.rows, s.px, s.py)
  if tile == "H" then
    for i = 1, #s.party do s.party[i].hp = max_hp(s.party[i]) end
    s.capsules = math.max(s.capsules, 5); s.message = (HEALERS[s.region] or "医师") .. "替伙伴恢复了体力；捕获器不足时补足至 5 个。"
  elseif tile == "R" then
    gather(s)
  elseif tile == "B" then
    s.phase = "journal"; s.message = "记录官 陆卷：完成后按 OK 领取报酬。"
  elseif tile == "S" then
    s.phase = "shop"; s.shop_selected = 1; s.message = "后勤员 沈砚：可以购买捕获器，或用样本制作星露药。"
  elseif tile == "N" then
    if not s.flags.ridge_observer then s.flags.ridge_observer = true; s.resources.shard = (s.resources.shard or 0) + 2; s.capsules = s.capsules + 1; s.message = "观测员兰阅赠你 2 份星屑与捕获器：山坳的风会记住每一次同行。"
    else s.message = "兰阅：天文台的星轨还在变化，带着不同属性的伙伴回来看看。" end
  elseif tile == "L" then
    if not s.flags.grove_lexicon then s.flags.grove_lexicon = true; s.charms = s.charms + 1; s.resources.moss = (s.resources.moss or 0) + 2; s.message = "译页师 顾铭译出碎页林地的旧注：赠你星屑护符与 2 份苔纤维。"
    else s.message = "顾铭：碎页不是地图残片，而是记录过的伙伴留下的页码。" end
  elseif tile == "E" then
    if not s.flags.shoal_ledger then s.flags.shoal_ledger = true; s.credits = s.credits + 25; s.charms = s.charms + 1; s.resources.shard = (s.resources.shard or 0) + 3; s.message = "潮汐记录员 洛棠收下终局潮印的抄本：赠你巡野印 25、护符与 3 份星屑。"
    else s.message = "洛棠：镜潮会把终局后的每一次远征都折回新的记录。" end
  elseif tile == "T" then
    local trainer = TRAINERS[s.region]
    begin_battle(s, make_mon(trainer.species, trainer.level), true, false, trainer.name)
  elseif tile == "C" then
    begin_battle(s, make_mon(BRIDGE_TRIAL.species, BRIDGE_TRIAL.level), true, false, BRIDGE_TRIAL.name, BRIDGE_TRIAL.id)
  elseif tile == "A" then
    if not (s.trials.harbor and s.trials.marsh and s.trials.bridge and s.trials.ridge and s.trials.observatory) then s.message = "台长 玄书：还缺前哨、湿地、渡桥、山坳或天文台的巡野印。"
    elseif not s.bosses.observatory then local boss = OBSERVATORY_BOSS[1]; begin_battle(s, make_mon(boss.species, boss.level), true, true)
    else s.phase = "expedition"; s.expedition_selected = 1; s.message = "台长 玄书展开三条可重复挑战的星轨。" end
  elseif tile == "V" then
    if not s.bosses.observatory then s.message = "守门人 潮屿：守门印尚未回应，先完成天文台记录守卫。"
    elseif not s.trials.vault then s.message = "守门人 潮屿：先完成库湾试炼。"
    elseif not s.bosses.vault then begin_battle(s, make_mon(VAULT_BOSS.species, VAULT_BOSS.level), true, true); s.battle.boss_id = "vault"; s.battle.note = "潮纹守门人唤醒了库湾的终局试炼。"
    else s.message = "终局潮印已经属于你。星轨远征仍可在天文台重复挑战。" end
  else
    s.message = "草地会留下轻微的星光。走进去，或按 BACK 查看图鉴。"
  end
end

local function step(s, dx, dy)
  local nx, ny = s.px + dx, s.py + dy
  local tile = cell(s.rows, nx, ny)
  if tile == "#" then s.message = "石墙挡住了去路。"; return end
  s.px, s.py = nx, ny
  if tile == "1" then enter_region(s, "harbor"); return
  elseif tile == "2" then enter_region(s, "marsh"); return
  elseif tile == "3" then enter_region(s, "observatory"); return
  elseif tile == "4" then enter_region(s, "ridge"); return
  elseif tile == "5" then if s.bosses.observatory then enter_region(s, "vault") else s.message = "潮纹库湾被天文台的钥印封着。" end; return
  elseif tile == "6" then enter_region(s, "grove"); return
  elseif tile == "7" then if s.bosses.vault then enter_region(s, "shoal") else s.message = "镜潮堤岸只向持有终局潮印的人开放。" end; return
  elseif tile == "g" then
    s.steps = s.steps + 1
    local wild = MAPS[s.region].wild
    if s.steps % 3 == 0 then begin_battle(s, make_mon(wild[math.random(1, #wild)], wild_level(s)), false); return end
  end
  if tile == "H" then s.message = "星港站就在这里。按 OK 治疗伙伴。"
  elseif tile == "R" then s.message = "这里有可采集的星野样本。按 OK 采集。"
  elseif tile == "B" then s.message = "巡野委托板。按 OK 查看目标。"
  elseif tile == "S" then s.message = "后勤站。按 OK 购买或制作。"
  elseif tile == "N" then s.message = "一位观测员正在记录山风。按 OK 对话。"
  elseif tile == "L" then s.message = "译页师顾铭正在拼合碎页。按 OK 对话。"
  elseif tile == "E" then s.message = "潮汐记录员洛棠正在抄写终局后的潮纹。按 OK 对话。"
  elseif tile == "T" then s.message = s.trials[s.region] and "巡野员可以复战。按 OK 继续磨合。" or "巡野员正在等候试炼。按 OK 挑战。"
  elseif tile == "C" then s.message = s.trials.bridge and "渡桥考官陵桥可以复战。按 OK 继续磨合。" or "渡桥考官陵桥正在等候试炼。按 OK 挑战。"
  elseif tile == "A" then s.message = s.bosses.observatory and "天文台已记录你的第一轮成果。按 OK 查看远征。" or "旧天文台的门需要四枚巡野印。"
  elseif tile == "V" then s.message = s.bosses.vault and "潮纹库湾已向你敞开。" or "潮纹守门人正在等待。先完成库湾试炼。"
  else s.message = "在星野里探索。草地可能有生物出现。" end
end

local function draw_creature(g, id, x, y, scale, color)
  local e = species(id).element
  color = color or 15
  if id == "reedling" then
    g:circle(x, y + 9 * scale, 8 * scale,{fill=true,color=color}); g:line(x, y, x - 5 * scale, y - 12 * scale,{color=color}); g:line(x, y, x + 5 * scale, y - 12 * scale,{color=color})
  elseif id == "glowtail" then
    g:circle(x, y, 9 * scale,{color=color}); g:circle(x + 13 * scale, y + 5 * scale, 4 * scale,{fill=true,color=color}); g:line(x - 8 * scale, y + 4 * scale, x - 20 * scale, y + 8 * scale,{color=color})
  elseif id == "mossfox" then
    g:circle(x, y + 4 * scale, 8 * scale,{color=color}); g:line(x - 5 * scale, y - 4 * scale, x - 8 * scale, y - 15 * scale,{color=color}); g:line(x + 5 * scale, y - 4 * scale, x + 8 * scale, y - 15 * scale,{color=color}); g:line(x + 8 * scale, y + 8 * scale, x + 19 * scale, y + 13 * scale,{color=color})
  elseif id == "shroomwing" then
    g:circle(x, y + 5 * scale, 8 * scale,{color=color}); g:rect(x - 10 * scale, y - 10 * scale, 20 * scale, 7 * scale,{fill=true,color=color}); g:line(x - 11 * scale, y + 7 * scale, x - 20 * scale, y + 1 * scale,{color=color})
  elseif id == "pebblit" then
    g:rect(x - 9 * scale, y - 9 * scale, 18 * scale, 18 * scale,{color=color}); g:circle(x - 4 * scale, y - 3 * scale, 1 * scale,{fill=true,color=color}); g:circle(x + 4 * scale, y - 3 * scale, 1 * scale,{fill=true,color=color})
  else
    g:circle(x, y, 8 * scale,{color=color}); g:line(x - 9 * scale, y, x - 17 * scale, y - 6 * scale,{color=color}); g:line(x + 9 * scale, y, x + 17 * scale, y - 6 * scale,{color=color})
  end
  g:text(x - 12 * scale, y + 15 * scale, e, { color = color })
end

local function draw_sprite(ctx, g, id, x, y, width, height)
  local key = "mon_" .. id
  if ctx.package:image(key) then PkgImage.draw(g, key, x, y, { w = width, h = height }); return true end
  return false
end

local function draw_battle_creature(ctx, g, id, x, y)
  if not draw_sprite(ctx, g, id, x - 64, y - 64, 128, 128) then draw_creature(g, id, x, y, 4, 15) end
end

local function header(g, sw, s, title)
  g:text(16, 16, "星野录", { color = 15 }); g:text(sw - 156, 16, title, { color = 15 }); g:line(16, 42, sw - 16, 42,{color=15})
  if #s.party > 0 then local p = active(s); g:text(16, 52, mon_name(p) .. " Lv." .. p.level .. " HP " .. p.hp .. "/" .. max_hp(p), { color = 15 }) end
end

local function draw_title(ctx, g, sw, sh)
  g:text(28, 34, "星野录", { color = 15 }); g:text(28, 68, "STARFIELD RECORD", { color = 15 })
  g:rect(34, 112, sw - 68, 300,{color=15})
  local ids = { "reedling", "glowtail", "mossfox" }
  for i = 1, 3 do
    local x = 54 + (i - 1) * 146
    if not draw_sprite(ctx, g, ids[i], x, 190, 112, 112) then draw_creature(g, ids[i], x + 56, 250, 3, 15) end
  end
  g:text(44, 454, "记录会发光的微小生命。", { color = 15 }); g:text(44, 482, "每一次相遇，都会留下名字。", { color = 15 })
  g:rect(36, sh - 112, sw - 72, 56,{fill=true,color=15}); g:text(54, sh - 96, "开始记录", { color = 0 }); g:text(36, sh - 28, "OK / 点击开始", { color = 15 })
end

local function draw_starters(ctx, g, sw, sh, s)
  header(g, sw, s, "选择伙伴"); g:text(26, 92, "星港站给了你三枚记录球。", { color = 15 }); g:text(26, 116, "选择第一个同行者：", { color = 15 })
  for i = 1, #STARTERS do
    local y = 148 + (i - 1) * 150; local on = s.selected == i; g:rect(28, y, sw - 56, 124,{fill=(on) and true or false,color=15})
    if not draw_sprite(ctx, g, STARTERS[i], 48, y + 18, 84, 84) then draw_creature(g, STARTERS[i], 90, y + 54, 3, on and 0 or 15) end; g:text(162, y + 30, species(STARTERS[i]).name .. " / " .. species(STARTERS[i]).element, { color = on and 0 or 15 }); g:text(162, y + 60, MOVES[species(STARTERS[i]).moves[1]].name, { color = on and 0 or 15 }); g:text(162, y + 86, "按 OK 成为伙伴", { color = on and 0 or 15 })
  end
  g:text(28, sh - 24, "上下选择  OK 确认", { color = 15 })
end

local function draw_explore(g, sw, sh, s)
  header(g, sw, s, MAPS[s.region].title); local cell_size, ox, oy = 24, 36, 88
  for y = 1, #s.rows do for x = 1, #s.rows[y] do
    local tile, px, py = cell(s.rows, x, y), ox + (x - 1) * cell_size, oy + (y - 1) * cell_size
    if tile == "#" then g:rect(px, py, cell_size, cell_size,{fill=true,color=15})
    elseif tile == "g" then g:rect(px + 3, py + 3, cell_size - 6, cell_size - 6,{color=15}); g:line(px + 7, py + 17, px + 11, py + 7,{color=15}); g:line(px + 14, py + 17, px + 17, py + 8,{color=15})
    elseif tile == "H" then g:rect(px + 4, py + 4, cell_size - 8, cell_size - 8,{color=15}); g:line(px + 12, py + 6, px + 12, py + 18,{color=15}); g:line(px + 7, py + 12, px + 17, py + 12,{color=15})
    elseif tile == "R" then g:text(px + 7, py + 4, "采", { color = 15 })
    elseif tile == "B" then g:text(px + 7, py + 4, "委", { color = 15 })
    elseif tile == "S" then g:text(px + 7, py + 4, "店", { color = 15 })
    elseif tile == "N" or tile == "L" or tile == "E" then g:text(px + 7, py + 4, "人", { color = 15 })
    elseif tile == "T" or tile == "C" then g:text(px + 7, py + 4, "人", { color = 15 })
    elseif tile == "V" then g:text(px + 7, py + 4, "印", { color = 15 })
    elseif tile == "1" or tile == "2" or tile == "3" or tile == "4" or tile == "5" or tile == "6" or tile == "7" then g:text(px + 7, py + 4, "门", { color = 15 })
    elseif tile == "A" then g:circle(px + 12, py + 12, 8,{color=15}); g:line(px + 4, py + 19, px + 20, py + 19,{color=15}) end
    if s.px == x and s.py == y then g:rect(px + 5, py + 5, cell_size - 10, cell_size - 10,{fill=true,color=15}); g:text(px + 7, py + 4, "我", { color = 0 }) end
  end end
  g:rect(18, sh - 154, sw - 36, 98,{color=15}); g:text(30, sh - 136, s.message, { color = 15 }); g:text(30, sh - 82, "方向移动  OK 交互  BACK 图鉴/队伍", { color = 15 }); g:text(sw - 238, 52, "捕获器 " .. s.capsules .. "  药 " .. s.tonics .. "  护符 " .. s.charms, { color = 15 })
end

local function draw_battle(ctx, g, sw, sh, s)
  local b, hero, foe = s.battle, active(s), s.battle.enemy; header(g, sw, s, b.boss_id == "vault" and "潮纹守门 · 终局" or (b.boss and ("记录守卫 · 第" .. b.stage .. "相") or (b.expedition and ("星轨远征 · 第" .. b.stage .. "段") or (b.trainer and "试炼对战" or "野外相遇"))))
  g:rect(26, 86, sw - 52, 218,{color=15}); draw_battle_creature(ctx, g, foe.species, math.floor(sw * 0.70), 155); draw_battle_creature(ctx, g, hero.species, math.floor(sw * 0.26), 254)
  g:text(38, 98, mon_name(foe) .. " Lv." .. foe.level, { color = 15 }); g:text(38, 124, "HP " .. foe.hp .. "/" .. max_hp(foe), { color = 15 }); g:text(38, 244, mon_name(hero) .. " Lv." .. hero.level, { color = 15 }); g:text(38, 270, "HP " .. hero.hp .. "/" .. max_hp(hero), { color = 15 })
  g:rect(26, 324, sw - 52, 110,{color=15}); g:text(42, 346, b.note, { color = 15 })
  local labels = { move_for(hero, 1).name, move_for(hero, 2).name, "使用捕获器 (" .. s.capsules .. ")", "星露药 (" .. s.tonics .. ")", "星屑护符 (" .. s.charms .. ")", "换伙伴", "离开" }
  for i = 1, 7 do local y, on = 394 + (i - 1) * 48, s.action == i; g:rect(28, y, sw - 56, 38,{fill=(on) and true or false,color=15}); g:text(46, y + 9, labels[i], { color = on and 0 or 15 }) end
  g:text(28, sh - 24, "左右选择招式/道具  OK 确认", { color = 15 })
end

local function draw_battle_switch(ctx, g, sw, sh, s)
  header(g, sw, s, "选择同行伙伴"); g:text(28, 90, "选择后，对方将立即行动。", { color = 15 })
  s.roster_selected = clamp(s.roster_selected or 1, 1, #s.party)
  for i = 1, #s.party do
    local mon, y, on = s.party[i], 132 + (i - 1) * 116, s.roster_selected == i
    g:rect(24, y, sw - 48, 96,{fill=(on) and true or false,color=15}); if not draw_sprite(ctx, g, mon.species, 42, y + 16, 64, 64) then draw_creature(g, mon.species, 72, y + 44, 2, on and 0 or 15) end
    g:text(124, y + 20, (i == s.active_slot and "当前：" or "同行：") .. mon_name(mon), { color = on and 0 or 15 }); g:text(124, y + 52, "Lv." .. mon.level .. "  HP " .. mon.hp .. "/" .. max_hp(mon), { color = on and 0 or 15 })
  end
  g:text(24, sh - 26, "上下选择  OK 换人  BACK 返回", { color = 15 })
end

local function draw_result(ctx, g, sw, sh, s)
  header(g, sw, s, "记录更新"); g:rect(30, 100, sw - 60, 270,{color=15}); if not draw_sprite(ctx, g, active(s).species, math.floor(sw / 2) - 64, 126, 128, 128) then draw_creature(g, active(s).species, math.floor(sw / 2), 190, 5, 15) end; g:text(48, 330, s.message, { color = 15 }); g:rect(36, sh - 112, sw - 72, 56,{fill=true,color=15}); g:text(56, sh - 96, "回到小径", { color = 0 })
end

local function draw_dex(ctx, g, sw, sh, s)
  if s.menu == "party" then
    header(g, sw, s, "伙伴队伍")
    local total = #s.party + #s.box; s.roster_selected = clamp(s.roster_selected or 1, 1, math.max(1, total))
    for i = 1, total do
      local mon = i <= #s.party and s.party[i] or s.box[i - #s.party]
      local y, on = 96 + (i - 1) * 104, s.roster_selected == i
      g:rect(24, y, sw - 48, 84,{fill=(on) and true or false,color=15}); if not draw_sprite(ctx, g, mon.species, 42, y + 12, 56, 56) then draw_creature(g, mon.species, 70, y + 38, 2, on and 0 or 15) end
      g:text(124, y + 18, (i <= #s.party and (i == s.active_slot and "当前：" or "同行：") or "图鉴盒：") .. mon_name(mon), { color = on and 0 or 15 })
      g:text(124, y + 46, "Lv." .. mon.level .. "  " .. species(mon.species).element .. "  HP " .. mon.hp .. "/" .. max_hp(mon), { color = on and 0 or 15 })
    end
    g:text(24, sh - 54, "OK 设当前/加入同行（最多三只）", { color = 15 }); g:text(24, sh - 26, "左右切到图鉴  BACK 返回", { color = 15 })
    return
  end
  header(g, sw, s, "星野图鉴"); local ids = { "reedling", "glowtail", "mossfox", "shroomwing", "pebblit", "driftfin", "brookit", "bramblet", "tinskip", "paperfin", "mossmantle", "mistbell", "sandplover", "pinepocket", "driftcrab", "weavemoth", "gorgeotter", "lanternheron", "reedbloom", "glowkeel", "keelray", "crownbadger" }; local start = (s.dex_page - 1) * 6 + 1; local finish = math.min(#ids, start + 5)
  for i = start, finish do local y, status = 86 + (i - start) * 78, s.dex[ids[i]] or "未知"; g:rect(24, y, sw - 48, 62,{color=15}); if not draw_sprite(ctx, g, ids[i], 38, y + 7, 48, 48) then draw_creature(g, ids[i], 62, y + 27, 2, s.dex[ids[i]] and 15 or 7) end; g:text(114, y + 14, s.dex[ids[i]] and species(ids[i]).name or "？？？", { color = 15 }); g:text(114, y + 38, status == "caught" and "已捕获" or (status == "seen" and "已发现" or "未记录"), { color = 15 }) end
  g:text(24, sh - 54, "图鉴 " .. s.dex_page .. "/4  上下翻页  左右查看队伍", { color = 15 }); g:text(24, sh - 26, "已捕获 " .. #s.box .. " 只  BACK 返回", { color = 15 })
end

local function draw_journal(g, sw, sh, s)
  header(g, sw, s, "巡野委托 · 周" .. (s.completed_weeks + 1) .. " / 日" .. s.week_day)
  if s.journal_page == 4 then
    g:text(28, 88, "地区调查：每张路线完成采集、战斗、捕获。", { color = 15 })
    for i = 1, #SURVEY_ORDER do
      local id, marks, done, y = SURVEY_ORDER[i], s.survey.progress[SURVEY_ORDER[i]] or {}, s.survey.completed[SURVEY_ORDER[i]], 120 + (i - 1) * 62
      g:rect(24, y, sw - 48, 48,{fill=(done) and true or false,color=15})
      g:text(40, y + 12, SURVEY_REGIONS[id], { color = done and 0 or 15 })
      g:text(242, y + 12, "采 " .. (marks.gather and "✓" or "·") .. "  战 " .. (marks.battle and "✓" or "·") .. "  捕 " .. (marks.capture and "✓" or "·") .. (done and "  归档" or ""), { color = done and 0 or 15 })
    end
    g:text(24, sh - 58, "完成任一地区：印 9 / 捕获器 1 / 星屑 1", { color = 15 }); g:text(24, sh - 28, "左右切换日程 / 研究 / 课题 / 调查  BACK 返回", { color = 15 })
    return
  end
  if s.journal_page == 3 then
    local track = s.field_contract
    g:text(28, 88, "田野课题：选一条长期研究路线。", { color = 15 })
    if track.selected then
      local contract = FIELD_CONTRACTS[track.selected]
      g:rect(24, 126, sw - 48, 154,{color=15}); g:text(42, 148, contract.title, { color = 15 }); g:text(42, 184, contract.note, { color = 15 }); g:text(42, 220, "进度 " .. track.progress .. " / " .. contract.need, { color = 15 }); g:text(42, 250, "报酬：印 " .. contract.credits .. "  捕获器 " .. contract.capsules .. "  星屑 " .. (contract.shard or 0) .. "  药 " .. (contract.tonic or 0), { color = 15 })
      g:text(24, sh - 58, "OK 交付已完成课题", { color = 15 })
    else
      for i = 1, #FIELD_CONTRACT_ORDER do
        local id, contract, y = FIELD_CONTRACT_ORDER[i], FIELD_CONTRACTS[FIELD_CONTRACT_ORDER[i]], 126 + (i - 1) * 132; local done, on = track.completed[id], track.choice == i
        g:rect(24, y, sw - 48, 108,{fill=(on) and true or false,color=15}); g:text(42, y + 14, (done and "已归档 · " or "") .. contract.title, { color = on and 0 or 15 }); g:text(42, y + 44, contract.note, { color = on and 0 or 15 }); g:text(42, y + 74, "报酬：印 " .. contract.credits .. "  捕获器 " .. contract.capsules .. "  星屑 " .. (contract.shard or 0) .. "  药 " .. (contract.tonic or 0), { color = on and 0 or 15 })
      end
      g:text(24, sh - 58, "上下选择  OK 接受课题", { color = 15 })
    end
    g:text(24, sh - 28, "左右切换日程 / 研究 / 课题 / 调查  BACK 返回", { color = 15 })
    return
  end
  if s.journal_page == 2 then
    g:text(28, 88, "整周研究会在第七日结束时刷新。", { color = 15 })
    for i = 1, #WEEKLY_ORDER do
      local id, goal, y = WEEKLY_ORDER[i], WEEKLY_RESEARCH[WEEKLY_ORDER[i]], 122 + (i - 1) * 112; local done = s.weekly.claimed[id]
      g:rect(24, y, sw - 48, 88,{fill=(done) and true or false,color=15}); g:text(42, y + 14, goal.title, { color = done and 0 or 15 }); g:text(42, y + 42, tostring(s.weekly[id] or 0) .. " / " .. goal.need .. (done and "  已领取" or ""), { color = done and 0 or 15 }); g:text(42, y + 66, "报酬：巡野印 " .. goal.credits .. "，捕获器 " .. goal.capsules, { color = done and 0 or 15 })
    end
    g:text(24, sh - 58, "OK 领取已完成研究", { color = 15 }); g:text(24, sh - 28, "左右切换日程 / 研究 / 课题 / 调查  BACK 返回", { color = 15 })
    return
  end
  for i = 1, #QUEST_ORDER do
    local id, quest = QUEST_ORDER[i], QUESTS[QUEST_ORDER[i]]; local progress = s.quests[id] or 0; local claimed = s.claimed_quests[id]
    local y = 96 + (i - 1) * 116; g:rect(24, y, sw - 48, 94,{fill=(claimed) and true or false,color=15})
    g:text(42, y + 16, quest.title, { color = claimed and 0 or 15 }); g:text(42, y + 44, tostring(progress) .. " / " .. tostring(quest.need) .. (claimed and "  已领取" or ""), { color = claimed and 0 or 15 })
    g:text(42, y + 68, "报酬：巡野印 " .. quest.credits .. "，捕获器 " .. quest.capsules, { color = claimed and 0 or 15 })
  end
  local daily, y = daily_goal(s), 452; local done = daily_done(s)
  g:rect(24, y, sw - 48, 126,{fill=(done) and true or false,color=15}); g:text(42, y + 14, daily.title, { color = done and 0 or 15 }); g:text(42, y + 38, "主目标 " .. s.daily.progress .. " / " .. daily.need, { color = done and 0 or 15 })
  for i = 1, #(daily.extras or {}) do local extra = daily.extras[i]; g:text(42, y + 38 + i * 22, extra.label .. " " .. (s.daily.extra[extra.id] or 0) .. " / " .. extra.need, { color = done and 0 or 15 }) end
  g:text(42, y + 104, "全部完成后进入下一日：巡野印 " .. daily.credits, { color = done and 0 or 15 })
  local records, reward = caught_count(s), DEX_MILESTONES[1]; for i = 1, #DEX_MILESTONES do if records >= DEX_MILESTONES[i].need then reward = DEX_MILESTONES[math.min(#DEX_MILESTONES, i + 1)] end end
  g:text(28, 604, "图鉴记录 " .. records .. "/10  下一档：" .. reward.title .. " / " .. reward.need, { color = 15 }); g:text(28, 632, "达成后在此领取巡野印 " .. reward.credits .. " 与捕获器 " .. reward.capsules, { color = 15 })
  g:text(24, sh - 58, "OK 领取已完成委托", { color = 15 }); g:text(24, sh - 28, "左右切换日程 / 研究 / 课题 / 调查  BACK 返回", { color = 15 })
end

local function draw_shop(g, sw, sh, s)
  header(g, sw, s, "星港后勤站"); g:text(30, 92, "印 " .. s.credits .. "  露 " .. s.resources.dew .. "  苔 " .. s.resources.moss .. "  屑 " .. s.resources.shard, { color = 15 })
  local rows = { "购入捕获器  /  巡野印 5", "制作星露药  /  星露 2 + 苔纤维 1", "压制星纹捕获器 ×2  /  星屑 3", "制作星屑护符  /  星屑 2 + 苔纤维 1" }
  for i = 1, 4 do local y, on = 136 + (i - 1) * 82, s.shop_selected == i; g:rect(28, y, sw - 56, 62,{fill=(on) and true or false,color=15}); g:text(46, y + 20, rows[i], { color = on and 0 or 15 }) end
  g:text(28, sh - 58, "上下选择  OK 购买/制作", { color = 15 }); g:text(28, sh - 28, "BACK 返回小径", { color = 15 })
end

local function draw_expedition(ctx, g, sw, sh, s)
  header(g, sw, s, "星轨远征")
  g:text(28, 88, "已完成 " .. s.expeditions.cleared .. " 次；远征可重复进行。", { color = 15 })
  for i = 1, #EXPEDITIONS do
    local e, y, on = EXPEDITIONS[i], 126 + (i - 1) * 120, s.expedition_selected == i
    g:rect(24, y, sw - 48, 96,{fill=(on) and true or false,color=15})
    local first, last = e.stages[1], e.stages[#e.stages]
    if not draw_sprite(ctx, g, first.species, 42, y + 16, 64, 64) then draw_creature(g, first.species, 74, y + 48, 2, on and 0 or 15) end
    g:text(124, y + 16, e.title .. " / 两段 Lv." .. scaled_level(s, first.level) .. "-" .. scaled_level(s, last.level), { color = on and 0 or 15 })
    g:text(124, y + 44, "对手：" .. species(first.species).name .. " → " .. species(last.species).name, { color = on and 0 or 15 })
    g:text(124, y + 70, "报酬：印 " .. e.credits .. "  星屑 " .. e.shards .. (s.expeditions.best["route_" .. tostring(i)] and "  已首胜" or ""), { color = on and 0 or 15 })
  end
  g:text(28, sh - 54, "上下选择  OK 出发", { color = 15 }); g:text(28, sh - 26, "BACK 返回天文台径", { color = 15 })
end

local function draw_victory(g, sw, sh, s)
  header(g, sw, s, "第一份记录"); g:rect(28, 100, sw - 56, 302,{fill=true,color=15}); g:circle(math.floor(sw / 2), 220, 58,{color=0}); g:line(math.floor(sw / 2) - 88, 290, math.floor(sw / 2) + 88, 290,{color=0}); g:text(56, 334, "旧天文台记录下你的名字。", { color = 0 }); g:text(38, 452, "你已完成探索、相遇、战斗、", { color = 15 }); g:text(38, 480, "捕获、治疗与试炼的第一轮循环。", { color = 15 }); g:text(38, sh - 54, "OK 从头开始新的记录", { color = 15 })
end

function on_load(ctx) math.randomseed(ctx.clock:millis()); state(ctx); ctx:invalidate() end

function on_input(ctx, ev)
  local s = state(ctx); local ok = ev.type == "key" and ev.phase == "down" and ev.key == "ok"; local back = ev.type == "key" and ev.phase == "down" and ev.key == "back"
  local left = ev.type == "key" and ev.phase == "down" and (ev.key == "left" or ev.key == "up"); local right = ev.type == "key" and ev.phase == "down" and (ev.key == "right" or ev.key == "down")
  local tap = (ev.type == "pointer" and ev.phase == "up") and (ev.gesture == "tap" or ev.gesture == "long")
  if s.phase == "title" and (ok or tap) then s.phase = "starter"; s.selected = 1
  elseif s.phase == "starter" then
    if left then s.selected = s.selected - 1 elseif right then s.selected = s.selected + 1 elseif ok or tap then local id = STARTERS[s.selected]; s.party = { make_mon(id, 3) }; s.active_slot = 1; caught(s, id); s.phase = "explore"; s.message = species(id).name .. " 成为了你的第一个伙伴。" elseif back then s.phase = "title" end
    if s.selected < 1 then s.selected = #STARTERS elseif s.selected > #STARTERS then s.selected = 1 end
  elseif s.phase == "explore" then
    if tap then local dx, dy = ev.x - 240, ev.y - 250; if math.abs(dx) > math.abs(dy) then step(s, dx < 0 and -1 or 1, 0) else step(s, 0, dy < 0 and -1 or 1) end elseif left then if ev.key == "up" then step(s, 0, -1) else step(s, -1, 0) end elseif right then if ev.key == "down" then step(s, 0, 1) else step(s, 1, 0) end elseif ok then interact(s) elseif back then s.phase = "dex"; s.menu = "dex"; s.roster_selected = 1 else return false end
  elseif s.phase == "battle" then
    if tap then local index = math.floor((ev.y - 394) / 48) + 1; if index >= 1 and index <= 7 then s.action = index; if index == 1 then attack(s, 1) elseif index == 2 then attack(s, 2) elseif index == 3 then capture(s) elseif index == 4 then use_tonic(s) elseif index == 5 then use_charm(s) elseif index == 6 then s.phase = "battle_switch"; s.roster_selected = s.active_slot else flee(s) end end
    elseif left then s.action = s.action - 1; if s.action < 1 then s.action = 7 end elseif right then s.action = s.action + 1; if s.action > 7 then s.action = 1 end elseif ok then if s.action == 1 then attack(s, 1) elseif s.action == 2 then attack(s, 2) elseif s.action == 3 then capture(s) elseif s.action == 4 then use_tonic(s) elseif s.action == 5 then use_charm(s) elseif s.action == 6 then s.phase = "battle_switch"; s.roster_selected = s.active_slot else flee(s) end elseif back then s.phase = "explore"; s.message = "你重新判断了局势。" else return false end
  elseif s.phase == "battle_switch" then
    if left then s.roster_selected = clamp(s.roster_selected - 1, 1, #s.party) elseif right then s.roster_selected = clamp(s.roster_selected + 1, 1, #s.party) elseif ok or tap then
      if s.roster_selected == s.active_slot then s.battle.note = "已经是当前伙伴。"; s.phase = "battle" else s.active_slot = s.roster_selected; s.phase = "battle"; s.battle.note = mon_name(active(s)) .. " 接替同行。"; enemy_turn(s) end
    elseif back then s.phase = "battle" else return false end
  elseif s.phase == "result" and (ok or tap or back) then s.phase = "explore"
  elseif s.phase == "dex" then
    if back then s.phase = "explore"
    elseif s.menu == "dex" and ev.type == "key" and ev.phase == "down" and (ev.key == "up" or ev.key == "down") then if ev.key == "up" then s.dex_page = s.dex_page - 1; if s.dex_page < 1 then s.dex_page = 4 end else s.dex_page = s.dex_page + 1; if s.dex_page > 4 then s.dex_page = 1 end end
    elseif ev.type == "key" and ev.phase == "down" and (ev.key == "left" or ev.key == "right") then s.menu = s.menu == "dex" and "party" or "dex"
    elseif s.menu == "party" and (left or right) then s.roster_selected = clamp(s.roster_selected + (right and 1 or -1), 1, math.max(1, #s.party + #s.box))
    elseif s.menu == "party" and (ok or tap) then
      if s.roster_selected <= #s.party then s.active_slot = s.roster_selected; s.message = mon_name(active(s)) .. " 成为了当前同行伙伴。"
      else local index = s.roster_selected - #s.party; local mon = s.box[index]; if #s.party < 3 then table.insert(s.party, mon); table.remove(s.box, index); s.active_slot = #s.party; s.roster_selected = s.active_slot; s.message = mon_name(mon) .. " 加入同行队伍。" else local old = active(s); s.party[s.active_slot] = mon; s.box[index] = old; s.message = mon_name(mon) .. " 接替当前同行伙伴。" end end
    elseif s.menu == "dex" and (ok or tap) then s.menu = "party" else return false end
  elseif s.phase == "journal" then
    if s.journal_page == 3 and not s.field_contract.selected and ev.type == "key" and ev.phase == "down" and (ev.key == "up" or ev.key == "down") then
      s.field_contract.choice = clamp(s.field_contract.choice + (ev.key == "down" and 1 or -1), 1, #FIELD_CONTRACT_ORDER)
    elseif left then s.journal_page = s.journal_page - 1; if s.journal_page < 1 then s.journal_page = 4 end
    elseif right then s.journal_page = s.journal_page + 1; if s.journal_page > 4 then s.journal_page = 1 end
    elseif ok or tap then if s.journal_page == 3 then accept_or_claim_field_contract(s) elseif s.journal_page ~= 4 then claim_quests(s) end
    elseif back then s.phase = "explore" else return false end
  elseif s.phase == "shop" then
    if left then s.shop_selected = s.shop_selected - 1; if s.shop_selected < 1 then s.shop_selected = 4 end elseif right then s.shop_selected = s.shop_selected + 1; if s.shop_selected > 4 then s.shop_selected = 1 end elseif ok or tap then buy_at_shop(s) elseif back then s.phase = "explore" else return false end
  elseif s.phase == "expedition" then
    if left then s.expedition_selected = clamp(s.expedition_selected - 1, 1, #EXPEDITIONS) elseif right then s.expedition_selected = clamp(s.expedition_selected + 1, 1, #EXPEDITIONS) elseif ok or tap then begin_expedition(s, s.expedition_selected) elseif back then s.phase = "explore" else return false end
  elseif s.phase == "victory" and (ok or tap) then ctx.state.starfield_monsters = fresh() else return false end
  ctx:invalidate(); return true
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s, sw, sh = state(ctx), ctx.screen.width, ctx.screen.height; g:clear(0)
  if s.phase == "title" then draw_title(ctx, g, sw, sh) elseif s.phase == "starter" then draw_starters(ctx, g, sw, sh, s) elseif s.phase == "explore" then draw_explore(g, sw, sh, s) elseif s.phase == "battle" then draw_battle(ctx, g, sw, sh, s) elseif s.phase == "battle_switch" then draw_battle_switch(ctx, g, sw, sh, s) elseif s.phase == "result" then draw_result(ctx, g, sw, sh, s) elseif s.phase == "dex" then draw_dex(ctx, g, sw, sh, s) elseif s.phase == "journal" then draw_journal(g, sw, sh, s) elseif s.phase == "shop" then draw_shop(g, sw, sh, s) elseif s.phase == "expedition" then draw_expedition(ctx, g, sw, sh, s) else draw_victory(g, sw, sh, s) end
end
