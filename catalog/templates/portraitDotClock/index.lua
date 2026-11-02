local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,48,w-m*2,"DOT MATRIX / LOCAL"); if p then C.draw_dots(g,string.format("%02d:%02d",p.hour,p.min),m+10,225,w-m*2-20,190,C.BLACK); g:line(m,486,w-m,486,{color=C.BLACK}); C.center(g,m,526,w-m*2,string.format("%02d 月 %02d 日",p.month,p.day)); local total=18; for i=0,total do local x=m+math.floor((w-m*2)*i/total); g:circle(x,602,3,{fill=(i<=math.floor(total*p.min/59)) and true or false,color=C.BLACK}) end; C.center(g,m,646,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]) else C.center(g,m,350,w-m*2,"时间未校准") end
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
