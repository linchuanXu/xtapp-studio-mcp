-- 斗地主规则内核（纯逻辑，无 UI/IO）
-- 牌值约定（与 donnki/ddz_skynet、songbaoming 一致）：
--   权重 grade：3=3 … 10=10, J=11, Q=12, K=13, A=14, 2=15, 小王=16, 大王=17
--   牌值 card id：1..54（1-13 梅花, 14-26 方块, 27-39 红桃, 40-52 黑桃, 53 小王, 54 大王）
-- 手牌表示：表数组，元素为 card id（1..54）。
-- 判定结果：{ t = 牌型名, grade = 主体权重, n = 连续张数/长度, cards = 手牌 id 列表 }

local M = {}

-- ── 常量 ────────────────────────────────────────────────────────────────────
M.CARD_TYPE = {
  single = "single",        -- 单张
  pair = "pair",            -- 对子
  trio = "trio",            -- 三张
  trio_solo = "trio_solo",  -- 三带一
  trio_pair = "trio_pair",  -- 三带二
  chain = "chain",          -- 顺子（单顺）
  pair_chain = "pair_chain",-- 连对
  trio_chain = "trio_chain",-- 飞机（三顺不带）
  trio_solo_chain = "trio_solo_chain", -- 飞机带单
  trio_pair_chain = "trio_pair_chain", -- 飞机带对
  four_two_solo = "four_two_solo", -- 四带两单
  four_two_pair = "four_two_pair", -- 四带两对
  bomb = "bomb",            -- 炸弹
  rocket = "rocket",        -- 王炸
}

-- 牌 id → 权重（3..17）
local GRADE = {}
for i = 1, 52 do
  local v = i % 13
  if v < 3 then v = v + 13 end
  GRADE[i] = v
end
GRADE[53] = 16 -- 小王
GRADE[54] = 17 -- 大王

-- 权重 → 显示名（点数）
local GRADE_TEXT = {}
for i = 3, 10 do GRADE_TEXT[i] = tostring(i) end
GRADE_TEXT[11] = "J"
GRADE_TEXT[12] = "Q"
GRADE_TEXT[13] = "K"
GRADE_TEXT[14] = "A"
GRADE_TEXT[15] = "2"
GRADE_TEXT[16] = "小王"
GRADE_TEXT[17] = "大王"

-- ── 基础工具 ────────────────────────────────────────────────────────────────
local function copy_list(values)
  local out = {}
  for i, v in ipairs(values or {}) do out[i] = v end
  return out
end

-- 计数表：grade(3..17) → 张数
function M.count_grades(cards)
  local counts = {}
  for i = 3, 17 do counts[i] = 0 end
  for _, id in ipairs(cards or {}) do
    local g = GRADE[id]
    if g then counts[g] = counts[g] + 1 end
  end
  return counts
end

-- 花色不影响斗地主的判型与大小。15 位点数计数是稳定、可复用的策略缓存键。
function M.hand_signature(cards)
  local counts = M.count_grades(cards)
  local parts = {}
  for grade = 3, 17 do parts[#parts + 1] = tostring(counts[grade]) end
  return table.concat(parts, "")
end

function M.grade_of(id) return GRADE[id] end
function M.grade_text(grade) return GRADE_TEXT[grade] end
function M.sort_desc(cards)
  local out = copy_list(cards)
  table.sort(out, function(a, b) return GRADE[a] > GRADE[b] end)
  return out
end

-- 取权重为 grade 的前 count 张牌 id
function M.first_ids(cards, grade, count)
  local ids = {}
  local got = 0
  for _, id in ipairs(cards or {}) do
    if GRADE[id] == grade and got < (count or 1) then
      ids[#ids + 1] = id
      got = got + 1
    end
  end
  return ids
end

-- 连续检测：grades 数组（升序）是否 3..A 范围内的连续段
local function is_continue(grades)
  if #grades < 1 then return false end
  for i = 2, #grades do
    if grades[i] ~= grades[i - 1] + 1 then return false end
  end
  return grades[1] >= 3 and grades[#grades] <= 14 -- 3..A，2 与王不入链
end

-- ── 牌型判定 ────────────────────────────────────────────────────────────────
-- 输入：手牌 id 列表；输出：{t, grade, n, cards} 或 nil（非法）
function M.get_type(cards)
  if not cards or #cards == 0 then return nil end
  local n = #cards
  local counts = M.count_grades(cards)

  -- 王炸：大小王各一
  if n == 2 and counts[16] == 1 and counts[17] == 1 then
    return { t = M.CARD_TYPE.rocket, grade = 17, n = 2, cards = copy_list(cards) }
  end

  -- 按最大同权张数分类
  local max_count, max_grade = 0, 0
  local mult = {} -- 张数 → {grade,...} 升序
  for i = 3, 17 do
    local c = counts[i]
    if c > 0 then
      if c > max_count then max_count, max_grade = c, i end
      mult[c] = mult[c] or {}
      table.insert(mult[c], i)
    end
  end

  if max_count == 4 then
    return M.get_type4(counts, mult, n)
  elseif max_count == 3 then
    return M.get_type3(counts, mult, n)
  elseif max_count == 2 then
    return M.get_type2(counts, mult, n)
  else
    return M.get_type1(counts, mult, n)
  end
end

-- 炸弹/四带
function M.get_type4(counts, mult, n)
  -- 纯炸弹：4 张同权
  if n == 4 and counts[mult[4][1]] == 4 then
    return { t = M.CARD_TYPE.bomb, grade = mult[4][1], n = 4, cards = {} }
  end
  -- 四带二（两单）：4 + 1 + 1
  if n == 6 and #mult[4] == 1 and (mult[1] and #mult[1] == 2) then
    return { t = M.CARD_TYPE.four_two_solo, grade = mult[4][1], n = 1, cards = {} }
  end
  -- 四带二（两对）：4 + 2 + 2
  if n == 8 and #mult[4] == 1 and (mult[2] and #mult[2] == 2) then
    return { t = M.CARD_TYPE.four_two_pair, grade = mult[4][1], n = 2, cards = {} }
  end
  return nil
end

-- 三张系列 / 飞机
function M.get_type3(counts, mult, n)
  local trios = mult[3] -- 三张组（升序）
  if not trios then return nil end

  if #trios == 1 and n == 3 then
    return { t = M.CARD_TYPE.trio, grade = trios[1], n = 1, cards = {} }
  end
  if #trios == 1 and n == 4 and mult[1] and #mult[1] == 1 then
    return { t = M.CARD_TYPE.trio_solo, grade = trios[1], n = 1, cards = {} }
  end
  if #trios == 1 and n == 5 and mult[2] and #mult[2] == 1 then
    return { t = M.CARD_TYPE.trio_pair, grade = trios[1], n = 1, cards = {} }
  end

  -- 飞机：多组三张连续
  if #trios >= 2 and is_continue(trios) then
    local k = #trios
    local wings_single = n == k * 4 -- 每组三张带一张单
    local wings_pair = n == k * 5 and (mult[2] and #mult[2] == k) -- 每组带一对
    if wings_single then
      return { t = M.CARD_TYPE.trio_solo_chain, grade = trios[#trios], n = k, cards = {} }
    elseif wings_pair then
      return { t = M.CARD_TYPE.trio_pair_chain, grade = trios[#trios], n = k, cards = {} }
    elseif n == k * 3 then
      return { t = M.CARD_TYPE.trio_chain, grade = trios[#trios], n = k, cards = {} }
    end
  end
  return nil
end

-- 对子 / 连对
function M.get_type2(counts, mult, n)
  local pairs = mult[2]
  if not pairs then return nil end
  if #pairs == 1 and n == 2 then
    return { t = M.CARD_TYPE.pair, grade = pairs[1], n = 2, cards = {} }
  end
  if #pairs >= 3 and n == #pairs * 2 and is_continue(pairs) then
    return { t = M.CARD_TYPE.pair_chain, grade = pairs[#pairs], n = #pairs, cards = {} }
  end
  return nil
end

-- 单张 / 顺子
function M.get_type1(counts, mult, n)
  local singles = mult[1]
  if not singles then return nil end
  if n == 1 then
    return { t = M.CARD_TYPE.single, grade = singles[1], n = 1, cards = {} }
  end
  if n >= 5 and n == #singles and is_continue(singles) then
    return { t = M.CARD_TYPE.chain, grade = singles[#singles], n = n, cards = {} }
  end
  return nil
end

-- ── 大小比较 ────────────────────────────────────────────────────────────────
-- type_a 是否大于 type_b（两者必须来自 M.get_type 的合法结果）
function M.greater(type_a, type_b)
  if not type_a or not type_b then return false end
  local ta, tb = type_a.t, type_b.t
  -- 王炸压一切
  if ta == M.CARD_TYPE.rocket then return true end
  if tb == M.CARD_TYPE.rocket then return false end
  -- 炸弹压非炸弹
  if ta == M.CARD_TYPE.bomb and tb ~= M.CARD_TYPE.bomb then return true end
  if tb == M.CARD_TYPE.bomb and ta ~= M.CARD_TYPE.bomb then return false end
  -- 同型同长才可比
  if ta ~= tb or type_a.n ~= type_b.n then return false end
  return type_a.grade > type_b.grade
end

-- ── 出牌合法性 ──────────────────────────────────────────────────────────────
-- 手牌是否包含选定牌（按 id 集合）
function M.contains(cards, selected)
  local pool = copy_list(cards)
  for _, id in ipairs(selected or {}) do
    local found = false
    for i, pid in ipairs(pool) do
      if pid == id then table.remove(pool, i) found = true break end
    end
    if not found then return false end
  end
  return true
end

-- 出牌是否合法：selected 组成合法牌型，且（无上家 或 大于上家）
-- 返回 {ok=bool, reason=string, type=牌型|nil}
function M.can_play(cards, selected, last_type)
  if not selected or #selected == 0 then return { ok = false, reason = "empty" } end
  local t = M.get_type(selected)
  if not t then return { ok = false, reason = "invalid_type" } end
  if not M.contains(cards, selected) then return { ok = false, reason = "not_in_hand" } end
  if last_type and not M.greater(t, last_type) then
    return { ok = false, reason = "not_greater" }
  end
  return { ok = true, reason = "ok", type = t }
end

-- 手牌移除选定牌，返回新手牌
function M.remove(cards, selected)
  local pool = copy_list(cards)
  for _, id in ipairs(selected or {}) do
    for i, pid in ipairs(pool) do
      if pid == id then table.remove(pool, i) break end
    end
  end
  return pool
end

-- ── 最小可压牌（托管 AI 基础）──────────────────────────────────────────────
-- 从候选牌中找能压过 last_type 的所有合法出牌（牌型 id 列表）。
-- 返回数组：每个元素是 { cards = {id,...}, type = 牌型 }。优先返回同型最小，最后补炸弹/王炸。
function M.greater_cards(cards, last_type)
  local results = {}
  if not last_type then return results end
  local counts = M.count_grades(cards)
  local target = last_type

  local function push(t, grade, n, ids)
    results[#results + 1] = { cards = ids, type = { t = t, grade = grade, n = n } }
  end

  local function push_checked(ids)
    local card_type = M.get_type(ids)
    if card_type and M.greater(card_type, target) then
      results[#results + 1] = { cards = ids, type = card_type }
    end
  end

  -- 基于玩家手牌取牌：确保返回的 id 玩家真实持有
  local function first_ids(grade, count)
    return M.first_ids(cards, grade, count or 1)
  end

  -- 同型更大的（逐档枚举）
  local function same_type_greater()
    local t = target.t
    if t == M.CARD_TYPE.single then
      for g = target.grade + 1, 17 do
        if counts[g] >= 1 then push(t, g, 1, first_ids(g, 1)) end
      end
    elseif t == M.CARD_TYPE.pair then
      for g = target.grade + 1, 15 do
        if counts[g] >= 2 then push(t, g, 2, first_ids(g, 2)) end
      end
    elseif t == M.CARD_TYPE.trio then
      for g = target.grade + 1, 15 do
        if counts[g] >= 3 then push(t, g, 3, first_ids(g, 3)) end
      end
    elseif t == M.CARD_TYPE.trio_solo then
      for g = target.grade + 1, 15 do
        if counts[g] >= 3 then
          local ids = first_ids(g, 3)
          -- 找一张单牌附件
          local solo = M.find_attachment(cards, ids, 1)
          if solo then
            for _, sid in ipairs(solo) do ids[#ids + 1] = sid end
            push(t, g, 1, ids)
          end
        end
      end
    elseif t == M.CARD_TYPE.trio_pair then
      for g = target.grade + 1, 15 do
        if counts[g] >= 3 then
          local ids = first_ids(g, 3)
          local pair = M.find_attachment(cards, ids, 2)
          if pair then
            for _, sid in ipairs(pair) do ids[#ids + 1] = sid end
            push(t, g, 2, ids)
          end
        end
      end
    elseif t == M.CARD_TYPE.chain then
      -- 同长顺子：枚举起始权重
      local len = target.n
      for start = target.grade - len + 2, 14 - len + 1 do
        if start >= 3 then
          local ok = true
          local ids = {}
          for k = 0, len - 1 do
            local g = start + k
            if counts[g] < 1 then ok = false break end
            local one = first_ids(g, 1)
            ids[#ids + 1] = one[1]
          end
          if ok then push(t, start + len - 1, len, ids) end
        end
      end
    elseif t == M.CARD_TYPE.pair_chain then
      local len = target.n
      for start = target.grade - len + 2, 14 - len + 1 do
        if start >= 3 then
          local ok = true
          local ids = {}
          for k = 0, len - 1 do
            local g = start + k
            if counts[g] < 2 then ok = false break end
            local pair_ids = first_ids(g, 2)
            ids[#ids + 1] = pair_ids[1]
            ids[#ids + 1] = pair_ids[2]
          end
          if ok then push(t, start + len - 1, len, ids) end
        end
      end
    elseif t == M.CARD_TYPE.trio_chain then
      local len = target.n
      for start = target.grade - len + 2, 14 - len + 1 do
        if start >= 3 then
          local ok = true
          local ids = {}
          for k = 0, len - 1 do
            local g = start + k
            if counts[g] < 3 then ok = false break end
            local trio_ids = first_ids(g, 3)
            for _, id in ipairs(trio_ids) do ids[#ids + 1] = id end
          end
          if ok then push(t, start + len - 1, len, ids) end
        end
      end
    elseif t == M.CARD_TYPE.trio_solo_chain or t == M.CARD_TYPE.trio_pair_chain then
      local len = target.n
      for start = target.grade - len + 2, 14 - len + 1 do
        if start >= 3 then
          local main, ok = {}, true
          for k = 0, len - 1 do
            local grade = start + k
            if counts[grade] < 3 then ok = false break end
            for _, id in ipairs(first_ids(grade, 3)) do main[#main + 1] = id end
          end
          if ok then
            local pool = M.remove(cards, main)
            local pool_counts = M.count_grades(pool)
            local wings = {}
            if t == M.CARD_TYPE.trio_pair_chain then
              for grade = 3, 15 do
                if #wings < len * 2 and pool_counts[grade] >= 2 then
                  for _, id in ipairs(M.first_ids(pool, grade, 2)) do wings[#wings + 1] = id end
                end
              end
            else
              -- 单翅先每个点数取一张，再取第二张，避免无意组成另一组三张。
              for layer = 1, 2 do
                for grade = 3, 17 do
                  if #wings < len and pool_counts[grade] >= layer then
                    local ids = M.first_ids(pool, grade, layer)
                    wings[#wings + 1] = ids[layer]
                  end
                end
              end
            end
            local needed = t == M.CARD_TYPE.trio_pair_chain and len * 2 or len
            if #wings == needed then
              for _, id in ipairs(wings) do main[#main + 1] = id end
              push_checked(main)
            end
          end
        end
      end
    elseif t == M.CARD_TYPE.four_two_solo or t == M.CARD_TYPE.four_two_pair then
      for grade = target.grade + 1, 15 do
        if counts[grade] >= 4 then
          local main = first_ids(grade, 4)
          local pool = M.remove(cards, main)
          local pool_counts = M.count_grades(pool)
          local wings = {}
          local each = t == M.CARD_TYPE.four_two_pair and 2 or 1
          for wing_grade = 3, 17 do
            if wing_grade ~= grade and #wings < each * 2 and pool_counts[wing_grade] >= each then
              for _, id in ipairs(M.first_ids(pool, wing_grade, each)) do wings[#wings + 1] = id end
            end
          end
          if #wings == each * 2 then
            for _, id in ipairs(wings) do main[#main + 1] = id end
            push_checked(main)
          end
        end
      end
    end
  end

  if target.t ~= M.CARD_TYPE.rocket then
    if target.t ~= M.CARD_TYPE.bomb then
      same_type_greater()
    end
    -- 炸弹兜底
    for g = 3, 15 do
      if target.t ~= M.CARD_TYPE.bomb or g > target.grade then
        if counts[g] >= 4 then push(M.CARD_TYPE.bomb, g, 4, first_ids(g, 4)) end
      end
    end
    -- 王炸兜底
    if counts[16] >= 1 and counts[17] >= 1 then
      push(M.CARD_TYPE.rocket, 17, 2, { 53, 54 })
    end
  end
  return results
end

-- 找附件（单牌/对子）：从 cards 中找 count 张不在主体 ids 中的同权牌
function M.find_attachment(cards, main_ids, count)
  local pool = M.remove(cards, main_ids)
  local counts = M.count_grades(pool)
  local want = count == 2 and 2 or 1
  for g = 3, 17 do
    if counts[g] >= want then
      local got = 0
      local ids = {}
      for _, id in ipairs(pool) do
        if GRADE[id] == g and got < want then
          ids[#ids + 1] = id got = got + 1
        end
      end
      if #ids >= want then return ids end
    end
  end
  return nil
end

return M
