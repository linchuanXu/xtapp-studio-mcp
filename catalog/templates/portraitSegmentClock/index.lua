local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,46,w-m*2,"THIN SEGMENT / CALIBRATION"); g:line(m,80,w-m,80,{color=C.BLACK}); if p then local panel_y=150; for row=0,7 do local y=panel_y+row*45; g:line(m,y,w-m,y,{color=C.BLACK}) end; for col=0,8 do local x=m+col*math.floor((w-m*2)/8); g:line(x,panel_y,x,panel_y+315,{color=C.BLACK}) end; g:rect(m+16,212,w-m*2-32,180,{fill=true,color=C.WHITE}); C.draw_segments(g,string.format("%02d:%02d",p.hour,p.min),m+26,230,w-m*2-52,150,C.BLACK); g:rect(m,500,w-m*2,58,{fill=true,color=C.BLACK}); C.center(g,m,516,w-m*2,string.format("CAL %04d.%02d.%02d",p.year,p.month,p.day),C.WHITE); for i=0,19 do local x=m+math.floor((w-m*2)*i/19); g:line(x,604,x,604+(i%5==0 and 30 or 12),{color=C.BLACK}) end; C.center(g,m,660,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]) else C.center(g,m,350,w-m*2,"时间未校准") end
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
