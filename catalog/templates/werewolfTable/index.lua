local Runtime = require("domain.game_runtime")
local View = require("domain.game_view")

local App = Runtime.create({ state_key = "werewolf_table" })

function on_load(ctx)
  ctx:set_tick(0)
  App.boot(ctx)
  ctx:invalidate()
end


function on_input(ctx, ev)
  return App.on_input(ctx, ev)
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  View.draw(ctx, g, App)
end
