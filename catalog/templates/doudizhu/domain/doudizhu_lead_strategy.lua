-- 首出策略：候选评分，不推进游戏状态。

local Rules = require("domain.doudizhu_rules")
local Evaluator = require("domain.doudizhu_hand_evaluator")
local Team = require("domain.doudizhu_team_strategy")
local Endgame = require("domain.doudizhu_endgame_strategy")
local M = {}

local function score_candidate(hand, candidate, view, profile, memo, budget)
  local remaining = Rules.remove(hand, candidate.cards)
  if #remaining == 0 then return 100000, "一手走完" end
  local quality = Evaluator.analyze(remaining)
  local split = Evaluator.split_cost(hand, candidate.cards)
  local power = Evaluator.power_cost(candidate.cards)
  local score = #candidate.cards * 24 - quality.turns * 110 - quality.singles * 18
  score = score - split * profile.split_penalty - power * profile.control_penalty
  if candidate.type.t == Rules.CARD_TYPE.bomb or candidate.type.t == Rules.CARD_TYPE.rocket then
    score = score - profile.bomb_penalty
  end
  score = score + Team.lead_adjustment(view, candidate)
  score = score + Endgame.adjustment(hand, candidate, view, profile, memo, budget)
  return score, "预计剩余" .. tostring(quality.turns) .. "手"
end

function M.choose(hand, view, profile, checkpoint)
  local candidates = Evaluator.enumerate_leads(hand, {
    checkpoint = checkpoint,
    max_candidates = profile.lead_enumeration_limit,
  })
  local best, best_score, best_reason = nil, -1000000, "无牌可出"
  local endgame_memo = {}
  local endgame_budget = {
    checkpoint = checkpoint,
    max_nodes = profile.endgame_node_limit,
    max_candidates = 36,
    branch_limit = 12,
  }
  local limit = profile.lead_candidate_limit and math.min(#candidates, profile.lead_candidate_limit) or #candidates
  for index = 1, limit do
    if checkpoint and checkpoint() == false then break end
    local candidate = candidates[index]
    local score, reason = score_candidate(hand, candidate, view, profile, endgame_memo, endgame_budget)
    if score > best_score then best, best_score, best_reason = candidate, score, reason end
    if endgame_budget.exhausted then break end
  end
  if not best and candidates[1] then
    best, best_reason = candidates[1], "决策预算到期 · 使用首个合法牌型"
  end
  return best and best.cards or nil, { score = best_score, reason = best_reason, candidate_count = #candidates }
end

return M
