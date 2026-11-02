-- Generic card-match state and zone operations.
--
-- The kernel deliberately knows nothing about ranks, suits, health, betting,
-- mana or victory. A game plugin owns those meanings. The kernel only owns
-- identities, participants, zones, locations and deterministic state.

local Rng = require("core.card_rng")

local M = {}

local VALID_VISIBILITY = { public = true, owner = true, private = true }

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, item in pairs(value) do out[clone(key, seen)] = clone(item, seen) end
  return out
end

M.clone = clone

local function copy_map(value)
  return type(value) == "table" and clone(value) or {}
end

function M.new(spec)
  assert(type(spec) == "table", "card_state.new: spec required")
  local player_count = math.max(1, math.floor(tonumber(spec.player_count) or 1))
  local state = {
    schema_version = 1,
    game_id = assert(spec.game_id, "card_state.new: game_id required"),
    revision = 0,
    rng_state = Rng.normalize(spec.seed),
    next_entity_id = 1,
    players = {},
    zones = {},
    zone_order = {},
    entities = {},
    locations = {},
    turn = copy_map(spec.turn),
    data = {
      public = copy_map(spec.data and spec.data.public),
      private = copy_map(spec.data and spec.data.private),
    },
    status = "active",
    winner = nil,
  }
  for index = 1, player_count do
    local source = type(spec.players) == "table" and spec.players[index] or nil
    state.players[index] = {
      id = index,
      public = copy_map(source and source.public),
      private = copy_map(source and source.private),
    }
  end
  return state
end

function M.add_zone(state, zone)
  assert(type(zone) == "table" and type(zone.id) == "string", "card_state.add_zone: id required")
  assert(state.zones[zone.id] == nil, "card_state.add_zone: duplicate zone " .. zone.id)
  local visibility = zone.visibility or "public"
  assert(VALID_VISIBILITY[visibility], "card_state.add_zone: invalid visibility")
  if zone.owner ~= nil then
    assert(state.players[zone.owner] ~= nil, "card_state.add_zone: invalid owner")
  end
  state.zones[zone.id] = {
    id = zone.id,
    owner = zone.owner,
    visibility = visibility,
    ordered = zone.ordered ~= false,
    cards = {},
    data = {
      public = copy_map(zone.data and zone.data.public),
      private = copy_map(zone.data and zone.data.private),
    },
  }
  state.zone_order[#state.zone_order + 1] = zone.id
  return state.zones[zone.id]
end

function M.create_card(state, definition_id, owner, data)
  assert(type(definition_id) == "string", "card_state.create_card: definition_id required")
  if owner ~= nil then assert(state.players[owner], "card_state.create_card: invalid owner") end
  local id = "c" .. tostring(state.next_entity_id)
  state.next_entity_id = state.next_entity_id + 1
  state.entities[id] = {
    id = id,
    definition_id = definition_id,
    owner = owner,
    controller = owner,
    data = copy_map(data),
  }
  return id
end

function M.zone(state, zone_id)
  return state.zones[zone_id]
end

function M.card(state, card_id)
  return state.entities[card_id]
end

function M.location(state, card_id)
  return state.locations[card_id]
end

function M.insert(state, zone_id, card_id, position)
  local zone = assert(state.zones[zone_id], "card_state.insert: unknown zone " .. tostring(zone_id))
  assert(state.entities[card_id], "card_state.insert: unknown card " .. tostring(card_id))
  assert(state.locations[card_id] == nil, "card_state.insert: card already in a zone")
  position = tonumber(position)
  if position and position >= 1 and position <= #zone.cards + 1 then
    table.insert(zone.cards, math.floor(position), card_id)
  else
    zone.cards[#zone.cards + 1] = card_id
  end
  state.locations[card_id] = zone_id
  return card_id
end

function M.remove(state, card_id)
  local zone_id = state.locations[card_id]
  if not zone_id then return nil, "card_not_in_zone" end
  local zone = state.zones[zone_id]
  for index, id in ipairs(zone.cards) do
    if id == card_id then
      table.remove(zone.cards, index)
      state.locations[card_id] = nil
      return card_id, zone_id, index
    end
  end
  return nil, "location_index_mismatch"
end

function M.move(state, card_id, destination, position)
  local id, source = M.remove(state, card_id)
  if not id then return nil, source end
  M.insert(state, destination, card_id, position)
  return card_id, source, destination
end

function M.draw(state, source, destination, count)
  local from = assert(state.zones[source], "card_state.draw: unknown source")
  assert(state.zones[destination], "card_state.draw: unknown destination")
  local moved = {}
  for _ = 1, math.max(0, math.floor(tonumber(count) or 1)) do
    local card_id = from.cards[#from.cards]
    if not card_id then break end
    M.move(state, card_id, destination)
    moved[#moved + 1] = card_id
  end
  return moved
end

function M.shuffle(state, zone_id)
  local zone = assert(state.zones[zone_id], "card_state.shuffle: unknown zone")
  Rng.shuffle(state, zone.cards)
  return zone.cards
end

function M.assert_valid(state)
  assert(type(state) == "table" and type(state.players) == "table", "card state missing players")
  assert(type(state.zones) == "table" and type(state.entities) == "table", "card state missing stores")
  local seen = {}
  local seen_zones = {}
  for _, zone_id in ipairs(state.zone_order or {}) do
    assert(not seen_zones[zone_id], "zone_order contains duplicate zone")
    seen_zones[zone_id] = true
    local zone = assert(state.zones[zone_id], "zone_order references missing zone")
    assert(VALID_VISIBILITY[zone.visibility], "zone has invalid visibility")
    for _, card_id in ipairs(zone.cards) do
      assert(state.entities[card_id], "zone references missing card " .. tostring(card_id))
      assert(not seen[card_id], "card appears in multiple zones " .. tostring(card_id))
      assert(state.locations[card_id] == zone_id, "card location mismatch " .. tostring(card_id))
      seen[card_id] = true
    end
  end
  for card_id, zone_id in pairs(state.locations) do
    assert(seen[card_id], "location references card absent from zone " .. tostring(card_id))
    assert(state.zones[zone_id], "location references missing zone")
  end
  for card_id in pairs(state.entities) do
    assert(seen[card_id], "card is not assigned to a zone " .. tostring(card_id))
  end
  return true
end

return M
