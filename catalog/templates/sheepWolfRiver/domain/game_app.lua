local State = require("domain.game_state")
local View = require("domain.game_view")
local M = {}

function M.start(ctx)
  State.get(ctx)
end

function M.enter(ctx)
  ctx:invalidate()
end

local function page_delta(s, delta)
  if s.page == "paths" then
    s.path_page = (s.path_page or 1) + delta
  elseif s.page == "achievements" then
    s.achievement_page = (s.achievement_page or 1) + delta
  end
end

local function apply(ctx, s, action)
  if not action then return false end
  local name = action.name
  if name == "level" then
    State.change_level(s, action.delta)
  elseif name == "story" then
    State.open_story(s)
  elseif name == "achievements" then
    State.open_achievements(s)
  elseif name == "resume" then
    State.resume_game(s)
  elseif name == "start" then
    State.start_round(s)
  elseif name == "rules" then
    State.open_rules(s)
  elseif name == "paths" then
    State.open_paths(s)
  elseif name == "return_game" then
    State.return_to_game(s)
  elseif name == "home" then
    State.go_home(s)
  elseif name == "dismiss_result" then
    State.dismiss_result(s)
  elseif name == "focus" then
    State.set_input_focus(s, action.index)
  elseif name == "digit" then
    State.set_input_digit(s, action.digit)
  elseif name == "submit" then
    State.submit_move(s)
  elseif name == "page_delta" then
    page_delta(s, action.delta)
  else
    return false
  end
  ctx:invalidate()
  return true
end

function M.key(ctx, s, key)
  local page = s.page
  if key == "back" then
    if page == "story" then State.go_home(s)
    elseif page == "game" then
      if s.result then State.dismiss_result(s) else State.open_rules(s) end
    elseif page == "rules" or page == "paths" then State.return_to_game(s)
    elseif page == "achievements" then State.go_home(s)
    else return false end
    ctx:invalidate()
    return true
  elseif key == "ok" then
    if page == "home" then State.open_story(s)
    elseif page == "story" then State.start_round(s)
    elseif page == "game" then
      if s.result then State.dismiss_result(s) else State.primary_game_action(s) end
    elseif page == "rules" or page == "paths" then State.return_to_game(s)
    elseif page == "achievements" then State.go_home(s)
    else return false end
    ctx:invalidate()
    return true
  elseif key == "up" then
    -- 游戏中：保存原局面并回首页；首页或成就页：回到保存的游戏。
    if page == "game" then State.pause_to_home(s); ctx:invalidate(); return true end
    if (page == "home" or page == "achievements") and State.has_active_game(s) then
      State.resume_game(s); ctx:invalidate(); return true
    end
    return false
  elseif key == "down" then
    -- 首页下键进入成就；游戏中下键保留原有的路径查看功能。
    if page == "home" then State.open_achievements(s); ctx:invalidate(); return true end
    if page == "game" then State.open_paths(s); ctx:invalidate(); return true end
    return false
  elseif key == "left" or key == "right" then
    if page == "home" then State.change_level(s, key == "left" and -1 or 1); ctx:invalidate(); return true end
    if page == "game" and not s.result then
      State.move_input_focus(s, key == "left" and -1 or 1); ctx:invalidate(); return true
    end
    if page == "paths" or page == "achievements" then
      page_delta(s, key == "left" and -1 or 1)
      ctx:invalidate()
      return true
    end
    return false
  end
  return false
end

function M.input(ctx, ev)
  local s = State.get(ctx)
  if (ev.type == "pointer" and ev.phase == "up") then
    return apply(ctx, s, View.hit(ctx, s, ev))
  end
  if ev.type == "key" and ev.phase == "down" then
    return M.key(ctx, s, ev.key)
  end
  return false
end

function M.draw(ctx, g)
  local s = State.get(ctx)
  View.draw(ctx, g, s)
end

return M
