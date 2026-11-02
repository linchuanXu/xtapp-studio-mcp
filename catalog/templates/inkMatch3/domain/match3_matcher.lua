local M = {}

local function key(row, col)
  return row .. ":" .. col
end

local function kind_at(board, row, col)
  if board.blocked and next(board.blocked) and board.blocked[key(row, col)] then return nil end
  local cell = board.cells[row] and board.cells[row][col]
  return cell and cell.kind or nil
end

local function add_group(groups, orientation, row, col, length)
  local cells = {}
  for offset = 0, length - 1 do
    cells[#cells + 1] = {
      row = row + (orientation == "v" and offset or 0),
      col = col + (orientation == "h" and offset or 0),
    }
  end
  groups[#groups + 1] = { orientation = orientation, length = length, cells = cells }
end

function M.find(board)
  local groups = {}
  for row = 1, board.rows do
    local col = 1
    while col <= board.cols do
      local kind = kind_at(board, row, col)
      local finish = col + 1
      while kind ~= nil and finish <= board.cols and kind_at(board, row, finish) == kind do finish = finish + 1 end
      if kind ~= nil and finish - col >= 3 then add_group(groups, "h", row, col, finish - col) end
      col = math.max(finish, col + 1)
    end
  end
  for col = 1, board.cols do
    local row = 1
    while row <= board.rows do
      local kind = kind_at(board, row, col)
      local finish = row + 1
      while kind ~= nil and finish <= board.rows and kind_at(board, finish, col) == kind do finish = finish + 1 end
      if kind ~= nil and finish - row >= 3 then add_group(groups, "v", row, col, finish - row) end
      row = math.max(finish, row + 1)
    end
  end

  local cells, lookup = {}, {}
  for _, group in ipairs(groups) do
    for _, point in ipairs(group.cells) do
      local id = key(point.row, point.col)
      if not lookup[id] then
        lookup[id] = true
        cells[#cells + 1] = { row = point.row, col = point.col }
      end
    end
  end
  return { groups = groups, cells = cells, lookup = lookup }
end

function M.has_match(board)
  return #M.find(board).groups > 0
end

return M
