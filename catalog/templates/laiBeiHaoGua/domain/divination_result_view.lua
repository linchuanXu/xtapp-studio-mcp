-- 结果页独立绘制模块：降低真机启动时单文件解析峰值。
local Hex = require("domain.hexagram")
local CategoryAnalysis = require("domain.category_analysis")

local M = {}
local W = 480
local H = 800
local MARGIN = 16
local DETAIL_WRAP_UNITS = 54
local HEX_TEXT_CACHE = nil

local function hexText(name)
  if not HEX_TEXT_CACHE then HEX_TEXT_CACHE = require("domain.hexagram_text") end
  return HEX_TEXT_CACHE.get(name)
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

local function roundedFill(g, x, y, w, h, radius, color)
  local r = math.max(0, math.min(radius, math.floor(w / 2), math.floor(h / 2)))
  if r == 0 then g:rect(x, y, w, h, "fill", color); return end
  g:rect(x + r, y, w - r * 2, h, "fill", color)
  g:rect(x, y + r, w, h - r * 2, "fill", color)
  g:circle(x + r, y + r, r, "fill", color)
  g:circle(x + w - 1 - r, y + r, r, "fill", color)
  g:circle(x + r, y + h - 1 - r, r, "fill", color)
  g:circle(x + w - 1 - r, y + h - 1 - r, r, "fill", color)
end

local function roundedRect(g, x, y, w, h, radius, mode, color)
  if mode == "fill" then roundedFill(g, x, y, w, h, radius, color); return end
  roundedFill(g, x, y, w, h, radius, color)
  local border = 2
  roundedFill(g, x + border, y + border, w - border * 2, h - border * 2,
    math.max(0, radius - border), color == 15 and 0 or 15)
end

local function yaoCompact(g, x, y, w, yang)
  local h = 8
  if yang then
    g:rect(x, y, w, h, "fill", 15)
  else
    local seg = math.floor((w - 16) / 2)
    g:rect(x, y, seg, h, "fill", 15)
    g:rect(x + seg + 16, y, seg, h, "fill", 15)
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

local function drawSubHeader(g, title, dateStr, sub)
  textAt(g, MARGIN + 10, 28, "来杯好卦爻一爻", 15)
  textAt(g, MARGIN + 10, 52, "起卦 " .. dateStr, 15)
  textAt(g, W - MARGIN - 152, 28, title, 15)
  textAt(g, W - MARGIN - 36, 52, sub .. "/4", 15)
  g:line(MARGIN, 82, W - MARGIN, 82, 15)
end

local function drawOneHex(g, x, width, label, name, palace, upper, lower, lines, changed)
  local cx = x + width / 2
  centerText(g, cx, 90, label, 15)
  for pos = 6, 1, -1 do
    local y = 120 + (6 - pos) * 28
    local lt = lines[pos]
    local yang = changed and (lt.moving and not lt.yang or lt.yang) or lt.yang
    textAt(g, x - 20, y - 2, POS_NAMES[pos], 15)
    yaoCompact(g, x, y, width, yang)
    if not changed and lt.moving then
      g:rect(x + width + 8, y, 8, 8, "fill", 15)
    end
  end
  centerText(g, cx, 300, name, 15)
  centerText(g, cx, 324, palace, 15)
  centerText(g, cx, 346, "上" .. upper .. " 下" .. lower, 15)
end

local function drawHexPair(g, r)
  if r.bian then
    drawOneHex(g, 50, 132, "本卦", r.ben.name,
      r.ben.palaceName .. "·" .. r.ben.palaceWx,
      r.ben.upperName, r.ben.lowerName, r.lines, false)
    centerText(g, W / 2, 190, "→", 15)
    drawOneHex(g, 298, 132, "变卦", r.bian.name,
      r.bian.palaceName .. "·" .. r.bian.palaceWx,
      r.bian.upperName, r.bian.lowerName, r.lines, true)
  else
    drawOneHex(g, 130, 220, "本卦（静卦）", r.ben.name,
      r.ben.palaceName .. "·" .. r.ben.palaceWx,
      r.ben.upperName, r.ben.lowerName, r.lines, false)
  end
  if r.ben.liuhe then
    local tagY = r.bian and 334 or 368
    centerText(g, W / 2, tagY, "〔六合卦〕", 15)
  end
end

local function drawInfoBlock(g, r, y)
  y = y or 612
  g:line(MARGIN, y, W - MARGIN, y, 15)
  textAt(g, MARGIN + 12, y + 10, "干支  年 " .. r.year .. "  月 " .. r.month, 15)
  textAt(g, MARGIN + 70, y + 32, "日 " .. r.day .. "  时 " .. r.hour, 15)
  textAt(g, MARGIN + 12, y + 54, "旬空  日 " .. r.kongDay .. "  时 " .. r.kongHour, 15)
  g:line(MARGIN, y + 88, W - MARGIN, y + 88, 15)
end

local function buildReferenceAnalysis(s, r)
  local item = hexText(r.ben.name)
  local lines = CategoryAnalysis.build(s.questionCategory, s.question, r)
  if not item then
    lines[#lines + 1] = "卦辞：暂未找到本卦资料，请结合用神明细审慎参考。"
    return lines
  end
  local config = CategoryAnalysis.get(s.questionCategory) or { field = "decision", label = "综合" }
  lines[#lines + 1] = "卦旨：本卦" .. r.ben.name .. "，重点“" .. item.subtitle .. "”。"
  if r.bian then
    local bianItem = hexText(r.bian.name)
    local positions = ""
    for i, mv in ipairs(r.moves) do
      if i > 1 then positions = positions .. "、" end
      positions = positions .. POS_NAMES[mv.pos]
    end
    local change = "变卦：" .. positions .. "爻动，后势转为" .. r.bian.name .. "。"
    if bianItem then
      local delta = ratingScore(bianItem.rating) - ratingScore(item.rating)
      if delta > 0 then change = change .. "趋势改善；"
      elseif delta < 0 then change = change .. "后势需谨慎；"
      else change = change .. "基调延续；" end
      change = change .. "重点“" .. bianItem.subtitle .. "”。"
    end
    lines[#lines + 1] = change
  else
    lines[#lines + 1] = "变化：无动爻，当前态势较稳定。"
  end
  lines[#lines + 1] = config.label .. "卦辞：" .. clipText(firstSentence(item[config.field] or item.decision), 22)
  lines[#lines + 1] = "提醒：卦象仅供传统文化参考，现实决定须核对事实与专业意见。"
  return lines
end

local function wrapAnalysis(text)
  local lines = wrap(text, 42)
  if #lines > 1 then
    local tail = utf8Chars(lines[#lines] or "")
    if #tail == 1 then lines[#lines] = nil end
  end
  return lines
end

local function drawQuestionAndAnalysis(g, s, r)
  local y = 378
  g:line(MARGIN, y, W - MARGIN, y, 15)
  textAt(g, MARGIN + 12, y + 12, "所问〔" .. CategoryAnalysis.label(s.questionCategory) .. "〕", 15)
  local questionLines = wrap(s.question == "" and "未填写" or s.question, 52)
  for i = 1, math.min(2, #questionLines) do
    textAt(g, MARGIN + 132, y + 12 + (i - 1) * 22, questionLines[i], 15)
  end
  local analysisY = y + (#questionLines > 1 and 62 or 42)
  g:line(MARGIN, analysisY, W - MARGIN, analysisY, 15)
  local sections = buildReferenceAnalysis(s, r)
  local allLines = {}
  for _, section in ipairs(sections) do
    for _, line in ipairs(wrapAnalysis(section)) do allLines[#allLines + 1] = line end
  end

  local linesPerPage = 5
  local pageMax = math.max(1, math.ceil(#allLines / linesPerPage))
  s.analysisPageMax = pageMax
  s.analysisPage = math.max(1, math.min(s.analysisPage or 1, pageMax))
  local title = "参考分析  " .. s.analysisPage .. "/" .. pageMax
  textAt(g, MARGIN + 12, analysisY + 12, title, 15)
  textAt(g, MARGIN + 13, analysisY + 12, title, 15)

  local start = (s.analysisPage - 1) * linesPerPage + 1
  for row = 1, linesPerPage do
    local line = allLines[start + row - 1]
    if line then textAt(g, MARGIN + 12, analysisY + 40 + (row - 1) * 24, line, 15) end
  end
  local bottom = analysisY + 188
  g:line(MARGIN, bottom, W - MARGIN, bottom, 15)
  return bottom
end

local function drawResult1(g, l, s, r)
  drawSubHeader(g, "卦象总览", r.dateStr, "1")
  drawHexPair(g, r)
  local infoY = drawQuestionAndAnalysis(g, s, r)
  drawInfoBlock(g, r, math.min(630, math.max(594, infoY)))
end

local function badgeTag(g, x, y, text)
  g:rect(x, y, 20, 16, "fill", 15)
  g:text(x + 5, y + 1, text, { color = 0 })
end

local function drawResult2(g, l, s, r)
  drawSubHeader(g, "六亲 · 六神 · 世应", r.dateStr, "2")
  local colY = 112
  local lx, rx, colW
  if r.bian then lx, rx, colW = 14, 246, 220 else lx, rx, colW = 62, nil, 356 end
  local rowH = 82

  centerText(g, lx + colW / 2, colY - 26, "本卦", 15)
  if r.bian then
    centerText(g, W / 2, colY - 26, "→", 15)
    centerText(g, rx + colW / 2, colY - 26, "变卦", 15)
  end

  for i = 1, 6 do
    local pos = 7 - i
    local lt = r.lines[pos]
    local yy = colY + (i - 1) * rowH
    g:line(lx, yy, lx + colW, yy, 15)
    if r.bian then g:line(rx, yy, rx + colW, yy, 15) end
    textAt(g, lx + 4, yy + 6, lt.shen .. " " .. lt.rel .. " " .. lt.gz .. " " .. lt.wxName, 15)
    textAt(g, lx + 4, yy + 34, lt.monthState .. " · " .. lt.longState, 15)
    yaoCompact(g, lx + colW - 72, yy + 56, 64, lt.yang)
    local bx = lx + colW - 8
    if lt.moving then badgeTag(g, bx - 24, yy + 8, "动"); bx = bx - 28 end
    if lt.shi then badgeTag(g, bx - 24, yy + 8, "世"); bx = bx - 28 end
    if lt.ying then badgeTag(g, bx - 24, yy + 8, "应") end
    if r.bian then
      local bl = r.bian.lines[pos]
      textAt(g, rx + 4, yy + 6, bl.rel .. " " .. bl.gz .. " " .. bl.wxName, 15)
      textAt(g, rx + 4, yy + 34, "日辰 " .. bl.longState, 15)
      local byang = lt.moving and not lt.yang or lt.yang
      yaoCompact(g, rx + colW - 72, yy + 56, 64, byang)
      if bl.empty then badgeTag(g, rx + colW - 28, yy + 8, "空") end
    end
  end
  g:line(lx, colY + 6 * rowH, lx + colW, colY + 6 * rowH, 15)
  if r.bian then g:line(rx, colY + 6 * rowH, rx + colW, colY + 6 * rowH, 15) end
end

local function drawResult3(g, l, s, r)
  drawSubHeader(g, "动爻化象 · 飞伏 · 神煞", r.dateStr, "3")
  local y = 100
  textAt(g, MARGIN + 10, y, "动爻化象", 15)
  y = y + 26
  if #r.moves == 0 then
    textAt(g, MARGIN + 22, y, "本卦无动爻，静卦不变", 15)
  else
    for _, mv in ipairs(r.moves) do
      textAt(g, MARGIN + 22, y, POS_NAMES[mv.pos] .. "爻  " .. mv.from .. " → " .. mv.to, 15)
      textAt(g, MARGIN + 42, y + 22, mv.relWord .. " · " .. mv.longWord, 15)
      y = y + 50
    end
  end
  y = y + 12
  g:line(MARGIN + 10, y, W - MARGIN - 10, y, 15)
  y = y + 18
  textAt(g, MARGIN + 10, y, "飞伏神 · 六亲不上卦", 15)
  y = y + 22
  if #r.fu == 0 then
    textAt(g, MARGIN + 22, y, "六亲俱全，无伏神", 15)
  else
    for _, fv in ipairs(r.fu) do
      textAt(g, MARGIN + 22, y, POS_NAMES[fv.pos] .. "爻 伏" .. fv.fuRel .. fv.fuGz .. " · 飞" .. fv.feiRel .. fv.feiGz, 15)
      y = y + 24
    end
  end
  y = y + 12
  g:line(MARGIN + 10, y, W - MARGIN - 10, y, 15)
  y = y + 18
  textAt(g, MARGIN + 10, y, "神煞", 15)
  textAt(g, MARGIN + 22, y + 22, "驿马 " .. r.sha.ma .. " · 桃花 " .. r.sha.tao, 15)
  textAt(g, MARGIN + 22, y + 44, "干禄 " .. r.sha.lu .. " · 贵人 " .. r.sha.gui1 .. "、" .. r.sha.gui2, 15)
end

local function interpretationLines(item, bianItem, categoryKey, question, r)
  if not item then return { "暂未找到本卦解读数据。" } end
  local config = CategoryAnalysis.get(categoryKey) or { field = "decision", label = "综合" }
  local out = {
    item.index .. "  " .. item.name .. "  " .. item.subtitle .. "  " .. item.rating,
    "",
    "所问",
  }
  local function appendDetail(text, indent)
    local width = DETAIL_WRAP_UNITS - (indent and 2 or 0)
    for _, line in ipairs(wrap(text or "", width)) do
      out[#out + 1] = (indent and "  " or "") .. line
    end
  end
  appendDetail(question == "" and "未填写" or question, true)
  out[#out + 1] = ""
  out[#out + 1] = "分类分析 · " .. config.label
  for _, section in ipairs(CategoryAnalysis.build(categoryKey, question, r)) do
    appendDetail(section, true)
  end
  out[#out + 1] = ""
  out[#out + 1] = "对应卦辞 · " .. config.label
  appendDetail(item[config.field] or item.decision, true)
  out[#out + 1] = ""
  if bianItem then
    out[#out + 1] = "变卦趋势 · " .. bianItem.name
    appendDetail(bianItem[config.field] or bianItem.decision, true)
    out[#out + 1] = ""
    local positions = ""
    for i, mv in ipairs(r.moves) do
      if i > 1 then positions = positions .. "、" end
      positions = positions .. POS_NAMES[mv.pos]
    end
    out[#out + 1] = "动爻提示"
    appendDetail(positions .. "爻发动，事情正在变化；本卦看当下，变卦看后续趋势。", true)
  else
    out[#out + 1] = "静卦提示"
    appendDetail("本卦无动爻，当前态势相对稳定，以本卦建议为主要参考。", true)
  end
  out[#out + 1] = ""
  out[#out + 1] = "本卦完整解读"
  out[#out + 1] = ""
  local function add(label, value)
    out[#out + 1] = label
    appendDetail(value, true)
    out[#out + 1] = ""
  end
  add("象曰", item.xiang)
  add("卦意", item.summary)
  add("事业", item.career)
  add("经商", item.business)
  add("求名", item.fame)
  add("外出", item.travel)
  add("婚恋", item.marriage)
  add("决策", item.decision)
  return out
end

local function drawResult4(g, l, s, r)
  drawSubHeader(g, "卦辞解读", r.dateStr, "4")
  local item = hexText(r.ben.name)
  local bianItem = r.bian and hexText(r.bian.name) or nil
  local lines = interpretationLines(item, bianItem, s.questionCategory, s.question, r)
  local maxStart = math.max(0, #lines - 23)
  local start = math.min(s.detailOffset or 0, maxStart)
  s.detailOffset = start
  local y = 100
  for i = start + 1, math.min(#lines, start + 23) do
    textAt(g, MARGIN + 12, y, lines[i], 15)
    y = y + 25
  end
  if maxStart > 0 then
    textAt(g, W - MARGIN - 146, 684, "上下滚动 " .. (start + 1) .. "/" .. (#lines - 22), 15)
  end
end

function M.draw(g, l, s)
  local r = Hex.calc(s.lines, s.castTs, s.castCivil)
  if s.resultSub == 1 then drawResult1(g, l, s, r)
  elseif s.resultSub == 2 then drawResult2(g, l, s, r)
  elseif s.resultSub == 3 then drawResult3(g, l, s, r)
  else drawResult4(g, l, s, r) end

  local by = 712
  roundedRect(g, MARGIN, by, W - MARGIN * 2, 56, 12, "fill", 15)
  centerText(g, W / 2, by + 20, "重新摇卦", 0)
  centerText(g, W / 2, H - 30, "OK重摇｜左右切｜上下翻页｜Back返", 15)
end


return M
