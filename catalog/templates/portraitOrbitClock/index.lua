local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local cx,cy=math.floor(w/2),350; local rings={170,124,78}; for i=1,3 do g:circle(cx,cy,rings[i],"stroke",C.BLACK) end; for i=0,11 do local a=i*math.pi/6-math.pi/2; g:line(cx+math.floor(math.cos(a)*176),cy+math.floor(math.sin(a)*176),cx+math.floor(math.cos(a)*164),cy+math.floor(math.sin(a)*164),C.BLACK) end; local ma=p.min*math.pi/30-math.pi/2; local ha=(p.hour%12+p.min/60)*math.pi/6-math.pi/2; local da=(p.day-1)*math.pi*2/31-math.pi/2; g:circle(cx+math.floor(math.cos(ma)*170),cy+math.floor(math.sin(ma)*170),12,"fill",C.BLACK); g:circle(cx+math.floor(math.cos(ha)*124),cy+math.floor(math.sin(ha)*124),14,"fill",C.BLACK); g:circle(cx+math.floor(math.cos(da)*78),cy+math.floor(math.sin(da)*78),11,"fill",C.BLACK); g:circle(cx,cy,46,"fill",C.BLACK); C.draw_brush_time(g,string.format("%02d:%02d",p.hour,p.min),cx-46,cy-12,92,24,C.WHITE); C.center(g,m,84,w-m*2,"ORBIT / LOCAL TIME"); C.center(g,m,548,w-m*2,"外圈：分钟   中圈：小时   内圈：日期"); C.center(g,m,606,w-m*2,string.format("%04d.%02d.%02d  星期%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_orbit_clock=ctx.state.portrait_orbit_clock or {}; ctx.state.portrait_orbit_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_orbit_clock.last then ctx.state.portrait_orbit_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
