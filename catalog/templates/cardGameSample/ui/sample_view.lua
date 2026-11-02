-- Sample presentation. It reads a projected view and never receives the full
-- match, which makes accidental hidden-card rendering impossible.

local Layout = require("ui.sample_layout")

local M = {}

local function text_units(value)
  local units, index = 0, 1
  value = tostring(value or "")
  while index <= #value do
    local byte = string.byte(value, index)
    units = units + ((byte or 0) < 128 and 1 or 2)
    index = index + (((byte or 0) < 128) and 1 or ((byte or 0) < 224 and 2 or ((byte or 0) < 240 and 3 or 4)))
  end
  return units
end

local function center(g, x, y, value, color)
  g:text(x - text_units(value) * 5, y, value, { color = color or 15 })
end

local function panel(g, x, y, width, height, fill)
  g:rect(x, y, width, height,{fill=true,color=fill or 0})
  g:rect(x, y, width, height,{color=15})
end

local function button(g, box, label, enabled)
  panel(g, box.x, box.y, box.w, box.h, enabled and 0 or 3)
  center(g, box.x + math.floor(box.w / 2), box.y + 16, label, 15)
end

local function card(g, x, y, visible, selected)
  if selected then y = y - 12 end
  panel(g, x, y, Layout.CARD_W, Layout.CARD_H, 0)
  if not visible then
    g:rect(x + 8, y + 8, Layout.CARD_W - 16, Layout.CARD_H - 16,{color=15})
    center(g, x + math.floor(Layout.CARD_W / 2), y + 42, "墨", 15)
    return
  end
  local p = visible.presentation or {}
  g:text(x + 8, y + 8, tostring(p.cost or 0), { color = 15 })
  center(g, x + math.floor(Layout.CARD_W / 2), y + 36, p.mark or "?", 15)
  center(g, x + math.floor(Layout.CARD_W / 2), y + 68, (p.name or "?") .. tostring(p.amount or ""), 15)
end

local function draw_player(g, player, x, y, active)
  local public = player.public or {}
  if active then g:rect(x - 8, y - 8, 248, 74,{color=15}) end
  g:text(x, y, tostring(public.name or "玩家"), { color = 15 })
  g:text(x, y + 26, "命 " .. tostring(public.health or 0) .. "  护 " .. tostring(public.armor or 0) .. "  墨 " .. tostring(public.energy or 0), { color = 15 })
end

function M.draw_menu(g)
  g:clear(0)
  center(g, 400, 82, "卡牌游戏样例", 15)
  center(g, 400, 126, "通用运行时 · 规则插件 · 信息隔离", 15)
  panel(g, 142, 186, 516, 94, 0)
  center(g, 400, 206, "样例玩法：墨牌试局", 15)
  center(g, 400, 242, "出牌消耗墨力，把纸偶的命降到零", 15)
  button(g, Layout.compute(0).start, "开始样例局", true)
  center(g, 400, 420, "核心不内置血量、花色、下注或胜负规则", 15)
end

function M.draw_game(g, view, selected_id, message)
  g:clear(0)
  center(g, 400, 12, "墨牌试局 · 第 " .. tostring(view.turn.round or 1) .. " 回", 15)
  local active = view.turn.active_player
  draw_player(g, view.players[2], 28, 52, active == 2)
  local ai_hand = view.zones.p2_hand
  g:text(310, 56, "对手手牌 " .. tostring(ai_hand and ai_hand.count or 0), { color = 15 })
  for index = 1, math.min(5, ai_hand and ai_hand.count or 0) do card(g, 430 + (index - 1) * 42, 44, nil, false) end

  g:line(20, 172, 780, 172,{color=15})
  local human = view.players[1]
  draw_player(g, human, 28, 202, active == 1)
  center(g, 400, 198, active == 1 and "你的回合" or "纸偶正在行动", 15)
  center(g, 400, 242, message or "选择一张牌，或直接收笔结束回合", 15)

  local hand = view.zones.p1_hand
  local layout = Layout.compute(hand and hand.count or 0)
  for index, visible in ipairs(hand and hand.cards or {}) do
    card(g, layout.hand.x + (index - 1) * layout.hand.step, layout.hand.y, visible, visible.id == selected_id)
  end
  button(g, layout.play, "打出", active == 1 and selected_id ~= nil)
  button(g, layout.finish, "收笔", active == 1)
end

function M.draw_result(g, view)
  g:clear(0)
  local won = view.winner == 1
  center(g, 400, 88, won and "试局获胜" or "试局落败", 15)
  center(g, 400, 140, won and "你的规则与行动顺利跑完整局" or "纸偶先完成了这场规则验证", 15)
  panel(g, 174, 206, 452, 94, 0)
  center(g, 400, 228, "状态修订 " .. tostring(view.revision or 0), 15)
  center(g, 400, 260, "所有行动均经过校验、事务提交与事件输出", 15)
  local layout = Layout.compute(0)
  button(g, layout.home, "返回首页", true)
  button(g, layout.again, "再试一局", true)
end

return M
