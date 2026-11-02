-- 飞书日历：墨水原语。纸/墨、窗、板、线；不决定排谁、谁多高。
local M = {}

M.BLACK, M.WHITE = 15, 0
M.IDS = { "ink", "pixel", "inverse", "press" }
M.LABELS = {
  ink = "墨线",
  pixel = "像素",
  inverse = "反白",
  press = "刊头",
}
M.HINTS = {
  ink = "圆角日程",
  pixel = "掌机菜单",
  inverse = "班次牌",
  press = "日报头版",
}

local function has(id)
  return id == "ink" or id == "pixel" or id == "inverse" or id == "press"
end

function M.normalize(value)
  value = tostring(value or "")
  if has(value) then return value end
  return "ink"
end

function M.id(s)
  return M.normalize(s and s.theme)
end

function M.label(s)
  return M.LABELS[M.id(s)]
end

function M.next(value)
  local current = M.normalize(value)
  for index, id in ipairs(M.IDS) do
    if id == current then
      return M.IDS[(index % #M.IDS) + 1]
    end
  end
  return "ink"
end

function M.prev(value)
  local current = M.normalize(value)
  for index, id in ipairs(M.IDS) do
    if id == current then
      return M.IDS[((index - 2) % #M.IDS) + 1]
    end
  end
  return "ink"
end

function M.paper(s)
  if M.id(s) == "inverse" then return M.BLACK end
  return M.WHITE
end

function M.ink(s)
  if M.id(s) == "inverse" then return M.WHITE end
  return M.BLACK
end

function M.needs_icon_plate(_s)
  return false
end

local function rounded_fill(g, x, y, width, height, radius, color)
  g:rect(x + radius, y, width - radius * 2, height,{fill=true,color=color})
  g:rect(x, y + radius, width, height - radius * 2,{fill=true,color=color})
  g:circle(x + radius, y + radius, radius,{fill=true,color=color})
  g:circle(x + width - radius - 1, y + radius, radius,{fill=true,color=color})
  g:circle(x + radius, y + height - radius - 1, radius,{fill=true,color=color})
  g:circle(x + width - radius - 1, y + height - radius - 1, radius,{fill=true,color=color})
end

local function pixel_fill(g, x, y, width, height, color)
  local step = 6
  if width < step * 2 or height < step * 2 then
    g:rect(x, y, width, height,{fill=true,color=color})
    return
  end
  g:rect(x + step, y, width - step * 2, height,{fill=true,color=color})
  g:rect(x, y + step, width, height - step * 2,{fill=true,color=color})
end

function M.fill(g, s, x, y, width, height, color, radius)
  local theme = M.id(s)
  color = color or M.ink(s)
  if theme == "pixel" then
    pixel_fill(g, x, y, width, height, color)
  elseif theme == "press" or theme == "inverse" then
    g:rect(x, y, width, height,{fill=true,color=color})
  else
    rounded_fill(g, x, y, width, height, radius or 12, color)
  end
end

function M.frame(g, s, x, y, width, height, radius)
  local theme = M.id(s)
  local ink, paper = M.ink(s), M.paper(s)
  if theme == "pixel" then
    M.window(g, x, y, width, height, ink, paper)
  elseif theme == "press" then
    g:rect(x, y, width, 2,{fill=true,color=ink})
    g:rect(x, y + height - 2, width, 2,{fill=true,color=ink})
  elseif theme == "inverse" then
    g:rect(x, y, width, 1,{fill=true,color=ink})
    g:rect(x, y + height - 1, width, 1,{fill=true,color=ink})
    g:rect(x, y, 1, height,{fill=true,color=ink})
    g:rect(x + width - 1, y, 1, height,{fill=true,color=ink})
  else
    M.fill(g, s, x, y, width, height, ink, radius or 10)
    M.fill(g, s, x + 2, y + 2, width - 4, height - 4, paper, math.max(2, (radius or 10) - 2))
  end
end

function M.window(g, x, y, width, height, ink, paper)
  ink = ink or M.BLACK
  paper = paper or M.WHITE
  g:rect(x, y, width, height,{fill=true,color=paper})
  g:rect(x, y, width, 3,{fill=true,color=ink})
  g:rect(x, y + height - 3, width, 3,{fill=true,color=ink})
  g:rect(x, y, 3, height,{fill=true,color=ink})
  g:rect(x + width - 3, y, 3, height,{fill=true,color=ink})
end

function M.solid(g, s, x, y, width, height, radius)
  local theme = M.id(s)
  if theme == "pixel" then
    g:rect(x, y, width, height,{fill=true,color=M.BLACK})
    return M.WHITE
  end
  if theme == "press" then
    g:rect(x, y, width, height,{fill=true,color=M.BLACK})
    return M.WHITE
  end
  if theme == "inverse" then
    return M.WHITE
  end
  M.fill(g, s, x, y, width, height, M.BLACK, radius or 12)
  return M.WHITE
end

function M.dot(g, s, cx, cy, color)
  color = color or M.ink(s)
  if M.id(s) == "pixel" then
    g:rect(cx - 3, cy - 3, 7, 7,{fill=true,color=color})
  elseif M.id(s) == "press" then
    g:rect(cx - 1, cy - 1, 8, 2,{fill=true,color=color})
  else
    g:circle(cx, cy, 3,{fill=true,color=color})
  end
end

function M.icon_plate(g, s, x, y, size)
  if not M.needs_icon_plate(s) then return end
  g:rect(x - 4, y - 4, size + 8, size + 8,{fill=true,color=M.WHITE})
end

function M.stage(g, s)
  local theme = M.id(s)
  if theme == "pixel" then
    g:rect(0, 0, 480, 800,{fill=true,color=M.WHITE})
    g:rect(0, 0, 480, 3,{fill=true,color=M.BLACK})
    g:rect(0, 797, 480, 3,{fill=true,color=M.BLACK})
    g:rect(0, 0, 3, 800,{fill=true,color=M.BLACK})
    g:rect(477, 0, 3, 800,{fill=true,color=M.BLACK})
    g:rect(16, 76, 448, 2,{fill=true,color=M.BLACK})
  elseif theme == "inverse" then
    g:rect(0, 0, 480, 800,{fill=true,color=M.BLACK})
    g:rect(24, 78, 432, 2,{fill=true,color=M.WHITE})
    g:rect(24, 732, 432, 2,{fill=true,color=M.WHITE})
  elseif theme == "press" then
    g:rect(0, 0, 480, 4,{fill=true,color=M.BLACK})
  end
end

function M.tab(g, s, x, selected, label, label_w, label_x)
  local ink, paper = M.ink(s), M.paper(s)
  local theme = M.id(s)
  local tab_y = 736
  if theme == "pixel" then
    if selected then
      g:rect(x + 16, tab_y + 14, 76, 36,{fill=true,color=ink})
      g:text(label_x, tab_y + 22, label, { color = paper })
    else
      g:text(label_x, tab_y + 22, label, { color = ink })
    end
  elseif theme == "inverse" then
    g:text(label_x, tab_y + 22, label, { color = ink })
    if selected then
      g:rect(label_x, tab_y + 48, label_w, 2,{fill=true,color=ink})
    end
  elseif theme == "press" then
    g:text(label_x, tab_y + 22, label, { color = ink })
    if selected then
      g:rect(label_x, tab_y + 48, label_w, 2,{fill=true,color=ink})
    end
  else
    g:text(label_x, tab_y + 22, label, { color = ink })
    if selected then
      g:rect(label_x - 2, tab_y + 48, label_w + 4, 3,{fill=true,color=ink})
    end
  end
end

function M.tab_rule(g, s)
  local theme = M.id(s)
  if theme == "pixel" or theme == "inverse" or theme == "press" then
    return
  end
  g:line(24, 736, 456, 736,{color=M.ink(s)})
end

function M.chrome_band(g, s)
  local theme = M.id(s)
  if theme == "inverse" then
    g:rect(0, 0, 480, 80,{fill=true,color=M.BLACK})
  elseif theme == "press" then
    g:rect(0, 0, 480, 4,{fill=true,color=M.BLACK})
  end
end

function M.swatch(g, id, x, y, width, height, selected)
  local fake = { theme = id }
  if id == "inverse" then
    g:rect(x, y, width, height,{fill=true,color=M.BLACK})
    g:rect(x, y, width, 1,{fill=true,color=M.WHITE})
    g:rect(x, y + height - 1, width, 1,{fill=true,color=M.WHITE})
    g:rect(x, y, 1, height,{fill=true,color=M.WHITE})
    g:rect(x + width - 1, y, 1, height,{fill=true,color=M.WHITE})
  elseif id == "pixel" then
    M.window(g, x, y, width, height, M.BLACK, M.WHITE)
  elseif id == "press" then
    g:rect(x, y, width, height,{fill=true,color=M.WHITE})
    g:rect(x, y, width, 8,{fill=true,color=M.BLACK})
    g:rect(x + 12, y + height - 10, width - 24, 2,{fill=true,color=M.BLACK})
  else
    g:rect(x, y, width, height,{fill=true,color=M.WHITE})
    M.frame(g, fake, x + 8, y + 10, width - 16, height - 20, 10)
  end
  if selected then
    local mark = id == "inverse" and M.WHITE or M.BLACK
    g:rect(x + 4, y + height - 4, width - 8, 2,{fill=true,color=mark})
  end
  return M.ink(fake), M.paper(fake), M.LABELS[id], M.HINTS[id]
end

return M
