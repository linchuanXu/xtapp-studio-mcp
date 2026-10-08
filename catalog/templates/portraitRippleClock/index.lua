local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local cx,cy=math.floor(w/2),350; for i=0,5 do local r=54+i*29; g:circle(cx,cy,r,"stroke",C.BLACK) end; for i=0,11 do local a=i*math.pi/6-math.pi/2; g:line(cx+math.floor(math.cos(a)*181),cy+math.floor(math.sin(a)*181),cx+math.floor(math.cos(a)*169),cy+math.floor(math.sin(a)*169),C.BLACK) end; local a=p.min*math.pi/30-math.pi/2; g:circle(cx+math.floor(math.cos(a)*170),cy+math.floor(math.sin(a)*170),9,"fill",C.BLACK); g:circle(cx,cy,118,"fill",C.WHITE); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),cx-142,cy-58,284,116,C.BLACK,"round"); C.center(g,m,74,w-m*2,"RIPPLE / MINUTE RHYTHM"); C.center(g,m,548,w-m*2,"圆点：当前分钟   外圈：五分钟刻度"); C.center(g,m,607,w-m*2,string.format("%02d 月 %02d 日  ·  星期%s",p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_ripple_clock=ctx.state.portrait_ripple_clock or {}; ctx.state.portrait_ripple_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_ripple_clock.last then ctx.state.portrait_ripple_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
