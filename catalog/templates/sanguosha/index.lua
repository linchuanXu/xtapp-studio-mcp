local PkgImage = require("pkg_image")
-- 三国杀·墨战：离线 2v2 可玩纵切。
-- 首版不依赖运行时 require；发布侧可直接加载单一入口。

local W, H = 480, 800
local CARD_W, CARD_H = 78, 92
local HEROES = {
  { name = "云岚", hp = 4, skill = "疾袭", text = "本回合第一张杀伤害+1" },
  { name = "玄戈", hp = 5, skill = "无技能", text = "无额外减伤效果" },
  { name = "青鸾", hp = 4, skill = "援护", text = "队友濒死时可多救一次" },
  { name = "赤羽", hp = 4, skill = "烈弓", text = "攻击距离+1" },
}
local CARD_LABEL = { slash = "杀", dodge = "闪", peach = "桃", duel = "决斗", steal = "顺手", draw = "无中", blade = "烈刃" }
local CARD_DESC = { slash = "伤害 1", dodge = "抵消杀", peach = "回复 1", duel = "轮流出杀", steal = "取 1 手牌", draw = "摸 2", blade = "范围+1" }
local PHASE_LABEL = { prepare = "准备", judge = "判定", draw = "摸牌", action = "出牌", discard = "弃牌", finish = "结束", response = "响应" }
local TARGET_CARD = { slash = true, duel = true, steal = true }
local HERO_SLOT = { [1] = { 187, 50 }, [2] = { 16, 230 }, [3] = { 358, 230 }, [4] = { 187, 476 } }

-- 预览与设备的默认文字是 20px；Lua # 会把汉字计为 3 个 UTF-8 字节，
-- 所以必须逐字按实际字面宽度估算，不能用“一个汉字 12px”的旧值。
local function text_width(t)
  local width, i = 0, 1
  while i <= #t do
    local b = string.byte(t, i)
    if b < 128 then
      -- 20px 系统字体中，空格和常见标点明显窄于字母/数字。
      if b == 32 then width = width + 5
      elseif b == 46 or b == 44 or b == 58 or b == 183 then width = width + 6
      else width = width + 11 end
      i = i + 1
    else
      width = width + 20
      i = i + (b < 224 and 2 or (b < 240 and 3 or 4))
    end
  end
  return width
end
local function glyph_sub(t, limit)
  local count, i, last = 0, 1, 0
  while i <= #t and count < limit do
    last = i; local b = string.byte(t, i)
    i = i + (b < 128 and 1 or (b < 224 and 2 or (b < 240 and 3 or 4)))
    count = count + 1
  end
  if i <= #t then return string.sub(t, 1, last - 1) .. "…" end
  return t
end
local function center(g, x, y, t, color) g:text(x - math.floor(text_width(t) / 2), y, t, { color = color or 15 }) end
local function inside(x, y, rx, ry, rw, rh) return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh end
local function copy(list) local r = {}; for i, v in ipairs(list or {}) do r[i] = v end; return r end
local function remove(list, value) for i, v in ipairs(list) do if v == value then table.remove(list, i); return true end end return false end
local function contains(list, value) for _, v in ipairs(list or {}) do if v == value then return true end end return false end
local function draw_button(g, x, y, w, h, text, primary)
  local asset = (w == 84 and "ui_btn_small") or (w == 160 and "ui_btn_wide") or (w == 180 and "ui_btn_response") or (w == 196 and "ui_btn_mulligan") or (w == 300 and "ui_btn_start")
  if asset then PkgImage.draw(g, asset, x, y) else g:rect(x, y, w, h,{fill=true,color=0}); g:rect(x, y, w, h,{color=15}) end
  center(g, x + math.floor(w / 2), y + math.floor(h / 2) - 7, text, 0)
end
local function draw_ink_button(g, x, y, w, h, text)
  g:rect(x, y, w, h,{fill=true,color=0}); g:rect(x, y, w, h,{color=15}); g:rect(x + 4, y + 4, w - 8, h - 8,{color=15})
  g:line(x + 14, y + 8, x + 30, y + 8,{color=15}); g:line(x + w - 30, y + h - 8, x + w - 14, y + h - 8,{color=15})
  center(g, x + math.floor(w / 2), y + math.floor(h / 2) - 8, text, 15)
end
local function deck(seed)
  local d = {}
  local kinds = { "slash", "slash", "slash", "slash", "slash", "slash", "dodge", "dodge", "dodge", "dodge", "peach", "peach", "duel", "duel", "steal", "steal", "draw", "draw", "blade" }
  for round = 1, 3 do for _, kind in ipairs(kinds) do d[#d + 1] = kind end end
  local n = seed or 7
  for i = #d, 2, -1 do n = (n * 1103515245 + 12345) % 2147483647; local j = n % i + 1; d[i], d[j] = d[j], d[i] end
  return d
end
local function pull(game, p, count)
  for _ = 1, count do
    if #game.deck == 0 then
      if #game.discard == 0 then return end
      game.deck, game.discard = game.discard, {}; game.reshuffles = (game.reshuffles or 0) + 1
    end
    p.hand[#p.hand + 1] = table.remove(game.deck)
  end
end
local function alive(p) return p and p.hp > 0 end
local function enemies(game, index)
  local out, team = {}, game.players[index].team
  for i, p in ipairs(game.players) do if alive(p) and p.team ~= team then out[#out + 1] = i end end
  return out
end
-- 屏幕座位为上、左、右、下，桌边环绕顺序是 1→2→4→3→1，而非 Lua 下标顺序。
local SEAT_DISTANCE = { { 0, 1, 1, 2 }, { 1, 0, 2, 1 }, { 1, 2, 0, 1 }, { 2, 1, 1, 0 } }
local function seat_distance(a, b) return SEAT_DISTANCE[a][b] end
local function attack_range(player)
  local range = 1
  if player.hero.skill == "烈弓" then range = range + 1 end
  if player.weapon == "blade" then range = range + 1 end
  return range
end
local function legal_target(game, actor, target, kind)
  if not (alive(game.players[actor]) and alive(game.players[target])) then return false end
  if game.players[actor].team == game.players[target].team then return false end
  if kind == "slash" then return seat_distance(actor, target) <= attack_range(game.players[actor]) end
  if kind == "steal" then return seat_distance(actor, target) <= 1 end
  return kind == "duel"
end
local function card_playable(game, actor, kind)
  if kind == "dodge" then return false end
  if kind == "slash" and (game.players[actor].slash_count or 0) >= 1 then return false end
  return true
end
local function selected_card(game)
  if not game.selected then return nil end
  return game.players[4].hand[game.selected]
end
local function set_effect(g, kind, source, target, label, ttl)
  g.effect = { kind = kind, source = source, target = target, label = label, ttl = ttl }
end
local function clear_selection(g)
  g.selected, g.target = nil, nil
  if g.effect and g.effect.kind == "aim" then g.effect = nil end
end
local function team_alive(game, team) for _, p in ipairs(game.players) do if p.team == team and alive(p) then return true end end return false end
local function start_game(s)
  local g = { deck = deck((s.seed or 41) + 1), discard = {}, round = 1, current = 4, phase = "mulligan", log = { "战局开始：请选择换牌或保留。" }, history = { "战局开始：请选择换牌或保留。" }, selected = nil, target = nil, prompt = nil, pending = nil, ai_wait = 0 }
  g.players = {
    { name = HEROES[1].name, hero = HEROES[1], team = "enemy", hp = 4, max_hp = 4, hand = {}, ai = true },
    { name = HEROES[2].name, hero = HEROES[2], team = "enemy", hp = 5, max_hp = 5, hand = {}, ai = true },
    { name = HEROES[3].name, hero = HEROES[3], team = "friend", hp = 4, max_hp = 4, hand = {}, ai = true },
    { name = "你", hero = HEROES[4], team = "friend", hp = 4, max_hp = 4, hand = {}, human = true },
  }
  for _, p in ipairs(g.players) do pull(g, p, 4) end
  s.game, s.screen = g, "mulligan"
end
local function add_log(g, text)
  g.log = g.log or {}; g.history = g.history or {}
  g.log[#g.log + 1] = text; g.history[#g.history + 1] = text
  while #g.log > 4 do table.remove(g.log, 1) end
  while #g.history > 80 do table.remove(g.history, 1) end
end
local function finish_if_needed(s)
  local g = s.game
  if not team_alive(g, "enemy") then s.screen = "result"; g.result = "友方获胜"; return true end
  if not team_alive(g, "friend") then s.screen = "result"; g.result = "敌方获胜"; return true end
  return false
end
local function declare_dead(s, target)
  local g, p = s.game, s.game.players[target]
  if p.hp > 0 then return false end
  p.hp = 0
  -- 阵亡角色的手牌与装备必须进入弃牌堆，避免牌凭空消失或仍显示在已阵亡角色身上。
  for _, kind in ipairs(p.hand) do g.discard[#g.discard + 1] = kind end
  p.hand = {}
  if p.weapon then g.discard[#g.discard + 1] = p.weapon; p.weapon = nil end
  add_log(g, p.name .. "阵亡")
  return finish_if_needed(s)
end
local function hurt(s, target, amount, source)
  local g = s.game
  local p = g and g.players[target]
  if not p or not alive(p) then return end
  p.hp = math.max(0, p.hp - amount); set_effect(g, "hit", nil, target, "伤害 " .. amount, 850); add_log(g, (source or "攻击") .. "令" .. p.name .. "失去 " .. amount .. " 点体力")
  if p.hp > 0 then return false end
  -- 人类可以用桃救自己或队友；这必须在阵亡前进入响应窗口。
  if p.team == "friend" and contains(g.players[4].hand, "peach") then
    g.pending = { kind = "dying", target = target }; g.phase = "response"; add_log(g, p.name .. "濒死，请决定是否使用桃救援")
    return true
  end
  for i, ally in ipairs(g.players) do
    if ally.team == p.team and i ~= target and i ~= 4 and alive(ally) and ally.hero.skill == "援护" and remove(ally.hand, "peach") then
      g.discard[#g.discard + 1] = "peach"; p.hp = 1; add_log(g, ally.name .. "发动援护，使用桃救回" .. p.name); return false
    end
  end
  return declare_dead(s, target)
end
local function next_alive_seat(g)
  for _ = 1, 4 do
    g.current = g.current % 4 + 1
    if alive(g.players[g.current]) then return end
  end
end
-- 阶段不是一条装饰文字：它是结算驱动。即使当前版本没有判定牌，判定阶段也会
-- 显式经过，后续加入延时锦囊时不用改写整条回合链。
local function advance_phase(s)
  local g, p = s.game, s.game.players[s.game.current]
  if g.phase == "prepare" then
    p.slash_count = 0
    add_log(g, p.name .. "的准备阶段")
    g.phase = "judge"
  elseif g.phase == "judge" then
    add_log(g, p.name .. "的判定阶段（无延时锦囊）")
    g.phase = "draw"
  elseif g.phase == "draw" then
    pull(g, p, 2)
    add_log(g, p.name .. "摸两张牌，进入出牌阶段")
    g.phase = "action"
    if p.human then set_effect(g, "turn", 4, 4, "你的回合", 1200) end
  elseif g.phase == "finish" then
    add_log(g, p.name .. "的结束阶段")
    g.selected, g.target, g.prompt = nil, nil, nil
    next_alive_seat(g)
    if g.current == 1 then g.round = g.round + 1 end
    g.phase = "prepare"; g.ai_wait = 500
  end
end
local function end_turn(s)
  local g, current = s.game, s.game.players[s.game.current]
  if g.phase == "action" then
    g.selected, g.target = nil, nil
    if current.human and #current.hand > current.hp then
      g.phase = "discard"; add_log(g, "进入弃牌阶段：需弃置 " .. (#current.hand - current.hp) .. " 张")
      return
    end
  end
  while #current.hand > current.hp do
    local discarded = table.remove(current.hand, 1); g.discard[#g.discard + 1] = discarded
  end
  g.phase = "finish"
end
local function resolve_response(s, use_dodge)
  local g, pending = s.game, s.game.pending
  if not pending then return end
  local defender, attacker = g.players[pending.target], g.players[pending.attacker]
  if pending.kind == "dying" then
    local rescued = use_dodge and remove(g.players[4].hand, "peach")
    if rescued then
      g.discard[#g.discard + 1] = "peach"; defender.hp = 1; add_log(g, "你使用桃救回" .. defender.name)
    else
      declare_dead(s, pending.target)
    end
    g.pending, g.selected, g.target = nil, nil, nil
    if s.screen ~= "result" then end_turn(s) end
    return
  end
  if pending.kind == "duel" then
    local responder = g.players[pending.next]
    if not use_dodge or not remove(responder.hand, "slash") then
      local awaiting_rescue = hurt(s, pending.next, 1, "决斗")
      if awaiting_rescue then return end
      g.pending, g.selected, g.target = nil, nil, nil
      if s.screen ~= "result" then end_turn(s) end
      return
    end
    g.discard[#g.discard + 1] = "slash"; add_log(g, "你在决斗中打出杀")
    local other = pending.attacker
    if pending.next == pending.attacker then other = pending.target end
    if other ~= 4 and remove(g.players[other].hand, "slash") then
      g.discard[#g.discard + 1] = "slash"; pending.next = 4; add_log(g, g.players[other].name .. "在决斗中打出杀，请继续响应")
      return
    end
    local awaiting_rescue = hurt(s, other, 1, "决斗")
    if awaiting_rescue then return end
    g.pending, g.selected, g.target = nil, nil, nil
    if s.screen ~= "result" then end_turn(s) end
    return
  end
  g.discard[#g.discard + 1] = "slash"
  if use_dodge and remove(defender.hand, "dodge") then
    g.discard[#g.discard + 1] = "dodge"; set_effect(g, "dodge", pending.target, pending.target, "闪避", 750); add_log(g, "你打出闪，抵消了" .. attacker.name .. "的杀")
  else
    local awaiting_rescue = hurt(s, pending.target, pending.damage or 1, attacker.name .. "使用杀")
    if awaiting_rescue then return end
  end
  g.pending, g.selected, g.target = nil, nil, nil
  if s.screen ~= "result" then end_turn(s) end
end
local function first_enemy(g, index, kind)
  for _, enemy in ipairs(enemies(g, index)) do if not kind or legal_target(g, index, enemy, kind) then return enemy end end
  return nil
end
local function ai_action(s)
  local g, p = s.game, s.game.players[s.game.current]
  if p.human or g.phase ~= "action" then return end
  local target = first_enemy(g, g.current, "slash")
  if not p.weapon and remove(p.hand, "blade") then p.weapon = "blade"; add_log(g, p.name .. "装备了烈刃")
  end
  if remove(p.hand, "peach") and p.hp < p.max_hp - 1 then p.hp = p.hp + 1; g.discard[#g.discard + 1] = "peach"; add_log(g, p.name .. "使用桃回复体力")
  elseif target and remove(p.hand, "slash") then
    set_effect(g, "slash", g.current, target, "杀", 900)
    if target == 4 then
      local damage = p.hero.skill == "疾袭" and (p.slash_count or 0) == 0 and 2 or 1
      p.slash_count = (p.slash_count or 0) + 1
      g.pending = { kind = "slash", attacker = g.current, target = target, damage = damage }; g.phase = "response"; add_log(g, p.name .. "对你使用杀，请响应")
      return
    end
    g.discard[#g.discard + 1] = "slash"
    if remove(g.players[target].hand, "dodge") then g.discard[#g.discard + 1] = "dodge"; set_effect(g, "dodge", target, target, "闪避", 750); add_log(g, p.name .. "对" .. g.players[target].name .. "出杀，被闪避")
    else local damage = p.hero.skill == "疾袭" and (p.slash_count or 0) == 0 and 2 or 1; p.slash_count = (p.slash_count or 0) + 1; hurt(s, target, damage, p.name .. "使用杀") end
  elseif remove(p.hand, "duel") then
    local duel_target = first_enemy(g, g.current, "duel")
    if duel_target then
      g.discard[#g.discard + 1] = "duel"
      set_effect(g, "duel", g.current, duel_target, "决斗", 900)
      if duel_target == 4 then g.pending = { kind = "duel", attacker = g.current, target = duel_target, next = 4 }; g.phase = "response"; add_log(g, p.name .. "向你发起决斗，请出杀")
      else hurt(s, duel_target, 1, p.name .. "以决斗") end
    else p.hand[#p.hand + 1] = "duel" end
  elseif remove(p.hand, "steal") then
    local steal_target = first_enemy(g, g.current, "steal")
    if steal_target and #g.players[steal_target].hand > 0 then
      g.discard[#g.discard + 1] = "steal"; set_effect(g, "aim", g.current, steal_target, "顺手", 850); p.hand[#p.hand + 1] = table.remove(g.players[steal_target].hand, 1)
      add_log(g, p.name .. "顺走了" .. g.players[steal_target].name .. "的一张手牌")
    else
      p.hand[#p.hand + 1] = "steal"
    end
  elseif remove(p.hand, "draw") then g.discard[#g.discard + 1] = "draw"; pull(g, p, 2); add_log(g, p.name .. "使用无中生有")
  end
  if s.screen ~= "result" and g.phase ~= "response" then end_turn(s) end
end
local function human_play(s)
  local g, p, hand_index, target = s.game, s.game.players[4], s.game.selected, s.game.target
  local kind = selected_card(g)
  if not kind or not card_playable(g, 4, kind) then return end
  if TARGET_CARD[kind] and (not target or not legal_target(g, 4, target, kind)) then
    add_log(g, "请先选择「" .. CARD_LABEL[kind] .. "」的合法目标")
    return
  end
  table.remove(p.hand, hand_index)
  if kind == "peach" then
    g.discard[#g.discard + 1] = kind; p.hp = math.min(p.max_hp, p.hp + 1); add_log(g, "你使用桃，回复 1 点体力")
  elseif kind == "draw" then
    g.discard[#g.discard + 1] = kind; pull(g, p, 2); add_log(g, "你使用无中生有，摸两张牌")
  elseif kind == "blade" then
    if p.weapon then g.discard[#g.discard + 1] = p.weapon end
    p.weapon = "blade"; add_log(g, "你装备了烈刃，攻击范围+1")
  elseif (kind == "slash" or kind == "duel" or kind == "steal") and target then
    g.discard[#g.discard + 1] = kind
    local t = g.players[target]
    set_effect(g, kind == "slash" and "slash" or (kind == "duel" and "duel" or "aim"), 4, target, CARD_LABEL[kind], 900)
    if kind == "slash" then p.slash_count = (p.slash_count or 0) + 1 end
    if kind == "slash" and remove(t.hand, "dodge") then g.discard[#g.discard + 1] = "dodge"; set_effect(g, "dodge", target, target, "闪避", 750); add_log(g, t.name .. "打出闪，抵消了你的杀")
    elseif kind == "steal" and #t.hand > 0 then p.hand[#p.hand + 1] = table.remove(t.hand, 1); add_log(g, "你顺走了" .. t.name .. "的一张手牌")
    elseif kind == "duel" then
      if remove(t.hand, "slash") then
        g.discard[#g.discard + 1] = "slash"; clear_selection(g); g.pending = { kind = "duel", attacker = 4, target = target, next = 4 }; g.phase = "response"
        add_log(g, t.name .. "在决斗中打出杀，请继续响应"); return
      end
      hurt(s, target, 1, "你以决斗")
    else
      local damage = p.hero.skill == "疾袭" and (p.slash_count or 0) == 0 and 2 or 1
      hurt(s, target, damage, kind == "slash" and "你使用杀" or "你以决斗")
    end
  end
  clear_selection(g)
end
local function draw_hero(g, p, index, x, y, active, selected, candidate, relation)
  local w, h = 106, 176; local ink, paper = 15, 0
  g:rect(x, y, w, h,{fill=true,color=paper})
  local portrait = p.name == "云岚" and "hero_yunlan" or (p.name == "玄戈" and "hero_xuange" or (p.name == "青鸾" and "hero_qingluan" or "hero_chiyu"))
  -- 角色原画按完整人物牌尺寸输出；顶部与底部只覆盖必要的状态信息，人物保持主视觉。
  PkgImage.draw(g, portrait, x, y)
  g:rect(x, y, w, 24,{fill=true,color=paper}); g:rect(x, y + 150, w, 26,{fill=true,color=paper})
  -- 小人物牌不再塞入“距离、装备、手牌”等长句；每行都限制在牌面安全宽度内。
  g:rect(x + 5, y + 4, 20, 18,{fill=true,color=p.team == "enemy" and 15 or 0}); g:rect(x + 5, y + 4, 20, 18,{color=15})
  center(g, x + 15, y + 6, p.team == "enemy" and "敌" or "友", p.team == "enemy" and 0 or 15)
  g:text(x + 31, y + 5, p.name, { color = ink })
  g:text(x + 7, y + 155, "体" .. p.hp, { color = ink })
  g:text(x + 55, y + 155, "牌" .. #p.hand, { color = ink })
  -- 装备始终占用人物牌右下角的固定徽记位，避免和体力/手牌文本抢同一行。
  if p.weapon == "blade" then
    g:rect(x + 72, y + 116, 29, 31,{fill=true,color=paper}); g:rect(x + 72, y + 116, 29, 31,{color=ink})
    PkgImage.draw(g, "card_mark_blade", x + 72, y + 116)
  end
  if candidate then
    g:rect(x + 62, y + 126, 39, 18,{fill=true,color=15}); center(g, x + 81, y + 129, "可选", 0)
  end
  -- 不画固定卡框，让大幅原画直接构成角色牌；只在交互状态出现轮廓。
  if active or selected then g:rect(x - 3, y - 3, w + 6, h + 6,{color=15}) end
  if selected then g:rect(x - 5, y - 5, w + 10, h + 10,{color=15}) end
end
local function draw_home(ctx, g, s)
  PkgImage.draw(g, "battle_board", 0, 0)
  g:rect(28, 18, 424, 52,{fill=true,color=0}); center(g, 240, 28, "三国杀·墨战", 15); center(g, 240, 50, "四席同桌 · 2V2 对局", 15)
  PkgImage.draw(g, "hero_yunlan", 72, 96); PkgImage.draw(g, "hero_chiyu", 302, 96)
  center(g, 125, 276, "云岚", 15); center(g, 355, 276, "赤羽", 15)
  g:rect(210, 166, 60, 32,{fill=true,color=15}); g:rect(210, 166, 60, 32,{color=0}); center(g, 240, 172, "对决", 0)
  center(g, 240, 310, "与你的队友配合，击败所有敌将", 15)
  draw_ink_button(g, 90, 350, 300, 58, "开始 2V2 对局")
  center(g, 240, 428, "开局可选择一次重摸手牌", 15)
  g:line(22, 742, 458, 742,{color=15}); center(g, 60, 760, "对战", 15); center(g, 180, 760, "武将", 15); center(g, 300, 760, "战报", 15); center(g, 420, 760, "规则", 15)
end
local function draw_subpage(g, title)
  PkgImage.draw(g, "battle_board", 0, 0); g:rect(0, 0, W, 68,{fill=true,color=0}); center(g, 240, 24, title, 15); draw_ink_button(g, 16, 14, 84, 38, "返回")
end
local function draw_heroes(g, s)
  draw_subpage(g, "武将")
  local cards = { { 16, 92, HEROES[1] }, { 250, 92, HEROES[2] }, { 16, 330, HEROES[3] }, { 250, 330, HEROES[4] } }
  for _, card in ipairs(cards) do
    local x, y, hero = card[1], card[2], card[3]
    g:rect(x, y, 214, 194,{fill=true,color=15}); g:rect(x, y, 214, 194,{color=0})
    center(g, x + 107, y + 20, hero.name, 0); center(g, x + 107, y + 48, "体力 " .. hero.hp, 0)
    center(g, x + 107, y + 86, hero.skill, 0); center(g, x + 107, y + 116, hero.text, 0)
    center(g, x + 107, y + 156, "2v2 首发武将", 0)
  end
end
local function draw_report(g, s)
  draw_subpage(g, "战报")
  local entries = s.game and s.game.history or { "尚未开始对局。" }
  local first = math.max(1, #entries - 12)
  for i = first, #entries do g:text(24, 88 + (i - first) * 36, "· " .. entries[i], { color = 0 }) end
end
local function draw_rules(g)
  draw_subpage(g, "玩法说明")
  local lines = { "消灭敌方全部武将即可获胜。", "每回合摸两张牌；结束时手牌不得超过体力。", "杀需要距离内敌人；闪可抵消杀。", "桃可回复，也可在队友濒死时救援。", "决斗要求连续打出杀，先无杀者受伤。", "烈刃增加攻击范围。" }
  for i, line in ipairs(lines) do g:text(28, 102 + (i - 1) * 56, line, { color = 0 }) end
end
local function draw_hand(g, game)
  local p, n = game.players[4], #game.players[4].hand
  for i, kind in ipairs(p.hand) do
    local gap = n <= 5 and 88 or math.max(54, math.floor((448 - CARD_W) / math.max(1, n - 1)))
    local x = 16 + (i - 1) * gap; local y = 696 - (game.selected == i and 10 or 0)
    -- 每张手牌都有独立的牌框与图标资源；运行时只负责叠加可变的牌名和效果。
    -- XIC 的白色像素不会覆盖底图，先铺白纸底才能在墨色桌面上保持牌面可读。
    g:rect(x, y, CARD_W, CARD_H,{fill=true,color=0})
    PkgImage.draw(g, "card_frame", x, y)
    center(g, x + math.floor(CARD_W / 2), y + 9, CARD_LABEL[kind], 0)
    PkgImage.draw(g, "card_mark_" .. kind, x + 24, y + 31)
    center(g, x + math.floor(CARD_W / 2), y + 62, CARD_DESC[kind], 15)
    if game.selected == i then g:rect(x - 2, y - 2, CARD_W + 4, CARD_H + 4,{color=15}) end
  end
end
local function hero_center(index)
  local slot = HERO_SLOT[index] or HERO_SLOT[4]
  return slot[1] + 53, slot[2] + 88
end
local function draw_arrow(g, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 1 then return end
  local ux, uy, px, py = dx / length, dy / length, -dy / length, dx / length
  local ex, ey = x2 - ux * 22, y2 - uy * 22
  g:line(x1, y1, ex, ey,{color=15})
  g:line(ex, ey, ex - ux * 13 + px * 7, ey - uy * 13 + py * 7,{color=15})
  g:line(ex, ey, ex - ux * 13 - px * 7, ey - uy * 13 - py * 7,{color=15})
end
local function draw_combat_effect(g, game)
  local effect = game.effect
  if not effect then return end
  if effect.kind == "turn" and game.current == 4 and game.phase == "action" then
    g:rect(150, 468, 180, 42,{fill=true,color=0}); PkgImage.draw(g, "fx_turn", 150, 468); center(g, 240, 480, "你的回合", 15)
    return
  end
  local target = effect.target
  if not target then return end
  local tx, ty = hero_center(target)
  if effect.source and effect.source ~= target then
    local sx, sy = hero_center(effect.source)
    draw_arrow(g, sx, sy, tx, ty)
    if effect.kind == "slash" or effect.kind == "duel" then PkgImage.draw(g, "fx_slash", math.floor((sx + tx) / 2) - 50, math.floor((sy + ty) / 2) - 22) end
  end
  local slot = HERO_SLOT[target]
  if effect.kind == "hit" then
    PkgImage.draw(g, "fx_hit", slot[1] + 29, slot[2] + 64)
  elseif effect.kind == "dodge" then
    PkgImage.draw(g, "card_mark_dodge", slot[1] + 38, slot[2] + 74)
    g:rect(slot[1] + 25, slot[2] + 126, 56, 16,{fill=true,color=0}); center(g, slot[1] + 53, slot[2] + 128, "闪避", 15)
  else
    PkgImage.draw(g, "fx_target", slot[1] + 26, slot[2] + 62)
  end
  if effect.label and effect.kind ~= "dodge" then
    g:rect(tx - 35, ty + 43, 70, 16,{fill=true,color=0}); center(g, tx, ty + 45, effect.label, 15)
  end
end
local function battle_hint(game)
  local p, chosen = game.players[game.current], selected_card(game)
  if game.phase == "response" then return "请响应当前牌" end
  if game.current ~= 4 then return p.name .. "行动中" end
  if game.phase == "discard" then return "请弃至不多于体力" end
  if game.phase ~= "action" then return "你的" .. (PHASE_LABEL[game.phase] or "回合") .. "阶段" end
  if not chosen then return "请选择一张手牌" end
  if TARGET_CARD[chosen] and not game.target then return "请选择合法目标" end
  if TARGET_CARD[chosen] then return "已选择 " .. game.players[game.target].name .. "，确认使用" end
  return "确认使用「" .. CARD_LABEL[chosen] .. "」"
end
local function draw_battle(ctx, g, s)
  local game = s.game; PkgImage.draw(g, "battle_board", 0, 0); g:rect(8, 8, W - 16, H - 16,{color=15})
  g:rect(8, 8, W - 16, 40,{fill=true,color=15}); center(g, 240, 20, "第" .. game.round .. "轮 · " .. game.players[game.current].name .. "的" .. (PHASE_LABEL[game.phase] or "回合" ) .. "阶段", 0)
  local chosen = selected_card(game)
  local targetable = chosen and TARGET_CARD[chosen] and game.current == 4 and game.phase == "action"
  draw_hero(g, game.players[1], 1, 187, 50, game.current == 1, game.target == 1, targetable and legal_target(game, 4, 1, chosen), "距" .. seat_distance(4, 1))
  draw_hero(g, game.players[2], 2, 16, 230, game.current == 2, game.target == 2, targetable and legal_target(game, 4, 2, chosen), "距" .. seat_distance(4, 2))
  draw_hero(g, game.players[3], 3, 358, 230, game.current == 3, game.target == 3, targetable and legal_target(game, 4, 3, chosen), "队友")
  draw_hero(g, game.players[4], 4, 187, 476, game.current == 4, false, false, "你")
  draw_combat_effect(g, game)
  g:rect(48, 420, 384, 48,{fill=true,color=0}); g:rect(48, 420, 384, 48,{color=15}); center(g, 240, 429, glyph_sub(game.log[#game.log] or "战局开始", 18), 15)
  center(g, 240, 448, battle_hint(game), 15)
  if game.current == 4 and game.phase == "action" then
    if chosen then
      draw_button(g, 150, 654, 84, 38, "确认", true); draw_button(g, 246, 654, 84, 38, "取消", false)
    else draw_button(g, 160, 650, 160, 44, "结束回合", true) end
  end
  if game.current == 4 and game.phase == "discard" then center(g, 240, 662, "请弃牌至不多于体力", 15) end
  draw_hand(g, game)
  if game.phase == "response" and game.pending then
    g:rect(30, 334, 420, 116,{fill=true,color=0}); g:rect(30, 334, 420, 116,{color=15})
    local dying, duel = game.pending.kind == "dying", game.pending.kind == "duel"
    center(g, 240, 346, dying and (game.players[game.pending.target].name .. "濒死") or (duel and (game.players[game.pending.attacker].name .. "发起决斗")) or (game.players[game.pending.attacker].name .. "对你使用杀"), 15)
    center(g, 240, 370, dying and "使用桃救援，或取消" or (duel and "打出一张杀，否则受伤" or "打出闪，或承受伤害"), 15)
    local response_card, response_label = dying and "peach" or (duel and "slash" or "dodge"), dying and "使用桃" or (duel and "打出杀" or "打出闪")
    if contains(game.players[4].hand, response_card) then draw_button(g, 46, 394, 180, 40, response_label, true) end
    draw_button(g, 254, 394, 180, 40, "取消", false)
  end
end
local function draw_mulligan(ctx, g, s)
  local game = s.game; PkgImage.draw(g, "battle_board", 0, 0); g:rect(28, 18, 424, 52,{fill=true,color=0}); center(g, 240, 28, "初始手牌", 15); center(g, 240, 50, "本局可换一次", 15)
  center(g, 240, 112, "保留手牌，或将全部手牌重摸一次", 15); draw_hand(g, game); draw_ink_button(g, 30, 590, 196, 56, "重摸"); draw_ink_button(g, 254, 590, 196, 56, "保留")
end
local function draw_result(ctx, g, s)
  PkgImage.draw(g, "home_bg", 0, 0); g:rect(32, 232, 416, 250,{fill=true,color=15}); g:rect(32, 232, 416, 250,{color=0})
  center(g, 240, 282, s.game.result, 0)
  center(g, 240, 326, s.game.result == "友方获胜" and "与队友并肩，赢得本局" or "再调整策略，下一局再战", 0)
  draw_button(g, 90, 404, 300, 54, "再来一局", true)
end
function on_load(ctx)
  ctx:set_tick(100)
  local s = ctx.state.sanguosha or { screen = "home", seed = 17 }; ctx.state.sanguosha = s; ctx:invalidate()
end
function on_tick(ctx, elapsed)
  local s = ctx.state.sanguosha; if not s or s.screen ~= "battle" or not s.game then return end
  local g = s.game
  if g.effect and g.effect.ttl then
    g.effect.ttl = g.effect.ttl - (elapsed or 60)
    if g.effect.ttl <= 0 then g.effect = nil end
  end
  if g.ai_wait and g.ai_wait > 0 then g.ai_wait = g.ai_wait - (elapsed or 60); if g.ai_wait > 0 then ctx:invalidate(); return end end
  if g.phase == "prepare" or g.phase == "judge" or g.phase == "draw" or g.phase == "finish" then
    advance_phase(s)
    if not g.players[g.current].human and g.phase == "action" then g.ai_wait = 850 end
  elseif not g.players[g.current].human then ai_action(s) end
  ctx:invalidate()
end
function on_draw(ctx, g) require("pkg_image").bind(ctx);
  -- 运行时不会替应用自动擦除上一帧；所有页面都必须从干净的白底重绘。
  g:clear(0)
  local s = ctx.state.sanguosha
  if not s or s.screen == "home" then draw_home(ctx, g, s or {})
  elseif s.screen == "heroes" then draw_heroes(g, s)
  elseif s.screen == "report" then draw_report(g, s)
  elseif s.screen == "rules" then draw_rules(g)
  elseif s.screen == "mulligan" then draw_mulligan(ctx, g, s)
  elseif s.screen == "battle" then draw_battle(ctx, g, s)
  else draw_result(ctx, g, s) end
end
function on_input(ctx, ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s, x, y = ctx.state.sanguosha, ev.x, ev.y
  if s.screen == "home" and inside(x, y, 90, 350, 300, 58) then start_game(s)
  elseif s.screen == "home" and y >= 742 then
    if x < 120 then s.screen = "home" elseif x < 240 then s.screen = "heroes" elseif x < 350 then s.screen = "report" else s.screen = "rules" end
  elseif (s.screen == "heroes" or s.screen == "report" or s.screen == "rules") and inside(x, y, 16, 14, 84, 38) then s.screen = "home"
  elseif s.screen == "mulligan" then
    if inside(x, y, 30, 590, 196, 56) then local p = s.game.players[4]; for _, c in ipairs(p.hand) do s.game.deck[#s.game.deck + 1] = c end; p.hand = {}; pull(s.game, p, 4); add_log(s.game, "你更换了初始手牌") ; s.screen = "battle"; s.game.phase = "prepare"
    elseif inside(x, y, 254, 590, 196, 56) then s.screen = "battle"; s.game.phase = "prepare" end
  elseif s.screen == "battle" then
    local g = s.game
    if g.phase == "response" and g.pending then
      local response_card = g.pending.kind == "dying" and "peach" or (g.pending.kind == "duel" and "slash" or "dodge")
      if contains(g.players[4].hand, response_card) and inside(x, y, 46, 394, 180, 40) then resolve_response(s, true)
      elseif inside(x, y, 254, 394, 180, 40) then resolve_response(s, false) end
    elseif g.current == 4 and g.phase == "discard" then
      local n, gap = #g.players[4].hand, (#g.players[4].hand <= 5 and 88 or math.max(54, math.floor((448 - CARD_W) / math.max(1, #g.players[4].hand - 1))))
      for i, kind in ipairs(g.players[4].hand) do
        if inside(x, y, 16 + (i - 1) * gap, 686, CARD_W, CARD_H + 12) then table.remove(g.players[4].hand, i); g.discard[#g.discard + 1] = kind; add_log(g, "你弃置了「" .. CARD_LABEL[kind] .. "」"); break end
      end
      if #g.players[4].hand <= g.players[4].hp then end_turn(s) end
    elseif g.current == 4 and g.phase == "action" then
      local chosen = selected_card(g)
      if chosen and inside(x, y, 150, 654, 84, 38) then
        human_play(s)
      elseif chosen and inside(x, y, 246, 654, 84, 38) then
        clear_selection(g); add_log(g, "取消使用「" .. CARD_LABEL[chosen] .. "」")
      elseif not chosen and inside(x, y, 160, 650, 160, 44) then
        end_turn(s)
      else
        local n, gap = #g.players[4].hand, (#g.players[4].hand <= 5 and 88 or math.max(54, math.floor((448 - CARD_W) / math.max(1, #g.players[4].hand - 1))))
        local picked = false
        for i, kind in ipairs(g.players[4].hand) do
          if inside(x, y, 16 + (i - 1) * gap, 686, CARD_W, CARD_H + 12) then
            if not card_playable(g, 4, kind) then add_log(g, "「" .. CARD_LABEL[kind] .. "」不能在出牌阶段主动使用")
            elseif g.selected == i then clear_selection(g)
            else g.selected, g.target = i, nil; add_log(g, "选中「" .. CARD_LABEL[kind] .. "」") end
            picked = true; break
          end
        end
        if not picked and chosen and TARGET_CARD[chosen] then
          local slots = {{187,50,1},{16,230,2},{358,230,3}}
          for _, slot in ipairs(slots) do
            if inside(x, y, slot[1], slot[2], 106, 176) and legal_target(g, 4, slot[3], chosen) then
              g.target = slot[3]; set_effect(g, "aim", 4, slot[3], "锁定", nil); add_log(g, "目标已指定为" .. g.players[slot[3]].name); break
            end
          end
        end
      end
    end
  elseif s.screen == "result" and inside(x, y, 90, 404, 300, 54) then s.screen = "home" end
  ctx:invalidate(); return true
end
