local Dashboard = require("dashboard_common")

function on_tick(ctx)
  ctx.lock:set_interval(60)
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  Dashboard.draw(ctx, g, false)
  end
