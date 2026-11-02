local Rules = require("domain.werewolf_rules")
local Brain = require("domain.npc_brain")
local Layout = require("domain.game_layout")

local M = {}

local function name_of(s, id)
  local person = Rules.person(s, id)
  return person and person.name or "未知"
end

local function wolf_allies_text(s)
  local names = {}
  for _, person in ipairs(s.roster) do
    if person.id ~= "you" and s.roles[person.id] == "wolf" then names[#names + 1] = person.name end
  end
  return table.concat(names, "、")
end

local function target_options(s, action)
  local targets = action == "badge" and Rules.badge_targets(s) or Rules.night_targets(s, action == "wolf" and "wolf" or "other")
  local page = s.target_page or 1
  local start = (page - 1) * 3 + 1
  local out = {}
  if page > 1 then out[#out + 1] = { kind = "page_prev", text = "上一页" } end
  for index = start, math.min(#targets, start + 2) do out[#out + 1] = { kind = "target", id = targets[index], text = name_of(s, targets[index]) } end
  if start + 3 <= #targets then out[#out + 1] = { kind = "page_next", text = "下一页" } end
  return out
end

function M.options(s)
  if s.phase == "briefing" then return { { kind = "begin", text = "开始" .. s.deck.name }, { kind = "deck_select", text = "选择其他牌局" } } end
  if s.phase == "deck_select" then return {
    { kind = "restart", deck = "mirror", text = "镜面局 · 预言家" },
    { kind = "restart", deck = "embers", text = "余烬局 · 平民" },
    { kind = "restart", deck = "still_night", text = "静夜局 · 女巫" },
    { kind = "restart", deck = "last_bullet", text = "最后一弹 · 猎人" },
    { kind = "restart", deck = "moonlit", text = "月蚀局 · 狼人" },
  } end
  if s.phase == "sheriff_choice" then return { { kind = "sheriff", run = true, text = "上警竞选" }, { kind = "sheriff", run = false, text = "不上警" } } end
  if s.phase == "sheriff_player_speech" then return {
    { kind = "sheriff_player_speech", style = "record", text = "承诺公开警徽流" },
    { kind = "sheriff_player_speech", style = "logic", text = "承诺逐条复盘票型" },
    { kind = "sheriff_player_speech", style = "quiet", text = "简短说明后退水" },
  } end
  if s.phase == "sheriff_vote" then
    local out = {}
    for _, id in ipairs(Rules.sheriff_targets(s)) do out[#out + 1] = { kind = "sheriff_vote", id = id, text = "投给" .. name_of(s, id) } end
    return out
  end
  if s.phase == "night_begin" then return { { kind = "night", text = "闭眼入夜" } } end
  if s.phase == "night_wolf_action" then return target_options(s, "wolf") end
  if s.phase == "night_seer_action" then return target_options(s, "seer") end
  if s.phase == "night_witch_action" then
    if s.target_mode == "poison" then return target_options(s, "poison") end
    local out = { { kind = "witch", action = "pass", text = "不用药" } }
    if s.knowledge.you.save and s.night.wolf_target then out[#out + 1] = { kind = "witch", action = "save", text = "使用解药" } end
    if s.knowledge.you.poison then out[#out + 1] = { kind = "witch", action = "poison", text = "使用毒药" } end
    return out
  end
  if s.phase == "hunter_shot" then return target_options(s, "hunter") end
  if s.phase == "death_last_words" and s.death_flow and s.death_flow.id == "you" then return {
    { kind = "last_words", style = "trust", text = "留下票型遗言" },
    { kind = "last_words", style = "suspect", text = "留下怀疑遗言" },
    { kind = "last_words", style = "review", text = "请求复盘发言" },
  } end
  if s.phase == "badge_transfer" then
    local out = target_options(s, "badge")
    out[#out + 1] = { kind = "badge_destroy", text = "撕毁警徽" }
    return out
  end
  if s.phase == "day_player_speech" then
    local out = { { kind = "player_speech", claim = "quiet", text = "暂不报身份" }, { kind = "player_speech", claim = "role", text = "公开我的身份" } }
    if s.roles.you == "wolf" then out[#out + 1] = { kind = "player_speech", claim = "fake_seer", text = "假报预言家" } end
    if s.roles.you == "seer" then
      for id in pairs(s.knowledge.you.checks) do out[#out + 1] = { kind = "player_speech", claim = "seer", id = id, text = "报" .. name_of(s, id) .. "验人" } end
    end
    return out
  end
  if s.phase == "day_player_stance" then return {
    { kind = "player_stance_kind", id = "suspect", text = "公开怀疑一人" },
    { kind = "player_stance_kind", id = "protect", text = "暂时保留一人" },
  } end
  if s.phase == "day_player_stance_target" then return target_options(s, "stance") end
  if s.phase == "day_fake_claim_target" then return target_options(s, "fake_claim") end
  if s.phase == "day_fake_claim_result" then return { { kind = "fake_claim_result", result = "wolf", text = "报验人为狼人" }, { kind = "fake_claim_result", result = "good", text = "报验人为好人" } } end
  if s.phase == "day_question" then
    if s.question_kind then return target_options(s, "question") end
    return {
      { kind = "question_kind", id = "stance", text = "追问站边依据" },
      { kind = "question_kind", id = "vote", text = "追问落票意向" },
      { kind = "question_kind", id = "contradiction", text = "追问前后矛盾" },
    }
  end
  if s.phase == "day_final_speech" then return {} end
  if s.phase == "day_final_stance" then return {
    { kind = "final_stance", action = "keep", text = "确认当前最终站边" },
    { kind = "final_stance", action = "change", text = "调整最终站边" },
  } end
  if s.phase == "day_final_stance_target" then return target_options(s, "final_stance") end
  if s.phase == "day_vote" then return target_options(s, "vote") end
  if s.phase == "day_final_stance" then return { title = "最终站边", speaker = "你", lines = { "两次追问已经写入公开证据。", "确认原立场，或根据回应调整目标。", "最终站边会和你的投票并列写入复盘。" } } end
  if s.phase == "day_final_stance_target" then return { title = "调整最终站边", speaker = "你", lines = { "请选择新的最终怀疑对象。", "改口本身不是问题，关键是留下原因。", "之后进入本轮放逐投票。" } } end
  if s.phase == "day_observe_vote" then return { { kind = "observe_vote", text = "观看本轮投票" } } end
  if s.phase == "ending" then return { { kind = "restart", text = "重开镜面局" }, { kind = "restart", deck = "embers", text = "挑战余烬局" }, { kind = "restart", deck = "still_night", text = "挑战静夜局" }, { kind = "restart", deck = "last_bullet", text = "挑战最后一弹" }, { kind = "restart", deck = "moonlit", text = "挑战月蚀局" } } end
  return {}
end

function M.log_page(s)
  local per_page = 6
  local pages = math.max(1, math.ceil(#s.log / per_page))
  local page = math.max(1, math.min(s.log_page or 1, pages))
  s.log_page = page
  local finish = #s.log - (page - 1) * per_page
  local start = math.max(1, finish - per_page + 1)
  local entries = {}
  for index = start, finish do entries[#entries + 1] = s.log[index] end
  return { entries = entries, page = page, pages = pages }
end

function M.description(s)
  local role = Rules.player_role(s)
  if s.notice then return { title = "本轮结果", speaker = nil, lines = s.notice } end
  if s.phase == "briefing" then
    local lines = { "你的身份是：" .. require("domain.roles").name(role) .. "。", s.deck.premise }
    if role == "wolf" then lines[#lines + 1] = "你的同伴是：" .. wolf_allies_text(s) .. "。" end
    lines[#lines + 1] = role == "wolf" and "白天请隐藏狼队关系。" or "请用公开信息找出狼人。"
    return { title = "身份牌", lines = lines }
  end
  if s.phase == "deck_select" then return { title = "选择牌局", lines = { "五套人工调校的九人局。", "每套都有不同的玩家身份与推理重点。", "选择后会开始一局全新的存档。" } } end
  if s.phase == "sheriff_choice" then return { title = "警长竞选", lines = { "警长拥有放逐时的 1.5 票。", "候选人会逐一竞选发言。", "你可以加入竞选，也可以观察票型。" } } end
  if s.phase == "sheriff_speech" then
    if s.current_speaker then return { title = "警长竞选 · 发言", speaker = name_of(s, s.current_speaker), lines = { Brain.sheriff_statement(Rules.npc_view(s, s.current_speaker)), "竞选承诺会写入证词簿。", "点击后由下一位候选人发言。" } } end
    return { title = "警长竞选 · 发言", lines = { "候选人依次说明警徽流与归票方式。", "点击开始听取竞选发言。" } }
  end
  if s.phase == "sheriff_player_speech" then return { title = "警长竞选 · 你的发言", speaker = "你", lines = { "你已经上警。", "选择一项公开承诺；它会进入证词簿。", "说完后仍需参加警长投票。" } } end
  if s.phase == "sheriff_vote" then return { title = "警长投票", lines = { "所有候选人均已完成竞选发言。", "本轮逐票记录会写入证词簿。", "请选择你支持的警长。" } } end
  if s.phase == "night_begin" then return { title = "第" .. tostring(s.day + 1) .. "夜", lines = { "所有人闭眼。", "夜晚行动依身份顺序发生。", "只带走你应知道的信息。" } } end
  if s.phase == "night_wolf_action" then return { title = "狼人行动", lines = { "狼队睁眼。", "同伴：" .. wolf_allies_text(s) .. "。", "请选择今晚的袭击目标。" } } end
  if s.phase == "night_seer_action" then return { title = "预言家行动", lines = { "请选择一名存活玩家查验。", "结果只会告诉你对方阵营。" } } end
  if s.phase == "night_witch_action" then return { title = "女巫行动", lines = { "今晚的受袭者是：" .. (s.night.wolf_target and name_of(s, s.night.wolf_target) or "无人") .. "。", "解药与毒药各只能使用一次。" } } end
  if s.phase == "hunter_shot" then return { title = "猎人开枪", lines = { "你已出局，仍可发动猎人技能。", "请选择一名存活玩家带走。", "开枪后立刻结算阵营胜负。" } } end
  if s.phase == "death_announce" and s.death_flow then
    local person = Rules.person(s, s.death_flow.id)
    return { title = "死亡公布", lines = { (s.death_flow.cause == "vote" and "放逐结果：" or "昨夜死亡：") .. person.name .. "。", "身份翻开为" .. require("domain.roles").name(s.roles[person.id]) .. "。", "点击进入遗言环节。" } }
  end
  if s.phase == "death_last_words" and s.death_flow then
    local person = Rules.person(s, s.death_flow.id)
    if s.death_flow.id == "you" then return { title = "你的遗言", speaker = "你", lines = { "你已出局，但仍可留下最后的公开信息。", "选择遗言后，桌面会继续结算。" } } end
    return { title = "遗言", speaker = person.name, lines = { Brain.last_words(Rules.npc_view(s, person.id)), "遗言会写入证词簿。", "点击继续处理技能或警徽。" } }
  end
  if s.phase == "hunter_npc_shot" and s.death_flow then return { title = "猎人开枪", speaker = name_of(s, s.death_flow.id), lines = { "猎人发动技能。", "他选择带走" .. name_of(s, s.death_flow.hunter_target) .. "。", "点击公布开枪结果。" } } end
  if s.phase == "badge_transfer" then return { title = "警徽移交", speaker = "你", lines = { "你携带警徽出局。", "选择一名存活玩家继承，或撕毁警徽。", "移交会公开记录。" } } end
  if s.phase == "badge_npc_transfer" and s.death_flow then return { title = "警徽移交", speaker = name_of(s, s.death_flow.id), lines = { "警长出局，留下警徽流。", "警徽将交给" .. name_of(s, s.death_flow.badge_target) .. "。", "点击完成移交。" } } end
  if s.phase == "day_speech" then
    if s.current_speaker then
      local view = Rules.npc_view(s, s.current_speaker)
      return { title = "第" .. tostring(s.day) .. "天 · 发言", speaker = name_of(s, s.current_speaker), lines = { Brain.statement(view), Brain.detail(view), "发言结束后，下一位继续。" } }
    end
    return { title = "第" .. tostring(s.day) .. "天 · 发言", lines = { "白天开始。", "点画面依次听取存活者发言。", "每个人的身份信息都不公开。" } }
  end
  if s.phase == "day_rebuttal" then
    if s.current_speaker then return { title = "第" .. tostring(s.day) .. "天 · 回应", speaker = name_of(s, s.current_speaker), lines = { Brain.rebuttal(Rules.npc_view(s, s.current_speaker)), "这是一轮对公开站边的回应。", "点击后由下一位继续。" } } end
    return { title = "第" .. tostring(s.day) .. "天 · 回应", lines = { "首轮发言结束。", "存活玩家依次回应桌面压力。", "点击开始回应轮。" } }
  end
  if s.phase == "day_player_speech" then return { title = "第" .. tostring(s.day) .. "天 · 你的发言", speaker = "你", lines = { "轮到你发言。", "公开身份会成为夜间目标。", "请选择本轮发言策略。" } } end
  if s.phase == "day_player_stance" then return { title = "公开站边", speaker = "你", lines = { "身份声明之后，给桌面一个明确方向。", "怀疑会提高他人对目标的关注。", "保留会让他人要求你之后给出理由。" } } end
  if s.phase == "day_player_stance_target" then
    local verb = s.player_stance_mode == "protect" and "暂时保留" or "公开怀疑"
    return { title = "公开站边", speaker = "你", lines = { "请选择你要" .. verb .. "的对象。", "这会进入桌面情报与证词簿。", "后续 NPC 会据此回应或调整立场。" } }
  end
  if s.phase == "day_fake_claim_target" then return { title = "伪装预言家", speaker = "你", lines = { "选择你要报出的验人。", "其他玩家只会看到公开声明。", "不要把狼队同伴推到台前。" } } end
  if s.phase == "day_fake_claim_result" then return { title = "伪装预言家", speaker = "你", lines = { "选择要公布的阵营结果。", "这条声明会进入证词簿。", "之后仍要用票型圆回逻辑。" } } end
  if s.phase == "day_question" then
    if s.question_kind then return { title = "追问对象", lines = { "本次追问：" .. ({ stance = "站边依据", vote = "落票意向", contradiction = "前后矛盾" })[s.question_kind] .. "。", "回答与这次压力都会写入证词簿。", "请选择你最想核对的人。" } } end
    return { title = "选择追问", lines = { "你还能追问" .. tostring(2 - s.question_count) .. "次。", "不同问题会给桌面带来不同压力。", "先选择这次要核对什么。" } }
  end
  if s.phase == "day_vote" then return { title = "放逐投票", lines = { "请选择要放逐的玩家。", "其他玩家按自己的信息投票。", "警长票按 1.5 票计算。" } } end
  if s.phase == "day_final_speech" then
    if s.current_speaker then return { title = "第" .. tostring(s.day) .. "天 · 最终陈词", speaker = name_of(s, s.current_speaker), lines = { Brain.final_statement(Rules.npc_view(s, s.current_speaker)), "最终陈词后将进入投票。", "点击后由下一位继续。" } } end
    return { title = "第" .. tostring(s.day) .. "天 · 最终陈词", lines = { "你的最终站边已公开。", "存活玩家将逐一给出最终票意。", "点击开始听取。" } }
  end
  if s.phase == "day_observe_vote" then return { title = "出局观战", lines = { "你已出局，不能再发言或投票。", "其余玩家会依据公开信息完成投票。", "点击查看本轮结果。" } } end
  if s.phase == "ending" then return { title = s.winner == "village" and "好人阵营胜利" or "狼人阵营胜利", lines = { "本局结束；结算页将公开身份与票型。", "可以重开当前或其他人工牌局。" } } end
  return { title = "月下狼局", lines = { "等待下一步。" } }
end

local function clear_notice(s)
  if s.notice then s.notice = nil; return true end
  return false
end

function M.advance(s)
  if clear_notice(s) then return true end
  if s.phase == "death_announce" or s.phase == "death_last_words" or s.phase == "hunter_npc_shot" or s.phase == "badge_npc_transfer" then
    return Rules.advance_death(s)
  end
  if s.dawn_report then
    s.notice = { s.dawn_report, "点击开始白天发言。" }
    s.dawn_report = nil
    return true
  end
  if s.phase == "day_speech" then
    if s.current_speaker and s.current_speaker ~= "you" then
      local view = Rules.npc_view(s, s.current_speaker)
      Rules.record_statement(s, s.current_speaker, Brain.statement(view), Brain.public_claim(view), Brain.stance(view))
    end
    local next_id = Rules.next_speech(s)
    s.current_speaker = next_id
    if next_id == "you" then s.phase = "day_player_speech" end
    if not next_id then
      s.current_speaker = nil
      if not Rules.player_alive(s) then s.phase = "day_observe_vote" end
    end
    return true
  end
  if s.phase == "sheriff_speech" then
    if s.current_speaker and s.current_speaker ~= "you" then
      Rules.record_sheriff_statement(s, s.current_speaker, Brain.sheriff_statement(Rules.npc_view(s, s.current_speaker)))
    end
    local next_id = Rules.next_sheriff_speech(s)
    s.current_speaker = next_id
    if next_id == "you" then s.phase = "sheriff_player_speech" end
    if not next_id then s.current_speaker = nil; s.phase = "sheriff_vote" end
    return true
  end
  if s.phase == "day_rebuttal" then
    if s.current_speaker then
      local view = Rules.npc_view(s, s.current_speaker)
      local text = Brain.rebuttal(view)
      Rules.record_statement(s, s.current_speaker, text, nil, Brain.stance(view))
    end
    s.current_speaker = Rules.next_rebuttal(s)
    return true
  end
  if s.phase == "day_final_speech" then
    if s.current_speaker then
      local text = Brain.final_statement(Rules.npc_view(s, s.current_speaker))
      Rules.record_statement(s, s.current_speaker, text)
    end
    s.current_speaker = Rules.next_final_speech(s)
    return true
  end
  return false
end

function M.choose(s, option)
  if option.kind == "page_prev" then s.target_page = math.max(1, (s.target_page or 1) - 1); return true end
  if option.kind == "page_next" then s.target_page = (s.target_page or 1) + 1; return true end
  if option.kind == "begin" then Rules.begin(s); return true end
  if option.kind == "deck_select" then s.phase = "deck_select"; return true end
  if option.kind == "sheriff" then Rules.choose_sheriff(s, option.run); return true end
  if option.kind == "sheriff_player_speech" then
    local text = option.style == "record" and "我承诺公开警徽流，逐票记录归票。"
      or option.style == "logic" and "我承诺逐条复盘票型，接受所有质询。"
      or "我简短说明后退水，把警徽交给更有把握的人。"
    Rules.record_sheriff_statement(s, "you", text)
    s.current_speaker = nil
    -- Return to the shared campaign cursor before requesting the next
    -- candidate.  The player-choice page is presentation-only, whereas the
    -- cursor deliberately asserts the canonical sheriff_speech phase.
    s.phase = "sheriff_speech"
    local next_id = Rules.next_sheriff_speech(s)
    s.current_speaker = next_id
    if next_id == "you" then error("candidate cursor did not advance") end
    if not next_id then s.phase = "sheriff_vote" else s.phase = "sheriff_speech" end
    return true
  end
  if option.kind == "sheriff_vote" then
    Rules.cast_sheriff_vote(s, option.id)
    s.notice = { "你警选投给" .. name_of(s, option.id) .. "。", "当选警长：" .. (s.sheriff_id and name_of(s, s.sheriff_id) or "无人") .. "。" }
    return true
  end
  if option.kind == "observe_vote" then
    local out, tied = Rules.resolve_vote(s)
    local lead = tied and "你没有投票；本轮平票。" or "NPC 放逐结果：" .. name_of(s, out) .. "。"
    s.notice = Rules.ballot_receipt(s, lead)
    return true
  end
  if option.kind == "night" then Rules.begin_night(s); return true end
  if option.kind == "last_words" then Rules.record_player_last_words(s, option.style); return true end
  if option.kind == "badge_destroy" then
    Rules.complete_player_badge_transfer(s, nil)
    return true
  end
  if option.kind == "witch" then
    if option.action == "poison" then s.target_mode = "poison"; s.target_page = 1
    else
      Rules.player_night_action(s, option.action)
      s.target_mode = nil
      s.notice = { option.action == "save" and "你使用了解药。" or "你决定不用药。", "夜晚结算将在下一步公开。" }
    end
    return true
  end
  if option.kind == "player_speech" then
    if option.claim == "fake_seer" then
      s.phase = "day_fake_claim_target"
      s.target_page = 1
      return true
    end
    Rules.record_claim(s, "you", option.claim, option.id)
    s.phase = "day_player_stance"
    return true
  end
  if option.kind == "player_stance_kind" then
    s.player_stance_mode = option.id
    s.phase = "day_player_stance_target"
    s.target_page = 1
    return true
  end
  if option.kind == "question_kind" then
    s.question_kind = option.id
    s.target_page = 1
    return true
  end
  if option.kind == "final_stance" then
    if option.action == "change" then
      s.phase = "day_final_stance_target"
      s.target_page = 1
    else
      Rules.finalize_player_stance(s)
      s.notice = { "你确认了最终站边。", "现在请按公开证据投票。" }
    end
    return true
  end
  if option.kind == "fake_claim_result" then
    Rules.record_claim(s, "you", "fake_seer", s.pending_claim_target, option.result)
    s.notice = { "你公开了伪造验人。", name_of(s, s.pending_claim_target) .. "被你报为" .. (option.result == "wolf" and "狼人。" or "好人。") }
    s.pending_claim_target = nil
    s.phase = "day_player_stance"
    return true
  end
  if option.kind == "target" then
    if s.phase == "night_wolf_action" then
      Rules.player_night_action(s, "kill", option.id)
      s.notice = { "狼队选择袭击" .. name_of(s, option.id) .. "。", "请等待天亮结算。" }
    elseif s.phase == "night_seer_action" then
      Rules.player_night_action(s, "check", option.id)
      local result = s.knowledge.you.checks[option.id]
      s.notice = { "查验结果：" .. name_of(s, option.id) .. "是" .. (result == "wolf" and "狼人。" or "好人。"), s.dawn_report or "该信息目前只有你知道。" }
      s.dawn_report = nil
    elseif s.phase == "night_witch_action" then
      Rules.player_night_action(s, "poison", option.id); s.target_mode = nil
      s.notice = { "你对" .. name_of(s, option.id) .. "使用了毒药。", "夜晚结算将在下一步公开。" }
    elseif s.phase == "hunter_shot" then
      Rules.player_hunter_shot(s, option.id)
      s.notice = { "你开枪带走了" .. name_of(s, option.id) .. "。", "阵营胜负正在结算。" }
    elseif s.phase == "badge_transfer" then
      Rules.complete_player_badge_transfer(s, option.id)
      s.notice = { "你将警徽移交给" .. name_of(s, option.id) .. "。", "移交已写入证词簿。" }
    elseif s.phase == "day_fake_claim_target" then
      s.pending_claim_target = option.id
      s.phase = "day_fake_claim_result"
      s.target_page = 1
      return true
    elseif s.phase == "day_question" then
      local question = Rules.ask(s, option.id, s.question_kind)
      local answer = Brain.answer(Rules.npc_view(s, option.id), "you", question)
      Rules.record_answer(s, option.id, "you", question, answer)
      s.notice = { "你问" .. name_of(s, option.id) .. "：" .. question, name_of(s, option.id) .. "：" .. answer }
      s.question_kind = nil
    elseif s.phase == "day_player_stance_target" then
      local mode = s.player_stance_mode or "suspect"
      local reason = mode == "protect" and "玩家要求桌面暂不放逐此人" or "玩家公开提出优先怀疑"
      Rules.record_stance(s, "you", option.id, reason, 1.6, mode)
      s.notice = { "你公开" .. (mode == "protect" and "保留" or "怀疑") .. name_of(s, option.id) .. "。", "该立场会影响后续回应与投票。" }
      s.player_stance_mode = nil
      s.phase = "day_speech"
      s.current_speaker = "you"
    elseif s.phase == "day_final_stance_target" then
      local changed = Rules.finalize_player_stance(s, option.id)
      s.notice = { changed and "你调整了最终站边。" or "你确认了最终站边。", "现在请按公开证据投票。" }
    elseif s.phase == "day_vote" then
      Rules.cast_vote(s, "you", option.id)
      local out, tied = Rules.resolve_vote(s)
      local lead = tied and ("你投给" .. name_of(s, option.id) .. "；本轮平票。") or ("你投给" .. name_of(s, option.id) .. "；放逐" .. name_of(s, out) .. "。")
      s.notice = Rules.ballot_receipt(s, lead)
    end
    s.target_page = 1
    return true
  end
  if option.kind == "restart" then
    local fresh = Rules.restart(s, option.deck)
    for key in pairs(s) do s[key] = nil end
    for key, value in pairs(fresh) do s[key] = value end
    return true
  end
  return false
end

function M.create(opts)
  local state_key = opts.state_key or "werewolf_table"
  local function ensure(ctx)
    local s = ctx.state[state_key]
    if type(s) == "table" and (s.schema == 1 or s.schema == 2 or s.schema == 3 or s.schema == 4) then
      s.schema = 5
      s.claims = s.claims or {}
      s.suspicion = s.suspicion or {}
      s.log = s.log or {}
      s.public_claims = s.public_claims or {}
      s.evidence = s.evidence or { events = {}, stances = {} }
      s.evidence.events = s.evidence.events or {}
      s.evidence.stances = s.evidence.stances or {}
    elseif type(s) ~= "table" or s.schema ~= 5 then
      s = Rules.new("mirror")
      ctx.state[state_key] = s
    end
    return s
  end
  return {
    STATE_KEY = state_key,
    boot = function(ctx) ensure(ctx) end,
    state = ensure,
    options = M.options,
    log_page = M.log_page,
    description = M.description,
    on_input = function(ctx, ev)
      if not (ev.type == "pointer" and ev.phase == "up") or ev.gesture ~= "tap" then return false end
      local s = ensure(ctx)
      local options = M.options(s)
      local b = Layout.compute(ctx, #options, s.phase == "ending")
      if s.overlay == "log" then
        local page = M.log_page(s)
        if Layout.hit_log_previous(b, ev.x, ev.y) and page.page < page.pages then
          s.log_page = page.page + 1
          ctx:invalidate()
          return true
        end
        if Layout.hit_log_next(b, ev.x, ev.y) and page.page > 1 then
          s.log_page = page.page - 1
          ctx:invalidate()
          return true
        end
        if Layout.hit_stage(b, ev.x, ev.y) then
          s.overlay = nil
          ctx:invalidate()
          return true
        end
        return false
      end
      if s.overlay == "board" then
        if Layout.hit_stage(b, ev.x, ev.y) then
          s.overlay = nil
          ctx:invalidate()
          return true
        end
        return false
      end
      if s.overlay == "menu" then
        local action = Layout.menu_action(ev.x, ev.y)
        if action == "log" then s.overlay = "log"; s.log_page = 1
        elseif action == "board" then s.overlay = "board"
        elseif action == "restart" then
          local fresh = Rules.restart(s)
          for key in pairs(s) do s[key] = nil end
          for key, value in pairs(fresh) do s[key] = value end
        elseif action == "decks" then
          local fresh = Rules.restart(s)
          for key in pairs(s) do s[key] = nil end
          for key, value in pairs(fresh) do s[key] = value end
          s.phase = "deck_select"
        elseif Layout.hit_stage(b, ev.x, ev.y) then s.overlay = nil
        else return false end
        ctx:invalidate()
        return true
      end
      if Layout.hit_log(b, ev.x, ev.y) then
        s.overlay = "menu"
        ctx:invalidate()
        return true
      end
      if s.notice then
        s.notice = nil
        ctx:invalidate()
        return true
      end
      for index, option in ipairs(options) do
        if Layout.hit_choice(b, index, ev.x, ev.y) then
          if M.choose(s, option) then ctx:invalidate(); return true end
        end
      end
      if Layout.hit_stage(b, ev.x, ev.y) and M.advance(s) then ctx:invalidate(); return true end
      return false
    end,
  }
end

return M
