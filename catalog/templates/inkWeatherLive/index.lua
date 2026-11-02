local PkgImage = require("pkg_image")
-- 墨水天气：固定 HTTP GET 获取天气仪表盘，凭据只存在服务器端。
local BLACK, WHITE = 15, 0
local WEATHER_API = "http://193.112.174.92:28473/demo/weather/dashboard/xtapp?city_id="
local LOCATION_API = "http://193.112.174.92:28473/demo/weather/locations/xtapp?parent="
local WEATHER_PROTOCOL = "XTAPP_WEATHER_DASHBOARD_V1"
local LOCATION_PROTOCOL = "XTAPP_WEATHER_LOCATIONS_V1"
local AUTO_REFRESH_SECONDS = 30 * 60
local task_id, task_kind = nil, nil
local on_net_done
local TABS = { "天气", "未来", "生活" }
local CONTENT_LEFT, CONTENT_WIDTH = 24, 432
local TEXT_ASCII_WIDTH, TEXT_CJK_WIDTH = 10, 20
local NUMBER_OPTICAL_SHIFT = 2
local WATCHDOG_FEED_INTERVAL_MS = 1000
local WATCHDOG_MAX_RUNTIME_MS = 9000

-- 天气响应解析和墨水屏绘制都可能在一次回调内完成较多工作。
-- 固件长任务看门狗只保护当前回调：start 后约每秒检查一次并按需 feed，
-- 正常返回仅清理 Lua 引用，绝不能调用语义为“退出应用”的 stop。
local LongCallback = {
  ctx = nil,
  started_ms = 0,
  last_feed_ms = 0,
  max_runtime_ms = WATCHDOG_MAX_RUNTIME_MS,
}

local function watchdog_elapsed(now, started)
  if now < started then return 0 end
  return now - started
end

local function watchdog_begin(ctx, max_runtime_ms)
  if LongCallback.ctx ~= nil then return nil, "already_active" end
  local ok, err = ctx.budget:extend()
  if ok ~= true then return nil, err or "inactive" end
  local now = ctx.clock:millis()
  LongCallback.ctx = ctx
  LongCallback.started_ms = now
  LongCallback.last_feed_ms = now
  LongCallback.max_runtime_ms = math.max(100, math.min(10000, math.floor(tonumber(max_runtime_ms) or WATCHDOG_MAX_RUNTIME_MS)))
  return true
end

local function watchdog_checkpoint()
  local ctx = LongCallback.ctx
  if not ctx then return true end
  local now = ctx.clock:millis()
  if watchdog_elapsed(now, LongCallback.started_ms) >= LongCallback.max_runtime_ms then
    error("weather callback exceeded app time budget", 0)
  end
  if watchdog_elapsed(now, LongCallback.last_feed_ms) >= WATCHDOG_FEED_INTERVAL_MS then
    local ok, err = ctx.budget:extend()
    if ok ~= true then error("budget extend failed: " .. tostring(err or "inactive"), 0) end
    LongCallback.last_feed_ms = now
  end
  return true
end

local function watchdog_finish()
  LongCallback.ctx = nil
  LongCallback.started_ms = 0
  LongCallback.last_feed_ms = 0
end

local function run_protected_callback(ctx, callback)
  local started, start_err = watchdog_begin(ctx, WATCHDOG_MAX_RUNTIME_MS)
  if started ~= true and start_err ~= "disabled" then
    error("watchdog start failed: " .. tostring(start_err), 0)
  end
  local ok, result = pcall(callback)
  watchdog_finish()
  if not ok then error(result, 0) end
  return result
end

local function app_state(ctx)
  ctx.state.ink_weather_live = ctx.state.ink_weather_live or {
    city_id = 2,
    city_name = "北京市",
    city_path = "北京市",
    tab = 1,
    status = "idle",
    forecast_offset = 1,
    auto_refresh = false,
    auto_elapsed = 0,
    picker_open = false,
    picker_parent = "0",
    picker_label = "选择省份",
    picker_items = {},
    picker_index = 1,
    picker_page = 1,
    picker_total_pages = 1,
    picker_total = 0,
    picker_status = "idle",
    picker_stack = {},
    picker_breadcrumb = {},
  }
  local s = ctx.state.ink_weather_live
  s.city_id = tonumber(s.city_id) or 2
  s.city_name = s.city_name or "北京市"
  s.city_path = s.city_path or s.city_name
  s.tab = math.max(1, math.min(#TABS, s.tab or 1))
  s.forecast_offset = math.max(1, math.min(6, s.forecast_offset or 1))
  if s.auto_refresh == nil then s.auto_refresh = false end
  s.auto_elapsed = math.max(0, tonumber(s.auto_elapsed) or 0)
  s.picker_items = s.picker_items or {}
  s.picker_stack = s.picker_stack or {}
  s.picker_breadcrumb = s.picker_breadcrumb or {}
  s.picker_index = math.max(0, math.min(#s.picker_items, s.picker_index or 1))
  return s
end

local function text_width(value)
  local width, index, text = 0, 1, tostring(value or "")
  while index <= #text do
    local byte = text:byte(index)
    if byte >= 0xE0 then width, index = width + TEXT_CJK_WIDTH, index + 3
    elseif byte >= 0xC0 then width, index = width + TEXT_ASCII_WIDTH, index + 2
    else width, index = width + TEXT_ASCII_WIDTH, index + 1 end
  end
  return width
end

local function center(g, x, y, width, value, color)
  local text = tostring(value or "")
  g:text(x + math.max(0, math.floor((width - text_width(text)) / 2)), y, text, { color = color or BLACK })
end

local function right(g, x, y, value, color)
  local text = tostring(value or "")
  g:text(x - text_width(text), y, text, { color = color or BLACK })
end

local function equal_cell(index, count)
  local x = CONTENT_LEFT + math.floor((index - 1) * CONTENT_WIDTH / count)
  local next_x = CONTENT_LEFT + math.floor(index * CONTENT_WIDTH / count)
  return x, next_x - x
end

local function rounded_fill(g, x, y, width, height, radius, color)
  g:rect(x + radius, y, width - radius * 2, height,{fill=true,color=color})
  g:rect(x, y + radius, width, height - radius * 2,{fill=true,color=color})
  g:circle(x + radius, y + radius, radius,{fill=true,color=color})
  g:circle(x + width - radius - 1, y + radius, radius,{fill=true,color=color})
  g:circle(x + radius, y + height - radius - 1, radius,{fill=true,color=color})
  g:circle(x + width - radius - 1, y + height - radius - 1, radius,{fill=true,color=color})
end

local function rounded_button(g, x, y, width, height, selected)
  local radius = 9
  rounded_fill(g, x, y, width, height, radius, BLACK)
  if not selected then rounded_fill(g, x + 2, y + 2, width - 4, height - 4, radius - 2, WHITE) end
end

local function dotted_rule(g, x, y, width)
  for px = x, x + width, 9 do
    watchdog_checkpoint()
    g:rect(px, y, 2, 2,{fill=true,color=BLACK})
  end
end

local function short_text(value, max_chars)
  local text, output, count, index = tostring(value or ""), {}, 0, 1
  while index <= #text and count < max_chars do
    local byte = text:byte(index)
    local length = byte >= 0xE0 and 3 or (byte >= 0xC0 and 2 or 1)
    output[#output + 1] = text:sub(index, index + length - 1)
    index, count = index + length, count + 1
  end
  if index <= #text then output[#output + 1] = "..." end
  return table.concat(output)
end

local function split_fields(line)
  local result, start = {}, 1
  while true do
    local position = line:find("\t", start, true)
    if not position then result[#result + 1] = line:sub(start); break end
    result[#result + 1] = line:sub(start, position - 1)
    start = position + 1
  end
  return result
end

local function parse_dashboard(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= WEATHER_PROTOCOL then return nil end
  local data = { hourly = {}, daily = {}, aqi_days = {}, alerts = {}, indices = {}, limits = {} }
  for line in body:gmatch("[^\r\n]+") do
    watchdog_checkpoint()
    local f = split_fields(line)
    if f[1] == "city" then
      data.city = { id = tonumber(f[2]), name = f[3], province = f[4], country = f[5], timezone = f[6] }
    elseif f[1] == "condition" then
      data.condition = {
        id = f[2], name = f[3], icon = f[4], temp = f[5], feel = f[6], humidity = f[7], pressure = f[8],
        visibility = f[9], uvi = f[10], wind_dir = f[11], wind_level = f[12], wind_speed = f[13],
        sunrise = f[14], sunset = f[15], updated = f[16], tips = f[17],
      }
    elseif f[1] == "hour" then
      data.hourly[#data.hourly + 1] = {
        date = f[2], hour = f[3], id = f[4], name = f[5], temp = f[6], feel = f[7], humidity = f[8],
        pop = f[9], rain = f[10], wind_dir = f[11], wind_level = f[12], wind_speed = f[13], day_icon = f[14], night_icon = f[15],
      }
    elseif f[1] == "day" then
      data.daily[#data.daily + 1] = {
        date = f[2], day_id = f[3], day_name = f[4], night_id = f[5], night_name = f[6], high = f[7], low = f[8],
        humidity = f[9], pop = f[10], rain = f[11], day_wind = f[12], day_level = f[13], night_wind = f[14], night_level = f[15],
        sunrise = f[16], sunset = f[17],
      }
    elseif f[1] == "aqi" then
      data.aqi = { value = f[2], rank = f[3], pm25 = f[4], pm10 = f[5], o3 = f[6], no2 = f[7], so2 = f[8], co = f[9], updated = f[10] }
    elseif f[1] == "aqi_day" then
      data.aqi_days[#data.aqi_days + 1] = { date = f[2], value = f[3], updated = f[4] }
    elseif f[1] == "alert" then
      data.alerts[#data.alerts + 1] = { id = f[2], title = f[3], level = f[4], published = f[5], content = f[6] }
    elseif f[1] == "index" then
      data.indices[#data.indices + 1] = { date = f[2], code = f[3], name = f[4], level = f[5], status = f[6], desc = f[7] }
    elseif f[1] == "limit" then
      data.limits[#data.limits + 1] = { date = f[2], prompt = f[3] }
    end
  end
  if not data.city or not data.condition or #data.hourly == 0 or #data.daily == 0 then return nil end
  return data
end

local function parse_locations(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= LOCATION_PROTOCOL then return nil end
  local data = { items = {}, page = 1, total_pages = 1, total = 0 }
  for line in body:gmatch("[^\r\n]+") do
    watchdog_checkpoint()
    local f = split_fields(line)
    if f[1] == "parent" then data.parent = f[2]
    elseif f[1] == "page" then data.page = tonumber(f[2]) or 1
    elseif f[1] == "total_pages" then data.total_pages = tonumber(f[2]) or 1
    elseif f[1] == "total" then data.total = tonumber(f[2]) or 0
    elseif f[1] == "item" then
      data.items[#data.items + 1] = {
        token = f[2], name = f[3], subtitle = f[4], city_id = tonumber(f[5]), has_children = f[6] == "1",
      }
    end
  end
  if not data.parent then return nil end
  return data
end

local function weather_key(name, large)
  local text = tostring(name or "")
  local kind = "cloud"
  if text:find("雷", 1, true) then kind = "storm"
  elseif text:find("雪", 1, true) or text:find("冰", 1, true) then kind = "snow"
  elseif text:find("雨", 1, true) then kind = "rain"
  elseif text:find("雾", 1, true) or text:find("霾", 1, true) or text:find("沙", 1, true) or text:find("尘", 1, true) then kind = "mist"
  elseif text:find("风", 1, true) then kind = "wind"
  elseif text:find("晴", 1, true) then kind = "sun"
  end
  return "weather_" .. kind .. (large and "_l" or "_s")
end

local TEMP_WIDTHS = { ["-"] = 42, ["°"] = 32 }
for digit = 0, 9 do TEMP_WIDTHS[tostring(digit)] = 58 end

local function big_number_width(text, degree)
  local width = 0
  for index = 1, #text do width = width + (TEMP_WIDTHS[text:sub(index, index)] or 58) end
  if degree then width = width + TEMP_WIDTHS["°"] end
  return width
end

local function draw_big_number(g, center_x, y, value, degree)
  local number = tonumber(value)
  local rounded = number and (number >= 0 and math.floor(number + 0.5) or math.ceil(number - 0.5))
  local text = rounded and tostring(rounded) or "--"
  local x = math.floor(center_x - big_number_width(text, degree) / 2)
  for index = 1, #text do
    local character = text:sub(index, index)
    local key = character == "-" and "temp_minus" or ("temp_" .. character)
    PkgImage.draw(g, key, x, y)
    x = x + (TEMP_WIDTHS[character] or 58)
  end
  if degree then PkgImage.draw(g, "temp_degree", x, y) end
end

local function request_weather(ctx)
  local s = app_state(ctx)
  if task_id then return end
  if not ctx.net then s.status = "no_net"; ctx:invalidate(); return end
  local id, err = ctx.net:request({ url = WEATHER_API .. tostring(s.city_id) }, on_net_done)
  if not id then s.status = tostring(err or "error"); ctx:invalidate(); return end
  task_id, task_kind, s.status, s.auto_elapsed = id, "weather", "loading", 0
  ctx:invalidate()
end

local function toggle_auto_refresh(ctx)
  local s = app_state(ctx)
  s.auto_refresh = not s.auto_refresh
  s.auto_elapsed = 0
  ctx:invalidate()
end

local function cancel_task(ctx)
  if task_id and ctx.net then task_id:cancel() end
  task_id, task_kind = nil, nil
end

local function request_locations(ctx, parent, page, restore_index)
  local s = app_state(ctx)
  cancel_task(ctx)
  if not ctx.net then s.picker_status = "no_net"; ctx:invalidate(); return end
  local url = LOCATION_API .. tostring(parent) .. "&page=" .. tostring(page or 1) .. "&page_size=7"
  local id, err = ctx.net:request({ url = url }, on_net_done)
  if not id then s.picker_status = tostring(err or "error"); ctx:invalidate(); return end
  s.picker_parent, s.picker_page = parent, page or 1
  s.picker_restore_index, s.picker_items, s.picker_status = restore_index or 1, {}, "loading"
  task_id, task_kind = id, "locations"
  ctx:invalidate()
end

local function tab_index_at(x)
  if x < 160 then return 1 elseif x < 320 then return 2 else return 3 end
end

local function switch_tab(ctx, index)
  local s = app_state(ctx)
  s.tab = math.max(1, math.min(#TABS, index))
  ctx:invalidate()
end

local function open_picker(ctx)
  local s = app_state(ctx)
  s.picker_open, s.picker_label, s.picker_stack, s.picker_breadcrumb = true, "选择省份", {}, {}
  request_locations(ctx, "0", 1, 1)
end

local function breadcrumb_copy(values)
  local result = {}
  for index, value in ipairs(values or {}) do result[index] = value end
  return result
end

local function picker_change_page(ctx, delta)
  local s = app_state(ctx)
  local page = math.max(1, math.min(s.picker_total_pages or 1, (s.picker_page or 1) + delta))
  if page ~= s.picker_page then request_locations(ctx, s.picker_parent, page, 1) end
end

local function picker_back(ctx)
  local s = app_state(ctx)
  if #s.picker_stack == 0 then
    cancel_task(ctx)
    s.picker_open = false
    ctx:invalidate()
    return
  end
  local previous = table.remove(s.picker_stack)
  s.picker_label = previous.label
  s.picker_breadcrumb = previous.breadcrumb
  request_locations(ctx, previous.parent, previous.page, previous.index)
end

local function picker_enter(ctx)
  local s = app_state(ctx)
  local item = s.picker_items[s.picker_index]
  if not item then return end
  if item.has_children then
    s.picker_stack[#s.picker_stack + 1] = {
      parent = s.picker_parent, page = s.picker_page, index = s.picker_index,
      label = s.picker_label, breadcrumb = breadcrumb_copy(s.picker_breadcrumb),
    }
    if s.picker_breadcrumb[#s.picker_breadcrumb] ~= item.name then
      s.picker_breadcrumb[#s.picker_breadcrumb + 1] = item.name
    end
    s.picker_label = item.name
    request_locations(ctx, item.token, 1, 1)
    return
  end
  if not item.city_id then return end
  local path = breadcrumb_copy(s.picker_breadcrumb)
  if path[#path] ~= item.name then path[#path + 1] = item.name end
  local changed = s.city_id ~= item.city_id
  s.city_id, s.city_name, s.city_path = item.city_id, item.name, table.concat(path, " ")
  s.picker_open, s.forecast_offset = false, 1
  if changed then
    s.data, s.status = nil, "idle"
    request_weather(ctx)
  else ctx:invalidate() end
end

function on_load(ctx)
  request_weather(ctx)
end

function on_tick(ctx, dt)
  local s = app_state(ctx)
  if s.auto_refresh then
    s.auto_elapsed = s.auto_elapsed + math.max(0, tonumber(dt) or 0)
    if s.auto_elapsed >= AUTO_REFRESH_SECONDS and not task_id and not s.picker_open then
      request_weather(ctx)
    end
  end
end

on_net_done = function(ctx, result)
  local s = app_state(ctx)
  local kind = task_kind
  task_id, task_kind = nil, nil
  if kind == "locations" then
    local parsed = result.ok and run_protected_callback(ctx, function()
      return parse_locations(result.body)
    end) or nil
    if parsed then
      s.picker_items, s.picker_page, s.picker_total_pages, s.picker_total = parsed.items, parsed.page, parsed.total_pages, parsed.total
      s.picker_index = math.max(0, math.min(#parsed.items, s.picker_restore_index or 1))
      s.picker_restore_index, s.picker_status = nil, "ready"
    else s.picker_status = tostring(result.err or result.status or "error") end
  else
    local parsed = result.ok and run_protected_callback(ctx, function()
      return parse_dashboard(result.body)
    end) or nil
    if parsed then s.data, s.status = parsed, "ready" else s.status = tostring(result.err or result.status or "error") end
  end
  ctx:invalidate()
end

function on_leave(ctx)
  cancel_task(ctx)
end

function on_input(ctx, ev)
  local s = app_state(ctx)
  if s.picker_open then
    if ev.type == "key" and ev.phase == "down" then
      if ev.key == "up" then s.picker_index = math.max(0, s.picker_index - 1)
      elseif ev.key == "down" then s.picker_index = math.min(#s.picker_items, s.picker_index + 1)
      elseif ev.key == "left" then picker_change_page(ctx, -1); return true
      elseif ev.key == "right" then picker_change_page(ctx, 1); return true
      elseif ev.key == "ok" then
        if s.picker_index == 0 then toggle_auto_refresh(ctx) else picker_enter(ctx) end
        return true
      elseif ev.key == "back" then picker_back(ctx); return true
      else return false end
      ctx:invalidate(); return true
    end
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "swipe_left" then picker_change_page(ctx, 1); return true end
      if ev.gesture == "swipe_right" then picker_change_page(ctx, -1); return true end
      if ev.gesture == "tap" then
        local x, y = ev.x or 0, ev.y or 0
        if y < 58 then picker_back(ctx); return true end
        if y >= 646 then picker_change_page(ctx, x < 240 and -1 or 1); return true end
        if y >= 108 and y < 172 then
          s.picker_index = 0
          toggle_auto_refresh(ctx)
          return true
        end
        local index = math.floor((y - 180) / 64) + 1
        if index >= 1 and index <= #s.picker_items then s.picker_index = index; picker_enter(ctx); return true end
      end
    end
    return false
  end

  if ev.type == "key" and ev.phase == "down" then
    if ev.key == "left" then switch_tab(ctx, s.tab - 1); return true end
    if ev.key == "right" then switch_tab(ctx, s.tab + 1); return true end
    if ev.key == "ok" then open_picker(ctx); return true end
    if ev.key == "up" then
      if s.tab == 2 and s.forecast_offset > 1 then s.forecast_offset = s.forecast_offset - 1; ctx:invalidate()
      elseif not s.auto_refresh or not s.data then request_weather(ctx) end
      return true
    end
    if ev.key == "down" and s.tab == 2 then s.forecast_offset = math.min(6, s.forecast_offset + 1); ctx:invalidate(); return true end
    if ev.key == "back" then ctx:quit(); return true end
  end

  if (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture == "swipe_left" then switch_tab(ctx, s.tab + 1); return true end
    if ev.gesture == "swipe_right" then switch_tab(ctx, s.tab - 1); return true end
    if s.tab == 2 and ev.gesture == "swipe_up" then s.forecast_offset = math.min(6, s.forecast_offset + 1); ctx:invalidate(); return true end
    if s.tab == 2 and ev.gesture == "swipe_down" then s.forecast_offset = math.max(1, s.forecast_offset - 1); ctx:invalidate(); return true end
    if ev.gesture == "tap" then
      local x, y = ev.x or 0, ev.y or 0
      if y >= 752 then switch_tab(ctx, tab_index_at(x)); return true end
      if y <= 64 and x >= 366 then
        if not s.auto_refresh then request_weather(ctx) end
        return true
      end
      if y <= 64 then open_picker(ctx); return true end
    end
  end
  return false
end

local function draw_header(g, s, title)
  center(g, 96, 24, 288, short_text(title or s.city_name, 12), BLACK)
  if not s.auto_refresh then right(g, 456, 24, s.status == "loading" and "更新中" or "更新", BLACK) end
end

local function draw_tabs(g, selected)
  local y, width = 756, 144
  for index, label in ipairs(TABS) do
    local x = 16 + (index - 1) * 152
    rounded_button(g, x, y, width, 36, index == selected)
    center(g, x, y + 10, width, label, index == selected and WHITE or BLACK)
  end
end

local function high_low_text(day)
  if not day then return "最高 --  最低 --" end
  return "最高 " .. tostring(day.high or "--") .. "°  最低 " .. tostring(day.low or "--") .. "°"
end

local function hour_label(hour, index)
  if index == 1 then return "现在" end
  local value = tonumber(hour)
  return value and string.format("%02d时", value) or "--"
end

local function draw_hourly(g, data)
  g:text(24, 264, "逐小时", { color = BLACK })
  local first = data.hourly[1]
  right(g, 456, 264, first and ((tonumber(first.pop) or 0) > 0 and (first.pop .. "% 降水") or "未来 24 小时") or "--", BLACK)
  for index = 1, 6 do
    local row = data.hourly[index]
    local x, width = equal_cell(index, 6)
    if row then
      center(g, x, 300, width, hour_label(row.hour, index), BLACK)
      PkgImage.draw(g, weather_key(row.name, false), x + math.floor((width - 28) / 2), 326)
      center(g, x + NUMBER_OPTICAL_SHIFT, 364, width, tostring(row.temp or "--") .. "°", BLACK)
    end
  end
end

local function draw_temperature_range(g, rows, index, y)
  local row = rows[index]
  if not row then return end
  local global_low, global_high = nil, nil
  for scan = 1, math.min(5, #rows) do
    local low, high = tonumber(rows[scan].low), tonumber(rows[scan].high)
    if low and high then
      global_low = global_low and math.min(global_low, low) or low
      global_high = global_high and math.max(global_high, high) or high
    end
  end
  local low, high = tonumber(row.low), tonumber(row.high)
  if global_low and global_high and low and high then
    local span = math.max(1, global_high - global_low)
    local start_x = 258 + math.floor((low - global_low) * 98 / span)
    local end_x = 258 + math.floor((high - global_low) * 98 / span)
    if end_x - start_x < 12 then end_x = start_x + 12 end
    g:line(start_x, y + 12, end_x, y + 12,{color=BLACK})
    g:line(start_x, y + 13, end_x, y + 13,{color=BLACK})
  end
end

local function draw_daily_preview(g, data)
  g:text(24, 410, "未来五天", { color = BLACK })
  right(g, 456, 410, "左右切换查看更多", BLACK)
  for index = 1, math.min(5, #data.daily) do
    local row, y = data.daily[index], 446 + (index - 1) * 48
    local date = index == 1 and "今天" or ((row.date or ""):sub(6, 10):gsub("-", "/"))
    g:text(24, y + 7, date, { color = BLACK })
    PkgImage.draw(g, weather_key(row.day_name, false), 118, y)
    right(g, 232, y + 7, tostring(row.low or "--") .. "°", BLACK)
    draw_temperature_range(g, data.daily, index, y)
    right(g, 456, y + 7, tostring(row.high or "--") .. "°", BLACK)
  end
end

local function draw_metrics(g, data)
  local condition, aqi = data.condition, data.aqi or {}
  dotted_rule(g, CONTENT_LEFT, 690, CONTENT_WIDTH)
  local metrics = {
    { "metric_thermometer", "体感", tostring(condition.feel or "--") .. "°" },
    { "metric_droplet", "湿度", tostring(condition.humidity or "--") .. "%" },
    { "metric_wind", "风力", tostring(condition.wind_level or "--") .. "级" },
    { "metric_umbrella", "空气", tostring(aqi.value or "--") },
  }
  for index, metric in ipairs(metrics) do
    local cell_x, cell_width = equal_cell(index, #metrics)
    local label_width = text_width(metric[2])
    local label_group_width = 24 + 6 + label_width
    local group_x = math.floor(cell_x + (cell_width - label_group_width) / 2)
    local label_x = group_x + 30
    PkgImage.draw(g, metric[1], group_x, 706)
    g:text(label_x, 706, metric[2], { color = BLACK })
    center(g, label_x + NUMBER_OPTICAL_SHIFT, 732, label_width, metric[3], BLACK)
  end
end

local function draw_now(g, s, data)
  draw_header(g, s, data.city and data.city.name or s.city_name)
  local condition = data.condition
  draw_big_number(g, 184, 70, condition.temp, true)
  PkgImage.draw(g, weather_key(condition.name, true), 318, 78)
  center(g, 24, 174, 432, tostring(condition.name or "--") .. "  " .. high_low_text(data.daily[1]), BLACK)
  center(g, 24, 204, 432, short_text(condition.tips or "", 22), BLACK)
  dotted_rule(g, 24, 246, 432)
  draw_hourly(g, data)
  dotted_rule(g, 24, 396, 432)
  draw_daily_preview(g, data)
  draw_metrics(g, data)
  draw_tabs(g, 1)
end

local function draw_future(g, s, data)
  draw_header(g, s, "15 天预报")
  local start = s.forecast_offset
  local visible = math.min(10, #data.daily - start + 1)
  for slot = 1, visible do
    local index, y = start + slot - 1, 78 + (slot - 1) * 64
    local row = data.daily[index]
    local date = index == 1 and "今天" or ((row.date or ""):sub(6, 10):gsub("-", "/"))
    g:text(24, y + 12, date, { color = BLACK })
    PkgImage.draw(g, weather_key(row.day_name, false), 110, y + 4)
    g:text(150, y + 4, row.day_name or "--", { color = BLACK })
    g:text(150, y + 26, tostring(row.day_wind or "") .. " " .. tostring(row.day_level or "") .. "级", { color = BLACK })
    right(g, 384, y + 13, tostring(row.low or "--") .. "°", BLACK)
    right(g, 456, y + 13, tostring(row.high or "--") .. "°", BLACK)
    if slot < visible then dotted_rule(g, 24, y + 57, 432) end
  end
  if #data.daily > 10 then right(g, 456, 724, tostring(start) .. "-" .. tostring(math.min(#data.daily, start + 9)) .. " / " .. tostring(#data.daily), BLACK) end
  draw_tabs(g, 2)
end

local function aqi_label(value)
  local number = tonumber(value)
  if not number then return "暂无" end
  if number <= 50 then return "优" elseif number <= 100 then return "良" elseif number <= 150 then return "轻度污染"
  elseif number <= 200 then return "中度污染" elseif number <= 300 then return "重度污染" else return "严重污染" end
end

local function today_limit(data)
  local date = data.daily[1] and data.daily[1].date
  for _, row in ipairs(data.limits) do if row.date == date then return row.prompt end end
  return data.limits[1] and data.limits[1].prompt or "--"
end

local function draw_life(g, s, data)
  draw_header(g, s, "生活与空气")
  local aqi = data.aqi or {}
  g:text(24, 84, "空气质量", { color = BLACK })
  draw_big_number(g, 130, 112, aqi.value or "--", false)
  g:text(250, 132, aqi_label(aqi.value), { color = BLACK })
  g:text(250, 160, "PM2.5  " .. tostring(aqi.pm25 or "--"), { color = BLACK })
  g:text(250, 188, "全国排名  " .. tostring(aqi.rank or "--"), { color = BLACK })
  dotted_rule(g, 24, 232, 432)

  g:text(24, 252, "天气预警", { color = BLACK })
  if #data.alerts == 0 then g:text(24, 282, "当前没有生效中的天气预警", { color = BLACK })
  else
    g:text(24, 282, short_text(data.alerts[1].title, 22), { color = BLACK })
    g:text(24, 310, short_text(data.alerts[1].content, 24), { color = BLACK })
  end
  right(g, 456, 252, "今日限行  " .. tostring(today_limit(data)), BLACK)
  dotted_rule(g, 24, 350, 432)

  g:text(24, 370, "生活指数", { color = BLACK })
  for index = 1, math.min(6, #data.indices) do
    local item = data.indices[index]
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local x, y = 24 + column * 224, 410 + row * 70
    g:text(x, y, short_text(item.name, 8), { color = BLACK })
    g:text(x, y + 28, short_text(item.status, 8), { color = BLACK })
  end
  dotted_rule(g, 24, 622, 432)
  g:text(24, 642, "未来空气", { color = BLACK })
  local visible_days = math.min(5, #data.aqi_days)
  for index = 1, visible_days do
    local row = data.aqi_days[index]
    local x, width = equal_cell(index, visible_days)
    center(g, x, 676, width, index == 1 and "今天" or (row.date or ""):sub(6, 10):gsub("-", "/"), BLACK)
    center(g, x, 704, width, tostring(row.value or "--"), BLACK)
  end
  draw_tabs(g, 3)
end

local function draw_picker(g, s)
  g:clear(WHITE)
  g:text(24, 24, #s.picker_stack > 0 and "返回" or "取消", { color = BLACK })
  center(g, 108, 24, 264, short_text(s.picker_label, 12), BLACK)
  right(g, 456, 24, tostring(s.picker_total or 0) .. " 项", BLACK)
  local path = #s.picker_breadcrumb > 0 and table.concat(s.picker_breadcrumb, " / ") or "请选择所在省份"
  center(g, 24, 70, 432, short_text(path, 22), BLACK)
  dotted_rule(g, 24, 104, 432)

  local setting_selected = s.picker_index == 0
  if setting_selected then g:rect(24, 108, 432, 64,{fill=true,color=BLACK}) end
  g:text(42, 118, "半小时自动更新", { color = setting_selected and WHITE or BLACK })
  g:text(42, 146, "开启后隐藏右上角更新按钮", { color = setting_selected and WHITE or BLACK })
  if setting_selected then
    right(g, 438, 132, s.auto_refresh and "已开启" or "已关闭", WHITE)
  elseif s.auto_refresh then
    g:rect(368, 122, 70, 34,{fill=true,color=BLACK})
    center(g, 368, 132, 70, "开启", WHITE)
  else
    g:rect(368, 122, 70, 34,{color=BLACK})
    center(g, 368, 132, 70, "关闭", BLACK)
  end

  if s.picker_status == "loading" then
    center(g, 24, 376, 432, "正在读取地区", BLACK)
  elseif s.picker_status ~= "ready" then
    center(g, 24, 376, 432, s.picker_status == "no_net" and "当前固件未提供联网能力" or "地区列表暂时不可用", BLACK)
    center(g, 24, 418, 432, "按 BACK 返回后重试", BLACK)
  end

  for index, item in ipairs(s.picker_items) do
    local y = 180 + (index - 1) * 64
    local selected = index == s.picker_index
    if selected then g:rect(24, y, 432, 58,{fill=true,color=BLACK}) end
    g:text(42, y + 8, short_text(item.name, 14), { color = selected and WHITE or BLACK })
    if item.subtitle and item.subtitle ~= "" then
      g:text(42, y + 32, short_text(item.subtitle, 18), { color = selected and WHITE or BLACK })
    end
    right(g, 438, y + 18, item.has_children and "进入" or "选择", selected and WHITE or BLACK)
    if not selected and index < #s.picker_items then dotted_rule(g, 24, y + 61, 432) end
  end
  dotted_rule(g, 24, 636, 432)
  g:text(24, 660, s.picker_page > 1 and "上一页" or "", { color = BLACK })
  center(g, 160, 660, 160, tostring(s.picker_page or 1) .. " / " .. tostring(s.picker_total_pages or 1), BLACK)
  right(g, 456, 660, s.picker_page < s.picker_total_pages and "下一页" or "", BLACK)
  center(g, 24, 718, 432, "上下选择  左右翻页  OK 确认", BLACK)
end

local function draw_weather(ctx, g)
  local s = app_state(ctx)
  g:clear(WHITE)
  if s.picker_open then draw_picker(g, s); return end
  if not s.data then
    draw_header(g, s, s.city_name)
    PkgImage.draw(g, "weather_cloud_l", 196, 250)
    center(g, 24, 366, 432, s.status == "loading" and "正在读取天气" or (s.status == "no_net" and "当前固件未提供联网能力" or "天气服务暂时不可用"), BLACK)
    center(g, 24, 404, 432, "按上键重试，OK 可切换城市", BLACK)
    draw_tabs(g, s.tab)
    return
  end
  if s.tab == 1 then draw_now(g, s, s.data)
  elseif s.tab == 2 then draw_future(g, s, s.data)
  else draw_life(g, s, s.data) end
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  run_protected_callback(ctx, function()
    draw_weather(ctx, g)
  end)
end
