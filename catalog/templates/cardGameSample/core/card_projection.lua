-- Information-safe projection. Hidden zones expose counts, never instance ids
-- or definition ids. This same boundary can support poker opponents, UNO hands
-- and deck-builder draw piles without trusting UI or AI code to look away.

local State = require("core.card_state")

local M = {}

local function may_see(zone, viewer)
  if zone.visibility == "public" then return true end
  if zone.visibility == "owner" then return viewer ~= nil and viewer == zone.owner end
  return false
end

function M.build(state, viewer, describe_card)
  local view = {
    schema_version = state.schema_version,
    game_id = state.game_id,
    revision = state.revision,
    viewer = viewer,
    status = state.status,
    winner = state.winner,
    turn = State.clone(state.turn),
    data = State.clone(state.data and state.data.public or {}),
    players = {},
    zones = {},
  }
  for index, player in ipairs(state.players) do
    view.players[index] = {
      id = index,
      public = State.clone(player.public),
      private = viewer == index and State.clone(player.private) or nil,
    }
  end
  for _, zone_id in ipairs(state.zone_order) do
    local zone = state.zones[zone_id]
    local projected = {
      id = zone.id,
      owner = zone.owner,
      visibility = zone.visibility,
      count = #zone.cards,
      data = State.clone(zone.data and zone.data.public or {}),
    }
    if may_see(zone, viewer) then
      projected.cards = {}
      for _, card_id in ipairs(zone.cards) do
        local card = state.entities[card_id]
        local visible = {
          id = card.id,
          definition_id = card.definition_id,
          owner = card.owner,
          controller = card.controller,
          data = State.clone(card.data),
        }
        if describe_card then visible.presentation = describe_card(card.definition_id) end
        projected.cards[#projected.cards + 1] = visible
      end
    end
    view.zones[zone_id] = projected
  end
  return view
end

return M
