local PkgImage = require("pkg_image")
-- 冰箱食材管家：本地模拟一台家庭冰箱的分区库存，不访问网络。
local BLACK, WHITE = 15, 0

local ZONES = {
  { name = "冷藏", icon = "icon_chill", count = 5, temp = "4°C", items = { { "鲜奶", "2 盒", "8 月 27 日" }, { "鸡蛋", "6 枚", "8 月 29 日" }, { "嫩豆腐", "1 盒", "8 月 26 日" } } },
  { name = "冷冻", icon = "icon_frozen", count = 3, temp = "-18°C", items = { { "三文鱼", "2 块", "冷冻保存" }, { "猪肉馅", "1 袋", "冷冻保存" }, { "玉米粒", "1 袋", "冷冻保存" } } },
  { name = "果蔬", icon = "icon_produce", count = 4, temp = "保鲜", items = { { "生菜", "1 颗", "明日到期" }, { "蓝莓", "1 盒", "8 月 28 日" }, { "牛油果", "2 个", "待食用" } } },
  { name = "门架", icon = "icon_pantry", count = 6, temp = "常温", items = { { "酸奶", "3 杯", "8 月 30 日" }, { "番茄酱", "1 瓶", "余量充足" }, { "气泡水", "4 罐", "随取随用" } } },
}

local function text_width(text)
  local width, index = 0, 1
  while index <= #text do
    if text:byte(index) >= 0xE0 then width, index = width + 20, index + 3 else width, index = width + 10, index + 1 end
  end
  return width
end

local function center(g, x, y, width, text, color)
  g:text(x + math.floor((width - text_width(text)) / 2), y, text, { color = color or BLACK })
end

local function fit_text(text, max_width)
  local output, width, index = "", 0, 1
  while index <= #text do
    local wide = text:byte(index) >= 0xE0
    local length, step = wide and 3 or 1, wide and 20 or 10
    if width + step > max_width then return output end
    output = output .. text:sub(index, index + length - 1)
    width, index = width + step, index + length
  end
  return output
end

local function right(g, edge, y, text, color)
  g:text(edge - text_width(text), y, text, { color = color or BLACK })
end

local function fitted(g, x, y, max_width, text, color)
  g:text(x, y, fit_text(text, max_width), { color = color or BLACK })
end

-- Rounded panels are built from rectangles and circles for stable 1bpp edges.
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

local function draw_zone(g, x, y, w, h, zone, selected)
  if selected then
    round_fill(g, x, y, w, h, 14, BLACK)
    PkgImage.draw(g, zone.icon, x + 16, y + 12, { color = WHITE })
    g:text(x + 78, y + 16, zone.name, { color = WHITE })
    right(g, x + w - 16, y + 16, zone.count .. "件", WHITE)
    g:text(x + 78, y + 45, zone.temp, { color = WHITE })
  else
    round_outline(g, x, y, w, h, 14, BLACK, WHITE)
    PkgImage.draw(g, zone.icon, x + 16, y + 12)
    g:text(x + 78, y + 16, zone.name, { color = BLACK })
    right(g, x + w - 16, y + 16, zone.count .. "件", BLACK)
    g:text(x + 78, y + 45, zone.temp, { color = BLACK })
  end
end

local function draw_zones(g, x, y, selected)
  local width, gap = 202, 20
  for index, zone in ipairs(ZONES) do
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    draw_zone(g, x + column * (width + gap), y + row * 98, width, 84, zone, selected == index)
  end
end

local function draw_items(g, x, y, width, zone)
  round_outline(g, x, y, width, 184, 16, BLACK, WHITE)
  PkgImage.draw(g, zone.icon, x + 16, y + 16)
  g:text(x + 78, y + 18, zone.name .. "食材", { color = BLACK })
  right(g, x + width - 20, y + 18, zone.count .. "件", BLACK)
  for index, item in ipairs(zone.items) do
    local row_y = y + 68 + (index - 1) * 36
    fitted(g, x + 20, row_y, 126, item[1], BLACK)
    right(g, x + 236, row_y, item[2], BLACK)
    right(g, x + width - 20, row_y, item[3], BLACK)
  end
end

local function draw(ctx, g)
  local state = ctx.state.fridge
  local selected = state.selected
  local zone = ZONES[selected]
  g:clear(WHITE)
  g:text(28, 34, "FRIDGE", { color = BLACK })
  g:text(352, 34, "18 件在库", { color = BLACK })
  g:line(28, 66, 452, 66,{color=BLACK})

  round_outline(g, 28, 92, 424, 76, 16, BLACK, WHITE)
  PkgImage.draw(g, "icon_produce", 48, 106)
  g:text(116, 108, "明天优先吃", { color = BLACK })
  fitted(g, 116, 134, 300, "生菜  1 颗  ·  果蔬区", BLACK)

  g:text(28, 194, "冰箱分区", { color = BLACK })
  g:text(372, 194, "4 个分区", { color = BLACK })
  draw_zones(g, 28, 222, selected)

  g:text(28, 434, "当前食材", { color = BLACK })
  draw_items(g, 28, 462, 424, zone)

  if state.focus then round_fill(g, 126, 704, 228, 46, 23, BLACK) else round_outline(g, 126, 704, 228, 46, 23, BLACK, WHITE) end
  center(g, 126, 717, 228, state.focus and "确认刷新" or "刷新库存", state.focus and WHITE or BLACK)
end

local function refresh(ctx)
  local state = ctx.state.fridge
  state.refreshes = state.refreshes + 1
  ctx:invalidate()
end

function on_load(ctx)
  ctx.state.fridge = { selected = 1, focus = false, refreshes = 0 }
  ctx:set_tick(500)
end


function on_input(ctx, ev)
  local state = ctx.state.fridge
  if ev.type == "key" and ev.phase == "down" then
    if ev.key == "back" then ctx:quit(); return true end
    if ev.key == "left" then state.selected = state.selected == 1 and #ZONES or state.selected - 1; ctx:invalidate(); return true end
    if ev.key == "right" then state.selected = state.selected == #ZONES and 1 or state.selected + 1; ctx:invalidate(); return true end
    if ev.key == "up" or ev.key == "down" then state.focus = not state.focus; ctx:invalidate(); return true end
    if ev.key == "ok" then refresh(ctx); return true end
  end
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if ev.x >= 28 and ev.x <= 452 and ev.y >= 222 and ev.y <= 404 then
      local column = ev.x < 240 and 0 or 1
      local row = ev.y < 320 and 0 or 1
      state.selected = row * 2 + column + 1
      if state.selected < 1 then state.selected = 1 end
      if state.selected > #ZONES then state.selected = #ZONES end
      ctx:invalidate(); return true
    end
    if ev.y >= 684 and ev.y <= 780 then refresh(ctx); return true end
  end
  return false
end

function on_draw(ctx, g) require("pkg_image").bind(ctx); draw(ctx, g) end
