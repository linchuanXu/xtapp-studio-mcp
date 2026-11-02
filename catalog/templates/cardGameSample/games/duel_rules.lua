-- A small playable rules plugin. It demonstrates private hands, draw/discard
-- zones, resources, damage, card effects and phase transitions. None of these
-- concepts are built into core/card_engine.lua.

local State = require("core.card_state")
local Cards = require("games.duel_cards")

local M = {}

local STARTING_HEALTH = 20
local TURN_ENERGY = 3
local STARTING_HAND = 4

local function zone_id(player, kind)
  return "p" .. tostring(player) .. "_" .. kind
end

local function other(player)
  return player == 1 and 2 or 1
end

local function recycle_if_needed(state, api, player)
  local deck_id, discard_id = zone_id(player, "deck"), zone_id(player, "discard")
  local deck, discard = api.zone(deck_id), api.zone(discard_id)
  if #deck.cards > 0 or #discard.cards == 0 then return end
  while #discard.cards > 0 do api.move(discard.cards[#discard.cards], deck_id) end
  api.shuffle(deck_id)
  api.emit("deck_recycled", { player = player })
end

local function draw(state, api, player, count)
  for _ = 1, count do
    recycle_if_needed(state, api, player)
    if #api.zone(zone_id(player, "deck")).cards == 0 then return end
    api.draw(zone_id(player, "deck"), zone_id(player, "hand"), 1)
  end
end

local function damage(state, target, amount, api)
  local public = state.players[target].public
  local absorbed = math.min(public.armor or 0, amount)
  public.armor = (public.armor or 0) - absorbed
  public.health = public.health - (amount - absorbed)
  api.emit("damage", { target = target, amount = amount - absorbed, absorbed = absorbed })
  if public.health <= 0 then
    public.health = 0
    state.status = "over"
    state.winner = other(target)
    state.turn.phase = "over"
    api.emit("match_ended", { winner = state.winner })
  end
end

function M.spec(options)
  return {
    game_id = "ink_duel_sample",
    player_count = 2,
    seed = options.seed or 41,
    players = {
      { public = { name = "你", health = STARTING_HEALTH, armor = 0, energy = 0 } },
      { public = { name = "纸偶", health = STARTING_HEALTH, armor = 0, energy = 0 } },
    },
    turn = { round = 1, active_player = 1, phase = "main" },
    data = { public = { title = "墨牌试局" } },
  }
end

function M.setup(state, api)
  for player = 1, 2 do
    State.add_zone(state, { id = zone_id(player, "deck"), owner = player, visibility = "private" })
    State.add_zone(state, { id = zone_id(player, "hand"), owner = player, visibility = "owner" })
    State.add_zone(state, { id = zone_id(player, "discard"), owner = player, visibility = "public" })
    for _, definition_id in ipairs(Cards.deck) do
      local card_id = api.create_card(definition_id, player)
      api.insert(zone_id(player, "deck"), card_id)
    end
    api.shuffle(zone_id(player, "deck"))
    draw(state, api, player, STARTING_HAND)
  end
  state.players[1].public.energy = TURN_ENERGY
  api.emit("match_started", { active_player = 1 })
end

function M.actions(state, actor)
  if state.status ~= "active" or actor ~= state.turn.active_player then return {} end
  local actions = {}
  local hand = state.zones[zone_id(actor, "hand")]
  local energy = state.players[actor].public.energy or 0
  for _, card_id in ipairs(hand.cards) do
    local card = state.entities[card_id]
    local definition = Cards.get(card.definition_id)
    if definition and definition.cost <= energy then
      actions[#actions + 1] = { type = "play", actor = actor, card_id = card_id }
    end
  end
  actions[#actions + 1] = { type = "end_turn", actor = actor }
  return actions
end

function M.validate(state, action)
  if state.status ~= "active" then return false, "match_over" end
  if action.actor ~= state.turn.active_player then return false, "not_your_turn" end
  if action.type == "end_turn" then return true end
  if action.type ~= "play" then return false, "unknown_action" end
  local card = state.entities[action.card_id]
  if not card then return false, "unknown_card" end
  if state.locations[action.card_id] ~= zone_id(action.actor, "hand") then return false, "card_not_in_hand" end
  local definition = Cards.get(card.definition_id)
  if not definition then return false, "unknown_definition" end
  if definition.cost > (state.players[action.actor].public.energy or 0) then return false, "not_enough_energy" end
  return true
end

function M.reduce(state, action, api)
  if action.type == "end_turn" then
    local next_player = other(action.actor)
    state.players[next_player].public.armor = 0
    state.players[next_player].public.energy = TURN_ENERGY
    state.turn.active_player = next_player
    if next_player == 1 then state.turn.round = state.turn.round + 1 end
    draw(state, api, next_player, 1)
    api.emit("turn_started", { player = next_player, round = state.turn.round })
    return { active_player = next_player }
  end

  local card = state.entities[action.card_id]
  local definition = Cards.get(card.definition_id)
  local player = state.players[action.actor].public
  player.energy = player.energy - definition.cost
  api.move(action.card_id, zone_id(action.actor, "discard"))
  api.emit("card_played", { player = action.actor, card_id = action.card_id, definition_id = card.definition_id })

  if definition.kind == "attack" then
    damage(state, other(action.actor), definition.amount, api)
  elseif definition.kind == "guard" then
    player.armor = player.armor + definition.amount
    api.emit("armor_gained", { player = action.actor, amount = definition.amount })
  elseif definition.kind == "draw" then
    draw(state, api, action.actor, definition.amount)
  end
  return { card_id = action.card_id, definition_id = card.definition_id }
end

function M.describe_card(definition_id)
  return State.clone(Cards.get(definition_id) or { name = "?", cost = 0, kind = "unknown", amount = 0, mark = "?" })
end

function M.project(state, view)
  view.sample = {
    active_name = state.players[state.turn.active_player].public.name,
    rules = "每回合 3 点墨力；出牌后可继续行动，也可主动收笔。",
  }
end

return M
