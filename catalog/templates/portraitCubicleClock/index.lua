local PkgImage = require("pkg_image")
local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then PkgImage.draw(g, "ornament", 0, 0); C.draw_stroke_time_rot(g,C.pad(p.hour)..":"..C.pad(p.min),214,298,208,100,-3.5,C.BLACK,"tube"); C.center_along_rot(g,214,298,110,354,316,354,-3.5,string.format("%04d.%02d.%02d  星期%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g,true) end
end
M.draw=draw
local timer, revision
local function next_minute(ctx)
  if timer then timer:cancel() end
  local t = ctx.clock:now()
  revision = t.revision
  timer = ctx:after(t.valid and (60 - t.second) * 1000 or 60000, function(c) c:invalidate(); next_minute(c) end)
end
function on_load(ctx) next_minute(ctx) end
function on_resume(ctx) if ctx.clock:now().revision ~= revision then next_minute(ctx) end; ctx:invalidate() end
function on_input(ctx,ev) return C.handle(ctx,ev,true) end
function on_draw(ctx,g) require("pkg_image").bind(ctx); draw(ctx,g,true) end
return M
