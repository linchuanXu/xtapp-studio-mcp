-- AI 可见信息边界。
-- 策略层只能得到当前 AI 的手牌与牌桌公开信息，绝不暴露其他玩家手牌。

local Rules = require("domain.doudizhu_rules")

local M = {}

local function copy_list(values)
  local out = {}
  for i, value in ipairs(values or {}) do out[i] = value end
  return out
end

local function copy_type(value)
  if not value then return nil end
  return { t = value.t, grade = value.grade, n = value.n }
end

local function copy_action(value)
  return {
    actor = value.actor,
    action = value.action,
    cards = copy_list(value.cards),
    type = copy_type(value.type),
  }
end

function M.build(state, self_index)
  local players = {}
  for index, player in ipairs(state.players or {}) do
    players[index] = {
      index = index,
      remaining = #(player.cards or {}),
      role = player.role,
      is_human = player.is_human == true,
    }
  end
  local trick_actions, history = {}, {}
  for i, action in ipairs(state.trick_actions or {}) do trick_actions[i] = copy_action(action) end
  for i, action in ipairs(state.public_history or {}) do history[i] = copy_action(action) end
  local played_counts = {}
  for grade = 3, 17 do played_counts[grade] = (state.played_counts or {})[grade] or 0 end
  return {
    self_index = self_index,
    own_cards = copy_list(state.players[self_index] and state.players[self_index].cards or {}),
    phase = state.phase,
    current = state.current,
    landlord = state.landlord,
    difficulty = state.difficulty,
    players = players,
    last_type = copy_type(state.last_type),
    last_player = state.last_player,
    pass_count = state.pass_count or 0,
    multiplier = state.multiplier or 1,
    bottom_cards = copy_list(state.bottom_cards),
    trick_actions = trick_actions,
    public_history = history,
    played_counts = played_counts,
  }
end

-- 公开推断：同点数尚未出现、且不在自己手里的牌有多少张。
-- 这只是记牌，不会推断某张牌具体在谁手中。
function M.unseen_count(view, grade)
  local total = grade >= 16 and 1 or 4
  local own = Rules.count_grades(view.own_cards or {})[grade] or 0
  local played = (view.played_counts or {})[grade] or 0
  return math.max(0, total - own - played)
end

function M.unseen_higher_count(view, grade)
  local total = 0
  for current = grade + 1, 17 do total = total + M.unseen_count(view, current) end
  return total
end

return M
