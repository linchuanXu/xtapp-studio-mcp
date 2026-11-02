local Runtime = require("domain.game_runtime")
local View = require("domain.game_view")

function on_load(ctx) Runtime.boot(ctx) end
function on_tick(ctx, dt) Runtime.tick(ctx, dt) end
function on_input(ctx, ev) return Runtime.input(ctx, ev) end
function on_draw(ctx, g) require("pkg_image").bind(ctx); View.draw(ctx, g, Runtime.state(ctx)) end
