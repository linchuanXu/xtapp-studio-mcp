local State = require("domain.pomodoro_state")
local View = require("domain.pomodoro_view")
local M = {}

local function apply_tick_rate(ctx, s)
  if s.mode == "running" then
    ctx:set_tick(500)
  else
    ctx:set_tick(0)
  end
end

function M.start(ctx)
  local s = State.get(ctx)
  apply_tick_rate(ctx, s)
end

function M.enter(ctx)
  local s = State.get(ctx)
  apply_tick_rate(ctx, s)
  ctx:invalidate()
end

function M.tick(ctx, dt_ms)
  local s = State.get(ctx)
  if State.tick(s, dt_ms) then ctx:invalidate() end
end

function M.input(ctx, ev)
  local s = State.get(ctx)
  local changed = false
  if ev.type == "key" and ev.phase == "down" then
    if ev.key == "ok" then
      State.toggle(s); changed = true
    elseif ev.key == "back" then
      State.restart(s); changed = true
    end
  elseif (ev.type == "pointer" and ev.phase == "up") then
    local l = View.layout(ctx)
    if ev.gesture == "tap" then
      if View.hit_start(ev, l) then State.toggle(s); changed = true
      elseif View.hit_restart(ev, l) then State.restart(s); changed = true end
    end
  end
  if changed then
    apply_tick_rate(ctx, s)
    ctx:invalidate()
  end
  return changed
end

function M.draw(ctx, g)
  View.draw(ctx, g, State.get(ctx))
end

return M
