-- 身份目标与农民协作，只依赖公开视图。

local M = {}

function M.context(view)
  local self_index = view.self_index
  local landlord = view.landlord
  local self_is_landlord = self_index == landlord
  local teammate = nil
  if landlord and not self_is_landlord then
    for index = 1, 3 do if index ~= landlord and index ~= self_index then teammate = index end end
  end
  local landlord_remaining = landlord and view.players[landlord] and view.players[landlord].remaining or 99
  local teammate_remaining = teammate and view.players[teammate] and view.players[teammate].remaining or 99
  local opponent_remaining = landlord_remaining
  local last_from_opponent = landlord ~= nil and view.last_player == landlord
  if self_is_landlord then
    opponent_remaining = 99
    for index = 1, 3 do
      if index ~= landlord and view.players[index] then
        opponent_remaining = math.min(opponent_remaining, view.players[index].remaining or 99)
      end
    end
    last_from_opponent = view.last_player ~= nil and view.last_player ~= landlord
  end
  return {
    self_is_landlord = self_is_landlord,
    teammate = teammate,
    teammate_remaining = teammate_remaining,
    landlord_remaining = landlord_remaining,
    opponent_remaining = opponent_remaining,
    last_from_teammate = teammate ~= nil and view.last_player == teammate,
    last_from_landlord = landlord ~= nil and view.last_player == landlord,
    last_from_opponent = last_from_opponent,
  }
end

function M.should_yield(view, profile)
  local tc = M.context(view)
  if not profile.coordinates or not tc.last_from_teammate then return false end
  return tc.teammate_remaining <= profile.partner_yield_count
end

function M.must_block(view)
  local tc = M.context(view)
  -- 无论自己是地主还是农民，只要对方阵营仅剩三张，就不能再按普通
  -- “保牌型”逻辑放行。旧实现只会阻断地主，AI 地主会眼看真人农民走完。
  return tc.last_from_opponent and tc.opponent_remaining <= 3
end

function M.lead_adjustment(view, candidate)
  local tc = M.context(view)
  if tc.self_is_landlord then
    local adjustment = #candidate.cards * 3
    if tc.opponent_remaining <= 2 then
      -- 农民快走完时，地主不再机械喂低单：优先多张牌；若只能出
      -- 单牌，则宁可用较大的牌卡住“总按提示出最小单张”的玩家。
      if #candidate.cards > 1 then
        adjustment = adjustment + 100 + #candidate.cards * 20
      elseif candidate.type.t == "single" then
        adjustment = adjustment + (candidate.type.grade or 0) * 9 - 90
      end
    end
    return adjustment
  end
  if tc.landlord_remaining == 1 and candidate.type.t == "single" then
    -- 地主仅剩一张时，农民应打出较高单牌阻断，而不是机械喂小牌。
    return (candidate.type.grade or 0) * 6
  end
  if tc.teammate_remaining <= 2 and candidate.type.t == "single" then
    -- 队友快走完时优先喂容易接的小单张。
    return -(candidate.type.grade or 0) * 3
  end
  return 0
end

return M
