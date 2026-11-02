-- 飞书日历：TSV 解析、拉取窗口、按日过滤与日程分组。纯逻辑，无绘制。
local Time = require("domain.calendar_time")

local M = {}
local local_midnight_epoch = Time.local_midnight_epoch

function M.events_on_day(events, year, month, day)
  local list = {}
  for index, event in ipairs(events) do
    if Time.event_on_day(event, year, month, day) then
      list[#list + 1] = { event = event, index = index }
    end
  end
  return list
end

function M.minutes_on_day(event, year, month, day)
  local a, b = event.start, event.finish or event.start
  if not a or a.all_day or (b and b.all_day) then return 0 end
  local start_m = a.hour * 60 + a.minute
  if not Time.same_day(a.year, a.month, a.day, year, month, day) then start_m = 0 end
  local end_m = 24 * 60
  if b and Time.same_day(b.year, b.month, b.day, year, month, day) then
    end_m = b.hour * 60 + b.minute
    if end_m <= start_m then end_m = start_m + 30 end
  end
  return math.max(30, end_m - start_m)
end

function M.parse(body, checkpoint)
  local events, calendars = {}, 0
  for line in (body .. "\n"):gmatch("(.-)\n") do
    if checkpoint then checkpoint() end
    if line:sub(1, 10) == "calendars\t" then
      calendars = tonumber(line:sub(11)) or 0
    elseif line:sub(1, 6) == "event\t" then
      local fields = {}
      for field in (line:sub(7) .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = field end
      local status = string.upper(fields[7] or "")
      if fields[1] and status ~= "CANCELLED" then
        local start = Time.parse_ics_local(fields[3])
        local finish = Time.parse_ics_local(fields[4])
        if fields[8] == "1" then
          if start then start.all_day = true end
          if finish then finish.all_day = true end
        end
        events[#events + 1] = {
          uid = fields[1] or "",
          title = fields[2] or "未命名日程",
          start_at = fields[3] or "",
          end_at = fields[4] or "",
          location = fields[5] or "",
          description = fields[6] or "",
          status = fields[7] or "",
          calendar = fields[9] or "",
          attendees = fields[10] or "",
          url = fields[11] or "",
          rrule = fields[12] or "",
          start = start,
          finish = finish,
        }
      end
    end
  end
  table.sort(events, function(a, b) return (a.start_at or "") < (b.start_at or "") end)
  return events, calendars
end

function M.day_count(events, year, month, day)
  return #M.events_on_day(events, year, month, day)
end

function M.start_minutes(event, year, month, day)
  local part = event.start
  if not part or part.all_day then return nil end
  if Time.same_day(part.year, part.month, part.day, year, month, day) then
    return part.hour * 60 + part.minute
  end
  return 0
end

function M.end_minutes(event, year, month, day)
  local start_m = M.start_minutes(event, year, month, day)
  if start_m == nil then return nil end
  return start_m + M.minutes_on_day(event, year, month, day)
end

function M.next_timed(events, year, month, day, hour, minute)
  if type(hour) ~= "number" or type(minute) ~= "number" then return nil, nil end
  local now_m = hour * 60 + minute
  local current, upcoming = nil, nil
  for _, item in ipairs(M.events_on_day(events, year, month, day)) do
    local event = item.event
    if event.start and not event.start.all_day then
      local start_m = M.start_minutes(event, year, month, day)
      local end_m = M.end_minutes(event, year, month, day)
      if start_m and end_m then
        if start_m <= now_m and now_m < end_m and not current then
          current = item
        elseif start_m >= now_m and not upcoming then
          upcoming = item
        end
      end
    end
  end
  if current then return current, "now" end
  if upcoming then return upcoming, "next" end
  return nil, nil
end

function M.day_plan(events, year, month, day, now)
  local allday, timed = {}, {}
  for _, item in ipairs(M.events_on_day(events, year, month, day)) do
    if item.event.start and item.event.start.all_day then
      allday[#allday + 1] = item
    else
      timed[#timed + 1] = item
    end
  end
  local pin, pin_kind = nil, nil
  if now then
    pin, pin_kind = M.next_timed(events, year, month, day, now.hour, now.minute)
  end
  local now_m = now and (now.hour * 60 + now.minute) or nil
  local list = {}
  for _, item in ipairs(timed) do
    local start_m = M.start_minutes(item.event, year, month, day) or 0
    local end_m = M.end_minutes(item.event, year, month, day) or (start_m + 30)
    list[#list + 1] = {
      kind = "timed",
      item = item,
      past = now_m ~= nil and end_m <= now_m,
      pinned = pin ~= nil and item.index == pin.index,
      from = start_m,
      to = end_m,
    }
  end
  return { allday = allday, timed = list, pin = pin, pin_kind = pin_kind }
end

function M.response_error(body)
  for line in (body .. "\n"):gmatch("(.-)\n") do
    if line:sub(1, 8) == "message\t" then return line:sub(9) end
  end
  return nil
end

function M.query_range(s, view_id)
  local y, m, d = s.year, s.month, s.day
  if view_id == "day" then
    return Time.utc_string(local_midnight_epoch(y, m, d)), Time.utc_string(local_midnight_epoch(y, m, d + 1))
  end
  if view_id == "week" then
    local wy, wm, wd = Time.monday_of(y, m, d)
    return Time.utc_string(local_midnight_epoch(wy, wm, wd)), Time.utc_string(local_midnight_epoch(wy, wm, wd + 7))
  end
  if view_id == "month" then
    return Time.utc_string(local_midnight_epoch(y, m, 1)), Time.utc_string(local_midnight_epoch(y, m + 1, 1))
  end
  return Time.utc_string(local_midnight_epoch(y, m, d)), Time.utc_string(local_midnight_epoch(y, m, d + 30))
end

function M.fetch_range(s, view_id)
  local y, m, d = s.year, s.month, s.day
  local from_y, from_m, from_d = Time.monday_of(y, m, 1)
  local to_y, to_m, to_d = Time.shift_date(y, m + 1, 1, 7)
  if view_id == "agenda" then
    local agenda_y, agenda_m, agenda_d = Time.shift_date(y, m, d, 30)
    if local_midnight_epoch(agenda_y, agenda_m, agenda_d) > local_midnight_epoch(to_y, to_m, to_d) then
      to_y, to_m, to_d = agenda_y, agenda_m, agenda_d
    end
    if local_midnight_epoch(y, m, d) < local_midnight_epoch(from_y, from_m, from_d) then
      from_y, from_m, from_d = y, m, d
    end
  end
  return Time.utc_string(local_midnight_epoch(from_y, from_m, from_d)), Time.utc_string(local_midnight_epoch(to_y, to_m, to_d))
end

function M.range_covers(cache_from, cache_to, need_from, need_to)
  return type(cache_from) == "string" and cache_from ~= ""
    and type(cache_to) == "string" and type(need_from) == "string" and type(need_to) == "string"
    and cache_from <= need_from and cache_to >= need_to
end

function M.sample(year, month, day)
  local function stamp(y, m, d, hour, minute)
    return string.format("%04d%02d%02dT%02d%02d00", y, m, d, hour, minute)
  end
  local function day_stamp(y, m, d)
    return string.format("%04d%02d%02d", y, m, d)
  end
  local ny, nm, nd = Time.shift_date(year, month, day, 1)
  local wy, wm, wd = Time.shift_date(year, month, day, 3)
  local lines = {
    "calendars\t1",
    "event\tsample-all\t团队日\t" .. day_stamp(year, month, day) .. "\t" .. day_stamp(ny, nm, nd) .. "\t\t示例全天\tCONFIRMED\t1\t工作\t\t\t",
    "event\tsample-am\t晨会\t" .. stamp(year, month, day, 9, 0) .. "\t" .. stamp(year, month, day, 9, 30) .. "\t线上\t示例\tCONFIRMED\t0\t工作\t\t\t",
    "event\tsample-pm\t设计评审\t" .. stamp(year, month, day, 14, 0) .. "\t" .. stamp(year, month, day, 15, 30) .. "\tA座\t示例\tCONFIRMED\t0\t工作\t张三、李四\thttps://vc.feishu.cn/j/demo\t",
    "event\tsample-eve\t晚间站会\t" .. stamp(year, month, day, 21, 0) .. "\t" .. stamp(year, month, day, 21, 30) .. "\t线上\t示例\tCONFIRMED\t0\t工作\t\t\t",
    "event\tsample-next\t周复盘\t" .. stamp(ny, nm, nd, 10, 0) .. "\t" .. stamp(ny, nm, nd, 11, 0) .. "\t\t示例\tCONFIRMED\t0\t工作\t\t\t",
    "event\tsample-later\t产品同步\t" .. stamp(wy, wm, wd, 16, 0) .. "\t" .. stamp(wy, wm, wd, 17, 0) .. "\t\t示例\tCONFIRMED\t0\t工作\t\t\t",
  }
  return M.parse(table.concat(lines, "\n"))
end

function M.agenda_groups(s)
  local groups, order = {}, {}
  local start_epoch = local_midnight_epoch(s.year, s.month, s.day)
  for index, event in ipairs(s.events) do
    local part = event.start
    if part then
      local key = string.format("%04d-%02d-%02d", part.year, part.month, part.day)
      local epoch = local_midnight_epoch(part.year, part.month, part.day)
      if epoch >= start_epoch and epoch < start_epoch + 30 * Time.DAY_SECONDS then
        if not groups[key] then
          groups[key] = { year = part.year, month = part.month, day = part.day, items = {} }
          order[#order + 1] = key
        end
        groups[key].items[#groups[key].items + 1] = { event = event, index = index }
      end
    end
  end
  table.sort(order)
  return groups, order
end

return M
