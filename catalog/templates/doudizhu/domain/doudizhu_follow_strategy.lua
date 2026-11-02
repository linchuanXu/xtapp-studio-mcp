-- 跟牌策略：压制、让牌、炸弹使用和公开记牌。

local Rules = require("domain.doudizhu_rules")
local PublicView = require("domain.doudizhu_public_view")
local Evaluator = require("domain.doudizhu_hand_evaluator")
local Team = require("domain.doudizhu_team_strategy")
local Endgame = require("domain.doudizhu_endgame_strategy")
local M = {}

local function score_option(hand, option, view, profile, memo, budget)
  local remaining = Rules.remove(hand, option.cards)
  if #remaining == 0 then return 100000, "一手走完" end
  local before = Evaluator.analyze(hand)
  local quality = Evaluator.analyze(remaining)
  local split = Evaluator.split_cost(hand, option.cards)
  local power = Evaluator.power_cost(option.cards)
  -- 与“不出”相比评估收益，0 就是保留当前手牌。这样 AI 会真的判断
  -- “该压还是该放”，而不是只要存在合法牌就机械打出。
  local score = (before.turns - quality.turns) * 115 + (before.singles - quality.singles) * 20
  score = score - split * profile.split_penalty - power * profile.control_penalty
  local is_bomb = option.type.t == Rules.CARD_TYPE.bomb or option.type.t == Rules.CARD_TYPE.rocket
  if is_bomb then score = score - profile.bomb_penalty end
  if option.type.t == view.last_type.t then score = score + 80 end
  if Team.must_block(view) then score = score + #option.cards * 10 + (is_bomb and 150 or 0) end
  if profile.remembers_cards and PublicView.unseen_higher_count(view, option.type.grade or 0) == 0 then
    score = score + 45 -- 公开信息确认它是当前控牌。
  end
  score = score + Endgame.adjustment(hand, option, view, profile, memo, budget)
  return score, Team.must_block(view) and "阻断地主" or (is_bomb and "夺回牌权" or "保留牌型")
end

function M.choose(hand, view, profile, checkpoint)
  local options = Rules.greater_cards(hand, view.last_type)
  if #options == 0 then return nil, { reason = "无牌可压", candidate_count = 0 } end
  if Team.should_yield(view, profile) and not Team.must_block(view) then
    return nil, { reason = "让队友先走", candidate_count = #options }
  end
  if profile.id == "novice" then
    table.sort(options, function(a, b)
      local same_a, same_b = a.type.t == view.last_type.t, b.type.t == view.last_type.t
      if same_a ~= same_b then return same_a end
      return (a.type.grade or 0) < (b.type.grade or 0)
    end)
    return options[1].cards, { reason = "最小合法压制", candidate_count = #options }
  end
  local best, best_score, best_reason = nil, -1000000, "不出"
  local endgame_memo = {}
  local endgame_budget = {
    checkpoint = checkpoint,
    max_nodes = profile.endgame_node_limit,
    max_candidates = 36,
    branch_limit = 12,
  }
  local limit = math.min(#options, profile.follow_candidate_limit or 16)
  for index = 1, limit do
    if checkpoint and checkpoint() == false then break end
    local option = options[index]
    local score, reason = score_option(hand, option, view, profile, endgame_memo, endgame_budget)
    if score > best_score then best, best_score, best_reason = option, score, reason end
    if endgame_budget.exhausted then break end
  end
  if not best then
    best, best_reason = options[1], "决策预算到期 · 使用首个合法压制"
    best_score = (profile.follow_pass_threshold or 20) + 1
  end
  if best_score <= (profile.follow_pass_threshold or 20) and not Team.must_block(view) then
    return nil, { score = best_score, reason = "保留完整牌型", candidate_count = #options }
  end
  return best and best.cards or nil, { score = best_score, reason = best_reason, candidate_count = #options }
end

return M
