local CLOCK = require("index")

function on_tick(ctx, _dt_ms)
    ctx.lock:set_interval(60)
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
    -- The lockscreen uses the same layout without the in-app action button.
    -- It is kept in this small entry file so the app can retain the portrait-only manifest.
    CLOCK.draw_dashboard(ctx, g, false)
    end
