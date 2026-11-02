-- 方向分析器：动态六爻规则 + Excel 生成的 64×14 离线预制结论。
local OfflineDB = require("domain.offline_analysis_db")

local M = {}

local CATEGORIES = {
  { key = "academic", label = "学业", field = "fame", relatives = { "父母" },
    use = "父母爻主考试、成绩、证书与师长，兼看世爻。",
    strong = "学业用神有力，准备、文书或考核条件较有利。",
    weak = "学业用神偏弱，宜补足复习、材料和时间安排。",
    advice = "把目标拆成可核对的成绩、材料与考试节点。" },
  { key = "career", label = "事业", field = "career", relatives = { "官鬼" },
    use = "官鬼爻主职位、求事与升迁，世爻代表自身承受力。",
    strong = "事业用神得力，职位、机会或上级支持较有基础。",
    weak = "事业用神受制，当前更像压力、竞争或职位未落实。",
    advice = "核实岗位、审批、竞争者与可交付成果。" },
  { key = "love", label = "爱情", field = "marriage", relatives = { "妻财", "官鬼" },
    use = "未区分性别时并看妻财、官鬼与世应关系。",
    strong = "感情用神较有力，关系具备推进或落实条件。",
    weak = "感情用神偏弱，双方意愿、现实条件或承诺仍需确认。",
    advice = "用明确沟通和现实行动验证关系，不代替当事人选择。" },
  { key = "wealth", label = "财运", field = "business", relatives = { "妻财" },
    use = "妻财爻主资金与收益，子孙为财源，兄弟旺动须防破耗。",
    strong = "财爻得力，周转、买卖或经营具备一定基础。",
    weak = "财爻受制，资金、回款或交易条件仍有阻力。",
    advice = "先核对现金流、合同、成本和最坏情形，不作投机承诺。" },
  { key = "lost", label = "失物", field = "decision", relatives = { "妻财" },
    use = "一般失物取妻财爻；内卦主近处，外卦主远处。",
    strong = "失物用神尚有力，仍有找回或重新出现的可能。",
    weak = "失物用神受制，物品可能已移位或查找阻力较大。",
    advice = "按最后出现时间倒查，再结合内外卦与方位缩小范围。" },
  { key = "lawsuit", label = "诉讼", field = "decision", relatives = { "官鬼" },
    use = "官鬼主案件与官方，世应分己方对方，父母爻主证据文书。",
    strong = "官鬼有力表示程序与约束较强，须谨慎应对。",
    weak = "官鬼偏弱表示程序或对方攻势暂缓，仍不可忽视期限。",
    advice = "保存证据、核对期限并咨询合资格法律专业人士。" },
  { key = "travel", label = "出行", field = "travel", focus = "shi", relatives = {},
    use = "出行以世爻为主，应爻为目的地，父母爻兼看交通工具。",
    strong = "世爻有力，出行承受力与执行条件较稳。",
    weak = "世爻偏弱或受制，行程宜增加准备并保留退路。",
    advice = "以天气、交通、证件和安全信息为现实依据。" },
  { key = "health", label = "健康", field = "decision", relatives = { "官鬼" },
    use = "疾病取官鬼爻，官鬼宜衰退；子孙爻可作医药辅助。",
    strong = "官鬼偏旺表示病象或压力较强，不宜拖延现实检查。",
    weak = "官鬼偏弱表示病象力量较轻，但仍须观察真实症状。",
    advice = "健康结论仅作文化参考；如有症状应及时就医。" },
  { key = "family", label = "家运", field = "decision", relatives = { "父母" },
    use = "家运兼看父母爻、世爻与二爻宅位。",
    strong = "家宅相关用神有力，稳定与协作条件较好。",
    weak = "家宅相关用神受制，宜处理沟通、维修或旧事牵连。",
    advice = "优先解决可见的家庭沟通、居住安全与财务安排。" },
  { key = "children", label = "子女", field = "decision", relatives = { "子孙" },
    use = "子女与胎孕取子孙爻，兼看月日生扶与空破。",
    strong = "子孙爻有力，子女事务或后续发展条件较顺。",
    weak = "子孙爻偏弱，宜增加照护、沟通与现实准备。",
    advice = "涉及孕产和儿童健康时，以正规医疗意见为准。" },
  { key = "fortune", label = "运势", field = "decision", focus = "shi", relatives = {},
    use = "综合运势以世爻为主，再看月日、动变与原忌关系。",
    strong = "世爻较有力，当前主动性和承受力较好。",
    weak = "世爻偏弱，宜先稳住资源与节奏，减少无把握行动。",
    advice = "把卦象转成可执行的小步骤，并定期按现实结果复盘。" },
  { key = "change", label = "改行", field = "career", relatives = { "官鬼", "父母" },
    use = "改行并看官鬼职位、父母单位文书与世爻承受力。",
    strong = "转向相关用神较有力，新方向具备一定承接条件。",
    weak = "转向相关用神偏弱，时机、资格或衔接尚不充分。",
    advice = "先验证新岗位、技能、收入和退出成本，再决定转换。" },
  { key = "opening", label = "开业", field = "business", relatives = { "妻财", "官鬼" },
    use = "开业并看妻财、官鬼、世爻及父母合同场地。",
    strong = "开业相关用神有力，经营与落地条件较有基础。",
    weak = "开业相关用神受制，资金、手续或市场条件仍需完善。",
    advice = "先完成现金流、证照、客源和止损方案再投入。" },
  { key = "people", label = "寻人", field = "decision", focus = "ying", relatives = {},
    use = "等人、寻人以应爻代表对方，再结合六神与内外卦取象。",
    strong = "应爻较有力，对方状态或消息较容易显现。",
    weak = "应爻偏弱或空破，消息可能延迟、失真或暂难落实。",
    advice = "同步使用电话、监控、行程和必要的报警求助等现实手段。" },
}

local BY_KEY = {}
for _, category in ipairs(CATEGORIES) do BY_KEY[category.key] = category end

local STATE_SCORE = { ["旺"] = 3, ["相"] = 2, ["休"] = 0, ["囚"] = -1, ["死"] = -2 }
local SHEN_IMAGE = {
  ["青龙"] = "青龙主喜庆与助力", ["朱雀"] = "朱雀主消息、文书与口舌",
  ["勾陈"] = "勾陈主迟滞、旧事与牵连", ["腾蛇"] = "腾蛇主疑虑、反复与信息不实",
  ["白虎"] = "白虎主急迫、冲突与损耗", ["玄武"] = "玄武主隐情、遗失与暗中变化",
}
local SHEN_DIRECTION = {
  ["青龙"] = "东", ["朱雀"] = "南", ["勾陈"] = "中部",
  ["腾蛇"] = "中部", ["白虎"] = "西", ["玄武"] = "北",
}

local function utf8Chars(str)
  local out, i = {}, 1
  while i <= #(str or "") do
    local b = string.byte(str, i)
    local len = 1
    if b >= 0xF0 then len = 4 elseif b >= 0xE0 then len = 3 elseif b >= 0xC0 then len = 2 end
    out[#out + 1] = string.sub(str, i, i + len - 1)
    i = i + len
  end
  return out
end

local function clip(str, maxChars)
  local chars = utf8Chars(str or "")
  if #chars <= maxChars then return str or "" end
  local out = ""
  for i = 1, maxChars do out = out .. chars[i] end
  return out .. "…"
end

local function score(line)
  if not line then return -99 end
  local value = STATE_SCORE[line.monthState] or 0
  if line.moving or line.darkMoving then value = value + 1 end
  if line.daySame then value = value + 1 end
  if line.empty then value = value - 2 end
  if line.monthBroken then value = value - 2 end
  if line.dayBroken then value = value - 1 end
  return value
end

local function hasRelative(relatives, rel)
  for _, expected in ipairs(relatives or {}) do if rel == expected then return true end end
  return false
end

local function bestLine(r, relatives)
  local best, bestScore = nil, -100
  for _, line in ipairs(r.lines or {}) do
    if hasRelative(relatives, line.rel) and score(line) > bestScore then
      best, bestScore = line, score(line)
    end
  end
  return best, bestScore
end

local function roleLine(r, role)
  for _, line in ipairs(r.lines or {}) do if line[role] then return line end end
  return nil
end

local function focusLine(category, r)
  if category.focus == "shi" then local line = roleLine(r, "shi"); return line, score(line) end
  if category.focus == "ying" then local line = roleLine(r, "ying"); return line, score(line) end
  return bestLine(r, category.relatives)
end

local function lineSummary(line)
  if not line then return "用神未现，须参考伏神与后续变化。" end
  local flags = {}
  if line.moving then flags[#flags + 1] = "发动" end
  if line.empty then flags[#flags + 1] = "旬空" end
  if line.monthBroken then flags[#flags + 1] = "月破" end
  if line.daySame then flags[#flags + 1] = "临日" end
  if line.darkMoving then flags[#flags + 1] = "暗动" end
  if line.dayBroken then flags[#flags + 1] = "日破" end
  local suffix = #flags > 0 and ("，" .. table.concat(flags, "、")) or "，安静"
  return line.rel .. line.gz .. "临" .. line.shen .. "，月令" .. line.monthState .. suffix .. "。"
end

local function moveSummary(r, focus)
  if not focus or not focus.moving then return "动变：主用爻安静，以月日旺衰和逢值逢冲为主。" end
  for _, move in ipairs(r.moves or {}) do
    if move.pos == focus.pos then
      return "动变：用神由" .. move.from .. "变" .. move.to .. "，" .. move.relWord .. "、" .. move.longWord .. "。"
    end
  end
  return "动变：用神发动，事情处于变化过程。"
end

local function timingSummary(focus)
  if not focus then return "应期：用神伏藏，宜待得生扶或透出时再观察。" end
  if focus.empty then return "应期：用神旬空，优先观察出空或被冲实之日。" end
  if focus.monthBroken then return "应期：用神月破，通常需出月或逢填实时再观察。" end
  if focus.moving then return "应期：用神发动，可留意逢合或其地支临值之日月。" end
  if focus.monthState == "旺" or focus.monthState == "相" then
    return "应期：用神旺相安静，较近，可留意逢值或逢冲之日月。"
  end
  return "应期：用神休囚，宜待得生扶、转旺的日月再观察。"
end

local function categoryExtra(key, r, focus)
  if key == "lost" and focus then
    local distance = focus.pos <= 3 and "内卦，先查家中或近处" or "外卦，先查外部或较远处"
    return "寻物：用神在" .. distance .. "；六神取象可先看" .. (SHEN_DIRECTION[focus.shen] or "原处周边") .. "方向。"
  elseif key == "lawsuit" or key == "love" then
    local shi, ying = roleLine(r, "shi"), roleLine(r, "ying")
    if score(shi) > score(ying) then return "世应：世强于应，己方主动性或承受力较强。" end
    if score(shi) < score(ying) then return "世应：应强于世，对方当前影响较大。" end
    return "世应：双方力量接近，现实沟通、证据或和解条件更关键。"
  elseif key == "family" and r.lines and r.lines[2] then
    return "家宅：二爻宅位为" .. lineSummary(r.lines[2])
  elseif key == "health" then
    local child = bestLine(r, { "子孙" })
    return child and ("医药：子孙爻" .. child.gz .. "月令" .. child.monthState .. "，仅作辅助。") or "医药：子孙爻未现，现实诊疗优先。"
  end
  return ""
end

local function offlineLines(key, r, focus)
  local record = OfflineDB.get(r.ben.name)
  if not record then return { "卦库：暂无本卦离线预制结论。" } end
  local lines = { "卦库预制〔" .. record.rating .. "〕：" .. (record.presets[key] or record.overview) }
  local movePos = focus and focus.moving and focus.pos or ((r.moves or {})[1] and r.moves[1].pos)
  if movePos and record.moves[movePos] then
    lines[#lines + 1] = "单爻库：" .. record.moves[movePos]
  end
  return lines
end

function M.options() return CATEGORIES end
function M.get(key) return BY_KEY[key] end
function M.label(key) return BY_KEY[key] and BY_KEY[key].label or "未分类" end
function M.offlineRecord(hexName) return OfflineDB.get(hexName) end

function M.build(key, question, r)
  local category = BY_KEY[key]
  if not category then
    local record = r and r.ben and OfflineDB.get(r.ben.name)
    local result = { "所问未填写，本次按通用卦意展示。" }
    if record then
      if record.overview and record.overview ~= "" then result[#result + 1] = "卦库总览：" .. record.overview end
      if record.guaci and record.guaci ~= "" then result[#result + 1] = "卦辞：" .. record.guaci end
      if record.xiang and record.xiang ~= "" then result[#result + 1] = "象传：" .. record.xiang end
    end
    return result
  end
  local focus, focusScore = focusLine(category, r)
  local highState = focusScore >= 1
  local lead
  if #(question or "") > 0 then
    lead = "针对“" .. clip(question, 16) .. "”，按" .. category.label .. "方向分析。"
  else
    lead = "未填写具体问题，按" .. category.label .. "方向展示基础结论。"
  end
  local result = { lead }
  for _, line in ipairs(offlineLines(key, r, focus)) do result[#result + 1] = line end
  result[#result + 1] = "取用：" .. category.use
  result[#result + 1] = "用神：" .. lineSummary(focus)
  result[#result + 1] = "判断：" .. (highState and category.strong or category.weak)
  result[#result + 1] = moveSummary(r, focus)
  local extra = categoryExtra(key, r, focus)
  if extra ~= "" then result[#result + 1] = extra end
  if focus then result[#result + 1] = "六神：" .. (SHEN_IMAGE[focus.shen] or "仅作辅助取象") .. "。" end
  result[#result + 1] = timingSummary(focus)
  result[#result + 1] = "建议：" .. category.advice
  result[#result + 1] = "原则：先用离线卦库回答所选方向，再以月日、动变和用神修正。"
  return result
end

return M
