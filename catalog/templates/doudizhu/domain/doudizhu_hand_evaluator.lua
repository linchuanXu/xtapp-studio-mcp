-- 手牌候选枚举与质量评估。只处理牌，不知道玩家身份或 UI。

local Rules = require("domain.doudizhu_rules")
local M = {}

local function copy_list(values)
  local out = {}
  for i, value in ipairs(values or {}) do out[i] = value end
  return out
end

local function candidate_key(cards)
  local sorted = Rules.sort_desc(cards)
  return table.concat(sorted, ",")
end

local function hand_key(cards)
  return candidate_key(cards)
end

local function type_priority(card_type)
  local order = {
    trio_pair_chain = 9, trio_solo_chain = 8, trio_chain = 7,
    pair_chain = 6, chain = 5, trio_pair = 4, trio_solo = 3,
    trio = 2, pair = 1, single = 0, bomb = -2, rocket = -3,
  }
  return order[card_type and card_type.t] or 0
end

function M.enumerate_leads(hand, options)
  options = options or {}
  local checkpoint = options.checkpoint
  local max_candidates = options.max_candidates or 96
  local work, exhausted = 0, false
  local function pulse()
    work = work + 1
    if checkpoint and work % 8 == 0 and checkpoint() == false then exhausted = true end
  end
  local function full(candidates)
    return exhausted or #candidates >= max_candidates
  end
  local counts = Rules.count_grades(hand)
  local candidates, seen = {}, {}
  local function push(cards)
    pulse()
    if full(candidates) then return false end
    if not cards or #cards == 0 then return end
    local card_type = Rules.get_type(cards)
    if not card_type then return end
    local key = candidate_key(cards)
    if seen[key] then return end
    seen[key] = true
    candidates[#candidates + 1] = { cards = copy_list(cards), type = card_type }
    return true
  end
  local function ids(grade, count) return Rules.first_ids(hand, grade, count) end

  push(hand) -- 整手合法时必须能立即走完。
  for grade = 3, 17 do
    if full(candidates) then break end
    if counts[grade] >= 1 then push(ids(grade, 1)) end
    if grade <= 15 and counts[grade] >= 2 then push(ids(grade, 2)) end
    if grade <= 15 and counts[grade] >= 3 then
      local trio = ids(grade, 3)
      push(trio)
      local solo = Rules.find_attachment(hand, trio, 1)
      if solo then
        local with_solo = copy_list(trio)
        for _, id in ipairs(solo) do with_solo[#with_solo + 1] = id end
        push(with_solo)
      end
      local pair = Rules.find_attachment(hand, trio, 2)
      if pair then
        local with_pair = copy_list(trio)
        for _, id in ipairs(pair) do with_pair[#with_pair + 1] = id end
        push(with_pair)
      end
    end
    if grade <= 15 and counts[grade] >= 4 then push(ids(grade, 4)) end
  end
  if counts[16] > 0 and counts[17] > 0 then push({ 53, 54 }) end

  local function runs(need, minimum)
    local start = 3
    while start <= 14 do
      pulse()
      if full(candidates) then return end
      while start <= 14 and counts[start] < need do start = start + 1 end
      if start > 14 then break end
      local finish = start
      while finish + 1 <= 14 and counts[finish + 1] >= need do finish = finish + 1 end
      if finish - start + 1 >= minimum then
        for left = start, finish - minimum + 1 do
          for right = left + minimum - 1, finish do
            if full(candidates) then return end
            local cards = {}
            for grade = left, right do
              for _, id in ipairs(ids(grade, need)) do cards[#cards + 1] = id end
            end
            push(cards)
          end
        end
      end
      start = finish + 1
    end
  end
  runs(1, 5)
  runs(2, 3)
  runs(3, 2)

  -- 为飞机与四张补最节省结构的翅膀。候选仍交给 Rules.get_type 复核，
  -- 评估层不复制一套判型规则。
  local structural_count = #candidates
  for index = 1, structural_count do
    pulse()
    if full(candidates) then break end
    local candidate = candidates[index]
    local pool = Rules.remove(hand, candidate.cards)
    local pool_counts = Rules.count_grades(pool)
    if candidate.type.t == Rules.CARD_TYPE.trio_chain then
      local length = candidate.type.n
      local singles = {}
      for layer = 1, 2 do
        for grade = 3, 17 do
          if #singles < length and pool_counts[grade] >= layer then
            local found = Rules.first_ids(pool, grade, layer)
            singles[#singles + 1] = found[layer]
          end
        end
      end
      if #singles == length then
        local with_singles = copy_list(candidate.cards)
        for _, id in ipairs(singles) do with_singles[#with_singles + 1] = id end
        push(with_singles)
      end
      local pairs = {}
      for grade = 3, 15 do
        if #pairs < length * 2 and pool_counts[grade] >= 2 then
          for _, id in ipairs(Rules.first_ids(pool, grade, 2)) do pairs[#pairs + 1] = id end
        end
      end
      if #pairs == length * 2 then
        local with_pairs = copy_list(candidate.cards)
        for _, id in ipairs(pairs) do with_pairs[#with_pairs + 1] = id end
        push(with_pairs)
      end
    elseif candidate.type.t == Rules.CARD_TYPE.bomb then
      local singles, pairs = {}, {}
      for grade = 3, 17 do
        if #singles < 2 and pool_counts[grade] >= 1 then singles[#singles + 1] = Rules.first_ids(pool, grade, 1)[1] end
        if grade <= 15 and #pairs < 4 and pool_counts[grade] >= 2 then
          for _, id in ipairs(Rules.first_ids(pool, grade, 2)) do pairs[#pairs + 1] = id end
        end
      end
      if #singles == 2 then
        local four_two = copy_list(candidate.cards)
        for _, id in ipairs(singles) do four_two[#four_two + 1] = id end
        push(four_two)
      end
      if #pairs == 4 then
        local four_pairs = copy_list(candidate.cards)
        for _, id in ipairs(pairs) do four_pairs[#four_pairs + 1] = id end
        push(four_pairs)
      end
    end
  end

  table.sort(candidates, function(a, b)
    if #a.cards ~= #b.cards then return #a.cards > #b.cards end
    local pa, pb = type_priority(a.type), type_priority(b.type)
    if pa ~= pb then return pa > pb end
    return (a.type.grade or 0) < (b.type.grade or 0)
  end)
  return candidates
end

function M.analyze(hand)
  local counts = Rules.count_grades(hand)
  local singles, bombs, controls = 0, 0, 0
  for grade = 3, 17 do
    if counts[grade] == 1 then singles = singles + 1 end
    if grade <= 15 and counts[grade] == 4 then bombs = bombs + 1 end
    if grade >= 14 then controls = controls + counts[grade] end
  end
  local longest = 1
  -- 评估会在每个候选上执行，必须保持线性复杂度；完整候选枚举只在真正决策时做一次。
  for _, spec in ipairs({ { 1, 5 }, { 2, 3 }, { 3, 2 } }) do
    local need, minimum, run = spec[1], spec[2], 0
    for grade = 3, 15 do
      if grade <= 14 and counts[grade] >= need then
        run = run + 1
        if run >= minimum then longest = math.max(longest, run * need) end
      else
        run = 0
      end
    end
  end
  for grade = 3, 15 do
    if counts[grade] >= 3 then longest = math.max(longest, 3) end
    if counts[grade] >= 4 then longest = math.max(longest, 4) end
  end
  if counts[16] > 0 and counts[17] > 0 then longest = math.max(longest, 2) end
  local turns = #hand == 0 and 0 or math.max(1, math.ceil(#hand / math.max(1, longest)))
  -- 每个无法进入长套的独立点数至少还会占用一手，作为稳健下界修正。
  turns = math.max(turns, math.ceil(singles / 2))
  return { turns = turns, singles = singles, bombs = bombs, controls = controls, longest = longest }
end

function M.split_cost(hand, cards)
  local before = Rules.count_grades(hand)
  local used = Rules.count_grades(cards)
  local cost = 0
  for grade = 3, 17 do
    if used[grade] > 0 and used[grade] < before[grade] then
      cost = cost + (before[grade] - used[grade])
      if before[grade] == 4 then cost = cost + 4 end
    end
  end
  return cost
end

function M.power_cost(cards)
  local card_type = Rules.get_type(cards)
  if not card_type then return 999 end
  if card_type.t == Rules.CARD_TYPE.rocket then return 12 end
  if card_type.t == Rules.CARD_TYPE.bomb then return 9 end
  local cost = 0
  for _, id in ipairs(cards) do
    local grade = Rules.grade_of(id)
    if grade >= 16 then cost = cost + 4
    elseif grade == 15 then cost = cost + 3
    elseif grade == 14 then cost = cost + 1 end
  end
  return cost
end

-- 有限深度只搜索“自己的牌还要几手”，不假装知道对手的隐藏手牌。
function M.finish_distance(hand, depth, memo, budget)
  if #hand == 0 then return 0 end
  local whole = Rules.get_type(hand)
  if whole then return 1 end
  if depth <= 0 then return M.analyze(hand).turns end
  memo = memo or {}
  budget = budget or {}
  budget.nodes = (budget.nodes or 0) + 1
  if budget.checkpoint and budget.nodes % 8 == 0 and budget.checkpoint() == false then
    budget.exhausted = true
  end
  if budget.max_nodes and budget.nodes > budget.max_nodes then
    budget.exhausted = true
    return M.analyze(hand).turns
  end
  if budget.exhausted then return M.analyze(hand).turns end
  local key = tostring(depth) .. ":" .. hand_key(hand)
  if memo[key] then return memo[key] end
  local best = 99
  local candidates = M.enumerate_leads(hand, {
    checkpoint = function()
      if budget.exhausted then return false end
      local keep_going = not budget.checkpoint or budget.checkpoint() ~= false
      if not keep_going then budget.exhausted = true end
      return keep_going
    end,
    max_candidates = budget.max_candidates or 36,
  })
  local limit = math.min(#candidates, budget.branch_limit or 12)
  for index = 1, limit do
    if budget.exhausted then break end
    local remaining = Rules.remove(hand, candidates[index].cards)
    best = math.min(best, 1 + M.finish_distance(remaining, depth - 1, memo, budget))
  end
  if best == 99 then best = M.analyze(hand).turns end
  if not budget.exhausted then memo[key] = best end
  return best
end

return M
