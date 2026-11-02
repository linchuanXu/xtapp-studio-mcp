local Inventory = require("domain.game_inventory")
local Property = require("domain.property_rules")
local Rules = require("domain.rules")
local Board = require("domain.board")

local M = {}

M.center = { x = 92, y = 70, w = 616, h = 340 }

function M.board_cells()
  local cells = {}
  local top_w, side_h = 88, 70
  for index = 1, 9 do cells[index] = { x = 4 + (index - 1) * top_w, y = 4, w = top_w, h = 62 } end
  for offset = 1, 5 do cells[9 + offset] = { x = 708, y = 66 + (offset - 1) * side_h, w = 88, h = side_h } end
  for offset = 1, 9 do cells[14 + offset] = { x = 708 - (offset - 1) * top_w, y = 416, w = 88, h = 60 } end
  for offset = 1, 5 do cells[23 + offset] = { x = 4, y = 346 - (offset - 1) * side_h, w = 88, h = side_h } end
  return cells
end

local function button(id, x, y, w, h, label, selected, visible)
  return { id = id, x = x, y = y, w = w, h = h, label = label, selected = selected == true, visible = visible ~= false }
end

local function icon_button(id, x, y, w, h)
  local action = button(id, x, y, w, h, "")
  action.icon_only = true
  return action
end

local function centered_button_row(definitions, y, width, height, gap)
  local out, count = {}, #definitions
  local total = count * width + math.max(0, count - 1) * gap
  local start_x = 400 - math.floor(total / 2)
  for index, definition in ipairs(definitions) do
    out[#out + 1] = button(definition.id, start_x + (index - 1) * (width + gap), y, width, height, definition.label)
  end
  return out
end

function M.setup_avatar_slots(player_count)
  local slots = {}
  local function add_row(first, count, y)
    local gap, portrait_size = 16, 64
    local total_width = count * portrait_size + math.max(0, count - 1) * gap
    local start_x = 400 - math.floor(total_width / 2)
    for offset = 0, count - 1 do
      slots[#slots + 1] = { player = first + offset, x = start_x + offset * (portrait_size + gap), y = y, w = 64, h = 64 }
    end
  end
  if player_count <= 4 then add_row(1, player_count, 150)
  else add_row(1, 4, 126); add_row(5, player_count - 4, 198) end
  return slots
end

local KEYBOARD_ROWS = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
  { "z", "x", "c", "v", "b", "n", "m", "back" },
  { "space", "done", "close" },
}

local function key_label(key)
  if key == "back" then return "删除" end
  if key == "space" then return "空格" end
  if key == "done" then return "确定" end
  if key == "close" then return "取消" end
  return key
end

local function keyboard_actions()
  local out = {}
  local kb_x, kb_w, gap = 44, 712, 5
  for ri = 1, #KEYBOARD_ROWS do
    local row = KEYBOARD_ROWS[ri]
    local y = 232 + (ri - 1) * 44
    local widths = {}
    if ri == 4 then widths = { 316, 185, 185 }
    else
      local w = math.floor((kb_w - gap * (#row - 1)) / #row)
      for ci = 1, #row do widths[ci] = w end
    end
    local total = gap * (#row - 1)
    for ci = 1, #row do total = total + widths[ci] end
    local cursor = kb_x + math.floor((kb_w - total) / 2)
    for ci = 1, #row do
      out[#out + 1] = button("kb_" .. row[ci], cursor, y, widths[ci], 40, key_label(row[ci]))
      cursor = cursor + widths[ci] + gap
    end
  end
  return out
end

function M.edit_actions(state)
  local out = {}
  out[#out + 1] = button("edit_prev", 264, 108, 64, 52, "‹")
  out[#out + 1] = button("edit_next", 472, 108, 64, 52, "›")
  for _, action in ipairs(keyboard_actions()) do out[#out + 1] = action end
  return out
end

function M.game_menu_action(state)
  local ui, phase = state.ui or {}, state.phase
  if ui.overlay or phase == "setup" or phase == "handoff" or phase == "results" or phase == "moving" or phase == "trade" then return nil end
  return icon_button("open_game_menu", 648, 80, 48, 48)
end

function M.actions(state)
  local ui, phase = state.ui or {}, state.phase
  if ui.overlay == "game_menu" then
    if ui.restart_confirm then
      return {
        button("close_overlay", 154, 330, 220, 54, "取消"),
        button("restart_game", 426, 330, 220, 54, "确认重开"),
      }
    end
    return {
      button("close_overlay", 112, 286, 180, 48, "继续游戏"),
      button("game_menu_help", 310, 286, 180, 48, "查看规则"),
      button("game_menu_restart", 508, 286, 180, 48, "重新开始"),
      button("game_menu_cover", 220, 348, 360, 48, "返回主菜单"),
    }
  end
  if ui.overlay == "help" then return { button("close_overlay", 292, 342, 216, 52, "返回游戏") } end
  if ui.overlay == "assets" then
    local index, cursor, list = Inventory.selected(state, state.current, ui.asset_cursor)
    if not index then return { button("close_overlay", 292, 342, 216, 52, "返回游戏") } end
    local out = { button("close_overlay", 570, 330, 118, 52, "完成") }
    if cursor > 1 then
      out[#out + 1] = icon_button("asset_prev", 112, 88, 70, 48)
    end
    if cursor < #list then
      out[#out + 1] = icon_button("asset_next", 618, 88, 70, 48)
    end
    if phase ~= "debt_resolution" and Property.can_build(state, state.current, index) then out[#out + 1] = button("asset_build", 112, 330, 102, 52, "建设") end
    if state.mode == "classic" and Property.can_sell_building(state, state.current, index) then out[#out + 1] = button("asset_sell", 224, 330, 102, 52, "出售") end
    if state.mode == "classic" and Property.can_mortgage(state, state.current, index) then out[#out + 1] = button("asset_mortgage", 336, 330, 102, 52, "抵押") end
    local asset = state.assets[index]
    if state.mode == "classic" and phase ~= "debt_resolution" and asset.mortgaged and state.players[state.current].cash >= Property.unmortgage_cost(index) then
      out[#out + 1] = button("asset_unmortgage", 448, 330, 112, 52, "解押")
    end
    return out
  end
  if ui.trade_step == "target" then
    local out = { button("trade_cancel", 560, 340, 128, 50, "取消") }
    local row = 0
    for _, index in ipairs(Inventory.trade_targets(state, state.current)) do
      local player = state.players[index]
      local column = row % 3; local line = math.floor(row / 3)
      local target = button("trade_target_" .. tostring(index), 118 + column * 190, 132 + line * 62, 170, 50, player.name)
      target.avatar = player.token or index
      out[#out + 1] = target
      row = row + 1
    end
    return out
  end
  if phase == "trade" then
    if ui.trade_step == "confirm" then return { button("trade_accept", 220, 346, 160, 48, "接受交易"), button("trade_decline", 420, 346, 160, 48, "拒绝") } end
    local trade, out = state.pending, { button("trade_cancel", 420, 346, 160, 48, "取消") }
    local mine, theirs = Inventory.tradable(state, trade.from), Inventory.tradable(state, trade.to)
    local my_cursor = math.max(1, math.min(ui.trade_my_cursor or 1, math.max(1, #mine)))
    local their_cursor = math.max(1, math.min(ui.trade_their_cursor or 1, math.max(1, #theirs)))
    if #mine > 0 then
      if my_cursor > 1 then out[#out + 1] = button("trade_my_prev", 112, 188, 48, 48, "‹") end
      out[#out + 1] = button("trade_my_toggle", 166, 188, 156, 48, "选/取消")
      if my_cursor < #mine then out[#out + 1] = button("trade_my_next", 328, 188, 48, 48, "›") end
    end
    if #theirs > 0 then
      if their_cursor > 1 then out[#out + 1] = button("trade_their_prev", 424, 188, 48, 48, "‹") end
      out[#out + 1] = button("trade_their_toggle", 478, 188, 156, 48, "选/取消")
      if their_cursor < #theirs then out[#out + 1] = button("trade_their_next", 640, 188, 48, 48, "›") end
    end
    local cash = ui.trade_cash or 0
    local cash_owner = ui.trade_cash_side == "to" and trade.to or trade.from
    local cash_limit = math.max(0, state.players[cash_owner].cash)
    if cash > 0 then out[#out + 1] = button("trade_cash_minus", 112, 242, 72, 48, "-" .. tostring(math.min(50, cash))) end
    if state.players[trade.from].cash > 0 or state.players[trade.to].cash > 0 then
      out[#out + 1] = button("trade_cash_side", 190, 242, 104, 48, "换方向")
    end
    if cash < cash_limit then out[#out + 1] = button("trade_cash_plus", 300, 242, 72, 48, "+" .. tostring(math.min(50, cash_limit - cash))) end
    if state.players[trade.from].pass_cards > 0 then out[#out + 1] = button("trade_card_from", 428, 242, 120, 48, "我方卡") end
    if state.players[trade.to].pass_cards > 0 then out[#out + 1] = button("trade_card_to", 568, 242, 120, 48, "对方卡") end
    if Inventory.trade_has_value(trade) then out[#out + 1] = button("trade_propose", 220, 346, 160, 48, "提交交易") end
    return out
  end
  if phase == "setup" then
    if ui.editing_player then return M.edit_actions(state) end
    if (ui.setup_step or "cover") == "cover" then
      if ui.has_resume then
        return {
          button("menu_continue", 220, 332, 360, 56, "继续游戏"),
          button("menu_start", 220, 400, 360, 56, "新开一局"),
        }
      end
      return {
      button("menu_start", 220, 392, 360, 60, "开始游戏")
    } end
    local out = {
      button("menu_back", 112, 80, 82, 48, "返回"),
      button("mode_quick", 112, 276, 170, 52, "轻松局", state.setup.mode == "quick"),
      button("mode_classic", 294, 276, 170, 52, "经典局", state.setup.mode == "classic"),
      button("start_game", 112, 342, 576, 56, "开始游戏")
    }
    if state.setup.players > 2 then out[#out + 1] = button("players_minus", 112, 168, 54, 58, "－") end
    if state.setup.players < 8 then out[#out + 1] = button("players_plus", 634, 168, 54, 58, "＋") end
    if state.setup.mode == "quick" then
      if state.setup.rounds > 12 then out[#out + 1] = button("rounds_minus", 476, 276, 52, 52, "－") end
      if state.setup.rounds < 20 then out[#out + 1] = button("rounds_plus", 636, 276, 52, 52, "＋") end
    end
    for _, slot in ipairs(M.setup_avatar_slots(state.setup.players)) do
      out[#out + 1] = button("setup_avatar_" .. tostring(slot.player), slot.x, slot.y, slot.w, slot.h, "", false, false)
    end
    return out
  end
  if phase == "handoff" then return { button("handoff_ready", 220, 360, 360, 72, "我准备好了") } end
  if phase == "pre_roll" then
    local out = { button("roll", 270, 202, 260, 82, "点击掷骰子") }
    local secondary = {}
    if #Inventory.owned(state, state.current) > 0 then secondary[#secondary + 1] = { id = "open_assets", label = state.mode == "quick" and "我的地标" or "资产" } end
    if state.mode == "classic" and #Inventory.trade_targets(state, state.current) > 0 then secondary[#secondary + 1] = { id = "start_trade", label = "交易" } end
    secondary[#secondary + 1] = { id = "open_help", label = "规则" }
    for _, action in ipairs(centered_button_row(secondary, 326, 132, 52, 16)) do out[#out + 1] = action end
    return out
  end
  if phase == "checkpoint_decision" then
    if state.mode == "quick" then
      local definitions = { { id = "checkpoint_wait", label = "休整一回合" } }
      if state.players[state.current].cash >= 50 then table.insert(definitions, 1, { id = "checkpoint_pay", label = "支付50继续" }) end
      return centered_button_row(definitions, 306, 180, 58, 40)
    end
    local definitions = { { id = "checkpoint_roll", label = "尝试掷对子" } }
    if state.players[state.current].cash >= 50 then definitions[#definitions + 1] = { id = "checkpoint_pay", label = "支付50" } end
    if state.players[state.current].pass_cards > 0 then definitions[#definitions + 1] = { id = "checkpoint_card", label = "使用通行卡" } end
    return centered_button_row(definitions, 306, 160, 58, 28)
  end
  if phase == "property_offer" then
    if not (state.pending and state.pending.index) then return {} end
    local definitions = {}
    if state.players[state.current].cash >= Board.space(state.pending.index).price then
      definitions[#definitions + 1] = { id = "buy", label = "购买" }
    end
    if state.mode == "quick" then definitions[#definitions + 1] = { id = "skip_offer", label = "暂不购买" }
    else definitions[#definitions + 1] = { id = "auction", label = "公开竞拍" } end
    return centered_button_row(definitions, 322, 180, 60, 64)
  end
  if phase == "auction" then
    if not (state.pending and state.pending.kind == "auction" and state.pending.current_bidder) then return {} end
    local auction, definitions = state.pending, {}
    local cash = state.players[auction.current_bidder].cash
    local minimum = Rules.auction_minimum(state)
    if cash >= minimum then definitions[#definitions + 1] = { id = "auction_min", label = "出价" .. tostring(minimum) } end
    if cash >= minimum + 50 then definitions[#definitions + 1] = { id = "auction_50", label = "出价" .. tostring(minimum + 50) } end
    if cash >= minimum + 100 then definitions[#definitions + 1] = { id = "auction_100", label = "出价" .. tostring(minimum + 100) } end
    definitions[#definitions + 1] = { id = "auction_pass", label = "退出竞拍" }
    return centered_button_row(definitions, 334, 130, 56, 16)
  end
  if phase == "event" then return { button("draw_event", 220, 340, 360, 62, "翻开事件") } end
  if phase == "event_result" then return { button("finish_event", 270, 340, 260, 58, "知道了") } end
  if phase == "rent_result" then return { button("rent_done", 270, 350, 260, 54, "确认结算") } end
  if phase == "optional_actions" then
    local definitions = {}
    if #Inventory.owned(state, state.current) > 0 then definitions[#definitions + 1] = { id = "open_assets", label = state.mode == "quick" and "升级地标" or "管理资产" } end
    if state.mode == "classic" and #Inventory.trade_targets(state, state.current) > 0 then definitions[#definitions + 1] = { id = "start_trade", label = "交易" } end
    definitions[#definitions + 1] = { id = "end_turn", label = "结束回合" }
    definitions[#definitions + 1] = { id = "open_help", label = "规则" }
    return centered_button_row(definitions, 332, 130, 56, 16)
  end
  if phase == "debt_resolution" then
    if ui.bankruptcy_confirm then
      local cancel_label = Inventory.has_debt_action(state, state.current) and "返回整理" or "取消"
      return centered_button_row({
        { id = "bankruptcy_cancel", label = cancel_label },
        { id = "bankrupt", label = "确认破产" }
      }, 334, 190, 58, 104)
    end
    local definitions = {}
    if Inventory.has_debt_action(state, state.current) then definitions[#definitions + 1] = { id = "open_assets", label = "整理资产" } end
    definitions[#definitions + 1] = { id = "bankruptcy_prompt", label = "宣布破产" }
    return centered_button_row(definitions, 334, 190, 58, 104)
  end
  if phase == "results" then return { button("new_game", 220, 392, 360, 60, "再开一局") } end
  return {}
end

function M.hit(action, x, y)
  return x >= action.x and x <= action.x + action.w and y >= action.y and y <= action.y + action.h
end

return M
