-- 受力图说 / X4 Pro
-- 力学与电路目录 + 运行时作图，点按高亮对应的力或元件。
local BLACK, WHITE = 15, 0
local VISIBLE, ROW_H, LIST_TOP = 7, 84, 96
local HEADER_H = 56
local FIG_X, FIG_Y, FIG_W, FIG_H = 24, 64, 432, 280
local CLAIM_Y, LINE_H, STEP_GAP = 352, 28, 8
local STEP_TEXT_W = 400

local SCENES = nil
local STEP_Y = {}

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

local function load_scenes(ctx)
  if SCENES then return end
  SCENES = {}
  local reader = ctx.package:open_text("scenes.tsv", {max_line_bytes = 512})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      SCENES[#SCENES + 1] = { id = c[1], title = c[2] or "", claim = c[3] or "", steps = split(c[4] or "", "|") }
    end
  end
  reader:close()
end

local function state(ctx)
  load_scenes(ctx)
  local s = ctx.state.physics_ink
  if type(s) ~= "table" then
    s = { screen = "list", cursor = 1, scroll = 0, highlight = 0 }
    ctx.state.physics_ink = s
  end
  s.cursor = math.max(1, math.min(#SCENES, math.floor(tonumber(s.cursor) or 1)))
  s.scroll = math.max(0, math.min(math.max(0, #SCENES - VISIBLE), math.floor(tonumber(s.scroll) or 0)))
  if s.cursor <= s.scroll then s.scroll = s.cursor - 1 end
  if s.cursor > s.scroll + VISIBLE then s.scroll = s.cursor - VISIBLE end
  s.highlight = math.max(0, math.floor(tonumber(s.highlight) or 0))
  local t = SCENES[s.cursor]
  if t then s.highlight = math.min(s.highlight, #t.steps) end
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

local function clip(text, max_w)
  if text_w(text) <= max_w then return text end
  local out, width, i = "", 0, 1
  while i <= #text do
    local b = string.byte(text, i)
    local step = b >= 224 and 3 or (b >= 192 and 2 or 1)
    local ch = string.sub(text, i, i + step - 1)
    local cw = step == 3 and 20 or 10
    if width + cw + 30 > max_w then break end
    out, width, i = out .. ch, width + cw, i + step
  end
  return out .. "..."
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

local function figure_steps(t)
  local y = CLAIM_Y
  local claim = wrap_text(t.claim, 432)
  y = y + #claim * LINE_H + STEP_GAP
  local rows = {}
  for i = 1, #t.steps do
    local lines = wrap_text(tostring(i) .. ". " .. t.steps[i], STEP_TEXT_W)
    local h = math.max(36, #lines * LINE_H + 8)
    rows[i] = { y = y, h = h, lines = lines }
    y = y + h
  end
  return claim, rows
end

local function I(v)
  return math.floor(v + 0.5)
end

local function rounded_rect(g, x, y, w, h, mode, color, radius)
  local r = math.max(0, math.min(radius or 8, math.floor(h / 2), math.floor(w / 2)))
  if r < 1 then
    g:rect(x, y, w, h,{fill=(mode) == "fill",color=color})
    return
  end
  if mode ~= "fill" then
    g:rect(x, y, w, h,{color=color})
    return
  end
  g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
  g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
end

local function draw_footer(g, left, right)
  g:text(24, 760, left, { color = BLACK })
  if right then g:text(456 - text_w(right), 760, right, { color = BLACK }) end
end

local function norm(x, y)
  local n = math.sqrt(x * x + y * y)
  if n < 1 then return 0, 0 end
  return x / n, y / n
end

local function mid(x1, y1, x2, y2)
  return I((x1 + x2) / 2), I((y1 + y2) / 2)
end

local function sq(g, x, y, s)
  s = s or 8
  g:rect(I(x) - math.floor(s / 2), I(y) - math.floor(s / 2), s, s,{fill=true,color=BLACK})
end

local function lab(g, box, x, y, name, dx, dy)
  local tx, ty = I(x + dx), I(y + dy)
  local tw = text_w(name)
  if tx < box.x + 3 then tx = box.x + 3 end
  if tx + tw > box.x + box.w - 3 then tx = box.x + box.w - 3 - tw end
  if ty < box.y + 2 then ty = box.y + 2 end
  if ty + 20 > box.y + box.h - 2 then ty = box.y + box.h - 22 end
  g:text(tx, ty, name, { color = BLACK })
end

local function seg(g, x1, y1, x2, y2, on)
  x1, y1, x2, y2 = I(x1), I(y1), I(x2), I(y2)
  g:line(x1, y1, x2, y2,{color=BLACK})
  if on then
    g:line(x1, y1 + 1, x2, y2 + 1,{color=BLACK})
    g:line(x1, y1 - 1, x2, y2 - 1,{color=BLACK})
    g:line(x1 + 1, y1, x2 + 1, y2,{color=BLACK})
    g:line(x1 - 1, y1, x2 - 1, y2,{color=BLACK})
    local mx, my = mid(x1, y1, x2, y2)
    sq(g, mx, my, 8)
  end
end

local function arrow(g, x1, y1, x2, y2, on)
  x1, y1, x2, y2 = I(x1), I(y1), I(x2), I(y2)
  g:line(x1, y1, x2, y2,{color=BLACK})
  local ux, uy = norm(x2 - x1, y2 - y1)
  local px, py = -uy, ux
  local back = on and 16 or 12
  local side = on and 8 or 6
  local hx, hy = x2 - ux * back, y2 - uy * back
  local ax, ay = I(hx + px * side), I(hy + py * side)
  local bx, by = I(hx - px * side), I(hy - py * side)
  g:line(x2, y2, ax, ay,{color=BLACK})
  g:line(x2, y2, bx, by,{color=BLACK})
  g:line(ax, ay, bx, by,{color=BLACK})
  if on then
    g:line(x1, y1 + 1, x2, y2 + 1,{color=BLACK})
    g:line(x1, y1 - 1, x2, y2 - 1,{color=BLACK})
    g:line(x1 + 1, y1, x2 + 1, y2,{color=BLACK})
    g:line(x1 - 1, y1, x2 - 1, y2,{color=BLACK})
    g:line(x2 + 1, y2, ax + 1, ay,{color=BLACK})
    local mx, my = mid(x1, y1, x2, y2)
    sq(g, mx, my, 8)
  end
end

local function mass(g, x, y, w, h, on)
  x, y, w, h = I(x), I(y), I(w), I(h)
  g:rect(x, y, w, h,{color=BLACK})
  if on then
    g:rect(x + 2, y + 2, w - 4, h - 4,{color=BLACK})
    if w > 12 and h > 12 then
      g:rect(x + 5, y + 5, w - 10, h - 10,{fill=true,color=BLACK})
    end
  end
end

local function ground(g, x, y, w, on)
  seg(g, x, y, x + w, y, on)
  local n = math.floor(w / 16)
  for i = 0, n do
    local sx = x + i * 16
    g:line(I(sx), I(y), I(sx - 8), I(y + 10),{color=BLACK})
  end
end

local function zig(g, x, y, w, on)
  local segs = 6
  local step = w / segs
  local amp = on and 12 or 9
  local px, py = x, y
  for i = 1, segs do
    local nx = x + i * step
    local ny = y
    if i < segs then
      ny = y + (i % 2 == 1 and -amp or amp)
    end
    seg(g, px, py, nx, ny, on)
    px, py = nx, ny
  end
end

local function battery(g, x, y, on)
  seg(g, x, y - 18, x, y + 18, on)
  seg(g, x + 10, y - 10, x + 10, y + 10, on)
  if on then sq(g, x + 5, y, 8) end
end

local function step_cursor(s, delta, reset_hi)
  local n = #SCENES
  if n < 1 then return end
  s.cursor = ((s.cursor - 1 + delta) % n) + 1
  if reset_hi then s.highlight = 0 end
end

local FIGURES = {}

function FIGURES.gravity(g, box, hi)
  local bx, by, bw, bh = box.x + 176, box.y + 88, 80, 64
  local cx, cy = bx + 40, by + 32
  ground(g, box.x + 56, by + bh, 320, false)
  mass(g, bx, by, bw, bh, hi == 1)
  arrow(g, cx, cy, cx, cy + 96, hi >= 2)
  lab(g, box, cx, cy + 96, "G", 10, -4)
end

function FIGURES.normal(g, box, hi)
  local bx, by, bw, bh = box.x + 176, box.y + 108, 80, 64
  local cx = bx + 40
  ground(g, box.x + 56, by + bh, 320, hi == 1)
  mass(g, bx, by, bw, bh, hi == 2)
  arrow(g, cx, by + bh, cx, by - 24, hi == 3)
  lab(g, box, cx, by - 24, "N", 10, -4)
end

function FIGURES.two_balance(g, box, hi)
  local bx, by, bw, bh = box.x + 176, box.y + 100, 80, 64
  local cx, cy = bx + 40, by + 32
  ground(g, box.x + 56, by + bh, 320, false)
  mass(g, bx, by, bw, bh, false)
  arrow(g, cx, cy, cx, cy + 88, hi == 1 or hi == 3)
  arrow(g, cx, cy, cx, cy - 88, hi == 2 or hi == 3)
  lab(g, box, cx, cy + 88, "G", 10, -4)
  lab(g, box, cx, cy - 88, "N", 10, -4)
end

function FIGURES.friction(g, box, hi)
  local bx, by, bw, bh = box.x + 168, box.y + 108, 88, 56
  local cx, cy = bx + 44, by + 28
  ground(g, box.x + 48, by + bh, 336, hi == 2)
  mass(g, bx, by, bw, bh, false)
  arrow(g, bx + bw, cy, bx + bw + 88, cy, hi == 1)
  arrow(g, bx, by + bh - 4, bx - 80, by + bh - 4, hi == 3)
  lab(g, box, bx + bw + 88, cy, "F", 8, -22)
  lab(g, box, bx - 80, by + bh - 4, "f", -4, -22)
end

function FIGURES.tension(g, box, hi)
  local bx, by, bw, bh = box.x + 184, box.y + 148, 64, 56
  local cx = bx + 32
  seg(g, box.x + 80, box.y + 28, box.x + box.w - 80, box.y + 28, false)
  seg(g, cx, box.y + 28, cx, by, hi == 1)
  mass(g, bx, by, bw, bh, false)
  arrow(g, cx, by + 8, cx, by - 56, hi == 2)
  arrow(g, cx, by + 28, cx, by + 28 + 72, hi == 3)
  lab(g, box, cx, by - 56, "T", 10, -4)
  lab(g, box, cx, by + 100, "G", 10, -4)
end

function FIGURES.incline(g, box, hi)
  local ax, ay = box.x + 48, box.y + box.h - 36
  local bx, by = box.x + box.w - 48, box.y + box.h - 36
  local cx, cy = bx, box.y + 48
  seg(g, ax, ay, bx, by, false)
  seg(g, bx, by, cx, cy, false)
  seg(g, ax, ay, cx, cy, false)
  local ux, uy = norm(cx - ax, cy - ay)
  local nx, ny = -uy, ux
  local mx, my = ax + (cx - ax) * 0.58, ay + (cy - ay) * 0.58
  local p1x, p1y = mx - ux * 28 + nx * 6, my - uy * 28 + ny * 6
  local p2x, p2y = mx + ux * 28 + nx * 6, my + uy * 28 + ny * 6
  local p3x, p3y = mx + ux * 28 + nx * 48, my + uy * 28 + ny * 48
  local p4x, p4y = mx - ux * 28 + nx * 48, my - uy * 28 + ny * 48
  seg(g, p1x, p1y, p2x, p2y, false)
  seg(g, p2x, p2y, p3x, p3y, false)
  seg(g, p3x, p3y, p4x, p4y, false)
  seg(g, p4x, p4y, p1x, p1y, false)
  local ox, oy = mid(p1x, p1y, p3x, p3y)
  arrow(g, ox, oy, ox, oy + 86, hi == 1)
  arrow(g, ox, oy, ox + nx * 70, oy + ny * 70, hi == 2)
  arrow(g, ox, oy, ox - ux * 80, oy - uy * 80, hi == 3)
  lab(g, box, ox, oy + 86, "G", 10, -4)
  lab(g, box, ox + nx * 70, oy + ny * 70, "Fn", 8, -20)
  lab(g, box, ox - ux * 80, oy - uy * 80, "Ft", -22, -4)
end

function FIGURES.newton3(g, box, hi)
  local y, h = box.y + 108, 64
  local lx, lw = box.x + 72, 96
  local rx = box.x + 264
  mass(g, lx, y, lw, h, hi == 1)
  mass(g, rx, y, lw, h, hi == 2)
  local midy = y + 32
  arrow(g, lx + lw, midy, rx - 8, midy, hi == 1 or hi == 3)
  arrow(g, rx, midy + 18, lx + lw + 8, midy + 18, hi == 2 or hi == 3)
  lab(g, box, rx - 8, midy, "F", 8, -22)
  lab(g, box, lx + lw + 8, midy + 18, "F'", -4, 8)
end

function FIGURES.spring(g, box, hi)
  local wall = box.x + 56
  local by, bw, bh = box.y + 108, 72, 56
  local bx = box.x + 280
  seg(g, wall, box.y + 48, wall, box.y + box.h - 48, hi == 1)
  zig(g, wall + 8, by + 28, bx - wall - 16, hi == 1)
  mass(g, bx, by, bw, bh, hi == 3)
  arrow(g, bx, by + 28, wall + 36, by + 28, hi == 2)
  lab(g, box, wall + 36, by + 28, "F", 4, -22)
end

function FIGURES.pulley(g, box, hi)
  local cx, cy, r = box.x + 216, box.y + 88, 28
  g:circle(I(cx), I(cy), r,{color=BLACK})
  if hi == 1 then
    g:circle(I(cx), I(cy), r - 4,{color=BLACK})
    sq(g, cx, cy, 8)
  end
  local leftx, rightx = cx - r, cx + r
  local by = box.y + 188
  seg(g, leftx, cy, leftx, by, hi == 2)
  seg(g, rightx, cy, rightx, by, hi == 3)
  mass(g, leftx - 28, by, 56, 44, false)
  arrow(g, leftx, by - 8, leftx, cy + r + 8, hi == 2)
  arrow(g, rightx, cy + r + 8, rightx, by, hi == 3)
  lab(g, box, leftx, cy + r + 8, "T", -22, 0)
  lab(g, box, rightx, by, "T", 10, -4)
end

function FIGURES.centripetal(g, box, hi)
  local cx, cy = box.x + math.floor(box.w / 2), box.y + math.floor(box.h / 2) + 8
  local r = 88
  g:circle(I(cx), I(cy), r,{color=BLACK})
  if hi == 1 then
    g:circle(I(cx), I(cy), r - 4,{color=BLACK})
    g:circle(I(cx), I(cy), r + 4,{color=BLACK})
  end
  local px, py = cx + r, cy
  mass(g, px - 16, py - 16, 32, 32, hi == 2)
  arrow(g, px - 18, py, cx + 10, py, hi == 3)
  sq(g, cx, cy, 6)
  lab(g, box, cx, cy, "O", 10, 8)
  lab(g, box, px - 18, py, "F", -8, -24)
end

function FIGURES.buoyancy(g, box, hi)
  local water = box.y + 118
  seg(g, box.x + 40, water, box.x + box.w - 40, water, hi == 1)
  local bx, by, bw, bh = box.x + 176, water - 20, 80, 72
  mass(g, bx, by, bw, bh, hi == 1)
  local cx, cy = bx + 40, by + 36
  arrow(g, cx, cy, cx, cy - 72, hi == 2)
  arrow(g, cx, cy, cx, cy + 72, hi == 3)
  lab(g, box, cx, cy - 72, "Fb", 10, -4)
  lab(g, box, cx, cy + 72, "G", 10, -4)
end

function FIGURES.lever(g, box, hi)
  local y = box.y + 150
  local x0, x1 = box.x + 48, box.x + box.w - 48
  local fx = box.x + 168
  seg(g, x0, y, x1, y, hi == 4)
  g:line(I(fx), I(y), I(fx - 22), I(y + 40),{color=BLACK})
  g:line(I(fx), I(y), I(fx + 22), I(y + 40),{color=BLACK})
  g:line(I(fx - 22), I(y + 40), I(fx + 22), I(y + 40),{color=BLACK})
  if hi == 1 then sq(g, fx, y, 10) else sq(g, fx, y, 6) end
  arrow(g, x0 + 36, y - 8, x0 + 36, y + 70, hi == 2)
  arrow(g, x1 - 36, y - 8, x1 - 36, y + 70, hi == 3)
  lab(g, box, fx, y, "支点", -20, -24)
  lab(g, box, x0 + 36, y + 70, "F1", -8, 4)
  lab(g, box, x1 - 36, y + 70, "F2", 8, 4)
end

function FIGURES.series(g, box, hi)
  local x0, x1 = box.x + 72, box.x + box.w - 72
  local y0, y1 = box.y + 64, box.y + 196
  seg(g, x0, y0, x1, y0, hi == 4)
  seg(g, x0, y1, x1, y1, hi == 4)
  seg(g, x0, y0, x0, y1, hi == 4)
  seg(g, x1, y0, x1, y1, hi == 4)
  battery(g, x0, (y0 + y1) / 2, hi == 1)
  zig(g, x0 + 80, y0, 88, hi == 2)
  zig(g, x1 - 168, y0, 88, hi == 3)
  if hi == 4 then
    arrow(g, x0 + 40, y1, x1 - 40, y1, true)
  end
  lab(g, box, x0, (y0 + y1) / 2, "E", -22, -8)
  lab(g, box, x0 + 124, y0, "R1", -10, 10)
  lab(g, box, x1 - 124, y0, "R2", -10, 10)
end

function FIGURES.parallel(g, box, hi)
  local x0, x1 = box.x + 72, box.x + box.w - 88
  local y0, y1, ym = box.y + 56, box.y + 216, box.y + 136
  seg(g, x0, ym, x0 + 48, ym, hi == 1 or hi == 4)
  battery(g, x0, ym, hi == 1)
  seg(g, x0 + 48, ym, x0 + 48, y0, hi == 4)
  seg(g, x0 + 48, ym, x0 + 48, y1, hi == 4)
  seg(g, x0 + 48, y0, x1, y0, hi == 2 or hi == 4)
  seg(g, x0 + 48, y1, x1, y1, hi == 3 or hi == 4)
  zig(g, x0 + 120, y0, 96, hi == 2)
  zig(g, x0 + 120, y1, 96, hi == 3)
  seg(g, x1, y0, x1, y1, hi == 4)
  if hi == 4 then
    arrow(g, x0 + 56, y0, x0 + 110, y0, true)
    arrow(g, x0 + 56, y1, x0 + 110, y1, true)
  end
  lab(g, box, x0, ym, "E", -22, -8)
  lab(g, box, x0 + 168, y0, "R1", -10, 10)
  lab(g, box, x0 + 168, y1, "R2", -10, 10)
end

function FIGURES.ohm(g, box, hi)
  local x0, x1 = box.x + 88, box.x + box.w - 88
  local y0, y1 = box.y + 72, box.y + 196
  seg(g, x0, y0, x1, y0, hi == 2)
  seg(g, x0, y1, x1, y1, hi == 2)
  seg(g, x0, y0, x0, y1, hi == 1)
  seg(g, x1, y0, x1, y1, hi == 3)
  battery(g, x0, (y0 + y1) / 2, hi == 1)
  zig(g, x0 + 120, y0, 120, hi == 3)
  if hi == 2 then
    arrow(g, x0 + 40, y1, x1 - 40, y1, true)
  end
  lab(g, box, x0, (y0 + y1) / 2, "V", -22, -8)
  lab(g, box, x0 + 180, y0, "R", -6, 10)
  lab(g, box, (x0 + x1) / 2, y1, "I", -4, 8)
end

local function draw_figure(g, scene, highlight)
  local box = { x = FIG_X, y = FIG_Y, w = FIG_W, h = FIG_H }
  g:rect(box.x, box.y, box.w, box.h,{color=BLACK})
  local fn = FIGURES[scene.id]
  if fn then fn(g, box, highlight) end
end

local function next_hi(s, t)
  local max_hi = t and #t.steps or 0
  s.highlight = s.highlight >= max_hi and 0 or s.highlight + 1
end

local function prev_hi(s, t)
  local max_hi = t and #t.steps or 0
  s.highlight = s.highlight <= 0 and max_hi or s.highlight - 1
end

local function open_scene(s, idx)
  if idx then s.cursor = idx end
  s.screen = "figure"
  s.highlight = 0
end

local function back_to_list(s)
  s.screen = "list"
end

function on_load(ctx)
  ctx:set_tick(0)
  ctx:invalidate()
end

function on_input(ctx, ev)
  local s = state(ctx)
  local handled = false
  if s.screen == "list" then
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "swipe_up" then
        step_cursor(s, 1, false)
      elseif ev.gesture == "swipe_down" then
        step_cursor(s, -1, false)
      elseif ev.gesture == "tap" then
        for vis = 1, VISIBLE do
          local idx = s.scroll + vis
          if idx > #SCENES then break end
          if hit(ev.x, ev.y, 0, LIST_TOP + (vis - 1) * ROW_H, 480, ROW_H) then
            open_scene(s, idx)
          end
        end
      end
      handled = true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "up" then step_cursor(s, -1, false); handled = true
      elseif ev.key == "down" then step_cursor(s, 1, false); handled = true
      elseif ev.key == "ok" then open_scene(s); handled = true
      end
    end
  else
    local t = SCENES[s.cursor]
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "tap" then
        if ev.y < HEADER_H then
          back_to_list(s)
        elseif hit(ev.x, ev.y, FIG_X, FIG_Y, FIG_W, FIG_H) then
          next_hi(s, t)
        else
          local rows = STEP_Y
          if type(rows) ~= "table" or #rows == 0 then
            local _, computed = figure_steps(t)
            rows = computed
          end
          for i = 1, #rows do
            if hit(ev.x, ev.y, 24, rows[i].y, 432, rows[i].h) then
              s.highlight = i
            end
          end
        end
      end
      handled = true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "back" then back_to_list(s); handled = true
      elseif ev.key == "ok" or ev.key == "down" then next_hi(s, t); handled = true
      elseif ev.key == "up" then prev_hi(s, t); handled = true
      elseif ev.key == "left" then step_cursor(s, -1, true); handled = true
      elseif ev.key == "right" then step_cursor(s, 1, true); handled = true
      end
    end
  end
  if handled then ctx:invalidate() end
  return handled
end

function on_draw(ctx, g)
  local s = state(ctx)
  g:clear(WHITE)
  if s.screen == "list" then
    g:text(24, 22, "受力图说", { color = BLACK })
    g:text(24, 50, string.format("%d 则 · 点开看图", #SCENES), { color = BLACK })
    g:line(24, 80, 456, 80,{color=BLACK})
    for vis = 1, VISIBLE do
      local idx = s.scroll + vis
      if idx > #SCENES then break end
      local t = SCENES[idx]
      local y = LIST_TOP + (vis - 1) * ROW_H
      local on = idx == s.cursor
      if on then g:rect(0, y, 480, ROW_H,{fill=true,color=BLACK}) end
      local ink = on and WHITE or BLACK
      g:text(24, y + 16, t.title, { color = ink })
      g:text(24, y + 46, clip(t.claim, 432), { color = ink })
      if not on then g:line(24, y + ROW_H - 1, 456, y + ROW_H - 1,{color=BLACK}) end
    end
    draw_footer(g, "点一行打开", string.format("%d/%d", s.cursor, #SCENES))
  else
    local t = SCENES[s.cursor]
    if not t then return end
    g:text(24, 18, t.title, { color = BLACK })
    local back = "〈 返回"
    g:text(456 - text_w(back), 18, back, { color = BLACK })
    g:line(24, 54, 456, 54,{color=BLACK})
    draw_figure(g, t, s.highlight)
    local claim, rows = figure_steps(t)
    STEP_Y = rows
    for i = 1, #claim do
      g:text(24, CLAIM_Y + (i - 1) * LINE_H, claim[i], { color = BLACK })
    end
    g:line(24, CLAIM_Y + #claim * LINE_H + 2, 456, CLAIM_Y + #claim * LINE_H + 2,{color=BLACK})
    for i = 1, #rows do
      local row = rows[i]
      local on = s.highlight == i
      if on then rounded_rect(g, 24, row.y, 432, row.h - 2, "fill", BLACK, 8) end
      for n = 1, #row.lines do
        g:text(36, row.y + 6 + (n - 1) * LINE_H, row.lines[n], { color = on and WHITE or BLACK })
      end
    end
    draw_footer(g, "点图下一步", string.format("%d/%d", s.cursor, #SCENES))
  end
end
