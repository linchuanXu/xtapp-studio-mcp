-- 中国象棋：应用控制器（输入路由 + AI 触发）
local State = require("domain.chess_state")
local View = require("domain.chess_view")
local AI = require("domain.chess_ai")
local Opening = require("domain.chess_opening")
local Watchdog = require("lib.watchdog_slice")
local M = {}
local ai_search = nil

local function cancel_ai_search()
  AI.cancel(ai_search)
  ai_search = nil
end

local function reset_ai_clock(s)
  s.ai_think_elapsed_ms = 0
  s.ai_think_display_seconds = 0
  s.ai_think_started_ms = nil
  s.ai_rendered_nodes = 0
end

-- 输入回调只落子并挂起 AI；搜索在续命 tick 里构建。
local DIFF_LABEL = { [1] = "简单", [2] = "中等", [3] = "复杂" }
local AI_DIALOGUES = {
  [1] = {
    start = {
      { "来下棋吧", "我会加油哦" }, { "准备好了吗", "我要出发啦" }, { "今天也要", "开心下棋呀" },
    },
    thinking = {
      { "轮到你啦", "我在想哦" }, { "这里不错", "让我看看" }, { "慢慢想呀", "我等你哦" },
      { "棋盘真有趣", "这步有意思" }, { "该你出招啦", "看看下一步" },
      { "嗯……这样走", "好像可以耶" }, { "让我数一数", "还有几步呢" },
    },
    proud = {
      { "嘿嘿看见没", "我可厉害啦" }, { "这步很妙吧", "快夸夸我呀" }, { "我领先一点", "要追上我哦" },
      { "找到好位置", "这回轮到你" }, { "哼哼小优势", "我会守住的" },
    },
    panicked = {
      { "哎呀糟糕啦", "得认真一点" }, { "等等等等", "我还没输呢" }, { "你走得真好", "我有点紧张" },
      { "不好被追啦", "让我补救下" }, { "这可怎么办", "再想一个招" },
    },
    capture = {
      { "抓到一颗", "还有机会哦" }, { "这颗归我", "继续继续" }, { "吃掉咯！", "你要小心呀" },
      { "被我发现啦", "下一颗在哪" },
    },
    check = {
      { "将军啦！", "快想想吧" }, { "你的帅危险", "快点保护他" }, { "当心这一招", "将军将军！" },
    },
    win = {
      { "我赢啦！", "再来一局" },
      { "好开心呀", "下次你会赢" },
    },
  },
  [2] = {
    start = {
      { "请多指教", "红方先行" }, { "棋局开始", "请从容落子" }, { "以棋会友", "请先走一步" },
    },
    thinking = {
      { "落子无悔", "请继续" }, { "稳住阵脚", "轮到你了" }, { "先占要点", "请应手" },
      { "局势胶着", "需再计算" }, { "攻守相当", "静待变化" },
      { "此处可行", "还需观察" }, { "双方均势", "胜负尚早" },
    },
    proud = {
      { "先得一筹", "仍不可大意" }, { "局面占优", "请谨慎应对" }, { "主动在手", "我将继续施压" },
      { "阵形已成", "轮到你破局" }, { "优势渐显", "此刻更要稳" },
    },
    panicked = {
      { "形势不利", "我需调整" }, { "你占了先机", "我得稳下来" }, { "阵脚有缺口", "先补这一处" },
      { "这步有压力", "容我再算算" }, { "局面被动", "尚有转机" },
    },
    capture = {
      { "承让一子", "局势未定" }, { "交换有利", "继续吧" }, { "此子可取", "攻势继续" },
      { "完成兑子", "再看后续" },
    },
    check = {
      { "将军", "请应将" }, { "将路已开", "请先解围" }, { "这一着将军", "请谨慎处理" },
    },
    win = {
      { "胜负已分", "再来一局" }, { "此局承让", "欢迎再战" },
    },
  },
  [3] = {
    start = {
      { "小友先请", "且从容落子" }, { "对坐一枰", "不妨徐徐来" }, { "棋局如山水", "请落第一笔" },
    },
    thinking = {
      { "不争一时", "静观后势" }, { "势在局外", "意在子先" }, { "且看此着", "如何化解" },
      { "局中有局", "须多看一层" }, { "缓处落子", "急处思量" },
      { "虚实相生", "此局尚平" }, { "一子落定", "余味未尽" },
    },
    proud = {
      { "势已在手", "仍须守正" }, { "水到渠成", "不必催促" }, { "先机渐明", "小友当慎" },
      { "棋筋已得", "后势可期" }, { "厚势初成", "胜机自现" },
    },
    panicked = {
      { "好一记妙手", "老夫须慎思" }, { "局势逆转", "不可轻言弃" }, { "小友攻得紧", "且容我守一守" },
      { "此处失算", "尚可寻转机" }, { "风声渐急", "更当定心" },
    },
    capture = {
      { "此子当弃", "莫乱阵脚" }, { "取舍有道", "守住本心" }, { "舍小取势", "方见全局" },
      { "此子暂收", "后着更要紧" },
    },
    check = {
      { "将军", "可有妙解" }, { "将门受制", "小友请解" }, { "锋芒已至", "当如何应对" },
    },
    win = {
      { "棋局已定", "善弈者复盘" }, { "一局终了", "得失皆可鉴" },
    },
  },
}

local function set_ai_dialogue(s, kind)
  local profile = AI_DIALOGUES[s.difficulty or 1] or AI_DIALOGUES[1]
  local pool = profile[kind] or profile.thinking
  s.ai_dialog_counts = s.ai_dialog_counts or {}
  local index = ((s.ai_dialog_counts[kind] or 0) % #pool) + 1
  local line = pool[index]
  local key = line[1] .. "|" .. line[2]
  if #pool > 1 and key == s.ai_last_dialog_key then
    index = index % #pool + 1
    line = pool[index]
    key = line[1] .. "|" .. line[2]
  end
  s.ai_dialog_counts[kind] = index
  s.ai_last_dialog_key = key
  s.ai_dialog = { line[1], line[2] }
end

local function restart_game(s)
  cancel_ai_search()
  s.ai_pending = false
  s.ai_thinking = false
  reset_ai_clock(s)
  State.new_game(s)
  s.ai_order_hint = nil
  if s.mode == "ai" then
    s.ai_mood = "thinking"
    set_ai_dialogue(s, "start")
  else
    s.ai_mood = nil
    s.ai_dialog = nil
  end
end

local function start_pvp(s)
  s.mode = "pvp"
  restart_game(s)
  s.screen = "game"
end

local function start_ai(s)
  s.mode = "ai"
  restart_game(s)
  s.screen = "game"
end

local function go_prev(s)
  cancel_ai_search()
  s.ai_pending = false
  s.ai_thinking = false
  reset_ai_clock(s)
  s.screen = "menu"
end

-- 玩家落子后若轮到 AI 且为人机模式，则让 AI 走一步
local function run_ai(s, mv)
  if s.screen ~= "game" or s.mode ~= "ai" then return false end
  if s.turn ~= "b" or s.status ~= "playing" then return false end
  if not mv then return false end
  local captured = State.piece_at(s, mv.tr, mv.tc)
  State.apply_move(s, mv.r, mv.c, mv.tr, mv.tc)
  s.ai_last_move = { fr = mv.r, fc = mv.c, tr = mv.tr, tc = mv.tc }
  local mood = AI.mood(s)
  local dialogue_kind = mood
  if s.status == "black_win" then dialogue_kind = "win"
  elseif s.in_check then dialogue_kind = "check"
  elseif captured ~= State.EMPTY then dialogue_kind = "capture" end
  set_ai_dialogue(s, dialogue_kind)
  s.ai_mood = mood
  return true
end

local function game_tap(s, r, c)
  if ((s.mode == "ai" and s.turn == "r") or s.mode == "pvp") and s.selR
    and State.is_legal(s, s.selR, s.selC, r, c) then
    State.push_undo(s)
  end
  return State.tap(s, r, c)
end

local function undo_game_turn(s)
  cancel_ai_search()
  s.ai_pending = false
  s.ai_thinking = false
  reset_ai_clock(s)
  if not State.undo(s) then
    s.message = "暂无可悔棋步"
    return true
  end
  s.ai_order_hint = nil
  s.status = "playing"
  if s.mode == "pvp" then
    s.message = (s.turn == "r") and "已悔棋 · 红方走棋" or "已悔棋 · 黑方走棋"
    return true
  end
  s.turn = "r"
  s.message = "已悔棋 · 红方走棋"
  s.ai_mood = "thinking"
  set_ai_dialogue(s, "thinking")
  return true
end

local function offer_draw(s)
  if s.status ~= "playing" then return false end
  s.selR, s.selC = nil, nil
  cancel_ai_search()
  s.ai_pending = false
  s.ai_thinking = false
  reset_ai_clock(s)
  s.status = "draw"
  s.message = "双方议和 · 和棋"
  if s.mode == "ai" then
    s.ai_mood = "thinking"
    s.ai_dialog = { "这一局旗鼓相当", "就此言和吧" }
  end
  return true
end

local function handle_key(s, l, key)
  if s.screen == "menu" then
    if key == "up" or key == "down" then
      if key == "down" then s.menuIdx = (s.menuIdx % 3) + 1
      else s.menuIdx = ((s.menuIdx - 2) % 3) + 1 end
      return true
    elseif key == "ok" then
      if s.menuIdx == 1 then s.screen = "setup"
      else start_pvp(s) end
      return true
    elseif key == "back" then
      return false
    end
    return false
  elseif s.screen == "setup" then
    if key == "up" or key == "down" then
      s.setupIdx = View.next_setup_index(s.setupIdx, key == "down" and 1 or -1)
      return true
    elseif key == "ok" then
      if s.setupIdx == 4 then
        start_ai(s)
      elseif not View.setup_locked(s.setupIdx) then
        s.difficulty = s.setupIdx
      end
      return true
    elseif key == "back" then
      s.screen = "menu"
      return true
    end
    return false
  end
  if s.mode == "ai" and s.ai_pending then
    if key == "back" then go_prev(s); return true end
    return false
  end
  if key == "left" then
    s.cursorC = math.max(0, s.cursorC - 1); return true
  elseif key == "right" then
    s.cursorC = math.min(8, s.cursorC + 1); return true
  elseif key == "up" then
    s.cursorR = math.max(0, s.cursorR - 1); return true
  elseif key == "down" then
    s.cursorR = math.min(9, s.cursorR + 1); return true
  elseif key == "ok" then
    if s.status ~= "playing" then
      restart_game(s)
      return true
    end
    return game_tap(s, s.cursorR, s.cursorC)
  elseif key == "back" then
    if s.selR then
      s.selR, s.selC = nil, nil
      return true
    end
    if s.screen == "game" then
      go_prev(s)
      return true
    end
    return false
  end
  return false
end

local function handle_touch(s, l, ev)
  if s.screen == "menu" then
    for i = 1, 2 do
      if View.menu_item_hit(ev, l, i) then
        s.menuIdx = i
        if i == 1 then s.screen = "setup"
        else start_pvp(s) end
        return true
      end
    end
    return false
  elseif s.screen == "setup" then
    if View.back_hit(ev, l) then s.screen = "menu"; return true end
    for i = 1, 4 do
      if View.setup_item_hit(ev, l, i) then
        if i == 4 then
          start_ai(s)
        elseif not View.setup_locked(i) then
          s.setupIdx = i
          s.difficulty = i
        end
        return true
      end
    end
    return false
  end
  -- 对局界面：先处理左上角返回
  if View.back_hit(ev, l) then
    go_prev(s)
    return true
  end
  if s.mode == "ai" and s.ai_pending then return false end
  if s.mode == "ai" or s.mode == "pvp" then
    local action = View.game_action_at(ev, l)
      or (s.mode == "pvp" and View.game_action_at(ev, l, l.opponent_action_y))
    if action == "undo" then return undo_game_turn(s) end
    if action == "draw" then return offer_draw(s) end
  end
  if View.button_hit(ev, l) then
    restart_game(s)
    return true
  end
  local r, c = View.cell_at(ev, l)
  if r and c and s.status == "playing" then
    return game_tap(s, r, c)
  end
  return false
end

function M.start(ctx)
  local s = State.get(ctx)
  Opening.bind(ctx)
  if ctx.clock then
    pcall(math.randomseed, ctx.clock:millis())
  end
  ctx:set_tick(0)
end

function M.enter(ctx)
  State.get(ctx)
  ctx:invalidate()
end

function M.input(ctx, ev)
  local s = State.get(ctx)
  local l = View.layout(ctx, s.mode)
  local menu_back_key = ev.type == "key" and ev.key == "back"
  local menu_back_touch = (ev.type == "pointer" and ev.phase == "up")
    and (ev.gesture == "tap" or ev.gesture == "long")
    and View.back_hit(ev, l)
  if s.screen == "menu" and (menu_back_key or menu_back_touch) then
    ctx:quit()
    return true
  end
  local changed = false
  if ev.type == "key" then
    changed = handle_key(s, l, ev.key)
  elseif (ev.type == "pointer" and ev.phase == "up") then
    if ev.gesture == "tap" or ev.gesture == "long" then
      changed = handle_touch(s, l, ev)
    end
  end
  if changed then
    if s.screen == "game" and s.mode == "ai" and s.turn == "b" and s.status == "playing" then
      s.ai_pending = true
      s.ai_thinking = true
      reset_ai_clock(s)
      set_ai_dialogue(s, "thinking")
      ctx:set_tick(50)
    elseif not s.ai_pending then
      ctx:set_tick(0)
    end
    ctx:invalidate()
    ctx:invalidate()
  end
  return changed
end

function M.tick(ctx, _dt_ms)
  local s = State.get(ctx)
  if not s.ai_pending then
    if s.screen == "game" and s.status == "playing" and s.in_check then
      s.check_anim_t = (s.check_anim_t or 0) + (_dt_ms or 0)
      ctx:set_tick(100)
      ctx:invalidate()
      ctx:invalidate()
    elseif s.check_anim_t then s.check_anim_t = nil; ctx:set_tick(0) end
    return
  end
  local now = ctx.clock:millis()
  if not s.ai_think_started_ms then s.ai_think_started_ms = now end
  s.ai_think_elapsed_ms = math.max(0, now - s.ai_think_started_ms)
  s.ai_think_display_seconds = math.floor(s.ai_think_elapsed_ms / 1000)
  -- 固件片长为 11 秒，但应用不能把它当计算预算。AI 每 1 秒续片，
  -- 单次决策最多计算 2 秒；预算到后策略返回当前最佳合法着。
  local began, begin_err = Watchdog.begin(ctx, { feed_interval_ms = 1000, max_runtime_ms = 2000 })
  if began ~= true then error("watchdog start failed: " .. tostring(begin_err or "disabled"), 0) end
  local ok, result = pcall(function()
    if not ai_search then
      ai_search = AI.begin(s, Watchdog)
    end
    local result
    repeat
      result = AI.step(ai_search, function() return ctx.clock:millis() end, _dt_ms, Watchdog)
    until result.done
    return result
  end)
  Watchdog.finish()
  -- 固件 watchdog/time budget 错误是普通 Lua error，内层 pcall 能捕获；
  -- 必须原样抛回宿主，绝不能吞掉后 feed 再继续。
  if not ok then
    cancel_ai_search()
    error(result, 0)
  end
  if result.stats and result.stats.book_out then s.book_out = true end
  local line = result.stats and AI.format_diagnostics(result.stats)
  if line and ctx.log then ctx.log:info(line) end
  s.ai_order_hint = result.order_hint
  local ai_moved = run_ai(s, result.move)
  cancel_ai_search()
  s.ai_pending = false
  s.ai_thinking = false
  reset_ai_clock(s)
  ctx:set_tick(0)
  if ai_moved then
    ctx:invalidate()
    ctx:invalidate()
  end
end

function M.unload(ctx)
  cancel_ai_search()
  ctx.state.chess = nil
end

function M.draw(ctx, g)
  local s = State.get(ctx)
  View.draw(ctx, g, s)
end

return M
