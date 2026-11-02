-- 港股实况：通过 ScriptNet GET 固定 Demo API，查询真实港股报价。
-- 完整链路：XTApp HTTP GET -> 阅星曈 Demo -> 阿里云市场 HTTPS POST。
-- 设备端绝不保存 AppCode；manifest 必须声明 permissions = { "net" }。
-- ctx.net:request() 发起请求，结束时回调 on_net_done；退出时 job:cancel()。

local BLACK, WHITE = 15, 0
local API_BASE = "http://193.112.174.92:28473/demo/stock/xtapp?symbol="
local KLINE_API_BASE = "http://193.112.174.92:28473/demo/stock/kline/xtapp?limit=40&type="
local RANKING_API = "http://193.112.174.92:28473/demo/stock/ranking/xtapp?limit=12"
local QUOTE_PROTOCOL = "XTAPP_STOCK_V1"
local KLINE_PROTOCOL = "XTAPP_KLINE_V1"
local RANKING_PROTOCOL = "XTAPP_RANKING_V1"
local DEFAULT_CODE = "03690"
local PRESETS = {
  { code = "00700", label = "腾讯" },
  { code = "09988", label = "阿里" },
  { code = "03690", label = "美团" },
}
local KLINE_TYPES = {
  { value = "1", label = "1分" }, { value = "5", label = "5分" },
  { value = "15", label = "15分" }, { value = "30", label = "30分" },
  { value = "60", label = "60分" },
}
local KLINE_TYPE_VALUES = { ["1"] = true, ["5"] = true, ["15"] = true, ["30"] = true, ["60"] = true }
local KLINE_TYPE_X, KLINE_TYPE_Y, KLINE_TYPE_WIDTH = 60, 338, 72
local request_id = nil
local on_net_done
local request_code = nil
local request_kind = nil

local function app_state(ctx)
  ctx.state.hk_stock_live = ctx.state.hk_stock_live or {
    code = DEFAULT_CODE,
    cursor = 3,
    editor_open = false,
    status = "idle",
    quote = nil,
    kline = nil,
    ranking = nil,
    view = "quote",
    kline_type = "1",
    last_http = nil,
  }
  local state = ctx.state.hk_stock_live
  if state.default_code_version ~= "meituan_v1" then
    state.code = DEFAULT_CODE
    state.default_code_version = "meituan_v1"
  end
  if type(state.code) ~= "string" or not state.code:match("^%d%d%d%d%d$") then state.code = DEFAULT_CODE end
  if type(state.cursor) ~= "number" or state.cursor < 1 or state.cursor > 5 then state.cursor = 3 end
  if type(state.status) ~= "string" then state.status = "idle" end
  if type(state.kline_type) ~= "string" or not KLINE_TYPE_VALUES[state.kline_type] then state.kline_type = "1" end
  return state
end

local function text_width(text)
  local width, index = 0, 1
  text = tostring(text or "")
  while index <= #text do
    local byte = text:byte(index)
    if byte >= 0xE0 then width, index = width + 20, index + 3
    elseif byte >= 0xC0 then width, index = width + 20, index + 2
    else width, index = width + 10, index + 1 end
  end
  return width
end

local function right_text(g, right, y, text)
  g:text(right - text_width(text), y, text, { color = BLACK })
end

local function center_text(g, x, y, width, text, color)
  g:text(x + math.max(0, math.floor((width - text_width(text)) / 2)), y, text, { color = color or BLACK })
end

local function short_number(value)
  local number = tonumber(value)
  if not number then return "--" end
  if math.abs(number) >= 100000000 then return string.format("%.2f亿", number / 100000000) end
  if math.abs(number) >= 10000 then return string.format("%.1f万", number / 10000) end
  return string.format("%.0f", number)
end

local function price(value)
  local number = tonumber(value)
  if not number then return "--" end
  return string.format("%.2f", number)
end

local function signed(value, suffix)
  local number = tonumber(value)
  if not number then return "--" end
  return string.format("%+.2f%s", number, suffix or "")
end

local SEGMENTS = {
  ["0"] = "ab cdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg",
  ["4"] = "bcfg", ["5"] = "acdfg", ["6"] = "acdefg", ["7"] = "abc",
  ["8"] = "abcdefg", ["9"] = "abcdfg",
}

local function has_segment(segments, segment)
  return segments and segments:find(segment, 1, true) ~= nil
end

local function draw_digit(g, x, y, char)
  local width, height, thick = 46, 88, 8
  if char == "." then g:rect(x + 2, y + height - thick, thick, thick,{fill=true,color=BLACK}); return 20 end
  if char == "-" then g:rect(x + 3, y + 40, width - 6, thick,{fill=true,color=BLACK}); return width + 6 end
  local segments = SEGMENTS[char]
  if not segments then return width + 5 end
  if has_segment(segments, "a") then g:rect(x + 5, y, width - 10, thick,{fill=true,color=BLACK}) end
  if has_segment(segments, "b") then g:rect(x + width - thick, y + 8, thick, 34,{fill=true,color=BLACK}) end
  if has_segment(segments, "c") then g:rect(x + width - thick, y + 46, thick, 34,{fill=true,color=BLACK}) end
  if has_segment(segments, "d") then g:rect(x + 5, y + height - thick, width - 10, thick,{fill=true,color=BLACK}) end
  if has_segment(segments, "e") then g:rect(x, y + 46, thick, 34,{fill=true,color=BLACK}) end
  if has_segment(segments, "f") then g:rect(x, y + 8, thick, 34,{fill=true,color=BLACK}) end
  if has_segment(segments, "g") then g:rect(x + 8, y + 40, width - 16, thick,{fill=true,color=BLACK}) end
  return width + 6
end

local function draw_price(g, y, value)
  local shown = price(value)
  local total = 0
  for char in shown:gmatch(".") do total = total + (char == "." and 20 or 52) end
  local x = math.floor((480 - total) / 2)
  for char in shown:gmatch(".") do x = x + draw_digit(g, x, y, char) end
end

local function parse_quote(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= QUOTE_PROTOCOL then return nil, "bad_protocol" end
  local quote = {}
  for line in body:gmatch("[^\r\n]+") do
    local key, value = line:match("^([^\t]+)\t(.*)$")
    if key then quote[key] = value end
  end
  if quote.status == "error" then return nil, quote.message or "upstream_error" end
  if not quote.symbol or not quote.price or quote.price == "" then return nil, "missing_price" end
  return quote
end

local function parse_kline(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= KLINE_PROTOCOL then return nil, "bad_kline_protocol" end
  local candles = {}
  for line in body:gmatch("[^\r\n]+") do
    local day, open, high, low, close, volume = line:match("^candle\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
    if day and tonumber(close) then
      candles[#candles + 1] = { day = day, open = open, high = high, low = low, close = close, volume = volume }
    end
  end
  if #candles < 2 then return nil, "missing_kline" end
  return candles
end

local function parse_ranking(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= RANKING_PROTOCOL then return nil, "bad_ranking_protocol" end
  local stocks = {}
  for line in body:gmatch("[^\r\n]+") do
    local symbol, name, price_value, change_rate, change, volume, value = line:match("^stock\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
    if symbol and name and tonumber(price_value) then
      stocks[#stocks + 1] = { symbol = symbol, name = name, price = price_value, changeRate = change_rate, change = change, volume = volume, value = value }
    end
  end
  if #stocks == 0 then return nil, "missing_ranking" end
  return stocks
end

local function request_quote(ctx)
  local state = app_state(ctx)
  if request_id then state.status = "busy"; ctx:invalidate(); return end
  if not ctx.net then state.status = "no_net"; ctx:invalidate(); return end
  local id, err = ctx.net:request({ url = API_BASE .. state.code }, on_net_done)
  if not id then state.status = "error"; state.error = tostring(err); ctx:invalidate(); return end
  request_id = id
  request_code = state.code
  request_kind = "quote"
  state.status = "loading"
  state.kline = nil
  state.kline_error = nil
  state.error = nil
  ctx:invalidate()
end

local function request_kline(ctx, code)
  local state = app_state(ctx)
  local id, err = ctx.net:request({ url = KLINE_API_BASE .. state.kline_type .. "&symbol=" .. code }, on_net_done)
  if not id then
    state.status = "ready"
    state.kline_error = tostring(err)
    ctx:invalidate()
    return
  end
  request_id = id
  request_code = code
  request_kind = "kline"
  state.status = "chart_loading"
  ctx:invalidate()
end

local function request_ranking(ctx)
  local state = app_state(ctx)
  if request_id then state.status = "busy"; ctx:invalidate(); return end
  if not ctx.net then state.status = "no_net"; ctx:invalidate(); return end
  local id, err = ctx.net:request({ url = RANKING_API }, on_net_done)
  if not id then state.status = "error"; state.ranking_error = tostring(err); ctx:invalidate(); return end
  request_id = id
  request_code = nil
  request_kind = "ranking"
  state.status = "ranking_loading"
  state.ranking_error = nil
  ctx:invalidate()
end

on_net_done = function(ctx, result)
  local state = app_state(ctx)
  local completed_code = request_code
  local completed_kind = request_kind
  request_id = nil
  request_code = nil
  request_kind = nil
  if (completed_kind == "quote" or completed_kind == "kline") and completed_code ~= state.code then
    state.status = "edited"
    ctx:invalidate()
    return
  end
  if completed_kind == "ranking" then
    if result.ok then
      local ranking, parse_error = parse_ranking(result.body)
      if ranking then state.ranking = ranking; state.ranking_error = nil else state.ranking_error = parse_error end
    else
      state.ranking_error = tostring(result.err or result.status or "request_failed")
    end
    state.status = "ready"
    ctx:invalidate()
    return
  end
  if completed_kind == "kline" then
    if result.ok then
      local kline, parse_error = parse_kline(result.body)
      if kline then
        state.kline = kline
        state.kline_error = nil
      else
        state.kline_error = parse_error
      end
    else
      state.kline_error = tostring(result.err or result.status or "request_failed")
    end
    state.status = "ready"
    ctx:invalidate()
    return
  end

  state.last_http = result.status
  if result.ok then
    local quote, parse_error = parse_quote(result.body)
    if quote then
      state.quote = quote
      state.error = nil
      request_kline(ctx, completed_code)
      return
    else
      state.status = "error"
      state.error = parse_error
    end
  else
    state.status = "error"
    state.error = tostring(result.err or result.status or "request_failed")
  end
  ctx:invalidate()
end

local function change_digit(state, direction)
  local at = state.cursor
  local value = tonumber(state.code:sub(at, at)) or 0
  value = (value + direction) % 10
  state.code = state.code:sub(1, at - 1) .. tostring(value) .. state.code:sub(at + 1)
  state.status = "edited"
end

local function set_preset(ctx, code)
  local state = app_state(ctx)
  state.code = code
  state.cursor = 3
  request_quote(ctx)
end

local function draw_code_selector(g, state)
  g:rect(382, 68, 74, 34,{color=BLACK})
  center_text(g, 382, 76, 74, "刷新", BLACK)
  -- 顶部铅笔：打开代码修改面板。
  g:line(339, 94, 355, 78,{color=BLACK})
  g:line(342, 97, 358, 81,{color=BLACK})
  g:line(339, 94, 342, 97,{color=BLACK})
  g:rect(355, 77, 5, 5,{fill=true,color=BLACK})
end

local function draw_presets(g, state)
  local y, width, gap = 68, 92, 8
  for index, preset in ipairs(PRESETS) do
    local x = 24 + (index - 1) * (width + gap)
    local active = state.code == preset.code
    g:rect(x, y, width, 32,{fill=(active) and true or false,color=BLACK})
    center_text(g, x, y + 6, width, preset.label, active and WHITE or BLACK)
  end
end

local function draw_metric(g, x, y, label, value)
  g:text(x, y, label, { color = BLACK })
  right_text(g, x + 194, y, tostring(value or "--"))
end

local function draw_dotted_line(g, x, y, width)
  for offset = 0, width - 1, 8 do
    g:line(x + offset, y, math.min(x + width, x + offset + 3), y,{color=BLACK})
  end
end

local function draw_kline(g, state)
  local x, y, width, height = 24, 377, 432, 128
  g:rect(x, y, width, height,{color=BLACK})
  draw_dotted_line(g, x, y + 64, width)
  local candles = state.kline
  if type(candles) ~= "table" or #candles < 2 then
    center_text(g, x, y + 48, width, state.status == "chart_loading" and "K线加载中" or "暂无走势数据", BLACK)
    return
  end
  local low, high = nil, nil
  for _, candle in ipairs(candles) do
    local value = tonumber(candle.close)
    if value then
      low = low and math.min(low, value) or value
      high = high and math.max(high, value) or value
    end
  end
  if not low or not high then return end
  if high == low then high, low = high + 0.01, low - 0.01 end
  right_text(g, x + width - 4, y + 4, price(high))
  right_text(g, x + width - 4, y + height - 20, price(low))
  local values, slopes = {}, {}
  for index, candle in ipairs(candles) do values[index] = tonumber(candle.close) end
  for index = 1, #values do
    if index == 1 then slopes[index] = values[2] - values[1]
    elseif index == #values then slopes[index] = values[index] - values[index - 1]
    else slopes[index] = (values[index + 1] - values[index - 1]) / 2 end
  end
  local previous_x, previous_y = nil, nil
  for index = 1, #values - 1 do
    local start_value, end_value = values[index], values[index + 1]
    local delta = end_value - start_value
    local start_slope, end_slope = slopes[index], slopes[index + 1]
    -- 单调限制避免平滑曲线越过相邻真实收盘价的高低范围。
    if delta == 0 then
      start_slope, end_slope = 0, 0
    else
      local start_ratio, end_ratio = start_slope / delta, end_slope / delta
      local ratio_length = start_ratio * start_ratio + end_ratio * end_ratio
      if ratio_length > 9 then
        local scale = 3 / math.sqrt(ratio_length)
        start_slope, end_slope = scale * start_ratio * delta, scale * end_ratio * delta
      end
    end
    for sample = 0, 4 do
      local t = sample / 4
      local t2, t3 = t * t, t * t * t
      local h00 = 2 * t3 - 3 * t2 + 1
      local h10 = t3 - 2 * t2 + t
      local h01 = -2 * t3 + 3 * t2
      local h11 = t3 - t2
      local value = h00 * start_value + h10 * start_slope + h01 * end_value + h11 * end_slope
      local point_x = x + 8 + math.floor((index - 1 + t) * (width - 16) / (#values - 1))
      local point_y = y + 14 + math.floor((high - value) * (height - 28) / (high - low))
      if previous_x then g:line(previous_x, previous_y, point_x, point_y,{color=BLACK}) end
      previous_x, previous_y = point_x, point_y
    end
  end
end

local function draw_kline_types(g, state)
  local x, y, width = KLINE_TYPE_X, KLINE_TYPE_Y, KLINE_TYPE_WIDTH
  for index, item in ipairs(KLINE_TYPES) do
    local item_x = x + (index - 1) * width
    local active = state.kline_type == item.value
    g:rect(item_x, y, width - 4, 24,{fill=(active) and true or false,color=BLACK})
    center_text(g, item_x, y + 4, width - 4, item.label, active and WHITE or BLACK)
  end
end

local function set_kline_type(ctx, kline_type)
  local state = app_state(ctx)
  if state.kline_type == kline_type then return end
  state.kline_type = kline_type
  state.kline = nil
  state.kline_error = nil
  if state.quote then request_kline(ctx, state.code) else request_quote(ctx) end
  ctx:invalidate()
end

local function draw_range(g, quote)
  local low = tonumber(quote["52week_low"])
  local high = tonumber(quote["52week_high"])
  local current = tonumber(quote.price)
  g:text(24, 524, "52周区间", { color = BLACK })
  right_text(g, 456, 524, price(quote["52week_low"]) .. " — " .. price(quote["52week_high"]))
  g:line(24, 555, 456, 555,{color=BLACK})
  if low and high and current and high > low then
    local ratio = math.max(0, math.min(1, (current - low) / (high - low)))
    local marker = 24 + math.floor(432 * ratio)
    g:rect(marker - 3, 547, 6, 17,{fill=true,color=BLACK})
  end
end

local function draw_tabs(g, state)
  local left_active = state.view ~= "ranking"
  g:rect(24, 112, 208, 28,{fill=(left_active) and true or false,color=BLACK})
  g:rect(248, 112, 208, 28,{fill=not (left_active),color=BLACK})
  center_text(g, 24, 117, 208, "行情", left_active and WHITE or BLACK)
  center_text(g, 248, 117, 208, "涨幅榜", left_active and BLACK or WHITE)
end

local function draw_ranking(g, state)
  g:text(24, 168, "港股涨幅榜", { color = BLACK })
  right_text(g, 456, 168, state.status == "ranking_loading" and "加载中" or "实时排行")
  local stocks = state.ranking
  if type(stocks) ~= "table" or #stocks == 0 then
    center_text(g, 24, 340, 432, state.status == "ranking_loading" and "榜单加载中" or "暂无排行数据", BLACK)
    if state.ranking_error then center_text(g, 24, 370, 432, "点击涨幅榜重试", BLACK) end
    return
  end
  g:text(24, 202, "代码 / 名称", { color = BLACK })
  right_text(g, 350, 202, "现价")
  -- 右侧保留一个字符的安全边距，避免真实涨幅末尾的 % 被裁到屏幕外。
  right_text(g, 440, 202, "涨幅")
  g:line(24, 224, 456, 224,{color=BLACK})
  for index, stock in ipairs(stocks) do
    local y = 238 + (index - 1) * 48
    if y > 718 then break end
    g:text(24, y, string.format("%02d", index), { color = BLACK })
    g:text(62, y, stock.name, { color = BLACK })
    g:text(62, y + 20, stock.symbol .. ".HK", { color = BLACK })
    right_text(g, 350, y, price(stock.price))
    right_text(g, 440, y, signed(stock.changeRate, "%"))
    g:line(24, y + 42, 456, y + 42,{color=BLACK})
  end
end

local function draw_quote(g, state)
  local quote = state.quote
  if not quote then
    local title = state.status == "loading" and "LOADING" or "HK STOCK LIVE"
    local hint = state.status == "error" and "请求失败，点击刷新重试" or "输入代码后查询真实行情"
    center_text(g, 24, 235, 432, title, BLACK)
    center_text(g, 24, 270, 432, hint, BLACK)
    return
  end

  g:text(24, 154, quote.name ~= "" and quote.name or quote.enname or "港股", { color = BLACK })
  right_text(g, 440, 154, quote.symbol .. ".HK")
  draw_price(g, 184, quote.price)
  local movement = signed(quote.change) .. "  " .. signed(quote.changeRate, "%")
  center_text(g, 24, 305, 432, movement, BLACK)
  right_text(g, 456, 305, quote.update_text ~= "" and quote.update_text or "实时")
  draw_kline(g, state)
  draw_range(g, quote)

  g:line(24, 574, 456, 574,{color=BLACK})
  g:line(240, 588, 240, 770,{color=BLACK})
  draw_metric(g, 24, 588, "开盘", price(quote.open))
  draw_metric(g, 262, 588, "昨收", price(quote.preclose))
  draw_metric(g, 24, 630, "最高", price(quote.high))
  draw_metric(g, 262, 630, "最低", price(quote.low))
  draw_metric(g, 24, 672, "成交量", short_number(quote.volume))
  draw_metric(g, 262, 672, "成交额", short_number(quote.value))
  draw_metric(g, 24, 714, "买一", price(quote.bid))
  draw_metric(g, 262, 714, "卖一", price(quote.ask))
  draw_metric(g, 24, 756, "市盈率", price(quote.pe))
  g:text(262, 756, quote.enname or "--", { color = BLACK })
end

local function draw_code_modal(g, state)
  if not state.editor_open then return end
  -- 弹窗打开时先清空内容区，避免底层指标穿透干扰输入。
  local screen_w, screen_h = g:size()
  g:rect(0, 60, screen_w, screen_h - 60,{fill=true,color=WHITE})
  g:rect(16, 178, 448, 390,{fill=true,color=WHITE})
  g:rect(16, 178, 448, 390,{color=BLACK})
  center_text(g, 16, 204, 448, "输入五位港股代码", BLACK)
  g:text(42, 238, "左右选择 · 上下修改", { color = BLACK })
  local box_w, gap, start_x, y = 56, 6, 87, 278
  for index = 1, 5 do
    local x = start_x + (index - 1) * (box_w + gap)
    g:rect(x, y, box_w, 48,{fill=(state.cursor == index) and true or false,color=BLACK})
    center_text(g, x, y + 13, box_w, state.code:sub(index, index), state.cursor == index and WHITE or BLACK)
  end
  g:rect(42, 382, 396, 54,{fill=true,color=BLACK})
  center_text(g, 42, 400, 396, "确认并查询", WHITE)
  center_text(g, 42, 474, 396, "OK 确认 · BACK 取消", BLACK)
end

function on_load(ctx)
  local state = app_state(ctx)
  state.status = "idle"
  state.editor_open = false
  ctx:invalidate()
  request_quote(ctx)
end

function on_leave(ctx)
  if request_id and ctx.net then request_id:cancel() end
  request_id = nil
  request_code = nil
  request_kind = nil
end

function on_input(ctx, ev)
  local state = app_state(ctx)
  if ev.type == "key" and ev.phase == "down" then
    if state.editor_open then
      if ev.key == "back" then state.editor_open = false; ctx:invalidate(); return true end
      if ev.key == "left" then state.cursor = (state.cursor + 3) % 5 + 1; ctx:invalidate(); return true end
      if ev.key == "right" then state.cursor = state.cursor % 5 + 1; ctx:invalidate(); return true end
      if ev.key == "up" then change_digit(state, 1); ctx:invalidate(); return true end
      if ev.key == "down" then change_digit(state, -1); ctx:invalidate(); return true end
      if ev.key == "ok" then state.editor_open = false; request_quote(ctx); return true end
      return true
    end
    if ev.key == "back" then ctx:quit(); return true end
    if ev.key == "left" then state.editor_open = true; state.cursor = (state.cursor + 3) % 5 + 1; ctx:invalidate(); return true end
    if ev.key == "right" then state.editor_open = true; state.cursor = state.cursor % 5 + 1; ctx:invalidate(); return true end
    if ev.key == "up" then state.editor_open = true; change_digit(state, 1); ctx:invalidate(); return true end
    if ev.key == "down" then state.editor_open = true; change_digit(state, -1); ctx:invalidate(); return true end
    if ev.key == "ok" then state.editor_open = true; ctx:invalidate(); return true end
    return false
  end

  if (ev.type == "pointer" and ev.phase == "up") and (ev.gesture == "tap" or ev.gesture == "long") then
    -- 走势区没有其他触控动作，优先消费周期选择，避免被后续编辑器/页签分支吞掉。
    if not state.editor_open and state.view == "quote" and ev.y >= 318 and ev.y <= 398 then
      local index = math.floor((ev.x - KLINE_TYPE_X) / KLINE_TYPE_WIDTH) + 1
      local selected_type = KLINE_TYPES[index] and KLINE_TYPES[index].value
      if selected_type and state.kline_type ~= selected_type then
        state.kline_type = selected_type
        state.kline = nil
        state.kline_error = nil
        if state.quote then request_kline(ctx, state.code) end
        ctx:invalidate()
        return true
      end
    end
    if state.editor_open then
      if ev.y >= 278 and ev.y <= 326 then
        local index = math.floor((ev.x - 87) / 62) + 1
        if index >= 1 and index <= 5 then
          state.cursor = index
          change_digit(state, ev.gesture == "long" and -1 or 1)
          ctx:invalidate()
          return true
        end
      end
      if ev.y >= 382 and ev.y <= 436 then state.editor_open = false; request_quote(ctx); return true end
      return true
    end
    if ev.y >= 68 and ev.y <= 102 and ev.x >= 330 and ev.x < 372 then state.editor_open = true; ctx:invalidate(); return true end
    if ev.y >= 68 and ev.y <= 102 and ev.x >= 382 then request_quote(ctx); return true end
    if ev.y >= 68 and ev.y <= 102 then
      local index = math.floor((ev.x - 24) / 100) + 1
      if PRESETS[index] then set_preset(ctx, PRESETS[index].code); return true end
    end
    if ev.y >= 112 and ev.y <= 140 then
      if ev.x < 240 then state.view = "quote"; ctx:invalidate()
      else state.view = "ranking"; request_ranking(ctx) end
      return true
    end
  end
  return false
end

function on_draw(ctx, g)
  local state = app_state(ctx)
  g:clear(WHITE)
  g:text(24, 25, "港股实况", { color = BLACK })
  right_text(g, 456, 25, "LIVE · HK")
  draw_code_selector(g, state)
  draw_presets(g, state)
  draw_tabs(g, state)
  if state.view == "ranking" then draw_ranking(g, state) else draw_quote(g, state); draw_kline_types(g, state) end
  draw_code_modal(g, state)
end
