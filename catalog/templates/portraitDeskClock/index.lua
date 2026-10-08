local M = {}
local BLACK = 15
local WHITE = 0
local BUTTON_H = 38

local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local WEEKDAYS = { "日", "一", "二", "三", "四", "五", "六" }

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function is_leap(year)
    return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function month_days(year, month)
    if month == 2 and is_leap(year) then return 29 end
    return MONTH_DAYS[month]
end

local function project_time(ctx)
    local clock = ctx.sys:clock()
    if not clock.valid or clock.year == nil or clock.hour == nil or clock.minute == nil then return nil end
    return { year = clock.year, month = clock.month, day = clock.day, hour = clock.hour, min = clock.minute, sec = clock.second, wday = clock.weekday }
end

local function first_wday(year, month)
    local days = 0
    for y = 1970, year - 1 do days = days + (is_leap(y) and 366 or 365) end
    for m = 1, month - 1 do days = days + month_days(year, m) end
    return (days + 4) % 7
end

local function text_width(text)
    local width, i = 0, 1
    while i <= #text do
        if text:byte(i) >= 0xE0 then width, i = width + 20, i + 3 else width, i = width + 10, i + 1 end
    end
    return width
end

local function center_text(g, x, y, width, text, color)
    g:text(x + math.floor((width - text_width(text)) / 2), y, text, { color = color })
end

local function draw_time(g, x, y, width, height, parts)
    local text = parts and string.format("%02d:%02d", parts.hour, parts.min) or "--:--"
    local digit_w, digit_h = 60, 91
    local gap, colon_w = 11, 22
    local total = digit_w * 4 + gap * 3 + colon_w
    local cursor, top = x + math.floor((width - total) / 2), y + math.floor((height - digit_h) / 2)
    for i = 1, #text do
        local char = text:sub(i, i)
        if char == ":" then
            local dot = 7
            g:circle(cursor + math.floor(colon_w / 2), top + math.floor(digit_h * .36), dot, "fill", BLACK)
            g:circle(cursor + math.floor(colon_w / 2), top + math.floor(digit_h * .68), dot, "fill", BLACK)
            cursor = cursor + colon_w
        else
            g:image("kaisei_digit_" .. char, cursor, top)
            cursor = cursor + digit_w + gap
        end
    end
end

local function draw_calendar(g, parts, x, y, width, height)
    local padding = 18
    local header_h = 30
    local weekday_h = 24
    local inner_x = x + padding
    local inner_w = width - padding * 2
    local cell_w = math.floor(inner_w / 7)
    local grid_y = y + header_h + weekday_h + 9
    local row_h = math.floor((height - header_h - weekday_h - 14) / 6)
    if not parts then
        center_text(g, x, y + 3, width, "---- / --", BLACK)
        center_text(g, x, grid_y + 20, width, "时间未校准", BLACK)
        return
    end
    center_text(g, x, y + 3, width, string.format("%04d 年 %02d 月", parts.year, parts.month), BLACK)
    for col = 0, 6 do
        center_text(g, inner_x + col * cell_w, y + header_h + 1, cell_w, WEEKDAYS[col + 1], BLACK)
    end
    g:line(inner_x, grid_y - 2, inner_x + cell_w * 7, grid_y - 2, BLACK)
    local first = first_wday(parts.year, parts.month)
    for day = 1, month_days(parts.year, parts.month) do
        local slot = first + day - 1
        local col, row = slot % 7, math.floor(slot / 7)
        local cx, cy = inner_x + col * cell_w, grid_y + row * row_h
        if day == parts.day then
            g:circle(cx + math.floor(cell_w / 2), cy + math.floor(row_h / 2), math.floor(math.min(cell_w, row_h) * .39), "fill", BLACK)
            center_text(g, cx, cy + math.floor((row_h - 20) / 2), cell_w, tostring(day), WHITE)
        else
            center_text(g, cx, cy + math.floor((row_h - 20) / 2), cell_w, tostring(day), BLACK)
        end
    end
end

local function button_rect(ctx)
    local width = math.min(180, ctx.screen.width - 56)
    return { x = math.floor((ctx.screen.width - width) / 2), y = ctx.screen.height - BUTTON_H - 22, w = width, h = BUTTON_H }
end

local function draw_dashboard(ctx, g, show_button)
    local width, height = ctx.screen.width, ctx.screen.height
    local margin = clamp(math.floor(width * 0.06), 20, 30)
    local parts = project_time(ctx)
    local calendar_h = 236
    local button_space = show_button and BUTTON_H + 30 or 26
    local calendar_y = height - margin - button_space - calendar_h
    g:clear(WHITE)
    center_text(g, margin, 54, width - margin * 2, "DESK CALENDAR")
    if parts then
        center_text(g, margin, 88, width - margin * 2, string.format("%04d 年 %02d 月 %02d 日  ·  星期%s", parts.year, parts.month, parts.day, WEEKDAYS[parts.wday + 1]))
    end
    draw_time(g, margin + 16, 148, width - margin * 2 - 32, 230, parts)
    if parts then
        center_text(g, margin, 420, width - margin * 2, "现在 · 此刻 · 本月")
    else
        center_text(g, margin, 420, width - margin * 2, "时间未校准", BLACK)
    end
    g:line(margin + 70, 462, width - margin - 70, 462, BLACK)
    draw_calendar(g, parts, margin, calendar_y, width - margin * 2, calendar_h)
    if show_button then
        local rect = button_rect(ctx)
        g:rect(rect.x, rect.y, rect.w, rect.h, "stroke", BLACK)
        center_text(g, rect.x, rect.y + 9, rect.w, ctx.state.clock_status or "设为锁屏", BLACK)
    end
end

M.draw_dashboard = draw_dashboard

local function refresh_key(parts)
    if not parts then return "unsynced" end
    return string.format("%04d%02d%02d%02d%02d", parts.year, parts.month, parts.day, parts.hour, parts.min)
end

function on_enter(ctx)
    ctx.state.portrait_clock = ctx.state.portrait_clock or {}
    ctx.state.portrait_clock.last_key = nil
    ctx:set_tick_rate("low")
    ctx:invalidate()
end

function on_tick(ctx, _dt_ms)
    local key = refresh_key(project_time(ctx))
    if key ~= ctx.state.portrait_clock.last_key then
        ctx.state.portrait_clock.last_key = key
        ctx:invalidate()
    end
end

function on_input(ctx, ev)
    if ev.type == "key" and ev.state == "down" then
        if ev.key == "back" then ctx:quit(); return true end
        if ev.key == "ok" then
            ctx.system:set_as_lockscreen_app()
            ctx.state.clock_status = "已设为锁屏"
            ctx:invalidate()
            return true
        end
    end
    if ev.type == "touch" and ev.gesture == "tap" then
        local rect = button_rect(ctx)
        if ev.x >= rect.x and ev.x < rect.x + rect.w and ev.y >= rect.y and ev.y < rect.y + rect.h then
            ctx.system:set_as_lockscreen_app()
            ctx.state.clock_status = "已设为锁屏"
            ctx:invalidate()
            return true
        end
    end
    return false
end

function on_draw(ctx, g)
    draw_dashboard(ctx, g, true)
end

return M
