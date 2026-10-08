-- 六爻卦象算法：干支、纳甲、六亲、六神、世应、空亡、旺衰、长生、飞伏、动变化象、神煞
local Data = require("domain.hexagram_data")

local M = {}

local GAN = "甲乙丙丁戊己庚辛壬癸"
local ZHI = "子丑寅卯辰巳午未申酉戌亥"
local WX_NAMES = { "木", "火", "土", "金", "水" }
local WX_IDX = { ["木"] = 0, ["火"] = 1, ["土"] = 2, ["金"] = 3, ["水"] = 4 }
local LIU_SHEN = { "青龙", "朱雀", "勾陈", "腾蛇", "白虎", "玄武" }
local LIU_QIN = { "父母", "兄弟", "子孙", "妻财", "官鬼" }
local ZHANG = { "长生", "沐浴", "冠带", "临官", "帝旺", "衰", "病", "死", "墓", "绝", "胎", "养" }
local ZHANG_START = { ["木"] = 11, ["火"] = 2, ["金"] = 5, ["土"] = 8, ["水"] = 8 } -- 长生地支序：木亥 火寅 金巳 水土申
local MONTH_WX = { ["寅"] = 0, ["卯"] = 0, ["辰"] = 2, ["巳"] = 1, ["午"] = 1, ["未"] = 2, ["申"] = 3, ["酉"] = 3, ["戌"] = 2, ["亥"] = 4, ["子"] = 4, ["丑"] = 2 }
local ZHI_WX = { ["木"] = { "寅", "卯" }, ["火"] = { "巳", "午" }, ["土"] = { "辰", "戌", "丑", "未" }, ["金"] = { "申", "酉" }, ["水"] = { "亥", "子" } }
-- 三合局：申子辰 / 寅午戌 / 巳酉丑 / 亥卯未 -> 驿马 / 桃花
local SANHE = { { 8, 0, 4 }, { 2, 6, 10 }, { 5, 9, 1 }, { 11, 3, 7 } }
local MA = { 2, 8, 11, 4 }   -- 寅 申 亥 巳
local TAO = { 9, 3, 6, 0 }   -- 酉 卯 午 子
local LU = { 2, 3, 4, 5, 4, 5, 8, 8, 11, 0 } -- 甲寅乙卯丙戊巳丁己午庚申辛酉壬亥癸子
local GUI = { { 1, 7 }, { 0, 8 }, { 11, 9 }, { 11, 9 }, { 1, 7 }, { 0, 8 }, { 1, 7 }, { 1, 7 }, { 3, 5 }, { 3, 5 } } -- 甲戊庚牛羊 乙己鼠猴 丙丁猪鸡 壬癸兔蛇 辛马虎
local LIUHE_HEX = { "天地否", "地天泰", "天泽履", "天山遁", "水泽节", "雷地豫", "火地晋" }

local BITS_TO_T = {
  ["111"] = 1, ["110"] = 2, ["101"] = 3, ["100"] = 4,
  ["011"] = 5, ["010"] = 6, ["001"] = 7, ["000"] = 8
}

-- 公历(y,m,d) -> JDN（自1970-01-01起算天数 + 2440588）
local function civilToJdn(y, m, d)
  local a = math.floor((14 - m) / 12)
  local yy = y + 4800 - a
  local mm = m + 12 * a - 3
  local jdn = d + math.floor((153 * mm + 2) / 5) + 365 * yy
    + math.floor(yy / 4) - math.floor(yy / 100) + math.floor(yy / 400) - 32045
  return jdn
end

-- epoch 秒 -> {year, month, day, hour, minute}
function M.civilFromEpoch(sec)
  sec = math.floor(tonumber(sec) or 0)
  if sec < 0 then sec = 0 end
  local days = sec // 86400
  local rem = sec - days * 86400
  local jdn = days + 2440588
  local a = jdn + 32044
  local b = math.floor((4 * a + 3) / 146097)
  local c = a - math.floor(146097 * b / 4)
  local d = math.floor((4 * c + 3) / 1461)
  local e = c - math.floor(1461 * d / 4)
  local m = math.floor((5 * e + 2) / 153)
  local day = e - math.floor((153 * m + 2) / 5) + 1
  local month = m + 3 - 12 * math.floor(m / 10)
  local year = 100 * b + d - 4800 + math.floor(m / 10)
  local hour = rem // 3600
  local minute = (rem % 3600) // 60
  return { year = year, month = month, day = day, hour = hour, minute = minute }
end

local function n60(gan, zhi)
  local n = zhi
  while n % 10 ~= gan do n = n + 12 end
  return n % 60
end

local function gz(n)
  n = ((n % 60) + 60) % 60
  local gi = n % 10
  local zi = n % 12
  return string.sub(GAN, gi * 3 + 1, gi * 3 + 3) .. string.sub(ZHI, zi * 3 + 1, zi * 3 + 3)
end

-- 空亡两字（干支序 n）
local function kong(n)
  local head = n - (n % 10)
  local z1 = (head + 10) % 12
  local z2 = (head + 11) % 12
  return string.sub(ZHI, z1 * 3 + 1, z1 * 3 + 3) .. string.sub(ZHI, z2 * 3 + 1, z2 * 3 + 3)
end

local function zhiIdx(c)
  local p = string.find(ZHI, c, 1, true)
  if not p then return -1 end
  return (p - 1) / 3
end

-- 干支四柱（year 为公历年；month/day/hour 为公历）
local function ganzhiTable(dt)
  dt.year = dt.year or 1970
  dt.month = dt.month or 1
  dt.day = dt.day or 1
  dt.hour = dt.hour or 0
  local yg = ((dt.year - 4) % 10 + 10) % 10
  local yz = ((dt.year - 4) % 12 + 12) % 12
  local yearN = n60(yg, yz)
  local mz = dt.month % 12
  local mg = (yg % 5 * 2 + mz) % 10
  local monthN = n60(mg, mz)
  local jdn = civilToJdn(dt.year, dt.month, dt.day)
  local dayN = (jdn + 49) % 60
  local hz = math.floor((dt.hour + 1) / 2) % 12
  local hg = (dayN % 5 * 2 + hz) % 10
  local hourN = n60(hg, hz)
  return {
    year = gz(yearN), month = gz(monthN), day = gz(dayN), hour = gz(hourN),
    yearN = yearN, monthN = monthN, dayN = dayN, hourN = hourN,
    dayGan = yg, dayZhi = dayN % 12, monthZhi = mz, hourZhi = hz,
    dayN60 = dayN
  }
end

-- 爻位干支（pos 1..6，自下而上）
local function lineGanzhi(lowerT, upperT, pos)
  local tr = pos <= 3 and Data.tri[lowerT] or Data.tri[upperT]
  local arr = pos <= 3 and tr.zi or tr.zo
  local idx = pos <= 3 and pos or (pos - 3)
  local gan = pos <= 3 and tr.gi or tr.go
  return gan .. arr[idx]
end

local function lineWxIdx(lowerT, upperT, pos)
  local tr = pos <= 3 and Data.tri[lowerT] or Data.tri[upperT]
  if not tr then return 1 end
  return WX_IDX[tr.wx] or 1
end

-- 六亲：myIdx 为卦宫五行序，lineIdx 为爻五行序
local function relName(myIdx, lineIdx)
  myIdx = myIdx or 1
  lineIdx = lineIdx or 1
  if lineIdx == myIdx then return "兄弟" end
  if lineIdx == (myIdx + 1) % 5 then return "子孙" end
  if lineIdx == (myIdx + 2) % 5 then return "妻财" end
  if myIdx == (lineIdx + 1) % 5 then return "父母" end
  return "官鬼"
end

-- 十二长生：日支序、五行序
local function zhangSheng(dayZhi, wxIdx)
  wxIdx = wxIdx or 1
  dayZhi = dayZhi or 0
  local start = ZHANG_START[WX_NAMES[wxIdx + 1]] or 0
  local idx = ((dayZhi - start) % 12) + 1
  return ZHANG[idx] or "长生"
end

-- 月令旺相休囚死
local function monthState(mm, wxIdx)
  mm = mm or 2
  wxIdx = wxIdx or 1
  if wxIdx == mm then return "旺" end
  if wxIdx == (mm + 1) % 5 then return "相" end
  if wxIdx == (mm + 2) % 5 then return "死" end
  if wxIdx == (mm + 3) % 5 then return "囚" end
  return "休"
end

-- 六神起始：日干序 0..9
local function startShen(dayGan)
  dayGan = dayGan or 0
  if dayGan <= 1 then return 1 end
  if dayGan <= 3 then return 2 end
  if dayGan == 4 then return 3 end
  if dayGan == 5 then return 4 end
  if dayGan <= 7 then return 5 end
  return 6
end

local function trigramFromBits(l1, l2, l3)
  return BITS_TO_T[(l1 and "1" or "0") .. (l2 and "1" or "0") .. (l3 and "1" or "0")]
end

-- 动爻化象关系词（原爻五行 -> 变爻五行，五行序）
local function moveRelWord(fromWx, toWx)
  if toWx == fromWx then return "比和" end
  if toWx == (fromWx + 1) % 5 then return "化泄气" end
  if fromWx == (toWx + 1) % 5 then return "化回头生" end
  if toWx == (fromWx + 2) % 5 then return "化回头克" end
  return "化耗气"
end

local function zhiName(i)
  return string.sub(ZHI, i * 3 + 1, i * 3 + 3)
end

local function wxIdxOfZhi(z)
  for wname, arr in pairs(ZHI_WX) do
    for _, c in ipairs(arr) do
      if c == z then return WX_IDX[wname] end
    end
  end
  return 1
end

-- 主入口：lines = { {yang, moving}, ... } 初爻在下；ts 为起卦 epoch 秒
function M.calc(lines, ts, civil)
  local dt = civil
  if type(dt) ~= "table" or dt.year == nil or dt.month == nil or dt.day == nil or dt.hour == nil or dt.minute == nil then
    dt = M.civilFromEpoch(ts or 0)
  end
  local g = ganzhiTable(dt)

  -- 本卦上下卦
  local lowerT = trigramFromBits(lines[1].yang, lines[2].yang, lines[3].yang)
  local upperT = trigramFromBits(lines[4].yang, lines[5].yang, lines[6].yang)
  local benKey = lowerT .. "_" .. upperT
  local ben = Data.hex[benKey]
  local palaceIdx = WX_IDX[Data.tri[ben.p].wx]

  -- 空亡支（先算，供变卦明细使用）
  local dayKong1 = g.dayN60 - (g.dayN60 % 10)
  local dayKongZhi = { (dayKong1 + 10) % 12, (dayKong1 + 11) % 12 }

  -- 变卦
  local bian = nil
  local hasMove = false
  for i = 1, 6 do if lines[i].moving then hasMove = true break end end
  if hasMove then
    local bl = {}
    for i = 1, 6 do
      bl[i] = lines[i].moving and not lines[i].yang or lines[i].yang
    end
    local blower = trigramFromBits(bl[1], bl[2], bl[3])
    local bupper = trigramFromBits(bl[4], bl[5], bl[6])
    local bianKey = blower .. "_" .. bupper
    local bb = Data.hex[bianKey]
    -- 变卦每爻明细（六亲按本卦宫五行，与示例一致）
    local bianLines = {}
    for pos = 1, 6 do
      local bgz = lineGanzhi(blower, bupper, pos)
      local bzhi = string.sub(bgz, 4, 6)
      local bw = wxIdxOfZhi(bzhi)
      local brel = relName(palaceIdx, bw)
      local isEmpty = (dayKongZhi[1] == zhiIdx(bzhi)) or (dayKongZhi[2] == zhiIdx(bzhi))
      bianLines[pos] = {
        rel = brel, gz = bgz, wxName = WX_NAMES[bw + 1],
        longState = zhangSheng(g.dayZhi, bw),
        empty = isEmpty
      }
    end
    bian = { key = bianKey, name = bb.n, p = bb.p, s = bb.s, lowerT = blower, upperT = bupper,
      lines = bianLines }
  end

  -- 每爻明细
  local mzName = zhiName(g.monthZhi)
  local mm = MONTH_WX[mzName] or 2
  local shenStart = startShen(g.dayGan)
  local linesOut = {}
  for pos = 1, 6 do
    local y = lines[pos]
    local gz = lineGanzhi(lowerT, upperT, pos)
    local zhiC = string.sub(gz, 4, 6)
    local z = zhiIdx(zhiC)
    local wxIdx = lineWxIdx(lowerT, upperT, pos)
    local rel = relName(palaceIdx, wxIdx)
    local shenIdx = ((shenStart + pos - 2) % 6) + 1
    local mState = monthState(mm, wxIdx)
    local daySame = z == g.dayZhi
    local dayClash = ((z + 6) % 12) == g.dayZhi
    local isStrong = mState == "旺" or mState == "相"
    local isEmpty = (dayKongZhi[1] == z) or (dayKongZhi[2] == z)
    local monthBroken = ((z + 6) % 12) == g.monthZhi and not y.moving and not daySame
    local lt = {
      pos = pos, yang = y.yang, moving = y.moving,
      type = y.moving and (y.yang and "老阳" or "老阴") or (y.yang and "少阳" or "少阴"),
      gz = gz, zhi = zhiC, wxName = WX_NAMES[wxIdx + 1],
      rel = rel, shen = LIU_SHEN[shenIdx],
      monthState = mState,
      longState = zhangSheng(g.dayZhi, wxIdx),
      empty = isEmpty,
      monthBroken = monthBroken,
      daySame = daySame,
      darkMoving = dayClash and not y.moving and isStrong,
      dayBroken = dayClash and not y.moving and not isStrong,
      shi = (ben.s or 1) == pos,
      ying = (ben.s + 3 <= 6 and (ben.s + 3 == pos)) or (ben.s - 3 == pos)
    }
    linesOut[pos] = lt
  end

  -- 动变化象
  local moves = {}
  if bian then
    local bianPalaceIdx = WX_IDX[Data.tri[bian.p].wx]
    for pos = 1, 6 do
      if lines[pos].moving then
        local from = linesOut[pos]
        local toGz = lineGanzhi(bian.lowerT, bian.upperT, pos)
        local toZhi = string.sub(toGz, 4, 6)
        -- 变爻五行由地支确定
        local toWx = wxIdxOfZhi(toZhi)
        local toRel = relName(palaceIdx, toWx)
        moves[#moves + 1] = {
          pos = pos,
          from = from.rel .. from.gz,
          to = toRel .. toGz,
          relWord = moveRelWord(WX_IDX[from.wxName], toWx),
          longWord = "化" .. zhangSheng(g.dayZhi, toWx)
        }
      end
    end
  end

  -- 飞伏神：本卦缺的六亲，伏于本宫首卦同爻位
  local relSet = {}
  for pos = 1, 6 do relSet[linesOut[pos].rel] = true end
  local fu = {}
  if #LIU_QIN > 0 then
    for _, r in ipairs(LIU_QIN) do
      if not relSet[r] then
        for pos = 1, 6 do
          local pgz = lineGanzhi(ben.p, ben.p, pos)
          local pzhi = string.sub(pgz, 4, 6)
          local pwx = wxIdxOfZhi(pzhi)
          local prel = relName(palaceIdx, pwx)
          if prel == r then
            fu[#fu + 1] = {
              pos = pos, fuRel = r, fuGz = pgz,
              feiRel = linesOut[pos].rel, feiGz = linesOut[pos].gz
            }
            break
          end
        end
      end
    end
  end

  -- 神煞
  local ma, tao, lu, gui1, gui2
  local group = 0
  for gi2, arr in ipairs(SANHE) do
    local hit = false
    for _, c in ipairs(arr) do if c == g.dayZhi then hit = true end end
    if hit then group = gi2 break end
  end
  ma = zhiName(MA[group]); tao = zhiName(TAO[group])
  lu = zhiName(LU[g.dayGan + 1])
  gui1 = zhiName(GUI[g.dayGan + 1][1]); gui2 = zhiName(GUI[g.dayGan + 1][2])

  -- 六合卦
  local liuhe = false
  for _, nm in ipairs(LIUHE_HEX) do if nm == ben.n then liuhe = true break end end

  return {
    ts = ts,
    dateStr = string.format("%04d-%02d-%02d %02d:%02d", dt.year, dt.month, dt.day, dt.hour, dt.minute),
    gz = g,
    year = g.year, month = g.month, day = g.day, hour = g.hour,
    kongYear = kong(g.yearN), kongMonth = kong(g.monthN), kongDay = kong(g.dayN), kongHour = kong(g.hourN),
    ben = { key = benKey, name = ben.n, p = ben.p, s = ben.s,
      palaceName = Data.tri[ben.p].n .. "宫", palaceWx = Data.tri[ben.p].wx,
      lowerName = Data.tri[lowerT].n, upperName = Data.tri[upperT].n,
      lowerWx = Data.tri[lowerT].wx, upperWx = Data.tri[upperT].wx,
      liuhe = liuhe },
    bian = bian and {
      key = bian.key, name = bian.name, p = bian.p, s = bian.s,
      palaceName = Data.tri[bian.p].n .. "宫", palaceWx = Data.tri[bian.p].wx,
      lowerName = Data.tri[bian.lowerT].n, upperName = Data.tri[bian.upperT].n,
      lines = bian.lines
    } or nil,
    lines = linesOut,
    moves = moves,
    fu = fu,
    sha = { ma = ma, tao = tao, lu = lu, gui1 = gui1, gui2 = gui2 },
    dayKongZhi = dayKongZhi
  }
end

return M
