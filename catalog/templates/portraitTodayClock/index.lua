local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); g:rect(m,48,w-m*2,86,"fill",C.BLACK); C.center(g,m,78,w-m*2,p and string.format("%04d / %02d",p.year,p.month) or "---- / --",C.WHITE); if p then C.draw_blocks(g,string.format("%02d",p.day),m,186,w-m*2,230); C.center(g,m,452,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]); g:line(m,492,w-m,492,C.BLACK); C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m,560,w-m*2,116) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_today_clock=ctx.state.portrait_today_clock or {}; ctx.state.portrait_today_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_today_clock.last then ctx.state.portrait_today_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
