local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:rect(m,34,w-m*2,74,{fill=true,color=C.BLACK}); C.center(g,m,48,w-m*2,"THE DAILY TIME",C.WHITE); C.center(g,m,76,w-m*2,string.format("%04d / %02d / %02d",p.year,p.month,p.day),C.WHITE); C.center(g,m,132,w-m*2,"此刻成为今日头条"); C.draw_stroke_time(g,string.format("%02d:%02d",p.hour,p.min),m+4,188,w-m*2-8,230,C.BLACK,"chamfer"); g:rect(m,458,w-m*2,8,{fill=true,color=C.BLACK}); g:rect(m,492,128,156,{fill=true,color=C.BLACK}); C.center(g,m,514,128,"周"..C.WEEKDAYS[p.wday+1],C.WHITE); C.center(g,m,552,128,C.pad(p.hour),C.WHITE); C.center(g,m,584,128,"时",C.WHITE); for i=0,7 do local y=498+i*20; g:line(m+150,y,w-m-(i%3)*40,y,{color=C.BLACK}) end; g:line(m+150,498,m+150,648,{color=C.BLACK}); g:line(m+290,498,m+290,648,{color=C.BLACK}) else C.center(g,m,350,w-m*2,"时间未校准") end
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
