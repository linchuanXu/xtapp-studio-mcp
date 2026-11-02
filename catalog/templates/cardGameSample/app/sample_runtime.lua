-- XTApp adapter for the sample plugin. Core engine modules do not know ctx,
-- screens, touch coordinates or drawing commands.

local Engine = require("core.card_engine")
local Rules = require("games.duel_rules")
local AI = require("games.duel_ai")
local Layout = require("ui.sample_layout")
local View = require("ui.sample_view")

local M = {}

local function next_seed(ctx, saved)
  local now = ctx.clock and ctx.clock:millis() or 1
  saved.seed = ((tonumber(saved.seed) or 41) + math.max(1, tonumber(now) or 1)) % 2147483646 + 1
  return saved.seed
end

local function message_for(result)
  if not result or not result.ok then return "行动没有通过规则校验" end
  for index = #result.events, 1, -1 do
    local event = result.events[index]
    if event.kind == "damage" then
      local payload = event.payload or {}
      return "造成 " .. tostring(payload.amount or 0) .. " 点伤害"
    elseif event.kind == "armor_gained" then
      return "获得 " .. tostring(event.payload.amount or 0) .. " 点护甲"
    elseif event.kind == "cards_drawn" then
      return "抽取 " .. tostring(event.payload.count or 0) .. " 张牌"
    elseif event.kind == "turn_started" then
      return event.payload.player == 1 and "轮到你行动" or "纸偶开始行动"
    end
  end
  return "行动已提交"
end

function M.create(options)
  options = options or {}
  local engine = Engine.bind(options.rules or Rules)
  local state_key = options.state_key or "card_game_sample"
  local app = {}

  local function ensure(ctx)
    local saved = ctx.state[state_key]
    if type(saved) ~= "table" then
      saved = { screen = "menu", seed = 41, selected_id = nil, message = nil }
      ctx.state[state_key] = saved
    end
    saved.screen = saved.screen or "menu"
    return saved
  end

  local function start(ctx, saved)
    saved.match = engine.new_match({ seed = next_seed(ctx, saved) })
    saved.screen, saved.selected_id, saved.message = "game", nil, "选择一张牌，或直接收笔"
  end

  local function apply(saved, action)
    local next_match, result = engine.apply(saved.match, action)
    saved.match = next_match
    saved.selected_id = nil
    saved.message = message_for(result)
    if saved.match.status == "over" then saved.screen = "result" end
    return result
  end

  local function selected_is_legal(saved)
    if not saved.selected_id or not saved.match then return false end
    for _, action in ipairs(engine.actions(saved.match, 1)) do
      if action.type == "play" and action.card_id == saved.selected_id then return true end
    end
    return false
  end

  function app.on_load(ctx)
    ensure(ctx)
    ctx:set_tick(100)
    ctx:invalidate()
  end

  function app.on_tick(ctx)
    local saved = ensure(ctx)
    if saved.screen == "game" and saved.match and saved.match.status == "active" and saved.match.turn.active_player == 2 then
      local view = engine.view(saved.match, 2)
      local action = AI.choose(view)
      if action then apply(saved, action) end
      ctx:invalidate()
    end
  end

  function app.on_input(ctx, event)
    local saved = ensure(ctx)
    local tap = (event.type == "pointer" and event.phase == "up") and event.gesture == "tap"
    if saved.screen == "menu" then
      if tap and Layout.hit(Layout.compute(0).start, event.x, event.y) or event.type == "key" and event.key == "OK" then
        start(ctx, saved)
        ctx:invalidate()
        return true
      end
      return false
    end

    if saved.screen == "result" then
      local layout = Layout.compute(0)
      if tap and Layout.hit(layout.home, event.x, event.y) then
        saved.screen, saved.match = "menu", nil
      elseif tap and Layout.hit(layout.again, event.x, event.y) or event.type == "key" and event.key == "OK" then
        start(ctx, saved)
      else
        return false
      end
      ctx:invalidate()
      return true
    end

    if saved.screen ~= "game" or not saved.match then return false end
    if event.type == "key" and event.key == "BACK" then
      saved.screen, saved.match, saved.selected_id = "menu", nil, nil
      ctx:invalidate()
      return true
    end
    if saved.match.turn.active_player ~= 1 or saved.match.status ~= "active" then return false end
    local projected = engine.view(saved.match, 1)
    local hand = projected.zones.p1_hand
    local layout = Layout.compute(hand.count)

    if tap then
      local hand_index = Layout.hand_hit(layout, hand.count, event.x, event.y)
      if hand_index then
        local card = hand.cards[hand_index]
        saved.selected_id = card and card.id or nil
        saved.message = selected_is_legal(saved) and "这张牌可以打出" or "墨力不足，换一张牌"
      elseif Layout.hit(layout.play, event.x, event.y) and selected_is_legal(saved) then
        apply(saved, { type = "play", actor = 1, card_id = saved.selected_id })
      elseif Layout.hit(layout.finish, event.x, event.y) then
        apply(saved, { type = "end_turn", actor = 1 })
      else
        return false
      end
      ctx:invalidate()
      return true
    end
    if event.type == "key" and event.key == "OK" and selected_is_legal(saved) then
      apply(saved, { type = "play", actor = 1, card_id = saved.selected_id })
      ctx:invalidate()
      return true
    end
    return false
  end

  function app.on_draw(ctx, g)
    local saved = ensure(ctx)
    if saved.screen == "menu" then
      View.draw_menu(g)
    elseif not saved.match then
      saved.screen = "menu"
      View.draw_menu(g)
    else
      local view = engine.view(saved.match, 1)
      if saved.screen == "result" then View.draw_result(g, view)
      else View.draw_game(g, view, saved.selected_id, saved.message) end
    end
  end

  function app.inspect(ctx)
    local saved = ensure(ctx)
    return saved.match and engine.view(saved.match, 1) or nil
  end

  app.engine = engine
  app.STATE_KEY = state_key
  return app
end

return M
