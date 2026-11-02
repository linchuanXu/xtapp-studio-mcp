local PkgImage = require("pkg_image")
local Backgrounds = require("data.backgrounds")
local Catalog = require("data.level_catalog")
local Config = require("domain.game_config")
local State = require("domain.game_state")
local M = {}

local C = Config.COLORS
local DW, DH = Config.DESIGN_WIDTH, Config.DESIGN_HEIGHT

local function utf8_chars(text)
  local chars, index = {}, 1
  text = tostring(text or "")
  while index <= #text do
    local first = string.byte(text, index)
    local length = 1
    if first >= 0xF0 then length = 4
    elseif first >= 0xE0 then length = 3
    elseif first >= 0xC0 then length = 2 end
    chars[#chars + 1] = string.sub(text, index, index + length - 1)
    index = index + length
  end
  return chars
end

local function char_width(char, scale)
  local width = #char == 1 and Config.FONT.ascii_width or Config.FONT.cjk_width
  return width * (scale or 1)
end

local function display_width(text, scale)
  local width = 0
  for _, char in ipairs(utf8_chars(text)) do width = width + char_width(char, scale) end
  return width
end

local function wrap_text(text, max_width, max_lines, scale)
  local lines, current, width = {}, "", 0
  for _, char in ipairs(utf8_chars(text)) do
    if char == "\n" then
      lines[#lines + 1], current, width = current, "", 0
    else
      local add = char_width(char, scale)
      if width + add > max_width and current ~= "" then
        lines[#lines + 1], current, width = current, char, add
      else
        current, width = current .. char, width + add
      end
    end
    if max_lines and #lines >= max_lines then break end
  end
  if (not max_lines or #lines < max_lines) and current ~= "" then lines[#lines + 1] = current end
  if #lines == 0 then lines[1] = "" end
  return lines
end

local function sx(layout, value) return math.floor(value * layout.scale + 0.5) end
local function px(layout, value) return layout.ox + sx(layout, value) end
local function py(layout, value) return layout.oy + sx(layout, value) end

local function rect(g, l, x, y, w, h, mode, color)
  g:rect(px(l, x), py(l, y), sx(l, w), sx(l, h),{fill=(mode) == "fill",color=color})
end

local function line(g, l, x1, y1, x2, y2, color)
  g:line(px(l, x1), py(l, y1), px(l, x2), py(l, y2),{color=color})
end

local function text_at(g, l, x, y, text, color)
  g:text(px(l, x), py(l, y), tostring(text or ""), { color = color or C.black })
end

local function centered(g, l, x, y, width, text, color)
  local left = x + math.max(0, math.floor((width - display_width(text)) / 2))
  text_at(g, l, left, y, text, color)
end

local function draw_wrapped(g, l, text, x, y, width, max_lines, centered_lines, color, line_h)
  local lines = wrap_text(text, width, max_lines)
  local height = line_h or Config.FONT.line_height
  for index, part in ipairs(lines) do
    if centered_lines then centered(g, l, x, y + (index - 1) * height, width, part, color)
    else text_at(g, l, x, y + (index - 1) * height, part, color) end
  end
  return y + #lines * height
end

local function panel(g, l, x, y, w, h, filled)
  if filled ~= false then rect(g, l, x, y, w, h, "fill", C.white) end
  rect(g, l, x, y, w, h, "stroke", C.black)
  rect(g, l, x + 4, y + 4, w - 8, h - 8, "stroke", C.black)
end

local function button(g, l, x, y, w, h, label, selected)
  rect(g, l, x, y, w, h, "fill", selected and C.black or C.white)
  rect(g, l, x, y, w, h, "stroke", C.black)
  centered(g, l, x, y + math.floor(h / 2) - 11, w, label,
    selected and C.white or C.black)
end

local function image(g, l, asset_key)
  -- 墨水屏必须先清上一页，否则规则页/路径页文字会残留在背景中部。
  g:clear(C.white)
  local ok = pcall(function()
    PkgImage.draw(g, asset_key, l.ox, l.oy, { w = l.canvas_w, h = l.canvas_h })
  end)
  if not ok then
    g:clear(C.white)
    rect(g, l, 0, 0, DW, DH, "stroke", C.black)
    centered(g, l, 0, 350, DW, "背景资源未加载", C.black)
    centered(g, l, 0, 382, DW, asset_key, C.black)
  end
end

function M.layout(ctx)
  local screen_w = tonumber(ctx.screen.width) or DW
  local screen_h = tonumber(ctx.screen.height) or DH
  local scale = math.min(screen_w / DW, screen_h / DH)
  local canvas_w = math.floor(DW * scale + 0.5)
  local canvas_h = math.floor(DH * scale + 0.5)
  return {
    w = screen_w,
    h = screen_h,
    scale = scale,
    canvas_w = canvas_w,
    canvas_h = canvas_h,
    ox = math.floor((screen_w - canvas_w) / 2),
    oy = math.floor((screen_h - canvas_h) / 2),
  }
end

local function top_bar(g, l, left_text, right_text)
  rect(g, l, 12, 12, 456, 64, "fill", C.white)
  rect(g, l, 12, 12, 456, 64, "stroke", C.black)
  text_at(g, l, 26, 31, left_text, C.black)
  text_at(g, l, math.max(26, 454 - display_width(right_text)), 31, right_text, C.black)
end

local function draw_bank_state(g, l, round)
  -- 精确状态不再写死在背景图里；每次确认有效运输后由round实时计算。
  panel(g, l, 42, 146, 396, 58, true)
  draw_wrapped(g, l, State.bank_state_text(round), 54, 163, 372, 2, true, C.black, 24)
end

local function draw_home(g, s, l)
  g:clear(C.white)
  panel(g, l, 24, 32, 432, 718, true)
  centered(g, l, 24, 68, 432, "羊狼过河", C.black)
  local level = State.level(s)
  centered(g, l, 24, 108, 432,
    tostring(level.sheep) .. "只羊 · " .. tostring(level.wolves) .. "只狼 · 1名船夫", C.black)
  line(g, l, 48, 148, 432, 148, C.black)
  centered(g, l, 24, 176, 432, "本关最大步数", C.black)
  centered(g, l, 24, 220, 432, tostring(level.max_steps) .. " 步", C.black)
  centered(g, l, 24, 264, 432, "第 " .. tostring(level.id) .. " / 50 关", C.black)
  button(g, l, 45, 305, 100, 58, "上一关", false)
  button(g, l, 335, 305, 100, 58,
    (s.level_index < #Catalog.levels and State.is_unlocked(s, s.level_index + 1))
      and "下一关" or "未解锁", false)
  centered(g, l, 24, 390, 432,
    State.is_completed(s, s.level_index) and "本关：已通过"
      or (State.is_unlocked(s, s.level_index) and "本关：已解锁" or "本关：未解锁"),
    C.black)
  centered(g, l, 24, 426, 432,
    "已通过 " .. tostring(State.completed_count(s)) .. "/50 关", C.black)
  draw_wrapped(g, l, "通过当前关后解锁下一关；在最大步数内任意合法方案都可以。",
    45, 474, 390, 3, true, C.black, 28)
  button(g, l, 55, 585, 370, 64,
    State.can_resume_selected(s) and "继续当前游戏" or "进入本关", true)
  button(g, l, 55, 670, 370, 54,
    State.has_active_game(s) and "上键继续 · 下键查看成就" or "下键：查看成就", false)
end

local function draw_story(g, s, l)
  g:clear(C.white)
  panel(g, l, 24, 24, 432, 728, false)
  centered(g, l, 24, 52, 432, "故事与规则", C.black)
  centered(g, l, 24, 91, 432,
    "第" .. tostring(s.level_index) .. "关 · 羊狼各" .. tostring(State.level(s).animal_count)
      .. "只 · 最大" .. tostring(State.level(s).max_steps) .. "步",
    C.black)
  line(g, l, 48, 126, 432, 126, C.black)
  local y = 153
  y = draw_wrapped(g, l, tostring(State.level(s).animal_count)
      .. "只羊和" .. tostring(State.level(s).animal_count)
      .. "只狼要从左岸到达右岸，船夫始终随船。",
    52, y, 376, 4, false, C.black, 28) + 12
  y = draw_wrapped(g, l, "前两关显示3格，第3关起显示5格；最后一格固定为3（船夫），无需修改。",
    52, y, 376, 6, false, C.black, 28) + 12
  y = draw_wrapped(g, l, "前两关最多带2只动物，第3关起最多带4只；船夫可单独过河。",
    52, y, 376, 7, false, C.black, 28) + 12
  draw_wrapped(g, l, "船夫离开的岸只要还有羊，狼数大于或等于羊数就会失败。",
    52, y, 376, 5, false, C.black, 28)
  button(g, l, 55, 666, 370, 62, "开始游戏", true)
end

local function draw_game_input(g, s, l)
  local round = s.round
  local slot_count = #round.input
  local slot_width = slot_count == 3 and 72 or 66
  local slot_gap = slot_count == 3 and 20 or 16
  local slots_width = slot_count * slot_width + (slot_count - 1) * slot_gap
  local slots_left = math.floor((DW - slots_width) / 2)
  panel(g, l, 24, 476, 432, 306, true)
  centered(g, l, 24, 489, 432,
    round.boat_side == "left" and "本次方向：左岸 → 右岸" or "本次方向：右岸 → 左岸",
    C.black)
  for index = 1, slot_count do
    button(g, l, slots_left + (index - 1) * (slot_width + slot_gap), 527,
      slot_width, 52, tostring(round.input[index]),
      index <= round.boat_capacity and round.input_focus == index)
  end
  for digit = 0, 2 do
    button(g, l, 55 + digit * 130, 590, 110, 46, tostring(digit), false)
  end
  draw_wrapped(g, l, round.feedback, 44, 647, 392, 2, true, C.black, 24)
  button(g, l, 65, 715, 350, 44, "确认本步",
    round.input_focus == round.boat_capacity + 1)
end

local function draw_result(g, s, l)
  local result = s.result
  local width, height = 408, 340
  local left, top = math.floor((DW - width) / 2), math.floor((DH - height) / 2)
  local inner_x, inner_w = left + 20, width - 40
  panel(g, l, left, top, width, height, true)
  centered(g, l, left, top + 27, width, result.title, C.black)
  line(g, l, inner_x, top + 66, inner_x + inner_w, top + 66, C.black)
  draw_wrapped(g, l, result.message, inner_x, top + 91, inner_w, 4, true, C.black, 31)
  draw_wrapped(g, l, result.detail or "", inner_x, top + 205, inner_w, 2, true, C.black, 25)
  line(g, l, inner_x, top + 276, inner_x + inner_w, top + 276, C.black)
  centered(g, l, left, top + height - 31, width, "点击或按OK再来一次", C.black)
end

local function draw_game(g, s, l)
  local background_key = s.round.background_key or Backgrounds.SCENE
  image(g, l, background_key)
  top_bar(g, l,
    "第" .. tostring(s.level_index) .. "关 " .. tostring(s.round.step) .. "/" .. tostring(s.round.max_steps) .. "步",
    "已找 " .. tostring(State.discovered_count(s)))
  button(g, l, 18, 90, 156, 44, "上·规则", false)
  button(g, l, 306, 90, 156, 44, "下·路径", false)
  draw_bank_state(g, l, s.round)
  if s.result then draw_result(g, s, l) else draw_game_input(g, s, l) end
end

local function draw_rules(g, s, l)
  g:clear(C.white)
  panel(g, l, 22, 22, 436, 732, false)
  centered(g, l, 22, 51, 436, "游戏规则", C.black)
  local rules = {
    "1. 最后一格固定为3（船夫），玩家只需选择前面的动物格。",
    "2. 1是羊、2是狼、0是空位；输入顺序不影响组合。",
    "3. 前两关最多带2只动物，第3关起最多带4只动物。",
    "4. 动物必须来自船所在岸；数量不足时不扣步数，可重新输入。",
    "5. 船夫离开的一岸若有羊且狼数≥羊数，本轮立即失败。",
    "6. 全部动物在最大步数内到达右岸即成功并解锁下一关。",
  }
  local y = 104
  for _, item in ipairs(rules) do
    y = draw_wrapped(g, l, item, 48, y, 384, 4, false, C.black, 27) + 13
  end
  button(g, l, 62, 681, 356, 52, "返回游戏", true)
end

local function draw_paths(g, s, l)
  g:clear(C.white)
  panel(g, l, 22, 22, 436, 732, false)
  centered(g, l, 22, 50, 436, "当前已选择路径", C.black)
  local total_pages = math.max(1, math.ceil(#s.round.path / Config.MAX_HISTORY_LINES))
  s.path_page = math.max(1, math.min(total_pages, s.path_page or 1))
  local first = (s.path_page - 1) * Config.MAX_HISTORY_LINES + 1
  local y = 96
  if #s.round.path == 0 then
    centered(g, l, 22, 330, 436, "尚未确认任何一步", C.black)
  else
    for index = first, math.min(#s.round.path, first + Config.MAX_HISTORY_LINES - 1) do
      rect(g, l, 46, y, 388, 72, "stroke", C.black)
      draw_wrapped(g, l, State.path_text(s.round.path[index]),
        60, y + 12, 360, 2, false, C.black, 25)
      y = y + 80
    end
  end
  centered(g, l, 22, 604, 436,
    "第 " .. tostring(s.path_page) .. "/" .. tostring(total_pages) .. " 页", C.black)
  button(g, l, 54, 675, 105, 52, "上一页", false)
  button(g, l, 321, 675, 105, 52, "下一页", false)
  button(g, l, 172, 675, 136, 52, "返回", true)
end

local function draw_achievements(g, s, l)
  g:clear(C.white)
  panel(g, l, 22, 22, 436, 732, false)
  centered(g, l, 22, 49, 436, "关卡成就", C.black)
  centered(g, l, 22, 86, 436, "已通过 " .. tostring(State.completed_count(s)) .. "/50", C.black)
  local per_page = 8
  local total_pages = math.ceil(#Catalog.levels / per_page)
  s.achievement_page = math.max(1, math.min(total_pages, s.achievement_page or 1))
  local first = (s.achievement_page - 1) * per_page + 1
  local y = 128
  for index = first, math.min(#Catalog.levels, first + per_page - 1) do
    local level = Catalog.get(index)
    local mark = State.is_completed(s, index) and "[已通过]"
      or (State.is_unlocked(s, index) and "[已解锁]" or "[未解锁]")
    rect(g, l, 48, y, 384, 51, "stroke", C.black)
    text_at(g, l, 62, y + 14,
      "第" .. tostring(index) .. "关 · 各" .. tostring(level.animal_count)
        .. "只 · 最大" .. tostring(level.max_steps) .. "步", C.black)
    text_at(g, l, 418 - display_width(mark), y + 14, mark, C.black)
    y = y + 59
  end
  centered(g, l, 22, 616, 436,
    "第 " .. tostring(s.achievement_page) .. "/" .. tostring(total_pages) .. " 页", C.black)
  button(g, l, 54, 675, 105, 52, "上一页", false)
  button(g, l, 321, 675, 105, 52, "下一页", false)
  button(g, l, 172, 675, 136, 52,
    State.has_active_game(s) and "上键回游戏" or "返回", true)
end

local function design_point(l, x, y)
  if l.scale <= 0 then return -1, -1 end
  return (x - l.ox) / l.scale, (y - l.oy) / l.scale
end

function M.hit(ctx, s, ev)
  if not (ev.type == "pointer" and ev.phase == "up") or ev.gesture ~= "tap" then return nil end
  local l = M.layout(ctx)
  local x, y = design_point(l, ev.x, ev.y)
  if s.page == "home" then
    if y >= 295 and y <= 373 and x <= 170 then return { name = "level", delta = -1 } end
    if y >= 295 and y <= 373 and x >= 310 then return { name = "level", delta = 1 } end
    if y >= 575 and y <= 660 then
      return { name = State.can_resume_selected(s) and "resume" or "story" }
    end
    if y >= 660 then return { name = "achievements" } end
  elseif s.page == "story" then
    if y >= 640 then return { name = "start" } end
  elseif s.page == "game" then
    if s.result then return { name = "dismiss_result" } end
    if y >= 80 and y <= 150 and x < 190 then return { name = "rules" } end
    if y >= 80 and y <= 150 and x > 290 then return { name = "paths" } end
    if y >= 517 and y <= 586 then
      local slot_count = #s.round.input
      local slot_width = slot_count == 3 and 72 or 66
      local slot_gap = slot_count == 3 and 20 or 16
      local slots_width = slot_count * slot_width + (slot_count - 1) * slot_gap
      local slots_left = math.floor((DW - slots_width) / 2)
      for index = 1, s.round.boat_capacity do
        local slot_left = slots_left + (index - 1) * (slot_width + slot_gap)
        if x >= slot_left and x <= slot_left + slot_width then
          return { name = "focus", index = index }
        end
      end
    end
    if y >= 582 and y <= 642 then
      for digit = 0, 2 do
        local digit_left = 55 + digit * 130
        if x >= digit_left and x <= digit_left + 110 then
          return { name = "digit", digit = digit }
        end
      end
    end
    if y >= 704 then return { name = "submit" } end
  elseif s.page == "rules" then
    if y >= 650 then return { name = "return_game" } end
  elseif s.page == "paths" or s.page == "achievements" then
    if y >= 650 and x < 168 then return { name = "page_delta", delta = -1 } end
    if y >= 650 and x > 312 then return { name = "page_delta", delta = 1 } end
    if y >= 650 then
      if s.page == "paths" then return { name = "return_game" } end
      return { name = State.has_active_game(s) and "resume" or "home" }
    end
  end
  return nil
end

function M.draw(ctx, g, s)
  local l = M.layout(ctx)
  if s.page == "home" then draw_home(g, s, l)
  elseif s.page == "story" then draw_story(g, s, l)
  elseif s.page == "game" then draw_game(g, s, l)
  elseif s.page == "rules" then draw_rules(g, s, l)
  elseif s.page == "paths" then draw_paths(g, s, l)
  elseif s.page == "achievements" then draw_achievements(g, s, l)
  else State.go_home(s); draw_home(g, s, l) end
end

return M
