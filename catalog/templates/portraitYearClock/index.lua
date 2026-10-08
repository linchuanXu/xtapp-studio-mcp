local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then C.center(g,m,48,w-m*2,"YEAR "..tostring(p.year)); C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m,125,w-m*2,130); C.center(g,m,312,w-m*2,string.format("第 %03d 天 / %03d",p.year_day,C.is_leap(p.year) and 366 or 365)); local grid_y=380; local cell_w=math.floor((w-m*2-22)/3); for month=1,12 do local col=(month-1)%3; local row=math.floor((month-1)/3); local x=m+col*(cell_w+11); local y=grid_y+row*67; if month==p.month then g:rect(x,y,cell_w,48,"fill",C.BLACK); C.center(g,x,y+13,cell_w,string.format("%02d 月",month),C.WHITE) else g:rect(x,y,cell_w,48,"stroke",C.BLACK); C.center(g,x,y+13,cell_w,string.format("%02d 月",month)) end end; local total=C.is_leap(p.year) and 366 or 365; local bar_w=w-m*2; g:rect(m,682,bar_w,22,"stroke",C.BLACK); g:rect(m,682,math.max(2,math.floor(bar_w*p.year_day/total)),22,"fill",C.BLACK) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_year_clock=ctx.state.portrait_year_clock or {}; ctx.state.portrait_year_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_year_clock.last then ctx.state.portrait_year_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
