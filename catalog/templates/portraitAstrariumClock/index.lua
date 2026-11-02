local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local cx,cy=math.floor(w/2),350; C.center(g,m,42,w-m*2,"ASTRARIUM / DAILY ORBITS"); for i=1,5 do local r=42+i*28; g:circle(cx,cy,r,{color=C.BLACK}) end; for i=0,23 do local a=i*math.pi/12-math.pi/2; local r1=174-(i%6==0 and 18 or 9); g:line(cx+math.floor(math.cos(a)*r1),cy+math.floor(math.sin(a)*r1),cx+math.floor(math.cos(a)*174),cy+math.floor(math.sin(a)*174),{color=C.BLACK}) end; local sun=(p.hour+p.min/60)*math.pi/12-math.pi/2; local moon=p.min*math.pi/30-math.pi/2; g:circle(cx+math.floor(math.cos(sun)*142),cy+math.floor(math.sin(sun)*142),16,{fill=true,color=C.BLACK}); g:circle(cx+math.floor(math.cos(moon)*88),cy+math.floor(math.sin(moon)*88),12,{fill=true,color=C.BLACK}); g:circle(cx,cy,52,{fill=true,color=C.BLACK}); C.draw_brush_time(g,string.format("%02d:%02d",p.hour,p.min),cx-52,cy-12,104,28,C.WHITE); C.center(g,m,570,w-m*2,"外轨：一天  ·  内轨：一小时"); C.center(g,m,616,w-m*2,string.format("%04d 年 %02d 月 %02d 日",p.year,p.month,p.day)); C.center(g,m,654,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]) else C.center(g,m,350,w-m*2,"时间未校准") end
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
