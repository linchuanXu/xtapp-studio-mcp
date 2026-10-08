-- 来杯好卦爻一爻 · 状态与摇卦
local CategoryAnalysis = require("domain.category_analysis")

local M = {}
local Pinyin = nil
local PHRASES = nil

local function ensureLexicons()
  if not Pinyin then Pinyin = require("domain.pinyin_lexicon") end
  if not PHRASES then PHRASES = require("domain.pinyin_phrase_lexicon") end
end

-- 随机数只在本次应用运行时初始化一次。每摇一爻都按毫秒计时重新播种，
-- 在部分设备上会得到相同或高度相关的序列，看起来像是“总在变卦”。
local RANDOM_SEEDED = false

-- 将高频字放到候选首位，避免按字典排序时“ni”的首选落到“尼”等低频字。
local COMMON_FIRST = {
  de = "的", yi = "一", shi = "是", wo = "我", ni = "你", ta = "他", men = "们",
  zhe = "这", na = "那", ge = "个", he = "和", yao = "要", you = "有", zai = "在",
  bu = "不", ren = "人", lai = "来", qu = "去", shang = "上", xia = "下", hao = "好",
  ke = "可", hui = "会", neng = "能", xiang = "想", wen = "问", ma = "吗", zen = "怎",
  me = "么", shen = "什", qing = "情", gan = "感", gong = "工", zuo = "作", cai = "财",
  yun = "运", hun = "婚", yin = "姻", xue = "学", kao = "考", cheng = "成", ji = "机",
  ai = "爱", diu = "丢", su = "诉", song = "讼", zhao = "找", dao = "到", zhi = "职",
  jian = "健", kang = "康", jia = "家", nv = "女", gai = "改", hang = "行", kai = "开", xun = "寻",
}

local function utf8Chars(str)
  local chars = {}
  local i = 1
  while i <= #str do
    local b = string.byte(str, i)
    local len = 1
    if b >= 0xF0 then len = 4 elseif b >= 0xE0 then len = 3 elseif b >= 0xC0 then len = 2 end
    chars[#chars + 1] = string.sub(str, i, i + len - 1)
    i = i + len
  end
  return chars
end

local function appendUnique(out, seen, value, limit)
  if value and value ~= "" and not seen[value] and #out < limit then
    seen[value] = true
    out[#out + 1] = value
  end
end

function M.get(ctx)
  local s = ctx.state
  if s.page == nil then s.page = 1 end        -- 1 首页 2 摇卦 3 结果 4 六十四卦 5 知识库
  if s.question == nil then s.question = "" end
  if s.lines == nil then s.lines = {} end     -- { {yang,moving}, ... } 自下而上
  if s.castTs == nil then s.castTs = 0 end
  if s.lastCoins == nil then s.lastCoins = {} end
  if s.lastValue == nil then s.lastValue = 0 end
  if s.resultSub == nil then s.resultSub = 1 end
  if s.analysisPage == nil then s.analysisPage = 1 end
  if s.analysisPageMax == nil then s.analysisPageMax = 1 end
  if s.detailOffset == nil then s.detailOffset = 0 end
  if s.imOpen == nil then s.imOpen = false end
  if s.imMode == nil then s.imMode = "cn" end
  if s.imPinyin == nil then s.imPinyin = "" end
  if s.imCandidatePage == nil then s.imCandidatePage = 1 end
  if s.imFocus == nil then s.imFocus = 0 end
  if s.imInteracted == nil then s.imInteracted = false end
  if s.catalogPage == nil then s.catalogPage = 1 end
  if s.knowledgeName == nil then s.knowledgeName = "" end
  if s.knowledgePage == nil then s.knowledgePage = 1 end
  if s.knowledgePageMax == nil then s.knowledgePageMax = 1 end
  return s
end

local function seedRandom(ctx)
  if RANDOM_SEEDED then return end
  local a = ctx.sys:millis() or 0
  local b = ctx.sys:uptime_ms() or 0
  math.randomseed((a * 2654435761 % 4294967296) + b + 1)
  -- 丢弃播种后的首批值，兼容随机数实现较简单的设备运行时。
  math.random()
  math.random()
  math.random()
  RANDOM_SEEDED = true
end

-- 铜钱法：正面计 2，背面计 3；三枚相加后 6/7/8/9 对应老阴/少阳/少阴/老阳。
function M.castLine(ctx, s)
  if #s.lines >= 6 then return false end
  seedRandom(ctx)
  local coins = {}
  local value = 0
  for i = 1, 3 do
    coins[i] = math.random(2) + 1
    value = value + coins[i]
  end

  local line
  if value == 6 then line = { yang = false, moving = true }       -- 老阴
  elseif value == 7 then line = { yang = true, moving = false }   -- 少阳
  elseif value == 8 then line = { yang = false, moving = false }  -- 少阴
  else line = { yang = true, moving = true } end                  -- 老阳
  line.value = value
  line.coins = coins
  s.lines[#s.lines + 1] = line
  s.lastCoins = coins
  s.lastValue = value
  if #s.lines == 6 then
    s.castTs = ctx.sys:epoch_sec() or 0
    s.castCivil = nil
    local clock = ctx.sys and ctx.sys.clock and ctx.sys:clock() or nil
    if type(clock) == "table" and clock.valid == true and clock.year ~= nil and clock.month ~= nil and clock.day ~= nil and clock.hour ~= nil and clock.minute ~= nil then
      s.castCivil = { year = clock.year, month = clock.month, day = clock.day, hour = clock.hour, minute = clock.minute }
    end
  end
  return true
end

function M.finishCasting(s)
  if #s.lines < 6 then return false end
  s.resultSub = 1
  s.analysisPage = 1
  s.analysisPageMax = 1
  s.detailOffset = 0
  s.page = 3
  return true
end

function M.startCasting(s)
  s.imOpen = false
  s.castCivil = nil
  s.lines = {}
  s.lastCoins = {}
  s.lastValue = 0
  s.page = 2
  return true
end

function M.resetAll(s)
  s.castCivil = nil
  s.lines = {}
  s.lastCoins = {}
  s.lastValue = 0
  s.page = 1
  s.resultSub = 1
  s.analysisPage = 1
  s.analysisPageMax = 1
  s.detailOffset = 0
end

function M.reroll(s)
  s.castCivil = nil
  s.lines = {}
  s.lastCoins = {}
  s.lastValue = 0
  s.page = 2
  s.resultSub = 1
  s.analysisPage = 1
  s.analysisPageMax = 1
  s.detailOffset = 0
end

function M.openHexCatalog(s)
  s.imOpen = false
  s.catalogPage = 1
  s.page = 4
  return true
end

function M.closeHexCatalog(s)
  s.page = 2
  return true
end

function M.prevHexCatalogPage(s)
  if (s.catalogPage or 1) <= 1 then return false end
  s.catalogPage = s.catalogPage - 1
  return true
end

function M.nextHexCatalogPage(s)
  if (s.catalogPage or 1) >= 4 then return false end
  s.catalogPage = s.catalogPage + 1
  return true
end

function M.openHexKnowledge(s, name)
  if not name or name == "" then return false end
  s.knowledgeName = name
  s.knowledgePage = 1
  s.knowledgePageMax = 1
  s.page = 5
  return true
end

function M.closeHexKnowledge(s)
  s.knowledgePage = 1
  s.page = 4
  return true
end

function M.prevKnowledgePage(s)
  if (s.knowledgePage or 1) <= 1 then return false end
  s.knowledgePage = s.knowledgePage - 1
  return true
end

function M.nextKnowledgePage(s)
  if (s.knowledgePage or 1) >= (s.knowledgePageMax or 1) then return false end
  s.knowledgePage = s.knowledgePage + 1
  return true
end

function M.nextSub(s)
  s.resultSub = s.resultSub % 4 + 1
  s.detailOffset = 0
end

function M.prevSub(s)
  s.resultSub = (s.resultSub + 2) % 4 + 1
  s.detailOffset = 0
end

function M.scrollDetail(s, delta)
  -- 绘制层会按实际总行数再次收紧；这里放宽上限，保证窄屏换行增多后仍能看到全文。
  s.detailOffset = math.max(0, math.min(500, (s.detailOffset or 0) + delta))
end

function M.prevAnalysis(s)
  if (s.analysisPage or 1) <= 1 then return false end
  s.analysisPage = s.analysisPage - 1
  return true
end

function M.nextAnalysis(s)
  if (s.analysisPage or 1) >= (s.analysisPageMax or 1) then return false end
  s.analysisPage = s.analysisPage + 1
  return true
end

function M.openIm(s, mode)
  s.imOpen = true
  s.imMode = mode or "cn"
  s.imPinyin = ""
  s.imCandidatePage = 1
  -- 首次进入输入页保持纯白：先记录默认焦点，但在用户真正按键或触摸前不绘制黑框。
  -- 已有方向时从字母 q 开始；尚未选方向时从第一个方向“学业”开始。
  s.imFocus = s.questionCategory and 7 or 38
  s.imInteracted = false
end

function M.setQuestionCategory(s, category)
  if not CategoryAnalysis.get(category) then return false end
  s.questionCategory = category
  s.imPinyin = ""
  s.imCandidatePage = 1
  s.imFocus = 7
  return true
end

function M.canStart(s)
  -- 所问为选填；首页随时可以直接进入摇卦。
  return true
end

function M.hasQuestionContext(s)
  return CategoryAnalysis.get(s.questionCategory) ~= nil and #(s.question or "") > 0
end

function M.closeIm(s)
  s.imOpen = false
  s.imCandidatePage = 1
  s.imInteracted = false
end

-- 输入法：问题文本最多 120 字节，约 40 个汉字。
function M.imAppend(s, ch)
  if not CategoryAnalysis.get(s.questionCategory) then return false end
  if ch == "" then return false end
  if #s.question + #ch <= 120 then
    s.question = s.question .. ch
    return true
  end
  return false
end

function M.imBackspace(s)
  if s.imMode == "cn" and #(s.imPinyin or "") > 0 then
    s.imPinyin = string.sub(s.imPinyin, 1, #s.imPinyin - 1)
    s.imCandidatePage = 1
    return true
  end
  local q = s.question
  if #q == 0 then return false end
  local i = #q
  -- 从 UTF-8 续字节向前找到当前字符的起始字节，避免删除中文时留下乱码。
  while i > 1 do
    local b = string.byte(q, i)
    if b < 0x80 or b >= 0xC0 then break end
    i = i - 1
  end
  s.question = string.sub(q, 1, i - 1)
  return true
end

local CANDIDATES_PER_PAGE = 4
local MAX_CANDIDATES = 96

local function matchingKeys(dict, py)
  local keys = {}
  for key in pairs(dict) do
    if string.sub(key, 1, #py) == py then keys[#keys + 1] = key end
  end
  table.sort(keys)
  return keys
end

-- 精确整词优先，再补常用单字、整词前缀和单字前缀。候选顺序固定，
-- 最多保留 64 项，供“前页 / 后页”继续选择。
local function candidatePool(s)
  ensureLexicons()
  local py = string.lower(s.imPinyin or "")
  if py == "" then return {} end
  local out, seen = {}, {}
  local phrase = PHRASES[py]
  if phrase then
    for _, value in ipairs(phrase) do appendUnique(out, seen, value, MAX_CANDIDATES) end
  end
  appendUnique(out, seen, COMMON_FIRST[py], MAX_CANDIDATES)
  local exact = Pinyin[py]
  if exact then
    local chars = utf8Chars(exact)
    for i = 1, math.min(16, #chars) do appendUnique(out, seen, chars[i], MAX_CANDIDATES) end
  end
  if #out < MAX_CANDIDATES then
    for _, key in ipairs(matchingKeys(PHRASES, py)) do
      for _, value in ipairs(PHRASES[key]) do
        appendUnique(out, seen, value, MAX_CANDIDATES)
      end
    end
  end
  if exact and #out < MAX_CANDIDATES then
    local chars = utf8Chars(exact)
    for i = 17, #chars do appendUnique(out, seen, chars[i], MAX_CANDIDATES) end
  end
  if #out < MAX_CANDIDATES then
    for _, key in ipairs(matchingKeys(Pinyin, py)) do
      appendUnique(out, seen, utf8Chars(Pinyin[key])[1], MAX_CANDIDATES)
      if #out >= MAX_CANDIDATES then break end
    end
  end
  return out
end

function M.imCandidatePageMax(s)
  return math.max(1, math.ceil(#candidatePool(s) / CANDIDATES_PER_PAGE))
end

function M.imCandidates(s)
  local pool = candidatePool(s)
  local pageMax = math.max(1, math.ceil(#pool / CANDIDATES_PER_PAGE))
  s.imCandidatePage = math.max(1, math.min(s.imCandidatePage or 1, pageMax))
  local first = (s.imCandidatePage - 1) * CANDIDATES_PER_PAGE + 1
  local out = {}
  for i = 0, CANDIDATES_PER_PAGE - 1 do
    if pool[first + i] then out[#out + 1] = pool[first + i] end
  end
  return out
end

function M.imPrevCandidatePage(s)
  if (s.imCandidatePage or 1) <= 1 then return false end
  s.imCandidatePage = s.imCandidatePage - 1
  return true
end

function M.imNextCandidatePage(s)
  if (s.imCandidatePage or 1) >= M.imCandidatePageMax(s) then return false end
  s.imCandidatePage = s.imCandidatePage + 1
  return true
end

function M.imLetter(s, letter)
  if not letter or letter == "" then return false end
  if not CategoryAnalysis.get(s.questionCategory) then return false end
  if s.imMode == "en" then return M.imAppend(s, letter) end
  if #(s.imPinyin or "") >= 16 then return false end
  s.imPinyin = (s.imPinyin or "") .. string.lower(letter)
  s.imCandidatePage = 1
  return true
end

function M.imSelectCandidate(s, index)
  local value = M.imCandidates(s)[index]
  if not value then return false end
  if not M.imAppend(s, value) then return false end
  s.imPinyin = ""
  s.imCandidatePage = 1
  s.imFocus = 7
  return true
end

function M.imCommitFirst(s)
  if s.imMode ~= "cn" or #(s.imPinyin or "") == 0 then return false end
  local candidates = M.imCandidates(s)
  if candidates[1] then return M.imSelectCandidate(s, 1) end
  local raw = s.imPinyin
  s.imPinyin = ""
  s.imCandidatePage = 1
  return M.imAppend(s, raw)
end

function M.imSpace(s)
  if s.imMode == "cn" and #(s.imPinyin or "") > 0 then return M.imCommitFirst(s) end
  return M.imAppend(s, " ")
end

function M.imSetMode(s, mode)
  if mode ~= "cn" and mode ~= "en" then return false end
  if mode == s.imMode then return false end
  if #(s.imPinyin or "") > 0 then M.imCommitFirst(s) end
  s.imMode = mode
  s.imCandidatePage = 1
  s.imFocus = 7
  return true
end

function M.finishIm(s)
  if not CategoryAnalysis.get(s.questionCategory) then return false end
  if #(s.imPinyin or "") > 0 then M.imCommitFirst(s) end
  if #(s.question or "") == 0 then return false end
  M.closeIm(s)
  return true
end

return M
