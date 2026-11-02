local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:rect(m,42,94,show_button and h-132 or h-70,{fill=true,color=C.BLACK}); C.center(g,m,70,94,"FLOW",C.WHITE); C.center(g,m,122,94,"LOCAL",C.WHITE); C.center(g,m,590,94,C.WEEKDAYS[p.wday+1],C.WHITE); local rx=m+118; local rw=w-rx-m; C.center(g,rx,58,rw,"CONTINUOUS / ROUND"); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),rx,192,rw,240,C.BLACK,"round"); g:line(rx,486,w-m,486,{color=C.BLACK}); C.center(g,rx,522,rw,string.format("%04d 年 %02d 月 %02d 日",p.year,p.month,p.day)); for i=0,5 do local y=590+i*18; g:line(rx,y,w-m-i*18,y,{color=C.BLACK}) end else C.center(g,m,350,w-m*2,"时间未校准") end
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
