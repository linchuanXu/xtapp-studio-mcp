local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); if p then g:rect(m,42,118,show_button and h-132 or h-70,{fill=true,color=C.BLACK}); C.center(g,m,74,118,"ARCHIVE",C.WHITE); C.draw_blocks(g,C.pad(p.hour),m+15,190,88,112,C.WHITE); g:line(m+18,340,m+100,340,{color=C.WHITE}); C.draw_blocks(g,C.pad(p.min),m+15,390,88,112,C.WHITE); C.center(g,m,600,118,"NO."..tostring(p.year_day),C.WHITE); local rx=m+140; local rw=w-rx-m; C.center(g,rx,76,rw,string.format("%04d",p.year)); C.draw_blocks(g,C.pad(p.day),rx,148,rw,145); C.center(g,rx,340,rw,string.format("%02d 月 / 周%s",p.month,C.WEEKDAYS[p.wday+1])); C.draw_calendar(g,p,rx,410,rw,270,true) else C.center(g,m,350,w-m*2,"时间未校准") end
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
