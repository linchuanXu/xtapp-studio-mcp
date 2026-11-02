-- 少牌残局的有限搜索。只搜索自己的牌型拆分，并结合公开剩余张数判断紧迫性。

local Rules = require("domain.doudizhu_rules")
local Evaluator = require("domain.doudizhu_hand_evaluator")
local M = {}

function M.adjustment(hand, candidate, view, profile, memo, budget)
  if profile.search_depth <= 0 or profile.endgame_node_limit <= 0 or #hand > profile.endgame_trigger then return 0 end
  if budget and budget.exhausted then return 0 end
  local remaining = Rules.remove(hand, candidate.cards)
  if #remaining == 0 then return 100000 end
  local distance = Evaluator.finish_distance(remaining, profile.search_depth - 1, memo or {}, budget)
  local score = (8 - math.min(8, distance)) * 70
  local nearest = 99
  for index, player in ipairs(view.players or {}) do
    if index ~= view.self_index then nearest = math.min(nearest, player.remaining or 99) end
  end
  if nearest <= 2 then score = score + #candidate.cards * 12 end
  return score
end

return M
