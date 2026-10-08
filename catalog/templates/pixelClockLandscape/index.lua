local M = {}
local BLACK = 15
local WHITE = 0
local BUTTON_H = 44
local BACKGROUND = "bg"

local DIGIT_W = 80
local DIGIT_H = 108
local COLON_W = 32
local ITEM_GAP = 12
-- 横版 800x480：HH : MM 单行，数字行水平居中
local TIME_W = DIGIT_W * 4 + COLON_W + ITEM_GAP * 4
local TIME_X = math.floor((800 - TIME_W) / 2)
local TIME_Y = 190

local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local WEEKDAYS = { "日", "一", "二", "三", "四", "五", "六" }

local function clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function is_leap(year)
  return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function month_days(year, month)
  if month == 2 and is_leap(year) then return 29 end
  return MONTH_DAYS[month]
end

local function project_time(ctx)
  local clock = ctx.sys:clock()
  if not clock.valid or clock.year == nil or clock.hour == nil or clock.minute == nil then return nil end
  return { year = clock.year, month = clock.month, day = clock.day, hour = clock.hour, min = clock.minute, sec = clock.second, wday = clock.weekday }
end

local function text_width(text)
  local width, i = 0, 1
  while i <= #text do
    if text:byte(i) >= 0xE0 then width, i = width + 20, i + 3 else width, i = width + 10, i + 1 end
  end
  return width
end

local function center_text(g, x, y, width, text, color)
  g:text(x + math.floor((width - text_width(text)) / 2), y, text, { color = color })
end

-- HH : MM，素材数字与冒号，每项一块白底衬板
local function draw_time(g, parts)
  if parts then
    local hh, mm = parts.hour, parts.min
    local digits = { math.floor(hh / 10), hh % 10, math.floor(mm / 10), mm % 10 }
    local x = TIME_X
    for i = 1, 2 do
      g:rect(x, TIME_Y, DIGIT_W, DIGIT_H, "fill", WHITE)
      g:image(tostring(digits[i]), x, TIME_Y)
      x = x + DIGIT_W + ITEM_GAP
    end
    g:rect(x, TIME_Y, COLON_W, DIGIT_H, "fill", WHITE)
    g:image("colon", x, TIME_Y)
    x = x + COLON_W + ITEM_GAP
    for i = 3, 4 do
      g:rect(x, TIME_Y, DIGIT_W, DIGIT_H, "fill", WHITE)
      g:image(tostring(digits[i]), x, TIME_Y)
      x = x + DIGIT_W + ITEM_GAP
    end
  else
    center_text(g, TIME_X, TIME_Y + 44, TIME_W, "时间未校准", WHITE)
  end
end

local function button_rect(ctx)
  local width = math.min(220, ctx.screen.width - 56)
  return { x = math.floor((ctx.screen.width - width) / 2), y = ctx.screen.height - BUTTON_H - 24, w = width, h = BUTTON_H }
end

function M.draw(ctx, g, show_button)
  local width, height = ctx.screen.width, ctx.screen.height
  g:clear(WHITE)
  g:image(BACKGROUND, 0, 0)
  draw_time(g, project_time(ctx))
  if show_button then
    local rect = button_rect(ctx)
    g:rect(rect.x, rect.y, rect.w, rect.h, "fill", WHITE)
    g:rect(rect.x, rect.y, rect.w, rect.h, "stroke", BLACK)
    center_text(g, rect.x, rect.y + 11, rect.w, ctx.state.clock_status or "设为锁屏", BLACK)
  end
end

local function refresh_key(parts)
  if not parts then return "unsynced" end
  return string.format("%04d%02d%02d%02d%02d", parts.year, parts.month, parts.day, parts.hour, parts.min)
end

function on_enter(ctx)
  ctx.state.pixel_clock = ctx.state.pixel_clock or {}
  ctx.state.pixel_clock.last_key = nil
  ctx:set_tick_rate("low")
  ctx:invalidate()
end

function on_tick(ctx, _dt_ms)
  local key = refresh_key(project_time(ctx))
  if key ~= ctx.state.pixel_clock.last_key then
    ctx.state.pixel_clock.last_key = key
    ctx:invalidate()
  end
end

function on_input(ctx, ev)
  if ev.type == "key" and ev.state == "down" then
    if ev.key == "back" then ctx:quit(); return true end
    if ev.key == "ok" then
      ctx.system:set_as_lockscreen_app()
      ctx.state.clock_status = "已设为锁屏"
      ctx:invalidate()
      return true
    end
  end
  if ev.type == "touch" and ev.gesture == "tap" then
    local rect = button_rect(ctx)
    if ev.x >= rect.x and ev.x < rect.x + rect.w and ev.y >= rect.y and ev.y < rect.y + rect.h then
      ctx.system:set_as_lockscreen_app()
      ctx.state.clock_status = "已设为锁屏"
      ctx:invalidate()
      return true
    end
  end
  return false
end

function on_draw(ctx, g)
  M.draw(ctx, g, true)
end

return M
