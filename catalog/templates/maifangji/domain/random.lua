local Random = {}

local MODULUS = 2147483647
local MULTIPLIER = 48271
local Q = math.floor(MODULUS / MULTIPLIER)
local R = MODULUS % MULTIPLIER

local function copy_forced_rolls(forced_rolls)
  if forced_rolls == nil then
    return {}
  end
  if type(forced_rolls) ~= "table" then
    error("forced_rolls must be an array table", 3)
  end

  local count = 0
  local maximum_index = 0
  for key, value in pairs(forced_rolls) do
    if type(key) ~= "number" or key <= 0 or key ~= math.floor(key) then
      error("forced_rolls keys must be positive integers", 3)
    end
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value < 0
        or value >= 1 then
      error("forced_rolls values must be finite numbers in [0, 1)", 3)
    end
    count = count + 1
    maximum_index = math.max(maximum_index, key)
  end

  if count ~= maximum_index then
    error("forced_rolls must not contain sparse entries", 3)
  end

  local forced = {}
  for i = 1, maximum_index do
    if rawget(forced_rolls, i) == nil then
      error("forced_rolls must not contain sparse entries", 3)
    end
    forced[i] = forced_rolls[i]
  end
  return forced
end

local function finite_index(value)
  return type(value) == "number" and value == math.floor(value) and value >= 1
end

function Random.sanitize(rng)
  if type(rng) ~= "table" then return rng end
  local state = tonumber(rng.state)
  if state == nil or state ~= state or state == math.huge or state == -math.huge then
    rng.state = 1
    return rng
  end
  state = math.floor(state + 0.5)
  state = state % MODULUS
  if state <= 0 then state = state + MODULUS end
  if state >= MODULUS then state = 1 end
  rng.state = state
  if not finite_index(rng.forced_index) then rng.forced_index = 1 end
  if type(rng.forced_rolls) ~= "table" then rng.forced_rolls = {} end
  return rng
end

function Random.new(seed, forced_rolls)
  local normalized = math.floor(tonumber(seed) or 1) % MODULUS
  if normalized <= 0 then
    normalized = normalized + MODULUS - 1
  end

  return Random.sanitize({
    state = normalized,
    forced_rolls = copy_forced_rolls(forced_rolls),
    forced_index = 1,
  })
end

function Random.next(rng)
  Random.sanitize(rng)
  local forced = rng.forced_rolls[rng.forced_index]
  if forced ~= nil then
    rng.forced_index = rng.forced_index + 1
    if forced < 0 then return 0 end
    if forced >= 1 then return 0.9999999999999999 end
    return forced
  end
  local hi = math.floor(rng.state / Q)
  local lo = rng.state - hi * Q
  local test = MULTIPLIER * lo - R * hi
  if test <= 0 then test = test + MODULUS end
  rng.state = test
  return rng.state / MODULUS
end

function Random.int(rng, minimum, maximum)
  local roll = Random.next(rng)
  if roll < 0 then
    roll = 0
  elseif roll >= 1 then
    roll = 0.9999999999999999
  end
  return minimum + math.floor(roll * (maximum - minimum + 1))
end

return Random
