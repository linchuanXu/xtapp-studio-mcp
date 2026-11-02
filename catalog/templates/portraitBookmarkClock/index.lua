local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local bw=210; local bx=math.floor((w-bw)/2); g:rect(bx,36,bw,show_button and h-142 or h-76,{color=C.BLACK}); g:rect(bx,36,bw,62,{fill=true,color=C.BLACK}); C.center(g,bx,56,bw,"TIME BOOKMARK",C.WHITE); C.draw_blocks(g,C.pad(p.hour),bx+25,150,bw-50,145); g:line(bx+30,340,bx+bw-30,340,{color=C.BLACK}); C.draw_blocks(g,C.pad(p.min),bx+25,395,bw-50,145); C.center(g,bx,606,bw,string.format("%02d.%02d",p.month,p.day)); C.center(g,bx,640,bw,"星期"..C.WEEKDAYS[p.wday+1]); local notch=18; g:line(bx,show_button and h-106 or h-40,bx+bw/2,show_button and h-106+notch or h-40+notch,{color=C.BLACK}); g:line(bx+bw/2,show_button and h-106+notch or h-40+notch,bx+bw,show_button and h-106 or h-40,{color=C.BLACK}) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
local timer, revision
local function next_minute(ctx)
  if timer then timer:cancel() end
  local t = ctx.clock:now()
  revision = t.revision
  timer = ctx:after(t.valid and (60 - t.second) * 1000 or 60000, function(c) c:invalidate(); next_minute(c) end)
end
function on_load(ctx) next_minute(ctx) end
function on_resume(ctx) if ctx.clock:now().revision ~= revision then next_minute(ctx) end; ctx:invalidate() end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
