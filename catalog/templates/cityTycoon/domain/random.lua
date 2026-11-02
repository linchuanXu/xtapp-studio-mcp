local M = {}

local MOD = 2147483647
local MUL = 48271

function M.normalize(seed)
  local value = math.floor(tonumber(seed) or 1) % MOD
  if value <= 0 then value = 1 end
  return value
end

function M.next(seed)
  local value = (M.normalize(seed) * MUL) % MOD
  return value, value / MOD
end

function M.int(seed, low, high)
  assert(low <= high, "invalid random range")
  local next_seed, unit = M.next(seed)
  return next_seed, low + math.floor(unit * (high - low + 1))
end

function M.shuffle(seed, values)
  local out = {}
  for index, value in ipairs(values) do out[index] = value end
  for index = #out, 2, -1 do
    local target
    seed, target = M.int(seed, 1, index)
    out[index], out[target] = out[target], out[index]
  end
  return seed, out
end

return M
