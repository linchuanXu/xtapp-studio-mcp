-- Canonical role metadata. Rule code uses alignment and ability ids instead
-- of scattering role-name checks through phases or view code.

local M = {}

M.definitions = {
  wolf = { name = "狼人", alignment = "wolf", night = "wolf_kill", reveal = "狼人" },
  seer = { name = "预言家", alignment = "village", night = "seer_check", reveal = "预言家" },
  witch = { name = "女巫", alignment = "village", night = "witch_act", reveal = "女巫" },
  hunter = { name = "猎人", alignment = "village", death = "hunter_shot", reveal = "猎人" },
  villager = { name = "平民", alignment = "village", reveal = "平民" },
}

function M.get(role)
  assert(M.definitions[role], "unknown werewolf role: " .. tostring(role))
  return M.definitions[role]
end

function M.is_wolf(role) return M.get(role).alignment == "wolf" end
function M.is_village(role) return M.get(role).alignment == "village" end
function M.name(role) return M.get(role).name end

return M
