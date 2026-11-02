-- Generated from itlwei/Chess js/gambit.all.js (MIT). Do not edit.
-- Prefix resources are fixed-width, length-segmented and loaded one segment at a time.
local Geometry = require("domain.chess_geometry")
local M = {}
local CANDIDATE_LIMIT = 8
local LINE_COUNT = 7309
local INDEX_ROW_WIDTH = 14
local DATA_CANDIDATE_WIDTH = 3
local HASH_WIDTH = 5
local OFFSET_WIDTH = 3
local HASH_BASE = 257
local U32 = 4294967296
local PACE_HASH_EMPTY_HI = 0
local PACE_HASH_EMPTY_LO = 0
local SEGMENTS = {
  [0] = { data_name = "openings.prefix.L00.txt", index_name = "openings.prefix.L00.index.txt", data_bytes = 26, index_bytes = 14 },
  [2] = { data_name = "openings.prefix.L02.txt", index_name = "openings.prefix.L02.index.txt", data_bytes = 461, index_bytes = 434 },
  [4] = { data_name = "openings.prefix.L04.txt", index_name = "openings.prefix.L04.index.txt", data_bytes = 1461, index_bytes = 2310 },
  [6] = { data_name = "openings.prefix.L06.txt", index_name = "openings.prefix.L06.index.txt", data_bytes = 2716, index_bytes = 5362 },
  [8] = { data_name = "openings.prefix.L08.txt", index_name = "openings.prefix.L08.index.txt", data_bytes = 4270, index_bytes = 9184 },
  [10] = { data_name = "openings.prefix.L10.txt", index_name = "openings.prefix.L10.index.txt", data_bytes = 6158, index_bytes = 13790 },
  [12] = { data_name = "openings.prefix.L12.txt", index_name = "openings.prefix.L12.index.txt", data_bytes = 8494, index_bytes = 19432 },
  [14] = { data_name = "openings.prefix.L14.txt", index_name = "openings.prefix.L14.index.txt", data_bytes = 11163, index_bytes = 26712 },
  [16] = { data_name = "openings.prefix.L16.txt", index_name = "openings.prefix.L16.index.txt", data_bytes = 14215, index_bytes = 33922 },
}
local _ctx
local _loaded_length = nil
local _loaded_data = nil
local _loaded_index = nil
local _loaded_segment = nil

function M.bind(ctx)
  _ctx = ctx
  Geometry.bind(ctx)
end

function M.ensure_ready() return Geometry.ensure_ready() end

local function codec_value(character)
  local value = string.byte(character)
  if not value or value < 32 or value > 126 or value == 34 or value == 92 then return nil end
  value = value - 32
  if string.byte(character) > 34 then value = value - 1 end
  if string.byte(character) > 92 then value = value - 1 end
  return value
end

local function dense_value(text, offset, width)
  local value = 0
  for index = offset, offset + width - 1 do
    local digit = codec_value(text:sub(index, index))
    if digit == nil then return nil end
    value = value * 93 + digit
  end
  return value
end

local function decode_move(text, offset)
  local high = codec_value(text:sub(offset, offset))
  local low = codec_value(text:sub(offset + 1, offset + 1))
  if high == nil or low == nil then return nil end
  local value = high * 93 + low
  local tr = value % 10
  local without_target_rank = math.floor(value / 10)
  local tc = without_target_rank % 9
  local without_target_file = math.floor(without_target_rank / 9)
  local r = without_target_file % 10
  local c = math.floor(without_target_file / 10)
  return { r = r, c = c, tr = tr, tc = tc }
end

local function encode_move(line, offset)
  local c = tonumber(line:sub(offset, offset))
  local r = tonumber(line:sub(offset + 1, offset + 1))
  local tc = tonumber(line:sub(offset + 2, offset + 2))
  local tr = tonumber(line:sub(offset + 3, offset + 3))
  local value = (((c * 10) + r) * 9 + tc) * 10 + tr
  local high = math.floor(value / 93)
  local low = value % 93
  local function character(digit)
    local code = digit + 32
    if code >= 34 then code = code + 1 end
    if code >= 92 then code = code + 1 end
    return string.char(code)
  end
  return character(high) .. character(low)
end

local function encode_pace(pace)
  local encoded = ""
  for offset = 1, #pace, 4 do encoded = encoded .. encode_move(pace, offset) end
  return encoded
end

local function prefix_hash(encoded)
  local hi, lo = PACE_HASH_EMPTY_HI, PACE_HASH_EMPTY_LO
  for index = 1, #encoded do
    local product = lo * HASH_BASE + string.byte(encoded, index)
    lo = product % U32
    hi = (hi * HASH_BASE + math.floor(product / U32)) % U32
  end
  return hi, lo
end

function M.close(session)
  if not session then return end
  local reader = session.reader
  if reader then reader:close(); session.reader = nil end
  if (session.close_count or 0) < 1 then session.close_count = 1 end
end

local function fail_book(session, err)
  M.close(session)
  session.book_error = err
  session.done = true
  return false
end

local function load_segment(session, should_stop)
  if _loaded_length == session.prefix_length and _loaded_data and _loaded_index then
    session.data_text, session.index_text = _loaded_data, _loaded_index
    session.segment = _loaded_segment
    return true
  end
  if should_stop and should_stop() then return false end
  if not _ctx or not _ctx.package then return fail_book(session, "no_ctx") end
  local segment = SEGMENTS[session.prefix_length]
  if not segment then
    session.done = true
    session.candidate_moves = {}
    return false
  end
  local data, data_err = _ctx.package:read(segment.data_name)
  if not data then return fail_book(session, data_err or "data_open_failed") end
  if should_stop and should_stop() then return false end
  local index, index_err = _ctx.package:read(segment.index_name)
  if not index then return fail_book(session, index_err or "index_open_failed") end
  _loaded_length, _loaded_data, _loaded_index, _loaded_segment =
    session.prefix_length, data, index, segment
  session.data_text, session.index_text, session.segment = data, index, segment
  session.segment_open_count = (session.segment_open_count or 0) + 1
  return true
end

local function find_data_offset(session, should_stop)
  local low, high = 0, math.floor(#session.index_text / INDEX_ROW_WIDTH) - 1
  while low <= high do
    if should_stop and should_stop() then return nil, false end
    local middle = math.floor((low + high) / 2)
    local offset = middle * INDEX_ROW_WIDTH + 1
    local row_hi = dense_value(session.index_text, offset, HASH_WIDTH)
    local row_lo = dense_value(session.index_text, offset + HASH_WIDTH, HASH_WIDTH)
    local row_offset = dense_value(
      session.index_text, offset + HASH_WIDTH * 2, OFFSET_WIDTH
    )
    session.lookup_reads = (session.lookup_reads or 0) + 1
    if row_hi == nil or row_lo == nil or row_offset == nil then return nil, true end
    if session.pace_hash_hi == row_hi and session.pace_hash_lo == row_lo then
      return row_offset, true
    end
    if session.pace_hash_hi < row_hi
      or (session.pace_hash_hi == row_hi and session.pace_hash_lo < row_lo) then
      high = middle - 1
    else
      low = middle + 1
    end
  end
  return nil, true
end

local function decode_candidates(session, data_offset)
  local count = dense_value(session.data_text, data_offset + 1, 1)
  if not count or count > CANDIDATE_LIMIT then return false end
  local cursor = data_offset + 2
  session.candidate_moves = {}
  for index = 1, count do
    local move = decode_move(session.data_text, cursor)
    if not move then return false end
    local static_rank = dense_value(session.data_text, cursor + 2, 1)
    if static_rank == nil or static_rank > 8 then return false end
    session.candidate_moves[index] = {
      move = move, corpus_index = index, static_rank = static_rank,
    }
    cursor = cursor + DATA_CANDIDATE_WIDTH
  end
  return true
end

function M.begin(pace)
  pace = pace or ""
  local valid = pace:match("^%d*$") ~= nil and #pace % 4 == 0
  local encoded = valid and encode_pace(pace) or ""
  local hash_hi, hash_lo = prefix_hash(encoded)
  return {
    pace = pace, pace_encoded = encoded, prefix_length = #encoded,
    pace_hash_hi = hash_hi, pace_hash_lo = hash_lo,
    candidate_moves = {}, lookup_reads = 0, segment_open_count = 0,
    done = not valid,
  }
end

function M.step(session, _budget, should_stop)
  if session.done then return true end
  if should_stop and should_stop() then return false end
  if not load_segment(session, should_stop) then return session.done end
  local data_offset, complete = find_data_offset(session, should_stop)
  if not complete then return false end
  if data_offset ~= nil and not decode_candidates(session, data_offset) then
    return fail_book(session, "record_invalid")
  end
  session.done = true
  M.close(session)
  return true
end

function M.candidates(session) return session and session.candidate_moves or {} end
function M.count() return LINE_COUNT end
function M.segment_stats()
  return { prefix_length = _loaded_length, data_bytes = _loaded_segment and _loaded_segment.data_bytes or 0 }
end
return M
