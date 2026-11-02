local Board = require("domain.board")

local M = {}

local function district_levels(state, district)
  local levels, minimum, maximum = {}, 3, 0
  for _, index in ipairs(Board.districts[district].spaces) do
    local level = state.assets[index].level or 0
    levels[index] = level; minimum = math.min(minimum, level); maximum = math.max(maximum, level)
  end
  return levels, minimum, maximum
end

function M.owns_district(state, player_index, district)
  for _, index in ipairs(Board.districts[district].spaces) do if state.assets[index].owner ~= player_index then return false end end
  return true
end

function M.can_build(state, player_index, index)
  local space, asset = Board.space(index), state.assets[index]
  local maximum_level = state.mode == "quick" and 2 or 3
  if not asset or space.kind ~= "property" or asset.owner ~= player_index or asset.mortgaged or asset.level >= maximum_level then return false end
  if state.mode == "quick" then return state.players[player_index].cash >= Board.build_costs[space.district] end
  if not M.owns_district(state, player_index, space.district) then return false end
  local _, minimum = district_levels(state, space.district)
  if asset.level ~= minimum then return false end
  for _, other_index in ipairs(Board.districts[space.district].spaces) do if state.assets[other_index].mortgaged then return false end end
  return state.players[player_index].cash >= Board.build_costs[space.district]
end

function M.liquidation_value(state, index)
  local space, asset = Board.space(index), state.assets[index]
  if not asset then return 0 end
  local value = space.price or 0
  if space.kind == "property" then
    value = value + math.floor(Board.build_costs[space.district] / 2) * (asset.level or 0)
  end
  return value
end

function M.build(state, player_index, index)
  assert(M.can_build(state, player_index, index), "cannot build here")
  local space, asset = Board.space(index), state.assets[index]
  local cost = Board.build_costs[space.district]
  state.players[player_index].cash = state.players[player_index].cash - cost
  asset.level = asset.level + 1
  return cost
end

function M.can_sell_building(state, player_index, index)
  local space, asset = Board.space(index), state.assets[index]
  if not asset or space.kind ~= "property" or asset.owner ~= player_index or asset.level <= 0 then return false end
  local _, _, maximum = district_levels(state, space.district)
  return asset.level == maximum
end

function M.sell_building(state, player_index, index)
  assert(M.can_sell_building(state, player_index, index), "cannot sell building here")
  local space, asset = Board.space(index), state.assets[index]
  local refund = math.floor(Board.build_costs[space.district] / 2)
  asset.level = asset.level - 1
  state.players[player_index].cash = state.players[player_index].cash + refund
  return refund
end

function M.mortgage_value(index)
  return math.floor((Board.space(index).price or 0) / 2)
end

function M.can_mortgage(state, player_index, index)
  local space, asset = Board.space(index), state.assets[index]
  if not asset or asset.owner ~= player_index or asset.mortgaged then return false end
  if space.kind == "property" then
    for _, other_index in ipairs(Board.districts[space.district].spaces) do if state.assets[other_index].level > 0 then return false end end
  end
  return true
end

function M.mortgage(state, player_index, index)
  assert(M.can_mortgage(state, player_index, index), "cannot mortgage asset")
  local value = M.mortgage_value(index)
  state.assets[index].mortgaged = true
  state.players[player_index].cash = state.players[player_index].cash + value
  return value
end

function M.unmortgage_cost(index)
  return math.ceil(M.mortgage_value(index) * 1.1)
end

function M.unmortgage(state, player_index, index)
  local asset, player = state.assets[index], state.players[player_index]
  local cost = M.unmortgage_cost(index)
  assert(asset and asset.owner == player_index and asset.mortgaged, "asset is not mortgaged by player")
  assert(player.cash >= cost, "insufficient cash")
  player.cash = player.cash - cost; asset.mortgaged = false
  return cost
end

return M
