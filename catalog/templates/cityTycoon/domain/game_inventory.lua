local Board = require("domain.board")
local Property = require("domain.property_rules")

local M = {}

function M.owned(state, owner)
  local out = {}
  for index, asset in pairs(state.assets or {}) do
    if asset.owner == owner then out[#out + 1] = index end
  end
  table.sort(out)
  return out
end

function M.selected(state, owner, cursor)
  local list = M.owned(state, owner)
  if #list == 0 then return nil, 1, list end
  local selected_cursor = math.max(1, math.min(cursor or 1, #list))
  return list[selected_cursor], selected_cursor, list
end

function M.tradable(state, owner)
  local out = {}
  for _, index in ipairs(M.owned(state, owner)) do
    local space, blocked = Board.space(index), false
    if space.kind == "property" then
      for _, other in ipairs(Board.districts[space.district].spaces) do
        if state.assets[other].level > 0 then blocked = true; break end
      end
    end
    if not blocked then out[#out + 1] = index end
  end
  return out
end

function M.trade_has_value(trade)
  if not trade then return false end
  return (trade.cash_from or 0) > 0 or (trade.cash_to or 0) > 0
    or (trade.cards_from or 0) > 0 or (trade.cards_to or 0) > 0
    or #(trade.assets_from or {}) > 0 or #(trade.assets_to or {}) > 0
end

function M.has_exchangeable_value(state, owner)
  local player = state.players and state.players[owner]
  if not player or player.bankrupt then return false end
  return player.cash > 0 or player.pass_cards > 0 or #M.tradable(state, owner) > 0
end

function M.trade_targets(state, owner)
  local out, owner_has_value = {}, M.has_exchangeable_value(state, owner)
  for index, player in ipairs(state.players or {}) do
    if index ~= owner and not player.bankrupt and (owner_has_value or M.has_exchangeable_value(state, index)) then
      out[#out + 1] = index
    end
  end
  return out
end

function M.has_debt_action(state, owner)
  for _, index in ipairs(M.owned(state, owner)) do
    if Property.can_sell_building(state, owner, index) or Property.can_mortgage(state, owner, index) then return true end
  end
  return false
end

function M.has_buildable(state, owner)
  for _, index in ipairs(M.owned(state, owner)) do
    if Property.can_build(state, owner, index) then return true end
  end
  return false
end

return M
