local Random = require("domain.random")

local Economy = {}

local GOODS = {
  { name = "医用口罩", average_price = 90 },
  { name = "饲料肉鸡", average_price = 170 },
  { name = "高档香烟", average_price = 380 },
  { name = "进口奶粉", average_price = 720 },
  { name = "防毒面具", average_price = 1500 },
  { name = "黄金首饰", average_price = 3000 },
  { name = "肾牌手机", average_price = 7000 },
  { name = "国产汽车", average_price = 19000 },
}

local function positive_integer(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function pay(state, cost)
  local from_cash = math.min(state.cash, cost)
  state.cash = state.cash - from_cash
  state.deposit = state.deposit - (cost - from_cash)
end

local function inventory_index_for(state, goods_id)
  for index, item in ipairs(state.inventory) do
    if item.goods_id == goods_id then
      return index
    end
  end
  return nil
end

local function market_price_for(state, goods_id)
  for _, item in ipairs(state.market) do
    if item.goods_id == goods_id then
      return item.price
    end
  end
  return nil
end

function Economy.goods()
  local result = {}
  for i, item in ipairs(GOODS) do
    result[i] = {
      id = i,
      name = item.name,
      average_price = item.average_price,
    }
  end
  return result
end

function Economy.refresh_market(state, rng)
  local available = {}
  local market = {}

  for i = 1, #GOODS do
    available[i] = i
  end

  for slot = 1, 5 do
    local pick = Random.int(rng, 1, #available)
    local goods_id = table.remove(available, pick)
    local average_price = GOODS[goods_id].average_price
    local direction = Random.int(rng, 0, 1) == 0 and -1 or 1
    local variation = Random.next(rng) / 3
    market[slot] = {
      goods_id = goods_id,
      price = math.max(1, math.floor(average_price * (1 + direction * variation))),
    }
  end

  state.market = market
  return market
end

function Economy.advance_week(state)
  state.week = state.week + 1

  if state.week > state.week_limit then
    state.status = "lost"
    state.ending = "time_up"
    return { ok = false, reason = "time_up", week = state.week }
  end

  for i, price in ipairs(state.house_prices) do
    state.house_prices[i] = math.floor(price * 1.01)
  end
  state.deposit = math.floor(state.deposit * 1.005)
  Economy.refresh_market(state, state.rng)

  return { ok = true, week = state.week }
end

function Economy.buy(state, market_index, quantity)
  local offer = state.market[market_index]
  if offer == nil then
    return { ok = false, reason = "invalid_market_index" }
  end
  if not positive_integer(quantity) then
    return { ok = false, reason = "invalid_quantity" }
  end

  local inventory_index = inventory_index_for(state, offer.goods_id)
  if inventory_index == nil and #state.inventory >= 5 then
    return { ok = false, reason = "slot_limit" }
  end
  if state.used + quantity > state.capacity then
    return { ok = false, reason = "capacity_limit" }
  end

  local cost = offer.price * quantity
  if state.cash + state.deposit < cost then
    return { ok = false, reason = "insufficient_funds" }
  end

  pay(state, cost)
  if inventory_index == nil then
    state.inventory[#state.inventory + 1] = {
      goods_id = offer.goods_id,
      quantity = quantity,
      average_cost = offer.price,
    }
  else
    local item = state.inventory[inventory_index]
    item.average_cost = math.floor(
      (item.average_cost * item.quantity + cost) / (item.quantity + quantity)
    )
    item.quantity = item.quantity + quantity
  end
  state.used = state.used + quantity

  return { ok = true, cost = cost }
end

function Economy.sell(state, inventory_index, quantity)
  local item = state.inventory[inventory_index]
  if item == nil then
    return { ok = false, reason = "invalid_inventory_index" }
  end

  local price = market_price_for(state, item.goods_id)
  if price == nil then
    return { ok = false, reason = "not_in_market" }
  end
  if not positive_integer(quantity) then
    return { ok = false, reason = "invalid_quantity" }
  end
  if quantity > item.quantity then
    return { ok = false, reason = "insufficient_quantity" }
  end

  local revenue = price * quantity
  state.cash = state.cash + revenue
  state.used = state.used - quantity
  item.quantity = item.quantity - quantity

  if item.goods_id == 3 or item.goods_id == 7 then
    state.reputation = state.reputation - 1
  end
  if item.quantity == 0 then
    table.remove(state.inventory, inventory_index)
  end

  return { ok = true, revenue = revenue }
end

function Economy.deposit_all(state)
  state.deposit = state.deposit + state.cash
  state.cash = 0
  return { ok = true }
end

function Economy.withdraw_all(state)
  state.cash = state.cash + state.deposit
  state.deposit = 0
  return { ok = true }
end

function Economy.expand_capacity(state, amount)
  if not positive_integer(amount) then
    return { ok = false, reason = "invalid_amount" }
  end

  local cost = amount * 10000
  if state.cash + state.deposit < cost then
    return { ok = false, reason = "insufficient_funds" }
  end

  pay(state, cost)
  state.capacity = state.capacity + amount
  return { ok = true, cost = cost }
end

function Economy.treat(state)
  if state.health >= 100 then
    return { ok = false, reason = "health_full" }
  end

  local cost = (100 - state.health) * 5000
  if state.cash + state.deposit < cost then
    return { ok = false, reason = "insufficient_funds", cost = cost }
  end

  pay(state, cost)
  state.health = 100
  return { ok = true, cost = cost }
end

return Economy
