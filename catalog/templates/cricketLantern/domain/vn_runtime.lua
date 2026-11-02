-- Composition root for the VN kit: bind story → engine → view/input handlers.

local Engine = require("domain.vn_engine")
local Layout = require("domain.vn_layout")
local View = require("domain.vn_view")

local M = {}

local function handle_menu_touch(engine, ctx, s, b, ev)
  if not Layout.hit_panel(b, ev.x, ev.y) then
    engine.close_menu(s)
    ctx:invalidate()
    return true
  end

  if s.menu_screen == "backlog" then
    local action = Layout.menu_backlog_hit(b, ev.x, ev.y)
    if action == "previous" then
      engine.move_backlog(s, -1)
    elseif action == "next" then
      engine.move_backlog(s, 1)
    elseif action == "home" then
      s.menu_screen = "home"
    else
      return false
    end
    ctx:invalidate()
    return true
  end

  if s.menu_screen == "checkpoints" then
    local choice = Layout.menu_checkpoint_hit(b, #s.checkpoints, ev.x, ev.y)
    if type(choice) == "number" then
      if engine.restore_checkpoint(s, choice) then ctx:invalidate() end
      return true
    end
    if choice == "home" then
      s.menu_screen = "home"
      ctx:invalidate()
      return true
    end
    return false
  end

  if s.menu_screen == "status" then
    local action = Layout.menu_status_hit(b, ev.x, ev.y)
    if action == "previous" then
      engine.move_status_page(s, -1, Layout.STATUS_ROWS_PER_PAGE)
    elseif action == "next" then
      engine.move_status_page(s, 1, Layout.STATUS_ROWS_PER_PAGE)
    elseif action == "home" then
      s.menu_screen = "home"
    else
      return false
    end
    ctx:invalidate()
    return true
  end

  local action = Layout.menu_home_hit(b, ev.x, ev.y)
  if action == "status" then
    engine.open_status(s)
  elseif action == "backlog" then
    engine.open_backlog(s)
  elseif action == "checkpoints" then
    engine.open_checkpoints(s)
  else
    return false
  end
  ctx:invalidate()
  return true
end

local function handle_touch(engine, ctx, ev)
  local s = engine.ensure(ctx)
  local cs = engine.choices(s)
  engine.refresh_ui(s)
  local visible = View.visible_choice_count(s, cs)
  local chrome = Layout.compute(ctx, 0)

  if ev.gesture ~= "tap" then return false end

  if Layout.hit_status(chrome, ev.x, ev.y) then
    engine.toggle_menu(s)
    ctx:invalidate()
    return true
  end

  if s.show_menu then
    return handle_menu_touch(engine, ctx, s, chrome, ev)
  end

  if engine.is_ending(s) then
    if Layout.hit_ending_restart(chrome, ev.x, ev.y) then
      engine.choose(s, 1)
      ctx:invalidate()
      return true
    end
    return false
  end

  engine.sync_reading(s)
  local b = Layout.compute(ctx, visible)

  if not s.reading_done then
    if Layout.hit_stage(b, ev.x, ev.y) then
      engine.advance(s)
      ctx:invalidate()
      return true
    end
    return false
  end

  if visible == 0 then return false end

  if visible == 1 then
    local on_choice = Layout.hit_choice(b, 1, ev.x, ev.y) == 1
    local on_stage = Layout.hit_stage(b, ev.x, ev.y)
    if on_choice or on_stage then
      engine.choose(s, 1)
      ctx:invalidate()
      return true
    end
    return false
  end

  local index = Layout.hit_choice(b, visible, ev.x, ev.y)
  if index then
    engine.choose(s, index)
    ctx:invalidate()
    return true
  end
  return false
end

function M.create(opts)
  assert(type(opts) == "table" and type(opts.story) == "table", "vn_runtime.create: opts.story required")
  local engine = Engine.bind(opts.story, opts)

  return {
    engine = engine,
    STATE_KEY = engine.STATE_KEY,
    boot = function(ctx)
      engine.boot(ctx)
    end,
    on_input = function(ctx, ev)
      if not (ev.type == "pointer" and ev.phase == "up") then return false end
      return handle_touch(engine, ctx, ev)
    end,
    on_draw = function(ctx, g)
      View.draw(ctx, g, engine)
    end,
  }
end

return M
