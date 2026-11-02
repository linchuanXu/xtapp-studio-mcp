-- 果蔬消消乐关卡数据。这里只描述内容，不包含棋盘生成、消除或存档逻辑。
--
-- 坐标统一使用 1 起始的 { row, col }，左上角为 { 1, 1 }。
-- goals 支持 collect / score / ink / drop。为保持规则引擎接口稳定，ink 是“冰层”
-- 的内部类型名；locks、rocks、weeds、drops 分别描述锁链、石块、杂草和掉落篮子。
-- stars.two / stars.three 是二、三星分数线；完成全部目标即获得一星。
local M = {}

M.symbols = {
  { id = 1, key = "apple", name = "苹果" },
  { id = 2, key = "grape", name = "葡萄" },
  { id = 3, key = "cherry", name = "樱桃" },
  { id = 4, key = "carrot", name = "胡萝卜" },
  { id = 5, key = "corn", name = "玉米" },
  { id = 6, key = "mushroom", name = "蘑菇" },
}

M.goal_labels = { collect = "收集", score = "得分", ink = "清除冰层", drop = "送出菜篮" }
M.obstacle_labels = { ink = "冰层", locks = "锁链", rocks = "石块", weeds = "杂草" }

M.chapters = {
  { id = 1, name = "新手果园", subtitle = "交换果蔬，完成基础收集" },
  { id = 2, name = "丰收菜园", subtitle = "制造四连、五连和爆炸特效" },
  { id = 3, name = "农场障碍", subtitle = "解开锁链，敲碎石块，送出菜篮" },
  { id = 4, name = "杂草危机", subtitle = "赶在杂草蔓延前完成目标" },
  { id = 5, name = "丰收挑战", subtitle = "组合目标，挑战完整三消技巧" },
}

local function P(row, col, layers)
  local point = { row = row, col = col }
  if layers then point.layers = layers end
  return point
end

local function collect(kind, amount)
  return { type = "collect", kind = kind, amount = amount }
end

local function score(amount)
  return { type = "score", amount = amount }
end

local function ink(amount)
  return { type = "ink", amount = amount }
end

local function drop(amount)
  return { type = "drop", amount = amount }
end

local function L(id, name, moves, seed, symbols, goals, stars, options)
  options = options or {}
  return {
    id = id,
    chapter = math.floor((id - 1) / 6) + 1,
    chapter_level = (id - 1) % 6 + 1,
    name = name,
    board = { rows = 7, cols = 7, symbols = symbols },
    moves = moves,
    seed = seed,
    goals = goals,
    ink = options.ink or {},
    locks = options.locks or {},
    rocks = options.rocks or {},
    weeds = options.weeds or {},
    drops = options.drops or {},
    pressure = options.pressure,
    tools = options.tools or { hint = 1, shuffle = 1 },
    stars = stars,
    tutorial = options.tutorial,
  }
end

M.levels = {
  -- 第一章：基础交换、收集与冰层，每关只引入一件新事物。
  L(1, "收集苹果", 18, 11031, 5,
    { collect(1, 12) }, { two = 900, three = 1500 },
    { tutorial = true, tools = { hint = 2, shuffle = 1 } }),
  L(2, "苹果和胡萝卜", 20, 12047, 5,
    { collect(2, 10), collect(4, 10) }, { two = 1300, three = 2100 },
    { tutorial = "一关可以有多个收集目标，顶部会显示还差多少。", tools = { hint = 2, shuffle = 1 } }),
  L(3, "冲击高分", 20, 13063, 5,
    { score(1900) }, { two = 2400, three = 3300 },
    { tutorial = "连续消除会得到更多分数，试着提前准备下一次消除。", tools = { hint = 2, shuffle = 1 } }),
  L(4, "蘑菇登场", 22, 14071, 6,
    { collect(1, 12), collect(5, 12) }, { two = 1800, three = 2800 },
    { tutorial = "蘑菇加入棋盘。果蔬种类越多，越要提前安排下一步。" }),
  L(5, "打碎薄冰", 22, 15083, 6,
    { ink(6) }, { two = 1700, three = 2700 },
    { ink = { P(3, 3), P(3, 4), P(3, 5), P(5, 3), P(5, 4), P(5, 5) }, tutorial = "消除冰块里的果蔬，就能打碎一层冰。" }),
  L(6, "新手丰收", 24, 16091, 6,
    { collect(3, 14), score(2400), ink(4) }, { two = 3000, three = 4100 },
    { ink = { P(2, 2), P(2, 6), P(6, 2), P(6, 6) } }),

  -- 第二章：用目标与对称布局教学横竖四连、五连和 T/L 爆炸。
  L(7, "横向火箭", 24, 21019, 6,
    { collect(4, 20), ink(5) }, { two = 2300, three = 3400 },
    { ink = { P(4, 2), P(4, 3), P(4, 4), P(4, 5), P(4, 6) }, tutorial = "横着连成四个，会生成清除整行的横向火箭。" }),
  L(8, "纵向火箭", 25, 22027, 6,
    { collect(2, 15), collect(3, 15), ink(5) }, { two = 2800, three = 4000 },
    { ink = { P(2, 4), P(3, 4), P(4, 4), P(5, 4), P(6, 4) }, tutorial = "竖着连成四个，会生成清除整列的纵向火箭。" }),
  L(9, "彩虹果篮", 24, 23041, 6,
    { score(3600), ink(4) }, { two = 4300, three = 5600 },
    { ink = { P(3, 2), P(3, 6), P(5, 2), P(5, 6) }, tools = { hint = 1, shuffle = 0 }, tutorial = "连成五个会生成彩虹果篮，可一次收走同类果蔬。" }),
  L(10, "爆炸南瓜", 26, 24049, 6,
    { collect(6, 20), ink(8) }, { two = 3400, three = 4700 },
    { ink = { P(2, 2), P(2, 3), P(2, 5), P(2, 6), P(6, 2), P(6, 3), P(6, 5), P(6, 6) }, tutorial = "连成 T 形或 L 形，会生成能炸开周围果蔬的南瓜。" }),
  L(11, "特效接力", 25, 25057, 6,
    { collect(1, 12), collect(4, 12), collect(5, 12) }, { two = 3600, three = 5000 },
    { tools = { hint = 1, shuffle = 0 } }),
  L(12, "菜园烟花", 27, 26069, 6,
    { score(4400), ink(9) }, { two = 5100, three = 6500 },
    { ink = { P(3, 3), P(3, 4), P(3, 5), P(4, 3), P(4, 4), P(4, 5), P(5, 3), P(5, 4), P(5, 5) } }),

  -- 第三章：锁链固定果蔬，石块占格；随后加入需要落到底部的菜篮。
  L(13, "解开锁链", 25, 31013, 6,
    { ink(8) }, { two = 2600, three = 3900 },
    { ink = { P(2, 2), P(2, 3), P(2, 5), P(2, 6), P(6, 2), P(6, 3), P(6, 5), P(6, 6) }, locks = { P(4, 3), P(4, 5) }, tutorial = "消除被锁住的果蔬，就能打开锁链。" }),
  L(14, "双层锁链", 27, 32029, 6,
    { collect(3, 18), ink(10) }, { two = 3300, three = 4700 },
    { ink = { P(2, 2, 2), P(2, 6, 2), P(4, 2), P(4, 6), P(6, 2, 2), P(6, 6, 2) }, locks = { P(3, 4, 2), P(5, 4, 2) } }),
  L(15, "敲碎石块", 28, 33037, 6,
    { ink(16), score(3000) }, { two = 4000, three = 5400 },
    { ink = { P(2, 3), P(2, 4, 2), P(2, 5), P(3, 2), P(3, 6), P(4, 2, 2), P(4, 6, 2), P(5, 2), P(5, 6), P(6, 3), P(6, 4, 2), P(6, 5) }, rocks = { P(4, 4) } }),
  L(16, "石墙缺口", 28, 34051, 6,
    { collect(2, 18), collect(6, 18) }, { two = 3900, three = 5300 },
    { rocks = { P(3, 2), P(3, 4), P(3, 6), P(5, 2), P(5, 4), P(5, 6) }, tools = { hint = 1, shuffle = 0 } }),
  L(17, "第一只菜篮", 29, 35059, 6,
    { drop(1), ink(16), collect(5, 16) }, { two = 4400, three = 5900 },
    { drops = { P(1, 4) }, ink = { P(2, 4, 2), P(3, 3), P(3, 4), P(3, 5), P(4, 2, 2), P(4, 3), P(4, 5), P(4, 6, 2), P(5, 3), P(5, 4), P(5, 5), P(6, 4, 2) }, rocks = { P(2, 2), P(2, 6), P(6, 2), P(6, 6) }, tutorial = "消除菜篮下方的果蔬，把菜篮送到棋盘底部。" }),
  L(18, "农场运货", 30, 36073, 6,
    { ink(20), score(4200) }, { two = 5200, three = 6800 },
    { ink = { P(2, 2, 2), P(2, 3), P(2, 5), P(2, 6, 2), P(3, 2), P(3, 6), P(4, 2, 2), P(4, 6, 2), P(5, 2), P(5, 6), P(6, 2, 2), P(6, 3), P(6, 5), P(6, 6, 2) }, rocks = { P(3, 4), P(4, 4), P(5, 4) } }),

  -- 第四章：杂草会按回合蔓延，迫使玩家优先处理动态威胁。
  L(19, "杂草冒头", 24, 41017, 6,
    { drop(1) }, { two = 2700, three = 4000 },
    { drops = { P(1, 4) }, weeds = { P(4, 4) }, pressure = { type = "weeds", every = 3, max = 5 }, tutorial = "杂草每隔几步会向旁边蔓延，尽快在它周围完成消除。" }),
  L(20, "两片杂草", 27, 42031, 6,
    { drop(2), collect(2, 14) }, { two = 3700, three = 5100 },
    { drops = { P(1, 2), P(1, 6) }, weeds = { P(4, 3), P(4, 5) }, pressure = { type = "weeds", every = 3, max = 7 } }),
  L(21, "冰块和杂草", 28, 43043, 6,
    { drop(2), ink(10) }, { two = 4100, three = 5600 },
    { drops = { P(1, 3), P(1, 5) }, ink = { P(3, 2), P(3, 3, 2), P(3, 5, 2), P(3, 6), P(6, 2), P(6, 3), P(6, 5), P(6, 6) }, weeds = { P(4, 4) }, pressure = { type = "weeds", every = 2, max = 8 } }),
  L(22, "菜篮抢运", 30, 44053, 6,
    { drop(3), score(3800) }, { two = 5000, three = 6500 },
    { drops = { P(1, 2), P(1, 4), P(1, 6) }, weeds = { P(3, 3), P(3, 5), P(5, 3), P(5, 5) }, pressure = { type = "weeds", every = 3, max = 9 } }),
  L(23, "杂草封路", 31, 45061, 6,
    { drop(3), collect(4, 18), ink(6) }, { two = 4900, three = 6500 },
    { drops = { P(1, 2), P(1, 4), P(1, 6) }, ink = { P(4, 1), P(4, 2), P(4, 3), P(4, 5), P(4, 6), P(4, 7) }, weeds = { P(3, 3), P(3, 5), P(5, 3), P(5, 5) }, pressure = { type = "weeds", every = 2, max = 10 }, tools = { hint = 1, shuffle = 0 } }),
  L(24, "除草大作战", 32, 46067, 6,
    { drop(4), ink(12) }, { two = 5600, three = 7300 },
    { drops = { P(1, 1), P(1, 3), P(1, 5), P(1, 7) }, ink = { P(3, 1), P(3, 3, 2), P(3, 5, 2), P(3, 7), P(5, 1), P(5, 3, 2), P(5, 5, 2), P(5, 7) }, weeds = { P(4, 2), P(4, 4), P(4, 6) }, pressure = { type = "weeds", every = 2, max = 12 } }),

  -- 第五章：复合目标终章；步数略放宽，但三星线要求更高的连锁效率。
  L(25, "果蔬拼盘", 30, 51025, 6,
    { collect(1, 18), collect(2, 18), ink(8) }, { two = 5000, three = 6600 },
    { ink = { P(2, 2), P(2, 6), P(3, 3), P(3, 5), P(5, 3), P(5, 5), P(6, 2), P(6, 6) }, rocks = { P(4, 4) } }),
  L(26, "满筐丰收", 31, 52033, 6,
    { collect(4, 18), collect(5, 18), score(4300) }, { two = 5500, three = 7100 },
    { rocks = { P(3, 2), P(3, 6), P(5, 2), P(5, 6) }, tools = { hint = 1, shuffle = 0 } }),
  L(27, "冷库运货", 32, 53047, 6,
    { drop(2), ink(16), score(4000) }, { two = 5800, three = 7500 },
    { drops = { P(1, 3), P(1, 5) }, ink = { P(2, 2, 2), P(2, 6, 2), P(3, 3), P(3, 5), P(4, 2, 2), P(4, 6, 2), P(5, 3), P(5, 5), P(6, 2, 2), P(6, 6, 2) }, rocks = { P(3, 4), P(5, 4) } }),
  L(28, "六种都要", 32, 54059, 6,
    { collect(1, 10), collect(2, 10), collect(3, 10), collect(4, 10), collect(5, 10), collect(6, 10) }, { two = 6200, three = 8000 },
    { tools = { hint = 0, shuffle = 1 }, tutorial = "六种果蔬都要收集，优先制造能带动多种果蔬的连锁。" }),
  L(29, "农场大订单", 34, 55063, 6,
    { drop(3), ink(20), collect(6, 16) }, { two = 6600, three = 8500 },
    { drops = { P(1, 2), P(1, 4), P(1, 6) }, ink = { P(2, 2, 2), P(2, 3), P(2, 5), P(2, 6, 2), P(3, 2), P(3, 6), P(4, 2, 2), P(4, 6, 2), P(5, 2), P(5, 6), P(6, 2, 2), P(6, 3), P(6, 5), P(6, 6, 2) }, rocks = { P(3, 3), P(3, 5), P(5, 3), P(5, 5) }, tools = { hint = 0, shuffle = 1 } }),
  L(30, "超级丰收日", 36, 56081, 6,
    { drop(4), ink(22), score(6200) }, { two = 7800, three = 9800 },
    { drops = { P(1, 1), P(1, 3), P(1, 5), P(1, 7) }, ink = { P(2, 2, 2), P(2, 3), P(2, 5), P(2, 6, 2), P(3, 2), P(3, 6), P(4, 2, 2), P(4, 3), P(4, 5), P(4, 6, 2), P(5, 2), P(5, 6), P(6, 2, 2), P(6, 3), P(6, 5), P(6, 6, 2) }, rocks = { P(3, 3), P(3, 4), P(3, 5), P(5, 3), P(5, 4), P(5, 5) }, tools = { hint = 0, shuffle = 1 } }),
}

function M.get(id)
  return M.levels[id]
end

return M
