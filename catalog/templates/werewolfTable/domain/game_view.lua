local PkgImage = require("pkg_image")
local Layout = require("domain.game_layout")

local M = {}

local function opaque(g, x, y, w, h) g:rect(x, y, w, h,{fill=true,color=0}) end

local function name_of(s, id)
  for _, person in ipairs(s.roster) do if person.id == id then return person.name end end
  return "未知"
end

-- One visual contract for the whole table: every actionable state owns the
-- right-side stage. People get a portrait; system-only actions get a stable,
-- replaceable event placeholder rather than leaving the stage blank.
local function presenter_id(s)
  if s.phase == "sheriff_speech" or s.phase == "day_speech" or s.phase == "day_rebuttal" or s.phase == "day_final_speech" then return s.current_speaker end
  if s.phase == "day_player_speech" or s.phase == "day_fake_claim_target" or s.phase == "day_fake_claim_result" or s.phase == "badge_transfer" then return "you" end
  if (s.phase == "death_last_words" or s.phase == "hunter_npc_shot" or s.phase == "badge_npc_transfer") and s.death_flow then return s.death_flow.id end
  return nil
end

local function draw_roster(g, s)
  for index, person in ipairs(s.roster) do
    local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
    local x, y = 16 + col * 152, 94 + row * 52
    opaque(g, x, y, 136, 42)
    g:rect(x, y, 136, 42,{color=15})
    local speaking = presenter_id(s) == person.id
    local suffix = speaking and "发言中" or (person.alive and "存活" or "出局")
    if person.sheriff then suffix = "警长" end
    PkgImage.draw(g, "char_" .. person.id, x + 96, y + 3, { w = 36, h = 36 })
    g:text(x + 8, y + 8, tostring(person.seat) .. " " .. person.name, { color = 15 })
    g:text(x + 8, y + 25, suffix, { color = 15 })
  end
end

local function draw_event_placeholder(g, title)
  opaque(g, 278, 74, 190, 308)
  g:rect(278, 74, 190, 308,{color=15})
  PkgImage.draw(g, "event_card", 285, 98, { w = 176, h = 264 })
  opaque(g, 294, 78, 158, 24)
  g:text(318, 82, "桌面事件", { color = 15 })
  opaque(g, 286, 330, 174, 44)
  g:text(300, 336, title or "状态确认", { color = 15 })
  g:text(318, 358, "点击继续", { color = 15 })
end

local function draw_presenter(g, s, description)
  local id = presenter_id(s)
  if not id then draw_event_placeholder(g, description and description.title); return end
  local person
  for _, candidate in ipairs(s.roster) do if candidate.id == id then person = candidate; break end end
  if not person then return end
  -- The solid white card is deliberate: XIC has no alpha plane and white
  -- pixels must never expose the table image behind a character's face.
  opaque(g, 278, 74, 190, 308)
  g:rect(278, 74, 190, 308,{color=15})
  PkgImage.draw(g, "char_" .. id .. "_stage", 285, 98, { w = 176, h = 264 })
  opaque(g, 294, 78, 158, 24)
  g:text(306, 82, person.name .. " · 正在发言", { color = 15 })
end

local function draw_dialog(g, b, description)
  opaque(g, b.dialog_x, b.dialog_y, b.dialog_w, 188)
  -- ui_dialog is shipped as a 448×188 XIC. Keep its native width inside the
  -- 456px stage gutter so browser preview and the target renderer agree.
  local chrome_w = math.min(b.dialog_w, Layout.dialog_chrome_w)
  local chrome_x = b.dialog_x + math.floor((b.dialog_w - chrome_w) / 2)
  PkgImage.draw(g, "ui_dialog", chrome_x, b.dialog_y, { w = chrome_w, h = 188 })
  if description.speaker then
    opaque(g, b.dialog_x + 28, b.dialog_y - 22, 148, 34)
    PkgImage.draw(g, "ui_nameplate", b.dialog_x + 28, b.dialog_y - 22, { w = 148, h = 34 })
    g:text(b.dialog_x + 42, b.dialog_y - 15, description.speaker, { color = 15 })
    g:text(b.dialog_x + 188, b.dialog_y + 16, description.title, { color = 15 })
  else
    g:text(b.dialog_x + 42, b.dialog_y + 16, description.title, { color = 15 })
  end
  for index, line in ipairs(description.lines or {}) do
    if index <= 4 then g:text(b.dialog_x + 42, b.dialog_y + 52 + (index - 1) * 30, line, { color = 15 }) end
  end
end

local function draw_choices(g, b, options)
  for index, option in ipairs(options) do
    local y = b.choice_y + (index - 1) * 62
    opaque(g, b.choice_x, y, b.choice_w, 52)
    PkgImage.draw(g, "ui_choice", b.choice_x, y, { w = b.choice_w, h = 52 })
    g:text(b.choice_x + 44, y + 16, option.text, { color = 15 })
  end
end

local function draw_log_button(g, b)
  opaque(g, b.menu_x, b.menu_y, b.menu_w, b.menu_h)
  g:rect(b.menu_x, b.menu_y, b.menu_w, b.menu_h,{color=15})
  g:rect(b.menu_x + 15, b.menu_y + 13, 22, 2,{fill=true,color=15})
  g:rect(b.menu_x + 15, b.menu_y + 24, 22, 2,{fill=true,color=15})
  g:rect(b.menu_x + 15, b.menu_y + 35, 14, 2,{fill=true,color=15})
end

local function draw_log_overlay(g, b, runtime, s)
  local page = runtime.log_page(s)
  opaque(g, 12, 58, b.w - 24, b.h - 76)
  g:rect(12, 58, b.w - 24, b.h - 76,{color=15})
  g:text(32, 78, "证词簿 · 第" .. tostring(page.page) .. "/" .. tostring(page.pages) .. "页", { color = 15 })
  g:text(282, 78, "点空白处返回", { color = 15 })
  g:rect(32, 104, b.w - 64, 2,{fill=true,color=15})
  local y = 124
  for _, entry in ipairs(page.entries) do
    local day = entry.day > 0 and "第" .. tostring(entry.day) .. "天" or "开局"
    g:text(32, y, day .. " · " .. entry.text, { color = 15 })
    y = y + 54
  end
  opaque(g, 28, b.h - 82, 200, 52)
  g:rect(28, b.h - 82, 200, 52,{color=15})
  g:text(82, b.h - 66, page.page < page.pages and "查看较早记录" or "没有更早记录", { color = 15 })
  opaque(g, 252, b.h - 82, 200, 52)
  g:rect(252, b.h - 82, 200, 52,{color=15})
  g:text(306, b.h - 66, page.page > 1 and "查看较新记录" or "当前最新记录", { color = 15 })
end

local function draw_menu_overlay(g)
  opaque(g, 72, 132, 336, 316)
  g:rect(72, 132, 336, 316,{color=15})
  g:text(96, 150, "游戏菜单", { color = 15 })
  local items = { "证词簿", "桌面情报", "重新开始本局", "回到牌局选择" }
  for index, label in ipairs(items) do
    local y = 176 + (index - 1) * 64
    g:rect(88, y, 304, 52,{color=15})
    g:text(116, y + 16, label, { color = 15 })
  end
end

local function draw_board_overlay(g, b, s)
  opaque(g, 12, 58, b.w - 24, b.h - 76)
  g:rect(12, 58, b.w - 24, b.h - 76,{color=15})
  g:text(32, 78, "桌面情报 · 第" .. tostring(s.day) .. "天", { color = 15 })
  g:text(282, 78, "只显示公开事实", { color = 15 })
  g:rect(32, 104, b.w - 64, 2,{fill=true,color=15})
  local alive, revealed, claims, stances = {}, {}, {}, {}
  for _, person in ipairs(s.roster) do
    if person.alive then alive[#alive + 1] = person.name .. (person.sheriff and "(警长)" or "") end
    if person.revealed then revealed[#revealed + 1] = person.name .. "·" .. require("domain.roles").name(s.roles[person.id]) end
  end
  for id, claim in pairs(s.public_claims or {}) do
    if claim.kind == "seer" then claims[#claims + 1] = name_of(s, id) .. "报" .. name_of(s, claim.target) .. "为" .. (claim.result == "wolf" and "狼人" or "好人")
    elseif claim.kind == "role" then claims[#claims + 1] = name_of(s, id) .. "公开" .. require("domain.roles").name(claim.role) end
  end
  for id, stance in pairs((s.evidence and s.evidence.stances) or {}) do
    if stance.target then
      local mark = stance.position == "protect" and "保" or "疑"
      stances[#stances + 1] = name_of(s, id) .. mark .. name_of(s, stance.target)
    end
  end
  table.sort(alive); table.sort(revealed); table.sort(claims); table.sort(stances)
  local function compact(items, limit)
    local shown = {}
    for index = 1, math.min(#items, limit) do shown[#shown + 1] = items[index] end
    if #items > limit then shown[#shown + 1] = "等" end
    return #shown > 0 and table.concat(shown, "；") or "暂无"
  end
  local last_answer
  for index = #((s.evidence and s.evidence.events) or {}), 1, -1 do
    local event = s.evidence.events[index]
    if event.kind == "answer" then last_answer = name_of(s, event.actor) .. "已回应追问"; break end
  end
  local last_stance
  for index = #((s.evidence and s.evidence.events) or {}), 1, -1 do
    local event = s.evidence.events[index]
    if event.kind == "stance" or event.kind == "stance_change" then
      last_stance = name_of(s, event.actor) .. "：" .. (event.reason or "未说明理由")
      break
    end
  end
  g:text(32, 126, "存活：" .. tostring(#alive) .. " 人 · 警长：" .. (s.sheriff_id and name_of(s, s.sheriff_id) or "无"), { color = 15 })
  g:text(32, 168, "已翻：" .. compact(revealed, 2), { color = 15 })
  g:text(32, 210, "公开声明：" .. compact(claims, 2), { color = 15 })
  g:text(32, 252, "当前站边：" .. compact(stances, 2), { color = 15 })
  g:text(32, 294, "今日追问：" .. tostring(s.question_count or 0) .. "/2" .. (last_answer and " · " .. last_answer or ""), { color = 15 })
  if s.last_question then g:text(32, 336, "最近追问：" .. name_of(s, s.last_question.target) .. " · " .. s.last_question.text, { color = 15 }) end
  if last_stance then g:text(32, 378, "最近立场理由：" .. last_stance, { color = 15 }) end
  g:text(32, 420, "未翻牌身份始终未知；完整过程见证词簿。", { color = 15 })
  g:text(32, 412, "点空白处返回", { color = 15 })
end

local function draw_ending(g, b, s, runtime)
  g:clear(0)
  opaque(g, 40, 56, 400, 200)
  PkgImage.draw(g, "bg_result", 40, 56, { w = 400, h = 200 })
  local title = s.winner == "village" and "好人阵营胜利" or "狼人阵营胜利"
  g:text(64, 272, title .. " · 第" .. tostring(s.day) .. "天", { color = 15 })
  local report = s.ending_report or { lines = { "结算资料准备中。" } }
  for index, line in ipairs(report.lines or {}) do
    if index <= 4 then g:text(64, 294 + (index - 1) * 22, line, { color = 15 }) end
  end
  g:rect(64, 342, 352, 2,{fill=true,color=15})
  for index, person in ipairs(s.roster) do
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
    g:text(64 + col * 180, 358 + row * 22, tostring(person.seat) .. " " .. person.name .. " · " .. require("domain.roles").name(s.roles[person.id]), { color = 15 })
  end
  local options = runtime.options(s)
  draw_choices(g, b, options)
  draw_log_button(g, b)
  if s.overlay == "log" then draw_log_overlay(g, b, runtime, s) end
  if s.overlay == "board" then draw_board_overlay(g, b, s) end
  if s.overlay == "menu" then draw_menu_overlay(g) end
end

function M.draw(ctx, g, runtime)
  local s = runtime.state(ctx)
  local options = runtime.options(s)
  local b = Layout.compute(ctx, #options, s.phase == "ending")
  if s.phase == "ending" then
    draw_ending(g, b, s, runtime)
    return
  end
  local night = s.phase == "night_begin" or string.find(s.phase, "night_") ~= nil
  g:clear(0)
  PkgImage.draw(g, night and "bg_table_night" or "bg_table_day", 0, 0, { w = 480, h = b.dialog_y })
  opaque(g, 12, 12, 210, 30)
  g:rect(12, 12, 210, 30,{color=15})
  g:text(24, 18, "月下狼局 · " .. s.deck.name, { color = 15 })
  draw_log_button(g, b)
  draw_roster(g, s)
  local description = runtime.description(s)
  draw_presenter(g, s, description)
  draw_choices(g, b, options)
  draw_dialog(g, b, description)
  if s.overlay == "log" then draw_log_overlay(g, b, runtime, s) end
  if s.overlay == "board" then draw_board_overlay(g, b, s) end
  if s.overlay == "menu" then draw_menu_overlay(g) end
end

return M
