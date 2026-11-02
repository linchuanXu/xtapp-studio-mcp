local PkgImage = require("pkg_image")
local State = require("domain.divination_state")
local Hex = require("domain.hexagram")
local HexData = require("domain.hexagram_data")
local CategoryAnalysis = require("domain.category_analysis")
local LibraryView = require("domain.divination_library_view")
local RESULT_VIEW = nil

local function resultView()
  if not RESULT_VIEW then RESULT_VIEW = require("domain.divination_result_view") end
  return RESULT_VIEW
end

local M = {}

local W = 480
local H = 800
local MARGIN = 16
local HOME_BACKGROUND = "home_background"
local INPUT_HEADER = "input_header"
local KEY_ROWS = {
  { letters = "qwertyuiop", x = 12, gap = 4 },
  { letters = "asdfghjkl", x = 32, gap = 5 },
  { letters = "zxcvbnm", x = 74, gap = 7 },
}
local KEY_W = 42
local KEY_H = 40
local DETAIL_WRAP_UNITS = 54
local CATEGORY_X = 6
local CATEGORY_Y = 310
local CATEGORY_W = 66
local CATEGORY_H = 42
local CATEGORY_GAP = 1
local CATEGORY_ROW_STEP = 46
local INPUT_LOWER_SHIFT = 12
local CANDIDATE_Y = 484 + INPUT_LOWER_SHIFT
local HEX_TEXT_CACHE = nil

local function hexText(name)
  if not HEX_TEXT_CACHE then HEX_TEXT_CACHE = require("domain.hexagram_text") end
  return HEX_TEXT_CACHE.get(name)
end

local function imHasComposition(s)
  return s.questionCategory ~= nil
    and s.imMode == "cn"
    and (s.imPinyin or "") ~= ""
end

local function imKeyboardBaseY(s)
  return imHasComposition(s) and (526 + INPUT_LOWER_SHIFT) or (486 + INPUT_LOWER_SHIFT)
end

local function imKeyboardRowY(s, rowIndex)
  return imKeyboardBaseY(s) + (rowIndex - 1) * 48
end

local function imControlY(s)
  return imKeyboardBaseY(s) + 150
end

function M.layout(ctx)
  return { w = W, h = H, margin = MARGIN }
end

local function utf8Chars(str)
  local chars = {}
  local i, n = 1, #str
  while i <= n do
    local b = string.byte(str, i)
    local len = 1
    if b >= 0xF0 then len = 4 elseif b >= 0xE0 then len = 3 elseif b >= 0xC0 then len = 2 end
    chars[#chars + 1] = string.sub(str, i, i + len - 1)
    i = i + len
  end
  return chars
end

local function wrap(str, maxUnits)
  if not str or str == "" then return {} end
  local lines, cur, units = {}, "", 0
  for _, c in ipairs(utf8Chars(str)) do
    local u = string.byte(c) > 127 and 2 or 1
    if units + u > maxUnits then
      lines[#lines + 1] = cur
      cur, units = c, u
    else
      cur = cur .. c
      units = units + u
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end

local function strUnits(str)
  local u = 0
  for _, c in ipairs(utf8Chars(str)) do
    u = u + (string.byte(c) > 127 and 2 or 1)
  end
  return u
end

local function textAt(g, x, y, str, color)
  g:text(x, y, str, { color = color })
end

local function centerText(g, cx, y, str, color)
  local u = strUnits(str)
  g:text(math.max(0, cx - u * 6), y, str, { color = color })
end

local function centerHomeText(g, y, str, color)
  centerText(g, W / 2 + 6, y, str, color)
end

local function centerInputText(g, y, str, color)
  local u = strUnits(str)
  g:text(math.max(0, W / 2 - u * 5), y, str, { color = color })
end

-- 参考“果蔬消消乐”的按钮衬底：用矩形与四个圆组合出真机兼容的圆角。
local function roundedFill(g, x, y, w, h, radius, color)
  local r = math.max(0, math.min(radius, math.floor(w / 2), math.floor(h / 2)))
  if r == 0 then g:rect(x, y, w, h,{fill=true,color=color}); return end
  g:rect(x + r, y, w - r * 2, h,{fill=true,color=color})
  g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
end

local function roundedRect(g, x, y, w, h, radius, mode, color)
  if mode == "fill" then roundedFill(g, x, y, w, h, radius, color); return end
  roundedFill(g, x, y, w, h, radius, color)
  local border = 2
  roundedFill(g, x + border, y + border, w - border * 2, h - border * 2,
    math.max(0, radius - border), color == 15 and 0 or 15)
end

local function yaoLine(g, x, y, w, yang, moving)
  if yang then
    g:rect(x, y, w, 12,{fill=true,color=15})
  else
    local seg = math.floor((w - 20) / 2)
    g:rect(x, y, seg, 12,{fill=true,color=15})
    g:rect(x + seg + 20, y, seg, 12,{fill=true,color=15})
  end
  if moving then
    g:rect(x + w + 8, y - 2, 22, 16,{fill=true,color=15})
    g:text(x + w + 11, y, "动", { color = 0 })
  end
end

local function yaoCompact(g, x, y, w, yang)
  local h = 8
  if yang then
    g:rect(x, y, w, h,{fill=true,color=15})
  else
    local seg = math.floor((w - 16) / 2)
    g:rect(x, y, seg, h,{fill=true,color=15})
    g:rect(x + seg + 16, y, seg, h,{fill=true,color=15})
  end
end

local POS_NAMES = { "初", "二", "三", "四", "五", "上" }

local function firstSentence(text)
  if not text or text == "" then return "宜结合实际情况谨慎判断。" end
  local p = string.find(text, "。", 1, true)
  if p then return string.sub(text, 1, p + 2) end
  return text
end

local function clipText(text, maxChars)
  local chars = utf8Chars(text or "")
  if #chars <= maxChars then return text or "" end
  local out = ""
  for i = 1, maxChars do out = out .. chars[i] end
  return out .. "…"
end

local function fitUnits(text, maxUnits)
  local chars = utf8Chars(text or "")
  local used = 0
  local out = ""
  for _, c in ipairs(chars) do
    local u = string.byte(c) > 127 and 2 or 1
    if used + u > maxUnits then
      local ellipsisUnits = 2
      while used + ellipsisUnits > maxUnits and #out > 0 do
        local kept = utf8Chars(out)
        local last = kept[#kept]
        out = string.sub(out, 1, #out - #last)
        used = used - (string.byte(last) > 127 and 2 or 1)
      end
      return out .. "…"
    end
    out = out .. c
    used = used + u
  end
  return out
end

local function ratingScore(rating)
  if rating == "上上卦" then return 3 end
  if rating == "中上卦" or rating == "上卦" then return 2 end
  if rating == "中中卦" then return 1 end
  if rating == "中下卦" then return 0 end
  return -1
end

local function drawHome(g, l, s)
  pcall(function()
    PkgImage.draw(g, HOME_BACKGROUND, 0, 0, { w = W, h = H })
  end)

  roundedRect(g, 72, 72, 336, 190, 16, "fill", 0)
  roundedRect(g, 72, 72, 336, 190, 16, "stroke", 15)
  centerHomeText(g, 100, "来杯好卦", 15)
  centerHomeText(g, 136, "爻一爻", 15)
  g:line(136, 172, W - 136, 172,{color=15})
  centerInputText(g, 195, "YI · SIX LINES", 15)
  centerInputText(g, 227, "古籍为根 · 静心占问", 15)

  roundedRect(g, 44, 286, W - 88, 54, 12, "fill", 0)
  roundedRect(g, 44, 286, W - 88, 54, 12, "stroke", 15)
  centerHomeText(g, 304, "本应用专注三枚钱六爻排盘", 15)

  roundedRect(g, 44, 366, W - 88, 158, 14, "fill", 0)
  roundedRect(g, 44, 366, W - 88, 158, 14, "stroke", 15)
  roundedRect(g, 48, 370, W - 96, 150, 11, "stroke", 15)
  textAt(g, 64, 386, "占问方向 · 所问之事（选填）", 15)
  g:line(64, 414, W - 64, 414,{color=15})
  local categoryLabel = s.questionCategory and CategoryAnalysis.label(s.questionCategory) or "未选择"
  textAt(g, 64, 424, "方向：" .. categoryLabel, 15)
  local qtext = (s.question == "") and "可直接爻卦；填写问题需先选择方向" or s.question
  local lines = wrap(qtext, 52)
  for i = 1, math.min(2, #lines) do
    textAt(g, 64, 448 + (i - 1) * 24, lines[i], 15)
  end
  roundedRect(g, W - 164, 482, 104, 28, 7, "fill", 15)
  centerText(g, W - 112, 488, State.hasQuestionContext(s) and "修改内容" or "选填内容", 0)

  roundedRect(g, 56, 580, W - 112, 66, 14, "fill", 15)
  centerHomeText(g, 603, "开始爻卦", 0)
  roundedRect(g, 90, 666, W - 180, 42, 10, "fill", 0)
  roundedRect(g, 90, 666, W - 180, 42, 10, "stroke", 15)
  centerInputText(g, 676, "三枚古钱 · 六次成卦", 15)
  roundedRect(g, 64, 734, W - 128, 36, 9, "fill", 0)
  centerHomeText(g, 743, "所问选填 · OK 直接开始爻卦", 15)
end

local VALUE_NAMES = { [6] = "老阴", [7] = "少阳", [8] = "少阴", [9] = "老阳" }

local function drawCoin(g, cx, cy, value)
  local radius = 31
  local hole = 13
  local halfHole = math.floor(hole / 2)
  if value == 3 then
    g:circle(cx, cy, radius,{fill=true,color=15})
    g:rect(cx - halfHole, cy - halfHole, hole, hole,{fill=true,color=0})
  else
    g:circle(cx, cy, radius,{color=15})
    if value == 2 then
      g:rect(cx - halfHole, cy - halfHole, hole, hole,{fill=true,color=15})
    else
      g:rect(cx - halfHole, cy - halfHole, hole, hole,{color=15})
    end
  end
end

local function drawCasting(g, l, s)
  centerText(g, W / 2, 44, "来杯好卦爻一爻", 15)
  local qtext
  if s.questionCategory and s.question ~= "" then
    qtext = "所问〔" .. CategoryAnalysis.label(s.questionCategory) .. "〕：" .. s.question
  elseif s.questionCategory then
    qtext = "所问〔" .. CategoryAnalysis.label(s.questionCategory) .. "〕：未填写具体问题"
  else
    qtext = "所问：未填写 · 本次按通用卦意"
  end
  local ql = wrap(qtext, 70)
  textAt(g, MARGIN + 10, 72, ql[1] or "", 15)
  if ql[2] then textAt(g, MARGIN + 10, 92, ql[2], 15) end
  g:line(MARGIN, 116, W - MARGIN, 116,{color=15})

  local coinY = 166
  local coinXs = { 144, 240, 336 }
  for i = 1, 3 do drawCoin(g, coinXs[i], coinY, s.lastCoins[i]) end
  if s.lastValue > 0 then
    centerText(g, W / 2, 208, s.lastValue .. " · " .. VALUE_NAMES[s.lastValue], 15)
  else
    centerText(g, W / 2, 208, "点击硬币摇出一爻", 15)
  end
  g:line(88, 238, W - 88, 238,{color=15})

  local baseY = 566
  local gap = 57
  local yw = 300
  local x = math.floor((W - yw) / 2)
  for pos = 6, 1, -1 do
    local y = baseY - (pos - 1) * gap
    local line = s.lines[pos]
    if line then
      yaoLine(g, x, y, yw, line.yang, line.moving)
      textAt(g, x - 34, y + 12, POS_NAMES[pos], 15)
      textAt(g, x + yw + 40, y + 12, line.moving and (line.yang and "老阳·动" or "老阴·动") or (line.yang and "少阳" or "少阴"), 15)
    else
      g:rect(x, y, yw, 2,{fill=true,color=15})
    end
  end

  local n = #s.lines
  textAt(g, MARGIN + 10, 622, "已摇 " .. n .. " / 6 爻", 15)
  if n < 6 then
    textAt(g, MARGIN + 10, 650, "点击上方硬币或按 OK 摇一爻", 15)
    textAt(g, MARGIN + 10, 676, "正面 2 · 背面 3 · 三枚相加定爻", 15)
  else
    textAt(g, MARGIN + 10, 650, "六爻已成 · 再按 OK 或点击硬币查看结果", 15)
    textAt(g, MARGIN + 10, 676, "本次 " .. s.lastValue .. " · " .. VALUE_NAMES[s.lastValue], 15)
  end
  textAt(g, MARGIN + 10, 702, "按外部左侧键回到首页，外部右侧键进入知识库", 15)
  textAt(g, MARGIN + 10, 726, "Back 返回并重新开始", 15)
end

local function drawIm(g, l, s)
  pcall(function()
    PkgImage.draw(g, INPUT_HEADER, 0, 0, { w = W, h = 260 })
  end)
  centerInputText(g, 250, "不诚不占，不义不占，不疑不占", 15)
  g:line(MARGIN, 280, W - MARGIN, 280,{color=15})

  centerInputText(g, 286, "先选择占问方向（14 选 1）", 15)
  for i, category in ipairs(CategoryAnalysis.options()) do
    local row = math.floor((i - 1) / 7)
    local col = (i - 1) % 7
    local x = CATEGORY_X + col * (CATEGORY_W + CATEGORY_GAP)
    local y = CATEGORY_Y + row * CATEGORY_ROW_STEP
    local active = (s.questionCategory == category.key) or (s.imInteracted and s.imFocus == i + 37)
    if active then
      roundedRect(g, x, y, CATEGORY_W, CATEGORY_H, 7, "fill", 15)
      centerText(g, x + CATEGORY_W / 2, y + 14, category.label, 0)
    else
      roundedRect(g, x, y, CATEGORY_W, CATEGORY_H, 7, "stroke", 15)
      centerText(g, x + CATEGORY_W / 2, y + 14, category.label, 15)
    end
  end

  local ty = 398 + INPUT_LOWER_SHIFT
  local py = s.imPinyin or ""
  local questionTitle = "具体问题 · " .. CategoryAnalysis.label(s.questionCategory)
  if imHasComposition(s) then questionTitle = questionTitle .. " · 拼音 " .. py end
  centerInputText(g, ty - 4, questionTitle, 15)
  roundedRect(g, MARGIN, ty + 22, W - MARGIN * 2, 60, 10, "stroke", 15)
  local qtext
  if not s.questionCategory then qtext = "请先选择上方方向"
  elseif s.question == "" then qtext = "选择完成，请输入具体问题"
  else qtext = s.question end
  local ql = wrap(qtext, 66)
  for i = 1, math.min(2, #ql) do
    textAt(g, MARGIN + 10, ty + 30 + (i - 1) * 22, ql[i], 15)
  end

  if imHasComposition(s) then
    local candidates = State.imCandidates(s)
    local candidateW = 69
    for i = 1, 6 do
      local label
      if i == 1 then label = "前页"
      elseif i == 6 then label = "后页"
      else label = candidates[i - 1] end
      local x = MARGIN + (i - 1) * (candidateW + 6)
      local focused = s.imInteracted and s.imFocus == i
      if focused then
        roundedRect(g, x, CANDIDATE_Y, candidateW, 34, 7, "fill", 15)
        centerText(g, x + candidateW / 2, CANDIDATE_Y + 8, label or "", 0)
      else
        roundedRect(g, x, CANDIDATE_Y, candidateW, 34, 7, "stroke", 15)
        centerText(g, x + candidateW / 2, CANDIDATE_Y + 8, label or "", 15)
      end
    end
  end

  local keyIndex = 0
  for rowIndex, row in ipairs(KEY_ROWS) do
    local rowY = imKeyboardRowY(s, rowIndex)
    for col = 1, #row.letters do
      keyIndex = keyIndex + 1
      local x = row.x + (col - 1) * (KEY_W + row.gap)
      local letter = string.sub(row.letters, col, col)
      local focused = s.imInteracted and s.imFocus == keyIndex + 6
      if focused then
        roundedRect(g, x, rowY, KEY_W, KEY_H, 6, "fill", 15)
        centerText(g, x + KEY_W / 2, rowY + 11, letter, 0)
      else
        roundedRect(g, x, rowY, KEY_W, KEY_H, 6, "stroke", 15)
        centerText(g, x + KEY_W / 2, rowY + 11, letter, 15)
      end
    end
  end

  local labels = { s.imMode == "cn" and "中文" or "EN", "删除", "空格", "确认", "返回" }
  local controlW = 84
  local controlY = imControlY(s)
  for i, label in ipairs(labels) do
    local x = MARGIN + (i - 1) * (controlW + 6)
    local focused = s.imInteracted and s.imFocus == i + 32
    if focused then
      roundedRect(g, x, controlY, controlW, 42, 8, "fill", 15)
      centerText(g, x + controlW / 2, controlY + 12, label, 0)
    else
      roundedRect(g, x, controlY, controlW, 42, 8, "stroke", 15)
      centerText(g, x + controlW / 2, controlY + 12, label, 15)
    end
  end
  centerInputText(g, controlY + 62, s.imMode == "cn" and "输入拼音后选字 · 空格确认首选" or "英文模式 · 字母直接上屏", 15)
  centerInputText(g, controlY + 88, "选择方向并输入问题后方可确认", 15)
end

function M.startButtonHit(ev, l)
  return ev.x >= 56 and ev.x <= W - 56
    and ev.y >= 580 and ev.y <= 646
end

function M.questionHit(ev, l)
  return ev.x >= 44 and ev.x <= W - 44
    and ev.y >= 366 and ev.y <= 524
end

function M.hexCatalogHit(ev, l, s)
  return LibraryView.hexCatalogHit(ev, l, s)
end

function M.catalogBackHit(ev, l)
  return LibraryView.catalogBackHit(ev, l)
end

function M.knowledgeBackHit(ev, l)
  return LibraryView.knowledgeBackHit(ev, l)
end

function M.coinAreaHit(ev, l)
  return ev.x >= 88 and ev.x <= W - 88
    and ev.y >= 126 and ev.y <= 228
end

function M.rerollHit(ev, l)
  return ev.x >= MARGIN and ev.x <= W - MARGIN
    and ev.y >= 712 and ev.y <= 768
end

function M.imHit(ev, l, s)
  for i, category in ipairs(CategoryAnalysis.options()) do
    local row = math.floor((i - 1) / 7)
    local col = (i - 1) % 7
    local x = CATEGORY_X + col * (CATEGORY_W + CATEGORY_GAP)
    local y = CATEGORY_Y + row * CATEGORY_ROW_STEP
    if ev.x >= x - 2 and ev.x <= x + CATEGORY_W + 2
      and ev.y >= y - 2 and ev.y <= y + CATEGORY_H + 2 then
      return { type = "category", category = category.key, focus = i + 37 }
    end
  end

  local candidateW = 69
  if imHasComposition(s) and ev.y >= CANDIDATE_Y and ev.y <= CANDIDATE_Y + 34
    and ev.x >= MARGIN and ev.x <= W - MARGIN then
    local i = math.floor((ev.x - MARGIN) / (candidateW + 6)) + 1
    if i == 1 then return { type = "candidate_prev", focus = 1 }
    elseif i == 6 then return { type = "candidate_next", focus = 6 }
    else
      local candidates = State.imCandidates(s)
      if i >= 2 and i <= 5 and candidates[i - 1] and candidates[i - 1] ~= "" then
        return { type = "candidate", index = i - 1, focus = i }
      end
    end
  end

  local keyIndex = 0
  for rowIndex, row in ipairs(KEY_ROWS) do
    local rowY = imKeyboardRowY(s, rowIndex)
    if ev.y >= rowY and ev.y <= rowY + KEY_H then
      for col = 1, #row.letters do
        keyIndex = keyIndex + 1
        local x = row.x + (col - 1) * (KEY_W + row.gap)
        if ev.x >= x and ev.x <= x + KEY_W then
          return { type = "letter", letter = string.sub(row.letters, col, col), focus = keyIndex + 6 }
        end
      end
    else
      keyIndex = keyIndex + #row.letters
    end
  end

  local controlW = 84
  local controlY = imControlY(s)
  if ev.y >= controlY and ev.y <= controlY + 42 then
    local i = math.floor((ev.x - MARGIN) / (controlW + 6)) + 1
    if i == 1 then return { type = "mode", mode = s.imMode == "cn" and "en" or "cn", focus = 33 } end
    if i == 2 then return { type = "backspace", focus = 34 } end
    if i == 3 then return { type = "space", focus = 35 } end
    if i == 4 then return { type = "done", focus = 36 } end
    if i == 5 then return { type = "close", focus = 37 } end
  end
  return nil
end

function M.draw(ctx, g, s)
  local l = M.layout(ctx)
  g:clear(0)
  if s.imOpen then
    drawIm(g, l, s)
  elseif s.page == 1 then
    drawHome(g, l, s)
  elseif s.page == 2 then
    drawCasting(g, l, s)
  elseif s.page == 3 then
    resultView().draw(g, l, s)
  elseif s.page == 4 then
    LibraryView.drawCatalog(g, l, s)
  else
    LibraryView.drawKnowledge(g, l, s)
  end
end

return M
