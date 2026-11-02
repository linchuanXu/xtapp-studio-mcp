local Economy = require("domain.economy")
local Houses = require("domain.houses")
local Random = require("domain.random")

local State = {}

function State.new(seed)
  local rng = Random.new(seed)
  local house_prices = {}
  for i, house in ipairs(Houses.catalog()) do
    house_prices[i] = house.base_price
  end

  local state = {
    week = 1,
    week_limit = 52,
    cash = 3000,
    deposit = 0,
    health = 100,
    reputation = 100,
    capacity = 100,
    used = 0,
    inventory = {},
    market = {},
    house_prices = house_prices,
    selected_house = 1,
    status = "playing",
    ending = nil,
    rng = rng,
  }

  Economy.refresh_market(state, rng)
  return state
end

return State
