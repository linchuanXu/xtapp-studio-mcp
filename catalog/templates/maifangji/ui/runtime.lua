local Economy = require("domain.economy")
local Events = require("domain.events")
local Houses = require("domain.houses")
local Layout = require("ui.layout")
local Random = require("domain.random")
local Save = require("domain.save")
local State = require("domain.game_state")
local View = require("ui.view")

local Runtime = {}
local office = nil

local SCREENS = {
  main = true, story = true, houses = true, records = true, help = true,
}

local OVERLAY_KINDS = {
  new_game = true, quit_game = true,
  buy_goods = true, sell_goods = true,
  bank = true, hospital = true, agency = true,
  price_note = true, life_note = true,
  sick_blackout = true, sick_dead = true, time_up = true,
  sell_reputation = true, no_money = true,
  status = true, buy_succ = true,
}

local PASSIVE_OVERLAY_KINDS = {
  price_note = true, life_note = true,
  sick_blackout = true, sick_dead = true, time_up = true,
  sell_reputation = true, no_money = true,
  status = true, buy_succ = true,
}

local REASONS = {
  insufficient_funds = "资金不足",
  capacity_limit = "仓容不足",
  slot_limit = "库存品类已满",
  not_in_market = "本周无此行情",
  insufficient_quantity = "库存不足",
  health_full = "健康已满",
  reputation_rejected = "名声资格未通过",
  invalid_office = "售楼资格已失效",
  invalid_market_index = "无效商品",
  invalid_inventory_index = "无效库存",
}


local HOUSE_SUCCESS_MESSAGES = {
  "    一年的努力， 我终于在这个城市有了一个家， 虽然很小， 但是很温馨！",
  "    一年的咸菜馒头没有白费， 我的努力换来了一套二手旧房， 在这个城市有了安家落脚的地方！",
  "    通过一年的努力， 我终于在一个高档小区买上了房子， 解决了婚房问题， 美好的生活就在眼前！",
  "    一年非人的生活， 付出超乎常人的努力， 我买到了一套跃层的大房子， 成功跻身小土豪行列！",
  "    我的智慧和努力得到了回报， 用一年时间在这个城市买到了一套3层的大房子， 完成了几乎不可能完成的任务， 无愧小超人头衔！",
  "    一年的奋斗， 我从一名草根青年晋级成为城市精英， 进入了这个城市的成功人士小圈子中！",
  "    白手起家， 一年时间跻身富豪行列， 我的成功经历， 成为了充满梦想的年轻人津津乐道的榜样。",
  "    从草根青年到超级富豪， 我只用了一年时间， 我的成功在别人眼中显得非常神秘和遥不可及。",
  "    一年时间， 我创造出了从未有人创造过的神话， 金钱对我来说已经像空气一样取之不尽， 我躺在自家的沙滩上， 晒着太阳， 思考人生的意义究竟何在。",
  "    能力越大的人， 注定要承担更大的责任， 我决定成为人类的先驱， 移民火星， 成为一名火星人。 再见， 地球。 再见， 人类。",
}

local function base_saved()
  return {
    schema = 2,
    screen = "story",
    overlay = nil,
    focus = 1,
    overlay_focus = 1,
    quantity = 1,
    current_market = 1,
    story_seen = false,
    story_step = 1,
    help_step = 1,
    house_scroll = 1,
    game = nil,
    records = Save.default_records(),
    message_queue = {},
    seed_counter = 0,
  }
end

local function finite_integer(value)
  return type(value) == "number"
    and value == value
    and value ~= math.huge
    and value ~= -math.huge
    and value == math.floor(value)
end

local function array_length(value)
  if type(value) ~= "table" then return nil end
  local count, maximum = 0, 0
  for key in pairs(value) do
    if not finite_integer(key) or key < 1 then return nil end
    count = count + 1
    maximum = math.max(maximum, key)
  end
  if count ~= maximum then return nil end
  for index = 1, maximum do
    if rawget(value, index) == nil then return nil end
  end
  return maximum
end

local function valid_rng(rng)
  if type(rng) ~= "table"
      or not finite_integer(rng.state)
      or rng.state <= 0
      or not finite_integer(rng.forced_index) then
    return false
  end
  local count = array_length(rng.forced_rolls)
  if count == nil or rng.forced_index < 1 or rng.forced_index > count + 1 then
    return false
  end
  for index = 1, count do
    local roll = rng.forced_rolls[index]
    if type(roll) ~= "number" or roll ~= roll or roll < 0 or roll >= 1
        or roll == math.huge or roll == -math.huge then
      return false
    end
  end
  return true
end

local function valid_game(game)
  if type(game) ~= "table" then return false end
  for _, field in ipairs({
    "week", "week_limit", "cash", "deposit", "health", "reputation",
    "capacity", "used", "selected_house",
  }) do
    if not finite_integer(game[field]) then return false end
  end
  if game.week < 1 or game.week > 53 or game.week_limit ~= 52
      or game.cash < 0 or game.deposit < 0
      or game.health < 0 or game.health > 100
      or game.reputation < 0 or game.reputation > 100
      or game.capacity < 1 or game.used < 0 or game.used > game.capacity
      or game.selected_house < 1 or game.selected_house > 10
      or (game.status ~= "playing" and game.status ~= "won" and game.status ~= "lost")
      or (game.ending ~= nil and type(game.ending) ~= "string")
      or not valid_rng(game.rng) then
    return false
  end

  local market_count = array_length(game.market)
  local inventory_count = array_length(game.inventory)
  local house_count = array_length(game.house_prices)
  if market_count ~= 5 or inventory_count == nil or inventory_count > 5 or house_count ~= 10 then
    return false
  end
  local seen_market = {}
  for index = 1, market_count do
    local offer = game.market[index]
    if type(offer) ~= "table"
        or not finite_integer(offer.goods_id) or offer.goods_id < 1 or offer.goods_id > 8
        or not finite_integer(offer.price) or offer.price <= 0
        or seen_market[offer.goods_id] then
      return false
    end
    seen_market[offer.goods_id] = true
  end
  local inventory_total = 0
  local seen_inventory = {}
  for index = 1, inventory_count do
    local item = game.inventory[index]
    if type(item) ~= "table"
        or not finite_integer(item.goods_id) or item.goods_id < 1 or item.goods_id > 8
        or not finite_integer(item.quantity) or item.quantity <= 0
        or not finite_integer(item.average_cost) or item.average_cost <= 0
        or seen_inventory[item.goods_id] then
      return false
    end
    seen_inventory[item.goods_id] = true
    inventory_total = inventory_total + item.quantity
  end
  if inventory_total ~= game.used then return false end
  for index = 1, house_count do
    if not finite_integer(game.house_prices[index]) or game.house_prices[index] <= 0 then
      return false
    end
  end
  return true
end

local function snap_near_int(value)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
    return value
  end
  if value == math.floor(value) then
    return value
  end
  local snapped = value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
  if math.abs(value - snapped) <= 1e-6 then
    return snapped
  end
  return value
end

local function floor_price(value)
  value = snap_near_int(value)
  if type(value) == "number" and value < 1 then
    return 1
  end
  return value
end

local function clamp_stat(value)
  value = snap_near_int(value)
  if type(value) == "number" then
    if value < 0 then return 0 end
    if value > 100 then return 100 end
  end
  return value
end

local function sanitize_game(game)
  if type(game) ~= "table" then return end
  if type(game.rng) == "table" then
    Random.sanitize(game.rng)
  end
  for _, field in ipairs({
    "week", "week_limit", "cash", "deposit", "capacity", "used", "selected_house",
  }) do
    game[field] = snap_near_int(game[field])
  end
  game.health = clamp_stat(game.health)
  game.reputation = clamp_stat(game.reputation)
  if type(game.market) == "table" then
    for index = 1, 5 do
      local offer = game.market[index]
      if type(offer) == "table" then
        offer.goods_id = snap_near_int(offer.goods_id)
        offer.price = floor_price(offer.price)
      end
    end
  end
  if type(game.house_prices) == "table" then
    for index, price in ipairs(game.house_prices) do
      game.house_prices[index] = floor_price(price)
    end
  end
  if type(game.inventory) == "table" then
    for _, item in ipairs(game.inventory) do
      if type(item) == "table" then
        item.goods_id = snap_near_int(item.goods_id)
        item.quantity = snap_near_int(item.quantity)
        item.average_cost = snap_near_int(item.average_cost)
      end
    end
  end
end

local function copy_overlay(value)
  if type(value) ~= "table" or type(value.kind) ~= "string"
      or not OVERLAY_KINDS[value.kind] then
    return nil
  end
  local copy = { kind = value.kind }
  if value.index ~= nil then
    if not finite_integer(value.index) or value.index < 1 or value.index > 5 then return nil end
    copy.index = value.index
  end
  if value.title ~= nil then
    if type(value.title) ~= "string" then return nil end
    copy.title = value.title
  end
  if value.text ~= nil then
    if type(value.text) ~= "string" then return nil end
    copy.text = value.text
  end
  if value.page ~= nil then
    if not finite_integer(value.page) or value.page < 1 then return nil end
    copy.page = value.page
  end
  if (copy.kind == "buy_goods" or copy.kind == "sell_goods") and copy.index == nil then
    return nil
  end
  return copy
end

local function copy_passive_overlay(value)
  local copy = copy_overlay(value)
  if copy == nil or not PASSIVE_OVERLAY_KINDS[copy.kind]
      or type(copy.title) ~= "string" or type(copy.text) ~= "string" then
    return nil
  end
  return copy
end

local function overlays_equal(left, right)
  return left ~= nil and right ~= nil
    and left.kind == right.kind
    and left.index == right.index
    and left.title == right.title
    and left.text == right.text
    and left.page == right.page
end

local function normalize_message_queue(value)
  local count = array_length(value)
  if count == nil then return {}, false end
  local out = {}
  for index = 1, count do
    local item = copy_passive_overlay(value[index])
    if item == nil then return {}, false end
    out[index] = item
  end
  return out, true
end

local function legacy_message(message, game)
  if type(message) ~= "table"
      or type(message.kind) ~= "string"
      or type(message.title) ~= "string"
      or type(message.text) ~= "string" then
    return nil
  end
  local kinds = {
    price = "price_note",
    life = "life_note",
    sickness = game and game.ending == "dead" and "sick_dead" or "sick_blackout",
    status = "status",
  }
  return {
    kind = kinds[message.kind] or "status",
    title = message.title,
    text = message.text,
  }
end

local function open_overlay(saved, overlay)
  saved.overlay = overlay
  saved.overlay_focus = 1
end

local function show_queue_head(saved)
  local head = saved.message_queue[1]
  if head then
    open_overlay(saved, copy_passive_overlay(head))
  else
    saved.overlay = nil
    saved.overlay_focus = 1
  end
end

local function advance_queue(saved)
  table.remove(saved.message_queue, 1)
  show_queue_head(saved)
end

local function set_passive_overlay(saved, overlay)
  saved.message_queue = { overlay }
  show_queue_head(saved)
end

local function migrate_schema_one(saved)
  local legacy_screen = saved.screen
  local legacy_messages = saved.message_queue
  saved.schema = 2
  saved.screen = (legacy_screen == "houses" or legacy_screen == "records")
    and legacy_screen or "main"
  saved.focus = 1
  saved.overlay = nil
  saved.overlay_focus = 1
  saved.message_queue = {}
  saved.story_seen = true
  saved.story_step = 5
  saved.help_step = 1
  saved.house_scroll = math.max(1, math.min(9,
    saved.game and saved.game.selected_house or 1
  ))

  if legacy_screen == "dialog" then
    local count = array_length(legacy_messages)
    if count then
      for index = 1, count do
        local item = legacy_message(legacy_messages[index], saved.game)
        if item then saved.message_queue[#saved.message_queue + 1] = item end
      end
    end
    show_queue_head(saved)
  elseif saved.game and saved.game.status == "playing" then
    if legacy_screen == "bank" or legacy_screen == "hospital" or legacy_screen == "agency" then
      open_overlay(saved, { kind = legacy_screen })
    end
  elseif legacy_screen == "result" and saved.game then
    if saved.game.status == "won" then
      set_passive_overlay(saved, {
        kind = "buy_succ",
        title = "购房成功",
        text = HOUSE_SUCCESS_MESSAGES[saved.game.selected_house] or "本局已完成置业",
        page = 1,
      })
    else
      set_passive_overlay(saved, {
        kind = saved.game.ending == "time_up" and "time_up" or "sick_dead",
        title = "本局结束",
        text = saved.game.ending == "time_up"
          and "    我的豪情壮志最终没有成为现实， 一年时间过去了， 我没能买到属于自己的房子。 回到冰冷的出租屋， 我收拾东西打算回老家去了。"
          or Events.death_text(),
      })
    end
  end
  saved.return_screen = nil
end

local function first_enabled_from(actions, start)
  if #actions == 0 then return nil end
  for offset = 0, #actions - 1 do
    local index = (start + offset - 1) % #actions + 1
    if not actions[index].disabled then return index end
  end
  return nil
end

local function next_enabled(actions, start, delta)
  if #actions == 0 then return nil end
  for offset = 1, #actions do
    local index = (start - 1 + delta * offset) % #actions + 1
    if not actions[index].disabled then return index end
  end
  return nil
end

local function clamp_focus(saved)
  local actions = Layout.actions(saved)
  local focus = #actions == 0 and nil
    or math.max(1, math.min(#actions, saved.focus or 1))
  saved.focus = focus and first_enabled_from(actions, focus) or 1

  local overlays = Layout.overlay_actions(saved)
  local overlay_focus = #overlays == 0 and nil
    or math.max(1, math.min(#overlays, saved.overlay_focus or 1))
  saved.overlay_focus = overlay_focus and first_enabled_from(overlays, overlay_focus) or 1
end

local function normalize_overlay_queue(saved)
  local passive_overlay = copy_passive_overlay(saved.overlay)
  if #saved.message_queue > 0 then
    if passive_overlay and overlays_equal(passive_overlay, saved.message_queue[1]) then
      saved.overlay = passive_overlay
    else
      saved.message_queue = {}
      if passive_overlay then saved.overlay = nil end
    end
  elseif passive_overlay then
    saved.overlay = nil
  end
end

local function normalize_saved(ctx)
  local saved = ctx.state.maifangji
  if type(saved) ~= "table" then
    saved = base_saved()
    ctx.state.maifangji = saved
  end

  local source_schema = saved.schema
  saved.focus = finite_integer(saved.focus) and math.max(1, saved.focus) or 1
  saved.overlay_focus = finite_integer(saved.overlay_focus)
    and math.max(1, saved.overlay_focus) or 1
  saved.quantity = finite_integer(saved.quantity)
    and math.max(1, math.min(999, saved.quantity)) or 1
  saved.current_market = finite_integer(saved.current_market)
    and math.max(1, math.min(3, saved.current_market)) or 1
  saved.story_seen = type(saved.story_seen) == "boolean" and saved.story_seen or false
  saved.story_step = finite_integer(saved.story_step)
    and math.max(1, math.min(5, saved.story_step)) or 1
  saved.help_step = finite_integer(saved.help_step)
    and math.max(1, math.min(9, saved.help_step)) or 1
  saved.house_scroll = finite_integer(saved.house_scroll)
    and math.max(1, math.min(9, saved.house_scroll)) or 1
  saved.seed_counter = finite_integer(saved.seed_counter)
    and math.max(0, saved.seed_counter) or 0
  saved.records = Save.decode(saved.records)

  if saved.game ~= nil then
    sanitize_game(saved.game)
    if not valid_game(saved.game) then saved.game = nil end
  end
  if source_schema == 1 then
    migrate_schema_one(saved)
  elseif source_schema ~= 2 and saved.game == nil then
    local records = saved.records
    saved = base_saved()
    saved.records = records
    ctx.state.maifangji = saved
  else
    saved.schema = 2
    if not SCREENS[saved.screen] then saved.screen = "main" end
    saved.overlay = copy_overlay(saved.overlay)
    local source_messages = saved.message_queue
    local temporary_queue = source_messages == nil and saved.queue ~= nil
    if temporary_queue then source_messages = saved.queue end
    local messages, messages_valid = normalize_message_queue(source_messages)
    saved.message_queue = messages
    if temporary_queue and messages_valid then
      local passive_overlay = copy_passive_overlay(saved.overlay)
      if passive_overlay and not overlays_equal(passive_overlay, saved.message_queue[1]) then
        table.insert(saved.message_queue, 1, passive_overlay)
      end
    end
  end
  saved.queue = nil

  if saved.game == nil then
    if saved.screen == "houses" then saved.screen = "main" end
    if saved.overlay and saved.overlay.kind ~= "new_game"
        and saved.overlay.kind ~= "status" and saved.overlay.kind ~= "no_money" then
      saved.overlay = nil
    end
    saved.message_queue = {}
  elseif saved.game.status ~= "playing" then
    if saved.screen == "houses" then saved.screen = "main" end
    if saved.overlay and (saved.overlay.kind == "buy_goods"
        or saved.overlay.kind == "sell_goods"
        or saved.overlay.kind == "bank"
        or saved.overlay.kind == "hospital"
        or saved.overlay.kind == "agency"
        or saved.overlay.kind == "quit_game") then
      saved.overlay = nil
    end
  end
  normalize_overlay_queue(saved)
  saved.return_screen = nil
  clamp_focus(saved)
  return saved
end

local function close_overlay(saved)
  saved.overlay = nil
  saved.overlay_focus = 1
end

local function feedback(saved, reason)
  local kind = reason == "insufficient_funds" and "no_money" or "status"
  set_passive_overlay(saved, {
    kind = kind,
    title = kind == "no_money" and "钱不够" or "提示",
    text = REASONS[reason] or tostring(reason),
  })
end

local function new_game(saved)
  saved.seed_counter = saved.seed_counter + 1
  saved.game = State.new(20260903 + saved.seed_counter)
  saved.screen = "main"
  saved.quantity = 1
  saved.current_market = 1
  saved.message_queue = {}
  saved.overlay = nil
  saved.overlay_focus = 1
  saved.focus = 1
  office = nil
end

local function open_houses(saved)
  if not saved.game or saved.game.status ~= "playing" then return false end
  office = Houses.open_office(saved.game, saved.game.rng)
  saved.screen = "houses"
  saved.house_scroll = math.max(1, math.min(9, saved.game.selected_house))
  saved.focus = 1
  return true
end

local function queue_week_events(saved, market_id)
  local game = saved.game
  if not game or game.status ~= "playing" or market_id == saved.current_market then return false end
  saved.current_market = market_id
  local advanced = Economy.advance_week(game)
  if not advanced.ok then
    set_passive_overlay(saved, {
      kind = "time_up",
      title = "本局结束",
      text = "    我的豪情壮志最终没有成为现实， 一年时间过去了， 我没能买到属于自己的房子。 回到冰冷的出租屋， 我收拾东西打算回老家去了。",
    })
    return true
  end

  local messages = {}
  local price = Events.price_event(game, game.rng)
  messages[#messages + 1] = {
    kind = "price_note",
    title = "行情快报",
    text = Events.price_text(price),
  }
  local life = Events.life_event(game, game.rng)
  if life.id ~= "none" then
    messages[#messages + 1] = {
      kind = "life_note",
      title = "人生插曲",
      text = Events.life_text(life.id) or life.id,
    }
  end
  local sickness = Events.sickness(game, game.rng)
  if sickness == "blackout" then
    local aid = Events.apply_blackout_aid(game)
    messages[#messages + 1] = {
      kind = "sick_blackout",
      title = "突发昏倒",
      text = Events.blackout_text(aid),
    }
  elseif sickness == "dead" then
    game.status = "lost"
    game.ending = "dead"
    messages[#messages + 1] = {
      kind = "sick_dead", title = "健康警报", text = Events.death_text(),
    }
  end
  saved.message_queue = messages
  show_queue_head(saved)
  return true
end

local function timestamp(ctx, game)
  local value = ctx.clock:now().local_sec
  if value == nil then value = ctx.clock:now().epoch_sec end
  if value == nil then return "第" .. tostring(game.week) .. "周" end
  return tostring(value)
end

local function run_main_action(saved, id)
  local game = saved.game
  if id == "start_game" then
    open_overlay(saved, {
      kind = game and game.status == "playing" and "quit_game" or "new_game",
    })
    return true
  elseif id == "records" or id == "help" then
    saved.screen = id
    saved.focus = 1
    if id == "help" then saved.help_step = 1 end
    return true
  elseif id == "houses" then
    return open_houses(saved)
  elseif id == "bank" or id == "hospital" or id == "agency" then
    if not game or game.status ~= "playing" then return false end
    open_overlay(saved, { kind = id })
    return true
  end

  local market_id = tonumber(string.match(id, "^market(%d+)$"))
  if market_id then return queue_week_events(saved, market_id) end

  local buy_index = tonumber(string.match(id, "^buy_(%d+)$"))
  if buy_index and game and game.status == "playing" and game.market[buy_index] then
    saved.quantity = 1
    open_overlay(saved, { kind = "buy_goods", index = buy_index })
    return true
  end
  local sell_index = tonumber(string.match(id, "^sell_(%d+)$"))
  if sell_index and game and game.status == "playing" and game.inventory[sell_index] then
    saved.quantity = 1
    open_overlay(saved, { kind = "sell_goods", index = sell_index })
    return true
  end
  return false
end

local function run_overlay_action(saved, id)
  local game = saved.game
  local overlay = saved.overlay
  if not overlay then return false end
  if id == "close_overlay" then
    close_overlay(saved)
  elseif id == "confirm_overlay" then
    if overlay.kind == "buy_succ" then
      local pages = View.success_text_pages(overlay.text)
      local page = overlay.page or 1
      if page < #pages then
        overlay.page = page + 1
        if saved.message_queue[1] then
          saved.message_queue[1].page = overlay.page
        end
        return true
      end
    end
    if #saved.message_queue > 0 then advance_queue(saved) else close_overlay(saved) end
  elseif id == "confirm_new_game" then
    new_game(saved)
  elseif id == "confirm_quit_game" then
    if not game or game.status ~= "playing" then return false end
    game.status = "lost"
    game.ending = "quit"
    close_overlay(saved)
  elseif id == "quantity_minus" then
    saved.quantity = math.max(1, saved.quantity - 1)
  elseif id == "quantity_plus" then
    if overlay.kind == "sell_goods" then
      local item = game and game.inventory[overlay.index]
      local stock = item and item.quantity or 0
      if saved.quantity >= stock then
        feedback(saved, "insufficient_quantity")
        return true
      end
      saved.quantity = math.min(stock, saved.quantity + 1)
    else
      saved.quantity = math.min(999, saved.quantity + 1)
    end
  elseif id == "sell_qty_all" or id == "sell_qty_half"
      or id == "sell_qty_quarter" or id == "sell_qty_tenth" then
    if overlay.kind ~= "sell_goods" or not game then return false end
    local item = game.inventory[overlay.index]
    local stock = item and item.quantity or 0
    local divisor = id == "sell_qty_all" and 1
      or id == "sell_qty_half" and 2
      or id == "sell_qty_quarter" and 4
      or 10
    saved.quantity = math.max(1, math.floor(stock / divisor))
  elseif id == "buy_qty_all" or id == "buy_qty_half"
      or id == "buy_qty_quarter" or id == "buy_qty_tenth" then
    if overlay.kind ~= "buy_goods" or not game then return false end
    local maximum = Layout.buy_maximum(saved)
    if maximum < 1 then return false end
    local divisor = id == "buy_qty_all" and 1
      or id == "buy_qty_half" and 2
      or id == "buy_qty_quarter" and 4
      or 10
    saved.quantity = math.max(1, math.floor(maximum / divisor))
  elseif id == "agency_qty_all" or id == "agency_qty_half"
      or id == "agency_qty_quarter" or id == "agency_qty_tenth" then
    if overlay.kind ~= "agency" or not game then return false end
    local maximum = Layout.agency_maximum(saved)
    local divisor = id == "agency_qty_all" and 1
      or id == "agency_qty_half" and 2
      or id == "agency_qty_quarter" and 4
      or 10
    saved.quantity = math.max(1, math.floor(maximum / divisor))
  elseif id == "confirm_buy" then
    if overlay.kind ~= "buy_goods" or not game then return false end
    local result = Economy.buy(game, overlay.index, saved.quantity)
    if result.ok then close_overlay(saved) else feedback(saved, result.reason) end
  elseif id == "confirm_sell" then
    if overlay.kind ~= "sell_goods" or not game then return false end
    local item = game.inventory[overlay.index]
    local goods_id = item and item.goods_id
    local result = Economy.sell(game, overlay.index, saved.quantity)
    if result.ok and (goods_id == 3 or goods_id == 7) then
      set_passive_overlay(saved, {
        kind = "sell_reputation",
        title = "名声变化",
        text = "交易使名声下降",
      })
    elseif result.ok then
      close_overlay(saved)
    else
      feedback(saved, result.reason)
    end
  elseif id == "deposit_all" then
    if not game then return false end
    Economy.deposit_all(game)
    close_overlay(saved)
  elseif id == "withdraw_all" then
    if not game then return false end
    Economy.withdraw_all(game)
    close_overlay(saved)
  elseif id == "treat" then
    if not game then return false end
    local result = Economy.treat(game)
    if not result.ok then feedback(saved, result.reason) end
  elseif id == "expand" then
    if not game then return false end
    local result = Economy.expand_capacity(game, saved.quantity)
    if result.ok then close_overlay(saved) else feedback(saved, result.reason) end
  else
    return false
  end
  return true
end

local function run_screen_action(ctx, saved, id)
  local game = saved.game
  if id == "return_main" then
    office = nil
    saved.screen = "main"
    saved.focus = 1
  elseif id == "continue_story" and saved.screen == "story" then
    saved.story_step = math.min(5, saved.story_step + 1)
  elseif id == "finish_story" and saved.screen == "story"
      and saved.story_step >= 5 then
    saved.story_seen = true
    saved.story_step = 5
    saved.screen = "main"
    saved.focus = 1
  elseif id == "help_next" and saved.screen == "help" then
    saved.help_step = math.min(9, saved.help_step + 1)
  elseif id == "house_buy" and game then
    local result = Houses.buy(game, game.selected_house, timestamp(ctx, game), office)
    if result.ok then
      Save.record_success(saved.records, game.selected_house, result.purchased_at)
      office = nil
      saved.screen = "main"
      set_passive_overlay(saved, {
        kind = "buy_succ",
        title = "购房成功",
        text = HOUSE_SUCCESS_MESSAGES[game.selected_house] or "本局已完成置业",
        page = 1,
      })
    else
      feedback(saved, result.reason)
    end
  else
    return false
  end
  return true
end

local function back(saved)
  if saved.overlay then
    if #saved.message_queue > 0
        and overlays_equal(saved.overlay, saved.message_queue[1]) then
      advance_queue(saved)
    else
      close_overlay(saved)
      saved.message_queue = {}
    end
    return true
  end
  if saved.screen == "houses" or saved.screen == "records"
      or saved.screen == "help" or saved.screen == "story" then
    office = nil
    saved.screen = "main"
    saved.focus = 1
    return true
  end
  return false
end

local function active_actions(saved)
  if saved.overlay then
    return Layout.overlay_actions(saved), "overlay_focus"
  end
  return Layout.actions(saved), "focus"
end

local function move_house_selection(saved, delta)
  local game = saved.game
  if not game then return false end
  local selected = game.selected_house + delta
  if selected < 1 or selected > 10 then return false end
  game.selected_house = selected
  if selected < saved.house_scroll then
    saved.house_scroll = selected
  elseif selected >= saved.house_scroll + Layout.ACTIVITIES.houses.visibleCount then
    saved.house_scroll = selected - Layout.ACTIVITIES.houses.visibleCount + 1
  end
  return true
end

local function key_input(ctx, saved, ev)
  if ev.phase ~= "down" then return false end
  if ev.key == "back" then return back(saved) end
  if saved.overlay == nil and saved.screen == "houses" then
    if ev.key == "up" then return move_house_selection(saved, -1) end
    if ev.key == "down" then return move_house_selection(saved, 1) end
  end
  local actions, focus_field = active_actions(saved)
  if ev.key == "up" then
    local next_focus = next_enabled(actions, saved[focus_field], -1)
    if not next_focus then return false end
    saved[focus_field] = next_focus
  elseif ev.key == "down" then
    local next_focus = next_enabled(actions, saved[focus_field], 1)
    if not next_focus then return false end
    saved[focus_field] = next_focus
  elseif ev.key == "left" or ev.key == "right" then
    local delta = ev.key == "left" and -1 or 1
    if saved.overlay and (saved.overlay.kind == "buy_goods"
        or saved.overlay.kind == "sell_goods" or saved.overlay.kind == "agency") then
      if saved.overlay.kind == "sell_goods" and delta > 0 then
        local item = saved.game and saved.game.inventory[saved.overlay.index]
        local stock = item and item.quantity or 0
        if saved.quantity >= stock then
          feedback(saved, "insufficient_quantity")
        else
          saved.quantity = math.min(stock, saved.quantity + delta)
        end
      else
        saved.quantity = math.max(1, math.min(999, saved.quantity + delta))
      end
    else
      return false
    end
  elseif ev.key == "ok" then
    local selected = actions[saved[focus_field]]
    if not selected or selected.disabled then return false end
    local handled
    if saved.overlay then
      handled = run_overlay_action(saved, selected.id)
    elseif saved.screen == "main" then
      handled = run_main_action(saved, selected.id)
    else
      handled = run_screen_action(ctx, saved, selected.id)
    end
    if not handled then return false end
  else
    return false
  end
  clamp_focus(saved)
  return true
end

local function touch_input(ctx, saved, ev)
  if saved.overlay == nil and saved.screen == "houses"
      and (ev.gesture == "swipe_up" or ev.gesture == "swipe_down") then
    local viewport = Layout.ACTIVITIES.houses.viewport
    if not Layout.hit(viewport, ev.x, ev.y) then return false end
    return move_house_selection(saved, ev.gesture == "swipe_up" and 1 or -1)
  end
  if ev.gesture ~= "tap" then return false end
  if saved.overlay == nil and saved.screen == "houses" then
    for _, row in ipairs(Layout.house_rows(saved)) do
      if Layout.hit(row, ev.x, ev.y) then
        saved.game.selected_house = row.house_index
        return true
      end
    end
  end
  local function activate(actions, focus_field)
    local action_screen = saved.screen
    for index, item in ipairs(actions) do
      if Layout.hit(item, ev.x, ev.y) then
        if item.disabled then return false end
        local handled
        if saved.overlay then
          handled = run_overlay_action(saved, item.id)
        elseif saved.screen == "main" then
          handled = run_main_action(saved, item.id)
        else
          handled = run_screen_action(ctx, saved, item.id)
        end
        if not handled then return false end
        if saved.screen == action_screen then saved[focus_field] = index end
        clamp_focus(saved)
        return true
      end
    end
    return false
  end

  local actions, focus_field = active_actions(saved)
  if activate(actions, focus_field) then return true end
  -- 真机每次触摸会先注入 Click/OK。若焦点停在「结束游戏」，会先弹出认输框，
  -- 手指实际点到的市场就被挡掉；点在框外时取消认输并落到主界面目标。
  if saved.overlay and (saved.overlay.kind == "quit_game" or saved.overlay.kind == "new_game") then
    close_overlay(saved)
    actions, focus_field = active_actions(saved)
    return activate(actions, focus_field)
  end
  return false
end

function Runtime.boot(ctx)
  local saved = normalize_saved(ctx)
  office = nil
  if not saved.story_seen and saved.game == nil and saved.screen == "main" then
    saved.screen = "story"
    saved.story_step = math.max(1, math.min(5, saved.story_step))
    saved.focus = 1
  end
  if saved.screen == "houses" and saved.game and saved.game.status == "playing" then
    office = Houses.open_office(saved.game, saved.game.rng)
  end
  clamp_focus(saved)
  ctx:set_tick(0)
end

function Runtime.state(ctx)
  return normalize_saved(ctx)
end

function Runtime.input(ctx, ev)
  local saved = normalize_saved(ctx)
  local before_screen = saved.screen
  local before_house_scroll = saved.house_scroll
  local handled
  if ev.type == "key" then
    handled = key_input(ctx, saved, ev)
  elseif (ev.type == "pointer" and ev.phase == "up") then
    handled = touch_input(ctx, saved, ev)
  else
    return false
  end
  if handled then
    ctx:invalidate()
  end
  return handled
end

return Runtime
