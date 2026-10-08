local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:image("ornament",0,0); C.draw_stroke_time(g,C.pad(p.hour),122,270,96,116,C.BLACK,"tube"); C.draw_stroke_time(g,C.pad(p.min),262,270,96,116,C.BLACK,"tube"); g:circle(240,309,6,"fill",C.BLACK); g:circle(240,349,6,"fill",C.BLACK); C.center(g,28,385,w-28,string.format("%04d.%02d.%02d    星期%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g,true) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_bronze_mirror_clock=ctx.state.portrait_bronze_mirror_clock or {}; ctx.state.portrait_bronze_mirror_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_bronze_mirror_clock.last then ctx.state.portrait_bronze_mirror_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev,true) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
