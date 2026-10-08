local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,44,w-m*2,"OUTLINE TUBE / FOUR CELLS"); if p then local gap=8; local cw=math.floor((w-m*2-gap*3)/4); local chars={C.pad(p.hour):sub(1,1),C.pad(p.hour):sub(2,2),C.pad(p.min):sub(1,1),C.pad(p.min):sub(2,2)}; for i=0,3 do local x=m+i*(cw+gap); g:rect(x,142,cw,330,"stroke",C.BLACK); g:rect(x+8,154,cw-16,306,"stroke",C.BLACK); C.draw_stroke_time(g,chars[i+1],x+12,208,cw-24,190,C.BLACK,"tube") end; g:circle(math.floor(w/2),276,7,"fill",C.BLACK); g:circle(math.floor(w/2),342,7,"fill",C.BLACK); g:rect(m,520,w-m*2,72,"fill",C.BLACK); C.center(g,m,538,w-m*2,string.format("%02d / %02d / %04d",p.day,p.month,p.year),C.WHITE); C.center(g,m,626,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]); C.center(g,m,670,w-m*2,"GLASS TUBE / LOCAL") else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_tube_clock=ctx.state.portrait_tube_clock or {}; ctx.state.portrait_tube_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_tube_clock.last then ctx.state.portrait_tube_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
