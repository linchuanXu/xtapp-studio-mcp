-- 墨闻：真实新闻头条阅读器。
-- 联网路由：Lua 只发固定 HTTP GET；服务器负责阿里云 HTTPS POST 与鉴权。
local BLACK, WHITE = 15, 0
local API = "http://193.112.174.92:28473/demo/news/feed/xtapp?category="
local PROTOCOL = "XTAPP_NEWS_V1"
local PAGE_LIMIT = 500
local ROWS_PER_SCREEN = 8
local LIST_TOP = 182
local ROW_HEIGHT = 68
local request_id = nil
local on_net_done

local CATEGORIES = {
  { key = "all", label = "综合" },
  { key = "domestic", label = "国内" },
  { key = "world", label = "国际" },
  { key = "finance", label = "财经" },
  { key = "technology", label = "科技" },
}

local function app_state(ctx)
  ctx.state.ink_news_live = ctx.state.ink_news_live or {
    category = 1,
    page = 1,
    total_pages = 1,
    total_count = 0,
    selected = 1,
    items = nil,
    status = "idle",
    detail = false,
  }
  local state = ctx.state.ink_news_live
  if type(state.category) ~= "number" or state.category < 1 or state.category > #CATEGORIES then state.category = 1 end
  if type(state.page) ~= "number" or state.page < 1 then state.page = 1 end
  if type(state.selected) ~= "number" or state.selected < 1 then state.selected = 1 end
  return state
end

local function glyphs(text)
  local result = {}
  for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do result[#result + 1] = char end
  return result
end

local function glyph_width(char)
  return #char == 1 and 10 or 20
end

local function text_width(text)
  local total = 0
  for _, char in ipairs(glyphs(text)) do total = total + glyph_width(char) end
  return total
end

local function right_text(g, right, y, text, color)
  g:text(right - text_width(text), y, text, { color = color or BLACK })
end

local function center_text(g, x, y, width, text, color)
  g:text(x + math.max(0, math.floor((width - text_width(text)) / 2)), y, text, { color = color or BLACK })
end

local function truncate(text, max_width)
  local chars, line, width = glyphs(text), "", 0
  for index, char in ipairs(chars) do
    local next_width = width + glyph_width(char)
    if next_width > max_width - 30 and index < #chars then return line .. "..." end
    if next_width > max_width then return line end
    line, width = line .. char, next_width
  end
  return line
end

local function wrap(text, max_width, max_lines)
  local rows, line, width = {}, "", 0
  local chars = glyphs(text)
  for index, char in ipairs(chars) do
    local char_width = glyph_width(char)
    if width + char_width > max_width and line ~= "" then
      rows[#rows + 1] = line
      line, width = "", 0
      if #rows == max_lines then
        local last, last_width = "", 0
        for _, last_char in ipairs(glyphs(rows[#rows])) do
          local next_width = last_width + glyph_width(last_char)
          if next_width > max_width - 30 then break end
          last, last_width = last .. last_char, next_width
        end
        rows[#rows] = last .. "..."
        return rows
      end
    end
    line, width = line .. char, width + char_width
    if index == #chars and line ~= "" then rows[#rows + 1] = line end
  end
  if #rows == 0 then rows[1] = "--" end
  return rows
end

local function wrap_with_widths(text, widths)
  local rows, line, width, line_index = {}, "", 0, 1
  for _, char in ipairs(glyphs(text)) do
    local char_width = glyph_width(char)
    local limit = widths[line_index] or widths[#widths]
    if width + char_width > limit and line ~= "" then
      if line_index == #widths then
        local fitted, fitted_width = "", 0
        for _, fitted_char in ipairs(glyphs(line)) do
          local next_width = fitted_width + glyph_width(fitted_char)
          if next_width > limit - 30 then break end
          fitted, fitted_width = fitted .. fitted_char, next_width
        end
        rows[#rows + 1] = fitted .. "..."
        return rows
      end
      rows[#rows + 1] = line
      line, width, line_index = "", 0, line_index + 1
    end
    line, width = line .. char, width + char_width
  end
  if line ~= "" then rows[#rows + 1] = line end
  if #rows == 0 then rows[1] = "--" end
  return rows
end

local function parse(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= PROTOCOL then return nil, "协议不匹配" end
  if body:find("\nstatus\terror\n", 1, true) then return nil, "新闻服务暂不可用" end
  local meta, items = {}, {}
  for line in body:gmatch("[^\r\n]+") do
    local id, channel, source, pub_date, have_pic, title, link = line:match(
      "^item\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$"
    )
    if title and title ~= "" then
      items[#items + 1] = {
        id = id,
        channel = channel,
        source = source,
        pub_date = pub_date,
        have_pic = have_pic == "1",
        title = title,
        link = link,
      }
    else
      local key, value = line:match("^([^\t]+)\t(.*)$")
      if key then meta[key] = value end
    end
  end
  if #items == 0 then return nil, "当前频道暂无头条" end
  return {
    items = items,
    page = tonumber(meta.page) or 1,
    total_pages = math.max(1, tonumber(meta.total_pages) or 1),
    total_count = math.max(#items, tonumber(meta.total_count) or #items),
    updated = meta.updated or "--",
  }
end

local function request_feed(ctx, requested_selection)
  local state = app_state(ctx)
  if request_id then state.status = "busy"; ctx:invalidate(); return false end
  if not ctx.net then state.status = "error"; state.error = "当前固件未提供 ScriptNet"; ctx:invalidate(); return false end
  local category = CATEGORIES[state.category]
  local url = API .. category.key .. "&page=" .. tostring(state.page)
  local id, err = ctx.net:request({ url = url }, on_net_done)
  if not id then state.status = "error"; state.error = tostring(err or "request_failed"); ctx:invalidate(); return false end
  request_id = id
  state.status = "loading"
  state.error = nil
  state.requested_selection = requested_selection
  ctx:invalidate()
  return true
end

local function switch_category(ctx, direction)
  local state = app_state(ctx)
  state.category = (state.category - 1 + direction) % #CATEGORIES + 1
  state.page, state.selected, state.items, state.detail = 1, 1, nil, false
  request_feed(ctx, 1)
end

local function change_page(ctx, direction, requested_selection)
  local state = app_state(ctx)
  local next_page = state.page + direction
  if next_page < 1 or next_page > math.min(PAGE_LIMIT, state.total_pages) then return false end
  state.page, state.items, state.detail = next_page, nil, false
  return request_feed(ctx, requested_selection)
end

local function refresh_feed(ctx)
  local state = app_state(ctx)
  state.page, state.selected, state.items, state.detail = 1, 1, nil, false
  return request_feed(ctx, 1)
end

local function change_selection(ctx, direction)
  local state = app_state(ctx)
  if not state.items or #state.items == 0 then return false end
  local next_selection = state.selected + direction
  if next_selection < 1 then return change_page(ctx, -1, "last") end
  if next_selection > #state.items then return change_page(ctx, 1, 1) end
  state.selected = next_selection
  ctx:invalidate()
  return true
end

local function dotted_rule(g, x, y, width)
  for offset = 0, width - 1, 8 do g:line(x + offset, y, math.min(x + width, x + offset + 3), y,{color=BLACK}) end
end

local function draw_header(g, state)
  g:rect(24, 20, 8, 40,{fill=true,color=BLACK})
  g:text(44, 28, "墨闻", { color = BLACK })
  right_text(g, 456, 28, state.status == "loading" and "更新中" or "手动刷新")
  dotted_rule(g, 24, 70, 432)
end

local function draw_categories(g, state)
  local x, y, width, gap = 24, 84, 82, 5
  for index, category in ipairs(CATEGORIES) do
    local left = x + (index - 1) * (width + gap)
    local active = index == state.category
    g:rect(left, y, width, 32,{fill=(active) and true or false,color=BLACK})
    center_text(g, left, y + 7, width, category.label, active and WHITE or BLACK)
  end
end

local function draw_list_footer(g)
  g:text(24, 756, "< 上一页", { color = BLACK })
  center_text(g, 174, 756, 132, "刷新", BLACK)
  right_text(g, 456, 756, "下一页 >")
end

local function draw_list(g, state)
  local label = CATEGORIES[state.category].label
  g:text(24, 142, label .. "头条", { color = BLACK })
  local updated_time = tostring(state.updated or "--"):match("(%d%d:%d%d)") or "--:--"
  right_text(g, 456, 142, tostring(state.total_count or 0) .. " 条  " .. updated_time .. " 更新")

  if not state.items then
    local message = state.status == "loading" and "正在收取最新头条" or "点击下方刷新获取头条"
    center_text(g, 24, 356, 432, message, BLACK)
    if state.error then center_text(g, 24, 390, 432, "获取失败，请再次点击刷新", BLACK) end
    draw_list_footer(g)
    return
  end

  local first = math.floor((state.selected - 1) / ROWS_PER_SCREEN) * ROWS_PER_SCREEN + 1
  for slot = 1, ROWS_PER_SCREEN do
    local index = first + slot - 1
    local item = state.items[index]
    if not item then break end
    local y = LIST_TOP + (slot - 1) * ROW_HEIGHT
    local active = index == state.selected
    if active then g:rect(24, y + 3, 4, 54,{fill=true,color=BLACK}) end
    center_text(g, 32, y + 7, 28, string.format("%02d", index), BLACK)
    local time = item.pub_date:match("(%d%d:%d%d)") or "--:--"
    local source = item.source ~= "" and item.source or item.channel
    local rows = wrap_with_widths(source .. "  " .. item.title, { 300, 372 })
    for line_index, row in ipairs(rows) do g:text(72, y + 7 + (line_index - 1) * 23, row, { color = BLACK }) end
    right_text(g, 456, y + 7, time)
    dotted_rule(g, 72, y + 60, 384)
  end

  draw_list_footer(g)
end

local function draw_detail(g, state)
  local item = state.items and state.items[state.selected]
  if not item then state.detail = false; draw_list(g, state); return end
  g:text(24, 94, "< 返回头条", { color = BLACK })
  right_text(g, 456, 94, string.format("%02d / %02d", state.selected, #state.items))
  dotted_rule(g, 24, 128, 432)

  local rows = wrap(item.title, 432, 8)
  local title_y = 172
  for index, row in ipairs(rows) do g:text(24, title_y + (index - 1) * 32, row, { color = BLACK }) end
  local meta_y = title_y + #rows * 32 + 28
  g:rect(24, meta_y, 56, 24,{fill=true,color=BLACK})
  center_text(g, 24, meta_y + 4, 56, "来源", WHITE)
  g:text(96, meta_y + 4, truncate(item.source ~= "" and item.source or "未知", 350), { color = BLACK })
  g:rect(24, meta_y + 44, 56, 24,{color=BLACK})
  center_text(g, 24, meta_y + 48, 56, "频道", BLACK)
  g:text(96, meta_y + 48, truncate(item.channel, 350), { color = BLACK })
  g:rect(24, meta_y + 88, 56, 24,{color=BLACK})
  center_text(g, 24, meta_y + 92, 56, "时间", BLACK)
  g:text(96, meta_y + 92, item.pub_date ~= "" and item.pub_date or "--", { color = BLACK })
  if item.have_pic then
    dotted_rule(g, 24, meta_y + 138, 432)
    g:rect(24, meta_y + 162, 12, 12,{fill=true,color=BLACK})
    g:text(52, meta_y + 158, "原始头条附有图片", { color = BLACK })
  end
  dotted_rule(g, 24, 706, 432)
  g:text(24, 738, "上 / 下切换", { color = BLACK })
  right_text(g, 456, 738, "BACK 返回")
end

function on_load(ctx)
  local state = app_state(ctx)
  state.detail = false
  request_feed(ctx, state.selected)
end

on_net_done = function(ctx, result)
  request_id = nil
  local state = app_state(ctx)
  if not result.ok then
    state.status, state.error = "error", tostring(result.err or result.status or "request_failed")
    ctx:invalidate()
    return
  end
  local parsed, parse_error = parse(result.body)
  if not parsed then
    state.status, state.error, state.items = "error", parse_error, nil
    ctx:invalidate()
    return
  end
  state.items = parsed.items
  state.page = parsed.page
  state.total_pages = parsed.total_pages
  state.total_count = parsed.total_count
  state.updated = parsed.updated
  state.selected = state.requested_selection == "last" and #parsed.items or math.max(1, math.min(tonumber(state.requested_selection) or 1, #parsed.items))
  state.requested_selection = nil
  state.status, state.error = "ready", nil
  ctx:invalidate()
end

function on_leave(ctx)
  if request_id and ctx.net then request_id:cancel() end
  request_id = nil
end

function on_input(ctx, ev)
  local state = app_state(ctx)
  if ev.type == "key" and ev.phase == "down" then
    if ev.key == "back" then
      if state.detail then state.detail = false; ctx:invalidate() else ctx:quit() end
      return true
    end
    if ev.key == "left" then switch_category(ctx, -1); return true end
    if ev.key == "right" then switch_category(ctx, 1); return true end
    if ev.key == "up" then return change_selection(ctx, -1) end
    if ev.key == "down" then return change_selection(ctx, 1) end
    if ev.key == "ok" and state.items then state.detail = not state.detail; ctx:invalidate(); return true end
    return false
  end

  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if state.detail then
      if ev.y <= 140 then state.detail = false; ctx:invalidate(); return true end
      if ev.y >= 700 then return change_selection(ctx, ev.x < 240 and -1 or 1) end
      return true
    end
    if ev.y >= 80 and ev.y <= 124 then
      local index = math.floor((ev.x - 24) / 87) + 1
      if CATEGORIES[index] then state.category = index; state.page, state.selected, state.items = 1, 1, nil; request_feed(ctx, 1); return true end
    end
    if ev.y >= LIST_TOP and ev.y < LIST_TOP + ROWS_PER_SCREEN * ROW_HEIGHT and state.items then
      local first = math.floor((state.selected - 1) / ROWS_PER_SCREEN) * ROWS_PER_SCREEN + 1
      local index = first + math.floor((ev.y - LIST_TOP) / ROW_HEIGHT)
      if state.items[index] then state.selected, state.detail = index, true; ctx:invalidate(); return true end
    end
    if ev.y >= 736 then
      if ev.x < 160 then return change_page(ctx, -1, 1) end
      if ev.x > 320 then return change_page(ctx, 1, 1) end
      refresh_feed(ctx)
      return true
    end
  end
  return false
end

function on_draw(ctx, g)
  local state = app_state(ctx)
  g:clear(WHITE)
  draw_header(g, state)
  if state.detail then draw_detail(g, state) else draw_categories(g, state); draw_list(g, state) end
end
