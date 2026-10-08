local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:image("ornament",0,0); C.draw_stroke_time_rot(g,C.pad(p.hour)..":"..C.pad(p.min),214,298,208,100,-3.5,C.BLACK,"tube"); C.center_along_rot(g,214,298,110,354,316,354,-3.5,string.format("%04d.%02d.%02d  星期%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g,true) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_cubicle_clock=ctx.state.portrait_cubicle_clock or {}; ctx.state.portrait_cubicle_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_cubicle_clock.last then ctx.state.portrait_cubicle_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev,true) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
