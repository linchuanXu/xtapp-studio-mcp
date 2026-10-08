local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,48,w-m*2,"DOT MATRIX / LOCAL"); if p then C.draw_dots(g,string.format("%02d:%02d",p.hour,p.min),m+10,225,w-m*2-20,190,C.BLACK); g:line(m,486,w-m,486,C.BLACK); C.center(g,m,526,w-m*2,string.format("%02d 月 %02d 日",p.month,p.day)); local total=18; for i=0,total do local x=m+math.floor((w-m*2)*i/total); g:circle(x,602,3,i<=math.floor(total*p.min/59) and "fill" or "stroke",C.BLACK) end; C.center(g,m,646,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_dot_clock=ctx.state.portrait_dot_clock or {}; ctx.state.portrait_dot_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_dot_clock.last then ctx.state.portrait_dot_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
