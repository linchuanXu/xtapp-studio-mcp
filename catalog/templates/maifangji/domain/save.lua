local Save = {}

local VERSION = 1

local function deep_copy(value, seen)
  if type(value) ~= "table" then
    return value
  end

  seen = seen or {}
  if seen[value] ~= nil then
    return seen[value]
  end

  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[deep_copy(key, seen)] = deep_copy(child, seen)
  end
  return copy
end

function Save.default_records()
  local houses = {}
  for i = 1, 10 do
    houses[i] = {
      first_success_at = "从未成功",
      success_count = 0,
    }
  end

  return {
    version = VERSION,
    houses = houses,
    total_successes = 0,
    best_house = -1,
  }
end

local function nonnegative_integer(value)
  return type(value) == "number"
    and value >= 0
    and value == math.floor(value)
    and value < math.huge
end

local function valid_best_house(value)
  return value == -1
    or (type(value) == "number"
      and value >= 1
      and value <= 10
      and value == math.floor(value))
end

local function records_are_valid(records)
  if type(records) ~= "table"
      or type(records.houses) ~= "table"
      or not nonnegative_integer(records.total_successes)
      or not valid_best_house(records.best_house) then
    return false
  end

  for i = 1, 10 do
    local house = records.houses[i]
    if type(house) ~= "table"
        or type(house.first_success_at) ~= "string"
        or not nonnegative_integer(house.success_count) then
      return false
    end
  end
  return true
end

function Save.record_success(records, house_index, succeeded_at)
  if not records_are_valid(records) or type(succeeded_at) ~= "string" then
    return { ok = false, reason = "invalid_records" }
  end
  if type(house_index) ~= "number"
      or house_index ~= math.floor(house_index)
      or house_index < 1
      or house_index > 10 then
    return { ok = false, reason = "invalid_house_index" }
  end

  local house = records.houses[house_index]
  if house.success_count == 0 then
    house.first_success_at = succeeded_at
  end
  house.success_count = house.success_count + 1
  records.total_successes = records.total_successes + 1
  if records.best_house == -1 or house_index > records.best_house then
    records.best_house = house_index
  end

  return { ok = true }
end

function Save.encode(records)
  return {
    version = VERSION,
    records = deep_copy(records),
  }
end

local function source_and_version(encoded)
  if type(encoded) ~= "table" then
    return nil, nil
  end

  local source = encoded
  if encoded.records ~= nil then
    if type(encoded.records) ~= "table" then
      return nil, nil
    end
    source = encoded.records
  end

  local version = encoded.version
  if version == nil then
    version = source.version
  end
  if version == nil then
    version = 0
  end
  if type(version) ~= "number"
      or version ~= math.floor(version)
      or version < 0
      or version > VERSION then
    return nil, nil
  end
  return source, version
end

function Save.decode(encoded)
  local records = Save.default_records()
  local source = source_and_version(encoded)
  if source == nil then
    return records
  end

  if type(source.houses) == "table" then
    for i = 1, 10 do
      local house_source = rawget(source.houses, i)
      if house_source == nil then
        house_source = rawget(source.houses, tostring(i))
      end
      if type(house_source) == "table" then
        if type(house_source.first_success_at) == "string" then
          records.houses[i].first_success_at = house_source.first_success_at
        end
        if nonnegative_integer(house_source.success_count) then
          records.houses[i].success_count = house_source.success_count
        end
      end
    end
  end

  if nonnegative_integer(source.total_successes) then
    records.total_successes = source.total_successes
  end
  if valid_best_house(source.best_house) then
    records.best_house = source.best_house
  end
  return records
end

return Save
