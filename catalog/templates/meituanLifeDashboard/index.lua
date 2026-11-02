local Dashboard = require("dashboard_common")

function on_load(ctx)
  Dashboard.state(ctx)
  ctx:set_tick(500)
end


function on_tick(ctx)
  ctx:invalidate()
end

function on_input(ctx, ev)
  return Dashboard.input(ctx, ev)
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  Dashboard.draw(ctx, g, true)
end
