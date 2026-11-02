-- Pure, deterministic Xiangqi leaf evaluation.  Scores use the itlwei scale
-- (pawn ~10, horse/cannon ~100, rook ~200); a check dominates unsafe captures.
local State = require("domain.chess_state")
local Itlwei = require("domain.chess_itlwei")
local Geometry = require("domain.chess_geometry")
local M = {}

local WEIGHTS = {
  attacked_protected = -4,   -- A defended target still costs some initiative.
  hanging_piece = -24,       -- Losing an undefended piece is tactically urgent.
  horse_move = 2,            -- At most 16 points for one fully mobile horse.
  crossed_pawn = 8,          -- River crossing unlocks sideways movement.
  connected_pawn = 6,        -- Count each adjacent pawn pair once.
  palace_pressure = -12,     -- Per attacked square in the 3 x 3 palace.
  in_check = -320,           -- Larger than one rook on the baseline scale.
  give_check = 24,           -- Delivering check earns only a small tempo, never a rook.
  general_pressure = 14,     -- Threshold synergy, not another per-square charge.
  coordinated_attack = 12,   -- Two independent attackers on one tactical piece.
  useful_blocker = 72,       -- Strong tempo, still well below baseline rook value.
  exchange_step = 4,         -- Per ten points of favorable capture quality.
}
local EXCHANGE_VALUE = { p = 10, a = 20, b = 20, n = 45, c = 50, r = 90, k = 900 }

local HORSE_STEPS = {
  { -2, -1, -1, 0 }, { -2, 1, -1, 0 },
  { 2, -1, 1, 0 }, { 2, 1, 1, 0 },
  { -1, -2, 0, -1 }, { 1, -2, 0, -1 },
  { -1, 2, 0, 1 }, { 1, 2, 0, 1 },
}
local KING_STEPS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local SIDES = { "r", "b" }
local SEARCH_FEATURES = {
  "safety", "mobility", "pawns", "king", "pressure",
  "coordination", "restriction", "exchange", "checked",
}
local ATTACK_KIND_VALUES = { 10, 20, 20, 45, 50, 90, 900 }

local function other(side) return side == "r" and "b" or "r" end

local function orient(red_score, black_score, side)
  local raw = red_score - black_score
  return side == "r" and raw or -raw
end

-- 单次有界分析供给搜索叶节点的所有特征；棋子列表调用即弃，不泄漏状态。
local function analyze(board)
  local pieces = { r = {}, b = {} }
  local scores = {
    r = {
      safety = 0, mobility = 0, pawns = 0, king = 0, checked = 0,
      pressure = 0, coordination = 0, restriction = 0, exchange = 0,
    },
    b = {
      safety = 0, mobility = 0, pawns = 0, king = 0, checked = 0,
      pressure = 0, coordination = 0, restriction = 0, exchange = 0,
    },
    baseline = 0,
  }
  local kings = {}
  local tactical_targets = {}

  for r = 0, 9 do
    for c = 0, 8 do
      local ch = State.at(board, r, c)
      if ch ~= "." then
        local side = State.side_of(ch)
        local kind = ch:lower()
        local value = Itlwei.value_at(ch, r, c)
        scores.baseline = scores.baseline + (side == "r" and value or -value)
        pieces[side][#pieces[side] + 1] = { r = r, c = c, kind = kind }
        if kind == "k" then kings[side] = { r = r, c = c } end
        if kind == "n" or kind == "c" or kind == "r" then
          tactical_targets[#tactical_targets + 1] = { r = r, c = c }
        end
        if kind == "n" then
          for _, step in ipairs(HORSE_STEPS) do
            local tr, tc = r + step[1], c + step[2]
            if tr >= 0 and tr <= 9 and tc >= 0 and tc <= 8
              and State.at(board, r + step[3], c + step[4]) == "."
              and State.side_of(State.at(board, tr, tc)) ~= side then
              scores[side].mobility = scores[side].mobility + WEIGHTS.horse_move
            end
          end
        elseif kind == "p" then
          local crossed = (side == "r" and r <= 4) or (side == "b" and r >= 5)
          if crossed then scores[side].pawns = scores[side].pawns + WEIGHTS.crossed_pawn end
          if State.at(board, r, c + 1) == ch then
            scores[side].pawns = scores[side].pawns + WEIGHTS.connected_pawn
          end
        end
      end
    end
  end

  local attack_maps = {
    r = State.board_attack_map(board, "r", tactical_targets),
    b = State.board_attack_map(board, "b", tactical_targets),
  }
  for _, side in ipairs(SIDES) do
    local enemy = other(side)
    local enemy_king = kings[enemy]
    if enemy_king then
      local restricted = 0
      for _, delta in ipairs(KING_STEPS) do
        local r, c = enemy_king.r + delta[1], enemy_king.c + delta[2]
        local in_rows = enemy == "r" and r >= 7 and r <= 9 or enemy == "b" and r >= 0 and r <= 2
        if in_rows and c >= 3 and c <= 5
          and State.side_of(State.at(board, r, c)) ~= enemy
          and State.attack_map_has(attack_maps[side], r, c, true) then
          restricted = restricted + 1
        end
      end
      -- 仅从第二个受制格开始计，且封顶。
      if restricted >= 2 then
        scores[side].pressure = math.min(2, restricted - 1) * WEIGHTS.general_pressure
      end
    end

    for _, piece in ipairs(pieces[side]) do
      -- 交换分仅限战术子；攻击图构造本身固定成本且常开。
      if piece.kind == "n" or piece.kind == "c" or piece.kind == "r" then
        local attacked = State.attack_map_has(attack_maps[enemy], piece.r, piece.c, false)
        if attacked then
          local protected = State.attack_map_has(attack_maps[side], piece.r, piece.c, false)
          scores[side].safety = scores[side].safety
            + (protected and WEIGHTS.attacked_protected or WEIGHTS.hanging_piece)
        end
      end
    end

    for _, target in ipairs(pieces[enemy]) do
      if target.kind == "n" or target.kind == "c" or target.kind == "r" then
        local attack_count = State.attack_map_count(attack_maps[side], target.r, target.c)
        if attack_count >= 2 then
          scores[side].coordination = scores[side].coordination + WEIGHTS.coordinated_attack
        end
        if attack_count > 0 then
          local minimum_attacker = nil
          for kind in pairs(State.attack_map_attackers(attack_maps[side], target.r, target.c)) do
            local value = EXCHANGE_VALUE[kind]
            if value and (not minimum_attacker or value < minimum_attacker) then
              minimum_attacker = value
            end
          end
          local quality = minimum_attacker
            and math.max(0, EXCHANGE_VALUE[target.kind] - minimum_attacker) or 0
          scores[side].exchange = scores[side].exchange
            + math.min(24, math.floor(quality / 10) * WEIGHTS.exchange_step)
        end
      end
    end

    local king = kings[side]
    if king then
      if State.attack_map_has(attack_maps[enemy], king.r, king.c, true) then
        scores[side].checked = 1
        scores[side].king = scores[side].king + WEIGHTS.in_check
      end
      -- 王宫压力指被攻击的一步逃格（非全九宫）；假设占位给炮捕获语义。
      for _, delta in ipairs(KING_STEPS) do
        local r, c = king.r + delta[1], king.c + delta[2]
        local in_rows = side == "r" and r >= 7 and r <= 9 or side == "b" and r >= 0 and r <= 2
        local target_side = State.side_of(State.at(board, r, c))
        if in_rows and c >= 3 and c <= 5 and target_side ~= side
          and State.attack_map_has(attack_maps[enemy], r, c, true) then
          scores[side].king = scores[side].king + WEIGHTS.palace_pressure
        end
      end

      -- 将帅间单一隔子是有效限制；炮排除（一个炮架即其吃子条件，奖分会反转战术）。
      for _, delta in ipairs(KING_STEPS) do
        local r, c = king.r + delta[1], king.c + delta[2]
        local blocker = false
        while r >= 0 and r <= 9 and c >= 0 and c <= 8 do
          local ch = State.at(board, r, c)
          if ch ~= "." then
            if not blocker and State.side_of(ch) == side and ch:lower() ~= "k" then
              blocker = true
            else
              if blocker and State.side_of(ch) == enemy and ch:lower() == "r" then
                scores[side].restriction = scores[side].restriction + WEIGHTS.useful_blocker
              end
              break
            end
          end
          r, c = r + delta[1], c + delta[2]
        end
      end
    end
  end
  return scores
end

local function minimum_attacker(mask)
  local bit = 1
  for index = 1, #ATTACK_KIND_VALUES do
    if math.floor(mask / bit) % 2 == 1 then return ATTACK_KIND_VALUES[index] end
    bit = bit * 2
  end
  return nil
end

local function analyze_search(board)
  local scores = board.evaluation_scores
  if not scores then
    scores = { r = {}, b = {}, baseline = 0 }
    board.evaluation_scores = scores
  end
  scores.baseline = 0
  for _, side in ipairs(SIDES) do
    for _, feature in ipairs(SEARCH_FEATURES) do scores[side][feature] = 0 end
  end

  for _, side in ipairs(SIDES) do
    for _, entry in ipairs(board.pieces[side]) do
      local kind, r, c = entry.piece:lower(), entry.r, entry.c
      local value = Itlwei.value_at(entry.piece, r, c)
      scores.baseline = scores.baseline + (side == "r" and value or -value)
      if kind == "n" then
        if Geometry.is_ready() then
          local offset, count = Geometry.move_range(1, entry.square)
          for index = 0, count - 1 do
            local _, _, target, blocker = Geometry.move_at(offset + index)
            if board.cells[blocker + 1] == "." then
              local target_piece = board.cells[target + 1]
              if target_piece == "." or State.side_of(target_piece) ~= side then
                scores[side].mobility = scores[side].mobility + WEIGHTS.horse_move
              end
            end
          end
        else
          for _, step in ipairs(HORSE_STEPS) do
            local tr, tc = r + step[1], c + step[2]
            if tr >= 0 and tr <= 9 and tc >= 0 and tc <= 8
              and State.at(board, r + step[3], c + step[4]) == "."
              and State.side_of(State.at(board, tr, tc)) ~= side then
              scores[side].mobility = scores[side].mobility + WEIGHTS.horse_move
            end
          end
        end
      elseif kind == "p" then
        local crossed = side == "r" and r <= 4 or side == "b" and r >= 5
        if crossed then scores[side].pawns = scores[side].pawns + WEIGHTS.crossed_pawn end
        if State.at(board, r, c + 1) == entry.piece then
          scores[side].pawns = scores[side].pawns + WEIGHTS.connected_pawn
        end
      end
    end
  end

  for _, side in ipairs(SIDES) do
    local enemy = other(side)
    local enemy_king = board.kings[enemy]
    if enemy_king and enemy_king.r ~= nil then
      local restricted = 0
      for _, delta in ipairs(KING_STEPS) do
        local r, c = enemy_king.r + delta[1], enemy_king.c + delta[2]
        local in_rows = enemy == "r" and r >= 7 and r <= 9 or enemy == "b" and r >= 0 and r <= 2
        if in_rows and c >= 3 and c <= 5
          and State.side_of(State.at(board, r, c)) ~= enemy
          and State.board_square_attacked(board, side, r, c, enemy == "r" and "k" or "K") then
          restricted = restricted + 1
        end
      end
      if restricted >= 2 then
        scores[side].pressure = math.min(2, restricted - 1) * WEIGHTS.general_pressure
      end
    end

    for _, piece in ipairs(board.pieces[side]) do
      local kind = piece.piece:lower()
      if kind == "n" or kind == "c" or kind == "r" then
        local square = piece.square
        if State.search_attack_count(board, enemy, square, true) > 0 then
          local protected = State.search_attack_count(board, side, square, true) > 0
          scores[side].safety = scores[side].safety
            + (protected and WEIGHTS.attacked_protected or WEIGHTS.hanging_piece)
        end
      end
    end

    for _, target in ipairs(board.pieces[enemy]) do
      local target_kind = target.piece:lower()
      if target_kind == "n" or target_kind == "c" or target_kind == "r" then
        local count = State.search_attack_count(board, side, target.square, true)
        if count >= 2 then
          scores[side].coordination = scores[side].coordination + WEIGHTS.coordinated_attack
        end
        if count > 0 then
          local minimum = minimum_attacker(State.search_attack_kinds(board, side, target.square, true))
          local quality = minimum and math.max(0, EXCHANGE_VALUE[target_kind] - minimum) or 0
          scores[side].exchange = scores[side].exchange
            + math.min(24, math.floor(quality / 10) * WEIGHTS.exchange_step)
        end
      end
    end

    local king = board.kings[side]
    if king and king.r ~= nil then
      if State.board_in_check(board, side) then
        scores[side].checked = 1
        scores[side].king = scores[side].king + WEIGHTS.in_check
      end
      for _, delta in ipairs(KING_STEPS) do
        local r, c = king.r + delta[1], king.c + delta[2]
        local in_rows = side == "r" and r >= 7 and r <= 9 or side == "b" and r >= 0 and r <= 2
        if in_rows and c >= 3 and c <= 5 and State.side_of(State.at(board, r, c)) ~= side
          and State.board_square_attacked(board, enemy, r, c, side == "r" and "k" or "K") then
          scores[side].king = scores[side].king + WEIGHTS.palace_pressure
        end
      end
      for direction = 0, 3 do
        local blocker = false
        local offset, count = Geometry.ray_range(king.r * 9 + king.c, direction)
        for index = 0, count - 1 do
          local square = Geometry.ray_at(offset + index)
          local ch = board.cells[square + 1]
          if ch ~= "." then
            if not blocker and State.side_of(ch) == side and ch:lower() ~= "k" then
              blocker = true
            else
              if blocker and State.side_of(ch) == enemy and ch:lower() == "r" then
                scores[side].restriction = scores[side].restriction + WEIGHTS.useful_blocker
              end
              break
            end
          end
        end
      end
    end
  end
  return scores
end

local function analyze_position(board)
  if type(board) == "table" and board.pieces and board.attack_occ_count_r then
    return analyze_search(board)
  end
  return analyze(board)
end

local function feature_score(scores, key, side)
  return orient(scores.r[key], scores.b[key], side)
end

-- 被将军的扣分只该惩罚己方；己方给敌方将军只计小的节奏奖励，
-- 避免一次无关将军(+320)在叶评估里盖过吃一辆免费车(+200)。
local function king_term(scores, side)
  local enemy = other(side)
  local enemy_checked = (scores[enemy].checked or 0) ~= 0
  return feature_score(scores, "king", side)
    + (enemy_checked and WEIGHTS.in_check or 0)
    + (enemy_checked and WEIGHTS.give_check or 0)
end

function M.material_score(board, side)
  -- 完整导入的 itlwei 棋子位置表即物态基线，不再用第二张本地价值表近似。
  if type(board) == "table" and board.pieces then
    local baseline = 0
    for _, own_side in ipairs(SIDES) do
      for _, entry in ipairs(board.pieces[own_side]) do
        local value = Itlwei.value_at(entry.piece, entry.r, entry.c)
        baseline = baseline + (own_side == "r" and value or -value)
      end
    end
    return side == "r" and baseline or -baseline
  end
  return Itlwei.evaluate(board, side)
end

function M.piece_safety_score(board, side)
  return feature_score(analyze_position(board), "safety", side)
end

function M.mobility_score(board, side)
  return feature_score(analyze_position(board), "mobility", side)
end

function M.pawn_structure_score(board, side)
  return feature_score(analyze_position(board), "pawns", side)
end

function M.king_safety_score(board, side)
  return feature_score(analyze_position(board), "king", side)
end

function M.general_pressure_score(board, side)
  return feature_score(analyze_position(board), "pressure", side)
end

function M.coordination_score(board, side)
  return feature_score(analyze_position(board), "coordination", side)
end

function M.restriction_score(board, side)
  return feature_score(analyze_position(board), "restriction", side)
end

function M.exchange_quality_score(board, side)
  -- 仅诊断/排序用：物态安全已计被攻战术子，加入叶总值会重复计。
  return feature_score(analyze_position(board), "exchange", side)
end

function M.component_scores(board, side)
  local scores = analyze_position(board)
  return {
    material = side == "r" and scores.baseline or -scores.baseline,
    piece_safety = feature_score(scores, "safety", side),
    mobility = feature_score(scores, "mobility", side),
    pawn_structure = feature_score(scores, "pawns", side),
    king_safety = feature_score(scores, "king", side),
    check_given = (scores[other(side)].checked or 0) ~= 0 and WEIGHTS.give_check or 0,
    general_pressure = feature_score(scores, "pressure", side),
    coordination = feature_score(scores, "coordination", side),
    restriction = feature_score(scores, "restriction", side),
    exchange_quality = feature_score(scores, "exchange", side),
  }
end

function M.evaluate(board, side)
  local scores = analyze_position(board)
  return (side == "r" and scores.baseline or -scores.baseline)
    + feature_score(scores, "safety", side)
    + feature_score(scores, "mobility", side)
    + king_term(scores, side)
    + feature_score(scores, "pawns", side)
    + feature_score(scores, "pressure", side)
    + feature_score(scores, "coordination", side)
    + feature_score(scores, "restriction", side)
end

return M
