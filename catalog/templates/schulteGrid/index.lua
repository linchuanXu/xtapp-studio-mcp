-- 舒尔特方格 / X4 Pro
-- 首页选规格 → 训练 → 结算 → 成绩。计时从点对第一格开始。
local BLACK, WHITE = 15, 0
local M, CW = 24, 432
local SIZES = { 3, 4, 5, 6 }
local MODES = { "asc", "desc", "odd" }
local MODE_LABEL = { asc = "正序", desc = "倒序", odd = "奇偶" }
local SCREENS = { home = 1, help = 1, play = 1, done = 1, stats = 1 }

local GRID_X, GRID_Y, GRID = 24, 168, 432
local DIGIT = {
  s = { prefix = "digit_s_", w = 24, h = 38 },
  m = { prefix = "digit_m_", w = 34, h = 50 },
  l = { prefix = "digit_l_", w = 50, h = 74 },
}
local CHIP_H = 52
local HOME_SIZE_Y, SIZE_W, SIZE_GAP = 248, 102, 8
local HOME_MODE_Y, MODE_W, MODE_GAP = 348, 138, 9
local HOME_HIDE_Y, HIDE_W = 448, 210
local START = { 24, 528, 432, 60 }
local HOME_HELP = { 24, 612, 204, 52 }
local HOME_STATS = { 252, 612, 204, 52 }
local NAV_BACK = { 24, 16, 96, 40 }
local NAV_RIGHT = { 360, 16, 96, 40 }
local PLAY_RESTART = { 24, 632, 204, 56 }
local PLAY_HOME = { 252, 632, 204, 56 }
local DONE_AGAIN = { 24, 604, 432, 60 }
local DONE_HOME = { 24, 680, 204, 52 }
local DONE_STATS = { 252, 680, 204, 52 }

local function text_w(text)
  local w, i = 0, 1
  text = tostring(text or "")
  while i <= #text do
    local b = string.byte(text, i)
    if b >= 224 then w, i = w + 20, i + 3 elseif b >= 192 then w, i = w + 10, i + 2 else w, i = w + 10, i + 1 end
  end
  return w
end

local function center(g, x, y, text, color)
  g:text(x - math.floor(text_w(text) / 2), y, tostring(text), { color = color or BLACK })
end

local function hit(x, y, rx, ry, rw, rh)
  return x >= rx and x < rx + rw and y >= ry and y < ry + rh
end

local function hit_box(x, y, t)
  return hit(x, y, t[1], t[2], t[3], t[4])
end

local function rounded_fill(g, x, y, w, h, radius, color)
  local r = math.max(1, math.min(radius, math.floor(w / 2), math.floor(h / 2)))
  g:rect(x + r, y, w - r * 2, h, "fill", color)
  g:rect(x, y + r, w, h - r * 2, "fill", color)
  g:circle(x + r, y + r, r, "fill", color)
  g:circle(x + w - 1 - r, y + r, r, "fill", color)
  g:circle(x + r, y + h - 1 - r, r, "fill", color)
  g:circle(x + w - 1 - r, y + h - 1 - r, r, "fill", color)
end

local function rounded_stroke(g, x, y, w, h, radius, thickness, color)
  local t = math.max(1, thickness)
  rounded_fill(g, x, y, w, h, radius, color)
  rounded_fill(g, x + t, y + t, w - t * 2, h - t * 2, math.max(1, radius - t), WHITE)
end

local function card(g, x, y, w, h)
  rounded_stroke(g, x, y, w, h, 14, 2, BLACK)
end

local function panel(g, x, y, w, h)
  rounded_fill(g, x, y, w, h, 14, BLACK)
end

local function chip(g, x, y, w, h, label, on)
  if on then
    rounded_fill(g, x, y, w, h, 12, BLACK)
    center(g, x + math.floor(w / 2), y + 16, label, WHITE)
  else
    rounded_stroke(g, x, y, w, h, 12, 2, BLACK)
    center(g, x + math.floor(w / 2), y + 16, label, BLACK)
  end
end

local function primary(g, x, y, w, h, label)
  rounded_fill(g, x, y, w, h, 14, BLACK)
  center(g, x + math.floor(w / 2), y + math.floor((h - 20) / 2), label, WHITE)
end

local function secondary(g, x, y, w, h, label)
  rounded_stroke(g, x, y, w, h, 14, 2, BLACK)
  center(g, x + math.floor(w / 2), y + math.floor((h - 20) / 2), label, BLACK)
end

local function draw_primary(g, t, label)
  primary(g, t[1], t[2], t[3], t[4], label)
end

local function draw_secondary(g, t, label)
  secondary(g, t[1], t[2], t[3], t[4], label)
end

local function header(g, title, right)
  g:text(M, 24, title, { color = BLACK })
  if right then draw_secondary(g, NAV_RIGHT, right) end
  g:line(M, 64, M + CW, 64, BLACK)
end

local function spec_key(s)
  return tostring(s.size) .. "_" .. s.mode .. (s.hide == 1 and "h" or "")
end

local function spec_name(s)
  return s.size .. "x" .. s.size .. " " .. MODE_LABEL[s.mode] .. (s.hide == 1 and " 消格" or " 留格")
end

local function key_name(key)
  local size, mode, hide = string.match(key or "", "^(%d+)_(%a+)(h?)$")
  if not size then return tostring(key or "") end
  return size .. "x" .. size .. " " .. (MODE_LABEL[mode] or mode) .. (hide == "h" and " 消格" or "")
end

local function expected(s)
  local n = s.size * s.size
  if s.mode == "desc" then return n - s.next_i + 1 end
  if s.mode == "odd" then
    local odds = math.ceil(n / 2)
    if s.next_i <= odds then return s.next_i * 2 - 1 end
    return (s.next_i - odds) * 2
  end
  return s.next_i
end

local function fmt_time(ms, whole)
  ms = tonumber(ms) or 0
  if ms <= 0 then return "--" end
  if whole then return tostring(math.floor(ms / 1000)) end
  return string.format("%.1f", ms / 1000)
end

local function time_label(ms, whole)
  local text = fmt_time(ms, whole)
  if text == "--" then return text end
  return text .. "s"
end

local function digit_spec(size)
  if size <= 4 then return DIGIT.l end
  if size == 5 then return DIGIT.m end
  return DIGIT.s
end

local function draw_digits(g, text, cx, cy, spec, invert)
  text = tostring(text or "")
  if text == "" or text == "--" then
    center(g, cx, cy - 10, "--", invert and WHITE or BLACK)
    return
  end
  local gap = 2
  local width = 0
  for i = 1, #text do
    local ch = string.sub(text, i, i)
    width = width + (ch == "." and 10 or spec.w)
    if i < #text then width = width + gap end
  end
  local x = cx - math.floor(width / 2)
  local y = cy - math.floor(spec.h / 2)
  local opts = invert and { color = 0 } or nil
  for i = 1, #text do
    local ch = string.sub(text, i, i)
    if ch == "." then
      g:rect(x + 2, y + spec.h - 12, 6, 6, "fill", invert and WHITE or BLACK)
      x = x + 10 + gap
    else
      g:image(spec.prefix .. ch, x, y, opts)
      x = x + spec.w + gap
    end
  end
end

local function grade(ms, n)
  local per = (tonumber(ms) or 0) / math.max(1, n)
  if per < 320 then return "飞手", "接近飞行员的扫视速度" end
  if per < 640 then return "优秀", "已经快于大多数人" end
  if per < 1040 then return "熟练", "常用训练水平" end
  return "入门", "再练几局，眼睛会稳下来"
end

local function has_got(s, value)
  if value < 1 then return false end
  return (s.got & (1 << (value - 1))) ~= 0
end

local function spec_last(s, key)
  for i = #s.recent, 1, -1 do
    if s.recent[i].k == key then return s.recent[i].t end
  end
end

local function spec_avg(s, key)
  local sum, n = 0, 0
  for i = 1, #s.recent do
    if s.recent[i].k == key then sum, n = sum + s.recent[i].t, n + 1 end
  end
  if n == 0 then return nil end
  return math.floor(sum / n)
end

local function days_since_unix(year, month, day)
  local y, m = year, month
  if m <= 2 then y, m = y - 1, m + 12 end
  local era = y // 400
  local yoe = y - era * 400
  local doy = (153 * (m - 3) + 2) // 5 + day - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end

local function today_id(ctx)
  local clock = ctx.sys:clock()
  if type(clock) ~= "table" or clock.valid ~= true or clock.year == nil or clock.month == nil or clock.day == nil then
    return 0
  end
  return days_since_unix(clock.year, clock.month, clock.day)
end

local function grid_geom(s)
  local n = s.size
  local cell = math.floor(GRID / n)
  local used = cell * n
  return {
    n = n,
    cell = cell,
    ox = GRID_X + math.floor((GRID - used) / 2),
    oy = GRID_Y + math.floor((GRID - used) / 2),
    used = used,
  }
end

local function cell_at(x, y, s)
  local geom = grid_geom(s)
  if x < geom.ox or y < geom.oy or x >= geom.ox + geom.used or y >= geom.oy + geom.used then return nil end
  local col = math.floor((x - geom.ox) / geom.cell)
  local row = math.floor((y - geom.oy) / geom.cell)
  return row * geom.n + col + 1
end

local function target(id, label, x, y, w, h, selected)
  return { id = id, label = label, x = x, y = y, width = w, height = h, selected = selected == true }
end

local function target_box(id, label, t, selected)
  return target(id, label, t[1], t[2], t[3], t[4], selected)
end

local function publish(ctx, targets)
  if ctx.state.__testing_interactions == nil then return end
  ctx.state.__testing_interactions = targets
end

local function deal(s)
  local n = s.size * s.size
  local cells = {}
  for i = 1, n do cells[i] = i end
  for i = n, 2, -1 do
    local j = math.random(i)
    cells[i], cells[j] = cells[j], cells[i]
  end
  s.cells = cells
  s.next_i = 1
  s.found = 0
  s.errors = 0
  s.got = 0
  s.running = false
  s.done = false
  s.start_ms = 0
  s.elapsed_ms = 0
  s.shown_sec = -1
  s.focus = 1
  s.new_best = false
  s.prev_ms = 0
  s.wrong = 0
  s.screen = "play"
end

local function finish(ctx, s)
  s.done = true
  s.running = false
  s.elapsed_ms = ctx.sys:millis() - s.start_ms
  s.screen = "done"
  s.games = (tonumber(s.games) or 0) + 1
  local day = today_id(ctx)
  if s.day ~= day then s.day, s.today = day, 0 end
  s.today = (tonumber(s.today) or 0) + 1
  local key = spec_key(s)
  s.prev_ms = spec_last(s, key) or 0
  local best = tonumber(s.best[key])
  if not best or s.elapsed_ms < best then
    s.best[key] = s.elapsed_ms
    s.new_best = true
  else
    s.new_best = false
  end
  if s.errors == 0 then s.clean = (tonumber(s.clean) or 0) + 1 else s.clean = 0 end
  s.recent[#s.recent + 1] = { k = key, t = s.elapsed_ms, e = s.errors }
  while #s.recent > 8 do table.remove(s.recent, 1) end
  ctx:set_tick_rate("idle")
end

local function tap_cell(ctx, s, idx)
  if s.screen ~= "play" or s.done then return false end
  if type(s.cells) ~= "table" or idx < 1 or idx > #s.cells then return false end
  local value = s.cells[idx]
  if has_got(s, value) then return true end
  if value ~= expected(s) then
    s.errors = (tonumber(s.errors) or 0) + 1
    s.wrong = idx
    return true
  end
  if not s.running then
    s.running = true
    s.start_ms = ctx.sys:millis()
    ctx:set_tick_rate("low")
  end
  s.got = s.got | (1 << (value - 1))
  s.next_i = s.next_i + 1
  s.found = s.found + 1
  s.wrong = 0
  if s.found >= s.size * s.size then finish(ctx, s) end
  return true
end

local function sync_tick(ctx, s)
  if s.screen == "play" and s.running and not s.done then ctx:set_tick_rate("low")
  else ctx:set_tick_rate("idle") end
end

local function go_home(ctx, s)
  s.screen = "home"
  s.running = false
  s.done = false
  sync_tick(ctx, s)
end

local function state(ctx)
  local s = ctx.state.schulte_grid
  if type(s) ~= "table" then
    s = {
      screen = "home", size = 5, mode = "asc", hide = 0, seen = 0, help = 1,
      games = 0, today = 0, day = 0, clean = 0, best = {}, recent = {},
    }
    ctx.state.schulte_grid = s
  end
  if type(s.best) ~= "table" then s.best = {} end
  if type(s.recent) ~= "table" then s.recent = {} end
  s.size = math.max(3, math.min(6, math.floor(tonumber(s.size) or 5)))
  if s.mode ~= "desc" and s.mode ~= "odd" then s.mode = "asc" end
  s.hide = s.hide == 1 and 1 or 0
  if not SCREENS[s.screen] then s.screen = "home" end
  s.next_i = math.max(1, math.floor(tonumber(s.next_i) or 1))
  s.found = math.max(0, math.floor(tonumber(s.found) or 0))
  s.errors = math.max(0, math.floor(tonumber(s.errors) or 0))
  s.got = math.floor(tonumber(s.got) or 0)
  s.help = math.max(1, math.min(2, math.floor(tonumber(s.help) or 1)))
  s.focus = math.max(1, math.min(s.size * s.size, math.floor(tonumber(s.focus) or 1)))
  local day = today_id(ctx)
  if s.day ~= day then s.day, s.today = day, 0 end
  return s
end

local function elapsed_now(ctx, s)
  if s.done then return tonumber(s.elapsed_ms) or 0 end
  if s.running then return ctx.sys:millis() - (tonumber(s.start_ms) or 0) end
  return 0
end

local function draw_home(g, ctx, s)
  header(g, "舒尔特方格")
  g:text(M, 80, "盯着方格中央，用余光找下一个数。", { color = BLACK })
  card(g, M, 112, CW, 92)
  g:text(44, 128, "今日  " .. tostring(s.today or 0) .. " 局     累计  " .. tostring(s.games or 0) .. " 局", { color = BLACK })
  g:text(44, 164, spec_name(s), { color = BLACK })
  g:text(260, 164, "最佳  " .. time_label(s.best[spec_key(s)]), { color = BLACK })

  g:text(M, 220, "规格", { color = BLACK })
  for i, size in ipairs(SIZES) do
    chip(g, M + (i - 1) * (SIZE_W + SIZE_GAP), HOME_SIZE_Y, SIZE_W, CHIP_H, size .. "x" .. size, s.size == size)
  end
  g:text(M, 320, "顺序", { color = BLACK })
  for i, mode in ipairs(MODES) do
    chip(g, M + (i - 1) * (MODE_W + MODE_GAP), HOME_MODE_Y, MODE_W, CHIP_H, MODE_LABEL[mode], s.mode == mode)
  end
  g:text(M, 420, "格上", { color = BLACK })
  chip(g, M, HOME_HIDE_Y, HIDE_W, CHIP_H, "留格 原式", s.hide == 0)
  chip(g, 246, HOME_HIDE_Y, HIDE_W, CHIP_H, "消格 省力", s.hide == 1)

  draw_primary(g, START, "开始本局")
  draw_secondary(g, HOME_HELP, "说明")
  draw_secondary(g, HOME_STATS, "成绩")
  g:text(M, 760, "OK 开始     左右换规格     上下换顺序", { color = BLACK })
  publish(ctx, {
    target_box("start", "开始本局", START),
    target_box("help", "说明", HOME_HELP),
    target_box("stats", "成绩", HOME_STATS),
    target("size:3", "3x3", M, HOME_SIZE_Y, SIZE_W, CHIP_H, s.size == 3),
    target("size:4", "4x4", M + SIZE_W + SIZE_GAP, HOME_SIZE_Y, SIZE_W, CHIP_H, s.size == 4),
    target("size:5", "5x5", M + 2 * (SIZE_W + SIZE_GAP), HOME_SIZE_Y, SIZE_W, CHIP_H, s.size == 5),
    target("size:6", "6x6", M + 3 * (SIZE_W + SIZE_GAP), HOME_SIZE_Y, SIZE_W, CHIP_H, s.size == 6),
    target("mode:asc", "正序", M, HOME_MODE_Y, MODE_W, CHIP_H, s.mode == "asc"),
    target("mode:desc", "倒序", M + MODE_W + MODE_GAP, HOME_MODE_Y, MODE_W, CHIP_H, s.mode == "desc"),
    target("mode:odd", "奇偶", M + 2 * (MODE_W + MODE_GAP), HOME_MODE_Y, MODE_W, CHIP_H, s.mode == "odd"),
    target("hide:0", "留格", M, HOME_HIDE_Y, HIDE_W, CHIP_H, s.hide == 0),
    target("hide:1", "消格", 246, HOME_HIDE_Y, HIDE_W, CHIP_H, s.hide == 1),
  })
end

local function draw_help(g, ctx, s)
  header(g, "怎么练", "返回")
  local cards
  if s.help == 1 then
    cards = {
      { "01", "点对第一个数，计时才开始" },
      { "02", "点错只记一笔，格子不重洗" },
      { "03", "眼睛停在中央，用余光找数" },
      { "04", "5x5 普通人大约 15 到 20 秒" },
    }
  else
    cards = {
      { "正序", "从 1 点到格子数" },
      { "倒序", "从最大数点回 1" },
      { "奇偶", "先奇数，再偶数" },
      { "留格", "点过的数字还在，这是原式" },
    }
  end
  for i, row in ipairs(cards) do
    local y = 84 + (i - 1) * 92
    card(g, M, y, CW, 80)
    panel(g, 40, y + 18, 72, 44)
    center(g, 76, y + 30, row[1], WHITE)
    g:text(132, y + 30, row[2], { color = BLACK })
  end
  center(g, 240, 460, s.help == 1 and "1 / 2" or "2 / 2", BLACK)
  primary(g, 24, 680, 432, 60, s.help == 1 and "下一页" or "知道了")
  publish(ctx, {
    target_box("help_back", "返回", NAV_RIGHT),
    target("help_next", s.help == 1 and "下一页" or "知道了", 24, 680, 432, 60),
  })
end

local function draw_play(g, ctx, s)
  draw_secondary(g, NAV_BACK, "返回")
  draw_secondary(g, NAV_RIGHT, "成绩")
  g:line(M, 64, M + CW, 64, BLACK)
  local ms = elapsed_now(ctx, s)
  local n = s.size * s.size
  panel(g, 24, 76, 136, 80)
  center(g, 92, 82, "下一格", WHITE)
  draw_digits(g, s.done and n or expected(s), 92, 128, DIGIT.m, true)
  card(g, 172, 76, 136, 80)
  center(g, 240, 82, "用时", BLACK)
  draw_digits(g, fmt_time(ms, s.running and not s.done), 240, 128, DIGIT.m, false)
  card(g, 320, 76, 136, 80)
  center(g, 388, 82, "进度", BLACK)
  draw_digits(g, s.found, 356, 128, DIGIT.s, false)
  g:rect(384, 148, 8, 3, "fill", BLACK)
  draw_digits(g, n, 414, 128, DIGIT.s, false)

  local geom = grid_geom(s)
  g:rect(geom.ox - 2, geom.oy - 2, geom.used + 4, geom.used + 4, "stroke", BLACK)
  g:rect(geom.ox, geom.oy, geom.used, geom.used, "stroke", BLACK)
  local targets = {
    target_box("play_back", "返回", NAV_BACK),
    target_box("play_stats", "成绩", NAV_RIGHT),
    target_box("play_restart", "重开", PLAY_RESTART),
    target_box("play_home", "回首页", PLAY_HOME),
  }
  for i = 1, geom.n * geom.n do
    local col = (i - 1) % geom.n
    local row = math.floor((i - 1) / geom.n)
    local x = geom.ox + col * geom.cell
    local y = geom.oy + row * geom.cell
    local value = s.cells and s.cells[i]
    local gone = s.hide == 1 and value and has_got(s, value)
    local wrong = s.wrong == i
    g:rect(x, y, geom.cell, geom.cell, "stroke", BLACK)
    if wrong then g:rect(x + 3, y + 3, geom.cell - 6, geom.cell - 6, "fill", BLACK) end
    if s.focus == i then
      g:rect(x + 4, y + 4, geom.cell - 8, geom.cell - 8, "stroke", wrong and WHITE or BLACK)
    end
    if value and not gone then
      draw_digits(g, value, x + math.floor(geom.cell / 2), y + math.floor(geom.cell / 2), digit_spec(s.size), wrong)
    elseif gone then
      g:rect(x + 8, y + 8, 10, 10, "fill", BLACK)
    end
    targets[#targets + 1] = target("cell:" .. i, tostring(value or i), x, y, geom.cell, geom.cell, s.focus == i)
  end

  local unit = math.max(4, math.floor(CW / n))
  local used = unit * n
  local ox = M + math.floor((CW - used) / 2)
  for i = 1, n do
    local x = ox + (i - 1) * unit
    if i <= s.found then g:rect(x, 612, unit - 2, 8, "fill", BLACK)
    else g:rect(x, 612, unit - 2, 8, "stroke", BLACK) end
  end
  draw_secondary(g, PLAY_RESTART, "重开")
  draw_secondary(g, PLAY_HOME, "回首页")
  local hint = s.running and ("找  " .. expected(s) .. "   " .. spec_name(s)) or ("点  " .. expected(s) .. "  开始计时")
  if s.errors > 0 then hint = hint .. "   错 " .. s.errors end
  center(g, 240, 760, hint, BLACK)
  publish(ctx, targets)
end

local function draw_done(g, ctx, s)
  header(g, s.new_best and "新纪录" or "本局完成")
  local n = s.size * s.size
  local title, tip = grade(s.elapsed_ms, n)
  panel(g, M, 84, CW, 168)
  draw_digits(g, fmt_time(s.elapsed_ms), 240, 132, DIGIT.l, true)
  center(g, 240, 184, title, WHITE)
  center(g, 240, 216, tip, WHITE)

  card(g, M, 272, CW, 168)
  g:text(44, 292, spec_name(s) .. "    错 " .. tostring(s.errors or 0), { color = BLACK })
  g:text(44, 328, "最佳     " .. time_label(s.best[spec_key(s)]), { color = BLACK })
  if (tonumber(s.prev_ms) or 0) > 0 then
    local delta = s.elapsed_ms - s.prev_ms
    g:text(44, 364, delta < 0 and ("上局     快了  " .. time_label(-delta)) or ("上局     慢了  " .. time_label(delta)), { color = BLACK })
  else
    g:text(44, 364, "上局     这是这个规格的第一局", { color = BLACK })
  end
  g:text(44, 400, "今日     " .. tostring(s.today or 0) .. " 局     无错连胜  " .. tostring(s.clean or 0), { color = BLACK })

  if s.size == 5 and s.mode == "asc" then
    g:text(M, 460, "5x5 正序参考", { color = BLACK })
    g:text(M, 496, "普通人 15-20s    熟练 8-15s    飞行员约 6s", { color = BLACK })
    g:text(M, 532, "看中央，用余光找。不要一行行扫。", { color = BLACK })
  else
    g:text(M, 460, "评级按每格耗时折算，方便和 5x5 比较。", { color = BLACK })
    g:text(M, 496, "留格更接近原式，消格适合热身。", { color = BLACK })
    g:text(M, 532, "近八局平均  " .. time_label(spec_avg(s, spec_key(s))), { color = BLACK })
  end
  draw_primary(g, DONE_AGAIN, "再来一局")
  draw_secondary(g, DONE_HOME, "回首页")
  draw_secondary(g, DONE_STATS, "成绩")
  publish(ctx, {
    target_box("again", "再来一局", DONE_AGAIN),
    target_box("done_home", "回首页", DONE_HOME),
    target_box("done_stats", "成绩", DONE_STATS),
  })
end

local function draw_stats(g, ctx, s)
  header(g, "成绩", "返回")
  card(g, M, 84, CW, 112)
  g:text(44, 104, "今日  " .. tostring(s.today or 0) .. "     累计  " .. tostring(s.games or 0) .. "     连胜  " .. tostring(s.clean or 0), { color = BLACK })
  g:text(44, 140, spec_name(s), { color = BLACK })
  g:text(44, 168, "最佳  " .. time_label(s.best[spec_key(s)]) .. "     平均  " .. time_label(spec_avg(s, spec_key(s))), { color = BLACK })

  g:text(M, 216, "各规格最佳", { color = BLACK })
  card(g, M, 248, CW, 200)
  local keys = {}
  for key, _ in pairs(s.best) do keys[#keys + 1] = key end
  table.sort(keys)
  if #keys == 0 then
    g:text(44, 328, "还没有完成的一局。", { color = BLACK })
  else
    local y = 268
    for i = 1, math.min(5, #keys) do
      g:text(44, y, key_name(keys[i]), { color = BLACK })
      g:text(320, y, time_label(s.best[keys[i]]), { color = BLACK })
      y = y + 34
    end
  end

  g:text(M, 468, "最近八局", { color = BLACK })
  card(g, M, 500, CW, 220)
  if #s.recent == 0 then
    g:text(44, 592, "练完一局后，这里会留下用时。", { color = BLACK })
  else
    local max_t = 1
    for i = 1, #s.recent do if s.recent[i].t > max_t then max_t = s.recent[i].t end end
    local y = 520
    for i = #s.recent, 1, -1 do
      local rec = s.recent[i]
      local bw = math.max(10, math.floor(240 * rec.t / max_t))
      g:rect(44, y + 8, bw, 12, "fill", BLACK)
      g:text(300, y, time_label(rec.t) .. (rec.e > 0 and ("  " .. rec.e .. "错") or ""), { color = BLACK })
      y = y + 24
    end
  end
  publish(ctx, { target_box("stats_back", "返回", NAV_RIGHT) })
end

local function handle_home_touch(s, x, y)
  for i, size in ipairs(SIZES) do
    if hit(x, y, M + (i - 1) * (SIZE_W + SIZE_GAP), HOME_SIZE_Y, SIZE_W, CHIP_H) then
      s.size = size
      return true
    end
  end
  for i, mode in ipairs(MODES) do
    if hit(x, y, M + (i - 1) * (MODE_W + MODE_GAP), HOME_MODE_Y, MODE_W, CHIP_H) then
      s.mode = mode
      return true
    end
  end
  if hit(x, y, M, HOME_HIDE_Y, HIDE_W, CHIP_H) then s.hide = 0; return true end
  if hit(x, y, 246, HOME_HIDE_Y, HIDE_W, CHIP_H) then s.hide = 1; return true end
  if hit_box(x, y, START) then deal(s); return true end
  if hit_box(x, y, HOME_HELP) then s.screen = "help"; s.help = 1; return true end
  if hit_box(x, y, HOME_STATS) then s.from = "home"; s.screen = "stats"; return true end
  return true
end

local function handle_input(ctx, ev)
  local s = state(ctx)
  if ev.type == "touch" then
    if ev.gesture == "swipe_left" and s.screen == "help" and s.help == 1 then s.help = 2; return true end
    if ev.gesture == "swipe_right" and s.screen == "help" and s.help == 2 then s.help = 1; return true end
    if ev.gesture ~= "tap" then return ev.gesture ~= nil end
    if s.screen == "home" then return handle_home_touch(s, ev.x, ev.y) end
    if s.screen == "help" then
      if hit_box(ev.x, ev.y, NAV_RIGHT) or (s.help == 2 and hit(ev.x, ev.y, 24, 680, 432, 60)) then
        s.seen = 1
        s.screen = "home"
        return true
      end
      if s.help == 1 and hit(ev.x, ev.y, 24, 680, 432, 60) then s.help = 2; return true end
      return true
    end
    if s.screen == "stats" then
      s.screen = s.from == "done" and "done" or (s.from == "play" and "play" or "home")
      return true
    end
    if s.screen == "done" then
      if hit_box(ev.x, ev.y, DONE_AGAIN) then deal(s); sync_tick(ctx, s); return true end
      if hit_box(ev.x, ev.y, DONE_HOME) then go_home(ctx, s); return true end
      if hit_box(ev.x, ev.y, DONE_STATS) then s.from = "done"; s.screen = "stats"; return true end
      return true
    end
    if hit_box(ev.x, ev.y, NAV_BACK) or hit_box(ev.x, ev.y, PLAY_HOME) then go_home(ctx, s); return true end
    if hit_box(ev.x, ev.y, NAV_RIGHT) then s.from = "play"; s.screen = "stats"; return true end
    if hit_box(ev.x, ev.y, PLAY_RESTART) then deal(s); sync_tick(ctx, s); return true end
    local idx = cell_at(ev.x, ev.y, s)
    if idx then
      s.focus = idx
      return tap_cell(ctx, s, idx)
    end
    return true
  end
  if ev.type ~= "key" or ev.state ~= "down" then return false end
  if s.screen == "home" then
    if ev.key == "ok" then deal(s); return true end
    if ev.key == "left" then s.size = s.size == 3 and 6 or s.size - 1; return true end
    if ev.key == "right" then s.size = s.size == 6 and 3 or s.size + 1; return true end
    if ev.key == "up" or ev.key == "down" then
      local idx = s.mode == "asc" and 1 or (s.mode == "desc" and 2 or 3)
      idx = ev.key == "down" and (idx == 3 and 1 or idx + 1) or (idx == 1 and 3 or idx - 1)
      s.mode = MODES[idx]
      return true
    end
    return false
  end
  if s.screen == "help" then
    if ev.key == "ok" or ev.key == "right" then
      if s.help == 1 then s.help = 2 else s.seen = 1; s.screen = "home" end
      return true
    end
    if ev.key == "left" and s.help == 2 then s.help = 1; return true end
    if ev.key == "back" then s.screen = "home"; return true end
    return false
  end
  if s.screen == "stats" then
    if ev.key == "ok" or ev.key == "back" then
      s.screen = s.from == "done" and "done" or (s.from == "play" and "play" or "home")
      return true
    end
    return false
  end
  if s.screen == "done" then
    if ev.key == "ok" then deal(s); sync_tick(ctx, s); return true end
    if ev.key == "back" then go_home(ctx, s); return true end
    return false
  end
  if ev.key == "back" then go_home(ctx, s); return true end
  if ev.key == "ok" then return tap_cell(ctx, s, s.focus) end
  if ev.key == "left" then
    s.focus = s.focus % s.size == 1 and s.focus + s.size - 1 or s.focus - 1
    return true
  end
  if ev.key == "right" then
    s.focus = s.focus % s.size == 0 and s.focus - s.size + 1 or s.focus + 1
    return true
  end
  if ev.key == "up" then
    s.focus = s.focus <= s.size and s.focus + s.size * (s.size - 1) or s.focus - s.size
    return true
  end
  if ev.key == "down" then
    s.focus = s.focus > s.size * (s.size - 1) and s.focus - s.size * (s.size - 1) or s.focus + s.size
    return true
  end
  return false
end

function on_enter(ctx)
  math.randomseed(ctx.sys:millis())
  local s = state(ctx)
  if s.screen == "play" and (type(s.cells) ~= "table" or #s.cells ~= s.size * s.size) then
    s.screen = "home"
  end
  sync_tick(ctx, s)
  ctx:invalidate()
end

function on_tick(ctx)
  local s = state(ctx)
  if s.screen == "play" and s.running and not s.done then
    local sec = math.floor(elapsed_now(ctx, s) / 1000)
    if sec ~= s.shown_sec then
      s.shown_sec = sec
      ctx:invalidate()
    end
  end
end

function on_input(ctx, ev)
  local handled = handle_input(ctx, ev)
  if handled then ctx:invalidate() end
  return handled
end

function on_draw(ctx, g)
  local s = state(ctx)
  g:clear(WHITE)
  if s.screen == "home" then draw_home(g, ctx, s)
  elseif s.screen == "help" then draw_help(g, ctx, s)
  elseif s.screen == "stats" then draw_stats(g, ctx, s)
  elseif s.screen == "done" then draw_done(g, ctx, s)
  else draw_play(g, ctx, s) end
end
