local PkgImage = require("pkg_image")
-- 家居状态板：所有数据均为本地模拟，不访问网络或 Home Assistant。
local BLACK, WHITE = 15, 0
local ROOMS = { "全屋", "客厅", "卧室", "书房", "玄关" }
local ROOM_ICONS = { "device_ac", "device_humidifier", "device_lamp", "device_lock" }
local DEVICE_NAMES = { "空调", "加湿器", "台灯", "门锁" }
local SNAPSHOTS = {
  { time = "08:42", updated = "刚刚更新", weather = "晴  26°", outside = "室外湿度 48%",
    overall = { temp = "25.8°", humidity = "56%", air = "良好", note = "全屋舒适，3 台设备运行中" },
    rooms = {
      { name = "客厅", temp = "26.1°", humidity = "54%", air = "优", device = "空调 · 运行" },
      { name = "卧室", temp = "25.4°", humidity = "58%", air = "良好", device = "加湿器 · 运行" },
      { name = "书房", temp = "25.9°", humidity = "55%", air = "优", device = "台灯 · 已关闭" },
      { name = "玄关", temp = "--", humidity = "--", air = "--", device = "门锁 · 已锁" },
    },
  },
  { time = "09:06", updated = "模拟刷新 · 24 秒前", weather = "多云  27°", outside = "室外湿度 51%",
    overall = { temp = "26.0°", humidity = "55%", air = "良好", note = "窗帘已拉开，2 台设备运行中" },
    rooms = {
      { name = "客厅", temp = "26.4°", humidity = "53%", air = "优", device = "空调 · 节能" },
      { name = "卧室", temp = "25.6°", humidity = "57%", air = "良好", device = "加湿器 · 运行" },
      { name = "书房", temp = "26.0°", humidity = "54%", air = "优", device = "台灯 · 已关闭" },
      { name = "玄关", temp = "--", humidity = "--", air = "--", device = "门锁 · 已锁" },
    },
  },
  { time = "09:31", updated = "模拟刷新 · 刚刚", weather = "晴  28°", outside = "室外湿度 46%",
    overall = { temp = "26.2°", humidity = "54%", air = "优", note = "日照升高，建议午后通风" },
    rooms = {
      { name = "客厅", temp = "26.7°", humidity = "52%", air = "优", device = "空调 · 待机" },
      { name = "卧室", temp = "25.8°", humidity = "56%", air = "良好", device = "加湿器 · 运行" },
      { name = "书房", temp = "26.2°", humidity = "53%", air = "优", device = "台灯 · 已关闭" },
      { name = "玄关", temp = "--", humidity = "--", air = "--", device = "门锁 · 已锁" },
    },
  },
}

local function board_state(ctx)
  local state = ctx.state.home_board or { room = 2, snapshot = 1, scene = 1 }
  state.devices = state.devices or { true, true, false, true }
  state.page = state.page or "home"
  ctx.state.home_board = state
  return state
end

local function layout(ctx)
  local w, h = ctx.screen.width, ctx.screen.height
  local m = math.max(32, math.floor(w * 0.067))
  return { w = w, h = h, m = m, hero_y = 82, hero_h = 112, list_y = 260, device_h = 112, advice_y = 520, scene_y = 592, footer_y = h - 56 }
end

local function text_width(text)
  local width, i = 0, 1
  while i <= #text do
    if text:byte(i) >= 0xE0 then width, i = width + 20, i + 3 else width, i = width + 10, i + 1 end
  end
  return width
end
local function center_x(l, text) return math.floor((l.w - text_width(text)) / 2) end
local function current_data(s)
  local shot = SNAPSHOTS[s.snapshot]
  return s.room == 1 and shot.overall or shot.rooms[s.room - 1]
end

local function active_device_count(s)
  local count = 0
  for _, on in ipairs(s.devices) do
    if on ~= false then count = count + 1 end
  end
  return count
end

local function device_label(index)
  return DEVICE_NAMES[index] or "设备"
end

local function device_notice(index, on)
  if index == 4 then return "门锁" .. (on and "已锁定" or "已解锁") end
  return device_label(index) .. (on and "已开启" or "已关闭")
end

local function advice_for(s)
  if s.notice then return s.notice end
  local count = active_device_count(s)
  if count == 0 then return "设备均已关闭，离家模式已准备好" end
  if count == 1 then return "仅保留必要设备，居家能耗较低" end
  return "当前 " .. count .. " 台设备已开启，环境保持稳定"
end

local function draw_header(g, l, shot)
  g:text(l.m, 28, "我的家", { color = BLACK })
  g:text(l.w - l.m - 42, 28, shot.time, { color = BLACK })
  g:text(l.m, 52, shot.weather .. "  ·  " .. shot.outside, { color = BLACK })
  g:line(l.m, 74, l.w - l.m, 74,{color=BLACK})
end

local function tab_width(l) return math.floor((l.w - l.m * 2 - 18) / 4) end
local function draw_tabs(g, l, s)
  local width = tab_width(l)
  for i, name in ipairs(ROOMS) do
    local x = l.m + (i - 1) * (width + 6)
    local active = s.room == i
    g:rect(x, l.tab_y, width, l.tab_h,{fill=(active) and true or false,color=BLACK})
    g:text(x + math.floor((width - #name * 10) / 2), l.tab_y + 12, name, { color = active and WHITE or BLACK })
  end
end

local SEGMENTS = {
  ["0"] = { 1, 2, 3, 5, 6, 7 }, ["1"] = { 3, 6 }, ["2"] = { 1, 3, 4, 5, 7 },
  ["3"] = { 1, 3, 4, 6, 7 }, ["4"] = { 2, 3, 4, 6 }, ["5"] = { 1, 2, 4, 6, 7 },
  ["6"] = { 1, 2, 4, 5, 6, 7 }, ["7"] = { 1, 3, 6 }, ["8"] = { 1, 2, 3, 4, 5, 6, 7 },
  ["9"] = { 1, 2, 3, 4, 6, 7 },
}

local function draw_segment_digit(g, digit, x, y, scale)
  local function unit(value) return math.floor(value * scale + 0.5) end
  local lit = {}
  for _, index in ipairs(SEGMENTS[digit] or {}) do lit[index] = true end
  local black = BLACK
  if lit[1] then g:rect(x + unit(5), y, unit(25), unit(5),{fill=true,color=black}) end
  if lit[2] then g:rect(x, y + unit(5), unit(5), unit(27),{fill=true,color=black}) end
  if lit[3] then g:rect(x + unit(30), y + unit(5), unit(5), unit(27),{fill=true,color=black}) end
  if lit[4] then g:rect(x + unit(5), y + unit(32), unit(25), unit(5),{fill=true,color=black}) end
  if lit[5] then g:rect(x, y + unit(37), unit(5), unit(27),{fill=true,color=black}) end
  if lit[6] then g:rect(x + unit(30), y + unit(37), unit(5), unit(27),{fill=true,color=black}) end
  if lit[7] then g:rect(x + unit(5), y + unit(64), unit(25), unit(5),{fill=true,color=black}) end
end

local function draw_large_value(g, value, x, y, suffix)
  local scale = 1.15
  local function unit(number) return math.floor(number * scale + 0.5) end
  local number = tonumber(tostring(value):match("%d+%.?%d*")) or 0
  local integer = math.floor(number + 0.5)
  local text = tostring(integer)
  for i = 1, #text do draw_segment_digit(g, text:sub(i, i), x + (i - 1) * unit(41), y, scale) end
  g:text(x + #text * unit(41) + unit(3), y + unit(40), suffix, { color = BLACK })
end

-- 复用斗地主的「矩形主体 + 四角圆」做法：在 1bpp 画布上比强行描边更稳定。
local function round_fill(g, x, y, w, h, radius, color)
  local r = math.max(2, math.min(radius, math.floor(math.min(w, h) / 2)))
  g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
  g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
end

local function round_outline(g, x, y, w, h, radius, outline, inside)
  round_fill(g, x, y, w, h, radius, outline)
  round_fill(g, x + 2, y + 2, w - 4, h - 4, math.max(2, radius - 2), inside)
end

local function draw_card(g, l, data, active_count)
  local x, y, w = l.m, l.hero_y, l.w - l.m * 2
  PkgImage.draw(g, "hero_title", x + 20, y - 4)
  g:text(x + w - 46, y + 8, active_count .. "台", { color = BLACK })
  PkgImage.draw(g, "icon_temp", x + 18, y + 62)
  draw_large_value(g, data.temp, x + 64, y + 45, "°C")
  g:line(x + 238, y + 48, x + 238, y + 112,{color=BLACK})
  PkgImage.draw(g, "icon_humidity", x + 264, y + 50)
  g:text(x + 308, y + 58, "湿度  " .. data.humidity, { color = BLACK })
  PkgImage.draw(g, "icon_air", x + 264, y + 90)
  g:text(x + 308, y + 98, "空气  " .. data.air, { color = BLACK })
end

local function draw_switch(g, x, y, on, color)
  local inside = color == WHITE and BLACK or WHITE
  round_outline(g, x, y, 34, 18, 9, color, inside)
  g:circle(on and x + 25 or x + 9, y + 9, 6,{fill=true,color=color})
end

local function device_lines(index, on, room)
  if index == 1 then
    return on and "制冷中" or "已关闭", on and "客厅 26°" or "客厅 待机"
  elseif index == 2 then
    return on and "自动加湿" or "已关闭", "卧室" .. room.humidity
  elseif index == 3 then
    return on and "暖光 65%" or "已关闭", on and "书房 已开启" or "书房 待机"
  end
  return on and "已锁定" or "已解锁", "玄关 92%"
end

local function draw_list(g, l, s, shot)
  local gap, half = 12, math.floor((l.w - l.m * 2 - 12) / 2)
  g:text(l.m, l.list_y - 24, "常用设备", { color = BLACK })
  for i, room in ipairs(shot.rooms) do
    local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local x = l.m + column * (half + gap)
    local y, w, h = l.list_y + row * (l.device_h + 14), half, l.device_h
    local on = s.devices[i] ~= false
    local primary, secondary = device_lines(i, on, room)
    round_outline(g, x, y, w, h, 10, BLACK, WHITE)
    local c = BLACK
    PkgImage.draw(g, ROOM_ICONS[i], x + 12, y + 20, { color = c })
    g:text(x + 94, y + 28, DEVICE_NAMES[i], { color = c })
    g:text(x + 94, y + 54, primary, { color = c })
    g:text(x + 94, y + 78, secondary, { color = c })
    draw_switch(g, x + w - 50, y + 8, on, c)
  end
end

local function draw_scenes(g, l, s)
  local gap, half = 12, math.floor((l.w - l.m * 2 - 12) / 2)
  local y = l.scene_y + 28
  g:text(l.m, l.scene_y, "快捷场景", { color = BLACK })
  round_outline(g, l.m, y, half, 66, 12, BLACK, WHITE)
  g:text(l.m + 16, y + 14, "回家", { color = BLACK })
  g:text(l.m + 16, y + 36, "客厅空调节能", { color = BLACK })
  round_outline(g, l.m + half + gap, y, half, 66, 12, BLACK, WHITE)
  g:text(l.m + half + gap + 16, y + 14, "睡眠", { color = BLACK })
  g:text(l.m + half + gap + 16, y + 36, "卧室加湿运行", { color = BLACK })
end

local function draw_detail_header(g, l, shot)
  g:text(l.m, 28, "家庭详情", { color = BLACK })
  g:text(l.w - l.m - 42, 28, shot.time, { color = BLACK })
  g:text(l.m, 52, "实时环境 · 能耗 · 安防 · 自动化", { color = BLACK })
  g:line(l.m, 74, l.w - l.m, 74,{color=BLACK})
end

local function draw_detail(g, l, s, shot)
  local x, w = l.m, l.w - l.m * 2
  local env_y, energy_y, security_y, automation_y = 96, 222, 344, 462
  local count, locked = active_device_count(s), s.devices[4] ~= false
  draw_detail_header(g, l, shot)

  g:rect(x, env_y, w, 108,{color=BLACK})
  PkgImage.draw(g, "detail_environment", x + 16, env_y + 28)
  g:text(x + 86, env_y + 12, "实时环境", { color = BLACK })
  g:text(x + 86, env_y + 42, "室温 " .. shot.overall.temp .. "   湿度 " .. shot.overall.humidity, { color = BLACK })
  g:text(x + 86, env_y + 70, "空气 " .. shot.overall.air .. "   CO2 618 ppm", { color = BLACK })

  g:rect(x, energy_y, w, 104,{color=BLACK})
  PkgImage.draw(g, "detail_energy", x + 16, energy_y + 26)
  g:text(x + 86, energy_y + 12, "用电概览", { color = BLACK })
  g:text(x + 86, energy_y + 42, "今日用电  3.2 kWh", { color = BLACK })
  g:text(x + 256, energy_y + 42, "待机 0.4 kWh", { color = BLACK })
  g:rect(x + 86, energy_y + 72, 166, 10,{color=BLACK})
  g:rect(x + 88, energy_y + 74, 104, 6,{fill=true,color=BLACK})
  g:text(x + 272, energy_y + 68, "较昨日 -8%", { color = BLACK })

  g:rect(x, security_y, w, 100,{color=BLACK})
  PkgImage.draw(g, "detail_security", x + 16, security_y + 22)
  g:text(x + 86, security_y + 12, "家庭安全", { color = BLACK })
  g:text(x + 86, security_y + 42, "玄关门锁 · " .. (locked and "已锁定" or "已解锁"), { color = BLACK })
  g:text(x + 290, security_y + 42, "电量 92%", { color = BLACK })
  g:text(x + 86, security_y + 68, "离家提醒 · 已开启    异常通知 · 已开启", { color = BLACK })

  g:rect(x, automation_y, w, 132,{color=BLACK})
  PkgImage.draw(g, "detail_automation", x + 16, automation_y + 36)
  g:text(x + 86, automation_y + 12, "自动化", { color = BLACK })
  g:text(x + 86, automation_y + 40, "回家模式     进门后开启客厅设备", { color = BLACK })
  g:line(x + 86, automation_y + 64, x + w - 16, automation_y + 64,{color=BLACK})
  g:text(x + 86, automation_y + 78, "睡眠模式     23:00 保留卧室加湿", { color = BLACK })
  g:text(x + 86, automation_y + 104, "当前 " .. count .. " 台设备处于开启状态", { color = BLACK })

  g:line(l.m, l.footer_y - 12, l.w - l.m, l.footer_y - 12,{color=BLACK})
  g:text(center_x(l, "BACK 返回首页"), l.footer_y + 10, "BACK 返回首页", { color = BLACK })
end

function on_load(ctx)
  board_state(ctx)
  ctx:set_tick(0); ctx:invalidate()
end

local function toggle_selected_device(s)
  local index = s.room - 1
  if index < 1 or index > #ROOM_ICONS then return false end
  s.devices[index] = not (s.devices[index] ~= false)
  return true
end

local function activate_scene(s, scene)
  s.scene = scene
  if scene == 1 then
    s.devices = { true, true, true, true }
    s.notice = "回家模式已执行，4 台设备已开启"
  else
    s.devices = { false, true, false, true }
    s.notice = "睡眠模式已执行，保留加湿器运行"
  end
  s.snapshot = s.snapshot % #SNAPSHOTS + 1
end

function on_input(ctx, ev)
  local s, l, changed = board_state(ctx), layout(ctx), false
  if ev.type == "key" and ev.phase == "down" then
    if s.page == "detail" then
      if ev.key == "back" or ev.key == "ok" then s.page = "home"; changed = true end
    elseif ev.key == "left" or ev.key == "up" then s.room = (s.room - 2) % #ROOMS + 1; changed = true
    elseif ev.key == "right" or ev.key == "down" then s.room = s.room % #ROOMS + 1; changed = true
    elseif ev.key == "ok" then
      if s.room == 1 then
        s.page = "detail"
        changed = true
      elseif toggle_selected_device(s) then
        local index, on = s.room - 1, s.devices[s.room - 1] ~= false
        s.notice = device_notice(index, on)
        changed = true
      else
        s.snapshot = s.snapshot % #SNAPSHOTS + 1
        s.notice = "全屋数据已切换为最新模拟快照"
        changed = true
      end
    elseif ev.key == "back" then s.room = 1; changed = true end
  elseif (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if s.page == "detail" then
      if ev.y >= l.footer_y - 24 then s.page = "home"; changed = true end
    elseif ev.y >= l.hero_y and ev.y <= l.hero_y + l.hero_h then
      s.page = "detail"; changed = true
    elseif ev.y >= l.list_y and ev.y <= l.list_y + l.device_h then
      s.room = ev.x < l.w / 2 and 2 or 3
      toggle_selected_device(s)
      s.notice = device_notice(s.room - 1, s.devices[s.room - 1] ~= false)
      changed = true
    elseif ev.y >= l.list_y + l.device_h + 14 and ev.y <= l.list_y + l.device_h * 2 + 14 then
      s.room = ev.x < l.w / 2 and 4 or 5
      toggle_selected_device(s)
      s.notice = device_notice(s.room - 1, s.devices[s.room - 1] ~= false)
      changed = true
    elseif ev.y >= l.scene_y and ev.y <= l.scene_y + 90 then
      activate_scene(s, ev.x < l.w / 2 and 1 or 2); changed = true
    elseif ev.y >= l.footer_y - 24 then
      s.snapshot = s.snapshot % #SNAPSHOTS + 1
      s.notice = "全屋数据已切换为最新模拟快照"
      changed = true
    end
  end
  if changed then ctx:invalidate() end
  return changed
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s, l = board_state(ctx), layout(ctx); local shot = SNAPSHOTS[s.snapshot]
  if s.page == "detail" then
    g:clear(WHITE); draw_detail(g, l, s, shot); return
  end
  g:clear(WHITE); draw_header(g, l, shot); draw_card(g, l, shot.overall, active_device_count(s)); draw_list(g, l, s, shot)
  g:rect(l.m, l.advice_y + 10, 4, 44,{fill=true,color=BLACK})
  g:text(l.m + 16, l.advice_y + 14, "家庭建议", { color = BLACK })
  g:text(l.m + 16, l.advice_y + 38, advice_for(s), { color = BLACK })
  draw_scenes(g, l, s)
  g:line(l.m, l.footer_y - 12, l.w - l.m, l.footer_y - 12,{color=BLACK})
  g:text(l.m, l.footer_y + 10, shot.updated, { color = BLACK })
  round_fill(g, l.w - l.m - 78, l.footer_y, 78, 40, 14, BLACK)
  g:text(l.w - l.m - 60, l.footer_y + 10, "刷新", { color = WHITE })
end
