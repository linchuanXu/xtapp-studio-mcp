-- 细胞图鉴 / X4 Pro
-- 结构目录 + 运行时作图，点部位或热区加粗并写出用途。
local BLACK, WHITE = 15, 0
local VISIBLE, ROW_H, LIST_TOP = 7, 84, 96
local HEADER_H = 56
local FIG_X, FIG_Y, FIG_W, FIG_H = 24, 64, 432, 280
local DETAIL_Y, PART_TOP, PART_H, LINE_H = 352, 428, 44, 26

local FIGURES_DATA = nil
local PART_HITS = {}

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

local function parse_parts(raw)
  local cols = split(raw or "", "|")
  local parts = {}
  local i = 1
  while i + 1 <= #cols do
    parts[#parts + 1] = { name = cols[i], use = cols[i + 1] }
    i = i + 2
  end
  return parts
end

local function load_figures(ctx)
  if FIGURES_DATA then return end
  FIGURES_DATA = {}
  local reader = ctx.package:open_text("figures.tsv", {max_line_bytes = 512})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      FIGURES_DATA[#FIGURES_DATA + 1] = {
        id = c[1], title = c[2] or "", blurb = c[3] or "", parts = parse_parts(c[4]),
      }
    end
  end
  reader:close()
end

local function state(ctx)
  load_figures(ctx)
  local s = ctx.state.cell_atlas
  if type(s) ~= "table" then
    s = { screen = "list", cursor = 1, scroll = 0, highlight = 0 }
    ctx.state.cell_atlas = s
  end
  s.cursor = math.max(1, math.min(#FIGURES_DATA, math.floor(tonumber(s.cursor) or 1)))
  s.scroll = math.max(0, math.min(math.max(0, #FIGURES_DATA - VISIBLE), math.floor(tonumber(s.scroll) or 0)))
  if s.cursor <= s.scroll then s.scroll = s.cursor - 1 end
  if s.cursor > s.scroll + VISIBLE then s.scroll = s.cursor - VISIBLE end
  s.highlight = math.max(0, math.floor(tonumber(s.highlight) or 0))
  local fig = FIGURES_DATA[s.cursor]
  if fig then s.highlight = math.min(s.highlight, #fig.parts) end
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

local function sq(g, x, y, s)
  s = s or 8
  g:rect(I(x) - math.floor(s / 2), I(y) - math.floor(s / 2), s, s,{fill=true,color=BLACK})
end

local function ring(g, cx, cy, r, on)
  cx, cy, r = I(cx), I(cy), I(r)
  g:circle(cx, cy, r,{color=BLACK})
  if on then
    if r > 6 then g:circle(cx, cy, r - 3,{color=BLACK}) end
    g:circle(cx, cy, r + 3,{color=BLACK})
  end
end

local function seg(g, x1, y1, x2, y2, on)
  x1, y1, x2, y2 = I(x1), I(y1), I(x2), I(y2)
  g:line(x1, y1, x2, y2,{color=BLACK})
  if on then
    g:line(x1, y1 + 1, x2, y2 + 1,{color=BLACK})
    g:line(x1, y1 - 1, x2, y2 - 1,{color=BLACK})
    g:line(x1 + 1, y1, x2 + 1, y2,{color=BLACK})
    g:line(x1 - 1, y1, x2 - 1, y2,{color=BLACK})
  end
end

local function box_stroke(g, x, y, w, h, on)
  x, y, w, h = I(x), I(y), I(w), I(h)
  g:rect(x, y, w, h,{color=BLACK})
  if on then
    g:rect(x + 3, y + 3, w - 6, h - 6,{color=BLACK})
    g:rect(x - 1, y - 1, w + 2, h + 2,{color=BLACK})
  end
end

local function stadium(g, x, y, w, h, on)
  x, y, w, h = I(x), I(y), I(w), I(h)
  local function outline(off)
    local ox, oy, ow, oh = x - off, y - off, w + off * 2, h + off * 2
    local rr = math.max(1, math.floor(oh / 2))
    g:circle(ox + rr, oy + rr, rr,{color=BLACK})
    g:circle(ox + ow - 1 - rr, oy + rr, rr,{color=BLACK})
    g:line(ox + rr, oy, ox + ow - rr, oy,{color=BLACK})
    g:line(ox + rr, oy + oh, ox + ow - rr, oy + oh,{color=BLACK})
  end
  outline(0)
  if on then outline(3) end
end

local function step_cursor(s, delta, reset_hi)
  local n = #FIGURES_DATA
  if n < 1 then return end
  s.cursor = ((s.cursor - 1 + delta) % n) + 1
  if reset_hi then s.highlight = 0 end
end

local DRAW = {}

function DRAW.animal(g, box, hi)
  local cx = I(box.x + box.w / 2)
  local cy = I(box.y + box.h / 2 + 4)
  local r = I(math.min(box.w, box.h) / 2) - 16
  ring(g, cx, cy, r, hi == 1)
  if hi == 2 then
    sq(g, cx + 8, cy + 52, 8)
    sq(g, cx + 36, cy + 28, 8)
  end
  local nx, ny, nr = cx - 36, cy - 8, 34
  ring(g, nx, ny, nr, hi == 3)
  g:circle(I(nx), I(ny), 9,{fill=true,color=BLACK})
  local mx, my, mw, mh = cx + 48, cy - 56, 70, 32
  stadium(g, mx, my, mw, mh, hi == 4)
  g:line(I(mx + 16), I(my + 8), I(mx + 50), I(my + 8),{color=BLACK})
  g:line(I(mx + 20), I(my + 16), I(mx + 56), I(my + 16),{color=BLACK})
  g:line(I(mx + 16), I(my + 24), I(mx + 48), I(my + 24),{color=BLACK})
  local dots = { { cx + 70, cy + 40 }, { cx + 82, cy + 52 }, { cx + 58, cy + 56 }, { cx + 74, cy + 64 } }
  for i = 1, #dots do
    g:circle(I(dots[i][1]), I(dots[i][2]), hi == 5 and 4 or 2,{fill=true,color=BLACK})
  end
  PART_HITS = {
    { x = cx - 40, y = box.y + 8, w = 80, h = 40 },
    { x = cx - 10, y = cy + 36, w = 50, h = 40 },
    { x = nx - nr, y = ny - nr, w = nr * 2, h = nr * 2 },
    { x = mx, y = my, w = mw, h = mh },
    { x = cx + 50, y = cy + 32, w = 48, h = 44 },
  }
end

function DRAW.plant(g, box, hi)
  local x, y = box.x + 28, box.y + 14
  local w, h = box.w - 56, box.h - 28
  box_stroke(g, x, y, w, h, hi == 1)
  box_stroke(g, x + 8, y + 8, w - 16, h - 16, hi == 2)
  local vx, vy, vw, vh = x + math.floor(w / 2) - 6, y + 26, math.floor(w / 2) - 18, h - 52
  box_stroke(g, vx, vy, vw, vh, hi == 3)
  stadium(g, x + 22, y + h - 78, 86, 36, hi == 4)
  g:line(I(x + 36), I(y + h - 66), I(x + 90), I(y + h - 66),{color=BLACK})
  g:line(I(x + 40), I(y + h - 56), I(x + 86), I(y + h - 56),{color=BLACK})
  local nx, ny, nr = x + 58, y + 62, 26
  ring(g, nx, ny, nr, hi == 5)
  g:circle(I(nx), I(ny), 7,{fill=true,color=BLACK})
  stadium(g, x + 28, y + 108, 56, 24, hi == 6)
  PART_HITS = {
    { x = x, y = y, w = w, h = 20 },
    { x = x + 8, y = y + 8, w = 24, h = h - 16 },
    { x = vx, y = vy, w = vw, h = vh },
    { x = x + 22, y = y + h - 78, w = 86, h = 36 },
    { x = nx - nr, y = ny - nr, w = nr * 2, h = nr * 2 },
    { x = x + 28, y = y + 108, w = 56, h = 24 },
  }
end

function DRAW.mito(g, box, hi)
  local x, y, w, h = box.x + 48, box.y + 46, box.w - 96, box.h - 92
  stadium(g, x, y, w, h, hi == 1)
  stadium(g, x + 16, y + 16, w - 32, h - 32, hi == 2)
  local inner_l, inner_r = x + 40, x + w - 40
  local mid = y + math.floor(h / 2)
  for i = 0, 4 do
    local yy = y + 36 + i * 22
    if yy < y + h - 36 then
      seg(g, inner_l, yy, x + math.floor(w / 2) + (i % 2) * 24 - 12, yy, hi == 3)
    end
  end
  if hi == 4 then
    sq(g, x + math.floor(w / 2) + 36, mid + 18, 8)
    sq(g, x + math.floor(w / 2) + 60, mid - 10, 8)
  end
  ring(g, x + w - 70, y + 48, 16, hi == 5)
  PART_HITS = {
    { x = x, y = y, w = w, h = 20 },
    { x = x + 16, y = y + 16, w = 28, h = h - 32 },
    { x = inner_l, y = y + 32, w = 90, h = h - 64 },
    { x = x + math.floor(w / 2) + 20, y = mid, w = 70, h = 40 },
    { x = x + w - 90, y = y + 30, w = 40, h = 40 },
  }
end

function DRAW.chloro(g, box, hi)
  local x, y, w, h = box.x + 40, box.y + 40, box.w - 80, box.h - 80
  stadium(g, x, y, w, h, hi == 1)
  stadium(g, x + 14, y + 14, w - 28, h - 28, hi == 2)
  local gx, gy = x + 40, y + 48
  for stack = 0, 2 do
    local sx = gx + stack * 86
    for n = 0, 3 do
      local ry = gy + n * 12
      box_stroke(g, sx, ry, 64, 10, hi == 3 or (hi == 4 and stack == 1))
    end
    if hi == 4 and stack == 1 then
      sq(g, sx + 32, gy + 20, 8)
    end
  end
  seg(g, gx + 64, gy + 18, gx + 86, gy + 18, hi == 3)
  seg(g, gx + 150, gy + 30, gx + 172, gy + 30, hi == 3)
  if hi == 5 then
    sq(g, x + w - 70, y + h - 56, 8)
    sq(g, x + 70, y + h - 48, 8)
  end
  PART_HITS = {
    { x = x, y = y, w = w, h = 18 },
    { x = x + 14, y = y + 14, w = 22, h = h - 28 },
    { x = gx, y = gy, w = 70, h = 52 },
    { x = gx + 86, y = gy, w = 70, h = 52 },
    { x = x + 48, y = y + h - 70, w = w - 96, h = 36 },
  }
end

function DRAW.nucleus(g, box, hi)
  local cx = I(box.x + box.w / 2)
  local cy = I(box.y + box.h / 2)
  local r = 108
  ring(g, cx, cy, r, hi == 1)
  ring(g, cx, cy, r - 8, hi == 1)
  for deg = 20, 340, 40 do
    local rad = deg * math.pi / 180
    local px = I(cx + (r - 4) * math.cos(rad))
    local py = I(cy - (r - 4) * math.sin(rad))
    g:circle(px, py, hi == 2 and 5 or 3,{fill=(hi == 2) and true or false,color=BLACK})
  end
  for i = 1, 7 do
    local a = (i * 47) * math.pi / 180
    local x1 = cx + math.cos(a) * 28
    local y1 = cy + math.sin(a) * 18 - 8
    local x2 = x1 + math.cos(a + 0.8) * 36
    local y2 = y1 + math.sin(a + 0.8) * 22
    seg(g, x1, y1, x2, y2, hi == 3)
  end
  ring(g, cx + 18, cy + 8, 22, hi == 4)
  g:circle(cx + 18, cy + 8, 6,{fill=true,color=BLACK})
  if hi == 5 then
    sq(g, cx - 50, cy + 40, 8)
    sq(g, cx + 56, cy - 36, 8)
  end
  PART_HITS = {
    { x = cx - r, y = cy - r, w = 36, h = r * 2 },
    { x = cx + r - 28, y = cy - 24, w = 36, h = 48 },
    { x = cx - 70, y = cy - 50, w = 80, h = 40 },
    { x = cx, y = cy - 12, w = 48, h = 44 },
    { x = cx - 60, y = cy + 28, w = 40, h = 36 },
  }
end

function DRAW.chrom(g, box, hi)
  local left = box.x + 36
  local cy = box.y + 96
  for i = 0, 18 do
    local x1 = left + i * 10
    local y1 = cy + math.sin(i * 0.7) * 16
    local y2 = cy + math.sin((i + 1) * 0.7) * 16
    seg(g, x1, y1, x1 + 10, y2, hi == 1)
    local z1 = cy + 28 + math.sin(i * 0.7 + 2.2) * 16
    local z2 = cy + 28 + math.sin((i + 1) * 0.7 + 2.2) * 16
    seg(g, x1, z1, x1 + 10, z2, hi == 1)
    if i % 3 == 0 then g:line(I(x1), I(y1), I(x1), I(z1),{color=BLACK}) end
  end
  ring(g, box.x + 96, box.y + 200, 16, hi == 2)
  ring(g, box.x + 136, box.y + 188, 16, hi == 2)
  seg(g, box.x + 96, box.y + 216, box.x + 200, box.y + 216, hi == 3)
  seg(g, box.x + 96, box.y + 228, box.x + 200, box.y + 228, hi == 3)
  local cx, cy2 = box.x + 320, box.y + 150
  seg(g, cx - 36, cy2 - 70, cx + 8, cy2 - 8, hi == 5)
  seg(g, cx + 20, cy2 - 70, cx - 8, cy2 - 8, hi == 5)
  seg(g, cx - 36, cy2 + 70, cx + 8, cy2 + 8, hi == 5)
  seg(g, cx + 20, cy2 + 70, cx - 8, cy2 + 8, hi == 5)
  g:circle(I(cx), I(cy2), hi == 4 and 8 or 5,{fill=true,color=BLACK})
  PART_HITS = {
    { x = left, y = box.y + 70, w = 200, h = 80 },
    { x = box.x + 80, y = box.y + 180, w = 80, h = 40 },
    { x = box.x + 96, y = box.y + 208, w = 110, h = 28 },
    { x = cx - 16, y = cy2 - 16, w = 32, h = 32 },
    { x = cx - 44, y = cy2 - 76, w = 72, h = 64 },
  }
end

function DRAW.membrane(g, box, hi)
  local y1, y2 = box.y + 88, box.y + 168
  local x0 = box.x + 28
  for i = 0, 11 do
    local x = x0 + i * 32
    g:circle(I(x + 10), I(y1), hi == 1 and 8 or 6,{color=BLACK})
    g:circle(I(x + 10), I(y2), hi == 1 and 8 or 6,{color=BLACK})
    seg(g, x + 10, y1 + 6, x + 10, y2 - 6, hi == 2)
    if i % 2 == 1 then
      g:line(I(x + 6), I(y1 + 18), I(x + 14), I(y1 + 30),{color=BLACK})
      g:line(I(x + 6), I(y2 - 18), I(x + 14), I(y2 - 30),{color=BLACK})
    end
  end
  if hi == 3 then
    box_stroke(g, x0, y1 - 12, 384, y2 - y1 + 24, true)
  else
    g:line(I(x0), I(y1 - 14), I(x0 + 384), I(y1 - 14),{color=BLACK})
    g:line(I(x0), I(y2 + 14), I(x0 + 384), I(y2 + 14),{color=BLACK})
  end
  local px, py, pw, ph = box.x + 188, box.y + 70, 52, 126
  box_stroke(g, px, py, pw, ph, hi == 4)
  seg(g, px + 10, py - 18, px + 10, py, hi == 5)
  seg(g, px + 26, py - 28, px + 26, py, hi == 5)
  seg(g, px + 42, py - 16, px + 42, py, hi == 5)
  g:circle(I(px + 10), I(py - 20), 3,{fill=true,color=BLACK})
  g:circle(I(px + 26), I(py - 30), 3,{fill=true,color=BLACK})
  g:circle(I(px + 42), I(py - 18), 3,{fill=true,color=BLACK})
  PART_HITS = {
    { x = x0, y = y1 - 16, w = 160, h = 28 },
    { x = x0 + 40, y = y1 + 20, w = 80, h = y2 - y1 - 40 },
    { x = x0 + 220, y = y1 - 14, w = 80, h = y2 - y1 + 28 },
    { x = px, y = py, w = pw, h = ph },
    { x = px, y = py - 36, w = pw, h = 36 },
  }
end

function DRAW.neuron(g, box, hi)
  local sx, sy, sr = box.x + 118, box.y + 128, 36
  ring(g, sx, sy, sr, hi == 2)
  g:circle(I(sx - 8), I(sy - 4), 8,{fill=true,color=BLACK})
  seg(g, sx - 20, sy - 28, sx - 64, sy - 70, hi == 1)
  seg(g, sx - 64, sy - 70, sx - 86, sy - 52, hi == 1)
  seg(g, sx - 64, sy - 70, sx - 78, sy - 88, hi == 1)
  seg(g, sx - 16, sy + 28, sx - 54, sy + 72, hi == 1)
  seg(g, sx - 54, sy + 72, sx - 80, sy + 58, hi == 1)
  seg(g, sx + sr - 4, sy, box.x + 300, sy, hi == 3)
  for i = 0, 3 do
    local mx = box.x + 178 + i * 28
    box_stroke(g, mx, sy - 12, 20, 24, hi == 4)
  end
  seg(g, box.x + 300, sy, box.x + 360, sy - 36, hi == 5)
  seg(g, box.x + 300, sy, box.x + 368, sy + 8, hi == 5)
  seg(g, box.x + 300, sy, box.x + 352, sy + 40, hi == 5)
  g:circle(I(box.x + 360), I(sy - 36), 4,{fill=true,color=BLACK})
  g:circle(I(box.x + 368), I(sy + 8), 4,{fill=true,color=BLACK})
  g:circle(I(box.x + 352), I(sy + 40), 4,{fill=true,color=BLACK})
  PART_HITS = {
    { x = box.x + 24, y = box.y + 40, w = 80, h = 80 },
    { x = sx - sr, y = sy - sr, w = sr * 2, h = sr * 2 },
    { x = sx + sr, y = sy - 16, w = 80, h = 32 },
    { x = box.x + 176, y = sy - 16, w = 116, h = 32 },
    { x = box.x + 300, y = sy - 48, w = 80, h = 100 },
  }
end

function DRAW.blood(g, box, hi)
  local y = box.y + 90
  ring(g, box.x + 86, y + 40, 40, hi == 1)
  ring(g, box.x + 86, y + 40, 16, hi == 1)
  ring(g, box.x + 220, y + 40, 46, hi == 2)
  ring(g, box.x + 208, y + 28, 14, hi == 2)
  ring(g, box.x + 232, y + 46, 12, hi == 2)
  stadium(g, box.x + 318, y + 28, 48, 22, hi == 3)
  stadium(g, box.x + 338, y + 54, 40, 18, hi == 3)
  if hi == 4 then
    sq(g, box.x + 40, box.y + 40, 8)
    sq(g, box.x + 400, box.y + 220, 8)
    sq(g, box.x + 240, box.y + 230, 8)
  end
  PART_HITS = {
    { x = box.x + 46, y = y, w = 80, h = 80 },
    { x = box.x + 174, y = y - 6, w = 92, h = 92 },
    { x = box.x + 314, y = y + 20, w = 70, h = 60 },
    { x = box.x + 24, y = box.y + 24, w = 80, h = 40 },
  }
end

local function spindle(g, cx, cy, r, hi_line)
  seg(g, cx, cy - r + 16, cx - 50, cy, hi_line)
  seg(g, cx, cy - r + 16, cx + 50, cy, hi_line)
  seg(g, cx, cy + r - 16, cx - 50, cy, hi_line)
  seg(g, cx, cy + r - 16, cx + 50, cy, hi_line)
  g:circle(I(cx), I(cy - r + 16), 5,{fill=true,color=BLACK})
  g:circle(I(cx), I(cy + r - 16), 5,{fill=true,color=BLACK})
end

function DRAW.prophase(g, box, hi)
  local cx = I(box.x + box.w / 2)
  local cy = I(box.y + box.h / 2)
  local r = 108
  ring(g, cx, cy, r, false)
  if hi == 2 then
    ring(g, cx, cy, 58, true)
  else
    for deg = 30, 330, 50 do
      local rad = deg * math.pi / 180
      local x1 = cx + 50 * math.cos(rad)
      local y1 = cy - 50 * math.sin(rad)
      local x2 = cx + 62 * math.cos(rad + 0.25)
      local y2 = cy - 62 * math.sin(rad + 0.25)
      g:line(I(x1), I(y1), I(x2), I(y2),{color=BLACK})
    end
  end
  local spots = { { -28, -24 }, { 22, -18 }, { -8, 26 }, { 34, 20 } }
  for i = 1, #spots do
    local x, y = cx + spots[i][1], cy + spots[i][2]
    seg(g, x - 10, y - 12, x + 8, y + 6, hi == 1)
    seg(g, x + 8, y - 12, x - 10, y + 6, hi == 1)
    g:circle(I(x), I(y), 3,{fill=true,color=BLACK})
  end
  g:circle(I(cx - 70), I(cy - 70), 5,{fill=true,color=BLACK})
  g:circle(I(cx + 72), I(cy + 68), 5,{fill=true,color=BLACK})
  if hi == 3 then
    sq(g, cx - 70, cy - 70, 10)
    sq(g, cx + 72, cy + 68, 10)
  end
  seg(g, cx - 70, cy - 70, cx - 20, cy - 10, hi == 4)
  seg(g, cx + 72, cy + 68, cx + 24, cy + 16, hi == 4)
  PART_HITS = {
    { x = cx - 40, y = cy - 40, w = 80, h = 70 },
    { x = cx + 40, y = cy - 70, w = 50, h = 50 },
    { x = cx - 86, y = cy - 86, w = 28, h = 28 },
    { x = cx - 70, y = cy - 70, w = 56, h = 40 },
  }
end

function DRAW.metaphase(g, box, hi)
  local cx = I(box.x + box.w / 2)
  local cy = I(box.y + box.h / 2)
  local r = 108
  ring(g, cx, cy, r, false)
  if hi == 1 then
    seg(g, cx - 70, cy, cx + 70, cy, true)
    sq(g, cx - 70, cy, 8)
    sq(g, cx + 70, cy, 8)
  else
    g:line(I(cx - 70), I(cy), I(cx + 70), I(cy),{color=BLACK})
  end
  for i = -2, 2 do
    local x = cx + i * 22
    seg(g, x - 8, cy - 18, x + 6, cy + 4, hi == 3)
    seg(g, x + 8, cy - 18, x - 6, cy + 4, hi == 3)
    g:circle(I(x), I(cy), hi == 2 and 6 or 3,{fill=true,color=BLACK})
  end
  spindle(g, cx, cy, r, hi == 4)
  PART_HITS = {
    { x = cx - 80, y = cy - 12, w = 40, h = 24 },
    { x = cx - 12, y = cy - 12, w = 24, h = 24 },
    { x = cx - 54, y = cy - 28, w = 108, h = 36 },
    { x = cx - 16, y = cy - r + 4, w = 32, h = 32 },
  }
end

function DRAW.anaphase(g, box, hi)
  local cx = I(box.x + box.w / 2)
  local cy = I(box.y + box.h / 2)
  local r = 108
  ring(g, cx, cy, r, hi == 4)
  for i = -2, 2 do
    local x = cx + i * 20
    seg(g, x - 7, cy - 52, x + 5, cy - 28, hi == 2)
    seg(g, x + 7, cy - 52, x - 5, cy - 28, hi == 2)
    seg(g, x - 7, cy + 28, x + 5, cy + 52, hi == 2)
    seg(g, x + 7, cy + 28, x - 5, cy + 52, hi == 2)
    g:circle(I(x), I(cy - 38), hi == 1 and 5 or 3,{fill=true,color=BLACK})
    g:circle(I(x), I(cy + 38), hi == 1 and 5 or 3,{fill=true,color=BLACK})
  end
  seg(g, cx, cy - r + 16, cx - 40, cy - 38, hi == 3)
  seg(g, cx, cy - r + 16, cx + 40, cy - 38, hi == 3)
  seg(g, cx, cy + r - 16, cx - 40, cy + 38, hi == 3)
  seg(g, cx, cy + r - 16, cx + 40, cy + 38, hi == 3)
  g:circle(I(cx), I(cy - r + 16), 5,{fill=true,color=BLACK})
  g:circle(I(cx), I(cy + r - 16), 5,{fill=true,color=BLACK})
  if hi == 4 then
    sq(g, cx, cy - r + 16, 10)
    sq(g, cx, cy + r - 16, 10)
  end
  PART_HITS = {
    { x = cx - 12, y = cy - 48, w = 24, h = 24 },
    { x = cx - 50, y = cy - 60, w = 100, h = 40 },
    { x = cx - 16, y = cy - r + 4, w = 32, h = 28 },
    { x = cx - 20, y = cy - r, w = 40, h = 28 },
  }
end

local function draw_figure(g, fig, highlight)
  local box = { x = FIG_X, y = FIG_Y, w = FIG_W, h = FIG_H }
  g:rect(box.x, box.y, box.w, box.h,{color=BLACK})
  PART_HITS = {}
  local fn = DRAW[fig.id]
  if fn then fn(g, box, highlight) end
end

local function next_hi(s, fig)
  local max_hi = fig and #fig.parts or 0
  s.highlight = s.highlight >= max_hi and 0 or s.highlight + 1
end

local function prev_hi(s, fig)
  local max_hi = fig and #fig.parts or 0
  s.highlight = s.highlight <= 0 and max_hi or s.highlight - 1
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
        step_cursor(s, 1, false)
      elseif ev.gesture == "swipe_down" then
        step_cursor(s, -1, false)
      elseif ev.gesture == "tap" then
        for vis = 1, VISIBLE do
          local idx = s.scroll + vis
          if idx > #FIGURES_DATA then break end
          if hit(ev.x, ev.y, 0, LIST_TOP + (vis - 1) * ROW_H, 480, ROW_H) then
            s.cursor = idx
            s.screen = "figure"
            s.highlight = 0
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
    local fig = FIGURES_DATA[s.cursor]
    if (ev.type == "pointer" and ev.phase == "up") then
      if ev.gesture == "tap" then
        if ev.y < HEADER_H then
          s.screen = "list"
        elseif hit(ev.x, ev.y, FIG_X, FIG_Y, FIG_W, FIG_H) then
          for i = 1, #PART_HITS do
            local zone = PART_HITS[i]
            if hit(ev.x, ev.y, zone.x, zone.y, zone.w, zone.h) then
              s.highlight = i
            end
          end
        else
          if fig then
            for i = 1, #fig.parts do
              if hit(ev.x, ev.y, 24, PART_TOP + (i - 1) * PART_H, 432, PART_H) then
                s.highlight = i
              end
            end
          end
        end
      end
      handled = true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "back" then s.screen = "list"; handled = true
      elseif ev.key == "ok" or ev.key == "down" then next_hi(s, fig); handled = true
      elseif ev.key == "up" then prev_hi(s, fig); handled = true
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
    g:text(24, 22, "细胞图鉴", { color = BLACK })
    g:text(24, 50, string.format("%d 幅 · 点开看结构", #FIGURES_DATA), { color = BLACK })
    g:line(24, 80, 456, 80,{color=BLACK})
    for vis = 1, VISIBLE do
      local idx = s.scroll + vis
      if idx > #FIGURES_DATA then break end
      local fig = FIGURES_DATA[idx]
      local y = LIST_TOP + (vis - 1) * ROW_H
      local on = idx == s.cursor
      if on then g:rect(0, y, 480, ROW_H,{fill=true,color=BLACK}) end
      local ink = on and WHITE or BLACK
      g:text(24, y + 16, fig.title, { color = ink })
      g:text(24, y + 46, clip(fig.blurb, 432), { color = ink })
      if not on then g:line(24, y + ROW_H - 1, 456, y + ROW_H - 1,{color=BLACK}) end
    end
    draw_footer(g, "点一行打开", string.format("%d/%d", s.cursor, #FIGURES_DATA))
  else
    local fig = FIGURES_DATA[s.cursor]
    if not fig then return end
    g:text(24, 18, fig.title, { color = BLACK })
    local back = "〈 返回"
    g:text(456 - text_w(back), 18, back, { color = BLACK })
    g:line(24, 54, 456, 54,{color=BLACK})
    draw_figure(g, fig, s.highlight)
    if s.highlight > 0 and fig.parts[s.highlight] then
      local part = fig.parts[s.highlight]
      g:text(24, DETAIL_Y + 4, part.name, { color = BLACK })
      g:text(24, DETAIL_Y + 32, clip(part.use, 432), { color = BLACK })
    else
      g:text(24, DETAIL_Y + 16, "点部位，或点图上的结构", { color = BLACK })
    end
    g:line(24, PART_TOP - 8, 456, PART_TOP - 8,{color=BLACK})
    for i = 1, #fig.parts do
      local y = PART_TOP + (i - 1) * PART_H
      local on = s.highlight == i
      if on then rounded_rect(g, 24, y, 432, PART_H - 2, "fill", BLACK, 8) end
      g:text(36, y + 12, fig.parts[i].name, { color = on and WHITE or BLACK })
      if not on then g:line(24, y + PART_H - 1, 456, y + PART_H - 1,{color=BLACK}) end
    end
    draw_footer(g, "点部位看用途", string.format("%d/%d", s.cursor, #FIGURES_DATA))
  end
end
