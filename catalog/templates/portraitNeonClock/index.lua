local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.BLACK); if p then local panel_h=show_button and h-122 or h-60; g:rect(m,42,w-m*2,panel_h,"stroke",C.WHITE); g:rect(m+12,54,w-m*2-24,panel_h-24,"stroke",C.WHITE); C.center(g,m,78,w-m*2,"NIGHT FRAME / MINUTE SCALE",C.WHITE); local scale_x=m+28; local scale_w=w-m*2-56; for i=0,11 do local x=scale_x+math.floor(scale_w*i/11); g:line(x,128,x,142+(i%3==0 and 11 or 5),C.WHITE) end; local marker=scale_x+math.floor(scale_w*p.min/59); g:circle(marker,154,6,"fill",C.WHITE); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),m+40,268,w-m*2-80,176,C.WHITE,"tube"); g:line(m+34,520,w-m-34,520,C.WHITE); C.center(g,m,554,w-m*2,string.format("%04d.%02d.%02d",p.year,p.month,p.day),C.WHITE); C.center(g,m,594,w-m*2,"白点：当前分钟  /  星期"..C.WEEKDAYS[p.wday+1],C.WHITE) else C.center(g,m,350,w-m*2,"TIME NOT READY",C.WHITE) end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_neon_clock=ctx.state.portrait_neon_clock or {}; ctx.state.portrait_neon_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_neon_clock.last then ctx.state.portrait_neon_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
