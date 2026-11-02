-- 单机欢乐豆账户：只持久化真人余额；AI 的输赢仅用于本局结算展示。
local M = {}

M.STARTING_BALANCE = 1200
M.BASE_STAKE = 20
M.RELIEF_THRESHOLD = 20
M.RELIEF_TARGETS = { 300, 180, 100 }
M.STREAK_MILESTONES = { [3] = 20, [5] = 40, [8] = 80 }

local function difficulty_stat(value)
  value = value or {}
  return {
    games = math.max(0, math.floor(tonumber(value.games) or 0)),
    wins = math.max(0, math.floor(tonumber(value.wins) or 0)),
    net = math.floor(tonumber(value.net) or 0),
  }
end

function M.account(value)
  value = value or {}
  local old_stats = value.difficulty_stats or {}
  return {
    balance = math.max(0, math.floor(tonumber(value.balance) or M.STARTING_BALANCE)),
    total_games = math.max(0, math.floor(tonumber(value.total_games) or 0)),
    wins = math.max(0, math.floor(tonumber(value.wins) or 0)),
    losses = math.max(0, math.floor(tonumber(value.losses) or 0)),
    relief_uses = math.max(0, math.floor(tonumber(value.relief_uses) or 0)),
    streak = math.max(0, math.floor(tonumber(value.streak) or 0)),
    best_streak = math.max(0, math.floor(tonumber(value.best_streak) or 0)),
    bonus_beans = math.max(0, math.floor(tonumber(value.bonus_beans) or 0)),
    difficulty_stats = {
      novice = difficulty_stat(old_stats.novice),
      casual = difficulty_stat(old_stats.casual),
      challenge = difficulty_stat(old_stats.challenge),
    },
  }
end

function M.amount(game)
  return M.BASE_STAKE * math.max(1, math.floor(tonumber(game and game.multiplier) or 1))
end

-- round_key 写在牌局对象中，旧存档也能自然获得一次性结算保护。
function M.settle(account, game, human_index)
  account = M.account(account)
  if not game or game.phase ~= "over" or not game.winner or not game.landlord then return account, nil end
  if game.economy_settlement then return account, game.economy_settlement end

  local stake = M.amount(game)
  local won = (game.winner == game.landlord) == (human_index == game.landlord)
  local base_delta = human_index == game.landlord and stake * 2 or stake
  local bonus = 0
  if won then
    account.streak = account.streak + 1
    account.best_streak = math.max(account.best_streak, account.streak)
    -- 连胜奖励只在 3/5/8 连胜里程碑发放。春天已通过规则倍率结算，
    -- 不再额外叠一份固定奖励，避免同一事件重复通胀。
    bonus = M.STREAK_MILESTONES[account.streak] or 0
    account.bonus_beans = account.bonus_beans + bonus
  else
    account.streak = 0
  end
  local delta = base_delta + (won and bonus or 0)
  if not won then delta = -math.min(account.balance, base_delta) end

  account.balance = account.balance + delta
  account.total_games = account.total_games + 1
  if won then account.wins = account.wins + 1 else account.losses = account.losses + 1 end

  local difficulty = game.difficulty
  local difficulty_stat_value = account.difficulty_stats[difficulty]
  if difficulty_stat_value then
    difficulty_stat_value.games = difficulty_stat_value.games + 1
    if won then difficulty_stat_value.wins = difficulty_stat_value.wins + 1 end
    difficulty_stat_value.net = difficulty_stat_value.net + delta
  end

  local relief = 0
  local relief_target = M.RELIEF_TARGETS[account.relief_uses + 1]
  if account.balance <= M.RELIEF_THRESHOLD and relief_target then
    relief = relief_target - account.balance
    account.balance = relief_target
    account.relief_uses = account.relief_uses + 1
  end
  local settlement = {
    delta = delta, base_delta = base_delta, bonus = won and bonus or 0,
    stake = stake, balance = account.balance, won = won, relief = relief,
    streak = account.streak,
  }
  game.economy_settlement = settlement
  return account, settlement
end

return M
