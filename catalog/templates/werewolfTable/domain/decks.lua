-- Curated tables, not unconstrained random shuffles. Each deck has a solvable
-- public-information trail and gives the lone player a different role.

local M = {}

M.roster = {
  { id = "you", name = "你", seat = 1, style = "player" },
  { id = "lin", name = "林澈", seat = 2, style = "record" },
  { id = "zhou", name = "周岚", seat = 3, style = "pressure" },
  { id = "xu", name = "许闻", seat = 4, style = "careful" },
  { id = "chen", name = "陈珂", seat = 5, style = "emotional" },
  { id = "shen", name = "沈舟", seat = 6, style = "logic" },
  { id = "tang", name = "唐梨", seat = 7, style = "probe" },
  { id = "gu", name = "顾言", seat = 8, style = "protect" },
  { id = "ma", name = "马会", seat = 9, style = "direct" },
}

M.order = { "mirror", "embers", "still_night", "last_bullet", "moonlit" }
M.definitions = {
  mirror = {
    id = "mirror", name = "镜面局", player_role = "seer",
    roles = { you = "seer", lin = "wolf", zhou = "witch", xu = "villager", chen = "wolf", shen = "hunter", tang = "villager", gu = "wolf", ma = "villager" },
    wolf_plan = { "xu", "ma", "shen" },
    sheriff_candidates = { "lin", "shen" },
    wolf_style = "claim",
    premise = "有人在首日急着替你安排身份。",
  },
  embers = {
    id = "embers", name = "余烬局", player_role = "villager",
    roles = { you = "villager", lin = "seer", zhou = "wolf", xu = "witch", chen = "villager", shen = "wolf", tang = "hunter", gu = "villager", ma = "wolf" },
    wolf_plan = { "lin", "tang", "xu" },
    sheriff_candidates = { "lin", "shen" },
    wolf_style = "split",
    premise = "两名狼人把矛盾留在票型里。",
  },
  still_night = {
    id = "still_night", name = "静夜局", player_role = "witch",
    roles = { you = "witch", lin = "wolf", zhou = "seer", xu = "villager", chen = "wolf", shen = "villager", tang = "hunter", gu = "wolf", ma = "villager" },
    wolf_plan = { "zhou", "tang", "ma" },
    sheriff_candidates = { "zhou", "lin" },
    wolf_style = "quiet",
    premise = "夜里留下的人，比死去的人更值得问。",
  },
  last_bullet = {
    id = "last_bullet", name = "最后一弹", player_role = "hunter",
    roles = { you = "hunter", lin = "wolf", zhou = "seer", xu = "witch", chen = "wolf", shen = "villager", tang = "wolf", gu = "villager", ma = "villager" },
    -- 首夜会被 NPC 女巫救下；第二夜再次落刀，保证猎人局能自然
    -- 进入“出局后开枪”的真实规则，而不是只在测试中出现。
    wolf_plan = { "you", "you", "zhou", "ma" },
    sheriff_candidates = { "zhou", "lin" },
    wolf_style = "pressure",
    premise = "你手里最后一颗子弹，只能在出局时使用。",
  },
  moonlit = {
    id = "moonlit", name = "月蚀局", player_role = "wolf",
    roles = { you = "wolf", lin = "seer", zhou = "witch", xu = "wolf", chen = "villager", shen = "hunter", tang = "wolf", gu = "villager", ma = "villager" },
    wolf_plan = { "lin", "chen", "shen" },
    sheriff_candidates = { "lin", "shen" },
    wolf_style = "split",
    premise = "你知道两名同伴，却要把每一次白天发言伪装成猜测。",
  },
}

function M.get(id)
  assert(M.definitions[id], "unknown werewolf deck: " .. tostring(id))
  return M.definitions[id]
end

return M
