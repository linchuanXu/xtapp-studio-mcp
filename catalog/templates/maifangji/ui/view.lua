local PkgImage = require("pkg_image")
local Economy = require("domain.economy")
local Houses = require("domain.houses")
local Layout = require("ui.layout")

local View = {}
local GOODS = Economy.goods()
local HOUSE_CATALOG = Houses.catalog()
local WHITE, BLACK = 0, 15
local GOODS_ASSETS = {
  "01", "02", "03", "04", "05", "06", "07", "08",
}
local MAIN_ACTION_ASSETS = {
  market1 = "main_market1",
  market2 = "main_market2",
  market3 = "main_market3",
  bank = "main_bank",
  hospital = "main_hospital",
  houses = "main_houses",
  agency = "main_agency",
  help = "main_help",
  start_game = "main_start",
  records = "main_records",
}
local OVERLAY_FRAME_ASSETS = {
  new_game = "new_game_bg",
  quit_game = "quit_game_bg",
  buy_goods = "trade_bg",
  sell_goods = "trade_bg",
  bank = "bank_bg",
  hospital = "hospital_bg",
  agency = "agency_bg",
  price_note = "note_price_bg",
  life_note = "note_event_bg",
  sick_blackout = "note_event_bg",
  sick_dead = "note_event_bg",
  time_up = "note_event_bg",
  sell_reputation = "note_event_bg",
  no_money = "feedback_bg",
  status = "feedback_bg",
  buy_succ = "success_bg",
}
local OVERLAY_ACTION_ASSETS = {
  confirm_new_game = "new_game_start",
  close_overlay_new_game = "modal_cancel",
  confirm_quit_game = "quit_confirm",
  close_overlay_quit_game = "modal_cancel",
  confirm_buy = "trade_buy",
  confirm_sell = "trade_sell",
  close_overlay_trade = "trade_close",
  quantity_minus = "quantity_minus",
  quantity_plus = "quantity_plus",
  deposit_all = "bank_save",
  withdraw_all = "bank_withdraw",
  close_overlay_bank = "bank_leave",
  treat = "hospital_treat",
  close_overlay_hospital = "hospital_leave",
  expand = "agency_deal",
  close_overlay_agency = "agency_leave",
  confirm_overlay = "feedback_confirm",
}

-- Firmware treats g:image as a drawing command and may return no value.  The
-- browser bridge returns a boolean for missing assets, so only an explicit
-- false can select a primitive fallback; a nil result still means the image
-- command was submitted and must not be painted over.
local function image_drawn(g, key, x, y, options)
  local result
  if options == nil then
    result = PkgImage.draw(g, key, x, y)
  else
    result = PkgImage.draw(g, key, x, y, options)
  end
  return result ~= false
end

View.STORY_PARAGRAPHS = {
  "    昨晚彻夜的游戏让我头昏脑涨， 此刻蹲在厕所的我两脚发麻， 但仍在积极地思考着人生。",
  "    来到这个城市四年了， 合租、月光的标签粘着我挥之不去， 难道这就是我的生活？ 买房的梦想就那么遥不可及？",
  "    门外合租的张XX已经捉急地在催促了， 而我却陷入了深深的思考中………",
  "    哼~ 有志者事竟成！ 我要用一年时间改变人生轨迹！ 我要完成别人做不到的事！ 等我来吧， 梦中的家！",
  "    接下去的一年时间里， 你要用身上仅有的3000块钱， 赚到几百万甚至上千万， 买到理想中的房子！ 你能完成这个挑战吗？",
}

View.HELP_EXPLANATIONS = {
  "    游戏目标： 在52周（一年）时间结束前赚到足够的钱买到房子。\n    这里显示了房价和时间， 房价可不是一成不变的， 每周都会上涨喔。",
  "    这里是市场， 点击市场中的货物可以进行购买。\n    游戏的关键就是要掌握货物价格的变化区间， 低买高卖。",
  "    这里是你的出租屋， 从市场购买的货物会存放在出租屋中。 点击货物可以卖出。\n    出租屋有容量限制， 30/100表示出租屋最多能存放100个货物， 目前还有30个空余空间。",
  "    这里显示了你的现金、存款以及健康和名声。\n    健康低于95， 你可能会暴毙街头。\n    名声太差， 售楼小姐可能会不愿意把房子卖给你。",
  "    点击这里的三个按钮， 上面市场中的货物和价格会发生变化， 同时时间也会增加一周。",
  "    把多余的现金存到银行， 可以减少损失， 同时每周都能得到利息。",
  "    在医院可以花钱看病， 减少暴毙街头的可能。",
  "    在售楼部你能买到心仪的房子。",
  "    在中介你可以花钱租用更多的出租屋空间， 让你能买进更多的货物。",
}

local HOUSE_DESCRIPTIONS = {
  "    30平米的单身公寓， 2个人住也非常温馨。",
  "    90年代建造的80平米三房旧楼， 虽然是老房子， 但非常实用。",
  "    环境优雅的新建高档小区， 是城市白领的聚集地。",
  "    180平米的跃层楼顶大房， 非常地宽敞好用。",
  "    280平米的三层排屋， 还带一个小院， 三代人同住也非常舒适。",
  "    风景优美、 位置稀缺， 属于城市精英的一线江景豪宅。",
  "    位于核心城区， 设计奢华、 闹中取静的高端豪华大宅。",
  "    森林环绕、 环境雅致， 带泳池和花园的超级别墅。",
  "    建造在小岛上的度假别墅， 属于你的私人小岛和私家海滩。",
  "    为地球毁灭而准备的， 建造在火星上的移民基地。",
}

local FONT_ADVANCE = {
  [32]=7, [33]=5, [34]=10, [35]=17, [36]=15, [37]=21, [38]=18, [39]=5,
  [40]=9, [41]=9, [42]=10, [43]=15, [44]=7, [45]=9, [46]=5, [47]=14,
  [48]=15, [49]=12, [50]=13, [51]=14, [52]=15, [53]=14, [54]=14, [55]=13,
  [56]=14, [57]=14, [58]=5, [59]=7, [60]=13, [61]=13, [62]=13, [63]=13,
  [64]=23, [65]=17, [66]=16, [67]=16, [68]=18, [69]=15, [70]=14, [71]=18,
  [72]=18, [73]=13, [74]=15, [75]=17, [76]=14, [77]=20, [78]=19, [79]=19,
  [80]=15, [81]=19, [82]=17, [83]=15, [84]=15, [85]=18, [86]=17, [87]=24,
  [88]=17, [89]=16, [90]=15, [91]=10, [92]=14, [93]=10, [94]=14, [95]=16,
  [96]=12, [97]=16, [98]=16, [99]=13, [100]=16, [101]=14, [102]=10, [103]=16,
  [104]=15, [105]=8, [106]=7, [107]=14, [108]=7, [109]=23, [110]=15, [111]=15,
  [112]=16, [113]=16, [114]=10, [115]=12, [116]=9, [117]=15, [118]=14, [119]=19,
  [120]=14, [121]=14, [122]=12, [123]=10, [124]=7, [125]=10, [126]=13,
}

function View.text_width(value)
  local width, index, text = 0, 1, tostring(value or "")
  while index <= #text do
    local byte = string.byte(text, index)
    if byte < 128 then
      width = width + (FONT_ADVANCE[byte] or 24)
      index = index + 1
    elseif byte == 0xC2 and string.byte(text, index + 1) == 0xB7 then
      width = width + 5
      index = index + 2
    else
      width = width + 24
      index = index + (byte < 224 and 2 or (byte < 240 and 3 or 4))
    end
  end
  return width
end

function View.fit_text(value, maximum)
  local text = tostring(value or "")
  if View.text_width(text) <= maximum then return text end
  local ellipsis, width, index, last = "…", 0, 1, 0
  while index <= #text do
    local byte = string.byte(text, index)
    local length = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
    local chunk = string.sub(text, index, index + length - 1)
    local next_width = width + View.text_width(chunk)
    if next_width + View.text_width(ellipsis) > maximum then break end
    width, last, index = next_width, index + length - 1, index + length
  end
  if last == 0 then return "" end
  return string.sub(text, 1, last) .. ellipsis
end

function View.format_record_time(value)
  local text = tostring(value or "")
  local month, day, hour, minute = string.match(text, "^%d%d%d%d%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d)")
  if month then return month .. "-" .. day .. " " .. hour .. ":" .. minute end
  return View.fit_text(text, 145)
end

local function house_asset_key(prefix, index)
  if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > 10 then return nil end
  return string.format(prefix .. "%02d", index)
end

function View.house_asset_key(index)
  return house_asset_key("house_", index)
end

function View.house_list_asset_key(index)
  return house_asset_key("house_list_", index)
end

function View.house_result_asset_key(index)
  return house_asset_key("house_result_", index)
end

local function keep_hand_art(base)
  return string.match(base, "^main_")
    or string.match(base, "^goods_")
    or string.match(base, "^bank_")
    or string.match(base, "^hospital_")
    or string.match(base, "^agency_")
    or string.match(base, "^houses_")
    or base == "trade_buy"
    or base == "trade_sell"
end

local function state_asset_key(base, focused, disabled)
  if not base then return nil end
  -- 按下/禁用 XIC 在 1bpp 上会糊成黑块，主界面、货物、买卖确定和
  -- 银行/医院/中介/售楼部按钮仍用手绘正常稿。
  if focused and not keep_hand_art(base) then return base .. "_p" end
  if disabled and not keep_hand_art(base) then return base .. "_d" end
  return base
end

local LIST_DIGIT_SIZE = 16

local function center(g, x, y, text, color, size)
  local width = View.text_width(text)
  if size then
    width = math.max(1, math.floor(width * size / 24 + 0.5))
  end
  g:text(x - math.floor(width / 2), y, text, { color = color or BLACK, size = size })
end

local function money(value)
  value = math.floor(tonumber(value) or 0)
  -- 十万元以下显示精确元数，避免 12600 被四舍五入成「1.3万」后看起来买得起 12635 的货。
  -- 更大金额按向下截断的一位小数缩写，绝不向上夸大。
  if value >= 100000000 then
    return string.format("%.1f亿", math.floor(value / 10000000) / 10)
  end
  if value >= 100000 then
    return string.format("%.1f万", math.floor(value / 1000) / 10)
  end
  return tostring(value)
end

-- 行情/买入价最多五位整数；不用「万」缩写，也不做省略裁剪。
local function list_price(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then value = 0 end
  return tostring(value)
end

local function header(g, right)
  g:clear(WHITE)
  g:rect(14, 14, 452, 54,{fill=true,color=BLACK})
  g:text(28, 30, "买房记", { color = WHITE })
  g:text(326, 30, right or "页面", { color = WHITE })
  g:line(14, 76, 466, 76,{color=BLACK})
  g:line(14, 81, 466, 81,{color=BLACK})
end

local function section_title(g, title, subtitle)
  g:text(24, 98, title, { color = BLACK })
  if subtitle then g:text(24, 124, subtitle, { color = BLACK }) end
end

local function button(g, item, focused)
  g:rect(item.x, item.y, item.w, item.h,{fill=(focused) and true or false,color=BLACK})
  center(g, item.x + item.w / 2, item.y + math.floor((item.h - 20) / 2), item.label, focused and WHITE or BLACK)
  if focused then
    g:circle(item.x + 15, item.y + item.h / 2, 7,{color=WHITE})
  end
end

local function draw_actions(g, saved, skip_prefix)
  for index, item in ipairs(Layout.actions(saved)) do
    if not skip_prefix or not string.match(item.id, skip_prefix) then
      button(g, item, index == saved.focus)
    end
  end
end

local draw_wrapped_text
local draw_control

local function draw_houses(g, saved)
  local page = Layout.ACTIVITIES.houses
  g:clear(WHITE)
  g:rect(page.head.x, page.head.y, page.head.w, page.head.h,{fill=true,color=BLACK})
  if not image_drawn(g, "houses_head", page.viewport.x, page.viewport.y) then
    g:line(0, page.viewport.y, 480, page.viewport.y,{color=WHITE})
  end
  if not image_drawn(g, "houses_tail", 0, 718) then
    g:line(0, 718, 480, 718,{color=BLACK})
  end
  center(g, page.title.x, page.title.y, "售楼部", WHITE)
  g:text(
    page.money.x,
    page.money.y,
    "可用资金：" .. tostring(saved.game.cash + saved.game.deposit),
    { color = WHITE }
  )
  local fields = page.rowFields
  for _, row in ipairs(Layout.house_rows(saved)) do
    local house_index = row.house_index
    local house = HOUSE_CATALOG[house_index]
    local record = saved.records.houses[house_index]
    local selected = house_index == saved.game.selected_house
    local image = {
      x = row.x + fields.image.x, y = row.y + fields.image.y,
      w = fields.image.w, h = fields.image.h,
    }
    g:rect(row.x, row.y, row.w, row.h,{fill=true,color=WHITE})
    g:rect(row.x, row.y, row.w, row.h,{color=BLACK})
    if not image_drawn(
      g,
      View.house_list_asset_key(house_index),
      image.x,
      image.y
    ) then
      g:rect(image.x, image.y, image.w, image.h,{color=BLACK})
    end
    local selection = {
      x = row.x + fields.selection.x, y = row.y + fields.selection.y,
      w = fields.selection.w, h = fields.selection.h,
    }
    if selected and not image_drawn(g, "houses_select1", selection.x, selection.y) then
      g:rect(selection.x, selection.y, selection.w, selection.h,{fill=true,color=BLACK})
    end
    center(
      g,
      row.x + fields.name.x + fields.name.w / 2,
      row.y + fields.name.y,
      house.name,
      BLACK
    )
    g:text(
      row.x + fields.price.x,
      row.y + fields.price.y,
      "售价：" .. money(saved.game.house_prices[house_index]),
      { color = BLACK }
    )
    if record.success_count > 0 then
      g:text(
        row.x + fields.purchased.x,
        row.y + fields.purchased.y,
        "已购",
        { color = BLACK }
      )
    end
    draw_wrapped_text(
      g,
      row.x + fields.description.x,
      row.y + fields.description.y,
      HOUSE_DESCRIPTIONS[house_index],
      fields.description.w,
      18,
      math.floor(fields.description.h / 18)
    )
  end
  for index, item in ipairs(Layout.actions(saved)) do
    if item.label == "返回" then
      g:rect(item.x, item.y, item.w, item.h,{color=WHITE})
      center(
        g,
        item.x + item.w / 2,
        item.y + math.max(2, math.floor((item.h - 24) / 2)),
        item.label,
        WHITE
      )
    else
      g:rect(item.x, item.y, item.w, item.h,{fill=true,color=WHITE})
      local base = item.id == "house_buy" and "houses_buy" or "houses_leave"
      draw_control(g, item, index == saved.focus, item.label, base)
    end
  end
end

local function draw_records(g, saved)
  local page = Layout.ACTIVITIES.records
  g:clear(WHITE)
  g:rect(page.head.x, page.head.y, page.head.w, page.head.h,{fill=true,color=BLACK})
  if not image_drawn(g, "records_head", page.rows[1].x, page.rows[1].y) then
    g:line(0, page.rows[1].y, 480, page.rows[1].y,{color=WHITE})
  end
  if not image_drawn(g, "records_tail", 0, 718) then
    g:line(0, 718, 480, 718,{color=BLACK})
  end
  center(g, page.title.x, page.title.y, "我的买房记录", WHITE)
  local first_center = page.columnWidths[1] / 2
  local second_center = page.columnWidths[1] + page.columnWidths[2] / 2
  local third_center = page.columnWidths[1] + page.columnWidths[2] + page.columnWidths[3] / 2
  center(g, first_center, page.columnsY, "房型", WHITE)
  center(g, second_center, page.columnsY, "首次购买时间", WHITE)
  center(g, third_center, page.columnsY, "成功次数", WHITE)
  local first_row, last_row = page.rows[1], page.rows[#page.rows]
  g:rect(
    first_row.x,
    first_row.y,
    first_row.w,
    last_row.y + last_row.h - first_row.y,{fill=true,color=WHITE})
  for index, rect in ipairs(page.rows) do
    local row = saved.records.houses[index]
    local y = rect.y
    if not image_drawn(g, "records_row" .. tostring(((index - 1) % 3) + 1), rect.x, rect.y) then
      g:rect(rect.x, rect.y, rect.w, rect.h,{fill=true,color=WHITE})
    end
    local name = View.fit_text(HOUSE_CATALOG[index].name, page.columnWidths[1] - 8)
    local first = View.format_record_time(row.first_success_at)
    local count = View.fit_text(tostring(row.success_count), page.columnWidths[3] - 8)
    center(g, first_center, y + 16, name, BLACK)
    center(g, second_center, y + 16, first, BLACK)
    center(g, third_center, y + 16, count, BLACK)
    g:line(rect.x, y + rect.h - 1, rect.x + rect.w, y + rect.h - 1,{color=BLACK})
  end
  for index, item in ipairs(Layout.actions(saved)) do
    if item.label == "返回" then
      g:rect(item.x, item.y, item.w, item.h,{color=WHITE})
      center(
        g,
        item.x + item.w / 2,
        item.y + math.max(2, math.floor((item.h - 24) / 2)),
        item.label,
        WHITE
      )
    else
      draw_control(g, item, index == saved.focus, item.label, "records_leave")
    end
  end
end

-- Task 5 can replace these primitive surfaces with XIC assets without moving
-- callers or changing any layout rectangle.
local function primitive_surface(g, rect)
  g:rect(rect.x, rect.y, rect.w, rect.h,{fill=true,color=WHITE})
  g:rect(rect.x, rect.y, rect.w, rect.h,{color=BLACK})
end

local function needs_label_overlay(base, disabled, focused)
  if not base then return false end
  if base == "story_continue" or base == "story_start" or base == "feedback_confirm"
      or base == "new_game_start" or base == "quit_confirm" then
    return true
  end
  return false
end

local function overlay_control_label(g, item, label, color, inset)
  center(
    g,
    item.x + item.w / 2,
    item.y + math.max(2, math.floor((item.h - 24) / 2)),
    View.fit_text(label, math.max(0, item.w - (inset or 0))),
    color
  )
end

draw_control = function(g, item, focused, label, asset_base)
  local active_focus = focused and not item.disabled
  local key = state_asset_key(asset_base, active_focus, item.disabled)
  -- 银行/医院/中介主按钮热区已放大；买入卖出确定必须沿用 67×39 手绘稿，避免素框压住加减。
  local enlarge_overlay_button = asset_base and (
    string.match(asset_base, "^bank_")
    or string.match(asset_base, "^hospital_")
    or string.match(asset_base, "^agency_")
  )
  if key and not enlarge_overlay_button and image_drawn(g, key, item.x, item.y) then
    if label and label ~= "" and needs_label_overlay(asset_base, item.disabled, active_focus) then
      overlay_control_label(g, item, label, WHITE, 8)
    end
    return true
  end
  g:rect(item.x, item.y, item.w, item.h,{fill=(active_focus) and true or false,color=BLACK})
  if item.disabled then
    g:line(item.x + 4, item.y + item.h - 4, item.x + item.w - 4, item.y + 4,{color=BLACK})
  end
  if label and label ~= "" then
    local text = View.fit_text(label, math.max(0, item.w - 6))
    center(
      g,
      item.x + item.w / 2,
      item.y + math.max(2, math.floor((item.h - 24) / 2)),
      text,
      active_focus and WHITE or BLACK
    )
  end
  return false
end

local function draw_main_header(g, game)
  local visual = Layout.MAIN_VISUAL
  local selected = game and game.selected_house or 1
  local price = game and game.house_prices and game.house_prices[selected]
  local header_rect = visual.header
  g:rect(header_rect.x, header_rect.y, header_rect.w, header_rect.h,{fill=true,color=BLACK})
  g:text(visual.header_house_label.x, visual.header_house_label.y, "房价：", { color = WHITE })
  g:text(visual.header_house_value.x, visual.header_house_value.y, price and money(price) or "—", { color = WHITE })
  g:text(visual.header_time_label.x, visual.header_time_label.y, "时间：", { color = WHITE })
  g:text(
    visual.header_time_value.x,
    visual.header_time_value.y,
    game and (tostring(game.week) .. "/52周") or "0/52周",
    { color = WHITE }
  )
end

local function draw_main_columns(g, saved, actions)
  local visual = Layout.MAIN_VISUAL
  local game = saved.game
  center(g, visual.market_title.x, visual.market_title.y, "市场", BLACK)
  local used = game and game.used or 0
  local capacity = game and game.capacity or 100
  center(
    g,
    visual.warehouse_title.x,
    visual.warehouse_title.y,
    "出租屋（" .. tostring(used) .. "/" .. tostring(capacity) .. "）",
    BLACK
  )
  local list = Layout.GOODS_LIST
  g:text(list.market_goods.x, list.market_goods.y, "货物", { color = BLACK })
  g:text(list.market_price.x, list.market_price.y, "价格", { color = BLACK })
  g:text(list.warehouse_goods.x, list.warehouse_goods.y, "货物", { color = BLACK })
  g:text(list.warehouse_price.x, list.warehouse_price.y, "买入价", { color = BLACK })
  g:text(list.warehouse_quantity.x, list.warehouse_quantity.y, "数量", { color = BLACK })

  for index = 1, 5 do
    local item = actions[index]
    local offer = game and game.market and game.market[index]
    local name = offer and GOODS[offer.goods_id] and GOODS[offer.goods_id].name or ""
    local base = offer and "goods_lm_" .. GOODS_ASSETS[offer.goods_id] or nil
    draw_control(g, item, saved.overlay == nil and saved.focus == index, name, base)
    if offer then
      local box = list.market_price_box
      center(
        g,
        box.x + box.w / 2,
        item.y + math.max(2, math.floor((item.h - 24) / 2)),
        list_price(offer.price),
        BLACK,
        LIST_DIGIT_SIZE
      )
    end
  end

  for index = 1, 5 do
    local action_index = index + 5
    local item = actions[action_index]
    local slot = game and game.inventory and game.inventory[index]
    local name = slot and GOODS[slot.goods_id] and GOODS[slot.goods_id].name or ""
    if slot then
      draw_control(
        g,
        item,
        saved.overlay == nil and saved.focus == action_index,
        name,
        "goods_lw_" .. GOODS_ASSETS[slot.goods_id]
      )
      local price_box = list.warehouse_price_box
      local quantity_box = list.warehouse_quantity_box
      local text_y = item.y + math.max(2, math.floor((item.h - 24) / 2))
      center(
        g,
        price_box.x + price_box.w / 2,
        text_y,
        list_price(slot.average_cost),
        BLACK,
        LIST_DIGIT_SIZE
      )
      center(
        g,
        quantity_box.x + quantity_box.w / 2,
        text_y,
        tostring(slot.quantity),
        BLACK,
        LIST_DIGIT_SIZE
      )
    elseif not game then
      draw_control(g, item, false, "")
    end
  end
end

local function draw_column_divider(g)
  local spec = Layout.COLUMN_DIVIDER
  local erase = spec.erase
  g:rect(erase.x, erase.y, erase.w, erase.h,{fill=true,color=WHITE})
  -- 从雨棚旧线口斜接到新列缝，再沿缝左右晃动，避免一根机械直线。
  g:line(201, spec.y, spec.x, spec.y + 14,{color=BLACK})
  local left = 225
  local right = spec.x + 3
  local wobble = { -3, -1, 2, 3, 0, -2, 1, 3, -3, -1, 2, 0, -2, 3, 1, -3, 0, 2, -1 }
  local steps = { 11, 8, 15, 10, 13, 9, 16, 12 }
  local x = spec.x
  local y = spec.y + 14
  local i = 1
  while y < spec.bottom do
    local nx = spec.x + wobble[((i - 1) % #wobble) + 1]
    if nx < left then nx = left end
    if nx > right then nx = right end
    local ny = y + steps[((i - 1) % #steps) + 1]
    if ny > spec.bottom then ny = spec.bottom end
    g:line(x, y, nx, ny,{color=BLACK})
    x = nx
    y = ny
    i = i + 1
  end
end

local function draw_status_divider(g, y)
  local x = 8
  while x < 472 do
    g:rect(x, y, 10, 2,{fill=true,color=WHITE})
    x = x + 16
  end
end

local function draw_main_status(g, game)
  local visual = Layout.MAIN_VISUAL
  local cash = game and game.cash or 0
  local health = game and game.health or 0
  local deposit = game and game.deposit or 0
  local reputation = game and game.reputation or 0
  local cash_rect = Layout.MAIN.status_cash
  local deposit_rect = Layout.MAIN.status_deposit
  local band_h = deposit_rect.y + deposit_rect.h - cash_rect.y
  local shift = 607 - 8 - band_h - cash_rect.y
  local top = cash_rect.y + shift
  if not image_drawn(g, "status_1_bg", 0, top) then
    g:rect(cash_rect.x, top, cash_rect.w, cash_rect.h,{fill=true,color=BLACK})
  end
  if not image_drawn(g, "status_2_bg", 0, deposit_rect.y + shift) then
    g:rect(deposit_rect.x, deposit_rect.y + shift, deposit_rect.w, deposit_rect.h,{fill=true,color=BLACK})
  end
  g:rect(cash_rect.x, top, cash_rect.w, band_h,{fill=true,color=BLACK})
  draw_status_divider(g, deposit_rect.y + shift - 3)
  g:text(visual.status_cash_label.x, visual.status_cash_label.y + shift, "现金：", { color = WHITE })
  g:text(visual.status_cash_value.x, visual.status_cash_value.y + shift, money(cash), { color = WHITE })
  g:text(visual.status_health_label.x, visual.status_health_label.y + shift, "健康：", { color = WHITE })
  g:text(visual.status_health_value.x, visual.status_health_value.y + shift, tostring(health), { color = WHITE })
  g:text(visual.status_deposit_label.x, visual.status_deposit_label.y + shift, "存款：", { color = WHITE })
  g:text(visual.status_deposit_value.x, visual.status_deposit_value.y + shift, money(deposit), { color = WHITE })
  g:text(visual.status_reputation_label.x, visual.status_reputation_label.y + shift, "名声：", { color = WHITE })
  g:text(visual.status_reputation_value.x, visual.status_reputation_value.y + shift, tostring(reputation), { color = WHITE })
end

local function draw_main_actions(g, saved, actions)
  for index = #actions, 11, -1 do
    local item = actions[index]
    local base = MAIN_ACTION_ASSETS[item.id]
    if item.id == "start_game" and saved.game and saved.game.status == "playing" then
      base = "main_end"
    end
    draw_control(g, item, saved.overlay == nil and saved.focus == index, item.label, base)
  end
end

local function draw_main(g, saved)
  g:clear(WHITE)
  if not image_drawn(g, "main_bg", 0, 60) then
    g:rect(0, 60, 480, 395,{fill=true,color=WHITE})
  end
  draw_column_divider(g)
  local actions = Layout.actions({
    screen = "main",
    game = saved.game,
    current_market = saved.current_market,
  })
  draw_main_header(g, saved.game)
  draw_main_columns(g, saved, actions)
  draw_main_status(g, saved.game)
  draw_main_actions(g, saved, actions)
end

local XML_TEXT_OVERLAY = {
  price_note = true,
  life_note = true,
  sick_blackout = true,
  sick_dead = true,
  time_up = true,
  sell_reputation = true,
  no_money = true,
  status = true,
  buy_succ = true,
}

local function wrapped_lines(value, maximum, maximum_lines)
  local text = tostring(value or "")
  local line, line_width, index, lines = "", 0, 1, {}
  while index <= #text and #lines < maximum_lines do
    local byte = string.byte(text, index)
    if byte == 10 then
      lines[#lines + 1], line, line_width = line, "", 0
      index = index + 1
    else
    local length = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
    local chunk = string.sub(text, index, index + length - 1)
    local width = View.text_width(chunk)
    if line ~= "" and line_width + width > maximum then
      lines[#lines + 1], line, line_width = line, "", 0
    end
    if #lines < maximum_lines then
      line, line_width = line .. chunk, line_width + width
    end
    index = index + length
    end
  end
  if line ~= "" and #lines < maximum_lines then lines[#lines + 1] = line end
  return lines
end

function View.success_text_pages(value)
  local text = Layout.modal_visual("buy_succ").text
  local maximum_lines = math.max(1, math.floor(text.h / text.lineHeight))
  local lines = wrapped_lines(value, text.w, math.huge)
  local pages = {}
  for first = 1, #lines, maximum_lines do
    pages[#pages + 1] = table.concat(
      lines,
      "\n",
      first,
      math.min(#lines, first + maximum_lines - 1)
    )
  end
  if #pages == 0 then pages[1] = "" end
  return pages
end

draw_wrapped_text = function(g, x, y, value, maximum, line_height, maximum_lines, color)
  for index, line in ipairs(wrapped_lines(value, maximum, maximum_lines)) do
    g:text(x, y + (index - 1) * line_height, line, { color = color or BLACK })
  end
end

local function draw_bottom_centered_text(g, visual, value)
  local lines = wrapped_lines(value, visual.w, math.huge)
  local first_y = visual.bottom - #lines * visual.lineHeight
  for index, line in ipairs(lines) do
    center(g, visual.centerX, first_y + (index - 1) * visual.lineHeight, line, BLACK)
  end
end

local function overlay_goods(saved)
  local overlay = saved.overlay
  local game = saved.game
  if not game then return "货物", nil end
  local source = overlay.kind == "buy_goods"
    and game.market and game.market[overlay.index]
    or game.inventory and game.inventory[overlay.index]
  if not source then return "货物", nil end
  local goods = GOODS[source.goods_id]
  return goods and goods.name or "货物", source
end

local function draw_overlay_actions(g, saved, actions)
  for index, item in ipairs(actions) do
    local kind = saved.overlay.kind
    local lookup = item.id
    if item.id == "close_overlay" then
      if kind == "new_game" then lookup = "close_overlay_new_game"
      elseif kind == "quit_game" then lookup = "close_overlay_quit_game"
      elseif kind == "buy_goods" or kind == "sell_goods" then lookup = "close_overlay_trade"
      else lookup = "close_overlay_" .. kind end
    end
    draw_control(
      g,
      item,
      saved.overlay_focus == index,
      item.label,
      OVERLAY_ACTION_ASSETS[lookup]
    )
  end
end

local function draw_xml_text_overlay(g, saved, visual, actions)
  if visual.image then
    g:rect(visual.image.x, visual.image.y, visual.image.w, visual.image.h,{color=BLACK})
    local house_index = saved.game and saved.game.selected_house
    local asset = saved.overlay.kind == "buy_succ"
      and View.house_result_asset_key(house_index)
    if asset then
      PkgImage.draw(g, asset, visual.image.x, visual.image.y)
    end
  end
  local text = visual.text
  local maximum_lines = text.h and math.max(1, math.floor(text.h / text.lineHeight)) or 8
  local value = saved.overlay.text or "请确认"
  if saved.overlay.kind == "buy_succ" then
    local pages = View.success_text_pages(value)
    value = pages[math.max(1, math.min(#pages, saved.overlay.page or 1))]
  end
  if saved.overlay.kind == "price_note" then
    g:rect(
      text.x - 4,
      text.y - 4,
      text.w + 8,
      math.min(5, maximum_lines) * text.lineHeight + 8,{fill=true,color=WHITE})
  end
  draw_wrapped_text(
    g,
    text.x,
    text.y,
    value,
    text.w,
    text.lineHeight,
    maximum_lines
  )
  if saved.overlay.kind == "no_money" or saved.overlay.kind == "status"
      or saved.overlay.kind == "buy_succ" then
    draw_overlay_actions(g, saved, actions)
  end
end

local function market_price(game, goods_id)
  for _, offer in ipairs(game.market or {}) do
    if offer.goods_id == goods_id then return offer.price end
  end
  return nil
end

local function sell_guidance(game, slot, quantity)
  local price = game and slot and market_price(game, slot.goods_id)
  if not price then return "市场中没有这种货物， 你无法出售" end
  local projected = (price - slot.average_cost) * quantity
  if projected < 0 then return "卖出会亏损 " .. money(-projected) end
  return "卖出可盈利 " .. money(projected)
end

local function draw_trade_overlay(g, saved, actions)
  local visual = Layout.modal_visual(saved.overlay.kind)
  local name, source = overlay_goods(saved)
  local goods_suffix = source and GOODS_ASSETS[source.goods_id]
  local goods_key = goods_suffix and (
    (saved.overlay.kind == "buy_goods" and "goods_m_" or "goods_w_")
      .. goods_suffix
  )
  if not goods_key or not image_drawn(g, goods_key, visual.goods.x, visual.goods.y) then
    center(
      g,
      visual.goods.x + visual.goods.w / 2,
      visual.goods.y + visual.fieldTextOffsetY,
      View.fit_text(name, visual.goods.w),
      BLACK
    )
  end
  if not image_drawn(g, "trade_edit", visual.input.x, visual.input.y) then
    g:rect(visual.input.x, visual.input.y, visual.input.w, visual.input.h,{color=BLACK})
  end
  center(
    g,
    visual.input.x + visual.input.w / 2,
    visual.input.y + visual.fieldTextOffsetY,
    tostring(saved.quantity),
    BLACK
  )
  if source then
    local guidance
    if saved.overlay.kind == "buy_goods" then
      guidance = "你最多可以购买"
        .. tostring(Layout.buy_maximum(saved)) .. "个" .. name
    else
      guidance = sell_guidance(saved.game, source, saved.quantity)
    end
    draw_bottom_centered_text(g, visual.guidance, guidance)
  end
  if saved.overlay.kind == "buy_goods" or saved.overlay.kind == "sell_goods" then
    local frame = Layout.overlay_frame(saved.overlay.kind)
    for _, item in ipairs(actions) do
      if string.match(item.id, "^buy_qty_") or string.match(item.id, "^sell_qty_") then
        g:rect(frame.x, item.y, frame.w, item.h,{fill=true,color=WHITE})
        break
      end
    end
  end
  draw_overlay_actions(g, saved, actions)
end

local function draw_actionable_overlay(g, saved, actions)
  local kind = saved.overlay.kind
  local visual = Layout.modal_visual(kind)
  if kind == "new_game" then
    center(g, visual.cash.x + visual.cash.w / 2, visual.cash.y, "3000", BLACK)
  elseif kind == "hospital" then
    local game = saved.game
    local health = game and game.health or 0
    local cost = math.max(0, (100 - health) * 5000)
    local funds = game and game.cash + game.deposit or 0
    local guidance
    if health >= 100 then
      guidance = "身体好好的来医院干啥， 赶紧干正事儿去吧。"
    elseif funds < cost then
      guidance = "看病需要花费" .. tostring(cost) .. "元， 你没有足够的钱看病！"
    else
      guidance = "看病需要花费" .. tostring(cost) .. "元， 确定要看病吗？"
    end
    local visual = Layout.modal_visual(kind)
    draw_wrapped_text(
      g,
      visual.text.x,
      visual.text.y,
      guidance,
      visual.text.w,
      visual.text.lineHeight,
      3
    )
  elseif kind == "agency" then
    -- 只盖住数量行底图错位字，左侧标题「中介」必须露出来。
    g:rect(
      visual.content_mask.x,
      visual.content_mask.y,
      visual.content_mask.w,
      visual.content_mask.h,{fill=true,color=WHITE})
    center(
      g,
      visual.prefix.x + visual.prefix.w / 2,
      visual.prefix.y + visual.fieldTextOffsetY,
      "增加",
      BLACK
    )
    g:rect(visual.input.x, visual.input.y, visual.input.w, visual.input.h,{color=BLACK})
    center(
      g,
      visual.input.x + visual.input.w / 2,
      visual.input.y + visual.fieldTextOffsetY,
      tostring(saved.quantity),
      BLACK
    )
    center(
      g,
      visual.suffix.x + visual.suffix.w / 2,
      visual.suffix.y + visual.fieldTextOffsetY,
      "个出租屋空间",
      BLACK
    )
    center(
      g,
      visual.note.x + visual.note.w / 2,
      visual.note.y,
      "共需要花费" .. money(saved.quantity * 10000) .. "元",
      BLACK
    )
    local frame = Layout.overlay_frame(kind)
    for _, item in ipairs(actions) do
      if string.match(item.id, "^agency_qty_") then
        g:rect(frame.x, item.y, frame.w, item.h,{fill=true,color=WHITE})
        break
      end
    end
  end
  draw_overlay_actions(g, saved, actions)
end

local function draw_overlay_frame(g, kind, frame, background)
  -- Clear the complete modal footprint first.  Trade dialogs are taller than
  -- the source 427x127 trade_bg because its shortcut row lives below the
  -- original trade controls.  Keep the source artwork at native size, then
  -- provide a crisp paper-white extension and a closed border for the added
  -- row; this prevents the row from exposing or covering footer controls.
  g:rect(frame.x, frame.y, frame.w, frame.h,{fill=true,color=WHITE})
  local drawn = background and image_drawn(g, background, frame.x, frame.y)
  local source_height = (
    kind == "buy_goods" or kind == "sell_goods"
      or kind == "bank" or kind == "hospital" or kind == "agency"
  ) and 127 or frame.h
  if drawn and frame.h > source_height then
    g:rect(
      frame.x,
      frame.y + source_height,
      frame.w,
      frame.h - source_height,{fill=true,color=WHITE})
    g:rect(frame.x, frame.y, frame.w, frame.h,{color=BLACK})
  elseif not drawn then
    g:rect(frame.x, frame.y, frame.w, frame.h,{color=BLACK})
  end
end

local function draw_overlay(g, saved)
  local overlay = saved.overlay
  if type(overlay) ~= "table" then return end
  local frame = Layout.overlay_frame(overlay.kind)
  if not frame then return end
  local actions = Layout.overlay_actions(saved)
  local background = OVERLAY_FRAME_ASSETS[overlay.kind]
  draw_overlay_frame(g, overlay.kind, frame, background)
  if XML_TEXT_OVERLAY[overlay.kind] then
    draw_xml_text_overlay(g, saved, Layout.modal_visual(overlay.kind), actions)
  elseif overlay.kind == "buy_goods" or overlay.kind == "sell_goods" then
    draw_trade_overlay(g, saved, actions)
  else
    draw_actionable_overlay(g, saved, actions)
  end
end

local function draw_story(g, saved)
  local page = Layout.ACTIVITIES.story
  local step = math.max(1, math.min(5, saved.story_step or 1))
  g:clear(WHITE)
  if not image_drawn(g, "story_bg", 0, 320) then
    g:rect(0, 320, 480, 480,{fill=true,color=WHITE})
  end
  draw_wrapped_text(
    g,
    page.text.x,
    page.text.y,
    View.STORY_PARAGRAPHS[step],
    page.text.w,
    26,
    math.floor(page.text.h / 26)
  )
  for index, item in ipairs(Layout.actions(saved)) do
    local base = item.id == "finish_story" and "story_start" or "story_continue"
    draw_control(g, item, index == saved.focus, item.label, base)
  end
end

local function fill_if_positive(g, x, y, w, h, color)
  if w > 0 and h > 0 then g:rect(x, y, w, h,{fill=true,color=color}) end
end

local function mask_except(g, rect)
  fill_if_positive(g, 0, 0, 480, rect.y, BLACK)
  fill_if_positive(g, 0, rect.y, rect.x, rect.h, BLACK)
  fill_if_positive(g, rect.x + rect.w, rect.y, 480 - rect.x - rect.w, rect.h, BLACK)
  fill_if_positive(g, 0, rect.y + rect.h, 480, 800 - rect.y - rect.h, BLACK)
end

local function draw_help(g, saved)
  local sample = {
    screen = "main",
    overlay = { kind = "help_mask" },
    focus = 1,
    current_market = 1,
    game = {
      week = 28,
      cash = 0,
      deposit = 734738,
      health = 96,
      reputation = 98,
      capacity = 100,
      used = 70,
      selected_house = 1,
      status = "playing",
      house_prices = { 259, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
      market = {
        { goods_id = 5, price = 397 },
        { goods_id = 2, price = 137 },
        { goods_id = 6, price = 3457 },
        { goods_id = 7, price = 106 },
        { goods_id = 4, price = 674 },
      },
      inventory = {
        { goods_id = 8, quantity = 50, average_cost = 15023 },
        { goods_id = 6, quantity = 20, average_cost = 2065 },
      },
    },
  }
  draw_main(g, sample)
  local page = Layout.ACTIVITIES.help
  local step = math.max(1, math.min(9, saved.help_step or 1))
  local highlight = page.highlights[step]
  mask_except(g, highlight)
  g:rect(highlight.x, highlight.y, highlight.w, highlight.h,{color=BLACK})
  g:rect(
    page.explanation.x,
    page.explanation.y,
    page.explanation.w,
    page.explanation.h,{fill=true,color=BLACK})
  draw_wrapped_text(
    g,
    page.explanation.x + 8,
    page.explanation.y + 8,
    View.HELP_EXPLANATIONS[step],
    page.explanation.w - 16,
    page.explanation.lineHeight,
    12,
    WHITE
  )
  for index, item in ipairs(Layout.actions(saved)) do
    draw_control(g, item, index == saved.focus, item.label)
  end
end

function View.draw(ctx, g, saved)
  if saved.screen == "houses" then draw_houses(g, saved)
  elseif saved.screen == "records" then draw_records(g, saved)
  elseif saved.screen == "help" then draw_help(g, saved)
  elseif saved.screen == "story" then draw_story(g, saved)
  else draw_main(g, saved) end
  draw_overlay(g, saved)
end

return View
