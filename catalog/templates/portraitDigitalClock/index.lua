local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); g:rect(m,38,w-m*2,show_button and h-126 or h-64,"stroke",C.BLACK); g:rect(m+14,54,w-m*2-28,70,"fill",C.BLACK); C.center(g,m+14,72,w-m*2-28,"DIGITAL MEMORY / MODULE 08",C.WHITE); if p then g:rect(m+24,162,w-m*2-48,292,"stroke",C.BLACK); C.draw_segments(g,string.format("%02d:%02d",p.hour,p.min),m+42,216,w-m*2-84,170,C.BLACK); for i=0,11 do local x=m+34+i*math.floor((w-m*2-68)/11); g:line(x,420,x,420+(i%3==0 and 20 or 10),C.BLACK) end; g:rect(m+24,488,112,138,"fill",C.BLACK); C.center(g,m+24,510,112,"DATE",C.WHITE); C.center(g,m+24,550,112,string.format("%02d / %02d",p.month,p.day),C.WHITE); C.center(g,m+24,584,112,"W"..C.WEEKDAYS[p.wday+1],C.WHITE); g:rect(m+152,488,w-m*2-176,138,"stroke",C.BLACK); C.center(g,m+152,510,w-m*2-176,tostring(p.year)); C.center(g,m+152,550,w-m*2-176,"LOCAL / 60 SEC"); g:line(m+170,592,w-m-42,592,C.BLACK) else C.center(g,m,350,w-m*2,"TIME NOT READY") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_digital_clock=ctx.state.portrait_digital_clock or {}; ctx.state.portrait_digital_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_digital_clock.last then ctx.state.portrait_digital_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
