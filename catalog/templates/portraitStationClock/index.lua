local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:rect(m,52,w-m*2,56,"fill",C.BLACK); C.center(g,m,69,w-m*2,"STATION CLOCK  /  LOCAL TIME",C.WHITE); local gap=14; local cw=math.floor((w-m*2-gap)/2); for i=0,1 do local x=m+i*(cw+gap); g:rect(x,174,cw,246,"fill",C.BLACK); g:line(x+12,196,x+cw-12,196,C.WHITE); g:line(x+12,398,x+cw-12,398,C.WHITE) end; C.draw_stroke_time(g,C.pad(p.hour),m+24,222,cw-48,155,C.WHITE,"chamfer"); C.draw_stroke_time(g,C.pad(p.min),m+cw+gap+24,222,cw-48,155,C.WHITE,"chamfer"); C.center(g,m,454,w-m*2,"小时                    分钟"); g:line(m,514,w-m,514,C.BLACK); C.center(g,m,548,w-m*2,string.format("%02d 月 %02d 日   星期%s",p.month,p.day,C.WEEKDAYS[p.wday+1])); C.center(g,m,600,w-m*2,"每分钟更新一次") else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_station_clock=ctx.state.portrait_station_clock or {}; ctx.state.portrait_station_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_station_clock.last then ctx.state.portrait_station_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
