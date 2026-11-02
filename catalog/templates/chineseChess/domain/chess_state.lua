-- 中国象棋：状态容器与全部行棋规则。棋盘 9 列(0..8) × 10 行(0..9)，红方在下(7..9)、黑方在上(0..2)；UI board 为 90 字符，搜索态 cells[1..90] 下标 = r*9+c；红子小写(k帅 a仕 b相 n马 r车 c炮 p兵)，黑子大写(K将 A士 B象 N马 R车 C炮 P卒)。

local Geometry = require("domain.chess_geometry")
local M = {}
M.EMPTY = "."

local EMPTY = "."
local INITIAL =
  "RNBAKABNR" .. "........." .. ".C.....C." .. "P.P.P.P.P" ..
  "........." .. "........." .. "p.p.p.p.p" .. ".c.....c." .. "........." .. "rnbakabnr"

local LABEL_RED = { k="帅", a="仕", b="相", n="马", r="车", c="炮", p="兵" }
local LABEL_BLACK = { K="将", A="士", B="象", N="马", R="车", C="炮", P="卒" }
local HORSE_ATTACKS = {
  { -2, -1, -1, 0 }, { -2, 1, -1, 0 }, { 2, -1, 1, 0 }, { 2, 1, 1, 0 },
  { -1, -2, 0, -1 }, { 1, -2, 0, -1 }, { -1, 2, 0, 1 }, { 1, 2, 0, 1 },
}
local ELEPHANT_DIAGONALS = { { -2, -2 }, { -2, 2 }, { 2, -2 }, { 2, 2 } }
local ADVISOR_DIAGONALS = { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
local GENERAL_STEPS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

local function idx(r, c) return r * 9 + c end
local function position_key(board, side) return board .. "|" .. side end

local function copy_position_counts(counts)
  local copy = {}
  for key, value in pairs(counts or {}) do copy[key] = value end
  return copy
end

local function copy_move_history(history)
  local copy = {}
  local first = math.max(1, #(history or {}) - 7)
  for index = first, #(history or {}) do
    local move = history[index]
    copy[#copy + 1] = {
      side = move.side, r = move.r, c = move.c, tr = move.tr, tc = move.tc,
    }
  end
  return copy
end

local function at(board, r, c)
  if r < 0 or r > 9 or c < 0 or c > 8 then return EMPTY end
  if type(board) == "table" and board.cells then
    return board.cells[idx(r, c) + 1] or EMPTY
  end
  if type(board) == "table" and board.board then
    return at(board.board, r, c)
  end
  if type(board) == "table" then return EMPTY end
  return board:sub(idx(r, c) + 1, idx(r, c) + 1)
end

local function setc(board, r, c, ch)
  local i = idx(r, c) + 1
  return board:sub(1, i - 1) .. ch .. board:sub(i + 1)
end

local function side_of(ch)
  if not ch or ch == EMPTY then return nil end
  if ch:byte() < 97 then return "b" end -- 大写 = 黑
  return "r"
end

local function in_palace(r, c, side)
  if c < 3 or c > 5 then return false end
  if side == "r" then return r >= 7 and r <= 9 end
  return r >= 0 and r <= 2
end

local function piece_between(board, r, c, tr, tc)
  local n = 0
  if r == tr then
    local step = tc > c and 1 or -1
    local cc = c + step
    while cc ~= tc do
      if at(board, r, cc) ~= EMPTY then n = n + 1 end
      cc = cc + step
    end
  else
    local step = tr > r and 1 or -1
    local rr = r + step
    while rr ~= tr do
      if at(board, rr, c) ~= EMPTY then n = n + 1 end
      rr = rr + step
    end
  end
  return n
end

local function clear_path(board, r, c, tr, tc)
  if r == tr then
    local step = tc > c and 1 or -1
    local cc = c + step
    while cc ~= tc do
      if at(board, r, cc) ~= EMPTY then return false end
      cc = cc + step
    end
    return true
  elseif c == tc then
    local step = tr > r and 1 or -1
    local rr = r + step
    while rr ~= tr do
      if at(board, rr, c) ~= EMPTY then return false end
      rr = rr + step
    end
    return true
  end
  return false
end

local function move_rule_ok(board, r, c, tr, tc)
  local ch = at(board, r, c)
  if not ch or ch == EMPTY then return false end
  local t = ch:lower():sub(1, 1)
  local target = at(board, tr, tc)
  local dr, dc = tr - r, tc - c
  local adr, adc = math.abs(dr), math.abs(dc)
  local same_line = (dr == 0 and dc ~= 0) or (dr ~= 0 and dc == 0)

  if t == "r" then -- 车
    return same_line and clear_path(board, r, c, tr, tc)
  elseif t == "c" then -- 炮
    if not same_line then return false end
    local between = piece_between(board, r, c, tr, tc)
    if target == EMPTY then return between == 0 end
    return between == 1
  elseif t == "n" then -- 马
    if not ((adr == 1 and adc == 2) or (adr == 2 and adc == 1)) then return false end
    if adc == 2 then return at(board, r, c + (dc > 0 and 1 or -1)) == EMPTY end
    return at(board, r + (dr > 0 and 1 or -1), c) == EMPTY
  elseif t == "b" then -- 象/相
    if adr ~= 2 or adc ~= 2 then return false end
    if at(board, r + (dr > 0 and 1 or -1), c + (dc > 0 and 1 or -1)) ~= EMPTY then return false end
    if side_of(ch) == "r" then return tr >= 5 end
    return tr <= 4
  elseif t == "a" then -- 士/仕
    return adr == 1 and adc == 1 and in_palace(tr, tc, side_of(ch))
  elseif t == "k" then -- 将/帅
    if ((adr == 1 and dc == 0) or (dr == 0 and adc == 1)) and in_palace(tr, tc, side_of(ch)) then
      return true
    end
    if dc == 0 and dr ~= 0 and target ~= EMPTY
      and side_of(target) ~= side_of(ch) and target:lower():sub(1, 1) == "k" then
      return clear_path(board, r, c, tr, tc)
    end
    return false
  elseif t == "p" then -- 兵/卒
    local side = side_of(ch)
    if side == "r" then
      local crossed = r <= 4
      if dr == -1 and dc == 0 then return true end
      return crossed and dr == 0 and adc == 1
    else
      local crossed = r >= 5
      if dr == 1 and dc == 0 then return true end
      return crossed and dr == 0 and adc == 1
    end
  end
  return false
end

local function find_general(board, side)
  if type(board) == "table" and board.kings and board.kings[side] then
    local king = board.kings[side]
    if king.r ~= nil then return king.r, king.c end
    return nil
  end
  local target = side == "r" and "k" or "K"
  for r = 0, 9 do
    for c = 0, 8 do
      if at(board, r, c) == target then return r, c end
    end
  end
  return nil
end

local square_attacked

local function attack_rule_ok(board, r, c, tr, tc, target_piece)
  local ch = at(board, r, c)
  local kind = ch:lower()
  if kind == "c" then
    local same_line = (r == tr and c ~= tc) or (c == tc and r ~= tr)
    if not same_line then return false end
    local occupied
    if target_piece ~= nil then
      occupied = target_piece ~= EMPTY
    else
      occupied = at(board, tr, tc) ~= EMPTY
    end
    return piece_between(board, r, c, tr, tc) == (occupied and 1 or 0)
  elseif kind == "k" and target_piece ~= nil then
    local dr, dc = tr - r, tc - c
    local adr, adc = math.abs(dr), math.abs(dc)
    if ((adr == 1 and dc == 0) or (dr == 0 and adc == 1))
      and in_palace(tr, tc, side_of(ch)) then return true end
    if c == tc and r ~= tr and target_piece:lower() == "k" then
      return clear_path(board, r, c, tr, tc)
    end
    return false
  end
  return move_rule_ok(board, r, c, tr, tc)
end

local function in_check(board, side)
  local gr, gc = find_general(board, side)
  if not gr then return false end
  if type(board) == "table" and board.attack_occ_count_r then
    local counts = side == "r" and board.attack_occ_count_b or board.attack_occ_count_r
    return (counts[idx(gr, gc) + 1] or 0) > 0 or board.flying == true
  end
  return square_attacked(board, side == "r" and "b" or "r", gr, gc, side == "r" and "k" or "K")
end

-- 搜索态：可写 90 格缓冲 + 双方棋子表 + 可回滚双字哈希；UI/双人仍走下方字符串纯函数。
local SEARCH_UNDO_CAPACITY = 24
local ATTACK_DELTA_PER_PLY = 384
local ATTACK_PLY_CAP = 24
local ATTACK_KIND_INDEX = { p = 1, a = 2, b = 3, n = 4, c = 5, r = 6, k = 7 }
local ATTACK_KIND_BITS = { 1, 2, 4, 8, 16, 32, 64 }
local ATTACK_KIND_FACTORS = { 1, 16, 256, 4096, 65536, 1048576, 16777216 }
local HASH_MOD = 4294967296
local HASH_HALF = 65536

local XOR4 = {}
for i = 0, 15 do
  XOR4[i] = {}
  for j = 0, 15 do
    local v, p, a, b = 0, 1, i, j
    for _ = 1, 4 do
      local aa, bb = a % 2, b % 2
      if aa ~= bb then v = v + p end
      a, b, p = (a - aa) / 2, (b - bb) / 2, p * 2
    end
    XOR4[i][j] = v
  end
end

local function xor16(a, b)
  local a0, b0 = a % 16, b % 16
  local a1, b1 = math.floor(a / 16) % 16, math.floor(b / 16) % 16
  local a2, b2 = math.floor(a / 256) % 16, math.floor(b / 256) % 16
  local a3, b3 = math.floor(a / 4096) % 16, math.floor(b / 4096) % 16
  return XOR4[a0][b0] + XOR4[a1][b1] * 16 + XOR4[a2][b2] * 256 + XOR4[a3][b3] * 4096
end

local function xor32(a, b)
  local alo, ahi = a % HASH_HALF, math.floor(a / HASH_HALF)
  local blo, bhi = b % HASH_HALF, math.floor(b / HASH_HALF)
  return xor16(alo, blo) + xor16(ahi, bhi) * HASH_HALF
end

local function hash_component(square, piece, salt)
  local byte = piece and piece:byte() or 0
  local value = (square + 1) * 131 + byte * 17 + salt
  return (value * 1103515245 + 12345) % HASH_MOD
end

-- 固定 Zobrist 表：初始化生成一次，搜索节点只做数组寻址。
local HASH_PIECES = { "p", "a", "b", "n", "r", "c", "k", "P", "A", "B", "N", "R", "C", "K" }
local HASH_PIECE_INDEX = {}
for index, piece in ipairs(HASH_PIECES) do HASH_PIECE_INDEX[piece] = index end
local ZOBRIST_HI, ZOBRIST_LO = {}, {}
for square = 0, 89 do
  for piece_index, piece in ipairs(HASH_PIECES) do
    local slot = square * #HASH_PIECES + piece_index
    ZOBRIST_HI[slot] = hash_component(square, piece, 7919)
    ZOBRIST_LO[slot] = hash_component(square, piece, 104729)
  end
end

local function search_hash_piece(state, square, piece)
  if not piece or piece == EMPTY then return end
  local piece_index = HASH_PIECE_INDEX[piece]
  local slot = square * #HASH_PIECES + piece_index
  local hi, lo = ZOBRIST_HI[slot], ZOBRIST_LO[slot]
  state.hash_hi = xor32(state.hash_hi, hi)
  state.hash_lo = xor32(state.hash_lo, lo)
end

local function attack_arrays(state, side, occupied)
  if side == "r" then
    if occupied then
      return state.attack_occ_count_r, state.attack_occ_packed_r, state.attack_occ_kinds_r
    end
    return state.attack_empty_count_r, state.attack_empty_packed_r, state.attack_empty_kinds_r
  end
  if occupied then
    return state.attack_occ_count_b, state.attack_occ_packed_b, state.attack_occ_kinds_b
  end
  return state.attack_empty_count_b, state.attack_empty_packed_b, state.attack_empty_kinds_b
end

local function change_attack_live(state, side, square, occupied, kind_index, amount)
  local counts, packed, kinds = attack_arrays(state, side, occupied)
  local slot = square + 1
  local factor = ATTACK_KIND_FACTORS[kind_index]
  local old_packed = packed[slot] or 0
  local old_kind_count = math.floor(old_packed / factor) % 16
  local new_kind_count = old_kind_count + amount
  if new_kind_count < 0 or new_kind_count > 15 then return false end
  local old_count = counts[slot] or 0
  local new_count = old_count + amount
  if new_count < 0 then return false end
  counts[slot] = new_count
  packed[slot] = old_packed + amount * factor
  local bit = ATTACK_KIND_BITS[kind_index]
  local mask = kinds[slot] or 0
  if old_kind_count == 0 and new_kind_count > 0 then
    kinds[slot] = mask + bit
  elseif old_kind_count > 0 and new_kind_count == 0 then
    kinds[slot] = mask - bit
  end
  return true
end

-- 每次贡献编码为小整数：热栈用单个预分配数值数组而非五个表。
local function encode_attack_delta(square, side, occupied, kind_index, amount)
  local side_bit = side == "b" and 1 or 0
  local channel = occupied and 1 or 0
  local negative = amount < 0 and 1 or 0
  return (((square * 2 + side_bit) * 2 + channel) * 7 + kind_index - 1) * 2 + negative
end

local function decode_attack_delta(value)
  local negative = value % 2
  value = math.floor(value / 2)
  local kind_index = value % 7 + 1
  value = math.floor(value / 7)
  local channel = value % 2
  value = math.floor(value / 2)
  local side_bit = value % 2
  local square = math.floor(value / 2)
  return square, side_bit == 1 and "b" or "r", channel == 1,
    kind_index, negative == 1 and -1 or 1
end

local function write_attack_delta(state, depth, count, square, side, occupied, kind_index, amount)
  local limit = state.attack_delta_limit or ATTACK_DELTA_PER_PLY
  if count >= limit then return nil end
  local base = (depth - 1) * ATTACK_DELTA_PER_PLY
  state.attack_delta_values[base + count + 1] =
    encode_attack_delta(square, side, occupied, kind_index, amount)
  return count + 1
end

local function add_attack_delta(state, depth, count, square, side, kind_index, amount, empty, occupied)
  if empty then
    count = write_attack_delta(state, depth, count, square, side, false, kind_index, amount)
    if not count then return nil end
  end
  if occupied then
    count = write_attack_delta(state, depth, count, square, side, true, kind_index, amount)
    if not count then return nil end
  end
  return count
end

local function geometry_ray(state, square, direction, visit)
  if Geometry.is_ready() then
    local offset, count = Geometry.ray_range(square, direction)
    for index = 0, count - 1 do
      if visit(Geometry.ray_at(offset + index)) == false then return end
    end
    return
  end
  local r, c = math.floor(square / 9), square % 9
  local deltas = { { -1, 0 }, { 0, 1 }, { 1, 0 }, { 0, -1 } }
  local delta = deltas[direction + 1]
  local rr, cc = r + delta[1], c + delta[2]
  while rr >= 0 and rr <= 9 and cc >= 0 and cc <= 8 do
    if visit(idx(rr, cc)) == false then return end
    rr, cc = rr + delta[1], cc + delta[2]
  end
end

local function emit_slider_attacks(state, entry, amount, depth, count)
  local side = side_of(entry.piece)
  local kind = entry.piece:lower()
  local kind_index = ATTACK_KIND_INDEX[kind]
  for direction = 0, 3 do
    local screened = false
    local overflow = false
    geometry_ray(state, entry.square, direction, function(square)
      local occupied_now = state.cells[square + 1] ~= EMPTY
      if kind == "r" then
        count = add_attack_delta(
          state, depth, count, square, side, kind_index, amount,
          true, true
        )
        if not count then overflow = true; return false end
        if occupied_now then return false end
      elseif not screened then
        count = add_attack_delta(
          state, depth, count, square, side, kind_index, amount, true, false
        )
        if not count then overflow = true; return false end
        if occupied_now then
          screened = true
        end
      else
        count = add_attack_delta(
          state, depth, count, square, side, kind_index, amount, false, true
        )
        if not count then overflow = true; return false end
        if occupied_now then return false end
      end
      return true
    end)
    if overflow then return nil end
  end
  return count
end

local function fallback_local_attacks(entry, visit)
  local r, c = entry.r, entry.c
  local kind = entry.piece:lower()
  if kind == "n" then
    for _, step in ipairs(HORSE_ATTACKS) do
      local tr, tc = r + step[1], c + step[2]
      if tr >= 0 and tr <= 9 and tc >= 0 and tc <= 8 then
        visit(idx(tr, tc), idx(r + step[3], c + step[4]))
      end
    end
  elseif kind == "b" then
    for _, step in ipairs(ELEPHANT_DIAGONALS) do
      local tr, tc = r + step[1], c + step[2]
      if tr >= 0 and tr <= 9 and tc >= 0 and tc <= 8 then
        visit(idx(tr, tc), idx(r + step[1] / 2, c + step[2] / 2))
      end
    end
  elseif kind == "a" then
    for _, step in ipairs(ADVISOR_DIAGONALS) do
      local tr, tc = r + step[1], c + step[2]
      if in_palace(tr, tc, side_of(entry.piece)) then visit(idx(tr, tc), nil) end
    end
  elseif kind == "k" then
    for _, step in ipairs(GENERAL_STEPS) do
      local tr, tc = r + step[1], c + step[2]
      if in_palace(tr, tc, side_of(entry.piece)) then visit(idx(tr, tc), nil) end
    end
  elseif kind == "p" then
    local side = side_of(entry.piece)
    local dr = side == "r" and -1 or 1
    if r + dr >= 0 and r + dr <= 9 then visit(idx(r + dr, c), nil) end
    local crossed = side == "r" and r <= 4 or side == "b" and r >= 5
    if crossed then
      if c > 0 then visit(idx(r, c - 1), nil) end
      if c < 8 then visit(idx(r, c + 1), nil) end
    end
  end
end

local function emit_local_attacks(state, entry, amount, depth, count)
  local side = side_of(entry.piece)
  local kind = entry.piece:lower()
  local kind_index = ATTACK_KIND_INDEX[kind]
  local overflow = false
  local function visit(square, blocker)
    if blocker and state.cells[blocker + 1] ~= EMPTY then return end
    if kind == "b" then
      local target_row = math.floor(square / 9)
      if side == "r" and target_row < 5 or side == "b" and target_row > 4 then return end
    end
    count = add_attack_delta(
      state, depth, count, square, side, kind_index, amount, true, true
    )
    if not count then overflow = true end
  end
  if Geometry.is_ready() then
    local geometry_kind = kind == "n" and 1
      or kind == "b" and 2
      or kind == "a" and 3
      or kind == "k" and 4
      or kind == "p" and (side == "r" and 5 or 6)
    local offset, move_count = Geometry.move_range(geometry_kind, entry.square)
    for index = 0, move_count - 1 do
      local _, _, target, blocker = Geometry.move_at(offset + index)
      visit(target, blocker ~= 99 and blocker or nil)
      if overflow then return nil end
    end
  else
    fallback_local_attacks(entry, visit)
  end
  return overflow and nil or count
end

local function emit_piece_attacks(state, entry, amount, depth, count)
  local kind = entry.piece:lower()
  if kind == "r" or kind == "c" then
    return emit_slider_attacks(state, entry, amount, depth, count)
  end
  return emit_local_attacks(state, entry, amount, depth, count)
end

local function piece_attack_affected(entry, from, to)
  if entry.square == from or entry.square == to then return true end
  local kind = entry.piece:lower()
  local r, c = entry.r, entry.c
  local fr, fc = math.floor(from / 9), from % 9
  local tr, tc = math.floor(to / 9), to % 9
  if kind == "r" or kind == "c" then
    return r == fr or c == fc or r == tr or c == tc
  elseif kind == "n" then
    for _, step in ipairs(HORSE_ATTACKS) do
      local leg = idx(r + step[3], c + step[4])
      if leg == from or leg == to then return true end
    end
  elseif kind == "b" then
    for _, step in ipairs(ELEPHANT_DIAGONALS) do
      local eye = idx(r + step[1] / 2, c + step[2] / 2)
      if eye == from or eye == to then return true end
    end
  end
  return false
end

local function emit_affected_attacks(state, from, to, amount, depth, count)
  for _, side in ipairs({ "r", "b" }) do
    for _, entry in ipairs(state.pieces[side]) do
      if piece_attack_affected(entry, from, to) then
        count = emit_piece_attacks(state, entry, amount, depth, count)
        if not count then return nil end
      end
    end
  end
  return count
end

local function compute_flying(state)
  local red, black = state.kings.r, state.kings.b
  if not red or not black or red.r == nil or black.r == nil or red.c ~= black.c then return false end
  local step = black.r > red.r and 1 or -1
  local r = red.r + step
  while r ~= black.r do
    if state.cells[idx(r, red.c) + 1] ~= EMPTY then return false end
    r = r + step
  end
  return true
end

local function apply_attack_slice(state, depth, count, reverse)
  local base = (depth - 1) * ATTACK_DELTA_PER_PLY
  if reverse then
    for index = count, 1, -1 do
      local square, side, occupied, kind_index, amount =
        decode_attack_delta(state.attack_delta_values[base + index])
      if not change_attack_live(state, side, square, occupied, kind_index, -amount) then return false end
    end
  else
    for index = 1, count do
      local square, side, occupied, kind_index, amount =
        decode_attack_delta(state.attack_delta_values[base + index])
      if not change_attack_live(state, side, square, occupied, kind_index, amount) then
        for rollback = index - 1, 1, -1 do
          local old_square, old_side, old_occupied, old_kind_index, old_amount =
            decode_attack_delta(state.attack_delta_values[base + rollback])
          change_attack_live(
            state, old_side, old_square, old_occupied, old_kind_index, -old_amount
          )
        end
        return false
      end
    end
  end
  return true
end

local function initialize_attack_state(state)
  for square = 1, 90 do
    if state.watchdog and square % 8 == 0 then state.watchdog:feed() end
    state.attack_empty_count_r[square], state.attack_empty_count_b[square] = 0, 0
    state.attack_occ_count_r[square], state.attack_occ_count_b[square] = 0, 0
    state.attack_empty_packed_r[square], state.attack_empty_packed_b[square] = 0, 0
    state.attack_occ_packed_r[square], state.attack_occ_packed_b[square] = 0, 0
    state.attack_empty_kinds_r[square], state.attack_empty_kinds_b[square] = 0, 0
    state.attack_occ_kinds_r[square], state.attack_occ_kinds_b[square] = 0, 0
  end
  -- 初始化在搜索树外，可直改活数组而不占 undo 切片。
  local function add_initial(entry)
    if state.watchdog then state.watchdog:feed() end
    local count = emit_piece_attacks(state, entry, 1, 1, 0)
    if not count then return false end
    return apply_attack_slice(state, 1, count, false)
  end
  for _, side in ipairs({ "r", "b" }) do
    for _, entry in ipairs(state.pieces[side]) do
      if not add_initial(entry) then return false end
    end
  end
  state.flying = compute_flying(state)
  return true
end

local function search_resource_failure(state, reason)
  state.search_error_reason = state.search_error_reason or reason
  return nil, reason
end

local function restore_search_position(state, token)
  local from, to = token.from, token.to
  local moving, taken = token.moving, token.taken
  local captured_side = side_of(token.captured)
  state.cells[from + 1], state.cells[to + 1] = token.piece, token.captured
  state.occupancy[from + 1] = true
  state.occupancy[to + 1] = token.captured ~= EMPTY
  state.by_square[from + 1], state.by_square[to + 1] = moving, taken
  moving.r, moving.c, moving.square = token.r, token.c, from
  if taken and captured_side then
    local list = state.pieces[captured_side]
    local old_len = #list + 1
    if token.taken_was_last then
      list[old_len] = taken
      taken.slot = old_len
    else
      list[token.taken_slot] = taken
      taken.slot = token.taken_slot
      list[old_len] = token.taken_last
      token.taken_last.slot = old_len
    end
  end
  state.hash_hi, state.hash_lo = token.old_hash_hi, token.old_hash_lo
  state.piece_count = token.old_piece_count
  local side = side_of(token.piece)
  if side and state.kings[side] then
    state.kings[side].r, state.kings[side].c = token.old_king_r, token.old_king_c
  end
  if captured_side and state.kings[captured_side] then
    state.kings[captured_side].r, state.kings[captured_side].c =
      token.old_taken_king_r, token.old_taken_king_c
  end
end

local function search_apply(state, move_or_r, c, tr, tc)
  if not state or not state.cells then return nil, "invalid_search_state" end
  local r
  if type(move_or_r) == "table" then
    r, c, tr, tc = move_or_r.r, move_or_r.c, move_or_r.tr, move_or_r.tc
  else
    r = move_or_r
  end
  state.search_apply_count = (state.search_apply_count or 0) + 1
  local from = idx(r, c)
  local to = idx(tr, tc)
  local piece = state.cells[from + 1]
  local captured = state.cells[to + 1]
  if not piece or piece == EMPTY then return nil, "empty_source" end
  local side = side_of(piece)
  local captured_side = side_of(captured)
  if captured_side == side then return nil, "friendly_target" end
  if state.undo_depth >= state.undo_capacity then
    return search_resource_failure(state, "undo_overflow")
  end

  local depth = state.undo_depth + 1
  if depth > ATTACK_PLY_CAP then return search_resource_failure(state, "attack_ply_overflow") end
  local token = state.undo_stack[depth]
  if token.active then return nil, "token_in_use" end
  local moving = state.by_square[from + 1]
  if not moving then return nil, "missing_piece_entry" end
  local taken = state.by_square[to + 1]
  token.from, token.to = from, to
  token.r, token.c, token.tr, token.tc = r, c, tr, tc
  token.piece, token.captured = piece, captured
  token.moving, token.taken = moving, taken
  token.moving_slot = moving and moving.slot or 0
  token.taken_slot = taken and taken.slot or 0
  token.taken_last = nil
  token.taken_was_last = false
  token.old_hash_hi, token.old_hash_lo = state.hash_hi, state.hash_lo
  token.old_piece_count = state.piece_count
  token.old_flying = state.flying
  token.attack_delta_count = 0
  token.owner_depth = 0
  token.active = false
  token.old_king_r, token.old_king_c = nil, nil
  token.old_taken_king_r, token.old_taken_king_c = nil, nil
  if side and state.kings[side] then
    token.old_king_r, token.old_king_c = state.kings[side].r, state.kings[side].c
  end
  if captured_side and state.kings[captured_side] then
    token.old_taken_king_r, token.old_taken_king_c =
      state.kings[captured_side].r, state.kings[captured_side].c
  end

  -- 先构造完整新旧攻击差，溢出是独立的可回滚搜索停止。
  local attack_delta_count = emit_affected_attacks(state, from, to, -1, depth, 0)
  if not attack_delta_count then
    state.attack_overflow = state.attack_overflow + 1
    return search_resource_failure(state, "attack_overflow")
  end

  search_hash_piece(state, from, piece)
  search_hash_piece(state, to, captured)
  search_hash_piece(state, to, piece)
  state.cells[from + 1], state.cells[to + 1] = EMPTY, piece
  state.occupancy[from + 1], state.occupancy[to + 1] = false, true
  state.by_square[from + 1], state.by_square[to + 1] = nil, moving
  moving.r, moving.c, moving.square = tr, tc, to

  if taken and captured_side then
    local list = state.pieces[captured_side]
    local slot, last_slot = taken.slot, #list
    token.taken_was_last = slot == last_slot
    token.taken_last = list[last_slot]
    if slot ~= last_slot then
      list[slot] = list[last_slot]
      list[slot].slot = slot
    end
    list[last_slot] = nil
    taken.slot = 0
    state.piece_count = state.piece_count - 1
    if captured:lower() == "k" then
      state.kings[captured_side].r, state.kings[captured_side].c = nil, nil
    end
  end
  if piece:lower() == "k" then
    state.kings[side].r, state.kings[side].c = tr, tc
  end

  attack_delta_count = emit_affected_attacks(
    state, from, to, 1, depth, attack_delta_count
  )
  if not attack_delta_count then
    restore_search_position(state, token)
    state.flying = token.old_flying
    state.attack_overflow = state.attack_overflow + 1
    return search_resource_failure(state, "attack_overflow")
  end
  if not apply_attack_slice(state, depth, attack_delta_count, false) then
    restore_search_position(state, token)
    state.flying = token.old_flying
    return search_resource_failure(state, "attack_state_error")
  end
  state.flying = compute_flying(state)
  token.attack_delta_count = attack_delta_count
  token.owner_depth = depth
  token.active = true
  state.undo_depth = depth
  return token
end

local function search_undo(state, token)
  if not state or not token or state.undo_depth <= 0
    or token.active ~= true or token.owner_depth ~= state.undo_depth
    or state.undo_stack[state.undo_depth] ~= token then
    if state then state.token_undo_failures = (state.token_undo_failures or 0) + 1 end
    return false
  end
  if not apply_attack_slice(state, state.undo_depth, token.attack_delta_count, true) then
    state.token_undo_failures = (state.token_undo_failures or 0) + 1
    return false
  end
  restore_search_position(state, token)
  state.flying = token.old_flying
  token.active = false
  token.owner_depth = 0
  token.attack_delta_count = 0
  state.undo_depth = state.undo_depth - 1
  state.token_undo_successes = (state.token_undo_successes or 0) + 1
  return true
end

local SEARCH_STATE_POOL = {}

local function fill_search_state(state, board, side)
  for square = 0, 89 do
    if state.watchdog and square % 8 == 0 then state.watchdog:feed() end
    local r, c = math.floor(square / 9), square % 9
    local piece = at(board, r, c)
    state.cells[square + 1] = piece
    state.occupancy[square + 1] = piece ~= EMPTY
    state.by_square[square + 1] = nil
    if piece ~= EMPTY then
      local side_key = side_of(piece)
      local list = state.pieces[side_key]
      local entry = { r = r, c = c, piece = piece, square = square, slot = #list + 1 }
      list[#list + 1] = entry
      state.by_square[square + 1] = entry
      state.piece_count = state.piece_count + 1
      search_hash_piece(state, square, piece)
      if piece:lower() == "k" then
        state.kings[side_key].r, state.kings[side_key].c = r, c
      end
    end
  end
end

local function create_search_state(board, side, watchdog)
  local state = {
    cells = {}, occupancy = {}, by_square = {}, pieces = { r = {}, b = {} },
    kings = { r = { r = nil, c = nil }, b = { r = nil, c = nil } },
    hash_hi = 0, hash_lo = 0, piece_count = 0, side = side,
    undo_capacity = SEARCH_UNDO_CAPACITY, undo_depth = 0, undo_stack = {},
    indexed_move_generation_count = 0, full_board_piece_discovery_scans = 0,
    hash_key_build_count = 0, undo_allocations = 0, search_apply_count = 0,
    token_undo_successes = 0, token_undo_failures = 0,
    attack_empty_count_r = {}, attack_empty_count_b = {},
    attack_occ_count_r = {}, attack_occ_count_b = {},
    attack_empty_packed_r = {}, attack_empty_packed_b = {},
    attack_occ_packed_r = {}, attack_occ_packed_b = {},
    attack_empty_kinds_r = {}, attack_empty_kinds_b = {},
    attack_occ_kinds_r = {}, attack_occ_kinds_b = {},
    attack_delta_values = {}, attack_delta_limit = ATTACK_DELTA_PER_PLY,
    attack_overflow = 0, flying = false, search_error_reason = nil,
    watchdog = watchdog,
  }
  for depth = 1, SEARCH_UNDO_CAPACITY do
    state.undo_stack[depth] = { active = false, owner_depth = 0, attack_delta_count = 0 }
    if watchdog and depth % 8 == 0 then watchdog:feed() end
  end
  for index = 1, ATTACK_DELTA_PER_PLY * ATTACK_PLY_CAP do
    state.attack_delta_values[index] = 0
    if watchdog and index % 256 == 0 then watchdog:feed() end
  end
  fill_search_state(state, board, side)
  if not initialize_attack_state(state) then
    state.attack_init_error = "attack_overflow"
  end
  return state
end

local function reset_search_state(state, board, side)
  state.side = side
  state.hash_hi, state.hash_lo = 0, 0
  state.piece_count = 0
  state.undo_depth = 0
  state.indexed_move_generation_count, state.full_board_piece_discovery_scans = 0, 0
  state.hash_key_build_count, state.undo_allocations, state.search_apply_count = 0, 0, 0
  state.token_undo_successes, state.token_undo_failures = 0, 0
  state.attack_overflow = 0
  state.flying = false
  state.search_error_reason = nil
  state.attack_init_error = nil
  state.pooled = nil
  state.undo_capacity, state.attack_delta_limit = SEARCH_UNDO_CAPACITY, ATTACK_DELTA_PER_PLY
  state.pieces.r = {}
  state.pieces.b = {}
  state.kings.r.r, state.kings.r.c = nil, nil
  state.kings.b.r, state.kings.b.c = nil, nil
  for depth = 1, SEARCH_UNDO_CAPACITY do
    if state.watchdog and depth % 8 == 0 then state.watchdog:feed() end
    local slot = state.undo_stack[depth]
    slot.active = false
    slot.owner_depth = 0
    slot.attack_delta_count = 0
  end
  fill_search_state(state, board, side)
  if not initialize_attack_state(state) then
    state.attack_init_error = "attack_overflow"
  end
  return state
end

local function new_search_state(board, side, watchdog)
  local state = table.remove(SEARCH_STATE_POOL)
  if state then
    state.watchdog = watchdog
    return reset_search_state(state, board, side)
  end
  return create_search_state(board, side, watchdog)
end

local function release_search_state(state)
  if not state or state.pooled then return end
  state.pooled = true
  state.watchdog = nil
  if #SEARCH_STATE_POOL < 2 then
    SEARCH_STATE_POOL[#SEARCH_STATE_POOL + 1] = state
  end
end

local function search_board(state)
  if not state or not state.cells then return state end
  return table.concat(state.cells)
end

-- 规则级攻击探测：不分配着法表、不查自身暴露，可在大量节点安全调用；合法性仍走 is_legal_move/in_check。
square_attacked = function(board, attacker_side, tr, tc, target_piece)
  if type(board) == "table" and board.attack_empty_count_r then
    if target_piece and target_piece:lower() == "k" then
      local general = board.kings[attacker_side]
      if general and general.r ~= nil and general.c == tc and general.r ~= tr
        and clear_path(board, general.r, general.c, tr, tc) then return true end
    end
    local occupied
    if target_piece ~= nil then
      occupied = target_piece ~= EMPTY
    else
      occupied = at(board, tr, tc) ~= EMPTY
    end
    local counts = attack_arrays(board, attacker_side, occupied)
    return (counts[idx(tr, tc) + 1] or 0) > 0
  end
  if type(board) == "table" and board.pieces then
    for _, entry in ipairs(board.pieces[attacker_side] or {}) do
      if attack_rule_ok(board, entry.r, entry.c, tr, tc, target_piece) then
        return true
      end
    end
    return false
  end
  for r = 0, 9 do
    for c = 0, 8 do
      local ch = at(board, r, c)
      if ch ~= EMPTY and side_of(ch) == attacker_side then
        if attack_rule_ok(board, r, c, tr, tc, target_piece) then return true end
      end
    end
  end
  return false
end

local function build_attack_map(board, attacker_side, detail_targets)
  local occupied, king, counts, attackers = {}, {}, {}, {}
  local detailed = nil
  if detail_targets then
    detailed = {}
    for _, target in ipairs(detail_targets) do
      detailed[idx(target.r, target.c)] = true
    end
  end
  local function mark(r, c, kind)
    if r >= 0 and r <= 9 and c >= 0 and c <= 8 then
      local key = idx(r, c)
      occupied[key], king[key] = true, true
      if not detailed or detailed[key] then
        counts[key] = (counts[key] or 0) + 1
        local kinds = attackers[key] or {}
        kinds[kind] = (kinds[kind] or 0) + 1
        attackers[key] = kinds
      end
    end
  end
  local function ray(r, c, dr, dc, cannon, kind)
    local rr, cc = r + dr, c + dc
    local screened = false
    while rr >= 0 and rr <= 9 and cc >= 0 and cc <= 8 do
      local target = at(board, rr, cc)
      if cannon then
        if screened then
          mark(rr, cc, kind)
          if target ~= EMPTY then return end
        elseif target ~= EMPTY then
          screened = true
        end
      else
        mark(rr, cc, kind)
        if target ~= EMPTY then return end
      end
      rr, cc = rr + dr, cc + dc
    end
  end

  local function visit_piece(r, c, ch)
    if ch == EMPTY or side_of(ch) ~= attacker_side then return end
    local kind = ch:lower()
    if kind == "r" or kind == "c" then
      local cannon = kind == "c"
      ray(r, c, -1, 0, cannon, kind); ray(r, c, 1, 0, cannon, kind)
      ray(r, c, 0, -1, cannon, kind); ray(r, c, 0, 1, cannon, kind)
    elseif kind == "n" then
      for _, d in ipairs(HORSE_ATTACKS) do
        if at(board, r + d[3], c + d[4]) == EMPTY then
          mark(r + d[1], c + d[2], kind)
        end
      end
    elseif kind == "b" then
      for _, d in ipairs(ELEPHANT_DIAGONALS) do
        local tr, tc = r + d[1], c + d[2]
        local own_half = attacker_side == "r" and tr >= 5 or attacker_side == "b" and tr <= 4
        if own_half and at(board, r + d[1] / 2, c + d[2] / 2) == EMPTY then
          mark(tr, tc, kind)
        end
      end
    elseif kind == "a" then
      for _, d in ipairs(ADVISOR_DIAGONALS) do
        local tr, tc = r + d[1], c + d[2]
        if in_palace(tr, tc, attacker_side) then mark(tr, tc, kind) end
      end
    elseif kind == "k" then
      for _, d in ipairs(GENERAL_STEPS) do
        local tr, tc = r + d[1], c + d[2]
        if in_palace(tr, tc, attacker_side) then mark(tr, tc, kind) end
      end
      for rr = r - 1, 0, -1 do
        local target = at(board, rr, c)
        king[idx(rr, c)] = true
        if target ~= EMPTY then break end
      end
      for rr = r + 1, 9 do
        local target = at(board, rr, c)
        king[idx(rr, c)] = true
        if target ~= EMPTY then break end
      end
    elseif kind == "p" then
      local dr = attacker_side == "r" and -1 or 1
      mark(r + dr, c, kind)
      local crossed = attacker_side == "r" and r <= 4 or attacker_side == "b" and r >= 5
      if crossed then mark(r, c - 1, kind); mark(r, c + 1, kind) end
    end
  end

  if type(board) == "table" and board.pieces then
    for _, entry in ipairs(board.pieces[attacker_side] or {}) do
      visit_piece(entry.r, entry.c, entry.piece)
    end
  else
    for r = 0, 9 do
      for c = 0, 8 do visit_piece(r, c, at(board, r, c)) end
    end
  end
  return { occupied = occupied, king = king, counts = counts, attackers = attackers }
end

local function is_legal_move(board, side, r, c, tr, tc)
  local ch = at(board, r, c)
  if not ch or ch == EMPTY or side_of(ch) ~= side then return false end
  local target = at(board, tr, tc)
  if target ~= EMPTY and side_of(target) == side then return false end
  if not move_rule_ok(board, r, c, tr, tc) then return false end
  if type(board) == "table" and board.cells then
    local token, reason = search_apply(board, r, c, tr, tc)
    if not token then return false, reason end
    local legal = not in_check(board, side)
    search_undo(board, token)
    return legal
  end
  local nb = setc(setc(board, r, c, EMPTY), tr, tc, ch)
  return not in_check(nb, side)
end

local function candidate_destinations(board, r, c)
  local out = {}
  local function add(tr, tc)
    if tr >= 0 and tr <= 9 and tc >= 0 and tc <= 8 then
      out[#out + 1] = { r = tr, c = tc }
    end
  end
  local ch = at(board, r, c)
  local t = ch:lower():sub(1, 1)

  if t == "r" or t == "c" then
    local function ray(dr, dc)
      local tr, tc = r + dr, c + dc
      local screened = false
      while tr >= 0 and tr <= 9 and tc >= 0 and tc <= 8 do
        local target = at(board, tr, tc)
        if t == "r" then
          add(tr, tc)
          if target ~= EMPTY then return end
        elseif not screened then
          if target == EMPTY then add(tr, tc) else screened = true end
        elseif target ~= EMPTY then
          if side_of(target) ~= side_of(ch) then add(tr, tc) end
          return
        end
        tr, tc = tr + dr, tc + dc
      end
    end
    ray(-1, 0); ray(1, 0); ray(0, -1); ray(0, 1)
  elseif t == "n" then
    for _, d in ipairs(HORSE_ATTACKS) do add(r + d[1], c + d[2]) end
  elseif t == "b" then
    add(r - 2, c - 2); add(r - 2, c + 2); add(r + 2, c - 2); add(r + 2, c + 2)
  elseif t == "a" then
    add(r - 1, c - 1); add(r - 1, c + 1); add(r + 1, c - 1); add(r + 1, c + 1)
  elseif t == "k" then
    add(r - 1, c); add(r + 1, c); add(r, c - 1); add(r, c + 1)
    -- 将帅照面：同列远距离吃将纳入候选以保留完整规则。
    for tr = r - 1, 0, -1 do
      local target = at(board, tr, c)
      if target ~= EMPTY then if side_of(target) ~= side_of(ch) and target:lower():sub(1, 1) == "k" then add(tr, c) end; break end
    end
    for tr = r + 1, 9 do
      local target = at(board, tr, c)
      if target ~= EMPTY then if side_of(target) ~= side_of(ch) and target:lower():sub(1, 1) == "k" then add(tr, c) end; break end
    end
  elseif t == "p" then
    if side_of(ch) == "r" then
      add(r - 1, c)
      if r <= 4 then add(r, c - 1); add(r, c + 1) end
    else
      add(r + 1, c)
      if r >= 5 then add(r, c - 1); add(r, c + 1) end
    end
  end
  return out
end

local function is_pseudo_legal_move(board, side, r, c, tr, tc)
  if r < 0 or r > 9 or c < 0 or c > 8
    or tr < 0 or tr > 9 or tc < 0 or tc > 8 then return false end
  local piece = at(board, r, c)
  if piece == EMPTY or side_of(piece) ~= side then return false end
  local target = at(board, tr, tc)
  if target ~= EMPTY and side_of(target) == side then return false end
  return move_rule_ok(board, r, c, tr, tc)
end

local function search_move_encode(r, c, tr, tc)
  return idx(r, c) * 90 + idx(tr, tc)
end

local function search_move_decode(code)
  local from = math.floor(code / 90)
  local to = code % 90
  return math.floor(from / 9), from % 9, math.floor(to / 9), to % 9
end

local SEARCH_GEOMETRY_KIND = { n = 1, b = 2, a = 3, k = 4 }
local KING_RAY_DIRECTIONS = { 0, 2 }

local function finish_search_cursor_piece(cursor)
  cursor.mode = nil
  cursor.entry = nil
  cursor.piece_index = cursor.piece_index + 1
end

local function begin_search_cursor_piece(cursor, entry)
  cursor.entry = entry
  cursor.from = entry.square
  cursor.kind = entry.piece:lower()
  cursor.fallback_targets = nil
  cursor.fallback_index = 1
  if not Geometry.is_ready() then
    cursor.mode = "fallback"
    cursor.fallback_targets = candidate_destinations(cursor.board, entry.r, entry.c)
    return
  end
  if cursor.kind == "r" or cursor.kind == "c" then
    cursor.mode = "slider"
    cursor.ray_direction = 0
    cursor.ray_index = 0
    cursor.screened = false
    cursor.ray_offset, cursor.ray_count = Geometry.ray_range(cursor.from, 0)
    return
  end
  local geometry_kind = SEARCH_GEOMETRY_KIND[cursor.kind]
  if cursor.kind == "p" then
    geometry_kind = side_of(entry.piece) == "r" and 5 or 6
  end
  cursor.mode = "local"
  cursor.local_index = 0
  cursor.local_offset, cursor.local_count = Geometry.move_range(geometry_kind, cursor.from)
end

local function append_search_move(cursor, target)
  local target_piece = cursor.board.cells[target + 1]
  if target_piece ~= EMPTY and side_of(target_piece) == cursor.side then return false end
  cursor.moves[#cursor.moves + 1] = cursor.from * 90 + target
  return true
end

local function advance_search_ray(cursor)
  cursor.ray_direction = cursor.ray_direction + 1
  cursor.ray_index = 0
  cursor.screened = false
  if cursor.ray_direction > 3 then
    finish_search_cursor_piece(cursor)
    return
  end
  cursor.ray_offset, cursor.ray_count = Geometry.ray_range(
    cursor.from, cursor.ray_direction
  )
end

local function resume_search_slider(cursor)
  if cursor.ray_index >= cursor.ray_count then
    advance_search_ray(cursor)
    return false
  end
  local target = Geometry.ray_at(cursor.ray_offset + cursor.ray_index)
  cursor.ray_index = cursor.ray_index + 1
  local target_piece = cursor.board.cells[target + 1]
  if cursor.kind == "r" then
    local appended = append_search_move(cursor, target)
    if target_piece ~= EMPTY then advance_search_ray(cursor) end
    return appended
  end
  if not cursor.screened then
    if target_piece == EMPTY then return append_search_move(cursor, target) end
    cursor.screened = true
    return false
  end
  if target_piece ~= EMPTY then
    local appended = append_search_move(cursor, target)
    advance_search_ray(cursor)
    return appended
  end
  return false
end

local function begin_king_flying(cursor)
  cursor.mode = "king_flying"
  cursor.king_direction_index = 1
  cursor.ray_index = 0
  cursor.ray_offset, cursor.ray_count = Geometry.ray_range(
    cursor.from, KING_RAY_DIRECTIONS[1]
  )
end

local function resume_search_king_flying(cursor)
  if cursor.ray_index >= cursor.ray_count then
    cursor.king_direction_index = cursor.king_direction_index + 1
    if cursor.king_direction_index > #KING_RAY_DIRECTIONS then
      finish_search_cursor_piece(cursor)
      return false
    end
    cursor.ray_index = 0
    cursor.ray_offset, cursor.ray_count = Geometry.ray_range(
      cursor.from, KING_RAY_DIRECTIONS[cursor.king_direction_index]
    )
    return false
  end
  local target = Geometry.ray_at(cursor.ray_offset + cursor.ray_index)
  cursor.ray_index = cursor.ray_index + 1
  local target_piece = cursor.board.cells[target + 1]
  if target_piece == EMPTY then return false end
  local capture = side_of(target_piece) ~= cursor.side and target_piece:lower() == "k"
  cursor.ray_index = cursor.ray_count
  return capture and append_search_move(cursor, target) or false
end

local function resume_search_local(cursor)
  if cursor.local_index >= cursor.local_count then
    if cursor.kind == "k" then begin_king_flying(cursor) else finish_search_cursor_piece(cursor) end
    return false
  end
  local _, _, target, blocker = Geometry.move_at(cursor.local_offset + cursor.local_index)
  cursor.local_index = cursor.local_index + 1
  if blocker ~= 99 and cursor.board.cells[blocker + 1] ~= EMPTY then return false end
  return append_search_move(cursor, target)
end

local function resume_search_fallback(cursor)
  local target = cursor.fallback_targets[cursor.fallback_index]
  if not target then finish_search_cursor_piece(cursor); return false end
  cursor.fallback_index = cursor.fallback_index + 1
  local entry = cursor.entry
  local target_piece = at(cursor.board, target.r, target.c)
  if target_piece ~= EMPTY and side_of(target_piece) == cursor.side then return false end
  if not move_rule_ok(cursor.board, entry.r, entry.c, target.r, target.c) then return false end
  return append_search_move(cursor, idx(target.r, target.c))
end

local function begin_search_moves(board, side)
  board.indexed_move_generation_count = (board.indexed_move_generation_count or 0) + 1
  return {
    board = board, side = side, piece_entries = board.pieces[side], piece_index = 1,
    entry = nil, mode = nil, moves = {}, done = false,
  }
end

local function resume_search_moves(cursor, should_stop, stop_after_first)
  while not cursor.done do
    if stop_after_first and #cursor.moves > 0 then return true end
    if should_stop and should_stop() then return false end
    if not cursor.mode then
      local entry = cursor.piece_entries[cursor.piece_index]
      if not entry then cursor.done = true; return true end
      begin_search_cursor_piece(cursor, entry)
    end
    local appended = cursor.mode == "slider" and resume_search_slider(cursor)
      or cursor.mode == "local" and resume_search_local(cursor)
      or cursor.mode == "king_flying" and resume_search_king_flying(cursor)
      or cursor.mode == "fallback" and resume_search_fallback(cursor)
    if stop_after_first and appended then return true end
  end
  return true
end

local function collect_moves(board, side)
  local moves = {}
  if type(board) == "table" and board.pieces then
    for _, entry in ipairs(board.pieces[side] or {}) do
      for _, target in ipairs(candidate_destinations(board, entry.r, entry.c)) do
        if is_legal_move(board, side, entry.r, entry.c, target.r, target.c) then
          moves[#moves + 1] = {
            r = entry.r, c = entry.c, tr = target.r, tc = target.c,
          }
        end
      end
    end
    return moves
  end
  for r = 0, 9 do
    for c = 0, 8 do
      local ch = at(board, r, c)
      if ch ~= EMPTY and side_of(ch) == side then
        for _, target in ipairs(candidate_destinations(board, r, c)) do
          if is_legal_move(board, side, r, c, target.r, target.c) then
            moves[#moves + 1] = { r = r, c = c, tr = target.r, tc = target.c }
          end
        end
      end
    end
  end
  return moves
end

local function first_legal_move(board, side)
  for r = 0, 9 do
    for c = 0, 8 do
      local ch = at(board, r, c)
      if ch ~= EMPTY and side_of(ch) == side then
        for _, target in ipairs(candidate_destinations(board, r, c)) do
          if is_legal_move(board, side, r, c, target.r, target.c) then
            return { r = r, c = c, tr = target.r, tc = target.c }
          end
        end
      end
    end
  end
  return nil
end

local function collect_moves_limited(board, side, should_stop)
  local cursor = M.begin_board_moves(board, side)
  M.resume_board_moves(cursor, should_stop)
  return { moves = cursor.moves, stopped = not cursor.done }
end

local function new_game(s)
  s.board = INITIAL
  s.turn = "r"
  s.selR, s.selC = nil, nil
  s.cursorR, s.cursorC = 9, 4
  s.status = "playing"
  s.in_check = false
  s.check_anim_t = 0
  s.message = "红方先行 · 点选棋子"
  s.moves = 0
  s.pace = ""
  s.book_out = false
  s.ai_order_hint = nil
  s.last = nil
  s.move_history = {}
  s.position_counts = { [position_key(s.board, s.turn)] = 1 }
  s.undo_stack = {}
end

local function apply_move(s, r, c, tr, tc)
  local ch = at(s.board, r, c)
  local captured = at(s.board, tr, tc)
  s.board = setc(setc(s.board, r, c, EMPTY), tr, tc, ch)
  s.last = { fr = r, fc = c, tr = tr, tc = tc, captured = captured }
  s.moves = s.moves + 1
  s.pace = (s.pace or "") .. c .. r .. tc .. tr
  local mover = s.turn
  s.move_history = s.move_history or {}
  s.move_history[#s.move_history + 1] = {
    side = mover, r = r, c = c, tr = tr, tc = tc,
  }
  if #s.move_history > 8 then table.remove(s.move_history, 1) end
  s.turn = (mover == "r") and "b" or "r"
  s.position_counts = s.position_counts or {}
  local key = position_key(s.board, s.turn)
  s.position_counts[key] = (s.position_counts[key] or 0) + 1
  s.selR, s.selC = nil, nil

  local gr = find_general(s.board, s.turn)
  if not gr then
    s.status = (mover == "r") and "red_win" or "black_win"
    s.message = (mover == "r") and "红方获胜" or "黑方获胜"
    return
  end

  local check = in_check(s.board, s.turn)
  s.in_check = check
  local has_move = first_legal_move(s.board, s.turn)
  if not has_move then
    s.status = (mover == "r") and "red_win" or "black_win"
    s.message = ((mover == "r") and "红方胜" or "黑方胜")
      .. (check and " · 将死" or " · 困毙")
  elseif check then
    s.message = ((s.turn == "r") and "红方" or "黑方") .. "被将军"
  else
    s.message = ((s.turn == "r") and "红方" or "黑方") .. "走棋"
  end
end

function M.get(ctx)
  local s = ctx.state.chess
  if not s then s = {}; ctx.state.chess = s end
  if (s.v ~= 1 and s.v ~= 2) or not s.board or #s.board ~= 90 then
    s.v = 2
    new_game(s)
    s.screen = "menu"
    s.menuIdx = 1
    s.setupIdx = 1
    s.mode = "ai"
    s.difficulty = 1
  end
  if s.v == 1 then s.v = 2 end
  if s.mode == "puzzle" or s.screen == "puzzle_select"
    or s.puzzle_progress or s.puzzle_id or s.puzzle_step
    or s.puzzle_red_moves or s.puzzle_notice then
    new_game(s)
    s.v = 2
    s.screen = "menu"
    s.menuIdx = 1
    s.setupIdx = 1
    s.mode = "ai"
    s.difficulty = 1
    s.puzzle_progress = nil
    s.puzzle_id = nil
    s.puzzle_step = nil
    s.puzzle_red_moves = nil
    s.puzzle_notice = nil
  end
  if s.turn ~= "r" and s.turn ~= "b" then new_game(s); s.screen = "menu" end
  if s.mode ~= "ai" and s.mode ~= "pvp" then s.mode = "ai" end
  if not s.difficulty then s.difficulty = 1 end
  if s.difficulty ~= 1 and s.difficulty ~= 2 and s.difficulty ~= 3 then s.difficulty = 1 end
  if s.status == nil then s.status = "playing" end
  if s.in_check == nil then s.in_check = in_check(s.board, s.turn) end
  s.position_counts = s.position_counts or { [position_key(s.board, s.turn)] = 1 }
  s.move_history = copy_move_history(s.move_history)
  local current_key = position_key(s.board, s.turn)
  if not s.position_counts[current_key] then s.position_counts[current_key] = 1 end
  if not s.menuIdx then s.menuIdx = 1 end
  if not s.setupIdx then s.setupIdx = 1 end
  if s.screen ~= "menu" and s.screen ~= "setup" and s.screen ~= "game" then s.screen = "menu" end
  return s
end

function M.new_game(s) new_game(s) end

function M.load_position(s, board, turn)
  s.board = board
  s.turn = turn or "r"
  s.selR, s.selC = nil, nil
  s.cursorR, s.cursorC = 9, 4
  s.status = "playing"
  s.in_check = in_check(s.board, s.turn)
  s.check_anim_t = 0
  s.message = "红方先行 · 找出杀着"
  s.moves = 0
  s.pace = ""
  s.book_out = false
  s.ai_order_hint = nil
  s.last = nil
  s.move_history = {}
  s.position_counts = { [position_key(s.board, s.turn)] = 1 }
  s.undo_stack = {}
end

function M.push_undo(s)
  s.undo_stack = s.undo_stack or {}
  s.undo_stack[#s.undo_stack + 1] = {
    board = s.board,
    turn = s.turn,
    status = s.status,
    in_check = s.in_check,
    message = s.message,
    moves = s.moves,
    pace = s.pace,
    book_out = s.book_out,
    last = s.last,
    move_history = copy_move_history(s.move_history),
    position_counts = copy_position_counts(s.position_counts),
    ai_mood = s.ai_mood,
    ai_dialog = s.ai_dialog,
  }
end

function M.can_undo(s)
  return type(s.undo_stack) == "table" and #s.undo_stack > 0
end

function M.undo(s)
  if not M.can_undo(s) then return false end
  local snapshot = table.remove(s.undo_stack)
  s.board = snapshot.board
  s.turn = snapshot.turn
  s.status = snapshot.status
  s.in_check = snapshot.in_check
  s.message = snapshot.message
  s.moves = snapshot.moves
  s.pace = snapshot.pace or ""
  s.book_out = snapshot.book_out or false
  s.last = snapshot.last
  s.move_history = copy_move_history(snapshot.move_history)
  s.position_counts = copy_position_counts(snapshot.position_counts)
  s.ai_mood = snapshot.ai_mood
  s.ai_dialog = snapshot.ai_dialog
  s.selR, s.selC = nil, nil
  return true
end

function M.piece_at(s, r, c) return at(s.board, r, c) end

function M.piece_label(ch)
  if not ch or ch == EMPTY then return "" end
  return LABEL_BLACK[ch] or LABEL_RED[ch] or ch
end

function M.in_check(s) return in_check(s.board, s.turn) end
function M.board_in_check(board, side) return in_check(board, side) end
function M.board_square_attacked(board, side, r, c, target_piece)
  return square_attacked(board, side, r, c, target_piece)
end
function M.board_attack_map(board, side, detail_targets)
  return build_attack_map(board, side, detail_targets)
end
function M.attack_map_has(map, r, c, king_target)
  return (king_target and map.king or map.occupied)[idx(r, c)] == true
end
function M.attack_map_count(map, r, c)
  return map.counts[idx(r, c)] or 0
end
function M.attack_map_attackers(map, r, c)
  return map.attackers[idx(r, c)] or {}
end

function M.general_pos(s)
  return find_general(s.board, s.turn)
end

function M.legal_targets(s, r, c)
  if s.status ~= "playing" then return {} end
  local ch = at(s.board, r, c)
  if not ch or ch == EMPTY or side_of(ch) ~= s.turn then return {} end
  local out = {}
  for _, target in ipairs(candidate_destinations(s.board, r, c)) do
    if is_legal_move(s.board, s.turn, r, c, target.r, target.c) then
      out[#out + 1] = { tr = target.r, tc = target.c }
    end
  end
  return out
end

-- 落点提示只服务重绘（避免每点全盘将军检测）；实际落子仍经 is_legal_move 校验。
function M.hint_targets(s, r, c)
  if s.status ~= "playing" then return {} end
  local ch = at(s.board, r, c)
  if not ch or ch == EMPTY or side_of(ch) ~= s.turn then return {} end
  local out = {}
  for _, target in ipairs(candidate_destinations(s.board, r, c)) do
    local target_ch = at(s.board, target.r, target.c)
    if (target_ch == EMPTY or side_of(target_ch) ~= s.turn)
      and move_rule_ok(s.board, r, c, target.r, target.c) then
      out[#out + 1] = { tr = target.r, tc = target.c }
    end
  end
  return out
end

function M.tap(s, r, c)
  if s.status ~= "playing" then return false end
  if s.selR and is_legal_move(s.board, s.turn, s.selR, s.selC, r, c) then
    apply_move(s, s.selR, s.selC, r, c)
    return true
  end
  local ch = at(s.board, r, c)
  if s.selR and s.in_check and (ch == EMPTY or side_of(ch) ~= s.turn) then
    s.message = "此着不能解将"
  end
  if ch ~= EMPTY and side_of(ch) == s.turn then
    s.selR, s.selC = r, c
  else
    s.selR, s.selC = nil, nil
  end
  return true
end

-- 提供给 AI 的纯函数接口
function M.side_of(ch) return side_of(ch) end
function M.board_moves(board, side) return collect_moves(board, side) end
function M.board_first_move(board, side) return first_legal_move(board, side) end
function M.begin_board_moves(board, side)
  if type(board) == "table" and board.pieces then
    board.indexed_move_generation_count =
      (board.indexed_move_generation_count or 0) + 1
  end
  return {
    board = board, side = side, r = 0, c = 0,
    piece_entries = type(board) == "table" and board.pieces and board.pieces[side] or nil,
    piece_index = 1,
    targets = nil, target_index = 1, moves = {}, done = false,
  }
end
function M.resume_board_moves(cursor, should_stop, stop_after_first)
  while not cursor.done do
    if stop_after_first and #cursor.moves > 0 then return true end
    if cursor.targets then
      local target = cursor.targets[cursor.target_index]
      if target then
        if should_stop and should_stop() then return false end
        cursor.target_index = cursor.target_index + 1
        local legal, reason = is_legal_move(
          cursor.board, cursor.side, cursor.r, cursor.c, target.r, target.c
        )
        if reason then cursor.error_reason = reason; return false end
        if legal then
          cursor.moves[#cursor.moves + 1] = {
            r = cursor.r, c = cursor.c, tr = target.r, tc = target.c,
          }
          if stop_after_first then return true end
        end
      else
        cursor.targets, cursor.target_index = nil, 1
        if not cursor.piece_entries then
          cursor.c = cursor.c + 1
          if cursor.c > 8 then cursor.r, cursor.c = cursor.r + 1, 0 end
        end
      end
    elseif cursor.piece_entries then
      local entry = cursor.piece_entries[cursor.piece_index]
      if not entry then
        cursor.done = true
      elseif should_stop and should_stop() then
        return false
      else
        cursor.r, cursor.c = entry.r, entry.c
        cursor.targets = candidate_destinations(cursor.board, cursor.r, cursor.c)
        cursor.piece_index = cursor.piece_index + 1
      end
    elseif cursor.r > 9 then
      cursor.done = true
    else
      local ch = at(cursor.board, cursor.r, cursor.c)
      if ch ~= EMPTY and side_of(ch) == cursor.side then
        if should_stop and should_stop() then return false end
        cursor.targets = candidate_destinations(cursor.board, cursor.r, cursor.c)
      else
        cursor.c = cursor.c + 1
        if cursor.c > 8 then cursor.r, cursor.c = cursor.r + 1, 0 end
      end
    end
  end
  return true
end
function M.board_moves_limited(board, side, should_stop)
  return collect_moves_limited(board, side, should_stop)
end

function M.apply_pure(board, r, c, tr, tc)
  local ch = at(board, r, c)
  return setc(setc(board, r, c, EMPTY), tr, tc, ch)
end

function M.new_search_state(board, side, watchdog)
  return new_search_state(board, side, watchdog)
end
function M.release_search_state(state) return release_search_state(state) end
function M.search_apply(state, move_or_r, c, tr, tc)
  return search_apply(state, move_or_r, c, tr, tc)
end
function M.search_undo(state, token) return search_undo(state, token) end
function M.search_board(state) return search_board(state) end
function M.search_at(state, r, c) return at(state, r, c) end
function M.search_hash(state) return state.hash_hi, state.hash_lo end
function M.search_piece_count(state) return state.piece_count end
function M.search_undo_depth(state) return state.undo_depth end
function M.search_undo_capacity() return SEARCH_UNDO_CAPACITY end
function M.search_attack_count(state, side, square, occupied)
  local counts = attack_arrays(state, side, occupied == true)
  return counts[square + 1] or 0
end
function M.search_attack_kinds(state, side, square, occupied)
  local _, _, kinds = attack_arrays(state, side, occupied == true)
  return kinds[square + 1] or 0
end
function M.search_attack_packed(state, side, square, occupied)
  local _, packed = attack_arrays(state, side, occupied == true)
  return packed[square + 1] or 0
end
function M.search_set_attack_delta_limit(state, limit)
  if type(limit) ~= "number" then return false end
  state.attack_delta_limit = math.max(0, math.min(ATTACK_DELTA_PER_PLY, math.floor(limit)))
  return true
end
function M.search_attack_overflow_count(state) return state.attack_overflow or 0 end
function M.search_attack_delta_capacity() return ATTACK_DELTA_PER_PLY, ATTACK_PLY_CAP end
function M.search_apply_count(state) return state.search_apply_count or 0 end
function M.search_token_undo_successes(state) return state.token_undo_successes or 0 end
function M.search_token_undo_failures(state) return state.token_undo_failures or 0 end
function M.search_error_reason(state) return state.search_error_reason end
function M.search_clear_error(state) state.search_error_reason = nil end
function M.search_move_encode(r, c, tr, tc) return search_move_encode(r, c, tr, tc) end
function M.search_move_decode(code) return search_move_decode(code) end
function M.search_pseudo_legal(state, side, r, c, tr, tc)
  return is_pseudo_legal_move(state, side, r, c, tr, tc)
end
function M.begin_search_moves(board, side) return begin_search_moves(board, side) end
function M.resume_search_moves(cursor, should_stop, stop_after_first)
  return resume_search_moves(cursor, should_stop, stop_after_first)
end

function M.apply_move(s, r, c, tr, tc) apply_move(s, r, c, tr, tc) end
function M.is_legal(s, r, c, tr, tc) return is_legal_move(s.board, s.turn, r, c, tr, tc) end
function M.at(board, r, c) return at(board, r, c) end

return M
