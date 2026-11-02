local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); local bottom=show_button and h-94 or h-42; C.center(g,m,58,w-m*2,"MINIMAL / "..(p and tostring(p.year) or "----")); g:line(m,86,w-m,86,{color=C.BLACK}); if p then C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m,math.floor(h*0.39),w-m*2,150); C.center(g,m,bottom-48,w-m*2,string.format("%02d 月 %02d 日  周%s",p.month,p.day,C.WEEKDAYS[p.wday+1])) else C.center(g,m,math.floor(h*0.5),w-m*2,"时间未校准") end
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
