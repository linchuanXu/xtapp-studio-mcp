local PkgImage = require("pkg_image")
local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,42,w-m*2,"HOURGLASS / MINUTE FLOW"); if p then PkgImage.draw(g, "ornament", 80, 82); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),m+42,548,w-m*2-84,92,C.BLACK,"chamfer"); local bar=w-m*2; g:rect(m,660,bar,12,{color=C.BLACK}); g:rect(m,660,math.max(2,math.floor(bar*p.min/59)),12,{fill=true,color=C.BLACK}); C.center(g,m,688,w-m*2,string.format("%02d 月 %02d 日  星期%s",p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
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
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) require("pkg_image").bind(ctx); draw(ctx,g,true) end
return M
