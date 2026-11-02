-- 五子棋·墨局
-- CrossMux Gomoku 的功能级 Lua 重实现；本文件只使用 XTApp 2.x 公开 API。

local SCREEN = { TITLE = "title", MENU = "menu", DIFFICULTY = "difficulty", GAME = "game", PAUSE = "pause", RESULT = "result", STATS = "stats" }
local BLACK, WHITE, EMPTY = 1, 2, 0
local WIN_LEN = 5
local DIRECTIONS = {{0, 1}, {1, 0}, {1, 1}, {-1, 1}}
local DESIGN_WIDTH, DESIGN_HEIGHT = 480, 800
local WATCHDOG_MAX_SEARCH_MS = 900

-- 保留参考实现的搜索轮廓。Lua 版本将一回合计算安排在 tick 中，避免阻塞输入。
local AI_CONFIGS = {
  easy = { depth = 2, radius = 1, branch = 8, budget_ms = 600, node_limit = 80, jitter = 30, suboptimal = 25 },
  medium = { depth = 4, radius = 2, branch = 12, budget_ms = 2000, node_limit = 120, jitter = 0, suboptimal = 0 },
  hard = { depth = 6, radius = 2, branch = 16, budget_ms = 4000, node_limit = 160, jitter = 0, suboptimal = 0 },
}
local RUN_SCORE = {
  [1] = { [0] = 0, [1] = 0, [2] = 0 },
  [2] = { [0] = 0, [1] = 10, [2] = 100 },
  [3] = { [0] = 0, [1] = 1000, [2] = 10000 },
  [4] = { [0] = 0, [1] = 100000, [2] = 1000000 },
  [5] = { [0] = 10000000, [1] = 10000000, [2] = 10000000 },
}

local function text_units(value)
  local units, index = 0, 1
  value = tostring(value or "")
  while index <= #value do
    local byte = string.byte(value, index)
    units = units + ((byte or 0) < 128 and 1 or 2)
    index = index + (((byte or 0) < 128) and 1 or ((byte or 0) < 224 and 2 or ((byte or 0) < 240 and 3 or 4)))
  end
  return units
end

local function center(g, x, y, value, color)
  g:text(x - text_units(value) * 5, y, value, { color = color or 15 })
end

local function inside(x, y, rx, ry, width, height)
  return x >= rx and x <= rx + width and y >= ry and y <= ry + height
end

-- 所有界面坐标在 480×800 逻辑画布中定义；按真实屏幕等比缩放并居中，横竖屏均不会裁切棋盘或触控区域。
local function viewport_layout(ctx)
  local width, height = ctx.screen.width, ctx.screen.height
  local scale = math.min(width / DESIGN_WIDTH, height / DESIGN_HEIGHT)
  return { scale = scale, offset_x = math.floor((width - DESIGN_WIDTH * scale) / 2), offset_y = math.floor((height - DESIGN_HEIGHT * scale) / 2) }
end

local function virtual_point(layout, x, y)
  return (x - layout.offset_x) / layout.scale, (y - layout.offset_y) / layout.scale
end

local function scaled_canvas(g, layout)
  local scale, ox, oy = layout.scale, layout.offset_x, layout.offset_y
  return {
    clear = function(_, color) return g:clear(color) end,
    rect = function(_, x, y, width, height, ...) return g:rect(ox + x * scale, oy + y * scale, width * scale, height * scale, ...) end,
    line = function(_, x1, y1, x2, y2, ...) return g:line(ox + x1 * scale, oy + y1 * scale, ox + x2 * scale, oy + y2 * scale, ...) end,
    circle = function(_, x, y, radius, ...) return g:circle(ox + x * scale, oy + y * scale, radius * scale, ...) end,
    text = function(_, x, y, value, options) return g:text(ox + x * scale, oy + y * scale, value, options) end,
  }
end

local function default_stats()
  return { started_15 = 0, started_9 = 0, black_wins_15 = 0, white_wins_15 = 0, draws_15 = 0,
    black_wins_9 = 0, white_wins_9 = 0, draws_9 = 0, best_15 = 0, best_9 = 0 }
end

local function state(ctx)
  local saved = ctx.state.gomoku
  if type(saved) ~= "table" then
    saved = { screen = SCREEN.TITLE, stats = default_stats(), menu_sel = 1 }
    ctx.state.gomoku = saved
  end
  if type(saved.stats) ~= "table" then saved.stats = default_stats() end
  if not saved.screen then saved.screen = SCREEN.TITLE end
  return saved
end

local function cells_total(game) return game.size * game.size end
local function index_of(game, row, column) return row * game.size + column + 1 end
local function row_of(game, index) return math.floor((index - 1) / game.size) end
local function col_of(game, index) return (index - 1) % game.size end
local function other(side) return side == BLACK and WHITE or BLACK end

local function board_value(game, row, column)
  if row < 0 or column < 0 or row >= game.size or column >= game.size then return nil end
  return game.board[index_of(game, row, column)] or EMPTY
end

local function set_board(game, row, column, value)
  game.board[index_of(game, row, column)] = value
end

local function grid_for(size)
  if size == 9 then return 60, 112, 45 end
  return 23, 90, 31
end

local function fresh_game(saved, mode, size, level, now)
  local x, y, pitch = grid_for(size)
  local game = { mode = mode, level = level or "medium", size = size, board = {}, moves = {}, turn = BLACK,
    grid_x = x, grid_y = y, pitch = pitch, cursor_row = math.floor(size / 2), cursor_col = math.floor(size / 2),
    elapsed_ms = 0, last_clock = now or 0, ai_pending = false, awaiting_player_refresh = false, result = nil, win_line = nil }
  for i = 1, size * size do game.board[i] = EMPTY end
  saved.game = game
  saved.screen = SCREEN.GAME
  local key = size == 9 and "started_9" or "started_15"
  saved.stats[key] = (saved.stats[key] or 0) + 1
  return game
end

local function normalize_game(game)
  if type(game) ~= "table" or (game.size ~= 9 and game.size ~= 15) then return false end
  game.board = type(game.board) == "table" and game.board or {}
  for i = 1, cells_total(game) do if game.board[i] == nil then game.board[i] = EMPTY end end
  game.moves = type(game.moves) == "table" and game.moves or {}
  game.turn = game.turn == WHITE and WHITE or BLACK
  local x, y, pitch = grid_for(game.size)
  game.grid_x, game.grid_y, game.pitch = x, y, pitch
  game.cursor_row = math.max(0, math.min(game.size - 1, tonumber(game.cursor_row) or math.floor(game.size / 2)))
  game.cursor_col = math.max(0, math.min(game.size - 1, tonumber(game.cursor_col) or math.floor(game.size / 2)))
  game.elapsed_ms = tonumber(game.elapsed_ms) or 0
  game.awaiting_player_refresh = game.awaiting_player_refresh == true
  return true
end

local function count_dir(game, row, column, dr, dc, side)
  local count = 0
  row, column = row + dr, column + dc
  while board_value(game, row, column) == side do
    count = count + 1
    row, column = row + dr, column + dc
  end
  return count, board_value(game, row, column) == EMPTY
end

local function would_win(game, row, column, side)
  for _, direction in ipairs(DIRECTIONS) do
    local forward = count_dir(game, row, column, direction[1], direction[2], side)
    local backward = count_dir(game, row, column, -direction[1], -direction[2], side)
    if forward + backward + 1 >= WIN_LEN then return true end
  end
  return false
end

local function win_line(game, row, column, side)
  for _, direction in ipairs(DIRECTIONS) do
    local fwd, _ = count_dir(game, row, column, direction[1], direction[2], side)
    local bwd, _ = count_dir(game, row, column, -direction[1], -direction[2], side)
    if fwd + bwd + 1 >= WIN_LEN then
      return { row - bwd * direction[1], column - bwd * direction[2], row + fwd * direction[1], column + fwd * direction[2] }
    end
  end
  return nil
end

local function point_score(game, row, column, side)
  local total = 0
  for _, direction in ipairs(DIRECTIONS) do
    local forward, forward_open = count_dir(game, row, column, direction[1], direction[2], side)
    local backward, backward_open = count_dir(game, row, column, -direction[1], -direction[2], side)
    local length = math.min(5, forward + backward + 1)
    local openness = (forward_open and 1 or 0) + (backward_open and 1 or 0)
    total = total + (RUN_SCORE[length][openness] or 0)
  end
  return total
end

local function has_neighbor(game, row, column, radius)
  for dr = -radius, radius do
    for dc = -radius, radius do
      if not (dr == 0 and dc == 0) and board_value(game, row + dr, column + dc) ~= nil and board_value(game, row + dr, column + dc) ~= EMPTY then
        return true
      end
    end
  end
  return false
end

local function candidates(game, radius)
  local list = {}
  for row = 0, game.size - 1 do
    for column = 0, game.size - 1 do
      if board_value(game, row, column) == EMPTY and has_neighbor(game, row, column, radius) then
        list[#list + 1] = { row = row, column = column }
      end
    end
  end
  if #list == 0 then list[1] = { row = math.floor(game.size / 2), column = math.floor(game.size / 2) } end
  return list
end

local function rank_candidates(game, list, side)
  local opponent = other(side)
  for _, candidate in ipairs(list) do
    candidate.score = point_score(game, candidate.row, candidate.column, side) + point_score(game, candidate.row, candidate.column, opponent)
  end
  table.sort(list, function(a, b)
    if a.score == b.score then
      local center = math.floor(game.size / 2)
      local da = math.abs(a.row - center) + math.abs(a.column - center)
      local db = math.abs(b.row - center) + math.abs(b.column - center)
      return da < db
    end
    return a.score > b.score
  end)
  return list
end

local function board_score(game)
  local ai_score, human_score = 0, 0
  for _, direction in ipairs(DIRECTIONS) do
    for row = 0, game.size - 1 do
      for column = 0, game.size - 1 do
        local side = board_value(game, row, column)
        if side ~= EMPTY and board_value(game, row - direction[1], column - direction[2]) ~= side then
          local length, rr, cc = 1, row + direction[1], column + direction[2]
          while board_value(game, rr, cc) == side do
            length, rr, cc = length + 1, rr + direction[1], cc + direction[2]
          end
          local back_open = board_value(game, row - direction[1], column - direction[2]) == EMPTY
          local forward_open = board_value(game, rr, cc) == EMPTY
          local openness = (back_open and 1 or 0) + (forward_open and 1 or 0)
          local score = RUN_SCORE[math.min(WIN_LEN, length)][openness] or 0
          if side == WHITE then ai_score = ai_score + score else human_score = human_score + score end
        end
      end
    end
  end
  return ai_score - math.floor(human_score * 1.2)
end

local function out_of_budget(search)
  search.nodes = search.nodes + 1
  if search.watchdog then search.watchdog:feed() end
  if search.nodes >= search.config.node_limit then search.timed_out = true end
  if not search.timed_out and search.now() - search.started_ms >= search.budget_ms then
    search.timed_out = true
  end
  return search.timed_out
end

local function alpha_beta(game, side, depth, alpha, beta, search)
  if out_of_budget(search) then return 0 end
  if depth == 0 then
    local score = board_score(game)
    return side == WHITE and score or -score
  end
  local list = rank_candidates(game, candidates(game, search.config.radius), side)
  local limit = math.min(#list, search.config.branch)
  if limit == 0 then return 0 end
  local best = -10000001
  for i = 1, limit do
    if out_of_budget(search) then break end
    local candidate = list[i]
    set_board(game, candidate.row, candidate.column, side)
    local score
    if would_win(game, candidate.row, candidate.column, side) then
      score = 10000000 - (search.config.depth - depth)
    else
      score = -alpha_beta(game, other(side), depth - 1, -beta, -alpha, search)
    end
    set_board(game, candidate.row, candidate.column, EMPTY)
    if search.timed_out then break end
    if score > best then best = score end
    if score > alpha then alpha = score end
    if alpha >= beta then break end
  end
  return best
end

local function iterative_search(game, list, config, now, watchdog)
  local search = {
    config = config, now = now, started_ms = now(), nodes = 0, timed_out = false,
    watchdog = watchdog, budget_ms = math.min(config.budget_ms, WATCHDOG_MAX_SEARCH_MS),
  }
  local limit = math.min(#list, config.branch)
  local best, best_score = list[1], -10000001
  local first_depth = config.depth <= 2 and config.depth or 2
  for depth = first_depth, config.depth, 2 do
    local current_best, current_score, alpha = list[1], -10000001, -10000001
    for i = 1, limit do
      if out_of_budget(search) then break end
      local candidate = list[i]
      set_board(game, candidate.row, candidate.column, WHITE)
      local score
      if would_win(game, candidate.row, candidate.column, WHITE) then
        score = 10000000 - (config.depth - depth)
      else
        score = -alpha_beta(game, BLACK, depth - 1, -10000001, -alpha, search)
      end
      set_board(game, candidate.row, candidate.column, EMPTY)
      if search.timed_out then break end
      if score > current_score then current_best, current_score = candidate, score end
      if score > alpha then alpha = score end
    end
    if search.timed_out then break end
    best, best_score = current_best, current_score
    if best_score >= 9999000 then break end
  end
  return best, best_score
end

local function choose_ai_move(game, now, watchdog)
  local config = AI_CONFIGS[game.level] or AI_CONFIGS.medium
  local list = candidates(game, config.radius)
  for _, candidate in ipairs(list) do
    if would_win(game, candidate.row, candidate.column, WHITE) then return candidate end
  end
  for _, candidate in ipairs(list) do
    if would_win(game, candidate.row, candidate.column, BLACK) then return candidate end
  end
  rank_candidates(game, list, WHITE)
  local best, best_score = iterative_search(game, list, config, now, watchdog)
  if config.jitter > 0 and best_score < 5000000 then
    local limit = math.min(#list, config.branch)
    for order = 1, limit do
      local candidate = list[order]
      local noise = ((order * 17 + #game.moves * 13) % 61) - 30
      candidate.score = candidate.score + math.floor(math.max(20, candidate.score) * config.jitter / 100) * noise / 30
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    best = list[1]
    if limit >= 2 and ((#game.moves * 31 + 17) % 100) < config.suboptimal then best = list[2] end
  end
  return best or list[1]
end

local function finish_game(saved, game, winner)
  game.result = winner or "draw"
  game.ai_pending = false
  saved.screen = SCREEN.RESULT
  saved.result_sel = 1
  local suffix = game.size == 9 and "_9" or "_15"
  if winner == "black" then saved.stats["black_wins" .. suffix] = (saved.stats["black_wins" .. suffix] or 0) + 1
  elseif winner == "white" then saved.stats["white_wins" .. suffix] = (saved.stats["white_wins" .. suffix] or 0) + 1
  else saved.stats["draws" .. suffix] = (saved.stats["draws" .. suffix] or 0) + 1 end
  local best_key = "best" .. suffix
  local elapsed = math.floor((game.elapsed_ms or 0) / 1000)
  if elapsed > 0 and ((saved.stats[best_key] or 0) == 0 or elapsed < saved.stats[best_key]) then saved.stats[best_key] = elapsed end
end

local function place(saved, game, row, column)
  if game.result or game.ai_pending or row < 0 or column < 0 or row >= game.size or column >= game.size then return false end
  if board_value(game, row, column) ~= EMPTY then return false end
  local side = game.turn
  set_board(game, row, column, side)
  game.moves[#game.moves + 1] = index_of(game, row, column)
  game.cursor_row, game.cursor_col = row, column
  local line = win_line(game, row, column, side)
  if line then
    game.win_line = line
    finish_game(saved, game, side == BLACK and "black" or "white")
    return true
  end
  if #game.moves >= cells_total(game) then finish_game(saved, game, nil); return true end
  game.turn = other(side)
  if game.mode == "ai" and game.turn == WHITE then game.ai_pending = true end
  return true
end

local function undo_one(game)
  local index = game.moves[#game.moves]
  if not index then return false end
  game.board[index] = EMPTY
  game.moves[#game.moves] = nil
  game.turn = (#game.moves % 2 == 0) and BLACK or WHITE
  game.result, game.win_line, game.ai_pending = nil, nil, false
  return true
end

local function undo_turn(game)
  if not undo_one(game) then return false end
  if game.mode == "ai" and #game.moves > 0 and game.turn == WHITE then undo_one(game) end
  return true
end

local function board_point(game, x, y)
  local column = math.floor((x - game.grid_x) / game.pitch + 0.5)
  local row = math.floor((y - game.grid_y) / game.pitch + 0.5)
  if row < 0 or column < 0 or row >= game.size or column >= game.size then return nil end
  local px, py = game.grid_x + column * game.pitch, game.grid_y + row * game.pitch
  if math.abs(x - px) > game.pitch * 0.45 or math.abs(y - py) > game.pitch * 0.45 then return nil end
  return row, column
end

local function menu_row(g, y, label, subtitle, selected)
  g:rect(40, y, 400, 48,{fill=true,color=selected and 15 or 0})
  g:rect(40, y, 400, 48,{color=15})
  g:text(60, y + 9, label, { color = selected and 0 or 15 })
  if subtitle then g:text(60, y + 27, subtitle, { color = selected and 0 or 15 }) end
end

local function difficulty_row(g, y, label, subtitle, selected)
  g:rect(40, y, 400, 84,{fill=true,color=selected and 15 or 0})
  g:rect(40, y, 400, 84,{color=15})
  g:text(60, y + 16, label, { color = selected and 0 or 15 })
  g:text(60, y + 48, subtitle, { color = selected and 0 or 15 })
end

local function draw_title(g)
  g:clear(0)
  g:rect(18, 18, 444, 46,{fill=true,color=15})
  g:text(34, 34, "五子棋·墨局", { color = 0 })
  g:text(382, 34, "开局", { color = 0 })

  local boardX, boardY, pitch = 104, 154, 34
  g:rect(78, 128, 324, 324,{color=15})
  for i = 0, 8 do
    g:line(boardX, boardY + i * pitch, boardX + 8 * pitch, boardY + i * pitch,{color=15})
    g:line(boardX + i * pitch, boardY, boardX + i * pitch, boardY + 8 * pitch,{color=15})
  end
  for _, point in ipairs({{2,2}, {2,6}, {4,4}, {6,2}, {6,6}}) do
    g:circle(boardX + point[2] * pitch, boardY + point[1] * pitch, 3,{fill=true,color=15})
  end
  g:circle(boardX + 4 * pitch, boardY + 4 * pitch, 14,{fill=true,color=15})
  g:circle(boardX + 5 * pitch, boardY + 5 * pitch, 14,{fill=true,color=0})
  g:circle(boardX + 5 * pitch, boardY + 5 * pitch, 14,{color=15})

  center(g, 240, 482, "五 子 棋", 15)
  center(g, 240, 510, "墨 局", 15)
  g:line(160, 544, 320, 544,{color=15})
  center(g, 240, 562, "落子成局，静候胜负", 15)
  g:rect(98, 620, 284, 62,{fill=true,color=15})
  center(g, 240, 640, "开始对局", 0)
  center(g, 240, 716, "15×15 · 9×9 · 双人 · 人机", 15)
end

local function draw_menu(saved, g)
  g:clear(0)
  g:rect(18, 18, 444, 46,{fill=true,color=15})
  g:text(34, 34, "五子棋·墨局", { color = 0 })
  g:text(330, 34, "选局", { color = 0 })
  menu_row(g, 188, "双人对弈", "15 × 15", saved.menu_sel == 1)
  menu_row(g, 260, "双人对弈", "9 × 9", saved.menu_sel == 2)
  menu_row(g, 332, "人机对弈", "15 × 15 · 选择难度", saved.menu_sel == 3)
  menu_row(g, 404, "人机对弈", "9 × 9 · 选择难度", saved.menu_sel == 4)
  menu_row(g, 476, "战绩记录", "按棋盘尺寸统计", saved.menu_sel == 5)
  if saved.game and not saved.game.result and #saved.game.moves > 0 then menu_row(g, 548, "继续对局", "保存的未结束棋局", saved.menu_sel == 6) end
  center(g, 240, 726, "方向选择 · 确认进入 · 返回退出", 15)
end

local function draw_difficulty(saved, g)
  g:clear(0)
  g:rect(18, 18, 444, 46,{fill=true,color=15})
  g:text(34, 34, "五子棋·墨局", { color = 0 })
  g:text(330, 34, "难度", { color = 0 })
  center(g, 240, 120, "AI 对弈 · " .. (saved.pending_size or 15) .. " × " .. (saved.pending_size or 15), 15)
  center(g, 240, 154, "选择 AI 难度", 15)
  difficulty_row(g, 190, "初级", "偶尔会放弃次优落点", saved.difficulty_sel == 1)
  difficulty_row(g, 286, "中级", "稳定防守与威胁推进", saved.difficulty_sel == 2)
  difficulty_row(g, 382, "高级", "更强的中心控制与双威胁", saved.difficulty_sel == 3)
  g:rect(150, 656, 180, 44,{color=15})
  center(g, 240, 670, "返回选局", 15)
  center(g, 240, 726, "点按选项开始 · Back 返回", 15)
end

local function draw_game(saved, g)
  local game = saved.game
  g:clear(0)
  g:rect(18, 16, 444, 46,{fill=true,color=15})
  local mode = game.mode == "ai" and ("人机 · " .. ({ easy = "初级", medium = "中级", hard = "高级" })[game.level]) or "双人对弈"
  g:text(30, 32, "五子棋 · " .. mode, { color = 0 })
  local seconds = math.floor((game.elapsed_ms or 0) / 1000)
  g:text(374, 32, string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60), { color = 0 })
  local end_at = (game.size - 1) * game.pitch
  for i = 0, game.size - 1 do
    g:line(game.grid_x, game.grid_y + i * game.pitch, game.grid_x + end_at, game.grid_y + i * game.pitch,{color=15})
    g:line(game.grid_x + i * game.pitch, game.grid_y, game.grid_x + i * game.pitch, game.grid_y + end_at,{color=15})
  end
  local stars = game.size == 9 and {{2,2},{2,6},{4,4},{6,2},{6,6}} or {{3,3},{3,11},{7,7},{11,3},{11,11}}
  for _, point in ipairs(stars) do g:circle(game.grid_x + point[2] * game.pitch, game.grid_y + point[1] * game.pitch, 3,{fill=true,color=15}) end
  for i = 1, #game.moves do
    local index = game.moves[i]
    local row, column = row_of(game, index), col_of(game, index)
    local x, y = game.grid_x + column * game.pitch, game.grid_y + row * game.pitch
    local radius = game.size == 9 and 17 or 12
    if game.board[index] == BLACK then g:circle(x, y, radius,{fill=true,color=15}) else g:circle(x, y, radius,{fill=true,color=0}); g:circle(x, y, radius,{color=15}) end
  end
  if game.moves[#game.moves] then
    local index = game.moves[#game.moves]
    local x, y = game.grid_x + col_of(game, index) * game.pitch, game.grid_y + row_of(game, index) * game.pitch
    g:circle(x, y, 2,{fill=true,color=game.board[index] == BLACK and 0 or 15})
  end
  if game.win_line then
    g:line(game.grid_x + game.win_line[2] * game.pitch, game.grid_y + game.win_line[1] * game.pitch, game.grid_x + game.win_line[4] * game.pitch, game.grid_y + game.win_line[3] * game.pitch,{color=15})
  end
  if not game.result and not game.ai_pending then
    local x, y = game.grid_x + game.cursor_col * game.pitch, game.grid_y + game.cursor_row * game.pitch
    local cursor_half = game.size == 9 and 12 or 14
    g:rect(x - cursor_half, y - cursor_half, cursor_half * 2, cursor_half * 2,{color=15})
  end
  g:rect(42, 552, 188, 58,{color=15})
  g:rect(250, 552, 188, 58,{color=15})
  center(g, 136, 568, "黑", 15); center(g, 136, 588, tostring(math.ceil(#game.moves / 2)), 15)
  center(g, 344, 568, "白", 15); center(g, 344, 588, tostring(math.floor(#game.moves / 2)), 15)
  if game.result then
    local title = game.result == "black" and "黑方胜" or (game.result == "white" and "白方胜" or "和棋")
    center(g, 240, 646, title .. " · 终局复盘", 15)
    local selected = saved.result_sel or 1
    g:rect(42, 674, 188, 44,{fill=(selected == 1) and true or false,color=15})
    g:rect(250, 674, 188, 44,{fill=(selected == 2) and true or false,color=15})
    center(g, 136, 686, "再来一局", selected == 1 and 0 or 15)
    center(g, 344, 686, "查看战绩", selected == 2 and 0 or 15)
    center(g, 240, 738, "方向选择 · OK 确认 · Back 选局", 15)
  else
    if game.ai_pending then center(g, 240, 646, "AI 正在推演…", 15)
    else center(g, 240, 646, game.turn == BLACK and "黑方落子" or "白方落子", 15) end
    g:rect(150, 674, 180, 36,{color=15})
    center(g, 240, 684, "返回选局", 15)
    center(g, 240, 738, "点按棋盘落子 · OK 确认 · Back 菜单", 15)
  end
end

local function draw_pause(saved, g)
  draw_game(saved, g)
  g:rect(70, 286, 340, 250,{fill=true,color=0})
  g:rect(70, 286, 340, 250,{color=15})
  center(g, 240, 304, "对局菜单", 15)
  menu_row(g, 324, "继续对局", nil, saved.pause_sel == 1)
  menu_row(g, 366, "悔棋", saved.game.mode == "ai" and "撤回双方最近一步" or "撤回最近一步", saved.pause_sel == 2)
  menu_row(g, 412, "认输", "当前行棋方认输", saved.pause_sel == 3)
  menu_row(g, 446, "重新开始", "保留模式与难度", saved.pause_sel == 4)
  menu_row(g, 480, "返回选局", "保存后回到主菜单", saved.pause_sel == 5)
end

local function draw_result(saved, g)
  draw_game(saved, g)
end

local function draw_stats(saved, g)
  g:clear(0)
  g:rect(18, 18, 444, 46,{fill=true,color=15}); g:text(34, 34, "战绩记录", { color = 0 })
  for row, size in ipairs({15, 9}) do
    local suffix, y = size == 9 and "_9" or "_15", 154 + (row - 1) * 210
    g:rect(46, y, 388, 168,{color=15})
    center(g, 240, y + 18, size .. " × " .. size, 15)
    center(g, 240, y + 54, "已开局 " .. (saved.stats["started" .. suffix] or 0), 15)
    center(g, 240, y + 84, "黑胜 " .. (saved.stats["black_wins" .. suffix] or 0) .. "  白胜 " .. (saved.stats["white_wins" .. suffix] or 0), 15)
    center(g, 240, y + 114, "和棋 " .. (saved.stats["draws" .. suffix] or 0) .. "  最快 " .. (saved.stats["best" .. suffix] or 0) .. " 秒", 15)
  end
  center(g, 240, 730, saved.stats_return_screen == SCREEN.RESULT and "点按或 Back 返回复盘" or "点按或 Back 返回", 15)
end

local function select_menu(saved, index, now)
  if index == 1 then fresh_game(saved, "pvp", 15, "medium", now)
  elseif index == 2 then fresh_game(saved, "pvp", 9, "medium", now)
  elseif index == 3 then saved.pending_size, saved.difficulty_sel, saved.screen = 15, 2, SCREEN.DIFFICULTY
  elseif index == 4 then saved.pending_size, saved.difficulty_sel, saved.screen = 9, 2, SCREEN.DIFFICULTY
  elseif index == 5 then saved.screen = SCREEN.STATS
  elseif index == 6 and saved.game and not saved.game.result then saved.screen = SCREEN.GAME end
end

local function commit_player_move(ctx, saved, game, row, column)
  local changed = place(saved, game, row, column)
  if changed then
    if game.ai_pending then game.awaiting_player_refresh = true end
    ctx:invalidate()
    ctx:invalidate()
  end
  return changed
end

local function handle_game_input(ctx, saved, ev)
  local game = saved.game
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if inside(ev.x, ev.y, 150, 674, 180, 36) then
      saved.screen = SCREEN.MENU
      ctx:set_tick(0)
      ctx:invalidate()
      return true
    end
    local row, column = board_point(game, ev.x, ev.y)
    if row then return commit_player_move(ctx, saved, game, row, column) end
  elseif ev.type == "key" and ev.phase == "down" then
    if ev.key == "up" then game.cursor_row = (game.cursor_row + game.size - 1) % game.size
    elseif ev.key == "down" then game.cursor_row = (game.cursor_row + 1) % game.size
    elseif ev.key == "left" then game.cursor_col = (game.cursor_col + game.size - 1) % game.size
    elseif ev.key == "right" then game.cursor_col = (game.cursor_col + 1) % game.size
    elseif ev.key == "ok" then return commit_player_move(ctx, saved, game, game.cursor_row, game.cursor_col)
    elseif ev.key == "back" then saved.pause_sel, saved.screen = 1, SCREEN.PAUSE
    else return false end
  else return false end
  ctx:invalidate()
  return true
end

local function handle_pause(saved, ev, now)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    local y = ev.y
    if y >= 360 and y <= 408 then undo_turn(saved.game); saved.screen = SCREEN.GAME
    elseif y >= 480 and y <= 528 then saved.screen = SCREEN.MENU
    elseif y >= 412 and y < 446 then
      local winner = saved.game.turn == BLACK and "white" or "black"
      finish_game(saved, saved.game, winner)
    elseif y >= 446 and y < 480 then fresh_game(saved, saved.game.mode, saved.game.size, saved.game.level, now)
    else saved.screen = SCREEN.GAME end
    return true
  end
  if ev.type == "key" and ev.phase == "down" then
    if ev.key == "back" then saved.screen = SCREEN.GAME; return true end
    if ev.key == "ok" then undo_turn(saved.game); saved.screen = SCREEN.GAME; return true end
  end
  return false
end

function on_load(ctx)
  local saved = state(ctx)
  if saved.game and not normalize_game(saved.game) then saved.game = nil; saved.screen = SCREEN.TITLE end
  ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0)
end


function on_tick(ctx, dt_ms)
  local saved = state(ctx)
  local game = saved.game
  if saved.screen ~= SCREEN.GAME or not game then return end
  game.elapsed_ms = (game.elapsed_ms or 0) + math.max(0, tonumber(dt_ms) or 0)
  if game.ai_pending and not game.result then
    if game.awaiting_player_refresh then return end
    ctx.budget:extend()
    local move = choose_ai_move(game, function() return ctx.clock:millis() end, { feed = function() return ctx.budget:extend() end })
    game.ai_pending = false
    place(saved, game, move.row, move.column)
    ctx:invalidate()
    ctx:invalidate()
    return
  end
  ctx:invalidate()
end

function on_input(ctx, ev)
  local saved, now = state(ctx), ctx.clock:millis()
  if (ev.type == "pointer" and ev.phase == "up") then
    local x, y = virtual_point(viewport_layout(ctx), ev.x, ev.y)
    ev = { type = ev.type, gesture = ev.gesture, x = x, y = y, key = ev.key, phase = ev.phase }
  end
  if saved.screen == SCREEN.TITLE then
    if ev.type == "key" and ev.phase == "down" and ev.key == "back" then
      ctx:quit()
      return true
    end
    if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" or (ev.type == "key" and ev.phase == "down" and ev.key == "ok") then saved.screen = SCREEN.MENU; ctx:set_tick(0); ctx:invalidate(); return true end
  elseif saved.screen == SCREEN.MENU then
    if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
      local y = ev.y
      if y >= 188 and y <= 236 then select_menu(saved, 1, now)
      elseif y >= 260 and y <= 308 then select_menu(saved, 2, now)
      elseif y >= 332 and y <= 378 then select_menu(saved, 3, now)
      elseif y >= 404 and y <= 452 then select_menu(saved, 4, now)
      elseif y >= 476 and y <= 524 then select_menu(saved, 5, now)
      elseif y >= 548 and y <= 596 then select_menu(saved, 6, now) else return false end
      ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0); ctx:invalidate(); return true
    elseif ev.type == "key" and ev.phase == "down" then
      local max = saved.game and not saved.game.result and #saved.game.moves > 0 and 6 or 5
      if ev.key == "up" then saved.menu_sel = ((saved.menu_sel or 1) + max - 2) % max + 1
      elseif ev.key == "down" then saved.menu_sel = ((saved.menu_sel or 1) % max) + 1
      elseif ev.key == "ok" then select_menu(saved, saved.menu_sel or 1, now)
      elseif ev.key == "back" then saved.screen = SCREEN.TITLE else return false end
      ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0); ctx:invalidate(); return true
    end
  elseif saved.screen == SCREEN.DIFFICULTY then
    if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
      if inside(ev.x, ev.y, 150, 656, 180, 44) then
        saved.screen = SCREEN.MENU
        ctx:set_tick(0)
        ctx:invalidate()
        return true
      elseif ev.y >= 190 and ev.y <= 274 then saved.difficulty_sel = 1
      elseif ev.y >= 286 and ev.y <= 370 then saved.difficulty_sel = 2
      elseif ev.y >= 382 and ev.y <= 466 then saved.difficulty_sel = 3 else return false end
      fresh_game(saved, "ai", saved.pending_size or 15, ({ "easy", "medium", "hard" })[saved.difficulty_sel], now)
      ctx:set_tick(100); ctx:invalidate(); return true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "back" then saved.screen = SCREEN.MENU
      elseif ev.key == "up" then saved.difficulty_sel = ((saved.difficulty_sel or 2) + 1) % 3 + 1
      elseif ev.key == "down" then saved.difficulty_sel = ((saved.difficulty_sel or 2) % 3) + 1
      elseif ev.key == "ok" then fresh_game(saved, "ai", saved.pending_size or 15, ({ "easy", "medium", "hard" })[saved.difficulty_sel or 2], now) end
      ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0); ctx:invalidate(); return true
    end
  elseif saved.screen == SCREEN.GAME then
    return handle_game_input(ctx, saved, ev)
  elseif saved.screen == SCREEN.PAUSE then
    local handled = handle_pause(saved, ev, now); if handled then ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0); ctx:invalidate() end; return handled
  elseif saved.screen == SCREEN.RESULT then
    if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
      if inside(ev.x, ev.y, 42, 674, 188, 44) then
        fresh_game(saved, saved.game.mode, saved.game.size, saved.game.level, now)
      elseif inside(ev.x, ev.y, 250, 674, 188, 44) then
        saved.stats_return_screen, saved.screen = SCREEN.RESULT, SCREEN.STATS
      else return false end
      ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0); ctx:invalidate(); return true
    elseif ev.type == "key" and ev.phase == "down" then
      if ev.key == "left" or ev.key == "up" then saved.result_sel = 1
      elseif ev.key == "right" or ev.key == "down" then saved.result_sel = 2
      elseif ev.key == "ok" and (saved.result_sel or 1) == 1 then fresh_game(saved, saved.game.mode, saved.game.size, saved.game.level, now)
      elseif ev.key == "ok" then saved.stats_return_screen, saved.screen = SCREEN.RESULT, SCREEN.STATS
      elseif ev.key == "back" then saved.screen = SCREEN.MENU else return false end
      ctx:set_tick(saved.screen == SCREEN.GAME and 100 or 0); ctx:invalidate(); return true
    end
  elseif saved.screen == SCREEN.STATS then
    if ((ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap") or (ev.type == "key" and ev.phase == "down" and (ev.key == "back" or ev.key == "ok")) then
      saved.screen = saved.stats_return_screen or SCREEN.MENU
      saved.stats_return_screen = nil
      ctx:invalidate()
      return true
    end
  end
  return false
end

function on_draw(ctx, g)
  local saved = state(ctx)
  local ui = scaled_canvas(g, viewport_layout(ctx))
  if saved.screen == SCREEN.TITLE then draw_title(ui)
  elseif saved.screen == SCREEN.MENU then draw_menu(saved, ui)
  elseif saved.screen == SCREEN.DIFFICULTY then draw_difficulty(saved, ui)
  elseif saved.screen == SCREEN.GAME then
    draw_game(saved, ui)
    if saved.game and saved.game.awaiting_player_refresh then saved.game.awaiting_player_refresh = false end
  elseif saved.screen == SCREEN.PAUSE then draw_pause(saved, ui)
  elseif saved.screen == SCREEN.RESULT then draw_result(saved, ui)
  elseif saved.screen == SCREEN.STATS then draw_stats(saved, ui) end
end
