local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); C.center(g,m,42,w-m*2,"FLIP CALENDAR"); if p then local gap=12; local card_w=math.floor((w-m*2-gap)/2); for i=0,1 do local x=m+i*(card_w+gap); g:rect(x,102,card_w,250,{color=C.BLACK}); g:line(x,252,x+card_w,252,{color=C.BLACK}) end; C.draw_blocks(g,C.pad(p.hour),m+12,143,card_w-24,82); C.draw_blocks(g,C.pad(p.min),m+card_w+gap+12,143,card_w-24,82); C.center(g,m,378,w-m*2,"HOUR                    MINUTE"); g:rect(m,454,w-m*2,172,{color=C.BLACK}); g:rect(m,454,94,172,{fill=true,color=C.BLACK}); C.center(g,m,521,94,C.pad(p.month),C.WHITE); C.draw_blocks(g,C.pad(p.day),m+112,485,w-m*2-130,110); C.center(g,m,648,w-m*2,string.format("%04d  星期%s",p.year,C.WEEKDAYS[p.wday+1])) else C.center(g,m,350,w-m*2,"时间未校准") end
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
