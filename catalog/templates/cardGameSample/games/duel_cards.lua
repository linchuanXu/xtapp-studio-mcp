-- Content belongs to the sample game, not the card engine.

local M = {}

M.definitions = {
  strike = { name = "击", cost = 1, kind = "attack", amount = 3, mark = "刃" },
  guard = { name = "守", cost = 1, kind = "guard", amount = 3, mark = "盾" },
  focus = { name = "观", cost = 1, kind = "draw", amount = 1, mark = "卷" },
  heavy = { name = "破", cost = 2, kind = "attack", amount = 6, mark = "雷" },
}

M.deck = {
  "strike", "strike", "strike", "strike",
  "guard", "guard", "guard",
  "focus", "focus",
  "heavy", "heavy", "heavy",
}

function M.get(definition_id)
  return M.definitions[definition_id]
end

return M
