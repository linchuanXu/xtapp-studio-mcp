local C = require("clock_common")
local M = {}

-- 秋日黄昏：圆月（高、大）+ 远山 + 水边枫 + 溪面线（顶部无短句）
local function draw_scene(g)
  -- 圆月：上移且更大
  g:circle(148, 366, 40, "stroke", C.BLACK)
  -- 远山：再下移一点、脊线仍平缓（墨痕未干）
  g:line(40, 546, 120, 508, C.BLACK)
  g:line(120, 508, 210, 522, C.BLACK)
  g:line(210, 522, 306, 480, C.BLACK)
  g:line(306, 480, 396, 512, C.BLACK)
  g:line(396, 512, 452, 484, C.BLACK)

  -- 枫树：整体下移左移，树冠完全落在远山之前
  g:line(320, 660, 318, 604, C.BLACK)  -- 干下段
  g:line(318, 604, 312, 552, C.BLACK)  -- 干中段（略收）
  g:line(312, 552, 302, 512, C.BLACK)  -- 干顶（微倾）
  g:line(318, 604, 332, 572, C.BLACK)  -- 右枝
  g:line(312, 578, 286, 548, C.BLACK)  -- 左枝
  g:line(302, 512, 278, 484, C.BLACK)  -- 顶枝

  -- 叶簇：结在各枝端与干顶
  g:circle(302, 508, 4, "fill", C.BLACK)
  g:circle(294, 516, 4, "fill", C.BLACK)
  g:circle(310, 518, 4, "fill", C.BLACK)
  g:circle(278, 480, 4, "fill", C.BLACK)
  g:circle(270, 488, 4, "fill", C.BLACK)
  g:circle(332, 568, 4, "fill", C.BLACK)
  g:circle(342, 576, 4, "fill", C.BLACK)
  g:circle(326, 580, 3, "fill", C.BLACK)
  g:circle(286, 544, 4, "fill", C.BLACK)
  g:circle(278, 552, 4, "fill", C.BLACK)
  g:circle(308, 592, 3, "fill", C.BLACK)

  -- 溪面（无浮叶）
  g:line(40, 668, 440, 668, C.BLACK)
end

local function draw(ctx, g, show_button)
  local w, h = ctx.screen.width, ctx.screen.height
  local m = C.clamp(math.floor(w * 0.06), 20, 30)
  local p = C.project(ctx)
  g:clear(C.WHITE)
  if p then
    -- 中央大号笔画时间（黑字白底，醒目；顶部无短句）
    C.draw_stroke_time(g, C.pad(p.hour), 144, 132, 78, 104, C.BLACK, "tube")
    C.draw_stroke_time(g, C.pad(p.min), 258, 132, 78, 104, C.BLACK, "tube")
    g:circle(240, 169, 3.5, "fill", C.BLACK)
    g:circle(240, 200, 3.5, "fill", C.BLACK)
    -- 下方秋日黄昏
    draw_scene(g)
    -- 底部日期
    C.center(g, 0, 770, w, string.format("%04d.%02d.%02d          星期%s", p.year, p.month, p.day, C.WEEKDAYS[p.wday + 1]))
  else
    C.center(g, m, 350, w - m * 2, "时间未校准")
  end
  if show_button then C.draw_button(ctx, g, true) end
end
M.draw = draw

function on_enter(ctx)
  ctx.state.portrait_maple_dusk_clock = ctx.state.portrait_maple_dusk_clock or {}
  ctx.state.portrait_maple_dusk_clock.last = nil
  ctx:set_tick_rate("low")
  ctx:invalidate()
end
function on_tick(ctx, _dt_ms)
  local p = C.project(ctx)
  local key = p and string.format("%04d%02d%02d%02d%02d", p.year, p.month, p.day, p.hour, p.min) or "unsynced"
  if key ~= ctx.state.portrait_maple_dusk_clock.last then
    ctx.state.portrait_maple_dusk_clock.last = key
    ctx:invalidate()
  end
end
function on_input(ctx, ev) return C.handle(ctx, ev, true) end
function on_draw(ctx, g) draw(ctx, g, true) end
return M
