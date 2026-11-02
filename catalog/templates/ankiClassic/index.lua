-- 墨卡复习 / X4 Classic
-- 实体键优先：方向键浏览，OK 翻面/记住，BACK 回到题面。
local CARDS = {
  { front = "serendipity", back = "意外发现美好事物的幸运" },
  { front = "deliberate", back = "深思熟虑的；有意的" },
  { front = "resilient", back = "有韧性，能恢复的" },
  { front = "coherent", back = "连贯的；条理清楚的" },
  { front = "subtle", back = "微妙的；不易察觉的" },
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function state(ctx)
  if not ctx.state.anki_classic then
    ctx.state.anki_classic = { index = 1, side = "front", again = 0, good = 0, message = "今日 5 张 · 从第一张开始" }
  end
  return ctx.state.anki_classic
end
local function card(s) return CARDS[s.index] end
local function show_front(s) s.side = "front"; s.message = "想好后按 OK 看答案" end
local function move(s, delta)
  s.index = ((s.index - 1 + delta) % #CARDS) + 1
  show_front(s)
end
local function grade(s, remembered)
  if remembered then s.good = s.good + 1; s.message = "记住了 · 下一张" else s.again = s.again + 1; s.message = "再来一次 · 已留在队列" end
  move(s, 1)
end
function on_load(ctx) ctx:invalidate() end
function on_input(ctx, ev)
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  local s = state(ctx)
  if s.side == "front" then
    if ev.key == "left" or ev.key == "up" then move(s, -1)
    elseif ev.key == "right" or ev.key == "down" then move(s, 1)
    elseif ev.key == "ok" then s.side = "back"; s.message = "↓ 再来一次 · OK 记住"
    elseif ev.key == "back" then s.message = "这是题面 · OK 翻面"
    else return false end
  else
    if ev.key == "ok" or ev.key == "right" then grade(s, true)
    elseif ev.key == "down" or ev.key == "left" then grade(s, false)
    elseif ev.key == "back" then show_front(s)
    else return false end
  end
  ctx:invalidate(); return true
end
function on_draw(ctx, g)
  local s = state(ctx); local c = card(s); local w, h = ctx.screen.width, ctx.screen.height
  local landscape = w > h
  local margin = math.max(18, math.floor(w * 0.06))
  local card_y = math.floor(h * (landscape and 0.16 or 0.18))
  local card_h = math.floor(h * (landscape and 0.54 or 0.54))
  local footer_y = h - (landscape and 76 or 130)
  g:clear(0)
  g:text(margin, math.floor(h * 0.055), "墨卡复习  /  CLASSIC", { color = 15 })
  g:text(margin, math.floor(h * 0.105), string.format("第 %d / %d 张", s.index, #CARDS), { color = 15 })
  g:text(math.max(margin, w - 180), math.floor(h * 0.105), string.format("记住 %d  再来 %d", s.good, s.again), { color = 15 })
  g:rect(margin, card_y, w - margin * 2, card_h,{fill=true,color=15})
  g:rect(margin, card_y, w - margin * 2, card_h,{color=0})
  g:text(margin + 28, card_y + math.floor(card_h * 0.1), s.side == "front" and "问题" or "答案", { color = 0 })
  if s.side == "front" then
    g:text(margin + 28, card_y + math.floor(card_h * 0.43), c.front, { color = 0 })
  else
    g:text(margin + 28, card_y + math.floor(card_h * 0.34), c.front, { color = 0 })
    g:line(margin + 28, card_y + math.floor(card_h * 0.44), w - margin - 28, card_y + math.floor(card_h * 0.44),{color=0})
    g:text(margin + 28, card_y + math.floor(card_h * 0.61), c.back, { color = 0 })
  end
  g:rect(margin, footer_y, w - margin * 2, landscape and 38 or 54,{color=15})
  g:text(margin + 16, footer_y + (landscape and 13 or 18), s.message, { color = 15 })
  g:text(margin, h - math.floor(h * 0.04), s.side == "front" and "←→ 浏览   OK 翻面   BACK 提示" or "↓ 再来一次   OK 记住   BACK 回题面", { color = 15 })
end
