-- Deterministic, inspectable 9-player werewolf rules.
-- This module owns secret roles and phase transitions. Presentation and NPC
-- dialogue must use the public/private views below rather than `state.roles`.

local Roles = require("domain.roles")
local Decks = require("domain.decks")
local Brain = require("domain.npc_brain")
local Evidence = require("domain.table_evidence")
local Report = require("domain.game_report")

local M = {}

local function copy_array(src)
  local out = {}
  for index, value in ipairs(src or {}) do out[index] = value end
  return out
end

local function copy_map(src)
  local out = {}
  for key, value in pairs(src or {}) do out[key] = value end
  return out
end

local function copy_roster()
  local out = {}
  for index, person in ipairs(Decks.roster) do
    out[index] = { id = person.id, name = person.name, seat = person.seat, style = person.style, alive = true, revealed = false, sheriff = false }
  end
  return out
end

local function player_of(s, id)
  for _, person in ipairs(s.roster) do if person.id == id then return person end end
  return nil
end

local function is_alive(s, id)
  local person = player_of(s, id)
  return person and person.alive or false
end

local function add_log(s, kind, text, actor, target)
  s.log[#s.log + 1] = { day = s.day, kind = kind, text = text, actor = actor, target = target }
  if #s.log > 64 then table.remove(s.log, 1) end
end

local function wolves(s)
  local out = {}
  for id, role in pairs(s.roles) do if is_alive(s, id) and Roles.is_wolf(role) then out[#out + 1] = id end end
  table.sort(out)
  return out
end

local function living_non_wolves(s)
  local count = 0
  for id, role in pairs(s.roles) do if is_alive(s, id) and not Roles.is_wolf(role) then count = count + 1 end end
  return count
end

local function check_winner(s)
  if #wolves(s) == 0 then s.winner = "village"; return true end
  if living_non_wolves(s) <= #wolves(s) then s.winner = "wolf"; return true end
  return false
end

local function first_alive(s, ids)
  for _, id in ipairs(ids or {}) do if is_alive(s, id) then return id end end
  return nil
end

local function next_alive_not(s, forbidden)
  for _, person in ipairs(s.roster) do
    if person.alive and not forbidden[person.id] then return person.id end
  end
  return nil
end

local function reveal_death(s, id, cause)
  local person = player_of(s, id)
  if not person or not person.alive then return false end
  local carried_badge = person.sheriff
  person.alive = false
  person.revealed = true
  person.sheriff = false
  if carried_badge then s.sheriff_id = nil end
  s.revealed[id] = s.roles[id]
  add_log(s, "death", person.name .. "出局，身份为" .. Roles.name(s.roles[id]) .. "。", id, cause)
  Evidence.append(s, "death", { actor = id, target = cause, text = person.name .. "出局并翻牌。" })
  return true, carried_badge
end

local function set_phase(s, phase)
  s.phase = phase
  s.focus = 1
end

local function enter_ending(s)
  s.ending_report = Report.build(s)
  set_phase(s, "ending")
end

-- Death is a public ceremony, not an invisible side effect.  The role is
-- revealed before last words; a hunter shot and a sheriff badge are then
-- resolved one at a time so the player can audit every consequence.
local resolve_dawn
local function finish_death(s, continuation)
  if continuation == "dawn" then resolve_dawn(s); return end
  if check_winner(s) then enter_ending(s) else set_phase(s, "night_begin") end
end

local function begin_death(s, id, cause, continuation)
  local died, carried_badge = reveal_death(s, id, cause)
  if not died then return false end
  s.death_flow = { id = id, cause = cause, continuation = continuation, badge = carried_badge and true or false }
  set_phase(s, "death_announce")
  return true
end

local function continue_after_last_words(s)
  local flow = s.death_flow
  if not flow then return end
  if s.roles[flow.id] == "hunter" then
    if flow.id == "you" then
      s.after_hunter = flow.continuation
      set_phase(s, "hunter_shot")
      return
    end
    local target = Brain.vote(M.npc_view(s, flow.id), M.alive_ids(s))
    if target and is_alive(s, target) then
      flow.hunter_target = target
      set_phase(s, "hunter_npc_shot")
      return
    end
  end
  if flow.badge then
    local targets = M.alive_ids(s)
    if flow.id == "you" then
      set_phase(s, "badge_transfer")
      return
    end
    flow.badge_target = Brain.badge_target(M.npc_view(s, flow.id), targets)
    set_phase(s, "badge_npc_transfer")
    return
  end
  local continuation = flow.continuation
  s.death_flow = nil
  finish_death(s, continuation)
end

local function private_knowledge(s, id)
  local role = s.roles[id]
  local knowledge = { role = role, checks = {}, wolf_allies = {}, witch = { save = false, poison = false } }
  for checked, result in pairs((s.knowledge[id] and s.knowledge[id].checks) or {}) do knowledge.checks[checked] = result end
  if Roles.is_wolf(role) then
    for other, other_role in pairs(s.roles) do if other ~= id and Roles.is_wolf(other_role) then knowledge.wolf_allies[#knowledge.wolf_allies + 1] = other end end
    table.sort(knowledge.wolf_allies)
  end
  if role == "witch" then
    knowledge.witch.save = s.knowledge[id].save
    knowledge.witch.poison = s.knowledge[id].poison
  end
  return knowledge
end

local function auto_npc_wolves(s)
  local wolf_ids = wolves(s)
  if #wolf_ids == 0 then return end
  local player_is_wolf = Roles.is_wolf(s.roles.you)
  if player_is_wolf and is_alive(s, "you") then set_phase(s, "night_wolf_action"); return end
  local forbidden = {}
  for _, id in ipairs(wolf_ids) do forbidden[id] = true end
  local target = first_alive(s, s.deck.wolf_plan)
  if target and forbidden[target] then target = nil end
  s.night.wolf_target = target or next_alive_not(s, forbidden)
end

local function auto_npc_seer(s)
  local seer
  for id, role in pairs(s.roles) do if role == "seer" and is_alive(s, id) then seer = id end end
  if not seer or seer == "you" then return end
  local target = next_alive_not(s, { [seer] = true })
  if target then s.knowledge[seer].checks[target] = Roles.is_wolf(s.roles[target]) and "wolf" or "good" end
end

local function auto_npc_witch(s)
  local witch
  for id, role in pairs(s.roles) do if role == "witch" and is_alive(s, id) then witch = id end end
  if not witch or witch == "you" then return end
  if s.knowledge[witch].save and s.night.wolf_target and not Roles.is_wolf(s.roles[s.night.wolf_target]) then
    s.knowledge[witch].save = false
    s.night.saved = true
  end
end

local function resolve_after_wolf_action(s)
  if s.roles.you == "seer" and is_alive(s, "you") then set_phase(s, "night_seer_action"); return end
  auto_npc_seer(s)
  if s.roles.you == "witch" and is_alive(s, "you") then set_phase(s, "night_witch_action"); return end
  auto_npc_witch(s)
  resolve_dawn(s)
end

local function continue_dawn(s)
  s.day = s.day + 1
  if check_winner(s) then enter_ending(s); return end
  s.speech_order = {}
  for _, person in ipairs(s.roster) do if person.alive then s.speech_order[#s.speech_order + 1] = person.id end end
  s.speech_index = 1
  s.question_count = 0
  s.votes = {}
  set_phase(s, "day_speech")
end

resolve_dawn = function(s)
  if not s.night.dawn_queue then
    s.night.dawn_queue = {}
    s.night.dawn_dead = {}
    if s.night.poison_target then s.night.dawn_queue[#s.night.dawn_queue + 1] = { id = s.night.poison_target, cause = "poison" } end
    if s.night.wolf_target and not s.night.saved and s.night.wolf_target ~= s.night.poison_target then
      s.night.dawn_queue[#s.night.dawn_queue + 1] = { id = s.night.wolf_target, cause = "night" }
    end
    if s.night.wolf_target and s.night.saved then add_log(s, "dawn", "昨夜平安夜。") end
  end
  while #s.night.dawn_queue > 0 do
    local death = table.remove(s.night.dawn_queue, 1)
    if is_alive(s, death.id) then
      s.night.dawn_dead[#s.night.dawn_dead + 1] = death.id
      begin_death(s, death.id, death.cause, "dawn")
      return
    end
  end
  continue_dawn(s)
  if #s.night.dawn_dead > 0 then
    local names = {}
    for _, id in ipairs(s.night.dawn_dead) do names[#names + 1] = player_of(s, id).name end
    s.dawn_report = "昨夜死亡：" .. table.concat(names, "、") .. "。"
  elseif s.night.saved then
    s.dawn_report = "昨夜平安夜。"
  else
    s.dawn_report = "昨夜无人死亡。"
  end
end

function M.new(deck_id)
  local deck = Decks.get(deck_id or "mirror")
  local s = {
    schema = 5, deck_id = deck.id, deck = deck, roster = copy_roster(), roles = {}, knowledge = {},
    phase = "briefing", day = 0, sheriff_id = nil, revealed = {}, log = {}, history = {}, suspicion = {}, claims = {},
    public_claims = {}, evidence = { events = {}, stances = {} }, night = {}, speech_order = {}, speech_index = 1, question_count = 0, votes = {}, focus = 1,
  }
  for id, role in pairs(deck.roles) do
    s.roles[id] = role
    s.knowledge[id] = { checks = {}, save = true, poison = true }
  end
  add_log(s, "setup", "本局为" .. deck.name .. "。")
  return s
end

function M.deck_name(s) return s.deck.name end
function M.player_role(s) return s.roles.you end
function M.player_alive(s) return is_alive(s, "you") end
function M.person(s, id) return player_of(s, id) end
function M.alive_ids(s)
  local out = {}
  for _, person in ipairs(s.roster) do if person.alive then out[#out + 1] = person.id end end
  return out
end

function M.public_view(s)
  local roster = {}
  for index, person in ipairs(s.roster) do
    roster[index] = { id = person.id, name = person.name, seat = person.seat, style = person.style, alive = person.alive, sheriff = person.sheriff, revealed = s.revealed[person.id] and Roles.name(s.revealed[person.id]) or nil }
  end
  local claims = {}
  for id, claim in pairs(s.public_claims or {}) do claims[id] = copy_map(claim) end
  return { phase = s.phase, day = s.day, roster = roster, sheriff_id = s.sheriff_id, log = copy_array(s.log), votes = copy_map(s.votes), winner = s.winner, suspicion = copy_map(s.suspicion), claims = claims, evidence = Evidence.public(s), alive_ids = M.alive_ids(s) }
end

function M.npc_view(s, id)
  return { public = M.public_view(s), self = private_knowledge(s, id), self_id = id }
end

function M.record_statement(s, id, text, claim, stance)
  assert(is_alive(s, id), "dead player cannot speak")
  if claim then s.public_claims[id] = copy_map(claim) end
  add_log(s, "speech", player_of(s, id).name .. "：" .. text, id)
  Evidence.append(s, "speech", { actor = id, text = text })
  if stance and stance.target then
    Evidence.set_stance(s, id, stance.target, stance.reason, stance.confidence, stance.position)
  end
end

function M.record_stance(s, id, target, reason, confidence, position)
  assert(is_alive(s, id) and is_alive(s, target) and id ~= target, "invalid public stance")
  local actor, subject = player_of(s, id), player_of(s, target)
  local verb = position == "protect" and "暂时保留" or "优先怀疑"
  local text = actor.name .. verb .. subject.name .. "。"
  add_log(s, "stance", text, id, target)
  Evidence.set_stance(s, id, target, reason, confidence, position)
end

function M.record_claim(s, id, claim, target, result)
  assert(is_alive(s, id), "dead player cannot claim")
  local text = "你暂时保留身份信息。"
  if claim == "seer" and target then
    local result = s.knowledge[id].checks[target]
    assert(result, "cannot claim an unchecked target")
    text = "你报出" .. player_of(s, target).name .. "的验人：" .. (result == "wolf" and "狼人" or "好人") .. "。"
  elseif claim == "role" then
    text = "你公开了自己的身份：" .. Roles.name(s.roles[id]) .. "。"
  elseif claim == "fake_seer" and target and (result == "wolf" or result == "good") then
    text = "你自称预言家，报" .. player_of(s, target).name .. "为" .. (result == "wolf" and "狼人" or "好人") .. "。"
  else
    assert(claim == "quiet", "invalid public claim")
  end
  s.claims[id] = { kind = claim, target = target, result = result }
  if claim == "seer" then s.public_claims[id] = { kind = "seer", target = target, result = s.knowledge[id].checks[target] }
  elseif claim == "fake_seer" then s.public_claims[id] = { kind = "seer", target = target, result = result }
  elseif claim == "role" then s.public_claims[id] = { kind = "role", role = s.roles[id] }
  end
  add_log(s, "claim", text, id, target)
  Evidence.append(s, "claim", { actor = id, target = target, text = text })
end

function M.record_answer(s, id, asker, question, answer)
  assert(is_alive(s, id), "dead player cannot answer")
  local text = player_of(s, id).name .. "回应：" .. answer
  add_log(s, "answer", text, id, asker)
  Evidence.append(s, "answer", { actor = id, target = asker, text = answer, reason = question })
end

function M.advance_death(s)
  local flow = s.death_flow
  assert(flow, "no death ceremony")
  if s.phase == "death_announce" then
    set_phase(s, "death_last_words")
    return true
  end
  if s.phase == "death_last_words" then
    if flow.id == "you" then return false end
    local words = Brain.last_words(M.npc_view(s, flow.id))
    add_log(s, "last_words", words, flow.id)
    Evidence.append(s, "last_words", { actor = flow.id, text = words })
    continue_after_last_words(s)
    return true
  end
  if s.phase == "hunter_npc_shot" then
    local target, continuation = flow.hunter_target, flow.continuation
    add_log(s, "hunter", player_of(s, flow.id).name .. "发动技能带走了" .. player_of(s, target).name .. "。", flow.id, target)
    s.death_flow = nil
    begin_death(s, target, "hunter", continuation)
    return true
  end
  if s.phase == "badge_npc_transfer" then
    local target, continuation = flow.badge_target, flow.continuation
    if target and is_alive(s, target) then M.transfer_badge(s, target) else M.transfer_badge(s, nil) end
    s.death_flow = nil
    finish_death(s, continuation)
    return true
  end
  return false
end

function M.record_player_last_words(s, style)
  local flow = s.death_flow
  assert(s.phase == "death_last_words" and flow and flow.id == "you", "player last words unavailable")
  local words = style == "trust" and "我的遗言：别急着追我的身份，先把公开票型逐张核完。"
    or style == "suspect" and "我的遗言：我仍怀疑我最后公开站边的那条线。"
    or "我的遗言：请把今天的发言、回应和票型放在一起看。"
  add_log(s, "last_words", words, "you")
  Evidence.append(s, "last_words", { actor = "you", text = words })
  continue_after_last_words(s)
end

function M.badge_targets(s)
  local out = {}
  for _, id in ipairs(M.alive_ids(s)) do out[#out + 1] = id end
  return out
end

function M.transfer_badge(s, target)
  local flow = s.death_flow
  assert(flow and flow.badge, "no badge to transfer")
  local owner = player_of(s, flow.id)
  if target then
    assert(is_alive(s, target), "invalid badge target")
    local successor = player_of(s, target)
    successor.sheriff = true
    s.sheriff_id = target
    add_log(s, "badge", owner.name .. "移交警徽给" .. successor.name .. "。", flow.id, target)
    Evidence.append(s, "badge", { actor = flow.id, target = target, text = owner.name .. "移交警徽。" })
  else
    add_log(s, "badge", owner.name .. "撕毁警徽。", flow.id)
    Evidence.append(s, "badge", { actor = flow.id, text = owner.name .. "撕毁警徽。" })
  end
end

function M.complete_player_badge_transfer(s, target)
  assert(s.phase == "badge_transfer" and s.death_flow and s.death_flow.id == "you", "player badge transfer unavailable")
  local continuation = s.death_flow.continuation
  M.transfer_badge(s, target)
  s.death_flow = nil
  finish_death(s, continuation)
end

function M.begin(s)
  assert(s.phase == "briefing", "game can only begin from briefing")
  set_phase(s, "sheriff_choice")
  add_log(s, "sheriff", "警长竞选开始。")
end

function M.choose_sheriff(s, player_runs)
  assert(s.phase == "sheriff_choice", "not sheriff choice")
  local candidates = copy_array(s.deck.sheriff_candidates)
  if player_runs then candidates[#candidates + 1] = "you" end
  s.sheriff_candidates = candidates
  s.sheriff_votes = {}
  local names = {}
  for _, id in ipairs(candidates) do names[#names + 1] = player_of(s, id).name end
  s.sheriff_speech_order = copy_array(candidates)
  s.sheriff_speech_index = 1
  add_log(s, "sheriff", table.concat(names, "、") .. "报名竞选警长。")
  set_phase(s, "sheriff_speech")
end

function M.next_sheriff_speech(s)
  assert(s.phase == "sheriff_speech", "not sheriff speech")
  local speaker = s.sheriff_speech_order[s.sheriff_speech_index]
  if speaker then s.sheriff_speech_index = s.sheriff_speech_index + 1 end
  return speaker
end

function M.record_sheriff_statement(s, id, text)
  assert(is_alive(s, id), "dead candidate cannot campaign")
  add_log(s, "sheriff_speech", player_of(s, id).name .. "竞选发言：" .. text, id)
  Evidence.append(s, "sheriff_speech", { actor = id, text = text })
end

function M.sheriff_targets(s)
  return copy_array(s.sheriff_candidates)
end

function M.cast_sheriff_vote(s, target)
  assert(s.phase == "sheriff_vote", "not sheriff vote")
  local valid = false
  for _, candidate in ipairs(s.sheriff_candidates) do if candidate == target then valid = true end end
  assert(valid, "invalid sheriff candidate")
  s.sheriff_votes.you = target
  local tally = {}
  for _, person in ipairs(s.roster) do
    if person.alive and person.id ~= "you" then
      local vote = Brain.sheriff_vote(M.npc_view(s, person.id), s.sheriff_candidates) or target
      s.sheriff_votes[person.id] = vote
    end
  end
  for voter, vote in pairs(s.sheriff_votes) do
    tally[vote] = (tally[vote] or 0) + 1
    add_log(s, "sheriff_ballot", player_of(s, voter).name .. "警选投给" .. player_of(s, vote).name .. "。", voter, vote)
  end
  local winner, high, tied = nil, -1, false
  for _, candidate in ipairs(s.sheriff_candidates) do
    local count = tally[candidate] or 0
    if count > high then winner, high, tied = candidate, count, false elseif count == high then tied = true end
  end
  if tied then
    add_log(s, "sheriff", "警长竞选平票，本局无警长。")
  else
    s.sheriff_id = winner
    player_of(s, winner).sheriff = true
    add_log(s, "sheriff", player_of(s, winner).name .. "当选警长。", winner)
  end
  s.night = {}
  set_phase(s, "night_begin")
end

function M.begin_night(s)
  assert(s.phase == "night_begin", "not night begin")
  s.night = { saved = false, poison_target = nil }
  auto_npc_wolves(s)
  if s.phase == "night_wolf_action" then return end
  if s.roles.you == "seer" and is_alive(s, "you") then set_phase(s, "night_seer_action"); return end
  auto_npc_seer(s)
  if s.roles.you == "witch" and is_alive(s, "you") then set_phase(s, "night_witch_action"); return end
  auto_npc_witch(s)
  resolve_dawn(s)
end

function M.night_targets(s, action)
  local out = {}
  for _, person in ipairs(s.roster) do
    if person.alive and person.id ~= "you" then
      if action ~= "wolf" or not Roles.is_wolf(s.roles[person.id]) then out[#out + 1] = person.id end
    end
  end
  return out
end

function M.hunter_targets(s)
  return M.night_targets(s, "hunter")
end

function M.player_night_action(s, action, target)
  assert(is_alive(s, "you"), "dead player cannot act at night")
  if s.phase == "night_wolf_action" then
    assert(action == "kill" and is_alive(s, target) and not Roles.is_wolf(s.roles[target]), "invalid wolf target")
    s.night.wolf_target = target
    resolve_after_wolf_action(s)
    return
  end
  if s.phase == "night_seer_action" then
    assert(action == "check" and is_alive(s, target) and target ~= "you", "invalid seer target")
    s.knowledge.you.checks[target] = Roles.is_wolf(s.roles[target]) and "wolf" or "good"
    add_log(s, "private", "你验到了" .. player_of(s, target).name .. "。", "you", target)
    if s.roles.you == "witch" then set_phase(s, "night_witch_action") else auto_npc_witch(s); resolve_dawn(s) end
    return
  end
  if s.phase == "night_witch_action" then
    assert(s.roles.you == "witch", "only witch has this phase")
    if action == "save" then
      assert(s.knowledge.you.save and s.night.wolf_target, "save unavailable")
      s.knowledge.you.save = false; s.night.saved = true
    elseif action == "poison" then
      assert(s.knowledge.you.poison and is_alive(s, target) and target ~= "you", "poison unavailable")
      s.knowledge.you.poison = false; s.night.poison_target = target
    elseif action ~= "pass" then error("unknown witch action") end
    resolve_dawn(s)
    return
  end
  error("no player night action in phase " .. tostring(s.phase))
end

function M.next_speech(s)
  assert(s.phase == "day_speech", "not day speech")
  local speaker = s.speech_order[s.speech_index]
  if not speaker then
    s.rebuttal_order = {}
    for _, id in ipairs(M.alive_ids(s)) do if id ~= "you" then s.rebuttal_order[#s.rebuttal_order + 1] = id end end
    s.rebuttal_index = 1
    set_phase(s, "day_rebuttal")
    return nil
  end
  s.speech_index = s.speech_index + 1
  return speaker
end

function M.next_rebuttal(s)
  assert(s.phase == "day_rebuttal", "not rebuttal phase")
  local speaker = s.rebuttal_order[s.rebuttal_index]
  if not speaker then set_phase(s, "day_question"); return nil end
  s.rebuttal_index = s.rebuttal_index + 1
  return speaker
end

function M.next_final_speech(s)
  assert(s.phase == "day_final_speech", "not final speech phase")
  local speaker = s.final_speech_order[s.final_speech_index]
  if not speaker then set_phase(s, "day_vote"); return nil end
  s.final_speech_index = s.final_speech_index + 1
  return speaker
end

function M.ask(s, target, kind)
  assert(s.phase == "day_question" and s.question_count < 2 and is_alive(s, target) and target ~= "you", "invalid question")
  assert(kind == "stance" or kind == "vote" or kind == "contradiction", "invalid question kind")
  s.question_count = s.question_count + 1
  local questions = {
    stance = "你的站边依据是什么？",
    vote = "你准备把票投给谁？",
    contradiction = "你刚才的说法和票型怎么对应？",
  }
  local pressure = { stance = 0.8, vote = 1.1, contradiction = 1.5 }
  local question = questions[kind]
  s.suspicion[target] = (s.suspicion[target] or 0) + pressure[kind]
  s.last_question = { target = target, kind = kind, text = question }
  add_log(s, "question", "你追问" .. player_of(s, target).name .. "：" .. question, "you", target)
  Evidence.append(s, "question", { actor = "you", target = target, text = question, reason = kind, confidence = pressure[kind] })
  if s.question_count >= 2 then set_phase(s, "day_final_stance") end
  return question
end

function M.finalize_player_stance(s, target)
  assert(s.phase == "day_final_stance" or s.phase == "day_final_stance_target", "not final stance phase")
  local current = Evidence.stance(s, "you")
  assert(current and current.target, "player must have an earlier public stance")
  local final_target = target or current.target
  assert(is_alive(s, final_target) and final_target ~= "you", "invalid final stance target")
  local changed = current.target ~= final_target
  M.record_stance(s, "you", final_target, changed and "玩家在追问后调整最终立场" or "玩家确认此前公开立场", 2.1, current.position)
  add_log(s, "final_stance", "你" .. (changed and "调整" or "确认") .. "最终站边。", "you", final_target)
  s.final_speech_order = {}
  for _, id in ipairs(M.alive_ids(s)) do if id ~= "you" then s.final_speech_order[#s.final_speech_order + 1] = id end end
  s.final_speech_index = 1
  set_phase(s, "day_final_speech")
  return changed
end

function M.cast_vote(s, voter, target)
  assert(s.phase == "day_vote" and is_alive(s, voter) and is_alive(s, target) and voter ~= target, "invalid vote")
  s.votes[voter] = target
end

function M.player_hunter_shot(s, target)
  assert(s.phase == "hunter_shot" and s.roles.you == "hunter", "hunter shot unavailable")
  assert(is_alive(s, target) and target ~= "you", "invalid hunter target")
  add_log(s, "hunter", "你发动猎人技能带走了" .. player_of(s, target).name .. "。", "you", target)
  local continuation = s.after_hunter
  s.after_hunter = nil
  s.death_flow = nil
  begin_death(s, target, "hunter", continuation)
end

function M.resolve_vote(s)
  assert(s.phase == "day_vote" or s.phase == "day_observe_vote", "not vote phase")
  if is_alive(s, "you") then assert(s.votes.you, "player must vote before resolve") end
  local tally = {}
  s.vote_reasons = s.vote_reasons or {}
  for _, person in ipairs(s.roster) do
    if person.alive and person.id ~= "you" then
      local decision = Brain.vote_decision(M.npc_view(s, person.id), M.alive_ids(s))
      local target = s.votes[person.id] or decision.target
      if target ~= person.id and is_alive(s, target) then
        s.votes[person.id] = target
        s.vote_reasons[person.id] = decision.reason
        if decision.changed then Evidence.set_stance(s, person.id, target, decision.reason, 2) end
      end
    end
  end
  for voter, target in pairs(s.votes) do
    local weight = voter == s.sheriff_id and 1.5 or 1
    tally[target] = (tally[target] or 0) + weight
    add_log(s, "ballot", player_of(s, voter).name .. "投给" .. player_of(s, target).name .. "。", voter, target)
    local reason = voter == "you" and "你的最终选择" or s.vote_reasons[voter] or (Evidence.stance(s, voter) and Evidence.stance(s, voter).reason or "依据桌面公开信息")
    Evidence.append(s, "ballot", { actor = voter, target = target, text = player_of(s, voter).name .. "投给" .. player_of(s, target).name .. "。", reason = reason })
  end
  local out, high, tied = nil, -1, false
  for target, count in pairs(tally) do
    if count > high then out, high, tied = target, count, false elseif count == high then tied = true end
  end
  s.last_ballot = { day = s.day, votes = copy_map(s.votes), tally = copy_map(tally), out = out, tied = tied }
  if out and not tied then
    begin_death(s, out, "vote", "vote")
  else add_log(s, "vote", "本轮平票，无人出局。") end
  if check_winner(s) then enter_ending(s) else set_phase(s, "night_begin") end
  return out, tied
end

function M.ballot_receipt(s, lead)
  local ballot = s.last_ballot
  if not ballot then return { lead or "本轮票型尚未产生。" } end
  local lines, row = { lead or "本轮投票结束。" }, {}
  for _, voter in ipairs(s.roster) do
    local target = ballot.votes[voter.id]
    if target then
      local mark = voter.id == s.sheriff_id and "*" or ""
      row[#row + 1] = voter.name .. mark .. "→" .. player_of(s, target).name
      if #row == 3 then lines[#lines + 1] = table.concat(row, "、"); row = {} end
    end
  end
  if #row > 0 then lines[#lines + 1] = table.concat(row, "、") end
  return lines
end

function M.restart(s, deck_id)
  return M.new(deck_id or s.deck_id)
end

return M
