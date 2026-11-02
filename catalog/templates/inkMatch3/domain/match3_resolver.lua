local Board = require("domain.match3_board")
local Matcher = require("domain.match3_matcher")

local M = {}

local function id(row, col) return row .. ":" .. col end

local function contains(group, row, col)
  for _, point in ipairs(group.cells) do
    if point.row == row and point.col == col then return true end
  end
  return false
end

local function choose_position(group, preferred)
  for _, point in ipairs(preferred or {}) do
    if contains(group, point.row, point.col) then return { row = point.row, col = point.col } end
  end
  return group.cells[math.floor((#group.cells + 1) / 2)]
end

local function special_creations(matches, preferred)
  local creations, occupied = {}, {}
  local horizontal, vertical, crossed = {}, {}, {}
  for _, group in ipairs(matches.groups) do
    for _, point in ipairs(group.cells) do
      local point_id = id(point.row, point.col)
      if group.orientation == "h" then horizontal[point_id] = point else vertical[point_id] = point end
    end
  end
  for point_id, point in pairs(horizontal) do
    if vertical[point_id] then
      creations[#creations + 1] = { row = point.row, col = point.col, special = "blast" }
      occupied[point_id] = true
      for _, group in ipairs(matches.groups) do
        if contains(group, point.row, point.col) then crossed[group] = true end
      end
    end
  end
  for _, group in ipairs(matches.groups) do
    local special = not crossed[group] and (group.length >= 5 and "color" or (group.length == 4 and (group.orientation == "h" and "row" or "col") or nil)) or nil
    if special then
      local position = choose_position(group, preferred)
      local point_id = id(position.row, position.col)
      if not occupied[point_id] then
        creations[#creations + 1] = { row = position.row, col = position.col, special = special }
        occupied[point_id] = true
      end
    end
  end
  return creations
end

local function most_common_kind(board)
  local counts, best_kind, best_count = {}, 1, -1
  for row = 1, board.rows do
    for col = 1, board.cols do
      local kind = board.cells[row][col] and board.cells[row][col].kind
      if kind then
        counts[kind] = (counts[kind] or 0) + 1
        if counts[kind] > best_count or (counts[kind] == best_count and kind < best_kind) then
          best_kind, best_count = kind, counts[kind]
        end
      end
    end
  end
  return best_kind
end

local function expand_specials(board, clear, color_kind, suppressed)
  local queue, cursor = {}, 1
  for _, point in pairs(clear) do queue[#queue + 1] = point end
  while cursor <= #queue do
    local point = queue[cursor]
    cursor = cursor + 1
    local cell = board.cells[point.row] and board.cells[point.row][point.col]
    local special = cell and cell.special
    if special and not point.triggered and not (suppressed and suppressed[id(point.row, point.col)]) then
      point.triggered = true
      local additions = {}
      if special == "row" then
        for col = 1, board.cols do additions[#additions + 1] = { row = point.row, col = col } end
      elseif special == "col" then
        for row = 1, board.rows do additions[#additions + 1] = { row = row, col = point.col } end
      elseif special == "blast" then
        for row = math.max(1, point.row - 1), math.min(board.rows, point.row + 1) do
          for col = math.max(1, point.col - 1), math.min(board.cols, point.col + 1) do
            additions[#additions + 1] = { row = row, col = col }
          end
        end
      elseif special == "color" then
        local target_kind = color_kind or most_common_kind(board)
        for row = 1, board.rows do
          for col = 1, board.cols do
            local target = board.cells[row][col]
            if target and target.kind == target_kind then additions[#additions + 1] = { row = row, col = col } end
          end
        end
      end
      for _, addition in ipairs(additions) do
        local addition_id = id(addition.row, addition.col)
        if not clear[addition_id] then
          clear[addition_id] = addition
          queue[#queue + 1] = addition
        end
      end
    end
  end
end

local function matched_kind_before_clear(board, matches, creation)
  for _, group in ipairs(matches.groups) do
    if contains(group, creation.row, creation.col) then
      for _, point in ipairs(group.cells) do
        local cell = board.cells[point.row][point.col]
        if cell and cell.kind then return cell.kind end
      end
    end
  end
  return 1
end

local function resolve_all(board, seed, initial_matches, preferred, forced, color_kind, suppressed)
  local waves, total, chain = {}, 0, 1
  local matches = initial_matches
  while #matches.groups > 0 or (forced and #forced > 0) do
    local creations = special_creations(matches, preferred)
    for _, creation in ipairs(creations) do creation.kind = matched_kind_before_clear(board, matches, creation) end

    local clear = {}
    for _, point in ipairs(matches.cells) do clear[id(point.row, point.col)] = { row = point.row, col = point.col } end
    for _, point in ipairs(forced or {}) do clear[id(point.row, point.col)] = { row = point.row, col = point.col } end
    expand_specials(board, clear, color_kind, suppressed)
    local removed_cells, by_kind = {}, {}
    for row = 1, board.rows do
      for col = 1, board.cols do
        if clear[id(row, col)] and not Board.is_blocked(board, row, col) then
          local cell = board.cells[row][col]
          if cell then
            removed_cells[#removed_cells + 1] = { row = row, col = col, kind = cell.kind, special = cell.special }
            if cell.kind then by_kind[cell.kind] = (by_kind[cell.kind] or 0) + 1 end
            board.cells[row][col] = nil
          end
        end
      end
    end
    local removed = #removed_cells
    for _, creation in ipairs(creations) do
      board.cells[creation.row][creation.col] = { kind = creation.special == "color" and nil or creation.kind, special = creation.special }
    end
    total = total + removed
    waves[#waves + 1] = {
      chain = chain,
      cleared = removed,
      cells = removed_cells,
      by_kind = by_kind,
      creations = creations,
      score = removed * 10 * math.min(chain, 5),
    }
    seed = Board.collapse_and_fill(board, seed)
    -- Keep the resolved board for the presentation layer.  The game state
    -- still resolves immediately; the UI can now reveal each wave in discrete
    -- e-ink-friendly clear and drop phases without changing the rules.
    waves[#waves].board_after = Board.clone(board)
    matches, preferred, forced, color_kind, suppressed = Matcher.find(board), nil, nil, nil, nil
    chain = chain + 1
    if chain > 100 then error("match resolution did not converge") end
  end
  local score = 0
  for _, wave in ipairs(waves) do score = score + wave.score end
  return { waves = waves, cleared = total, score = score, seed = seed }
end

local function add_point(points, lookup, row, col)
  local point_id = id(row, col)
  if not lookup[point_id] then
    lookup[point_id] = true
    points[#points + 1] = { row = row, col = col }
  end
end

local function add_row(board, points, lookup, row)
  for col = 1, board.cols do add_point(points, lookup, row, col) end
end

local function add_col(board, points, lookup, col)
  for row = 1, board.rows do add_point(points, lookup, row, col) end
end

local function add_area(board, points, lookup, center_row, center_col, radius)
  for row = math.max(1, center_row - radius), math.min(board.rows, center_row + radius) do
    for col = math.max(1, center_col - radius), math.min(board.cols, center_col + radius) do
      add_point(points, lookup, row, col)
    end
  end
end

local function is_line(special)
  return special == "row" or special == "col"
end

local function build_combo(board, first, second, row1, col1, row2, col2)
  local first_special, second_special = first.special, second.special
  if not first_special and not second_special then return nil end

  local forced, lookup, suppressed = {}, {}, {}
  -- After swapping, first lives at the second coordinate and vice versa.
  local first_id, second_id = id(row2, col2), id(row1, col1)
  suppressed[first_id], suppressed[second_id] = true, true

  if first_special == "color" and second_special == "color" then
    for row = 1, board.rows do for col = 1, board.cols do add_point(forced, lookup, row, col) end end
    return forced, nil, suppressed, "color_color"
  end

  local color, partner, color_row, color_col
  if first_special == "color" then
    color, partner, color_row, color_col = first, second, row2, col2
  elseif second_special == "color" then
    color, partner, color_row, color_col = second, first, row1, col1
  end
  if color then
    local target_kind = partner.kind
    add_point(forced, lookup, color_row, color_col)
    local converted = 0
    for row = 1, board.rows do
      for col = 1, board.cols do
        local cell = board.cells[row][col]
        if cell and cell.kind == target_kind then
          if is_line(partner.special) then
            converted = converted + 1
            cell.special = converted % 2 == 1 and "row" or "col"
          elseif partner.special == "blast" then
            cell.special = "blast"
          end
          -- Converted pieces must be allowed to trigger; only suppress the color piece.
          suppressed[id(row, col)] = nil
          add_point(forced, lookup, row, col)
        end
      end
    end
    local combo = partner.special == "blast" and "color_blast" or (is_line(partner.special) and "color_line" or "color_normal")
    return forced, target_kind, suppressed, combo
  end

  if not first_special or not second_special then return nil end

  if is_line(first_special) and is_line(second_special) then
    add_row(board, forced, lookup, row2)
    add_col(board, forced, lookup, col2)
    return forced, nil, suppressed, "line_line"
  end
  if (is_line(first_special) and second_special == "blast") or (first_special == "blast" and is_line(second_special)) then
    for row = math.max(1, row2 - 1), math.min(board.rows, row2 + 1) do add_row(board, forced, lookup, row) end
    for col = math.max(1, col2 - 1), math.min(board.cols, col2 + 1) do add_col(board, forced, lookup, col) end
    return forced, nil, suppressed, "line_blast"
  end
  if first_special == "blast" and second_special == "blast" then
    add_area(board, forced, lookup, row2, col2, 2)
    return forced, nil, suppressed, "blast_blast"
  end
  return nil
end

function M.resolve_matches(board, seed)
  return resolve_all(board, seed, Matcher.find(board))
end

function M.try_swap(board, row1, col1, row2, col2, seed)
  if not Board.in_bounds(board, row1, col1) or not Board.in_bounds(board, row2, col2) then
    return { valid = false, reason = "outside", seed = seed }
  end
  if Board.is_blocked(board, row1, col1) or Board.is_blocked(board, row2, col2) then
    return { valid = false, reason = "blocked", seed = seed }
  end
  if not Board.adjacent(row1, col1, row2, col2) then return { valid = false, reason = "not_adjacent", seed = seed } end
  local first, second = board.cells[row1][col1], board.cells[row2][col2]
  if not first or not second then return { valid = false, reason = "empty", seed = seed } end

  Board.swap(board, row1, col1, row2, col2)
  local matches = Matcher.find(board)
  local forced, color_kind, suppressed, combo = build_combo(board, first, second, row1, col1, row2, col2)
  forced = forced or {}
  if not combo and (first.special or second.special) then
    forced = { { row = row2, col = col2 }, { row = row1, col = col1 } }
    if first.special == "color" then color_kind = second.kind end
    if second.special == "color" then color_kind = first.kind end
  end
  if #matches.groups == 0 and #forced == 0 then
    Board.swap(board, row1, col1, row2, col2)
    return { valid = false, reason = "no_match", seed = seed }
  end
  local before_resolve = Board.clone(board)
  local result = resolve_all(board, seed, matches, { { row = row2, col = col2 }, { row = row1, col = col1 } }, forced, color_kind, suppressed)
  result.valid = true
  result.board_before = before_resolve
  result.combo = combo
  result.reshuffled = false
  if not Board.has_legal_move(board) then
    result.seed = Board.reshuffle(board, result.seed)
    result.reshuffled = true
  end
  return result
end

return M
