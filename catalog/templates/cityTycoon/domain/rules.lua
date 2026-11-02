local Board = require("domain.board")
local Random = require("domain.random")
local Auction = require("domain.auction")
local Events = require("domain.events")
local Property = require("domain.property_rules")
local Scoring = require("domain.scoring")
local Trade = require("domain.trade_rules")

local M = {}
M.schema = 2

local function copy_array(values)
  local out = {}
  for index, value in ipairs(values or {}) do out[index] = value end
  return out
end

local function active_count(state)
  local count = 0
  for _, player in ipairs(state.players) do if not player.bankrupt then count = count + 1 end end
  return count
end

function M.new(player_count, mode, seed, round_limit)
  assert(player_count >= 2 and player_count <= 8, "player count must be 2-8")
  assert(mode == "quick" or mode == "classic", "invalid game mode")
  local players = {}
  for index = 1, player_count do
    players[index] = {
      id = "p" .. tostring(index), name = tostring(index) .. "号玩家", token = index,
      cash = Board.start_cash, position = 1, detained = 0, pass_cards = 0,
      bankrupt = false,
    }
  end
  local assets = {}
  for _, index in ipairs(Board.asset_spaces()) do assets[index] = { owner = nil, level = 0, mortgaged = false } end
  local normalized_seed = Random.normalize(seed)
  local decks
  normalized_seed, decks = Events.setup(normalized_seed)
  return {
    schema = M.schema, mode = mode, round_limit = mode == "quick" and (round_limit or 12) or nil,
    seed = normalized_seed, decks = decks, phase = "handoff", players = players, assets = assets,
    current = 1, round = 1, doubles = 0, last_roll = nil, pending = nil,
    log = { "游戏开始，由1号玩家先行。" }, results = nil,
    fund = 0, ui = {},
  }
end

function M.current_player(state)
  return assert(state.players[state.current], "missing current player")
end

function M.add_log(state, text)
  state.log[#state.log + 1] = text
  while #state.log > 40 do table.remove(state.log, 1) end
end

function M.ack_handoff(state)
  assert(state.phase == "handoff", "not waiting for handoff")
  state.phase = M.current_player(state).detained > 0 and "checkpoint_decision" or "pre_roll"
  M.add_log(state, M.current_player(state).name .. "接过本回合。")
end

function M.roll(state, forced_a, forced_b)
  assert(state.phase == "pre_roll", "cannot roll in current phase")
  state.ui = state.ui or {}; state.ui.banner = nil
  local player = M.current_player(state)
  local a, b
  if forced_a and forced_b then
    assert(forced_a >= 1 and forced_a <= 6 and forced_b >= 1 and forced_b <= 6, "invalid dice")
    a, b = forced_a, forced_b
  else
    state.seed, a = Random.int(state.seed, 1, 6)
    state.seed, b = Random.int(state.seed, 1, 6)
  end
  local is_double = a == b
  state.doubles = is_double and (state.doubles + 1) or 0
  state.last_roll = { a = a, b = b, total = a + b, is_double = is_double }
  if state.mode == "classic" and state.doubles >= 3 then
    player.position = 11; player.detained = 1; state.doubles = 0
    state.phase = "optional_actions"; state.pending = { kind = "sent_to_checkpoint" }
    M.add_log(state, player.name .. "连续三次掷出对子，前往检查站。")
    return copy_array({ 11 })
  end
  local path = {}
  for step = 1, a + b do path[#path + 1] = ((player.position - 1 + step) % #Board.spaces) + 1 end
  state.pending = { kind = "move", path = path, passed_start = player.position + a + b > #Board.spaces }
  state.phase = "moving"
  M.add_log(state, player.name .. "掷出" .. tostring(a) .. "+" .. tostring(b) .. "。")
  return copy_array(path)
end

function M.complete_move(state)
  assert(state.phase == "moving" and state.pending and state.pending.kind == "move", "not moving")
  local player = M.current_player(state)
  local move = state.pending
  player.position = move.path[#move.path] or player.position
  if move.passed_start then player.cash = player.cash + Board.start_income; M.add_log(state, player.name .. "经过启程广场，获得200。") end
  state.pending = nil
  return M.resolve_space(state)
end

function M.asset_rent(state, index, roll_total)
  local space, asset = Board.space(index), assert(state.assets[index], "not an asset")
  if asset.mortgaged or not asset.owner then return 0 end
  if space.kind == "property" then
    local rent = space.rent[(asset.level or 0) + 1]
    if asset.level == 0 and M.owns_district(state, asset.owner, space.district) then rent = rent * 2 end
    return rent
  end
  if space.kind == "transit" then
    if state.mode == "quick" then return 30 end
    local owned = 0
    for asset_index, other in pairs(state.assets) do if other.owner == asset.owner and Board.space(asset_index).kind == "transit" and not other.mortgaged then owned = owned + 1 end end
    return owned == 2 and 50 or 25
  end
  if state.mode == "quick" then return 30 end
  local owned = 0
  for asset_index, other in pairs(state.assets) do if other.owner == asset.owner and Board.space(asset_index).kind == "utility" and not other.mortgaged then owned = owned + 1 end end
  return (roll_total or 0) * (owned == 2 and 10 or 4)
end

function M.owns_district(state, player_index, district)
  return Property.owns_district(state, player_index, district)
end

local function easiest_asset_to_liquidate(state, player_index)
  local best_index, best_value
  for index, asset in pairs(state.assets) do
    if asset.owner == player_index then
      local value = Property.liquidation_value(state, index)
      if not best_value or value < best_value or (value == best_value and index < best_index) then
        best_index, best_value = index, value
      end
    end
  end
  return best_index, best_value
end

local function easy_payment(state, payer_index, amount, creditor_index, reason)
  local payer = state.players[payer_index]
  while payer.cash < amount do
    local index, value = easiest_asset_to_liquidate(state, payer_index)
    if not index then break end
    local asset = state.assets[index]
    asset.owner, asset.level, asset.mortgaged = nil, 0, false
    payer.cash = payer.cash + value
    M.add_log(state, payer.name .. "自动出售" .. Board.space(index).name .. "，收回" .. tostring(value) .. "。")
  end
  local paid = math.min(amount, math.max(0, payer.cash))
  payer.cash = payer.cash - paid
  if creditor_index then state.players[creditor_index].cash = state.players[creditor_index].cash + paid end
  if paid < amount then
    M.add_log(state, payer.name .. "现金不足，本次支付" .. tostring(paid) .. "（" .. reason .. "）。")
  else
    M.add_log(state, payer.name .. "支付" .. tostring(paid) .. "（" .. reason .. "）。")
  end
  state.phase = "optional_actions"
  return paid
end

local function set_banner(state, title, text, amount)
  state.ui = state.ui or {}
  state.ui.banner = { title = title, text = text, amount = amount }
end

function M.charge(state, payer_index, amount, creditor_index, reason, resume)
  if state.mode == "quick" then
    local paid = easy_payment(state, payer_index, amount, creditor_index, reason)
    if not creditor_index then state.fund = (state.fund or 0) + paid end
    return paid
  end
  local payer = state.players[payer_index]
  payer.cash = payer.cash - amount
  if creditor_index then
    state.players[creditor_index].cash = state.players[creditor_index].cash + amount
  else
    state.fund = (state.fund or 0) + amount
  end
  M.add_log(state, payer.name .. "支付" .. tostring(amount) .. "（" .. reason .. "）。")
  if payer.cash < 0 then
    state.phase = "debt_resolution"
    state.pending = { kind = "debt", creditor = creditor_index, reason = reason, resume = resume }
  else state.phase = "optional_actions" end
  return amount
end

function M.resolve_space(state)
  local player = M.current_player(state)
  local space = Board.space(player.position)
  if Board.is_asset(space) then
    local asset = state.assets[player.position]
    if not asset.owner then state.phase = "property_offer"; state.pending = { kind = "offer", index = player.position }; return "offer" end
    if asset.owner ~= state.current and not asset.mortgaged then
      local rent = M.asset_rent(state, player.position, state.last_roll and state.last_roll.total or 0)
      local settlement = { kind = "rent", payer = state.current, owner = asset.owner, index = player.position, amount = rent }
      settlement.amount = M.charge(state, state.current, rent, asset.owner, space.name .. "租金", { kind = "rent_result", settlement = settlement })
      if state.phase ~= "debt_resolution" then state.phase = "rent_result"; state.pending = settlement end
      return "rent"
    end
    if asset.owner == state.current then
      M.add_log(state, player.name .. "停在自己的" .. space.name .. "。")
      set_banner(state, space.name, "自己的地产")
    else
      M.add_log(state, space.name .. "已抵押，本次无需支付租金。")
      set_banner(state, space.name, "已抵押 · 免付租金")
    end
    state.phase = "optional_actions"; return "owned"
  end
  if space.kind == "tax" then
    M.charge(state, state.current, space.amount, nil, space.name)
    set_banner(state, space.name, "向城市基金缴纳 ¥" .. tostring(space.amount))
    return "tax"
  end
  if space.kind == "event" then state.phase = "event"; state.pending = { kind = "event", deck = space.deck }; return "event" end
  if space.kind == "park" then
    local fund = state.fund or 0
    if fund > 0 then
      player.cash = player.cash + fund
      M.add_log(state, player.name .. "领取城市发展基金" .. tostring(fund) .. "。")
      set_banner(state, "城市发展基金", "领取", fund)
      state.fund = 0
    else
      M.add_log(state, player.name .. "在人民公园休整，基金池还是空的。")
      set_banner(state, "人民公园", "基金池还是空的")
    end
    state.phase = "optional_actions"
    return "park"
  end
  if space.kind == "start" then
    M.add_log(state, player.name .. "抵达启程广场。")
    set_banner(state, "华夏启程", "抵达起点")
  elseif space.kind == "checkpoint" then
    M.add_log(state, player.name .. "经过交通管制站，本回合不受影响。")
    set_banner(state, "交通管制站", "路过，本回合不受影响")
  else
    M.add_log(state, player.name .. "抵达" .. space.name .. "。")
  end
  state.phase = "optional_actions"
  return space.kind
end

function M.buy_offered(state)
  assert(state.phase == "property_offer" and state.pending and state.pending.kind == "offer", "no property offer")
  local index = state.pending.index
  local space, player = Board.space(index), M.current_player(state)
  assert(not state.assets[index].owner, "asset already owned")
  assert(player.cash >= space.price, "insufficient cash")
  player.cash = player.cash - space.price
  state.assets[index].owner = state.current
  state.pending = nil; state.phase = "optional_actions"
  M.add_log(state, player.name .. "以" .. tostring(space.price) .. "购入" .. space.name .. "。")
  local can_build = Property.can_build(state, state.current, index)
  set_banner(state, "已购入 " .. space.name, can_build and "可以立即升级" or "已加入你的资产")
end

function M.decline_offered(state)
  assert(state.mode == "classic", "auction is only available in classic mode")
  assert(state.phase == "property_offer" and state.pending and state.pending.kind == "offer", "no property offer")
  local index = state.pending.index
  Auction.start(state, index)
  M.add_log(state, Board.space(index).name .. "进入公开竞拍。")
end

function M.skip_offered(state)
  assert(state.phase == "property_offer" and state.pending and state.pending.kind == "offer", "no property offer")
  assert(state.mode == "quick", "skip is only available in easy mode")
  local player, space = M.current_player(state), Board.space(state.pending.index)
  local bonus = math.floor((space.price or 0) / 2)
  player.cash = player.cash + bonus
  M.add_log(state, player.name .. "暂不购买" .. space.name .. "，领取市政补贴" .. tostring(bonus) .. "。")
  set_banner(state, "市政补贴", "领取 ¥" .. tostring(bonus))
  state.pending = nil; state.phase = "optional_actions"
end

function M.auction_bid(state, amount)
  local bidder = state.pending.current_bidder
  local result = Auction.bid(state, amount)
  M.add_log(state, state.players[bidder].name .. "出价" .. tostring(amount) .. "。")
  if result then M.add_log(state, state.players[result.winner].name .. "以" .. tostring(result.amount) .. "竞得" .. Board.space(result.index).name .. "。") end
end

function M.auction_pass(state)
  local bidder = state.pending.current_bidder
  local result = Auction.pass(state)
  M.add_log(state, state.players[bidder].name .. "退出本次竞拍。")
  if result then
    if result.winner then M.add_log(state, state.players[result.winner].name .. "以" .. tostring(result.amount) .. "竞得" .. Board.space(result.index).name .. "。")
    else M.add_log(state, Board.space(result.index).name .. "本次流拍。") end
  end
end

function M.auction_minimum(state)
  return Auction.minimum(state)
end

function M.build(state, index)
  assert(state.phase == "pre_roll" or state.phase == "optional_actions", "cannot build now")
  local cost = Property.build(state, state.current, index)
  M.add_log(state, M.current_player(state).name .. "在" .. Board.space(index).name .. "建设一级，支付" .. tostring(cost) .. "。")
end

function M.sell_building(state, index)
  assert(state.mode == "classic", "selling buildings is only available in classic mode")
  assert(state.phase == "pre_roll" or state.phase == "optional_actions" or state.phase == "debt_resolution", "cannot sell building now")
  local refund = Property.sell_building(state, state.current, index)
  M.add_log(state, M.current_player(state).name .. "出售" .. Board.space(index).name .. "一级建筑，收回" .. tostring(refund) .. "。")
  M.resolve_debt_if_paid(state)
end

function M.mortgage(state, index)
  assert(state.mode == "classic", "mortgage is only available in classic mode")
  assert(state.phase == "pre_roll" or state.phase == "optional_actions" or state.phase == "debt_resolution", "cannot mortgage now")
  local value = Property.mortgage(state, state.current, index)
  M.add_log(state, M.current_player(state).name .. "抵押" .. Board.space(index).name .. "，获得" .. tostring(value) .. "。")
  M.resolve_debt_if_paid(state)
end

function M.unmortgage(state, index)
  assert(state.mode == "classic", "unmortgage is only available in classic mode")
  assert(state.phase == "pre_roll" or state.phase == "optional_actions", "cannot unmortgage now")
  local cost = Property.unmortgage(state, state.current, index)
  M.add_log(state, M.current_player(state).name .. "解除" .. Board.space(index).name .. "抵押，支付" .. tostring(cost) .. "。")
end

function M.resolve_debt_if_paid(state)
  if state.phase == "debt_resolution" and M.current_player(state).cash >= 0 then
    local resume = state.pending and state.pending.resume
    state.phase = "optional_actions"; state.pending = nil
    M.add_log(state, M.current_player(state).name .. "已完成债务整理。")
    if resume and resume.kind == "rent_result" then
      state.phase = "rent_result"; state.pending = resume.settlement
    elseif resume and resume.kind == "checkpoint_roll" then
      state.phase = "pre_roll"
      M.roll(state, resume.a, resume.b)
    end
    return true
  end
  return false
end

function M.finish_rent(state)
  assert(state.phase == "rent_result" and state.pending and state.pending.kind == "rent", "rent result is not visible")
  state.pending = nil; state.phase = "optional_actions"
end

function M.declare_bankruptcy(state)
  assert(state.mode == "classic", "bankruptcy is only available in classic mode")
  assert(state.phase == "debt_resolution", "player is not resolving debt")
  local player_index, creditor = state.current, state.pending and state.pending.creditor
  local player = M.current_player(state)
  player.bankrupt = true; player.cash = 0
  for _, asset in pairs(state.assets) do
    if asset.owner == player_index then
      asset.owner = creditor; asset.level = 0
      if not creditor then asset.mortgaged = false end
    end
  end
  M.add_log(state, player.name .. "宣布破产。")
  state.pending = nil; state.phase = "optional_actions"; state.last_roll = nil; state.doubles = 0
  if active_count(state) <= 1 then state.results = Scoring.results(state); state.phase = "results" end
end

function M.start_trade(state, target)
  assert(state.mode == "classic", "trade is only available in classic mode")
  Trade.start(state, target)
end
function M.set_trade_offer(state, offer) Trade.set_offer(state, offer) end
function M.accept_trade(state) Trade.accept(state); M.add_log(state, "双方完成一笔资产交易。") end
function M.decline_trade(state) Trade.decline(state); M.add_log(state, "交易提案未达成。") end

local function move_to(state, position, collect_start)
  local player = M.current_player(state)
  if collect_start then player.cash = player.cash + Board.start_income end
  player.position = position
end

function M.draw_event(state)
  assert(state.phase == "event" and state.pending and state.pending.kind == "event", "no event to draw")
  local deck = state.pending.deck
  local card = Events.for_mode(Events.draw(state, deck), state.mode)
  local player = M.current_player(state)
  state.pending = { kind = "event_result", card = card, deck = deck }
  M.add_log(state, player.name .. "抽到：" .. card.text)
  if card.effect == "cash" then
    if card.amount >= 0 then player.cash = player.cash + card.amount; state.phase = "event_result"
    else M.charge(state, state.current, -card.amount, nil, "城市事件") end
  elseif card.effect == "collect_each" then
    for index, other in ipairs(state.players) do
      if index ~= state.current and not other.bankrupt then
        local paid = math.min(card.amount, math.max(0, other.cash))
        other.cash = other.cash - paid; player.cash = player.cash + paid
      end
    end
    state.phase = "event_result"
  elseif card.effect == "pay_each" then
    local recipients = active_count(state) - 1
    local paid = M.charge(state, state.current, card.amount * recipients, nil, "社区互助")
    local share = recipients > 0 and math.floor(paid / recipients) or 0
    for index, other in ipairs(state.players) do if index ~= state.current and not other.bankrupt then other.cash = other.cash + share end end
    if state.phase ~= "debt_resolution" then state.phase = "event_result" end
  elseif card.effect == "pass_card" then player.pass_cards = player.pass_cards + 1; state.phase = "event_result"
  elseif card.effect == "checkpoint" then player.position = 11; player.detained = 1; state.phase = "event_result"
  elseif card.effect == "repairs" then
    local levels = 0; for _, asset in pairs(state.assets) do if asset.owner == state.current then levels = levels + asset.level end end
    M.charge(state, state.current, levels * card.amount, nil, "建筑维护")
    if state.phase ~= "debt_resolution" then state.phase = "event_result" end
  elseif card.effect == "move" then move_to(state, card.position, card.collect_start); state.pending.resolve_after = true; state.phase = "event_result"
  end
  return card
end

function M.finish_event(state)
  assert(state.phase == "event_result", "event result is not visible")
  local resolve_after = state.pending and state.pending.resolve_after
  state.pending = nil
  if resolve_after then return M.resolve_space(state) end
  state.phase = "optional_actions"
end

function M.checkpoint_pay(state)
  assert(state.phase == "checkpoint_decision", "not at checkpoint decision")
  local player = M.current_player(state); assert(player.cash >= 50, "insufficient cash")
  player.cash = player.cash - 50; player.detained = 0; state.phase = "pre_roll"
end

function M.checkpoint_wait(state)
  assert(state.mode == "quick" and state.phase == "checkpoint_decision", "cannot rest now")
  local player = M.current_player(state)
  player.detained = 0
  M.add_log(state, player.name .. "在交通管制站休整一回合。")
  state.phase = "optional_actions"
  M.end_turn(state)
end

function M.checkpoint_use_card(state)
  assert(state.mode == "classic", "checkpoint cards are only available in classic mode")
  assert(state.phase == "checkpoint_decision", "not at checkpoint decision")
  local player = M.current_player(state); assert(player.pass_cards > 0, "no pass card")
  player.pass_cards = player.pass_cards - 1; player.detained = 0; state.phase = "pre_roll"
end

function M.checkpoint_roll(state, forced_a, forced_b)
  assert(state.mode == "classic", "checkpoint rolls are only available in classic mode")
  assert(state.phase == "checkpoint_decision", "not at checkpoint decision")
  local player = M.current_player(state)
  local a, b
  if forced_a and forced_b then a, b = forced_a, forced_b else state.seed, a = Random.int(state.seed, 1, 6); state.seed, b = Random.int(state.seed, 1, 6) end
  state.last_roll = { a = a, b = b, total = a + b, is_double = a == b }
  if a == b then player.detained = 0; state.phase = "pre_roll"; return M.roll(state, a, b) end
  player.detained = player.detained + 1
  if player.detained > 3 then
    player.detained = 0
    M.charge(state, state.current, 50, nil, "检查站离场费", { kind = "checkpoint_roll", a = a, b = b })
    if state.phase == "debt_resolution" then return nil end
    state.phase = "pre_roll"; return M.roll(state, a, b)
  end
  state.phase = "optional_actions"; M.add_log(state, player.name .. "未掷出对子，本回合留在检查站。")
end

function M.end_turn(state)
  assert(state.phase == "optional_actions", "cannot end turn")
  local extra = state.mode == "classic" and state.last_roll and state.last_roll.is_double and M.current_player(state).detained == 0
  state.pending = nil; state.last_roll = nil
  state.ui = state.ui or {}; state.ui.banner = nil
  if extra then state.phase = "pre_roll"; M.add_log(state, M.current_player(state).name .. "掷出对子，继续行动。"); return end
  state.doubles = 0
  local previous = state.current
  repeat state.current = state.current % #state.players + 1 until not state.players[state.current].bankrupt
  if state.current <= previous then state.round = state.round + 1 end
  if active_count(state) <= 1 or (state.mode == "quick" and state.round > state.round_limit) then state.results = Scoring.results(state); state.phase = "results"; return end
  state.phase = "handoff"
end

return M
