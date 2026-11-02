-- 来杯好卦爻一爻 · 输入分发
local State = require("domain.divination_state")
local View = require("domain.divination_view")

local M = {}
local QWERTY = "qwertyuiopasdfghjklzxcvbnm"
local CATEGORY_KEYS = {
  "academic", "career", "love", "wealth", "lost", "lawsuit", "travel",
  "health", "family", "children", "fortune", "change", "opening", "people",
}

local function imActivate(s, focus)
  if focus == 1 then
    return State.imPrevCandidatePage(s)
  elseif focus >= 2 and focus <= 5 then
    return State.imSelectCandidate(s, focus - 1)
  elseif focus == 6 then
    return State.imNextCandidatePage(s)
  elseif focus >= 7 and focus <= 32 then
    return State.imLetter(s, string.sub(QWERTY, focus - 6, focus - 6))
  elseif focus == 33 then
    return State.imSetMode(s, s.imMode == "cn" and "en" or "cn")
  elseif focus == 34 then
    return State.imBackspace(s)
  elseif focus == 35 then
    return State.imSpace(s)
  elseif focus == 36 then
    return State.finishIm(s)
  elseif focus == 37 then
    State.closeIm(s)
    return true
  elseif focus >= 38 and focus <= 51 then
    return State.setQuestionCategory(s, CATEGORY_KEYS[focus - 37])
  end
  return false
end

function M.start(ctx)
  State.get(ctx)
  ctx:set_tick(0)
end

function M.enter(ctx)
  State.get(ctx)
  ctx:invalidate()
end

-- ---------- 输入法按键 ----------
local function imKey(ctx, s, key)
  if key == "up" then
    -- 输入页与摇卦页使用相同的侧键层级：上返回首页，下进入六十四卦。
    State.closeIm(s)
    s.page = 1
    return true
  elseif key == "down" then
    return State.openHexCatalog(s)
  elseif key == "left" or key == "right" then
    if not s.imInteracted then
      s.imInteracted = true
      s.imFocus = s.questionCategory and 7 or 38
      return true
    end
    if key == "left" then
      if s.imFocus > 1 then s.imFocus = s.imFocus - 1 end
    elseif s.imFocus < 51 then
      s.imFocus = s.imFocus + 1
    end
    return true
  elseif key == "ok" then
    if not s.imInteracted then
      s.imInteracted = true
      s.imFocus = s.questionCategory and 7 or 38
    end
    return imActivate(s, s.imFocus or 7)
  elseif key == "back" then
    State.closeIm(s)
    return true
  end
  return false
end

-- ---------- 输入法触摸 ----------
local function imTouch(ctx, s, ev)
  local hit = View.imHit(ev, View.layout(ctx), s)
  if not hit then return false end
  s.imInteracted = true
  if hit.focus then s.imFocus = hit.focus end
  local focused = hit.focus ~= nil
  if hit.type == "letter" then
    return State.imLetter(s, hit.letter) or focused
  elseif hit.type == "candidate" then
    return State.imSelectCandidate(s, hit.index) or focused
  elseif hit.type == "candidate_prev" then
    return State.imPrevCandidatePage(s) or focused
  elseif hit.type == "candidate_next" then
    return State.imNextCandidatePage(s) or focused
  elseif hit.type == "category" then
    return State.setQuestionCategory(s, hit.category) or focused
  elseif hit.type == "mode" then
    return State.imSetMode(s, hit.mode) or focused
  elseif hit.type == "space" then
    return State.imSpace(s) or focused
  elseif hit.type == "backspace" then
    return State.imBackspace(s) or focused
  elseif hit.type == "done" then
    return State.finishIm(s) or focused
  elseif hit.type == "close" then
    State.closeIm(s)
    return true
  end
  return false
end

-- ---------- 页面按键 ----------
local function pageKey(ctx, s, key)
  if s.page == 1 then
    if key == "ok" then
      State.startCasting(s)
      return true
    end
    return false
  elseif s.page == 2 then
    if key == "ok" then
      if #s.lines >= 6 then State.finishCasting(s)
      else State.castLine(ctx, s) end
      return true
    elseif key == "up" then
      State.resetAll(s)
      return true
    elseif key == "down" then
      State.openHexCatalog(s)
      return true
    elseif key == "back" then
      State.resetAll(s)
      return true
    end
    return false
  elseif s.page == 3 then
    if key == "ok" then
      State.reroll(s)
      return true
    elseif key == "up" then
      if s.resultSub == 1 then return State.prevAnalysis(s)
      elseif s.resultSub == 4 then State.scrollDetail(s, -5)
      else State.prevSub(s) end
      return true
    elseif key == "down" then
      if s.resultSub == 1 then return State.nextAnalysis(s)
      elseif s.resultSub == 4 then State.scrollDetail(s, 5)
      else State.nextSub(s) end
      return true
    elseif key == "left" then
      State.prevSub(s)
      return true
    elseif key == "right" then
      State.nextSub(s)
      return true
    elseif key == "back" then
      State.resetAll(s)
      return true
    end
  elseif s.page == 4 then
    if key == "up" then
      if (s.catalogPage or 1) > 1 then return State.prevHexCatalogPage(s) end
      return State.closeHexCatalog(s)
    elseif key == "down" then
      return State.nextHexCatalogPage(s)
    elseif key == "back" then
      return State.closeHexCatalog(s)
    end
  elseif s.page == 5 then
    if key == "up" then
      return State.prevKnowledgePage(s)
    elseif key == "down" then
      return State.nextKnowledgePage(s)
    elseif key == "left" or key == "back" then
      return State.closeHexKnowledge(s)
    end
  end
  return false
end

-- ---------- 页面触摸 ----------
local function pageTouch(ctx, s, ev)
  if s.page == 1 then
    if View.questionHit(ev, View.layout(ctx)) then
      State.openIm(s)
      return true
    end
    if View.startButtonHit(ev, View.layout(ctx)) then
      State.startCasting(s)
      return true
    end
    return false
  elseif s.page == 2 then
    if ev.gesture == "tap" and View.coinAreaHit(ev, View.layout(ctx)) then
      if #s.lines >= 6 then State.finishCasting(s)
      else State.castLine(ctx, s) end
      return true
    end
    return false
  elseif s.page == 3 then
    if View.rerollHit(ev, View.layout(ctx)) then
      State.reroll(s)
      return true
    end
    if ev.gesture == "swipe_up" then
      if s.resultSub == 1 then return State.nextAnalysis(s)
      elseif s.resultSub == 4 then State.scrollDetail(s, 5)
      else State.nextSub(s) end
      return true
    elseif ev.gesture == "swipe_down" then
      if s.resultSub == 1 then return State.prevAnalysis(s)
      elseif s.resultSub == 4 then State.scrollDetail(s, -5)
      else State.prevSub(s) end
      return true
    elseif ev.gesture == "swipe_left" then
      State.nextSub(s)
      return true
    elseif ev.gesture == "swipe_right" then
      State.prevSub(s)
      return true
    end
    return false
  elseif s.page == 4 then
    if ev.gesture == "tap" then
      if View.catalogBackHit(ev, View.layout(ctx)) then return State.closeHexCatalog(s) end
      local name = View.hexCatalogHit(ev, View.layout(ctx), s)
      if name then return State.openHexKnowledge(s, name) end
    elseif ev.gesture == "swipe_left" then
      return State.nextHexCatalogPage(s)
    elseif ev.gesture == "swipe_right" then
      return State.prevHexCatalogPage(s)
    end
    return false
  elseif s.page == 5 then
    if ev.gesture == "tap" and View.knowledgeBackHit(ev, View.layout(ctx)) then
      return State.closeHexKnowledge(s)
    elseif ev.gesture == "swipe_up" then
      return State.nextKnowledgePage(s)
    elseif ev.gesture == "swipe_down" then
      return State.prevKnowledgePage(s)
    end
    return false
  end
  return false
end

function M.input(ctx, ev)
  local s = State.get(ctx)
  local changed = false
  if ev.type == "key" and ev.phase == "down" then
    if s.imOpen then
      changed = imKey(ctx, s, ev.key)
    else
      changed = pageKey(ctx, s, ev.key)
    end
  elseif (ev.type == "pointer" and ev.phase == "up") then
    if s.imOpen then
      changed = imTouch(ctx, s, ev)
    else
      changed = pageTouch(ctx, s, ev)
    end
  end
  if changed then ctx:invalidate() end
  return changed
end

function M.draw(ctx, g)
  View.draw(ctx, g, State.get(ctx))
end

return M
