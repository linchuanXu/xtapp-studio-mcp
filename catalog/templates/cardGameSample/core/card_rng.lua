-- Deterministic Park-Miller RNG. The engine stores the seed in match state so
-- tests, replays and resumed games all see the same chance outcomes.

local M = {}

local MODULUS = 2147483647
local MULTIPLIER = 48271

function M.normalize(seed)
  return (math.floor(tonumber(seed) or 1) % (MODULUS - 1)) + 1
end

function M.next(state)
  state.rng_state = (M.normalize(state.rng_state) * MULTIPLIER) % MODULUS
  return state.rng_state
end

function M.range(state, maximum)
  maximum = math.max(1, math.floor(tonumber(maximum) or 1))
  return 1 + (M.next(state) % maximum)
end

function M.shuffle(state, values)
  for index = #values, 2, -1 do
    local other = M.range(state, index)
    values[index], values[other] = values[other], values[index]
  end
  return values
end

return M
