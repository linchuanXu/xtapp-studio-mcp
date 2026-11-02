-- 六十四卦总表与完整知识页。独立模块用于降低真机启动时单个 Lua 文件的解析峰值。
local HexData = require("domain.hexagram_data")
local HexText = require("domain.hexagram_text")
local KnowledgeDB = require("domain.hexagram_knowledge_db")

local M = {}
local W = 480
local MARGIN = 16
local KNOWLEDGE_WRAP_UNITS = 44
local CATALOG_LABEL_X = 8
local CATALOG_LABEL_W = 64
local CATALOG_X = 72
local CATALOG_Y = 156
local CATALOG_CELL_W = 100
local CATALOG_CELL_H = 128
local CATALOG_HEADER_Y = 84
local CATALOG_HEADER_H = 72
local TRI_BITS = {
  [1] = { true, true, true },
  [2] = { true, true, false },
  [3] = { true, false, true },
  [4] = { true, false, false },
  [5] = { false, true, true },
  [6] = { false, true, false },
  [7] = { false, false, true },
  [8] = { false, false, false },
}
local TRI_IMAGES = { "天", "泽", "火", "雷", "风", "水", "山", "地" }

local function utf8Chars(str)
  local chars, i, n = {}, 1, #str
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
  for _, ch in ipairs(utf8Chars(str)) do
    local size = string.byte(ch) > 127 and 2 or 1
    if units + size > maxUnits then
      lines[#lines + 1] = cur
      cur, units = ch, size
    else
      cur, units = cur .. ch, units + size
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end

local function strUnits(str)
  local units = 0
  for _, ch in ipairs(utf8Chars(str)) do units = units + (string.byte(ch) > 127 and 2 or 1) end
  return units
end

local function textAt(g, x, y, str, color)
  g:text(x, y, str, { color = color })
end

local function centerText(g, cx, y, str, color)
  g:text(math.max(0, cx - strUnits(str) * 6), y, str, { color = color })
end

local function centerDeviceText(g, y, str, color, offsetX)
  g:text(math.max(0, W / 2 - strUnits(str) * 5 + (offsetX or 0)), y, str, { color = color })
end

local function drawMiniYao(g, x, y, width, yang)
  if yang then
    g:rect(x, y, width, 2,{fill=true,color=15})
  else
    local segment = math.floor((width - 6) / 2)
    g:rect(x, y, segment, 2,{fill=true,color=15})
    g:rect(x + segment + 6, y, segment, 2,{fill=true,color=15})
  end
end

local function drawMiniHex(g, x, y, lower, upper, width, step)
  local lowerBits, upperBits = TRI_BITS[lower], TRI_BITS[upper]
  local display = { upperBits[3], upperBits[2], upperBits[1], lowerBits[3], lowerBits[2], lowerBits[1] }
  for i, yang in ipairs(display) do drawMiniYao(g, x, y + (i - 1) * step, width, yang) end
end

local function drawMiniTri(g, x, y, index)
  local bits = TRI_BITS[index]
  for i = 1, 3 do drawMiniYao(g, x, y + (i - 1) * 7, 34, bits[4 - i]) end
end

function M.drawCatalog(g, l, s)
  local page = math.max(1, math.min(4, s.catalogPage or 1))
  local firstCol = math.floor((page - 1) / 2) * 4 + 1
  local firstRow = ((page - 1) % 2) * 4 + 1
  local colNames = firstCol == 1 and "乾 兑 离 震" or "巽 坎 艮 坤"
  local rowNames = firstRow == 1 and "乾 兑 离 震行" or "巽 坎 艮 坤行"
  centerText(g, W / 2, 12, "六十四卦知识总表", 15)
  centerText(g, W / 2 + 45, 38, "按上卦为列、下卦为行·点击卦格查看完整资料", 15)
  local pageLabel = "第" .. page .. "/4页"
  local directionLabel = colNames .. " · " .. rowNames
  textAt(g, 6, 58, pageLabel, 15)
  centerDeviceText(g, 58, directionLabel, 15, 19)

  g:rect(CATALOG_LABEL_X, CATALOG_HEADER_Y, CATALOG_LABEL_W, CATALOG_HEADER_H,{color=15})
  centerText(g, CATALOG_LABEL_X + CATALOG_LABEL_W / 2, CATALOG_HEADER_Y + 10, "上卦", 15)
  centerText(g, CATALOG_LABEL_X + CATALOG_LABEL_W / 2, CATALOG_HEADER_Y + 36, "下卦", 15)
  for localCol = 1, 4 do
    local col = firstCol + localCol - 1
    local x = CATALOG_X + (localCol - 1) * CATALOG_CELL_W
    g:rect(x, CATALOG_HEADER_Y, CATALOG_CELL_W, CATALOG_HEADER_H,{color=15})
    drawMiniTri(g, x + 33, CATALOG_HEADER_Y + 8, col)
    centerText(g, x + CATALOG_CELL_W / 2, CATALOG_HEADER_Y + 38, HexData.tri[col].n .. "（" .. TRI_IMAGES[col] .. "）", 15)
  end

  for localRow = 1, 4 do
    local row = firstRow + localRow - 1
    local y = CATALOG_Y + (localRow - 1) * CATALOG_CELL_H
    g:rect(CATALOG_LABEL_X, y, CATALOG_LABEL_W, CATALOG_CELL_H,{color=15})
    drawMiniTri(g, CATALOG_LABEL_X + 15, y + 38, row)
    centerText(g, CATALOG_LABEL_X + CATALOG_LABEL_W / 2, y + 68, HexData.tri[row].n, 15)
    for localCol = 1, 4 do
      local col = firstCol + localCol - 1
      local x = CATALOG_X + (localCol - 1) * CATALOG_CELL_W
      local hex = HexData.hex[row .. "_" .. col]
      local record = hex and HexText.get(hex.n)
      g:rect(x, y, CATALOG_CELL_W, CATALOG_CELL_H,{color=15})
      if hex then
        drawMiniHex(g, x + 20, y + 12, row, col, 60, 8)
        local textCenterX = x + CATALOG_CELL_W / 2 + 3
        centerText(g, textCenterX, y + 59, hex.n, 15)
        centerText(g, textCenterX, y + 79, record and record.index or "--", 15)
        centerText(g, textCenterX, y + 99, record and record.rating or "资料待补", 15)
      end
    end
  end
  centerDeviceText(g, 680, "点击任意放大卦格进入完整知识库", 15)
  if page == 1 then
    centerDeviceText(g, 708, "下：第二页 · 上 / Back：返回摇卦", 15, 13)
  elseif page == 4 then
    centerDeviceText(g, 708, "上：第三页 · Back：返回摇卦", 15, 13)
  else
    centerDeviceText(g, 708, "上：上一页 · 下：下一页 · Back：返回摇卦", 15, 13)
  end
  g:rect(96, 734, W - 192, 48,{color=15})
  centerText(g, W / 2, 748, "返回摇卦", 15)
end

local function appendKnowledgeText(out, text, maxUnits)
  local source = (text or "") .. "\n"
  for paragraph in string.gmatch(source, "([^\n]*)\n") do
    if paragraph == "" then
      if #out > 0 and out[#out] ~= "" then out[#out + 1] = "" end
    else
      for _, line in ipairs(wrap(paragraph, maxUnits)) do out[#out + 1] = line end
    end
  end
end

local function knowledgeLines(record)
  if not record then return { "暂未找到该卦知识库资料。" } end
  local out = {}
  for _, section in ipairs(record.sections or {}) do
    for _, line in ipairs(wrap("【" .. section.title .. "】", KNOWLEDGE_WRAP_UNITS)) do out[#out + 1] = line end
    appendKnowledgeText(out, section.text, KNOWLEDGE_WRAP_UNITS)
    if out[#out] ~= "" then out[#out + 1] = "" end
  end
  return out
end

function M.drawKnowledge(g, l, s)
  local record = KnowledgeDB.get(s.knowledgeName or "")
  if not record then
    centerText(g, W / 2, 28, "知识库资料缺失", 15)
    centerText(g, W / 2, 380, "Back 返回六十四卦总表", 15)
    return
  end
  centerDeviceText(g, 18, "第" .. record.index .. "卦 · " .. record.name .. " · " .. record.rating, 15)
  centerDeviceText(g, 44, "完整离线知识库", 15)
  g:line(MARGIN, 70, W - MARGIN, 70,{color=15})
  local lines = knowledgeLines(record)
  local linesPerPage = 24
  local pageMax = math.max(1, math.ceil(#lines / linesPerPage))
  s.knowledgePageMax = pageMax
  if s.knowledgePage > pageMax then s.knowledgePage = pageMax end
  local first = (s.knowledgePage - 1) * linesPerPage + 1
  for i = 0, linesPerPage - 1 do
    local line = lines[first + i]
    if not line then break end
    textAt(g, MARGIN + 4, 84 + i * 24, line, 15)
  end
  g:line(MARGIN, 674, W - MARGIN, 674,{color=15})
  centerText(g, W / 2, 686, s.knowledgePage .. "/" .. pageMax .. " · 上下翻页", 15)
  g:rect(80, 726, W - 160, 48,{color=15})
  centerText(g, W / 2, 740, "Back 返回六十四卦总表", 15)
end

function M.hexCatalogHit(ev, l, s)
  if ev.x < CATALOG_X or ev.x >= CATALOG_X + CATALOG_CELL_W * 4 then return nil end
  if ev.y < CATALOG_Y or ev.y >= CATALOG_Y + CATALOG_CELL_H * 4 then return nil end
  local localCol = math.floor((ev.x - CATALOG_X) / CATALOG_CELL_W) + 1
  local page = math.max(1, math.min(4, s.catalogPage or 1))
  local col = math.floor((page - 1) / 2) * 4 + localCol
  local localRow = math.floor((ev.y - CATALOG_Y) / CATALOG_CELL_H) + 1
  local row = ((page - 1) % 2) * 4 + localRow
  local hex = HexData.hex[row .. "_" .. col]
  return hex and hex.n or nil
end

function M.catalogBackHit(ev, l)
  return ev.x >= 96 and ev.x <= W - 96 and ev.y >= 734 and ev.y <= 782
end

function M.knowledgeBackHit(ev, l)
  return ev.x >= 80 and ev.x <= W - 80 and ev.y >= 726 and ev.y <= 774
end

return M
