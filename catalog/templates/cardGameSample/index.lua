-- 卡牌游戏样例：组合根。
-- 换游戏时替换 rules / AI / view；通用核心保持不动。

local Runtime = require("app.sample_runtime")

local App = Runtime.create({ state_key = "card_game_sample" })

function on_load(ctx)
  ctx:set_tick(100)
  App.on_load(ctx)
end


function on_tick(ctx, dt)
  App.on_tick(ctx, dt)
end

function on_input(ctx, ev)
  return App.on_input(ctx, ev)
end

function on_draw(ctx, g)
  App.on_draw(ctx, g)
end

function on_leave(ctx)
  ctx:set_tick(0)
end
