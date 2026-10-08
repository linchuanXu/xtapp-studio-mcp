local C = require("clock_common")
local M = {}
local function draw(ctx,g,show_button)
  local w,h=ctx.screen.width,ctx.screen.height; local m=C.clamp(math.floor(w*0.06),20,30); local p=C.project(ctx)
  g:clear(C.WHITE); g:rect(28,34,424,64,"fill",C.BLACK); C.center(g,28,54,424,"中文报时 / 此刻",C.WHITE); if p then g:rect(38,142,104,410,"fill",C.BLACK); C.center(g,38,172,104,"现",C.WHITE); C.center(g,38,244,104,"在",C.WHITE); C.center(g,38,316,104,"是",C.WHITE); g:rect(166,142,276,178,"stroke",C.BLACK); C.center(g,166,198,276,C.cn_number(p.hour).."时"); g:rect(166,344,276,208,"fill",C.BLACK); C.center(g,166,414,276,C.cn_number(p.min).."分",C.WHITE); g:rect(38,584,404,70,"stroke",C.BLACK); C.center(g,38,600,404,string.format("%04d 年 %02d 月 %02d 日  星期%s",p.year,p.month,p.day,C.WEEKDAYS[p.wday+1])); C.center(g,38,628,150,"数字校对"); C.draw_brush_time(g,string.format("%02d:%02d",p.hour,p.min),170,612,250,42,C.BLACK) else C.center(g,m,350,w-m*2,"时间未校准") end
  if show_button then C.draw_button(ctx,g) end
end
M.draw=draw
function on_enter(ctx) ctx.state.portrait_chinese_clock=ctx.state.portrait_chinese_clock or {}; ctx.state.portrait_chinese_clock.last=nil; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local p=C.project(ctx); local key=p and string.format("%04d%02d%02d%02d%02d",p.year,p.month,p.day,p.hour,p.min) or "unsynced"; if key~=ctx.state.portrait_chinese_clock.last then ctx.state.portrait_chinese_clock.last=key; ctx:invalidate() end end
function on_input(ctx,ev) return C.handle(ctx,ev) end
function on_draw(ctx,g) draw(ctx,g,true) end
return M
