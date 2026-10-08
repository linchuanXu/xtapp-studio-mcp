local B, W = 15, 0
local WEEKDAYS = {"日", "一", "二", "三", "四", "五", "六"}
local MONTH_DAYS = {31,28,31,30,31,30,31,31,30,31,30,31}
local SEGMENTS = {
  ["0"]="abcedf", ["1"]="bc", ["2"]="abdeg", ["3"]="abcdg", ["4"]="bcfg",
  ["5"]="acdfg", ["6"]="acdefg", ["7"]="abc", ["8"]="abcdefg", ["9"]="abcdfg"
}

local function is_leap(year)
  return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function month_days(year, month)
  if month == 2 and is_leap(year) then return 29 end
  return MONTH_DAYS[month]
end

local function project(ctx)
  local clock = ctx.sys:clock()
  if not clock.valid or clock.month == nil or clock.day == nil or clock.hour == nil or clock.minute == nil then return nil end
  return {
    month=clock.month, day=clock.day, weekday=clock.weekday,
    hour=clock.hour, minute=clock.minute
  }
end

local function center(g, x, y, width, text)
  local units, i = 0, 1
  while i <= #text do
    if text:byte(i) >= 0xE0 then units, i = units + 20, i + 3 else units, i = units + 10, i + 1 end
  end
  g:text(x + math.max(0, math.floor((width - units) / 2)), y, text, {color=B})
end

local function has(set, key)
  return set and string.find(set, key, 1, true)
end

local function draw_time(ctx, g, text)
  local digit_width, gap, colon_width = 72, 10, 28
  local total = digit_width * 4 + gap * 3 + colon_width
  local x, y, height, thick = math.floor((ctx.screen.width - total) / 2), 108, 108, 8
  local half = math.floor(height / 2)
  for index=1,#text do
    local char = string.sub(text, index, index)
    if char == ":" then
      g:circle(x + math.floor(colon_width / 2), y + 34, 6, "fill", B)
      g:circle(x + math.floor(colon_width / 2), y + 76, 6, "fill", B)
      x = x + colon_width
    else
      local set = SEGMENTS[char]
      local span = digit_width - thick * 2
      if has(set, "a") then g:rect(x+thick,y,span,thick,"fill",B) end
      if has(set, "b") then g:rect(x+digit_width-thick,y+thick,thick,half-thick*2,"fill",B) end
      if has(set, "c") then g:rect(x+digit_width-thick,y+half+thick,thick,half-thick*2,"fill",B) end
      if has(set, "d") then g:rect(x+thick,y+height-thick,span,thick,"fill",B) end
      if has(set, "e") then g:rect(x,y+half+thick,thick,half-thick*2,"fill",B) end
      if has(set, "f") then g:rect(x,y+thick,thick,half-thick*2,"fill",B) end
      if has(set, "g") then g:rect(x+thick,y+half-math.floor(thick/2),span,thick,"fill",B) end
      x = x + digit_width + gap
    end
  end
end

local function completed_count(state)
  local done = 0
  if state and state.reminder_done then
    for i=1,4 do if state.reminder_done[i] then done = done + 1 end end
  end
  return done
end

function on_tick(ctx)
  ctx.lock:set_interval(60)
end

function on_draw(ctx, g)
  local parts = project(ctx)
  local state = ctx.state.alipay_money_brief
  local remaining = math.max(0, 4 - completed_count(state))
  g:clear(W)
  g:image("brand_mark", 24, 18)
  g:rect(350, 20, 106, 38, "stroke", B)
  center(g, 350, 30, 106, "隐私锁屏")
  g:line(24, 82, 456, 82, B)
  if parts then
    draw_time(ctx, g, string.format("%02d:%02d", parts.hour, parts.minute))
    center(g, 24, 236, 432, string.format("%02d月%02d日 · 周%s", parts.month, parts.day, WEEKDAYS[parts.weekday + 1]))
  else
    center(g, 24, 162, 432, "时间未校准")
  end
  g:line(24, 278, 456, 278, B)
  g:image("icon_reminder", 24, 306)
  g:text(92, 308, "付款提醒", {color=B})
  g:text(24, 368, remaining > 0 and (remaining .. " 项待处理") or "今日已处理完", {color=B})
  g:text(24, 412, remaining > 0 and "最近窗口 · 今天 20:00 前" or "下一次提醒 · 明天 09:00", {color=B})
  g:line(24, 460, 456, 460, B)
  g:image("icon_shield", 24, 488)
  g:text(92, 490, "本月消费状态", {color=B})
  g:rect(24, 548, 432, 90, "stroke", B)
  g:rect(24, 548, 6, 90, "fill", B)
  g:text(50, 566, "预算内", {color=B})
  g:text(50, 600, "固定扣款已纳入计划", {color=B})
  g:line(24, 674, 456, 674, B)
  center(g, 24, 700, 432, "金额与账户明细已隐藏")
  center(g, 24, 738, 432, "打开应用后可查看完整信息")
  g:line(24, 762, 456, 762, B)
  ctx.lock:flush_once("partial")
end
