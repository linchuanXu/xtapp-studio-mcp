local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,44,w-m*2,"OUTLINE TUBE / FOUR CELLS"); if p then local gap=8; local cw=math.floor((w-m*2-gap*3)/4); local chars={C.pad(p.hour):sub(1,1),C.pad(p.hour):sub(2,2),C.pad(p.min):sub(1,1),C.pad(p.min):sub(2,2)}; for i=0,3 do local x=m+i*(cw+gap); g:rect(x,142,cw,330,{color=C.BLACK}); g:rect(x+8,154,cw-16,306,{color=C.BLACK}); C.draw_stroke_time(g,chars[i+1],x+12,208,cw-24,190,C.BLACK,"tube") end; g:circle(math.floor(w/2),276,7,{fill=true,color=C.BLACK}); g:circle(math.floor(w/2),342,7,{fill=true,color=C.BLACK}); g:rect(m,520,w-m*2,72,{fill=true,color=C.BLACK}); C.center(g,m,538,w-m*2,string.format("%02d / %02d / %04d",p.day,p.month,p.year),C.WHITE); C.center(g,m,626,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]); C.center(g,m,670,w-m*2,"GLASS TUBE / LOCAL") else C.center(g,m,350,w-m*2,"时间未校准") end
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
