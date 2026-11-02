local PkgImage = require("pkg_image")
-- 中国象棋：绘制（黑白高对比）
local State = require("domain.chess_state")

-- 中文字符的近似等宽值
local CHAR_W = 20
local CHAR_H = 20
local PIECE_TEXT_DY = -CHAR_H / 2 - 2
local MENU_X = 28
local MENU_W = 424
local MENU_ITEMS = {
  [1] = { y = 256, h = 90, piece = "将", label = "人机对战", detail = "三档棋力  执红先行" },
  [2] = { y = 360, h = 90, piece = "车", label = "双人对战", detail = "同屏对弈  轮流落子" },
}
local SETUP_X = 28
local SETUP_W = 424
local SETUP_ITEMS = {
  [1] = { y = 254, h = 92 },
  [2] = { y = 358, h = 92 },
  [3] = { y = 462, h = 92 },
  [4] = { y = 610, h = 72 },
}
-- 仅少年棋手与「确认开局」可聚焦；青年棋士与棋坛耆宿为「即将开放」的锁定卡片。
local SETUP_FOCUS = { 1, 4 }
local SETUP_LOCKED = { [2] = true, [3] = true }
local OPPONENTS = {
  [1] = { piece = "兵", label = "少年棋手", detail = "轻松试探  入门棋力" },
  [2] = { piece = "马", label = "青年棋士", detail = "即将开放，敬请期待" },
  [3] = { piece = "将", label = "棋坛耆宿", detail = "即将开放，敬请期待" },
}
local PORTRAITS = {
  [1] = {
    thinking = "portrait_child",
    proud = "portrait_child_proud",
    panicked = "portrait_child_panicked",
  },
  [2] = {
    thinking = "portrait_adult",
    proud = "portrait_adult_proud",
    panicked = "portrait_adult_panicked",
  },
  [3] = {
    thinking = "portrait_elder",
    proud = "portrait_elder_proud",
    panicked = "portrait_elder_panicked",
  },
}
-- 顶部人像条带高度（约占屏幕 800 的 1/3）
local BAND_H = 210
local BACK_W = 68
local BACK_H = 30
local DIFF_W = 126
local BUBBLE_X = 300
local BUBBLE_Y = 26
local BUBBLE_W = 162
local BUBBLE_H = 98

local M = {}

local function utf8_len(s)
  local n = 0
  for i = 1, #s do
    local b = s:byte(i)
    if b < 128 or b >= 192 then n = n + 1 end
  end
  return n
end

local function center_text(g, cx, cy, text, color)
  g:text(cx - utf8_len(text) * CHAR_W / 2, cy, text, { color = color })
end

-- 双人=经典大棋盘；人机=人像作顶部约 1/3 条带，棋盘延伸到底部使主体为棋盘。
function M.layout(ctx, mode)
  local w, h = ctx.screen.width, ctx.screen.height
  local margin = 18
  local cell = 50
  local bw = cell * 8
  local x0 = math.floor((w - bw) / 2)
  local y0 = (mode == "ai") and 184 or 176
  local bottom = y0 + cell * 9
  local btn_h = 52
  local btn_y = h - margin - btn_h
  local action_y = bottom + 28
  local action_gap = 12
  local action_w = math.floor((w - margin * 2 - action_gap) / 2)
  return {
    w = w, h = h, cell = cell, x0 = x0, y0 = y0, bottom = bottom,
    margin = margin, btn_w = w - margin * 2, btn_h = btn_h, btn_y = btn_y,
    action_y = action_y, opponent_action_y = 116,
    action_h = 42, action_w = action_w, action_gap = action_gap,
    mode = mode,
  }
end

function M.cell_at(ev, l)
  local c = math.floor((ev.x - l.x0) / l.cell + 0.5)
  local r = math.floor((ev.y - l.y0) / l.cell + 0.5)
  if c < 0 or c > 8 or r < 0 or r > 9 then return nil, nil end
  local ix = l.x0 + c * l.cell
  local iy = l.y0 + r * l.cell
  if math.abs(ev.x - ix) <= l.cell / 2 and math.abs(ev.y - iy) <= l.cell / 2 then
    return r, c
  end
  return nil, nil
end

function M.button_hit(ev, l)
  return ev.x >= l.margin and ev.x <= l.w - l.margin
    and ev.y >= l.btn_y and ev.y <= l.btn_y + l.btn_h
end

function M.game_action_at(ev, l, action_y)
  local y = action_y or l.action_y
  if ev.y < y or ev.y > y + l.action_h then return nil end
  if ev.x >= l.margin and ev.x <= l.margin + l.action_w then return "undo" end
  local draw_x = l.margin + l.action_w + l.action_gap
  if ev.x >= draw_x and ev.x <= draw_x + l.action_w then return "draw" end
  return nil
end

function M.back_hit(ev, l)
  local top = 8
  return ev.x >= l.margin and ev.x <= l.margin + BACK_W
    and ev.y >= top and ev.y <= top + BACK_H
end

local function draw_back(g, l, y)
  local top = y or 8
  g:rect(l.margin, top, BACK_W, BACK_H,{fill=true,color=0})
  g:rect(l.margin, top, BACK_W, BACK_H,{color=15})
  g:text(l.margin + (BACK_W - CHAR_W * 2) / 2, top + 6, "返回", { color = 15 })
end

function M.menu_item_hit(ev, l, i)
  local item = MENU_ITEMS[i]
  if not item then return false end
  return ev.x >= MENU_X and ev.x <= MENU_X + MENU_W
    and ev.y >= item.y and ev.y <= item.y + item.h
end

function M.setup_item_hit(ev, l, i)
  local item = SETUP_ITEMS[i]
  if not item then return false end
  return ev.x >= SETUP_X and ev.x <= SETUP_X + SETUP_W
    and ev.y >= item.y and ev.y <= item.y + item.h
end

function M.setup_locked(i)
  return SETUP_LOCKED[i] == true
end

-- 在可聚焦项（少年棋手 ↔ 确认开局）之间循环；dir=1 向下、-1 向上。
function M.next_setup_index(current, dir)
  local n = #SETUP_FOCUS
  for i = 1, n do
    if SETUP_FOCUS[i] == current then
      return SETUP_FOCUS[((i - 1 + dir) % n) + 1]
    end
  end
  return SETUP_FOCUS[1]
end

local function draw_ai_bubble(g, s)
  local lines = s.ai_dialog
  if type(lines) ~= "table" or not lines[1] then return end
  g:rect(BUBBLE_X, BUBBLE_Y, BUBBLE_W, BUBBLE_H,{fill=true,color=0})
  g:rect(BUBBLE_X, BUBBLE_Y, BUBBLE_W, BUBBLE_H,{color=15})
  g:line(BUBBLE_X, BUBBLE_Y + 46, BUBBLE_X - 12, BUBBLE_Y + 58,{color=15})
  g:line(BUBBLE_X - 12, BUBBLE_Y + 58, BUBBLE_X, BUBBLE_Y + 70,{color=15})
  g:text(BUBBLE_X + 12, BUBBLE_Y + 22, lines[1], { color = 15 })
  if lines[2] then g:text(BUBBLE_X + 12, BUBBLE_Y + 54, lines[2], { color = 15 }) end
end

-- AI 人像顶部区域。三种难度使用各自的 160x160、1bpp 四阶网点头像。
local function draw_ai_portrait(ctx, g, l, s)
  local portraits = PORTRAITS[s.difficulty] or PORTRAITS[1]
  local mood = s.ai_mood or "thinking"
  PkgImage.draw(g, portraits[mood] or portraits.thinking, 128, 0)
  draw_ai_bubble(g, s)
  -- AI 模式：完整方形头像贴顶并位于文案右侧；难度位于返回按钮正下方。
  if s.mode == "ai" then
    draw_back(g, l, 8)
    g:rect(l.margin, 44, DIFF_W, 30,{color=15})
    local opponent = OPPONENTS[s.difficulty] or OPPONENTS[1]
    g:text(l.margin + 8, 50, "AI·" .. opponent.label, { color = 15 })
    if s.ai_thinking then
      g:text(l.margin, 84, "AI思考中", { color = 15 })
      g:text(l.margin, 112, string.format("思考 %d 秒", s.ai_think_display_seconds or 0), { color = 15 })
    end
  else
    draw_back(g, l)
    g:rect(l.margin + BACK_W + 8, 8, l.w - l.margin * 2 - BACK_W - 8, 30,{color=15})
    g:text(l.margin + BACK_W + 14, 14, "对弈中", { color = 15 })
  end
  if s.status == "playing" and s.in_check then
    g:text(l.w - l.margin - 64, 14, "将军", { color = 15 })
  end
end

local function star(g,x,y,c)
  for dx=-1,1,2 do for dy=-1,1,2 do
    if(c~=0 or dx==1)and(c~=8 or dx==-1)then
      local a,b=x+dx*23,y+dy*23
      g:line(a,b,a-dx*6,b,{color=15});g:line(a,b,a,b-dy*6,{color=15})
    end
  end end
end

local function draw_board(g, l, s)
  local cell = l.cell
  local x0, y0 = l.x0, l.y0
  local bw = cell * 8
  local bh = cell * 9
  for r = 0, 9 do
    g:line(x0, y0 + r * cell, x0 + bw, y0 + r * cell,{color=15})
  end
  for c = 0, 8 do
    g:line(x0 + c * cell, y0, x0 + c * cell, y0 + 4 * cell,{color=15})
    g:line(x0 + c * cell, y0 + 5 * cell, x0 + c * cell, y0 + bh,{color=15})
  end
  g:line(x0 + 3 * cell, y0, x0 + 5 * cell, y0 + 2 * cell,{color=15})
  g:line(x0 + 5 * cell, y0, x0 + 3 * cell, y0 + 2 * cell,{color=15})
  g:line(x0 + 3 * cell, y0 + 7 * cell, x0 + 5 * cell, y0 + 9 * cell,{color=15})
  g:line(x0 + 5 * cell, y0 + 7 * cell, x0 + 3 * cell, y0 + 9 * cell,{color=15})
  g:rect(x0, y0, bw, bh,{color=15})

  local cy = y0 + 4 * cell + 22
  local left_cx = x0 + 2 * cell
  local right_cx = x0 + 6 * cell
  g:rect(left_cx - 22, cy - 14, 44, 28,{color=15})
  g:text(left_cx - CHAR_W, cy - CHAR_H / 2, "楚", { color = 15 })
  g:text(left_cx, cy - CHAR_H / 2, "河", { color = 15 })
  g:rect(right_cx - 22, cy - 14, 44, 28,{color=15})
  g:text(right_cx - CHAR_W, cy - CHAR_H / 2, "漢", { color = 15 })
  g:text(right_cx, cy - CHAR_H / 2, "界", { color = 15 })

  -- L 谱星。
  for _, entry in ipairs({ { 2, { 1, 7 } }, { 7, { 1, 7 } }, { 3, { 0, 2, 4, 6, 8 } }, { 6, { 0, 2, 4, 6, 8 } } }) do
    for _, c in ipairs(entry[2]) do
      local x, y = x0 + c * cell, y0 + entry[1] * cell
      star(g,x,y,c)
    end
  end
end

local function draw_black_piece(g, cx, cy, label)
  local rad = 20
  g:circle(cx, cy, rad,{fill=true,color=15})
  g:text(cx - CHAR_W / 2, cy + PIECE_TEXT_DY, label, { color = 0 })
end

local function draw_white_piece(g, cx, cy, label)
  local rad = 20
  g:circle(cx, cy, rad,{fill=true,color=0})
  g:circle(cx, cy, rad,{color=15})
  g:text(cx - CHAR_W / 2, cy + PIECE_TEXT_DY, label, { color = 15 })
end

local function draw_piece(g, l, s, r, c, ch)
  local cx = l.x0 + c * l.cell
  local cy = l.y0 + r * l.cell
  local rad = 20
  if (s.selR == r and s.selC == c) then
    g:circle(cx, cy, rad + 5,{color=15})
    g:circle(cx, cy, rad + 7,{color=15})
  end
  local label = State.piece_label(ch)
  if ch:byte() < 97 then
    draw_black_piece(g, cx, cy, label)
  else
    draw_white_piece(g, cx, cy, label)
  end
end

local function draw_hints(g, l, s)
  if s.status ~= "playing" or not s.selR then return end
  local targets = State.hint_targets(s, s.selR, s.selC)
  for _, t in ipairs(targets) do
    local cx = l.x0 + t.tc * l.cell
    local cy = l.y0 + t.tr * l.cell
    if State.piece_at(s, t.tr, t.tc) == State.EMPTY then
      g:circle(cx, cy, 5,{fill=true,color=15})
    else
      g:circle(cx, cy, 8,{color=15})
    end
  end
end

local function draw_last(g, l, s)
  if not s.last then return end
  local from_x = l.x0 + s.last.fc * l.cell
  local from_y = l.y0 + s.last.fr * l.cell
  local to_x = l.x0 + s.last.tc * l.cell
  local to_y = l.y0 + s.last.tr * l.cell
  g:circle(from_x, from_y, 7,{color=15})
  g:circle(to_x, to_y, 24,{color=15})
end

local CHECK_ANIM_PHASE_MS = 250
local CHECK_ANIM_RADII = { 27, 28, 29, 28 }

local function draw_check(g, l, s)
  if s.status ~= "playing" or not s.in_check then return end
  local gr, gc = State.general_pos(s)
  if gr then
    local phase = math.floor((s.check_anim_t or 0) / CHECK_ANIM_PHASE_MS) % #CHECK_ANIM_RADII + 1    g:circle(l.x0 + gc * l.cell, l.y0 + gr * l.cell, CHECK_ANIM_RADII[phase],{color=15})
  end
end

function M.draw_game(ctx, g, s)
  local l = M.layout(ctx, s.mode)
  g:clear(0)

  if s.mode == "ai" then
    draw_ai_portrait(ctx, g, l, s)
  else
    draw_back(g, l)
    center_text(g, l.w / 2, 16, "中国象棋", 15)
    g:text(l.margin + BACK_W + 8, 44, "双人对战", { color = 15 })
    g:text(l.w - l.margin - 140, 44, "第 " .. tostring(s.moves) .. " 手", { color = 15 })
    g:text(l.margin + BACK_W + 8, 66, s.message or "对弈中", { color = 15 })
    if s.status == "playing" and s.in_check then
      g:text(l.w - l.margin - 110, 66, "将军", { color = 15 })
    end
    g:line(l.margin, 88, l.w - l.margin, 88,{color=15})
  end

  draw_board(g, l, s)
  draw_hints(g, l, s)

  for r = 0, 9 do
    for c = 0, 8 do
      local ch = State.piece_at(s, r, c)
      if ch ~= State.EMPTY then draw_piece(g, l, s, r, c, ch) end
    end
  end
  draw_last(g, l, s)
  draw_check(g, l, s)

  if s.mode == "ai" or s.mode == "pvp" then
    local undo_ready = State.can_undo(s)
    local draw_x = l.margin + l.action_w + l.action_gap
    g:rect(l.margin, l.action_y, l.action_w, l.action_h,{fill=(undo_ready) and true or false,color=15})
    center_text(g, l.margin + l.action_w / 2, l.action_y + (l.action_h - CHAR_H) / 2, "悔棋", undo_ready and 0 or 15)
    g:rect(draw_x, l.action_y, l.action_w, l.action_h,{color=15})
    center_text(g, draw_x + l.action_w / 2, l.action_y + (l.action_h - CHAR_H) / 2, "求和", 15)
  end

  if s.mode == "pvp" then
    local undo_ready = State.can_undo(s)
    local draw_x = l.margin + l.action_w + l.action_gap
    local y = l.opponent_action_y
    g:rect(l.margin, y, l.action_w, l.action_h,{fill=(undo_ready) and true or false,color=15})
    center_text(g, l.margin + l.action_w / 2, y + (l.action_h - CHAR_H) / 2, "悔棋", undo_ready and 0 or 15)
    g:rect(draw_x, y, l.action_w, l.action_h,{color=15})
    center_text(g, draw_x + l.action_w / 2, y + (l.action_h - CHAR_H) / 2, "求和", 15)
  end

  local button_label = "新开一局"
  g:rect(l.margin, l.btn_y, l.btn_w, l.btn_h,{fill=true,color=15})
  center_text(g, l.margin + l.btn_w / 2, l.btn_y + (l.btn_h - CHAR_H) / 2, button_label, 0)
  if s.mode ~= "ai" then
    g:text(l.margin, l.h - l.margin - 18, "点选/方向键+OK · Back 返回", { color = 15 })
  end

  if s.status ~= "playing" then
    local oy = l.y0 + 40
    local overlay_h = 110
    g:rect(60, oy, l.w - 120, overlay_h,{fill=true,color=15})
    center_text(g, l.w / 2, oy + 30, s.message, 0)
    center_text(g, l.w / 2, oy + 62, "点「新开一局」或按 OK", 0)
  end
end

local function draw_menu_piece(g, cx, cy, label, focused)
  local fill = focused and 0 or 15
  local ink = focused and 15 or 0
  g:circle(cx, cy, 26,{fill=true,color=fill})
  g:circle(cx, cy, 26,{color=ink})
  g:circle(cx, cy, 21,{color=ink})
  g:text(cx - CHAR_W / 2, cy + PIECE_TEXT_DY, label, { color = ink })
end

local function draw_menu_item(g, s, index)
  local item = MENU_ITEMS[index]
  local focused = s.menuIdx == index
  local ink = focused and 0 or 15
  if focused then
    g:rect(MENU_X, item.y, MENU_W, item.h,{fill=true,color=15})
  else
    g:rect(MENU_X, item.y, MENU_W, item.h,{color=15})
  end
  draw_menu_piece(g, MENU_X + 44, item.y + item.h / 2, item.piece, focused)
  g:line(MENU_X + 86, item.y + 16, MENU_X + 86, item.y + item.h - 16,{color=ink})
  g:text(MENU_X + 112, item.y + 16, item.label, { color = ink })
  g:text(MENU_X + 112, item.y + 50, item.detail, { color = ink })
  g:text(MENU_X + MENU_W - 32, item.y + 32, ">", { color = ink })
end

local function draw_setup_piece(g, cx, cy, label, focused, locked)
  -- 锁定卡片呈现空心棋子徽章：盘面与背景同色，仅保留双环与子名。
  local fill = (locked or focused) and 0 or 15
  local ink = (focused or locked) and 15 or 0
  g:circle(cx, cy, 27,{fill=true,color=fill})
  g:circle(cx, cy, 27,{color=ink})
  g:circle(cx, cy, 22,{color=ink})
  g:text(cx - CHAR_W / 2, cy + PIECE_TEXT_DY, label, { color = ink })
end

local function draw_opponent_card(g, s, index)
  local item = SETUP_ITEMS[index]
  local opponent = OPPONENTS[index]
  local locked = M.setup_locked(index)
  local focused = s.setupIdx == index and not locked
  local ink = focused and 0 or 15
  if focused then
    g:rect(SETUP_X, item.y, SETUP_W, item.h,{fill=true,color=15})
  else
    g:rect(SETUP_X, item.y, SETUP_W, item.h,{color=15})
    g:line(SETUP_X + 6, item.y + 6, SETUP_X + 6, item.y + item.h - 6,{color=15})
  end
  draw_setup_piece(g, SETUP_X + 42, item.y + item.h / 2, opponent.piece, focused, locked)
  g:line(SETUP_X + 82, item.y + 14, SETUP_X + 82, item.y + item.h - 14,{color=ink})
  g:text(SETUP_X + 104, item.y + 18, opponent.label, { color = ink })
  g:text(SETUP_X + 104, item.y + 52, opponent.detail, { color = ink })
  if s.difficulty == index then
    g:text(SETUP_X + SETUP_W - 56, item.y + 18, "当前", { color = ink })
  elseif locked then
    g:text(SETUP_X + SETUP_W - 56, item.y + 18, "锁定", { color = ink })
  end
end

local function draw_setup_action(g, s)
  local item = SETUP_ITEMS[4]
  local opponent = OPPONENTS[s.difficulty] or OPPONENTS[1]
  -- 确认动作：始终渲染为实心主色条并复述将要确认的选择。
  g:rect(SETUP_X, item.y, SETUP_W, item.h,{fill=true,color=15})
  if s.setupIdx == 4 then
    g:rect(SETUP_X + 6, item.y + 6, SETUP_W - 12, item.h - 12,{color=0})
  end
  g:text(SETUP_X + 52, item.y + 10, "已选对手", { color = 0 })
  g:text(SETUP_X + 174, item.y + 10, opponent.label .. " · 执黑", { color = 0 })
  g:line(SETUP_X + 22, item.y + 34, SETUP_X + SETUP_W - 22, item.y + 34,{color=0})
  g:text(SETUP_X + 116, item.y + 44, "确认开局", { color = 0 })
  g:text(SETUP_X + 260, item.y + 44, "执红先行", { color = 0 })
end

function M.draw_menu(ctx, g, s)
  local l = M.layout(ctx, nil)
  g:clear(0)
  draw_back(g, l)
  g:text(MENU_X, 52, "楚河", { color = 15 })
  g:text(l.w - MENU_X - CHAR_W * 2, 52, "汉界", { color = 15 })
  g:line(MENU_X + CHAR_W * 3, 64, l.w - MENU_X - CHAR_W * 3, 64,{color=15})
  center_text(g, l.w / 2, 86, "中国象棋", 15)
  center_text(g, l.w / 2, 126, "红方先行  落子无悔", 15)
  g:line(MENU_X, 174, l.w - MENU_X, 174,{color=15})
  g:line(MENU_X + 36, 182, l.w - MENU_X - 36, 182,{color=15})
  center_text(g, l.w / 2, 206, "选择棋局", 15)

  for i = 1, #MENU_ITEMS do draw_menu_item(g, s, i) end
  g:line(MENU_X, 610, l.w - MENU_X, 610,{color=15})
  g:text(MENU_X, 638, "↑↓ 切换焦点  OK 进入", { color = 15 })
  g:text(MENU_X, 672, "触摸：点按整行选择", { color = 15 })
end

function M.draw_setup(ctx, g, s)
  local l = M.layout(ctx, nil)
  g:clear(0)
  draw_back(g, l)
  center_text(g, l.w / 2, 14, "对弈设定", 15)
  g:text(l.w - SETUP_X - CHAR_W * 4, 14, "红方先行", { color = 15 })
  g:line(SETUP_X, 54, l.w - SETUP_X, 54,{color=15})
  g:line(SETUP_X, 58, l.w - SETUP_X, 58,{color=15})
  center_text(g, l.w / 2, 84, "选择对手", 15)
  center_text(g, l.w / 2, 118, "三位棋手 三种棋风", 15)

  local opponent = OPPONENTS[s.difficulty] or OPPONENTS[1]
  local black_role = opponent.label .. "执黑"
  g:text(SETUP_X, 168, "本局阵营", { color = 15 })
  g:line(SETUP_X + CHAR_W * 5, 181, l.w - SETUP_X, 181,{color=15})
  g:text(SETUP_X, 198, "你执红", { color = 15 })
  center_text(g, l.w / 2, 198, "对阵", 15)
  g:text(l.w - SETUP_X - utf8_len(black_role) * CHAR_W, 198, black_role, { color = 15 })

  for i = 1, 3 do draw_opponent_card(g, s, i) end
  draw_setup_action(g, s)
  g:text(SETUP_X, 704, "↑↓ 切换焦点   OK 选择 / 开局", { color = 15 })
  g:text(SETUP_X, 738, "Back 返回上一级", { color = 15 })
end

function M.draw(ctx, g, s)
  if s.screen == "menu" then M.draw_menu(ctx, g, s)
  elseif s.screen == "setup" then M.draw_setup(ctx, g, s)
  else M.draw_game(ctx, g, s) end
end

return M
