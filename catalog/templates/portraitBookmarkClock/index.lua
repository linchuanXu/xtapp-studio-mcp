local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local bw=210; local bx=math.floor((w-bw)/2); g:rect(bx,36,bw,show_button and h-142 or h-76,"stroke",C.BLACK); g:rect(bx,36,bw,62,"fill",C.BLACK); C.center(g,bx,56,bw,"TIME BOOKMARK",C.WHITE); C.draw_blocks(g,C.pad(p.hour),bx+25,150,bw-50,145); g:line(bx+30,340,bx+bw-30,340,C.BLACK); C.draw_blocks(g,C.pad(p.min),bx+25,395,bw-50,145); C.center(g,bx,606,bw,string.format("%02d.%02d",p.month,p.day)); C.center(g,bx,640,bw,"星期"..C.WEEKDAYS[p.wday+1]); local notch=18; g:line(bx,show_button and h-106 or h-40,bx+bw/2,show_button and h-106+notch or h-40+notch,C.BLACK); g:line(bx+bw/2,show_button and h-106+notch or h-40+notch,bx+bw,show_button and h-106 or h-40,C.BLACK) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_bookmark_clock=ctx.state.portrait_bookmark_clock or {}; ctx.state.portrait_bookmark_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_bookmark_clock.last then ctx.state.portrait_bookmark_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
