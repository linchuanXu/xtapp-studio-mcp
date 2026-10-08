local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); local bottom=show_button and h-94 or h-42; C.center(g,m,58,w-m*2,"MINIMAL / "..(p and tostring(p.year) or "----")); g:line(m,86,w-m,86,C.BLACK); if p then C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m,math.floor(h*0.39),w-m*2,150); C.center(g,m,bottom-48,w-m*2,string.format("%02d 月 %02d 日  周%s",p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,math.floor(h*0.5),w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_minimal_clock=ctx.state.portrait_minimal_clock or {}; ctx.state.portrait_minimal_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_minimal_clock.last then ctx.state.portrait_minimal_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
