-- 史纲年表 / X4 Pro 480×800
-- 总表：左侧年代，右侧朝代或事件；当前行反色。分类芯片可筛上古到近代。
--
-- 列表：芯片热区 (6+(i-1)*79, 76, 76×48)，视觉胶囊 inset 4px。
-- 行从 y=136 起，行高 76，分隔线不是每行方框；点 (240, 160) 第一行夏。
-- 详情：返回文字链热区 (12, 12, 80×48)，点 (48, 36)。
-- 列表 BACK 不处理；空白 tap 仍吞掉，避免误触退出。
local BLACK, WHITE = 15, 0
local ERA_ORDER = { "ancient", "qinhan", "suitang", "songyuan", "mingqing", "modern" }
local ERA_LABEL = {
  ancient = "上古", qinhan = "秦汉", suitang = "隋唐",
  songyuan = "宋元", mingqing = "明清", modern = "近代",
}
local ROW_H, VISIBLE, LIST_TOP = 76, 8, 136
local FOOTER_Y = 764

local ERAS = nil

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

local function load_eras(ctx)
  if ERAS then return end
  ERAS = {}
  local reader = ctx.package:open_text("eras.tsv", {max_line_bytes = 1024})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      ERAS[#ERAS + 1] = {
        id = c[1] or "", era = c[2] or "", title = c[3] or "", year = c[4] or "",
        start = c[5] or "", finish = c[6] or "", capital = c[7] or "",
        points = split(c[8] or "", "|"),
      }
    end
  end
  reader:close()
end

local function filtered(s)
  local rows = {}
  for i = 1, #ERAS do
    if ERAS[i].era == s.era then rows[#rows + 1] = ERAS[i] end
  end
  return rows
end

local function restore_cursor(s, rows)
  if s.last_id == "" or #rows == 0 then return end
  for i = 1, #rows do
    if rows[i].id == s.last_id then s.cursor = i; return end
  end
end

local function state(ctx)
  load_eras(ctx)
  local s = ctx.state.dynasty_line
  if type(s) ~= "table" then
    s = { screen = "list", era = "ancient", cursor = 1, scroll = 0, last_id = "" }
    ctx.state.dynasty_line = s
  end
  s.era = ERA_LABEL[s.era] and s.era or "ancient"
  if s.screen ~= "detail" then s.screen = "list" end
  local rows = filtered(s)
  if #rows == 0 then
    s.cursor = 1
    if s.screen == "list" then s.scroll = 0 end
    return s, rows
  end
  s.cursor = math.max(1, math.min(#rows, math.floor(tonumber(s.cursor) or 1)))
  if s.screen == "list" then
    s.scroll = math.max(0, math.min(math.max(0, #rows - VISIBLE), math.floor(tonumber(s.scroll) or 0)))
    if s.cursor <= s.scroll then s.scroll = s.cursor - 1 end
    if s.cursor > s.scroll + VISIBLE then s.scroll = s.cursor - VISIBLE end
  end
  return s, rows
end

local function current(s, rows)
  return rows[s.cursor]
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

local function wrap(text, max_w)
  local lines, buf, width, i = {}, "", 0, 1
  text = text or ""
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

local function hit(x, y, rx, ry, rw, rh)
  return x >= rx and x < rx + rw and y >= ry and y < ry + rh
end

local function rounded_rect(g, x, y, w, h, mode, color, radius)
  local r = radius or math.max(6, math.min(20, math.floor(h / 2)))
  if r * 2 > w then r = math.floor(w / 2) end
  if r * 2 > h then r = math.floor(h / 2) end
  if mode == "fill" then
    g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
    g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
    g:circle(x + r, y + r, r,{fill=true,color=color})
    g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
    g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
    g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
    return
  end
  local inset = 2
  local ri = math.max(2, r - inset)
  rounded_rect(g, x, y, w, h, "fill", color, r)
  rounded_rect(g, x + inset, y + inset, w - inset * 2, h - inset * 2, "fill", WHITE, ri)
end

local function era_chip(i)
  return 6 + (i - 1) * 79, 76, 76, 48
end

local function list_row(i, width)
  return 0, LIST_TOP + (i - 1) * ROW_H, width, ROW_H
end

local function back_hit()
  return 12, 12, 80, 48
end

local function open_detail(s, rows)
  local item = current(s, rows)
  if not item then return end
  s.screen = "detail"
  s.last_id = item.id
end

local function back_to_list(s, rows)
  s.screen = "list"
  restore_cursor(s, rows)
end

local function move_cursor(s, rows, delta)
  if #rows == 0 then return end
  s.cursor = ((s.cursor - 1 + delta) % #rows) + 1
end

local function cycle_era(s, delta)
  local i = 1
  for n = 1, #ERA_ORDER do if ERA_ORDER[n] == s.era then i = n end end
  i = i + delta
  if i < 1 then i = #ERA_ORDER elseif i > #ERA_ORDER then i = 1 end
  s.era = ERA_ORDER[i]
  s.cursor = 1
  s.scroll = 0
end

local function step_item(s, rows, delta)
  if #rows == 0 then return end
  local nxt = s.cursor + delta
  if nxt < 1 or nxt > #rows then return end
  s.cursor = nxt
  s.last_id = rows[s.cursor].id
end

local function handle_list(ctx, s, rows, ev)
  local width = ctx.screen.width
  if (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture == "swipe_up" then move_cursor(s, rows, 1); return true end
    if ev.gesture == "swipe_down" then move_cursor(s, rows, -1); return true end
    if ev.gesture == "swipe_left" then cycle_era(s, 1); return true end
    if ev.gesture == "swipe_right" then cycle_era(s, -1); return true end
    if ev.gesture ~= "tap" then return true end
    for i = 1, #ERA_ORDER do
      local x, y, w, h = era_chip(i)
      if hit(ev.x, ev.y, x, y, w, h) then
        s.era = ERA_ORDER[i]
        s.cursor = 1
        s.scroll = 0
        return true
      end
    end
    for vis = 1, VISIBLE do
      local idx = s.scroll + vis
      if idx > #rows then break end
      local x, y, w, h = list_row(vis, width)
      if hit(ev.x, ev.y, x, y, w, h) then s.cursor = idx; open_detail(s, rows); return true end
    end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "left" then cycle_era(s, -1)
  elseif ev.key == "right" then cycle_era(s, 1)
  elseif ev.key == "up" then move_cursor(s, rows, -1)
  elseif ev.key == "down" then move_cursor(s, rows, 1)
  elseif ev.key == "ok" then open_detail(s, rows)
  else return false end
  return true
end

local function handle_detail(ctx, s, rows, ev)
  local item = current(s, rows)
  if not item then s.screen = "list"; return true end
  if (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture == "swipe_left" then step_item(s, rows, 1); return true end
    if ev.gesture == "swipe_right" then step_item(s, rows, -1); return true end
    if ev.gesture ~= "tap" then return true end
    local bx, by, bw, bh = back_hit()
    if hit(ev.x, ev.y, bx, by, bw, bh) then back_to_list(s, rows); return true end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "back" then back_to_list(s, rows)
  elseif ev.key == "left" then step_item(s, rows, -1)
  elseif ev.key == "right" then step_item(s, rows, 1)
  elseif ev.key == "up" then step_item(s, rows, -1)
  elseif ev.key == "down" then step_item(s, rows, 1)
  else return false end
  return true
end

function on_load(ctx)
  ctx:set_tick(0)
  state(ctx)
  ctx:invalidate()
end

function on_input(ctx, ev)
  local s, rows = state(ctx)
  local handled
  if s.screen == "detail" then
    handled = handle_detail(ctx, s, rows, ev)
  else
    handled = handle_list(ctx, s, rows, ev)
  end
  if handled then ctx:invalidate() end
  return handled
end

local function center_text(g, cx, y, text, color)
  g:text(cx - math.floor(text_w(text) / 2), y, text, { color = color })
end

local function draw_header(g, title, sub)
  g:text(24, 22, title, { color = BLACK })
  if sub then g:text(24, 46, sub, { color = BLACK }) end
  g:line(24, 68, 456, 68,{color=BLACK})
end

local function draw_footer(g, text)
  g:text(24, FOOTER_Y, text, { color = BLACK })
end

local function draw_list(g, s, rows, width)
  local sub = string.format("%s · %d 条", ERA_LABEL[s.era], #rows)
  if #rows == 0 then sub = "这一类是空的" end
  draw_header(g, "史纲年表", sub)
  for i = 1, #ERA_ORDER do
    local hx, hy, hw, hh = era_chip(i)
    local x, y, w, h = hx + 4, hy + 4, hw - 8, hh - 8
    local on = s.era == ERA_ORDER[i]
    local label = ERA_LABEL[ERA_ORDER[i]]
    if on then
      rounded_rect(g, x, y, w, h, "fill", BLACK, math.floor(h / 2))
    else
      rounded_rect(g, x, y, w, h, "stroke", BLACK, math.floor(h / 2))
    end
    center_text(g, x + math.floor(w / 2), y + 10, label, on and WHITE or BLACK)
  end
  if #rows == 0 then
    center_text(g, math.floor(width / 2), 360, "这一类还没有条目", BLACK)
    draw_footer(g, "←→ 换一类")
    return
  end
  for vis = 1, VISIBLE do
    local idx = s.scroll + vis
    if idx > #rows then break end
    local item = rows[idx]
    local x, y, w, h = list_row(vis, width)
    local on = idx == s.cursor
    if on then g:rect(x, y, w, h,{fill=true,color=BLACK}) end
    if vis > 1 then
      local prev_on = (idx - 1) == s.cursor
      if not on and not prev_on then
        g:line(24, y, 456, y,{color=BLACK})
      end
    end
    local ink = on and WHITE or BLACK
    g:text(28, y + 26, clip(item.year, 108), { color = ink })
    g:text(148, y + 26, clip(item.title, 300), { color = ink })
  end
  draw_footer(g, "↑↓ 选条    ←→ 分类    OK 打开")
end

local function draw_axis(g, item)
  local x, top, bottom = 48, 100, 236
  local mid = math.floor((top + bottom) / 2)
  g:line(x, top, x, bottom,{color=BLACK})
  g:circle(x, top, 6,{color=BLACK})
  g:circle(x, mid, 8,{fill=true,color=BLACK})
  g:circle(x, bottom, 6,{color=BLACK})
  g:text(72, top - 8, clip(item.start, 360), { color = BLACK })
  local mid_label = item.capital ~= "" and item.capital or item.title
  g:text(72, mid - 8, clip(mid_label, 360), { color = BLACK })
  g:text(72, bottom - 8, clip(item.finish, 360), { color = BLACK })
end

local function draw_detail(g, s, rows)
  local item = current(s, rows)
  if not item then return end
  g:text(16, 22, "〈 返回", { color = BLACK })
  center_text(g, 240, 18, clip(item.title, 260), BLACK)
  center_text(g, 240, 44, clip(ERA_LABEL[item.era] .. " · " .. item.year, 260), BLACK)
  g:line(24, 72, 456, 72,{color=BLACK})
  draw_axis(g, item)
  g:line(24, 260, 456, 260,{color=BLACK})
  local y = 280
  g:text(28, y, "起止  " .. clip(item.start .. " — " .. item.finish, 360), { color = BLACK })
  y = y + 40
  if item.capital ~= "" then
    g:text(28, y, "都城  " .. item.capital, { color = BLACK })
    y = y + 40
  end
  y = y + 8
  for i = 1, #item.points do
    local lines = wrap("· " .. item.points[i], 400)
    for n = 1, #lines do
      if y + 24 < FOOTER_Y then g:text(28, y, lines[n], { color = BLACK }) end
      y = y + 34
    end
    y = y + 6
  end
  draw_footer(g, "←→ 邻条    BACK 返回")
end

function on_draw(ctx, g)
  local s, rows = state(ctx)
  g:clear(WHITE)
  if s.screen == "detail" then
    draw_detail(g, s, rows)
  else
    draw_list(g, s, rows, ctx.screen.width)
  end
end
