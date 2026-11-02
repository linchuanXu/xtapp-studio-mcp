local PkgImage = require("pkg_image")
-- 四象限清单：任务均为本地模拟数据，不连接任何在线清单服务。
local BLACK, WHITE = 15, 0

local QUADRANTS = {
  { title = "重要且紧急", tag = "现在处理", icon = "icon_fire", note = "需要专注 45 分钟", tasks = {
    { title = "客户汇报", overview = "今天 16点", meta = "今天 16点 · 45分钟" }, { title = "修复登录问题", meta = "今天 11点 · 20分钟" }, { title = "确认合同条款", meta = "今天 · 15分钟" },
  } },
  { title = "重要不紧急", tag = "安排时间", icon = "icon_sprout", note = "为长期目标留出时间", tasks = {
    { title = "产品复盘", overview = "本周三", meta = "本周三 · 30分钟" }, { title = "整理阅读笔记", meta = "本周 · 25分钟" }, { title = "准备下周计划", meta = "周五 · 20分钟" },
  } },
  { title = "紧急不重要", tag = "快速完成", icon = "icon_bell", note = "可以在碎片时间处理", tasks = {
    { title = "快递取件", overview = "今天 12点", meta = "今天 12点 · 10分钟" }, { title = "回复行政确认", meta = "今天 · 5分钟" }, { title = "预约保洁", meta = "明天 · 10分钟" },
  } },
  { title = "不紧急不重要", tag = "稍后再说", icon = "icon_archive", note = "避免占用黄金时间", tasks = {
    { title = "整理相册", overview = "无截止", meta = "无截止时间" }, { title = "清理收藏夹", meta = "无截止时间" }, { title = "浏览新品资讯", meta = "周末再看" },
  } },
}

local function planner_state(ctx)
  local state = ctx.state.quadrant_planner or { selected = 1, task = 1, page = "home", done = {} }
  state.done = state.done or {}
  state.task = state.task or 1
  state.page = state.page or "home"
  ctx.state.quadrant_planner = state
  return state
end

local function layout(ctx)
  local w, h = ctx.screen.width, ctx.screen.height
  local m, gap = math.max(32, math.floor(w * 0.07)), 14
  local card_w = math.floor((w - m * 2 - gap) / 2)
  return { w = w, h = h, m = m, gap = gap, card_w = card_w, card_h = 170, cards_y = 164, footer_y = h - 58 }
end

local function text_width(text)
  local width, index = 0, 1
  while index <= #text do
    if text:byte(index) >= 0xE0 then width, index = width + 20, index + 3 else width, index = width + 10, index + 1 end
  end
  return width
end

local function center_x(l, text)
  return math.floor((l.w - text_width(text)) / 2)
end

local function round_fill(g, x, y, w, h, radius, color)
  local r = math.max(2, math.min(radius, math.floor(math.min(w, h) / 2)))
  g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
  g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
end

local function round_outline(g, x, y, w, h, radius)
  round_fill(g, x, y, w, h, radius, BLACK)
  round_fill(g, x + 2, y + 2, w - 4, h - 4, math.max(2, radius - 2), WHITE)
end

local function card_position(l, index)
  local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
  return l.m + column * (l.card_w + l.gap), l.cards_y + row * (l.card_h + l.gap)
end

local function done_count(state)
  local total = 0
  for _, done in pairs(state.done) do if done then total = total + 1 end end
  return total
end

local function task_done(state, quadrant, task)
  return state.done[quadrant] and state.done[quadrant][task] == true
end

local function quadrant_open_count(state, index)
  local count = 0
  for task = 1, #QUADRANTS[index].tasks do
    if not task_done(state, index, task) then count = count + 1 end
  end
  return count
end

local function toggle_task(state)
  state.done[state.selected] = state.done[state.selected] or {}
  state.done[state.selected][state.task] = not task_done(state, state.selected, state.task)
end

local function draw_header(g, l, state)
  g:text(l.m, 28, "今天的清单", { color = BLACK })
  g:text(l.w - l.m - 42, 28, "09:41", { color = BLACK })
  g:text(l.m, 52, "周一 · 8 月 24 日", { color = BLACK })
  g:text(l.w - l.m - 116, 52, "已完成 " .. done_count(state) .. " 项", { color = BLACK })
  g:line(l.m, 78, l.w - l.m, 78,{color=BLACK})
  g:text(l.m, 102, "先做重要的事，再做紧急的事", { color = BLACK })
  g:rect(l.m, 132, l.w - l.m * 2, 6,{color=BLACK})
  g:rect(l.m + 2, 134, 168, 2,{fill=true,color=BLACK})
end

local function draw_card(g, l, state, index)
  local x, y = card_position(l, index)
  local item, primary = QUADRANTS[index], QUADRANTS[index].tasks[1]
  local done = task_done(state, index, 1)
  round_outline(g, x, y, l.card_w, l.card_h, 16)
  g:text(x + 16, y + 16, item.title, { color = BLACK })
  g:text(x + l.card_w - 48, y + 16, quadrant_open_count(state, index) .. "项", { color = BLACK })
  g:line(x + 16, y + 42, x + l.card_w - 16, y + 42,{color=BLACK})
  PkgImage.draw(g, item.icon, x + 16, y + 58, { color = BLACK })
  g:text(x + 86, y + 60, primary.title, { color = BLACK })
  g:text(x + 86, y + 84, primary.overview, { color = BLACK })
  g:text(x + 16, y + 132, item.tag, { color = BLACK })
  if done then
    round_fill(g, x + l.card_w - 44, y + l.card_h - 42, 28, 28, 14, BLACK)
    PkgImage.draw(g, "icon_check", x + l.card_w - 40, y + l.card_h - 38, { color = WHITE })
  else
    g:circle(x + l.card_w - 30, y + l.card_h - 28, 12,{color=BLACK})
  end
end

local function draw_summary(g, l, state)
  local y = l.cards_y + l.card_h * 2 + l.gap + 24
  g:text(l.m, y, "留给自己的时间", { color = BLACK })
  g:text(l.m, y + 28, "重要不紧急的 3 项，今天先安排 30 分钟。", { color = BLACK })
  g:line(l.m, y + 62, l.w - l.m, y + 62,{color=BLACK})
  g:text(l.m, y + 82, "待处理 " .. (12 - done_count(state)) .. " 项", { color = BLACK })
  g:text(l.w - l.m - 140, y + 82, "离线模拟数据", { color = BLACK })
end

local function draw_detail(g, l, state)
  local item = QUADRANTS[state.selected]
  g:text(l.m, 28, item.title, { color = BLACK })
  g:text(l.w - l.m - 42, 28, "清单", { color = BLACK })
  g:text(l.m, 52, item.tag .. " · " .. item.note, { color = BLACK })
  g:line(l.m, 78, l.w - l.m, 78,{color=BLACK})
  PkgImage.draw(g, item.icon, l.m, 96, { color = BLACK })
  g:text(l.m + 76, 106, "本象限任务", { color = BLACK })
  g:text(l.m + 76, 132, quadrant_open_count(state, state.selected) .. " 项待处理", { color = BLACK })
  for index, task in ipairs(item.tasks) do
    local y, done = 184 + (index - 1) * 100, task_done(state, state.selected, index)
    round_outline(g, l.m, y, l.w - l.m * 2, 82, 14)
    if index == state.task then g:rect(l.m + 2, y + 16, 4, 50,{fill=true,color=BLACK}) end
    g:circle(l.m + 34, y + 40, 13,{color=BLACK})
    if done then
      g:circle(l.m + 34, y + 40, 8,{fill=true,color=BLACK})
      g:text(l.m + 64, y + 22, task.title, { color = BLACK })
      g:text(l.m + 64, y + 48, "已完成", { color = BLACK })
    else
      g:text(l.m + 64, y + 22, task.title, { color = BLACK })
      g:text(l.m + 64, y + 48, task.meta, { color = BLACK })
    end
  end
  g:line(l.m, l.footer_y - 10, l.w - l.m, l.footer_y - 10,{color=BLACK})
  g:text(center_x(l, "选择任务 · OK 勾选 · BACK 返回"), l.footer_y + 10, "选择任务 · OK 勾选 · BACK 返回", { color = BLACK })
end

function on_load(ctx)
  planner_state(ctx)
  ctx:set_tick(0); ctx:invalidate()
end

function on_input(ctx, ev)
  local state, l, changed = planner_state(ctx), layout(ctx), false
  if ev.type == "key" and ev.phase == "down" then
    if state.page == "detail" then
      if ev.key == "up" then state.task = state.task > 1 and state.task - 1 or #QUADRANTS[state.selected].tasks; changed = true
      elseif ev.key == "down" then state.task = state.task % #QUADRANTS[state.selected].tasks + 1; changed = true
      elseif ev.key == "ok" then toggle_task(state); changed = true
      elseif ev.key == "back" then state.page = "home"; changed = true end
    elseif ev.key == "left" then state.selected = state.selected % 2 == 0 and state.selected - 1 or state.selected; changed = true
    elseif ev.key == "right" then state.selected = state.selected % 2 == 1 and state.selected + 1 or state.selected; changed = true
    elseif ev.key == "up" then state.selected = state.selected > 2 and state.selected - 2 or state.selected; changed = true
    elseif ev.key == "down" then state.selected = state.selected <= 2 and state.selected + 2 or state.selected; changed = true
    elseif ev.key == "ok" then state.page = "detail"; state.task = 1; changed = true
    elseif ev.key == "back" then state.selected = 1; changed = true end
  elseif (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if state.page == "detail" then
      for index = 1, #QUADRANTS[state.selected].tasks do
        local y = 184 + (index - 1) * 100
        if ev.y >= y and ev.y <= y + 82 and ev.x >= l.m and ev.x <= l.w - l.m then
          state.task = index
          if ev.x <= l.m + 64 then toggle_task(state) end
          changed = true
        end
      end
      if ev.y >= l.footer_y - 24 then state.page = "home"; changed = true end
    else
      for index = 1, 4 do
        local x, y = card_position(l, index)
        if ev.x >= x and ev.x <= x + l.card_w and ev.y >= y and ev.y <= y + l.card_h then
          state.selected, state.task, state.page = index, 1, "detail"
          changed = true
        end
      end
    end
  end
  if changed then ctx:invalidate() end
  return changed
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local state, l = planner_state(ctx), layout(ctx)
  g:clear(WHITE)
  if state.page == "detail" then draw_detail(g, l, state); return end
  draw_header(g, l, state)
  for index = 1, 4 do draw_card(g, l, state, index) end
  draw_summary(g, l, state)
  g:line(l.m, l.footer_y - 10, l.w - l.m, l.footer_y - 10,{color=BLACK})
  g:text(center_x(l, "方向键选择 · OK 查看任务"), l.footer_y + 10, "方向键选择 · OK 查看任务", { color = BLACK })
end
