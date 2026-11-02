local PkgImage = require("pkg_image")
local State = require("domain.pomodoro_state")
local M = {}

local BACKGROUND = "bg"

local DIGIT_W = 80
local DIGIT_H = 108
local DIGIT_GAP = 36   -- 一组内两个数字之间的间隔
local ROW_GAP = 48     -- 三组（行）上下之间的间隔
local GROUPS_TOP = 170 -- 最上面那组距页面顶部的像素

local BTN_START = "button-start"
local BTN_PAUSE = "button-pause"
local BTN_STOP = "button-stop"
local BTN_W = 184
local BTN_H = 80
local BTN_LEFT_X = 50
local BTN_RIGHT_X = 246
local BTN_Y = 660

-- 用素材数字画一个两位数：每个数字单独一块与素材等大的白底，两数字间隔 DIGIT_GAP
local function draw_pair(g, x, y, value)
  local tens = math.floor(value / 10) % 10
  local ones = value % 10
  g:rect(x, y, DIGIT_W, DIGIT_H,{fill=true,color=0})
  g:rect(x + DIGIT_W + DIGIT_GAP, y, DIGIT_W, DIGIT_H,{fill=true,color=0})
  PkgImage.draw(g, tostring(tens), x, y)
  PkgImage.draw(g, tostring(ones), x + DIGIT_W + DIGIT_GAP, y)
end

function M.layout(ctx)
  local w, h = ctx.screen.width, ctx.screen.height -- 480 x 800
  local row_y = {
    GROUPS_TOP,
    GROUPS_TOP + DIGIT_H + ROW_GAP,
    GROUPS_TOP + (DIGIT_H + ROW_GAP) * 2,
  }
  local group_w = DIGIT_W * 2 + DIGIT_GAP
  local group_x = math.floor((w - group_w) / 2)
  return { w=w, h=h, row_y=row_y, group_x=group_x,
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
  draw_pair(g, l.group_x, l.row_y[1], hh)
  draw_pair(g, l.group_x, l.row_y[2], mm)
  draw_pair(g, l.group_x, l.row_y[3], ss)

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
