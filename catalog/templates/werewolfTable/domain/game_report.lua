-- End-of-game-only recap.  It is deliberately built after a winner exists:
-- unlike the public evidence ledger, this report may name the true role of
-- a voted player because the result screen has already revealed the table.

local Roles = require("domain.roles")

local M = {}

local function name_of(s, id)
  for _, person in ipairs(s.roster) do if person.id == id then return person.name end end
  return "未知"
end

function M.build(s)
  local questions, stances, votes, correct_votes = 0, 0, 0, 0
  local key_vote
  for _, event in ipairs((s.evidence and s.evidence.events) or {}) do
    if event.actor == "you" then
      if event.kind == "question" then questions = questions + 1 end
      if event.kind == "stance" or event.kind == "stance_change" then stances = stances + 1 end
      if event.kind == "ballot" then
        votes = votes + 1
        if s.roles[event.target] and Roles.is_wolf(s.roles[event.target]) then correct_votes = correct_votes + 1 end
      end
    end
    if event.kind == "death" and event.target == "vote" then key_vote = event end
  end
  local role = Roles.name(s.roles.you)
  local player_team = Roles.is_wolf(s.roles.you) and "wolf" or "village"
  local won = player_team == s.winner
  local turning = key_vote and ("第" .. tostring(key_vote.day) .. "天放逐了" .. name_of(s, key_vote.actor) .. "。") or "胜负由夜晚结算决定。"
  return {
    won = won, role = role, votes = votes, correct_votes = correct_votes,
    questions = questions, stances = stances, turning = turning,
    lines = {
      role .. (won and "获胜" or "失利") .. " · 票" .. tostring(votes) .. "中狼" .. tostring(correct_votes) .. "。",
      "站边" .. tostring(stances) .. " · 追问" .. tostring(questions) .. " · " .. turning,
    },
  }
end

return M
