-- NPC reasoning consumes only the projected view supplied by werewolf_rules.
-- It never receives the full game state, keeping a solo table fair rather
-- than scripting omniscient opponents.

local M = {}

local function person(view, id)
  for _, entry in ipairs(view.public.roster) do if entry.id == id then return entry end end
end

local function is_ally(view, id)
  for _, ally in ipairs(view.self.wolf_allies or {}) do if ally == id then return true end end
  return id == view.self_id
end

local function public_claim(view, id)
  return (view.public.claims or {})[id]
end

local function public_stance(view, id)
  return view.public.evidence and view.public.evidence.stances and view.public.evidence.stances[id]
end

local function evidence_score(view, id)
  local score = (view.public.suspicion and view.public.suspicion[id]) or 0
  local player_position = public_stance(view, "you")
  if player_position and player_position.target == id then
    score = score + (player_position.position == "protect" and -1.2 or 1.6)
  end
  for claimant, claim in pairs(view.public.claims or {}) do
    if claimant ~= id and claim.kind == "seer" and claim.target == id then
      score = score + (claim.result == "wolf" and 3 or -1.2)
    end
  end
  for _, entry in ipairs(view.public.log or {}) do
    if entry.kind == "ballot" and entry.actor == id then
      local target = person(view, entry.target)
      if target and target.revealed == "狼人" then score = score - 0.5 end
      if target and target.revealed and target.revealed ~= "狼人" then score = score + 0.5 end
    elseif entry.kind == "question" and entry.target == id then
      score = score + 0.3
    end
  end
  return score
end

local function best_target(view, candidates, allow_allies)
  local best, score = nil, -999
  for _, id in ipairs(candidates) do
    if id ~= view.self_id and (allow_allies or not is_ally(view, id)) then
      local value = evidence_score(view, id)
      local entry = person(view, id)
      if entry and entry.sheriff then value = value + 0.15 end
      if value > score then best, score = id, value end
    end
  end
  return best
end

function M.public_claim(view)
  if view.self.role ~= "seer" then return nil end
  for id, result in pairs(view.self.checks or {}) do
    return { kind = "seer", target = id, result = result }
  end
  return nil
end

-- A position is a public commitment, not merely flavour text.  The later
-- vote will honour it unless a stronger, newly public piece of evidence
-- arrives (for example a black check).  Wolves still only receive their own
-- teammate knowledge through the projected private view.
function M.stance(view)
  local checked_target
  for id, result in pairs(view.self.checks or {}) do
    if result == "wolf" then checked_target = id end
  end
  if checked_target then
    return { target = checked_target, reason = "我的验人结果为狼人", confidence = 3, position = "suspect" }
  end
  for claimant, claim in pairs(view.public.claims or {}) do
    if claimant ~= view.self_id and claim.kind == "seer" and claim.result == "wolf" and claim.target then
      return { target = claim.target, reason = person(view, claimant).name .. "公开报出黑验", confidence = 2.4, position = "suspect" }
    end
  end
  local target = best_target(view, view.public.alive_ids or {}, view.self.role ~= "wolf")
  local speaker = person(view, view.self_id)
  local reason = "暂时没有更强公开证据"
  if speaker and speaker.style == "record" then reason = "先核对已有票型和发言" end
  if speaker and speaker.style == "pressure" then reason = "需要对方明确站边" end
  if speaker and speaker.style == "logic" then reason = "前后说法仍待核对" end
  if speaker and speaker.style == "probe" then reason = "回答尚未消除疑点" end
  if speaker and speaker.style == "protect" then reason = "不愿仓促放逐他人" end
  local pressure = target and evidence_score(view, target) or 0
  -- Questions and a player's public position are weaker than a black check,
  -- but can still legitimately move a cautious NPC off an early hunch.
  local confidence = target and math.max(1.1, math.min(2.4, 1 + pressure * 0.5)) or 0.2
  return { target = target, reason = reason, confidence = confidence, position = "suspect" }
end

function M.vote_decision(view, candidates)
  local fresh = M.stance(view)
  local committed = public_stance(view, view.self_id)
  local target, reason = fresh.target, fresh.reason
  local allowed = {}
  for _, candidate in ipairs(candidates or {}) do allowed[candidate] = true end
  if target and not allowed[target] then
    target = best_target(view, candidates, view.self.role ~= "wolf")
    reason = "在本轮候选人中选择更可疑的一位"
  end
  if committed and committed.target then
    for _, candidate in ipairs(candidates or {}) do
      if candidate == committed.target then
        target, reason = committed.target, committed.reason
        break
      end
    end
  end
  -- A public black check (or the seer's own check) is allowed to supersede a
  -- weaker earlier hunch; the changed reason remains visible in the ledger.
  if fresh.confidence > ((committed and committed.confidence) or 0) + 0.35 then
    target, reason = fresh.target, fresh.reason
  end
  return { target = target, reason = reason, changed = committed and committed.target ~= target or false }
end

function M.vote(view, candidates)
  return M.vote_decision(view, candidates).target
end

-- The sheriff vote happens before the first public day discussion, so it
-- deliberately does not inherit a later day-position.  This keeps the
-- opening deck balance independent from the evidence-led day loop.
function M.sheriff_vote(view, candidates)
  if view.self.role == "wolf" then return best_target(view, candidates, false) end
  return best_target(view, candidates, true)
end

-- Campaign, rebuttal and final words deliberately live beside the NPC's
-- public reasoning.  They receive only a projected view, just like a vote;
-- this prevents presentation copy from becoming a secret-role backdoor.
function M.sheriff_statement(view)
  local speaker = person(view, view.self_id)
  if speaker and speaker.style == "record" then return "我上警只做票型记录，警徽流会公开。" end
  if speaker and speaker.style == "logic" then return "我愿意把每一步判断摆在桌上，接受质询。" end
  return "我愿意承担归票责任，警徽流会写进证词簿。"
end

function M.rebuttal(view)
  local stance = public_stance(view, view.self_id)
  local target = stance and stance.target and person(view, stance.target)
  if view.self.role == "wolf" then return "我保留原判断，先看谁的票型最急。" end
  if target then return "我仍关注" .. target.name .. "，但愿意根据回应调整。" end
  return "这轮信息还不够，我不会把怀疑当成定论。"
end

function M.final_statement(view)
  local decision = M.vote_decision(view, view.public.alive_ids or {})
  local target = decision.target and person(view, decision.target)
  if target then return "最终我会投" .. target.name .. "，理由是" .. decision.reason .. "。" end
  return "我暂不改口，票型会与公开立场对应。"
end

function M.last_words(view)
  local speaker = person(view, view.self_id)
  local target = M.vote_decision(view, view.public.alive_ids or {}).target
  local target_name = target and person(view, target).name or "桌上剩下的人"
  if view.self.role == "wolf" then return "别急着替我定性，继续核对" .. target_name .. "的票。" end
  return (speaker and speaker.name or "我") .. "的遗言：别只看我的身份，继续核对" .. target_name .. "。"
end

function M.badge_target(view, candidates)
  return M.vote_decision(view, candidates).target or candidates[1]
end

function M.statement(view)
  local speaker = person(view, view.self_id)
  local position = M.stance(view)
  local target = position.target
  local target_name = target and person(view, target).name or "暂时没人"
  local own_claim = M.public_claim(view)
  if own_claim then
    return "昨夜验" .. person(view, own_claim.target).name .. "：" .. (own_claim.result == "wolf" and "狼人" or "好人") .. "。"
  end
  local claim = target and public_claim(view, target)
  if claim and claim.kind == "seer" and claim.result == "wolf" then
    return "先跟" .. person(view, target).name .. "的黑验。"
  end
  if speaker.style == "record" then return "我先站" .. target_name .. "，理由是票型要核。" end
  if speaker.style == "pressure" then return target_name .. "，我站你，先把依据说清。" end
  if speaker.style == "careful" then return "我暂时站" .. target_name .. "，但保留复核。" end
  if speaker.style == "logic" then return "我先站" .. target_name .. "，重点核前后说法。" end
  if speaker.style == "probe" then return target_name .. "，我先盯你这条线。" end
  if speaker.style == "protect" then return "我不愿仓促推" .. target_name .. "，先听回应。" end
  if speaker.style == "direct" then return "我当前票会给" .. target_name .. "。" end
  return "我暂时不信" .. target_name .. "。"
end

function M.detail(view)
  local speaker = person(view, view.self_id)
  local own_claim = M.public_claim(view)
  if own_claim then return "验人和票型需要交叉核对。" end
  local position = M.stance(view)
  local target = position.target
  local claim = target and public_claim(view, target)
  if claim and claim.kind == "seer" and claim.result == "wolf" then return "先看这条声明能否经住票型。" end
  return "我的理由是：" .. position.reason .. "。"
end

function M.answer(view, asker, question)
  local self = person(view, view.self_id)
  local stance = public_stance(view, view.self_id)
  local target_name = stance and stance.target and person(view, stance.target).name or "暂未定人"
  if view.self.role == "wolf" then return "我目前站" .. target_name .. "，理由已写入证词簿。" end
  local claim = public_claim(view, view.self_id)
  if claim and claim.kind == "seer" then return "验人已报，请结合票型判断。" end
  if question == "你刚才的说法和票型怎么对应？" then return "我会优先投" .. target_name .. "；若有新黑验才会改票。" end
  if question == "你准备把票投给谁？" then return "我当前站" .. target_name .. "，最终票会和这个立场对应。" end
  return "我站" .. target_name .. "，理由是" .. (stance and stance.reason or "还在核对公开信息") .. "。"
end

return M
