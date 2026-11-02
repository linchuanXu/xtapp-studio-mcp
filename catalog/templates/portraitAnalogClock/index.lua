local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local cx=math.floor(w/2); local cy=338; local r=190; g:rect(m,38,w-m*2,54,{fill=true,color=C.BLACK}); C.center(g,m,56,w-m*2,"OBSERVATORY ANALOG / 12H",C.WHITE); g:circle(cx,cy,r,{color=C.BLACK}); g:circle(cx,cy,r-10,{color=C.BLACK}); for i=0,59 do local angle=i*math.pi/30-math.pi/2; local outer=r-10; local inner=outer-(i%5==0 and 24 or 8); g:line(cx+math.floor(math.cos(angle)*inner),cy+math.floor(math.sin(angle)*inner),cx+math.floor(math.cos(angle)*outer),cy+math.floor(math.sin(angle)*outer),{color=C.BLACK}) end; for i=0,3 do local a=i*math.pi/2-math.pi/2; g:circle(cx+math.floor(math.cos(a)*(r-42)),cy+math.floor(math.sin(a)*(r-42)),5,{fill=true,color=C.BLACK}) end; local ma=p.min*math.pi/30-math.pi/2; local ha=(p.hour%12+p.min/60)*math.pi/6-math.pi/2; g:line(cx,cy,cx+math.floor(math.cos(ha)*102),cy+math.floor(math.sin(ha)*102),{color=C.BLACK}); g:line(cx,cy,cx+math.floor(math.cos(ma)*151),cy+math.floor(math.sin(ma)*151),{color=C.BLACK}); g:circle(cx,cy,10,{fill=true,color=C.BLACK}); g:rect(88,558,304,112,{fill=true,color=C.BLACK}); C.draw_brush_time(g,string.format("%02d:%02d",p.hour,p.min),88,566,304,61,C.WHITE); C.center(g,88,638,304,string.format("%04d.%02d.%02d  周%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1]),C.WHITE) else C.center(g,m,350,w-m*2,"时间未校准") end
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
