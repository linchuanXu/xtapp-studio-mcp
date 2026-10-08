-- 飞书日历：X4 Pro 触屏日历。运行前表单注入用户名和专用密码。
local Time = require("domain.calendar_time")
local Events = require("domain.calendar_events")
local Layout = require("ui.calendar_layout")
local Theme = require("ui.calendar_theme")
local Views = require("ui.calendar_views")

local CONFIG = {
  backend_url = "http://193.112.174.92:28473/demo/calendar/xtapp",
  server = "https://caldav.feishu.cn",
  username = "__APP_CONFIG_FEISHU_USERNAME__",
  password = "__APP_CONFIG_FEISHU_PASSWORD__",
}

local CONTENT_LEFT = Layout.CONTENT_LEFT
local TAB_Y, TAB_H = Layout.TAB_Y, Layout.TAB_H
local REFRESH_MIN_MINUTES, REFRESH_DEFAULT_MINUTES = 10, 60
local REFRESH_MAX_MINUTES, REFRESH_STEP_MINUTES = 360, 10
local VIEWS = {
  { id = "day", label = "日" },
  { id = "week", label = "周" },
  { id = "month", label = "月" },
  { id = "agenda", label = "日程" },
}
local hit = Layout.hit
local WATCHDOG_FEED_INTERVAL_MS = 1000
local WATCHDOG_MAX_RUNTIME_MS = 4000

-- 进入、首帧绘制和 TSV 解析都可能超过短回调预算。
-- 固件长任务只保护当前回调：start 后约每秒 feed，正常完成不得 stop。
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
  if type(ctx) ~= "table" or type(ctx.longtask) ~= "table"
    or type(ctx.longtask.start) ~= "function" then
    return nil, "disabled"
  end
  local ok, err = ctx.longtask:start()
  if ok ~= true then return nil, err or "disabled" end
  local now = ctx.sys:millis()
  LongCallback.ctx = ctx
  LongCallback.started_ms = now
  LongCallback.last_feed_ms = now
  LongCallback.max_runtime_ms = math.max(100, math.min(10000, math.floor(tonumber(max_runtime_ms) or WATCHDOG_MAX_RUNTIME_MS)))
  return true
end

local function watchdog_checkpoint()
  local ctx = LongCallback.ctx
  if not ctx then return true end
  local now = ctx.sys:millis()
  if watchdog_elapsed(now, LongCallback.started_ms) >= LongCallback.max_runtime_ms then
    error("calendar callback exceeded app time budget", 0)
  end
  if watchdog_elapsed(now, LongCallback.last_feed_ms) >= WATCHDOG_FEED_INTERVAL_MS then
    if type(ctx.longtask.feed) ~= "function" then error("watchdog feed failed: inactive", 0) end
    local ok, err = ctx.longtask:feed()
    if ok ~= true then error("watchdog feed failed: " .. tostring(err or "inactive"), 0) end
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

Views.checkpoint = watchdog_checkpoint

local function configured()
  return CONFIG.username ~= "" and CONFIG.username ~= "__APP_CONFIG_FEISHU_USERNAME__"
    and CONFIG.password ~= "" and CONFIG.password ~= "__APP_CONFIG_FEISHU_PASSWORD__"
end

local function url_encode(value)
  return tostring(value):gsub("[^%w%-_%.~]", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function clamp_refresh_minutes(value)
  local minutes = math.floor((tonumber(value) or REFRESH_DEFAULT_MINUTES) / REFRESH_STEP_MINUTES) * REFRESH_STEP_MINUTES
  if minutes < REFRESH_MIN_MINUTES then return REFRESH_MIN_MINUTES end
  if minutes > REFRESH_MAX_MINUTES then return REFRESH_MAX_MINUTES end
  return minutes
end

local function now_sec(ctx)
  if ctx.sys and ctx.sys.epoch_sec then
    local epoch = ctx.sys:epoch_sec()
    if type(epoch) == "number" then return epoch end
  end
  if ctx.sys and ctx.sys.millis then
    local ms = ctx.sys:millis()
    if type(ms) == "number" then return ms / 1000 end
  end
  return nil
end

local function apply_tick_rate(ctx, s)
  if s.task then ctx:set_tick_rate("normal")
  elseif s.auto_refresh then ctx:set_tick_rate("low")
  else ctx:set_tick_rate("idle") end
end

local function mark_fetch(ctx, s)
  s.last_fetch_sec = now_sec(ctx)
  s.auto_elapsed_ms = 0
end

local function device_clock(ctx)
  local clock = ctx.sys and ctx.sys.clock and ctx.sys:clock() or nil
  if type(clock) ~= "table" or clock.valid ~= true or clock.year == nil or clock.month == nil or clock.day == nil or clock.hour == nil or clock.minute == nil then
    return { has_clock = false, year = 2026, month = 9, day = 4 }
  end
  return {
    has_clock = true,
    year = clock.year,
    month = clock.month,
    day = clock.day,
    hour = clock.hour,
    minute = clock.minute,
    epoch = clock.epoch_sec,
  }
end

local function device_today(ctx)
  local clock = device_clock(ctx)
  return clock.year, clock.month, clock.day
end

local function freshness_text(ctx, s)
  if s.task then return "正在更新" end
  local stamp = Time.hms_from_epoch(s.last_ok_sec)
  if not stamp then
    if s.stale then return "仍显示上次" end
    return ""
  end
  local hm = Time.pad2(stamp.hour) .. ":" .. Time.pad2(stamp.minute)
  if s.stale then return hm .. " · 已过期" end
  return hm .. " 已更新"
end

local function state(ctx)
  local s = ctx.state
  if s.view == nil then s.view = 1 end
  if s.status == nil then s.status = configured() and "准备读取日历" or "请先填写配置" end
  if s.events == nil then s.events = {} end
  if s.offset == nil then s.offset = 1 end
  if s.detail == nil then s.detail = 0 end
  if s.settings == nil then s.settings = 0 end
  if s.auto_refresh == nil then s.auto_refresh = true end
  s.theme = Theme.normalize(s.theme)
  s.refresh_minutes = clamp_refresh_minutes(s.refresh_minutes)
  if s.auto_elapsed_ms == nil then s.auto_elapsed_ms = 0 end
  local clock = device_clock(ctx)
  s.has_clock = clock.has_clock
  if s.year == nil then s.year, s.month, s.day = clock.year, clock.month, clock.day end
  if clock.has_clock and Time.same_day(s.year, s.month, s.day, clock.year, clock.month, clock.day) then
    s.now = { hour = clock.hour, minute = clock.minute }
  else
    s.now = nil
  end
  if s.sample then
    s.freshness = "示例 · " .. Theme.label(s)
  else
    s.freshness = freshness_text(ctx, s)
  end
  return s
end

local function ensure_demo(s)
  if configured() then
    if s.sample then s.sample = false end
    return false
  end
  s.events = Events.sample(s.year, s.month, s.day)
  s.sample = true
  s.stale = false
  s.status = "示例日程，填写账号后读取飞书"
  return true
end

local function view_id(s)
  return Layout.view_id(s)
end

local function request_body(s, force)
  local from, to = Events.fetch_range(s, view_id(s))
  if not from or not to then return nil end
  local body = "server=" .. url_encode(CONFIG.server)
    .. "&username=" .. url_encode(CONFIG.username)
    .. "&password=" .. url_encode(CONFIG.password)
    .. "&from=" .. url_encode(from)
    .. "&to=" .. url_encode(to)
  if force then body = body .. "&refresh=1" end
  return body, from, to
end

local function start_request(ctx, force)
  local s = state(ctx)
  if s.task ~= nil then return end
  if not configured() then
    ensure_demo(s)
    ctx:invalidate()
    return
  end
  local body, from, to = request_body(s, force)
  if not body then
    s.status = "设备时间未校准"
    ctx:invalidate()
    return
  end
  if not force and Events.range_covers(s.cache_from, s.cache_to, from, to) then
    ctx:invalidate()
    return
  end
  local task, err = ctx.net:post(CONFIG.backend_url, body, {
    ["Content-Type"] = "application/x-www-form-urlencoded",
  })
  if task == nil then
    s.status = "请求启动失败"
    ctx:invalidate()
    return
  end
  s.pending_from, s.pending_to = from, to
  s.task, s.status = task, "正在读取飞书日历"
  mark_fetch(ctx, s)
  apply_tick_rate(ctx, s)
  ctx:invalidate()
end

local function parse_response(s, body)
  local events, calendars = Events.parse(body, watchdog_checkpoint)
  s.events, s.calendars = events, calendars
  if type(s.offset) ~= "number" or s.offset < 1 then s.offset = 1 end
  if s.detail > #events then s.detail = 0 end
  s.cache_from, s.cache_to = s.pending_from, s.pending_to
  s.sample = false
  s.stale = false
  if #events == 0 then
    s.status = "没有日程"
  elseif calendars > 0 then
    s.status = "读取完成，" .. tostring(calendars) .. " 个日历 · " .. tostring(#events) .. " 条"
  else
    s.status = "读取完成，共 " .. tostring(#events) .. " 条"
  end
end

local function shift_cursor(s, direction)
  local id = view_id(s)
  if id == "day" then
    s.year, s.month, s.day = Time.shift_date(s.year, s.month, s.day, direction)
  elseif id == "week" then
    s.year, s.month, s.day = Time.shift_date(s.year, s.month, s.day, direction * 7)
  elseif id == "agenda" then
    s.year, s.month, s.day = Time.shift_date(s.year, s.month, s.day, direction * 30)
  else
    s.year, s.month, s.day = s.year, s.month + direction, 1
    if s.month > 12 then s.year, s.month = s.year + 1, 1 end
    if s.month < 1 then s.year, s.month = s.year - 1, 12 end
  end
  s.offset, s.detail = 1, 0
end

local function go_today(ctx)
  local s = state(ctx)
  s.year, s.month, s.day = device_today(ctx)
  s.offset, s.detail = 1, 0
end

local function open_day(ctx, year, month, day)
  local s = state(ctx)
  s.year, s.month, s.day = year, month, day
  s.view, s.offset, s.detail = 1, 1, 0
  start_request(ctx)
end

local function open_item_at(s, x, y)
  local index = Layout.item_at(s, x, y)
  if not index then return false end
  s.detail = index
  return true
end

local function handle_settings_tap(ctx, x, y)
  local s = state(ctx)
  local layout = Layout.settings_layout(s)
  if hit(x, y, layout.back.x, layout.back.y, layout.back.w, layout.back.h) then
    s.settings = 0
    ctx:invalidate()
    return true
  end
  for _, chip in ipairs(layout.themes) do
    if hit(x, y, chip.x, chip.y, chip.w, chip.h) then
      s.theme = chip.id
      ctx:invalidate()
      return true
    end
  end
  if hit(x, y, layout.auto.x, layout.auto.y, layout.auto.w, layout.auto.h) then
    s.auto_refresh = not s.auto_refresh
    mark_fetch(ctx, s)
    apply_tick_rate(ctx, s)
    ctx:invalidate()
    return true
  end
  if hit(x, y, layout.minus.x, layout.minus.y, layout.minus.w, layout.minus.h) then
    s.refresh_minutes = clamp_refresh_minutes(s.refresh_minutes - REFRESH_STEP_MINUTES)
    ctx:invalidate()
    return true
  end
  if hit(x, y, layout.plus.x, layout.plus.y, layout.plus.w, layout.plus.h) then
    s.refresh_minutes = clamp_refresh_minutes(s.refresh_minutes + REFRESH_STEP_MINUTES)
    ctx:invalidate()
    return true
  end
  return true
end

local function maybe_auto_refresh(ctx, s, dt_ms)
  if not s.auto_refresh or s.task ~= nil or not configured() then return end
  local interval = clamp_refresh_minutes(s.refresh_minutes) * 60
  local now = now_sec(ctx)
  if now then
    if type(s.last_fetch_sec) ~= "number" then
      s.last_fetch_sec = now
      return
    end
    if now - s.last_fetch_sec >= interval then start_request(ctx, true) end
    return
  end
  s.auto_elapsed_ms = (tonumber(s.auto_elapsed_ms) or 0) + math.max(0, tonumber(dt_ms) or 0)
  if s.auto_elapsed_ms >= interval * 1000 then start_request(ctx, true) end
end

local function handle_chrome_tap(ctx, x, y)
  local s = state(ctx)
  local chrome = Views.chrome(s)
  if hit(x, y, chrome.settings_x - 8, 16, 44, 48) then
    s.settings, s.detail = 1, 0
    ctx:invalidate()
    return true
  end
  if hit(x, y, chrome.refresh_x - 8, 16, 48, 48) then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    start_request(ctx, true)
    return true
  end
  if hit(x, y, chrome.prev_x - 8, 16, 40, 48) then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    shift_cursor(s, -1)
    start_request(ctx)
    return true
  end
  if hit(x, y, chrome.next_x - 4, 16, 40, 48) then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    shift_cursor(s, 1)
    start_request(ctx)
    return true
  end
  if hit(x, y, chrome.today_x, chrome.today_y - 4, chrome.today_w, chrome.today_h + 8) then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    go_today(ctx)
    start_request(ctx)
    return true
  end
  if #Layout.visible_items(s) == 0 and not s.task and hit(x, y, 180, Layout.retry_top(s), 120, 44) then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    start_request(ctx, true)
    return true
  end
  for index, _ in ipairs(VIEWS) do
    local tab_x = CONTENT_LEFT + (index - 1) * 108
    if hit(x, y, tab_x, TAB_Y, 108, TAB_H) then
      if s.view ~= index then
        if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
        s.view, s.offset, s.detail = index, 1, 0
        start_request(ctx)
      end
      return true
    end
  end
  if view_id(s) == "week" then
    for _, row in ipairs(Layout.week_rows(s)) do
      if hit(x, y, row.x, row.y, row.w, row.h) then
        open_day(ctx, row.year, row.month, row.day)
        return true
      end
    end
  end
  if view_id(s) == "month" then
    for _, cell in ipairs(Layout.month_cells(s)) do
      if hit(x, y, cell.x, cell.y, cell.w, cell.h) then
        if cell.day == s.day then
          open_day(ctx, s.year, s.month, cell.day)
        else
          s.day, s.offset, s.detail = cell.day, 1, 0
          ctx:invalidate()
        end
        return true
      end
    end
    local heading = Layout.month_heading(s)
    if hit(x, y, heading.x, heading.y, heading.w, heading.h) then
      open_day(ctx, s.year, s.month, s.day)
      return true
    end
  end
  if open_item_at(s, x, y) then
    ctx:invalidate()
    return true
  end
  return false
end

function on_load(ctx) state(ctx) end

function on_enter(ctx)
  run_protected_callback(ctx, function()
    local s = state(ctx)
    local clock = device_clock(ctx)
    if clock.has_clock then
      s.year, s.month, s.day = clock.year, clock.month, clock.day
    elseif s.year == nil then
      s.year, s.month, s.day = clock.year, clock.month, clock.day
    end
    s.offset, s.detail = 1, 0
    apply_tick_rate(ctx, s)
    start_request(ctx)
    ctx:invalidate()
  end)
end

function on_tick(ctx, dt_ms)
  local s = state(ctx)
  maybe_auto_refresh(ctx, s, dt_ms)
  apply_tick_rate(ctx, s)
  if s.task == nil then return end
  local result, err = ctx.net:poll(s.task)
  if result == nil then
    s.task = nil
    s.stale = #s.events > 0
    s.status = "请求失败"
    apply_tick_rate(ctx, s)
    ctx:invalidate()
    return
  end
  if not result.done then return end
  s.task = nil
  run_protected_callback(ctx, function()
    if result.ok then
      parse_response(s, result.body or "")
      s.last_ok_sec = now_sec(ctx)
    else
      s.stale = #s.events > 0
      s.status = "读取失败: " .. tostring(Events.response_error(result.body or "") or result.status or "未知错误")
    end
  end)
  apply_tick_rate(ctx, s)
  ctx:invalidate()
end

local handle_input

function on_input(ctx, ev)
  return run_protected_callback(ctx, function()
    return handle_input(ctx, ev)
  end)
end

handle_input = function(ctx, ev)
  local s = state(ctx)
  if ev.type == "touch" then
    if ev.gesture == "tap" then
      if s.settings == 1 then
        handle_settings_tap(ctx, ev.x, ev.y)
        return true
      end
      if s.detail > 0 then
        if hit(ev.x, ev.y, 400, 20, 64, 44) or ev.y < 80 then
          s.detail = 0
          ctx:invalidate()
        end
        return true
      end
      handle_chrome_tap(ctx, ev.x, ev.y)
      return true
    end
    if s.settings == 1 then return true end
    if ev.gesture == "swipe_left" then
      if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
      shift_cursor(s, 1)
      start_request(ctx)
      return true
    end
    if ev.gesture == "swipe_right" then
      if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
      shift_cursor(s, -1)
      start_request(ctx)
      return true
    end
    if ev.gesture == "swipe_up" then
      local items = Layout.visible_items(s)
      s.offset = math.min(#items, s.offset + Layout.card_page(s))
      ctx:invalidate()
      return true
    end
    if ev.gesture == "swipe_down" then
      s.offset = math.max(1, s.offset - Layout.card_page(s))
      ctx:invalidate()
      return true
    end
    return true
  end
  if ev.type ~= "key" or ev.state ~= "down" then return false end
  if ev.key == "back" then
    if s.settings == 1 then s.settings = 0; ctx:invalidate(); return true end
    if s.detail > 0 then s.detail = 0; ctx:invalidate(); return true end
    if s.task ~= nil then ctx.net:cancel(s.task) end
    ctx:quit()
    return true
  end
  if s.settings == 1 then
    if ev.key == "ok" then
      s.auto_refresh = not s.auto_refresh
      mark_fetch(ctx, s)
      apply_tick_rate(ctx, s)
      ctx:invalidate()
      return true
    end
    if ev.key == "up" then
      s.theme = Theme.prev(s.theme)
      ctx:invalidate()
      return true
    end
    if ev.key == "down" then
      s.theme = Theme.next(s.theme)
      ctx:invalidate()
      return true
    end
    if ev.key == "left" then
      s.refresh_minutes = clamp_refresh_minutes(s.refresh_minutes - REFRESH_STEP_MINUTES)
      ctx:invalidate()
      return true
    end
    if ev.key == "right" then
      s.refresh_minutes = clamp_refresh_minutes(s.refresh_minutes + REFRESH_STEP_MINUTES)
      ctx:invalidate()
      return true
    end
    return true
  end
  if ev.key == "left" then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    shift_cursor(s, -1)
    start_request(ctx)
    return true
  end
  if ev.key == "right" then
    if s.task ~= nil then ctx.net:cancel(s.task); s.task = nil end
    shift_cursor(s, 1)
    start_request(ctx)
    return true
  end
  if ev.key == "up" then
    s.offset = math.max(1, s.offset - Layout.card_page(s))
    ctx:invalidate()
    return true
  end
  if ev.key == "down" then
    local items = Layout.visible_items(s)
    s.offset = math.min(math.max(1, #items), s.offset + Layout.card_page(s))
    ctx:invalidate()
    return true
  end
  if ev.key == "ok" then
    if s.detail > 0 then s.detail = 0; ctx:invalidate(); return true end
    local index = Layout.first_visible_event(s)
    if index then s.detail = index; ctx:invalidate() end
    return true
  end
  return false
end

function on_draw(ctx, g)
  run_protected_callback(ctx, function()
    local s = state(ctx)
    s.ty, s.tm, s.td = device_today(ctx)
    g:clear(Theme.paper(s))
    if s.settings == 1 then
      Views.draw_settings(g, s)
      return
    end
    Views.draw(g, s)
  end)
end

function on_leave(ctx)
  local s = state(ctx)
  if s.task ~= nil then ctx.net:cancel(s.task) end
  s.task = nil
end
