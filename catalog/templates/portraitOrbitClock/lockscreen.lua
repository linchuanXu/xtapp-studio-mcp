local CLOCK = require("index")
function on_load(ctx) ctx.lock:set_interval(60) end
function on_draw(ctx, g) CLOCK.draw(ctx, g, false) end
