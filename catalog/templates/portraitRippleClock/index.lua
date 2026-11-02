local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local cx,cy=math.floor(w/2),350; for i=0,5 do local r=54+i*29; g:circle(cx,cy,r,{color=C.BLACK}) end; for i=0,11 do local a=i*math.pi/6-math.pi/2; g:line(cx+math.floor(math.cos(a)*181),cy+math.floor(math.sin(a)*181),cx+math.floor(math.cos(a)*169),cy+math.floor(math.sin(a)*169),{color=C.BLACK}) end; local a=p.min*math.pi/30-math.pi/2; g:circle(cx+math.floor(math.cos(a)*170),cy+math.floor(math.sin(a)*170),9,{fill=true,color=C.BLACK}); g:circle(cx,cy,118,{fill=true,color=C.WHITE}); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),cx-142,cy-58,284,116,C.BLACK,"round"); C.center(g,m,74,w-m*2,"RIPPLE / MINUTE RHYTHM"); C.center(g,m,548,w-m*2,"圆点：当前分钟   外圈：五分钟刻度"); C.center(g,m,607,w-m*2,string.format("%02d 月 %02d 日  ·  星期%s",p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
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
