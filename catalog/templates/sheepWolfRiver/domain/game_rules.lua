local Config = require("domain.game_config")
local Backgrounds = require("data.backgrounds")
local M = {}

local function bank_name(side)
  return side == "left" and "左岸" or "右岸"
end

local function make_path_entry(step, from_left, move)
  local from_side = from_left and "left" or "right"
  local to_side = from_left and "right" or "left"
  return {
    step = step,
    from_side = from_side,
    to_side = to_side,
    sheep = move.sheep,
    wolves = move.wolves,
    text = "第" .. tostring(step) .. "步：从" .. bank_name(from_side)
      .. "运" .. tostring(move.sheep) .. "羊" .. tostring(move.wolves)
      .. "狼到" .. bank_name(to_side),
  }
end

local function source_shortage(side, need_sheep, need_wolves, have_sheep, have_wolves)
  local missing_sheep = have_sheep < need_sheep
  local missing_wolves = have_wolves < need_wolves
  local what = missing_sheep and missing_wolves and "动物"
    or (missing_sheep and "羊" or "狼")
  return (side == "left" and "左岸" or "右岸") .. "没有足够的" .. what
end

function M.initial_round(level)
  local total_sheep = tonumber(level.sheep) or 3
  local total_wolves = tonumber(level.wolves) or 3
  local boat_capacity = tonumber(level.boat_capacity) or 2
  local input = {}
  for index = 1, boat_capacity do input[index] = 0 end
  input[boat_capacity + 1] = 3
  return {
    total_sheep = total_sheep,
    total_wolves = total_wolves,
    boat_capacity = boat_capacity,
    left_sheep = total_sheep,
    left_wolves = total_wolves,
    boat_side = "left",
    step = 0,
    max_steps = tonumber(level.max_steps) or (total_sheep * 2 - 1),
    input = input,
    input_focus = 1,
    path = {},
    signature_parts = {},
    feedback = "请选择本次载船组合",
    background_key = Backgrounds.initial(total_sheep, total_wolves),
  }
end

function M.normalize_input(values, boat_capacity)
  local sheep, wolves, people = 0, 0, 0
  boat_capacity = tonumber(boat_capacity) or 2
  if type(values) ~= "table" or #values ~= boat_capacity + 1 then
    return nil, "输入格数量与本关船容量不一致"
  end
  for index = 1, #values do
    local digit = tonumber(values[index])
    if digit == 1 then sheep = sheep + 1
    elseif digit == 2 then wolves = wolves + 1
    elseif digit == 3 then people = people + 1
    elseif digit ~= 0 then return nil, "只可输入0、1、2、3" end
  end
  if people ~= 1 then return nil, "每次输入必须且只能有一个3（船夫）" end
  if sheep + wolves > boat_capacity then
    return nil, "本关船一次最多载" .. tostring(boat_capacity) .. "只动物"
  end
  return {
    sheep = sheep,
    wolves = wolves,
    digits = Config.move_digits(sheep, wolves),
  }
end

-- 只检查船夫离开后无人看守的一岸；有羊时狼数大于或等于羊数即失败。
function M.unattended_bank_is_safe(left_sheep, left_wolves, boat_side,
    total_sheep, total_wolves)
  local sheep, wolves
  if boat_side == "right" then
    sheep, wolves = left_sheep, left_wolves
  else
    sheep = total_sheep - left_sheep
    wolves = total_wolves - left_wolves
  end
  return sheep == 0 or wolves < sheep
end

function M.preview(round, move)
  local from_left = round.boat_side == "left"
  local direction = from_left and "a" or "b"
  local left_sheep, left_wolves = round.left_sheep, round.left_wolves
  local total_sheep = round.total_sheep
  local total_wolves = round.total_wolves
  local have_sheep = from_left and left_sheep or total_sheep - left_sheep
  local have_wolves = from_left and left_wolves or total_wolves - left_wolves

  if have_sheep < move.sheep or have_wolves < move.wolves then
    return {
      kind = "input_error",
      message = source_shortage(from_left and "left" or "right",
        move.sheep, move.wolves, have_sheep, have_wolves),
    }
  end

  if from_left then
    left_sheep = left_sheep - move.sheep
    left_wolves = left_wolves - move.wolves
  else
    left_sheep = left_sheep + move.sheep
    left_wolves = left_wolves + move.wolves
  end

  local boat_side = from_left and "right" or "left"
  local step = round.step + 1
  local common = {
    -- a/b编码只参与内部判重，不会出现在玩家路径页面。
    path_code = tostring(step) .. direction .. move.digits,
    path_entry = make_path_entry(step, from_left, move),
    signature = direction .. move.digits,
    left_sheep = left_sheep,
    left_wolves = left_wolves,
    boat_side = boat_side,
    step = step,
    background = Backgrounds.path(left_sheep, left_wolves, total_sheep, total_wolves),
  }

  if not M.unattended_bank_is_safe(left_sheep, left_wolves, boat_side,
      total_sheep, total_wolves) then
    common.kind = "failure"
    common.reason = "船夫离开的一岸出现狼数大于或等于羊数"
    return common
  end

  local won = left_sheep == 0 and left_wolves == 0 and boat_side == "right"
  if won then
    common.kind = "success"
    return common
  end

  if step >= round.max_steps then
    common.kind = "failure"
    common.reason = "已达到本关最大步数"
    return common
  end

  common.kind = "continue"
  return common
end

function M.signature(round, extra)
  local parts = {}
  for index, value in ipairs(round.signature_parts) do parts[index] = value end
  if extra then parts[#parts + 1] = extra end
  return table.concat(parts, "|")
end

return M
