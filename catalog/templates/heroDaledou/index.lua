-- 勇者大乐斗 / XTApp 0.8
-- 单入口、横屏、离线存档。所有核心操作都可由 X4 Classic 按键完成。

local W, H = 800, 480
local TABS = { "营地", "招募", "装备", "收藏", "远征", "悬赏", "试炼塔" }
local WEAPONS = {
  { name = "枝芽木剑", atk = 3, crit = 0, guard = 0, kind = "稳定" },
  { name = "旅行平底锅", atk = 5, crit = 8, guard = 0, kind = "重击" },
  { name = "史莱姆罐", atk = 2, crit = 0, guard = 15, kind = "格挡" },
  { name = "晨星短刃", atk = 7, crit = 14, guard = 0, kind = "暴击" },
  { name = "风铃双刃", atk = 4, crit = 10, guard = 0, kind = "连击" },
  { name = "猎人短弓", atk = 6, crit = 6, guard = 0, kind = "穿透" },
  { name = "雷鸣法杖", atk = 8, crit = 4, guard = 0, kind = "灼伤" },
  { name = "捕兽铁夹", atk = 5, crit = 0, guard = 10, kind = "束缚" },
  { name = "混沌骰子", atk = 6, crit = 12, guard = 0, kind = "随机" },
  { name = "珊瑚礁枪", atk = 7, crit = 3, guard = 4, kind = "潮汐" },
  { name = "锚钩重刃", atk = 10, crit = 0, guard = 4, kind = "破甲" },
  { name = "镜面长靴", atk = 4, crit = 16, guard = 2, kind = "闪避" },
  { name = "壁垒战斧", atk = 11, crit = 0, guard = 12, kind = "重盾" },
  { name = "雾灯提灯", atk = 5, crit = 5, guard = 8, kind = "迷雾" },
  { name = "云纹长弓", atk = 9, crit = 12, guard = 0, kind = "压制" },
  { name = "口袋铃铛", atk = 3, crit = 20, guard = 0, kind = "幸运" },
  { name = "陨星巨锤", atk = 14, crit = 0, guard = 0, kind = "震荡" },
  { name = "彗星折扇", atk = 8, crit = 10, guard = 3, kind = "连环" },
}
local SKILLS = { "绝地反击", "铜皮铁骨", "狩猎刻印", "疾风步", "净化之泉", "借力打力", "勇者战吼", "假死术", "孤注一掷", "不屈意志", "盾击号令", "潮汐守势", "幸运护符", "流星许愿" }
local PARTNERS = { "苔藓精灵", "发条鸟", "焰尾狐", "甲壳虫卫", "珍珠鼹鼠", "云团纸鸢" }
-- 前四项保持旧存档索引不变；新增两件与网页基准对应的遗物。
local RELICS = { "回响金币", "天气瓶", "破王冠", "铜罗盘", "幸运缎带", "黎明羽毛" }
local HEROES = { "岩盾阿洛", "风行诺雅", "烬火维拉", "星语弥尔", "潮汐医师", "流云刺客" }
-- 网页基准的 13 个逐层对手；敌人图像按 5 张已生成 XIC 立绘轮换，名称与机制保持逐层变化。
local FOES = { "苔原史莱姆", "盗贼斥候", "石甲守卫", "烈焰萨满", "影狼首领", "远古竞技者", "锈钳蟹将", "潮歌魅影", "沉船私掠者", "潮汐巨兽", "浮空巡弋机", "星轨先知", "天穹冠军" }
local ZONES = { "霜草竞技场", "沉船斗技场", "浮空冠军赛" }
local HERO_SPRITES = { "hero_alo", "hero_noya", "hero_vira", "hero_miel", "hero_tide", "hero_assassin" }
local HERO_THUMBS = { "hero_thumb_alo", "hero_thumb_noya", "hero_thumb_vira", "hero_thumb_miel", "hero_tide_thumb", "hero_assassin_thumb" }
local RESULT_HERO_SPRITES = { "ch_alo", "ch_noya", "ch_vira", "ch_miel", "h_tide_medic", "h_cloud_assassin" }
local FOE_SPRITES = { "foe_slime", "foe_boar", "foe_crab", "foe_knight", "foe_golem" }
local FOE_TRAITS = {
  { name = "回响", text = "每 3 回合恢复 3 点生命。" },
  { name = "猛扑", text = "每 3 回合反击额外造成 4 点伤害。" },
  { name = "硬壳", text = "奇数回合受到的伤害降低 20%。" },
  { name = "反击", text = "玩家使用重击后，反击伤害提高 3 点。" },
  { name = "震荡", text = "每 4 回合反击额外造成 6 点伤害。" },
  { name = "回响", text = "远古竞技者会在长战中恢复生命。", behavior = "boss" },
  { name = "硬壳", text = "蟹甲会周期性展开石甲护盾。", behavior = "shield" },
  { name = "震荡", text = "潮歌会在长战中施加持续灼伤。", behavior = "burn" },
  { name = "反击", text = "私掠者会偷走下一件武器触发。", behavior = "steal" },
  { name = "猛扑", text = "潮汐巨兽会蓄力发动高伤害扑击。", behavior = "pounce" },
  { name = "震荡", text = "巡弋机每 4 回合释放震荡。", behavior = "pounce" },
  { name = "回响", text = "星轨灼烧会叠加但会自然衰退。", behavior = "burn" },
  { name = "反击", text = "天穹冠军会在半血后改变进攻姿态。", behavior = "boss" },
}
-- 网页基准的三赛季 × 10 场对手顺序；索引指向上面的统一敌人名册。
local CAMPAIGN_FOES = {
  { 1, 2, 1, 3, 2, 4, 3, 5, 4, 13 },
  { 7, 9, 7, 8, 9, 7, 8, 5, 9, 10 },
  { 11, 12, 11, 3, 12, 11, 9, 5, 12, 13 },
}
local WEAPON_SPRITES = { "weapon_twig", "weapon_pan", "weapon_jar", "weapon_star", "w_wind_daggers", "w_hunter_bow", "w_spark_staff", "w_trap_claw", "w_chaos_dice", "w_reef_spear", "w_anchor_blade", "w_mirror_boot", "w_shield_axe", "w_mist_lantern", "w_cloud_bow", "w_pocket_bell", "w_meteor_hammer", "w_comet_fan" }
local SKILL_SPRITES = { "s_last_stand", "s_thick_skin", "s_bleed_mark", "s_quick_feet", "s_cleanse", "s_counter", "s_battle_cry", "s_fake_death", "s_all_in", "s_second_wind", "s_shield_slam", "s_tidal_guard", "s_lucky_charm", "s_starfall" }
local PARTNER_SPRITES = { "p_moss_sprite", "p_clockwork_bird", "p_ember_fox", "p_shield_beetle", "p_pearl_mole", "p_cloud_kite" }
local RELIC_SPRITES = { "p_echo_coin", "p_weather_vial", "p_broken_crown", "p_copper_compass", "p_ribbon_charm", "p_dawn_feather" }
-- 收藏册专用大图；装备页继续使用 76px 小图，避免底部三槽在 480px 高度内被裁切。
local COLLECTION_WEAPON_SPRITES = { "cw_twig", "cw_pan", "cw_jar", "cw_star", "cw_wind_daggers", "cw_hunter_bow", "cw_spark_staff", "cw_trap_claw", "cw_chaos_dice", "cw_reef_spear", "cw_anchor_blade", "cw_mirror_boot", "cw_shield_axe", "cw_mist_lantern", "cw_cloud_bow", "cw_pocket_bell", "cw_meteor_hammer", "cw_comet_fan" }
local COLLECTION_SKILL_SPRITES = { "cs_last_stand", "cs_thick_skin", "cs_bleed_mark", "cs_quick_feet", "cs_cleanse", "cs_counter", "cs_battle_cry", "cs_fake_death", "cs_all_in", "cs_second_wind", "cs_shield_slam", "cs_tidal_guard", "cs_lucky_charm", "cs_starfall" }
local COLLECTION_PARTNER_SPRITES = { "cp_moss_sprite", "cp_clockwork_bird", "cp_ember_fox", "cp_shield_beetle", "cp_pearl_mole", "cp_cloud_kite" }
local COLLECTION_RELIC_SPRITES = { "cp_echo_coin", "cp_weather_vial", "cp_broken_crown", "cp_copper_compass", "cp_ribbon_charm", "cp_dawn_feather" }
local EVENT_SPRITES = { "e_rest", "e_thorns", "e_wind", "e_chest", "e_merchant", "e_elite" }
local BOUNTY_SPRITES = { "e_wind", "e_elite", "e_chest" }
local ROUTES = {
  { name = "补给营", text = "风险较低，胜利额外获得 12 金币。", hp = 0.92, power = 0.95, reward = 12 },
  { name = "精英试炼", text = "敌人更强，胜利经验与金币提高。", hp = 1.14, power = 1.12, reward = 28 },
  { name = "神秘商路", text = "敌人略强，胜利额外获得 1 精粹。", hp = 1.04, power = 1.06, reward = 1 },
}
local EVENTS = {
  { name = "篝火休整", text = "开场获得 22 点护盾。", reward = "开场 +22 护盾", sprite = "e_rest", bonus = { start_shield = 22 } },
  { name = "遗失宝箱", text = "敌人生命 +10%，胜利多得 20 金币。", reward = "金币 +20", sprite = "e_chest", bonus = { foe_hp_mul = 1.10, gold = 20 } },
  { name = "顺风追击", text = "第一回合攻击必定暴击。", reward = "首击必暴", sprite = "e_wind", bonus = { force_crit = true } },
  { name = "荆棘捷径", text = "开场失去 14 生命，胜利获得 14 精粹。", reward = "精粹 +14", sprite = "e_thorns", bonus = { start_damage = 14, essence = 14 } },
  { name = "旅行商人", text = "商人押注你的胜利，交付 1 张招募券。", reward = "招募券 +1", sprite = "e_merchant", bonus = { tickets = 1 } },
  { name = "冠军旗帜", text = "敌人更强，但胜利获得 42 金币与 1 张招募券。", reward = "高风险高回报", sprite = "e_elite", bonus = { foe_hp_mul = 1.22, foe_atk_mul = 1.16, gold = 42, tickets = 1 } },
}
local COLLECTION_LABELS = { "英雄", "武器", "战技", "伙伴", "遗物" }
local HERO_LEVEL_CAP = 30
local HERO_RANK_CAP = 5
local TACTICS = {
  { name = "猛攻", short = "攻击 +7 · 先伤 4", text = "开场攻击 +7，但先承受 4 点灼伤。", atk = 7, start_damage = 4 },
  { name = "守阵", short = "开场护盾 +16", text = "开场获得 16 点护盾，适合稳健推进。", shield = 16 },
  { name = "瞄准", short = "暴击率 +8%", text = "本场暴击率额外 +8%，适合高暴击武器。", crit = 8 },
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function inside(x, y, rx, ry, rw, rh) return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh end
local function event_options(s)
  local start = ((math.max(1, s.floor or 1) - 1) * 2 + math.max(0, (s.bounty_cycle or 1) - 1)) % #EVENTS
  return { (start % #EVENTS) + 1, ((start + 1) % #EVENTS) + 1, ((start + 2) % #EVENTS) + 1 }
end
local function selected_event(s) return EVENTS[event_options(s)[s.event_choice or 1]] or EVENTS[1] end
local function text(g, x, y, value, color) g:text(x, y, value, { color = color or 15 }) end
local function glyph_count(value)
  local count, index = 0, 1
  value = tostring(value or "")
  while index <= #value do
    local byte = string.byte(value, index); count = count + 1
    if byte < 128 then index = index + 1 elseif byte < 224 then index = index + 2 elseif byte < 240 then index = index + 3 else index = index + 4 end
  end
  return count
end
local function utf8_slice(value, start_char, count)
  value = tostring(value or ""); local start_byte, index, char = 1, 1, 0
  while index <= #value and char < start_char do
    local byte = string.byte(value, index); index = index + ((byte < 128 and 1) or (byte < 224 and 2) or (byte < 240 and 3) or 4); char = char + 1
  end
  start_byte = index; local end_byte = index; local taken = 0
  while end_byte <= #value and taken < count do
    local byte = string.byte(value, end_byte); end_byte = end_byte + ((byte < 128 and 1) or (byte < 224 and 2) or (byte < 240 and 3) or 4); taken = taken + 1
  end
  return string.sub(value, start_byte, end_byte - 1)
end
local function center(g, x, y, value, color) g:text(x - math.floor(glyph_count(value) * 5), y, value, { color = color or 15 }) end
local function bar(g, x, y, w, value, max, label)
  g:rect(x, y, w, 16, "stroke", 15)
  g:rect(x + 2, y + 2, math.floor((w - 4) * clamp(value / math.max(1, max), 0, 1)), 12, "fill", 15)
  text(g, x, y - 18, label .. " " .. math.max(0, value) .. "/" .. max)
end
local function button(g, x, y, w, h, label, selected, disabled)
  if selected then g:rect(x, y, w, h, "fill", 15); text(g, x + 16, y + math.floor(h / 2) - 8, label, 0)
  else g:rect(x, y, w, h, "stroke", disabled and 8 or 15); text(g, x + 16, y + math.floor(h / 2) - 8, label, disabled and 8 or 15) end
end

local function fresh()
  -- 与网页基准 STARTER_PROFILE 对齐：新玩家从有限资源开始，通过远征和悬赏建立循环。
  return { screen = "camp", tab = 1, selected = 1, coins = 40, essence = 0, tickets = 1, level = 1, xp = 0, hero_level = 1,
    weapon = 1, weapon_slot = 1, weapon_loadout = { 1, 2, 3 }, weapon_levels = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, weapon_owned = { true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false }, hero = 1, heroes = { true, false, false, false, false, false }, hero_levels = { 1, 1, 1, 1, 1, 1 }, hero_xp = { 0, 0, 0, 0, 0, 0 }, floor = 1, tower_best = 0,
    daily = -1, shop_day = -1, seed = 17, gacha_pity = 0, gear_pity = 0, hero_free = true, season_victories = 0, shop_buys = { false, false, false }, collection_rewards = {}, collection_type = 1, collection_page = 1, route = nil, route_choice = 1, tactic = 1, hero_ranks = { 0, 0, 0, 0, 0, 0 }, hero_echoes = { 0, 0, 0, 0, 0, 0 }, bounty_cycle = 1, bounty_choice = 1, bounty_progress = { 0, 0, 0 }, bounty_claimed = { false, false, false }, history = {}, last_replay = nil, last_draws = {}, replay_mode = false, skill = 1, skill_slot = 1, skill_loadout = { 1, 2, 3 }, partner = 1, relic = 1, skill_levels = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, skills = { true, true, true, false, false, false, false, false, false, false, false, false, false, false }, partners = { true, false, false, false, false, false }, relics = { true, false, false, false, false, false }, message = "从营地出发：远征、养成与招募已准备好。" }
end
local function state(ctx)
  local s = ctx.state.hero_daledou
  if not s then s = fresh(); ctx.state.hero_daledou = s end
  s.screen = s.screen or "camp"; s.tab = s.tab or 1; s.selected = s.selected or 1; s.weapon_levels = s.weapon_levels or {}; s.weapon_owned = s.weapon_owned or {}; for i = 1, #WEAPONS do s.weapon_levels[i] = s.weapon_levels[i] or 0; s.weapon_owned[i] = s.weapon_owned[i] == true or s.weapon_levels[i] > 0 or (i <= 3 and not s.weapon_owned[i] and s.weapon_loadout == nil) end; s.weapon_owned[s.weapon or 1] = true; s.heroes = s.heroes or { true, false, false, false, false, false }; if not s.hero_levels then s.hero_levels = { 1, 1, 1, 1, 1, 1 }; s.hero_levels[s.hero or 1] = s.hero_level or 1 end; for i = 1, #HEROES do s.heroes[i] = s.heroes[i] == true; s.hero_levels[i] = clamp(s.hero_levels[i] or 1, 1, HERO_LEVEL_CAP) end; s.hero_xp = s.hero_xp or {}; for i = 1, #HEROES do s.hero_xp[i] = math.max(0, s.hero_xp[i] or 0) end
  s.coins = s.coins or 0; s.essence = s.essence or 0; s.tickets = s.tickets or 0; s.floor = s.floor or 1; s.tower_best = s.tower_best or 0; s.hero_level = s.hero_level or 1; s.xp = s.xp or 0; s.level = s.level or 1
  s.weapon = s.weapon or 1; s.weapon_slot = clamp(s.weapon_slot or 1, 1, 3); s.weapon_loadout = s.weapon_loadout or { s.weapon, s.weapon, s.weapon }; for i = 1, 3 do local wi = s.weapon_loadout[i] or s.weapon; s.weapon_loadout[i] = s.weapon_owned[wi] and wi or s.weapon end; s.daily = s.daily or -1; s.shop_day = s.shop_day or -1; s.seed = s.seed or 17; s.gacha_pity = s.gacha_pity or 0; s.gear_pity = s.gear_pity or 0; s.hero_free = s.hero_free == true; s.season_victories = s.season_victories or 0; s.message = s.message or "营地已经准备好。"
  s.hero = s.hero or 1; s.hero_level = s.hero_levels[s.hero] or s.hero_level or 1; s.shop_buys = s.shop_buys or { false, false, false }; s.collection_rewards = s.collection_rewards or {}
  if type(s.history) ~= "table" then s.history = {} end; if type(s.last_draws) ~= "table" then s.last_draws = {} end; s.last_replay = s.last_replay or nil; s.replay_mode = s.replay_mode == true
  s.collection_type = clamp(s.collection_type or 1, 1, #COLLECTION_LABELS); s.collection_page = math.max(1, s.collection_page or 1); s.tactic = clamp(s.tactic or 1, 1, #TACTICS); s.hero_ranks = s.hero_ranks or {}; s.hero_echoes = s.hero_echoes or {}; for i = 1, #HEROES do s.hero_ranks[i] = clamp(s.hero_ranks[i] or 0, 0, HERO_RANK_CAP); s.hero_echoes[i] = math.max(0, s.hero_echoes[i] or 0) end
  s.skill = s.skill or 1; s.skill_slot = clamp(s.skill_slot or 1, 1, 3); s.skill_loadout = s.skill_loadout or { s.skill, s.skill, s.skill }; s.skill_levels = s.skill_levels or {}; s.skills = s.skills or { true, false, false, false }; for i = 1, #SKILLS do s.skill_levels[i] = s.skill_levels[i] or 0; s.skills[i] = s.skills[i] == true end; for i = 1, 3 do local si = s.skill_loadout[i] or s.skill; s.skill_loadout[i] = s.skills[si] and si or s.skill end; s.partner = s.partner or 1; s.relic = clamp(s.relic or 1, 1, #RELICS); s.partners = s.partners or { true, false, false, false }; for i = 1, #PARTNERS do s.partners[i] = s.partners[i] == true end; s.relics = s.relics or { true, false, false, false, false, false }; for i = 1, #RELICS do s.relics[i] = s.relics[i] == true end
  s.bounty_cycle = s.bounty_cycle or 1; s.bounty_choice = clamp(s.bounty_choice or 1, 1, 3); s.bounty_progress = s.bounty_progress or { 0, 0, 0 }; s.bounty_progress[1] = clamp(s.bounty_progress[1] or 0, 0, 3); s.bounty_progress[2] = clamp(s.bounty_progress[2] or 0, 0, 1); s.bounty_progress[3] = clamp(s.bounty_progress[3] or 0, 0, 2); s.bounty_claimed = s.bounty_claimed or { false, false, false }
  return s
end
local function hero_level(s) return s.hero_levels[s.hero] or s.hero_level or 1 end
local function hero_xp_need(level) return 18 + level * 12 end
local function hero_rank(s, index) return s.hero_ranks[index or s.hero] or 0 end
local function hero_rank_need(s, index) return 2 + hero_rank(s, index) * 2 end
local function hero_rank_label(s, index)
  local rank = hero_rank(s, index); return string.rep("★", rank) .. string.rep("☆", HERO_RANK_CAP - rank)
end
local function gain_hero_xp(s, amount)
  local index = s.hero; s.hero_xp[index] = (s.hero_xp[index] or 0) + amount
  while hero_level(s) < HERO_LEVEL_CAP and s.hero_xp[index] >= hero_xp_need(hero_level(s)) do s.hero_xp[index] = s.hero_xp[index] - hero_xp_need(hero_level(s)); s.hero_levels[index] = hero_level(s) + 1 end
  if hero_level(s) >= HERO_LEVEL_CAP then s.hero_xp[index] = 0 end
end
local function hero_hp(s) return 68 + (hero_level(s) - 1) * 8 + hero_rank(s) * 4 + (s.hero == 3 and 6 or s.hero == 5 and 8 or s.hero == 6 and 2 or 0) + (s.partner == 1 and 4 or s.partner == 3 and 8 or 0) + (s.relic == 2 and 6 or 0) end
local function hero_atk(s)
  local w = WEAPONS[s.weapon]; return 12 + (hero_level(s) - 1) * 2 + hero_rank(s) * 2 + w.atk + (s.weapon_levels[s.weapon] or 0) * 2 + (s.hero == 2 and 2 or s.hero == 4 and 1 or s.hero == 5 and 1 or s.hero == 6 and 3 or 0) + (s.partner == 2 and 2 or 0) + (s.relic == 3 and 3 or s.relic == 4 and 1 or 0)
end
local function set_weapon(s, index)
  if not s.weapon_owned[index] then return false end
  s.weapon = index; s.weapon_loadout[s.weapon_slot or 1] = index; return true
end
local function grant_weapon_drop(s, index, source)
  local level = s.weapon_levels[index] or 0
  if level >= 5 then
    s.essence = s.essence + 2; s.message = source .. WEAPONS[index].name .. " 已满阶，转化为 2 精粹。"
  else
    s.weapon_owned[index] = true; s.weapon_levels[index] = level + 1; s.message = source .. WEAPONS[index].name .. " 强化 +1。"
  end
end
local function rotate_weapon(s)
  local slot = (s.weapon_slot or 1) % 3 + 1; local index = s.weapon_loadout[slot]
  if s.weapon_owned[index] then s.weapon_slot = slot; s.weapon = index end
end
local function weapon_slot_label(s, index)
  local labels = ""
  for slot = 1, 3 do if s.weapon_loadout[slot] == index then labels = labels .. (labels == "" and "槽" or "/") .. slot end end
  return labels
end
local function set_skill(s, index)
  if not s.skills[index] then return false end
  s.skill = index; s.skill_loadout[s.skill_slot or 1] = index; return true
end
local function rotate_skill(s)
  local slot = (s.skill_slot or 1) % 3 + 1; local index = s.skill_loadout[slot]
  if s.skills[index] then s.skill_slot = slot; s.skill = index end
end
local function collection_count(s)
  local count = 0
  for i = 1, #HEROES do if s.heroes[i] then count = count + 1 end end
  for i = 1, #WEAPONS do if s.weapon_owned[i] then count = count + 1 end end
  for i = 1, #SKILLS do if s.skills[i] then count = count + 1 end end
  for i = 1, #PARTNERS do if s.partners[i] then count = count + 1 end end
  for i = 1, #RELICS do if s.relics[i] then count = count + 1 end end
  return count
end
local function check_collection_rewards(s)
  local count = collection_count(s); local percent = math.floor(count * 100 / 50); local rewards = { [25] = { coins = 80, essence = 12 }, [50] = { coins = 120, essence = 24, tickets = 1 }, [75] = { coins = 180, essence = 42, tickets = 1 }, [100] = { coins = 300, essence = 80, tickets = 2 } }
  for _, threshold in ipairs({ 25, 50, 75, 100 }) do
    local reward = rewards[threshold]
    if percent >= threshold and not s.collection_rewards[threshold] then
      s.collection_rewards[threshold] = true; s.coins = s.coins + reward.coins; s.essence = s.essence + reward.essence; s.tickets = s.tickets + (reward.tickets or 0)
      s.message = "收藏里程碑：完成 " .. threshold .. "%，金币 +" .. reward.coins .. "、精粹 +" .. reward.essence .. ((reward.tickets and "、招募券 +" .. reward.tickets) or "") .. "。"
    end
  end
end
local function collection_summary(s)
  local weapons, skills, partners, relics = 0, 0, 0, 0
  for i = 1, #WEAPONS do if s.weapon_owned[i] then weapons = weapons + 1 end end
  for i = 1, #SKILLS do if s.skills[i] then skills = skills + 1 end end
  for i = 1, #PARTNERS do if s.partners[i] then partners = partners + 1 end end
  for i = 1, #RELICS do if s.relics[i] then relics = relics + 1 end end
  local heroes = 0; for i = 1, #HEROES do if s.heroes[i] then heroes = heroes + 1 end end
  return "发现：英 " .. heroes .. "/6 · 武 " .. weapons .. "/18 · 技 " .. skills .. "/14 · 伴 " .. partners .. "/6 · 遗 " .. relics .. "/6"
end
local function collection_next_goal(s)
  local count = collection_count(s); local percent = math.floor(count * 100 / 50)
  for _, threshold in ipairs({ 25, 50, 75, 100 }) do
    if percent < threshold or not s.collection_rewards[threshold] then return "下个里程碑 " .. threshold .. "%" end
  end
  return "收藏里程碑已完成"
end
local function collection_def(s, kind)
  if kind == 1 then return HEROES, HERO_THUMBS, s.heroes end
  if kind == 2 then return WEAPONS, COLLECTION_WEAPON_SPRITES, s.weapon_owned end
  if kind == 3 then return SKILLS, COLLECTION_SKILL_SPRITES, s.skills end
  if kind == 4 then return PARTNERS, COLLECTION_PARTNER_SPRITES, s.partners end
  return RELICS, COLLECTION_RELIC_SPRITES, s.relics
end
-- 英雄/伙伴/遗物使用字符串表，武器使用带 name 字段的对象表；
-- 收藏册和点击提示必须通过同一个适配器取名，避免未拥有条目显示空白或点击时报错。
local function collection_entry_name(entries, index)
  local entry = entries[index]
  if type(entry) == "table" then return entry.name or "未命名" end
  return entry or "未命名"
end
local function collection_pages(s)
  local entries = collection_def(s, s.collection_type or 1)
  -- 480px 小屏优先两列大卡片；每页四项，减少拥挤并让立绘占据主要视觉区域。
  return math.max(1, math.ceil(#entries / 4))
end
local function collection_equipped(s, kind, index)
  if kind == 1 then return s.hero == index end
  if kind == 2 then return s.weapon == index end
  if kind == 3 then return s.skill == index end
  if kind == 4 then return s.partner == index end
  return s.relic == index
end
-- 使用契约提供的本地秒数计算自然日；RTC 未校准时安全回退到同一序号，
-- 避免伪造日期，也保证已领取状态不会因 nil 运行时值反复发奖。
local function day(ctx)
  local clock = ctx.sys and ctx.sys:clock()
  if not clock or clock.valid ~= true or clock.year == nil or clock.month == nil or clock.day == nil then return 0 end
  return clock.year * 10000 + clock.month * 100 + clock.day
end
local function rand(s, limit) s.seed = (s.seed * 1103515245 + 12345) % 2147483647; return (s.seed % limit) + 1 end
local function gain_xp(s, amount)
  s.xp = s.xp + amount
  while s.xp >= s.level * 30 do s.xp = s.xp - s.level * 30; s.level = s.level + 1; s.coins = s.coins + 10; s.message = "帐篷升级！获得 10 金币。" end
end
local function tower_law(floor)
  local laws = {
    { name = "坚甲", text = "守关者生命提高 12%。", hp = 1.12, atk = 0 },
    { name = "狂袭", text = "守关者攻击提高 2 点。", hp = 1, atk = 2 },
    { name = "回响", text = "守关者生命提高 6%，攻击提高 1 点。", hp = 1.06, atk = 1 },
  }
  return laws[(math.floor((math.max(1, floor) - 1) / 5) % #laws) + 1]
end
local function foe_stats(s, tower)
  local floor = tower and math.max(1, s.tower_best + 1) or s.floor
  local hp = 48 + floor * (tower and 17 or 12)
  local atk = 7 + math.floor(floor * (tower and 1.15 or 0.55))
  if tower then local law = tower_law(floor); hp = math.floor(hp * law.hp); atk = atk + law.atk end
  if not tower and floor % 5 == 0 then hp = math.floor(hp * 1.18); atk = math.floor(atk * 1.08) end
  local season = math.floor((floor - 1) / 10) % #CAMPAIGN_FOES + 1; local local_floor = ((floor - 1) % 10) + 1
  local index = tower and (((floor - 1) % #FOES) + 1) or CAMPAIGN_FOES[season][local_floor]
  return floor, hp, atk, FOES[index], FOE_TRAITS[index]
end
local function start_battle(s, tower, training)
  local floor, hp, atk, name, trait = foe_stats(s, tower)
  local route = s.route and ROUTES[s.route]
  local tactic = TACTICS[s.tactic or 1] or TACTICS[1]
  if not s.replay_mode and not training then
    s.last_replay = { tower = tower, floor = floor, route = s.route, tactic = s.tactic or 1, event_choice = s.event_choice or 1 }
  end
  if route and not tower then hp = math.floor(hp * route.hp); atk = math.max(1, math.floor(atk * route.power)) end
  local event = s.event_bonus or {}; hp = math.floor(hp * (event.foe_hp_mul or 1)); atk = math.max(1, math.floor(atk * (event.foe_atk_mul or 1)) + (event.foe_atk_delta or 0))
  s.screen = "battle"; s.selected = 1
  local max_hp = hero_hp(s) + (event.hero_hp_bonus or 0)
  local opening_hp = math.max(1, max_hp - (event.start_damage or 0) - (tactic.start_damage or 0))
  local boss = not tower and floor % 10 == 0
  local elite = not tower and floor % 5 == 0 and not boss
  local opening_shield = (tactic.shield or 0) + (event.start_shield or 0) + (s.partner == 4 and 12 or 0) + (boss and s.relic == 3 and 18 or 0)
  s.battle = { tower = tower, training = training == true, replay = s.replay_mode == true, boss = boss, elite = elite, floor = floor, route = s.route, tactic = tactic.name, tactic_atk = tactic.atk or 0, tactic_shield = tactic.shield or 0, opening_bonus = s.relic == 4 and 8 or 0, event_gold = event.gold or 0, event_essence = event.essence or 0, event_tickets = event.tickets or 0, foe = name, foe_trait = trait, hero_trait = s.hero == 3 and "灼伤" or s.hero == 5 and "潮愈" or s.hero == 2 and "迅击" or s.hero == 6 and "背刺" or "坚韧", foe_hp = hp, foe_max = hp, foe_atk = atk, foe_shield = 0, foe_burn = 0, foe_phase = false, hero_hp = opening_hp, hero_max = max_hp, shield = opening_shield, force_crit = event.force_crit or false, crit_chance = math.min(40, (WEAPONS[s.weapon].crit or 0) + (s.hero == 2 and 8 or 0) + (s.hero == 6 and 5 or 0) + (s.partner == 5 and 4 or 0) + (s.partner == 6 and 4 or 0) + (tactic.crit or 0)), guard = false, skill_used = false, skill_used_slots = { false, false, false }, relic_saved = false, ribbon_used = false, dawn_used = false, dodge = false, fake_death = false, tidal = false, mole_used = false, log = training and "训练开始 · 不消耗资源 · 战技可用" or ("战术 " .. tactic.name .. " · 敌 " .. trait.name .. " · 战技可用"), turn = 1, fx_ms = 0, fx_label = "" }
  s.event_bonus = nil
  if tactic.start_damage then s.battle.log = s.battle.log .. " 先手灼伤 -" .. tactic.start_damage .. "生命。" end
  if tactic.shield then s.battle.log = s.battle.log .. " 开场护盾 +" .. tactic.shield .. "。" end
  if opening_shield > (tactic.shield or 0) then s.battle.fx_label = "开场护盾 +" .. (opening_shield - (tactic.shield or 0)) end
  if s.relic == 4 then s.battle.fx_label = "罗盘首击 +8" end
end
local function finish_battle(s, won)
  local b = s.battle
  if b and b.training then
    s.last_battle = { won = won, foe = b.foe, floor = b.floor, turn = b.turn, training = true }
    s.history = s.history or {}; table.insert(s.history, 1, { won = won, foe = b.foe, floor = b.floor, turn = b.turn, training = true }); while #s.history > 8 do table.remove(s.history) end
    s.message = won and "训练完成：战斗数据已记录，不消耗资源也不推进远征。" or "训练结束：调整构筑后可再次测试，不影响远征进度。"
    s.battle = nil; s.screen = "result"; s.result = won and "训练完成" or "训练结束"; s.loot_options = nil; s.loot_claimed = true; return
  end
  local replay = b and b.replay == true
  if replay then
    s.last_battle = { won = won, foe = b.foe, floor = b.floor, turn = b.turn, replay = true }
    s.history = s.history or {}; table.insert(s.history, 1, { won = won, foe = b.foe, floor = b.floor, turn = b.turn, replay = true }); while #s.history > 8 do table.remove(s.history) end
    s.message = won and "重播完成：本次不重复领取奖励，构筑记录已保留。" or "重播结束：本次不影响养成进度。"
    s.floor = s.replay_return_floor or s.floor; s.route = nil; s.replay_return_floor = nil; s.replay_mode = false; s.battle = nil; s.screen = "result"; s.result = won and "重播胜利" or "重播撤退"; s.loot_options = nil; s.loot_claimed = true
    return
  end
  local coins_before, essence_before, tickets_before = s.coins, s.essence, s.tickets
  if won then
    local gold = 18 + b.floor * 5 + (b.event_gold or 0) + (s.relic == 1 and 5 or 0); local route = b.route and ROUTES[b.route]
    s.essence = s.essence + (b.event_essence or 0); s.tickets = s.tickets + (b.event_tickets or 0)
    if route and not b.tower then gold = gold + (b.route == 1 and 12 or 0); s.essence = s.essence + (b.route == 3 and 1 or 0) end
    local hero_xp_gain = 10 + b.floor * 2; s.last_hero_xp_gain = hero_xp_gain; s.coins = s.coins + gold; s.essence = s.essence + 1; gain_xp(s, 12 + b.floor * 4 + (route and b.route == 2 and 8 or 0)); gain_hero_xp(s, hero_xp_gain)
    if b.tower then
      s.bounty_progress[3] = math.min(2, (s.bounty_progress[3] or 0) + 1)
      if b.floor > s.tower_best then
        s.tower_best = b.floor; s.essence = s.essence + 2
        if b.floor == 50 then s.coins = s.coins + 360; s.tickets = s.tickets + 2; s.essence = s.essence + 90; s.message = "第 50 层斗神宝藏：金币 +360、精粹 +90、招募券 +2。"
        elseif b.floor == 35 then s.coins = s.coins + 260; s.tickets = s.tickets + 2; s.essence = s.essence + 60; s.message = "第 35 层冠冕：金币 +260、精粹 +60、招募券 +2。"
        elseif b.floor == 20 then s.coins = s.coins + 180; s.tickets = s.tickets + 1; s.essence = s.essence + 40; s.message = "第 20 层试炼箱：金币 +180、精粹 +40、招募券 +1。"
        elseif b.floor == 10 then s.coins = s.coins + 120; s.tickets = s.tickets + 1; s.essence = s.essence + 24; s.message = "第 10 层徽章：金币 +120、精粹 +24、招募券 +1。"
        elseif b.floor == 5 then s.coins = s.coins + 80; s.essence = s.essence + 16; s.message = "第 5 层补给：金币 +80、精粹 +16。"
        else s.message = "塔层纪录刷新：" .. b.floor .. " 层，获得精粹。" end
      else s.message = "塔战胜利，获得 " .. gold .. " 金币。" end
    else
      if b.floor % 10 == 0 then s.tickets = s.tickets + 1 end
      local season_boss = b.floor % 30 == 0
      if season_boss then
        s.season_victories = (s.season_victories or 0) + 1
        s.shop_buys = { false, false, false }
        if s.season_victories % 3 == 0 then s.tickets = s.tickets + 1; s.essence = s.essence + 18; s.message = "赛季首领击破！远征已重开，商店货架与赛季奖励已刷新。"
        else s.message = "赛季首领击破！远征已重开，保底券已收入。" end
        s.floor = 1
      else s.floor = s.floor + 1; s.message = "远征胜利，获得 " .. gold .. " 金币。" end
      s.route = nil; s.bounty_progress[1] = math.min(3, (s.bounty_progress[1] or 0) + 1); s.bounty_progress[2] = math.min(1, (s.bounty_progress[2] or 0) + (b.floor % 10 == 0 and 1 or 0))
    end
  else s.last_hero_xp_gain = 0; s.message = "本次失利。强化装备或换一种指令再来。" end
  s.last_reward = { coins = s.coins - coins_before, essence = s.essence - essence_before, tickets = s.tickets - tickets_before, hero_xp = s.last_hero_xp_gain or 0 }
  s.last_battle = { won = won, foe = b.foe, floor = b.floor, turn = b.turn, tower = b.tower == true }
  s.history = s.history or {}; table.insert(s.history, 1, { won = won, foe = b.foe, floor = b.floor, turn = b.turn, tower = b.tower == true }); while #s.history > 8 do table.remove(s.history) end
  -- 胜负都进入结算页：失败也要给玩家清晰战报、重整入口和可持续的下一步。
  s.battle = nil; s.screen = "result"; s.result = won and "胜利" or "撤退"; s.loot_choice = 1; s.loot_claimed = false
  if won then
    -- 三个槽位随远征场次轮换收藏类型，保证长期游玩能逐步遇到英雄、装备、战技、伙伴与遗物。
    local kinds = { "heroes", "weapons", "skills", "partners", "relics" }
    local lists = { HEROES, WEAPONS, SKILLS, PARTNERS, RELICS }
    s.loot_options = {}
    for slot = 1, 3 do
      local kind_index = ((b.floor + slot - 2) % #kinds) + 1; local kind = kinds[kind_index]; local entries = lists[kind_index]; local index = rand(s, #entries); local entry = entries[index]; local name = type(entry) == "table" and entry.name or entry
      local sprite = kind == "heroes" and RESULT_HERO_SPRITES[index] or kind == "weapons" and WEAPON_SPRITES[index] or kind == "skills" and SKILL_SPRITES[index] or kind == "partners" and PARTNER_SPRITES[index] or RELIC_SPRITES[index]
      s.loot_options[slot] = { kind = kind, index = index, sprite = sprite, label = (kind == "heroes" and "英雄 · " or kind == "weapons" and "武器 · " or kind == "skills" and "战技 · " or kind == "partners" and "伙伴 · " or "遗物 · ") .. name }
    end
  else s.loot_options = nil end
end
local function battle_action(s, kind)
  local b, w = s.battle, WEAPONS[s.weapon]
  if not b then return end
  b.fx_target = kind == 3 and "hero" or "foe"
  local enemy_note = ""; local behavior = b.foe_trait and b.foe_trait.behavior
  if b.foe_burn and b.foe_burn > 0 then b.hero_hp = b.hero_hp - 3; b.foe_burn = b.foe_burn - 1; enemy_note = enemy_note .. "·灼伤 -3" end
  if behavior == "shield" and b.turn % 3 == 0 then b.foe_shield = math.max(b.foe_shield or 0, 18); enemy_note = enemy_note .. "·石甲护盾 +18" end
  if behavior == "burn" and b.turn % 4 == 1 then b.foe_burn = math.max(b.foe_burn or 0, 3); enemy_note = enemy_note .. "·持续灼伤" end
  if behavior == "steal" and b.turn % 4 == 1 and b.steal_turn ~= b.turn then rotate_weapon(s); b.steal_turn = b.turn; w = WEAPONS[s.weapon]; enemy_note = enemy_note .. "·偷取触发" end
  if behavior == "pounce" and b.turn % 4 == 0 then b.enemy_power_bonus = 6; enemy_note = enemy_note .. "·蓄力扑击" end
  if behavior == "boss" and not b.foe_phase and b.foe_hp <= b.foe_max * 0.5 then b.foe_phase = true; b.foe_shield = math.max(b.foe_shield or 0, 16); b.enemy_power_bonus = 7; enemy_note = enemy_note .. "·首领转阶段" end
  local active_weapon, previous_weapon = s.weapon, b.last_weapon
  b.weapon_hits = (b.weapon_hits or 0) + 1; b.last_weapon = active_weapon
  local damage, label = hero_atk(s) + (b.tactic_atk or 0) + (b.turn == 1 and (b.opening_bonus or 0) or 0), "普攻" .. enemy_note
  if kind == 2 then
    label = "重击"
    if rand(s, 100) <= 25 then damage = 0; label = "重击落空" else damage = math.floor(damage * 1.65) end
  elseif kind == 3 then b.guard = true; b.hero_hp = math.min(b.hero_max, b.hero_hp + 3); damage = math.floor(damage * 0.55); label = "格挡反击"
  elseif kind == 4 then
    local skill_slot = s.skill_slot or 1
    if b.skill_used_slots[skill_slot] then b.log = "战技槽 " .. skill_slot .. " 已使用，轮换后再出招。"; return end
    b.skill_used_slots[skill_slot] = true; b.skill_used = true; label = SKILLS[s.skill] .. "·槽" .. skill_slot
    local rank = s.skill_levels[s.skill] or 0
    if s.skill == 1 then
      damage = math.floor(damage * (0.85 + rank * 0.08)); if b.hero_hp < b.hero_max * 0.65 then b.hero_hp = math.min(b.hero_max, b.hero_hp + 16 + rank * 2); label = label .. "·回春" end
    elseif s.skill == 2 then
      b.guard = true; damage = math.floor(damage * (0.9 + rank * 0.08)); label = label .. "·护体"
    elseif s.skill == 3 then
      b.foe_atk = math.max(1, b.foe_atk - 2); b.foe_bleeding = true; damage = math.floor(damage * (1.1 + rank * 0.08)); label = label .. "·流血刻印·破绽"
    elseif s.skill == 4 then
      b.dodge = true; damage = math.floor(damage * 0.8); label = label .. "·必闪"
    elseif s.skill == 5 then
      b.hero_hp = math.min(b.hero_max, b.hero_hp + 20 + rank * 2); damage = math.floor(damage * 0.65); label = label .. "·净化"
    elseif s.skill == 6 then
      b.guard = true; damage = math.floor(damage * (1.25 + rank * 0.1)); label = label .. "·反制"
    elseif s.skill == 7 then
      damage = math.floor(damage * (1.55 + rank * 0.12)); label = label .. "·增幅"
    elseif s.skill == 8 then
      b.fake_death = true; damage = math.floor(damage * 0.8); label = label .. "·假死护身"
    elseif s.skill == 9 then
      b.hero_hp = math.max(1, b.hero_hp - 12); damage = math.floor(damage * (2.1 + rank * 0.15)); label = label .. "·孤注"
    elseif s.skill == 10 then
      if b.hero_hp <= b.hero_max * 0.25 then b.shield = b.shield + 12; b.fake_death = true; label = label .. "·不屈护盾" end
      damage = math.floor(damage * (1.35 + rank * 0.1))
    elseif s.skill == 11 then
      if b.shield > 0 then local slam = math.floor(b.shield / 2); b.shield = b.shield - slam; damage = damage + slam; b.foe_locked = true; label = label .. "·盾击 " .. slam end
    elseif s.skill == 12 then
      b.shield = b.shield + 14; b.tidal = true; damage = math.floor(damage * 0.8); label = label .. "·潮汐护盾"
    elseif s.skill == 13 then
      b.crit_chance = math.min(55, b.crit_chance + 10); damage = math.floor(damage * 0.9); label = label .. "·幸运"
    elseif s.skill == 14 then
      damage = damage + 8 + (b.foe_burned and 4 or 0); label = label .. "·流星 " .. (b.foe_burned and "+12" or "+8")
    else
      damage = math.floor(damage * (1.7 + rank * 0.15))
    end
  end
  -- 每把武器都有一个轻量、可观察的触发，不改变 800×480 的操作节奏。
  if active_weapon == 1 and previous_weapon == 1 then damage = damage + 3; label = label .. "·连斩" end
  if active_weapon == 2 and rand(s, 100) <= 20 then b.foe_locked = true; label = label .. "·击晕" end
  if active_weapon == 3 then b.shield = b.shield + 5; label = label .. "·护盾+5" end
  if active_weapon == 5 then damage = damage + math.floor(damage * 0.65); label = label .. "·双刃" end
  if active_weapon == 6 and (b.foe_burned or b.foe_bleeding) then damage = damage + 8; label = label .. "·撕裂" end
  if active_weapon == 7 then b.foe_burned = true; damage = damage + 2; label = label .. "·灼伤" end
  if active_weapon == 8 then b.foe_locked = true; label = label .. "·束缚" end
  if active_weapon == 9 then local bonus = rand(s, 36); damage = damage + bonus; label = label .. "·骰面+" .. bonus end
  if active_weapon == 11 and b.foe_hp == b.foe_max then damage = damage + 12; label = label .. "·破绽" end
  if active_weapon == 12 or active_weapon == 14 then b.dodge = true; label = label .. "·闪避准备" end
  if active_weapon == 13 and b.shield > 0 then local slam = math.min(8, b.shield); damage = damage + slam; label = label .. "·盾击+" .. slam end
  if active_weapon == 15 then b.foe_locked = true; label = label .. "·压制" end
  if active_weapon == 16 and rand(s, 100) <= 35 then b.extra_rotate = true; label = label .. "·提前轮换" end
  if active_weapon == 17 then if b.foe_stunned then damage = math.max(damage, math.floor(b.foe_max * 0.18)); label = label .. "·处决" elseif rand(s, 100) <= 30 then b.foe_stunned = true; label = label .. "·震晕" end end
  if active_weapon == 18 and b.foe_burned then damage = damage + 4; label = label .. "·灼热" end
  b.fx_label = label; b.fx_ms = 650
  if b.foe_trait and b.foe_trait.name == "硬壳" and b.turn % 2 == 1 then damage = math.floor(damage * 0.8); label = label .. "·硬壳" end
  if s.hero == 3 then damage = damage + 2 + (s.relic == 2 and 2 or 0); b.foe_burned = true; label = label .. (s.relic == 2 and "·天气灼伤" or "·灼伤") end
  if s.partner == 3 and b.foe_burned then damage = damage + 5; label = label .. "·焰尾" end
  if b.tidal and b.foe_burned then damage = math.floor(damage * 0.5); b.tidal = false; label = label .. "·异常减半" end
  local critical = damage > 0 and ((b.force_crit and b.turn == 1) or rand(s, 100) <= (b.crit_chance or w.crit or 0))
  if critical then
    damage = math.floor(damage * 1.5); label = label .. " 暴击"
    if s.relic == 5 and not b.ribbon_used then b.ribbon_used = true; b.hero_hp = math.min(b.hero_max, b.hero_hp + 10); label = label .. "·缎带回春" end
    if s.relic == 6 and not b.dawn_used then b.dawn_used = true; b.dodge = true; label = label .. "·羽毛闪避" end
  end
  local foe_absorbed = math.min(b.foe_shield or 0, math.max(0, damage)); b.foe_shield = math.max(0, (b.foe_shield or 0) - foe_absorbed); damage = damage - foe_absorbed
  if foe_absorbed > 0 then label = label .. "·敌盾吸收 " .. foe_absorbed end
  b.foe_hp = b.foe_hp - damage
  if b.foe_hp <= 0 then b.log = label .. "造成 " .. damage .. " 点伤害！"; finish_battle(s, true); return end
  local enemy = b.foe_atk + (b.enemy_power_bonus or 0); b.enemy_power_bonus = 0
  if b.foe_trait then
    if b.foe_trait.name == "回响" and b.turn % 3 == 0 then b.foe_hp = math.min(b.foe_max, b.foe_hp + 3); label = label .. "·回响" end
    if b.foe_trait.name == "猛扑" and b.turn % 3 == 0 then enemy = enemy + 4; label = label .. "·猛扑" end
    if b.foe_trait.name == "反击" and kind == 2 then enemy = enemy + 3; label = label .. "·反击" end
    if b.foe_trait.name == "震荡" and b.turn % 4 == 0 then enemy = enemy + 6; label = label .. "·震荡" end
  end
  if b.foe_locked then enemy = 0; b.foe_locked = false; label = label .. "·跳过反击" end
  if b.dodge then enemy = 0; b.dodge = false; label = label .. "·闪避成功" end
  if s.relic == 1 and rand(s, 100) <= 25 then
    b.turn = b.turn + 1; b.log = label .. " " .. damage .. " · 回响硬币免去反击"; rotate_weapon(s); rotate_skill(s); if b.extra_rotate then rotate_weapon(s); b.extra_rotate = false end; b.next_weapon = s.weapon; b.next_skill = s.skill; return
  end
  if b.guard then enemy = math.max(1, math.floor(enemy * math.max(0.2, 0.35 - (w.guard + (s.partner == 4 and 10 or 0)) / 100))); b.guard = false end
  local shield_before = b.shield or 0; local absorbed = math.min(shield_before, enemy); b.shield = math.max(0, shield_before - absorbed); enemy = enemy - absorbed
  if s.partner == 5 and shield_before > 0 and b.shield == 0 and not b.mole_used then b.mole_used = true; b.shield = 10; label = label .. "·鼹鼠补盾" end
  b.hero_hp = b.hero_hp - enemy; b.turn = b.turn + 1
  if s.hero == 5 and b.turn % 2 == 0 then b.hero_hp = math.min(b.hero_max, b.hero_hp + 4 + (s.partner == 6 and 2 or 0)); label = label .. "·潮愈" end
  if s.partner == 1 and b.turn % 3 == 0 then b.hero_hp = math.min(b.hero_max, b.hero_hp + 8); label = label .. "·苔藓疗愈" end
  b.log = label .. " " .. damage .. "  /  敌方反击 " .. enemy .. (absorbed > 0 and ("（护盾吸收 " .. absorbed .. "）") or "")
  if b.hero_hp <= 0 and b.fake_death then b.hero_hp = 1; b.fake_death = false; b.foe_locked = true; b.log = label .. " · 假死保命，敌方下回合失衡"; rotate_weapon(s); rotate_skill(s); b.next_weapon = s.weapon; b.next_skill = s.skill
  elseif b.hero_hp <= 0 then finish_battle(s, false) else rotate_weapon(s); rotate_skill(s); if b.extra_rotate then rotate_weapon(s); b.extra_rotate = false end; b.next_weapon = s.weapon; b.next_skill = s.skill end
end

local function draw_header(g, s)
  g:rect(0, 0, W, 50, "fill", 15); text(g, 22, 16, "勇者大乐斗", 0)
  text(g, 555, 16, "金 " .. s.coins .. "  精 " .. s.essence .. "  券 " .. s.tickets, 0)
  for i, name in ipairs(TABS) do
    local x = 20 + (i - 1) * 108
    if s.tab == i then g:rect(x, 58, 94, 30, "fill", 15); text(g, x + 14, 66, name, 0) else text(g, x + 14, 66, name, 15) end
  end
  g:line(20, 98, 780, 98, 15)
end
local function draw_avatar(g, x, y, enemy, index)
  g:image(enemy and FOE_SPRITES[index or 1] or HERO_SPRITES[index or 1], x, y)
end
local function draw_camp(ctx, g, s)
  text(g, 34, 122, "冒险者营地  ·  Lv." .. s.level)
  -- 176×220 的大立绘独占左卡片，信息移到右侧，避免文字压在素材上。
  g:rect(30, 145, 268, 250, "stroke", 15); draw_avatar(g, 76, 151, false, s.hero)
  g:rect(326, 145, 442, 250, "stroke", 15); text(g, 356, 170, "当前出战")
  text(g, 356, 192, HEROES[s.hero] .. "  Lv." .. hero_level(s)); text(g, 356, 214, "生命 " .. hero_hp(s) .. "   攻击 " .. hero_atk(s))
  text(g, 356, 234, hero_level(s) >= HERO_LEVEL_CAP and "英雄经验已满" or ("经验 " .. (s.hero_xp[s.hero] or 0) .. "/" .. hero_xp_need(hero_level(s))), 8)
  text(g, 356, 250, "战技 · 伙伴 · 遗物已装备（装备页可调整）", 8)
  button(g, 356, 264, 370, 40, "领取每日补给  +30 金币 / +1 招募券", s.selected == 1, false)
  button(g, 356, 312, 370, 40, "英雄阶位  " .. hero_rank_label(s) .. "  · " .. s.hero_echoes[s.hero] .. "/" .. hero_rank_need(s) .. " 回响", s.selected == 2, s.hero_ranks[s.hero] >= HERO_RANK_CAP or s.hero_echoes[s.hero] < hero_rank_need(s))
  button(g, 356, 360, 370, 40, "进入试炼塔  ·  最高 " .. s.tower_best .. " 层", s.selected == 3, false)
  local report = s.last_battle and ((s.last_battle.training and "训练" or (s.last_battle.won and "胜利" or "撤退")) .. " · " .. (s.last_battle.foe or "未知对手") .. " · " .. (s.last_battle.turn or 0) .. " 回合") or "尚未完成战斗"
  text(g, 30, 424, "最近战报 · " .. report, 8)
  button(g, 356, 410, 210, 38, "训练场 · 不消耗", s.selected == 5, false)
  button(g, 590, 412, 178, 38, "重播最近战报", s.selected == 4, s.last_replay == nil)
  text(g, 30, 454, utf8_slice(s.message or "营地已经准备好。", 1, 48), 8)
end
local function draw_gacha(g, s)
  text(g, 34, 122, "招募所  ·  每张券都会转化为实际战力")
  g:rect(30, 150, 370, 220, "stroke", 15); text(g, 54, 180, "限时常驻 · 星辉英雄池"); draw_avatar(g, 64, 150, false, 2)
  if s.last_draw then
    local recent = s.last_draws or {}
    if #recent > 1 then
      local shown = math.min(4, #recent)
      for i = 1, shown do g:image(recent[i].sprite or "weapon_star", 48 + (i - 1) * 88, 286) end
      text(g, 54, 346, "最近 " .. #recent .. " 次 · " .. utf8_slice(s.last_draw.label or "补给结果", 1, 9), 15)
    else
      g:image(s.last_draw.sprite or "weapon_star", 286, 286); text(g, 250, 324, "最近获得", 8); text(g, 250, 346, utf8_slice(s.last_draw.label or "补给结果", 1, 10), 15)
    end
  else
    g:image("weapon_star", 286, 286); text(g, 250, 346, "抽卡后揭晓", 8)
  end
  text(g, 250, 234, "英雄池"); text(g, 250, 262, "招募英雄")
  button(g, 430, 150, 330, 46, s.hero_free and "招募 1 次  ·  免费" or "招募 1 次  ·  1 券", s.selected == 1, not s.hero_free and s.tickets < 1 and s.coins < 120)
  button(g, 430, 204, 330, 46, "80 金币换 1 券", s.selected == 2, s.coins < 80)
  button(g, 430, 258, 330, 46, "连招 5 次  ·  5 券", s.selected == 3, s.tickets < 5 and s.coins < 520)
  button(g, 430, 312, 330, 46, "战备 1 次  ·  1 券", s.selected == 4, s.tickets < 1 and s.coins < 80)
  text(g, 34, 390, "状态 · " .. utf8_slice(s.message or "招募准备就绪。", 1, 26), 8)
  text(g, 430, 390, "保底  " .. s.gacha_pity .. "/10  ·  " .. s.gear_pity .. "/10", 8)
  button(g, 34, 410, 370, 42, "战备连招 5 次", s.selected == 6, s.tickets < 5 and s.coins < 360)
  button(g, 430, 410, 330, 42, "进入商店", s.selected == 5, false)
end
local function draw_shop(g, s)
  text(g, 34, 122, "补给商店  ·  远征金币与精粹在这里循环转化")
  button(g, 626, 106, 140, 30, "返回招募", false, false)
  g:rect(34, 150, 732, 70, "stroke", 15); text(g, 62, 176, "商店货架每轮各限购一次，完成远征后继续积累资源。")
  button(g, 34, 240, 732, 54, "招募券 ×1  ·  60 金币", s.selected == 1, s.shop_buys[1] or s.coins < 60)
  button(g, 34, 306, 732, 54, "精粹 ×2  ·  120 金币", s.selected == 2, s.shop_buys[2] or s.coins < 120)
  button(g, 34, 372, 732, 54, "金币 ×70  ·  4 精粹", s.selected == 3, s.shop_buys[3] or s.essence < 4)
  text(g, 34, 456, utf8_slice(s.message or "商店准备就绪。", 1, 58), 8)
end
local function draw_bag(g, s)
  text(g, 34, 122, "装备  ·  当前槽 " .. s.weapon_slot .. "：" .. WEAPONS[s.weapon].name .. "  ·  三武器轮换")
  for i = 1, 4 do local w = WEAPONS[i]
    local x, y = 34 + ((i - 1) % 2) * 374, 150 + math.floor((i - 1) / 2) * 102
    g:rect(x, y, 350, 96, "stroke", 15); if s.weapon == i then g:rect(x + 4, y + 4, 8, 88, "fill", 15) end
    g:image(COLLECTION_WEAPON_SPRITES[i], x + 230, y)
    text(g, x + 24, y + 16, s.weapon_owned[i] and (w.name .. "  +" .. w.atk .. " 攻") or "尚未发现")
    text(g, x + 24, y + 42, s.weapon_owned[i] and (w.kind .. " · 强化 " .. (s.weapon_levels[i] or 0) .. "/5" .. (weapon_slot_label(s, i) ~= "" and (" · " .. weapon_slot_label(s, i)) or "")) or "未获得", s.weapon_owned[i] and 15 or 8)
    if s.selected == i then g:rect(x + 270, y + 18, 60, 48, "fill", 15); text(g, x + 278, y + 34, "选中", 0) end
  end
  button(g, 34, 354, 350, 48, "切换武器槽  1→2→3", s.selected == 5, false)
  button(g, 410, 354, 350, 48, "强化当前  ·  2 精粹", s.selected == 6, s.essence < 2 or (s.weapon_levels[s.weapon] or 0) >= 5)
  local loadout = {
    { key = PARTNER_SPRITES[s.partner], label = "伙伴  " .. PARTNERS[s.partner], selected = s.selected == 7 },
    { key = SKILL_SPRITES[s.skill], label = "战技槽" .. s.skill_slot .. "  " .. SKILLS[s.skill] .. " Lv." .. (s.skill_levels[s.skill] or 0), selected = s.selected == 8 },
    { key = RELIC_SPRITES[s.relic], label = "遗物  " .. RELICS[s.relic], selected = s.selected == 9 },
  }
  for i, item in ipairs(loadout) do
    local x = 34 + (i - 1) * 246
    g:rect(x, 404, 240, 76, "stroke", 15); g:image(item.key, x + 6, 404)
    text(g, x + 110, 420, utf8_slice(item.label, 1, 11)); text(g, x + 110, 446, item.selected and "OK 切换" or "已装配", item.selected and 15 or 8)
  end
end
local function draw_collection(g, s)
  local kind = s.collection_type or 1; local entries, sprites, owned = collection_def(s, kind); local pages = collection_pages(s); s.collection_page = clamp(s.collection_page or 1, 1, pages); local page = s.collection_page
  -- 小屏横屏优先：分类与分页按钮提高到 32px，压缩说明文字，把可视面积留给卡片。
  for i, label in ipairs(COLLECTION_LABELS) do button(g, 30 + (i - 1) * 128, 98, 118, 32, label, kind == i, false) end
  button(g, 690, 98, 80, 32, "页 " .. page .. "/" .. pages, false, pages == 1)
  text(g, 34, 136, "收藏册  ·  " .. COLLECTION_LABELS[kind] .. "  ·  已发现 " .. collection_count(s) .. "/50")
  text(g, 34, 154, collection_summary(s), 8); text(g, 610, 154, collection_next_goal(s), 8)
  local first = (page - 1) * 4
  for slot = 1, 4 do
    local actual = first + slot; local entry = entries[actual]
    if entry then
      local x = 30 + ((slot - 1) % 2) * 370
      local y = 174 + math.floor((slot - 1) / 2) * 150
      local found = owned[actual] == true; local equipped = found and collection_equipped(s, kind, actual)
      g:rect(x, y, 360, 150, "stroke", 15); if equipped then g:rect(x + 4, y + 4, 8, 142, "fill", 15) elseif s.selected == actual then g:rect(x + 4, y + 4, 4, 142, "fill", 8) end
      -- 锁定条目也展示对应的 XIC 轮廓，配合“尚未发现”状态文字保留收集目标，避免收藏册出现大片空白卡片。
      g:image(sprites[actual], x + 8, y)
      text(g, x + 194, y + 30, found and collection_entry_name(entries, actual) or "尚未发现", found and 15 or 8)
      local detail = found and "已发现" or "未获得"
      if found and kind == 1 then detail = "Lv." .. (s.hero_levels[actual] or 1) .. " " .. hero_rank_label(s, actual) .. (equipped and " · 出战" or "")
      elseif found and kind == 2 then detail = "攻+" .. entry.atk .. "  强化 " .. (s.weapon_levels[actual] or 0) .. "/5" .. (equipped and " · 装备" or "")
      elseif found and kind == 3 then detail = "战技 Lv." .. (s.skill_levels[actual] or 0) .. "  " .. (equipped and "当前" or "可切换")
      elseif found and kind == 4 then detail = "伙伴 " .. (equipped and "· 当前" or "· 可切换")
      elseif found and kind == 5 then detail = "遗物 " .. (equipped and "· 当前" or "· 可切换") end
      text(g, x + 194, y + 58, detail, found and 15 or 8)
      text(g, x + 194, y + 86, equipped and "正在使用" or (found and "可切换" or "未获得"), equipped and 15 or 8)
    end
  end
end
local function draw_path(g, x, y, count, current, tower)
  local step = count == 10 and 25 or 46
  local end_x = x + (count - 1) * step
  g:line(x, y + 7, end_x, y + 7, 8)
  for i = 1, count do
    local px = x + (i - 1) * step
    local done = i < current
    local active = i == current
    if done then g:rect(px, y, 15, 15, "fill", 15)
    elseif active then g:rect(px, y, 15, 15, "stroke", 15); g:rect(px + 4, y + 4, 7, 7, "fill", 15)
    else g:rect(px, y, 15, 15, "stroke", 8) end
    if tower and i == count then text(g, px + 3, y + 18, "♛", 15) end
  end
end
local function draw_expedition(g, s, tower)
  local floor, hp, atk, foe, trait = foe_stats(s, tower)
  text(g, 34, 122, tower and "试炼塔  ·  每层都是一次资源检验" or "远征  ·  失败不会丢失养成")
  local local_floor = ((floor - 1) % 10) + 1
  local zone = ZONES[math.floor((floor - 1) / 10) % #ZONES + 1]
  g:rect(34, 150, 292, 260, "stroke", 15); draw_avatar(g, 92, 150, true, ((floor - 1) % #FOE_SPRITES) + 1); text(g, 66, 342, foe); text(g, 66, 366, tower and ("最高纪录 " .. s.tower_best .. " 层") or (zone .. "  ·  " .. local_floor .. "/10"), 8)
  draw_path(g, 51, 386, tower and 5 or 10, tower and 1 or local_floor, tower)
  g:rect(354, 150, 406, 260, "stroke", 15); text(g, 386, 182, tower and ("第 " .. floor .. " 层守关者") or (floor % 30 == 0 and ("第 " .. floor .. " 场赛季首领") or floor % 10 == 0 and ("第 " .. floor .. " 场赛季首领") or floor % 5 == 0 and ("第 " .. floor .. " 场精英") or ("第 " .. floor .. " 场对手"))); bar(g, 386, 232, 300, hp, hp, "敌方生命"); text(g, 386, 282, "敌方攻击 " .. atk); text(g, 386, 316, "特性 " .. trait.name)
  button(g, 386, 344, 300, 50, tower and "挑战此层" or (s.route and "进入乐斗" or "选择路线"), s.selected == 1, false)
  text(g, 34, 436, tower and ("塔律：" .. tower_law(floor).name .. " · 调整构筑应对") or (s.route and ("已选路线：" .. ROUTES[s.route].name) or ("赛季回响 " .. s.season_victories .. " 次 · 第 30 场通关后重开")))
end
local function draw_route(g, s)
  text(g, 34, 122, "路线抉择  ·  选一条路，把它带进本场乐斗")
  button(g, 626, 106, 140, 30, "返回远征", false, false)
  for i, tactic in ipairs(TACTICS) do
    local x = 34 + (i - 1) * 246
    button(g, x, 140, 228, 38, tactic.name .. " · " .. tactic.short, s.tactic == i, false)
  end
  for i, route in ipairs(ROUTES) do
    local y = 188 + (i - 1) * 82
    button(g, 34, y, 732, 66, route.name .. "  ·  " .. route.text, s.route_choice == i, false)
  end
  text(g, 34, 452, "←→ 选择战术   ↑↓ 选择路线   OK 确认   BACK 返回远征")
end
local function draw_event(g, s)
  text(g, 34, 122, "远征事件  ·  先做决定，再进入本场乐斗")
  button(g, 626, 106, 140, 30, "返回路线", false, false)
  g:rect(34, 150, 732, 64, "stroke", 15); text(g, 62, 174, "临时营地：选择一项，让本场战斗产生不同节奏。", 15); text(g, 62, 196, "图标对应事件类型，确认后立即进入乐斗。", 15)
  local options = event_options(s)
  for i = 1, 3 do local event = EVENTS[options[i]]; local y = 224 + (i - 1) * 82; g:rect(34, y, 732, 76, "stroke", 15); g:image(event.sprite, 40, y); text(g, 128, y + 18, event.name); text(g, 128, y + 42, event.text); text(g, 590, y + 42, s.event_choice == i and "已选 · OK" or event.reward, s.event_choice == i and 15 or 8) end
  -- 选项本身已经有清晰的选中态；省略底部说明，给小屏保留安全边距。
end
local function draw_training(g, s)
  text(g, 34, 122, "训练场  ·  无消耗测试，观察真实战斗逻辑")
  button(g, 626, 106, 140, 30, "返回营地", false, false)
  g:rect(34, 150, 284, 250, "stroke", 15); draw_avatar(g, 78, 164, false, s.hero); text(g, 64, 370, HEROES[s.hero] .. "  Lv." .. hero_level(s)); text(g, 64, 388, "生命 " .. hero_hp(s) .. "  攻击 " .. hero_atk(s), 8)
  g:rect(346, 150, 420, 250, "stroke", 15); text(g, 376, 180, "石甲假人")
  draw_avatar(g, 580, 170, true, 3)
  text(g, 376, 226, "不会推进远征层数，也不会", 8); text(g, 376, 246, "发放金币、精粹或战利品。", 8)
  text(g, 376, 278, "可观察武器轮换、战技触发、", 8); text(g, 376, 298, "护盾和异常状态。", 8)
  text(g, 376, 322, "构筑  " .. WEAPONS[s.weapon].name .. " · " .. SKILLS[s.skill], 8)
  button(g, 376, 334, 300, 50, "开始训练", s.selected == 1, false)
  text(g, 34, 436, "BACK 返回营地 · 训练结果会写入战报，但不改变正式进度。", 8)
end
local function draw_bounties(g, s)
  text(g, 34, 122, "悬赏板  ·  第 " .. s.bounty_cycle .. " 轮 · 完成短目标，领取额外资源")
  local names = { "竞技三连", "首领悬赏", "塔顶试炼" }
  local needs = { 3, 1, 2 }
  local rewards = { "60 金币 + 1 招募券", "20 精粹 + 1 招募券", "40 金币 + 16 精粹" }
  for i = 1, 3 do
    local y = 150 + (i - 1) * 88
    local progress = s.bounty_progress[i] or 0
    local label = names[i] .. "  " .. progress .. "/" .. needs[i] .. "  ·  " .. rewards[i]
    if s.bounty_choice == i then
      g:rect(34, y, 732, 76, "stroke", 15); g:rect(38, y + 4, 7, 68, "fill", 15); text(g, 50, y + 30, label, 15)
    else
      button(g, 34, y, 732, 76, label, false, progress < needs[i] or s.bounty_claimed[i])
    end
    g:image(BOUNTY_SPRITES[i], 680, y)
  end
  text(g, 34, 430, "↑↓ 选择悬赏   OK 领取   奖励会直接进入存档。")
end
local function draw_battle(g, s)
  local b = s.battle; g:clear(0); g:rect(0, 0, W, 50, "fill", 15); text(g, 24, 16, b.tower and "试炼塔战斗" or (b.boss and "远征首领战" or "远征战斗"), 0); text(g, 450, 16, "槽 " .. s.weapon_slot .. " · " .. WEAPONS[s.weapon].name, 0); text(g, 690, 16, "第 " .. b.turn .. " 回合", 0)
  button(g, 20, 54, 112, 28, "撤退", false, false)
  -- 大立绘上移，姓名/特性/生命条独立成一层，保证素材与信息不互相遮挡。
  draw_avatar(g, 54, 78, false, s.hero); draw_avatar(g, 570, 90, true, ((b.floor - 1) % #FOE_SPRITES) + 1)
  -- 650ms 动作反馈：用安全边界内的高亮框和斜线提示目标，不依赖额外动画素材。
  if (b.fx_ms or 0) > 0 then
    local target_x, target_y = b.fx_target == "hero" and 48 or 564, b.fx_target == "hero" and 72 or 84
    local pulse = (b.fx_ms or 0) < 330 and 5 or 0
    g:rect(target_x - pulse, target_y - pulse, 188 + pulse * 2, 232 + pulse * 2, "stroke", 15)
    if b.fx_target ~= "hero" then
      local action = b.fx_label or ""
      if string.find(action, "暴击") then
        g:line(566, 88, 742, 248, 15); g:line(742, 88, 566, 248, 15)
        g:line(584, 88, 760, 248, 15); g:line(760, 88, 584, 248, 15)
      elseif string.find(action, "战技") then
        g:line(654, 82, 654, 254, 15); g:line(578, 168, 730, 168, 15)
        g:line(600, 114, 708, 222, 15); g:line(708, 114, 600, 222, 15)
      else
        g:line(566, 88, 742, 248, 15); g:line(742, 88, 566, 248, 15)
      end
    elseif string.find(b.fx_label or "", "格挡") then
      g:rect(58, 86, 164, 8, "fill", 15); g:rect(72, 104, 136, 136, "stroke", 15)
    else
      g:rect(58, 86, 164, 8, "fill", 15)
    end
  end
  text(g, 60, 306, HEROES[s.hero]); text(g, 570, 306, b.foe); bar(g, 50, 358, 260, b.hero_hp, b.hero_max, b.shield > 0 and ("你的生命 · 盾" .. b.shield) or "你的生命"); bar(g, 490, 358, 260, b.foe_hp, b.foe_max, (b.foe_shield or 0) > 0 and ("敌方生命 · 盾" .. b.foe_shield) or (b.foe_burn or 0) > 0 and ("敌方生命 · 灼" .. b.foe_burn) or "敌方生命")
  g:rect(248, 110, 304, 150, "stroke", 15)
  center(g, 400, 142, "本回合选择一项行动", 15)
  local battle_log = b.log or "等待你的下一步指令。"
  center(g, 400, 180, utf8_slice(battle_log, 1, 18), 15)
  if glyph_count(battle_log) > 18 then center(g, 400, 198, utf8_slice(battle_log, 19, 18), 15) end
  if (b.fx_ms or 0) > 0 then g:rect(292, 214, 216, 34, "fill", 15); center(g, 400, 223, b.fx_label, 0) end
  local skill_disabled = b.skill_used_slots[1] and b.skill_used_slots[2] and b.skill_used_slots[3]
  button(g, 34, 398, 174, 54, "普攻", s.selected == 1, false); button(g, 216, 398, 174, 54, "重击", s.selected == 2, false); button(g, 398, 398, 174, 54, "格挡", s.selected == 3, false); button(g, 580, 398, 186, 54, "战技  " .. SKILLS[s.skill], s.selected == 4, skill_disabled)
end
local function draw_result(g, s)
  g:clear(0); g:rect(40, 48, 720, 390, "stroke", 15); center(g, 400, 70, s.result, 15); draw_avatar(g, s.result == "胜利" and 312 or 328, s.result == "胜利" and 62 or 90, s.result ~= "胜利", s.result == "胜利" and s.hero or 5)
  if s.result == "胜利" and not s.loot_claimed then
    local reward = s.last_reward or { coins = 0, essence = 0, tickets = 0 }
    center(g, 400, 290, "收益  金币 +" .. (reward.coins or 0) .. "  精粹 +" .. (reward.essence or 0) .. "  券 +" .. (reward.tickets or 0), 15)
    center(g, 400, 308, "英雄经验 +" .. (reward.hero_xp or s.last_hero_xp_gain or 0), 15)
    center(g, 400, 326, "选择一件战利品", 15)
    local options = s.loot_options or { { label = "金币 +20" }, { label = "精粹 +2" }, { label = "武器强化 +1" } }
    for i, option in ipairs(options) do
      local x = 64 + (i - 1) * 229; local y = 344
      if s.loot_choice == i then
        -- Keep the selected card light so the large XIC icon remains readable.
        g:rect(x, y, 214, 76, "stroke", 15)
        g:rect(x + 4, y + 4, 7, 68, "fill", 15)
        g:image(option.sprite or "weapon_star", x + 8, y)
        text(g, x + 92, y + 30, option.label, 15)
      else
        g:rect(x, y, 214, 76, "stroke", 15)
        g:image(option.sprite or "weapon_star", x + 8, y)
        text(g, x + 92, y + 30, option.label, 15)
      end
    end
  else
    center(g, 400, 330, s.message, 15)
    if (s.result == "胜利" or s.result == "重播胜利") and s.loot_claimed then
      local choice = s.result_choice or 2
      button(g, 74, 366, 286, 44, "整理装备", choice == 1, false)
      local label = s.result == "胜利" and (s.last_battle and s.last_battle.tower and "继续试炼塔" or "继续远征") or "继续远征"
      button(g, 440, 366, 286, 44, label, choice == 2, false)
    else
      local label = s.result == "撤退" and "返回远征" or "回到营地"
      button(g, 250, 366, 300, 44, label, true, false)
    end
  end
end

function on_load(ctx) ctx:set_tick_rate("normal") end
function on_enter(ctx) state(ctx); ctx:invalidate() end
function on_tick(ctx, dt_ms)
  local s = state(ctx); local b = s.battle
  if b and (b.fx_ms or 0) > 0 then b.fx_ms = math.max(0, b.fx_ms - (dt_ms or 100)); ctx:invalidate() end
end
function on_draw(ctx, g)
  -- 以契约屏幕对象为运行时事实来源；当前 manifest 固定横屏，设计基准为 800×480。
  local screen_width, screen_height = ctx.screen.width, ctx.screen.height
  local s = state(ctx)
  if s.screen == "battle" then draw_battle(g, s); return end
  if s.screen == "result" then draw_result(g, s); return end
  g:clear(0)
  draw_header(g, s)
  if s.screen == "camp" then draw_camp(ctx, g, s)
  elseif s.screen == "gacha" then draw_gacha(g, s)
  elseif s.screen == "shop" then draw_shop(g, s)
  elseif s.screen == "bag" then draw_bag(g, s)
  elseif s.screen == "collection" then draw_collection(g, s)
  elseif s.screen == "route" then draw_route(g, s)
  elseif s.screen == "event" then draw_event(g, s)
  elseif s.screen == "training" then draw_training(g, s)
  elseif s.screen == "bounties" then draw_bounties(g, s)
  elseif s.screen == "expedition" then draw_expedition(g, s, false)
  else draw_expedition(g, s, true) end
end
local function select_tab(s, tab)
  s.tab = tab; s.selected = 1; s.screen = ({ "camp", "gacha", "bag", "collection", "expedition", "bounties", "tower" })[tab]
end
local function record_draw(s, sprite, label)
  s.last_draw = { sprite = sprite, label = label }
  s.last_draws = s.last_draws or {}
  table.insert(s.last_draws, 1, { sprite = sprite, label = label })
  while #s.last_draws > 5 do table.remove(s.last_draws) end
end
local function recruit_once(s)
  if s.bulk_draw then s.hero_free = false elseif s.hero_free then s.hero_free = false elseif s.tickets >= 1 then s.tickets = s.tickets - 1 elseif s.coins >= 120 then s.coins = s.coins - 120 else return false end
  local draw_sprite, draw_label
  s.gacha_pity = s.gacha_pity + 1; local roll = rand(s, 100)
  if s.gacha_pity >= 10 or roll <= 18 then local h = rand(s, #HEROES); s.gacha_pity = 0; draw_sprite = RESULT_HERO_SPRITES[h]; draw_label = HEROES[h]; if s.heroes[h] then local level = math.min(HERO_LEVEL_CAP, (s.hero_levels[h] or 1) + 1); s.hero_levels[h] = level; s.hero_echoes[h] = (s.hero_echoes[h] or 0) + (h >= 5 and 3 or h >= 3 and 2 or 1); s.essence = s.essence + 2; s.message = "英雄重复，" .. HEROES[h] .. " 升至 Lv." .. level .. "，获得回响并转化 2 精粹。" else s.heroes[h] = true; s.hero_levels[h] = s.hero_levels[h] or 1; s.message = "招募到英雄：" .. HEROES[h] end
  elseif roll <= 48 then local w = rand(s, #WEAPONS); draw_sprite = WEAPON_SPRITES[w]; draw_label = WEAPONS[w].name; grant_weapon_drop(s, w, "获得武器：")
  elseif roll <= 70 then local skill = rand(s, #SKILLS); draw_sprite = SKILL_SPRITES[skill]; draw_label = SKILLS[skill]; if s.skills[skill] then s.skill_levels[skill] = math.min(5, (s.skill_levels[skill] or 0) + 1); s.essence = s.essence + 1; s.message = "战技重复，" .. SKILLS[skill] .. " 升阶并转化 1 精粹。" else s.skills[skill] = true; s.skill = skill; s.message = "获得战技：" .. SKILLS[skill] end
  elseif roll <= 84 then local partner = rand(s, #PARTNERS); draw_sprite = PARTNER_SPRITES[partner]; draw_label = PARTNERS[partner]; if s.partners[partner] then s.essence = s.essence + 1; s.message = "伙伴重复，转化 1 精粹。" else s.partners[partner] = true; s.partner = partner; s.message = "伙伴加入：" .. PARTNERS[partner] end
  elseif roll <= 94 then local relic = rand(s, #RELICS); draw_sprite = RELIC_SPRITES[relic]; draw_label = RELICS[relic]; if s.relics[relic] then s.essence = s.essence + 1; s.message = "遗物重复，转化 1 精粹。" else s.relics[relic] = true; s.relic = relic; s.message = "遗物发现：" .. RELICS[relic] end
  else draw_sprite = "p_echo_coin"; draw_label = "精粹 +3"; s.essence = s.essence + 3; s.message = "转化为 3 精粹。" end
  record_draw(s, draw_sprite, draw_label)
  check_collection_rewards(s); return true
end
local function gear_once(s)
  if s.bulk_gear then s.gear_pity = s.gear_pity + 1 elseif s.tickets >= 1 then s.tickets = s.tickets - 1; s.gear_pity = s.gear_pity + 1 elseif s.coins >= 80 then s.coins = s.coins - 80; s.gear_pity = s.gear_pity + 1 else return false end
  local draw_sprite, draw_label
  local roll = rand(s, 100)
  if s.gear_pity >= 10 or roll <= 45 then local w = rand(s, #WEAPONS); s.gear_pity = 0; draw_sprite = WEAPON_SPRITES[w]; draw_label = WEAPONS[w].name; grant_weapon_drop(s, w, "战备补给：")
  elseif roll <= 70 then local skill = rand(s, #SKILLS); draw_sprite = SKILL_SPRITES[skill]; draw_label = SKILLS[skill]; if s.skills[skill] then s.skill_levels[skill] = math.min(5, (s.skill_levels[skill] or 0) + 1); s.essence = s.essence + 1; s.message = "战备重复战技，升阶并转化 1 精粹。" else s.skills[skill] = true; s.skill = skill; s.message = "战备补给：获得战技 " .. SKILLS[skill] .. "。" end
  elseif roll <= 88 then local partner = rand(s, #PARTNERS); draw_sprite = PARTNER_SPRITES[partner]; draw_label = PARTNERS[partner]; if s.partners[partner] then s.essence = s.essence + 1; s.message = "战备重复伙伴，转化 1 精粹。" else s.partners[partner] = true; s.partner = partner; s.message = "战备补给：伙伴加入 " .. PARTNERS[partner] .. "。" end
  else local relic = rand(s, #RELICS); draw_sprite = RELIC_SPRITES[relic]; draw_label = RELICS[relic]; if s.relics[relic] then s.essence = s.essence + 1; s.message = "战备重复遗物，转化 1 精粹。" else s.relics[relic] = true; s.relic = relic; s.message = "战备补给：发现遗物 " .. RELICS[relic] .. "。" end end
  record_draw(s, draw_sprite, draw_label)
  check_collection_rewards(s); return true
end
local function gear_five(s)
  local paid
  if s.tickets >= 5 then s.tickets = s.tickets - 5; paid = "消耗 5 券" elseif s.coins >= 360 then s.coins = s.coins - 360; paid = "消耗 360 金币" else return false end
  s.bulk_gear = true; for _ = 1, 5 do gear_once(s) end; s.bulk_gear = false; s.message = "战备连招完成：5 次补给已收入收藏（" .. paid .. "）。"; return true
end
local function activate(ctx, s)
  if s.screen == "camp" then
    if s.selected == 1 then local d = day(ctx); if s.daily == d then s.message = "今日补给已领取，去远征变强吧。" else s.daily = d; s.coins = s.coins + 30; s.tickets = s.tickets + 1; s.message = "每日补给已领取。" end
    elseif s.selected == 2 then
      local rank = hero_rank(s); local need = hero_rank_need(s)
      if rank >= HERO_RANK_CAP then s.message = "当前英雄阶位已满。"
      elseif s.hero_echoes[s.hero] < need then s.message = "回响不足：还需要 " .. (need - s.hero_echoes[s.hero]) .. " 点。"
      else s.hero_echoes[s.hero] = s.hero_echoes[s.hero] - need; s.hero_ranks[s.hero] = rank + 1; s.message = HEROES[s.hero] .. " 突破至阶位 " .. s.hero_ranks[s.hero] .. "，生命与攻击提升。" end
    elseif s.selected == 3 then select_tab(s, 7)
    elseif s.selected == 4 then
      local replay = s.last_replay
      if replay then
        s.replay_mode = true; s.replay_return_floor = s.floor; s.floor = replay.floor or s.floor; s.route = replay.route; s.tactic = replay.tactic or 1; s.event_choice = replay.event_choice or 1; s.event_bonus = selected_event(s).bonus; start_battle(s, replay.tower == true); s.message = "开始重播：本次不会重复领取奖励。"
      else s.message = "还没有可重播的战报。" end
    elseif s.selected == 5 then s.screen = "training"; s.selected = 1; s.message = "训练场已打开：不会消耗资源。"
    else select_tab(s, 7) end
  elseif s.screen == "gacha" then
    if s.selected == 5 then local d = day(ctx); if s.shop_day ~= d then s.shop_day = d; s.shop_buys = { false, false, false } end; s.screen = "shop"; s.selected = 1; s.message = "商店已打开。"
    elseif s.selected == 2 and s.coins >= 80 then s.coins = s.coins - 80; s.tickets = s.tickets + 1; s.message = "兑换成功，招募券 +1。"
    elseif s.selected == 1 then if not recruit_once(s) then s.message = "资源不足。" end
    elseif s.selected == 3 then
      local paid = ""
      if s.tickets >= 5 then s.tickets = s.tickets - 5; paid = "消耗 5 券"
      elseif s.coins >= 520 then s.coins = s.coins - 520; paid = "消耗 520 金币"
      else s.message = "连招需要 5 张招募券或 520 金币。"; return end
      s.hero_free = false; s.bulk_draw = true; for _ = 1, 5 do recruit_once(s) end; s.bulk_draw = false; s.message = "连招完成：5 次补给已收入收藏（" .. paid .. "）。"
    elseif s.selected == 4 then if not gear_once(s) then s.message = "资源不足：需要 1 张招募券或 80 金币。" end
    elseif s.selected == 6 then if not gear_five(s) then s.message = "战备连招需要 5 张招募券或 360 金币。" end
    end
  elseif s.screen == "shop" then
    if s.selected == 1 and not s.shop_buys[1] and s.coins >= 60 then s.coins = s.coins - 60; s.tickets = s.tickets + 1; s.shop_buys[1] = true; s.message = "商店购入：招募券 +1。"
    elseif s.selected == 2 and not s.shop_buys[2] and s.coins >= 120 then s.coins = s.coins - 120; s.essence = s.essence + 2; s.shop_buys[2] = true; s.message = "商店购入：精粹 +2。"
    elseif s.selected == 3 and not s.shop_buys[3] and s.essence >= 4 then s.essence = s.essence - 4; s.coins = s.coins + 70; s.shop_buys[3] = true; s.message = "商店兑换：金币 +70。"
    else s.message = "资源不足或本轮已购买。" end
  elseif s.screen == "bag" then
  if s.selected <= 4 then if set_weapon(s, s.selected) then s.message = "槽 " .. s.weapon_slot .. " 已装备 " .. WEAPONS[s.weapon].name else s.message = "这件武器尚未发现。" end
    elseif s.selected == 5 then local next = s.weapon; for _ = 1, #WEAPONS do next = (next % #WEAPONS) + 1; if set_weapon(s, next) then s.message = "槽 " .. s.weapon_slot .. " 已切换为 " .. WEAPONS[s.weapon].name; break end end
    elseif s.selected == 6 then if s.essence >= 2 and (s.weapon_levels[s.weapon] or 0) < 5 then s.essence = s.essence - 2; s.weapon_levels[s.weapon] = s.weapon_levels[s.weapon] + 1; s.message = "强化成功。" else s.message = "精粹不足或已满级。" end
    elseif s.selected == 7 then
      local next, switched = s.partner, false
      for _ = 1, #PARTNERS do next = (next % #PARTNERS) + 1; if s.partners[next] then s.partner = next; s.message = "伙伴已切换为 " .. PARTNERS[s.partner] .. "。"; switched = true; break end end
      if not switched then s.message = "暂无其他已拥有伙伴。" end
    elseif s.selected == 8 then
      local next, switched = s.skill, false
      for _ = 1, #SKILLS do next = (next % #SKILLS) + 1; if set_skill(s, next) then s.message = "战技槽 " .. s.skill_slot .. " 已切换为 " .. SKILLS[s.skill] .. "。"; switched = true; break end end
      if not switched then s.message = "暂无其他已拥有战技。" end
    elseif s.selected == 9 then
      local next, switched = s.relic, false
      for _ = 1, #RELICS do next = (next % #RELICS) + 1; if s.relics[next] then s.relic = next; s.message = "遗物已切换为 " .. RELICS[s.relic] .. "。"; switched = true; break end end
      if not switched then s.message = "暂无其他已拥有遗物。" end
    end
  elseif s.screen == "collection" then
    local kind = s.collection_type or 1; local entries, _, owned = collection_def(s, kind); local index = s.selected
    if s.collection_slot then index = (s.collection_page - 1) * 4 + s.collection_slot; s.collection_slot = nil end
    if not entries[index] then s.message = "这一页没有该条目。"
    elseif not owned[index] then s.message = "尚未发现：" .. collection_entry_name(entries, index)
    elseif kind == 1 then s.hero = index; s.hero_level = s.hero_levels[s.hero] or 1; s.message = "已切换为 " .. HEROES[s.hero] .. " Lv." .. s.hero_level .. "。"
    elseif kind == 2 then set_weapon(s, index); s.message = "槽 " .. s.weapon_slot .. " 已装备 " .. WEAPONS[index].name .. "。"
    elseif kind == 3 then set_skill(s, index); s.message = "战技槽 " .. s.skill_slot .. " 已切换为 " .. SKILLS[index] .. "。"
    elseif kind == 4 then s.partner = index; s.message = "伙伴已切换为 " .. PARTNERS[index] .. "。"
    else s.relic = index; s.message = "遗物已切换为 " .. RELICS[index] .. "。" end
  elseif s.screen == "expedition" then s.screen = "route"; s.route_choice = 1; s.selected = 1
  elseif s.screen == "route" then s.route = s.route_choice; s.event_choice = 1; s.screen = "event"; s.message = "路线已锁定，先处理路上的意外。"
  elseif s.screen == "event" then
    local event = selected_event(s); s.event_bonus = event.bonus; s.message = "事件决定：" .. event.name; start_battle(s, false)
  elseif s.screen == "training" then
    start_battle(s, false, true)
  elseif s.screen == "bounties" then
    local i = s.bounty_choice; local needs = ({ 3, 1, 2 })[i]; local progress = s.bounty_progress[i] or 0
    if progress >= needs and not s.bounty_claimed[i] then
      s.bounty_claimed[i] = true; local cycle_bonus = math.max(0, (s.bounty_cycle or 1) - 1); if i == 1 then s.coins = s.coins + 60 + cycle_bonus * 5; s.tickets = s.tickets + 1 elseif i == 2 then s.essence = s.essence + 20 + cycle_bonus; s.tickets = s.tickets + 1 else s.coins = s.coins + 40 + cycle_bonus * 5; s.essence = s.essence + 16 + cycle_bonus * 2 end
      local complete = s.bounty_claimed[1] and s.bounty_claimed[2] and s.bounty_claimed[3]
      if complete then s.bounty_cycle = s.bounty_cycle + 1; s.bounty_progress = { 0, 0, 0 }; s.bounty_claimed = { false, false, false }; s.shop_buys = { false, false, false }; s.message = "本轮悬赏完成，下一轮目标与商店货架已刷新。" else s.message = "悬赏奖励已领取。" end
    else s.message = "这个悬赏还没有完成。" end
  elseif s.screen == "tower" then start_battle(s, true)
  elseif s.screen == "battle" then battle_action(s, s.selected)
  elseif s.screen == "result" then
    if s.result == "胜利" and not s.loot_claimed then
      local loot = (s.loot_options or {})[s.loot_choice]
      if not loot then s.coins = s.coins + 20; s.message = "战利品已收入营地：金币 +20。"
      elseif loot.kind == "heroes" then
        local h = loot.index; if s.heroes[h] then s.hero_echoes[h] = (s.hero_echoes[h] or 0) + (h >= 5 and 3 or h >= 3 and 2 or 1); s.essence = s.essence + 2; s.message = "重复英雄转化：" .. HEROES[h] .. " 获得回响与 2 精粹。" else s.heroes[h] = true; s.hero_levels[h] = s.hero_levels[h] or 1; s.message = "新英雄加入收藏：" .. HEROES[h] .. "。" end
      elseif loot.kind == "weapons" then
        local w = loot.index; grant_weapon_drop(s, w, "战利品：")
      elseif loot.kind == "skills" then
        local skill = loot.index; if s.skills[skill] then s.skill_levels[skill] = math.min(5, (s.skill_levels[skill] or 0) + 1); s.essence = s.essence + 1; s.message = "重复战技转化：" .. SKILLS[skill] .. " 升阶并获得 1 精粹。" else s.skills[skill] = true; s.skill = skill; s.message = "新战技加入收藏：" .. SKILLS[skill] .. "。" end
      elseif loot.kind == "partners" then
        local partner = loot.index; if s.partners[partner] then s.essence = s.essence + 1; s.message = "重复伙伴转化：" .. PARTNERS[partner] .. " +1 精粹。" else s.partners[partner] = true; s.partner = partner; s.message = "新伙伴加入收藏：" .. PARTNERS[partner] .. "。" end
      else
        local relic = loot.index; if s.relics[relic] then s.essence = s.essence + 1; s.message = "重复遗物转化：" .. RELICS[relic] .. " +1 精粹。" else s.relics[relic] = true; s.relic = relic; s.message = "新遗物加入收藏：" .. RELICS[relic] .. "。" end
      end
      check_collection_rewards(s)
      s.loot_claimed = true; s.result_choice = 2
    elseif s.result == "撤退" then
      s.screen = "expedition"; s.tab = 5; s.selected = 1; s.message = "回到远征入口：调整构筑或路线后可以再次挑战。"
    elseif (s.result == "胜利" or s.result == "重播胜利") and s.loot_claimed and s.result_choice == 1 then
      select_tab(s, 3); s.message = "已打开装备页：调整构筑后再继续挑战。"
    elseif s.result == "胜利" then
      if s.last_battle and s.last_battle.tower then s.screen = "tower"; s.tab = 7 else s.screen = "expedition"; s.tab = 5 end
      s.selected = 1; s.message = s.last_battle and s.last_battle.tower and "战利品已收入，继续挑战下一层试炼塔。" or "战利品已收入，继续选择下一场远征。"
    elseif s.result == "重播胜利" then
      s.screen = "expedition"; s.tab = 5; s.selected = 1; s.message = "重播完成，继续选择下一场远征。"
    elseif s.result ~= "胜利" then
      s.screen = "camp"; s.tab = 1; s.selected = 1; s.message = "已回到营地。调整构筑后可以再次挑战，养成进度不会丢失。"
    else select_tab(s, 1) end
  end
end
function on_input(ctx, ev)
  local s = state(ctx); local key = ev.type == "key" and ev.state == "down" and ev.key or nil
  if ev.type == "touch" then
    local x, y = ev.x, ev.y
    if s.screen == "battle" then if x <= 140 and y >= 50 and y < 95 then s.battle = nil; s.replay_mode = false; s.training_mode = false; s.route = nil; s.event_bonus = nil; s.screen = "camp"; s.tab = 1; s.selected = 1; s.message = "主动撤退，养成进度已保留。" elseif y >= 385 then s.selected = x < 208 and 1 or x < 390 and 2 or x < 580 and 3 or 4; activate(ctx, s) else return false end
    elseif s.screen == "result" then if (s.result == "胜利" and not s.loot_claimed) and y >= 320 then s.loot_choice = clamp(math.floor((x - 64) / 229) + 1, 1, 3); activate(ctx, s) elseif s.loot_claimed and y >= 350 then s.result_choice = x < 400 and 1 or 2; activate(ctx, s) else activate(ctx, s) end
    elseif y >= 54 and y <= 94 then select_tab(s, clamp(math.floor((x - 20) / 108) + 1, 1, #TABS))
    elseif s.screen == "camp" then if y >= 198 and y <= 398 then s.selected = clamp(math.floor((y - 205) / 67) + 1, 1, 3); activate(ctx, s) elseif y >= 400 and x >= 560 then s.selected = 4; activate(ctx, s) elseif y >= 400 and x >= 330 then s.selected = 5; activate(ctx, s) end
    elseif s.screen == "gacha" then if x >= 420 and y >= 140 and y < 400 then s.selected = y < 204 and 1 or y < 258 and 2 or y < 312 and 3 or 4; activate(ctx, s) elseif y >= 400 then s.selected = x >= 420 and 5 or 6; activate(ctx, s) end
    elseif s.screen == "shop" then if x >= 580 and y >= 96 and y < 150 then s.screen = "gacha"; s.selected = 5 elseif y >= 230 and y < 440 then s.selected = clamp(math.floor((y - 240) / 66) + 1, 1, 3); activate(ctx, s) end
    elseif s.screen == "bag" then if y >= 140 and y < 350 then s.selected = (x < 400 and 1 or 2) + (y >= 248 and 2 or 0); activate(ctx, s) elseif y >= 350 and y < 404 then s.selected = x < 400 and 5 or 6; activate(ctx, s) elseif y >= 404 then s.selected = x < 280 and 7 or x < 526 and 8 or 9; activate(ctx, s) end
    elseif s.screen == "collection" then
      if y >= 96 and y < 136 then
        if x >= 680 then s.collection_page = (s.collection_page or 1) + 1; if s.collection_page > collection_pages(s) then s.collection_page = 1 end else s.collection_type = clamp(math.floor((x - 30) / 128) + 1, 1, #COLLECTION_LABELS); s.collection_page = 1 end
        s.selected = 1
      elseif y >= 168 and y < 480 then local col = clamp(math.floor((x - 30) / 370) + 1, 1, 2); local row = y >= 324 and 1 or 0; s.collection_slot = nil; s.selected = (s.collection_page - 1) * 4 + row * 2 + col; activate(ctx, s) end
    elseif s.screen == "route" then if x >= 620 and y >= 96 and y < 136 then s.screen = "expedition"; s.tab = 5; s.selected = 1 elseif y >= 136 and y < 179 then s.tactic = clamp(math.floor((x - 34) / 246) + 1, 1, #TACTICS); s.message = "战术已选择：" .. TACTICS[s.tactic].name elseif y >= 179 and y < 440 then s.route_choice = clamp(math.floor((y - 188) / 82) + 1, 1, #ROUTES); activate(ctx, s) end
    elseif s.screen == "event" then if x >= 620 and y >= 96 and y < 136 then s.screen = "route"; s.selected = 1 elseif y >= 224 and y < 460 then s.event_choice = clamp(math.floor((y - 224) / 82) + 1, 1, 3); activate(ctx, s) end
    elseif s.screen == "training" then if x >= 620 and y >= 96 and y < 150 then s.screen = "camp"; s.tab = 1; s.selected = 1 elseif x >= 340 and y >= 320 and y < 410 then activate(ctx, s) else return false end
    elseif s.screen == "bounties" then if y >= 150 and y < 410 then s.bounty_choice = clamp(math.floor((y - 150) / 88) + 1, 1, 3); activate(ctx, s) end
    elseif (s.screen == "expedition" or s.screen == "tower") and x >= 370 and y >= 330 then activate(ctx, s) else return false end
  elseif key then
    if s.screen == "battle" then if key == "left" or key == "up" then s.selected = clamp(s.selected - 1, 1, 4) elseif key == "right" or key == "down" then s.selected = clamp(s.selected + 1, 1, 4) elseif key == "ok" then activate(ctx, s) elseif key == "back" then s.battle = nil; s.replay_mode = false; s.training_mode = false; s.route = nil; s.event_bonus = nil; s.screen = "camp"; s.tab = 1; s.selected = 1; s.message = "主动撤退，养成进度已保留。" else return false end
    elseif s.screen == "route" then if key == "left" then s.tactic = ((s.tactic - 2) % #TACTICS) + 1 elseif key == "right" then s.tactic = (s.tactic % #TACTICS) + 1 elseif key == "up" then s.route_choice = clamp(s.route_choice - 1, 1, #ROUTES) elseif key == "down" then s.route_choice = clamp(s.route_choice + 1, 1, #ROUTES) elseif key == "ok" then activate(ctx, s) elseif key == "back" then s.screen = "expedition"; s.tab = 5 else return false end
    elseif s.screen == "event" then if key == "up" then s.event_choice = clamp(s.event_choice - 1, 1, 3) elseif key == "down" then s.event_choice = clamp(s.event_choice + 1, 1, 3) elseif key == "ok" then activate(ctx, s) elseif key == "back" then s.screen = "route" else return false end
    elseif s.screen == "training" then if key == "ok" then activate(ctx, s) elseif key == "back" then s.screen = "camp"; s.tab = 1; s.selected = 1 else return false end
    elseif s.screen == "bounties" then if key == "up" then s.bounty_choice = clamp(s.bounty_choice - 1, 1, 3) elseif key == "down" then s.bounty_choice = clamp(s.bounty_choice + 1, 1, 3) elseif key == "left" or key == "right" then select_tab(s, clamp(s.tab + (key == "right" and 1 or -1), 1, #TABS)) elseif key == "ok" then activate(ctx, s) elseif key == "back" then select_tab(s, 1) else return false end
    elseif s.screen == "shop" then if key == "up" then s.selected = clamp(s.selected - 1, 1, 3) elseif key == "down" then s.selected = clamp(s.selected + 1, 1, 3) elseif key == "left" or key == "right" then select_tab(s, clamp(s.tab + (key == "right" and 1 or -1), 1, #TABS)) elseif key == "ok" then activate(ctx, s) elseif key == "back" then s.screen = "gacha"; s.selected = 5 else return false end
    elseif s.screen == "result" then if s.loot_claimed and (s.result == "胜利" or s.result == "重播胜利") then if key == "left" or key == "up" then s.result_choice = 1 elseif key == "right" or key == "down" then s.result_choice = 2 elseif key == "ok" or key == "back" then activate(ctx, s) else return false end elseif key == "left" or key == "up" then s.loot_choice = clamp((s.loot_choice or 1) - 1, 1, 3) elseif key == "right" or key == "down" then s.loot_choice = clamp((s.loot_choice or 1) + 1, 1, 3) elseif key == "ok" or key == "back" then activate(ctx, s) else return false end
    elseif s.screen == "collection" then
      -- 收藏册保留左右跨页面；上下在卡片、分页与分类之间移动，BACK 回到营地。
      local entries = collection_def(s, s.collection_type or 1); local pages = collection_pages(s); local page = s.collection_page or 1
      local slots = math.min(4, math.max(1, #entries - (page - 1) * 4))
      if key == "left" then s.collection_slot = nil; select_tab(s, clamp(s.tab - 1, 1, #TABS))
      elseif key == "right" then s.collection_slot = nil; select_tab(s, clamp(s.tab + 1, 1, #TABS))
      elseif key == "up" then
        s.collection_slot = nil; if s.selected > 2 then s.selected = s.selected - 2 elseif page > 1 then s.collection_page = page - 1; s.selected = math.min(4, math.max(1, math.min(2, #entries - (page - 2) * 4) + 2)) else s.collection_type = (s.collection_type - 2) % #COLLECTION_LABELS + 1; s.collection_page = 1; s.selected = 1 end
      elseif key == "down" then
        s.collection_slot = nil; if s.selected <= 2 and s.selected + 2 <= slots then s.selected = s.selected + 2 elseif page < pages then s.collection_page = page + 1; s.selected = 1 else s.collection_type = s.collection_type % #COLLECTION_LABELS + 1; s.collection_page = 1; s.selected = 1 end
      elseif key == "ok" then s.collection_slot = s.selected; activate(ctx, s)
      elseif key == "back" then select_tab(s, 1)
      else return false end
    elseif key == "left" then select_tab(s, clamp(s.tab - 1, 1, #TABS))
    elseif key == "right" then select_tab(s, clamp(s.tab + 1, 1, #TABS))
    elseif key == "up" then s.selected = clamp(s.selected - 1, 1, s.screen == "camp" and 5 or s.screen == "gacha" and 6 or s.screen == "bag" and 9 or s.screen == "collection" and 4 or 1)
    elseif key == "down" then s.selected = clamp(s.selected + 1, 1, s.screen == "camp" and 5 or s.screen == "gacha" and 6 or s.screen == "bag" and 9 or s.screen == "collection" and 4 or 1)
    elseif key == "ok" then activate(ctx, s)
    elseif key == "back" then select_tab(s, 1)
    else return false end
  else return false end
  ctx:invalidate(); return true
end
