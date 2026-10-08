-- 墨水状态板：全部指标都是离线生成的模拟数据。
-- 设计为分钟级快照，避免在墨水屏上进行无意义的高频刷新。

local BLACK, WHITE = 15, 0

local function clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function text_width(text)
  local width, index = 0, 1
  while index <= #text do
    if text:byte(index) >= 0xE0 then width, index = width + 20, index + 3 else width, index = width + 10, index + 1 end
  end
  return width
end

local function center(g, x, y, width, text, color)
  g:text(x + math.floor((width - text_width(text)) / 2), y, text, { color = color or BLACK })
end

local function date_parts(clock)
  if not clock or clock.valid ~= true or clock.year == nil or clock.hour == nil or clock.minute == nil then return nil end
  return { year = clock.year, month = clock.month, day = clock.day, hour = clock.hour, min = clock.minute, weekday = clock.weekday }
end

-- 一个确定性的轻量伪随机序列：无需网络，刷新后仍能得到自然的模拟状态。
local function next_value(seed)
  return (seed * 73 + 41) % 997
end

local function snapshot(ctx)
  ctx.state.ink_board = ctx.state.ink_board or { nonce = 0, focus = 0 }
  local state = ctx.state.ink_board
  local clock = ctx.sys:clock()
  local minute = clock.valid and (clock.hour * 60 + clock.minute) or 0
  local seed = (minute + state.nonce * 137) % 997
  seed = next_value(seed); local quota = 18 + seed % 71
  seed = next_value(seed); local temperature = 16 + seed % 18
  seed = next_value(seed); local humidity = 36 + seed % 45
  seed = next_value(seed); local focus_minutes = 24 + seed % 56
  seed = next_value(seed); local remaining = 2 + seed % 7
  seed = next_value(seed); local jobs = 1 + seed % 5
  return { quota = quota, temperature = temperature, humidity = humidity, focus_minutes = focus_minutes, remaining = remaining, jobs = jobs, parts = date_parts(clock) }
end

local function draw_rule(g, x, y, width)
  g:line(x, y, x + width, y, BLACK)
end

local function draw_meter(g, x, y, width, percent)
  local blocks = 8
  local gap = 6
  local block_width = math.floor((width - (blocks - 1) * gap) / blocks)
  local filled = math.max(1, math.floor(percent * blocks / 100 + 0.5))
  for index = 0, blocks - 1 do
    local bx = x + index * (block_width + gap)
    if index < filled then
      g:rect(bx, y, block_width, 10, "fill", BLACK)
    else
      g:rect(bx, y, block_width, 10, "stroke", BLACK)
    end
  end
end

local function draw_task(g, x, y, width, icon, title, detail, status)
  g:image(icon, x, y + 9)
  g:text(x + 52, y + 9, title, { color = BLACK })
  g:text(x + 52, y + 34, detail, { color = BLACK })
  g:text(x + width - text_width(status), y + 22, status, { color = BLACK })
  g:line(x + 52, y + 67, x + width, y + 67, BLACK)
end

local function draw_habit(g, x, y, label, done)
  g:rect(x, y, 22, 22, done and "fill" or "stroke", BLACK)
  g:text(x + 32, y + 2, label, { color = BLACK })
end

local function draw(ctx, g)
  local w, h = ctx.screen.width, ctx.screen.height
  local margin = clamp(math.floor(w * 0.055), 20, 28)
  local inner = w - margin * 2
  local data = snapshot(ctx)
  local parts = data.parts
  local weekdays = { "日", "一", "二", "三", "四", "五", "六" }
  g:clear(WHITE)
  local state = ctx.state.ink_board
  g:text(margin, 28, parts and string.format("%02d / %02d  周%s", parts.month, parts.day, weekdays[parts.weekday + 1]) or "今日", { color = BLACK })
  g:image("icon_cup", w - margin - 36, 18)
  g:text(margin, 66, "墨水状态板", { color = BLACK })
  g:text(margin, 92, "离线状态，专注当下", { color = BLACK })
  draw_rule(g, margin, 124, inner)

  g:rect(margin, 176, 4, 56, "fill", BLACK)
  g:text(margin + 20, 154, "今日最重要", { color = BLACK })
  g:image("icon_focus", w - margin - 36, 169)
  g:text(margin + 20, 194, "深度工作", { color = BLACK })
  g:text(margin + 20, 221, string.format("已经沉浸 %d 分钟", data.focus_minutes), { color = BLACK })
  local focus_status = state.paused and "已暂停" or "进行中"
  g:text(w - margin - text_width(focus_status), 221, focus_status, { color = BLACK })
  draw_rule(g, margin, 252, inner)

  g:image("icon_deepseek", margin, 284)
  g:text(margin + 50, 284, "DEEPSEEK 额度", { color = BLACK })
  g:text(margin + 50, 311, string.format("%d%%", data.quota), { color = BLACK })
  draw_meter(g, margin + 50, 349, 118, data.quota)
  g:line(240, 278, 240, 364, BLACK)
  g:image("icon_weather", 274, 287)
  g:text(324, 284, "窗外天气", { color = BLACK })
  g:text(324, 311, string.format("%d°C", data.temperature), { color = BLACK })
  g:text(324, 338, string.format("湿度 %d%%", data.humidity), { color = BLACK })
  draw_rule(g, margin, 386, inner)

  g:text(margin, 418, "其余事项", { color = BLACK })
  draw_task(g, margin, 442, inner, "icon_todo", "待办确认", state.todo_done and "已完成，等待归档" or string.format("还有 %d 项需要回复", data.remaining), state.todo_done and "完成" or "稍后")
  draw_task(g, margin, 509, inner, "icon_build", "本地构建", state.build_done and "构建已通过" or string.format("队列里有 %d 个任务", data.jobs), state.build_done and "完成" or "安静")

  g:text(margin, 608, "轻量习惯", { color = BLACK })
  draw_habit(g, margin, 638, "喝水", state.hydrated)
  draw_habit(g, 172, 638, "阅读", state.read_done)
  draw_habit(g, 316, 638, "走动", state.walk_done)
  center(g, margin, 682, inner, "轻触项目切换状态", BLACK)
  local action = state.focus == 0 and "刷新快照" or "确认刷新"
  local button_x, button_width = 126, 228
  g:rect(button_x, 716, button_width, 42, state.focus == 1 and "fill" or "stroke", BLACK)
  center(g, button_x, 727, button_width, action, state.focus == 1 and WHITE or BLACK)
end

local function refresh(ctx)
  local state = ctx.state.ink_board
  state.nonce = state.nonce + 1
  ctx:invalidate()
end

function on_load(ctx)
  ctx.state.ink_board = { nonce = 0, focus = 0, minute = nil, paused = false, todo_done = false, build_done = false, hydrated = false, read_done = false, walk_done = false }
  ctx:set_tick_rate("low")
end

function on_enter(ctx)
  ctx:invalidate()
end

function on_tick(ctx, _dt_ms)
  local state = ctx.state.ink_board
  local clock = ctx.sys:clock()
  local minute = clock.valid and (clock.hour * 60 + clock.minute) or nil
  if minute ~= state.minute then state.minute = minute; ctx:invalidate() end
end

function on_input(ctx, ev)
  local state = ctx.state.ink_board
  if ev.type == "key" and ev.state == "down" then
    if ev.key == "back" then ctx:quit(); return true end
    if ev.key == "up" or ev.key == "down" then state.focus = 1 - state.focus; ctx:invalidate(); return true end
    if ev.key == "ok" then refresh(ctx); return true end
  end
  if ev.type == "touch" and ev.gesture == "tap" then
    if ev.y >= 140 and ev.y <= 252 then state.paused = not state.paused; ctx:invalidate(); return true end
    if ev.y >= 442 and ev.y < 509 then state.todo_done = not state.todo_done; ctx:invalidate(); return true end
    if ev.y >= 509 and ev.y < 576 then state.build_done = not state.build_done; ctx:invalidate(); return true end
    if ev.y >= 628 and ev.y <= 674 then
      if ev.x < 156 then state.hydrated = not state.hydrated
      elseif ev.x < 300 then state.read_done = not state.read_done
      else state.walk_done = not state.walk_done end
      ctx:invalidate(); return true
    end
    if ev.y >= 700 and ev.y <= 774 then refresh(ctx); return true end
  end
  return false
end

function on_draw(ctx, g)
  draw(ctx, g)
end
