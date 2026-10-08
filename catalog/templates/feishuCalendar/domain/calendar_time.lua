-- 飞书日历：北京时区日期、ICS 本地时间和跨日判定。纯逻辑，无绘制、无网络。
local M = {}

M.DAY_SECONDS = 86400
M.BEIJING_OFFSET_SECONDS = 8 * 3600

function M.leap_year(year)
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

function M.days_in_year(year)
  return M.leap_year(year) and 366 or 365
end

function M.days_in_month(year, month)
  local lengths = { 31, M.leap_year(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  return lengths[month]
end

function M.utc_string(seconds)
  if type(seconds) ~= "number" or seconds < 0 then return nil end
  local whole = seconds // 1
  local days = whole // 86400
  local remaining = whole - days * 86400
  local year = 1970
  while days >= (M.leap_year(year) and 366 or 365) do
    days = days - (M.leap_year(year) and 366 or 365)
    year = year + 1
  end
  local month_days = { 31, M.leap_year(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local month = 1
  while days >= month_days[month] do days = days - month_days[month]; month = month + 1 end
  local hour = remaining // 3600
  local minute = (remaining // 60) % 60
  local second = remaining % 60
  return string.format("%04d%02d%02dT%02d%02d%02dZ", year, month, days + 1, hour, minute, second)
end

function M.local_midnight_epoch(year, month, day)
  while month > 12 do year, month = year + 1, month - 12 end
  while month < 1 do year, month = year - 1, month + 12 end
  while day < 1 do
    month = month - 1
    if month < 1 then year, month = year - 1, 12 end
    day = day + M.days_in_month(year, month)
  end
  while day > M.days_in_month(year, month) do
    day = day - M.days_in_month(year, month)
    month = month + 1
    if month > 12 then year, month = year + 1, 1 end
  end
  local days = 0
  if year >= 1970 then
    for cursor = 1970, year - 1 do days = days + M.days_in_year(cursor) end
  else
    for cursor = year, 1969 do days = days - M.days_in_year(cursor) end
  end
  for cursor = 1, month - 1 do days = days + M.days_in_month(year, cursor) end
  days = days + day - 1
  return days * M.DAY_SECONDS - M.BEIJING_OFFSET_SECONDS
end

function M.shift_date(year, month, day, delta)
  local stamp = M.utc_string(M.local_midnight_epoch(year, month, day) + M.BEIJING_OFFSET_SECONDS + delta * M.DAY_SECONDS)
  return tonumber(stamp:sub(1, 4)), tonumber(stamp:sub(5, 6)), tonumber(stamp:sub(7, 8))
end

function M.weekday_monday(year, month, day)
  local local_epoch = M.local_midnight_epoch(year, month, day) + M.BEIJING_OFFSET_SECONDS
  return (local_epoch // M.DAY_SECONDS + 3) % 7 + 1
end

function M.monday_of(year, month, day)
  return M.shift_date(year, month, day, 1 - M.weekday_monday(year, month, day))
end

function M.ymd_from_epoch(epoch_sec)
  if type(epoch_sec) ~= "number" then return 2026, 9, 4 end
  local stamp = M.utc_string(epoch_sec + M.BEIJING_OFFSET_SECONDS)
  return tonumber(stamp:sub(1, 4)), tonumber(stamp:sub(5, 6)), tonumber(stamp:sub(7, 8))
end

function M.hms_from_epoch(epoch_sec)
  if type(epoch_sec) ~= "number" then return nil end
  local stamp = M.utc_string(epoch_sec + M.BEIJING_OFFSET_SECONDS)
  if not stamp then return nil end
  return {
    year = tonumber(stamp:sub(1, 4)),
    month = tonumber(stamp:sub(5, 6)),
    day = tonumber(stamp:sub(7, 8)),
    hour = tonumber(stamp:sub(10, 11)),
    minute = tonumber(stamp:sub(12, 13)),
  }
end

function M.hm_minutes(minutes)
  minutes = math.max(0, math.min(24 * 60, math.floor(tonumber(minutes) or 0)))
  return M.pad2(math.floor(minutes / 60)) .. ":" .. M.pad2(minutes % 60)
end

function M.same_day(a_y, a_m, a_d, b_y, b_m, b_d)
  return a_y == b_y and a_m == b_m and a_d == b_d
end

function M.parse_ics_local(value)
  value = tostring(value or "")
  if value == "" then return nil end
  if #value == 8 and value:match("^%d+$") then
    return {
      year = tonumber(value:sub(1, 4)), month = tonumber(value:sub(5, 6)), day = tonumber(value:sub(7, 8)),
      hour = 0, minute = 0, all_day = true,
    }
  end
  local year, month, day, hour, minute = value:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)")
  if not year then return nil end
  year, month, day, hour, minute = tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(minute)
  if value:sub(-1) == "Z" then
    local days = 0
    if year >= 1970 then
      for cursor = 1970, year - 1 do days = days + M.days_in_year(cursor) end
    end
    for cursor = 1, month - 1 do days = days + M.days_in_month(year, cursor) end
    days = days + day - 1
    local stamp = M.utc_string(days * M.DAY_SECONDS + hour * 3600 + minute * 60 + M.BEIJING_OFFSET_SECONDS)
    if not stamp then return nil end
    return {
      year = tonumber(stamp:sub(1, 4)), month = tonumber(stamp:sub(5, 6)), day = tonumber(stamp:sub(7, 8)),
      hour = tonumber(stamp:sub(10, 11)), minute = tonumber(stamp:sub(12, 13)), all_day = false,
    }
  end
  return { year = year, month = month, day = day, hour = hour, minute = minute, all_day = false }
end

function M.pad2(value)
  return string.format("%02d", value)
end

function M.hm(part)
  if not part or part.all_day then return "全天" end
  return M.pad2(part.hour) .. ":" .. M.pad2(part.minute)
end

function M.md(part)
  if not part then return "" end
  return tostring(part.month) .. "/" .. tostring(part.day)
end

function M.format_range(event)
  local a, b = event.start, event.finish
  if not a then return event.start_at end
  if a.all_day or (b and b.all_day) then
    if b and not M.same_day(a.year, a.month, a.day, b.year, b.month, b.day) then
      local ey, em, ed = M.shift_date(b.year, b.month, b.day, -1)
      if M.same_day(a.year, a.month, a.day, ey, em, ed) then return "全天" end
      return M.md(a) .. " – " .. tostring(em) .. "/" .. tostring(ed) .. " 全天"
    end
    return "全天"
  end
  if b and not M.same_day(a.year, a.month, a.day, b.year, b.month, b.day) then
    return M.md(a) .. " " .. M.hm(a) .. " – " .. M.md(b) .. " " .. M.hm(b)
  end
  return M.hm(a) .. " – " .. M.hm(b or a)
end

function M.event_on_day(event, year, month, day)
  local a, b = event.start, event.finish or event.start
  if not a then return false end
  local end_year, end_month, end_day = a.year, a.month, a.day
  if b then
    end_year, end_month, end_day = b.year, b.month, b.day
    if a.all_day or b.all_day then
      end_year, end_month, end_day = M.shift_date(b.year, b.month, b.day, -1)
    elseif b.hour == 0 and b.minute == 0 then
      end_year, end_month, end_day = M.shift_date(b.year, b.month, b.day, -1)
    end
  end
  local day_epoch = M.local_midnight_epoch(year, month, day)
  return day_epoch >= M.local_midnight_epoch(a.year, a.month, a.day) and day_epoch <= M.local_midnight_epoch(end_year, end_month, end_day)
end

return M
