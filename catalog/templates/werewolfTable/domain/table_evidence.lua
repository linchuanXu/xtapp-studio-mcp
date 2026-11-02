-- Public table memory for the solo werewolf game.
--
-- This module intentionally stores only facts every player at the table may
-- know.  Secret roles, night targets and private checks remain in the rules
-- state and must never be copied here.  NPCs use this ledger to keep a
-- visible position across speech, questioning and voting.

local M = {}

local function copy_map(src)
  local out = {}
  for key, value in pairs(src or {}) do out[key] = value end
  return out
end

local function copy_event(event)
  return {
    day = event.day, kind = event.kind, actor = event.actor, target = event.target,
    text = event.text, reason = event.reason, confidence = event.confidence, position = event.position,
  }
end

function M.ensure(s)
  s.evidence = s.evidence or { events = {}, stances = {} }
  s.evidence.events = s.evidence.events or {}
  s.evidence.stances = s.evidence.stances or {}
  return s.evidence
end

function M.append(s, kind, fields)
  local ledger = M.ensure(s)
  local event = {
    day = s.day, kind = kind, actor = fields and fields.actor,
    target = fields and fields.target, text = fields and fields.text,
    reason = fields and fields.reason, confidence = fields and fields.confidence,
  }
  ledger.events[#ledger.events + 1] = event
  if #ledger.events > 96 then table.remove(ledger.events, 1) end
  return event
end

function M.set_stance(s, actor, target, reason, confidence, position)
  local ledger = M.ensure(s)
  local previous = ledger.stances[actor]
  local changed = previous and previous.target ~= target
  local stance = {
    actor = actor, target = target, reason = reason or "暂未说明",
    confidence = confidence or 1, position = position or "suspect", day = s.day,
  }
  ledger.stances[actor] = stance
  M.append(s, changed and "stance_change" or "stance", stance)
  return stance, changed
end

function M.stance(s, actor)
  local ledger = M.ensure(s)
  return ledger.stances[actor] and copy_map(ledger.stances[actor]) or nil
end

function M.public(s)
  local ledger = M.ensure(s)
  local events, stances = {}, {}
  for index, event in ipairs(ledger.events) do events[index] = copy_event(event) end
  for id, stance in pairs(ledger.stances) do stances[id] = copy_map(stance) end
  return { events = events, stances = stances }
end

return M
