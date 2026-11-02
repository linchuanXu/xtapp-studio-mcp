local App = require("domain.pomodoro_app")

function on_load(ctx)
  App.start(ctx)
  App.enter(ctx)
end
function on_input(ctx, ev) return App.input(ctx, ev) end
function on_tick(ctx, dt_ms) App.tick(ctx, dt_ms) end
function on_draw(ctx, g) require("pkg_image").bind(ctx); App.draw(ctx, g) end
