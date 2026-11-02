local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); local panel_h=show_button and h-122 or h-60; g:rect(m,42,w-m*2,panel_h,{fill=true,color=C.BLACK}); if p then C.center(g,m,75,w-m*2,string.format("%04d.%02d.%02d  周%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1]),C.WHITE); C.draw_blocks(g,string.format("%02d:%02d",p.hour,p.min),m+18,260,w-m*2-36,180,C.WHITE); C.center(g,m,panel_h-8,w-m*2,"BLACK / WHITE",C.WHITE) else C.center(g,m,350,w-m*2,"时间未校准",C.WHITE) end
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
