-- Xiangqi engine: itlwei tables + opening book baseline, device-safe iterative deepening and tactical search.
local State = require("domain.chess_state")
local Opening = require("domain.chess_opening")
local Evaluation = require("domain.chess_evaluation")
local M = {}

local WIN = 8888
local ALPHA = -99999
local BETA = 99999
local SLICE_MS = 100
local STATIC_SLICE_NODES = 5
local REPLY_SCAN_BUDGET = 36
local THINK_MS = { [1] = 2000, [2] = 2000, [3] = 2000 }
local STATIC_THINK_MS = 2000
local BOOK_BUDGET_MS = 150
local PRECHECK_BUDGET_MS = 950
local SEARCH_RESERVE_MS = 1850
local AI_DIAGNOSTICS = true
local EASY_TACTICAL_ROOTS = 4
local TARGET_DEPTH = { [1] = 1, [2] = 4, [3] = 4 }
local START_DEPTH = { [1] = 1, [2] = 2, [3] = 2 }
local QUIESCENCE_DEPTH = { [1] = 1, [2] = 2, [3] = 3 }
local CHECK_EVASION_DEPTH = 2
local SAFETY_LEAVES = { [1] = 12000, [2] = 50000, [3] = 120000 }
local TT_LIMIT = 1024
local EVAL_CACHE_LIMIT = 512
local MOVE_CACHE_LIMIT = 512
local REPETITION_HISTORY_LIMIT = 128
local RECENT_MOVE_LIMIT = 4
local POINTLESS_REVERSAL_PENALTY = 36
local REPEAT_CHECK_PENALTY = 400
local MOOD_EDGE = 200
local PIECE_VALUE = { p = 10, a = 20, b = 20, n = 45, c = 50, r = 90, k = 900 }
local EXACT = "EXACT"
local LOWER = "LOWER"
local UPPER = "UPPER"

local function other(side) return side == "r" and "b" or "r" end
local function position_key(board, side) return board .. "|" .. side end
local function copy_move(move)
  if not move then return nil end
  return { r = move.r, c = move.c, tr = move.tr, tc = move.tc }
end

local function copy_order_hint(hint)
  if type(hint) ~= "table" then return nil end
  local copy = { hash_move = copy_move(hint.hash_move), killers = {} }
  for depth, moves in pairs(hint.killers or {}) do
    local depth_number = tonumber(depth)
    if depth_number and type(moves) == "table" then
      local pair = {}
      for index = 1, 2 do
        local move = copy_move(moves[index])
        if move then pair[#pair + 1] = move end
      end
      if #pair > 0 then copy.killers[depth_number] = pair end
    end
  end
  if not copy.hash_move and next(copy.killers) == nil then return nil end
  return copy
end

local function build_order_hint(session)
  local hint = copy_order_hint({
    hash_move = session.best,
    killers = session.killers,
  })
  return hint
end

local function copy_counts(counts)
  local copy = {}
  for key, value in pairs(counts or {}) do copy[key] = value end
  return copy
end

local UINT32 = 4294967296

local function string_hash(text, seed)
  local hash = seed
  for index = 1, #text do
    hash = (hash * 33 + text:byte(index)) % UINT32
  end
  return hash
end

local function cache_hash(board, side)
  local hi, lo
  if type(board) == "table" and board.hash_hi then
    board.hash_key_build_count = (board.hash_key_build_count or 0) + 1
    hi, lo = board.hash_hi, board.hash_lo
  else
    local text = tostring(board or "")
    hi = string_hash(text, 2166136261)
    lo = string_hash(text, 2246822519)
  end
  local side_salt = side == "r" and 2654435761 or 2246822519
  return (hi + side_salt) % UINT32, (lo + side_salt * 3) % UINT32
end

local function search_position_key(board, side)
  local hi, lo = cache_hash(board, side)
  return tostring(math.floor(hi)) .. ":" .. tostring(math.floor(lo))
end

local function new_cache(capacity, watchdog)
  local hi, lo, value = {}, {}, {}
  for index = 1, capacity do
    if watchdog and index % 64 == 0 then watchdog:feed() end
  end
  return {
    kind = "open_addressed", capacity = capacity, count = 0, cursor = 1,
    hi = hi, lo = lo, value = value,
    probe_count = 0, collision_count = 0, eviction_count = 0,
  }
end

local CACHE_POOL = {}

local function clear_cache(cache, watchdog)
  for index = 1, cache.capacity do
    cache.hi[index], cache.lo[index], cache.value[index] = nil, nil, nil
    if cache.fast then cache.fast[index], cache.full[index] = nil, nil end
    if watchdog and index % 64 == 0 then watchdog:feed() end
  end
  cache.count = 0
  cache.cursor = 1
  cache.probe_count = 0
  cache.collision_count = 0
  cache.eviction_count = 0
end

local function acquire_caches(watchdog)
  for _, group in ipairs(CACHE_POOL) do
    if not group.in_use then
      group.in_use = true
      clear_cache(group.tt, watchdog)
      clear_cache(group.eval, watchdog)
      clear_cache(group.move, watchdog)
      return group
    end
  end
  local eval = new_cache(EVAL_CACHE_LIMIT, watchdog)
  eval.fast = {}
  eval.full = {}
  local group = {
    in_use = true,
    tt = new_cache(TT_LIMIT, watchdog),
    eval = eval,
    move = new_cache(MOVE_CACHE_LIMIT, watchdog),
  }
  CACHE_POOL[#CACHE_POOL + 1] = group
  return group
end

local function release_caches(session)
  if not session or session.caches_released then return end
  if session.cache_group then session.cache_group.in_use = false end
  session.caches_released = true
end

local function lua_memory_kb()
  local ctx = require("lib.watchdog_slice").ctx
  if ctx then return ctx.gc:count() / 1024 end
  return nil
end

local function cache_start(cache, hi, lo)
  return ((hi % cache.capacity) + (lo % cache.capacity) * 3) % cache.capacity + 1
end

local function cache_find(cache, hi, lo)
  local index = cache_start(cache, hi, lo)
  local probes = 0
  for _ = 1, cache.capacity do
    probes = probes + 1
    local key_hi = cache.hi[index]
    if key_hi == nil then
      cache.probe_count = cache.probe_count + probes
      return nil, index
    end
    if key_hi == hi and cache.lo[index] == lo then
      cache.probe_count = cache.probe_count + probes
      return index, index
    end
    cache.collision_count = cache.collision_count + 1
    index = index % cache.capacity + 1
  end
  cache.probe_count = cache.probe_count + probes
  return nil, nil
end

local function cache_claim(cache, hi, lo)
  local index, empty = cache_find(cache, hi, lo)
  if index then return index, true end
  if empty then
    cache.count = cache.count + 1
    cache.hi[empty], cache.lo[empty] = hi, lo
    return empty, false
  end
  local victim = cache.cursor
  cache.cursor = cache.cursor % cache.capacity + 1
  cache.hi[victim], cache.lo[victim], cache.value[victim] = hi, lo, nil
  cache.eviction_count = cache.eviction_count + 1
  return victim, false
end

local function cache_legacy_key(board, side)
  if type(board) == "table" and board.cells then
    return State.search_board(board) .. "|" .. side
  end
  return tostring(board) .. "|" .. side
end

local function repetition_signature(counts)
  local root, total = {}, 0
  for key, count in pairs(counts or {}) do
    if count > 0 then
      total = total + 1
      if total > REPETITION_HISTORY_LIMIT then return nil, total end
      root[key] = count
    end
  end
  return { root = root, unique = total }, total
end

local function extend_repetition_signature(signature, key, count, entry_count)
  if not signature or not entry_count then
    return nil, entry_count
  end
  local old = signature.root[key] or 0
  local node = signature
  while node do
    if node.key == key then old = node.count; break end
    node = node.parent
  end
  local next_count = entry_count + (old == 0 and 1 or 0)
  if next_count > REPETITION_HISTORY_LIMIT then return nil, next_count end
  return {
    root = signature.root, parent = signature, key = key, count = count,
    unique = next_count,
  }, next_count
end

local function tt_context_matches(entry, signature)
  local left = entry and entry.repetition_signature
  if not left or not signature then return false end
  if left == signature then return true end
  if left.root == signature.root then
    local a, b = left, signature
    while a and b and a.key == b.key and a.count == b.count do
      a, b = a.parent, b.parent
    end
    if not a and not b then return true end
  end
  local function materialize(context)
    local values = {}
    for key, count in pairs(context.root or {}) do values[key] = count end
    local chain, node = {}, context
    while node do chain[#chain + 1] = node; node = node.parent end
    for i = #chain, 1, -1 do
      node = chain[i]
      if node.key then values[node.key] = node.count end
    end
    return values
  end
  local left_values, right_values = materialize(left), materialize(signature)
  for key, count in pairs(left_values) do
    if right_values[key] ~= count then return false end
  end
  for key, count in pairs(right_values) do
    if left_values[key] ~= count then return false end
  end
  return true
end

local function should_stop(session, book_mode)
  if session.watchdog then
    local keep, reason = session.watchdog:feed()
    if keep == false then
      session.elapsed_ms = session.max_ms
      session.stats.elapsed_ms = session.elapsed_ms
      session.stop_reason = reason or "app_budget_exhausted"
      return true
    end
  end
  if not book_mode and session.stop_reason then return true end
  local now = session.clock()
  if now >= session.hard_deadline then
    session.elapsed_ms = session.max_ms
    session.stats.elapsed_ms = session.elapsed_ms
    session.stop_reason = "timeout"
    return true
  end
  if not book_mode and session.stats.nodes >= session.leaf_limit then
    session.stop_reason = "leaf_limit"
    return true
  end
  return now >= session.slice_deadline
    or (book_mode and session.book_deadline_ms and now >= session.book_deadline_ms)
end

local function evaluate(board, side)
  return Evaluation.evaluate(board, side)
end

local function search_evaluate(session, board, side, fast)
  local hi, lo = cache_hash(board, side)
  local eval_cache = session.eval_cache
  local index, empty_index = cache_find(eval_cache, hi, lo)
  if index then
    local value
    if fast then value = eval_cache.fast[index] else value = eval_cache.full[index] end
    if value ~= nil then
      session.stats.eval_cache_hits = session.stats.eval_cache_hits + 1
      return value
    end
  end
  local value
  if fast then
    value = Evaluation.material_score(board, side)
    session.stats.fast_leaf_evaluations = session.stats.fast_leaf_evaluations + 1
  else
    value = evaluate(board, side)
    session.stats.full_leaf_evaluations = session.stats.full_leaf_evaluations + 1
  end
  if index then
    if fast then eval_cache.fast[index] = value else eval_cache.full[index] = value end
  else
    local slot = empty_index or cache_claim(eval_cache, hi, lo)
    if fast then eval_cache.fast[slot] = value else eval_cache.full[slot] = value end
    session.eval_cache_count = eval_cache.count
  end
  return value
end

local function opening_move(candidate)
  return candidate and (candidate.move or candidate) or nil
end

local DIFFICULTY_PROFILE = {
  [1] = { history_ordering = true, fast_leaf_evaluation = true },
  [2] = { history_ordering = false, fast_leaf_evaluation = false },
  [3] = { history_ordering = true, fast_leaf_evaluation = false },
}
local function new_frame(
  board, side, depth, alpha, beta, root, qdepth, history_key,
  repetition_context, repetition_entry_count, check_evasions, tactical_leaf
)
  return {
    board = board, side = side, depth = depth, alpha = alpha, beta = beta,
    original_alpha = alpha, original_beta = beta,
    root = root or false, qdepth = qdepth or 0, history_key = history_key,
    check_evasions = check_evasions or 0, check_evasion_extension = false,
    tactical_leaf = tactical_leaf or false,
    initialized = false, moves = nil, index = 1, waiting = false,
    child_value = nil, best_move = nil, tt_checked = false, tt_entry = nil,
    undo_token = nil,
    legal_move_count = 0, resource_failure_reason = nil,
    current_move = {},
    repetition_signature = repetition_context,
    repetition_entry_count = repetition_entry_count,
  }
end

local function begin_alpha_beta(session, depth)
  session.active_depth = depth
  session.search_result = nil
  session.layer_sequence = session.layer_sequence + 1
  session.layer_node_start = session.stats.nodes
  session.layer_root_start = session.stats.root_moves_completed
  session.stats.current_layer_id = session.layer_sequence
  session.stats.current_layer_starts = 1
  session.stats.current_layer_resumes = 0
  session.stats.current_layer_progress = 0
  session.stats.root_min_child_depth = nil
  session.stats.root_reduced_moves = 0
  session.search_stack = {
    new_frame(
      session.search_state, session.side, depth, session.root_alpha, session.root_beta,
      true, nil, nil, session.root_repetition_signature,
      session.root_repetition_entry_count, session.check_evasion_depth, false
    ),
  }
end

local function same_move(a, b)
  return a and b and a.r == b.r and a.c == b.c and a.tr == b.tr and a.tc == b.tc
end

local function same_coordinates(move, r, c, tr, tc)
  return move and move.r == r and move.c == c and move.tr == tr and move.tc == tc
end

local function recent_own_move_from_state(s)
  local history = type(s.move_history) == "table" and s.move_history or {}
  local considered, recent = 0, nil
  local first = math.max(1, #history - RECENT_MOVE_LIMIT + 1)
  for index = #history, first, -1 do
    considered = considered + 1
    local move = history[index]
    if move and move.side == s.turn
      and move.r ~= nil and move.c ~= nil and move.tr ~= nil and move.tc ~= nil then
      recent = move
      break
    end
  end
  return recent, considered
end

local function immediate_reversal_from_state(s)
  local recent, considered = recent_own_move_from_state(s)
  if not recent then return nil, considered end
  return {
    r = recent.tr, c = recent.tc, tr = recent.r, tc = recent.c,
  }, considered
end

local function replace_square(board, r, c, piece)
  local index = r * 9 + c + 1
  return board:sub(1, index - 1) .. piece .. board:sub(index + 1)
end

local function last_own_gave_check(s)
  local last = s.last
  if not last or last.fr == nil or last.fc == nil
    or last.tr == nil or last.tc == nil then return false end
  local moved = State.at(s.board, last.tr, last.tc)
  if moved == "." then return false end
  local previous = replace_square(
    s.board, last.tr, last.tc, last.captured or "."
  )
  previous = replace_square(previous, last.fr, last.fc, moved)
  return State.board_in_check(previous, other(s.turn))
end

local function pointless_reversal_penalty(s, move, next_board)
  local recent = recent_own_move_from_state(s)
  local reversal = immediate_reversal_from_state(s)
  if State.board_in_check(s.board, s.turn) then return 0 end
  if State.at(s.board, move.tr, move.tc) ~= "." then return 0 end
  local piece = State.at(s.board, move.r, move.c)
  next_board = next_board
    or State.apply_pure(s.board, move.r, move.c, move.tr, move.tc)
  if State.board_in_check(next_board, other(s.turn)) then
    if recent and move.r == recent.tr and move.c == recent.tc
      and last_own_gave_check(s) then return REPEAT_CHECK_PENALTY end
    return 0
  end
  if not same_move(reversal, move) then return 0 end
  local kind = piece:lower()
  if kind == "n" or kind == "c" or kind == "r" then
    local enemy = other(s.turn)
    local attacked_now = State.board_square_attacked(
      s.board, enemy, move.r, move.c, piece
    )
    local safe_after_return = not State.board_square_attacked(
      next_board, enemy, move.tr, move.tc, piece
    )
    if attacked_now and safe_after_return then return 0 end
  end
  return POINTLESS_REVERSAL_PENALTY
end

local function is_pointless_root_reversal(session, frame, move)
  return frame.root
    and (move.root_cycle_penalty or 0) > 0
end

local function record_killer(session, depth, move)
  local killers = session.killers[depth] or {}
  if not same_move(killers[1], move) then
    killers[2] = killers[1]
    killers[1] = { r = move.r, c = move.c, tr = move.tr, tc = move.tc }
    session.killers[depth] = killers
  end
end

local function tt_best_matches(entry, r, c, tr, tc)
  return entry and entry.best_r == r and entry.best_c == c
    and entry.best_tr == tr and entry.best_tc == tc
end

local function score_move(session, frame, code)
  local r, c, tr, tc = State.search_move_decode(code)
  local hash = frame.tt_entry
  local killers = session.killers[frame.depth] or {}
  local target = State.at(frame.board, tr, tc)
  local winning = target ~= "." and target:lower() == "k"
  local score = 0
  local kind = "history"
  if hash and tt_best_matches(hash, r, c, tr, tc) then
    score = score + 1000000000
    kind = "hash"
    session.stats.tt_order_hits = session.stats.tt_order_hits + 1
  end
  if frame.root and session.order_hint
    and same_coordinates(session.order_hint.hash_move, r, c, tr, tc)
  then
    score = score + 900000000
    if kind ~= "hash" then kind = "order_hint_hash" end
    session.stats.order_hint_hits = session.stats.order_hint_hits + 1
  end
  if winning then
    score = score + 100000000
    if kind ~= "hash" and kind ~= "order_hint_hash" then kind = "win" end
  end
  if target ~= "." and not winning then
    local victim = PIECE_VALUE[target:lower()] or 0
    local attacker = PIECE_VALUE[State.at(frame.board, r, c):lower()] or 0
    score = score + 1000000 + victim * 32 - attacker
    if kind == "history" then kind = "capture" end
  else
    if frame.checked and State.at(frame.board, r, c):lower() ~= "k" then
      score = score + 20000
      if kind == "history" then kind = "block" end
    end
    if same_coordinates(killers[1], r, c, tr, tc) then
      score = score + 100000
      if kind == "history" then kind = "killer" end
    elseif same_coordinates(killers[2], r, c, tr, tc) then
      score = score + 50000
      if kind == "history" then kind = "killer" end
    end
    if session.profile.history_ordering then
      score = score + math.min(12000, session.history[code] or 0)
    end
  end
  if frame.root and same_coordinates(session.immediate_reversal, r, c, tr, tc) then
    score = score - 20000
    kind = "reversal"
  end
  return score, kind
end

local function order_moves(session, frame, moves)
  frame.order_source = frame.order_source or {}
  frame.order_source_scores = frame.order_source_scores or {}
  frame.order_source_kinds = frame.order_source_kinds or {}
  frame.order_index = frame.order_index or 1
  while not frame.order_done do
    if frame.order_index <= #moves then
      if should_stop(session) then return false end
      local code = moves[frame.order_index]
      local score, kind = score_move(session, frame, code)
      local output_index = #frame.order_source + 1
      frame.order_source[output_index] = code
      frame.order_source_scores[output_index] = score
      frame.order_source_kinds[output_index] = kind
      frame.order_index = frame.order_index + 1
    elseif #frame.order_source <= 1 then
      frame.moves = frame.order_source
      frame.move_scores = frame.order_source_scores
      frame.move_kinds = frame.order_source_kinds
      frame.order_done = true
    elseif not frame.order_width then
      frame.order_width = 1
      frame.order_output = {}
      frame.order_output_scores = {}
      frame.order_output_kinds = {}
      frame.order_pair_start = 1
    elseif frame.order_width >= #frame.order_source then
      frame.moves = frame.order_source
      frame.move_scores = frame.order_source_scores
      frame.move_kinds = frame.order_source_kinds
      frame.order_done = true
    elseif frame.order_pair_start > #frame.order_source then
      frame.order_source = frame.order_output
      frame.order_source_scores = frame.order_output_scores
      frame.order_source_kinds = frame.order_output_kinds
      frame.order_width = frame.order_width * 2
      frame.order_output = {}
      frame.order_output_scores = {}
      frame.order_output_kinds = {}
      frame.order_pair_start = 1
      frame.order_left, frame.order_right = nil, nil
    elseif not frame.order_left then
      if should_stop(session) then return false end
      frame.order_left = frame.order_pair_start
      frame.order_left_end = math.min(
        #frame.order_source, frame.order_pair_start + frame.order_width - 1
      )
      frame.order_right = frame.order_left_end + 1
      frame.order_right_end = math.min(
        #frame.order_source, frame.order_pair_start + frame.order_width * 2 - 1
      )
    elseif frame.order_left > frame.order_left_end
      and frame.order_right > frame.order_right_end then
      frame.order_pair_start = frame.order_pair_start + frame.order_width * 2
      frame.order_left, frame.order_right = nil, nil
    elseif frame.order_right > frame.order_right_end then
      local output_index = #frame.order_output + 1
      frame.order_output[output_index] = frame.order_source[frame.order_left]
      frame.order_output_scores[output_index] = frame.order_source_scores[frame.order_left]
      frame.order_output_kinds[output_index] = frame.order_source_kinds[frame.order_left]
      frame.order_left = frame.order_left + 1
    elseif frame.order_left > frame.order_left_end then
      local output_index = #frame.order_output + 1
      frame.order_output[output_index] = frame.order_source[frame.order_right]
      frame.order_output_scores[output_index] = frame.order_source_scores[frame.order_right]
      frame.order_output_kinds[output_index] = frame.order_source_kinds[frame.order_right]
      frame.order_right = frame.order_right + 1
    else
      local left_score = frame.order_source_scores[frame.order_left]
      local right_score = frame.order_source_scores[frame.order_right]
      local source_index
      if left_score >= right_score then
        source_index = frame.order_left
        frame.order_left = frame.order_left + 1
      else
        source_index = frame.order_right
        frame.order_right = frame.order_right + 1
      end
      local output_index = #frame.order_output + 1
      frame.order_output[output_index] = frame.order_source[source_index]
      frame.order_output_scores[output_index] = frame.order_source_scores[source_index]
      frame.order_output_kinds[output_index] = frame.order_source_kinds[source_index]
    end
  end
  if frame.root and frame.moves[1] and not session.stats.first_order_kind then
    session.stats.first_order_kind = frame.move_kinds[1]
  end
  return true
end

local function probe_legal_move(session, frame)
  if not frame.raw_moves then
    frame.move_cursor = frame.move_cursor or State.begin_search_moves(frame.board, frame.side)
    State.resume_search_moves(
      frame.move_cursor, function() return should_stop(session) end
    )
    if not frame.move_cursor.done then return false end
    frame.raw_moves = frame.move_cursor.moves
    frame.legal_probe_index = 1
  end
  while frame.legal_probe_index <= #frame.raw_moves do
    if should_stop(session) then return false end
    local code = frame.raw_moves[frame.legal_probe_index]
    frame.legal_probe_index = frame.legal_probe_index + 1
    local r, c, tr, tc = State.search_move_decode(code)
    session.stats.legal_probe_search_apply_count =
      session.stats.legal_probe_search_apply_count + 1
    local token, reason = State.search_apply(frame.board, r, c, tr, tc)
    if not token then
      if reason == "attack_overflow" then
        frame.resource_failure_reason = reason
      elseif reason == "attack_ply_overflow" or reason == "undo_overflow" then
        session.stop_reason = reason
        return false
      end
    else
      local legal = not State.board_in_check(frame.board, frame.side)
      State.search_undo(frame.board, token)
      if legal then frame.has_legal_move = true; return true end
      session.stats.self_check_pruned = session.stats.self_check_pruned + 1
    end
  end
  if frame.resource_failure_reason then
    session.stop_reason = frame.resource_failure_reason
    return false
  end
  frame.no_legal_moves = true
  return true
end

local function prepare_moves(session, frame, forcing_only)
  if not frame.prepare_apply_start then
    frame.prepare_apply_start = State.search_apply_count(frame.board)
  end
  if not frame.raw_moves and not frame.move_cursor then
    local hi, lo = cache_hash(frame.board, frame.side)
    local cached_index = cache_find(session.move_cache, hi, lo)
    local cached = cached_index and session.move_cache.value[cached_index] or nil
    if cached then
      frame.raw_moves = cached
      frame.candidates = frame.raw_moves
      session.stats.move_cache_hits = session.stats.move_cache_hits + 1
    else
      frame.move_cursor = State.begin_search_moves(frame.board, frame.side)
    end
  end
  if frame.move_cursor and not frame.move_cursor.done then
    State.resume_search_moves(frame.move_cursor, function() return should_stop(session) end)
    if not frame.move_cursor.done then return false end
    frame.raw_moves = frame.move_cursor.moves
    local hi, lo = cache_hash(frame.board, frame.side)
    local cached_index, empty_index = cache_find(session.move_cache, hi, lo)
    if not cached_index then
      local slot = empty_index or cache_claim(session.move_cache, hi, lo)
      session.move_cache.value[slot] = frame.raw_moves
      session.move_cache_count = session.move_cache.count
    end
    frame.candidates = frame.raw_moves
  end
  if #frame.raw_moves == 0 then frame.no_legal_moves = true; return true end
  if frame.root and session.root_candidate_codes then
    frame.candidates = session.root_candidate_codes
  else
    frame.candidates = frame.candidates or frame.raw_moves
  end
  if not order_moves(session, frame, frame.candidates) then return false end
  frame.initialized = true
  session.stats.prepare_search_apply_count = session.stats.prepare_search_apply_count
    + State.search_apply_count(frame.board) - frame.prepare_apply_start
  return true
end

local function store_tt(session, frame, value)
  if frame.depth <= 0 or not frame.best_move or frame.qdepth > 0 then return end
  if not frame.repetition_signature then
    session.stats.tt_context_skips = session.stats.tt_context_skips + 1
    return
  end
  local hi, lo = cache_hash(frame.board, frame.side)
  local tt_cache = session.tt_cache
  local index, empty_index = cache_find(tt_cache, hi, lo)
  local existing = index and tt_cache.value[index] or nil
  local bound = EXACT
  if value <= frame.original_alpha then
    bound = UPPER
  elseif value >= frame.original_beta then
    bound = LOWER
  end
  if existing and existing.depth > frame.depth then
    session.stats.tt_rejected_shallow = session.stats.tt_rejected_shallow + 1
    return
  end
  if existing and existing.depth == frame.depth
    and existing.bound == EXACT and bound ~= EXACT then
    session.stats.tt_preserved_strong = session.stats.tt_preserved_strong + 1
    return
  end
  if not existing and not empty_index then
    local victim_index = tt_cache.cursor
    local victim = tt_cache.value[victim_index]
    session.stats.tt_replacement_candidates = session.stats.tt_replacement_candidates + 1
    if victim and (victim.depth < frame.depth
      or (victim.depth == frame.depth and (victim.generation or 0) <= session.active_depth)) then
      tt_cache.cursor = tt_cache.cursor % TT_LIMIT + 1
      session.stats.tt_replacements = session.stats.tt_replacements + 1
    else
      session.stats.tt_capacity_rejects = session.stats.tt_capacity_rejects + 1
      return
    end
    index = victim_index
  end
  if not existing and empty_index then
    tt_cache.count = tt_cache.count + 1
    index = empty_index
  end
  local entry = {
    depth = frame.depth,
    score = value,
    bound = bound,
    best_r = frame.best_move.r, best_c = frame.best_move.c,
    best_tr = frame.best_move.tr, best_tc = frame.best_move.tc,
    repetition_signature = frame.repetition_signature,
    generation = session.active_depth,
  }
  tt_cache.hi[index], tt_cache.lo[index], tt_cache.value[index] = hi, lo, entry
  session.tt_count = tt_cache.count
  if session.legacy_tt_enabled then
    session.tt[cache_legacy_key(frame.board, frame.side)] = entry
  end
  session.stats.tt_stores = session.stats.tt_stores + 1
end

local function finish_frame(session, value, move)
  local stack = session.search_stack
  local finished = table.remove(stack)
  store_tt(session, finished, value)
  if finished.undo_token then
    State.search_undo(finished.board, finished.undo_token)
    finished.undo_token = nil
  end
  if finished.history_key then
    local count = (session.position_counts[finished.history_key] or 1) - 1
    if count <= 0 then session.position_counts[finished.history_key] = nil else session.position_counts[finished.history_key] = count end
  end
  local parent = stack[#stack]
  if parent then
    parent.child_value = value
    parent.waiting = false
  else
    session.stats.score = value
    session.search_result = { move = copy_move(move or finished.best_move), value = value }
  end
end

local function adopt_tt_best(frame, entry)
  frame.best_move = frame.best_move or {}
  frame.best_move.r, frame.best_move.c = entry.best_r, entry.best_c
  frame.best_move.tr, frame.best_move.tc = entry.best_tr, entry.best_tc
end

local function probe_tt(session, frame)
  frame.tt_checked = true
  if not frame.repetition_signature then
    session.stats.tt_context_skips = session.stats.tt_context_skips + 1
    return false
  end
  local hi, lo = cache_hash(frame.board, frame.side)
  local index = cache_find(session.tt_cache, hi, lo)
  local entry = index and session.tt_cache.value[index] or nil
  if not entry and session.legacy_tt_enabled then
    entry = session.tt[cache_legacy_key(frame.board, frame.side)]
  end
  if not entry then return false end
  if not tt_context_matches(entry, frame.repetition_signature) then
    session.stats.tt_context_misses = session.stats.tt_context_misses + 1
    return false
  end
  if entry.best_r == nil or not State.search_pseudo_legal(
    frame.board, frame.side,
    entry.best_r, entry.best_c, entry.best_tr, entry.best_tc
  ) then
    session.stats.tt_invalid_moves = session.stats.tt_invalid_moves + 1
    return false
  end
  frame.tt_entry = entry
  session.stats.tt_hits = session.stats.tt_hits + 1
  if entry.depth < frame.depth then return false end
  session.stats.tt_score_hits = session.stats.tt_score_hits + 1

  if entry.bound == EXACT then
    session.stats.tt_exact_hits = session.stats.tt_exact_hits + 1
    local value = entry.score
    if value <= frame.alpha then value = frame.alpha end
    if value >= frame.beta then value = frame.beta end
    adopt_tt_best(frame, entry)
    finish_frame(session, value, frame.root and frame.best_move or nil)
    return true
  elseif entry.bound == LOWER then
    if entry.score >= frame.beta then
      session.stats.tt_cutoffs = session.stats.tt_cutoffs + 1
      adopt_tt_best(frame, entry)
      finish_frame(session, frame.beta, frame.root and frame.best_move or nil)
      return true
    end
    if entry.score > frame.alpha then frame.alpha = entry.score end
  elseif entry.bound == UPPER then
    if entry.score <= frame.alpha then
      session.stats.tt_cutoffs = session.stats.tt_cutoffs + 1
      adopt_tt_best(frame, entry)
      finish_frame(session, frame.alpha, frame.root and frame.best_move or nil)
      return true
    end
    if entry.score < frame.beta then frame.beta = entry.score end
  end
  return false
end

local push_child

local function consume_child(session, frame)
  local move = frame.current_move
  local value = -frame.child_value
  frame.child_value = nil
  frame.waiting = false
  if is_pointless_root_reversal(session, frame, move) then
    value = value - move.root_cycle_penalty
    session.stats.pointless_reversal_penalties =
      session.stats.pointless_reversal_penalties + 1
  end
  if frame.root then
    session.stats.root_moves_completed = session.stats.root_moves_completed + 1
    if session.baseline_collecting then
      session.baseline_ranked[#session.baseline_ranked + 1] = {
        code = frame.moves[frame.index],
        score = value,
        order = #session.baseline_ranked + 1,
      }
    end
  end
  if not frame.best_move then frame.best_move = copy_move(move) end
  if value >= frame.beta then
    session.stats.cutoffs = session.stats.cutoffs + 1
    if State.at(frame.board, move.tr, move.tc) == "." then
      record_killer(session, frame.depth, move)
      local key = frame.moves[frame.index]
      session.history[key] = math.min(12000, (session.history[key] or 0) + frame.depth * frame.depth)
    end
    finish_frame(session, frame.beta, frame.root and move or nil)
    return true
  end
  if value > frame.alpha then
    frame.alpha = value
    frame.best_move = copy_move(move)
  end
  frame.index = frame.index + 1
  return false
end

push_child = function(session, frame, code)
  local move = frame.current_move
  move.r, move.c, move.tr, move.tc = State.search_move_decode(code)
  move.gives_check, move.root_cycle_penalty = nil, nil
  local target = State.at(frame.board, move.tr, move.tc)
  local next_side = other(frame.side)
  session.stats.expansion_search_apply_count =
    session.stats.expansion_search_apply_count + 1
  local undo_token, apply_reason = State.search_apply(
    frame.board, move.r, move.c, move.tr, move.tc
  )
  if not undo_token then
    if apply_reason == "attack_overflow" then
      frame.resource_failure_reason = apply_reason
      frame.index = frame.index + 1
      return
    elseif apply_reason == "attack_ply_overflow" or apply_reason == "undo_overflow" then
      session.stats.undo_overflow = (session.stats.undo_overflow or 0) + 1
    end
    session.stop_reason = apply_reason or "search_apply_failed"
    return
  end
  if State.board_in_check(frame.board, frame.side) then
    State.search_undo(frame.board, undo_token)
    session.stats.self_check_pruned = session.stats.self_check_pruned + 1
    frame.index = frame.index + 1
    return
  end
  frame.legal_move_count = frame.legal_move_count + 1
  move.gives_check = State.board_in_check(frame.board, next_side)
  if frame.root then
    move.root_cycle_penalty = pointless_reversal_penalty(
      session.root_policy_state, move, frame.board
    )
    session.stats.fallback_verified_count = session.stats.fallback_verified_count + 1
    if not session.verified_fallback then
      session.verified_fallback = copy_move(move)
      session.fallback = copy_move(move)
    end
  end
  if target:lower() == "k" then
    State.search_undo(frame.board, undo_token)
    if frame.root then session.stats.root_moves_completed = session.stats.root_moves_completed + 1 end
    if frame.root then session.terminal_root = true end
    frame.best_move = copy_move(move)
    if WIN >= frame.beta then
      session.stats.cutoffs = session.stats.cutoffs + 1
      finish_frame(session, frame.beta, frame.root and move or nil)
    elseif WIN <= frame.alpha then
      finish_frame(session, frame.alpha, frame.root and move or nil)
    else
      finish_frame(session, WIN, frame.root and move or nil)
    end
    return
  end
  if frame.depth == 0 and frame.forcing_only and not frame.checked then
    local mover_kind = State.at(frame.board, move.tr, move.tc):lower()
    local major_capture = target ~= "."
      and (mover_kind == "r" or mover_kind == "n" or mover_kind == "c")
    if not major_capture and not move.gives_check then
      State.search_undo(frame.board, undo_token)
      frame.index = frame.index + 1
      session.stats.quiet_pruned_after_apply = session.stats.quiet_pruned_after_apply + 1
      return
    end
  end
  local key = search_position_key(frame.board, next_side)
  local repeats = session.position_counts[key] or 0
  if repeats >= 2 then
    -- 第三次出现按和棋计：避免在根层人工过滤，给对手真实的非重复胜机。
    State.search_undo(frame.board, undo_token)
    frame.child_value = 0
    frame.waiting = true
    return
  end
  session.position_counts[key] = repeats + 1
  frame.waiting = true
  local qdepth = frame.depth == 0 and math.max(0, frame.qdepth - 1)
    or (frame.depth == 1 and session.quiescence_depth or 0)
  local check_evasions = frame.check_evasions
  if frame.check_evasion_extension then check_evasions = math.max(0, check_evasions - 1) end
  local child_signature, child_entry_count = extend_repetition_signature(
    frame.repetition_signature, key, repeats + 1, frame.repetition_entry_count
  )
  local child_depth = math.max(0, frame.depth - 1)
  local child_alpha, child_beta = -frame.beta, -frame.alpha
  if frame.root and session.baseline_collecting then
    child_alpha, child_beta = -session.root_beta, -session.root_alpha
  end
  if frame.root and not frame.root_depth_recorded then
    frame.root_depth_recorded = {}
  end
  if frame.root and not frame.root_depth_recorded[frame.index] then
    frame.root_depth_recorded[frame.index] = true
    session.stats.root_min_child_depth = math.min(
      session.stats.root_min_child_depth or child_depth, child_depth
    )
    if child_depth < math.max(0, frame.depth - 1) then
      session.stats.root_reduced_moves = session.stats.root_reduced_moves + 1
    end
  end
  local child = new_frame(
    frame.board, next_side, child_depth, child_alpha, child_beta,
    false, qdepth, key, child_signature, child_entry_count, check_evasions,
    frame.depth == 0 and frame.forcing_only
  )
  child.undo_token = undo_token
  table.insert(session.search_stack, child)
end

local function can_use_fast_leaf_evaluation(session, frame)
  return session.profile.fast_leaf_evaluation
    and not frame.root and not frame.checked and not frame.tactical_leaf
end

local function resume_alpha_beta(session)
  while #session.search_stack > 0 do
    local frame = session.search_stack[#session.search_stack]
    if not frame.initialized then
      if frame.depth > 0 and not frame.tt_checked then
        if should_stop(session) then return end
        if probe_tt(session, frame) then
        end
      elseif not frame.node_started then
        if should_stop(session) then return end
        frame.node_started = true
        frame.checked = State.board_in_check(frame.board, frame.side)
        if frame.depth == 0 then
          session.stats.nodes = session.stats.nodes + 1
          frame.terminal_probe_pending = true
        else
          frame.forcing_only = false
        end
      elseif frame.terminal_probe_pending then
        if (frame.checked or frame.root) and not probe_legal_move(session, frame) then
          return
        end
        frame.terminal_probe_pending = false
        if frame.no_legal_moves then
          finish_frame(session, -WIN)
        elseif frame.checked then
          frame.stand_pat = search_evaluate(session, frame.board, frame.side, false)
          if frame.check_evasions > 0 then
            frame.check_evasion_extension = true
            frame.forcing_only = true
          else
            finish_frame(session, frame.stand_pat)
          end
        elseif frame.qdepth <= 0 then
          frame.stand_pat = search_evaluate(
            session, frame.board, frame.side,
            can_use_fast_leaf_evaluation(session, frame)
          )
          finish_frame(session, frame.stand_pat)
        else
          local fast = can_use_fast_leaf_evaluation(session, frame)
          frame.stand_pat = search_evaluate(session, frame.board, frame.side, fast)
          if frame.stand_pat >= frame.beta then
            finish_frame(session, frame.beta)
          else
            if frame.stand_pat > frame.alpha then frame.alpha = frame.stand_pat end
            frame.forcing_only = true
          end
        end
      elseif not prepare_moves(session, frame, frame.forcing_only) then
        return
      elseif frame.no_legal_moves then
        finish_frame(session, -WIN)
      end
    elseif frame.child_value ~= nil then
      if should_stop(session) then return end
      consume_child(session, frame)
    elseif frame.index > #frame.moves
      or (frame.root and session.root_move_limit > 0
        and frame.index > session.root_move_limit) then
      if should_stop(session) then return end
      if frame.resource_failure_reason then
        session.stop_reason = frame.resource_failure_reason
        return
      elseif frame.legal_move_count == 0 then
        finish_frame(session, -WIN)
      else
        finish_frame(session, frame.alpha, frame.root and frame.best_move or nil)
      end
    else
      if should_stop(session) then return end
      push_child(session, frame, frame.moves[frame.index])
    end
  end
end

local function end_phase_timing(session, phase, now)
  local started_key = phase .. "_started_ms"
  local finished_key = phase .. "_finished_ms"
  if not session[started_key] or session[finished_key] then return end
  now = now or (session.clock and session.clock()) or session[started_key]
  session[finished_key] = now
  session.stats[phase .. "_elapsed_ms"] = math.max(0, now - session[started_key])
end

local function finalize_phase_timings(session)
  local now = (session.clock and session.clock()) or session.started_ms or 0
  end_phase_timing(session, "book", now)
  end_phase_timing(session, "precheck", now)
  end_phase_timing(session, "search", now)
end

local function sync_runtime_metrics(session)
  local stats = session.stats
  local book = session.book_session
  local state = session.search_state
  local caches = { session.tt_cache, session.eval_cache, session.move_cache }
  local probe_count, collision_count, eviction_count = 0, 0, 0
  for _, cache in ipairs(caches) do
    probe_count = probe_count + (cache and cache.probe_count or 0)
    collision_count = collision_count + (cache and cache.collision_count or 0)
    eviction_count = eviction_count + (cache and cache.eviction_count or 0)
  end
  stats.book_lookup_reads = book and book.lookup_reads or stats.book_lookup_reads or 0
  stats.book_scan_lines = 0
  stats.book_segment_open_count = book and book.segment_open_count or 0
  stats.book_flash_reads = stats.book_segment_open_count * 2
  stats.book_probe_count = stats.book_lookup_reads
  stats.indexed_move_generation_count = state
    and state.indexed_move_generation_count or 0
  stats.full_board_piece_discovery_scans = state
    and state.full_board_piece_discovery_scans or 0
  stats.hash_key_build_count = state and state.hash_key_build_count or 0
  stats.undo_allocations = state and state.undo_allocations or 0
  stats.total_search_apply_count = state and State.search_apply_count(state) or 0
  stats.undo_overflow = stats.undo_overflow or 0
  stats.attack_overflow = state and State.search_attack_overflow_count(state) or 0
  stats.final_undo_depth = state and State.search_undo_depth(state) or 0
  stats.token_undo_successes = state and State.search_token_undo_successes(state) or 0
  stats.token_undo_failures = state and State.search_token_undo_failures(state) or 0
  stats.total_search_undo_count = stats.token_undo_successes
  stats.cache_probe_count = probe_count
  stats.cache_collision_count = collision_count
  stats.cache_eviction_count = eviction_count
end

local function unwind_search_stack(session)
  local stack = session and session.search_stack
  if not stack then return end
  for index = #stack, 1, -1 do
    local frame = stack[index]
    if frame.undo_token then
      State.search_undo(frame.board, frame.undo_token)
      frame.undo_token = nil
    end
  end
  session.search_stack = nil
end

local function ensure_verified_fallback(session)
  if session.best or session.fallback or not session.search_state then return end
  local cursor = State.begin_search_moves(session.search_state, session.side)
  State.resume_search_moves(cursor)
  for _, code in ipairs(cursor.moves) do
    local r, c, tr, tc = State.search_move_decode(code)
    local token, reason = State.search_apply(session.search_state, r, c, tr, tc)
    if token then
      local legal = not State.board_in_check(session.search_state, session.side)
      State.search_undo(session.search_state, token)
      if legal then
        session.fallback = { r = r, c = c, tr = tr, tc = tc }
        session.verified_fallback = copy_move(session.fallback)
        session.stats.fallback_verified_count =
          session.stats.fallback_verified_count + 1
        return
      end
    elseif reason == "attack_overflow" or reason == "attack_ply_overflow"
      or reason == "undo_overflow" then
      break
    end
  end
end

local HANGING_MAJOR = { n = true, c = true, r = true }

local function hanging_major_penalty(state, side, skip_square)
  local enemy = other(side)
  local penalty = 0
  for _, entry in ipairs(state.pieces[side] or {}) do
    local kind = entry.piece:lower()
    if HANGING_MAJOR[kind] and entry.square ~= skip_square then
      local attacked = State.search_attack_count(state, enemy, entry.square, true) > 0
      local protected = State.search_attack_count(state, side, entry.square, true) > 0
      if attacked and not protected then
        penalty = penalty + (PIECE_VALUE[kind] or 0)
      end
    end
  end
  return penalty
end

local function static_reply_resume(session)
  local rp = session.rp
  local cursor = rp.cursor
  State.resume_search_moves(cursor, function() return should_stop(session) end)
  local moves, n = cursor.moves, #cursor.moves
  local scanned = false
  while session.rp_budget > 0 and not session.stop_reason and rp.i < n
    and session.static_slice_nodes < session.static_slice_limit do
    rp.i = rp.i + 1
    local er, ec, etr, etc = State.search_move_decode(moves[rp.i])
    if etr == rp.tr and etc == rp.tc then
      if should_stop(session) and scanned then break end
      local token, reason = State.search_apply(session.search_state, er, ec, etr, etc)
      if token then
        if not State.board_in_check(session.search_state, rp.enemy) then
          session.rp_budget = session.rp_budget - 1
          scanned = true
          session.stats.nodes = session.stats.nodes + 1
          local reply_score = Evaluation.material_score(session.search_state, session.side)
          if reply_score < rp.worst then rp.worst = reply_score end
        end
        State.search_undo(session.search_state, token)
      elseif reason == "attack_overflow" or reason == "attack_ply_overflow" or reason == "undo_overflow" then
        break
      end
      session.static_slice_nodes = session.static_slice_nodes + 1
    end
  end
  return session.rp_budget <= 0 or (cursor.done and rp.i >= n)
end

local function static_one_step(session)
  local cursor = session.static_cursor
  if not cursor then
    cursor = State.begin_search_moves(session.search_state, session.side)
    session.static_cursor = cursor
  end
  State.resume_search_moves(cursor, function() return should_stop(session) end)
  local n, evaluated = #cursor.moves, session.static_evaluated or 0
  local enemy = session.side == "r" and "b" or "r"
  while (evaluated < n or session.rp) and not session.stop_reason and session.static_slice_nodes < session.static_slice_limit do
    if session.rp then
      if static_reply_resume(session) then
        State.search_undo(session.search_state, session.rp.token)
        local final = session.rp.worst
        if not session.best or final > session.best_score then
          session.best = session.rp.move
          session.best_score = final
        end
        session.rp = nil
      end
      if should_stop(session) then break end
    else
      evaluated = evaluated + 1
      session.static_evaluated = evaluated
      local r, c, tr, tc = State.search_move_decode(cursor.moves[evaluated])
      local token, reason = State.search_apply(session.search_state, r, c, tr, tc)
      if token then
        session.stats.nodes = session.stats.nodes + 1
        if State.board_in_check(session.search_state, session.side) then
          State.search_undo(session.search_state, token)
        else
          local fast = Evaluation.material_score(session.search_state, session.side)
          session.stats.fast_root_evals = session.stats.fast_root_evals + 1
          if token.captured == "." and not State.board_in_check(session.search_state, enemy) then
            local score = fast - hanging_major_penalty(session.search_state, session.side)
            if not session.best or score > session.best_score then
              session.best = { r = r, c = c, tr = tr, tc = tc }
              session.best_score = score
            end
            State.search_undo(session.search_state, token)
          else
            local dest = tr * 9 + tc
            local scan = session.rp_budget > 0
              and State.search_attack_count(session.search_state, enemy, dest, true) > 0
            local score = evaluate(session.search_state, session.side)
              - hanging_major_penalty(
                session.search_state, session.side, scan and dest or nil
              )
            session.stats.full_root_evals = session.stats.full_root_evals + 1
            if scan then
              session.rp = {
                cursor = State.begin_search_moves(session.search_state, enemy),
                token = token, worst = score, i = 0,
                tr = tr, tc = tc, enemy = enemy,
                move = { r = r, c = c, tr = tr, tc = tc },
              }
              session.stats.reply_scan_runs = (session.stats.reply_scan_runs or 0) + 1
            else
              session.stats.reply_scan_skips = (session.stats.reply_scan_skips or 0) + 1
              if not session.best or score > session.best_score then
                session.best = { r = r, c = c, tr = tr, tc = tc }
                session.best_score = score
              end
              State.search_undo(session.search_state, token)
            end
          end
        end
      elseif reason == "attack_overflow" or reason == "attack_ply_overflow" or reason == "undo_overflow" then
        break
      end
      session.static_slice_nodes = session.static_slice_nodes + 1
    end
  end
  return cursor.done and evaluated >= n and not session.rp
end

local function finish(session, reason)
  unwind_search_stack(session)
  ensure_verified_fallback(session)
  Opening.close(session.book_session)
  finalize_phase_timings(session)
  session.done = true
  local search_reason = reason or session.stop_reason
  session.stats.search_stop_reason = search_reason
  if session.book_unavailable
    and search_reason ~= "timeout"
    and search_reason ~= "target_depth"
    and search_reason ~= "leaf_limit"
    and search_reason ~= "book"
  then
    session.stop_reason = "book_unavailable"
  else
    session.stop_reason = search_reason
  end
  session.stats.completed_depth = session.completed_depth
  session.stats.max_ms = session.max_ms
  if session.stop_reason == "book" then
    session.stats.best_source = "book"
  elseif session.stats.terminal_complete then
    session.stats.best_source = "terminal"
  elseif session.completed_depth == 1 and session.stats.tactical_complete then
    session.stats.best_source = "tactical"
  elseif session.completed_depth == 1 and session.stats.baseline_complete then
    session.stats.best_source = "baseline"
  else
    session.stats.best_source =
      session.completed_depth > 0 and ("depth" .. tostring(session.completed_depth))
      or (session.best and "search" or "fallback")
  end
  session.stats.nodes_per_sec = session.stats.elapsed_ms > 0
    and math.floor(session.stats.nodes * 1000 / session.stats.elapsed_ms)
    or 0
  session.stats.reason = session.stop_reason
  session.stats.stop_reason = session.stop_reason
  sync_runtime_metrics(session)
  release_caches(session)
  if session.search_state then
    State.release_search_state(session.search_state)
    session.search_state = nil
  end
  return {
    done = true,
    move = session.best or session.fallback,
    order_hint = build_order_hint(session),
    stats = session.stats,
  }
end

local function book_budget_exhausted(session)
  return session.book_deadline_ms
    and session.clock() >= session.book_deadline_ms
    and session.stop_reason == nil
end

local function step_opening_with_metrics(session)
  local book = session.book_session
  local before = Opening.segment_stats()
  local was_loaded = before and before.prefix_length == book.prefix_length
  local started = session.clock()
  local complete = Opening.step(
    book, 2048, function() return should_stop(session, true) end
  )
  local elapsed = math.max(0, session.clock() - started)
  if was_loaded then
    session.stats.book_hot_lookup_ms =
      session.stats.book_hot_lookup_ms + elapsed
  else
    session.stats.book_cold_init_ms =
      session.stats.book_cold_init_ms + elapsed
  end
  return complete
end

local function first_legal_opening_move(session)
  local candidates = {}
  for _, candidate in ipairs(Opening.candidates(session.book_session)) do
    local move = opening_move(candidate)
    local rank = tonumber(candidate.static_rank) or 0
    if move and rank < 8 and State.is_legal(
      { board = session.board, turn = session.side },
      move.r, move.c, move.tr, move.tc
    ) then
      candidates[#candidates + 1] = { move = move, rank = rank }
    end
  end
  if #candidates == 0 then return nil end
  local main = candidates[1]
  for index = 2, #candidates do
    if candidates[index].rank < main.rank then main = candidates[index] end
  end
  if not session.book_variety or #candidates < 2 then return main.move end
  table.sort(candidates, function(a, b) return a.rank < b.rank end)
  local top = math.min(3, #candidates)
  local pick, cumulative = math.random(top * (7 - top) / 2), 0
  for index = 1, top do
    cumulative = cumulative + 4 - index
    if pick <= cumulative then return candidates[index].move end
  end
  return main.move
end

local function finish_opening_phase(session)
  local move = first_legal_opening_move(session)
  Opening.close(session.book_session)
  end_phase_timing(session, "book")
  session.book_phase = false
  if move then
    session.best = move
    return finish(session, "book")
  end
  session.stats.book_out = true
  return nil
end

local function begin_session(s, options)
  options = options or {}
  local watchdog = options.watchdog
  if watchdog then watchdog:feed() end
  Opening.ensure_ready()
  local difficulty = s.difficulty or 1
  local static_slice_limit = math.max(1, tonumber(options.ai_static_slice_nodes) or STATIC_SLICE_NODES)
  local profile = DIFFICULTY_PROFILE[difficulty] or DIFFICULTY_PROFILE[1]
  local book_variety = options.ai_book_variety
  if book_variety == nil then book_variety = difficulty == 1 end
  local static_mode = options.ai_static_mode == true and not (options.ai_search_force == true or s.ai_search_force == true)
  local think_ms = static_mode and STATIC_THINK_MS or (THINK_MS[difficulty] or THINK_MS[1])
  local search_state = State.new_search_state(s.board, s.turn, watchdog)
  if watchdog then watchdog:feed() end
  local root_checked = State.board_in_check(search_state, s.turn)
  if watchdog then watchdog:feed() end
  local position_counts = copy_counts(s.position_counts)
  local root_legacy_key = position_key(s.board, s.turn)
  local root_search_key = search_position_key(search_state, s.turn)
  local legacy_position_counts = copy_counts(s.position_counts)
  legacy_position_counts[root_legacy_key] = legacy_position_counts[root_legacy_key] or 1
  local legacy_root_repetition_signature = repetition_signature(legacy_position_counts)
  position_counts[root_search_key] = position_counts[root_legacy_key] or 1
  position_counts[root_legacy_key] = nil
  local root_repetition_signature, root_repetition_entry_count = repetition_signature(position_counts)
  local target_depth = TARGET_DEPTH[difficulty] or TARGET_DEPTH[1]
  if tonumber(options.ai_search_depth) then target_depth = math.max(1, tonumber(options.ai_search_depth)) end
  local start_depth = math.max(1, math.min(target_depth, tonumber(options.ai_start_depth) or START_DEPTH[difficulty] or 1))
  local configured_quiescence_depth = QUIESCENCE_DEPTH[difficulty] or 0
  local two_stage_easy = difficulty == 1 and not static_mode and start_depth == 1
    and (options.ai_diagnostics ~= true or options.ai_two_stage_easy == true)
  local root_alpha = tonumber(options.ai_alpha) or ALPHA
  local root_beta = tonumber(options.ai_beta) or BETA
  local immediate_reversal, history_considered = immediate_reversal_from_state(s)
  local reversal_penalty = immediate_reversal and pointless_reversal_penalty(s, immediate_reversal) or 0
  local order_hint = copy_order_hint(s.ai_order_hint)
  if root_alpha >= root_beta then root_alpha, root_beta = ALPHA, BETA end
  local sample_cache_memory = AI_DIAGNOSTICS or options.ai_diagnostics == true
  local cache_memory_before_kb = sample_cache_memory and lua_memory_kb() or nil
  local cache_group = acquire_caches(options.watchdog)
  local cache_memory_after_kb = sample_cache_memory and lua_memory_kb() or nil
  local cache_memory_delta_kb = 0
  local cache_memory_sampled = false
  if cache_memory_before_kb and cache_memory_after_kb then
    cache_memory_delta_kb = math.max(0, cache_memory_after_kb - cache_memory_before_kb); cache_memory_sampled = true
  end
  local session = {
    board = s.board, search_state = search_state, side = s.turn,
    fallback = nil, verified_fallback = nil, best = nil,
    stop_reason = nil,
    difficulty = difficulty, book_variety = book_variety,
    max_ms = think_ms, elapsed_ms = 0,
    started_ms = nil, deadline_ms = nil,
    target_depth = target_depth, active_depth = start_depth,
    root_alpha = root_alpha, root_beta = root_beta,
    completed_depth = 0,
    quiescence_depth = two_stage_easy and 0 or configured_quiescence_depth,
    check_evasion_depth = CHECK_EVASION_DEPTH,
    leaf_limit = tonumber(options.ai_node_limit) or SAFETY_LEAVES[difficulty] or SAFETY_LEAVES[1],
    root_move_limit = (difficulty == 1) and 12 or 0,
    static_mode = static_mode,
    static_cursor = nil, static_evaluated = 0,
    static_slice_limit = static_slice_limit, static_slice_nodes = 0,
    rp = nil, rp_budget = REPLY_SCAN_BUDGET,
    book_phase = not options.ai_skip_book and not s.book_out,
    book_session = not options.ai_skip_book and not s.book_out
      and Opening.begin(s.pace or "") or nil,
    search_stack = nil, layer_sequence = 0, layer_node_start = 0, layer_root_start = 0,
    profile = profile, order_hint = order_hint,
    root_checked = root_checked, book_deadline_ms = nil,
    search_result = nil, done = false, position_counts = position_counts,
    root_repetition_signature = root_repetition_signature,
    root_repetition_entry_count = root_repetition_entry_count,
    legacy_root_repetition_signature = legacy_root_repetition_signature,
    legacy_tt_enabled = options.ai_diagnostics == true,
    tt = options.ai_diagnostics == true and {} or nil,
    cache_group = cache_group, caches_released = false,
    tt_cache = cache_group.tt, tt_count = 0,
    eval_cache = cache_group.eval, eval_cache_count = 0,
    move_cache = cache_group.move, move_cache_count = 0,
    killers = order_hint and order_hint.killers or {}, history = {},
    two_stage_easy = two_stage_easy,
    baseline_collecting = two_stage_easy,
    baseline_ranked = {},
    root_candidate_codes = nil,
    immediate_reversal = immediate_reversal, immediate_reversal_penalty = reversal_penalty,
    root_policy_state = {
      board = s.board, turn = s.turn, last = s.last,
      move_history = s.move_history,
    },
    stats = {
      nodes = 0, cutoffs = 0, completed_depth = 0, elapsed_ms = 0, max_ms = think_ms,
      search_mode = static_mode and "static" or "normal", target_depth = target_depth,
      tick_ms = 0, max_tick_ms = 0, nodes_per_sec = 0, best_source = "fallback",
      root_moves_completed = 0, resume_count = 0, tt_hits = 0,
      tt_score_hits = 0, tt_exact_hits = 0, tt_cutoffs = 0, tt_order_hits = 0,
      tt_invalid_moves = 0, tt_rejected_shallow = 0, tt_capacity_rejects = 0,
      tt_replacements = 0, tt_preserved_strong = 0, tt_replacement_candidates = 0,
      tt_stores = 0, tt_context_misses = 0, tt_context_skips = 0, tt_capacity = TT_LIMIT,
      cache_kind = "open_addressed", undo_capacity = State.search_undo_capacity(),
      score = nil, first_order_kind = nil,
      eval_cache_hits = 0, fast_leaf_evaluations = 0, full_leaf_evaluations = 0,
      fast_root_evals = 0, full_root_evals = 0, move_cache_hits = 0,
      prepare_search_apply_count = 0, expansion_search_apply_count = 0,
      legal_probe_search_apply_count = 0, self_check_pruned = 0,
      quiet_pruned_after_apply = 0, fallback_verified_count = 0, order_hint_hits = 0,
      move_history_entries_considered = history_considered,
      pointless_reversal_penalties = 0,
      forced_threat_scanned = 0, forced_threat_analyzed = 0,
      precheck_aborted = false, precheck_skipped = not root_checked, search_started = false,
      book_elapsed_ms = 0, book_cold_init_ms = 0, book_hot_lookup_ms = 0,
      book_lookup_reads = 0, book_scan_lines = 0,
      book_segment_open_count = 0, book_flash_reads = 0, book_probe_count = 0,
      precheck_elapsed_ms = 0, search_elapsed_ms = 0,
      indexed_move_generation_count = 0, full_board_piece_discovery_scans = 0,
      hash_key_build_count = 0, undo_allocations = 0, undo_overflow = 0,
      cache_memory_delta_kb = cache_memory_delta_kb, cache_memory_sampled = cache_memory_sampled,
      cache_probe_count = 0, cache_collision_count = 0, cache_eviction_count = 0,
      root_moves_unpruned = true,
      current_layer_id = nil, current_layer_starts = 0,
      current_layer_resumes = 0, current_layer_progress = 0,
      root_min_child_depth = nil, root_reduced_moves = 0,
      two_stage_easy = two_stage_easy,
      baseline_complete = false, baseline_elapsed_ms = 0,
      baseline_root_moves_completed = 0,
      tactical_started = false, tactical_complete = false,
      tactical_candidate_count = 0, tactical_root_moves_completed = 0,
      book_out = s.book_out == true, book_unavailable = false,
      book_aborted = false, reason = nil, stop_reason = nil,
    },
  }
  return session
end

function M.begin(s, watchdog)
  return begin_session(s, { watchdog = watchdog })
end
function M.format_diagnostics(stats)
  if not AI_DIAGNOSTICS or not stats then return nil end
  return string.format(
    "ai mode=%s max=%s elapsed=%s stop=%s target=%s depth=%s roots=%s nodes=%s book_ms=%s search_ms=%s book_out=%s src=%s",
    tostring(stats.search_mode),
    tostring(stats.max_ms), tostring(stats.elapsed_ms), tostring(stats.stop_reason),
    tostring(stats.target_depth), tostring(stats.completed_depth), tostring(stats.root_moves_completed),
    tostring(stats.nodes),
    tostring(stats.book_elapsed_ms), tostring(stats.search_elapsed_ms), tostring(stats.book_out),
    tostring(stats.best_source)
  )
end

local function diagnostics_seed_tt(session, board, side, entry)
  local state = State.new_search_state(board, side)
  local hi, lo = cache_hash(state, side)
  local index = cache_find(session.tt_cache, hi, lo)
  if not index then index = cache_claim(session.tt_cache, hi, lo) end
  if entry and entry.best and not entry.best_r then
    entry.best_r = entry.best.r
    entry.best_c = entry.best.c
    entry.best_tr = entry.best.tr
    entry.best_tc = entry.best.tc
    entry.best = nil
  end
  session.tt_cache.value[index] = entry
  session.tt_count = session.tt_cache.count
end

local function diagnostics_peek_tt(session, board, side)
  local state = State.new_search_state(board, side)
  local hi, lo = cache_hash(state, side)
  local index = cache_find(session.tt_cache, hi, lo)
  return index and session.tt_cache.value[index] or nil
end

local function diagnostics_fill_tt(session, depth)
  for index = 1, TT_LIMIT do
    session.tt_cache.hi[index], session.tt_cache.lo[index] = 100000 + index, 200000 + index * 3
    session.tt_cache.value[index] = {
      depth = depth or 1, score = 0, bound = UPPER,
      best_r = 1, best_c = 4, best_tr = 9, best_tc = 4,
      repetition_signature = session.root_repetition_signature,
      generation = 0,
    }
  end
  session.tt_cache.count = TT_LIMIT
  session.tt_count = TT_LIMIT
end

local function diagnostics_search_position_key(board, side)
  return search_position_key(State.new_search_state(board, side), side)
end

M.diagnostics = {
  begin = function(s, options)
    options = options or {}
    options.ai_diagnostics = true
    return begin_session(s, options)
  end,
  seed_tt = diagnostics_seed_tt,
  peek_tt = diagnostics_peek_tt,
  fill_tt = diagnostics_fill_tt,
  search_position_key = diagnostics_search_position_key,
  pointless_reversal_penalty = pointless_reversal_penalty,
  config = function()
    return {
      target_depths = { 1, 4, 4 },
      think_ms = { 2000, 2000, 2000 },
      slice_ms = SLICE_MS,
      phase_budgets = {
        book_ms = BOOK_BUDGET_MS,
        precheck_ms = PRECHECK_BUDGET_MS,
        search_reserve_ms = SEARCH_RESERVE_MS,
      },
      cache_limits = {
        tt = TT_LIMIT,
        evaluation = EVAL_CACHE_LIMIT,
        moves = MOVE_CACHE_LIMIT,
      },
      cache_kind = "open_addressed",
      search_undo_capacity = State.search_undo_capacity(),
      safety_leaves = {
        SAFETY_LEAVES[1], SAFETY_LEAVES[2], SAFETY_LEAVES[3],
      },
      difficulty_profiles = {
        easy = DIFFICULTY_PROFILE[1],
        medium = DIFFICULTY_PROFILE[2],
        hard = DIFFICULTY_PROFILE[3],
      },
    }
  end,
}

function M.step(session, clock, elapsed_ms, watchdog)
  session.watchdog = watchdog
  if session.done then
    return {
      done = true, move = session.best or session.fallback,
      order_hint = build_order_hint(session), stats = session.stats,
    }
  end
  session.clock = clock
  local tick_ms = math.max(0, tonumber(elapsed_ms) or 0)
  session.stats.tick_ms = tick_ms
  session.stats.max_tick_ms = math.max(session.stats.max_tick_ms or 0, tick_ms)
  if not session.started_ms then
    session.started_ms = clock()
    session.deadline_ms = session.started_ms + session.max_ms
    local book_reserve_ms = session.root_checked and SEARCH_RESERVE_MS or 0
    session.book_deadline_ms = math.min(
      session.started_ms + BOOK_BUDGET_MS,
      session.deadline_ms - book_reserve_ms
    )
    if session.book_phase then session.book_started_ms = session.started_ms end
  end
  if not session.geometry_ready then session.geometry_ready = true; Opening.ensure_ready() end
  local now = clock()
  session.elapsed_ms = now - session.started_ms
  if session.elapsed_ms < 0 then session.elapsed_ms = 0 end
  if session.elapsed_ms > session.max_ms then session.elapsed_ms = session.max_ms end
  session.stats.elapsed_ms = session.elapsed_ms
  session.stats.max_ms = session.max_ms
  if session.elapsed_ms >= session.max_ms or now >= session.deadline_ms then
    return finish(session, "timeout")
  end
  local slice_started = clock()
  session.hard_deadline = session.deadline_ms
  local remaining_ms = session.deadline_ms - slice_started
  if remaining_ms <= 0 then
    session.elapsed_ms = session.max_ms
    session.stats.elapsed_ms = session.elapsed_ms
    return finish(session, "timeout")
  end
  session.slice_deadline = slice_started + math.min(SLICE_MS, remaining_ms)

  if session.book_phase then
    local complete = step_opening_with_metrics(session)
    if not complete then
      if session.stop_reason then return finish(session, session.stop_reason) end
      if book_budget_exhausted(session) then
        session.stats.book_aborted = true
        session.stats.book_out = true
        Opening.close(session.book_session)
        end_phase_timing(session, "book")
        session.book_phase = false
      else
        return { done = false, stats = session.stats }
      end
    end
    if session.book_phase and session.book_session.book_error then
      end_phase_timing(session, "book")
      session.book_phase = false
      session.book_unavailable = true
      session.stats.book_unavailable = true
      session.stats.book_out = true
    elseif session.book_phase then
      local result = finish_opening_phase(session)
      if result then return result end
    end
  end

  if session.static_mode then
    if not session.search_started then
      session.stats.search_started = true
      session.search_started_ms = session.search_started_ms or session.clock()
    end
    session.static_slice_nodes = 0
    local complete = static_one_step(session)
    if complete or session.stop_reason then return finish(session, session.stop_reason or "static_eval") end
    return { done = false, stats = session.stats }
  end

  local resumed_existing_layer =
    session.search_stack ~= nil and #session.search_stack > 0
  if not session.search_stack then
    session.stats.search_started = true
    session.search_started_ms = session.search_started_ms or session.clock()
    begin_alpha_beta(session, session.active_depth)
  end
  resume_alpha_beta(session)
  if resumed_existing_layer and not session.stop_reason then
    session.stats.resume_count = session.stats.resume_count + 1
    session.stats.current_layer_resumes = session.stats.current_layer_resumes + 1
  end
  session.stats.current_layer_progress =
    (session.stats.nodes - session.layer_node_start)
    + (session.stats.root_moves_completed - session.layer_root_start)
  if session.search_stack and #session.search_stack > 0 then
    if session.stop_reason then return finish(session, session.stop_reason) end
    return { done = false, stats = session.stats }
  end

  local result = session.search_result
  if result and result.move then
    session.best = result.move
    session.completed_depth = session.active_depth
    session.stats.completed_depth = session.completed_depth
    if session.two_stage_easy and session.active_depth == 1
      and session.terminal_root then
      session.stats.terminal_complete = true
    elseif session.two_stage_easy and session.active_depth == 1
      and not session.stats.baseline_complete then
      session.baseline_collecting = false
      session.stats.baseline_complete = true
      session.stats.baseline_elapsed_ms = math.max(
        0, session.clock() - (session.search_started_ms or session.started_ms)
      )
      session.stats.baseline_root_moves_completed =
        session.stats.root_moves_completed - session.layer_root_start
      table.sort(session.baseline_ranked, function(a, b)
        if a.score == b.score then return a.order < b.order end
        return a.score > b.score
      end)
      session.root_candidate_codes = {}
      local tactical_count = math.min(EASY_TACTICAL_ROOTS, #session.baseline_ranked)
      for index = 1, tactical_count do
        session.root_candidate_codes[index] = session.baseline_ranked[index].code
      end
      session.stats.tactical_started = tactical_count > 0
      session.stats.tactical_candidate_count = tactical_count
      if session.stats.tactical_started then
        clear_cache(session.tt_cache, session.watchdog)
        if session.legacy_tt_enabled then session.tt = {} end
        session.tt_count = 0
        session.quiescence_depth = QUIESCENCE_DEPTH[session.difficulty] or 0
        session.root_move_limit = tactical_count
        begin_alpha_beta(session, 1)
        return { done = false, move = session.best, stats = session.stats }
      end
    elseif session.two_stage_easy and session.stats.tactical_started
      and not session.stats.tactical_complete and session.active_depth == 1 then
      session.stats.tactical_complete = true
      session.stats.tactical_root_moves_completed =
        session.stats.root_moves_completed - session.layer_root_start
      session.root_candidate_codes = nil
      session.root_move_limit = 12
    end
    if session.active_depth < session.target_depth and session.elapsed_ms < session.max_ms then
      begin_alpha_beta(session, session.active_depth + 1)
      return { done = false, stats = session.stats }
    end
    return finish(session, "target_depth")
  end
  return finish(session, "no_legal_move")
end

function M.choose(s, opts)
  local fallback = State.board_first_move(s.board, s.turn)
  if not fallback then return nil end
  if opts and opts.budget_ms and opts.budget_ms <= 0 then return fallback end
  return fallback
end

function M.result(session) return session and (session.best or session.fallback) or nil end
function M.cancel(session)
  if not session then return end
  unwind_search_stack(session)
  Opening.close(session.book_session)
  finalize_phase_timings(session)
  sync_runtime_metrics(session)
  if not session.done then
    session.done = true
    session.stop_reason = session.stop_reason or "cancelled"
  end
  if session.stats then
    session.stats.reason = session.stop_reason
    session.stats.stop_reason = session.stop_reason
  end
  release_caches(session)
  if session.search_state then
    State.release_search_state(session.search_state)
    session.search_state = nil
  end
end
function M.eval(board, side) return evaluate(board, side) end
function M.repetition_signature(counts) return repetition_signature(counts) end
function M.extend_repetition_signature(signature, key, count, entry_count)
  return extend_repetition_signature(signature, key, count, entry_count)
end
function M.tt_context_matches(entry, signature) return tt_context_matches(entry, signature) end

function M.mood(s)
  if s.status == "black_win" then return "proud" end
  if s.status == "red_win" then return "panicked" end
  local score = evaluate(s.board, "b")
  if score >= MOOD_EDGE then return "proud" end
  if score <= -MOOD_EDGE then return "panicked" end
  return "thinking"
end

return M
