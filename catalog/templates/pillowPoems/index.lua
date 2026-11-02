-- 枕上古诗 / X4 Pro 480×800
-- 列表 → 朗读 → 遮句背诵。篇目按 TSV 文件顺序，不套间隔复习。
--
-- 列表：芯片热区 (10+(i-1)*94, 76, 88×48)，视觉胶囊 inset 4px。
-- 行从 y=136 起，行高 76，分隔线不是每行方框；点 (240, 160) 第一行静夜思。
-- 朗读/背诵：正文 96–656；提示条 662；底栏热区 692–752；页脚 764。
-- 返回文字链热区 (12, 12, 80×48)，点 (48, 36)；正文点 (240, 300) 开注释。
local BLACK, WHITE = 15, 0
local FILES = {
  { era = "tang", name = "tang.tsv" },
  { era = "song", name = "song.tsv" },
  { era = "wen", name = "wen.tsv" },
}
local ERA_ORDER = { "all", "tang", "song", "wen", "fav" }
local ERA_LABEL = { all = "全部", tang = "唐", song = "宋", wen = "文", fav = "收藏" }
local ROW_H, VISIBLE, LIST_TOP = 76, 8, 136
local LEAD, VERSE_TOP, VERSE_BOTTOM = 40, 96, 656
local HINT_Y, FOOTER_Y = 662, 764
local NOTE_LEAD = 34
local BAR_HITS = {
  { 8, 692, 96, 60 },
  { 104, 692, 80, 60 },
  { 184, 692, 192, 60 },
  { 376, 692, 96, 60 },
}

local POEMS = nil

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

local function load_file(ctx, era, name)
  local reader = ctx.package:open_text(name, {max_line_bytes = 8192})
  if not reader then return end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    if line ~= "" then
      local c = split(line, "\t")
      POEMS[#POEMS + 1] = {
        id = c[1] or "", era = era, title = c[2] or "", author = c[3] or "",
        lines = split(c[4] or "", "|"), note = c[5] or "", yi = c[6] or "",
      }
    end
  end
  reader:close()
end

local function ensure_poems(ctx)
  if POEMS then return end
  POEMS = {}
  for i = 1, #FILES do load_file(ctx, FILES[i].era, FILES[i].name) end
end

local function filtered(s)
  local rows = {}
  for i = 1, #POEMS do
    local p = POEMS[i]
    if s.era == "fav" then
      if s.favorites[p.id] then rows[#rows + 1] = p end
    elseif s.era == "all" or p.era == s.era then
      rows[#rows + 1] = p
    end
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
  ensure_poems(ctx)
  local s = ctx.state.pillow_poems
  if type(s) ~= "table" then
    s = {
      screen = "list", era = "all", cursor = 1, scroll = 0, read_scroll = 0,
      show_notes = false, recite = 0, favorites = {}, last_id = "",
    }
    ctx.state.pillow_poems = s
  end
  s.favorites = type(s.favorites) == "table" and s.favorites or {}
  s.era = ERA_LABEL[s.era] and s.era or "all"
  if s.screen ~= "read" and s.screen ~= "recite" then s.screen = "list" end
  s.show_notes = s.screen == "read" and s.show_notes == true
  s.recite = math.max(0, math.floor(tonumber(s.recite) or 0))
  s.read_scroll = math.max(0, math.floor(tonumber(s.read_scroll) or 0))
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
  local p = rows[s.cursor]
  if p then s.recite = math.min(s.recite, #p.lines) end
  return s, rows
end

local function current(s, rows)
  return rows[s.cursor]
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

local function notes_height(p)
  return NOTE_LEAD + #wrap(p.note, 400) * NOTE_LEAD + 20 + NOTE_LEAD + #wrap(p.yi, 400) * NOTE_LEAD
end

local function page_span(s, p)
  if not p then return 0 end
  if s.screen == "read" and s.show_notes then return notes_height(p) end
  return #p.lines * LEAD
end

local function room()
  return VERSE_BOTTOM - VERSE_TOP
end

local function can_scroll_more(s, p)
  return s.read_scroll + room() < page_span(s, p)
end

local function clamp_read_scroll(s, p)
  s.read_scroll = math.max(0, math.min(s.read_scroll, math.max(0, page_span(s, p) - room())))
end

local function open_read(s, rows)
  local p = current(s, rows)
  if not p then return end
  s.screen = "read"
  s.show_notes = false
  s.recite = 0
  s.read_scroll = 0
  s.last_id = p.id
end

local function enter_recite(s, rows)
  local p = current(s, rows)
  if not p then return end
  s.screen = "recite"
  s.show_notes = false
  s.recite = 0
  s.read_scroll = 0
  s.last_id = p.id
end

local function exit_recite(s)
  s.screen = "read"
  s.show_notes = false
  s.recite = 0
  s.read_scroll = 0
end

local function back_to_list(s, rows)
  s.screen = "list"
  s.show_notes = false
  s.recite = 0
  s.read_scroll = 0
  restore_cursor(s, rows)
end

local function step_poem(s, rows, delta)
  if #rows == 0 then return end
  local nxt = s.cursor + delta
  if nxt < 1 or nxt > #rows then return end
  s.cursor = nxt
  s.show_notes = false
  s.recite = 0
  s.read_scroll = 0
  s.last_id = rows[s.cursor].id
end

local function ensure_line_visible(s, p, index)
  if not p or index < 1 then
    s.read_scroll = 0
    return
  end
  local y = (index - 1) * LEAD
  if y < s.read_scroll then s.read_scroll = y end
  if y + LEAD > s.read_scroll + room() then s.read_scroll = y + LEAD - room() end
  clamp_read_scroll(s, p)
end

local function reveal_next(s, p)
  if not p or #p.lines == 0 then return end
  if s.recite >= #p.lines then
    s.recite = 0
    s.read_scroll = 0
  else
    s.recite = s.recite + 1
    ensure_line_visible(s, p, s.recite)
  end
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
  return 10 + (i - 1) * 94, 76, 88, 48
end

local function list_row(i)
  return 0, LIST_TOP + (i - 1) * ROW_H, 480, ROW_H
end

local function bar_hit(i)
  local t = BAR_HITS[i]
  return t[1], t[2], t[3], t[4]
end

local function back_hit()
  return 12, 12, 80, 48
end

local function fav_hit()
  return 400, 12, 68, 48
end

local function title_hit()
  return 100, 12, 292, 52
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

local function toggle_fav(s, p)
  if not p then return end
  s.favorites[p.id] = not s.favorites[p.id]
end

local function handle_list(ctx, s, rows, ev)
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
      local x, y, w, h = list_row(vis)
      if hit(ev.x, ev.y, x, y, w, h) then s.cursor = idx; open_read(s, rows); return true end
    end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "left" then cycle_era(s, -1)
  elseif ev.key == "right" then cycle_era(s, 1)
  elseif ev.key == "up" then move_cursor(s, rows, -1)
  elseif ev.key == "down" then move_cursor(s, rows, 1)
  elseif ev.key == "ok" then open_read(s, rows)
  else return false end
  return true
end

local function handle_header_touch(s, rows, ev)
  local p = current(s, rows)
  local bx, by, bw, bh = back_hit()
  if hit(ev.x, ev.y, bx, by, bw, bh) then
    if s.screen == "read" then back_to_list(s, rows) else exit_recite(s) end
    return true
  end
  local fx, fy, fw, fh = fav_hit()
  local tx, ty, tw, th = title_hit()
  if hit(ev.x, ev.y, fx, fy, fw, fh) or hit(ev.x, ev.y, tx, ty, tw, th) then
    toggle_fav(s, p)
    return true
  end
  return false
end

local function handle_read_bar(s, rows, ev)
  for i = 1, 4 do
    local x, y, w, h = bar_hit(i)
    if hit(ev.x, ev.y, x, y, w, h) then
      if i == 1 then step_poem(s, rows, -1)
      elseif i == 2 then s.show_notes = not s.show_notes; s.read_scroll = 0
      elseif i == 3 then enter_recite(s, rows)
      else step_poem(s, rows, 1) end
      return true
    end
  end
  return false
end

local function handle_recite_bar(s, rows, ev, p)
  for i = 1, 4 do
    local x, y, w, h = bar_hit(i)
    if hit(ev.x, ev.y, x, y, w, h) then
      if i == 1 then step_poem(s, rows, -1)
      elseif i == 2 then exit_recite(s)
      elseif i == 3 then reveal_next(s, p)
      else step_poem(s, rows, 1) end
      return true
    end
  end
  return false
end

local function handle_read(ctx, s, rows, ev)
  local p = current(s, rows)
  if not p then s.screen = "list"; return true end
  if (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture == "swipe_up" then
      s.read_scroll = s.read_scroll + LEAD; clamp_read_scroll(s, p); return true
    end
    if ev.gesture == "swipe_down" then
      s.read_scroll = math.max(0, s.read_scroll - LEAD); return true
    end
    if ev.gesture == "swipe_left" then step_poem(s, rows, 1); return true end
    if ev.gesture == "swipe_right" then step_poem(s, rows, -1); return true end
    if ev.gesture ~= "tap" then return true end
    if handle_header_touch(s, rows, ev) then return true end
    if handle_read_bar(s, rows, ev) then return true end
    if ev.y >= VERSE_TOP and ev.y < 692 then
      s.show_notes = not s.show_notes
      s.read_scroll = 0
      return true
    end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "back" then back_to_list(s, rows)
  elseif ev.key == "ok" then s.show_notes = not s.show_notes; s.read_scroll = 0
  elseif ev.key == "down" then
    if can_scroll_more(s, p) then
      s.read_scroll = s.read_scroll + LEAD
      clamp_read_scroll(s, p)
    else
      enter_recite(s, rows)
    end
  elseif ev.key == "up" then
    if s.read_scroll > 0 then s.read_scroll = math.max(0, s.read_scroll - LEAD)
    else step_poem(s, rows, -1) end
  elseif ev.key == "left" then step_poem(s, rows, -1)
  elseif ev.key == "right" then step_poem(s, rows, 1)
  else return false end
  return true
end

local function handle_recite(ctx, s, rows, ev)
  local p = current(s, rows)
  if not p then s.screen = "list"; return true end
  if (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture == "swipe_up" then
      s.read_scroll = s.read_scroll + LEAD; clamp_read_scroll(s, p); return true
    end
    if ev.gesture == "swipe_down" then
      s.read_scroll = math.max(0, s.read_scroll - LEAD); return true
    end
    if ev.gesture == "swipe_left" then step_poem(s, rows, 1); return true end
    if ev.gesture == "swipe_right" then step_poem(s, rows, -1); return true end
    if ev.gesture ~= "tap" then return true end
    if handle_header_touch(s, rows, ev) then return true end
    if handle_recite_bar(s, rows, ev, p) then return true end
    if ev.y >= VERSE_TOP and ev.y < 692 then
      reveal_next(s, p)
      return true
    end
    return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "back" then exit_recite(s)
  elseif ev.key == "ok" or ev.key == "down" then reveal_next(s, p)
  elseif ev.key == "up" then
    if s.recite > 0 then
      s.recite = s.recite - 1
      if s.recite > 0 then ensure_line_visible(s, p, s.recite) else s.read_scroll = 0 end
    end
  elseif ev.key == "left" then step_poem(s, rows, -1)
  elseif ev.key == "right" then step_poem(s, rows, 1)
  else return false end
  return true
end

function on_load(ctx)
  ctx:set_tick(0)
  ctx:invalidate()
end

function on_input(ctx, ev)
  local s, rows = state(ctx)
  local handled
  if s.screen == "list" then
    handled = handle_list(ctx, s, rows, ev)
  elseif s.screen == "recite" then
    handled = handle_recite(ctx, s, rows, ev)
  else
    handled = handle_read(ctx, s, rows, ev)
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

local function draw_link(g, i, label)
  local x, y, w, h = bar_hit(i)
  center_text(g, x + math.floor(w / 2), y + 20, label, BLACK)
end

local function draw_primary(g, label)
  local x, y, w, h = bar_hit(3)
  local vx, vy, vw, vh = x + 8, y + 6, w - 16, h - 12
  rounded_rect(g, vx, vy, vw, vh, "stroke", BLACK, 16)
  center_text(g, x + math.floor(w / 2), y + 20, label, BLACK)
end

local function draw_footer(g, text)
  g:text(24, FOOTER_Y, text, { color = BLACK })
end

local function draw_hint(g, text)
  if not text or text == "" then return end
  center_text(g, 240, HINT_Y, text, BLACK)
end

local function draw_list(g, s, rows)
  local sub = string.format("%d 篇 · 选一首读", #rows)
  if s.era == "fav" then
    sub = #rows == 0 and "收藏" or string.format("%d 篇收藏", #rows)
  elseif #rows == 0 then
    sub = "这一类是空的"
  end
  draw_header(g, "枕上古诗", sub)
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
    g:circle(240, 292, 26,{color=BLACK})
    center_text(g, 240, 282, "☆", BLACK)
    if s.era == "fav" then
      center_text(g, 240, 360, "还没有收藏", BLACK)
      center_text(g, 240, 400, "读到喜欢的，点右上角 ★", BLACK)
    else
      center_text(g, 240, 360, "这一类还没有篇目", BLACK)
    end
    draw_footer(g, "←→ 换一类")
    return
  end
  for vis = 1, VISIBLE do
    local idx = s.scroll + vis
    if idx > #rows then break end
    local p = rows[idx]
    local x, y, w, h = list_row(vis)
    local on = idx == s.cursor
    if on then g:rect(x, y, w, h,{fill=true,color=BLACK}) end
    if vis > 1 then
      local prev_on = (idx - 1) == s.cursor
      if not on and not prev_on then
        g:line(24, y, 456, y,{color=BLACK})
      end
    end
    local ink = on and WHITE or BLACK
    local mark = s.favorites[p.id] and "★ " or ""
    g:text(32, y + 10, clip(mark .. p.title, 416), { color = ink })
    local first = p.lines[1] or ""
    local line2 = ERA_LABEL[p.era] .. " · " .. p.author
    if first ~= "" then line2 = line2 .. " · " .. first end
    g:text(32, y + 38, clip(line2, 416), { color = ink })
  end
  draw_footer(g, "↑↓ 选篇    ←→ 分类    OK 打开")
end

local function draw_clipped_text(g, x, y, text)
  if y >= VERSE_TOP - 4 and y + 24 <= VERSE_BOTTOM then
    g:text(x, y, text, { color = BLACK })
    return true
  end
  return false
end

local function draw_notes(g, p, scroll)
  local y = VERSE_TOP - scroll
  draw_clipped_text(g, 24, y, "注释")
  y = y + NOTE_LEAD
  local note_lines = wrap(p.note, 400)
  for i = 1, #note_lines do
    draw_clipped_text(g, 36, y, note_lines[i])
    y = y + NOTE_LEAD
  end
  y = y + 20
  draw_clipped_text(g, 24, y, "今译")
  y = y + NOTE_LEAD
  local yi_lines = wrap(p.yi, 400)
  for i = 1, #yi_lines do
    draw_clipped_text(g, 36, y, yi_lines[i])
    y = y + NOTE_LEAD
  end
end

local function draw_verses(g, p, s)
  local y = VERSE_TOP - s.read_scroll
  local hiding = s.screen == "recite"
  for i = 1, #p.lines do
    local line = p.lines[i]
    local w = text_w(line)
    local x = math.max(24, math.floor((480 - w) / 2))
    if y >= VERSE_TOP - 4 and y + 28 <= VERSE_BOTTOM then
      if hiding and i > s.recite then
        g:line(x, y + 22, x + math.max(w, 20), y + 22,{color=BLACK})
      else
        g:text(x, y, line, { color = BLACK })
      end
    end
    y = y + LEAD
  end
end

local function recite_sub(s, p)
  local base = p.author .. " · " .. ERA_LABEL[p.era]
  if s.recite <= 0 then
    return clip(base .. " · 先想一句", 260)
  end
  if s.recite >= #p.lines then
    return clip(base .. " · 揭完了", 260)
  end
  return clip(string.format("%s · %d/%d", base, s.recite, #p.lines), 260)
end

local function draw_poem_header(g, s, p)
  g:text(16, 22, "〈 返回", { color = BLACK })
  local starred = s.favorites[p.id]
  local cx, cy, r = 434, 36, 16
  if starred then
    g:circle(cx, cy, r,{fill=true,color=BLACK})
    center_text(g, cx, cy - 10, "★", WHITE)
  else
    g:circle(cx, cy, r,{color=BLACK})
    center_text(g, cx, cy - 10, "☆", BLACK)
  end
  local title = clip(p.title, 260)
  center_text(g, 240, 18, title, BLACK)
  local sub = p.author .. " · " .. ERA_LABEL[p.era]
  if s.screen == "recite" then sub = recite_sub(s, p) end
  center_text(g, 240, 44, clip(sub, 260), BLACK)
  g:line(24, 72, 456, 72,{color=BLACK})
end

local function draw_read(g, s, rows)
  local p = current(s, rows)
  if not p then return end
  clamp_read_scroll(s, p)
  draw_poem_header(g, s, p)
  if s.show_notes then
    draw_notes(g, p, s.read_scroll)
  else
    draw_verses(g, p, s)
  end
  if can_scroll_more(s, p) then
    draw_hint(g, "还有下文 ↓")
    draw_footer(g, "↓ 往下看    OK 注释")
  else
    draw_footer(g, "↓ 去背诵    OK 注释")
  end
  draw_link(g, 1, "上一篇")
  draw_link(g, 2, s.show_notes and "收起" or "注释")
  draw_primary(g, "背诵")
  draw_link(g, 4, "下一篇")
end

local function draw_recite(g, s, rows)
  local p = current(s, rows)
  if not p then return end
  clamp_read_scroll(s, p)
  draw_poem_header(g, s, p)
  draw_verses(g, p, s)
  local done = s.recite >= #p.lines and #p.lines > 0
  if done then
    draw_hint(g, "揭完了，再按重来")
  elseif s.recite == 0 then
    draw_hint(g, "想起来再揭")
  end
  draw_link(g, 1, "上一篇")
  draw_link(g, 2, "看全文")
  draw_primary(g, done and "重来" or "下一句")
  draw_link(g, 4, "下一篇")
  draw_footer(g, "OK 揭开    ↑ 收回    BACK 朗读")
end

function on_draw(ctx, g)
  local s, rows = state(ctx)
  g:clear(WHITE)
  if s.screen == "list" then
    draw_list(g, s, rows)
  elseif s.screen == "recite" then
    draw_recite(g, s, rows)
  else
    draw_read(g, s, rows)
  end
end
