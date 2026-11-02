-- 新手 AI 的即时决策路径。
-- 花色不参与斗地主判型；缓存只保存 15 个点数的出牌配方，再映射回实际 card id。

local Rules = require("domain.doudizhu_rules")

local M = {}
local MAX_CACHE = 96
local lead_cache, follow_cache = {}, {}
local lead_order, follow_order = {}, {}

local function remember(cache, order, key, recipe)
  if cache[key] then return end
  cache[key] = recipe
  order[#order + 1] = key
  if #order > MAX_CACHE then cache[table.remove(order, 1)] = nil end
end

local function grade_recipe(cards)
  local grades = {}
  for i, id in ipairs(cards or {}) do grades[i] = Rules.grade_of(id) end
  table.sort(grades)
  return grades
end

local function cards_from_recipe(hand, recipe)
  local needed, cards = {}, {}
  for _, grade in ipairs(recipe or {}) do needed[grade] = (needed[grade] or 0) + 1 end
  for grade = 3, 17 do
    local count = needed[grade] or 0
    if count > 0 then
      local ids = Rules.first_ids(hand, grade, count)
      if #ids ~= count then return nil end
      for _, id in ipairs(ids) do cards[#cards + 1] = id end
    end
  end
  return cards
end

local function longest_run(counts, need, minimum)
  local best, start = nil, 3
  while start <= 14 do
    while start <= 14 and counts[start] ~= need do start = start + 1 end
    if start > 14 then break end
    local finish = start
    while finish < 14 and counts[finish + 1] == need do finish = finish + 1 end
    if finish - start + 1 >= minimum then
      local candidate = { start = start, finish = finish, need = need }
      if not best or (candidate.finish - candidate.start) > (best.finish - best.start) then best = candidate end
    end
    start = finish + 1
  end
  return best
end

local function run_recipe(run)
  local recipe = {}
  for grade = run.start, run.finish do
    for _ = 1, run.need do recipe[#recipe + 1] = grade end
  end
  return recipe
end

local function first_recipe_by_count(counts, wanted)
  for grade = 3, 17 do
    if counts[grade] == wanted then
      local recipe = {}
      for _ = 1, wanted do recipe[#recipe + 1] = grade end
      return recipe
    end
  end
  return nil
end

local function fast_lead_recipe(hand)
  if Rules.get_type(hand) then return grade_recipe(hand), "一手走完" end
  local counts = Rules.count_grades(hand)
  -- 不从四张里拆长套，保留炸弹；其余长套优先一次走更多牌。
  local best = nil
  for _, candidate in ipairs({
    { run = longest_run(counts, 3, 2) },
    { run = longest_run(counts, 2, 3) },
    { run = longest_run(counts, 1, 5) },
  }) do
    local run = candidate.run
    if run and (not best or (run.finish - run.start + 1) * run.need > (best.finish - best.start + 1) * best.need) then best = run end
  end
  if best then return run_recipe(best), "快速长套" end
  for grade = 3, 15 do
    if counts[grade] == 3 then
      local trio = Rules.first_ids(hand, grade, 3)
      local wing = Rules.find_attachment(hand, trio, 1)
      if wing then return { grade, grade, grade, Rules.grade_of(wing[1]) }, "快速三带一" end
    end
  end
  local pair = first_recipe_by_count(counts, 2)
  if pair then return pair, "快速对子" end
  local trio = first_recipe_by_count(counts, 3)
  if trio then return trio, "快速三张" end
  local single = first_recipe_by_count(counts, 1)
  if single then return single, "快速单张" end
  local bomb = first_recipe_by_count(counts, 4)
  if bomb then return bomb, "保留后使用炸弹" end
  if counts[16] == 1 and counts[17] == 1 then return { 16, 17 }, "保留后使用王炸" end
  return { Rules.grade_of(hand[1]) }, "兜底单张"
end

function M.choose_lead(hand)
  local key = Rules.hand_signature(hand)
  local recipe = lead_cache[key]
  if recipe then return cards_from_recipe(hand, recipe), { reason = "快速缓存首出", cache_hit = true } end
  recipe = select(1, fast_lead_recipe(hand))
  remember(lead_cache, lead_order, key, recipe)
  return cards_from_recipe(hand, recipe), { reason = "快速规则首出", cache_hit = false }
end

local function target_key(card_type)
  return table.concat({ card_type.t or "", card_type.grade or 0, card_type.n or 0 }, ":")
end

function M.choose_follow(hand, last_type)
  local key = Rules.hand_signature(hand) .. "|" .. target_key(last_type)
  local recipe = follow_cache[key]
  if recipe then
    if recipe == false then return nil, { reason = "快速缓存不出", cache_hit = true } end
    return cards_from_recipe(hand, recipe), { reason = "快速缓存压制", cache_hit = true }
  end
  -- greater_cards 的顺序是同型最小压制 → 炸弹 → 王炸；新手只取第一手。
  local options = Rules.greater_cards(hand, last_type)
  local first = options[1]
  recipe = first and grade_recipe(first.cards) or false
  remember(follow_cache, follow_order, key, recipe)
  if not first then return nil, { reason = "无牌可压", cache_hit = false } end
  return first.cards, { reason = "快速最小压制", cache_hit = false }
end

return M
