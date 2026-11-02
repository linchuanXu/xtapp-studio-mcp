local Layout = {}

local function action(id, x, y, w, h, label, disabled)
  return {
    id = id, x = x, y = y, w = w, h = h,
    label = label, disabled = disabled or nil,
  }
end

local function copy_actions(source)
  local out = {}
  for index, item in ipairs(source) do
    out[index] = action(
      item.id, item.x, item.y, item.w, item.h, item.label, item.disabled
    )
  end
  return out
end

-- Task 1 locks interactive rectangles and coarse regions only.
-- Task 3 adds labels and the remaining noninteractive visual fields.
-- These are 360x600 logical rectangles scaled component-wise with
-- floor(value * 4 / 3 + 0.5); the golden fixture retains logical provenance.
-- X4P portrait is locked to 480x800; ctx.screen.width/height stay 480/800.
Layout.MAIN = {
  market = { x = 0, y = 92, w = 205, h = 255 },
  warehouse = { x = 205, y = 92, w = 275, h = 255 },
  status_cash = { x = 0, y = 351, w = 480, h = 43 },
  status_deposit = { x = 0, y = 399, w = 480, h = 43 },
}

Layout.MAIN_VISUAL = {
  header = { x = 0, y = 0, w = 480, h = 60 },
  header_house_label = { x = 13, y = 18 },
  header_house_value = { x = 96, y = 18 },
  header_time_label = { x = 300, y = 18 },
  header_time_value = { x = 383, y = 18 },
  market_title = { x = 103, y = 92 },
  warehouse_title = { x = 343, y = 92 },
  column_y = 120,
  market_goods = { x = 27, y = 120 },
  market_price = { x = 113, y = 120 },
  warehouse_goods = { x = 232, y = 120 },
  warehouse_price = { x = 307, y = 120 },
  warehouse_quantity = { x = 387, y = 120 },
  market_price_box = { x = 100, y = 147, w = 69, h = 40 },
  warehouse_price_box = { x = 305, y = 147, w = 69, h = 40 },
  warehouse_quantity_box = { x = 375, y = 147, w = 69, h = 40 },
  slot_step = 40,
  slot_text_y_offset = 8,
  status_cash_label = { x = 13, y = 360 },
  status_cash_value = { x = 92, y = 360 },
  status_health_label = { x = 288, y = 360 },
  status_health_value = { x = 367, y = 360 },
  status_deposit_label = { x = 13, y = 408 },
  status_deposit_value = { x = 92, y = 408 },
  status_reputation_label = { x = 288, y = 408 },
  status_reputation_value = { x = 367, y = 408 },
}

-- Resolved from the original 360x600 Android activities, then scaled
-- component-wise by 4/3. android-activity-layout.golden.json preserves the
-- source XML hashes and raw constraints used to derive these rectangles.
Layout.ACTIVITIES = {
  story = {
    text = { x = 40, y = 67, w = 400, h = 147 },
    continue = { x = 327, y = 227, w = 100, h = 51 },
    start = { x = 107, y = 227, w = 267, h = 51 },
  },
  help = {
    leave = { x = 11, y = 740, w = 133, h = 60 },
    next = { x = 336, y = 740, w = 133, h = 60 },
    highlights = {
      { x = 0, y = 0, w = 480, h = 60 },
      { x = 0, y = 60, w = 205, h = 291 },
      { x = 205, y = 60, w = 275, h = 291 },
      { x = 0, y = 351, w = 480, h = 92 },
      { x = 0, y = 633, w = 480, h = 60 },
      { x = 0, y = 687, w = 120, h = 60 },
      { x = 120, y = 687, w = 120, h = 60 },
      { x = 240, y = 687, w = 120, h = 60 },
      { x = 360, y = 687, w = 120, h = 60 },
    },
    explanation = { x = 40, y = 460, w = 400, h = 160, lineHeight = 24 },
  },
  houses = {
    head = { x = 0, y = 0, w = 480, h = 267 },
    title = { x = 240, y = 13 },
    money = { x = 13, y = 63 },
    viewport = { x = 0, y = 96, w = 480, h = 623 },
    visibleCount = 2,
    rows = {
      { x = 0, y = 96, w = 480, h = 217 },
      { x = 0, y = 313, w = 480, h = 217 },
    },
    rowFields = {
      image = { x = 5, y = 3, w = 253, h = 212 },
      selection = { x = 264, y = 0, w = 163, h = 53 },
      name = { x = 264, y = 13, w = 163, h = 32 },
      price = { x = 264, y = 53, w = 211, h = 32 },
      purchased = { x = 427, y = 53, w = 48, h = 32 },
      description = { x = 264, y = 99, w = 211, h = 104 },
    },
    buy = { x = 67, y = 745, w = 67, h = 39 },
    leave = { x = 347, y = 745, w = 67, h = 39 },
  },
  records = {
    head = { x = 0, y = 0, w = 480, h = 267 },
    title = { x = 240, y = 13 },
    columnsY = 63,
    columnWidths = { 184, 184, 112 },
    rows = {
      { x = 0, y = 88, w = 480, h = 59 },
      { x = 0, y = 147, w = 480, h = 59 },
      { x = 0, y = 205, w = 480, h = 59 },
      { x = 0, y = 264, w = 480, h = 59 },
      { x = 0, y = 323, w = 480, h = 59 },
      { x = 0, y = 381, w = 480, h = 59 },
      { x = 0, y = 440, w = 480, h = 59 },
      { x = 0, y = 499, w = 480, h = 59 },
      { x = 0, y = 557, w = 480, h = 59 },
      { x = 0, y = 616, w = 480, h = 59 },
    },
    leave = { x = 207, y = 745, w = 67, h = 39 },
  },
}

-- 设备字体只有 24px，用加高描边按钮占满行情区空白；顶行仍锚在 XML 的 147。
-- 状态栏绘制在 二手市场 上方 8px（y=508），五行均分 147..500。
Layout.GOODS_SLOTS = {
  first_y = 147,
  w = 150,
  h = 70,
  step = 70,
  art_w = 135,
  art_h = 54,
  sell_x = 232,
}

-- 底图旧竖线在 x≈200；新线在价格右缘 225 与仓库按钮 232 之间晃动。
Layout.COLUMN_DIVIDER = {
  x = 228,
  y = 92,
  bottom = 508,
  erase = { x = 197, y = 90, w = 8, h = 365 },
}

Layout.GOODS_LIST = {
  market_goods = { x = 48, y = 120 },
  market_price = { x = 164, y = 120 },
  warehouse_goods = { x = 260, y = 120 },
  warehouse_price = { x = 358, y = 120 },
  warehouse_quantity = { x = 430, y = 120 },
  market_price_box = { x = 150, y = 147, w = 75, h = 60 },
  warehouse_price_box = { x = 347, y = 147, w = 75, h = 60 },
  warehouse_quantity_box = { x = 450, y = 147, w = 30, h = 60 },
}

local main_actions = {}

for index = 1, 5 do
  main_actions[#main_actions + 1] = action(
    "buy_" .. index,
    Layout.MAIN.market.x,
    Layout.GOODS_SLOTS.first_y + (index - 1) * Layout.GOODS_SLOTS.step,
    Layout.GOODS_SLOTS.w,
    Layout.GOODS_SLOTS.h,
    "买入"
  )
end

for index = 1, 5 do
  main_actions[#main_actions + 1] = action(
    "sell_" .. index,
    Layout.GOODS_SLOTS.sell_x,
    Layout.GOODS_SLOTS.first_y + (index - 1) * Layout.GOODS_SLOTS.step,
    Layout.GOODS_SLOTS.w,
    Layout.GOODS_SLOTS.h,
    "卖出"
  )
end

-- XML paints lbtnline1, then lbtnline2, then lbtnline3. The touch dispatcher
-- selects the first hit, so overlapping rows are stored in reverse paint order:
-- markets above services, and services above footer actions.
main_actions[#main_actions + 1] = action("market1", 13, 607, 133, 60, "二手市场")
main_actions[#main_actions + 1] = action("market2", 173, 607, 133, 60, "农贸市场")
main_actions[#main_actions + 1] = action("market3", 333, 607, 133, 60, "批发市场")
main_actions[#main_actions + 1] = action("bank", 9, 660, 100, 60, "银行")
main_actions[#main_actions + 1] = action("hospital", 129, 660, 100, 60, "医院")
main_actions[#main_actions + 1] = action("houses", 249, 660, 100, 60, "售楼部")
main_actions[#main_actions + 1] = action("agency", 369, 660, 100, 60, "中介")
main_actions[#main_actions + 1] = action("help", 13, 713, 133, 60, "帮助")
main_actions[#main_actions + 1] = action("start_game", 173, 713, 133, 60, "开始游戏")
main_actions[#main_actions + 1] = action("records", 333, 713, 133, 60, "历程表")

Layout.MAIN_ACTIONS = copy_actions(main_actions)

function Layout.actions(saved)
  local screen = saved.screen
  if screen == "main" then
    local out = copy_actions(main_actions)
    local playing = saved.game ~= nil and saved.game.status == "playing"
    local inventory_count = playing and #saved.game.inventory or 0
    for _, item in ipairs(out) do
      local buy_index = tonumber(string.match(item.id, "^buy_(%d+)$"))
      local sell_index = tonumber(string.match(item.id, "^sell_(%d+)$"))
      local market_index = tonumber(string.match(item.id, "^market(%d+)$"))
      if buy_index then
        item.disabled = not playing
      elseif sell_index then
        item.disabled = not playing or sell_index > inventory_count
      elseif market_index then
        item.disabled = not playing or market_index == saved.current_market
      elseif item.id == "bank" or item.id == "hospital"
          or item.id == "houses" or item.id == "agency" then
        item.disabled = not playing
      elseif item.id == "start_game" then
        item.label = playing and "结束游戏" or "开始游戏"
      end
    end
    return out
  elseif screen == "story" then
    if (saved.story_step or 1) >= 5 then
      local rect = Layout.ACTIVITIES.story.start
      return { action("finish_story", rect.x, rect.y, rect.w, rect.h, "开始挑战") }
    end
    local rect = Layout.ACTIVITIES.story.continue
    return { action("continue_story", rect.x, rect.y, rect.w, rect.h, "继续") }
  elseif screen == "houses" then
    local page = Layout.ACTIVITIES.houses
    -- XTApp addition: original Android only had footer 离开, which is invisible
    -- on the 1bpp black tail. Keep that hit target and expose a header 返回.
    local back = { x = 12, y = 8, w = 80, h = 36 }
    return {
      action("house_buy", page.buy.x, page.buy.y, page.buy.w, page.buy.h, "购买"),
      action("return_main", page.leave.x, page.leave.y, page.leave.w, page.leave.h, "离开"),
      action("return_main", back.x, back.y, back.w, back.h, "返回"),
    }
  elseif screen == "records" then
    -- Same as 售楼部: footer 离开 sits on the 1bpp black tail and disappears.
    local rect = Layout.ACTIVITIES.records.leave
    local back = { x = 12, y = 8, w = 80, h = 36 }
    return {
      action("return_main", rect.x, rect.y, rect.w, rect.h, "离开"),
      action("return_main", back.x, back.y, back.w, back.h, "返回"),
    }
  elseif screen == "help" then
    local page = Layout.ACTIVITIES.help
    if (saved.help_step or 1) < 9 then
      return {
        action("help_next", page.next.x, page.next.y, page.next.w, page.next.h, "下一步"),
        action("return_main", page.leave.x, page.leave.y, page.leave.w, page.leave.h, "离开"),
      }
    end
    return {
      action("return_main", page.leave.x, page.leave.y, page.leave.w, page.leave.h, "离开"),
    }
  end
  return {}
end

function Layout.house_rows(saved)
  local page = Layout.ACTIVITIES.houses
  local first = math.max(1, math.min(9, saved.house_scroll or 1))
  local rows = {}
  for slot, rect in ipairs(page.rows) do
    rows[slot] = {
      id = "house_row_" .. tostring(first + slot - 1),
      house_index = first + slot - 1,
      x = rect.x, y = rect.y, w = rect.w, h = rect.h,
    }
  end
  return rows
end

-- The original trade dialog is 127px high.  Trade shortcuts are an XTApp
-- addition, so reserve one complete row inside each trade dialog instead of
-- painting that row over the main-screen footer.
local TRADE_CONTENT_HEIGHT = 127
local QTY_ROW_HEIGHT = 36
local SERVICE_FRAME = { x = 27, y = 400, w = 427, h = 220 }
local SERVICE_BTN = { w = 100, h = 52 }
local QTY_BTN = { w = 48, h = 52 }
local SERVICE_BTN_Y = 548
local AGENCY_BTN_Y = 563

local overlay_frames = {
  new_game = { x = 27, y = 455, w = 427, h = 287 },
  quit_game = { x = 50, y = 455, w = 380, h = 180 },
  buy_goods = {
    x = 27, y = 455, w = 427,
    h = TRADE_CONTENT_HEIGHT + QTY_ROW_HEIGHT,
  },
  sell_goods = {
    x = 27, y = 455, w = 427,
    h = TRADE_CONTENT_HEIGHT + QTY_ROW_HEIGHT,
  },
  bank = { x = SERVICE_FRAME.x, y = SERVICE_FRAME.y, w = SERVICE_FRAME.w, h = SERVICE_FRAME.h },
  hospital = { x = SERVICE_FRAME.x, y = SERVICE_FRAME.y, w = SERVICE_FRAME.w, h = SERVICE_FRAME.h },
  agency = { x = SERVICE_FRAME.x, y = SERVICE_FRAME.y, w = SERVICE_FRAME.w, h = SERVICE_FRAME.h },
  price_note = { x = 125, y = 250, w = 231, h = 300 },
  life_note = { x = 127, y = 250, w = 227, h = 300 },
  sick_blackout = { x = 127, y = 250, w = 227, h = 300 },
  sick_dead = { x = 127, y = 250, w = 227, h = 300 },
  time_up = { x = 127, y = 250, w = 227, h = 300 },
  sell_reputation = { x = 127, y = 250, w = 227, h = 300 },
  no_money = { x = 50, y = 333, w = 380, h = 133 },
  status = { x = 50, y = 333, w = 380, h = 133 },
  buy_succ = { x = 47, y = 160, w = 387, h = 480 },
}

local modal_visuals = {
  new_game = {
    title = { x = 40, y = 468 },
    cash = { x = 195, y = 568, w = 97, h = 29 },
    message = { centerX = 240, y = 577 },
  },
  quit_game = {
    title = { x = 63, y = 468 },
    message = { centerX = 240, y = 532 },
  },
  buy_goods = {
    title = { x = 40, y = 468 },
    goods = { x = 69, y = 491, w = 100, h = 40 },
    input = { x = 176, y = 491, w = 123, h = 40 },
    guidance = { centerX = 240, bottom = 561, w = 395, lineHeight = 21 },
    fieldTextOffsetY = 8,
  },
  sell_goods = {
    title = { x = 40, y = 468 },
    goods = { x = 69, y = 491, w = 100, h = 40 },
    input = { x = 176, y = 491, w = 123, h = 40 },
    guidance = { centerX = 240, bottom = 561, w = 395, lineHeight = 21 },
    fieldTextOffsetY = 8,
  },
  bank = {
    title = { x = 40, y = 413 },
    message = { centerX = 240, y = 460 },
  },
  hospital = {
    title = { x = 40, y = 413 },
    text = { x = 144, y = 418, w = 280, lineHeight = 24 },
  },
  agency = {
    title = { x = 40, y = 413 },
    content_mask = { x = 118, y = 413, w = 336, h = 79 },
    prefix = { x = 118, y = 428, w = 48, h = 52 },
    input = { x = 214, y = 428, w = 56, h = 52 },
    suffix = { x = 318, y = 428, w = 136, h = 52 },
    note = { x = 27, y = 492, w = 427, lineHeight = 21 },
    fieldTextOffsetY = 14,
  },
  price_note = {
    text = { x = 147, y = 310, w = 187, lineHeight = 24 },
  },
  life_note = {
    text = { x = 161, y = 322, w = 173, lineHeight = 24 },
  },
  sick_blackout = {
    text = { x = 161, y = 322, w = 173, lineHeight = 24 },
  },
  sick_dead = {
    text = { x = 161, y = 322, w = 173, lineHeight = 24 },
  },
  time_up = {
    text = { x = 161, y = 322, w = 173, h = 216, lineHeight = 21 },
  },
  sell_reputation = {
    text = { x = 161, y = 322, w = 173, lineHeight = 24 },
  },
  no_money = {
    text = { x = 78, y = 349, w = 324, h = 61, lineHeight = 24 },
  },
  status = {
    text = { x = 78, y = 349, w = 324, h = 61, lineHeight = 24 },
  },
  buy_succ = {
    image = { x = 67, y = 181, w = 347, h = 289 },
    text = { x = 71, y = 477, w = 337, h = 84, lineHeight = 24 },
  },
}

local function copy_rect(rect)
  if rect == nil then return nil end
  return { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
end

function Layout.overlay_frame(kind)
  return copy_rect(overlay_frames[kind])
end

function Layout.modal_visual(kind)
  local source = modal_visuals[kind]
  if source == nil then return nil end
  local out = {}
  for name, item in pairs(source) do
    if type(item) == "table" then
      out[name] = {}
      for key, value in pairs(item) do out[name][key] = value end
    else
      out[name] = item
    end
  end
  return out
end

local overlay_action_sets = {
  new_game = {
    action("confirm_new_game", 132, 676, 67, 39, "开始"),
    action("close_overlay", 281, 676, 67, 39, "取消"),
  },
  quit_game = {
    action("confirm_quit_game", 132, 569, 67, 39, "结束"),
    action("close_overlay", 281, 569, 67, 39, "取消"),
  },
  buy_goods = {
    action("confirm_buy", 320, 491, 67, 39, "确定"),
    action("close_overlay", 403, 476, 33, 33, "关闭"),
    action("quantity_minus", 176, 491, QTY_BTN.w, QTY_BTN.h, "－"),
    action("quantity_plus", 251, 491, QTY_BTN.w, QTY_BTN.h, "＋"),
  },
  sell_goods = {
    action("confirm_sell", 320, 491, 67, 39, "确定"),
    action("close_overlay", 403, 476, 33, 33, "关闭"),
    action("quantity_minus", 176, 491, QTY_BTN.w, QTY_BTN.h, "－"),
    action("quantity_plus", 251, 491, QTY_BTN.w, QTY_BTN.h, "＋"),
  },
  bank = {
    action("deposit_all", 74, SERVICE_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "存钱"),
    action("withdraw_all", 190, SERVICE_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "取钱"),
    action("close_overlay", 306, SERVICE_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "离开"),
  },
  hospital = {
    action("treat", 128, SERVICE_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "看病"),
    action("close_overlay", 252, SERVICE_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "离开"),
  },
  agency = {
    action("expand", 128, AGENCY_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "成交"),
    action("close_overlay", 252, AGENCY_BTN_Y, SERVICE_BTN.w, SERVICE_BTN.h, "离开"),
    action("quantity_minus", 166, 428, QTY_BTN.w, QTY_BTN.h, "－"),
    action("quantity_plus", 270, 428, QTY_BTN.w, QTY_BTN.h, "＋"),
  },
}

local passive_cards = {
  price_note = true, life_note = true, sick_blackout = true,
  sick_dead = true, time_up = true, sell_reputation = true,
}

local feedback_actions = {
  no_money = { action("confirm_overlay", 207, 408, 67, 39, "确认") },
  status = { action("confirm_overlay", 207, 408, 67, 39, "确认") },
  buy_succ = { action("confirm_overlay", 207, 575, 67, 39, "确认") },
}

local SELL_QTY_SPECS = {
  { id = "sell_qty_all", divisor = 1, min = 1 },
  { id = "sell_qty_half", divisor = 2, min = 2 },
  { id = "sell_qty_quarter", divisor = 4, min = 4 },
  { id = "sell_qty_tenth", divisor = 10, min = 11 },
}

local BUY_QTY_SPECS = {
  { id = "buy_qty_all", divisor = 1, min = 1 },
  { id = "buy_qty_half", divisor = 2, min = 2 },
  { id = "buy_qty_quarter", divisor = 4, min = 4 },
  { id = "buy_qty_tenth", divisor = 10, min = 11 },
}

local AGENCY_QTY_SPECS = {
  { id = "agency_qty_all", divisor = 1, min = 1 },
  { id = "agency_qty_half", divisor = 2, min = 2 },
  { id = "agency_qty_quarter", divisor = 4, min = 4 },
  { id = "agency_qty_tenth", divisor = 10, min = 11 },
}

local function quantity_actions(specs, frame, quantity, row_y)
  quantity = math.floor(tonumber(quantity) or 0)
  local visible = {}
  for _, spec in ipairs(specs) do
    if quantity >= spec.min then
      visible[#visible + 1] = spec
    end
  end
  local count = #visible
  if count == 0 then return {} end
  local y = row_y or (frame.y + TRADE_CONTENT_HEIGHT)
  local h = QTY_ROW_HEIGHT
  local base = math.floor(frame.w / count)
  local extra = frame.w % count
  local used = 0
  local out = {}
  for index, spec in ipairs(visible) do
    local w = base + (index <= extra and 1 or 0)
    local amount = math.max(1, math.floor(quantity / spec.divisor))
    out[index] = action(spec.id, frame.x + used, y, w, h, tostring(amount))
    used = used + w
  end
  return out
end

function Layout.sell_qty_actions(stock)
  return quantity_actions(SELL_QTY_SPECS, overlay_frames.sell_goods, stock)
end

function Layout.buy_qty_actions(maximum)
  return quantity_actions(BUY_QTY_SPECS, overlay_frames.buy_goods, maximum)
end

function Layout.agency_maximum(saved)
  local game = saved and saved.game
  if not game then return 1 end
  local funds = (tonumber(game.cash) or 0) + (tonumber(game.deposit) or 0)
  return math.max(1, math.floor(funds / 10000))
end

function Layout.agency_qty_actions(maximum)
  return quantity_actions(
    AGENCY_QTY_SPECS,
    overlay_frames.agency,
    maximum,
    overlay_frames.agency.y + TRADE_CONTENT_HEIGHT
  )
end

local function sell_stock(saved)
  local overlay = saved and saved.overlay
  local game = saved and saved.game
  if not overlay or not game or overlay.kind ~= "sell_goods" then return 0 end
  local item = game.inventory and game.inventory[overlay.index]
  return item and item.quantity or 0
end

local function buy_maximum(saved)
  local overlay = saved and saved.overlay
  local game = saved and saved.game
  if not overlay or not game or overlay.kind ~= "buy_goods" then return 0 end
  local offer = game.market and game.market[overlay.index]
  if not offer or not offer.price or offer.price <= 0 then return 0 end
  local inventory = game.inventory or {}
  local has_goods = false
  for _, item in ipairs(inventory) do
    if item and item.goods_id == offer.goods_id then
      has_goods = true
      break
    end
  end
  if #inventory >= 5 and not has_goods then return 0 end
  local by_funds = math.floor(((game.cash or 0) + (game.deposit or 0)) / offer.price)
  local by_capacity = math.max(0, (game.capacity or 0) - (game.used or 0))
  return math.max(0, math.min(by_funds, by_capacity))
end

function Layout.buy_maximum(saved)
  return buy_maximum(saved)
end

function Layout.overlay_actions(saved)
  local overlay = saved.overlay
  if type(overlay) ~= "table" or type(overlay.kind) ~= "string" then return {} end
  local source = overlay_action_sets[overlay.kind]
  if source then
    local out = copy_actions(source)
    if overlay.kind == "hospital" then
      local game = saved.game
      local cost = game and (100 - game.health) * 5000 or 0
      local disabled = game == nil or game.status ~= "playing"
        or game.health >= 100 or game.cash + game.deposit < cost
      out[1].disabled = disabled and true or nil
    elseif overlay.kind == "buy_goods" then
      for _, item in ipairs(Layout.buy_qty_actions(buy_maximum(saved))) do
        out[#out + 1] = item
      end
    elseif overlay.kind == "sell_goods" then
      for _, item in ipairs(Layout.sell_qty_actions(sell_stock(saved))) do
        out[#out + 1] = item
      end
    elseif overlay.kind == "agency" then
      for _, item in ipairs(Layout.agency_qty_actions(Layout.agency_maximum(saved))) do
        out[#out + 1] = item
      end
    end
    return out
  end
  source = feedback_actions[overlay.kind]
  if source then return copy_actions(source) end
  if passive_cards[overlay.kind] then
    local frame = overlay_frames[overlay.kind]
    return {
      action("confirm_overlay", frame.x, frame.y, frame.w, frame.h, "确认"),
    }
  end
  return {}
end

function Layout.hit(item, x, y)
  return x >= item.x and x < item.x + item.w
    and y >= item.y and y < item.y + item.h
end

return Layout
