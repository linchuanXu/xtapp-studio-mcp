-- 斗地主 AI 难度配置。
-- 所有档位差异集中在这里，UI 与规则引擎不散落难度分支。

local M = {}

M.DEFAULT = "casual"
M.ORDER = { "novice", "casual", "challenge" }

local PROFILES = {
  novice = {
    id = "novice", label = "新手", marker = "入门",
    description = "快速整理牌型，适合熟悉规则",
    bid_structure_weight = 1,
    split_penalty = 22,
    control_penalty = 12,
    bomb_penalty = 120,
    partner_yield_count = 2,
    endgame_trigger = 0,
    search_depth = 0,
    remembers_cards = false,
    coordinates = false,
    follow_pass_threshold = 10,
    lead_candidate_limit = 14,
    lead_enumeration_limit = 48,
    follow_candidate_limit = 16,
    endgame_node_limit = 0,
  },
  casual = {
    id = "casual", label = "休闲", marker = "推荐",
    description = "会记牌、会逼牌",
    bid_structure_weight = 1,
    split_penalty = 28,
    control_penalty = 6,
    bomb_penalty = 72,
    partner_yield_count = 3,
    endgame_trigger = 10,
    search_depth = 3,
    remembers_cards = true,
    coordinates = true,
    follow_pass_threshold = 0,
    lead_candidate_limit = 24,
    lead_enumeration_limit = 96,
    follow_candidate_limit = 28,
    endgame_node_limit = 220,
  },
  challenge = {
    id = "challenge", label = "挑战", marker = "进阶",
    description = "会记牌、会算残局",
    bid_structure_weight = 2,
    split_penalty = 30,
    control_penalty = 3,
    bomb_penalty = 40,
    partner_yield_count = 5,
    endgame_trigger = 13,
    search_depth = 5,
    remembers_cards = true,
    coordinates = true,
    follow_pass_threshold = -20,
    lead_candidate_limit = 36,
    lead_enumeration_limit = 144,
    follow_candidate_limit = 36,
    -- 此预算覆盖一次决策的所有残局候选，不是每个候选各自一棵树。
    endgame_node_limit = 420,
  },
}

function M.normalize(value)
  return PROFILES[value] and value or M.DEFAULT
end

function M.get(value)
  return PROFILES[M.normalize(value)]
end

function M.list()
  local out = {}
  for _, id in ipairs(M.ORDER) do out[#out + 1] = PROFILES[id] end
  return out
end

return M
