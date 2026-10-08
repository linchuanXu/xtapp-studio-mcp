local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:rect(m,42,94,show_button and h-132 or h-70,"fill",C.BLACK); C.center(g,m,70,94,"FLOW",C.WHITE); C.center(g,m,122,94,"LOCAL",C.WHITE); C.center(g,m,590,94,C.WEEKDAYS[p.wday+1],C.WHITE); local rx=m+118; local rw=w-rx-m; C.center(g,rx,58,rw,"CONTINUOUS / ROUND"); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),rx,192,rw,240,C.BLACK,"round"); g:line(rx,486,w-m,486,C.BLACK); C.center(g,rx,522,rw,string.format("%04d 年 %02d 月 %02d 日",p.year,p.month,p.day)); for i=0,5 do local y=590+i*18; g:line(rx,y,w-m-i*18,y,C.BLACK) end else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_ribbon_clock=ctx.state.portrait_ribbon_clock or {}; ctx.state.portrait_ribbon_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_ribbon_clock.last then ctx.state.portrait_ribbon_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
