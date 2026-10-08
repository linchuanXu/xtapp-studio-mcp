local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,42,w-m*2,"FLIP CALENDAR"); if p then local gap=12; local card_w=math.floor((w-m*2-gap)/2); for i=0,1 do local x=m+i*(card_w+gap); g:rect(x,102,card_w,250,"stroke",C.BLACK); g:line(x,252,x+card_w,252,C.BLACK) end; C.draw_blocks(g,C.pad(p.hour),m+12,143,card_w-24,82); C.draw_blocks(g,C.pad(p.min),m+card_w+gap+12,143,card_w-24,82); C.center(g,m,378,w-m*2,"HOUR                    MINUTE"); g:rect(m,454,w-m*2,172,"stroke",C.BLACK); g:rect(m,454,94,172,"fill",C.BLACK); C.center(g,m,521,94,C.pad(p.month),C.WHITE); C.draw_blocks(g,C.pad(p.day),m+112,485,w-m*2-130,110); C.center(g,m,648,w-m*2,string.format("%04d  星期%s",p.year,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_flip_clock=ctx.state.portrait_flip_clock or {}; ctx.state.portrait_flip_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_flip_clock.last then ctx.state.portrait_flip_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
