local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then local function dial(cx,cy,r,value,label) g:circle(cx,cy,r,{color=C.WHITE}); for i=0,10 do local a=math.pi+i*math.pi/10; local ir=r-(i%5==0 and 22 or 11); g:line(cx+math.floor(math.cos(a)*ir),cy+math.floor(math.sin(a)*ir),cx+math.floor(math.cos(a)*r),cy+math.floor(math.sin(a)*r),{color=C.WHITE}) end; local a=math.pi+value*math.pi; g:line(cx,cy,cx+math.floor(math.cos(a)*(r-30)),cy+math.floor(math.sin(a)*(r-30)),{color=C.WHITE}); g:circle(cx,cy,7,{fill=true,color=C.WHITE}); C.center(g,cx-r,cy+30,r*2,label,C.WHITE) end; g:rect(24,32,432,520,{fill=true,color=C.BLACK}); C.center(g,24,62,432,"TWIN INSTRUMENT / LOCAL",C.WHITE); dial(math.floor(w*.29),332,112,p.hour/23,"HOUR  "..C.pad(p.hour)); dial(math.floor(w*.71),332,112,p.min/59,"MINUTE  "..C.pad(p.min)); g:rect(82,580,316,112,{color=C.BLACK}); C.draw_brush_time(g,string.format("%02d:%02d",p.hour,p.min),82,588,316,67,C.BLACK); C.center(g,82,666,316,string.format("%04d.%02d.%02d",p.year,p.month,p.day)) else C.center(g,m,350,w-m*2,"时间未校准") end
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
