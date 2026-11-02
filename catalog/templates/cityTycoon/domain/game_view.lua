local PkgImage = require("pkg_image")
local Board = require("domain.board")
local Inventory = require("domain.game_inventory")
local Layout = require("domain.game_layout")
local Patterns = require("domain.game_patterns")
local Property = require("domain.property_rules")
local Visuals = require("domain.game_visuals")

local M = {}

-- Layout coordinates use the firmware font's visual baseline. g:text receives the
-- glyph box's top edge, so compensate once here instead of nudging every screen.
local TEXT_TOP_OFFSET = -16
local ART_CAPTION_GAP = 12
local ART_HEIGHT = { landmark = 176, event = 190, special = 126 }
local function text(g, x, y, value, color) g:text(x, y + TEXT_TOP_OFFSET, tostring(value), { color = color or 15 }) end

-- 1bpp API 只提供 g:rect 与 g:circle。用四角圆 + 主体矩形拼出任意尺寸的圆角
-- 卡片/按钮：fill 模式同色叠加无痕，stroke 模式由四条边与四段圆弧自然衔接。
local function corner_radius(height)
  return math.max(6, math.min(14, math.floor(height / 4)))
end

-- 圆角矩形：radius 可选，缺省按高度推导；0 为直角。
local function rounded_rect(g, x, y, w, h, mode, color, radius)
  local r = radius == nil and corner_radius(h) or math.max(0, radius or 0)
  if mode == "fill" then
    -- 十字形主体：横竖两条矩形，四角由同色圆补齐；角部圆形之外露出背景色，
    -- 才是真正的圆角填充（全铺矩形会把角盖成直角）。
    g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
    g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
    g:circle(x + r, y + r, r,{fill=true,color=color})
    g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
    g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
    g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
  else
    -- 1bpp API 的 g:circle stroke 画的是完整圆环而非圆弧，直接画四角会出现
    -- 按钮内部的小圆圈。描边改用差集：先铺深色大圆角，再叠背景色内缩圆角，
    -- 留下均匀外框；内缩圆角半径与外圆角同心，保证四角仍是平滑圆弧。
    local fill_color = color or 15
    local inset_color = fill_color == 15 and 0 or 15
    local inset = 2
    local ri = math.max(4, r - inset)
    -- 外框：与外圆角同尺寸的深色圆角
    g:rect(x + r, y, w - r * 2, h,{fill=true,color=fill_color})
    g:rect(x, y + r, w, h - r * 2,{fill=true,color=fill_color})
    g:circle(x + r, y + r, r,{fill=true,color=fill_color})
    g:circle(x + w - 1 - r, y + r, r,{fill=true,color=fill_color})
    g:circle(x + r, y + h - 1 - r, r,{fill=true,color=fill_color})
    g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=fill_color})
    -- 内缩圆角：整体内移 inset，圆心与外圆角同心（右下用 w-1-r / h-1-r），
    -- 半径 ri = r - inset，留下均匀 inset 宽的边框。
    g:rect(x + r, y + inset, w - r * 2, h - inset * 2,{fill=true,color=inset_color})
    g:rect(x + inset, y + r, w - inset * 2, h - r * 2,{fill=true,color=inset_color})
    g:circle(x + r, y + r, ri,{fill=true,color=inset_color})
    g:circle(x + w - 1 - r, y + r, ri,{fill=true,color=inset_color})
    g:circle(x + r, y + h - 1 - r, ri,{fill=true,color=inset_color})
    g:circle(x + w - 1 - r, y + h - 1 - r, ri,{fill=true,color=inset_color})
  end
end

local function panel(g, x, y, w, h) rounded_rect(g, x, y, w, h, "fill", 0); rounded_rect(g, x, y, w, h, "stroke", 15) end
-- 设备 system_font_medium 字形 advance（来自 IDF u8g2-font-dump metrics.json）：
-- 中文全角 24px；ASCII 按字形精确 advance（空格 7、数字 12-15、字母 7-24）；
-- "·" 5px；未收录字符按全角 24px 兜底。
local FONT_ADVANCE = {
  [32]=7, [33]=5, [34]=10, [35]=17, [36]=15, [37]=21, [38]=18, [39]=5,
  [40]=9, [41]=9, [42]=10, [43]=15, [44]=7, [45]=9, [46]=5, [47]=14,
  [48]=15, [49]=12, [50]=13, [51]=14, [52]=15, [53]=14, [54]=14, [55]=13,
  [56]=14, [57]=14, [58]=5, [59]=7, [60]=13, [61]=13, [62]=13, [63]=13,
  [64]=23, [65]=17, [66]=16, [67]=16, [68]=18, [69]=15, [70]=14, [71]=18,
  [72]=18, [73]=13, [74]=15, [75]=17, [76]=14, [77]=20, [78]=19, [79]=19,
  [80]=15, [81]=19, [82]=17, [83]=15, [84]=15, [85]=18, [86]=17, [87]=24,
  [88]=17, [89]=16, [90]=15, [91]=10, [92]=14, [93]=10, [94]=14, [95]=16,
  [96]=12, [97]=16, [98]=16, [99]=13, [100]=16, [101]=14, [102]=10, [103]=16,
  [104]=15, [105]=8, [106]=7, [107]=14, [108]=7, [109]=23, [110]=15, [111]=15,
  [112]=16, [113]=16, [114]=10, [115]=12, [116]=9, [117]=15, [118]=14, [119]=19,
  [120]=14, [121]=14, [122]=12, [123]=10, [124]=7, [125]=10, [126]=13, [0xB7]=5,
}
local function text_width(value)
  local width, index, string_value = 0, 1, tostring(value)
  while index <= #string_value do
    local byte = string.byte(string_value, index)
    if byte < 128 then
      width = width + (FONT_ADVANCE[byte] or 24)
      index = index + 1
    elseif byte < 224 then
      -- 2 字节字符：仅"·"(0xC2 0xB7) 收录为 5px，其余按全角 24px
      if byte == 0xC2 and string.byte(string_value, index + 1) == 0xB7 then
        width = width + 5
      else
        width = width + 24
      end
      index = index + 2
    else
      width = width + 24 -- 中文全角
      index = index + 3
    end
  end
  return width
end

local function centered_text(g, x, y, w, value, color)
  text(g, x + math.max(0, math.floor((w - text_width(value)) / 2)), y, value, color)
end

local TOKEN_SIZES = { default = 32, large = 64, hero = 128 }
local function draw_player_token(g, state, player_index, x, y, size)
  local player = state.players[player_index]
  local token_size = TOKEN_SIZES[size or "default"]
  local badge_size = size == "hero" and 32 or size == "large" and 24 or 16
  PkgImage.draw(g, Visuals.token(player.token or player_index, size), x, y)
  if badge_size == 16 then
    PkgImage.draw(g, Visuals.player_marker(player_index), x + token_size - 16, y + token_size - 16)
  else
    local badge_x, badge_y = x + token_size - badge_size, y + token_size - badge_size
    g:rect(badge_x, badge_y, badge_size, badge_size,{fill=true,color=15})
    centered_text(g, badge_x, badge_y + math.floor(badge_size / 2) + 6, badge_size, tostring(player_index), 0)
  end
end

local PRIMARY_ACTIONS = {
  menu_start = true, menu_continue = true, start_game = true, handoff_ready = true, roll = true, buy = true,
  auction_min = true, draw_event = true, finish_event = true,
  end_turn = true, trade_propose = true, trade_accept = true, new_game = true,
}

local function draw_button(g, action)
  -- 封面"开始游戏"主按钮：干净白底素材（纯白+圆角+黑描边+黑字）。
  -- 1bpp 素材白像素不覆盖背景，先以一条整块 g:rect fill 0 涂白垫底
  -- （单条命令、不逐点、CPU 零压力），再贴素材黑区（描边/文字/图标）。
  if action.id == "menu_start" and action.label == "开始游戏" then
    -- 圆角白底垫底（rounded_rect 由几条 rect + 4 个 circle 拼出，非逐点），
    -- 与素材圆角对齐，四角不会跃出圆角描边；再贴素材黑区。
    rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0)
    PkgImage.draw(g, "ui_btn_menu_start", action.x, action.y)
    return
  end
  -- 设置页按钮：文字烧入素材。白底款先圆角垫白再贴；选中款（黑底白字）直接贴。
  -- 加减按钮按热区分尺寸：players(54x58) 用大号、rounds(52x52) 用小号。
  local setup_asset = {
    menu_back = "ui_btn_back",
    mode_quick = action.selected == true and "ui_btn_mode_quick_sel" or "ui_btn_mode_quick",
    mode_classic = action.selected == true and "ui_btn_mode_classic_sel" or "ui_btn_mode_classic",
    start_game = "ui_btn_start_game",
    players_minus = "ui_btn_minus",
    players_plus = "ui_btn_plus",
    rounds_minus = "ui_btn_minus_small",
    rounds_plus = "ui_btn_plus_small",
  }
  local setup_key = setup_asset[action.id]
  if setup_key then
    if action.selected ~= true then
      rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0)
    end
    PkgImage.draw(g, setup_key, action.x, action.y)
    return
  end
  -- 主操作按钮：白底粗描边素材（区别于次操作细描边）。
  -- 图标按钮：方形白底 + IconPark 图标素材，无文字。
  local primary_asset = {
    roll = "ui_btn_roll",
    buy = "ui_btn_buy",
    draw_event = "ui_btn_draw_event",
    finish_event = "ui_btn_finish_event",
    rent_done = "ui_btn_rent_done",
    trade_accept = "ui_btn_trade_accept",
    handoff_ready = "ui_btn_handoff_ready",
  }
  local primary_key = primary_asset[action.id]
  if primary_key then
    rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0)
    PkgImage.draw(g, primary_key, action.x, action.y)
    return
  end
  -- "结束回合"：黑底白字特殊强调（反色主操作），黑像素覆盖背景，直接贴。
  if action.id == "end_turn" then
    PkgImage.draw(g, "ui_btn_end_turn", action.x, action.y)
    return
  end
  local icon_asset = {
    asset_prev = "ui_btn_prev",
    asset_next = "ui_btn_next",
    open_game_menu = "ui_btn_menu",
  }
  local icon_key = icon_asset[action.id]
  if icon_key then
    rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0)
    PkgImage.draw(g, icon_key, action.x, action.y)
    return
  end
  -- 次操作按钮：白底细描边固定文字素材。close_overlay 文字多变，按 label 分派。
  local secondary_asset = {
    asset_build = "ui_btn_asset_build",
    asset_sell = "ui_btn_asset_sell",
    asset_mortgage = "ui_btn_asset_mortgage",
    asset_unmortgage = "ui_btn_asset_unmortgage",
    trade_decline = "ui_btn_trade_decline",
  }
  local secondary_key = secondary_asset[action.id]
  if not secondary_key then
    if action.id == "close_overlay" then
      if action.label == "完成" then secondary_key = "ui_btn_asset_done"
      elseif action.label == "继续游戏" then secondary_key = "ui_btn_continue"
      elseif action.label == "返回游戏" then secondary_key = "ui_btn_back_game"
      else secondary_key = "ui_btn_close" end
    elseif action.id == "trade_cancel" then secondary_key = action.w >= 150 and "ui_btn_trade_cancel_160" or "ui_btn_trade_cancel" end
  end
  if secondary_key then
    rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0)
    PkgImage.draw(g, secondary_key, action.x, action.y)
    return
  end
  local cover_action = action.id == "menu_start" or action.id == "menu_continue"
  local primary = PRIMARY_ACTIONS[action.id] == true
  local icon = Visuals.action_icons[action.id]
  local trade_target = string.match(action.id, "^trade_target_(%d+)$")
  if trade_target then icon = Visuals.token(action.avatar or tonumber(trade_target)) end
  -- 浅色优先：全部白底。主操作粗描边（4px），次操作细描边（2px）。
  if cover_action then rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0); rounded_rect(g, action.x, action.y, action.w, action.h, "stroke", 15)
  else
    rounded_rect(g, action.x, action.y, action.w, action.h, "fill", 0)
    if primary then
      -- 主操作粗描边：外粗框 + 内细线
      rounded_rect(g, action.x + 2, action.y + 2, action.w - 4, action.h - 4, "stroke", 15)
      rounded_rect(g, action.x, action.y, action.w, action.h, "stroke", 15)
    else
      rounded_rect(g, action.x, action.y, action.w, action.h, "stroke", 15)
    end
  end
  local text_x, text_w = action.x, action.w
  if icon then
    local icon_x = action.icon_only and action.x + math.floor((action.w - 24) / 2) or action.x + 10
    PkgImage.draw(g, icon, icon_x, action.y + math.floor((action.h - 24) / 2))
    if not action.icon_only then text_x, text_w = action.x + 32, action.w - 36 end
  end
  if action.label ~= "" then centered_text(g, text_x, action.y + math.floor(action.h / 2) + 6, text_w, action.label, 15) end
end

local function draw_screen_actions(g, state)
  for _, action in ipairs(Layout.actions(state)) do if action.visible ~= false then draw_button(g, action) end end
end

local function draw_game_menu_button(g, state)
  local action = Layout.game_menu_action(state)
  if action then draw_button(g, action) end
end

local function draw_handoff_screen(g, state)
  local player = state.players[state.current]
  draw_player_token(g, state, state.current, 336, 58, "hero")
  centered_text(g, 0, 224, 800, "轮到 " .. player.name)
  centered_text(g, 0, 262, 800, "点击下方按钮，开始这一回合")
end

local function draw_results_screen(g, state)
  local winner = state.results and state.results[1]
  PkgImage.draw(g, "result_trophy", 310, 24)
  centered_text(g, 0, 142, 800, winner and ("冠军 · " .. winner.name) or "城市经营者排名")
  if winner then centered_text(g, 0, 170, 800, "冠军净资产 · " .. tostring(winner.worth)) end
  local count = math.min(8, #(state.results or {}))
  if count <= 4 then
    local start_y = 194 + math.floor((4 - count) * 21)
    for index, row in ipairs(state.results or {}) do
      if index <= count then
        draw_player_token(g, state, row.player, 230, start_y + (index - 1) * 42)
        text(g, 264, start_y + 20 + (index - 1) * 42, "第" .. tostring(row.rank) .. "名  " .. row.name .. "  净资产 " .. tostring(row.worth))
      end
    end
    return
  end
  local rows = math.ceil(count / 2)
  local start_y = 194 + math.floor((4 - rows) * 21)
  for index, row in ipairs(state.results or {}) do
    if index <= count then
      local column = index > rows and 1 or 0
      local line = column == 0 and (index - 1) or (index - rows - 1)
      draw_player_token(g, state, row.player, 116 + column * 344, start_y + line * 42)
      text(g, 150 + column * 344, start_y + 20 + line * 42, "第" .. tostring(row.rank) .. "名  " .. row.name .. "  净资产 " .. tostring(row.worth))
    end
  end
end

local function draw_setup_roster(g, state)
  for _, slot in ipairs(Layout.setup_avatar_slots(state.setup.players)) do
    local token = (state.setup.tokens and state.setup.tokens[slot.player]) or slot.player
    rounded_rect(g, slot.x - 2, slot.y - 2, 68, 68, "fill", 0)
    rounded_rect(g, slot.x - 2, slot.y - 2, 68, 68, "stroke", 15)
    PkgImage.draw(g, Visuals.token(token, "large"), slot.x, slot.y)
    rounded_rect(g, slot.x + 44, slot.y + 42, 22, 22, "fill", 15)
    centered_text(g, slot.x + 44, slot.y + 58, 22, tostring(slot.player), 0)
  end
end

local function draw_edit_player(g, state)
  local ui, setup = state.ui or {}, state.setup
  local player_index = ui.editing_player
  centered_text(g, 92, 90, 616, "编辑 " .. tostring(player_index) .. "号玩家")
  local token = ui.edit_token or (setup.tokens and setup.tokens[player_index]) or player_index
  PkgImage.draw(g, Visuals.token(token, "large"), 368, 106)
  g:rect(424, 154, 22, 22,{fill=true,color=15})
  centered_text(g, 424, 170, 22, tostring(player_index), 0)
  local name = ui.edit_name or ""
  rounded_rect(g, 200, 178, 400, 44, "stroke", 15)
  local display = name ~= "" and (name .. "_") or (tostring(player_index) .. "号玩家")
  centered_text(g, 200, 206, 400, display, 15)
end

local function draw_board(g, state)
  for index, cell in ipairs(Layout.board_cells()) do
    local space, asset = Board.space(index), state.assets and state.assets[index]
    local tokens = {}
    for player_index, player in ipairs(state.players or {}) do
      if not player.bankrupt and player.position == index then tokens[#tokens + 1] = player_index end
    end
    -- 格子统一圆角方块（恢复默认形态）
    rounded_rect(g, cell.x, cell.y, cell.w, cell.h, "stroke", 15)
    PkgImage.draw(g, Visuals.space_icon(index), cell.x + 4, cell.y + 8)
    text(g, cell.x + 40, cell.y + 20, Board.labels[index])
    if asset and asset.owner then
      PkgImage.draw(g, Visuals.owner_marker(asset.owner), cell.x + 4, cell.y + cell.h - 18)
    end
    if #tokens == 0 then
      if asset and asset.owner then
        if asset.mortgaged then text(g, cell.x + 40, cell.y + 42, "已抵押") end
        if asset.level > 0 then PkgImage.draw(g, Visuals.building_badge(asset.level), cell.x + cell.w - 28, cell.y + cell.h - 24) end
      elseif space.price then text(g, cell.x + 40, cell.y + 42, "$" .. tostring(space.price))
      elseif space.kind ~= "property" then text(g, cell.x + 40, cell.y + 42, ({ transit = "车站", utility = "公用", event = "事件", tax = "税务", park = "休息", checkpoint = "停留", start = "+200" })[space.kind] or "") end
    end
    for token_row, player_index in ipairs(tokens) do
      local offset = token_row - 1
      local tx = cell.x + 22 + (offset % 4) * 16
      local ty = cell.y + cell.h - 18 - math.floor(offset / 4) * 16
      if player_index == state.current then
        rounded_rect(g, tx - 2, ty - 2, 20, 20, "fill", 0)
        rounded_rect(g, tx - 2, ty - 2, 20, 20, "stroke", 15)
      end
      PkgImage.draw(g, Visuals.player_marker(player_index), tx, ty)
    end
  end
end

local function current_summary(g, state)
  local player = state.players and state.players[state.current]
  if not player then return end
  -- 默认名"N号玩家"缩写为"N号"，自定义名保持原样
  local short_name = string.match(player.name or "", "^(%d+)号玩家$")
  local display_name = short_name and (short_name .. "号") or (player.name or "")
  local summary_text = display_name .. "  $" .. tostring(player.cash) .. "  第" .. tostring(state.round) .. "轮"
  draw_player_token(g, state, state.current, 112, 78)
  -- 状态行白底自适应：从左侧(100)到文字末尾，宽度按文字实时计算
  local badge_w = math.max(200, 46 + text_width(summary_text) + 14)
  rounded_rect(g, 100, 70, badge_w, 44, "fill", 0)
  rounded_rect(g, 100, 70, badge_w, 44, "stroke", 15)
  text(g, 146, 96, summary_text)
end

local function art_top_for_caption(caption_baseline, art_height)
  return caption_baseline + TEXT_TOP_OFFSET - ART_CAPTION_GAP - art_height
end

-- 资产格报价/竞拍使用全幅卡面铺满面板，默认状态行（白底+文字）会被卡面盖住并透出，
-- 因此这些分支跳过默认 current_summary，由卡面上的自适应徽章承担状态行。
local function full_card(state)
  if not (state.phase == "property_offer" or state.phase == "auction") then return false end
  local index = state.pending and state.pending.index
  return index ~= nil and Board.is_asset(Board.space(index))
end

-- 全幅卡面左上角的状态徽章：只包住文字，不遮挡卡面背景图
local function full_card_badge(g, state)
  local player = state.players[state.current]
  local short_name = string.match(player.name or "", "^(%d+)号玩家$")
  local display_name = short_name and (short_name .. "号") or (player.name or "")
  local summary_text = display_name .. "  $" .. tostring(player.cash) .. "  第" .. tostring(state.round) .. "轮"
  local badge_w = math.max(200, 46 + text_width(summary_text) + 14)
  rounded_rect(g, 100, 70, badge_w, 44, "fill", 0)
  rounded_rect(g, 100, 70, badge_w, 44, "stroke", 15)
  draw_player_token(g, state, state.current, 112, 78)
  text(g, 146, 96, summary_text)
end

-- 全幅卡面下部悬浮的信息条：白底围绕文字自适应居中
local function full_card_caption(g, line)
  local line_w = text_width(line) + 32
  local line_x = 92 + math.floor((616 - line_w) / 2)
  rounded_rect(g, line_x, 250, line_w, 44, "fill", 0)
  rounded_rect(g, line_x, 250, line_w, 44, "stroke", 15)
  centered_text(g, 92, 280, 616, line, 15)
end

local OWNED_KINDS = { property = true, transit = true, utility = true }

local function draw_landmark_art(g, index, space, x, caption_baseline)
  if space and OWNED_KINDS[space.kind] then
    PkgImage.draw(g, Visuals.landmark_art(index), x, art_top_for_caption(caption_baseline, ART_HEIGHT.landmark))
    return true
  end
  return false
end

local function draw_last_roll(g, state)
  if not state.last_roll then return end
  PkgImage.draw(g, "dice_" .. tostring(state.last_roll.a), 316, 126)
  PkgImage.draw(g, "dice_" .. tostring(state.last_roll.b), 412, 126)
end

local function draw_big_amount(g, x, y, amount)
  local digits = tostring(math.max(0, math.floor(amount or 0)))
  local digit_w, digit_h, gap = 40, 58, 4
  local total = #digits * digit_w + math.max(0, #digits - 1) * gap
  local cursor = x + math.max(0, math.floor((568 - total) / 2))
  for index = 1, #digits do
    PkgImage.draw(g, "fund_digit_" .. digits:sub(index, index), cursor, y, { invert = true })
    cursor = cursor + digit_w + gap
  end
end

local function draw_banner(g, state)
  local banner = state.ui and state.ui.banner
  if not banner then return false end
  local x, y, w = 116, 118, 568
  if banner.amount and banner.amount > 0 then
    rounded_rect(g, x, y, w, 118, "fill", 15)
    centered_text(g, x, y + 26, w, banner.title, 0)
    draw_big_amount(g, x, y + 48, banner.amount)
  else
    rounded_rect(g, x, y, w, 96, "fill", 15)
    centered_text(g, x, y + 30, w, banner.title, 0)
    centered_text(g, x, y + 64, w, banner.text or "", 0)
  end
  return true
end

local function action_hint(state)
  local hints = {}
  if Inventory.has_buildable(state, state.current) then
    hints[#hints + 1] = state.mode == "quick" and "升级地标" or "建设地产"
  end
  if state.mode == "classic" and #Inventory.trade_targets(state, state.current) > 0 then
    hints[#hints + 1] = "发起交易"
  end
  return #hints > 0 and ("现在可以：" .. table.concat(hints, " / ")) or nil
end

local function draw_overlay(g, state)
  local ui = state.ui or {}; panel(g, 92, 70, 616, 340)
  if ui.overlay == "help" then
    local function rule_row(y, label, description)
      rounded_rect(g, 116, y - 24, 72, 30, "fill", 15)
      centered_text(g, 116, y, 72, label, 0)
      text(g, 208, y, description)
    end
    PkgImage.draw(g, Visuals.action_icons.open_help, 116, 88)
    text(g, 150, 108, "城镇大亨 · 规则")
    Patterns.divider_h(g, 116, 126, 568)
    if state.mode == "quick" then
      rule_row(158, "回合", "掷骰前进，落地后购买或自动结算")
      rule_row(198, "地标", "任意自有地标可直接升级，最高二级")
      rule_row(238, "资金", "不足时自动出售最低价值资产，不会淘汰")
    else
      rule_row(158, "回合", "掷两枚骰子前进，落地后购买或结算")
      rule_row(198, "地产", "集齐街区后，可均衡建设三级建筑")
      rule_row(238, "资金", "不足时出售或抵押，仍无法偿还才破产")
    end
    rule_row(278, "胜负", state.mode == "quick" and ("第" .. tostring(state.round_limit) .. "轮后按净资产排名") or "坚持到最后一位未破产玩家")
    return
  end
  if ui.overlay == "game_menu" then
    rounded_rect(g, 116, 86, 132, 36, "fill", 15)
    centered_text(g, 116, 110, 132, "本局设置", 0)
    Patterns.divider_h(g, 116, 138, 568)
    if ui.restart_confirm then
      centered_text(g, 116, 196, 568, "重新开始本局？")
      centered_text(g, 116, 232, 568, "当前进度将丢失，玩家设置会保留")
    else
      centered_text(g, 116, 196, 568, "可随时继续游戏、查看规则或重新开始")
      centered_text(g, 116, 232, 568, "重新开始会保留人数、头像、模式与回合数")
    end
    return
  end
  if ui.overlay == "assets" then
    local index, cursor, list = Inventory.selected(state, state.current, ui.asset_cursor)
    if index then centered_text(g, 182, 116, 436, "资产 " .. tostring(cursor) .. "/" .. tostring(#list))
    else centered_text(g, 92, 126, 616, "资产管理") end
    if index then
      local space, asset = Board.space(index), state.assets[index]
      text(g, 132, 166, space.name)
      if state.mode == "quick" then
        text(g, 132, 198, "购入 " .. tostring(space.price) .. " · 自动出售 " .. tostring(Property.liquidation_value(state, index)))
        text(g, 132, 230, "状态：建筑等级 " .. tostring(asset.level) .. (space.kind == "property" and "/2" or ""))
      else
        local finance = asset.mortgaged and ("解押 " .. tostring(Property.unmortgage_cost(index))) or ("抵押 " .. tostring(Property.mortgage_value(index)))
        text(g, 132, 198, "购入 " .. tostring(space.price) .. " · " .. finance)
        text(g, 132, 230, asset.mortgaged and "状态：已抵押" or ("状态：建筑等级 " .. tostring(asset.level)))
      end
      if space.kind == "property" then
        text(g, 132, 262, Board.districts[space.district].name)
        text(g, 132, 294, "建设费 " .. tostring(Board.build_costs[space.district]))
        draw_landmark_art(g, index, space, 328, 346)
      else
        text(g, 132, 262, "类型 · " .. (({ transit = "车站", utility = "公共设施" })[space.kind] or "资产"))
        draw_landmark_art(g, index, space, 328, 346)
      end
    else
      centered_text(g, 92, 210, 616, "当前还没有资产")
      centered_text(g, 92, 246, 616, state.mode == "quick" and "购买地标后，可以在这里查看和升级" or "购买地产、车站或公共设施后，可以在这里管理")
    end
    return
  end
end

local function trade_asset_summary(state, indexes)
  if not indexes or #indexes == 0 then return "无" end
  if #indexes == 1 then return Board.space(indexes[1]).name end
  -- The currently focused asset is already shown above. Keeping every name in
  -- the bottom receipt made the right column collide with its edge on large
  -- trades, so summarize multi-item selections by count here.
  return tostring(#indexes) .. "项地标"
end

local function candidate_text(state, values, cursor, selected)
  if #values == 0 then return "无可交易资产" end
  local index = values[math.max(1, math.min(cursor or 1, #values))]
  local mark = ""
  for _, chosen in ipairs(selected or {}) do if chosen == index then mark = " [已选]" end end
  return Board.space(index).name .. mark
end

local function candidate_index(values, cursor)
  if #values == 0 then return nil end
  return values[math.max(1, math.min(cursor or 1, #values))]
end

local function draw_trade(g, state)
  local ui, trade = state.ui or {}, state.pending
  panel(g, 92, 70, 616, 340)
  if ui.trade_step == "target" then text(g, 116, 108, "选择交易对象"); return end
  local heading = ui.trade_step == "confirm" and "请接收方确认交易" or "编辑交易提案"
  if ui.trade_step ~= "confirm" and not Inventory.trade_has_value(trade) then heading = heading .. " · 请先加入交易内容" end
  text(g, 116, 108, heading)
  if trade then
    local mine, theirs = Inventory.tradable(state, trade.from), Inventory.tradable(state, trade.to)
    local mine_index, their_index = candidate_index(mine, ui.trade_my_cursor), candidate_index(theirs, ui.trade_their_cursor)
    Patterns.divider_v(g, 400, 116, 118)
    draw_player_token(g, state, trade.from, 116, 116, "large")
    text(g, 190, 138, "我方  " .. state.players[trade.from].name)
    if mine_index then PkgImage.draw(g, Visuals.space_icon(mine_index), 190, 146) end
    text(g, mine_index and 226 or 190, 166, candidate_text(state, mine, ui.trade_my_cursor, trade.assets_from))
    draw_player_token(g, state, trade.to, 428, 116, "large")
    text(g, 502, 138, "对方  " .. state.players[trade.to].name)
    if their_index then PkgImage.draw(g, Visuals.space_icon(their_index), 502, 146) end
    text(g, their_index and 538 or 502, 166, candidate_text(state, theirs, ui.trade_their_cursor, trade.assets_to))
    Patterns.divider_h(g, 116, 296, 568)
    text(g, 116, 322, "给出 " .. trade_asset_summary(state, trade.assets_from) .. "  $" .. tostring(trade.cash_from) .. "  卡" .. tostring(trade.cards_from))
    text(g, 428, 322, "得到 " .. trade_asset_summary(state, trade.assets_to) .. "  $" .. tostring(trade.cash_to) .. "  卡" .. tostring(trade.cards_to))
  end
end

function M.draw(ctx, g, state)
  g:clear(0)
  local setup_cover = state.phase == "setup" and (state.ui.setup_step or "cover") == "cover"
  if setup_cover then
    PkgImage.draw(g, "menu_cover", 0, 0)
    PkgImage.draw(g, "menu_title_edge", 180, 70, { color = 0 })
    PkgImage.draw(g, "menu_title", 180, 70)
    draw_screen_actions(g, state)
    return
  end
  if state.phase == "handoff" then
    draw_handoff_screen(g, state)
    draw_screen_actions(g, state)
    return
  end
  if state.phase == "results" then
    draw_results_screen(g, state)
    draw_screen_actions(g, state)
    return
  end
  if state.phase ~= "setup" then draw_board(g, state) end
  if state.ui and (state.ui.overlay == "help" or state.ui.overlay == "assets" or state.ui.overlay == "game_menu") then draw_overlay(g, state)
  elseif (state.ui and state.ui.trade_step == "target") or state.phase == "trade" then draw_trade(g, state)
  else
    panel(g, 92, 70, 616, 340)
    if state.phase ~= "setup" and not full_card(state) then current_summary(g, state) end
    if state.phase == "setup" then
      if state.ui and state.ui.editing_player then
        draw_edit_player(g, state)
      else
        if state.setup.players <= 4 then
          centered_text(g, 92, 96, 616, "准备开城")
          centered_text(g, 92, 118, 616, tostring(state.setup.players) .. " 位玩家 · 点击头像可改名和换头像")
        else
          centered_text(g, 92, 96, 616, "准备开城 · " .. tostring(state.setup.players) .. " 位玩家 · 点击头像编辑")
        end
        draw_setup_roster(g, state)
        if state.setup.mode == "quick" then
          rounded_rect(g, 476, 276, 212, 52, "stroke", 15)
          centered_text(g, 528, 308, 108, tostring(state.setup.rounds) .. " 轮")
        end
      end
    elseif state.phase == "pre_roll" then
      draw_player_token(g, state, state.current, 174, 126, "large")
      text(g, 264, 152, "轮到你规划这座城市")
      text(g, 264, 180, "掷骰后棋子将逐格前进")
      local hint = action_hint(state)
      if hint then text(g, 264, 196, hint) end
    elseif state.phase == "moving" then
      local path = state.pending and state.pending.path or {}
      local moved = math.min((state.ui and state.ui.move_cursor) or 0, #path)
      local destination = #path > 0 and Board.space(path[#path]).name or "下一站"
      draw_last_roll(g, state)
      centered_text(g, 92, 228, 616, "正在前进 " .. tostring(moved) .. " / " .. tostring(#path) .. " 格")
      centered_text(g, 92, 264, 616, "即将抵达 · " .. destination)
    elseif state.phase == "property_offer" then
      local index = state.pending and state.pending.index
      if not index then
        centered_text(g, 92, 264, 616, "地产报价已失效")
      elseif full_card(state) then
        -- 全幅卡面铺满面板：左上自适应状态徽章 + 下部悬浮信息条（避开右上角菜单）
        PkgImage.draw(g, string.format("ui_full_%02d", index), 92, 70)
        full_card_badge(g, state)
        local space = Board.space(index)
        local cash = state.players[state.current].cash
        full_card_caption(g, space.name .. "  ·  售价 " .. tostring(space.price) .. "  ·  现金 " .. tostring(cash))
      else
        local space = Board.space(index)
        local cash = state.players[state.current].cash
        draw_landmark_art(g, index, space, 220, 306)
        local offer_text = space.name .. "  ·  售价 " .. tostring(space.price) .. "  ·  现金 " .. tostring(cash)
        if state.mode == "quick" then
          offer_text = offer_text .. "  ·  跳过领 ¥" .. tostring(math.floor(space.price / 2))
        elseif cash < space.price then
          offer_text = offer_text .. "  ·  可竞拍"
        end
        centered_text(g, 92, 306, 616, offer_text)
      end
    elseif state.phase == "auction" then
      local auction = state.pending
      if not (auction and auction.index and auction.current_bidder) then
        centered_text(g, 92, 264, 616, "竞拍状态已失效")
      elseif full_card(state) then
        PkgImage.draw(g, string.format("ui_full_%02d", auction.index), 92, 70)
        full_card_badge(g, state)
        local space = Board.space(auction.index)
        full_card_caption(g, "竞拍 · " .. space.name .. " · 当前 " .. tostring(auction.high_bid) .. " · 轮到 " .. state.players[auction.current_bidder].name)
      else
        local space = Board.space(auction.index)
        draw_landmark_art(g, auction.index, space, 220, 306)
        centered_text(g, 92, 306, 616, "竞拍 · " .. space.name .. " · 当前 " .. tostring(auction.high_bid) .. " · 轮到 " .. state.players[auction.current_bidder].name)
      end
    elseif state.phase == "event" then
      PkgImage.draw(g, Visuals.event_art(state.pending.deck), 220, art_top_for_caption(322, ART_HEIGHT.event))
      centered_text(g, 92, 322, 616, state.pending.deck == "plan" and "建设提案" or "城市见闻")
    elseif state.phase == "event_result" then
      PkgImage.draw(g, Visuals.event_art(state.pending.deck, state.pending.card), 220, art_top_for_caption(322, ART_HEIGHT.event))
      centered_text(g, 92, 322, 616, state.pending.card.text)
    elseif state.phase == "rent_result" then
      local settlement = state.pending
      local space = Board.space(settlement.index)
      if not draw_landmark_art(g, settlement.index, space, 220, 306) then PkgImage.draw(g, Visuals.space_icon(settlement.index), 384, 166) end
      draw_player_token(g, state, settlement.payer, 112, 278, "large")
      draw_player_token(g, state, settlement.owner, 624, 278, "large")
      centered_text(g, 188, 306, 424, "租金结算 · " .. space.name)
      centered_text(g, 188, 330, 424, state.players[settlement.payer].name .. " 向 " .. state.players[settlement.owner].name .. " 支付 " .. tostring(settlement.amount))
    elseif state.phase == "optional_actions" then
      local player = state.players[state.current]
      local space = Board.space(player.position)
      local hint = action_hint(state)
      if not draw_banner(g, state) then
        if not draw_landmark_art(g, player.position, space, 220, 280) then PkgImage.draw(g, Visuals.space_icon(player.position), 384, 160) end
        centered_text(g, 92, 280, 616, state.log and state.log[#state.log] or (space.name .. " · 本次落点已结算"))
      end
      if hint then centered_text(g, 92, 306, 616, hint) end
    elseif state.phase == "checkpoint_decision" then
      PkgImage.draw(g, Visuals.special_art.checkpoint, 290, art_top_for_caption(258, ART_HEIGHT.special))
      local checkpoint_player = state.players[state.current]
      local attempt = math.max(1, math.min(checkpoint_player.detained or 1, 3))
      if state.mode == "quick" then
        centered_text(g, 92, 258, 616, "交通管制站")
        centered_text(g, 92, 286, 616, checkpoint_player.cash >= 50 and "支付 50 立即继续，或在这里休整一回合" or "在这里休整一回合，下轮恢复行动")
        draw_screen_actions(g, state)
        return
      end
      local checkpoint_hint = "当前只能尝试掷出对子离开"
      if checkpoint_player.cash >= 50 and checkpoint_player.pass_cards > 0 then checkpoint_hint = "掷出对子可离开，也可以支付或使用通行卡"
      elseif checkpoint_player.cash >= 50 then checkpoint_hint = "掷出对子可离开，也可以支付 50"
      elseif checkpoint_player.pass_cards > 0 then checkpoint_hint = "掷出对子可离开，也可以使用通行卡" end
      centered_text(g, 92, 258, 616, "交通管制站 · 第 " .. tostring(attempt) .. " / 3 次尝试")
      centered_text(g, 92, 286, 616, checkpoint_hint)
    elseif state.phase == "debt_resolution" then
      PkgImage.draw(g, Visuals.special_art.debt, 290, art_top_for_caption(254, ART_HEIGHT.special))
      local debt = state.pending or {}
      local cash = state.players[state.current].cash
      if state.ui and state.ui.bankruptcy_confirm then
        centered_text(g, 92, 254, 616, "确认宣布破产？")
        local recipient = debt.creditor and state.players[debt.creditor] and ("所有资产将移交给 " .. state.players[debt.creditor].name)
          or "所有资产将交还银行"
        centered_text(g, 92, 282, 616, recipient .. "，你将退出本局")
        centered_text(g, 92, 310, 616, "此操作不可撤销")
      else
        centered_text(g, 92, 254, 616, "债务处理 · " .. tostring(debt.reason or "资金不足"))
        centered_text(g, 92, 282, 616, "当前现金 " .. tostring(cash) .. " · 还需筹集 " .. tostring(math.max(0, -cash)))
        if debt.creditor and state.players[debt.creditor] then
          centered_text(g, 92, 310, 616, "债权人 · " .. state.players[debt.creditor].name)
        elseif Inventory.has_debt_action(state, state.current) then centered_text(g, 92, 310, 616, "出售建筑或抵押资产后可继续")
        else centered_text(g, 92, 310, 616, "已无可整理资产，只能宣布破产") end
      end
    end
  end
  draw_screen_actions(g, state)
  draw_game_menu_button(g, state)
end

return M
