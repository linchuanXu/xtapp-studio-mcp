local PkgImage = require("pkg_image")
-- 斗地主
-- 单机：1 真人 + 2 AI（或纯观战）。触屏为主，方向键 + OK/Back 可操作。

local Rules = require("domain.doudizhu_rules")
local AI = require("domain.doudizhu_ai")
local Economy = require("domain.doudizhu_economy")
local Watchdog = require("lib.watchdog_slice")

local DESIGN_WIDTH, DESIGN_HEIGHT = 800, 480 -- 横屏
local CARD_W, CARD_H = 72, 100               -- 与素材尺寸一致（g:image 不缩放）
local CARD_BACK = "card_back"
local TABLE_BG = "table_bg"
local PLAYER_LEFT = "player_left"
local PLAYER_RIGHT = "player_right"
local PLAYER_HERO = "player_hero"
local PLAYER_HERO_TABLE = "hero_l"
-- 每局从现有与新增人物中选择两位不同的 AI；人物仅影响视觉，不影响牌局规则。
local AI_PORTRAITS = { PLAYER_LEFT, PLAYER_RIGHT, "ai_rival_woman", "ai_rival_man" }
local MENU_START_X, MENU_START_Y, MENU_START_W, MENU_START_H = 250, 354, 300, 64
local MENU_FORTUNE_X, MENU_FORTUNE_Y, MENU_FORTUNE_W, MENU_FORTUNE_H = 250, 262, 310, 104
local DIFFICULTY_START_X, DIFFICULTY_START_Y, DIFFICULTY_START_W, DIFFICULTY_START_H = 250, 402, 300, 56
-- 返回封面只保留一个不抢戏的圆形返回图标；可点范围仍足够触屏操作。
local DIFFICULTY_BACK_X, DIFFICULTY_BACK_Y, DIFFICULTY_BACK_W, DIFFICULTY_BACK_H = 18, 18, 44, 44
-- 三档策略均已采用有界候选与即时新手路径；开放集合只决定入口可见性，
-- 开局后的难度仍会固定在本局 game 状态，不能中途切换。
local OPEN_DIFFICULTIES = { novice = true, casual = true, challenge = true }

-- 所有牌桌坐标只从这一张 800×480 的空间地图取得。XIC 不能在运行时缩放，
-- 因此每个区域按素材原始尺寸划定；禁止再把“大标题”塞回旧头像旁的小章坐标。
local LAYOUT = {
  status = {
    bottom = { x = 12, y = 8, width = 156 },
    beans = { x = 350, y = 8, width = 100 },
    multiplier = { x = 654, y = 8, width = 82 },
    settings = { x = 744, y = 8, width = 42, height = 32 },
  },
  seats = {
    left = { portrait_x = 6, portrait_y = 78, fan_x = 2, fan_y = 48, fan_direction = 1 },
    right = { portrait_x = 668, portrait_y = 78, fan_x = 726, fan_y = 48, fan_direction = -1 },
  },
  trick = {
    left = { center_x = 190, y = 112 },
    right = { center_x = 610, y = 112 },
    human = { center_x = 400, y = 188 },
  },
  -- 操作栏底边固定停在上浮手牌（y=350）之上，留出 10px 空隙；
  -- 这样“出牌 / 不要 / 提示”永远不会和任何一张手牌重叠。
  action_bar = { y = 280, width = 156, height = 60, gap = 16 },
  effect = {
    flow_stage = { x = 100, y = 80, width = 600, height = 280 },
    flow_icon = { x = 100, y = 120 },
    flow_title = { x = 300, y = 120 },
    bid_title = { x = 200, y = 70 },
    human_turn_title = { x = 200, y = 164 },
    seat = {
      -- 三家动作章与对应出牌槽共享中心线：有牌动作避开牌面，“不要”占用该出牌槽。
      left = { x = 90, play_y = 214, pass_y = 112 },
      right = { x = 510, play_y = 214, pass_y = 112 },
      human = { x = 300, play_y = 0, pass_y = 188 },
    },
    bid_seat = {
      -- 叫分阶段没有“已出牌”可供对齐，动作章应贴近叫分者而不是复用出牌槽。
      left = { x = 126, y = 96 },
      right = { x = 468, y = 96 },
      human = { x = 300, y = 150 },
    },
  },
}

-- 回退到 ORDER 里第一个开放的档位：用户未选择、或所选档位被关闭时都落到这里。
local function first_open_difficulty()
  for _, profile in ipairs(AI.difficulties()) do
    if OPEN_DIFFICULTIES[profile.id] then return profile.id end
  end
  return "novice"
end

local EFFECT_DURATION = 1100
-- 只有需要围桌玩家辨认的复杂高光牌型延长停留；普通局势仍保持牌局节奏。
local EFFECT_DURATION_BY_KIND = { plane = 3000, straight = 2400, pair_chain = 2400, trio_solo = 1800, trio_pair = 1800, four_two_solo = 2200, four_two_pair = 2200, bid = 850, no_bid = 650, pass = 800, hint = 900, overcome = 900, lead = 900, landlord = 2500, bomb = 2500, rocket = 3000, spring = 2500, anti_spring = 2500, victory = 2600, defeat = 2600 }
local CARD_TYPE_EFFECT = {
  trio_solo = "trio_solo",
  trio_pair = "trio_pair",
  four_two_solo = "four_two_solo",
  -- 两种四带二分别使用独立演出，清楚表达“两单”和“两对”的规则差异。
  four_two_pair = "four_two_pair",
  chain = "straight",
  pair_chain = "pair_chain",
  trio_chain = "plane",
  trio_solo_chain = "plane",
  trio_pair_chain = "plane",
}
-- 普通动作章本身就是可见停留，不应结束后再加一段没有新画面的空等待。
-- AI 仍会给出短暂思考锚点，既显得有对手在决策，也不让一局被无信息停顿拖慢。
local AI_THINK_DURATION = 650
-- 兼容已有状态与输入冻结契约：动作刚落下的同一帧仍保留 notice，下一 tick 即释放。
local TURN_NOTICE_DURATION = 1
local HUMAN_TURN_PROMPT_DURATION = 800
local BUTTON_ASSET = {
  ["开始对局"] = "ui_btn_start", ["出牌"] = "ui_btn_play", ["不要"] = "ui_btn_pass",
  ["提示"] = "ui_btn_hint", ["不叫"] = "ui_btn_bid_0", ["1 分"] = "ui_btn_bid_1",
  ["2 分"] = "ui_btn_bid_2", ["3 分"] = "ui_btn_bid_3", ["再来一局"] = "ui_btn_again",
  ["继续游戏"] = "ui_btn_resume", ["重新开始"] = "ui_btn_restart", ["返回封面"] = "ui_btn_home",
  ["规则说明"] = "ui_btn_rules", ["返回菜单"] = "ui_btn_rules_back", ["返回首页"] = "ui_btn_result_home",
}

local function text_units(value)
  -- 真机字体宽度近似：中文全角 12 单位，ASCII 半角 6 单位（用于居中偏移）
  local units, index = 0, 1
  value = tostring(value or "")
  while index <= #value do
    local byte = string.byte(value, index)
    if byte < 128 then
      units = units + 6
      index = index + 1
    else
      units = units + 12
      local len = byte < 224 and 2 or (byte < 240 and 3 or 4)
      index = index + len
    end
  end
  return units
end

local function center(g, x, y, value, color)
  g:text(x - math.floor(text_units(value) / 2), y, value, { color = color or 15 })
end

local function inside(x, y, rx, ry, width, height)
  return x >= rx and x <= rx + width and y >= ry and y <= ry + height
end

-- 牌面素材 key：card_{suit}{rank} / card_joker_black / card_joker_red
local RANK_KEY = { [3] = "3", [4] = "4", [5] = "5", [6] = "6", [7] = "7", [8] = "8", [9] = "9", [10] = "10", [11] = "j", [12] = "q", [13] = "k", [14] = "a", [15] = "2" }
local SUIT_KEY = { "c", "d", "h", "s" }

-- 牌 id → 素材 key
local function card_key(id)
  if id == 53 then return "card_joker_black" end
  if id == 54 then return "card_joker_red" end
  local grade = Rules.grade_of(id)
  local suit = SUIT_KEY[math.floor((id - 1) / 13) + 1]
  return "card_" .. suit .. (RANK_KEY[grade] or "3")
end


local function card_short_label(id)
  if id == 53 then return "小王" end
  if id == 54 then return "大王" end
  return Rules.grade_text(Rules.grade_of(id))
end

local function bottom_cards_label(game)
  local cards = game.bottom_cards or {}
  if #cards == 0 then return "底牌未亮" end
  local labels = {}
  for i, id in ipairs(cards) do labels[i] = card_short_label(id) end
  return "底牌 " .. table.concat(labels, " · ")
end

-- ── 新对局 ──────────────────────────────────────────────────────────────────
-- 设备侧每次发牌都混入墙钟/开机时长；局序号防止同一毫秒内重发。
-- seed 始终限制在 32 位安全整数范围，避免 Lua 数值精度吞掉低位熵。
-- 显式传 seed 时只用于测试和问题复现。
local function next_deal_seed(ctx, saved)
  local t = ctx.clock:now()
  local epoch = t.epoch_sec or t.local_sec
  local uptime = ctx.clock:millis()

  local mod = 2147483647 -- Park–Miller 的素数模数，乘积仍在 Lua 精确整数范围内。
  local epoch_part = (tonumber(epoch) or 0) % mod
  local uptime_part = (tonumber(uptime) or 0) % 1000000
  -- 时钟只负责首次播种。之后严格推进并持久化独立序列：无论同一秒内
  -- 重开、RTC 未校时、还是退出后恢复 state，每一次发牌都得到不同 seed。
  local nonce = tonumber(saved.shuffle_nonce)
  if not nonce or nonce <= 0 or nonce >= mod then
    nonce = (epoch_part * 1009 + uptime_part * 9176 + 104729) % mod
    if nonce == 0 then nonce = 104729 end
  end
  nonce = (math.floor(nonce) * 48271) % mod
  if nonce == 0 then nonce = 1 end
  saved.shuffle_nonce = nonce
  saved.deal_sequence = (saved.deal_sequence or 0) + 1
  return nonce
end

local function fresh_game(ctx, saved, seed)
  local human = saved.human_index or 1
  local game_seed = seed or next_deal_seed(ctx, saved)
  local difficulty = AI.difficulty_profile(saved.difficulty).id
  if not OPEN_DIFFICULTIES[difficulty] then difficulty = first_open_difficulty() end
  saved.difficulty = difficulty
  local game = AI.new_game(game_seed, human, difficulty)
  local first = (game_seed % #AI_PORTRAITS) + 1
  local second = ((math.floor(game_seed / 7) + 1) % #AI_PORTRAITS) + 1
  if second == first then second = (second % #AI_PORTRAITS) + 1 end
  saved.ai_portraits = { AI_PORTRAITS[first], AI_PORTRAITS[second] }
  saved.game = game
  saved.selected = {}
  saved.hint = nil
  saved.screen = "bid"
  saved.seed = game_seed
  saved.effect = nil
  saved.effect_queue = {}
  saved.turn_notice = nil
  saved.human_turn_prompt = nil
  saved.pending_human_turn_prompt = nil
  saved.ai_think = nil
  saved.activity_log = {}
  saved.message = nil
end

local function settle_economy(saved, game)
  local account, settlement = Economy.settle(saved.economy, game, saved.human_index)
  saved.economy = account
  return settlement
end

-- ── 状态访问 ────────────────────────────────────────────────────────────────
local function load_state(ctx)
  local saved = ctx.state.doudizhu
  if not saved then
    saved = {
      screen = "menu",
      game = nil,
      selected = {},
      hint = nil,
      human_index = 1,
      difficulty = "casual",
      message = "开始新一局",
      ai_pending = false,
      effect = nil,
      effect_queue = {},
      turn_notice = nil,
      human_turn_prompt = nil,
      pending_human_turn_prompt = nil,
      ai_think = nil,
      activity_log = {},
      economy = Economy.account(),
    }
    ctx.state.doudizhu = saved
  end
  saved.economy = Economy.account(saved.economy)
  -- 旧版本可能把“轮到你了”与牌型演出同时存档；恢复时始终让演出优先。
  if saved.effect then
    saved.human_turn_prompt = nil
    -- 兼容旧存档：终局特效尚在时必须回到牌桌承载演出，不能与结算页叠绘。
    if saved.game and saved.game.phase == "over" then saved.screen = "play" end
  end
  -- 恢复到已结束旧对局时也补一次结算；模块中的标记保证不会重复。
  if saved.game and saved.game.phase == "over" then settle_economy(saved, saved.game) end
  saved.difficulty = AI.difficulty_profile(saved.difficulty).id
  if not OPEN_DIFFICULTIES[saved.difficulty] then saved.difficulty = first_open_difficulty() end
  if saved.game and not saved.game.difficulty then saved.game.difficulty = saved.difficulty end
  local needs_game = saved.screen == "bid" or saved.screen == "play" or saved.screen == "pause" or saved.screen == "result" or saved.screen == "rules"
  if needs_game and not saved.game then fresh_game(ctx, saved, nil) end
  return saved
end

local function role_label(game, index) return game.landlord and (game.landlord == index and "地主" or "农民") or nil end
local function display_name(saved, index) return index == saved.human_index and "你" or (index == 3 and "阿砚" or "小舟") end
local function ai_indices(saved)
  local out = {}
  for i = 1, 3 do if i ~= saved.human_index then out[#out + 1] = i end end
  return out[1], out[2]
end

-- ── 可见事件队列 ────────────────────────────────────────────────────────────
-- 一局里可能连续出现"王炸 → 春天 → 胜利"。逐个展示，绝不让后一事件吞掉前一事件。
local function queue_effect(saved, kind, actor, multiplier)
  local event = { kind = kind, actor = actor, multiplier = multiplier, remaining = EFFECT_DURATION_BY_KIND[kind] or EFFECT_DURATION }
  if not saved.effect then saved.effect = event
  else
    saved.effect_queue = saved.effect_queue or {}
    saved.effect_queue[#saved.effect_queue + 1] = event
  end
end

local function present_game_event(saved, game, actor, result)
  if not result then return end
  if result.action == "bid" then queue_effect(saved, (result.want or 0) > 0 and "bid" or "no_bid", actor, result.want) end
  if result.action == "pass" then queue_effect(saved, "pass", actor) end
  local last = game.players[actor] and game.players[actor].last_play
  local combo_effect = last and last.type and CARD_TYPE_EFFECT[last.type.t]
  -- 一手压过若已经有炸弹 / 牌型主视觉，就不再串一个泛用“压过”。
  -- 这样一回合只讲一个重点，保留高光语义，又不会让用户等三轮重复演出。
  if result.followed and not result.special and not combo_effect then queue_effect(saved, "overcome", actor) end
  if result.landlord then queue_effect(saved, "landlord", result.landlord, game.multiplier) end
  if result.special then queue_effect(saved, result.special, actor, game.multiplier) end
  if result.action == "play" or result.action == "win" then
    if combo_effect then queue_effect(saved, combo_effect, actor, game.multiplier)
    elseif result.followed == false and not result.special then queue_effect(saved, "lead", actor) end
  end
  if result.action == "win" then
    -- 胜负落定时立即记账；不能等结果页首次绘制，否则退出或重绘会漏结算。
    settle_economy(saved, game)
    if game.spring then queue_effect(saved, "spring", game.winner, game.multiplier)
    elseif game.anti_spring then queue_effect(saved, "anti_spring", game.winner, game.multiplier) end
    queue_effect(saved, game.players[game.winner].is_human and "victory" or "defeat", game.winner, game.multiplier)
  end
  -- 真人提示必须排到所有压过、牌型与倍率演出之后，不能和任何主视觉素材同屏。
  if game.phase == "play" and game.current == saved.human_index and result.action ~= "win" then
    saved.turn_notice = nil
    saved.human_turn_prompt = nil
    saved.pending_human_turn_prompt = true
    if not saved.effect then
      saved.pending_human_turn_prompt = nil
      saved.human_turn_prompt = { remaining = HUMAN_TURN_PROMPT_DURATION }
    end
  end
end

local function type_label(card_type)
  if not card_type then return "" end
  local grade = Rules.grade_text(card_type.grade or 3)
  local labels = {
    single = "单 " .. grade, pair = "对 " .. grade, trio = "三张 " .. grade,
    trio_solo = "三带一", trio_pair = "三带二", chain = "顺子",
    pair_chain = "连对", trio_chain = "飞机", trio_solo_chain = "飞机带单",
    trio_pair_chain = "飞机带对", four_two_solo = "四带二", four_two_pair = "四带两对",
    bomb = grade .. " 炸弹", rocket = "王炸",
  }
  return labels[card_type.t] or "一手牌"
end

local function append_activity(saved, text)
  local log = saved.activity_log or {}
  log[#log + 1] = text
  while #log > 2 do table.remove(log, 1) end
  saved.activity_log = log
end

-- 每一次可见动作都留下简短记录，并冻结下一手 AI；玩家看到什么，就只会发生什么。
local function present_turn(saved, game, actor, result)
  if not result then return end
  saved.message = nil
  local name = display_name(saved, actor)
  if result.action == "bid" then
    local bid = result.bid or result.want
    append_activity(saved, name .. (bid and bid > 0 and (" 叫 " .. bid .. " 分") or " 不叫"))
  elseif result.action == "pass" then
    append_activity(saved, name .. " 不要")
  elseif result.action == "play" or result.action == "win" then
    local last = game.players[actor] and game.players[actor].last_play
    append_activity(saved, name .. " 出 " .. type_label(last and last.type))
  end
  if result.action == "bid" or result.action == "pass" or result.action == "play" or result.action == "win" then
    saved.turn_notice = { remaining = TURN_NOTICE_DURATION }
  end
  present_game_event(saved, game, actor, result)
end

local function advance_effect(saved, dt)
  local effect = saved.effect
  if not effect then return false end
  effect.remaining = effect.remaining - math.max(80, tonumber(dt) or 120)
  if effect.remaining > 0 then return true end
  local queue = saved.effect_queue or {}
  saved.effect = table.remove(queue, 1)
  if not saved.effect and saved.pending_human_turn_prompt then
    saved.pending_human_turn_prompt = nil
    saved.human_turn_prompt = { remaining = HUMAN_TURN_PROMPT_DURATION }
  end
  return saved.effect ~= nil
end

local function advance_turn_notice(saved, dt)
  local notice = saved.turn_notice
  if not notice then return false end
  notice.remaining = notice.remaining - math.max(80, tonumber(dt) or 120)
  if notice.remaining > 0 then return true end
  saved.turn_notice = nil
  return false
end

local function advance_human_turn_prompt(saved, dt)
  local prompt = saved.human_turn_prompt
  if not prompt then return false end
  prompt.remaining = prompt.remaining - math.max(80, tonumber(dt) or 120)
  if prompt.remaining > 0 then return true end
  saved.human_turn_prompt = nil
  return false
end

local function advance_ai_think(saved, dt)
  local think = saved.ai_think
  if not think then return false end
  think.remaining = think.remaining - math.max(80, tonumber(dt) or 120)
  if think.remaining > 0 then return true end
  saved.ai_think = nil
  return false
end

-- 真人最后一手落下后，胜负特效队列仍需在牌桌画面里完整播放。
-- 不能在输入回调里抢先切到结算页，否则“胜利 / 春天”等覆盖层会压住结算内容。
local function finish_human_turn(saved, game)
  if game.phase ~= "over" then
    saved.ai_pending = true
    return
  end
  saved.ai_pending = false
  saved.screen = saved.effect and "play" or "result"
end

-- 没有任何合法压牌时，AI 的选择是确定的“不要”。这类回合无需展示思考停顿，
-- 直接进入座位级“不要”反馈，让对局节奏保持干脆。
local function ai_must_pass(game)
  if not game or game.phase ~= "play" or not game.last_type then return false end
  local player = game.players and game.players[game.current]
  return player and not player.is_human and #Rules.greater_cards(player.cards or {}, game.last_type) == 0
end

-- AI 轮到：推进直到真人轮到或对局结束（tick 内分步，避免长阻塞）
local function run_one_ai_turn(ctx, saved, game)
  if game.phase == "over" or game.phase == "menu" then
    saved.ai_pending = false
    if game.phase == "over" then saved.screen = "result" end
    return false
  end
  local idx = game.current
  local player = game.players[idx]
  if player and player.is_human then
    saved.ai_pending = false
    return false
  end
  -- 固件片长为 11 秒，但应用不能把它当计算预算。AI 每 1 秒续片，
  -- 单次决策最多计算 2 秒；预算到后策略返回当前最佳合法牌。
  local began, begin_err = Watchdog.begin(ctx, { feed_interval_ms = 1000, max_runtime_ms = 2000 })
  if began ~= true then error("watchdog start failed: " .. tostring(begin_err or "disabled"), 0) end
  local ok, result = pcall(AI.ai_act, game, Watchdog.checkpoint)
  Watchdog.finish()
  -- 固件 watchdog/time budget 错误是普通 Lua error，内层 pcall 能捕获；
  -- 必须原样抛回宿主，绝不能吞掉后 feed 再继续。
  if not ok then error(result, 0) end
  if result and result.action == "redeal" then
    fresh_game(ctx, saved, nil)
    saved.screen = "bid"
    saved.message = "本轮全员不叫 · 已重新发牌"
    return true
  end
  present_turn(saved, game, idx, result)
  saved.ai_pending = not (game.phase == "over" or (game.players[game.current] and game.players[game.current].is_human))
  if game.phase == "play" and saved.screen ~= "result" then saved.screen = "play" end
  if game.phase == "over" and not saved.effect then saved.screen = "result" end
  return true
end

-- ── 渲染 ────────────────────────────────────────────────────────────────────
-- g:image 不能缩放（见 luaCanvasRenderer：请求非原尺寸会告警并画原尺寸）。
-- 素材已按 CARD_W×CARD_H 生成，这里直接按原尺寸贴，避免缩放告警/失效。
local function draw_card(g, key, x, y)
  PkgImage.draw(g, key, x, y)
end

local function draw_background(g)
  PkgImage.draw(g, TABLE_BG, 0, 0)
end

local function draw_panel(g, x, y, width, height)
  g:rect(x, y, width, height,{fill=true,color=0})
  g:rect(x, y, width, height,{color=15})
end

-- 辅助页不是临时白框：先用内缩的宣纸阅读区托住文字，再叠透明墨卷边饰。
-- 边饰保留桌游的现场感，内区只承担小屏阅读对比度。
local function draw_ink_modal(g, y)
  g:rect(168, y + 18, 464, 258,{fill=true,color=0})
  g:rect(168, y + 18, 464, 258,{color=15})
  PkgImage.draw(g, "ui_ink_frame", 140, y)
end

local function rounded_button(g, x, y, width, height, primary)
  local radius = math.max(8, math.min(14, math.floor(height / 3)))
  g:rect(x + radius, y, width - radius * 2, height,{fill=true,color=0})
  g:rect(x, y + radius, width, height - radius * 2,{fill=true,color=0})
  g:circle(x + radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + radius, y + height - 1 - radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + height - 1 - radius, radius,{fill=true,color=0})
  -- 黑色外框、文字和图标都由同尺寸 XIC 绘制；这里仅负责让白底不透出牌桌纹理。
end

-- 手牌底板与牌面素材保持同一组小圆角。底板只负责压住重叠牌下方的桌纹，
-- 不再用方形矩形把牌面四角重新封死；牌面自身的圆角边框因此能够露出来。
local function rounded_card_fill(g, x, y, width, height, radius, color)
  local r = math.max(3, math.min(radius or 6, math.floor(math.min(width, height) / 2)))
  g:rect(x + r, y, width - r * 2, height,{fill=true,color=color})
  g:rect(x, y + r, width, height - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + width - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + height - 1 - r, r,{fill=true,color=color})
  g:circle(x + width - 1 - r, y + height - 1 - r, r,{fill=true,color=color})
end

local function rounded_card_stroke(g, x, y, width, height, radius, color)
  local r = math.max(3, math.min(radius or 6, math.floor(math.min(width, height) / 2)))
  g:line(x + r, y, x + width - r, y,{color=color})
  g:line(x + r, y + height, x + width - r, y + height,{color=color})
  g:line(x, y + r, x, y + height - r,{color=color})
  g:line(x + width, y + r, x + width, y + height - r,{color=color})
  g:circle(x + r, y + r, r,{color=color})
  g:circle(x + width - 1 - r, y + r, r,{color=color})
  g:circle(x + r, y + height - 1 - r, r,{color=color})
  g:circle(x + width - 1 - r, y + height - 1 - r, r,{color=color})
end

local function draw_status_chip(g, x, y, width, label, value, value_offset)
  -- 顶部状态不再是一条横幅：只用无边框的小白卡承载必要信息。
  -- 和演出舞台一致，圆角只负责留白，不制造额外的黑色 UI 噪声。
  local height, radius = 32, 12
  g:rect(x + radius, y, width - radius * 2, height,{fill=true,color=0})
  g:rect(x, y + radius, width, height - radius * 2,{fill=true,color=0})
  g:circle(x + radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + radius, y + height - 1 - radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + height - 1 - radius, radius,{fill=true,color=0})
  g:text(x + 12, y + 8, label, { color = 15 })
  g:text(x + (value_offset or 38), y + 8, value, { color = 15 })
end

local function draw_play_status_cards(g, game)
  local labels = {}
  for i, id in ipairs(game.bottom_cards or {}) do labels[i] = card_short_label(id) end
  local bottom, multiplier = LAYOUT.status.bottom, LAYOUT.status.multiplier
  draw_status_chip(g, bottom.x, bottom.y, bottom.width, "底", #labels > 0 and table.concat(labels, " · ") or "未亮")
  draw_status_chip(g, multiplier.x, multiplier.y, multiplier.width, "倍", "×" .. tostring(game.multiplier or 1))
end

local function draw_bean_status(g, saved, x, y, width)
  local balance = tostring(saved.economy and saved.economy.balance or Economy.STARTING_BALANCE)
  -- 对局中的余额保留数字，但在左侧加一枚小古钱；封面的大铜钱布局不复用到这里。
  PkgImage.draw(g, "fx_coin_status_outline", x, y - 2, { color = 0 })
  PkgImage.draw(g, "fx_coin_status", x, y - 2)
  -- 数字从铜币右侧只留 2px，避免状态条默认的 38px 内缩制造大空白。
  draw_status_chip(g, x + 30, y, width - 30, "", balance, 8)
end

local function draw_brush_number(g, value, x, y, width)
  value = tostring(math.abs(math.floor(tonumber(value) or 0)))
  local digit_w, digit_h, gap = 34, 52, 7
  local total = #value * digit_w + (#value - 1) * gap
  local cursor = x + math.floor((width - total) / 2)
  for index = 1, #value do
    PkgImage.draw(g, "brush_digit_" .. value:sub(index, index), cursor, y)
    cursor = cursor + digit_w + gap
  end
end

local function draw_large_balance(g, saved, x, y, width)
  draw_brush_number(g, saved.economy and saved.economy.balance or Economy.STARTING_BALANCE, x, y, width)
end

local function draw_layered_asset(g, key, x, y)
  PkgImage.draw(g, key .. "_outline", x, y, { color = 0 })
  PkgImage.draw(g, key, x, y)
end

local function draw_button(g, x, y, width, height, label, primary)
  rounded_button(g, x, y, width, height, primary)
  local asset = BUTTON_ASSET[label]
  if asset then PkgImage.draw(g, asset, x, y)
  else center(g, x + math.floor(width / 2), y + math.floor(height / 2) - 8, label, 15) end
end

local function draw_persona(g, key, x, y, name, count, role, active, options)
  options = options or {}
  -- 所有人物都由透明轮廓生成贴身白底与细外 halo，不会出现矩形白底。
  PkgImage.draw(g, key .. "_outline", x, y, { color = 0 })
  PkgImage.draw(g, key, x, y)
  -- 信息放到头像上方，不盖住表情和发型。
  local tag_y = y - 30
  local info_offset = name == "你" and -15 or 0
  -- 底部真人的手牌已直观表达局势，不再重复“你 · 余 N”；
  -- 对手只保留“身份 · 余牌”这一条信息。昵称和独立身份牌会在小屏上互相挤压。
  if name ~= "你" then
    -- 两个对手的信息条统一向左收 10px，与头像主体的视觉重心对齐。
    local tag_x = x - 3 + info_offset
    -- 右侧座位仅留一条标签的空间，左收避免贴边或截断。
    local label = (role or "对手") .. " · 余 " .. count
    -- 预留两个数字位：余牌从 17 变为 10 或 9 时都不会挤到右侧或被裁掉。
    local tag_w = 122
    tag_x = math.min(tag_x, DESIGN_WIDTH - 2 - tag_w)
    -- 正在行动时反相，既能识别回合，又不再多加独立白点或第二个身份框。
    -- 不画外层白描边，避免在深色牌桌上显出一圈突兀的白边。
    g:rect(tag_x, tag_y, tag_w, 24,{fill=true,color=active and 0 or 15})
    -- 黑底位置不动，只将文字在其中向左校正，消除左侧视觉空隙。
    center(g, tag_x + math.floor(tag_w / 2) - 10, tag_y + 5, label, active and 15 or 0)
  end
  if role and name == "你" then
    local role_x = x + 32 + info_offset
    local role_y = tag_y - 22
    if options.role_x then role_x = options.role_x end
    if options.role_y then role_y = options.role_y end
    -- 默认 20px 顶对齐文字，上下各留 5px，不能再用不足一行字高的底板。
    g:rect(role_x, role_y, 62, 30,{fill=true,color=active and 15 or 0})
    g:rect(role_x, role_y, 62, 30,{color=15})
    center(g, role_x + 31, role_y + 5, role, active and 0 or 15)
  end
end

-- 结算页已经在右侧完整说明胜者、身份和倍率，因此只保留人物本身。
-- 不复用座位信息条，避免它压住结算标题或底部的“再来一局”。
local function draw_result_persona(g, key, x, y)
  PkgImage.draw(g, key .. "_outline", x, y, { color = 0 })
  PkgImage.draw(g, key, x, y)
end

-- 手牌槽宽：让 count 张牌在左右留白内排成一行，重叠只露左上角标。
-- 牌面 72 宽时，露出 ≥36px 可看清角标与部分中央图案；17 张仍能放下。
local function hand_slot_width(count, available)
  if count <= 1 then return CARD_W end
  available = available or (DESIGN_WIDTH - 16)
  -- 少牌时最多贴齐，绝不为了铺满整行拉出空隙；只有空间不足才重叠。
  return math.min(CARD_W, math.max(36, math.floor((available - CARD_W) / (count - 1))))
end

-- 重叠手牌中，前面的牌只露出一个槽宽；最后一张则完整露出。
-- 绘制、触控和自动化命中都必须使用这同一条规则，避免可见右缘点不到。
local function hand_card_hit_width(index, count, slot_w)
  if index == count then return CARD_W end
  return slot_w
end

-- 横向重叠牌使用半开 x 区间：[left, right)。交界点属于后画的下一张牌，
-- 与实际叠放顺序一致，不会出现看着是后一张却选中前一张的情况。
local function inside_hand_card(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y <= top + height
end

local function draw_hand_row(g, cards, x, y, slot_w, opts)
  opts = opts or {}
  local face_up = opts.face_up ~= false
  local selected_set = opts.selected_set
  local back = opts.back == true
  local vertical = opts.vertical == true -- 竖排：牌从上到下叠，只露左上角标
  local count = #cards
  if count == 0 then return end
  local total, start
  if vertical then
    if not slot_w or slot_w <= 0 then slot_w = 22 end
    total = (count - 1) * slot_w + CARD_H
    start = math.floor(y + (DESIGN_HEIGHT - y * 2 - total) / 2)
  else
    if not slot_w or slot_w <= 0 then slot_w = hand_slot_width(count) end
    total = (count - 1) * slot_w + CARD_W
    local available = opts.available or (DESIGN_WIDTH - x * 2)
    start = math.floor(x + (available - total) / 2)
  end
  for i, id in ipairs(cards) do
    local cx = vertical and x or (start + (i - 1) * slot_w)
    local cy = vertical and (start + (i - 1) * slot_w) or y
    local is_selected = not back and selected_set and selected_set[id]
    local lift = is_selected and (vertical and 0 or 30) or 0
    local draw_y = cy - lift
    -- XIC 白像素透明：先铺不透明白底再叠牌，重叠区才不会透出下层线条
    -- 选中牌在自己的原始绘制顺序中上浮。后画的相邻牌仍会压回它的重叠部分，
    -- 只有上沿露出，因此不会因“统一最后重画”而盖住后面的牌。
    if is_selected then
      rounded_card_fill(g, cx - 3, draw_y - 3, CARD_W + 6, CARD_H + 6, 9, 0)
      rounded_card_stroke(g, cx - 3, draw_y - 3, CARD_W + 6, CARD_H + 6, 9, 15)
    end
    rounded_card_fill(g, cx, draw_y, CARD_W, CARD_H, 6, 0)
    if back then
      draw_card(g, CARD_BACK, cx, draw_y)
    else
      draw_card(g, card_key(id), cx, draw_y)
      -- 选中标记（红牌用下划线区分花色；选中加边框）
      local is_red = (id >= 27 and id <= 39) or (id >= 14 and id <= 26) or id == 54
      if is_red then
        g:line(cx + 4, draw_y + CARD_H - 4, cx + CARD_W - 4, draw_y + CARD_H - 4,{color=15})
      end
    end
  end
end

-- 自己的手牌横向居中、贴近底边；人物在下层，因此牌多时会自然遮住人物。
-- 最底部手牌始终给设备边缘留出 10px，长手牌才在这一区域内叠放。
local HAND_X, HAND_AVAILABLE, HAND_Y = 10, 780, 380
local BID_Y, BID_W, BID_H, BID_GAP = 282, 112, 50, 12
local SETTINGS_X, SETTINGS_Y = LAYOUT.status.settings.x, LAYOUT.status.settings.y
local SETTINGS_W, SETTINGS_H = LAYOUT.status.settings.width, LAYOUT.status.settings.height

local function can_open_game_menu(saved, game)
  local current = game and game.players[game.current]
  return saved.screen ~= "pause" and current and current.is_human and not saved.effect and not saved.turn_notice and not saved.ai_think
end

-- 右上角只用三点图形，不额外引入一颗文字按钮；它是暂离牌桌的低优先级入口。
local function draw_settings_button(g)
  rounded_button(g, SETTINGS_X, SETTINGS_Y, SETTINGS_W, SETTINGS_H, false)
  for x = SETTINGS_X + 12, SETTINGS_X + 30, 9 do g:circle(x, SETTINGS_Y + 16, 2,{fill=true,color=15}) end
end

-- 只露出规则上真正允许的叫分：例如已有 2 分时，玩家只需在“不叫”和“3 分”间选择。
-- 这比让用户点到报错再理解规则更直接，也让按钮数量随局势自然收敛。
local function bid_actions(game)
  local called = game.bid_called or 0
  local actions = { { want = 0, label = "不叫" } }
  for want = 1, 3 do
    if want > called then actions[#actions + 1] = { want = want, label = tostring(want) .. " 分" } end
  end
  local total = #actions * BID_W + (#actions - 1) * BID_GAP
  local start = math.floor(400 - total / 2)
  for i, action in ipairs(actions) do
    action.x, action.y, action.width, action.height = start + (i - 1) * (BID_W + BID_GAP), BID_Y, BID_W, BID_H
  end
  return actions
end

-- 三座布局：自己位于底部左侧，左家和右家分列两边。
local function draw_ai_seat(g, saved, game, key, x, y, player_index)
  local is_current = game.current == player_index
  draw_persona(g, key, x, y, display_name(saved, player_index), #game.players[player_index].cards, role_label(game, player_index), is_current)
end

-- 对手手牌必须可感知但不能泄露：每一张都画为牌背，边缘叠成一束。
-- 牌越少，露出的牌背越少，也让围桌玩家能直观看到局势。
local function draw_ai_card_fan(g, count, x, y, direction)
  local step = 3
  for i = 1, count do
    local card_x = x + (i - 1) * step * direction
    g:rect(card_x, y, CARD_W, CARD_H,{fill=true,color=0})
    g:rect(card_x, y, CARD_W, CARD_H,{color=15})
    draw_card(g, CARD_BACK, card_x, y)
  end
end

local function draw_table_players(g, saved, game)
  local left, right = ai_indices(saved)
  -- 牌背顶端留在状态栏和人物之间：可看清两家仍握着一整叠牌，
  -- 又不会压住头像、昵称或中央出牌区。
  local left_seat, right_seat = LAYOUT.seats.left, LAYOUT.seats.right
  draw_ai_card_fan(g, #game.players[left].cards, left_seat.fan_x, left_seat.fan_y, left_seat.fan_direction)
  draw_ai_card_fan(g, #game.players[right].cards, right_seat.fan_x, right_seat.fan_y, right_seat.fan_direction)
  local portraits = saved.ai_portraits or { PLAYER_LEFT, PLAYER_RIGHT }
  draw_ai_seat(g, saved, game, portraits[1], left_seat.portrait_x, left_seat.portrait_y, left)
  draw_ai_seat(g, saved, game, portraits[2], right_seat.portrait_x, right_seat.portrait_y, right)
end
local function draw_human_hand(g, saved, game)
  local human, selected = game.players[saved.human_index], {}
  for _, id in ipairs(saved.selected or {}) do selected[id] = true end
  -- 主角和两位对手使用同尺寸整身人物。先画人物、后画手牌：牌多时遮住下半身，
  -- 随手牌减少自然露出更多人物，形成桌游常见的层级关系。
  local role = role_label(game, saved.human_index) or "农民"
  local count = #human.cards
  local slot_w = hand_slot_width(count, HAND_AVAILABLE)
  -- 身份条固定在牌列右端上方，不随手牌减少左右漂移。
  -- 身份牌加高后向上收 8px，底部仍停在手牌开始的 y=380 之前。
  local persona_options = { role_x = 729, role_y = 348 }
  -- 右上角保持在 (178, 242)，等比放大的左下角延展至屏幕左边缘。
  draw_persona(g, PLAYER_HERO_TABLE, 0, 242, "你", count, role, game.current == saved.human_index, persona_options)
  draw_hand_row(g, human.cards, HAND_X, HAND_Y, slot_w, { face_up = true, selected_set = selected, available = HAND_AVAILABLE })
end

-- 每一墩是三家依次行动的过程：领出、压牌、不出都必须同时留在桌上，
-- 直到领出者下一次重新出牌才清空。不能只把“当前待压牌”当成桌面。
local function draw_trick_cards(g, cards, center_x, y)
  local count = #cards
  if count == 0 then return end
  -- 与手牌完全同款同尺寸的 XIC。少牌紧凑相邻，长牌型才压缩重叠，绝不拉开空隙。
  local available = 270
  local slot = count <= 1 and CARD_W or math.min(CARD_W, math.max(8, math.floor((available - CARD_W) / (count - 1))))
  local total = (count - 1) * slot + CARD_W
  local start_x = center_x - math.floor(total / 2)
  for i, id in ipairs(cards) do
    local x = start_x + (i - 1) * slot
    -- XIC 的白像素透明；底板保证叠牌时不会透出人物或桌面纹理。
    g:rect(x, y, CARD_W, CARD_H,{fill=true,color=0})
    draw_card(g, card_key(id), x, y)
  end
end

local function draw_trick_action(g, saved, entry, actor, center_x, y)
  if entry and entry.action == "play" then
    -- 牌就摆在对应座位附近，牌型的即时识别交给已播放过的演出；
    -- 不额外留一行孤立文字抢占中央空间。
    draw_trick_cards(g, entry.cards or {}, center_x, y)
  elseif entry and entry.action == "pass" then
    -- “不要”只作为排队中的中央动作演出显示一次。它是 400×200 的大素材，
    -- 不能在演出结束后复用旧的头像旁坐标常驻，否则会盖住中央出牌区。
    -- 本墩的牌面仍由 play 记录保留；弃牌不会制造第二张静态“不要”。
  end
end

-- 中央出牌区直接落在牌桌背景上：三行完整保留本墩动作，不再套白色信息卡。
local function draw_play_area(g, saved, game)
  -- 大号“轮到你了”提示占用中央 400×120 区域，显示它的短暂时刻不叠放旧墩牌面。
  if saved.human_turn_prompt then return end
  local by_actor = {}
  for _, entry in ipairs(game.trick_actions or {}) do by_actor[entry.actor] = entry end
  if #(game.trick_actions or {}) > 0 then
    -- 牌靠近各自玩家，而不是挤成中央日志：围桌的人能一眼看出是谁出的。
    local left, right = ai_indices(saved)
    local left_slot, right_slot, human_slot = LAYOUT.trick.left, LAYOUT.trick.right, LAYOUT.trick.human
    draw_trick_action(g, saved, by_actor[left], left, left_slot.center_x, left_slot.y)
    draw_trick_action(g, saved, by_actor[right], right, right_slot.center_x, right_slot.y)
    draw_trick_action(g, saved, by_actor[saved.human_index], saved.human_index, human_slot.center_x, human_slot.y)
  else
    -- 新一墩没有历史动作时刻意留白；首出由“轮到你了”或 AI 头像旁的思考章表达。
  end
end

local function draw_bid_screen(g, saved, game)
  draw_table_players(g, saved, game)
  local beans, bid_title = LAYOUT.status.beans, LAYOUT.effect.bid_title
  draw_bean_status(g, saved, beans.x, beans.y, beans.width)
  -- 叫分阶段只留下本身的视觉标题与可点分数，不再用白框堆叠规则提示。
  -- 普通待叫分态采用屏幕中心坐标；发生叫分动作时由队列中的动态“叫 N 分”
  -- 演出接管，避免同一时刻画出两张标题。
  if not saved.effect then
    PkgImage.draw(g, "fx_bid_t_outline", bid_title.x, bid_title.y, { color = 0 })
    PkgImage.draw(g, "fx_bid_t", bid_title.x, bid_title.y)
  end
  if game.players[game.current] and game.players[game.current].is_human then
    for _, action in ipairs(bid_actions(game)) do draw_button(g, action.x, action.y, action.width, action.height, action.label, action.want == 3) end
  else
    local left = ai_indices(saved)
    local x = game.current == left and 110 or 618
    PkgImage.draw(g, "fx_think_i_outline", x, 108, { color = 0 })
    PkgImage.draw(g, "fx_think_i", x, 108)
  end
  -- 叫分过程的状态已由分数按钮、人物旁思考章和“叫分/不叫”素材表达。
  -- 这里不再落一行瞬时系统字，避免和标题及人物重叠。
  draw_human_hand(g, saved, game)
  if can_open_game_menu(saved, game) then draw_settings_button(g) end
end

local function human_can_beat(game, human)
  return not game.last_type or #Rules.greater_cards(human.cards, game.last_type) > 0
end

local function selected_cards_playable(game, human, selected)
  if #(selected or {}) == 0 then return false end
  local verdict = Rules.can_play(human.cards, selected, game.last_type)
  return verdict and verdict.ok == true
end

local function play_actions(game, human, can_play_selection, has_selection)
  local actions
  if has_selection then
    -- 无论这组牌最终是否可出，都不能在选牌态显示“不要”。用户先取消/调整
    -- 选牌，才能重新看到弃牌操作；这样触控区不会与上浮牌产生歧义。
    actions = {}
    if can_play_selection then actions[#actions + 1] = { key = "play", label = "出牌", primary = true } end
    actions[#actions + 1] = { key = "hint", label = "提示" }
  elseif game.last_type and not human_can_beat(game, human) then
    -- 无牌可压时只给唯一正确动作，避免摆出点了也无效的按钮。
    actions = { { key = "pass", label = "不要", primary = true } }
  else
    -- 先选牌再出现“出牌”，不让一个必然报“请选择”的按钮占据主操作位。
    actions = {}
    if can_play_selection then actions[#actions + 1] = { key = "play", label = "出牌", primary = true } end
    -- 任何牌一旦上浮，就只允许确认或继续调整。先隐藏“不要”，避免手指
    -- 落在牌与按钮交界时误弃掉已经选好的牌。
    if game.last_type and not has_selection then actions[#actions + 1] = { key = "pass", label = "不要" } end
    actions[#actions + 1] = { key = "hint", label = "提示" }
  end
  local bar = LAYOUT.action_bar
  local start = math.floor(DESIGN_WIDTH / 2 - (#actions * bar.width + (#actions - 1) * bar.gap) / 2)
  for i, a in ipairs(actions) do a.x, a.y, a.width, a.height = start + (i - 1) * (bar.width + bar.gap), bar.y, bar.width, bar.height end
  return actions
end
local function draw_play_screen(g, saved, game)
  draw_table_players(g, saved, game)
  draw_play_area(g, saved, game)
  local now = game.players[game.current]
  local now_name = display_name(saved, game.current)
  local human = game.players[saved.human_index]
  -- 回合、无牌可压、选牌等信息已经由“轮到你了”演出、按钮显隐和手牌上浮表达。
  -- 不再在中央重复成说明文字，避免与牌型特效争夺同一块视觉区域。
  -- 防御性错误仍记录在 state，供日志和测试诊断；不在牌桌中央显示孤立文字。
  -- 先画手牌，再画操作区：已选牌上浮时不能盖住“出牌”按钮。
  draw_human_hand(g, saved, game)
  -- 牌型演出有透明留白；若仍绘制底层按钮，"出牌 / 不要 / 提示"会从留白处露出，
  -- 看起来像特效后面多了一排残留控件。演出期间只保留牌桌与特效本身。
  if not saved.effect and now and now.is_human then
    for _, a in ipairs(play_actions(game, human, selected_cards_playable(game, human, saved.selected), #(saved.selected or {}) > 0)) do draw_button(g, a.x, a.y, a.width, a.height, a.label, a.primary) end
  elseif not saved.effect then
    -- 对手回合没有可点的操作，也不再用一行孤立文字冒充状态栏。
    -- 思考只在对应头像旁出现墨云章；已出的牌与“不要”章会保留在本墩内。
    -- AI 的等待需有视觉锚点，而不是只有一行字。墨云小章靠近当前座位，
    -- 三层贴身白底保证在花纹牌桌上可读，但不使用矩形信息板。
    if saved.ai_think then
      local left = ai_indices(saved)
      local x = game.current == left and 110 or 618
      PkgImage.draw(g, "fx_think_i_outline", x, 108, { color = 0 })
      PkgImage.draw(g, "fx_think_i", x, 108)
    end
  end
  if not saved.effect and can_open_game_menu(saved, game) then draw_settings_button(g) end
end

local function draw_pause_screen(g, saved, game)
  -- 暂停前的牌桌仍留在背后，帮助围桌玩家理解“继续”会回到哪里。
  -- 但背景是纯画面而不是可操作画面：若复用完整的 bid/play screen，
  -- “提示”“出牌”等按钮会从墨卷边下露出来，造成暂停后仍可点击的错觉。
  if game.phase == "bid" then
    draw_table_players(g, saved, game)
    draw_human_hand(g, saved, game)
  else
    draw_play_status_cards(g, game)
    draw_table_players(g, saved, game)
    draw_play_area(g, saved, game)
    draw_human_hand(g, saved, game)
  end
  draw_ink_modal(g, 60)
  -- 四个操作按钮已经承担菜单语义；去掉会落在卷边上的重复标题。
  center(g, 400, 108, "暂停中 · 难度：" .. AI.difficulty_profile(game.difficulty).label .. " · 牌局已保留", 15)
  draw_button(g, 280, 126, 240, 48, "继续游戏", true)
  draw_button(g, 280, 180, 240, 48, "规则说明", false)
  draw_button(g, 280, 234, 240, 48, "重新开始", false)
  draw_button(g, 280, 288, 240, 48, "返回封面", false)
end

local function draw_rules_screen(g)
  draw_ink_modal(g, 60)
  -- 页面入口“规则说明”已经给出标题；卷边内只保留可执行的规则正文，
  -- 避免把泛用标题画进最容易被边饰压住的顶端。
  -- 左对齐的规则列比逐行居中更易扫读，且始终留出足够右侧安全边距。
  g:text(216, 118, "① 首家选牌后出牌，不能“不要”", { color = 15 })
  g:text(216, 146, "② 跟牌需同型且更大；否则“不要”", { color = 15 })
  g:text(216, 174, "③ “提示”会选出最小能压牌", { color = 15 })
  g:text(216, 202, "④ 叫分定初倍；炸弹、王炸再翻", { color = 15 })
  g:text(240, 226, "春天继续翻倍，最高 ×48", { color = 15 })
  g:text(216, 254, "⑤ 先出完手牌的一方获胜", { color = 15 })
  draw_button(g, 292, 304, 216, 46, "返回菜单", true)
end

local function draw_stats_screen(g, saved)
  -- 战绩页把欢乐豆从“余额数字”升级成可点击的财神仪式：大古钱、奖励钱潮与账户数据同屏。
  -- 真机中文字体的实际字宽比 text_units 的保守估算略宽；战绩列单独左移，
  -- 让四行文字的视觉中心与底部按钮中心重合，而不牵连其他页面的排版。
  local stats_center_x = 378
  center(g, stats_center_x, 30, "财运战绩", 15)
  draw_layered_asset(g, "fx_coin_r", 140, 52)
  local account = saved.economy or Economy.account()
  local total = account.total_games or 0
  local wins = account.wins or 0
  local losses = account.losses or 0
  local rate = total > 0 and math.floor(wins * 100 / total) or 0
  local difficulty = saved.difficulty or "casual"
  local difficulty_stats = account.difficulty_stats and account.difficulty_stats[difficulty] or {}
  local difficulty_label = AI.difficulty_profile(difficulty).label
  center(g, stats_center_x, 292, "总局 " .. total .. "  ·  胜 " .. wins .. "  · 负 " .. losses, 15)
  center(g, stats_center_x, 320, "胜率 " .. rate .. "%  ·  救济 " .. (account.relief_uses or 0) .. " 次", 15)
  center(g, stats_center_x, 348, "余额 " .. (account.balance or Economy.STARTING_BALANCE) .. " 豆  ·  " .. difficulty_label .. "净胜 " .. (difficulty_stats.net or 0), 15)
  center(g, stats_center_x, 376, "当前连胜 " .. (account.streak or 0) .. "  ·  最高连胜 " .. (account.best_streak or 0), 15)
  draw_button(g, 292, 412, 216, 46, "返回封面", true)
end
local function draw_result_screen(g, saved, game)
  local settlement = game.economy_settlement
  local winner = game.players[game.winner]
  -- 结算要从牌局中彻底抽离：不保留牌桌、敌人或墨卷边饰，
  -- 让围桌玩家一眼进入“这一局已经结束”的全屏结果页。
  local winner_key = winner.is_human and PLAYER_HERO or (game.winner == 3 and PLAYER_RIGHT or PLAYER_LEFT)
  local winner_name = winner.is_human and "你" or display_name(saved, game.winner)
  local title_key = winner.is_human and "fx_win_t" or "fx_loss_t"
  local change = settlement and settlement.delta or 0

  -- 参考经典结算页的叙事顺序：左边胜者陪同，右边是一张独立账单；
  -- 横幅覆盖账单顶部，把“胜利”从普通文本升级为领奖仪式，而不是左右各一张海报。
  if winner.is_human then
    draw_background(g)
    -- 结算人物使用封面级原生大图，不在运行时缩放；人物需要撑住左侧舞台，
    -- 才能与右边的领奖单形成主从，而不是缩成一枚旁注头像。
    draw_result_persona(g, "menu_hero_l", 28, 140)
    draw_panel(g, 280, 96, 480, 356)
    g:rect(288, 104, 464, 340,{color=15})
    PkgImage.draw(g, "ui_win_band_outline", 310, 32, { color = 0 })
    PkgImage.draw(g, "ui_win_band", 310, 32)
    PkgImage.draw(g, "fx_win_t_outline", 380, 38, { color = 0 })
    PkgImage.draw(g, "fx_win_t", 380, 38)
    center(g, 520, 150, "地主 · 本局获胜", 15)
    PkgImage.draw(g, "fx_coin_win", 288, 148)
    center(g, 574, 186, "欢乐豆入账", 15)
    local reward_text = tostring(math.abs(change))
    local reward_width = #reward_text * 34 + (#reward_text - 1) * 7
    draw_brush_number(g, change, 574 - math.floor(reward_width / 2), 212, reward_width)
    local account_line = "余额 " .. tostring(saved.economy.balance) .. " 豆 · 倍数 ×" .. tostring(game.multiplier)
    if settlement and settlement.bonus > 0 then account_line = account_line .. " · 里程碑 +" .. settlement.bonus end
    center(g, 520, 276, account_line, 15)
    g:line(316, 302, 724, 302,{color=15})
    for index, player in ipairs(game.players) do
      local name = player.is_human and "你" or display_name(saved, index)
      local role = role_label(game, index) or "牌手"
      local row_y = 316 + (index - 1) * 25
      g:text(334, row_y, name .. " · " .. role, { color = 15 })
      g:text(674, row_y, index == game.winner and "胜" or "负", { color = 15 })
    end
    draw_button(g, 332, 394, 180, 46, "返回首页", true)
    draw_button(g, 528, 394, 180, 46, "再来一局", true)
    return
  end

  PkgImage.draw(g, title_key .. "_outline", 260, 16, { color = 0 })
  PkgImage.draw(g, title_key, 260, 16)
  -- 失败但尚未触发救济时保留人物，避免每个结果都变成同一张奖励图。
  if settlement and settlement.relief > 0 then
    PkgImage.draw(g, "fx_coin_help_outline", 320, 78, { color = 0 })
    PkgImage.draw(g, "fx_coin_help", 320, 78)
  else
    draw_result_persona(g, winner_key, 337, 104)
  end
  local reward_label = change >= 0 and "本局赢得欢乐豆" or "本局扣除欢乐豆"
  local reward_center_x = 400
  center(g, reward_center_x, 286, (role_label(game, game.winner) or "本局胜者") .. " · " .. reward_label, 15)
  local reward_text = tostring(math.abs(change))
  local reward_width = #reward_text * 34 + (#reward_text - 1) * 7
  local reward_x = reward_center_x - math.floor(reward_width / 2)
  draw_brush_number(g, change, reward_x, 304, reward_width)
  local account_line = "余额 " .. tostring(saved.economy.balance) .. " 豆 · 倍数 ×" .. tostring(game.multiplier)
  if settlement and settlement.relief > 0 then
    account_line = "余额 " .. tostring(saved.economy.balance) .. " 豆 · 救济 +" .. settlement.relief
  elseif settlement and settlement.bonus > 0 then
    account_line = "余额 " .. tostring(saved.economy.balance) .. " 豆 · 里程碑 +" .. settlement.bonus
  else
    account_line = account_line .. " · " .. AI.difficulty_profile(game.difficulty).label
  end
  center(g, 400, 370, account_line, 15)
  local marks = {}
  for index, player in ipairs(game.players) do
    local name = player.is_human and "你" or (index == 2 and "左家" or "右家")
    marks[#marks + 1] = name .. (index == game.winner and " 胜" or " 负")
  end
  center(g, 400, 398, table.concat(marks, "  ·  "), 15)
  draw_button(g, 212, 426, 180, 46, "返回首页", true)
  draw_button(g, 408, 426, 180, 46, "再来一局", true)
end

local function difficulty_cards()
  local cards = {}
  for index, profile in ipairs(AI.difficulties()) do
    cards[index] = { profile = profile, x = 70 + (index - 1) * 240, y = 76, width = 180, height = 310 }
  end
  return cards
end

local function difficulty_available(profile)
  return OPEN_DIFFICULTIES[profile.id] == true
end

local function difficulty_portrait_key(profile)
  if profile.id == "novice" then return "diff_novice" end
  if profile.id == "casual" then return "diff_casual" end
  return "diff_challenge"
end

local function difficulty_summary(profile)
  if profile.id == "novice" then return "熟悉规则" end
  if profile.id == "casual" then return "会配合、会控牌" end
  return "记牌、算残局"
end

local function draw_difficulty_back(g)
  -- 用一个标准返回箭头表达低优先级导航；不再以笨重的文字按钮切断顶部重心。
  local cx, cy = DIFFICULTY_BACK_X + 22, DIFFICULTY_BACK_Y + 22
  g:circle(cx, cy, 15,{color=15})
  g:line(cx + 7, cy, cx - 7, cy,{color=15})
  g:line(cx - 7, cy, cx - 1, cy - 6,{color=15})
  g:line(cx - 7, cy, cx - 1, cy + 6,{color=15})
end

local function draw_difficulty_screen(g, saved)
  -- 独立的全屏开局场景：不再套进牌桌或弹窗，三位对手和触控选择成为全部视觉内容。
  center(g, 400, 32, "选择对手强度", 15)
  draw_difficulty_back(g)
  for _, card in ipairs(difficulty_cards()) do
    local profile = card.profile
    local available = difficulty_available(profile)
    local selected = available and saved.difficulty == profile.id
    g:rect(card.x, card.y, card.width, card.height,{fill=true,color=0})
    g:rect(card.x, card.y, card.width, card.height,{color=15})
    local portrait = difficulty_portrait_key(profile)
    -- 与牌桌人物相同的贴身白底和细 halo，人物是内容本身而非白色方块里的缩略图。
    PkgImage.draw(g, portrait .. "_outline", card.x + 5, card.y + 12, { color = 0 })
    PkgImage.draw(g, portrait, card.x + 5, card.y + 12)
    center(g, card.x + 90, card.y + 242, profile.label, 15)
    -- 两个长说明的视觉重心受人物留白影响更偏右，额外左校正；档位标题仍严格居中。
    local summary_x = card.x + (profile.id == "novice" and 82 or 72)
    center(g, summary_x, card.y + 262, available and difficulty_summary(profile) or "即将开放", 15)
    if selected then
      g:rect(card.x + 1, card.y + 282, card.width - 2, 27,{fill=true,color=15})
      center(g, card.x + 90, card.y + 288, "已选择", 0)
    end
  end
  draw_button(g, DIFFICULTY_START_X, DIFFICULTY_START_Y, DIFFICULTY_START_W, DIFFICULTY_START_H, "开始对局", true)
end

-- 运行时资源 key 最长 23 字符。完整牌型名保留在业务枚举里，只有素材协议使用短名。
local EFFECT_ICON_KEYS = {
  straight = "fx_str_i",
  pair_chain = "fx_pair_i",
  trio_solo = "fx_3_1_i",
  trio_pair = "fx_3_2_i",
  four_two_solo = "fx_4_2_i",
  four_two_pair = "fx_4_2p_i",
  bid = "fx_bid_i",
  no_bid = "fx_no_bid_i",
  pass = "fx_pass_i",
  hint = "fx_hint_i",
  overcome = "fx_over_i",
  lead = "fx_lead_i",
  anti_spring = "fx_as_i",
  landlord = "fx_land_i",
}

local EFFECT_TITLE_KEYS = {
  bomb = "fx_bomb_t", rocket = "fx_rock_t", spring = "fx_spring_t", anti_spring = "fx_as_t",
  bid = "fx_bid_t", no_bid = "fx_no_bid_t", pass = "fx_pass_t", hint = "fx_hint_t",
  overcome = "fx_over_t", lead = "fx_lead_t", landlord = "fx_land_t", victory = "fx_win_t",
  defeat = "fx_loss_t", plane = "fx_plane_t", straight = "fx_str_t", pair_chain = "fx_pair_t",
  trio_solo = "fx_3_1_t", trio_pair = "fx_3_2_t", four_two_solo = "fx_4_2_t",
  four_two_pair = "fx_4_2p_t", your_turn = "fx_turn_t",
}

local function effect_icon_key(kind)
  return EFFECT_ICON_KEYS[kind] or ("fx_" .. kind .. "_icon")
end

local function effect_title_key(kind, multiplier)
  if kind == "bid" and multiplier and multiplier >= 1 and multiplier <= 3 then
    return "fx_bid" .. tostring(multiplier) .. "_t"
  end
  return EFFECT_TITLE_KEYS[kind]
end

local function draw_effect_title(g, key, x, y)
  PkgImage.draw(g, key .. "_outline", x, y, { color = 0 })
  PkgImage.draw(g, key, x, y)
end

local function multiplier_badge_key(multiplier)
  if multiplier == 2 then return "fx_x2" end
  if multiplier == 4 then return "fx_x4" end
  if multiplier == 8 then return "fx_x8" end
  return nil
end

local function draw_multiplier_badge(g, key, x, y)
  -- 倍数也是文字型图像，沿用标题的三层合成，避免只剩黑色阴影。
  PkgImage.draw(g, key .. "_outline", x, y, { color = 0 })
  PkgImage.draw(g, key, x, y)
end

local function draw_effect_stage(g, x, y, width, height)
  -- 大演出只借用一块纯白留白区来隔离复杂牌桌：没有描边、没有卡片阴影，
  -- 让素材成为唯一焦点，同时仍保留四周角色、牌桌和手牌作为空间线索。
  -- 用较大的圆角而非直角白块，让舞台和牌桌的椭圆桌面保持柔和关系。
  local radius = math.min(24, math.floor(width / 8), math.floor(height / 4))
  g:rect(x + radius, y, width - radius * 2, height,{fill=true,color=0})
  g:rect(x, y + radius, width, height - radius * 2,{fill=true,color=0})
  g:circle(x + radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + radius, radius,{fill=true,color=0})
  g:circle(x + radius, y + height - 1 - radius, radius,{fill=true,color=0})
  g:circle(x + width - 1 - radius, y + height - 1 - radius, radius,{fill=true,color=0})
end

-- 视觉反馈按影响范围分层：
-- global 会让全桌都停下来阅读；seat 只说明某一位玩家的动作；local 只确认
-- 当前用户刚触发的小功能。不能再把这三类都画成同一块中央大舞台。
local function effect_tier(kind)
  if kind == "hint" then return "local" end
  if kind == "bid" or kind == "no_bid" or kind == "pass" or kind == "overcome" or kind == "lead" then return "seat" end
  return "global"
end

local function effect_blocks_input(effect)
  return effect and effect_tier(effect.kind) ~= "local"
end

local function seat_effect_position(saved, actor, effect_kind)
  local left = ai_indices(saved)
  local seat_key
  if actor == saved.human_index then seat_key = "human"
  elseif actor == left then seat_key = "left"
  else seat_key = "right" end
  if effect_kind == "bid" or effect_kind == "no_bid" then return LAYOUT.effect.bid_seat[seat_key] end
  local slot = LAYOUT.effect.seat[seat_key]
  return { x = slot.x, y = effect_kind == "pass" and slot.pass_y or slot.play_y }
end

local function seat_effect_label(effect)
  if effect.kind == "bid" then return "叫 " .. tostring(effect.multiplier or 0) .. " 分" end
  if effect.kind == "no_bid" then return "不叫" end
  if effect.kind == "pass" then return "不要" end
  if effect.kind == "overcome" then return "压过" end
  return "领出"
end

local function draw_effect_overlay(g, saved, game)
  local effect = saved.effect
  if not effect then return end
  local tier = effect_tier(effect.kind)
  if tier == "local" then
    -- “提示”本身就是选中可出牌的本地操作；上浮手牌已经是充分反馈。
    -- 旧存档即使带有 hint effect 也不再额外绘制任何素材。
    return
  elseif tier == "seat" then
    -- 单个玩家的“不要 / 叫分 / 压过”使用 200×200 的图形章贴近行动者。
    -- 它不占全桌中央舞台，文字只做就地识别，避免再次引入 400×200 大标题。
    local seat = seat_effect_position(saved, effect.actor, effect.kind)
    local icon_key = effect_icon_key(effect.kind)
    PkgImage.draw(g, icon_key .. "_outline", seat.x, seat.y, { color = 0 })
    PkgImage.draw(g, icon_key, seat.x, seat.y)
    center(g, seat.x + 100, seat.y + 172, seat_effect_label(effect), 15)
    return
  end
  -- 强牌型和胜负演出都在中部无边框留白区播放。大组合用更宽、更高的
  -- 舞台和专用 200px 素材，围桌玩家无需凑近也能辨认牌型。
  local large_combo = effect.kind == "plane" or effect.kind == "straight" or effect.kind == "pair_chain" or effect.kind == "four_two_solo" or effect.kind == "four_two_pair"
  local medium_combo = effect.kind == "trio_solo" or effect.kind == "trio_pair"
  -- 放大的图标与标题保持原尺寸；只收紧宣纸底衬。横构图的左侧允许略微越出，
  -- 让牌型像冲出白边，而不是被一整块宽白板困住。
  if large_combo then draw_effect_stage(g, 130, 66, 560, 250)
  elseif medium_combo then draw_effect_stage(g, 140, 66, 530, 250)
  else draw_effect_stage(g, 160, 86, 480, 214) end
  local icon_key = effect_icon_key(effect.kind)
  if effect.kind == "plane" or effect.kind == "straight" or effect.kind == "pair_chain" or effect.kind == "trio_solo" or effect.kind == "trio_pair" or effect.kind == "four_two_solo" or effect.kind == "four_two_pair" or effect.kind == "landlord" or effect.kind == "rocket" or effect.kind == "bomb" or effect.kind == "spring" or effect.kind == "anti_spring" or effect.kind == "victory" or effect.kind == "defeat" then
    -- 复杂牌型素材遵循贴身白底 + 细 halo + 细节的三层顺序，
    -- 让图形在花纹牌桌上清晰，不出现矩形白色底板。
    local icon_x = large_combo and 130 or (medium_combo and 100 or 180)
    local icon_y = large_combo and 71 or (medium_combo and 76 or 92)
    PkgImage.draw(g, icon_key .. "_outline", icon_x, icon_y, { color = 0 })
  end
  local icon_x = large_combo and 130 or (medium_combo and 100 or 180)
  local icon_y = large_combo and 71 or (medium_combo and 76 or 92)
  PkgImage.draw(g, icon_key, icon_x, icon_y)
  -- 标题保持与舞台整体居中；素材自带留白虽然拉开图文，能避免右侧视觉失重。
  local title_x = large_combo and 390 or (medium_combo and 440 or 400)
  draw_effect_title(g, effect_title_key(effect.kind, effect.multiplier), title_x, large_combo and 144 or (medium_combo and 144 or 132))
  if effect.kind == "bomb" or effect.kind == "rocket" or effect.kind == "spring" or effect.kind == "anti_spring" then
    local multiplier_key = multiplier_badge_key(effect.multiplier)
    if multiplier_key then draw_multiplier_badge(g, multiplier_key, 344, 210) end
  end
end

local function draw_human_turn_prompt(g, saved)
  if not saved.human_turn_prompt then return end
  -- 只用标题作为轻提示，置于操作区上方；即使 AI 的复杂牌型仍在演出，
  -- 真人也能立即看到自己的回合且按钮保持可用。
  local title = LAYOUT.effect.human_turn_title
  draw_effect_title(g, "fx_turn_t", title.x, title.y)
end

-- 语义点击树只服务预览与自动化测试：它和真正的命中检测共用同一组布局数据。
-- 浏览器运行时会注入这个临时 state 槽位并在快照时剥离；真机没有它，游戏不依赖它。

-- ── 绘制入口 ────────────────────────────────────────────────────────────────
function on_draw(ctx, g) require("pkg_image").bind(ctx);
  g:clear(0) -- 0=白底，15=黑字（EPD 颜色契约）
  local saved = load_state(ctx)
  local game = saved.game

  -- 结算页是干净的全屏白纸，其余页面才需要牌桌背景。
  if saved.screen ~= "result" and saved.screen ~= "difficulty" and saved.screen ~= "stats" then draw_background(g) end

  if saved.screen == "menu" then
    -- 首页是“已经开席”的一张牌桌：上方给游戏名足够的落点，中央用三张真牌
    -- 建立斗地主识别，人物留在两侧而不把开局入口挤成一颗普通按钮。
    -- 白描边先落在深色牌桌背景上，再叠黑字；既保证标题可读，也不把场景切成白色弹窗。
    PkgImage.draw(g, "menu_title_edge", 200, 30, { color = 0 })
    PkgImage.draw(g, "menu_title", 200, 30)
    -- 首页直接展示已确认的新版普通牌面；不用小王这类特殊牌当首屏样张，
    -- 让用户第一眼就看到与实战手牌完全一致的数字 / 小花色 / 大主花色层级。
    for _, card in ipairs({ { "card_h3", 290, 162 }, { "card_s6", 364, 148 }, { "card_d9", 438, 162 } }) do
      g:rect(card[2], card[3], CARD_W, CARD_H,{fill=true,color=0})
      g:rect(card[2], card[3], CARD_W, CARD_H,{color=15})
      draw_card(g, card[1], card[2], card[3])
    end
    -- 封面人物沿用牌局内的贴身白底与细轮廓，避免透明人物直接叠在桌布上显虚。
    -- 左侧佳人、右侧俊男只承担封面氛围，不影响每局随机 AI 阵容与规则。
    draw_result_persona(g, "menu_hero_l", 0, 186)
    draw_result_persona(g, "menu_hero_r", 590, 186)
    draw_layered_asset(g, "fx_coin_big", 270, 262)
    draw_large_balance(g, saved, 362, 286, 174)
    draw_button(g, MENU_START_X, MENU_START_Y, MENU_START_W, MENU_START_H, "开始对局", true)
  elseif saved.screen == "difficulty" then
    draw_difficulty_screen(g, saved)
  elseif saved.screen == "bid" then
    draw_bid_screen(g, saved, game)
  elseif saved.screen == "play" then
    -- 顶部只保留底牌和倍数两枚圆角小卡；地主身份已在人物旁表达。
    draw_play_status_cards(g, game)
    local beans = LAYOUT.status.beans
    draw_bean_status(g, saved, beans.x, beans.y, beans.width)
    draw_play_screen(g, saved, game)
  elseif saved.screen == "pause" and game then
    draw_pause_screen(g, saved, game)
  elseif saved.screen == "rules" then
    draw_rules_screen(g)
  elseif saved.screen == "stats" then
    draw_stats_screen(g, saved)
  elseif saved.screen == "result" then
    draw_result_screen(g, saved, game)
  end
  if saved.effect and game then draw_effect_overlay(g, saved, game) end
  if saved.screen == "play" then draw_human_turn_prompt(g, saved) end
end

-- ── 输入 ────────────────────────────────────────────────────────────────────
local function handle_menu_input(ctx, saved, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if inside(ev.x, ev.y, MENU_FORTUNE_X, MENU_FORTUNE_Y, MENU_FORTUNE_W, MENU_FORTUNE_H) then
      saved.screen = "stats"
      ctx:invalidate()
      return true
    elseif inside(ev.x, ev.y, MENU_START_X, MENU_START_Y, MENU_START_W, MENU_START_H) then
      saved.screen = "difficulty"
      ctx:invalidate()
      return true
    end
  end
  return false
end

local function handle_stats_input(ctx, saved, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" and inside(ev.x, ev.y, 292, 412, 216, 46) then
    saved.screen = "menu"
    ctx:invalidate()
    return true
  end
  return false
end

local function handle_difficulty_input(ctx, saved, ev)
  if not (ev.type == "pointer" and ev.phase == "up") or ev.gesture ~= "tap" then return false end
  if inside(ev.x, ev.y, DIFFICULTY_BACK_X, DIFFICULTY_BACK_Y, DIFFICULTY_BACK_W, DIFFICULTY_BACK_H) then
    saved.screen = "menu"
  elseif inside(ev.x, ev.y, DIFFICULTY_START_X, DIFFICULTY_START_Y, DIFFICULTY_START_W, DIFFICULTY_START_H) then
    fresh_game(ctx, saved, nil)
  else
    for _, card in ipairs(difficulty_cards()) do
      if inside(ev.x, ev.y, card.x, card.y, card.width, card.height) then
        if difficulty_available(card.profile) then saved.difficulty = card.profile.id end
        ctx:invalidate()
        return true
      end
    end
    return false
  end
  ctx:invalidate()
  return true
end

local function handle_bid_input(ctx, saved, ev)
  local game = saved.game
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    local idx = game.current
    local player = game.players[idx]
    if not (player and player.is_human) then
      -- AI 由 tick 一步一步推进；点击不能偷偷把局面跳到下一手。
      ctx:invalidate()
      return true
    end
    -- 仅响应当前展示的合法叫分选项。
    for _, action in ipairs(bid_actions(game)) do
      if inside(ev.x, ev.y, action.x, action.y, action.width, action.height) then
        local want = action.want
        local res = AI.human_play(game, want)
        if res.ok then
          present_turn(saved, game, idx, res)
          saved.ai_pending = true -- 让 tick 推进后续 AI 叫分/出牌
          if game.phase == "over" then saved.screen = "result" end
          if game.phase == "play" then saved.screen = "play" end
        elseif res.reason == "redeal" then
          fresh_game(ctx, saved, nil)
          saved.screen = "bid"
          saved.message = "本轮全员不叫 · 已重新发牌"
        else
          saved.message = "叫分必须高于当前最高分"
        end
        ctx:invalidate()
        return true
      end
    end
  elseif ev.type == "key" and ev.phase == "down" and ev.key == "ok" then
    local idx = game.current
    local player = game.players[idx]
    if player and player.is_human then
      local res = AI.human_play(game, 0)
      if res.ok then
        present_turn(saved, game, idx, res)
        saved.ai_pending = true
        if game.phase == "play" then saved.screen = "play" end
      elseif res.reason == "redeal" then
        fresh_game(ctx, saved, nil)
        saved.screen = "bid"
        saved.message = "本轮全员不叫 · 已重新发牌"
      end
      ctx:invalidate()
      return true
    end
  end
  return false
end

local function handle_play_input(ctx, saved, ev)
  local game = saved.game
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    local is_human_turn = game.players[game.current] and game.players[game.current].is_human
    -- 对手回合不允许预选手牌；所见状态与可操作状态严格一致。
    if not is_human_turn then
      ctx:invalidate()
      return true
    end
    local human_idx = saved.human_index
    local human = game.players[human_idx]
    -- 操作按钮优先于手牌。已选手牌会上浮 30px，若先命中手牌，
    -- “不要/出牌”按钮的中心会被上浮牌遮住，导致看得到却点不动。
    for _, action in ipairs(play_actions(game, human, selected_cards_playable(game, human, saved.selected), #(saved.selected or {}) > 0)) do
      if inside(ev.x, ev.y, action.x, action.y, action.width, action.height) and action.key == "play" then
        local actor = saved.human_index
        local res = AI.human_play(game, saved.selected)
        if res.ok then
          present_turn(saved, game, actor, res)
          saved.selected = {}
          finish_human_turn(saved, game)
        else
          saved.message = game.last_type and "这手牌压不过当前牌" or "请选择一手合法的牌"
        end
        ctx:invalidate()
        return true
      elseif inside(ev.x, ev.y, action.x, action.y, action.width, action.height) and action.key == "pass" then
        local res = AI.human_play(game, {})
        if res.ok then
          present_turn(saved, game, saved.human_index, res)
          saved.selected = {}
          finish_human_turn(saved, game)
        else
          saved.message = "本圈你是首家，不能过"
        end
        ctx:invalidate()
        return true
      elseif inside(ev.x, ev.y, action.x, action.y, action.width, action.height) and action.key == "hint" then
        local hint = AI.hint_choice(game, saved.human_index)
        if hint then
          saved.selected = hint
          saved.hint = game.last_type and { cards = hint } or nil
        else
          saved.message = "只能过"
        end
        -- 提示只选牌不代打；上浮的选中手牌就是唯一反馈，避免再弹出冗余素材。
        ctx:invalidate()
        return true
      end
    end
    -- 选牌：点击手牌区域
    if human and human_can_beat(game, human) then
      local count = #human.cards
      local slot_w = hand_slot_width(count, HAND_AVAILABLE)
      local total_w = (count - 1) * slot_w + CARD_W
      local start_x = math.floor(HAND_X + (HAND_AVAILABLE - total_w) / 2)
      if ev.y >= HAND_Y - 30 and ev.y <= HAND_Y + CARD_H then
        for i, id in ipairs(human.cards) do
          local cx = start_x + (i - 1) * slot_w
          local is_selected = false
          for _, sid in ipairs(saved.selected) do if sid == id then is_selected = true break end end
          local lift = is_selected and 30 or 0
          if inside_hand_card(ev.x, ev.y, cx, HAND_Y - lift, hand_card_hit_width(i, count, slot_w), CARD_H + lift) then
            -- toggle 选中
            local found = false
            for j, sid in ipairs(saved.selected) do
              if sid == id then table.remove(saved.selected, j) found = true break end
            end
            if not found then saved.selected[#saved.selected + 1] = id end
            ctx:invalidate()
            return true
          end
        end
      end
    end
  elseif ev.type == "key" and ev.phase == "down" then
    if ev.key == "ok" then
      if not (game.players[game.current] and game.players[game.current].is_human) then
        ctx:invalidate()
        return true
      end
      local human = game.players[saved.human_index]
      if not selected_cards_playable(game, human, saved.selected) then
        saved.message = "请先选一手能出的牌"
        ctx:invalidate()
        return true
      end
      local res = AI.human_play(game, saved.selected)
      if res.ok then
        present_turn(saved, game, saved.human_index, res)
        saved.selected = {}
        finish_human_turn(saved, game)
      else
        saved.message = game.last_type and "这手牌压不过当前牌" or "请选择一手合法的牌"
      end
      ctx:invalidate()
      return true
    elseif ev.key == "back" then
      saved.selected = {}
      ctx:invalidate()
      return true
    end
  end
  return false
end

local function handle_result_input(ctx, saved, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    local game = saved.game
    local human_won = game and game.winner and game.players[game.winner] and game.players[game.winner].is_human
    local home_x, action_y = human_won and 304 or 170, human_won and 394 or 426
    local replay_x = human_won and 492 or 390
    if inside(ev.x, ev.y, home_x, action_y, 140, 46) then
      saved.screen = "menu"
      ctx:invalidate()
      return true
    elseif inside(ev.x, ev.y, replay_x, action_y, 216, 46) then
      saved.screen = "bid"
      fresh_game(ctx, saved, nil)
      return true
    end
  end
  return false
end

local function handle_pause_input(ctx, saved, ev)
  if not (ev.type == "pointer" and ev.phase == "up") or ev.gesture ~= "tap" then return false end
  if inside(ev.x, ev.y, 280, 126, 240, 48) then
    saved.screen = saved.pause_from or (saved.game.phase == "bid" and "bid" or "play")
  elseif inside(ev.x, ev.y, 280, 180, 240, 48) then
    saved.screen = "rules"
  elseif inside(ev.x, ev.y, 280, 234, 240, 48) then
    fresh_game(ctx, saved, nil)
    saved.screen = "bid"
    saved.message = "已重新开始 · 请叫地主"
  elseif inside(ev.x, ev.y, 280, 288, 240, 48) then
    saved.screen = "menu"
    saved.game = nil
    saved.selected = {}
    saved.message = nil
  else
    return false
  end
  saved.pause_from = nil
  ctx:invalidate()
  return true
end

local function handle_rules_input(ctx, saved, ev)
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" and inside(ev.x, ev.y, 292, 304, 216, 46) then
    saved.screen = "pause"
    ctx:invalidate()
    return true
  end
  return false
end

function on_input(ctx, ev)
  local saved = load_state(ctx)

  if saved.screen == "pause" then return handle_pause_input(ctx, saved, ev) end
  if saved.screen == "rules" then return handle_rules_input(ctx, saved, ev) end
  if saved.screen == "stats" then return handle_stats_input(ctx, saved, ev) end
  -- 宣告与普通动作停留期间冻结输入：点击不再暗中推进 AI 或选中手牌。
  if effect_blocks_input(saved.effect) or saved.turn_notice or saved.ai_think then ctx:invalidate(); return true end
  if (saved.screen == "bid" or saved.screen == "play") and saved.game and can_open_game_menu(saved, saved.game)
    and (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" and inside(ev.x, ev.y, SETTINGS_X, SETTINGS_Y, SETTINGS_W, SETTINGS_H) then
    saved.pause_from = saved.screen
    saved.screen = "pause"
    ctx:invalidate()
    return true
  end
  if saved.screen == "menu" then return handle_menu_input(ctx, saved, ev) end
  if saved.screen == "difficulty" then return handle_difficulty_input(ctx, saved, ev) end
  if saved.screen == "bid" then return handle_bid_input(ctx, saved, ev) end
  if saved.screen == "play" then return handle_play_input(ctx, saved, ev) end
  if saved.screen == "result" then return handle_result_input(ctx, saved, ev) end
  return false
end

-- ── 生命周期 ────────────────────────────────────────────────────────────────
function on_load(ctx)
  local saved = load_state(ctx)
  ctx:invalidate()
  local saved = load_state(ctx)
  if saved.restart_on_enter then
    saved.restart_on_enter = nil
    fresh_game(ctx, saved, nil)
    saved.message = "重新进入 · 已重新发牌"
  end
  ctx:set_tick(100)
  ctx:invalidate()
end


function on_tick(ctx, dt)
  local saved = load_state(ctx)
  advance_human_turn_prompt(saved, dt)
  if saved.screen == "pause" or saved.screen == "rules" then
    ctx:invalidate()
    return
  end
  if saved.effect then
    advance_effect(saved, dt)
    if not saved.effect and saved.game and saved.game.phase == "over" then saved.screen = "result" end
    ctx:invalidate()
    return
  end
  if saved.turn_notice then
    advance_turn_notice(saved, dt)
    ctx:invalidate()
    return
  end
  -- 一次 tick 只让一个 AI 动作。这样每次出牌/不要都能被玩家看见。
  if saved.ai_think then
    if advance_ai_think(saved, dt) then
      ctx:invalidate()
      return
    end
    -- 思考计时刚结束：本次 tick 才真正落子，下一步会再新建一次思考计时。
    if saved.game and saved.game.phase ~= "menu" and saved.game.phase ~= "over" then
      run_one_ai_turn(ctx, saved, saved.game)
    end
    ctx:invalidate()
    return
  end
  if saved.game and saved.game.phase ~= "menu" and saved.game.phase ~= "over" then
    local current = saved.game.players[saved.game.current]
    if current and not current.is_human then
      if ai_must_pass(saved.game) then run_one_ai_turn(ctx, saved, saved.game)
      else saved.ai_think = { remaining = AI_THINK_DURATION } end
    else
      run_one_ai_turn(ctx, saved, saved.game)
    end
  end
  ctx:invalidate()
end

function on_leave(ctx)
  local saved = ctx.state.doudizhu
  -- 退出牌局是明确结束本轮体验；下次进入直接发一副新牌，余额等账户状态仍保留。
  if saved and saved.game and (saved.screen == "bid" or saved.screen == "play" or saved.screen == "pause") then
    saved.restart_on_enter = true
  end
  ctx:set_tick(0)
end
