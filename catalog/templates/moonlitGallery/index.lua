-- 雨夜画廊：基于文游基座的原创成人恋爱互动 Demo。

local Story = require("domain.story_moonlit")
local VN = require("domain.vn_runtime")

local App = VN.create({
  story = Story,
  state_key = "moonlit_gallery",
})

function on_load(ctx)
  ctx:set_tick(0)
  App.boot(ctx)
  ctx:invalidate()
end


function on_input(ctx, ev)
  return App.on_input(ctx, ev)
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  App.on_draw(ctx, g)
end
