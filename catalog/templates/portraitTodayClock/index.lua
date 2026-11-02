local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); g:rect(m,48,w-m*2,86,{fill=true,color=C.BLACK}); C.center(g,m,78,w-m*2,p and string.format("%04d / %02d",p.year,p.month) or "---- / --",C.WHITE); if p then C.draw_blocks(g,string.format("%02d",p.day),m,186,w-m*2,230); C.center(g,m,452,w-m*2,"星期"..C.WEEKDAYS[p.wday+1]); g:line(m,492,w-m,492,{color=C.BLACK}); C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m,560,w-m*2,116) else C.center(g,m,350,w-m*2,"时间未校准") end
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
