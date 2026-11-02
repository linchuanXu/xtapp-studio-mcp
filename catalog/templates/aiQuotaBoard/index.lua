local PkgImage = require("pkg_image")
-- AI 余量板：仅显示 Codex、DeepSeek 和 Claude Code 的离线模拟余量。

local BLACK, WHITE = 15, 0

local function clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function text_width(text)
  local width, index = 0, 1
  while index <= #text do
    if text:byte(index) >= 0xE0 then width, index = width + 20, index + 3 else width, index = width + 10, index + 1 end
  end
  return width
end

local function center(g, x, y, width, text, color)
  g:text(x + math.floor((width - text_width(text)) / 2), y, text, { color = color or BLACK })
end

local function next_value(seed)
  return (seed * 149 + 67) % 997
end

local function snapshot(ctx)
  local state = ctx.state.ai_quota
  local now = ctx.clock:now().local_sec or 1711929600
  local seed = (math.floor(now / 60) + state.nonce * 173) % 997
  seed = next_value(seed); local codex = 24 + seed % 68
  seed = next_value(seed); local deepseek = 19 + seed % 76
  seed = next_value(seed); local claude = 22 + seed % 71
  return { codex = codex, deepseek = deepseek, claude = claude }
end

local function draw_progress(g, x, y, width, percent)
  g:rect(x, y, width, 12,{color=BLACK})
  local fill = math.max(4, math.floor((width - 4) * percent / 100))
  g:rect(x + 2, y + 2, fill, 8,{fill=true,color=BLACK})
end

local function draw_quota(g, x, y, width, icon, title, subtitle, percent)
  g:rect(x, y + 10, 4, 116,{fill=true,color=BLACK})
  PkgImage.draw(g, icon, x + 16, y + 18)
  g:text(x + 106, y + 20, title, { color = BLACK })
  g:text(x + 106, y + 48, subtitle, { color = BLACK })
  local value = string.format("%d%%", percent)
  g:text(x + width - 20 - text_width(value), y + 20, value, { color = BLACK })
  g:text(x + width - 20 - text_width("可用"), y + 48, "可用", { color = BLACK })
  draw_progress(g, x + 106, y + 84, width - 126, percent)
  g:text(x + 106, y + 116, "剩余进度", { color = BLACK })
  g:text(x + width - 20 - text_width(string.format("%d / 100", percent)), y + 116, string.format("%d / 100", percent), { color = BLACK })
  g:line(x, y + 148, x + width, y + 148,{color=BLACK})
end

local function draw(ctx, g)
  local w = ctx.screen.width
  local margin = clamp(math.floor(w * 0.055), 20, 28)
  local inner = w - margin * 2
  local state = ctx.state.ai_quota
  local data = snapshot(ctx)
  local content_y = 12
  g:clear(WHITE)
  g:text(margin, 28 + content_y, "AI QUOTA", { color = BLACK })
  g:line(margin, 62 + content_y, margin + inner, 62 + content_y,{color=BLACK})

  draw_quota(g, margin, 88 + content_y, inner, "icon_codex", "CODEX", "Codex 可用额度", data.codex)
  draw_quota(g, margin, 278 + content_y, inner, "icon_deepseek", "DEEPSEEK", "DeepSeek 可用额度", data.deepseek)
  draw_quota(g, margin, 468 + content_y, inner, "icon_claude", "CLAUDE CODE", "Claude Code 可用额度", data.claude)

  local action = state.focus == 0 and "刷新余量" or "确认刷新"
  g:rect(126, 712 + content_y, 228, 42,{fill=(state.focus == 1) and true or false,color=BLACK})
  center(g, 126, 723 + content_y, 228, action, state.focus == 1 and WHITE or BLACK)
end

local function refresh(ctx)
  ctx.state.ai_quota.nonce = ctx.state.ai_quota.nonce + 1
  ctx:invalidate()
end

function on_load(ctx)
  ctx.state.ai_quota = { nonce = 0, focus = 0 }
  ctx:set_tick(500)
end


function on_input(ctx, ev)
  local state = ctx.state.ai_quota
  if ev.type == "key" and ev.phase == "down" then
    if ev.key == "back" then ctx:quit(); return true end
    if ev.key == "up" or ev.key == "down" then state.focus = 1 - state.focus; ctx:invalidate(); return true end
    if ev.key == "ok" then refresh(ctx); return true end
  end
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" and ev.y >= 702 and ev.y <= 792 then refresh(ctx); return true end
  return false
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  draw(ctx, g)
end
