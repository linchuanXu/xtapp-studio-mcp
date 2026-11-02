-- Pure geometry and hit testing. No game rules live here.

local M = {}

M.CARD_W, M.CARD_H = 78, 108

local function inside(x, y, box)
  return x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

function M.compute(hand_count)
  local count = math.max(1, hand_count or 1)
  local available = 560
  local step = math.min(86, math.floor((available - M.CARD_W) / math.max(1, count - 1)))
  local width = M.CARD_W + step * (count - 1)
  local hand_x = math.floor((600 - width) / 2) + 18
  return {
    hand = { x = hand_x, y = 350, w = width, h = M.CARD_H, step = step },
    play = { x = 628, y = 354, w = 148, h = 48 },
    finish = { x = 628, y = 410, w = 148, h = 48 },
    start = { x = 280, y = 322, w = 240, h = 58 },
    home = { x = 206, y = 350, w = 180, h = 54 },
    again = { x = 414, y = 350, w = 180, h = 54 },
  }
end

function M.hand_hit(layout, count, x, y)
  if not inside(x, y, layout.hand) then return nil end
  for index = count, 1, -1 do
    local left = layout.hand.x + (index - 1) * layout.hand.step
    local width = index == count and M.CARD_W or layout.hand.step
    if x >= left and x <= left + width then return index end
  end
  return nil
end

function M.hit(box, x, y) return inside(x, y, box) end

return M
