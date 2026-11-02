local App = require("domain.chess_app")

-- 对局不跨应用生命周期保存；每次启动都从新的菜单和新棋局开始。
function on_load(ctx)
  ctx.state.chess = nil
  App.start(ctx)
  App.enter(ctx)
end
function on_input(ctx, ev)
  local handled = App.input(ctx, ev)
  if handled then ctx:invalidate() end
  return handled
end
function on_tick(ctx, dt_ms) App.tick(ctx, dt_ms) end
function on_draw(ctx, g) require("pkg_image").bind(ctx); App.draw(ctx, g) end
function on_leave(ctx) App.unload(ctx) end
