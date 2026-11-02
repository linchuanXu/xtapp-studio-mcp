-- 飞书日历：共用尺子。字宽、命中、设置页、周/月格子；日视图矩形由各主题 builder 出。
local Time = require("domain.calendar_time")
local Events = require("domain.calendar_events")

local M = {}

M.CONTENT_LEFT, M.CONTENT_WIDTH = 24, 432
M.CHROME_H, M.CONTENT_TOP, M.TAB_Y, M.TAB_H = 80, 80, 736, 64
M.ROW_H, M.RAIL_W, M.ALLDAY_H = 56, 3, 40
M.WEEK_BUSY_H, M.WEEK_EMPTY_H = 72, 42
M.MONTH_CELL_W, M.MONTH_CELL_H = 61, 56
M.MONTH_DOT_MAX, M.MONTH_DOT_R, M.MONTH_DOT_GAP = 5, 3, 7
M.PIN_H, M.GAP_H = 80, 28
M.AGENDA_HEAD_H = 36
M.ASCII_W, M.CJK_W = 10, 20
M.WEEKDAYS = { "一", "二", "三", "四", "五", "六", "日" }
local VIEW_IDS = { "day", "week", "month", "agenda" }

function M.view_id(s)
  return VIEW_IDS[s.view] or "month"
end

function M.hit(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y < top + height
end

function M.text_width(value)
  local width, index, text = 0, 1, tostring(value or "")
  while index <= #text do
    local byte = text:byte(index)
    if byte >= 0xE0 then width, index = width + M.CJK_W, index + 3
    elseif byte >= 0xC0 then width, index = width + M.CJK_W, index + 2
    else width, index = width + M.ASCII_W, index + 1 end
  end
  return width
end

function M.short(value, max_width)
  value = tostring(value or "")
  if M.text_width(value) <= max_width then return value end
  local out, width, index = {}, 0, 1
  local ellipsis = 30
  while index <= #value do
    local byte = value:byte(index)
    local step = (byte >= 0xE0 and 3) or (byte >= 0xC0 and 2) or 1
    local add = step == 1 and M.ASCII_W or M.CJK_W
    if width + add + ellipsis > max_width then break end
    out[#out + 1] = value:sub(index, index + step - 1)
    width = width + add
    index = index + step
  end
  return table.concat(out) .. "..."
end

function M.wrap_text(value, max_width, max_lines)
  local lines, current, width, index = {}, {}, 0, 1
  value = tostring(value or "")
  while index <= #value and #lines < max_lines do
    local byte = value:byte(index)
    local step = (byte >= 0xE0 and 3) or (byte >= 0xC0 and 2) or 1
    local add = step == 1 and M.ASCII_W or M.CJK_W
    if width + add > max_width and #current > 0 then
      lines[#lines + 1] = table.concat(current)
      current, width = {}, 0
    else
      current[#current + 1] = value:sub(index, index + step - 1)
      width = width + add
      index = index + step
    end
  end
  if #current > 0 and #lines < max_lines then
    lines[#lines + 1] = table.concat(current)
  end
  return lines
end

function M.is_today(s, year, month, day)
  return Time.same_day(year, month, day, s.ty, s.tm, s.td)
end

function M.viewing_today(s)
  return M.is_today(s, s.year, s.month, s.day)
end

function M.date_title(s)
  local id = M.view_id(s)
  if id == "day" then return string.format("%d月%d日 周%s", s.month, s.day, M.WEEKDAYS[Time.weekday_monday(s.year, s.month, s.day)]) end
  if id == "week" then
    local y, m, d = Time.monday_of(s.year, s.month, s.day)
    local ey, em, ed = Time.shift_date(y, m, d, 6)
    if m == em then return string.format("%d月%d–%d日", m, d, ed) end
    return string.format("%d/%d – %d/%d", m, d, em, ed)
  end
  if id == "agenda" then return string.format("%d月%d日起 30 天", s.month, s.day) end
  return string.format("%d年%d月", s.year, s.month)
end

function M.chrome_title(s)
  local theme = tostring(s.theme or "ink")
  local arrow, gap, band_left, band_right = 24, 8, 64, 304
  if theme == "inverse" then
    if M.view_id(s) == "day" then
      return M.short(string.format("%d.%d  周%s", s.month, s.day, M.WEEKDAYS[Time.weekday_monday(s.year, s.month, s.day)]), 220)
    end
    return M.short(M.date_title(s), 220)
  end
  if theme == "press" then
    return M.short(M.date_title(s), 260)
  end
  if theme == "pixel" then
    if M.view_id(s) == "day" then
      return M.short(string.format("%d/%d 周%s", s.month, s.day, M.WEEKDAYS[Time.weekday_monday(s.year, s.month, s.day)]), 180)
    end
    return M.short(M.date_title(s), 180)
  end
  return M.short(M.date_title(s), band_right - band_left - arrow * 2 - gap * 2)
end

function M.chrome_layout(s)
  local theme = tostring(s.theme or "ink")
  local title = M.chrome_title(s)
  local title_w = M.text_width(title)
  local arrow, gap = 24, 8
  local band_left, band_right = 64, 304
  if theme == "inverse" then band_left, band_right = 16, 300 end
  if theme == "press" then band_left, band_right = 24, 300 end
  if theme == "pixel" then band_left, band_right = 24, 300 end
  local group_w = title_w + arrow * 2 + gap * 2
  local start = band_left + math.max(0, math.floor((band_right - band_left - group_w) / 2))
  local has_sub = type(s.freshness) == "string" and s.freshness ~= ""
  local title_y, subtitle_y, today_y, icon_y, logo_y = 16, 42, 20, 28, 20
  if not has_sub then title_y = 28 end
  if theme == "inverse" then title_y, subtitle_y, today_y, icon_y, logo_y = 22, 72, 20, 20, 20 end
  if theme == "press" then title_y, subtitle_y, today_y, icon_y, logo_y = 54, 78, 52, 52, 14 end
  if theme == "pixel" then title_y, subtitle_y, today_y, icon_y, logo_y = 30, 48, 24, 28, 24 end
  return {
    title = title,
    prev_x = start,
    title_x = start + arrow + gap,
    next_x = start + arrow + gap + title_w + gap,
    title_y = title_y,
    subtitle = s.freshness or "",
    subtitle_x = start + arrow + gap,
    subtitle_y = subtitle_y,
    today_x = 312,
    today_y = today_y,
    today_w = 68,
    today_h = 40,
    icon_y = icon_y,
    logo_y = logo_y,
    settings_x = 388,
    refresh_x = 428,
    flag = theme == "press" and "飞书日报" or "",
  }
end

function M.month_grid_bottom(s)
  local rows = math.ceil((Time.weekday_monday(s.year, s.month, 1) - 1 + Time.days_in_month(s.year, s.month)) / 7)
  return M.CONTENT_TOP + 26 + rows * M.MONTH_CELL_H
end

function M.empty_top(s)
  if M.view_id(s) == "week" then return M.CONTENT_TOP + 16 end
  if M.view_id(s) == "month" then return M.month_grid_bottom(s) + 12 end
  return 200
end

function M.retry_top(s)
  local top = M.empty_top(s)
  if top + 232 > M.TAB_Y then return top + 40 end
  return top + 180
end

function M.page_size_for(available)
  return math.max(1, math.floor(available / (M.ROW_H + 8)))
end

function M.block_h(_minutes, has_location)
  return has_location and 72 or 56
end

function M.day_plan(s)
  return Events.day_plan(s.events, s.year, s.month, s.day, s.now)
end

function M.ink_rows(s)
  local plan = M.day_plan(s)
  local rows, prev_end = {}, nil
  for _, row in ipairs(plan.timed or {}) do
    local start_m, end_m = row.from, row.to
    if prev_end and start_m and start_m - prev_end >= 30 then
      rows[#rows + 1] = { kind = "gap", from = prev_end, to = start_m }
    end
    if not row.pinned then
      rows[#rows + 1] = row
    end
    if end_m then prev_end = math.max(prev_end or 0, end_m) end
  end
  return rows, plan
end

function M.ink_day_blocks(s)
  local rows, plan = M.ink_rows(s)
  local blocks, y = {}, M.CONTENT_TOP
  if plan.pin then
    if y + M.PIN_H > M.TAB_Y - 8 then return blocks end
    blocks[#blocks + 1] = {
      kind = "pin",
      pin_kind = plan.pin_kind,
      x = M.CONTENT_LEFT,
      y = y,
      w = M.CONTENT_WIDTH,
      h = M.PIN_H,
      item = plan.pin,
    }
    y = y + M.PIN_H + 8
  end
  for _, item in ipairs(plan.allday) do
    if y + M.ALLDAY_H > M.TAB_Y - 8 then return blocks end
    blocks[#blocks + 1] = {
      kind = "allday",
      x = M.CONTENT_LEFT,
      y = y,
      w = M.CONTENT_WIDTH,
      h = M.ALLDAY_H,
      item = item,
    }
    y = y + M.ALLDAY_H + 8
  end
  local offset = tonumber(s.offset) or 1
  if offset < 1 then offset = 1 end
  for index = offset, #rows do
    local row = rows[index]
    local h = M.GAP_H
    if row.kind == "timed" then
      local event = row.item.event
      h = M.block_h(Events.minutes_on_day(event, s.year, s.month, s.day), event.location ~= "")
    end
    if y + h > M.TAB_Y - 8 then break end
    blocks[#blocks + 1] = {
      kind = row.kind,
      x = row.kind == "gap" and M.CONTENT_LEFT or 92,
      y = y,
      w = row.kind == "gap" and M.CONTENT_WIDTH or (M.CONTENT_WIDTH - 68),
      h = h,
      item = row.item,
      from = row.from,
      to = row.to,
      past = row.past,
    }
    y = y + h + 8
  end
  return blocks
end

function M.day_blocks(s)
  local theme = tostring(s.theme or "ink")
  if theme ~= "ink" and theme ~= "" then
    return require("ui.calendar_views").day_blocks(s)
  end
  return M.ink_day_blocks(s)
end

function M.agenda_blocks(s)
  local groups, order = Events.agenda_groups(s)
  local blocks = {}
  local y, skipped, shown = M.CONTENT_TOP, 0, 0
  local page = M.page_size_for(M.TAB_Y - 8 - M.CONTENT_TOP)
  for _, key in ipairs(order) do
    local group = groups[key]
    local heading_drawn = false
    for _, item in ipairs(group.items) do
      if skipped + 1 < s.offset then
        skipped = skipped + 1
      else
        if not heading_drawn then
          if y + M.AGENDA_HEAD_H > M.TAB_Y - 8 then return blocks end
          local heading = string.format("%d月%d日 周%s", group.month, group.day, M.WEEKDAYS[Time.weekday_monday(group.year, group.month, group.day)])
          blocks[#blocks + 1] = {
            kind = "heading",
            x = M.CONTENT_LEFT,
            y = y,
            w = M.CONTENT_WIDTH,
            h = M.AGENDA_HEAD_H,
            text = heading,
          }
          y = y + 44
          heading_drawn = true
        end
        if y + M.ROW_H > M.TAB_Y - 8 or shown >= page then return blocks end
        blocks[#blocks + 1] = {
          kind = "row",
          x = M.CONTENT_LEFT,
          y = y,
          w = M.CONTENT_WIDTH,
          h = M.ROW_H,
          item = item,
        }
        y = y + M.ROW_H + 8
        shown = shown + 1
      end
    end
  end
  return blocks
end

function M.week_preview(s, year, month, day)
  local items = Events.events_on_day(s.events, year, month, day)
  local titles = {}
  for index = 1, math.min(2, #items) do
    titles[#titles + 1] = items[index].event.title
  end
  return { count = #items, titles = titles, extra = math.max(0, #items - 2) }
end

function M.week_row_h(count)
  return (tonumber(count) or 0) > 0 and M.WEEK_BUSY_H or M.WEEK_EMPTY_H
end

function M.week_rows(s)
  local y0, m0, d0 = Time.monday_of(s.year, s.month, s.day)
  local rows, y = {}, M.CONTENT_TOP
  for index = 0, 6 do
    local year, month, day = Time.shift_date(y0, m0, d0, index)
    local preview = M.week_preview(s, year, month, day)
    local h = M.week_row_h(preview.count)
    rows[#rows + 1] = {
      year = year,
      month = month,
      day = day,
      weekday = index + 1,
      x = M.CONTENT_LEFT,
      y = y,
      w = M.CONTENT_WIDTH,
      h = h - 4,
      count = preview.count,
      titles = preview.titles,
      extra = preview.extra,
    }
    y = y + h
  end
  return rows
end

function M.month_dots(count)
  count = tonumber(count) or 0
  if count <= 0 then return 0 end
  return math.min(count, M.MONTH_DOT_MAX)
end

function M.month_cells(s)
  local first_week = Time.weekday_monday(s.year, s.month, 1)
  local count = Time.days_in_month(s.year, s.month)
  local cells = {}
  for day = 1, count do
    local slot = first_week - 1 + day
    local col = (slot - 1) % 7
    local row = math.floor((slot - 1) / 7)
    cells[#cells + 1] = {
      day = day,
      count = Events.day_count(s.events, s.year, s.month, day),
      x = M.CONTENT_LEFT + col * M.MONTH_CELL_W,
      y = M.CONTENT_TOP + 26 + row * M.MONTH_CELL_H,
      w = M.MONTH_CELL_W,
      h = M.MONTH_CELL_H,
    }
  end
  return cells
end

function M.month_heading(s)
  local label = string.format("%d月%d日 周%s", s.month, s.day, M.WEEKDAYS[Time.weekday_monday(s.year, s.month, s.day)])
  return {
    x = M.CONTENT_LEFT,
    y = M.month_grid_bottom(s) + 8,
    w = M.CONTENT_WIDTH,
    h = 32,
    text = label,
  }
end

function M.month_detail_blocks(s)
  local heading = M.month_heading(s)
  local blocks = {
    { kind = "heading", x = heading.x, y = heading.y, w = heading.w, h = heading.h, text = heading.text },
  }
  local y = heading.y + heading.h + 4
  local items = Events.events_on_day(s.events, s.year, s.month, s.day)
  if #items == 0 then
    blocks[#blocks + 1] = {
      kind = "empty",
      x = M.CONTENT_LEFT,
      y = y,
      w = M.CONTENT_WIDTH,
      h = 28,
      text = "没有日程",
    }
    return blocks
  end
  for _, item in ipairs(items) do
    if y + M.ROW_H > M.TAB_Y - 8 then break end
    blocks[#blocks + 1] = {
      kind = "row",
      x = M.CONTENT_LEFT,
      y = y,
      w = M.CONTENT_WIDTH,
      h = M.ROW_H,
      item = item,
    }
    y = y + M.ROW_H + 6
  end
  return blocks
end

function M.visible_items(s)
  local id = M.view_id(s)
  if id == "week" or id == "month" or id == "day" then
    return Events.events_on_day(s.events, s.year, s.month, s.day)
  end
  local groups, order = Events.agenda_groups(s)
  local items = {}
  for _, key in ipairs(order) do
    for _, item in ipairs(groups[key].items) do items[#items + 1] = item end
  end
  return items
end

function M.card_page(s)
  local id = M.view_id(s)
  if id == "day" then
    return math.max(1, #(M.day_plan(s).timed or {}))
  end
  if id == "month" or id == "week" then
    return 1
  end
  return M.page_size_for(M.TAB_Y - 8 - M.CONTENT_TOP)
end

function M.first_visible_event(s)
  for _, block in ipairs(M.day_blocks(s)) do
    if block.item then return block.item.index end
  end
  local items = M.visible_items(s)
  if items[1] then return items[1].index end
  return nil
end

function M.settings_layout(_s)
  local themes = {
    { id = "ink", x = 24, y = 84, w = 208, h = 72 },
    { id = "pixel", x = 248, y = 84, w = 208, h = 72 },
    { id = "inverse", x = 24, y = 164, w = 208, h = 72 },
    { id = "press", x = 248, y = 164, w = 208, h = 72 },
  }
  return {
    back = { x = 24, y = 20, w = 64, h = 44 },
    themes = themes,
    auto = { x = 24, y = 252, w = 432, h = 112 },
    toggle = { x = 348, y = 288, w = 82, h = 38 },
    interval = { x = 24, y = 380, w = 432, h = 220 },
    minus = { x = 48, y = 436, w = 72, h = 64 },
    plus = { x = 360, y = 436, w = 72, h = 64 },
  }
end

function M.item_at(s, x, y)
  local id = M.view_id(s)
  if id == "month" then
    for _, block in ipairs(M.month_detail_blocks(s)) do
      if block.kind == "row" and block.item and M.hit(x, y, block.x, block.y, block.w, block.h) then
        return block.item.index
      end
    end
    return nil
  end
  if id == "agenda" then
    for _, block in ipairs(M.agenda_blocks(s)) do
      if block.kind == "row" and M.hit(x, y, block.x, block.y, block.w, block.h) then
        return block.item.index
      end
    end
    return nil
  end
  if id == "day" then
    for _, block in ipairs(M.day_blocks(s)) do
      if block.item and M.hit(x, y, block.x, block.y, block.w, block.h) then
        return block.item.index
      end
    end
    return nil
  end
  return nil
end

return M
