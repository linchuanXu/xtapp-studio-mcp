local PkgImage = require("pkg_image")
-- 果蔬消消乐：X4 Pro 竖屏经典交换三消。
-- 规则、关卡与绘制分离；所有随机局面都可由关卡 seed 复现。

local Engine = require("domain.match3_engine")
local Levels = require("data.levels")

local SCREEN_W, SCREEN_H = 480, 800
-- 448px 宽的 7×7 棋盘几乎铺满 X4 Pro，但仍留出安全边与底部道具区。
local CELL, TILE = 64, 62
local BOARD_X, BOARD_Y = 16, 188
local BOARD_SIZE = CELL * 7
local TILE_KEYS = {
  [1] = "tile_apple", [2] = "tile_grape", [3] = "tile_cherry",
  [4] = "tile_carrot", [5] = "tile_corn", [6] = "tile_mushroom",
}
local SPECIAL_KEYS = { row = "tile_row", col = "tile_col", blast = "tile_blast", color = "tile_color" }
local COMBO_LABELS = {
  line_line = "十字火箭！", line_blast = "火箭爆破！", blast_blast = "双重爆破！",
  color_normal = "同类全收！", color_line = "满屏火箭！", color_blast = "满屏爆破！",
  color_color = "超级清屏！",
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, item in pairs(value) do out[key] = copy(item) end
  return out
end

local function inside(x, y, rx, ry, width, height)
  return x >= rx and x <= rx + width and y >= ry and y <= ry + height
end

local function point_id(row, col) return row .. ":" .. col end

local function find_point(points, row, col)
  for index, point in ipairs(points or {}) do
    if point.row == row and point.col == col then return point, index end
  end
  return nil
end

local function text_width(value)
  local units, index = 0, 1
  value = tostring(value or "")
  while index <= #value do
    local byte = string.byte(value, index)
    if byte < 128 then units, index = units + 6, index + 1
    else
      units = units + 12
      index = index + (byte < 224 and 2 or (byte < 240 and 3 or 4))
    end
  end
  return units
end

local function center(g, x, y, value, color)
  g:text(x - math.floor(text_width(value) / 2), y, value, { color = color or 15 })
end

local function two_lines(value, max_units)
  value, max_units = tostring(value or ""), max_units or 168
  local units, index = 0, 1
  while index <= #value do
    local byte = string.byte(value, index)
    local step, width = (byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))), (byte < 128 and 6 or 12)
    if units + width > max_units then
      local second, second_units, second_index = string.sub(value, index), 0, index
      while second_index <= #value do
        local next_byte = string.byte(value, second_index)
        local next_step, next_width = (next_byte < 128 and 1 or (next_byte < 224 and 2 or (next_byte < 240 and 3 or 4))), (next_byte < 128 and 6 or 12)
        if second_units + next_width > max_units - 12 then
          return string.sub(value, 1, index - 1), string.sub(value, index, second_index - 1) .. "…"
        end
        second_units, second_index = second_units + next_width, second_index + next_step
      end
      return string.sub(value, 1, index - 1), second
    end
    units, index = units + width, index + step
  end
  return value, nil
end

local function draw_action(g, x, y, asset)
  PkgImage.draw(g, asset, x, y)
end

-- 与斗地主相同：XIC 按钮先落在各自的白色圆角衬底上，
-- 而不是把整块页面底部变成操作台。这样背景仍是场景，按钮仍有实体感。
local function draw_button_plate(g, x, y, width, height)
  local radius = 16
  g:rect(x + radius, y, width - radius * 2, height,{fill=true,color=0})
  g:rect(x, y + radius, width, height - radius * 2,{fill=true,color=0})
  g:circle(x + radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + radius, y + height - 1 - radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + height - 1 - radius, radius,{fill=true,color=0})
end

local function draw_menu_action(g, y, asset)
  draw_button_plate(g, 90, y, 300, 64)
  draw_action(g, 90, y, asset)
end

local function initial_state()
  return {
    screen = "menu", level = 1, unlocked = 1, stars = {}, best_score = {},
    board = nil, goals = {}, selected = nil, score = 0, moves_left = 0,
    seed = 1, ice = {}, locks = {}, rocks = {}, weeds = {}, drops = {}, dropped = 0,
    tools = { hint = 1, shuffle = 1 }, tool_base = { hint = 1, shuffle = 1 }, reserve = { hint = 0, shuffle = 0 },
    reward_note = nil, effect = nil, animation = nil, message = "",
  }
end

local function state(ctx)
  if not ctx.state.ink_match3 then ctx.state.ink_match3 = initial_state() end
  local s = ctx.state.ink_match3
  s.screen = s.screen or "menu"
  s.level = math.max(1, math.min(#Levels.levels, tonumber(s.level) or 1))
  s.unlocked = math.max(1, math.min(#Levels.levels, tonumber(s.unlocked) or 1))
  s.stars, s.best_score = s.stars or {}, s.best_score or {}
  s.goals, s.tools = s.goals or {}, s.tools or { hint = 1, shuffle = 1 }
  s.tool_base, s.reserve = s.tool_base or { hint = 0, shuffle = 0 }, s.reserve or { hint = 0, shuffle = 0 }
  s.reserve.hint, s.reserve.shuffle = tonumber(s.reserve.hint) or 0, tonumber(s.reserve.shuffle) or 0
  s.ice, s.locks, s.rocks, s.weeds, s.drops = s.ice or {}, s.locks or {}, s.rocks or {}, s.weeds or {}, s.drops or {}
  return s
end

local function blocked_points(s)
  local out = {}
  for _, source in ipairs({ s.rocks or {}, s.weeds or {} }) do
    for _, point in ipairs(source) do out[#out + 1] = { row = point.row, col = point.col } end
  end
  return out
end

local function make_goals(level)
  local goals = {}
  for index, goal in ipairs(level.goals) do
    goals[index] = copy(goal)
    goals[index].done = 0
  end
  return goals
end

local function begin_level(s, level_id)
  local level = Levels.get(level_id)
  if not level then return false end
  s.level = level_id
  s.seed = level.seed
  s.ice, s.locks, s.rocks, s.weeds, s.drops = copy(level.ink), copy(level.locks), copy(level.rocks), copy(level.weeds), copy(level.drops)
  s.board, s.seed = Engine.new_board(level.board.rows, level.board.cols, level.board.symbols, s.seed, blocked_points(s))
  s.goals, s.score, s.moves_left, s.dropped = make_goals(level), 0, level.moves, 0
  s.tool_base = copy(level.tools)
  s.tools = {
    hint = (s.tool_base.hint or 0) + (s.reserve.hint or 0),
    shuffle = (s.tool_base.shuffle or 0) + (s.reserve.shuffle or 0),
  }
  s.selected, s.effect, s.reward_note, s.animation = nil, nil, nil, nil
  s.screen = level.tutorial and "brief" or "play"
  -- 教程只决定是否展示关前信息，不作为底部状态文字；
  -- 开局应把注意力留给棋盘，而不是重复一句玩法说明。
  s.message = ""
  return true
end

local function goal_value(s, goal)
  if goal.type == "score" then return s.score end
  if goal.type == "ink" then
    local remaining = 0
    for _, point in ipairs(s.ice) do remaining = remaining + (point.layers or 1) end
    return math.max(0, goal.amount - remaining)
  end
  if goal.type == "drop" then return s.dropped or 0 end
  return goal.done or 0
end

local function goals_complete(s)
  for _, goal in ipairs(s.goals) do
    if goal_value(s, goal) < goal.amount then return false end
  end
  return true
end

local function star_count(s)
  local level = Levels.get(s.level)
  if s.score >= level.stars.three then return 3 end
  if s.score >= level.stars.two then return 2 end
  return 1
end

local function total_stars(s)
  local total = 0
  for _, amount in pairs(s.stars or {}) do total = total + (tonumber(amount) or 0) end
  return total
end

local function update_collect_goals(s, result)
  for _, wave in ipairs(result.waves or {}) do
    for _, goal in ipairs(s.goals) do
      if goal.type == "collect" then goal.done = math.min(goal.amount, (goal.done or 0) + (wave.by_kind[goal.kind] or 0)) end
    end
  end
end

local function damage_layer(points, row, col)
  local point, index = find_point(points, row, col)
  if not point then return false end
  point.layers = (point.layers or 1) - 1
  if point.layers <= 0 then table.remove(points, index) end
  return true
end

local function cleared_lookup(result)
  local out = {}
  for _, wave in ipairs(result.waves or {}) do
    for _, cell in ipairs(wave.cells or {}) do out[point_id(cell.row, cell.col)] = cell end
  end
  return out
end

local function adjacent_to_clear(clear, row, col)
  return clear[point_id(row - 1, col)] or clear[point_id(row + 1, col)] or clear[point_id(row, col - 1)] or clear[point_id(row, col + 1)]
end

local function update_obstacles(s, result)
  local clear = cleared_lookup(result)
  for id in pairs(clear) do
    local row, col = string.match(id, "^(%d+):(%d+)$")
    row, col = tonumber(row), tonumber(col)
    damage_layer(s.ice, row, col)
    damage_layer(s.locks, row, col)
  end
  local changed_blockers = false
  for _, points in ipairs({ s.rocks, s.weeds }) do
    for index = #points, 1, -1 do
      local point = points[index]
      if adjacent_to_clear(clear, point.row, point.col) then
        point.layers = (point.layers or 1) - 1
        if point.layers <= 0 then table.remove(points, index); changed_blockers = true end
      end
    end
  end
  if changed_blockers then
    Engine.Board.set_blocked(s.board, blocked_points(s))
    s.seed = Engine.Board.collapse_and_fill(s.board, s.seed)
  end
  return clear
end

local function update_drops(s, clear)
  for index = #s.drops, 1, -1 do
    local drop = s.drops[index]
    local distance = 0
    for row = drop.row + 1, s.board.rows do if clear[point_id(row, drop.col)] then distance = distance + 1 end end
    if distance > 0 then drop.row = math.min(s.board.rows, drop.row + distance) end
    if drop.row >= s.board.rows then table.remove(s.drops, index); s.dropped = (s.dropped or 0) + 1 end
  end
end

local function spread_weeds(s)
  local level = Levels.get(s.level)
  local pressure = level.pressure
  if not pressure or pressure.type ~= "weeds" then return false end
  local used = level.moves - s.moves_left
  if used <= 0 or used % pressure.every ~= 0 or #s.weeds >= pressure.max then return false end
  local occupied = {}
  for _, point in ipairs(blocked_points(s)) do occupied[point_id(point.row, point.col)] = true end
  for _, weed in ipairs(s.weeds) do
    for _, delta in ipairs({ { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }) do
      local row, col = weed.row + delta[1], weed.col + delta[2]
      if row >= 1 and row <= 7 and col >= 1 and col <= 7 and not occupied[point_id(row, col)] then
        s.weeds[#s.weeds + 1] = { row = row, col = col, layers = 1 }
        Engine.Board.set_blocked(s.board, blocked_points(s))
        s.seed = Engine.Board.collapse_and_fill(s.board, s.seed)
        return true
      end
    end
  end
  return false
end

local function point_lookup(points)
  local lookup = {}
  for _, point in ipairs(points or {}) do lookup[point_id(point.row, point.col)] = true end
  return lookup
end

local function begin_animation(s, result)
  s.animation = {
    result = result, wave = 1, board = copy(result.board_before),
    phase = "original", remaining = 500,
  }
end

local function finish_turn(s, result)
  s.moves_left = s.moves_left - 1
  s.score = s.score + (result.score or 0)
  update_collect_goals(s, result)
  local clear = update_obstacles(s, result)
  update_drops(s, clear)
  local spread = spread_weeds(s)
  local chain = #(result.waves or {})
  local label = COMBO_LABELS[result.combo]
  if not label and chain >= 2 then label = "连消 ×" .. tostring(chain) end
  if result.reshuffled then label = "自动重排" end
  if spread then label = "杂草蔓延了！" end
  if label then s.effect = { label = label, remaining = 1100 } end
  if goals_complete(s) then
    local stars = star_count(s)
    local previous_stars = s.stars[s.level] or 0
    local new_stars = math.max(0, stars - previous_stars)
    local was_unlocked = s.unlocked
    s.stars[s.level] = math.max(previous_stars, stars)
    s.best_score[s.level] = math.max(s.best_score[s.level] or 0, s.score)
    s.unlocked = math.max(s.unlocked, math.min(#Levels.levels, s.level + 1))
    local rewards = {}
    if new_stars > 0 then
      s.reserve.hint = (s.reserve.hint or 0) + 1
      rewards[#rewards + 1] = "获得 1 次提示"
    end
    if s.unlocked > was_unlocked and s.unlocked > 1 and (s.unlocked - 1) % 6 == 0 then
      s.reserve.shuffle = (s.reserve.shuffle or 0) + 1
      rewards[#rewards + 1] = "获得 1 次重排"
    end
    s.reward_note = #rewards > 0 and table.concat(rewards, "  ·  ") or "本关最高分已刷新"
    s.screen, s.message = "won", ""
  elseif s.moves_left <= 0 then
    s.reward_note = nil
    s.screen, s.message = "lost", "步数用完了"
  else
    s.message = label or ("消除 " .. tostring(result.cleared or 0) .. " 枚")
  end
end

local function try_cell(s, row, col)
  if Engine.Board.is_blocked(s.board, row, col) or find_point(s.locks, row, col) then
    s.message = find_point(s.locks, row, col) and "先消除锁链旁的果蔬" or "这里不能交换"
    return true
  end
  if not s.selected then
    s.selected = { row = row, col = col }
    s.message = "选择相邻果蔬"
    return true
  end
  local selected = s.selected
  if selected.row == row and selected.col == col then s.selected = nil; s.message = ""; return true end
  if not Engine.Board.adjacent(selected.row, selected.col, row, col) then
    s.selected = { row = row, col = col }
    s.message = "选择相邻果蔬"
    return true
  end
  local result = Engine.try_swap(s.board, selected.row, selected.col, row, col, s.seed)
  s.selected = nil
  if not result.valid then
    s.message = ""
    s.effect = { label = "换个位置", remaining = 650 }
    return true
  end
  s.seed = result.seed
  begin_animation(s, result)
  return true
end

local function use_hint(s)
  if s.selected then s.message = "先完成这次选择"; return true end
  if (s.tools.hint or 0) <= 0 then s.message = "提示用完了"; return true end
  local moves = Engine.legal_moves(s.board)
  if #moves == 0 then s.seed = Engine.reshuffle(s.board, s.seed); s.message = "自动重排"; return true end
  s.tools.hint = s.tools.hint - 1
  if (s.tool_base.hint or 0) > 0 then s.tool_base.hint = s.tool_base.hint - 1
  else s.reserve.hint = math.max(0, (s.reserve.hint or 0) - 1) end
  local move = moves[1]
  s.selected = { row = move.row1, col = move.col1, hint_row = move.row2, hint_col = move.col2 }
  s.message = "交换标出的果蔬"
  return true
end

local function use_shuffle(s)
  if (s.tools.shuffle or 0) <= 0 then s.message = "重排用完了"; return true end
  s.tools.shuffle = s.tools.shuffle - 1
  if (s.tool_base.shuffle or 0) > 0 then s.tool_base.shuffle = s.tool_base.shuffle - 1
  else s.reserve.shuffle = math.max(0, (s.reserve.shuffle or 0) - 1) end
  s.seed = Engine.reshuffle(s.board, s.seed)
  s.selected, s.message, s.effect = nil, "", { label = "已重排", remaining = 900 }
  return true
end

local function draw_goal(g, s, goal, x, y)
  local label
  if goal.type == "collect" then label = Levels.symbols[goal.kind].name
  elseif goal.type == "score" then label = "得分"
  elseif goal.type == "ink" then label = "冰层"
  else label = "菜篮" end
  local current = math.min(goal.amount, goal_value(s, goal))
  g:text(x, y, (current >= goal.amount and "完成 · " or "") .. label .. " " .. current .. "/" .. goal.amount, { color = 15 })
end

local function nearest_goal(s)
  local best, remaining
  for _, goal in ipairs(s.goals or {}) do
    local left = math.max(0, goal.amount - goal_value(s, goal))
    if left > 0 and (not remaining or left < remaining) then best, remaining = goal, left end
  end
  if not best then return "下一局冲更高分" end
  local label = best.type == "collect" and Levels.symbols[best.kind].name or (best.type == "score" and "分数" or (best.type == "ink" and "冰层" or "菜篮"))
  return label .. "还差 " .. tostring(remaining)
end

local function next_star_note(s)
  local level = Levels.get(s.level)
  if s.score < level.stars.two then
    return "再得 " .. tostring(level.stars.two - s.score) .. " 分升二星"
  end
  if s.score < level.stars.three then
    return "再得 " .. tostring(level.stars.three - s.score) .. " 分升三星"
  end
  return "已达三星"
end

local function draw_board(g, s, shown_board, animation)
  local board = shown_board or s.board
  g:rect(BOARD_X - 7, BOARD_Y - 7, BOARD_SIZE + 12, BOARD_SIZE + 12,{fill=true,color=15})
  g:rect(BOARD_X - 3, BOARD_Y - 3, BOARD_SIZE + 4, BOARD_SIZE + 4,{fill=true,color=0})
  for row = 1, 7 do
    for col = 1, 7 do
      local x, y = BOARD_X + (col - 1) * CELL, BOARD_Y + (row - 1) * CELL
      g:rect(x, y, TILE, TILE,{fill=true,color=0})
      g:rect(x, y, TILE, TILE,{color=15})
      local rock = find_point(s.rocks, row, col)
      local weed = find_point(s.weeds, row, col)
      local cell = board and board.cells[row] and board.cells[row][col]
      if animation and animation.phase == "blank" and animation.hidden[point_id(row, col)] then cell = nil end
      -- 54px artwork sits inside the 62px framed tile, leaving a four-pixel
      -- breathing edge on all sides without changing the 60px touch cell.
      if rock then PkgImage.draw(g, "ui_rock", x + 4, y + 4)
      elseif weed then PkgImage.draw(g, "ui_weed", x + 4, y + 4)
      elseif cell then
        PkgImage.draw(g, cell.special and SPECIAL_KEYS[cell.special] or TILE_KEYS[cell.kind], x + 4, y + 4)
      end
      if find_point(s.ice, row, col) then
        g:rect(x + 4, y + 4, TILE - 8, TILE - 8,{color=15})
        g:line(x + 7, y + 16, x + 24, y + 23,{color=15})
        g:line(x + 24, y + 23, x + 39, y + 10,{color=15})
      end
      if find_point(s.locks, row, col) then
        g:rect(x + 18, y + 20, 22, 20,{color=15})
        g:circle(x + 29, y + 19, 8,{color=15})
      end
      if find_point(s.drops, row, col) then PkgImage.draw(g, "ui_basket", x + 4, y + 4) end
      if s.selected and ((s.selected.row == row and s.selected.col == col) or (s.selected.hint_row == row and s.selected.hint_col == col)) then
        g:rect(x - 2, y - 2, TILE + 4, TILE + 4,{color=15})
        g:rect(x + 3, y + 3, TILE - 6, TILE - 6,{color=15})
      end
    end
  end
end

local function draw_menu(g, s)
  -- 首页由一张完整果园场景承担氛围，不再拼贴角色头像和水果图标。
  PkgImage.draw(g, "home_orchard", 0, 0)
  -- 游戏名是独立绘制的标题徽标，而非裸文字。
  -- XIC 白色像素不透明：先贴膨胀的白色轮廓与贴身底层，
  -- 再叠细节，让底色跟着字形和叶片走而不是变成方块。
  PkgImage.draw(g, "ui_title_outline", 48, 8, { color = 0 })
  PkgImage.draw(g, "ui_title", 48, 8)
  draw_menu_action(g, 604, "btn_continue")
  draw_menu_action(g, 684, "btn_levels")
end

local function draw_levels(g, s)
  center(g, 240, 28, "果园地图", 15)
  g:line(50, 60, 430, 60,{color=15})
  -- 地图不是纯导航：把可累计的星星和储备道具常驻显示，
  -- 玩家返回这里能立刻看见自己继续闯关的收益。
  center(g, 240, 76, "★ " .. total_stars(s) .. "/" .. (#Levels.levels * 3) .. "   提示 " .. (s.reserve.hint or 0) .. "   重排 " .. (s.reserve.shuffle or 0), 15)
  for level = 1, #Levels.levels do
    local index = level - 1
    local col, row = index % 6, math.floor(index / 6)
    local x, y = 42 + col * 72, 128 + row * 96
    local open = level <= s.unlocked
    if col > 0 then g:line(x - 14, y + 28, x + 3, y + 28,{color=15}) end
    g:circle(x + 28, y + 28, 23,{fill=true,color=open and 15 or 0})
    g:circle(x + 28, y + 28, 23,{color=15})
    center(g, x + 28, y + 20, open and tostring(level) or "·", open and 0 or 15)
    if level == s.level then g:circle(x + 28, y + 28, 28,{color=15}) end
    if open and (s.stars[level] or 0) > 0 then center(g, x + 28, y + 60, string.rep("★", s.stars[level]), 15) end
    if col == 0 then g:text(2, y + 20, "第" .. tostring(row + 1) .. "章", { color = 15 }) end
  end
  draw_action(g, 90, 666, "btn_home")
end

local function draw_brief(g, s)
  local level = Levels.get(s.level)
  center(g, 240, 38, "第 " .. s.level .. " 关 · " .. level.name, 15)
  g:line(58, 70, 422, 70,{color=15})
  -- 竖屏不采用「左人物 + 右长文」：长句会在右边被裁掉，底部还会撞上状态。
  -- 角色、诀窍、步数与目标严格共享一条中轴，阅读顺序从上到下。
  PkgImage.draw(g, "hero_farmer", 166, 92)
  -- 教学句不放进关前页：它既占空间也不能代替实际操作。
  -- 这里仅保留玩家开局前必须扫到的步数和目标。
  center(g, 240, 300, "步数 " .. level.moves, 15)
  g:line(118, 328, 362, 328,{color=15})
  center(g, 240, 348, "丰收目标", 15)
  -- 后期关卡会有六个收集目标。两列三行让信息完整保留，
  -- 同时不挤占“开始挑战”的明确触控区。
  if #s.goals > 3 then
    for index, goal in ipairs(s.goals) do
      local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
      draw_goal(g, s, goal, 74 + col * 190, 384 + row * 30)
    end
  else
    for index, goal in ipairs(s.goals) do draw_goal(g, s, goal, 170, 384 + (index - 1) * 32) end
  end
  draw_action(g, 90, 522, "btn_start")
  draw_action(g, 90, 608, "btn_back")
end

local function draw_play(g, s)
  local level = Levels.get(s.level)
  g:text(18, 54, "第 " .. s.level .. " 关 · " .. level.name, { color = 15 })
  PkgImage.draw(g, "ui_pause", 416, 32)
  g:line(18, 82, 462, 82,{color=15})
  -- 顶部只分成「局面」与「目标」两组，避免奖杯、果蔬、文字三方挤在一起。
  g:text(28, 102, "步数  " .. tostring(s.moves_left), { color = 15 })
  g:text(28, 128, "得分  " .. tostring(s.score), { color = 15 })
  g:line(190, 94, 190, 162,{color=15})
  PkgImage.draw(g, "tile_apple", 210, 100)
  g:text(270, 100, "丰收目标", { color = 15 })
  local shown = math.min(3, #s.goals)
  for index = 1, shown do
    draw_goal(g, s, s.goals[index], 270, 122 + (index - 1) * 20)
  end
  if #s.goals > shown then g:text(372, 162, "＋" .. (#s.goals - shown), { color = 15 }) end
  local animation = s.animation
  local settled = animation and animation.phase == "settled" and animation.result.waves[animation.wave].board_after
  draw_board(g, s, settled or (animation and animation.board) or nil, animation)
  draw_action(g, 36, 686, "btn_hint")
  draw_action(g, 248, 686, "btn_shuffle")
  center(g, 134, 752, "×" .. tostring(s.tools.hint or 0), 15)
  center(g, 346, 752, "×" .. tostring(s.tools.shuffle or 0), 15)
  if s.message and s.message ~= "" then
    local status, overflow = two_lines(s.message, 300)
    center(g, 240, 776, status .. (overflow and "…" or ""), 15)
  end
  if s.effect then
    g:rect(74, 390, 332, 88,{fill=true,color=15})
    g:rect(82, 398, 316, 72,{fill=true,color=0})
    PkgImage.draw(g, "tile_color", 92, 408)
    center(g, 260, 422, s.effect.label, 15)
  end
end

local function draw_rules(g)
  center(g, 240, 40, "玩法说明", 15)
  g:line(58, 68, 422, 68,{color=15})
  PkgImage.draw(g, "prop_water", 54, 96)
  PkgImage.draw(g, "tile_apple", 120, 124)
  g:text(190, 118, "先交换相邻的两枚果蔬", { color = 15 })
  g:text(190, 148, "横竖三个相同，就能收获", { color = 15 })
  g:line(190, 178, 430, 178,{color=15})
  PkgImage.draw(g, "tile_row", 52, 212)
  g:text(130, 220, "四连 · 生成横纵火箭", { color = 15 })
  PkgImage.draw(g, "tile_blast", 52, 282)
  g:text(130, 290, "T / L 形 · 范围爆炸", { color = 15 })
  PkgImage.draw(g, "tile_color", 52, 352)
  g:text(130, 360, "五连 · 生成彩虹果篮", { color = 15 })
  PkgImage.draw(g, "ui_basket", 52, 422)
  g:text(130, 430, "步数内完成全部丰收目标", { color = 15 })
  draw_action(g, 90, 538, "btn_home")
end

local function draw_pause(g, s)
  PkgImage.draw(g, "hero_farmer", 166, 48)
  center(g, 240, 214, "暂停", 15)
  center(g, 240, 244, "第 " .. s.level .. " 关", 15)
  draw_action(g, 90, 276, "btn_resume")
  draw_action(g, 90, 356, "btn_restart")
  draw_action(g, 90, 436, "btn_levels")
  draw_action(g, 90, 508, "btn_home")
end

local function draw_result(g, s, won)
  -- 人物与结果徽章分列，不再把两张 148/160px 素材压在同一中心点。
  PkgImage.draw(g, "hero_farmer", 42, 86)
  PkgImage.draw(g, won and "ui_victory" or "ui_defeat", 278, 80)
  center(g, 240, 270, won and "大丰收！" or "还差一点", 15)
  if won then
    center(g, 240, 300, string.rep("★", star_count(s)), 15)
    center(g, 240, 326, "得分 " .. s.score .. " · 剩余 " .. s.moves_left .. " 步", 15)
    center(g, 240, 350, next_star_note(s), 15)
    center(g, 240, 374, s.reward_note or "继续收集更多星星", 15)
    draw_action(g, 90, 402, s.level < #Levels.levels and "btn_next" or "btn_home")
    draw_action(g, 90, 474, "btn_again")
  else
    center(g, 240, 306, "离丰收只差一点", 15)
    center(g, 240, 334, nearest_goal(s), 15)
    draw_action(g, 90, 402, "btn_again")
  end
  draw_action(g, 90, 546, "btn_levels")
end

-- 浏览器预览与自动化会读取这份伴随信息；真机忽略它，真实输入仍由 on_input 处理。

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s = state(ctx)
  g:clear(0)
  if s.screen == "menu" then draw_menu(g, s)
  elseif s.screen == "levels" then draw_levels(g, s)
  elseif s.screen == "brief" then draw_brief(g, s)
  elseif s.screen == "play" then draw_play(g, s)
  elseif s.screen == "rules" then draw_rules(g)
  elseif s.screen == "pause" then draw_pause(g, s)
  elseif s.screen == "won" then draw_result(g, s, true)
  elseif s.screen == "lost" then draw_result(g, s, false) end
end

local function touch_menu(s, ev)
  if inside(ev.x, ev.y, 90, 604, 300, 64) then return begin_level(s, s.level) end
  if inside(ev.x, ev.y, 90, 684, 300, 64) then s.screen = "levels"; return true end
  return false
end

local function touch_levels(s, ev)
  if inside(ev.x, ev.y, 90, 666, 300, 64) then s.screen = "menu"; return true end
  for level = 1, #Levels.levels do
    local index = level - 1
    local x, y = 42 + (index % 6) * 72, 128 + math.floor(index / 6) * 96
    if inside(ev.x, ev.y, x, y, 56, 72) then
      if level <= s.unlocked then return begin_level(s, level) end
      s.message = "请先完成前一关"
      return true
    end
  end
  return false
end

local function touch_play(s, ev)
  if inside(ev.x, ev.y, 416, 32, 48, 48) then s.screen = "pause"; return true end
  if inside(ev.x, ev.y, 36, 686, 196, 58) then return use_hint(s) end
  if inside(ev.x, ev.y, 248, 686, 196, 58) then return use_shuffle(s) end
  if inside(ev.x, ev.y, BOARD_X, BOARD_Y, BOARD_SIZE, BOARD_SIZE) then
    local col = math.floor((ev.x - BOARD_X) / CELL) + 1
    local row = math.floor((ev.y - BOARD_Y) / CELL) + 1
    if row <= 7 and col <= 7 then return try_cell(s, row, col) end
  end
  return false
end

function on_input(ctx, ev)
  local s = state(ctx)
  if not (ev.type == "pointer" and ev.phase == "up") or ev.gesture ~= "tap" then return false end
  if s.effect or s.animation then ctx:invalidate(); return true end
  local handled = false
  if s.screen == "menu" then handled = touch_menu(s, ev)
  elseif s.screen == "levels" then handled = touch_levels(s, ev)
  elseif s.screen == "brief" then
    if inside(ev.x, ev.y, 90, 522, 300, 64) then s.screen = "play"; handled = true
    elseif inside(ev.x, ev.y, 90, 608, 300, 64) then s.screen = "levels"; handled = true end
  elseif s.screen == "play" then handled = touch_play(s, ev)
  elseif s.screen == "rules" then
    if inside(ev.x, ev.y, 90, 538, 300, 64) then s.screen = "menu"; handled = true end
  elseif s.screen == "pause" then
    if inside(ev.x, ev.y, 90, 276, 300, 64) then s.screen = "play"; handled = true
    elseif inside(ev.x, ev.y, 90, 356, 300, 64) then handled = begin_level(s, s.level)
    elseif inside(ev.x, ev.y, 90, 436, 300, 64) then s.screen = "levels"; handled = true
    elseif inside(ev.x, ev.y, 90, 508, 300, 64) then s.screen = "menu"; handled = true end
  elseif s.screen == "won" then
    if inside(ev.x, ev.y, 90, 402, 300, 64) then
      if s.level < #Levels.levels then handled = begin_level(s, s.level + 1) else s.screen = "menu"; handled = true end
    elseif inside(ev.x, ev.y, 90, 474, 300, 64) then handled = begin_level(s, s.level)
    elseif inside(ev.x, ev.y, 90, 546, 300, 64) then s.screen = "levels"; handled = true end
  elseif s.screen == "lost" then
    if inside(ev.x, ev.y, 90, 402, 300, 64) then handled = begin_level(s, s.level)
    elseif inside(ev.x, ev.y, 90, 546, 300, 64) then s.screen = "levels"; handled = true end
  end
  if handled then ctx:invalidate() end
  return handled
end

function on_leave(ctx) ctx:set_tick(0) end
function on_load(ctx)
  state(ctx); ctx:invalidate()
  ctx:set_tick(100); ctx:invalidate()
end

function on_tick(ctx, dt)
  local s = state(ctx)
  if s.animation then
    local animation = s.animation
    animation.remaining = (animation.remaining or 500) - math.max(80, tonumber(dt) or 120)
    if animation.remaining <= 0 then
      if animation.phase == "original" then
        animation.hidden = point_lookup(animation.result.waves[animation.wave].cells)
        animation.phase, animation.remaining = "blank", 1000
      elseif animation.phase == "blank" then
        animation.phase, animation.remaining = "settled", 500
      elseif animation.wave < #animation.result.waves then
        animation.wave = animation.wave + 1
        animation.board = copy(animation.result.waves[animation.wave - 1].board_after)
        animation.hidden, animation.phase, animation.remaining = nil, "original", 500
      else
        local result = animation.result
        s.animation = nil
        finish_turn(s, result)
      end
    end
    ctx:invalidate()
    return
  end
  if s.effect then
    s.effect.remaining = s.effect.remaining - math.max(80, tonumber(dt) or 120)
    if s.effect.remaining <= 0 then s.effect = nil end
    ctx:invalidate()
  end
end
