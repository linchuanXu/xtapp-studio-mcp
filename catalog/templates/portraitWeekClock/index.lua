local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,50,w-m*2,p and string.format("%04d / WEEK",p.year) or "WEEK"); if p then C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m,174,w-m*2,160); local track_y=438; for i=0,6 do local cell=math.floor((w-m*2)/7); local x=m+i*cell; if i==p.wday then g:rect(x+4,track_y,cell-8,62,{fill=true,color=C.BLACK}); C.center(g,x,track_y+20,cell,C.WEEKDAYS[i+1],C.WHITE) else g:rect(x+4,track_y,cell-8,62,{color=C.BLACK}); C.center(g,x,track_y+20,cell,C.WEEKDAYS[i+1]) end end; C.center(g,m,545,w-m*2,string.format("今天是 %02d 月 %02d 日",p.month,p.day)); g:line(m,586,w-m,586,{color=C.BLACK}); C.center(g,m,618,w-m*2,"一周走到第 "..tostring(p.wday+1).." 天") else C.center(g,m,350,w-m*2,"时间未校准") end
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
