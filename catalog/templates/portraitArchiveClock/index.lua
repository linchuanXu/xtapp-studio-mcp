local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:rect(m,42,118,show_button and h-132 or h-70,"fill",C.BLACK); C.center(g,m,74,118,"ARCHIVE",C.WHITE); C.draw_blocks(g,C.pad(p.hour),m+15,190,88,112,C.WHITE); g:line(m+18,340,m+100,340,C.WHITE); C.draw_blocks(g,C.pad(p.min),m+15,390,88,112,C.WHITE); C.center(g,m,600,118,"NO."..tostring(p.year_day),C.WHITE); local rx=m+140; local rw=w-rx-m; C.center(g,rx,76,rw,string.format("%04d",p.year)); C.draw_blocks(g,C.pad(p.day),rx,148,rw,145); C.center(g,rx,340,rw,string.format("%02d 月 / 周%s",p.month,C.WEEKDAYS[p.wday+1])); C.draw_calendar(g,p,rx,410,rw,270,true) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_archive_clock=ctx.state.portrait_archive_clock or {}; ctx.state.portrait_archive_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_archive_clock.last then ctx.state.portrait_archive_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
