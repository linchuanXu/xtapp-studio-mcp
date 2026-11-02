local M = {}

local MOD = 2147483647
local MUL = 48271

function M.normalize(seed)
  local value = math.floor(tonumber(seed) or 1) % MOD
  if value <= 0 then value = value + MOD - 1 end
  return value
end

function M.next(seed)
  return (M.normalize(seed) * MUL) % MOD
end

function M.int(seed, low, high)
  low = math.floor(low)
  high = math.floor(high)
  assert(high >= low, "invalid random range")
  local next_seed = M.next(seed)
  return low + (next_seed % (high - low + 1)), next_seed
end

function M.shuffle(values, seed)
  for index = #values, 2, -1 do
    local selected
    selected, seed = M.int(seed, 1, index)
    values[index], values[selected] = values[selected], values[index]
  end
  return seed
end

return M
