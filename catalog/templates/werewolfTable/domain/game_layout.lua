-- Geometry for the 480×800 touch-only table view.

local M = {}

M.edge = 12
M.dialog_h = 188
M.dialog_chrome_w = 448
M.choice_h = 52
M.choice_slot = 62
M.choice_w = 384

function M.compute(ctx, count, ending)
  local w, h = ctx.screen.width, ctx.screen.height
  local dialog_y = h - M.dialog_h - M.edge
  local choice_x = math.floor((w - M.choice_w) / 2)
  local stack = count * M.choice_slot
  local choice_y = ending and (h - M.edge - stack) or math.max(118, dialog_y - 20 - stack)
  return {
    w = w, h = h, dialog_x = M.edge, dialog_y = dialog_y, dialog_w = w - M.edge * 2,
    choice_x = choice_x, choice_y = choice_y, choice_w = M.choice_w,
    menu_x = w - M.edge - 52, menu_y = M.edge, menu_w = 52, menu_h = 52,
  }
end

function M.hit_choice(b, index, x, y)
  local top = b.choice_y + (index - 1) * M.choice_slot
  return x >= b.choice_x and x <= b.choice_x + b.choice_w and y >= top and y <= top + M.choice_h
end

function M.hit_stage(b, x, y)
  return x >= 0 and x <= b.w and y >= 0 and y < b.dialog_y + M.dialog_h
end

function M.hit_log(b, x, y)
  return x >= b.menu_x and x <= b.menu_x + b.menu_w and y >= b.menu_y and y <= b.menu_y + b.menu_h
end

function M.hit_log_previous(b, x, y)
  return x >= 28 and x <= 228 and y >= b.h - 82 and y <= b.h - 30
end

function M.hit_log_next(b, x, y)
  return x >= 252 and x <= 452 and y >= b.h - 82 and y <= b.h - 30
end

function M.menu_action(x, y)
  if x < 72 or x > 408 then return nil end
  if y >= 176 and y <= 228 then return "log" end
  if y >= 240 and y <= 292 then return "board" end
  if y >= 304 and y <= 356 then return "restart" end
  if y >= 368 and y <= 420 then return "decks" end
  return nil
end

return M
