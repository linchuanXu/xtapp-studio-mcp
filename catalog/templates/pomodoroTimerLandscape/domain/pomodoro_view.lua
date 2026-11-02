local PkgImage = require("pkg_image")
local State = require("domain.pomodoro_state")
local M = {}

local BACKGROUND = "bg"

-- 横版 800x480，布局按设计稿（Figma）：
-- 数字行起点 (86,168)：数字 80x108、冒号 32x108，所有项间距 12；
-- 按钮 184x80，左 (204,332)、右 (412,332)，间距 24，底边距 68。
local DIGIT_W = 80
local DIGIT_H = 108
local COLON_W = 32
local ITEM_GAP = 12   -- 数字/冒号所有项之间的间距
local ROW_X = 86      -- 数字行左边缘
local GROUP_Y = 168   -- 数字行顶部 y

local BTN_START = "button-start"
local BTN_PAUSE = "button-pause"
local BTN_STOP = "button-stop"
local BTN_W = 184
local BTN_H = 80
local BTN_LEFT_X = 204
local BTN_RIGHT_X = 412
local BTN_Y = 332

-- 六个数字位与两个冒号位（按 Figma 顺序：HH : MM : SS）
local function slots_x()
  local xs = {}
  local x = ROW_X
  for _, slot in ipairs({ "d", "d", "c", "d", "d", "c", "d", "d" }) do
    xs[#xs + 1] = { x = x, w = (slot == "c" and COLON_W or DIGIT_W) }
    x = x + xs[#xs].w + ITEM_GAP
  end
  return xs
end

-- 用素材数字画一个两位数：每个数字单独一块与素材等大的白底
local function draw_pair(g, s1, s2, y, value)
  g:rect(s1.x, y, DIGIT_W, DIGIT_H,{fill=true,color=0})
  g:rect(s2.x, y, DIGIT_W, DIGIT_H,{fill=true,color=0})
  PkgImage.draw(g, tostring(math.floor(value / 10) % 10), s1.x, y)
  PkgImage.draw(g, tostring(value % 10), s2.x, y)
end

local function draw_colon(g, slot, y)
  g:rect(slot.x, y, COLON_W, DIGIT_H,{fill=true,color=0})
  PkgImage.draw(g, "colon", slot.x, y)
end

function M.layout(ctx)
  local w, h = ctx.screen.width, ctx.screen.height -- 800 x 480
  local slots = slots_x()
  return { w=w, h=h, slots=slots, group_y=GROUP_Y,
    btn_x_left=BTN_LEFT_X, btn_x_right=BTN_RIGHT_X, btn_y=BTN_Y,
    btn_w=BTN_W, btn_h=BTN_H }
end

-- 按钮素材是白底黑图：先画白底衬板让黑笔触清晰可见
local function draw_button(g, key, x, y)
  g:rect(x, y, BTN_W, BTN_H,{fill=true,color=0})
  PkgImage.draw(g, key, x, y)
end

function M.draw(ctx, g, s)
  local l = M.layout(ctx)
  g:clear(0)
  PkgImage.draw(g, BACKGROUND, 0, 0)

  local hh, mm, ss = State.parts(s.elapsed_ms)
  draw_pair(g, l.slots[1], l.slots[2], l.group_y, hh)
  draw_colon(g, l.slots[3], l.group_y)
  draw_pair(g, l.slots[4], l.slots[5], l.group_y, mm)
  draw_colon(g, l.slots[6], l.group_y)
  draw_pair(g, l.slots[7], l.slots[8], l.group_y, ss)

  -- 左侧：开始（idle/paused）或 暂停（running）
  local start_key = (s.mode == "running") and BTN_PAUSE or BTN_START
  draw_button(g, start_key, l.btn_x_left, l.btn_y)
  -- 右侧：结束
  draw_button(g, BTN_STOP, l.btn_x_right, l.btn_y)
end

function M.hit_start(ev, l)
  return ev.x >= l.btn_x_left and ev.x <= l.btn_x_left + l.btn_w
    and ev.y >= l.btn_y and ev.y <= l.btn_y + l.btn_h
end

function M.hit_restart(ev, l)
  return ev.x >= l.btn_x_right and ev.x <= l.btn_x_right + l.btn_w
    and ev.y >= l.btn_y and ev.y <= l.btn_y + l.btn_h
end

return M
