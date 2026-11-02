-- 山河简图 / X4 Pro 横屏 800×480
-- 总表 4×3 卡片一屏看全。点开后左边作图，右边图例；点图层或图例高亮对应带。
-- 相对 800×480：卡片 origin (16, 56)，格 184×118，列距 16，行距 12。
-- 第 1 格中心 (108, 115)，第 2 格 (308, 115)，第 5 格 (108, 245)。
-- 图页「〈 返回」热区 (8, 6, 128×40)，顶栏 y<52 也可回表。
-- 图框 (16, 56, 468, 380)。图例第 i 条 (504, 64+(i-1)*44, 280×36)。
-- 三级阶梯：一阶 (40, 80, 140, 96)，二阶 (40, 180, 250, 100)，三阶 (40, 284, 420, 124)。
local BLACK, WHITE = 15, 0
local COLS, ROWS = 4, 3
local CARD_W, CARD_H = 184, 118
local CARD_OX, CARD_OY = 16, 56
local CARD_GX, CARD_GY = 16, 12
local HEADER_H = 52
local BACK_BTN = { x = 8, y = 6, w = 128, h = 40 }
local FIG = { x = 16, y = 56, w = 468, h = 380 }
local LEGEND_X, LEGEND_Y, LEGEND_W, LEGEND_H, LEGEND_GAP = 504, 64, 280, 36, 8

local MAPS = nil
local LAYER_HITS = {}

local function split(text, sep)
  local rows, start = {}, 1
  while true do
    local i = string.find(text, sep, start, true)
    if not i then rows[#rows + 1] = string.sub(text, start); break end
    rows[#rows + 1] = string.sub(text, start, i - 1)
    start = i + #sep
  end
  return rows
end

local function load_maps(ctx)
  if MAPS then return end
  MAPS = {}
  local reader = ctx.package:open_text("maps.tsv", {max_line_bytes = 512})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      MAPS[#MAPS + 1] = {
        id = c[1],
        title = c[2] or "",
        hint = c[3] or "",
        layers = split(c[4] or "", "|"),
        note = c[5] or "",
      }
    end
  end
  reader:close()
end

local function state(ctx)
  load_maps(ctx)
  local s = ctx.state.geo_outline
  if type(s) ~= "table" then
    s = { screen = "list", cursor = 1, highlight = 0 }
    ctx.state.geo_outline = s
  end
  local n = math.max(1, #MAPS)
  s.cursor = math.max(1, math.min(n, math.floor(tonumber(s.cursor) or 1)))
  s.highlight = math.max(0, math.floor(tonumber(s.highlight) or 0))
  local m = MAPS[s.cursor]
  if m then s.highlight = math.min(s.highlight, #m.layers) end
  if s.screen ~= "map" then s.screen = "list" end
  return s
end

local function hit(x, y, rx, ry, rw, rh)
  return x >= rx and x < rx + rw and y >= ry and y < ry + rh
end

local function text_w(text)
  local w, i = 0, 1
  while i <= #text do
    local b = string.byte(text, i)
    if b >= 224 then w, i = w + 20, i + 3 elseif b >= 192 then w, i = w + 10, i + 2 else w, i = w + 10, i + 1 end
  end
  return w
end

local function wrap_text(text, max_w)
  local lines, buf, width, i = {}, "", 0, 1
  while i <= #text do
    local b = string.byte(text, i)
    local step = b >= 224 and 3 or (b >= 192 and 2 or 1)
    local ch = string.sub(text, i, i + step - 1)
    local cw = step == 3 and 20 or 10
    if width + cw > max_w and buf ~= "" then
      lines[#lines + 1] = buf
      buf, width = ch, cw
    else
      buf, width = buf .. ch, width + cw
    end
    i = i + step
  end
  if buf ~= "" then lines[#lines + 1] = buf end
  if #lines == 0 then lines[1] = "" end
  return lines
end

local function I(v)
  return math.floor(v + 0.5)
end

local function rounded_fill(g, x, y, w, h, radius, color)
  local r = math.max(1, math.min(radius, math.floor(w / 2), math.floor(h / 2)))
  g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
  g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
end

local function rounded_stroke(g, x, y, w, h, radius, thickness, color)
  local t = math.max(1, thickness)
  rounded_fill(g, x, y, w, h, radius, color)
  rounded_fill(g, x + t, y + t, w - t * 2, h - t * 2, math.max(1, radius - t), WHITE)
end

local function center_text(g, cx, y, text, color)
  g:text(cx - math.floor(text_w(text) / 2), y, text, { color = color or BLACK })
end

local function card_xy(index)
  local i = index - 1
  local col = i % COLS
  local row = math.floor(i / COLS)
  return CARD_OX + col * (CARD_W + CARD_GX), CARD_OY + row * (CARD_H + CARD_GY)
end

local function legend_box(i)
  return { x = LEGEND_X, y = LEGEND_Y + (i - 1) * (LEGEND_H + LEGEND_GAP), w = LEGEND_W, h = LEGEND_H }
end

local function add_rect_hit(i, x, y, w, h)
  LAYER_HITS[i] = { kind = "rect", x = x, y = y, w = w, h = h }
end

local function add_ring_hit(i, cx, cy, r0, r)
  LAYER_HITS[i] = { kind = "ring", cx = cx, cy = cy, r0 = r0, r = r }
end

local function hit_layer(px, py)
  for i = #LAYER_HITS, 1, -1 do
    local b = LAYER_HITS[i]
    if b and b.kind == "ring" then
      local dx, dy = px - b.cx, py - b.cy
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= b.r and d >= (b.r0 or 0) then return i end
    elseif b and hit(px, py, b.x, b.y, b.w, b.h) then
      return i
    end
  end
  return nil
end

local function band(g, x, y, w, h, on, label, lx, ly)
  if on then
    g:rect(x, y, w, h,{fill=true,color=BLACK})
  else
    g:rect(x, y, w, h,{color=BLACK})
  end
  if label then
    g:text(lx or (x + 10), ly or (y + math.floor((h - 16) / 2)), label, { color = on and WHITE or BLACK })
  end
end

local function thick(g, x1, y1, x2, y2, on)
  x1, y1, x2, y2 = I(x1), I(y1), I(x2), I(y2)
  g:line(x1, y1, x2, y2,{color=BLACK})
  if on then
    g:line(x1, y1 + 1, x2, y2 + 1,{color=BLACK})
    g:line(x1, y1 - 1, x2, y2 - 1,{color=BLACK})
    g:line(x1 + 1, y1, x2 + 1, y2,{color=BLACK})
    g:line(x1 - 1, y1, x2 - 1, y2,{color=BLACK})
  end
end

local function norm(x, y)
  local n = math.sqrt(x * x + y * y)
  if n < 1 then return 0, 0 end
  return x / n, y / n
end

local function arrow(g, x1, y1, x2, y2, on)
  thick(g, x1, y1, x2, y2, on)
  local ux, uy = norm(x2 - x1, y2 - y1)
  local px, py = -uy, ux
  local s = on and 12 or 10
  g:line(I(x2), I(y2), I(x2 - ux * s + px * 5), I(y2 - uy * s + py * 5),{color=BLACK})
  g:line(I(x2), I(y2), I(x2 - ux * s - px * 5), I(y2 - uy * s - py * 5),{color=BLACK})
end

local function hatch(g, x, y, w, h, step)
  step = step or 8
  for i = 0, w - 1, step do
    g:line(x + i, y, x + i, y + h - 1,{color=BLACK})
  end
end

local function lab(g, x, y, text, color)
  g:text(I(x), I(y), text, { color = color or BLACK })
end

local FIGURES = {}

function FIGURES.stairs(g, box, hi)
  local a = { x = 40, y = 80, w = 140, h = 96 }
  local b = { x = 40, y = 180, w = 250, h = 100 }
  local c = { x = 40, y = 284, w = 420, h = 124 }
  band(g, a.x, a.y, a.w, a.h, hi == 1, "第一阶梯", a.x + 16, a.y + 38)
  band(g, b.x, b.y, b.w, b.h, hi == 2, "第二阶梯", b.x + 16, b.y + 40)
  band(g, c.x, c.y, c.w, c.h, hi == 3, "第三阶梯", c.x + 16, c.y + 52)
  lab(g, a.x + a.w + 8, a.y + 38, "青藏")
  lab(g, b.x + b.w + 8, b.y + 40, "黄土·云贵")
  lab(g, c.x + 280, c.y + 52, "东部平原")
  add_rect_hit(1, a.x, a.y, a.w, a.h)
  add_rect_hit(2, b.x, b.y, b.w, b.h)
  add_rect_hit(3, c.x, c.y, c.w, c.h)
end

function FIGURES.monsoon(g, box, hi)
  local land = { x = 220, y = 120, w = 230, h = 240 }
  g:rect(36, 90, 420, 310,{color=BLACK})
  band(g, land.x, land.y, land.w, land.h, false, "陆地", land.x + 80, land.y + 108)
  lab(g, 56, 220, "海")
  arrow(g, 80, 360, 250, 250, hi == 1)
  arrow(g, 90, 300, 240, 200, hi == 1)
  arrow(g, 400, 140, 120, 200, hi == 2)
  arrow(g, 380, 180, 140, 260, hi == 2)
  if hi == 3 then
    g:rect(230, 200, 210, 36,{fill=true,color=BLACK})
    center_text(g, 335, 208, "雨带", WHITE)
  else
    g:rect(230, 200, 210, 36,{color=BLACK})
    center_text(g, 335, 208, "雨带", BLACK)
  end
  add_rect_hit(1, 60, 240, 200, 140)
  add_rect_hit(2, 300, 100, 160, 100)
  add_rect_hit(3, 230, 200, 210, 36)
end

function FIGURES.water(g, box, hi)
  g:circle(400, 110, 22,{fill=(hi == 1) and true or false,color=BLACK})
  lab(g, 428, 100, "日")
  band(g, 40, 280, 200, 120, hi == 1 or hi == 3, "海洋", 96, 328)
  band(g, 280, 260, 180, 140, hi == 2 or hi == 3, "陆地", 332, 318)
  arrow(g, 130, 280, 200, 140, hi == 1)
  lab(g, 148, 190, "蒸发")
  arrow(g, 240, 130, 360, 250, hi == 2)
  lab(g, 300, 170, "降水")
  arrow(g, 280, 330, 200, 330, hi == 3)
  lab(g, 214, 300, "径流")
  add_rect_hit(1, 40, 100, 200, 300)
  add_rect_hit(2, 280, 120, 180, 140)
  add_rect_hit(3, 200, 300, 160, 60)
end

function FIGURES.earth(g, box, hi)
  local cx, cy = 250, 246
  local r = { 36, 78, 128, 168 }
  local names = { "内核", "外核", "地幔", "地壳" }
  -- layers: 地壳 地幔 外核 内核
  local order = { 4, 3, 2, 1 }
  for n = 4, 1, -1 do
    local on = hi == order[n]
    if on then
      g:circle(cx, cy, r[n],{fill=true,color=BLACK})
      if n > 1 then g:circle(cx, cy, r[n - 1],{fill=true,color=WHITE}) end
    else
      g:circle(cx, cy, r[n],{color=BLACK})
    end
  end
  lab(g, cx + 140, 96, names[4], hi == 1 and BLACK or BLACK)
  lab(g, cx + 100, 156, names[3])
  lab(g, cx + 52, 210, names[2])
  lab(g, cx - 20, 238, names[1], hi == 4 and WHITE or BLACK)
  add_ring_hit(1, cx, cy, r[3], r[4])
  add_ring_hit(2, cx, cy, r[2], r[3])
  add_ring_hit(3, cx, cy, r[1], r[2])
  add_ring_hit(4, cx, cy, 0, r[1])
end

function FIGURES.atmo(g, box, hi)
  local x, w = 80, 300
  local bands = {
    { y = 320, h = 90, name = "对流层" },
    { y = 236, h = 84, name = "平流层" },
    { y = 160, h = 76, name = "中间层" },
    { y = 80, h = 80, name = "热层" },
  }
  for i = 1, 4 do
    local b = bands[i]
    band(g, x, b.y, w, b.h, hi == i, b.name, x + 20, b.y + math.floor((b.h - 16) / 2))
    add_rect_hit(i, x, b.y, w, b.h)
  end
  lab(g, 396, 356, "地面")
end

function FIGURES.current(g, box, hi)
  g:rect(60, 100, 380, 280,{color=BLACK})
  lab(g, 76, 112, "大陆")
  lab(g, 360, 112, "大洋")
  -- 西岸暖流、东岸寒流、赤道西向流
  arrow(g, 160, 340, 160, 160, hi == 1)
  arrow(g, 160, 160, 360, 160, hi == 1)
  arrow(g, 360, 140, 360, 320, hi == 2)
  arrow(g, 360, 320, 180, 320, hi == 2)
  arrow(g, 380, 240, 150, 240, hi == 3)
  lab(g, 168, 170, "暖")
  lab(g, 368, 220, "寒")
  lab(g, 240, 214, "赤道流")
  add_rect_hit(1, 140, 150, 80, 200)
  add_rect_hit(2, 330, 130, 80, 210)
  add_rect_hit(3, 150, 220, 230, 40)
end

function FIGURES.plate(g, box, hi)
  local left = { x = 40, y = 160, w = 160, h = 180 }
  local right = { x = 300, y = 160, w = 160, h = 180 }
  band(g, left.x, left.y, left.w, left.h, hi == 1, "板块甲", left.x + 36, left.y + 80)
  band(g, right.x, right.y, right.w, right.h, hi == 2, "板块乙", right.x + 36, right.y + 80)
  arrow(g, 70, 140, 180, 160, hi == 1)
  arrow(g, 430, 140, 320, 160, hi == 2)
  local mx, my = 250, 150
  if hi == 3 then
    g:rect(210, 88, 80, 72,{fill=true,color=BLACK})
    center_text(g, mx, 112, "山", WHITE)
  else
    thick(g, 210, 160, 250, 88, false)
    thick(g, 250, 88, 290, 160, false)
    lab(g, 232, 100, "山")
  end
  add_rect_hit(1, left.x, left.y, left.w, left.h)
  add_rect_hit(2, right.x, right.y, right.w, right.h)
  add_rect_hit(3, 210, 88, 80, 80)
end

function FIGURES.rivers(g, box, hi)
  g:rect(36, 80, 420, 320,{color=BLACK})
  band(g, 50, 96, 90, 140, hi == 3, "源地", 64, 156)
  -- 长江：靠南折线
  thick(g, 120, 220, 180, 250, hi == 1)
  thick(g, 180, 250, 260, 270, hi == 1)
  thick(g, 260, 270, 360, 300, hi == 1)
  thick(g, 360, 300, 430, 310, hi == 1)
  lab(g, 300, 276, "长江", hi == 1 and BLACK or BLACK)
  -- 黄河：北绕一弯
  thick(g, 120, 180, 200, 150, hi == 2)
  thick(g, 200, 150, 280, 130, hi == 2)
  thick(g, 280, 130, 300, 190, hi == 2)
  thick(g, 300, 190, 360, 210, hi == 2)
  thick(g, 360, 210, 430, 220, hi == 2)
  lab(g, 220, 112, "黄河")
  add_rect_hit(1, 160, 240, 260, 80)
  add_rect_hit(2, 160, 120, 260, 100)
  add_rect_hit(3, 50, 96, 90, 140)
end

function FIGURES.tilt(g, box, hi)
  local cx, cy, r = 230, 246, 130
  g:circle(cx, cy, r,{color=BLACK})
  -- 赤道
  thick(g, cx - r, cy, cx + r, cy, hi == 1)
  lab(g, cx + r + 8, cy - 8, "赤道")
  -- 黄道约 23.5°
  local deg = 23.5 * math.pi / 180
  local dx, dy = r * math.cos(deg), r * math.sin(deg)
  thick(g, cx - dx, cy + dy, cx + dx, cy - dy, hi == 2)
  lab(g, cx + 40, cy - 88, "黄道")
  -- 地轴
  thick(g, cx + 40, cy - r - 8, cx - 40, cy + r + 8, hi == 2)
  -- 昼半球：右半
  if hi == 3 then
    hatch(g, cx - r, cy - r, r, r * 2, 7)
    g:circle(cx, cy, r,{color=BLACK})
  end
  lab(g, cx - r - 8, cy - r - 18, "夜")
  lab(g, cx + 20, cy - r - 18, "昼")
  g:circle(420, 130, 16,{fill=true,color=BLACK})
  lab(g, 440, 122, "日")
  add_rect_hit(1, cx - r, cy - 16, r * 2, 32)
  add_rect_hit(2, cx - 20, cy - r - 10, 80, 40)
  add_rect_hit(3, cx, cy - r, r, r * 2)
end

function FIGURES.landuse(g, box, hi)
  local rings = {
    { x = 190, y = 186, w = 100, h = 80, name = "商业" },
    { x = 140, y = 140, w = 200, h = 172, name = "住宅" },
    { x = 70, y = 90, w = 340, h = 272, name = "农田" },
  }
  band(g, rings[3].x, rings[3].y, rings[3].w, rings[3].h, hi == 3, "农田", 86, 110)
  band(g, rings[2].x, rings[2].y, rings[2].w, rings[2].h, hi == 2, "住宅", 156, 156)
  band(g, rings[1].x, rings[1].y, rings[1].w, rings[1].h, hi == 1, "商业", 208, 214)
  add_rect_hit(3, rings[3].x, rings[3].y, rings[3].w, rings[3].h)
  add_rect_hit(2, rings[2].x, rings[2].y, rings[2].w, rings[2].h)
  add_rect_hit(1, rings[1].x, rings[1].y, rings[1].w, rings[1].h)
end

function FIGURES.front(g, box, hi)
  band(g, 40, 120, 180, 260, hi == 1, "冷气团", 72, 236)
  band(g, 260, 120, 180, 260, hi == 2, "暖气团", 292, 236)
  if hi == 3 then
    g:rect(210, 120, 40, 260,{fill=true,color=BLACK})
    center_text(g, 230, 236, "锋", WHITE)
  else
    thick(g, 230, 120, 230, 380, true)
    lab(g, 236, 236, "锋")
  end
  -- 冷锋齿、暖锋弧的示意点
  for i = 0, 4 do
    local y = 150 + i * 44
    g:rect(198, y, 12, 12,{fill=true,color=BLACK})
    g:circle(262, y + 6, 7,{color=BLACK})
  end
  add_rect_hit(1, 40, 120, 180, 260)
  add_rect_hit(2, 260, 120, 180, 260)
  add_rect_hit(3, 210, 120, 40, 260)
end

function FIGURES.belts(g, box, hi)
  local x, w = 70, 340
  local bands = {
    { y = 300, h = 90, name = "赤道低压" },
    { y = 200, h = 100, name = "副热带高压" },
    { y = 90, h = 110, name = "西风带" },
  }
  for i = 1, 3 do
    local b = bands[i]
    band(g, x, b.y, w, b.h, hi == i, b.name, x + 20, b.y + math.floor((b.h - 16) / 2))
    add_rect_hit(i, x, b.y, w, b.h)
  end
  if hi == 3 then
    arrow(g, 300, 140, 380, 140, true)
  else
    arrow(g, 300, 140, 380, 140, false)
  end
end

local function draw_figure(g, m, hi)
  LAYER_HITS = {}
  rounded_stroke(g, FIG.x, FIG.y, FIG.w, FIG.h, 12, 2, BLACK)
  local fn = FIGURES[m.id]
  if fn then fn(g, FIG, hi) end
end

local function draw_capsule(g, box, label, on)
  local r = math.floor(box.h / 2)
  if on then
    rounded_fill(g, box.x, box.y, box.w, box.h, r, BLACK)
  else
    rounded_stroke(g, box.x, box.y, box.w, box.h, r, 2, BLACK)
  end
  center_text(g, box.x + math.floor(box.w / 2), box.y + 8, label, on and WHITE or BLACK)
end

local function draw_thumb(g, id, x, y, ink)
  if id == "stairs" then
    g:rect(x, y, 16, 10,{fill=true,color=ink})
    g:rect(x, y + 10, 28, 10,{color=ink})
    g:rect(x, y + 20, 40, 10,{color=ink})
  elseif id == "earth" or id == "tilt" then
    g:circle(x + 16, y + 16, 14,{color=ink})
    g:circle(x + 16, y + 16, 6,{fill=true,color=ink})
  elseif id == "water" or id == "current" then
    g:circle(x + 28, y + 8, 6,{color=ink})
    g:rect(x, y + 20, 36, 12,{color=ink})
  else
    g:rect(x, y + 8, 36, 16,{color=ink})
    g:line(x + 4, y + 16, x + 32, y + 16,{color=ink})
  end
end

local function open_map(s, index)
  if index then s.cursor = index end
  s.screen = "map"
  s.highlight = 0
end

local function next_hi(s, m)
  local n = m and #m.layers or 0
  s.highlight = s.highlight >= n and 0 or s.highlight + 1
end

local function prev_hi(s, m)
  local n = m and #m.layers or 0
  s.highlight = s.highlight <= 0 and n or s.highlight - 1
end

local function step_cursor(s, delta)
  local n = #MAPS
  if n < 1 then return end
  s.cursor = ((s.cursor - 1 + delta) % n) + 1
  s.highlight = 0
end

local function toggle_hi(s, i)
  s.highlight = s.highlight == i and 0 or i
end

function on_load(ctx)
  state(ctx)
  ctx:set_tick(0)
  ctx:invalidate()
end

function on_input(ctx, ev)
  local s = state(ctx)
  local handled = false
  if s.screen == "list" then
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "swipe_up" then
        step_cursor(s, 1)
      elseif ev.gesture == "swipe_down" then
        step_cursor(s, -1)
      elseif ev.gesture == "tap" then
        for i = 1, #MAPS do
          local x, y = card_xy(i)
          if hit(ev.x, ev.y, x, y, CARD_W, CARD_H) then
            open_map(s, i)
            break
          end
        end
      end
      handled = true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "left" then step_cursor(s, -1); handled = true
      elseif ev.key == "right" then step_cursor(s, 1); handled = true
      elseif ev.key == "up" then step_cursor(s, -COLS); handled = true
      elseif ev.key == "down" then step_cursor(s, COLS); handled = true
      elseif ev.key == "ok" then open_map(s); handled = true
      end
    end
  else
    local m = MAPS[s.cursor]
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "tap" then
        if hit(ev.x, ev.y, BACK_BTN.x, BACK_BTN.y, BACK_BTN.w, BACK_BTN.h) or ev.y < HEADER_H then
          s.screen = "list"
        else
          local layer = hit_layer(ev.x, ev.y)
          if layer then
            toggle_hi(s, layer)
          else
            local hit_legend = false
            if m then
              for i = 1, #m.layers do
                local box = legend_box(i)
                if hit(ev.x, ev.y, box.x, box.y, box.w, box.h) then
                  toggle_hi(s, i)
                  hit_legend = true
                  break
                end
              end
            end
            if not hit_legend and hit(ev.x, ev.y, FIG.x, FIG.y, FIG.w, FIG.h) then
              next_hi(s, m)
            end
          end
        end
      end
      handled = true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "back" then s.screen = "list"; handled = true
      elseif ev.key == "ok" or ev.key == "down" then next_hi(s, m); handled = true
      elseif ev.key == "up" then prev_hi(s, m); handled = true
      elseif ev.key == "left" then step_cursor(s, -1); handled = true
      elseif ev.key == "right" then step_cursor(s, 1); handled = true
      end
    end
  end
  if handled then ctx:invalidate() end
  return handled
end

local function draw_list(g, s, L)
  g:text(16, 14, "山河简图", { color = BLACK })
  g:text(160, 16, string.format("%d 则 · 点开看图", #MAPS), { color = BLACK })
  for i = 1, #MAPS do
    local m = MAPS[i]
    local x, y = card_xy(i)
    local on = i == s.cursor
    if on then
      rounded_fill(g, x, y, CARD_W, CARD_H, 12, BLACK)
    else
      rounded_stroke(g, x, y, CARD_W, CARD_H, 12, 2, BLACK)
    end
    local ink = on and WHITE or BLACK
    draw_thumb(g, m.id, x + 14, y + 12, ink)
    g:text(x + 64, y + 18, m.title, { color = ink })
    g:text(x + 64, y + 48, m.hint, { color = ink })
  end
  g:text(16, L.h - 20, "点卡片打开   方向键移动   OK 看图", { color = BLACK })
end

local function draw_map(g, s, L)
  local m = MAPS[s.cursor]
  g:text(BACK_BTN.x + 10, BACK_BTN.y + 10, "〈  返回", { color = BLACK })
  if not m then return end
  g:text(160, 14, m.title, { color = BLACK })
  local progress = string.format("%d/%d", s.cursor, #MAPS)
  g:text(L.w - 16 - text_w(progress), 14, progress, { color = BLACK })
  draw_figure(g, m, s.highlight)
  for i = 1, #m.layers do
    draw_capsule(g, legend_box(i), m.layers[i], s.highlight == i)
  end
  local note_y = LEGEND_Y + #m.layers * (LEGEND_H + LEGEND_GAP) + 8
  local lines = wrap_text(m.note, 276)
  for i = 1, math.min(#lines, 5) do
    g:text(504, note_y + (i - 1) * 26, lines[i], { color = BLACK })
  end
  g:text(16, L.h - 20, "点图层或图例看对应带", { color = BLACK })
end

function on_draw(ctx, g)
  local s = state(ctx)
  local L = { w = ctx.screen.width, h = ctx.screen.height }
  g:clear(WHITE)
  if s.screen == "map" then
    draw_map(g, s, L)
  else
    draw_list(g, s, L)
  end
end
