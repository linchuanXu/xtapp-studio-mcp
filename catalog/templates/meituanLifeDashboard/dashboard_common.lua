local M = {}
local B, W = 15, 0
local WEEKDAYS = { "日", "一", "二", "三", "四", "五", "六" }
local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local SEGMENTS = {
  ["0"]="abcedf", ["1"]="bc", ["2"]="abdeg", ["3"]="abcdg", ["4"]="bcfg",
  ["5"]="acdfg", ["6"]="acdefg", ["7"]="abc", ["8"]="abcdefg", ["9"]="abcdfg",
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
  if not clock.valid or clock.year == nil or clock.hour == nil or clock.minute == nil then return nil end
  return {
    year=clock.year, month=clock.month, day=clock.day,
    hour=clock.hour, min=clock.minute, wday=clock.weekday,
  }
end

local function text_width(text)
  local width, i = 0, 1
  while i <= #text do
    local byte = string.byte(text, i)
    if byte and byte >= 0xE0 then width, i = width + 20, i + 3 else width, i = width + 10, i + 1 end
  end
  return width
end

local function center(g, x, y, width, text, color)
  g:text(x + math.floor((width - text_width(text)) / 2), y, text, { color=color or B })
end

local function has(set, key)
  return set and string.find(set, key, 1, true)
end

local function draw_time(g, text, x, y, width, height)
  local digit_w, gap, colon_w = 72, 12, 30
  local total = digit_w * 4 + gap * 3 + colon_w
  local cursor = x + math.floor((width - total) / 2)
  local thick = 8
  local digit_h = math.min(height, 116)
  local half = math.floor(digit_h / 2)
  for index=1,#text do
    local char = string.sub(text, index, index)
    if char == ":" then
      g:circle(cursor + math.floor(colon_w / 2), y + 38, 6, "fill", B)
      g:circle(cursor + math.floor(colon_w / 2), y + 80, 6, "fill", B)
      cursor = cursor + colon_w
    else
      local set = SEGMENTS[char]
      local span = digit_w - thick * 2
      if has(set, "a") then g:rect(cursor+thick,y,span,thick,"fill",B) end
      if has(set, "b") then g:rect(cursor+digit_w-thick,y+thick,thick,half-thick*2,"fill",B) end
      if has(set, "c") then g:rect(cursor+digit_w-thick,y+half+thick,thick,half-thick*2,"fill",B) end
      if has(set, "d") then g:rect(cursor+thick,y+digit_h-thick,span,thick,"fill",B) end
      if has(set, "e") then g:rect(cursor,y+half+thick,thick,half-thick*2,"fill",B) end
      if has(set, "f") then g:rect(cursor,y+thick,thick,half-thick*2,"fill",B) end
      if has(set, "g") then g:rect(cursor+thick,y+half-math.floor(thick/2),span,thick,"fill",B) end
      cursor = cursor + digit_w + gap
    end
  end
end

local function now(ctx)
  return ctx.sys:local_sec() or math.floor(ctx.sys:millis() / 1000)
end

function M.state(ctx)
  if not ctx.state.meituan_life_dashboard then
    ctx.state.meituan_life_dashboard = {
      delivery_started=now(ctx), deal_index=1, summary_index=1, clock_status="设为锁屏",
    }
  end
  return ctx.state.meituan_life_dashboard
end

local DEALS = {
  { title="火锅双人餐", detail="¥128 · 620m" },
  { title="手冲咖啡", detail="¥19.9 · 380m" },
  { title="炭火烧肉", detail="¥168 · 1.1km" },
}

local SUMMARIES = {
  "本月聚餐增加，周末消费更集中。",
  "咖啡复购稳定，夜宵次数有所下降。",
  "外卖支出平稳，到店体验正在增加。",
}

local function delivery(ctx, state)
  local elapsed = math.max(0, now(ctx) - (state.delivery_started or now(ctx)))
  local eta = math.max(0, 12 - math.floor(elapsed / 60))
  if eta == 0 then return 0, "订单已送达", "餐品已放观澜湖前台" end
  if eta <= 3 then return eta, "即将送达", "骑手进入观澜湖园区" end
  if eta <= 8 then return eta, "骑手配送中", "距观澜湖园区 1.2 公里" end
  return eta, "骑手配送中", "已从观澜湖新城取餐"
end

local function card(g, x, y, width, title, icon, primary, secondary, selected)
  g:line(x,y,x+width,y,B)
  if selected then g:rect(x,y+12,5,72,"fill",B) end
  g:image(icon,x+14,y+14)
  g:text(x+72,y+17,title,{color=B})
  g:text(x+16,y+62,primary,{color=B})
  g:text(x+16,y+90,secondary,{color=B})
end

function M.draw(ctx, g, show_button)
  local state = M.state(ctx)
  local parts = project(ctx)
  local width = ctx.screen.width
  local deal = DEALS[state.deal_index or 1]
  local eta, delivery_title, delivery_detail = delivery(ctx, state)
  g:clear(W)

  g:image("brand_logo",24,14)
  if parts then
    g:text(274,20,string.format("%02d月%02d日 · 周%s",parts.month,parts.day,WEEKDAYS[parts.wday+1]),{color=B})
    draw_time(g,string.format("%02d:%02d",parts.hour,parts.min),20,86,width-40,120)
  else
    center(g,20,112,width-40,"时间未校准",B)
  end
  if show_button then
    g:rect(332,52,124,34,"stroke",B)
    g:rect(332,52,5,34,"fill",B)
    center(g,332,59,124,state.clock_status or "设为锁屏",B)
  end
  g:line(24,224,456,224,B)

  g:image("icon_rider",24,252)
  g:text(88,256,eta > 0 and "外卖还有" or "外卖状态",{color=B})
  g:text(24,308,eta > 0 and (eta.." 分钟") or "已送达",{color=B})
  g:text(208,276,delivery_title,{color=B})
  g:text(208,314,delivery_detail,{color=B})
  for index=1,5 do
    local x=210+(index-1)*38
    g:circle(x,348,5,index<=4 and "fill" or "stroke",B)
    if index<5 then g:line(x+6,348,x+32,348,B) end
  end
  g:line(24,376,456,376,B)

  card(g,24,398,208,"观澜湖好价","icon_hotpot",deal.title,deal.detail,true)
  card(g,248,398,208,"本月美食","icon_chart","¥ 1,286","外卖占 43%",false)
  card(g,24,530,208,"美团 3690","icon_trend","HK$ 102.4","▲ 2.3%",false)
  card(g,248,530,208,"LongCat","icon_cat","可用 72%","运行顺畅",false)
  g:line(240,398,240,642,B)

  g:line(24,656,456,656,B)
  g:text(24,678,"生活小结",{color=B})
  g:text(24,714,SUMMARIES[state.summary_index or 1],{color=B})
  g:line(24,754,456,754,B)
  center(g,24,772,432,"时间之下，生活正在发生",B)
end

function M.input(ctx, event)
  if event.type ~= "touch" or event.gesture ~= "tap" then return false end
  local state = M.state(ctx)
  if event.y >= 48 and event.y <= 92 and event.x >= 320 then
    ctx.system:set_as_lockscreen_app()
    state.clock_status = "已设为锁屏"
  elseif event.y >= 246 and event.y <= 372 then
    state.delivery_started = now(ctx)
  elseif event.y >= 398 and event.y <= 514 and event.x < 240 then
    state.deal_index = (state.deal_index or 1) % #DEALS + 1
  elseif event.y >= 664 and event.y <= 750 then
    state.summary_index = (state.summary_index or 1) % #SUMMARIES + 1
  else
    return false
  end
  ctx:invalidate()
  return true
end

return M
