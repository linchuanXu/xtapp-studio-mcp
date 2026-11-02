local Rng = require("domain.match3_rng")
local Matcher = require("domain.match3_matcher")

local M = {}

local function clone_cell(cell)
  if not cell then return nil end
  return { kind = cell.kind, special = cell.special }
end

function M.new(rows, cols, kind_count)
  assert(rows >= 3 and cols >= 3, "board must be at least 3x3")
  assert(kind_count >= 3, "at least three kinds are required")
  local board = { rows = rows, cols = cols, kind_count = kind_count, cells = {}, blocked = {} }
  for row = 1, rows do
    board.cells[row] = {}
  end
  return board
end

function M.clone(board)
  local copy = M.new(board.rows, board.cols, board.kind_count)
  for point_id, blocked in pairs(board.blocked or {}) do copy.blocked[point_id] = blocked end
  for row = 1, board.rows do
    for col = 1, board.cols do copy.cells[row][col] = clone_cell(board.cells[row][col]) end
  end
  return copy
end

local function point_id(row, col) return row .. ":" .. col end

function M.is_blocked(board, row, col)
  return board.blocked and next(board.blocked) ~= nil and board.blocked[point_id(row, col)] == true
end

function M.set_blocked(board, blocked)
  board.blocked = {}
  for key, value in pairs(blocked or {}) do
    local row, col
    if type(value) == "table" then
      row, col = value.row or value[1], value.col or value[2]
    elseif value == true and type(key) == "string" then
      row, col = string.match(key, "^(%d+):(%d+)$")
    end
    row, col = tonumber(row), tonumber(col)
    if row and col and M.in_bounds(board, row, col) then
      board.blocked[point_id(row, col)] = true
      board.cells[row][col] = nil
    end
  end
  return board
end

function M.in_bounds(board, row, col)
  return row >= 1 and row <= board.rows and col >= 1 and col <= board.cols
end

function M.adjacent(row1, col1, row2, col2)
  return math.abs(row1 - row2) + math.abs(col1 - col2) == 1
end

function M.swap(board, row1, col1, row2, col2)
  assert(M.in_bounds(board, row1, col1) and M.in_bounds(board, row2, col2), "swap outside board")
  board.cells[row1][col1], board.cells[row2][col2] = board.cells[row2][col2], board.cells[row1][col1]
end

function M.legal_moves(board)
  local moves = {}
  for row = 1, board.rows do
    for col = 1, board.cols do
      if not M.is_blocked(board, row, col) then
        for _, delta in ipairs({ { 0, 1 }, { 1, 0 } }) do
          local row2, col2 = row + delta[1], col + delta[2]
          if M.in_bounds(board, row2, col2) and not M.is_blocked(board, row2, col2) then
            local first, second = board.cells[row][col], board.cells[row2][col2]
            if first and second then
              local special = first.special or second.special
              M.swap(board, row, col, row2, col2)
              local valid = special ~= nil or Matcher.has_match(board)
              M.swap(board, row, col, row2, col2)
              if valid then moves[#moves + 1] = { row1 = row, col1 = col, row2 = row2, col2 = col2 } end
            end
          end
        end
      end
    end
  end
  return moves
end

function M.has_legal_move(board)
  return #M.legal_moves(board) > 0
end

local function fill_stable(board, seed)
  for row = 1, board.rows do
    for col = 1, board.cols do
      if M.is_blocked(board, row, col) then
        board.cells[row][col] = nil
      else
        local choices = {}
        for kind = 1, board.kind_count do
          local left1, left2 = board.cells[row][col - 1], board.cells[row][col - 2]
          local up1 = board.cells[row - 1] and board.cells[row - 1][col]
          local up2 = board.cells[row - 2] and board.cells[row - 2][col]
          local horizontal = left1 and left2 and left1.kind == kind and left2.kind == kind
          local vertical = up1 and up2 and up1.kind == kind and up2.kind == kind
          if not horizontal and not vertical then choices[#choices + 1] = kind end
        end
        local selected
        selected, seed = Rng.int(seed, 1, #choices)
        board.cells[row][col] = { kind = choices[selected] }
      end
    end
  end
  return seed
end

function M.generate(rows, cols, kind_count, seed, blocked)
  seed = Rng.normalize(seed)
  for _ = 1, 300 do
    local board = M.new(rows, cols, kind_count)
    M.set_blocked(board, blocked)
    seed = fill_stable(board, seed)
    if M.has_legal_move(board) then return board, seed end
  end
  error("unable to generate playable board")
end

function M.collapse_and_fill(board, seed)
  for col = 1, board.cols do
    local segment_end = board.rows
    while segment_end >= 1 do
      while segment_end >= 1 and M.is_blocked(board, segment_end, col) do
        board.cells[segment_end][col] = nil
        segment_end = segment_end - 1
      end
      if segment_end < 1 then break end
      local segment_start = segment_end
      while segment_start > 1 and not M.is_blocked(board, segment_start - 1, col) do segment_start = segment_start - 1 end
      local values = {}
      for row = segment_end, segment_start, -1 do
        if board.cells[row][col] then values[#values + 1] = board.cells[row][col] end
        board.cells[row][col] = nil
      end
      local write = segment_end
      for _, cell in ipairs(values) do
        board.cells[write][col] = cell
        write = write - 1
      end
      while write >= segment_start do
        local kind
        kind, seed = Rng.int(seed, 1, board.kind_count)
        board.cells[write][col] = { kind = kind }
        write = write - 1
      end
      segment_end = segment_start - 1
    end
  end
  return seed
end

function M.reshuffle(board, seed)
  local values = {}
  for row = 1, board.rows do
    for col = 1, board.cols do
      if not M.is_blocked(board, row, col) then values[#values + 1] = clone_cell(board.cells[row][col]) end
    end
  end
  for _ = 1, 300 do
    seed = Rng.shuffle(values, seed)
    local index = 1
    for row = 1, board.rows do
      for col = 1, board.cols do
        if M.is_blocked(board, row, col) then
          board.cells[row][col] = nil
        else
          board.cells[row][col], index = clone_cell(values[index]), index + 1
        end
      end
    end
    if not Matcher.has_match(board) and M.has_legal_move(board) then return seed, true end
  end
  local fresh
  fresh, seed = M.generate(board.rows, board.cols, board.kind_count, seed, board.blocked)
  board.cells = fresh.cells
  return seed, true
end

return M
