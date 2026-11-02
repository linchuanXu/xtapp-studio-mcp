local PkgImage = require("pkg_image")
-- 一叩 / X4 Classic + Pro
-- OK 或点按木鱼敲击；不依赖声音、震动等未在 XTApp API 2.x 契约中确认的能力。
local TARGETS = { 27, 54, 108, 216 }
-- 墨水屏对瞬时动画不友好：预备帧 260ms，落点帧 1000ms，留出明确的触底画面。
local STRIKE_DURATION_MS = 1360
local RAISE_END_MS = 1100
local HIT_END_MS = 100
local ACHIEVEMENT_NOTICE_MS = 2200
local MALLET_LEFT_SHIFT = 36
local PHRASES = {
  "先不求答案，先把这一叩敲好。", "呼吸比念头更早抵达。", "不赶路，也不催自己。",
  "一声清响，万事放轻。", "把杂念放在木鱼之外。", "慢一点，听见这一刻。",
  "手起手落，心也有了归处。", "今天不必完成所有事。", "此刻已经足够安静。",
  "心里的风，正在小一点。", "愿所念之人，今夜安眠。", "把肩膀轻轻放下来。",
  "不和念头争，只看它路过。", "你回来就好。", "这一叩，送给当下。",
  "先听见自己，再听见世界。", "不必用力，仍然可以前进。", "让心慢半拍。",
  "每一次落下，都是一次归来。", "留一点空白给自己。", "不求圆满，只求安稳。",
  "念头很多，呼吸只有一件事。", "今天也值得被温柔对待。", "让声音停在心里。",
  "不急着变好，先安静一会儿。", "这一刻，没有需要追赶的事。", "把复杂留在门外。",
  "心有来处，也有归处。", "风会过去，叩声留下。", "安住不是停下，是不慌。",
  "不用证明什么，继续这一叩。", "给自己一个慢下来的理由。", "愿你此刻，略有轻安。",
  "敲到这里，已经很好。", "把今天分成小小的一叩。", "静一点，清一点，松一点。",
  "万事未定，心可以先定。", "这一声，不为催促，只为照见。", "愿心中有一盏不灭的灯。",
}
local ACHIEVEMENTS = {
  { id = "first", label = "初心入定", desc = "从这一叩开始，练习回到当下。", rule = function(s) return s.total >= 1 end },
  { id = "nine", label = "九点微墨", desc = "九次回响，留下一粒墨点。", rule = function(s) return s.total >= 9 end },
  { id = "ten", label = "十念轻放", desc = "十个念头，慢慢放下。", rule = function(s) return s.total >= 10 end },
  { id = "twentyseven", label = "晨钟微响", desc = "二十七叩，心里的风小了一些。", rule = function(s) return s.total >= 27 end },
  { id = "session_nine", label = "一息九叩", desc = "在同一段安静里，完成九次归来。", rule = function(s) return s.session_best >= 9 end },
  { id = "fiftyfour", label = "半日清宁", desc = "五十四叩，不必用力也能前行。", rule = function(s) return s.total >= 54 end },
  { id = "round_one", label = "一轮圆满", desc = "完成一次为自己设下的日课。", rule = function(s) return s.rounds_completed >= 1 end },
  { id = "hundredeight", label = "百念归一", desc = "一百零八叩，缓缓放下。", rule = function(s) return s.total >= 108 end },
  { id = "return", label = "回心见月", desc = "重新开始时，也仍愿意回来。", rule = function(s) return s.resets >= 1 and s.session >= 1 end },
  { id = "three_rounds", label = "三轮安住", desc = "安静完成三次自己的练习。", rule = function(s) return s.rounds_completed >= 3 end },
  { id = "beyond", label = "余韵未尽", desc = "目标已圆满，仍为自己多留一叩。", rule = function(s) return s.session > TARGETS[s.target_index] end },
  { id = "threehundred", label = "松风入怀", desc = "三百声后，愿你依然从容。", rule = function(s) return s.total >= 300 end },
  { id = "nine_rounds", label = "九印成章", desc = "九次圆满，墨印终于完整。", rule = function(s) return s.rounds_completed >= 9 end },
  { id = "thousand", label = "千声如一", desc = "一千次归来，仍听得见自己。", rule = function(s) return s.total >= 1000 end },
  { id = "ten_thousand", label = "万象无声", desc = "敲过万声，仍留得住心中留白。", rule = function(s) return s.total >= 10000 end },
}

local function state(ctx)
  if not ctx.state.quiet_fish then
    ctx.state.quiet_fish = {
      total = 0, session = 0, target_index = 3, phrase_index = 1, strike_ms = 0,
      note = "准备好了，轻叩木鱼", ink_pattern = 1, ink_dots = 0,
      session_best = 0, rounds_completed = 0, resets = 0, unlocked = {},
      achievement_note = "", achievement_ms = 0, last_achievement = "",
    }
  end
  local s = ctx.state.quiet_fish
  -- 兼容已安装的旧版存档。
  s.ink_pattern = s.ink_pattern or 1; s.ink_dots = s.ink_dots or 0
  s.session_best = s.session_best or 0; s.rounds_completed = s.rounds_completed or 0
  s.resets = s.resets or 0; s.unlocked = s.unlocked or {}
  s.achievement_note = s.achievement_note or ""; s.achievement_ms = s.achievement_ms or 0
  s.last_achievement = s.last_achievement or ""
  return s
end

local function target(s) return TARGETS[s.target_index] end
local function wrap(value, size) return ((value - 1) % size) + 1 end
local function achievement_count(s)
  local count = 0
  for _ in pairs(s.unlocked) do count = count + 1 end
  return count
end

local function check_achievements(s)
  for _, achievement in ipairs(ACHIEVEMENTS) do
    if not s.unlocked[achievement.id] and achievement.rule(s) then
      s.unlocked[achievement.id] = true
      s.last_achievement = achievement.label
      s.achievement_note = "得印「" .. achievement.label .. "」"
      s.achievement_ms = ACHIEVEMENT_NOTICE_MS
      return achievement
    end
  end
  return nil
end

local function phrase_for_strike(s)
  -- 每次推进 14 格；与当前 39 条文案互质，一轮内不会机械重复。
  s.phrase_index = ((s.total * 7 + s.session * 7 + s.target_index * 5 + s.resets) % #PHRASES) + 1
  if s.session == target(s) then return "今日一轮圆满，愿心安住。" end
  if s.session % 27 == 0 then return string.format("第 %d 叩，一段小圆满。", s.session) end
  if s.session > target(s) then return "今日已圆满，余下每一叩都只为自己。" end
  return PHRASES[s.phrase_index]
end

local function strike(s)
  s.total = s.total + 1
  s.session = s.session + 1
  s.session_best = math.max(s.session_best, s.session)
  s.ink_pattern = wrap(s.ink_pattern + 1, 6)
  s.ink_dots = s.total % 9
  s.strike_ms = STRIKE_DURATION_MS
  if s.session == target(s) then s.rounds_completed = s.rounds_completed + 1 end
  s.note = phrase_for_strike(s)
  local achievement = check_achievements(s)
  if achievement then s.note = achievement.desc end
end

local function layout(ctx)
  local w, h = ctx.screen.width, ctx.screen.height
  local landscape = w > h
  local fish_w = math.floor(w * (landscape and 0.38 or 0.82))
  local fish_h = math.floor(fish_w * 0.625)
  local fish_x = math.floor((w - fish_w) / 2)
  local fish_y = math.floor(h * (landscape and 0.27 or 0.31))
  local progress_y = fish_y + fish_h + math.floor(h * 0.105)
  local status_y = progress_y + math.floor(h * (landscape and 0.065 or 0.07))
  return {
    w = w, h = h, landscape = landscape, margin = math.max(20, math.floor(w * 0.055)),
    fish_x = fish_x, fish_y = fish_y, fish_w = fish_w, fish_h = fish_h,
    daily_y = fish_y + fish_h + math.floor(h * 0.055), progress_y = progress_y, status_y = status_y,
  }
end

function on_load(ctx)
  local s = state(ctx)
  if s.strike_ms > 0 or s.achievement_ms > 0 then
    ctx:set_tick(100)
  else
    ctx:set_tick(0)
  end
  ctx:invalidate()
end

function on_tick(ctx, dt_ms)
  local s = state(ctx)
  local changed = false
  if s.strike_ms > 0 then s.strike_ms = math.max(0, s.strike_ms - dt_ms); changed = true end
  if s.achievement_ms > 0 then s.achievement_ms = math.max(0, s.achievement_ms - dt_ms); changed = true end
  if changed then ctx:invalidate() end
  if s.strike_ms == 0 and s.achievement_ms == 0 then ctx:set_tick(0) end
end

function on_input(ctx, ev)
  local s = state(ctx)
  local l = layout(ctx)
  if (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture ~= "tap" and ev.gesture ~= "long" then return false end
    local within_fish = ev.x >= l.fish_x - 30 and ev.x <= l.fish_x + l.fish_w + 30 and ev.y >= l.fish_y - 50 and ev.y <= l.fish_y + l.fish_h + 50
    if within_fish then strike(s); ctx:set_tick(100)
    elseif ev.y >= l.h * 0.78 then s.target_index = ev.x < l.w / 2 and wrap(s.target_index - 1, #TARGETS) or wrap(s.target_index + 1, #TARGETS); s.note = "今日目标已切换"
    else return false end
    ctx:invalidate(); return true
  end
  if ev.type ~= "key" or ev.phase ~= "down" then return false end
  if ev.key == "ok" then strike(s); ctx:set_tick(100)
  elseif ev.key == "up" then s.target_index = wrap(s.target_index + 1, #TARGETS); s.note = "今日目标已切换"
  elseif ev.key == "down" then s.target_index = wrap(s.target_index - 1, #TARGETS); s.note = "今日目标已切换"
  elseif ev.key == "left" then s.phrase_index = wrap(s.phrase_index - 1, #PHRASES); s.note = PHRASES[s.phrase_index]
  elseif ev.key == "right" then s.phrase_index = wrap(s.phrase_index + 1, #PHRASES); s.note = PHRASES[s.phrase_index]
  elseif ev.key == "back" then s.session = 0; s.resets = s.resets + 1; s.note = "本次进度已归零，累计与墨印仍在"
  else return false end
  ctx:invalidate(); return true
end

function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s = state(ctx)
  local l = layout(ctx)
  local m = l.margin
  g:clear(0)
  g:text(m, math.floor(l.h * 0.055), "一叩", { color = 15 })
  g:text(m, math.floor(l.h * 0.095), "电子木鱼  /  QUIET FISH", { color = 15 })
  g:text(math.max(m, l.w - 154), math.floor(l.h * 0.065), "累计功德", { color = 15 })
  g:text(math.max(m, l.w - 154), math.floor(l.h * 0.108), tostring(s.total), { color = 15 })
  g:line(m, math.floor(l.h * 0.14), l.w - m, math.floor(l.h * 0.14),{color=15})

  PkgImage.draw(g, "woodfish_hero", l.fish_x, l.fish_y, { w = l.fish_w, h = l.fish_h })
  -- 木鱼槌保持在主体上方的留白区，避免白底透明时与木鱼线稿混在一起。
  local mallet_key, mallet_x, mallet_y = "mallet_rest", l.fish_x + l.fish_w - 92 - MALLET_LEFT_SHIFT, l.fish_y - 106
  if s.strike_ms > RAISE_END_MS then
    mallet_key, mallet_x, mallet_y = "mallet_raise", l.fish_x + l.fish_w - 148 - MALLET_LEFT_SHIFT, l.fish_y - 140
  elseif s.strike_ms > HIT_END_MS then
    mallet_key, mallet_x, mallet_y = "mallet_hit", l.fish_x + l.fish_w - 144 - MALLET_LEFT_SHIFT, l.fish_y - 70
    -- XIC 的白色留白不会覆盖木鱼底图；先铺白色槌头遮罩，保证内部不透底。
    g:circle(mallet_x + 34, mallet_y + 89, 30,{fill=true,color=0})
  end
  PkgImage.draw(g, mallet_key, mallet_x, mallet_y, { w = 112, h = 156 })
  -- 敲击反馈只由木槌位置承担，避免在木鱼主图上叠加任何纹路。
  g:text(m, l.daily_y, string.format("今日  %d / %d", s.session, target(s)), { color = 15 })
  g:rect(m, l.progress_y, l.w - m * 2, 12,{color=15})
  local progress = math.min(1, s.session / target(s))
  if progress > 0 then g:rect(m + 2, l.progress_y + 2, math.floor((l.w - m * 2 - 4) * progress), 8,{fill=true,color=15}) end
  local status_line = math.floor(l.h * (l.landscape and 0.05 or 0.05))
  g:text(m, l.status_y, string.format("此刻  ·  墨印 %d / %d", achievement_count(s), #ACHIEVEMENTS), { color = 15 })
  g:text(m, l.status_y + status_line, s.note, { color = 15 })
  local detail = s.last_achievement ~= "" and ("已得印：" .. s.last_achievement .. "   最长一轮：" .. s.session_best .. " 叩") or ("墨点会在每九叩聚成一印")
  g:text(m, l.status_y + status_line * 2, detail, { color = 15 })
  if s.achievement_ms > 0 then
    local badge_w = math.min(l.w - m * 2, 238)
    local badge_x = math.floor((l.w - badge_w) / 2)
    local badge_y = l.fish_y + math.floor(l.fish_h * 0.30)
    g:rect(badge_x, badge_y, badge_w, 44,{fill=true,color=15})
    g:rect(badge_x, badge_y, badge_w, 44,{color=0})
    g:text(badge_x + 18, badge_y + 13, s.achievement_note, { color = 0 })
  end
  if s.session <= 10 then
    g:text(m, l.h - math.floor(l.h * 0.045), "OK / 点木鱼敲击   ↑↓ 目标   ←→ 短句   BACK 清本次", { color = 15 })
  end
end
