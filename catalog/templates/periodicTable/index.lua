-- 元素周期表 / X4 Pro 横屏 800×480
-- 总表占满一屏。点格子或 OK 再进详情：先读名字和数据，再看玻尔或同族。
-- 点空位先落在同一周期行，避免第一周期空位误开到 Be。
-- 「必考」只在常考元素间走键；点按仍可打开任意格子。
local BLACK, WHITE = 15, 0

-- 相对 800×480：总表 origin (36, 60)，格 40×42，f 区额外空 12px。
-- 顶栏胶囊高 36：全部 (200,4,88×36)，必考 (296,4,88×36)，自测 (680,4,104×36)。
-- 详情「〈 返回」热区 (8,6,128×40)，顶栏 y<52 也可回表；自测主按钮 (552,408,224×44)。
local CELL_W, CELL_H = 40, 42
local ORIGIN_X, ORIGIN_Y = 36, 60
local F_GAP = 12
local COLS = 18
local CHIP_ALL = { x = 200, y = 4, w = 88, h = 36 }
local CHIP_CORE = { x = 296, y = 4, w = 88, h = 36 }
local CHIP_QUIZ = { x = 680, y = 4, w = 104, h = 36 }
local BACK_BTN = { x = 8, y = 6, w = 128, h = 40 }
local DETAIL_QUIZ = { x = 552, y = 408, w = 224, h = 44 }
local QUIZ_BACK = { x = 8, y = 6, w = 128, h = 40 }

local ELEMENTS = nil

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

local function load_elements(ctx)
  if ELEMENTS then return end
  ELEMENTS = {}
  local reader = ctx.package:open_text("elements.tsv", {max_line_bytes = 512})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      local z = tonumber(c[1]) or 0
      local note = c[8] or ""
      ELEMENTS[z] = {
        z = z, symbol = c[2] or "", name = c[3] or "", mass = c[4] or "",
        col = tonumber(c[5]) or 1, row = tonumber(c[6]) or 1,
        valence = c[7] or "-", note = note, shells = c[9] or "",
        core = note ~= "高中少考，仅作定位。",
      }
    end
  end
  reader:close()
end

local function state(ctx)
  load_elements(ctx)
  local s = ctx.state.periodic_table
  if type(s) ~= "table" then
    s = { screen = "table", z = 1, quiz_z = 1, quiz_show = false, mode = "all", quiz_from = "table" }
    ctx.state.periodic_table = s
  end
  s.z = math.max(1, math.min(118, math.floor(tonumber(s.z) or 1)))
  s.quiz_z = math.max(1, math.min(20, math.floor(tonumber(s.quiz_z) or 1)))
  if s.mode ~= "core" then s.mode = "all" end
  if s.screen ~= "detail" and s.screen ~= "quiz" then s.screen = "table" end
  return s
end

local function el(z) return ELEMENTS[z] end

local function is_core(e)
  return e and e.core
end

local function layout(ctx)
  local w, h = ctx.screen.width, ctx.screen.height
  return {
    w = w, h = h,
    origin_x = ORIGIN_X, origin_y = ORIGIN_Y,
    cell_w = CELL_W, cell_h = CELL_H, f_gap = F_GAP,
    table_w = COLS * CELL_W,
    table_h = 7 * CELL_H + F_GAP + 2 * CELL_H,
  }
end

local function cell_xy(e, L)
  local x = L.origin_x + (e.col - 1) * L.cell_w
  local y
  if e.row <= 7 then
    y = L.origin_y + (e.row - 1) * L.cell_h
  else
    y = L.origin_y + 7 * L.cell_h + L.f_gap + (e.row - 9) * L.cell_h
  end
  return x, y
end

local function period_of(e)
  if e.row <= 7 then return e.row end
  if e.row == 9 then return 6 end
  if e.row == 10 then return 7 end
  return e.row
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

local function center_text(g, cx, y, text, color)
  g:text(cx - math.floor(text_w(text) / 2), y, text, { color = color or BLACK })
end

local function wrap_lines(text, max_w, max_lines)
  local lines, buf, width, i = {}, "", 0, 1
  while i <= #text do
    local b = string.byte(text, i)
    local step = b >= 224 and 3 or (b >= 192 and 2 or 1)
    local ch = string.sub(text, i, i + step - 1)
    local cw = step == 3 and 20 or 10
    if width + cw > max_w and buf ~= "" then
      lines[#lines + 1] = buf
      if #lines >= max_lines then return lines end
      buf, width = ch, cw
    else
      buf, width = buf .. ch, width + cw
    end
    i = i + step
  end
  if buf ~= "" and #lines < max_lines then lines[#lines + 1] = buf end
  return lines
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

local function kind_of(e)
  if e.row == 9 then return "镧系" end
  if e.row == 10 then return "锕系" end
  if e.z == 1 then return "非金属" end
  if e.col == 1 then return "碱金属" end
  if e.col == 2 then return "碱土金属" end
  if e.col == 17 then return "卤素" end
  if e.col == 18 then return "稀有气体" end
  if e.col >= 3 and e.col <= 12 then return "过渡金属" end
  if e.z == 5 or e.z == 14 or e.z == 32 or e.z == 33 or e.z == 51 or e.z == 52 then return "准金属" end
  if e.z == 6 or e.z == 7 or e.z == 8 or e.z == 15 or e.z == 16 or e.z == 34 then return "非金属" end
  return "主族金属"
end

-- 左右：同一视觉行。上下：同一列。core_only 跳过少考格。
local function neighbor(z, dc, dr, core_only)
  local cur = el(z)
  if not cur then return z end
  if dc ~= 0 then
    local best, best_col = z, dc > 0 and 99 or 0
    for i = 1, 118 do
      local e = el(i)
      if e and e.row == cur.row and (not core_only or is_core(e)) then
        if dc > 0 and e.col > cur.col and e.col < best_col then
          best, best_col = i, e.col
        elseif dc < 0 and e.col < cur.col and e.col > best_col then
          best, best_col = i, e.col
        end
      end
    end
    return best
  end
  if dr ~= 0 then
    local best, best_row = z, dr > 0 and 99 or 0
    for i = 1, 118 do
      local e = el(i)
      if e and e.col == cur.col and (not core_only or is_core(e)) then
        if dr > 0 and e.row > cur.row and e.row < best_row then
          best, best_row = i, e.row
        elseif dr < 0 and e.row < cur.row and e.row > best_row then
          best, best_row = i, e.row
        end
      end
    end
    return best
  end
  return z
end

local function nearest_among(px, py, L, row)
  local best, best_d = nil, 1e12
  for z = 1, 118 do
    local e = el(z)
    if e and (not row or e.row == row) then
      local x, y = cell_xy(e, L)
      local dx = px - (x + math.floor(L.cell_w / 2))
      local dy = py - (y + math.floor(L.cell_h / 2))
      local d = dx * dx + dy * dy
      if d < best_d then best, best_d = z, d end
    end
  end
  return best
end

local function row_band(py, L)
  if py < L.origin_y then return nil end
  local main_h = 7 * L.cell_h
  if py < L.origin_y + main_h then
    return 1 + math.floor((py - L.origin_y) / L.cell_h)
  end
  local f_y = L.origin_y + main_h + L.f_gap
  if py >= f_y and py < f_y + L.cell_h then return 9 end
  if py >= f_y + L.cell_h and py < f_y + 2 * L.cell_h then return 10 end
  return nil
end

local function hit_cell(px, py, L)
  for z = 1, 118 do
    local e = el(z)
    if e then
      local x, y = cell_xy(e, L)
      if hit(px, py, x, y, L.cell_w, L.cell_h) then return z end
    end
  end
  return nil
end

-- 先精确命中占用格；空位只在同一周期行里找最近。
local function pick_z(px, py, L)
  local z = hit_cell(px, py, L)
  if z then return z end
  local row = row_band(py, L)
  if row then return nearest_among(px, py, L, row) end
  if hit(px, py, L.origin_x, L.origin_y, L.table_w, L.table_h + 8) then
    return nearest_among(px, py, L, nil)
  end
  return nil
end

local function family_line(e)
  local parts = {}
  for z = 1, 118 do
    local o = el(z)
    if o and o.col == e.col then
      if e.row >= 9 then
        if o.row == e.row then parts[#parts + 1] = o.symbol end
      elseif o.row <= 7 then
        parts[#parts + 1] = o.symbol
      end
    end
  end
  return table.concat(parts, " ")
end

local function side_symbols(e)
  local left_z = neighbor(e.z, -1, 0, false)
  local right_z = neighbor(e.z, 1, 0, false)
  local left = left_z ~= e.z and el(left_z)
  local right = right_z ~= e.z and el(right_z)
  local l = left and left.symbol or "（无）"
  local r = right and right.symbol or "（无）"
  return l .. "  ·  " .. r
end

local function header_title(e)
  if e.name ~= e.symbol then
    return e.symbol .. "  " .. e.name
  end
  return e.symbol
end

local function open_quiz(s)
  s.quiz_from = s.screen
  s.screen = "quiz"
  s.quiz_z = ((s.z - 1) % 20) + 1
  s.quiz_show = false
end

local function open_detail(s, z)
  if z then s.z = z end
  s.screen = "detail"
end

local function leave_detail(s)
  s.screen = "table"
  s.eat_chip = true
end

local function handle_table(s, ev, L)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    -- 详情顶栏和总表「自测」叠带；吞掉回表后误点到自测的连击。
    if s.eat_chip then
      s.eat_chip = false
      if hit(ev.x, ev.y, CHIP_QUIZ.x, CHIP_QUIZ.y, CHIP_QUIZ.w, CHIP_QUIZ.h) then
        return true
      end
    end
    if hit(ev.x, ev.y, CHIP_ALL.x, CHIP_ALL.y, CHIP_ALL.w, CHIP_ALL.h) then
      s.mode = "all"
      return true
    end
    if hit(ev.x, ev.y, CHIP_CORE.x, CHIP_CORE.y, CHIP_CORE.w, CHIP_CORE.h) then
      s.mode = "core"
      return true
    end
    if hit(ev.x, ev.y, CHIP_QUIZ.x, CHIP_QUIZ.y, CHIP_QUIZ.w, CHIP_QUIZ.h) then
      open_quiz(s)
      return true
    end
    local f_y = L.origin_y + 7 * L.cell_h + L.f_gap
    if hit(ev.x, ev.y, 0, f_y, L.origin_x, L.cell_h) then
      open_detail(s, 57)
      return true
    end
    if hit(ev.x, ev.y, 0, f_y + L.cell_h, L.origin_x, L.cell_h) then
      open_detail(s, 89)
      return true
    end
    local z = pick_z(ev.x, ev.y, L)
    if z then open_detail(s, z) end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  local core_only = s.mode == "core"
  if ev.key == "left" then s.z = neighbor(s.z, -1, 0, core_only)
  elseif ev.key == "right" then s.z = neighbor(s.z, 1, 0, core_only)
  elseif ev.key == "up" then s.z = neighbor(s.z, 0, -1, core_only)
  elseif ev.key == "down" then s.z = neighbor(s.z, 0, 1, core_only)
  elseif ev.key == "ok" then open_detail(s)
  else return false end
  return true
end

local function handle_detail(s, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if hit(ev.x, ev.y, BACK_BTN.x, BACK_BTN.y, BACK_BTN.w, BACK_BTN.h) or ev.y < 52 then
      leave_detail(s)
      return true
    end
    if hit(ev.x, ev.y, DETAIL_QUIZ.x, DETAIL_QUIZ.y, DETAIL_QUIZ.w, DETAIL_QUIZ.h) then
      open_quiz(s)
      return true
    end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  local core_only = s.mode == "core"
  if ev.key == "back" then s.screen = "table"
  elseif ev.key == "left" then s.z = neighbor(s.z, -1, 0, core_only)
  elseif ev.key == "right" then s.z = neighbor(s.z, 1, 0, core_only)
  elseif ev.key == "up" then s.z = neighbor(s.z, 0, -1, core_only)
  elseif ev.key == "down" then s.z = neighbor(s.z, 0, 1, core_only)
  elseif ev.key == "ok" then open_quiz(s)
  else return false end
  return true
end

local function handle_quiz(s, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if hit(ev.x, ev.y, QUIZ_BACK.x, QUIZ_BACK.y, QUIZ_BACK.w, QUIZ_BACK.h) or ev.y < 48 then
      s.screen = s.quiz_from == "detail" and "detail" or "table"
      return true
    end
    if s.quiz_show then s.quiz_z = (s.quiz_z % 20) + 1; s.quiz_show = false else s.quiz_show = true end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "back" then s.screen = s.quiz_from == "detail" and "detail" or "table"
  elseif ev.key == "ok" or ev.key == "down" then
    if s.quiz_show then s.quiz_z = (s.quiz_z % 20) + 1; s.quiz_show = false else s.quiz_show = true end
  else return false end
  return true
end

function on_load(ctx)
  state(ctx)
  ctx:set_tick(0)
  ctx:invalidate()
end

function on_input(ctx, ev)
  local s = state(ctx)
  local handled = false
  if s.screen == "quiz" then
    handled = handle_quiz(s, ev)
  elseif s.screen == "detail" then
    handled = handle_detail(s, ev)
  else
    handled = handle_table(s, ev, layout(ctx))
  end
  if handled then ctx:invalidate() end
  return handled
end

local function draw_bohr(g, e, cx, cy, max_r)
  local parts = split(e.shells, ",")
  if #parts == 0 or max_r < 20 then return end
  local denom = math.max(#parts, 3)
  local step = math.max(14, math.floor((max_r - 8) / denom))
  g:circle(cx, cy, 5,{fill=true,color=BLACK})
  for i = 1, #parts do
    local n = tonumber(parts[i]) or 0
    local r = i * step
    g:circle(cx, cy, r,{color=BLACK})
    for k = 1, n do
      local a = (k - 1) * (6.2832 / n) - 1.5708
      g:rect(math.floor(cx + r * math.cos(a) - 3), math.floor(cy + r * math.sin(a) - 3), 6, 6,{fill=true,color=BLACK})
    end
  end
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

local function draw_text_link(g, box, label)
  g:text(box.x + 10, box.y + 10, label, { color = BLACK })
end

local function draw_primary(g, box, label)
  rounded_stroke(g, box.x, box.y, box.w, box.h, 12, 3, BLACK)
  center_text(g, box.x + math.floor(box.w / 2), box.y + 12, label, BLACK)
end

local function draw_cell(g, e, s, L, x, y)
  local on = e.z == s.z
  local faded = s.mode == "core" and not is_core(e) and not on
  if on then
    g:rect(x, y, L.cell_w - 2, L.cell_h - 2,{fill=true,color=BLACK})
  elseif not faded then
    g:rect(x, y, L.cell_w - 2, L.cell_h - 2,{color=BLACK})
  end
  local ink = on and WHITE or BLACK
  local z_label = tostring(e.z)
  g:text(x + math.max(2, math.floor((L.cell_w - 2 - text_w(z_label)) / 2)), y + 4, z_label, { color = ink })
  g:text(x + math.max(2, math.floor((L.cell_w - 2 - text_w(e.symbol)) / 2)), y + 20, e.symbol, { color = ink })
end

local function label_y(top)
  return top + math.floor((CELL_H - 16) / 2)
end

local function draw_table(g, s, L)
  g:text(12, 12, "元素周期表", { color = BLACK })
  draw_capsule(g, CHIP_ALL, "全部", s.mode == "all")
  draw_capsule(g, CHIP_CORE, "必考", s.mode == "core")
  draw_capsule(g, CHIP_QUIZ, "自测", false)
  for col = 1, COLS do
    local label = tostring(col)
    local x = L.origin_x + (col - 1) * L.cell_w
    g:text(x + math.max(1, math.floor((L.cell_w - text_w(label)) / 2)), L.origin_y - 18, label, { color = BLACK })
  end
  for row = 1, 7 do
    local top = L.origin_y + (row - 1) * L.cell_h
    g:text(14, label_y(top), tostring(row), { color = BLACK })
  end
  local f_y = L.origin_y + 7 * L.cell_h + L.f_gap
  g:text(8, label_y(f_y), "La", { color = BLACK })
  g:text(8, label_y(f_y + L.cell_h), "Ac", { color = BLACK })
  for z = 1, 118 do
    local e = el(z)
    if e then
      local x, y = cell_xy(e, L)
      draw_cell(g, e, s, L, x, y)
    end
  end
  local hint = s.mode == "core" and "有框常考 · 方向键只走常考" or "点格看详情 · 方向键移动 · OK 打开"
  g:text(12, L.h - 16, hint, { color = BLACK })
end

local function draw_wrapped(g, x, y, text, max_w, max_lines, step)
  local lines = wrap_lines(text, max_w, max_lines)
  for i = 1, #lines do
    g:text(x, y, lines[i], { color = BLACK })
    y = y + step
  end
  return y
end

local function draw_fact(g, x, y, label, value)
  g:text(x, y, label, { color = BLACK })
  g:text(x + 140, y, value, { color = BLACK })
end

local function draw_kind_chip(g, x, y, kind)
  local w = text_w(kind) + 28
  rounded_stroke(g, x, y, w, 28, 14, 2, BLACK)
  g:text(x + 14, y + 4, kind, { color = BLACK })
end

local function draw_detail(g, s, L)
  local e = el(s.z)
  draw_text_link(g, BACK_BTN, "〈  返回")
  if not e then return end
  g:text(160, 14, header_title(e), { color = BLACK })

  rounded_stroke(g, 28, 60, 332, 108, 14, 2, BLACK)
  center_text(g, 194, 80, e.symbol, BLACK)
  center_text(g, 194, 120, e.name, BLACK)

  if e.z <= 20 and e.shells ~= "" then
    g:text(28, 184, "电子层", { color = BLACK })
    draw_bohr(g, e, 194, 292, 64)
  else
    local fam = "同族  " .. kind_of(e)
    if e.col == 3 and e.row <= 7 then fam = fam .. " · 镧锕见表下" end
    g:text(28, 184, fam, { color = BLACK })
    local y = draw_wrapped(g, 28, 212, family_line(e), 332, 4, 24)
    g:text(28, y + 6, "本周期左右", { color = BLACK })
    draw_wrapped(g, 28, y + 32, side_symbols(e), 332, 2, 24)
  end

  local x = 392
  draw_kind_chip(g, x, 60, kind_of(e))
  draw_fact(g, x, 108, "原子序", tostring(e.z))
  draw_fact(g, x, 140, "相对质量", e.mass)
  draw_fact(g, x, 172, "族 / 周期", tostring(e.col) .. " / " .. tostring(period_of(e)))
  draw_fact(g, x, 204, "化合价", e.valence)
  if e.z <= 20 and e.shells ~= "" then
    draw_fact(g, x, 236, "电子层", e.shells)
    g:text(x, 276, "短注", { color = BLACK })
    draw_wrapped(g, x, 304, e.note, 380, 3, 26)
  else
    g:text(x, 244, "短注", { color = BLACK })
    draw_wrapped(g, x, 272, e.note, 380, 4, 26)
  end

  draw_primary(g, DETAIL_QUIZ, "自测")
  g:text(24, L.h - 20, "←→ 换元素   OK 自测   BACK 回总表", { color = BLACK })
end

local function draw_quiz(g, s, L)
  local e = el(s.quiz_z)
  draw_text_link(g, QUIZ_BACK, "〈  返回")
  g:text(160, 14, "自测", { color = BLACK })
  local progress = tostring(s.quiz_z) .. " / 20"
  center_text(g, math.floor(L.w / 2), 64, progress, BLACK)

  local box_w, box_h = 460, 248
  local box_x = math.floor((L.w - box_w) / 2)
  local box_y = 100
  rounded_stroke(g, box_x, box_y, box_w, box_h, 16, 2, BLACK)
  center_text(g, box_x + math.floor(box_w / 2), box_y + 36, "原子序", BLACK)
  center_text(g, box_x + math.floor(box_w / 2), box_y + 68, tostring(s.quiz_z), BLACK)
  if s.quiz_show and e then
    center_text(g, box_x + math.floor(box_w / 2), box_y + 128, e.symbol, BLACK)
    center_text(g, box_x + math.floor(box_w / 2), box_y + 172, e.name, BLACK)
  else
    center_text(g, box_x + math.floor(box_w / 2), box_y + 148, "点按或 OK 揭开", BLACK)
  end
  g:text(24, L.h - 20, "点按或 OK：揭开 / 下一题     BACK：回上一页", { color = BLACK })
end

function on_draw(ctx, g)
  local s = state(ctx)
  local L = layout(ctx)
  g:clear(WHITE)
  if s.screen == "quiz" then
    draw_quiz(g, s, L)
  elseif s.screen == "detail" then
    draw_detail(g, s, L)
  else
    draw_table(g, s, L)
  end
end
