-- Build-generated geometry.v1 loader.  Resource strings are decoded exactly
-- once; search queries use only integer array indexes afterwards.
local M = {}

local VERSION = 1
local MOVE_RECORD_WIDTH = 8
local MOVE_INDEX_RECORD_WIDTH = 6
local RAY_RECORD_WIDTH = 39
local MOVE_INDEX_RECORDS = 540
local RAY_RECORDS = 360
local UINT32 = 4294967296
local FILES = {
  moves = { name = "geometry.v1.moves.txt", max_bytes = 9072 },
  move_index = { name = "geometry.v1.moves.index.txt", max_bytes = 3240 },
  rays = { name = "geometry.v1.rays.txt", max_bytes = 14040 },
  meta = { name = "geometry.v1.meta.txt", max_bytes = 183 },
}

local _ctx
local _loaded = false
local _load_error = nil
local _move_values = nil
local _move_offsets = nil
local _move_counts = nil
local _ray_values = nil
local _ray_offsets = nil
local _ray_counts = nil
local _stats = { load_count = 0, read_count = 0, lookup_count = 0 }

local function rolling_checksum(parts)
  local value = 0
  for _, text in ipairs(parts) do
    for index = 1, #text do
      value = (value * 131 + string.byte(text, index)) % UINT32
    end
  end
  local n = math.floor(value) % UINT32
  local hi = math.floor(n / 65536)
  local lo = math.floor(n % 65536)
  return string.format("%04X%04X", hi, lo)
end

local function parse_meta(text)
  local values = {}
  for line in string.gmatch(text or "", "[^\r\n]+") do
    local key, value = string.match(line, "^([A-Z_]+)=(.+)$")
    if key then values[key] = value end
  end
  return values
end

local function read_resource(entry)
  if not _ctx or not _ctx.package then return nil, "geometry_no_ctx" end
  local text, err = _ctx.package:read(entry.name)
  if not text then return nil, err or (entry.name .. "_read_failed") end
  _stats.read_count = _stats.read_count + 1
  return text
end

local function fail(err)
  _load_error = err
  return false, err
end

function M.bind(ctx)
  _ctx = ctx
end

function M.ensure_ready()
  if _loaded then return true end
  if _load_error then return false, _load_error end
  if not _ctx or not _ctx.package then
    -- Not bound yet; retryable so a pre-bind caller cannot poison the load.
    return false, "geometry_no_ctx"
  end
  local moves, moves_err = read_resource(FILES.moves)
  if not moves then return fail(moves_err) end
  local move_index, index_err = read_resource(FILES.move_index)
  if not move_index then return fail(index_err) end
  local rays, rays_err = read_resource(FILES.rays)
  if not rays then return fail(rays_err) end
  local meta_text, meta_err = read_resource(FILES.meta)
  if not meta_text then return fail(meta_err) end
  local meta = parse_meta(meta_text)
  if tonumber(meta.VERSION) ~= VERSION then return fail("geometry_version_mismatch") end
  if tonumber(meta.MOVES_BYTES) ~= #moves
    or tonumber(meta.MOVE_INDEX_BYTES) ~= #move_index
    or tonumber(meta.RAYS_BYTES) ~= #rays then
    return fail("geometry_size_mismatch")
  end
  if #moves % MOVE_RECORD_WIDTH ~= 0
    or #move_index ~= MOVE_INDEX_RECORDS * MOVE_INDEX_RECORD_WIDTH
    or #rays ~= RAY_RECORDS * RAY_RECORD_WIDTH then
    return fail("geometry_record_width_mismatch")
  end
  if rolling_checksum({ moves, move_index, rays }) ~= meta.CHECKSUM then
    return fail("geometry_checksum_mismatch")
  end

  local move_values = {}
  local move_records = math.floor(#moves / MOVE_RECORD_WIDTH)
  for record = 0, move_records - 1 do
    local offset = record * MOVE_RECORD_WIDTH + 1
    local kind = tonumber(string.sub(moves, offset, offset))
    local from = tonumber(string.sub(moves, offset + 1, offset + 2))
    local to = tonumber(string.sub(moves, offset + 3, offset + 4))
    local blocker = tonumber(string.sub(moves, offset + 5, offset + 6))
    local flag = tonumber(string.sub(moves, offset + 7, offset + 7))
    if not kind or not from or not to or not blocker or not flag then
      return fail("geometry_move_decode_failed")
    end
    move_values[record + 1] = (((kind * 100 + from) * 100 + to) * 100 + blocker) * 10 + flag
  end

  local move_offsets, move_counts = {}, {}
  for record = 0, MOVE_INDEX_RECORDS - 1 do
    local offset = record * MOVE_INDEX_RECORD_WIDTH + 1
    local first = tonumber(string.sub(move_index, offset, offset + 3))
    local count = tonumber(string.sub(move_index, offset + 4, offset + 5))
    if not first or not count or first + count > move_records then
      return fail("geometry_move_index_decode_failed")
    end
    move_offsets[record + 1] = first + 1
    move_counts[record + 1] = count
  end

  local ray_values, ray_offsets, ray_counts = {}, {}, {}
  local ray_cursor = 1
  for record = 0, RAY_RECORDS - 1 do
    local offset = record * RAY_RECORD_WIDTH + 1
    local from = tonumber(string.sub(rays, offset, offset + 1))
    local direction = tonumber(string.sub(rays, offset + 2, offset + 2))
    local count = tonumber(string.sub(rays, offset + 3, offset + 4))
    local expected_from, expected_direction = math.floor(record / 4), record % 4
    if from ~= expected_from or direction ~= expected_direction or not count or count > 17 then
      return fail("geometry_ray_index_decode_failed")
    end
    ray_offsets[record + 1] = ray_cursor
    ray_counts[record + 1] = count
    for index = 0, count - 1 do
      local square_offset = offset + 5 + index * 2
      local square = tonumber(string.sub(rays, square_offset, square_offset + 1))
      if not square or square < 0 or square > 89 then return fail("geometry_ray_decode_failed") end
      ray_values[ray_cursor] = square
      ray_cursor = ray_cursor + 1
    end
  end

  _move_values, _move_offsets, _move_counts = move_values, move_offsets, move_counts
  _ray_values, _ray_offsets, _ray_counts = ray_values, ray_offsets, ray_counts
  moves, move_index, rays, meta_text, meta = nil, nil, nil, nil, nil
  _loaded = true
  _stats.load_count = _stats.load_count + 1
  return true
end

function M.move_range(kind, square)
  if not _loaded then return nil, 0 end
  if kind < 1 or kind > 6 or square < 0 or square > 89 then return nil, 0 end
  _stats.lookup_count = _stats.lookup_count + 1
  local slot = (kind - 1) * 90 + square + 1
  return _move_offsets[slot], _move_counts[slot]
end

function M.move_at(index)
  if not _loaded then return nil end
  _stats.lookup_count = _stats.lookup_count + 1
  local value = _move_values[index]
  if not value then return nil end
  local flag = value % 10; value = math.floor(value / 10)
  local blocker = value % 100; value = math.floor(value / 100)
  local to = value % 100; value = math.floor(value / 100)
  local from = value % 100; value = math.floor(value / 100)
  return value, from, to, blocker, flag
end

function M.ray_range(square, direction)
  if not _loaded then return nil, 0 end
  if square < 0 or square > 89 or direction < 0 or direction > 3 then return nil, 0 end
  _stats.lookup_count = _stats.lookup_count + 1
  local slot = square * 4 + direction + 1
  return _ray_offsets[slot], _ray_counts[slot]
end

function M.ray_at(index)
  if not _loaded then return nil end
  _stats.lookup_count = _stats.lookup_count + 1
  return _ray_values[index]
end

function M.is_ready() return _loaded end
function M.error() return _load_error end
function M.stats()
  return {
    load_count = _stats.load_count,
    read_count = _stats.read_count,
    lookup_count = _stats.lookup_count,
  }
end

return M
