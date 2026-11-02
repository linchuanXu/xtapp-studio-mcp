local Board = require("domain.board")
local Inventory = require("domain.game_inventory")
local Layout = require("domain.game_layout")
local Migration = require("domain.migration")
local Property = require("domain.property_rules")
local Rules = require("domain.rules")

local M = {}

function M.new_setup()
  return {
    schema = 3, phase = "setup",
    setup = { players = 4, mode = "quick", rounds = 12, tokens = { 1, 2, 3, 4, 5, 6, 7, 8 }, names = {} },
    ui = { setup_step = "cover" },
  }
end

function M.is_match(state)
  return type(state) == "table" and type(state.players) == "table" and state.phase ~= nil and state.phase ~= "setup" and #state.players >= 2
end

function M.setup_from_match(match)
  local setup = match and match.setup
  if type(setup) ~= "table" then
    setup = {
      players = match and match.players and #match.players or 4,
      mode = match and match.mode or "quick",
      rounds = match and match.round_limit or 12,
      tokens = {},
      names = {},
    }
    for i, player in ipairs((match and match.players) or {}) do
      setup.tokens[i] = player.token or i
      setup.names[i] = player.name
    end
  end
  return {
    schema = 3, phase = "setup",
    setup = {
      players = setup.players or 4,
      mode = setup.mode or "quick",
      rounds = setup.rounds or 12,
      tokens = setup.tokens or { 1, 2, 3, 4, 5, 6, 7, 8 },
      names = setup.names or {},
    },
    ui = { setup_step = "cover" },
  }
end

function M.boot(ctx)
  ctx.state.city_tycoon = Migration.ensure(ctx.state.city_tycoon)
  ctx.state.city_tycoon_resume = Migration.ensure(ctx.state.city_tycoon_resume)
  if M.is_match(ctx.state.city_tycoon) then
    ctx.state.city_tycoon_resume = ctx.state.city_tycoon
    ctx.state.city_tycoon = M.setup_from_match(ctx.state.city_tycoon_resume)
  elseif not ctx.state.city_tycoon then
    ctx.state.city_tycoon = M.new_setup()
  end
  return M.state(ctx)
end

function M.state(ctx)
  ctx.state.city_tycoon = Migration.ensure(ctx.state.city_tycoon) or M.new_setup()
  ctx.state.city_tycoon_resume = Migration.ensure(ctx.state.city_tycoon_resume)
  local live = ctx.state.city_tycoon
  live.ui = live.ui or {}
  live.ui.has_resume = M.is_match(ctx.state.city_tycoon_resume)
  return live
end

local function toggle(values, target)
  local out, removed = {}, false
  for _, value in ipairs(values or {}) do
    if value == target then removed = true else out[#out + 1] = value end
  end
  if target and not removed then out[#out + 1] = target end
  table.sort(out); return out
end

local function cursor_value(values, cursor)
  if #values == 0 then return nil end
  return values[((cursor or 1) - 1) % #values + 1]
end

local function sync_trade(state)
  local trade, ui = state.pending, state.ui
  Rules.set_trade_offer(state, {
    cash_from = ui.trade_cash_side == "from" and (ui.trade_cash or 0) or 0,
    cash_to = ui.trade_cash_side == "to" and (ui.trade_cash or 0) or 0,
    assets_from = ui.trade_my_assets or {}, assets_to = ui.trade_their_assets or {},
    cards_from = ui.trade_card_from or 0, cards_to = ui.trade_card_to or 0,
  })
end

local function start_game(ctx, state)
  local setup = state.setup
  local seed = ctx.clock:millis() + setup.players * 1009 + setup.rounds * 97 + 17
  local game = Rules.new(setup.players, setup.mode, seed, setup.rounds)
  for index = 1, setup.players do
    game.players[index].token = (setup.tokens and setup.tokens[index]) or index
    local name = setup.names and setup.names[index]
    if name and name ~= "" then game.players[index].name = name end
  end
  game.ui = {}
  game.setup = {
    players = setup.players, mode = setup.mode, rounds = setup.rounds,
    tokens = setup.tokens, names = setup.names,
  }
  return game
end

local function restart_game(ctx, state)
  local seed = ctx.clock:millis() + #state.players * 1009 + (state.round_limit or 0) * 97 + 17
  local game = Rules.new(#state.players, state.mode, seed, state.round_limit)
  for index, player in ipairs(state.players) do
    game.players[index].token = player.token or index
    game.players[index].name = player.name
  end
  game.ui = {}
  game.setup = state.setup
  if type(game.setup) ~= "table" then
    game.setup = { players = #state.players, mode = state.mode, rounds = state.round_limit or 12, tokens = {}, names = {} }
    for index, player in ipairs(state.players) do
      game.setup.tokens[index] = player.token or index
      game.setup.names[index] = player.name
    end
  end
  return game
end

local function selected_asset(state)
  local index, cursor = Inventory.selected(state, state.current, state.ui.asset_cursor)
  state.ui.asset_cursor = cursor
  return index
end

local function handle_asset_action(state, id)
  local list = Inventory.owned(state, state.current)
  if id == "asset_prev" then state.ui.asset_cursor = math.max(1, (state.ui.asset_cursor or 1) - 1); return true end
  if id == "asset_next" then state.ui.asset_cursor = math.min(math.max(1, #list), (state.ui.asset_cursor or 1) + 1); return true end
  local index = selected_asset(state); if not index then return false end
  if id == "asset_build" and state.phase ~= "debt_resolution" and Property.can_build(state, state.current, index) then Rules.build(state, index); return true end
  if state.mode == "classic" and id == "asset_sell" and Property.can_sell_building(state, state.current, index) then
    local resolving_debt = state.phase == "debt_resolution"
    Rules.sell_building(state, index)
    if resolving_debt and state.phase ~= "debt_resolution" then state.ui.overlay = nil end
    return true
  end
  if state.mode == "classic" and id == "asset_mortgage" and Property.can_mortgage(state, state.current, index) then
    local resolving_debt = state.phase == "debt_resolution"
    Rules.mortgage(state, index)
    if resolving_debt and state.phase ~= "debt_resolution" then state.ui.overlay = nil end
    return true
  end
  if state.mode == "classic" and id == "asset_unmortgage" then
    local asset, cost = state.assets[index], Property.unmortgage_cost(index)
    if asset.mortgaged and state.players[state.current].cash >= cost and state.phase ~= "debt_resolution" then Rules.unmortgage(state, index); return true end
  end
  return false
end

local function handle_trade_action(state, id)
  local ui = state.ui
  if id == "trade_cancel" then
    if state.phase == "trade" then Rules.decline_trade(state) end
    ui.trade_step = nil; return true
  end
  local target = string.match(id, "^trade_target_(%d+)$")
  if target then
    Rules.start_trade(state, tonumber(target)); ui.trade_step = "compose"; ui.trade_cash = 0; ui.trade_cash_side = "from"
    ui.trade_my_assets, ui.trade_their_assets = {}, {}; ui.trade_my_cursor, ui.trade_their_cursor = 1, 1
    ui.trade_card_from, ui.trade_card_to = 0, 0
    sync_trade(state); return true
  end
  if state.phase ~= "trade" then return false end
  local trade = state.pending
  local mine, theirs = Inventory.tradable(state, trade.from), Inventory.tradable(state, trade.to)
  if id == "trade_my_prev" then ui.trade_my_cursor = math.max(1, (ui.trade_my_cursor or 1) - 1); return true end
  if id == "trade_my_next" then ui.trade_my_cursor = math.min(math.max(1, #mine), (ui.trade_my_cursor or 1) + 1); return true end
  if id == "trade_my_toggle" then ui.trade_my_assets = toggle(ui.trade_my_assets, cursor_value(mine, ui.trade_my_cursor)); sync_trade(state); return true end
  if id == "trade_their_prev" then ui.trade_their_cursor = math.max(1, (ui.trade_their_cursor or 1) - 1); return true end
  if id == "trade_their_next" then ui.trade_their_cursor = math.min(math.max(1, #theirs), (ui.trade_their_cursor or 1) + 1); return true end
  if id == "trade_their_toggle" then ui.trade_their_assets = toggle(ui.trade_their_assets, cursor_value(theirs, ui.trade_their_cursor)); sync_trade(state); return true end
  if id == "trade_cash_side" then ui.trade_cash_side = ui.trade_cash_side == "from" and "to" or "from"; ui.trade_cash = 0; sync_trade(state); return true end
  if id == "trade_cash_plus" then
    local owner = ui.trade_cash_side == "to" and trade.to or trade.from
    ui.trade_cash = math.min(state.players[owner].cash, (ui.trade_cash or 0) + 50); sync_trade(state); return true
  end
  if id == "trade_cash_minus" then ui.trade_cash = math.max(0, (ui.trade_cash or 0) - 50); sync_trade(state); return true end
  if id == "trade_card_from" and state.players[trade.from].pass_cards > 0 then ui.trade_card_from = ui.trade_card_from == 1 and 0 or 1; sync_trade(state); return true end
  if id == "trade_card_to" and state.players[trade.to].pass_cards > 0 then ui.trade_card_to = ui.trade_card_to == 1 and 0 or 1; sync_trade(state); return true end
  if id == "trade_propose" then ui.trade_step = "confirm"; return true end
  if id == "trade_accept" then Rules.accept_trade(state); ui.trade_step = nil; return true end
  if id == "trade_decline" then Rules.decline_trade(state); ui.trade_step = nil; return true end
  return false
end

local function handle_edit_action(state, id)
  local ui, setup = state.ui, state.setup
  if id == "edit_prev" or id == "edit_next" then
    local current = ui.edit_token or (setup.tokens and setup.tokens[ui.editing_player]) or ui.editing_player
    local direction = id == "edit_next" and 1 or -1
    for offset = 1, 8 do
      local candidate = ((current - 1 + offset * direction) % 8) + 1
      local used = false
      for player = 1, setup.players do
        if player ~= ui.editing_player and (setup.tokens and setup.tokens[player]) == candidate then used = true; break end
      end
      if not used then ui.edit_token = candidate; break end
    end
    return true
  end
  if id == "kb_back" then
    local name = ui.edit_name or ""
    ui.edit_name = string.sub(name, 1, math.max(0, #name - 1))
    return true
  end
  if id == "kb_space" then
    if #(ui.edit_name or "") < 12 then ui.edit_name = (ui.edit_name or "") .. " " end
    return true
  end
  if id == "kb_done" then
    setup.names = setup.names or {}
    setup.names[ui.editing_player] = ui.edit_name or ""
    setup.tokens = setup.tokens or {}
    setup.tokens[ui.editing_player] = ui.edit_token or ui.editing_player
    ui.editing_player = nil
    return true
  end
  if id == "kb_close" then
    ui.editing_player = nil
    return true
  end
  local letter = string.match(id, "^kb_([a-z])$")
  if letter then
    if #(ui.edit_name or "") < 12 then ui.edit_name = (ui.edit_name or "") .. letter end
    return true
  end
  return false
end

function M.action(ctx, state, id)
  local ui = state.ui or {}; state.ui = ui
  if string.match(id, "^trade_") then
    if state.mode ~= "classic" then return false end
    return handle_trade_action(state, id)
  end
  if string.match(id, "^asset_") then return handle_asset_action(state, id) end
  if id == "close_overlay" then ui.overlay = nil; return true end
  if id == "open_game_menu" then ui.overlay = "game_menu"; ui.restart_confirm = nil; return true end
  if id == "open_help" then ui.overlay = "help"; return true end
  if id == "game_menu_help" and ui.overlay == "game_menu" then ui.overlay = "help"; return true end
  if id == "game_menu_restart" and ui.overlay == "game_menu" then ui.restart_confirm = true; return true end
  if id == "restart_game" and ui.overlay == "game_menu" and ui.restart_confirm then ctx.state.city_tycoon = restart_game(ctx, state); return true end
  if id == "game_menu_cover" and ui.overlay == "game_menu" then
    ctx.state.city_tycoon_resume = state
    ctx.state.city_tycoon = M.setup_from_match(state)
    return true
  end
  if id == "open_assets" then ui.overlay = "assets"; ui.asset_cursor = 1; return true end
  if id == "menu_continue" then
    local resume = ctx.state.city_tycoon_resume
    if not M.is_match(resume) then return false end
    resume.ui = resume.ui or {}
    resume.ui.overlay = nil
    resume.ui.trade_step = nil
    resume.ui.restart_confirm = nil
    ctx.state.city_tycoon = resume
    ctx.state.city_tycoon_resume = nil
    return true
  end
  if id == "menu_start" then
    ctx.state.city_tycoon_resume = nil
    ui.has_resume = false
    ui.setup_step = "players"
    return true
  end
  if id == "menu_back" then ui.setup_step = "cover"; return true end
  local avatar_player = tonumber(string.match(id, "^setup_avatar_(%d+)$"))
  if avatar_player and avatar_player <= state.setup.players then
    state.setup.tokens = state.setup.tokens or { 1, 2, 3, 4, 5, 6, 7, 8 }
    state.setup.names = state.setup.names or {}
    ui.editing_player = avatar_player
    ui.edit_name = state.setup.names[avatar_player] or ""
    ui.edit_token = state.setup.tokens[avatar_player] or avatar_player
    return true
  end
  if ui.editing_player and handle_edit_action(state, id) then return true end
  if id == "players_minus" then state.setup.players = math.max(2, state.setup.players - 1); return true end
  if id == "players_plus" then state.setup.players = math.min(8, state.setup.players + 1); return true end
  if id == "mode_quick" then state.setup.mode = "quick"; return true end
  if id == "mode_classic" then state.setup.mode = "classic"; return true end
  if id == "rounds_minus" then state.setup.rounds = math.max(12, state.setup.rounds - 4); return true end
  if id == "rounds_plus" then state.setup.rounds = math.min(20, state.setup.rounds + 4); return true end
  if id == "start_game" then ctx.state.city_tycoon = start_game(ctx, state); return true end
  if id == "handoff_ready" then Rules.ack_handoff(state); return true end
  if id == "roll" then Rules.roll(state); ui.move_cursor = 0; ui.move_elapsed = 0; return true end
  if id == "buy" then if state.players[state.current].cash >= Board.space(state.pending.index).price then Rules.buy_offered(state); return true end return false end
  if id == "skip_offer" and state.mode == "quick" then Rules.skip_offered(state); return true end
  if id == "auction" then if state.mode ~= "classic" then return false end Rules.decline_offered(state); return true end
  if id == "auction_min" or id == "auction_50" or id == "auction_100" then
    local minimum = Rules.auction_minimum(state)
    local amount = minimum + (id == "auction_50" and 50 or id == "auction_100" and 100 or 0)
    if state.players[state.pending.current_bidder].cash < amount then return false end
    Rules.auction_bid(state, amount); return true
  end
  if id == "auction_pass" then Rules.auction_pass(state); return true end
  if id == "draw_event" then Rules.draw_event(state); return true end
  if id == "finish_event" then Rules.finish_event(state); return true end
  if id == "rent_done" then Rules.finish_rent(state); return true end
  if id == "start_trade" and state.mode == "classic" then ui.trade_step = "target"; return true end
  if id == "end_turn" then Rules.end_turn(state); return true end
  if id == "checkpoint_pay" then if state.players[state.current].cash >= 50 then Rules.checkpoint_pay(state); return true end return false end
  if id == "checkpoint_wait" and state.mode == "quick" then Rules.checkpoint_wait(state); return true end
  if id == "checkpoint_card" then if state.mode == "classic" and state.players[state.current].pass_cards > 0 then Rules.checkpoint_use_card(state); return true end return false end
  if id == "checkpoint_roll" then if state.mode ~= "classic" then return false end Rules.checkpoint_roll(state); return true end
  if id == "bankruptcy_prompt" then if state.mode ~= "classic" then return false end ui.bankruptcy_confirm = true; return true end
  if id == "bankruptcy_cancel" then ui.bankruptcy_confirm = nil; return true end
  if id == "bankrupt" and state.mode == "classic" and ui.bankruptcy_confirm then
    ui.bankruptcy_confirm = nil
    Rules.declare_bankruptcy(state)
    if state.phase == "optional_actions" then Rules.end_turn(state) end
    return true
  end
  if id == "new_game" then
    ctx.state.city_tycoon_resume = nil
    ctx.state.city_tycoon = M.new_setup()
    return true
  end
  return false
end

function M.input(ctx, event)
  if not (event.type == "pointer" and event.phase == "up") or event.gesture ~= "tap" then return false end
  local state = M.state(ctx)
  local game_menu = Layout.game_menu_action(state)
  if game_menu and Layout.hit(game_menu, event.x, event.y) then
    local handled = M.action(ctx, state, game_menu.id)
    if handled then ctx:invalidate() end
    return handled
  end
  for _, action in ipairs(Layout.actions(state)) do
    if Layout.hit(action, event.x, event.y) then
      local handled = M.action(ctx, state, action.id)
      if handled then ctx:invalidate() end
      return handled
    end
  end
  return false
end

function M.tick(ctx, dt)
  local state = M.state(ctx)
  if state.phase ~= "moving" then return false end
  if not (state.pending and state.pending.kind == "move" and state.pending.path) then
    state.phase = "optional_actions"
    state.pending = nil
    ctx:invalidate()
    return true
  end
  local ui, path = state.ui, state.pending.path
  ui.move_elapsed = (ui.move_elapsed or 0) + math.max(0, dt or 0)
  if ui.move_elapsed < 180 then return false end
  ui.move_elapsed = ui.move_elapsed - 180; ui.move_cursor = (ui.move_cursor or 0) + 1
  state.players[state.current].position = path[math.min(ui.move_cursor, #path)]
  if ui.move_cursor >= #path then Rules.complete_move(state); ui.move_cursor = nil end
  ctx:invalidate(); return true
end

return M
