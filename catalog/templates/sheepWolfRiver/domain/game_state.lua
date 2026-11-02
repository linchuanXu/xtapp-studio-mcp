local Catalog = require("data.level_catalog")
local Backgrounds = require("data.backgrounds")
local Config = require("domain.game_config")
local Rules = require("domain.game_rules")
local M = {}

local function ensure_table(parent, key)
  if type(parent[key]) ~= "table" then parent[key] = {} end
  return parent[key]
end

local function table_count(value)
  local count = 0
  if type(value) == "table" then
    for _ in pairs(value) do count = count + 1 end
  end
  return count
end

local function signature_steps(signature)
  if type(signature) ~= "string" or signature == "" then return nil end
  local count = 1
  for _ in string.gmatch(signature, "|") do count = count + 1 end
  return count
end

local function normalize_found(found)
  for level_key, bucket in pairs(found) do
    if type(bucket) ~= "table" then
      found[level_key] = nil
    else
      for signature, present in pairs(bucket) do
        if not present or not signature_steps(signature) then bucket[signature] = nil end
      end
    end
  end
end

function M.get(ctx)
  local root = ctx.state
  if type(root.sheep_wolf) ~= "table" then root.sheep_wolf = {} end
  local old = root.sheep_wolf

  if old.data_version ~= Config.DATA_VERSION then
    local level_index = math.max(1, math.min(#Catalog.levels, tonumber(old.level_index) or 1))
    local found = type(old.found) == "table" and old.found or {}
    normalize_found(found)
    -- 1.3.0曾短暂使用全局记录，无法恢复原始关卡；升级时仅归入当前关，
    -- 避免一条短方案错误地增加所有后续关卡的玩家发现数。
    if type(old.found_global) == "table" then
      local key = tostring(level_index)
      if type(found[key]) ~= "table" then found[key] = {} end
      for signature, value in pairs(old.found_global) do
        if value and signature_steps(signature) then found[key][signature] = true end
      end
    end
    local old_page = old.page
    local has_active_game = old.has_active_game == true
      or old_page == "game" or old_page == "rules" or old_page == "paths"
    root.sheep_wolf = {
      data_version = Config.DATA_VERSION,
      page = "home",
      level_index = 1,
      paused_level_index = 1,
      achievement_page = math.max(1, tonumber(old.achievement_page) or 1),
      path_page = math.max(1, tonumber(old.path_page) or 1),
      -- 1.4.0起关卡数量和安全规则已改变，旧方案/成就不可沿用。
      found = {},
      completed = {},
      round = nil,
      result = nil,
      has_active_game = false,
      game_paused = false,
    }
    old = root.sheep_wolf
  end

  local s = old
  if s.page == nil then s.page = "home" end
  s.level_index = math.max(1, math.min(#Catalog.levels, tonumber(s.level_index) or 1))
  s.paused_level_index = math.max(1, math.min(#Catalog.levels,
    tonumber(s.paused_level_index) or s.level_index))
  s.achievement_page = math.max(1, tonumber(s.achievement_page) or 1)
  s.path_page = math.max(1, tonumber(s.path_page) or 1)
  ensure_table(s, "found")
  ensure_table(s, "completed")
  normalize_found(s.found)
  if type(s.round) ~= "table" then
    s.round = Rules.initial_round(Catalog.get(s.level_index))
  end
  -- 兼容1.6.2及更早版本固定5格的进行中存档：只重置输入区，不丢失局面。
  local capacity = tonumber(s.round.boat_capacity) or 2
  local expected_slots = capacity + 1
  local reset_input = type(s.round.input) ~= "table" or #s.round.input ~= expected_slots
    or tonumber(s.round.input[expected_slots]) ~= 3
  if not reset_input then
    for index = 1, capacity do
      local value = tonumber(s.round.input[index])
      if value == nil or value < 0 or value > 2 then reset_input = true; break end
    end
  end
  if reset_input then
    s.round.input = {}
    for index = 1, capacity do s.round.input[index] = 0 end
    s.round.input[expected_slots] = 3
    s.round.input_focus = 1
  end
  if not s.round.background_key then
    s.round.background_key = Backgrounds.key(s.round.left_sheep or 3, s.round.left_wolves or 3,
      s.round.total_sheep or 3, s.round.total_wolves or 3)
  end
  return s
end

function M.level(s)
  return Catalog.get(s.level_index)
end

function M.bank_state_text(round)
  round = round or {}
  local total_sheep = tonumber(round.total_sheep) or 0
  local total_wolves = tonumber(round.total_wolves) or 0
  local left_sheep = tonumber(round.left_sheep) or 0
  local left_wolves = tonumber(round.left_wolves) or 0
  local right_sheep = total_sheep - left_sheep
  local right_wolves = total_wolves - left_wolves
  return "左岸：" .. tostring(left_sheep) .. "羊" .. tostring(left_wolves)
    .. "狼  右岸：" .. tostring(right_sheep) .. "羊" .. tostring(right_wolves) .. "狼"
end

function M.path_text(entry)
  if type(entry) == "table" then return tostring(entry.text or "") end
  -- 仅用于兼容极少数未迁移的旧运行状态；1.6.0新记录都是自然语言表。
  return tostring(entry or "")
end

function M.set_level(s, index)
  local target = math.max(1, math.min(#Catalog.levels, tonumber(index) or 1))
  if target > M.unlocked_level(s) then target = M.unlocked_level(s) end
  s.level_index = target
end

function M.change_level(s, delta)
  M.set_level(s, s.level_index + delta)
end

function M.open_story(s)
  if M.is_unlocked(s, s.level_index) then s.page = "story" end
end

function M.start_round(s)
  s.round = Rules.initial_round(M.level(s))
  s.result = nil
  s.path_page = 1
  s.paused_level_index = s.level_index
  s.has_active_game = true
  s.game_paused = false
  s.page = "game"
end

function M.has_active_game(s)
  return s.has_active_game == true and type(s.round) == "table"
end

-- 首页黑色按钮只能继续“当前选中关卡”的未结束局面。
-- 切换到新解锁关卡后，旧关卡局面不能再劫持“进入本关”按钮。
function M.can_resume_selected(s)
  return M.has_active_game(s)
    and tonumber(s.paused_level_index) == tonumber(s.level_index)
    and s.result == nil
end

function M.pause_to_home(s)
  if not M.has_active_game(s) then return false end
  s.paused_level_index = s.level_index
  s.game_paused = true
  s.page = "home"
  return true
end

function M.resume_game(s)
  if not M.has_active_game(s) then return false end
  s.level_index = s.paused_level_index or s.level_index
  s.game_paused = false
  s.page = "game"
  return true
end

function M.go_home(s)
  if M.has_active_game(s) then s.game_paused = true end
  s.page = "home"
end

function M.open_rules(s)
  if s.page == "game" then s.page = "rules" end
end

function M.open_paths(s)
  if s.page == "game" then
    s.path_page = math.max(1, math.ceil(#s.round.path / Config.MAX_HISTORY_LINES))
    s.page = "paths"
  end
end

function M.return_to_game(s)
  if (s.page == "rules" or s.page == "paths" or s.page == "achievements")
      and M.has_active_game(s) then
    s.game_paused = false
    s.level_index = s.paused_level_index or s.level_index
    s.page = "game"
  end
end

function M.open_achievements(s)
  if M.has_active_game(s) then s.game_paused = true end
  s.page = "achievements"
end

function M.set_input_focus(s, index)
  local choices = (tonumber(s.round.boat_capacity) or 2) + 1
  s.round.input_focus = ((tonumber(index) or 1) - 1) % choices + 1
end

function M.move_input_focus(s, delta)
  M.set_input_focus(s, s.round.input_focus + delta)
end

function M.set_input_digit(s, digit)
  digit = tonumber(digit)
  if digit == nil or digit < 0 or digit > 2 then return false end
  local focus = s.round.input_focus
  local capacity = tonumber(s.round.boat_capacity) or 2
  if focus < 1 or focus > capacity then focus = 1 end
  s.round.input[focus] = digit
  s.round.input_focus = focus % capacity + 1
  s.round.feedback = "已输入，请确认载船组合"
  return true
end

function M.primary_game_action(s)
  local capacity = tonumber(s.round.boat_capacity) or 2
  if s.round.input_focus == capacity + 1 then return M.submit_move(s) end
  local focus = s.round.input_focus
  s.round.input[focus] = (s.round.input[focus] + 1) % 3
  s.round.feedback = "左右选择，OK修改；选中确认后提交"
  return true
end

function M.discovered_count(s, level_index)
  return table_count(s.found[tostring(level_index or s.level_index)])
end

local function append_outcome(round, outcome)
  round.step = outcome.step
  round.left_sheep = outcome.left_sheep
  round.left_wolves = outcome.left_wolves
  round.boat_side = outcome.boat_side
  round.background_key = outcome.background
  round.path[#round.path + 1] = outcome.path_entry
  round.signature_parts[#round.signature_parts + 1] = outcome.signature
end

function M.submit_move(s)
  if s.page ~= "game" or s.result then return false end
  local move, error_message = Rules.normalize_input(s.round.input, s.round.boat_capacity)
  if not move then
    s.round.feedback = error_message
    return true
  end

  local outcome = Rules.preview(s.round, move)
  if outcome.kind == "input_error" then
    s.round.feedback = outcome.message
    return true
  end

  append_outcome(s.round, outcome)
  s.round.input = {}
  for index = 1, s.round.boat_capacity do s.round.input[index] = 0 end
  s.round.input[s.round.boat_capacity + 1] = 3
  s.round.input_focus = 1

  if outcome.kind == "continue" then
    s.round.feedback = "第" .. tostring(outcome.step) .. "步有效，请继续"
    return true
  end

  s.round.feedback = "本轮已结束"
  if outcome.kind == "failure" then
    s.result = {
      kind = "failure",
      title = "本轮结束",
      message = Config.RESULT_TEXT.failure,
      detail = "原因：" .. tostring(outcome.reason or "违反运输规则"),
    }
    return true
  end

  local signature = Rules.signature(s.round)
  local level_key = tostring(s.level_index)
  if type(s.found[level_key]) ~= "table" then s.found[level_key] = {} end
  local duplicate = s.found[level_key][signature] == true
  if not duplicate then s.found[level_key][signature] = true end
  s.completed[tostring(s.level_index)] = true
  s.result = {
    kind = duplicate and "duplicate" or "new",
    title = duplicate and "方案已找到过" or "发现新方案",
    message = duplicate and Config.RESULT_TEXT.duplicate or Config.RESULT_TEXT.new,
    detail = "本次共用 " .. tostring(s.round.step) .. " 步",
  }
  return true
end

function M.dismiss_result(s)
  if not s.result then return false end
  M.start_round(s)
  return true
end

function M.completed_count(s)
  return table_count(s.completed)
end

function M.unlocked_level(s)
  local unlocked = 1
  while unlocked < #Catalog.levels and s.completed[tostring(unlocked)] == true do
    unlocked = unlocked + 1
  end
  return unlocked
end

function M.is_unlocked(s, level_index)
  return (tonumber(level_index) or 1) <= M.unlocked_level(s)
end

function M.is_completed(s, level_index)
  return s.completed[tostring(level_index)] == true
end

return M
