local PkgImage = require("pkg_image")
-- MindNotes / Legacy review client
-- 安装前填写专用 Skill Token。
local TOKEN = "__PREVIEW_ENV_MINDNOTES_TOKEN__"
if TOKEN == "__PREVIEW_ENV_MINDNOTES_TOKEN__" then TOKEN = "" end
local API = "http://api.mindnotes.cn/legacy-review/v1/"
local BATCH = 20

local task_id = nil
local on_net_done

local function quote(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  return '"' .. value .. '"'
end

local function utf8_char(code)
  if code < 0x80 then return string.char(code) end
  if code < 0x800 then return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40) end
  if code < 0x10000 then return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40) end
  return string.char(0xF0 + math.floor(code / 0x40000), 0x80 + math.floor(code / 0x1000) % 0x40, 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local ESCAPE = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function json_string(text, pos)
  local out, i, start = {}, pos + 1, pos + 1
  while true do
    local stop = text:find('[\\"]', i)
    if not stop then return nil, i end
    if text:sub(stop, stop) == '"' then
      if stop > start then out[#out + 1] = text:sub(start, stop - 1) end
      return table.concat(out), stop + 1
    end
    if stop > start then out[#out + 1] = text:sub(start, stop - 1) end
    local e = text:sub(stop + 1, stop + 1)
    if e == "u" then
      local code = tonumber(text:sub(stop + 2, stop + 5), 16)
      i = stop + 6
      if code and code >= 0xD800 and code <= 0xDBFF and text:sub(i, i + 1) == "\\u" then
        local low = tonumber(text:sub(i + 2, i + 5), 16)
        if low and low >= 0xDC00 and low <= 0xDFFF then
          code = 0x10000 + (code - 0xD800) * 0x400 + low - 0xDC00
          i = i + 6
        end
      end
      out[#out + 1] = code and utf8_char(code) or "?"
    else
      out[#out + 1] = ESCAPE[e] or e
      i = stop + 2
    end
    start = i
  end
end

local function json_value(text, pos)
  pos = pos or 1
  pos = text:find("%S", pos) or (#text + 1)
  local first = text:sub(pos, pos)
  if first == '"' then
    return json_string(text, pos)
  elseif first == "{" then
    local object, i = {}, pos + 1
    while true do
      i = text:find("%S", i) or (#text + 1)
      if text:sub(i, i) == "}" then return object, i + 1 end
      local key; key, i = json_value(text, i)
      if key == nil then return nil, i end
      i = text:find("%S", i) or (#text + 1)
      if text:sub(i, i) ~= ":" then return nil, i end
      local value; value, i = json_value(text, i + 1); object[key] = value
      i = text:find("%S", i) or (#text + 1)
      if text:sub(i, i) == "}" then return object, i + 1 end
      if text:sub(i, i) ~= "," then return nil, i end
      i = i + 1
    end
  elseif first == "[" then
    local array, i = {}, pos + 1
    while true do
      i = text:find("%S", i) or (#text + 1)
      if text:sub(i, i) == "]" then return array, i + 1 end
      local value; value, i = json_value(text, i); array[#array + 1] = value
      i = text:find("%S", i) or (#text + 1)
      if text:sub(i, i) == "]" then return array, i + 1 end
      if text:sub(i, i) ~= "," then return nil, i end
      i = i + 1
    end
  end
  local last = pos
  while last <= #text do
    local b = text:byte(last)
    if not b or b <= 32 or b == 44 or b == 93 or b == 125 then break end
    last = last + 1
  end
  local raw = text:sub(pos, last - 1)
  if raw == "true" then return true, pos + 4 end
  if raw == "false" then return false, pos + 5 end
  if raw == "null" then return nil, pos + 4 end
  return tonumber(raw), pos + #raw
end

local function strip_bom(text)
  text = tostring(text or "")
  if #text >= 3 and text:byte(1) == 239 and text:byte(2) == 187 and text:byte(3) == 191 then
    return text:sub(4)
  end
  return text
end

local function decode(text)
  local ok, value = pcall(json_value, strip_bom(text), 1)
  if not ok then
    local message = tostring(value)
    if message:find("watchdog", 1, true) and message:find("time budget", 1, true) then error(value, 0) end
    return nil
  end
  return value
end
local function pick(source, keys)
  if type(source) ~= "table" then return nil end
  for _, key in ipairs(keys) do if source[key] ~= nil then return source[key] end end
end
local function parse_failure(result)
  local body = tostring(result.body or "")
  local bytes = tonumber(result.bytes) or #body
  if result.err == "too_large" then return "复习数据超过 128KB，点重试会改取更小一批" end
  if body == "" then return "复习数据为空" end
  local last = body:match("(%S)%s*$")
  if last ~= "}" and last ~= "]" then return "复习数据不完整（" .. tostring(bytes) .. " 字节）" end
  return "复习数据解析失败"
end
local function request_error(result)
  local status = tonumber(result.status)
  if status == 401 then return "Token 无效或已过期，请重新填写 Skill Token" end
  if status == 403 then return "这个 Token 没有复习权限，需要 notes:read 和 review:write" end
  if result.err == "too_large" then return parse_failure(result) end
  local envelope = decode(result.body or "") or {}
  local problem = envelope.error or envelope
  local message = pick(problem, { "message", "detail", "code" })
  if message and tostring(message) ~= "" then return tostring(message) end
  if status then return "请求失败 " .. tostring(status) end
  return tostring(result.err or "请求失败")
end
local function normalize_status(value)
  local status = tostring(value or "")
  if status == "forgotten" then return "again" end
  if status == "fuzzy" then return "hard" end
  if status == "remembered" then return "easy" end
  if status == "again" or status == "hard" or status == "good" or status == "easy" then return status end
  return nil
end
local function loading_message(kind)
  if kind == "dashboard" then return "正在读取今日复习…" end
  if kind == "next" then return "正在领取本轮卡片…" end
  if kind == "submit" then return "正在提交评分…" end
  return "正在连接…"
end
local function app(ctx)
  ctx.state.mindnotes = ctx.state.mindnotes or { screen = "loading", side = "front", message = "正在获取下一张…", sequence = 0 }
  return ctx.state.mindnotes
end
local function headers() return { ["Authorization"] = "Bearer " .. TOKEN, ["Content-Type"] = "application/json" } end
local function start(ctx, path, body, kind)
  local s = app(ctx)
  if task_id then return false end
  local id, err = ctx.net:request({ url = API .. path, method = "POST", body = body, headers = headers() }, on_net_done)
  if not id then s.screen = "error"; s.message = tostring(err); ctx:invalidate(); return false end
  task_id = id; s.request_kind = kind; s.screen = "loading"; s.message = loading_message(kind); ctx:invalidate(); return true
end
local function queue_body(count)
  local fields = { '"include_new":true', '"new_limit":10' }
  if count then fields[#fields + 1] = '"count":' .. tostring(count) end
  return "{" .. table.concat(fields, ",") .. "}"
end
local function fetch_dashboard(ctx) return start(ctx, "due", queue_body(nil), "dashboard") end
local function fetch_next(ctx, count)
  local s = app(ctx)
  s.batch_count = tonumber(count) or s.batch_count or BATCH
  return start(ctx, "next", queue_body(s.batch_count), "next")
end
local function retry_smaller_batch(ctx, s)
  local current = tonumber(s.batch_count) or BATCH
  if s.request_kind ~= "next" or current <= 3 then return false end
  return fetch_next(ctx, math.max(3, math.floor(current / 2)))
end
local function begin_parse(ctx)
  ctx.budget:extend()
end
local function can_review(s)
  return (tonumber(s.due_count) or 0) > 0 or (tonumber(s.new_count) or 0) > 0
end
local function begin_session(s)
  s.session_reviewed = 0
  s.session_grades = { again = 0, hard = 0, good = 0, easy = 0 }
end
local function read_counts(s, data)
  data = type(data) == "table" and data or {}
  local counts = type(data.counts) == "table" and data.counts or {}
  s.due_count = tonumber(pick(data, { "due_count", "due", "total" }) or pick(counts, { "due", "total" })) or 0
  s.overdue_count = tonumber(pick(data, { "overdue_count", "overdue" }) or pick(counts, { "overdue" })) or 0
  s.new_count = tonumber(pick(data, { "new_count", "new_available_count", "new" }) or pick(counts, { "new", "new_available_count" })) or 0
  s.reviewed_today_count = tonumber(pick(data, { "reviewed_today_count", "reviewed_today" }) or pick(counts, { "reviewed_today_count" })) or s.reviewed_today_count or 0
  s.remaining = tonumber(data.remaining or s.remaining) or 0
end
local function review_notes(data)
  if type(data) ~= "table" then return {} end
  local notes = pick(data, { "notes", "items", "cards" })
  if type(notes) == "table" and notes[1] then return notes end
  local note = pick(data, { "note", "card", "item" })
  if type(note) == "table" and (note.note_id or note.id or note.title or note.content) then return { note } end
  return {}
end
local function show_note(s, note)
  note = type(note) == "table" and note or {}
  s.note_id = pick(note, { "note_id", "id" })
  s.title = pick(note, { "title", "front", "question", "prompt" }) or ""
  s.content = pick(note, { "content", "back", "answer", "body", "preview" }) or ""
  s.fsrs = note.fsrs or {}
  s.memory = note.memory or {}
  s.preview_memory = note.preview_memory or {}
  s.content_offset = 0
  s.revealed = false
  s.side = "back"
  s.screen = s.note_id and "card" or "done"
  s.message = s.note_id and "" or "今日没有待复习卡片"
end
local function load_queue(s, data)
  read_counts(s, data)
  s.queue = review_notes(data)
  s.queue_index = 1
  if #(s.queue) == 0 then
    s.note_id = nil
    if (s.session_reviewed or 0) > 0 then s.screen = "done"; s.message = ""
    else s.screen = "empty"; s.message = "今日没有待复习卡片" end
    return
  end
  show_note(s, s.queue[1])
end
local function advance_queue(s)
  s.queue_index = (s.queue_index or 1) + 1
  local note = s.queue and s.queue[s.queue_index]
  if note then show_note(s, note) else s.note_id = nil; s.screen = "done"; s.message = "" end
end
local function submit(ctx, status)
  local s = app(ctx)
  if s.pending_status then status = s.pending_status else
    s.sequence = (s.sequence or 0) + 1; s.pending_status = status
    s.operation_id = "mindnotes-" .. tostring(s.sequence) .. "-" .. tostring(ctx.clock:now().epoch_sec or 0)
  end
  return start(ctx, "submit", '{"note_id":' .. quote(s.note_id) .. ',"status":' .. quote(status) .. ',"client_operation_id":' .. quote(s.operation_id) .. "}", "submit")
end
function on_load(ctx)
  local s = app(ctx)
  if TOKEN == "" then s.screen = "setup"; s.message = "请先填写 TOKEN" else fetch_dashboard(ctx) end
  ctx:invalidate()
end
on_net_done = function(ctx, result)
  task_id = nil; local s = app(ctx)
  if not result.ok then
    if result.err == "too_large" and retry_smaller_batch(ctx, s) then return end
    s.screen = "error"; s.message = request_error(result); ctx:invalidate(); return
  end
  begin_parse(ctx)
  local envelope = decode(result.body or "")
  if type(envelope) ~= "table" then
    if retry_smaller_batch(ctx, s) then return end
    s.screen = "error"; s.message = parse_failure(result); ctx:invalidate(); return
  end
  if envelope.ok == false then s.screen = "error"; s.message = request_error(result); ctx:invalidate(); return end
  local data = envelope.data or envelope
  if s.request_kind == "dashboard" then
    read_counts(s, data)
    s.screen = "home"; s.message = ""
  elseif s.request_kind == "next" then load_queue(s, data)
  else
    local status = normalize_status(data.status) or normalize_status(s.pending_status)
    s.session_reviewed = (s.session_reviewed or 0) + 1
    s.session_grades = s.session_grades or { again = 0, hard = 0, good = 0, easy = 0 }
    if status then s.session_grades[status] = (s.session_grades[status] or 0) + 1 end
    s.reviewed_today_count = (tonumber(s.reviewed_today_count) or 0) + 1
    s.pending_status = nil; s.operation_id = nil; s.message = data.idempotent_replay == true and "已同步" or "已提交"; advance_queue(s)
  end
  ctx:invalidate()
end
function on_leave(ctx) if task_id then task_id:cancel(); task_id = nil end end
local function grade_layout(ctx)
  local margin, gap, height = 32, 8, 48
  local width = math.floor((ctx.screen.width - margin * 2 - gap * 3) / 4)
  return ctx.screen.height - height - 24, width, gap, height, margin
end
function on_input(ctx, ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s = app(ctx)
  if ev.gesture == "swipe_up" or ev.gesture == "swipe_down" then
    local direction = ev.gesture == "swipe_up" and 4 or -4
    s.content_offset = math.max(0, (s.content_offset or 0) + direction); ctx:invalidate(); return true
  end
  if ev.gesture ~= "tap" then return false end
  if s.screen == "setup" then return false end
  if s.screen == "loading" then return true end
  if s.screen == "error" then
    if s.pending_status then submit(ctx, s.pending_status)
    elseif s.request_kind == "dashboard" then fetch_dashboard(ctx)
    else s.batch_count = BATCH; fetch_next(ctx) end
    return true
  end
  if s.screen == "home" then
    if ev.y >= 84 and ev.y <= 320 or ev.y >= ctx.screen.height - 128 then
      if can_review(s) then begin_session(s); s.batch_count = BATCH; fetch_next(ctx) else fetch_dashboard(ctx) end
    end
    return true
  end
  if s.screen == "empty" then
    if ev.y >= ctx.screen.height - 128 then fetch_dashboard(ctx) end
    return true
  end
  if s.screen == "done" then
    local remaining = tonumber(s.remaining) or 0
    if remaining > 0 and ev.y >= ctx.screen.height - 128 then begin_session(s); s.batch_count = BATCH; fetch_next(ctx)
    elseif remaining > 0 and ev.y >= ctx.screen.height - 188 then fetch_dashboard(ctx)
    elseif ev.y >= ctx.screen.height - 128 then fetch_dashboard(ctx) end
    return true
  end
  if s.screen == "card" and ev.x >= ctx.screen.width - 112 and ev.y <= 64 then
    fetch_dashboard(ctx)
    return true
  end
  local button_y, bw, gap, button_h, m = grade_layout(ctx)
  if s.revealed and ev.y >= button_y - 32 and ev.y <= button_y + button_h then
    local index = math.floor((ev.x - m) / (bw + gap)) + 1
    local grades = { "again", "hard", "good", "easy" }
    if index >= 1 and index <= 4 and ev.x <= m + (index - 1) * (bw + gap) + bw then submit(ctx, grades[index]); return true end
  end
  if ev.y >= 76 and ev.y < button_y then
    s.revealed = not s.revealed
    s.content_offset = 0
    ctx:invalidate()
    return true
  end
  return true
end
local function wrapped_lines(text, width)
  local line, lines = "", {}
  local function emit(value) if value ~= "" then lines[#lines + 1] = value end end
  for paragraph in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    local count = 0
    for char in paragraph:gmatch("[\1-\127\194-\244][\128-\191]*") do
      if count >= width then emit(line); line, count = "", 0 end
      line, count = line .. char, count + 1
    end
    emit(line)
    line, count = "", 0
  end
  return lines
end
local function draw_lines(g, lines, x, y, start, max_lines, line_height, color)
  local last = math.min(#lines, start + max_lines - 1)
  for index = start, last do g:text(x, y + (index - start) * line_height, lines[index], { color = color }) end
end
local function plain_text(value)
  local text = tostring(value or "")
  text = text:gsub("<[^>]->", ""):gsub("%*%*", ""):gsub("__", "")
  return text
end
local function utf8_count(text)
  local count = 0
  for _ in tostring(text or ""):gmatch("[\1-\127\194-\244][\128-\191]*") do count = count + 1 end
  return count
end
local function text_pixel_width(text)
  local width = 0
  for char in tostring(text or ""):gmatch("[\1-\127\194-\244][\128-\191]*") do
    width = width + (#char == 1 and 10 or 20)
  end
  return width
end
local function centered_text(g, center, y, text, color)
  g:text(center - math.floor(text_pixel_width(text) / 2), y, text, { color = color })
end
local WHITE, BLACK = 0, 15
local function rounded_fill(g, x, y, width, height, radius, color)
  local r = math.max(1, math.min(radius, math.floor(width / 2), math.floor(height / 2)))
  g:rect(x + r, y, width - r * 2, height,{fill=true,color=color})
  g:rect(x, y + r, width, height - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + width - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + height - 1 - r, r,{fill=true,color=color})
  g:circle(x + width - 1 - r, y + height - 1 - r, r,{fill=true,color=color})
end
local function rounded_stroke(g, x, y, width, height, radius, thickness, color, background)
  local t = math.max(1, math.min(thickness, math.floor((width - 1) / 2), math.floor((height - 1) / 2)))
  rounded_fill(g, x, y, width, height, radius, color)
  rounded_fill(g, x + t, y + t, width - t * 2, height - t * 2, math.max(1, radius - t), background)
end
local SEGMENTS = { ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg", ["4"] = "bcfg", ["5"] = "acdfg", ["6"] = "acdefg", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg" }
local function has_segment(s, key) return s and s:find(key, 1, true) ~= nil end
local function draw_digit(g, x, y, ch, color, dw, dh, t)
  local s = SEGMENTS[ch]
  if not s then return dw end
  local mid = math.floor(dh / 2)
  if has_segment(s, "a") then g:rect(x + t, y, dw - t * 2, t,{fill=true,color=color}) end
  if has_segment(s, "b") then g:rect(x + dw - t, y + t, t, mid - t,{fill=true,color=color}) end
  if has_segment(s, "c") then g:rect(x + dw - t, y + mid, t, mid - t,{fill=true,color=color}) end
  if has_segment(s, "d") then g:rect(x + t, y + dh - t, dw - t * 2, t,{fill=true,color=color}) end
  if has_segment(s, "e") then g:rect(x, y + mid, t, mid - t,{fill=true,color=color}) end
  if has_segment(s, "f") then g:rect(x, y + t, t, mid - t,{fill=true,color=color}) end
  if has_segment(s, "g") then g:rect(x + t, y + mid - math.floor(t / 2), dw - t * 2, t,{fill=true,color=color}) end
  return dw
end
local function draw_count(g, cx, y, value, color, dw, dh, t, gap)
  local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
  local width = #text * dw + math.max(0, #text - 1) * gap
  local x = cx - math.floor(width / 2)
  for i = 1, #text do
    draw_digit(g, x, y, text:sub(i, i), color, dw, dh, t)
    x = x + dw + gap
  end
  return width
end
local function progress_bar(g, x, y, width, height, ratio, color)
  g:rect(x, y, width, height,{color=color})
  local inner = math.max(0, math.min(width - 4, math.floor((width - 4) * math.max(0, math.min(1, ratio)))))
  if inner > 0 then g:rect(x + 2, y + 2, inner, height - 4,{fill=true,color=color}) end
end
local function chrome(g, w, title, meta, hide_rule)
  g:text(32, 32, title, { color = BLACK })
  if meta and meta ~= "" then g:text(w - 32 - text_pixel_width(meta), 32, meta, { color = BLACK }) end
  if not hide_rule then g:line(32, 62, w - 32, 62,{color=BLACK}) end
end
local function primary_button(g, w, h, label)
  rounded_fill(g, 32, h - 104, w - 64, 64, 14, BLACK)
  centered_text(g, math.floor(w / 2), h - 83, label, WHITE)
end
local function secondary_button(g, w, h, label)
  rounded_stroke(g, 32, h - 188, w - 64, 52, 12, 2, BLACK, WHITE)
  centered_text(g, math.floor(w / 2), h - 172, label, BLACK)
end
local function stat_tile(g, x, y, width, height, label, value)
  rounded_stroke(g, x, y, width, height, 12, 2, BLACK, WHITE)
  centered_text(g, x + math.floor(width / 2), y + 18, label, BLACK)
  centered_text(g, x + math.floor(width / 2), y + 56, tostring(value), BLACK)
end
local function status_copy(g, w, y, title, lines)
  centered_text(g, math.floor(w / 2), y, title, BLACK)
  for index, line in ipairs(lines or {}) do
    centered_text(g, math.floor(w / 2), y + 36 + (index - 1) * 32, line, BLACK)
  end
end
local function review_text(value, revealed)
  local text = tostring(value or "")
  text = text:gsub("<br%s*/>", "\n"):gsub("<br%s*>", "\n"):gsub("</p>", "\n"):gsub("<li[^>]*>", "\n"):gsub("</li>", "")
  local function mask(segment) return revealed and segment or string.rep("█", math.max(1, utf8_count(plain_text(segment)))) end
  if text:find("<mark[^>]*>") then
    text = text:gsub("<mark[^>]*>(.-)</mark>", mask)
  else
    text = text:gsub("<strong[^>]*>(.-)</strong>", mask):gsub("<b[^>]*>(.-)</b>", mask):gsub("%*%*(.-)%*%*", mask)
  end
  return plain_text(text):gsub("&nbsp;", " "):gsub("&lt;", "<"):gsub("&gt;", ">")
end
local UNDERLINE_START, UNDERLINE_END = "\1", "\2"
local function review_underlined_text(value)
  local text = tostring(value or "")
  text = text:gsub("<br%s*/>", "\n"):gsub("<br%s*>", "\n"):gsub("</p>", "\n"):gsub("<li[^>]*>", "\n"):gsub("</li>", "")
  local function underline(segment) return UNDERLINE_START .. plain_text(segment) .. UNDERLINE_END end
  if text:find("<mark[^>]*>") then
    text = text:gsub("<mark[^>]*>(.-)</mark>", underline)
  else
    text = text:gsub("<strong[^>]*>(.-)</strong>", underline):gsub("<b[^>]*>(.-)</b>", underline):gsub("%*%*(.-)%*%*", underline)
  end
  return plain_text(text):gsub("&nbsp;", " "):gsub("&lt;", "<"):gsub("&gt;", ">")
end
local function wrapped_annotated_lines(text, width)
  local lines, annotations = {}, {}
  local line, count, pixels, spans = "", 0, 0, {}
  local active, underline_x = false, 0
  local function close_span()
    if active and pixels > underline_x then spans[#spans + 1] = { x = underline_x, width = pixels - underline_x } end
  end
  local function emit()
    close_span()
    if line ~= "" then lines[#lines + 1], annotations[#annotations + 1] = line, spans end
    line, count, pixels, spans = "", 0, 0, {}
    if active then underline_x = 0 end
  end
  for char in (tostring(text or "") .. "\n"):gmatch("[\1-\127\194-\244][\128-\191]*") do
    if char == UNDERLINE_START then active, underline_x = true, pixels
    elseif char == UNDERLINE_END then close_span(); active = false
    elseif char == "\n" then emit()
    else
      if count >= width then emit() end
      line, count = line .. char, count + 1
      pixels = pixels + (#char == 1 and 10 or 20)
    end
  end
  return lines, annotations
end
local function interval(s, name)
  local aliases = { again = { "again", "fsrs_again", "forgotten" }, hard = { "hard", "fsrs_hard", "fuzzy" }, good = { "good", "fsrs_good" }, easy = { "easy", "fsrs_easy", "remembered" } }
  for _, key in ipairs(aliases[name]) do
    local entry = s.preview_memory and s.preview_memory[key]
    if entry and entry.interval_label then return tostring(entry.interval_label) end
  end
  return "—"
end
local function interval_text(s, name)
  local value = interval(s, name):gsub("^%+", "")
  local amount, unit = value:match("^([%d%.]+)%s*([%a]+)$")
  local units = { m = "分钟", h = "小时", d = "天", w = "周", mo = "月", y = "年" }
  if amount and units[unit] then return "+" .. amount .. units[unit] end
  return value == "—" and value or "+" .. value
end
function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s = app(ctx); local w, h = ctx.screen.width, ctx.screen.height; local m = 32
  g:clear(WHITE)
  if s.screen == "card" then
    local total = #(s.queue or {})
    local progress = total > 0 and (tostring(s.queue_index or 1) .. "/" .. tostring(total)) or ""
    chrome(g, w, "复习", "", true)
    if progress ~= "" then g:text(w - 88 - text_pixel_width(progress), 32, progress, { color = BLACK }) end
    PkgImage.draw(g, "nav_back", w - 56, 28)
    if total > 0 then
      local bar_w = w - m * 2
      local fill = math.max(4, math.floor(bar_w * (s.queue_index or 1) / total))
      g:rect(m, 64, fill, 3,{fill=true,color=BLACK})
    end
  elseif s.screen == "home" then chrome(g, w, "MindNotes", "今日")
  elseif s.screen == "done" then chrome(g, w, "MindNotes", "本轮")
  elseif s.screen == "empty" then chrome(g, w, "MindNotes", "今日")
  elseif s.screen == "setup" then chrome(g, w, "MindNotes", "安装")
  elseif s.screen == "loading" then chrome(g, w, "MindNotes", "连接中")
  elseif s.screen == "error" then chrome(g, w, "MindNotes", "出错")
  else chrome(g, w, "MindNotes", "") end
  if s.screen == "setup" then
    PkgImage.draw(g, "home_review", math.floor((w - 104) / 2), 118)
    status_copy(g, w, 248, "需要 Skill Token", { "安装时填写专用 Token", "保存后重新打开即可" })
    return
  end
  if s.screen == "loading" then
    rounded_stroke(g, m, math.floor(h / 2) - 56, w - m * 2, 112, 14, 2, BLACK, WHITE)
    centered_text(g, math.floor(w / 2), math.floor(h / 2) - 18, s.message ~= "" and s.message or "正在连接…", BLACK)
    centered_text(g, math.floor(w / 2), math.floor(h / 2) + 18, "请稍候", BLACK)
    return
  end
  if s.screen == "home" then
    local due = tonumber(s.due_count) or 0
    local overdue = tonumber(s.overdue_count) or 0
    local fresh = tonumber(s.new_count) or 0
    local reviewed = tonumber(s.reviewed_today_count) or 0
    local today = reviewed + due
    rounded_fill(g, m, 84, w - m * 2, 236, 16, BLACK)
    g:text(m + 24, 104, "待复习", { color = WHITE })
    draw_count(g, math.floor(w / 2), 148, due, WHITE, 44, 80, 6, 10)
    centered_text(g, math.floor(w / 2), 238, due > 0 and "张到期卡片" or "今天没有到期卡片", WHITE)
    progress_bar(g, m + 24, 278, w - m * 2 - 48, 10, today > 0 and (reviewed / today) or 0, WHITE)
    local gap, tile_w, tile_h, tile_y = 12, math.floor((w - m * 2 - 24) / 3), 100, 348
    stat_tile(g, m, tile_y, tile_w, tile_h, "逾期", overdue .. " 张")
    stat_tile(g, m + tile_w + gap, tile_y, tile_w, tile_h, "新卡", fresh .. " 张")
    stat_tile(g, m + (tile_w + gap) * 2, tile_y, tile_w, tile_h, "已复习", reviewed .. " 张")
    rounded_stroke(g, m, 468, w - m * 2, 52, 12, 2, BLACK, WHITE)
    g:text(m + 20, 484, "全部笔记", { color = BLACK })
    local batch_label = "每轮最多 " .. tostring(BATCH) .. " 张"
    g:text(w - m - 20 - text_pixel_width(batch_label), 484, batch_label, { color = BLACK })
    centered_text(g, math.floor(w / 2), h - 128, can_review(s) and "点按开始这一轮" or "没有待复习时可以刷新", BLACK)
    primary_button(g, w, h, can_review(s) and "开始复习" or "刷新")
    return
  end
  if s.screen == "empty" then
    PkgImage.draw(g, "result_complete", math.floor((w - 80) / 2), 120)
    status_copy(g, w, 228, "今日没有待复习", { "新卡 " .. tostring(s.new_count or 0) .. " 张", "可以稍后再来，或返回首页刷新" })
    primary_button(g, w, h, "返回首页")
    return
  end
  if s.screen == "done" then
    local grades = s.session_grades or { again = 0, hard = 0, good = 0, easy = 0 }
    local remaining = tonumber(s.remaining) or 0
    local reviewed = tonumber(s.session_reviewed) or 0
    PkgImage.draw(g, "result_complete", math.floor((w - 80) / 2), 88)
    status_copy(g, w, 188, "本轮完成", { "复习 " .. tostring(reviewed) .. " 张", remaining > 0 and ("还剩 " .. tostring(remaining) .. " 张") or "这批已经全部评完" })
    local gap, tile_w, tile_h, tile_y = 12, math.floor((w - m * 2 - 12) / 2), 88, remaining > 0 and 300 or 288
    stat_tile(g, m, tile_y, tile_w, tile_h, "忘了", grades.again or 0)
    stat_tile(g, m + tile_w + gap, tile_y, tile_w, tile_h, "困难", grades.hard or 0)
    stat_tile(g, m, tile_y + tile_h + gap, tile_w, tile_h, "记得", grades.good or 0)
    stat_tile(g, m + tile_w + gap, tile_y + tile_h + gap, tile_w, tile_h, "轻松", grades.easy or 0)
    if remaining > 0 then secondary_button(g, w, h, "返回首页") end
    primary_button(g, w, h, remaining > 0 and "继续复习" or "返回首页")
    return
  end
  if s.screen == "error" then
    rounded_stroke(g, m, 96, w - m * 2, 280, 14, 2, BLACK, WHITE)
    g:text(m + 20, 118, "请求未完成", { color = BLACK })
    draw_lines(g, wrapped_lines(s.message, math.floor((w - m * 2 - 40) / 20)), m + 20, 162, 1, 6, 28, BLACK)
    primary_button(g, w, h, "重试")
    return
  end
  local button_y, button_width, button_gap, button_height = grade_layout(ctx)
  local card_y = 86
  local stats_y = h - 48
  -- The device font's CJK glyphs are wider than Latin characters. Reserve a
  -- 20-pixel cell so mixed Chinese/English cards never cross the card edge.
  local text_x, text_width = m, math.floor((w - m * 2) / 20)
  local title_lines = wrapped_lines(plain_text(s.title), text_width)
  local title_count = math.min(2, #title_lines)
  draw_lines(g, title_lines, text_x, card_y, 1, 2, 28, BLACK)
  local content_y = card_y + 10 + math.max(1, title_count) * 28
  local content_limit = s.revealed and button_y - 44 or stats_y - 48
  local content_count = math.max(1, math.floor((content_limit - content_y) / 28))
  local content_lines, underlines
  if s.revealed then content_lines, underlines = wrapped_annotated_lines(review_underlined_text(s.content), text_width)
  else content_lines, underlines = wrapped_lines(review_text(s.content, false), text_width), {} end
  local max_offset = math.max(0, #content_lines - content_count)
  s.content_offset = math.max(0, math.min(max_offset, s.content_offset or 0))
  draw_lines(g, content_lines, text_x, content_y, s.content_offset + 1, content_count, 28, BLACK)
  if s.revealed then
    local first, last = s.content_offset + 1, math.min(#content_lines, s.content_offset + content_count)
    for index = first, last do
      for _, span in ipairs(underlines[index] or {}) do
        local y = content_y + (index - first) * 28 + 22
        g:line(text_x + span.x, y, text_x + span.x + span.width, y,{color=BLACK})
      end
    end
  end
  if max_offset > 0 then
    local rail_x = w - 18
    local rail_h = math.max(28, content_count * 28 - 8)
    local thumb_h = math.max(18, math.floor(rail_h * content_count / #content_lines))
    local thumb_y = content_y + math.floor((rail_h - thumb_h) * s.content_offset / max_offset)
    g:line(rail_x, content_y, rail_x, content_y + rail_h,{color=BLACK})
    g:rect(rail_x - 2, thumb_y, 5, thumb_h,{fill=true,color=BLACK})
  end
  if not s.revealed then
    centered_text(g, math.floor(w / 2), stats_y - 36, "点按查看原文", BLACK)
    local reviews = tonumber(s.memory and s.memory.review_count or 0) or 0
    g:text(m, stats_y, reviews == 0 and "新卡" or ("复习 " .. tostring(reviews) .. " 次"), { color = BLACK })
    g:text(math.floor(w * 0.46), stats_y, string.format("D %.1f  S %.0f  R %.0f%%", tonumber(s.fsrs and s.fsrs.d or 0) or 0, tonumber(s.fsrs and s.fsrs.s or 0) or 0, (tonumber(s.fsrs and s.fsrs.r or 0) or 0) * 100), { color = BLACK })
    return
  end
  local labels, keys = { "忘了", "困难", "记得", "轻松" }, { "again", "hard", "good", "easy" }
  local icons = { "grade_again", "grade_hard", "grade_good_inverse", "grade_easy_inverse" }
  for i = 1, 4 do
    local x = m + (i - 1) * (button_width + button_gap)
    local center = x + math.floor(button_width / 2)
    centered_text(g, center, button_y - 28, interval_text(s, keys[i]), BLACK)
    rounded_fill(g, x, button_y, button_width, button_height, 10, BLACK)
    if i <= 2 then rounded_fill(g, x + 2, button_y + 2, button_width - 4, button_height - 4, 8, WHITE) end
    PkgImage.draw(g, icons[i], x + 10, button_y + 12, { color = i <= 2 and 15 or 0 })
    g:text(x + 42, button_y + 14, labels[i], { color = i <= 2 and 15 or 0 })
  end
end
