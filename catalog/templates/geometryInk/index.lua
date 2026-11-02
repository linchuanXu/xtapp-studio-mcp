-- 尺规几何 / X4 Pro
-- 经典定理目录 + 运行时作图，点按高亮对应边角。
local BLACK, WHITE = 15, 0
local VISIBLE, ROW_H, LIST_TOP = 7, 84, 96
local HEADER_H = 56
local FIG_X, FIG_Y, FIG_W, FIG_H = 24, 64, 432, 280
local CLAIM_Y, LINE_H, STEP_GAP = 352, 28, 8
local STEP_TEXT_W = 400

local THEOREMS = nil
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

local function load_theorems(ctx)
  if THEOREMS then return end
  THEOREMS = {}
  local reader = ctx.package:open_text("theorems.tsv", {max_line_bytes = 512})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      THEOREMS[#THEOREMS + 1] = { id = c[1], title = c[2] or "", claim = c[3] or "", steps = split(c[4] or "", "|") }
    end
  end
  reader:close()
end

local function state(ctx)
  load_theorems(ctx)
  local s = ctx.state.geometry_ink
  if type(s) ~= "table" then
    s = { screen = "list", cursor = 1, scroll = 0, highlight = 0 }
    ctx.state.geometry_ink = s
  end
  s.cursor = math.max(1, math.min(#THEOREMS, math.floor(tonumber(s.cursor) or 1)))
  s.scroll = math.max(0, math.min(math.max(0, #THEOREMS - VISIBLE), math.floor(tonumber(s.scroll) or 0)))
  if s.cursor <= s.scroll then s.scroll = s.cursor - 1 end
  if s.cursor > s.scroll + VISIBLE then s.scroll = s.cursor - VISIBLE end
  s.highlight = math.max(0, math.floor(tonumber(s.highlight) or 0))
  local t = THEOREMS[s.cursor]
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

local function oncirc(cx, cy, r, deg)
  local rad = deg * math.pi / 180
  return I(cx + r * math.cos(rad)), I(cy - r * math.sin(rad))
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

local function ring(g, cx, cy, r, on)
  cx, cy, r = I(cx), I(cy), I(r)
  g:circle(cx, cy, r,{color=BLACK})
  if on then
    if r > 6 then g:circle(cx, cy, r - 3,{color=BLACK}) end
    g:circle(cx, cy, r + 3,{color=BLACK})
  end
end

local function ra(g, vx, vy, p1x, p1y, p2x, p2y, on)
  local s = on and 16 or 14
  local ux, uy = norm(p1x - vx, p1y - vy)
  local wx, wy = norm(p2x - vx, p2y - vy)
  local ax, ay = I(vx + ux * s), I(vy + uy * s)
  local bx, by = I(vx + wx * s), I(vy + wy * s)
  local ix, iy = I(vx + (ux + wx) * s), I(vy + (uy + wy) * s)
  g:line(ax, ay, ix, iy,{color=BLACK})
  g:line(bx, by, ix, iy,{color=BLACK})
  if on then
    g:line(ax, ay + 1, ix, iy + 1,{color=BLACK})
    g:line(bx + 1, by, ix + 1, iy,{color=BLACK})
    sq(g, ix, iy, 8)
  end
end

local function ang(g, vx, vy, p1x, p1y, p2x, p2y, on)
  if not on then return end
  local ux, uy = norm(p1x - vx, p1y - vy)
  local wx, wy = norm(p2x - vx, p2y - vy)
  local bx, by = norm(ux + wx, uy + wy)
  sq(g, vx + bx * 20, vy + by * 20, 8)
end

local function ticks(g, x1, y1, x2, y2, n)
  local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
  local ux, uy = norm(x2 - x1, y2 - y1)
  local px, py = -uy, ux
  for k = 1, n do
    local off = (k - (n + 1) / 2) * 6
    local sx, sy = mx + ux * off, my + uy * off
    g:line(I(sx - px * 8), I(sy - py * 8), I(sx + px * 8), I(sy + py * 8),{color=BLACK})
  end
end

local function step_cursor(s, delta, reset_hi)
  local n = #THEOREMS
  if n < 1 then return end
  s.cursor = ((s.cursor - 1 + delta) % n) + 1
  if reset_hi then s.highlight = 0 end
end

local FIGURES = {}

function FIGURES.pythagoras(g, box, hi)
  local unit = math.floor(math.min(box.w, box.h) / 5.6)
  local ab, ac = unit * 4, unit * 3
  local ax = I(box.x + (box.w - ab) / 2 + 8)
  local ay = I(box.y + (box.h + ac) / 2 + 6)
  local bx, by = ax + ab, ay
  local cx, cy = ax, ay - ac
  seg(g, ax, ay, cx, cy, hi == 2 or hi == 4)
  seg(g, ax, ay, bx, by, hi == 2 or hi == 4)
  seg(g, bx, by, cx, cy, hi == 3 or hi == 4)
  ra(g, ax, ay, bx, by, cx, cy, hi == 1 or hi == 4)
  lab(g, box, ax, ay, "A", -20, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, cx, cy, "C", -20, -22)
end

function FIGURES.inscribed(g, box, hi)
  local cx, cy = box.x + math.floor(box.w / 2), box.y + math.floor(box.h / 2) + 6
  local r = math.floor(math.min(box.w, box.h) / 2) - 38
  ring(g, cx, cy, r, false)
  local ax, ay = oncirc(cx, cy, r, 22)
  local bx, by = oncirc(cx, cy, r, 158)
  local px, py = oncirc(cx, cy, r, 262)
  seg(g, cx, cy, ax, ay, hi == 2 or hi == 4)
  seg(g, cx, cy, bx, by, hi == 2 or hi == 4)
  seg(g, px, py, ax, ay, hi == 3 or hi == 4)
  seg(g, px, py, bx, by, hi == 3 or hi == 4)
  if hi == 1 then
    for deg = 22, 158, 17 do
      local x, y = oncirc(cx, cy, r, deg)
      sq(g, x, y, 6)
    end
  end
  ang(g, cx, cy, ax, ay, bx, by, hi == 2 or hi == 4)
  ang(g, px, py, ax, ay, bx, by, hi == 3 or hi == 4)
  sq(g, cx, cy, 6)
  lab(g, box, cx, cy, "O", 10, 8)
  lab(g, box, ax, ay, "A", 10, -4)
  lab(g, box, bx, by, "B", -22, -8)
  lab(g, box, px, py, "P", -6, 8)
end

function FIGURES.similar(g, box, hi)
  local base_y = box.y + box.h - 40
  local left = box.x + 100
  local right = box.x + 340
  local w1, h1 = 58, 82
  local w2, h2 = 86, 120
  local ax, ay = left - w1, base_y
  local bx, by = left + w1, base_y
  local cx, cy = left - math.floor(w1 * 0.28), base_y - h1
  local dx, dy = right - w2, base_y
  local ex, ey = right + w2, base_y
  local fx, fy = right - math.floor(w2 * 0.28), base_y - h2
  seg(g, ax, ay, bx, by, hi == 2)
  seg(g, ax, ay, cx, cy, false)
  seg(g, bx, by, cx, cy, false)
  seg(g, dx, dy, ex, ey, hi == 2)
  seg(g, dx, dy, fx, fy, false)
  seg(g, ex, ey, fx, fy, false)
  ang(g, ax, ay, bx, by, cx, cy, hi == 1)
  ang(g, dx, dy, ex, ey, fx, fy, hi == 1)
  ang(g, bx, by, ax, ay, cx, cy, hi == 1)
  ang(g, ex, ey, dx, dy, fx, fy, hi == 1)
  if hi == 3 then
    seg(g, cx, cy, cx, ay, true)
    seg(g, fx, fy, fx, dy, true)
  else
    g:line(I(cx), I(cy), I(cx), I(ay),{color=BLACK})
    g:line(I(fx), I(fy), I(fx), I(dy),{color=BLACK})
  end
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, cx, cy, "C", -10, -22)
  lab(g, box, dx, dy, "D", -18, 6)
  lab(g, box, ex, ey, "E", 8, 6)
  lab(g, box, fx, fy, "F", -10, -22)
end

function FIGURES.parallelogram(g, box, hi)
  local w, h, skew = 220, 118, 54
  local x = I(box.x + (box.w - w - skew) / 2)
  local y = I(box.y + (box.h - h) / 2)
  local ax, ay = x, y + h
  local bx, by = x + w, y + h
  local cx, cy = x + w + skew, y
  local dx, dy = x + skew, y
  local ox, oy = mid(ax, ay, cx, cy)
  seg(g, ax, ay, bx, by, hi == 1)
  seg(g, dx, dy, cx, cy, hi == 1)
  seg(g, ax, ay, dx, dy, hi == 2)
  seg(g, bx, by, cx, cy, hi == 2)
  seg(g, ax, ay, cx, cy, hi == 3)
  seg(g, dx, dy, bx, by, hi == 3)
  if hi == 1 then ticks(g, ax, ay, bx, by, 1); ticks(g, dx, dy, cx, cy, 1) end
  if hi == 2 then ticks(g, ax, ay, dx, dy, 2); ticks(g, bx, by, cx, cy, 2) end
  if hi == 3 then sq(g, ox, oy, 8) end
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, cx, cy, "C", 8, -22)
  lab(g, box, dx, dy, "D", -18, -22)
end

function FIGURES.special_right(g, box, hi)
  local short = math.floor(math.min(box.h - 56, (box.w - 80) / 1.85))
  local long = I(short * 1.732)
  local ax = I(box.x + (box.w - long) / 2)
  local ay = I(box.y + (box.h + short) / 2)
  local bx, by = ax + long, ay
  local cx, cy = ax, ay - short
  seg(g, ax, ay, bx, by, false)
  seg(g, ax, ay, cx, cy, hi == 3 or hi == 4)
  seg(g, bx, by, cx, cy, hi == 4)
  ra(g, ax, ay, bx, by, cx, cy, hi == 1)
  ang(g, bx, by, ax, ay, cx, cy, hi == 2)
  ang(g, cx, cy, ax, ay, bx, by, hi == 2)
  lab(g, box, ax, ay, "A", -20, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, cx, cy, "C", -20, -22)
  g:text(I(bx - 52), I(by - 40), "30", { color = BLACK })
  g:text(I(cx + 14), I(cy + 28), "60", { color = BLACK })
end

function FIGURES.tangent(g, box, hi)
  local r = math.floor(math.min(box.w, box.h) / 2) - 44
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2) + 22
  local tx, ty = cx, cy - r
  ring(g, cx, cy, r, hi == 1)
  seg(g, tx - r - 16, ty, tx + r + 16, ty, hi == 1 or hi == 4)
  seg(g, cx, cy, tx, ty, hi == 3 or hi == 4)
  ra(g, tx, ty, tx + 40, ty, cx, cy, hi == 4)
  if hi == 2 then sq(g, tx, ty, 10) else sq(g, tx, ty, 6) end
  sq(g, cx, cy, 6)
  lab(g, box, cx, cy, "O", 10, 8)
  lab(g, box, tx, ty, "T", 12, -22)
end

function FIGURES.vertical(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local ax, ay = cx - 120, cy - 72
  local bx, by = cx + 120, cy + 72
  local px, py = cx - 120, cy + 72
  local qx, qy = cx + 120, cy - 72
  seg(g, ax, ay, bx, by, hi == 1)
  seg(g, px, py, qx, qy, hi == 1)
  ang(g, cx, cy, ax, ay, px, py, hi == 2 or hi == 3)
  ang(g, cx, cy, bx, by, qx, qy, hi == 2 or hi == 3)
  sq(g, cx, cy, 6)
  lab(g, box, ax, ay, "A", -18, -22)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, px, py, "C", -18, 6)
  lab(g, box, qx, qy, "D", 8, -22)
  lab(g, box, cx, cy, "O", 12, 8)
  if hi == 3 then lab(g, box, cx, cy, "等", -28, -24) end
end

function FIGURES.angle_sum(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local ax, ay = cx - 128, cy + 78
  local bx, by = cx + 136, cy + 64
  local px, py = cx - 16, cy - 92
  seg(g, ax, ay, bx, by, hi == 1)
  seg(g, ax, ay, px, py, hi == 1)
  seg(g, bx, by, px, py, hi == 1)
  ang(g, ax, ay, bx, by, px, py, hi == 2 or hi == 3)
  ang(g, bx, by, ax, ay, px, py, hi == 2 or hi == 3)
  ang(g, px, py, ax, ay, bx, by, hi == 2 or hi == 3)
  if hi == 3 then lab(g, box, cx, cy, "180", -20, -8) end
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, px, py, "C", -8, -22)
end

function FIGURES.isosceles(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local ax, ay = cx - 118, cy + 80
  local bx, by = cx + 118, cy + 80
  local px, py = cx, cy - 88
  local mx, my = cx, ay
  seg(g, ax, ay, px, py, hi == 1)
  seg(g, bx, by, px, py, hi == 1)
  seg(g, ax, ay, bx, by, hi == 3)
  if hi == 1 then ticks(g, ax, ay, px, py, 1); ticks(g, bx, by, px, py, 1) end
  ang(g, ax, ay, bx, by, px, py, hi == 2)
  ang(g, bx, by, ax, ay, px, py, hi == 2)
  seg(g, px, py, mx, my, hi == 3)
  if hi == 3 then
    sq(g, mx, my, 8)
    ticks(g, ax, ay, mx, my, 1)
    ticks(g, mx, my, bx, by, 1)
  end
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, px, py, "C", -8, -22)
  lab(g, box, mx, my, "M", 10, 6)
end

function FIGURES.midline(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local ax, ay = cx - 140, cy + 80
  local bx, by = cx + 140, cy + 80
  local px, py = cx - 36, cy - 92
  local mx, my = mid(ax, ay, px, py)
  local nx, ny = mid(bx, by, px, py)
  seg(g, ax, ay, bx, by, hi == 3 or hi == 4)
  seg(g, ax, ay, px, py, false)
  seg(g, bx, by, px, py, false)
  seg(g, mx, my, nx, ny, hi == 2 or hi == 3 or hi == 4)
  if hi == 1 or hi == 4 then sq(g, mx, my, 8); sq(g, nx, ny, 8) else sq(g, mx, my, 5); sq(g, nx, ny, 5) end
  if hi == 4 then ticks(g, mx, my, nx, ny, 1); ticks(g, ax, ay, bx, by, 2) end
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, px, py, "C", -8, -22)
  lab(g, box, mx, my, "M", -20, -8)
  lab(g, box, nx, ny, "N", 8, -8)
end

function FIGURES.thales(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2) + 12
  local r = math.floor(math.min(box.w, box.h) / 2) - 40
  ring(g, cx, cy, r, false)
  local ax, ay = cx - r, cy
  local bx, by = cx + r, cy
  local px, py = oncirc(cx, cy, r, 90)
  seg(g, ax, ay, bx, by, hi == 1)
  seg(g, ax, ay, px, py, hi == 3)
  seg(g, bx, by, px, py, hi == 3)
  if hi == 2 then sq(g, px, py, 10) end
  ra(g, px, py, ax, ay, bx, by, hi == 4)
  sq(g, cx, cy, 5)
  lab(g, box, ax, ay, "A", -20, 8)
  lab(g, box, bx, by, "B", 8, 8)
  lab(g, box, px, py, "P", -8, -22)
  lab(g, box, cx, cy, "O", 8, 8)
end

function FIGURES.exterior(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local ax, ay = cx - 130, cy + 70
  local bx, by = cx + 20, cy + 70
  local px, py = cx - 40, cy - 88
  local dx, dy = cx + 150, cy + 70
  seg(g, ax, ay, bx, by, false)
  seg(g, bx, by, dx, dy, hi == 1)
  seg(g, ax, ay, px, py, hi == 3)
  seg(g, bx, by, px, py, hi == 1 or hi == 2)
  ang(g, bx, by, dx, dy, px, py, hi == 1 or hi == 2 or hi == 3)
  ang(g, bx, by, ax, ay, px, py, hi == 2)
  ang(g, ax, ay, bx, by, px, py, hi == 3)
  ang(g, px, py, ax, ay, bx, by, hi == 3)
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", -8, 6)
  lab(g, box, px, py, "C", -8, -22)
  lab(g, box, dx, dy, "D", 8, 6)
end

function FIGURES.corresponding(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local ya, yb = cy - 48, cy + 52
  local x0, x1 = box.x + 36, box.x + box.w - 36
  local tx0, ty0 = cx - 80, box.y + 28
  local tx1, ty1 = cx + 100, box.y + box.h - 28
  local function cross(y)
    local t = (y - ty0) / (ty1 - ty0)
    return I(tx0 + t * (tx1 - tx0)), y
  end
  local i1x, i1y = cross(ya)
  local i2x, i2y = cross(yb)
  seg(g, x0, ya, x1, ya, hi == 3)
  seg(g, x0, yb, x1, yb, hi == 3)
  seg(g, tx0, ty0, tx1, ty1, hi == 1)
  ang(g, i1x, i1y, i1x + 50, i1y, tx1, ty1, hi == 2)
  ang(g, i2x, i2y, i2x + 50, i2y, tx1, ty1, hi == 2)
  if hi == 3 then ticks(g, x0, ya, x1, ya, 1); ticks(g, x0, yb, x1, yb, 1) end
  lab(g, box, x0, ya, "a", 4, -22)
  lab(g, box, x0, yb, "b", 4, 6)
  lab(g, box, tx0, ty0, "E", -18, 0)
  lab(g, box, tx1, ty1, "F", 8, -4)
end

function FIGURES.rectangle(g, box, hi)
  local w, h = 260, 136
  local x = I(box.x + (box.w - w) / 2)
  local y = I(box.y + (box.h - h) / 2)
  local ax, ay = x, y + h
  local bx, by = x + w, y + h
  local cx, cy = x + w, y
  local dx, dy = x, y
  local ox, oy = x + math.floor(w / 2), y + math.floor(h / 2)
  seg(g, ax, ay, bx, by, hi == 1)
  seg(g, bx, by, cx, cy, hi == 1)
  seg(g, cx, cy, dx, dy, hi == 1)
  seg(g, dx, dy, ax, ay, hi == 1)
  seg(g, ax, ay, cx, cy, hi >= 2)
  seg(g, dx, dy, bx, by, hi >= 2)
  if hi == 3 then ticks(g, ax, ay, cx, cy, 1); ticks(g, dx, dy, bx, by, 1) end
  if hi == 4 then sq(g, ox, oy, 8) else sq(g, ox, oy, 5) end
  lab(g, box, ax, ay, "A", -18, 6)
  lab(g, box, bx, by, "B", 8, 6)
  lab(g, box, cx, cy, "C", 8, -22)
  lab(g, box, dx, dy, "D", -18, -22)
  if hi == 4 then lab(g, box, ox, oy, "O", 10, -22) end
end

function FIGURES.circle_chord(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2) - 4
  local r = math.floor(math.min(box.w, box.h) / 2) - 36
  ring(g, cx, cy, r, false)
  local drop = math.floor(r * 0.48)
  local half = I(math.sqrt(r * r - drop * drop))
  local mx, my = cx, cy + drop
  local ax, ay = cx - half, my
  local bx, by = cx + half, my
  seg(g, ax, ay, bx, by, hi == 3)
  seg(g, cx, cy, mx, my, hi == 1)
  ra(g, mx, my, ax, ay, cx, cy, hi == 1)
  if hi == 2 then sq(g, mx, my, 10) else sq(g, mx, my, 5) end
  if hi == 3 then ticks(g, ax, ay, mx, my, 1); ticks(g, mx, my, bx, by, 1) end
  sq(g, cx, cy, 5)
  lab(g, box, cx, cy, "O", -22, -18)
  lab(g, box, ax, ay, "A", -20, 8)
  lab(g, box, bx, by, "B", 8, 8)
  lab(g, box, mx, my, "M", 12, 10)
end

function FIGURES.altitude(g, box, hi)
  local cx = box.x + math.floor(box.w / 2)
  local cy = box.y + math.floor(box.h / 2)
  local px, py = cx - 118, cy + 72
  local ax, ay = cx + 122, cy + 72
  local bx, by = cx - 118, cy - 88
  local mx, my = mid(ax, ay, bx, by)
  seg(g, px, py, ax, ay, false)
  seg(g, px, py, bx, by, false)
  seg(g, ax, ay, bx, by, hi == 3)
  ra(g, px, py, ax, ay, bx, by, false)
  if hi == 1 then sq(g, mx, my, 10) else sq(g, mx, my, 5) end
  seg(g, px, py, mx, my, hi == 2 or hi == 3)
  if hi == 3 then ticks(g, px, py, mx, my, 1); ticks(g, ax, ay, bx, by, 2) end
  lab(g, box, ax, ay, "A", 8, 6)
  lab(g, box, bx, by, "B", -20, -22)
  lab(g, box, px, py, "C", -20, 6)
  lab(g, box, mx, my, "M", 12, -20)
end

local function draw_figure(g, theorem, highlight)
  local box = { x = FIG_X, y = FIG_Y, w = FIG_W, h = FIG_H }
  g:rect(box.x, box.y, box.w, box.h,{color=BLACK})
  local fn = FIGURES[theorem.id]
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
          if idx > #THEOREMS then break end
          if hit(ev.x, ev.y, 0, LIST_TOP + (vis - 1) * ROW_H, 480, ROW_H) then
            s.cursor = idx; s.screen = "figure"; s.highlight = 0
          end
        end
      end
      handled = true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "up" then step_cursor(s, -1, false); handled = true
      elseif ev.key == "down" then step_cursor(s, 1, false); handled = true
      elseif ev.key == "ok" then s.screen = "figure"; s.highlight = 0; handled = true
      end
    end
  else
    local t = THEOREMS[s.cursor]
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "tap" then
        if ev.y < HEADER_H then
          s.screen = "list"
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
      if ev.key == "back" then s.screen = "list"; handled = true
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
    g:text(24, 22, "尺规几何", { color = BLACK })
    g:text(24, 50, string.format("%d 则 · 点开看图", #THEOREMS), { color = BLACK })
    g:line(24, 80, 456, 80,{color=BLACK})
    for vis = 1, VISIBLE do
      local idx = s.scroll + vis
      if idx > #THEOREMS then break end
      local t = THEOREMS[idx]
      local y = LIST_TOP + (vis - 1) * ROW_H
      local on = idx == s.cursor
      if on then g:rect(0, y, 480, ROW_H,{fill=true,color=BLACK}) end
      local ink = on and WHITE or BLACK
      g:text(24, y + 16, t.title, { color = ink })
      g:text(24, y + 46, clip(t.claim, 432), { color = ink })
      if not on then g:line(24, y + ROW_H - 1, 456, y + ROW_H - 1,{color=BLACK}) end
    end
    draw_footer(g, "点一行打开", string.format("%d/%d", s.cursor, #THEOREMS))
  else
    local t = THEOREMS[s.cursor]
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
    draw_footer(g, "点图下一步", string.format("%d/%d", s.cursor, #THEOREMS))
  end
end
