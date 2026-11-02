local CLOCK = require("index")
function on_tick(ctx, _dt_ms) ctx.lock:set_interval(60) end
function on_draw(ctx, g) require("pkg_image").bind(ctx); CLOCK.draw(ctx, g, false); end
