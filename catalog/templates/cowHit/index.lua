local PkgImage = require("pkg_image")
-- 牛马再打我一次
-- XTApp Lua / XTEINK X4 Pro 480x800
-- 0 = white, 15 = black

local WHITE = 0
local BLACK = 15
local GAME_SECONDS = 60

local IMAGE_KEYS = {
  intro = "scene1",
  ready = "scene2",
  hit_a = "scene3",
  hit_b = "scene4",
  finished = "scene5",
}

local function game_state(ctx)
  ctx.state.cow_hit_game = ctx.state.cow_hit_game or {}
  local s = ctx.state.cow_hit_game

  if s.phase == nil then s.phase = "intro" end
  if s.clicks == nil then s.clicks = 0 end
  if s.hit_frame == nil then s.hit_frame = 0 end
  if s.result_visible == nil then s.result_visible = false end

  return s
end

local function now_seconds(ctx)
  local t = ctx.clock:now()
  return t.local_sec or t.epoch_sec
end

local function now_milliseconds(ctx)
  return ctx.clock:millis()
end

local function remaining_seconds(ctx, s)
  local now_sec = now_seconds(ctx)
  if now_sec ~= nil and s.end_sec ~= nil then
    return math.max(0, s.end_sec - now_sec)
  end

  local now_ms = now_milliseconds(ctx)
  if now_ms ~= nil and s.end_uptime_ms ~= nil then
    return math.max(
      0,
      math.ceil((s.end_uptime_ms - now_ms) / 1000)
    )
  end

  if s.fallback_remaining_ms ~= nil then
    return math.max(0, math.ceil(s.fallback_remaining_ms / 1000))
  end

  return s.last_remaining or GAME_SECONDS
end

local function finish_game(ctx, s)
  if s.phase ~= "playing" then return end
  s.phase = "finished"
  s.last_remaining = 0
  s.result_visible = false
  ctx:set_tick(0)
  ctx:invalidate()
end

local function sync_timer(ctx, s)
  if s.phase ~= "playing" then return end
  if remaining_seconds(ctx, s) <= 0 then
    finish_game(ctx, s)
  end
end

local function start_game(ctx, s)
  local now_sec = now_seconds(ctx)
  local now_ms = now_milliseconds(ctx)

  s.phase = "playing"
  s.clicks = 0
  s.hit_frame = 0
  s.result_visible = false
  s.end_sec = now_sec and (now_sec + GAME_SECONDS) or nil
  s.end_uptime_ms = now_ms and (now_ms + GAME_SECONDS * 1000) or nil
  s.fallback_remaining_ms = GAME_SECONDS * 1000
  s.last_remaining = GAME_SECONDS
  ctx:set_tick(100)
  ctx:invalidate()
end

local function reset_game(ctx, s)
  s.phase = "intro"
  s.clicks = 0
  s.hit_frame = 0
  s.result_visible = false
  s.end_sec = nil
  s.end_uptime_ms = nil
  s.fallback_remaining_ms = nil
  s.last_remaining = nil
  ctx:set_tick(0)
  ctx:invalidate()
end

local function handle_action(ctx)
  local s = game_state(ctx)
  sync_timer(ctx, s)

  if s.phase == "intro" then
    -- The first tap reveals scene 2 and starts the 60-second round.
    start_game(ctx, s)
    return true
  end

  if s.phase == "playing" then
    s.clicks = s.clicks + 1
    s.hit_frame = (s.hit_frame % 2) + 1
    ctx:invalidate()
    return true
  end

  if s.phase == "finished" then
    if not s.result_visible then
      s.result_visible = true
      ctx:invalidate()
    else
      reset_game(ctx, s)
    end
    return true
  end

  return false
end

local function draw_image(g, key)
  local ok = pcall(function()
    PkgImage.draw(g, key, 0, 0, { w = 480, h = 800 })
  end)

  if not ok then
    g:rect(18, 90, 444, 620,{color=BLACK})
    g:text(52, 370, "图片资源未加载：" .. key, { color = BLACK })
  end
end

local function estimate_text_width(text, cell_width)
  local unit = cell_width or 8
  local width = 0
  local index = 1

  while index <= #text do
    local byte = string.byte(text, index)
    if byte < 0x80 then
      width = width + unit
      index = index + 1
    elseif byte < 0xE0 then
      width = width + unit * 2
      index = index + 2
    elseif byte < 0xF0 then
      width = width + unit * 2
      index = index + 3
    else
      width = width + unit * 2
      index = index + 4
    end
  end

  return width
end

local function draw_centered_text(g, y, text, color, cell_width)
  local width = estimate_text_width(text, cell_width)
  local x = math.max(8, math.floor((480 - width) / 2))
  g:text(x, y, text, { color = color or BLACK })
end

local function draw_hud_box(g, x, y, w, label, value)
  g:rect(x, y, w, 56,{fill=true,color=WHITE})
  g:rect(x, y, w, 56,{color=BLACK})
  g:text(x + 8, y + 6, label, { color = BLACK })
  g:text(x + 8, y + 29, value, { color = BLACK })
end

local function draw_game_hud(ctx, g, s)
  local remaining = remaining_seconds(ctx, s)
  local timer_text = string.format("00:%02d", remaining)
  if remaining >= 60 then timer_text = "01:00" end

  draw_hud_box(g, 12, 12, 108, "倒计时", timer_text)
  draw_hud_box(g, 348, 12, 120, "点击次数", tostring(s.clicks))

  g:rect(85, 730, 310, 42,{fill=true,color=WHITE})
  g:rect(85, 730, 310, 42,{color=BLACK})
  draw_centered_text(g, 742, "快点点击屏幕！", BLACK, 16)
end

local function draw_result(g, clicks)
  local left = 45
  local top = 286
  local width = 390
  local height = 228

  g:rect(left, top, width, height,{fill=true,color=WHITE})
  g:rect(left, top, width, height,{color=BLACK})
  g:rect(left + 4, top + 4, width - 8, height - 8,{color=BLACK})

  draw_centered_text(g, top + 38, "60秒挑战完成", BLACK, 16)
  draw_centered_text(g, top + 88, "你一共点击了", BLACK, 16)

  local count_text = tostring(clicks) .. " 次"
  draw_centered_text(g, top + 130, count_text, BLACK, 24)
  draw_centered_text(g, top + 184, "再点一下重新开始", BLACK, 16)
end

function on_load(ctx)
  game_state(ctx)
  ctx:set_tick(0)
  local s = game_state(ctx)
  ctx:set_tick(s.phase == "playing" and 100 or 0)
  ctx:invalidate()
end


function on_tick(ctx, dt_ms)
  local s = game_state(ctx)
  if s.phase ~= "playing" then return end

  if now_seconds(ctx) == nil and now_milliseconds(ctx) == nil then
    local elapsed = tonumber(dt_ms) or 100
    s.fallback_remaining_ms = math.max(
      0,
      (s.fallback_remaining_ms or GAME_SECONDS * 1000) - elapsed
    )
  end

  local remaining = remaining_seconds(ctx, s)
  if remaining <= 0 then
    finish_game(ctx, s)
  elseif remaining ~= s.last_remaining then
    s.last_remaining = remaining
    ctx:invalidate()
  end
end

function on_input(ctx, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    return handle_action(ctx)
  end

  if ev.type == "key" and ev.phase == "down" and ev.key == "ok" then
    return handle_action(ctx)
  end

  return false
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s = game_state(ctx)
  sync_timer(ctx, s)
  g:clear(WHITE)

  if s.phase == "intro" then
    draw_image(g, IMAGE_KEYS.intro)
    g:rect(70, 724, 340, 48,{fill=true,color=WHITE})
    g:rect(70, 724, 340, 48,{color=BLACK})
    draw_centered_text(g, 739, "点击屏幕继续", BLACK, 16)
    return
  end

  if s.phase == "playing" then
    if s.hit_frame == 0 then
      draw_image(g, IMAGE_KEYS.ready)
    elseif s.hit_frame == 1 then
      draw_image(g, IMAGE_KEYS.hit_a)
    else
      draw_image(g, IMAGE_KEYS.hit_b)
    end
    draw_game_hud(ctx, g, s)
    return
  end

  draw_image(g, IMAGE_KEYS.finished)
  if s.result_visible then
    draw_result(g, s.clicks)
  else
    g:rect(55, 724, 370, 48,{fill=true,color=WHITE})
    g:rect(55, 724, 370, 48,{color=BLACK})
    draw_centered_text(g, 739, "点击查看本次成绩", BLACK, 16)
  end
end
