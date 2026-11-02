local PkgImage = require("pkg_image")
-- 飞书日历：四套版式。每套自己排 blocks，绘制和点击读同一份矩形。
local Time = require("domain.calendar_time")
local Events = require("domain.calendar_events")
local Layout = require("ui.calendar_layout")
local Theme = require("ui.calendar_theme")

local M = {}
M.checkpoint = function() end

local BLACK, WHITE = 15, 0
local CONTENT_LEFT, CONTENT_WIDTH = Layout.CONTENT_LEFT, Layout.CONTENT_WIDTH
local CONTENT_TOP, TAB_Y = Layout.CONTENT_TOP, Layout.TAB_Y
local RAIL_W = Layout.RAIL_W
local MONTH_CELL_W, MONTH_CELL_H = Layout.MONTH_CELL_W, Layout.MONTH_CELL_H
local WEEKDAYS = Layout.WEEKDAYS
local TAB_LABELS = {
  ink = { "日", "周", "月", "日程" },
  pixel = { "日", "周", "月", "日程" },
  inverse = { "日", "周", "月", "日程" },
  press = { "日", "周", "月", "日程" },
}

function M.chrome(s)
  return Layout.chrome_layout(s)
end

local function ink_of(s)
  return Theme.ink(s)
end

local function paper_of(s)
  return Theme.paper(s)
end

local function tick()
  M.checkpoint()
end

local function refresh_label(minutes)
  minutes = math.floor((tonumber(minutes) or 60) / 10) * 10
  if minutes < 10 then minutes = 10 end
  if minutes > 360 then minutes = 360 end
  if minutes % 60 == 0 then
    local hours = minutes / 60
    if hours == 1 then return "1 小时" end
    return tostring(hours) .. " 小时"
  end
  return tostring(minutes) .. " 分钟"
end

local function packed_timed(s)
  local plan = Layout.day_plan(s)
  local rows = {}
  for _, row in ipairs(plan.timed or {}) do
    if not row.pinned then rows[#rows + 1] = row end
  end
  return rows, plan
end

local function append_allday(blocks, plan, y, h, gap)
  h = h or Layout.ALLDAY_H
  gap = gap or 8
  for _, item in ipairs(plan.allday) do
    if y + h > TAB_Y - 8 then return blocks, y, true end
    blocks[#blocks + 1] = {
      kind = "allday",
      x = CONTENT_LEFT,
      y = y,
      w = CONTENT_WIDTH,
      h = h,
      item = item,
    }
    y = y + h + gap
  end
  return blocks, y, false
end

local function append_timed(blocks, s, rows, y, full, fixed_h, gap)
  local offset = tonumber(s.offset) or 1
  if offset < 1 then offset = 1 end
  gap = gap or 8
  for index = offset, #rows do
    local row = rows[index]
    local event = row.item.event
    local h = fixed_h or Layout.block_h(Events.minutes_on_day(event, s.year, s.month, s.day), event.location ~= "")
    if y + h > TAB_Y - 8 then break end
    blocks[#blocks + 1] = {
      kind = "timed",
      x = full and CONTENT_LEFT or 92,
      y = y,
      w = full and CONTENT_WIDTH or (CONTENT_WIDTH - 68),
      h = h,
      item = row.item,
      from = row.from,
      to = row.to,
      past = row.past,
    }
    y = y + h + gap
  end
  return blocks, y
end

local function number_rows(blocks)
  local n = 0
  for _, block in ipairs(blocks) do
    if block.kind == "allday" or block.kind == "timed" then
      n = n + 1
      block.seq = n
    end
  end
end

local function pixel_day_blocks(s)
  local rows, plan = packed_timed(s)
  local blocks, y = {}, CONTENT_TOP + 4
  if plan.pin then
    if y + 56 > TAB_Y - 8 then return blocks end
    blocks[#blocks + 1] = {
      kind = "pin",
      pin_kind = plan.pin_kind,
      x = CONTENT_LEFT,
      y = y,
      w = CONTENT_WIDTH,
      h = 56,
      item = plan.pin,
    }
    y = y + 60
  end
  local done
  blocks, y, done = append_allday(blocks, plan, y, 48, 2)
  if done then return blocks end
  return append_timed(blocks, s, rows, y, true, 52, 2)
end

local function inverse_day_blocks(s)
  local rows, plan = packed_timed(s)
  local blocks, y = {}, CONTENT_TOP + 8
  if plan.pin then
    if y + 56 > TAB_Y - 8 then return blocks end
    blocks[#blocks + 1] = {
      kind = "pin",
      pin_kind = plan.pin_kind,
      x = CONTENT_LEFT,
      y = y,
      w = CONTENT_WIDTH,
      h = 56,
      item = plan.pin,
    }
    y = y + 60
  end
  local done
  blocks, y, done = append_allday(blocks, plan, y, 56, 4)
  if done then return blocks end
  return append_timed(blocks, s, rows, y, true, 56, 4)
end

local function press_day_blocks(s)
  local rows, plan = packed_timed(s)
  local blocks, y = {}, CONTENT_TOP
  if plan.pin then
    if y + 100 > TAB_Y - 8 then return blocks end
    blocks[#blocks + 1] = {
      kind = "pin",
      pin_kind = plan.pin_kind,
      x = CONTENT_LEFT,
      y = y,
      w = CONTENT_WIDTH,
      h = 100,
      item = plan.pin,
    }
    y = y + 108
  end
  if y + 32 <= TAB_Y - 8 and (#plan.allday > 0 or #rows > 0) then
    blocks[#blocks + 1] = {
      kind = "heading",
      x = CONTENT_LEFT,
      y = y,
      w = CONTENT_WIDTH,
      h = 32,
      text = "今日目录",
    }
    y = y + 36
  end
  local done
  blocks, y, done = append_allday(blocks, plan, y, 40, 6)
  if done then
    number_rows(blocks)
    return blocks
  end
  blocks, y = append_timed(blocks, s, rows, y, true, 64, 6)
  number_rows(blocks)
  return blocks
end

function M.day_blocks(s)
  local theme = Theme.id(s)
  if theme == "pixel" then return pixel_day_blocks(s) end
  if theme == "inverse" then return inverse_day_blocks(s) end
  if theme == "press" then return press_day_blocks(s) end
  return Layout.ink_day_blocks(s)
end

function M.kinds(s)
  local kinds, has_gap = {}, false
  for _, block in ipairs(M.day_blocks(s)) do
    kinds[#kinds + 1] = block.kind
    if block.kind == "gap" then has_gap = true end
  end
  return kinds, has_gap
end

local function empty_message(s, fallback)
  if s.task then return "正在读取飞书日历" end
  if tostring(s.status):find("失败", 1, true) then return Layout.short(s.status, 400) end
  return fallback or "这一天没有日程"
end

local function empty_art(s, agenda)
  if s.task then return "empty_loading" end
  if agenda then return "empty_no_agenda" end
  return "empty_no_events"
end

local function draw_retry(g, s)
  local top = Layout.retry_top(s)
  local color = ink_of(s)
  local theme = Theme.id(s)
  if theme == "inverse" then
    g:text(math.floor((480 - Layout.text_width("重试")) / 2), top + 12, "重试", { color = color })
    g:rect(210, top + 38, 60, 1,{fill=true,color=color})
  elseif theme == "press" then
    g:text(math.floor((480 - Layout.text_width("重试")) / 2), top + 12, "重试", { color = color })
    g:rect(210, top + 38, 60, 1,{fill=true,color=color})
  elseif theme == "pixel" then
    g:rect(180, top, 120, 44,{fill=true,color=color})
    g:text(math.floor((480 - Layout.text_width("重试")) / 2), top + 12, "重试", { color = paper_of(s) })
  else
    Theme.frame(g, s, 180, top, 120, 44, 10)
    g:text(math.floor((480 - Layout.text_width("重试")) / 2), top + 12, "重试", { color = color })
  end
end

local function draw_empty(g, s, message, agenda)
  local top = Layout.empty_top(s)
  local label = message or empty_message(s)
  local color = ink_of(s)
  local theme = Theme.id(s)
  if theme ~= "ink" or top + 232 > TAB_Y then
    g:text(math.floor((480 - Layout.text_width(label)) / 2), top + 40, Layout.short(label, 400), { color = color })
    if theme == "inverse" then
      g:rect(80, top + 28, 80, 2,{fill=true,color=color})
      g:rect(320, top + 28, 80, 2,{fill=true,color=color})
    elseif theme == "press" then
      g:rect(120, top + 72, 240, 1,{fill=true,color=color})
    end
    if not s.task then draw_retry(g, s) end
    return
  end
  Theme.icon_plate(g, s, 140, top, 200)
  PkgImage.draw(g, empty_art(s, agenda), 140, top)
  g:text(math.floor((480 - Layout.text_width(label)) / 2), top + 148, Layout.short(label, 400), { color = color })
  if not s.task then draw_retry(g, s) end
end

function M.draw_header(g, s)
  local chrome = M.chrome(s)
  local color = ink_of(s)
  local theme = Theme.id(s)
  Theme.chrome_band(g, s)
  if theme == "press" then
    g:text(24, 14, chrome.flag, { color = color })
    g:rect(24, 42, 432, 2,{fill=true,color=color})
    g:rect(24, 46, 432, 1,{fill=true,color=color})
  elseif theme == "ink" then
    Theme.icon_plate(g, s, 16, chrome.logo_y, 48)
    PkgImage.draw(g, "logo_feishu", 16, chrome.logo_y)
  end
  local title_color = color
  if theme == "inverse" then
    g:text(chrome.prev_x, chrome.title_y + 2, "<", { color = color })
  else
    Theme.icon_plate(g, s, chrome.prev_x, chrome.title_y, 24)
    PkgImage.draw(g, "icon_nav_prev", chrome.prev_x, chrome.title_y)
  end
  g:text(chrome.title_x, chrome.title_y + 2, chrome.title, { color = title_color })
  if theme == "inverse" then
    g:text(chrome.next_x, chrome.title_y + 2, ">", { color = color })
  else
    Theme.icon_plate(g, s, chrome.next_x, chrome.title_y, 24)
    PkgImage.draw(g, "icon_nav_next", chrome.next_x, chrome.title_y)
  end
  if chrome.subtitle ~= "" and theme == "ink" then
    g:text(chrome.subtitle_x, chrome.subtitle_y, Layout.short(chrome.subtitle, 200), { color = color })
  end
  local today_label = "今天"
  local today_x = chrome.today_x + math.floor((chrome.today_w - Layout.text_width(today_label)) / 2)
  if theme == "inverse" then
    g:text(today_x, 26, today_label, { color = color })
    if Layout.viewing_today(s) then
      g:rect(today_x, 50, Layout.text_width(today_label), 2,{fill=true,color=color})
    end
  elseif theme == "pixel" then
    g:rect(chrome.today_x, chrome.today_y, chrome.today_w, chrome.today_h,{fill=true,color=color})
    g:text(today_x, chrome.today_y + 10, today_label, { color = paper_of(s) })
  elseif theme == "press" then
    g:text(today_x, chrome.today_y + 10, today_label, { color = color })
    if Layout.viewing_today(s) then
      g:rect(today_x, chrome.today_y + 34, Layout.text_width(today_label), 2,{fill=true,color=color})
    end
  else
    Theme.frame(g, s, chrome.today_x, chrome.today_y, chrome.today_w, chrome.today_h, 12)
    g:text(today_x, chrome.today_y + 10, today_label, { color = color })
  end
  if Layout.viewing_today(s) and theme ~= "inverse" and theme ~= "press" then
    g:rect(chrome.today_x + 16, chrome.today_y + chrome.today_h - 6, chrome.today_w - 32, 2,{fill=true,color=theme == "pixel" and paper_of(s) or color})
  end
  if theme == "inverse" then
    g:text(chrome.settings_x, chrome.icon_y + 2, "设", { color = color })
    g:text(chrome.refresh_x, chrome.icon_y + 2, "刷", { color = color })
  else
    Theme.icon_plate(g, s, chrome.settings_x, chrome.icon_y, 24)
    PkgImage.draw(g, "icon_settings", chrome.settings_x, chrome.icon_y)
    Theme.icon_plate(g, s, chrome.refresh_x, chrome.icon_y, 24)
    PkgImage.draw(g, "icon_refresh", chrome.refresh_x, chrome.icon_y)
  end
end

function M.draw_tabs(g, s)
  Theme.tab_rule(g, s)
  local labels = TAB_LABELS[Theme.id(s)] or TAB_LABELS.ink
  for index, label in ipairs(labels) do
    local x = CONTENT_LEFT + (index - 1) * 108
    local label_w = Layout.text_width(label)
    local label_x = x + math.floor((108 - label_w) / 2)
    Theme.tab(g, s, x, s.view == index, label, label_w, label_x)
  end
end

local function draw_toggle(g, s, x, y, on)
  local width, height = 82, 38
  local radius = math.floor(height / 2)
  if Theme.id(s) == "inverse" then
    Theme.frame(g, s, x, y, width, height, radius)
    local knob_x = on and (x + width - radius) or (x + radius)
    g:circle(knob_x, y + radius, 8,{fill=true,color=WHITE})
    return
  end
  if on then
    Theme.fill(g, s, x, y, width, height, BLACK, radius)
  else
    Theme.frame(g, s, x, y, width, height, radius)
  end
  local knob_x = on and (x + width - radius) or (x + radius)
  if Theme.id(s) == "pixel" then
    g:rect(knob_x - 10, y + 8, 20, 22,{fill=true,color=on and paper_of(s) or ink_of(s)})
  else
    g:circle(knob_x, y + radius, 13,{fill=true,color=on and paper_of(s) or ink_of(s)})
  end
end

function M.draw_settings(g, s)
  Theme.stage(g, s)
  Theme.chrome_band(g, s)
  local layout = Layout.settings_layout(s)
  local color = ink_of(s)
  local theme = Theme.id(s)
  local title = "外观 · " .. Theme.label(s)
  if theme == "inverse" then
    g:text(layout.back.x + 14, layout.back.y + 12, "返回", { color = color })
    g:rect(layout.back.x + 14, layout.back.y + 38, 40, 1,{fill=true,color=color})
    g:text(140, 28, title, { color = color })
  elseif theme == "press" then
    g:text(layout.back.x + 8, layout.back.y + 12, "返回", { color = color })
    g:rect(layout.back.x + 8, layout.back.y + 38, 40, 1,{fill=true,color=color})
    g:text(140, 28, title, { color = color })
  elseif theme == "pixel" then
    g:rect(layout.back.x, layout.back.y, layout.back.w, layout.back.h,{fill=true,color=color})
    g:text(layout.back.x + 14, layout.back.y + 12, "返回", { color = paper_of(s) })
    g:text(140, 28, title, { color = color })
  else
    Theme.frame(g, s, layout.back.x, layout.back.y, layout.back.w, layout.back.h, 10)
    g:text(layout.back.x + 14, layout.back.y + 12, "返回", { color = color })
    Theme.icon_plate(g, s, 104, 30, 24)
    PkgImage.draw(g, "icon_settings", 104, 30)
    g:text(140, 28, title, { color = color })
  end
  for _, chip in ipairs(layout.themes) do
    local _, _, label, hint = Theme.swatch(g, chip.id, chip.x, chip.y, chip.w, chip.h, s.theme == chip.id)
    local chip_ink = Theme.ink({ theme = chip.id })
    g:text(chip.x + 16, chip.y + 12, label, { color = chip_ink })
    g:text(chip.x + 16, chip.y + 40, hint, { color = chip_ink })
  end
  Theme.frame(g, s, layout.auto.x, layout.auto.y, layout.auto.w, layout.auto.h, 16)
  g:text(48, layout.auto.y + 16, "自动刷新", { color = color })
  g:text(48, layout.auto.y + 52, s.auto_refresh and ("已开启 · 每 " .. refresh_label(s.refresh_minutes)) or "已关闭，只在手动时请求", { color = color })
  draw_toggle(g, s, layout.toggle.x, layout.toggle.y, s.auto_refresh)
  Theme.frame(g, s, layout.interval.x, layout.interval.y, layout.interval.w, layout.interval.h, 16)
  g:text(48, layout.interval.y + 16, "刷新间隔", { color = color })
  Theme.frame(g, s, layout.minus.x, layout.minus.y, layout.minus.w, layout.minus.h, 14)
  g:text(layout.minus.x + 24, layout.minus.y + 20, "减", { color = color })
  local label = refresh_label(s.refresh_minutes)
  g:text(math.floor((480 - Layout.text_width(label)) / 2), layout.minus.y + 20, label, { color = color })
  Theme.frame(g, s, layout.plus.x, layout.plus.y, layout.plus.w, layout.plus.h, 14)
  g:text(layout.plus.x + 24, layout.plus.y + 20, "加", { color = color })
  g:text(48, layout.interval.y + 140, "最快 10 分钟，默认 1 小时", { color = color })
end

local function draw_section(g, s, x, y, h, text)
  local color = ink_of(s)
  local theme = Theme.id(s)
  if theme == "press" then
    g:text(x, y + 4, text, { color = color })
    g:rect(x, y + h - 3, Layout.text_width(text), 2,{fill=true,color=color})
  elseif theme == "inverse" then
    g:text(x, y + 6, Layout.short(text, CONTENT_WIDTH), { color = color })
    g:rect(x, y + h - 2, CONTENT_WIDTH, 2,{fill=true,color=color})
  elseif theme == "pixel" then
    g:rect(x, y, CONTENT_WIDTH, h,{fill=true,color=color})
    g:text(x + 12, y + 6, Layout.short(text, CONTENT_WIDTH - 24), { color = paper_of(s) })
  else
    g:text(x, y + 4, text, { color = color })
    g:line(x, y + h - 2, x + Layout.text_width(text), y + h - 2,{color=color})
  end
end

local function draw_row(g, s, x, y, width, item)
  local event = item.event
  local color = ink_of(s)
  local theme = Theme.id(s)
  local meta = Time.format_range(event)
  if event.location ~= "" then meta = meta .. "  " .. event.location end
  if theme == "press" then
    g:text(x, y + 6, Layout.short(event.title, width), { color = color })
    g:text(x, y + 32, Layout.short(meta, width), { color = color })
    g:rect(x, y + Layout.ROW_H - 2, width, 1,{fill=true,color=color})
  elseif theme == "inverse" then
    local stamp = event.start and not event.start.all_day and Time.hm(event.start) or "全天"
    g:text(x, y + 8, stamp, { color = color })
    g:text(x + 80, y + 8, Layout.short(event.title, width - 88), { color = color })
    g:text(x + 80, y + 32, Layout.short(meta, width - 88), { color = color })
    g:rect(x, y + Layout.ROW_H - 1, width, 1,{fill=true,color=color})
  elseif theme == "pixel" then
    g:text(x + 8, y + 8, Layout.short(event.title, width - 16), { color = color })
    g:text(x + 8, y + 32, Layout.short(meta, width - 16), { color = color })
    g:rect(x, y + Layout.ROW_H - 1, width, 1,{fill=true,color=color})
  else
    g:rect(x, y + 8, RAIL_W, Layout.ROW_H - 16,{fill=true,color=color})
    g:text(x + 16, y + 8, Layout.short(event.title, width - 24), { color = color })
    g:text(x + 16, y + 32, Layout.short(meta, width - 24), { color = color })
  end
end

local function draw_dots(g, s, count, right, cy, color)
  local dots = Layout.month_dots(count)
  if dots <= 0 then return end
  local gap = Layout.MONTH_DOT_GAP
  local cx = right - (dots - 1) * gap
  for i = 1, dots do
    Theme.dot(g, s, cx + (i - 1) * gap, cy, color)
  end
end

local function draw_end_mark(_g, _s, _last)
end

local function draw_day_ink(g, s, blocks)
  local color = ink_of(s)
  for _, block in ipairs(blocks) do
    if block.kind == "timed" or block.kind == "pin" then
      g:line(80, CONTENT_TOP, 80, TAB_Y - 12,{color=color})
      break
    end
  end
  for _, block in ipairs(blocks) do
    tick()
    if block.kind == "gap" then
      g:line(76, block.y + 14, 84, block.y + 14,{color=color})
      g:text(96, block.y + 6, Time.hm_minutes(block.from) .. " – " .. Time.hm_minutes(block.to) .. " 空", { color = color })
    elseif block.kind == "pin" then
      local event = block.item.event
      local badge = block.pin_kind == "now" and "进行中" or "下一场"
      local fg = Theme.solid(g, s, block.x, block.y, block.w, block.h, 12)
      PkgImage.draw(g, "icon_pin", block.x + 12, block.y + 12)
      g:text(block.x + 44, block.y + 10, badge, { color = fg })
      g:text(block.x + 16, block.y + 36, Layout.short(event.title, block.w - 32), { color = fg })
      local meta = Time.format_range(event)
      if event.location ~= "" then meta = meta .. "  " .. event.location end
      g:text(block.x + 16, block.y + 56, Layout.short(meta, block.w - 32), { color = fg })
    elseif block.kind == "allday" then
      Theme.frame(g, s, CONTENT_LEFT, block.y, CONTENT_WIDTH, block.h, 10)
      g:text(CONTENT_LEFT + 16, block.y + 10, Layout.short("全天  " .. block.item.event.title, CONTENT_WIDTH - 32), { color = color })
    else
      local event = block.item.event
      local title = block.past and ("已过 " .. event.title) or event.title
      g:text(CONTENT_LEFT, block.y + 12, Time.hm(event.start), { color = color })
      Theme.frame(g, s, block.x, block.y, block.w, block.h, 10)
      g:rect(block.x, block.y + 10, RAIL_W, block.h - 20,{fill=true,color=color})
      g:text(108, block.y + 12, Layout.short(title, CONTENT_WIDTH - 92), { color = color })
      if event.location ~= "" then
        g:text(108, block.y + 38, Layout.short(event.location, CONTENT_WIDTH - 92), { color = color })
      end
    end
  end
end

local function draw_day_pixel(g, s, blocks)
  local color = ink_of(s)
  for _, block in ipairs(blocks) do
    tick()
    local event = block.item and block.item.event
    if block.kind == "pin" then
      g:rect(block.x, block.y, block.w, block.h,{fill=true,color=color})
      local badge = block.pin_kind == "now" and "进行中" or "下一场"
      g:text(block.x + 16, block.y + 8, badge, { color = WHITE })
      g:text(block.x + 16, block.y + 30, Layout.short(event.title, block.w - 32), { color = WHITE })
    elseif block.kind == "allday" then
      g:text(block.x + 16, block.y + 14, Layout.short("全天  " .. event.title, 400), { color = color })
      g:rect(block.x, block.y + block.h - 1, block.w, 1,{fill=true,color=color})
    else
      local title = block.past and ("已过  " .. event.title) or event.title
      g:text(block.x + 16, block.y + 8, Layout.short(Time.hm(event.start) .. "  " .. title, 400), { color = color })
      if event.location ~= "" then
        g:text(block.x + 16, block.y + 30, Layout.short(event.location, 400), { color = color })
      end
      g:rect(block.x, block.y + block.h - 1, block.w, 1,{fill=true,color=color})
    end
  end
end

local function draw_day_inverse(g, s, blocks)
  local color = ink_of(s)
  for _, block in ipairs(blocks) do
    tick()
    local event = block.item and block.item.event
    if block.kind == "pin" then
      local stamp = event.start and not event.start.all_day and Time.hm(event.start) or "全天"
      local kicker = block.pin_kind == "now" and "现在" or "下一场"
      g:rect(block.x, block.y + 8, 3, block.h - 16,{fill=true,color=color})
      g:text(block.x + 16, block.y + 8, kicker .. "  " .. stamp, { color = color })
      g:text(block.x + 16, block.y + 32, Layout.short(event.title, 400), { color = color })
      g:rect(block.x, block.y + block.h - 1, block.w, 1,{fill=true,color=color})
    elseif block.kind == "allday" then
      g:text(36, block.y + math.floor((block.h - 20) / 2), "全天", { color = color })
      g:text(112, block.y + math.floor((block.h - 20) / 2), Layout.short(event.title, 328), { color = color })
      g:rect(block.x, block.y + block.h - 1, block.w, 1,{fill=true,color=color})
    else
      g:text(36, block.y + 8, Time.hm(event.start), { color = color })
      local title = block.past and ("已过  " .. event.title) or event.title
      g:text(112, block.y + 8, Layout.short(title, 328), { color = color })
      if event.location ~= "" then
        g:text(112, block.y + 32, Layout.short(event.location, 328), { color = color })
      end
      g:rect(block.x, block.y + block.h - 1, block.w, 1,{fill=true,color=color})
    end
  end
end

local function draw_day_press(g, s, blocks)
  local color = ink_of(s)
  for _, block in ipairs(blocks) do
    tick()
    if block.kind == "heading" then
      draw_section(g, s, block.x, block.y, block.h, block.text)
    elseif block.kind == "pin" then
      local event = block.item.event
      local kicker = block.pin_kind == "now" and "现在" or "下一场"
      g:text(24, block.y + 8, kicker, { color = color })
      g:rect(24, block.y + 32, 40, 2,{fill=true,color=color})
      g:text(24, block.y + 40, Layout.short(event.title, 432), { color = color })
      local byline = Time.format_range(event)
      if event.location ~= "" then byline = byline .. "  ·  " .. event.location end
      g:text(24, block.y + 68, Layout.short(byline, 432), { color = color })
      g:rect(24, block.y + block.h - 2, 432, 2,{fill=true,color=color})
    elseif block.kind == "allday" then
      g:text(24, block.y + 10, Layout.short("全天  " .. block.item.event.title, 432), { color = color })
      g:rect(24, block.y + block.h - 1, 432, 1,{fill=true,color=color})
    else
      local event = block.item.event
      g:text(24, block.y + 8, Layout.short(event.title, 432), { color = color })
      local byline = Time.format_range(event)
      if event.location ~= "" then byline = byline .. "  ·  " .. event.location end
      if block.past then byline = "已过  " .. byline end
      g:text(24, block.y + 36, Layout.short(byline, 432), { color = color })
      g:rect(24, block.y + block.h - 1, 432, 1,{fill=true,color=color})
    end
  end
end

local function draw_day(g, s)
  local blocks = M.day_blocks(s)
  if #blocks == 0 then
    draw_empty(g, s, empty_message(s))
    return
  end
  local theme = Theme.id(s)
  if theme == "pixel" then
    draw_day_pixel(g, s, blocks)
  elseif theme == "inverse" then
    draw_day_inverse(g, s, blocks)
  elseif theme == "press" then
    draw_day_press(g, s, blocks)
  else
    draw_day_ink(g, s, blocks)
  end
end

local function draw_week(g, s)
  local color = ink_of(s)
  local theme = Theme.id(s)
  for _, row in ipairs(Layout.week_rows(s)) do
    tick()
    local selected = Time.same_day(row.year, row.month, row.day, s.year, s.month, s.day)
    local today = Layout.is_today(s, row.year, row.month, row.day)
    local head = WEEKDAYS[row.weekday] .. "  " .. tostring(row.day)
    local extra = row.extra > 0 and ("  +" .. tostring(row.extra)) or ""
    local titles = #row.titles > 0 and (table.concat(row.titles, "  ") .. extra) or ""
    local fg = color
    if theme == "pixel" then
      if selected then
        g:rect(row.x, row.y, row.w, row.h,{fill=true,color=color})
        fg = WHITE
      else
        g:rect(row.x, row.y + row.h - 2, row.w, 2,{fill=true,color=color})
      end
      g:text(row.x + 16, row.y + 8, head, { color = fg })
      if titles ~= "" then
        g:text(row.x + 12, row.y + 34, Layout.short(titles, row.w - 24), { color = fg })
      end
    elseif theme == "inverse" then
      g:text(row.x + 16, row.y + 8, head, { color = color })
      if titles ~= "" then
        g:text(row.x + 16, row.y + 34, Layout.short(titles, row.w - 32), { color = color })
      end
      g:rect(row.x, row.y + row.h - (selected and 2 or 1), row.w, selected and 2 or 1,{fill=true,color=color})
      if today and not selected then
        g:rect(row.x + 16, row.y + 28, Layout.text_width(head), 2,{fill=true,color=color})
      end
      draw_dots(g, s, row.count, row.x + row.w - 16, row.y + 16, color)
    elseif theme == "press" then
      g:text(row.x, row.y + 8, head, { color = color })
      if titles ~= "" then
        g:text(row.x, row.y + 34, Layout.short(titles, row.w), { color = color })
      end
      g:rect(row.x, row.y + row.h - (selected and 2 or 1), row.w, selected and 2 or 1,{fill=true,color=color})
      if today and not selected then
        g:rect(row.x, row.y + 28, Layout.text_width(head), 2,{fill=true,color=color})
      end
    else
      if selected then
        Theme.frame(g, s, row.x, row.y, row.w, row.h, 10)
        g:rect(row.x, row.y + 8, RAIL_W, row.h - 16,{fill=true,color=color})
      elseif today then
        g:rect(row.x + 16, row.y + row.h - 3, 72, 2,{fill=true,color=color})
      end
      g:text(row.x + 16, row.y + 8, head, { color = color })
      draw_dots(g, s, row.count, row.x + row.w - 20, row.y + 16, fg)
      if titles ~= "" then
        g:text(row.x + 16, row.y + 36, Layout.short(titles, row.w - 32), { color = fg })
      end
    end
    if theme == "pixel" then
      draw_dots(g, s, row.count, row.x + row.w - 16, row.y + 16, fg)
    elseif theme == "press" then
      draw_dots(g, s, row.count, row.x + row.w - 8, row.y + 16)
    end
  end
end

local function draw_month(g, s)
  local color = ink_of(s)
  local theme = Theme.id(s)
  for index, label in ipairs(WEEKDAYS) do
    local x = CONTENT_LEFT + (index - 1) * MONTH_CELL_W
    if theme == "inverse" then
      g:text(x + 18, CONTENT_TOP, label, { color = color })
    else
      g:text(x + 18, CONTENT_TOP, label, { color = color })
    end
  end
  for _, cell in ipairs(Layout.month_cells(s)) do
    tick()
    local selected = cell.day == s.day
    local today = Layout.is_today(s, s.year, s.month, cell.day)
    local label = tostring(cell.day)
    local lx = cell.x + math.floor((MONTH_CELL_W - Layout.text_width(label)) / 2)
    local fg = color
    if selected then
      if theme == "pixel" then
        g:rect(cell.x + 2, cell.y, MONTH_CELL_W - 6, MONTH_CELL_H - 6,{fill=true,color=color})
        fg = paper_of(s)
      elseif theme == "inverse" then
        g:rect(lx, cell.y + 30, Layout.text_width(label), 2,{fill=true,color=color})
      elseif theme == "press" then
        g:rect(lx, cell.y + 30, Layout.text_width(label), 3,{fill=true,color=color})
        g:rect(cell.x + 8, cell.y + 2, MONTH_CELL_W - 16, 2,{fill=true,color=color})
      else
        Theme.frame(g, s, cell.x + 2, cell.y, MONTH_CELL_W - 6, MONTH_CELL_H - 6, 8)
      end
    elseif today then
      g:rect(lx, cell.y + 28, Layout.text_width(label), theme == "press" and 3 or 2,{fill=true,color=color})
    end
    g:text(lx, cell.y + 8, label, { color = fg })
    local dots = Layout.month_dots(cell.count)
    if dots > 0 then
      local gap = Layout.MONTH_DOT_GAP
      local cx = cell.x + math.floor((MONTH_CELL_W - (dots - 1) * gap) / 2)
      local cy = cell.y + 38
      for i = 1, dots do
        Theme.dot(g, s, cx + (i - 1) * gap, cy, fg)
      end
    end
  end
  for _, block in ipairs(Layout.month_detail_blocks(s)) do
    tick()
    if block.kind == "heading" then
      draw_section(g, s, block.x, block.y, block.h, block.text)
    elseif block.kind == "empty" then
      g:text(block.x, block.y + 4, block.text, { color = color })
    else
      draw_row(g, s, block.x, block.y, block.w, block.item)
    end
  end
end

local function draw_agenda(g, s)
  local _, order = Events.agenda_groups(s)
  if #order == 0 then
    local fallback = "未来 30 天没有日程"
    draw_empty(g, s, empty_message(s, fallback), true)
    return
  end
  for _, block in ipairs(Layout.agenda_blocks(s)) do
    tick()
    if block.kind == "heading" then
      draw_section(g, s, block.x, block.y, block.h, block.text)
    else
      draw_row(g, s, block.x, block.y, block.w, block.item)
    end
  end
end

function M.draw_detail(g, s)
  local event = s.events[s.detail]
  if not event then return end
  local color = ink_of(s)
  local theme = Theme.id(s)
  Theme.chrome_band(g, s)
  if theme == "inverse" then
    g:text(414, 32, "返回", { color = color })
    g:rect(414, 56, 40, 1,{fill=true,color=color})
  elseif theme == "press" then
    g:text(414, 32, "返回", { color = color })
    g:rect(414, 56, 40, 2,{fill=true,color=color})
  elseif theme == "pixel" then
    Theme.window(g, 400, 20, 64, 44, color, paper_of(s))
    g:text(414, 32, "返回", { color = color })
  else
    Theme.frame(g, s, 400, 20, 64, 44, 10)
    g:text(414, 32, "返回", { color = color })
  end
  local title_y = 88
  if event.calendar and event.calendar ~= "" then
    local kicker = event.calendar
    if theme == "press" then kicker = "来源 · " .. event.calendar
    elseif theme == "inverse" then kicker = "线别  " .. event.calendar
    elseif theme == "pixel" then kicker = event.calendar end
    g:text(CONTENT_LEFT, title_y, Layout.short(kicker, 432), { color = color })
    title_y = title_y + 32
  end
  for _, line in ipairs(Layout.wrap_text(event.title, 432, 3)) do
    tick()
    g:text(CONTENT_LEFT, title_y, line, { color = color })
    title_y = title_y + 28
  end
  if theme == "press" then
    g:rect(CONTENT_LEFT, title_y + 6, 432, 4,{fill=true,color=color})
    g:rect(CONTENT_LEFT, title_y + 12, 432, 1,{fill=true,color=color})
  elseif theme == "inverse" then
    g:rect(CONTENT_LEFT, title_y + 8, 432, 1,{fill=true,color=color})
  elseif theme == "pixel" then
    g:rect(CONTENT_LEFT, title_y + 8, 432, 4,{fill=true,color=color})
  else
    g:line(CONTENT_LEFT, title_y + 8, 456, title_y + 8,{color=color})
  end
  local y = title_y + 28
  local function field(icon, text)
    if theme == "press" or theme == "inverse" then
      g:text(24, y + 2, Layout.short(text, 432), { color = color })
    else
      Theme.icon_plate(g, s, 24, y, 24)
      PkgImage.draw(g, icon, 24, y)
      g:text(56, y + 2, Layout.short(text, 380), { color = color })
    end
    y = y + 44
  end
  local when = Time.format_range(event)
  if event.rrule and event.rrule ~= "" then when = when .. "  " .. event.rrule end
  field("icon_section_time", theme == "press" and ("时刻  " .. when) or when)
  field("icon_section_place", event.location ~= "" and Layout.short(event.location, 380) or (theme == "inverse" and "无站台" or (theme == "press" and "未署地点" or "没有地点")))
  if event.attendees and event.attendees ~= "" then
    field("icon_section_note", Layout.short(event.attendees, 380))
  end
  if event.url and event.url ~= "" then
    field("icon_pin", Layout.short(event.url, 380))
  end
  local note = theme == "press" and "正文" or (theme == "inverse" and "备注" or (theme == "pixel" and "NOTE" or "摘要"))
  if theme == "press" or theme == "inverse" then
    g:text(24, y + 2, note, { color = color })
    g:rect(24, y + 28, 40, theme == "press" and 3 or 1,{fill=true,color=color})
  else
    Theme.icon_plate(g, s, 24, y, 24)
    PkgImage.draw(g, "icon_section_note", 24, y)
    g:text(56, y + 2, note, { color = color })
  end
  y = y + 36
  local body = event.description ~= "" and event.description or (theme == "press" and "此条没有更多正文。" or (theme == "inverse" and "无更多备注。" or "这条日程没有更多摘要。"))
  for _, line in ipairs(Layout.wrap_text(body, 432, 10)) do
    tick()
    if y >= 700 then break end
    g:text(CONTENT_LEFT, y, line, { color = color })
    y = y + 32
  end
end

function M.draw(g, s)
  Theme.stage(g, s)
  if s.detail > 0 and s.events[s.detail] then
    local theme = Theme.id(s)
    if theme == "ink" then
      Theme.icon_plate(g, s, 16, 16, 48)
      PkgImage.draw(g, "logo_feishu", 16, 16)
    end
    local detail_title = "日程详情"
    if theme == "press" then detail_title = "本条记事" end
    g:text(theme == "ink" and 76 or 24, 28, detail_title, { color = ink_of(s) })
    M.draw_detail(g, s)
    return
  end
  M.draw_header(g, s)
  local id = Layout.view_id(s)
  if id == "day" then
    draw_day(g, s)
  elseif id == "week" then
    draw_week(g, s)
  elseif id == "agenda" then
    draw_agenda(g, s)
  else
    draw_month(g, s)
  end
  M.draw_tabs(g, s)
end

return M
