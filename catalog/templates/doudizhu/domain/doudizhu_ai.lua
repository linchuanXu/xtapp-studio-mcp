-- 斗地主托管 AI 与对局引擎（纯逻辑，无 UI/IO）
-- 依赖 domain.doudizhu_rules（判型/比较/可压牌生成）。
-- 对局引擎：3 家（1 真人 + 2 AI，或 3 AI 观战）轮流叫地主、出牌、结算。

local Rules = require("domain.doudizhu_rules")
local Difficulty = require("domain.doudizhu_difficulty")
local PublicView = require("domain.doudizhu_public_view")
local Evaluator = require("domain.doudizhu_hand_evaluator")
local FastStrategy = require("domain.doudizhu_fast_strategy")
local LeadStrategy = require("domain.doudizhu_lead_strategy")
local FollowStrategy = require("domain.doudizhu_follow_strategy")

local M = {}

-- 叫分、炸弹和春天都可以翻倍，但必须有上限，避免一局极端牌型
-- 把单机欢乐豆账户永久打穿。48 倍仍保留足够强的高潮感。
M.MAX_MULTIPLIER = 48

local function multiply(state, factor)
  local current = math.max(1, math.floor(tonumber(state.multiplier) or 1))
  state.multiplier = math.min(M.MAX_MULTIPLIER, current * factor)
end

-- ── 发牌 ────────────────────────────────────────────────────────────────────
-- 返回 { hands = {player1, player2, player3}, deck = 3 张底牌 }
function M.deal(seed)
  local cards = {}
  for i = 1, 54 do cards[i] = i end
  -- Park–Miller 随机序列：乘积始终低于 Lua 双精度整数安全上限，
  -- 不会像旧 1103515245 LCG 那样吞掉低位，导致不同重开 seed 洗成同一副牌。
  local rng = (math.floor(tonumber(seed) or 1) % 2147483646) + 1
  for i = 54, 2, -1 do
    rng = (rng * 48271) % 2147483647
    local j = 1 + (rng % i)
    cards[i], cards[j] = cards[j], cards[i]
  end
  local hands = {
    {}, {}, {},
  }
  for i = 1, 51 do
    hands[((i - 1) % 3) + 1][#hands[((i - 1) % 3) + 1] + 1] = cards[i]
  end
  local deck = { cards[52], cards[53], cards[54] }
  for i = 1, 3 do hands[i] = Rules.sort_desc(hands[i]) end
  return { hands = hands, deck = deck }
end

-- ── 叫地主评分（rlcard get_landlord_score 启发式）──────────────────────────
-- A=1, 2=2, 小王=3, 大王=4, 王炸+8, 每炸弹+6
function M.landlord_score(hand)
  local counts = Rules.count_grades(hand)
  local score = 0
  if counts[16] >= 1 and counts[17] >= 1 then score = score + 8 end
  score = score + counts[14] * 1 + counts[15] * 2 + counts[16] * 3 + counts[17] * 4
  for g = 3, 15 do
    if counts[g] >= 4 then score = score + 6 end
  end
  return score
end

-- 叫分决策：返回叫分 0(不叫)/1/2/3
function M.bid_decision(hand, phase, called, difficulty)
  local profile = type(difficulty) == "table" and difficulty or Difficulty.get(difficulty)
  local score = M.landlord_score(hand)
  if profile.bid_structure_weight > 0 then
    local quality = Evaluator.analyze(hand)
    score = score + math.max(0, 6 - quality.turns) * profile.bid_structure_weight
  end
  -- 简单阈值：分数越高叫得越高；已有人叫分时只叫更高
  local want = 0
  if score >= 10 then want = 1 end
  if score >= 14 then want = 2 end
  if score >= 18 then want = 3 end
  if phase == "rob" then
    -- 抢地主：手牌够强就抢
    return score >= 16 and 1 or 0
  end
  if called and want <= called then return 0 end
  return want
end

-- ── 出牌选择 ────────────────────────────────────────────────────────────────
-- 领出：先整理完整长套，再处理散牌；炸弹始终保留。
-- 这样一局不至于变成连续的小单张，AI 也更像真实牌桌上的普通玩家。
function M.choose_lead(hand, difficulty, public_view, checkpoint)
  local profile = Difficulty.get(difficulty)
  if profile.id == "novice" then return FastStrategy.choose_lead(hand) end
  local view = public_view or {
    self_index = 1, landlord = 1, players = { { remaining = #hand }, { remaining = 17 }, { remaining = 17 } },
    played_counts = {}, own_cards = hand,
  }
  return LeadStrategy.choose(hand, view, profile, checkpoint)
end

-- 跟牌：在 greater_cards 结果里选。
--   yield_to_partner: 队友已接近出完时才让牌，避免整局由同一位农民独自出牌
--   landlord: 地主下标
--   self_idx: 当前玩家下标
-- 策略：同型最小压；不拆炸弹去压同型；队友的牌不大就放。
function M.choose_follow(hand, last_type, yield_to_partner, landlord, self_idx, difficulty, public_view, checkpoint)
  if yield_to_partner then return nil, { reason = "让队友先走" } end
  local profile = Difficulty.get(difficulty)
  if profile.id == "novice" then return FastStrategy.choose_follow(hand, last_type) end
  local view = public_view or {
    self_index = self_idx or 1,
    landlord = landlord,
    players = { { remaining = 17 }, { remaining = 17 }, { remaining = 17 } },
    last_type = last_type,
    last_player = landlord,
    played_counts = {}, own_cards = hand,
  }
  return FollowStrategy.choose(hand, view, profile, checkpoint)
end

-- ── 对局引擎 ────────────────────────────────────────────────────────────────
-- 状态：
--   phase: "deal"(发牌) / "bid"(叫地主) / "play"(出牌) / "over"(结算)
--   players: {{cards={...}, is_human, role="landlord"|"farmer"|nil}}
--   current: 当前行动玩家下标 1..3
--   landlord: 地主下标
--   last_play: {player, type} 上一手有效出牌（过牌不算）
--   last_type: 待压的牌型（本圈最大）
--   pass_count: 本圈连续过牌数
--   trick_actions: 当前一墩的可见动作；从领出到两家不出都保留，下一墩领出时才清空
--   multiplier: 倍数
--   winner: 胜方
function M.new_game(seed, human_index, difficulty)
  local dealt = M.deal(seed or 42)
  local played_counts = {}
  for grade = 3, 17 do played_counts[grade] = 0 end
  return {
    difficulty = Difficulty.normalize(difficulty),
    phase = "bid",
    players = {
      { cards = dealt.hands[1], is_human = human_index == 1, role = nil, last_play = nil },
      { cards = dealt.hands[2], is_human = human_index == 2, role = nil, last_play = nil },
      { cards = dealt.hands[3], is_human = human_index == 3, role = nil, last_play = nil },
    },
    deck = dealt.deck,
    current = 1,
    landlord = nil,
    bid_called = nil,   -- 当前最高叫分
    bid_best = nil,     -- 叫分最高者
    bid_round = 0,      -- 已叫分人数（1..3）
    last_type = nil,
    last_player = nil,
    pass_count = 0,
    trick_actions = {},
    public_history = {},
    played_counts = played_counts,
    bid_multiplier = 1,
    multiplier = 1,
    winner = nil,
    message = "叫地主",
    -- 春天/反春判定
    spring = nil,       -- 春天（地主出完且农民一张未出）
    anti_spring = nil,  -- 反春（农民出完且地主只出过一手）
    landlord_played = false, -- 地主是否出过牌
    landlord_hand_count = 0, -- 地主累计出牌手数（反春判定）
    farmer_played = { false, false, false }, -- 各农民是否出过牌（春天判定）
  }
end

-- 定地主：把底牌并入地主手牌、定 roles、地主先出。
-- 返回 true 表示成功定地主；false 表示需要重新发牌。
local function set_landlord(state, idx)
  if not idx then return false end
  state.landlord = idx
  local lord = state.players[idx]
  -- 底牌并入地主手牌后仍保留展示副本，供 UI 在整局持续展示关键信息。
  state.bottom_cards = {}
  for i, id in ipairs(state.deck) do state.bottom_cards[i] = id end
  for _, id in ipairs(state.deck) do lord.cards[#lord.cards + 1] = id end
  lord.cards = Rules.sort_desc(lord.cards)
  lord.role = "landlord"
  for i = 1, 3 do
    if i ~= idx then state.players[i].role = "farmer" end
  end
  state.deck = {}                 -- 底牌已并入地主，清空
  state.phase = "play"
  state.current = idx
  state.last_type = nil
  state.last_player = nil
  state.pass_count = 0
  state.trick_actions = {}
  -- 叫 1/2/3 分不只是决定地主，也决定这一局的初始风险。此前叫三分
  -- 仍从 1 倍开始，玩家几乎感受不到抢地主的代价和收益。
  state.bid_multiplier = math.max(1, math.min(3, math.floor(tonumber(state.bid_called) or 1)))
  state.multiplier = state.bid_multiplier
  state.message = "地主确定 · 底牌已亮"
  return true
end

-- 座位固定为：1=底部真人、2=左侧、3=右侧。
-- 斗地主按逆时针轮转，因此应是 1 → 3 → 2 → 1，
-- 而不是 Lua 下标递增的 1 → 2 → 3 → 1。
local function next_counterclockwise_player(index)
  return (index + 1) % 3 + 1
end

-- 桌面不是“最后一手牌”的快照，而是一墩牌的过程记录。UI 用它并列呈现
-- 三家的出牌/不出；复制 cards，避免后续调用方修改同一张表造成历史画面漂移。
local function append_trick_action(state, idx, action, cards, card_type)
  state.trick_actions = state.trick_actions or {}
  local copied = {}
  for i, id in ipairs(cards or {}) do copied[i] = id end
  state.trick_actions[#state.trick_actions + 1] = {
    actor = idx, action = action, cards = copied, type = card_type,
  }
  state.public_history = state.public_history or {}
  state.public_history[#state.public_history + 1] = {
    actor = idx, action = action, cards = copied, type = card_type,
  }
  if action == "play" then
    state.played_counts = state.played_counts or {}
    for grade = 3, 17 do state.played_counts[grade] = state.played_counts[grade] or 0 end
    for _, id in ipairs(copied) do
      local grade = Rules.grade_of(id)
      if grade then state.played_counts[grade] = state.played_counts[grade] + 1 end
    end
  end
end

-- 叫地主推进（AI 与人类共用）：
--   递增 bid_round；若某家叫 3 分立即定地主；叫满 3 家后定最高分者或重发。
-- 返回 "advance"（轮到下一家）/ "set"（已定地主）/ "redeal"（全不叫重发）
local function advance_bid(state, this_want, this_idx)
  state.bid_round = state.bid_round + 1
  -- 叫 3 分：立即定地主
  if this_want and this_want >= 3 then
    if set_landlord(state, this_idx) then return "set" end
    return "redeal"
  end
  -- 叫满 3 家
  if state.bid_round >= 3 then
    if state.bid_best then
      if set_landlord(state, state.bid_best) then return "set" end
    end
    return "redeal"
  end
  state.current = next_counterclockwise_player(state.current)
  return "advance"
end

-- 炸弹与王炸是可见的局势转折：规则层负责真正翻倍，UI 只消费 special
-- 做宣告，避免出现"炸弹特效很大但计分没有变化"的假反馈。
local function apply_special_multiplier(state, card_type)
  if not card_type then return nil end
  if card_type.t == Rules.CARD_TYPE.rocket then
    multiply(state, 2)
    return "rocket"
  end
  if card_type.t == Rules.CARD_TYPE.bomb then
    multiply(state, 2)
    return "bomb"
  end
  return nil
end

local function play_difficulty(state, actor_index)
  local actor = state.players[actor_index]
  if not actor or actor.role ~= "farmer" then return state.difficulty end
  for _, player in ipairs(state.players) do
    if player.is_human and player.role == "farmer" then
      -- 单人难度只增强真人的对手。若挑战档同时增强真人的 AI 农民
      -- 队友，队友会替机械提示玩家赢下更多牌局，难度反而倒挂。
      return "novice"
    end
  end
  return state.difficulty
end

-- AI 行动（由 UI 或测试调用）：根据当前状态自动决策并推进
-- 返回 { action, ... } 描述发生了什么
function M.ai_act(state, checkpoint)
  local idx = state.current
  local player = state.players[idx]
  if state.phase == "bid" then
    local called = state.bid_called or 0
    local want = M.bid_decision(player.cards, "bid", called, state.difficulty)
    -- 只能叫比当前最高分更高（或 0 = 不叫）
    if want > 0 and want <= called then want = 0 end
    if want > called then
      state.bid_called = want
      state.bid_best = idx
    end
    local r = advance_bid(state, want, idx)
    if r == "set" then return { action = "bid", want = want, landlord = state.landlord } end
    if r == "redeal" then return { action = "redeal" } end
    return { action = "bid", want = want }
  elseif state.phase == "play" then
    -- 落子后 last_type 会被新牌覆盖，先保留它是否在跟牌的语义供界面演出使用。
    local was_follow = state.last_type ~= nil
    local view = PublicView.build(state, idx)
    local actor_difficulty = play_difficulty(state, idx)
    local choice
    local decision
    local special = nil
    if not state.last_type then
      -- 领出
      choice, decision = M.choose_lead(player.cards, actor_difficulty, view, checkpoint)
      -- 搜索阶段只读状态；取得合法结果后才提交牌局变化，避免异常或预算
      -- 中止把半更新的 ctx.state 留给 on_leave 落盘。
      -- 上一墩的“出牌、不出、不出”在此刻才退场，新领出开启新的桌面记录。
      state.trick_actions = {}
      state.last_type = Rules.get_type(choice)
      special = apply_special_multiplier(state, state.last_type)
      state.last_player = idx
      state.pass_count = 0
      player.cards = Rules.remove(player.cards, choice)
      player.last_play = { cards = choice, type = state.last_type, action = "play" }
      append_trick_action(state, idx, "play", choice, state.last_type)
      M.note_played(state, idx)
    else
      choice, decision = M.choose_follow(player.cards, state.last_type, false, state.landlord, idx, actor_difficulty, view, checkpoint)
      if choice then
        state.last_type = Rules.get_type(choice)
        special = apply_special_multiplier(state, state.last_type)
        state.last_player = idx
        state.pass_count = 0
        player.cards = Rules.remove(player.cards, choice)
        player.last_play = { cards = choice, type = state.last_type, action = "play" }
        append_trick_action(state, idx, "play", choice, state.last_type)
        M.note_played(state, idx)
      else
        state.pass_count = state.pass_count + 1
        player.last_play = { action = "pass" }
        append_trick_action(state, idx, "pass")
      end
    end
    -- 结算
    if #player.cards == 0 then
      state.phase = "over"
      state.winner = idx
      state.message = "出完"
      M.judge_spring(state)
      -- 胜负同样是一手真实出牌；保留 cards 让状态记录、回放和测试
      -- 都能完整追踪 54 张牌的去向。
      return { action = "win", winner = idx, cards = choice, special = special, decision = decision, followed = was_follow }
    end
    -- 圈结束：两家都过 → 本圈最后出牌者重新领出
    if state.pass_count >= 2 then
      local lead = state.last_player
      state.last_type = nil
      state.last_player = nil
      state.pass_count = 0
      state.current = lead or idx
    else
      state.current = next_counterclockwise_player(state.current)
    end
    return { action = choice and "play" or "pass", cards = choice, special = special, decision = decision, followed = choice and was_follow or false }
  end
  return { action = "idle" }
end

function M.public_view(state, self_index)
  return PublicView.build(state, self_index)
end

function M.difficulty_profile(value)
  return Difficulty.get(value)
end

function M.difficulties()
  return Difficulty.list()
end

-- 界面“提示”的唯一决策源。它刻意保持易懂：首出最小单张，跟牌用
-- 规则枚举的第一手合法牌。测试用同一策略模拟全程依赖提示的玩家，
-- 避免 UI 与难度基准各自复制一套、最后测到的不是实际行为。
function M.hint_choice(state, player_index)
  local player = state and state.players and state.players[player_index]
  if not player then return nil end
  if state.last_type then
    local options = Rules.greater_cards(player.cards, state.last_type)
    return options[1] and options[1].cards or nil
  end
  local counts = Rules.count_grades(player.cards)
  for grade = 3, 17 do
    if counts[grade] >= 1 then return Rules.first_ids(player.cards, grade, 1) end
  end
  return nil
end

-- 记录某家出过牌（春天/反春判定）
function M.note_played(state, idx)
  if idx == state.landlord then
    state.landlord_played = true
    state.landlord_hand_count = (state.landlord_hand_count or 0) + 1
  elseif state.farmer_played then
    state.farmer_played[idx] = true
  end
end

-- 结算时判定春天/反春
-- 春天：地主出完时，两个农民都一张未出 → ×2
-- 反春：任一农民出完时，地主只出过一手 → ×2
function M.judge_spring(state)
  if not state.winner or not state.landlord then return end
  local landlord_win = state.winner == state.landlord
  if landlord_win then
    local any_farmer_played = state.farmer_played[1] or state.farmer_played[2] or state.farmer_played[3]
    if not any_farmer_played then
      state.spring = true
      multiply(state, 2)
      state.message = "春天 ×2"
    end
  else
    if (state.landlord_hand_count or 0) == 1 then
      state.anti_spring = true
      multiply(state, 2)
      state.message = "反春 ×2"
    end
  end
end

-- 人类出牌：selected 为选中的牌 id 列表
function M.human_play(state, selected)
  local idx = state.current
  local player = state.players[idx]
  if state.phase == "bid" then
    -- human 叫分：selected 为数字 0-3（0=不叫）
    local want = tonumber(selected) or 0
    local called = state.bid_called or 0
    if want > 0 and want <= called then return { ok = false, reason = "must_be_higher" } end
    if want > called then
      state.bid_called = want
      state.bid_best = idx
    end
    local r = advance_bid(state, want, idx)
    if r == "set" then return { ok = true, action = "bid", want = want, landlord = state.landlord, phase = "play" } end
    if r == "redeal" then return { ok = false, reason = "redeal" } end
    return { ok = true, action = "bid", want = want }
  elseif state.phase == "play" then
    -- 人类出牌也要保留首出/压过的差别；这是界面效果的真实规则来源。
    local was_follow = state.last_type ~= nil
    if not selected or #selected == 0 then
      -- 过牌
      if not state.last_type then return { ok = false, reason = "must_lead" } end
      state.pass_count = state.pass_count + 1
      player.last_play = { action = "pass" }
      append_trick_action(state, idx, "pass")
      if state.pass_count >= 2 then
        local lead = state.last_player
        state.last_type = nil
        state.last_player = nil
        state.pass_count = 0
        state.current = lead or idx
      else
        state.current = next_counterclockwise_player(state.current)
      end
      return { ok = true, action = "pass" }
    end
    local check = Rules.can_play(player.cards, selected, state.last_type)
    if not check.ok then return { ok = false, reason = check.reason } end
    -- 首家领出意味着前一墩结束；清空要晚于用户看见两家“不出”，早于新牌入桌。
    if not state.last_type then state.trick_actions = {} end
    state.last_type = check.type
    local special = apply_special_multiplier(state, check.type)
    state.last_player = idx
    state.pass_count = 0
    player.cards = Rules.remove(player.cards, selected)
    player.last_play = { cards = selected, type = check.type, action = "play" }
    append_trick_action(state, idx, "play", selected, check.type)
    M.note_played(state, idx)
    if #player.cards == 0 then
      state.phase = "over"
      state.winner = idx
      state.message = "出完"
      M.judge_spring(state)
      -- 与 AI 结算事件保持同一数据契约：最后一手也必须带出出的牌。
      return { ok = true, action = "win", winner = idx, cards = selected, special = special, followed = was_follow }
    end
    if state.pass_count >= 2 then
      state.current = state.last_player or idx
    else
      state.current = next_counterclockwise_player(state.current)
    end
    return { ok = true, action = "play", special = special, followed = was_follow }
  end
  return { ok = false, reason = "phase" }
end

return M
