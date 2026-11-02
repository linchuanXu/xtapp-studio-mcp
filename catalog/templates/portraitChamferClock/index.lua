local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then C.center(g,m,42,w-m*2,"CHAMFER / STACKED"); g:line(m,76,w-m,76,{color=C.BLACK}); C.draw_stroke_time(g,C.pad(p.hour),m+52,112,w-m*2-104,220,C.BLACK,"chamfer"); g:rect(m+90,365,w-m*2-180,6,{fill=true,color=C.BLACK}); C.draw_stroke_time(g,C.pad(p.min),m+52,400,w-m*2-104,220,C.BLACK,"chamfer"); C.center(g,m,654,w-m*2,string.format("%04d.%02d.%02d  周%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
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
function on_draw(ctx,g) draw(ctx,g,true) end
return M
