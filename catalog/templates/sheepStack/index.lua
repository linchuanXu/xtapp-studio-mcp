local PkgImage = require("pkg_image")
-- 三羊叠叠乐 / GPL-3.0-or-later
-- 规则移植来源与完整归属说明见 NOTICE.md。
local LevelData = require("levels")

local TILE_KEYS = {
  "tile_leaf", "tile_flower", "tile_fruit", "tile_bell", "tile_cloud",
  "tile_star", "tile_pot", "tile_umbrella", "tile_moon",
}
local TILE_LABELS = { "叶", "花", "果", "铃", "云", "星", "壶", "伞", "月" }
local LEVELS = 36
local TRAY_CAPACITY = 7
local CARD_W, CARD_H = 54, 64

local function copy_list(values)
  local result = {}
  for i, value in ipairs(values or {}) do result[i] = value end
  return result
end

local function copy_cards(cards)
  local result = {}
  for i, card in ipairs(cards or {}) do
    result[i] = { id = card.id, kind = card.kind, x = card.x, y = card.y, order = card.order, taken = card.taken }
  end
  return result
end

local function snapshot(s)
  s.undo = { cards = copy_cards(s.cards), tray = copy_list(s.tray), phase = s.phase, message = s.message }
end

local function restore_snapshot(s)
  if not s.undo then return false end
  s.cards, s.tray, s.phase, s.message = copy_cards(s.undo.cards), copy_list(s.undo.tray), s.undo.phase, s.undo.message
  s.undo = nil
  return true
end

local function new_board(level)
  return LevelData.cards(level)
end

local function fresh_state()
  return { phase = "menu", level = 1, unlocked = 1, cards = {}, tray = {}, tools = { undo = 3, remove = 2, shuffle = 2 }, message = "选择继续或关卡", undo = nil }
end

local function state(ctx)
  if not ctx.state.sheep_stack then ctx.state.sheep_stack = fresh_state() end
  local s = ctx.state.sheep_stack
  s.level = s.level or 1; s.unlocked = s.unlocked or 1; s.cards = s.cards or {}; s.tray = s.tray or {}
  s.tools = s.tools or { undo = 3, remove = 2, shuffle = 2 }; s.phase = s.phase or "menu"
  -- 兼容旧版以 z 表示层级的残局存档；迁移后引擎只读取唯一 order。
  for index, card in ipairs(s.cards) do
    if not card.order then card.order = (card.z or 0) * 100 + (card.id or index) end
  end
  -- 兼容早期试玩版保存的标题状态。
  if s.phase == "title" then s.phase = "menu" end
  return s
end

local function overlap(a, b)
  return a.x < b.x + CARD_W and a.x + CARD_W > b.x and a.y < b.y + CARD_H and a.y + CARD_H > b.y
end

local function selectable(cards, card)
  if card.taken then return false end
  for _, other in ipairs(cards) do
    if not other.taken and other.order > card.order and overlap(card, other) then return false end
  end
  return true
end

local function available(s)
  local result = {}
  for _, card in ipairs(s.cards) do if selectable(s.cards, card) then result[#result + 1] = card end end
  table.sort(result, function(a, b) if a.y == b.y then return a.x < b.x end return a.y < b.y end)
  return result
end

local function remaining(s)
  local total = 0
  for _, card in ipairs(s.cards) do if not card.taken then total = total + 1 end end
  return total
end

local function insert_tray(s, kind)
  -- 上游在第一个同类后插入；同类连续时等同于放到同类尾部，但不依赖该前提。
  for i, entry in ipairs(s.tray) do
    if entry == kind then table.insert(s.tray, i + 1, kind); return end
  end
  table.insert(s.tray, kind)
end

local function eliminate(s)
  -- 与上游一致：本次落牌只清除扫描到的第一组相邻三消。
  for i = 1, #s.tray - 2 do
    if s.tray[i] == s.tray[i + 1] and s.tray[i] == s.tray[i + 2] then
      table.remove(s.tray, i); table.remove(s.tray, i); table.remove(s.tray, i)
      return true
    end
  end
  return false
end

local function begin_level(s, level)
  s.level = level; s.cards = new_board(level); s.tray = {}; s.undo = nil; s.phase = "play"
  local spec = LevelData.get(level)
  s.tools = { undo = spec.tools.undo, remove = spec.tools.remove, shuffle = spec.tools.shuffle }
  s.message = string.format("第 %d 关 · %s · %s", level, spec.name, spec.difficulty)
end

local function take(s, card)
  if not card or not selectable(s.cards, card) then return false end
  snapshot(s); card.taken = true; insert_tray(s, card.kind)
  local cleared = eliminate(s)
  if remaining(s) == 0 then
    s.phase = "won"; s.unlocked = math.min(LEVELS, math.max(s.unlocked, s.level + 1)); s.message = "本关完成！"
  elseif #s.tray >= TRAY_CAPACITY then
    s.phase = "lost"; s.message = "暂存槽满了"
  elseif cleared then s.message = "三张相同棋子已消除"
  else s.message = string.format("暂存 %d / %d", #s.tray, TRAY_CAPACITY) end
  s.hint_kind = nil
  return true
end

local function use_undo(s)
  if s.tools.undo <= 0 or not s.undo then s.message = "没有可撤销的操作"; return false end
  s.tools.undo = s.tools.undo - 1; restore_snapshot(s); s.message = "已撤销上一步"; return true
end

local function use_remove(s)
  if s.tools.remove <= 0 or #s.tray == 0 then s.message = "暂存槽中没有可移出的棋子"; return false end
  snapshot(s); s.tools.remove = s.tools.remove - 1; table.remove(s.tray, #s.tray); s.message = "已移出最后一张暂存棋子"; return true
end

local function use_shuffle(s)
  if s.tools.shuffle <= 0 then s.message = "提示次数已用完"; return false end
  local counts, choices = {}, available(s)
  for _, card in ipairs(choices) do counts[card.kind] = (counts[card.kind] or 0) + 1 end
  local best_kind, best_count = nil, 0
  for kind, count in pairs(counts) do if count > best_count then best_kind, best_count = kind, count end end
  if not best_kind then s.message = "当前没有可提示的棋子"; return false end
  s.tools.shuffle = s.tools.shuffle - 1
  s.hint_kind = best_kind
  s.message = string.format("提示：先收集三个「%s」", TILE_LABELS[best_kind])
  return true
end

local function visible_cards(s)
  local result = {}
  for _, card in ipairs(s.cards) do if not card.taken then result[#result + 1] = card end end
  table.sort(result, function(a, b) return a.order < b.order end)
  return result
end

local function top_card_at(s, x, y)
  local cards = visible_cards(s)
  for i = #cards, 1, -1 do
    local card = cards[i]
    if x >= card.x and x <= card.x + CARD_W and y >= card.y and y <= card.y + CARD_H then
      return selectable(s.cards, card) and card or nil
    end
  end
  return nil
end

local function point_card(s, x, y)
  local card = top_card_at(s, x, y)
  if not card then return nil, nil end
  local choices = available(s)
  for i, choice in ipairs(choices) do if choice.id == card.id then return card, i end end
  return nil, nil
end

local function touch_play(s, ev)
  if ev.gesture == "long" then s.phase = "pause"; s.message = "已暂停"; return true end
  if ev.gesture ~= "tap" then return false end
  local card = point_card(s, ev.x, ev.y)
  if card then return take(s, card) end
  if ev.y >= 548 and ev.y <= 606 then
    if ev.x < 160 then return use_undo(s) elseif ev.x < 320 then return use_remove(s) else return use_shuffle(s) end
  end
  return false
end

function on_load(ctx) ctx:invalidate() end

function on_input(ctx, ev)
  local s = state(ctx)
  if (ev.type == "pointer" and ev.phase == "up") then
    local handled = false
    if s.phase == "play" then handled = touch_play(s, ev)
    elseif ev.gesture == "tap" and s.phase == "menu" then
      if ev.y >= 282 and ev.y <= 340 then
        begin_level(s, s.level); handled = true
      elseif ev.y >= 366 and ev.y <= 424 then
        s.phase = "levels"; s.message = "选择已解锁关卡"; handled = true
      elseif ev.y >= 450 and ev.y <= 508 then
        s.phase = "rules"; handled = true
      end
    elseif ev.gesture == "tap" and s.phase == "levels" then
      if ev.y >= 144 and ev.y <= 564 then
        local col = math.floor((ev.x - 36) / 70) + 1
        local row = math.floor((ev.y - 144) / 70) + 1
        if col >= 1 and col <= 6 and row >= 1 and row <= 6 then
          local level = (row - 1) * 6 + col
          if level <= s.unlocked then begin_level(s, level); handled = true else s.message = "请先完成前一关"; handled = true end
        end
      elseif ev.y >= 622 and ev.y <= 682 then
        s.phase = "menu"; handled = true
      end
    elseif ev.gesture == "tap" and s.phase == "rules" then
      s.phase = "menu"; handled = true
    elseif ev.gesture == "tap" and s.phase == "pause" then
      if ev.x < 240 then s.phase = "play"; s.message = "继续游戏" else begin_level(s, s.level) end
      handled = true
    elseif ev.gesture == "tap" and s.phase == "won" then
      if s.level >= LEVELS then s.phase = "menu"; s.message = "36 关全部完成" else begin_level(s, s.level + 1) end
      handled = true
    elseif ev.gesture == "tap" and s.phase == "lost" then begin_level(s, s.level); handled = true end
    if handled then ctx:invalidate() end
    return handled
  end
  return false
end

local function draw_header(g, s, w)
  local spec = LevelData.get(s.level)
  g:text(24, 28, "三羊叠叠乐", { color = 15 })
  g:text(24, 58, string.format("第 %d / %d 关 · 第 %d 章 · %s", s.level, LEVELS, spec.chapter, spec.difficulty), { color = 15 })
  g:text(w - 148, 58, string.format("剩余 %d", remaining(s)), { color = 15 })
  g:line(24, 82, w - 24, 82,{color=15})
end

local function draw_tile_at(g, kind, x, y)
  g:rect(x, y, CARD_W, CARD_H,{fill=true,color=0})
  PkgImage.draw(g, TILE_KEYS[kind], x, y, { w = CARD_W, h = CARD_H })
  g:rect(x, y, CARD_W, CARD_H,{color=15})
end

local function draw_tile(g, card, is_selectable)
  draw_tile_at(g, card.kind, card.x, card.y)
  -- 被遮挡牌使用内缩虚线框提示，不覆盖棋子图案，也不是点击后的选中效果。
  if not is_selectable then
    local x, y, inner_w, inner_h = card.x + 5, card.y + 5, CARD_W - 10, CARD_H - 10
    for offset = 0, inner_w - 1, 10 do
      g:line(x + offset, y, x + math.min(offset + 5, inner_w), y,{color=15})
      g:line(x + offset, y + inner_h, x + math.min(offset + 5, inner_w), y + inner_h,{color=15})
    end
    for offset = 0, inner_h - 1, 10 do
      g:line(x, y + offset, x, y + math.min(offset + 5, inner_h),{color=15})
      g:line(x + inner_w, y + offset, x + inner_w, y + math.min(offset + 5, inner_h),{color=15})
    end
  end
end

local function draw_tools(g, s, w)
  local labels = { string.format("撤销 %d", s.tools.undo), string.format("移出 %d", s.tools.remove), string.format("提示 %d", s.tools.shuffle) }
  local icons = { "ui_tool_undo", "ui_tool_remove", "ui_tool_hint" }
  for i = 1, 3 do
    local x = 24 + (i - 1) * 150
    -- ui_button 是横向主按钮，不拉伸到道具的窄比例。
    g:rect(x, 548, 132, 48,{color=15})
    PkgImage.draw(g, icons[i], x + 8, 556, { w = 28, h = 28 })
    g:text(x + 42, 565, labels[i], { color = 15 })
  end
  g:text(24, 624, "暂存槽 · 三张相同自动消除", { color = 15 })
  for i = 1, TRAY_CAPACITY do
    local x, kind = 24 + (i - 1) * 62, s.tray[i]
    if kind then
      draw_tile_at(g, kind, x, 652)
    else
      PkgImage.draw(g, "ui_tray_slot", x, 652, { w = CARD_W, h = CARD_H })
    end
  end
  g:text(24, 758, s.message, { color = 15 })
  g:text(24, 782, "点牌/点道具 · 长按棋盘暂停", { color = 15 })
end

local function draw_play(g, s, w)
  draw_header(g, s, w)
  for _, card in ipairs(visible_cards(s)) do draw_tile(g, card, selectable(s.cards, card)) end
  draw_tools(g, s, w)
end

local function label_width(label)
  -- #label 返回 UTF-8 字节数；中文为三字节，不能用它直接给文字居中。
  local width, index = 0, 1
  while index <= #label do
    local byte = string.byte(label, index)
    if byte >= 224 then
      width, index = width + 16, index + 3
    elseif byte >= 192 then
      width, index = width + 12, index + 2
    elseif byte == 32 then
      width, index = width + 6, index + 1
    else
      width, index = width + 8, index + 1
    end
  end
  return width
end

local function draw_centered_text(g, w, y, label)
  g:text(math.floor((w - label_width(label)) / 2), y, label, { color = 15 })
end

local function draw_center(g, w, title, lines)
  PkgImage.draw(g, "ui_state_panel", 24, 52, { w = w - 48, h = 648 })
  -- 文字落在竖版边框的中段留白，避免与顶部叶片、两侧节点或底部卡牌重叠。
  draw_centered_text(g, w, 174, title)
  for i, line in ipairs(lines) do draw_centered_text(g, w, 270 + (i - 1) * 52, line) end
end

local function draw_button(g, _, y, _, label)
  -- 1bpp XIC 不能缩放；始终使用 396px 的原始按钮，并在 480px 画布中居中。
  local x, w = 42, 396
  PkgImage.draw(g, "ui_button", x, y, { w = w, h = 58 })
  -- 按钮四角有装饰；使用中间留白显示 Lua 文案。
  g:text(x + math.floor((w - label_width(label)) / 2), y + 21, label, { color = 15 })
end

local function draw_menu(g, s, w)
  -- 菜单是一张完整的竖版卡片：边框、标题和操作区共用同一安全区域。
  -- 原 ui_logo 只有左右散件，单独使用会使标题与边框割裂，因此不放在此页。
  PkgImage.draw(g, "ui_state_panel", 24, 52, { w = w - 48, h = 648 })
  g:text(190, 166, "三羊叠叠乐", { color = 15 })
  g:text(142, 200, string.format("已解锁 %d / %d 关", s.unlocked, LEVELS), { color = 15 })
  g:text(158, 230, "叠牌三消 · 触屏版", { color = 15 })
  draw_button(g, 141, 282, 198, string.format("继续第 %d 关", s.level))
  draw_button(g, 141, 366, 198, "选择关卡")
  draw_button(g, 141, 450, 198, "玩法说明")
  g:text(132, 540, "点按棋子 · 长按棋盘暂停", { color = 15 })
end

local function draw_levels(g, s, w)
  g:text(28, 48, "选择关卡", { color = 15 })
  g:text(28, 82, string.format("已解锁 %d / %d", s.unlocked, LEVELS), { color = 15 })
  for level = 1, LEVELS do
    local index, col, row = level - 1, (level - 1) % 6, math.floor((level - 1) / 6)
    local x, y = 36 + col * 70, 144 + row * 70
    PkgImage.draw(g, "ui_level_cell", x, y, { w = 56, h = 52 })
    if level <= s.unlocked then g:text(x + 15, y + 17, tostring(level), { color = 15 }) else g:text(x + 20, y + 17, "—", { color = 15 }) end
  end
  draw_button(g, 42, 622, w - 84, "返回菜单")
  g:text(42, 710, s.message, { color = 15 })
end

local function draw_rules(g, s, w)
  draw_center(g, w, "玩法说明", {
    "点按未被遮挡的棋子", "暂存槽内三张相同棋子自动消除",
    "暂存槽满 7 格且不能消除则失败", "底部可使用撤销、移出与提示",
    "长按棋盘暂停 · 点按返回菜单",
  })
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s, w = state(ctx), ctx.screen.width
  g:clear(0)
  if s.phase == "play" then draw_play(g, s, w); return end
  if s.phase == "menu" then
    draw_menu(g, s, w)
  elseif s.phase == "levels" then
    draw_levels(g, s, w)
  elseif s.phase == "rules" then
    draw_rules(g, s, w)
  elseif s.phase == "pause" then draw_center(g, w, "游戏暂停", { "点左侧继续", "点右侧重新开始本关", s.message })
  elseif s.phase == "won" then draw_center(g, w, s.level >= LEVELS and "全部完成！" or "本关完成！", { s.level >= LEVELS and "点按回到标题" or "点按进入下一关", "进度已保存" })
  else draw_center(g, w, "暂存槽满", { "点按重试本关", "善用撤销、移出和提示" }) end
end
