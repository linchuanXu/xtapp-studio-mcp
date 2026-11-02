local Random = require("domain.random")

local Houses = {}
local OFFICE_METADATA = setmetatable({}, { __mode = "k" })
local ACTIVE_OFFICES = setmetatable({}, { __mode = "k" })

local CATALOG = {
  { name = "单身公寓", base_price = 400000 },
  { name = "二手旧房", base_price = 1200000 },
  { name = "高档小区", base_price = 2400000 },
  { name = "跃层大房", base_price = 4000000 },
  { name = "四联排屋", base_price = 6000000 },
  { name = "一线江景豪宅", base_price = 10000000 },
  { name = "内环高端大宅", base_price = 20000000 },
  { name = "单体泳池别墅", base_price = 50000000 },
  { name = "热带小岛别墅", base_price = 100000000 },
  { name = "火星移民基地", base_price = 300000000 },
}

function Houses.catalog()
  local result = {}
  for i, house in ipairs(CATALOG) do
    result[i] = {
      id = i,
      name = house.name,
      base_price = house.base_price,
    }
  end
  return result
end

function Houses.reputation_allows(state, roll)
  local point = math.floor(roll * 50)
  return point >= 100 - state.reputation
end

function Houses.open_office(state, rng)
  local office = {}
  local allowed = {}
  for house_index = 1, #CATALOG do
    allowed[house_index] = Houses.reputation_allows(state, Random.next(rng))
  end
  OFFICE_METADATA[office] = { state = state, allowed = allowed }
  ACTIVE_OFFICES[state] = office
  return office
end

local function office_metadata(state, office)
  if type(office) ~= "table" then
    return nil
  end
  local metadata = OFFICE_METADATA[office]
  if metadata == nil
      or not rawequal(metadata.state, state)
      or not rawequal(ACTIVE_OFFICES[state], office) then
    return nil
  end
  return metadata
end

function Houses.can_buy(state, house_index, office)
  if type(house_index) ~= "number"
      or house_index ~= math.floor(house_index)
      or CATALOG[house_index] == nil
      or state.house_prices[house_index] == nil then
    return { ok = false, reason = "invalid_house_index" }
  end
  if state.status ~= "playing" then
    return { ok = false, reason = "not_playing" }
  end
  local metadata = office_metadata(state, office)
  if metadata == nil then
    return { ok = false, reason = "invalid_office" }
  end

  local price = state.house_prices[house_index]
  if state.cash + state.deposit < price then
    return { ok = false, reason = "insufficient_funds" }
  end
  if metadata.allowed[house_index] ~= true then
    return { ok = false, reason = "reputation_rejected" }
  end

  return { ok = true, price = price }
end

function Houses.buy(state, house_index, purchased_at, office)
  local result = Houses.can_buy(state, house_index, office)
  if not result.ok then
    return result
  end

  local from_cash = math.min(state.cash, result.price)
  state.cash = state.cash - from_cash
  state.deposit = state.deposit - (result.price - from_cash)
  state.selected_house = house_index
  state.status = "won"
  state.ending = "house_bought"

  return {
    ok = true,
    house_id = house_index,
    price = result.price,
    purchased_at = purchased_at,
  }
end

return Houses
