-- AI consumes only an information-safe player view plus its legal action list.

local M = {}

local function score(action, view)
  if action.type == "end_turn" then return -100 end
  local hand = view.zones["p" .. tostring(action.actor) .. "_hand"]
  for _, card in ipairs(hand and hand.cards or {}) do
    if card.id == action.card_id then
      local p = card.presentation or {}
      if p.kind == "attack" then return 100 + (p.amount or 0) * 10 - (p.cost or 0) end
      if p.kind == "draw" then return 60 - (p.cost or 0) end
      if p.kind == "guard" then return 40 + (p.amount or 0) - (p.cost or 0) end
    end
  end
  return 0
end

function M.choose(view)
  local best, best_score = nil, -1000
  for _, action in ipairs(view.actions or {}) do
    local value = score(action, view)
    if value > best_score then best, best_score = action, value end
  end
  return best
end

return M
