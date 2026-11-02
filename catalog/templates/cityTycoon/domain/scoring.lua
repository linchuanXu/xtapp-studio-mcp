local Board = require("domain.board")
local Property = require("domain.property_rules")

local M = {}

function M.net_worth(state, player_index)
  local player = state.players[player_index]
  local total = math.max(0, player.cash)
  for index, asset in pairs(state.assets) do
    if asset.owner == player_index then
      local space = Board.space(index)
      total = total + (asset.mortgaged and Property.mortgage_value(index) or space.price)
      if space.kind == "property" then total = total + math.floor(Board.build_costs[space.district] / 2) * asset.level end
    end
  end
  return total
end

function M.results(state)
  local rows = {}
  for index, player in ipairs(state.players) do
    local districts, assets = 0, 0
    for key, definition in pairs(Board.districts) do if Property.owns_district(state, index, key) then districts = districts + 1 end end
    for _, asset in pairs(state.assets) do if asset.owner == index then assets = assets + 1 end end
    rows[#rows + 1] = { player = index, name = player.name, bankrupt = player.bankrupt, worth = M.net_worth(state, index), cash = player.cash, districts = districts, assets = assets }
  end
  table.sort(rows, function(a, b)
    if a.bankrupt ~= b.bankrupt then return not a.bankrupt end
    if a.worth ~= b.worth then return a.worth > b.worth end
    if a.cash ~= b.cash then return a.cash > b.cash end
    if a.districts ~= b.districts then return a.districts > b.districts end
    if a.assets ~= b.assets then return a.assets > b.assets end
    return a.player < b.player
  end)
  for rank, row in ipairs(rows) do row.rank = rank end
  return rows
end

return M
