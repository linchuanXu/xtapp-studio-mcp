-- 八卦专注时钟 / Bagua Focus Timer
-- 八格连续累加，每格5分钟；乾固定在12点，顺时针乾→兑→离→震→巽→坎→艮→坤。
-- 颜色：0=白 15=黑

local BLACK = 15
local WHITE = 0

local MAX_SEL = 8
local MINS_PER = 5
local DBL_TAP_MS = 500
local RING_THICK = 3   -- 圆环线宽

local NAMES = { "乾", "兑", "离", "震", "巽", "坎", "艮", "坤" }
local YAO = {
  {1,1,1}, {0,1,1}, {1,0,1}, {0,0,1},
  {1,1,0}, {0,1,0}, {1,0,0}, {0,0,0},
}

-- ── 状态 ──────────────────────────────
local function S(ctx)
  ctx.state.bagua = ctx.state.bagua or {}
  local s = ctx.state.bagua
  if s.n        == nil then s.n        = 0 end
  if s.phase    == nil then s.phase    = "idle" end
  if s.mins     == nil then s.mins     = 0 end
  if s.end_s    == nil then s.end_s    = nil end
  if s.last     == nil then s.last     = nil end
  if s._dt_si   == nil then s._dt_si   = nil end
  if s._dt_ms   == nil then s._dt_ms   = 0 end
  return s
end

-- ── 几何 ──────────────────────────────
local function G(ctx)
  local sw, sh = ctx.screen.width, ctx.screen.height
  local side = math.min(sw, sh)
  local cx = math.floor(sw / 2)
  local cy = math.floor(sh * 0.45)
  local or_ = math.floor(side * 0.43)
  local ir  = math.floor(or_ * 0.38)
  return { cx=cx, cy=cy, or_=or_, ir=ir, sw=sw, sh=sh }
end

-- ── 粗环：叠加同心 stroke 圆 ──
local function thick_ring(g, cx, cy, r, color)
  for d = 0, RING_THICK - 1 do
    g:circle(cx, cy, r - d, "stroke", color)
  end
end

-- ── 扇区索引（乾=0 在 12 点） ──
local function sector_index(geo, x, y)
  local dx, dy = x - geo.cx, y - geo.cy
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < geo.ir or dist > geo.or_ then return nil end
  local ang = math.atan(dy, dx)
  ang = ang + math.pi/2
  if ang < 0 then ang = ang + math.pi * 2 end
  return math.floor((ang + math.pi/8) / (math.pi/4)) % 8
end

-- ── 填充扇形 ──
local function fill_sector(g, geo, a0, a1, color)
  local step = 0.018
  local a = a0
  while a <= a1 do
    local ca, sa = math.cos(a), math.sin(a)
    g:line(
      math.floor(geo.cx + geo.ir * ca),
      math.floor(geo.cy + geo.ir * sa),
      math.floor(geo.cx + geo.or_ * ca),
      math.floor(geo.cy + geo.or_ * sa),
      color)
    a = a + step
  end
end

-- ── 手绘爻线 ──
local function draw_yao(g, geo, i, fg)
  local mid = -math.pi/2 + i * math.pi/4
  local bw  = geo.or_ - geo.ir
  local sr  = geo.ir + bw * 0.52
  local px  = geo.cx + sr * math.cos(mid)
  local py  = geo.cy + sr * math.sin(mid)

  local tan_ang = mid + math.pi/2
  local ctx_t, sty = math.cos(tan_ang), math.sin(tan_ang)

  local half_w  = math.max(11, math.floor(bw * 0.31))
  local gap     = math.max(3,  math.floor(half_w * 0.30))
  local spacing = math.max(5, math.floor(bw * 0.135))

  local cr, sr2 = math.cos(mid), math.sin(mid)
  local p = YAO[i+1]

  for row = 1, 3 do
    local off = (2 - row) * spacing
    local lx = px + off * cr
    local ly = py + off * sr2

    if p[row] == 1 then
      g:line(
        math.floor(lx - half_w * ctx_t), math.floor(ly - half_w * sty),
        math.floor(lx + half_w * ctx_t), math.floor(ly + half_w * sty),
        fg)
    else
      g:line(
        math.floor(lx - half_w * ctx_t), math.floor(ly - half_w * sty),
        math.floor(lx - gap * ctx_t),    math.floor(ly - gap * sty),
        fg)
      g:line(
        math.floor(lx + gap * ctx_t),    math.floor(ly + gap * sty),
        math.floor(lx + half_w * ctx_t), math.floor(ly + half_w * sty),
        fg)
    end
  end
end

-- ── 工具 ──
local function text_width(s)
  local w = 0
  for _ in string.gmatch(s, "[\1-\127]") do w = w + 8 end
  for _ in string.gmatch(s, "[\194-\253]") do w = w + 16 end
  return w
end

local function ct(g, cx, y, t, c)
  g:text(math.floor(cx - text_width(t)/2), y, t, {color = c})
end

local function wall_clock(ctx)
  local clock = ctx.sys and ctx.sys:clock()
  if not clock or clock.valid ~= true or clock.hour == nil or clock.minute == nil then return nil end
  return clock
end

local function hhmm(ctx)
  local clock = wall_clock(ctx)
  if not clock then return "--:--" end
  return string.format("%02d:%02d", clock.hour, clock.minute)
end

local function mmss(sec)
  local v = math.max(0, math.floor(sec or 0))
  return string.format("%02d:%02d", math.floor(v / 60), v % 60)
end

local function remaining(ctx, s)
  local now = ctx.sys:local_sec()
  if now and s.end_s then return math.max(0, s.end_s - now) end
  return 0
end

-- ══════════════════════════════════════
--  生命周期
-- ══════════════════════════════════════

function on_load(ctx)
  S(ctx)
  ctx:set_tick_rate("normal")
end

function on_enter(ctx)
  ctx:invalidate()
end

function on_tick(ctx, _dt)
  local s = S(ctx)
  if s.phase == "focusing" then
    local r = remaining(ctx, s)
    if r <= 0 then
      s.phase = "finished"
      s.last = nil
      ctx:invalidate()
    elseif r ~= s.last then
      s.last = r
      ctx:invalidate()
    end
  elseif s.phase == "idle" then
    local clock = wall_clock(ctx)
    local minute = clock and (clock.hour * 60 + clock.minute) or nil
    if minute and minute ~= s.last then
      s.last = minute
      ctx:invalidate()
    end
  end
end

function on_input(ctx, ev)
  local s = S(ctx)
  local geo = G(ctx)

  -- 完成弹框
  if s.phase == "finished" then
    if (ev.type == "key" and ev.state == "down" and ev.key == "ok")
       or (ev.type == "touch" and ev.gesture == "tap") then
      s.n = 0; s.mins = 0; s.end_s = nil; s.last = nil
      s.phase = "idle"
      s._dt_si = nil; s._dt_ms = 0
      ctx:invalidate()
      return true
    end
    return true
  end

  -- 专注中锁定
  if s.phase == "focusing" then return true end

  -- 按键
  if ev.type == "key" and ev.state == "down" then
    if ev.key == "right" and s.n < MAX_SEL then
      s.n = s.n + 1; s._dt_si = nil; ctx:invalidate(); return true
    elseif ev.key == "left" and s.n > 0 then
      s.n = s.n - 1; s._dt_si = nil; ctx:invalidate(); return true
    elseif ev.key == "ok" and s.n > 0 then
      s.phase = "focusing"
      s.mins = s.n * MINS_PER
      local now = ctx.sys:local_sec()
      s.end_s = now and (now + s.mins * 60) or nil
      s.last = s.mins * 60
      s._dt_si = nil; s._dt_ms = 0
      ctx:invalidate(); return true
    elseif ev.key == "back" and s.n > 0 then
      s.n = 0; s.last = nil; s._dt_si = nil; s._dt_ms = 0
      ctx:invalidate(); return true
    end
    return false
  end

  -- 触摸
  if ev.type == "touch" then
    if ev.gesture == "swipe_right" and s.n < MAX_SEL then
      s.n = s.n + 1; s._dt_si = nil; ctx:invalidate(); return true
    elseif ev.gesture == "swipe_left" and s.n > 0 then
      s.n = s.n - 1; s._dt_si = nil; ctx:invalidate(); return true
    end

    if ev.gesture == "tap" then
      local si = sector_index(geo, ev.x, ev.y)

      if si ~= nil then
        -- 单击下一个待选扇区 → 添加
        if si == s.n and s.n < MAX_SEL then
          s.n = s.n + 1
          s._dt_si = nil
          ctx:invalidate()
          return true
        end

        -- 双击最后一个已选扇区 → 撤销
        if si == s.n - 1 then
          local now_ms = ctx.sys:uptime_ms()
          if s._dt_si == si and (now_ms - s._dt_ms) < DBL_TAP_MS then
            s.n = s.n - 1
            s._dt_si = nil
            s._dt_ms = 0
            ctx:invalidate()
            return true
          else
            s._dt_si = si
            s._dt_ms = now_ms
            return true
          end
        end

        s._dt_si = nil
        return false
      end

      -- 点中央 → 开始专注
      s._dt_si = nil
      local dx, dy = ev.x - geo.cx, ev.y - geo.cy
      if dx * dx + dy * dy <= geo.ir * geo.ir and s.n > 0 then
        s.phase = "focusing"
        s.mins = s.n * MINS_PER
        local now = ctx.sys:local_sec()
        s.end_s = now and (now + s.mins * 60) or nil
        s.last = s.mins * 60
        ctx:invalidate()
        return true
      end
    end

    return false
  end

  return false
end

-- ══════════════════════════════════════
--  绘制
-- ══════════════════════════════════════

function on_draw(ctx, g)
  local s   = S(ctx)
  local geo = G(ctx)

  g:clear(WHITE)

  -- ═══ 八扇区 ═══
  for i = 0, 7 do
    local a0 = -math.pi/2 - math.pi/8 + i * math.pi/4
    local a1 = a0 + math.pi/4
    local sel = i < s.n
    local bg = sel and BLACK or WHITE
    local fg = sel and WHITE or BLACK

    fill_sector(g, geo, a0, a1, bg)

    -- 扇区分隔线
    local ca0, sa0 = math.cos(a0), math.sin(a0)
    g:line(
      math.floor(geo.cx + geo.ir * ca0),
      math.floor(geo.cy + geo.ir * sa0),
      math.floor(geo.cx + geo.or_ * ca0),
      math.floor(geo.cy + geo.or_ * sa0),
      BLACK)

    -- 卦名
    local mid = a0 + math.pi/8
    local bw  = geo.or_ - geo.ir
    local nr  = geo.ir + bw * 0.78
    local nx  = math.floor(geo.cx + nr * math.cos(mid))
    local ny  = math.floor(geo.cy + nr * math.sin(mid))
    g:text(nx - 8, ny - 8, NAMES[i+1], {color = fg})

    -- 爻象
    draw_yao(g, geo, i, fg)
  end

  -- 闭合分隔线
  local a_last = -math.pi/2 - math.pi/8 + 8 * math.pi/4
  local ca, sa = math.cos(a_last), math.sin(a_last)
  g:line(
    math.floor(geo.cx + geo.ir * ca),
    math.floor(geo.cy + geo.ir * sa),
    math.floor(geo.cx + geo.or_ * ca),
    math.floor(geo.cy + geo.or_ * sa),
    BLACK)

  -- 内圆填充（先填白再画粗环）
  g:circle(geo.cx, geo.cy, geo.ir, "fill", WHITE)

  -- 粗环：外圈 + 内圈
  thick_ring(g, geo.cx, geo.cy, geo.or_, BLACK)
  thick_ring(g, geo.cx, geo.cy, geo.ir,  BLACK)

  -- ═══ 中央时间 ═══
  if s.phase == "focusing" then
    ct(g, geo.cx, geo.cy - 8, mmss(remaining(ctx, s)), BLACK)
  elseif s.phase == "finished" then
    ct(g, geo.cx, geo.cy - 8, "00:00", BLACK)
  else
    ct(g, geo.cx, geo.cy - 8, hhmm(ctx), BLACK)
  end

  -- ═══ 底部提示 ═══
  local hint
  if s.phase == "focusing" then
    hint = "专注中 · " .. s.mins .. " 分钟"
  elseif s.n == 0 then
    hint = "点击选中*从乾开始*双击取消"
  else
    hint = "点中央开始 · " .. (s.n * MINS_PER) .. " 分钟"
  end
  ct(g, geo.cx, geo.sh - 40, hint, BLACK)

  -- ═══ 完成弹框 ═══
  if s.phase == "finished" then
    local pw = math.floor(geo.sw * 0.82)
    local ph = 150
    local px = math.floor((geo.sw - pw) / 2)
    local py = math.floor((geo.sh - ph) / 2)

    g:rect(px, py, pw, ph, "fill", BLACK)
    g:rect(px, py, pw, ph, "stroke", WHITE)

    local msg = "恭喜，今天又专注了 " .. s.mins .. " 分钟"
    ct(g, geo.cx, py + 40, msg, WHITE)

    local bw_btn = math.floor(pw * 0.44)
    local bh_btn = 38
    local bx = math.floor((geo.sw - bw_btn) / 2)
    local by = py + 88
    g:rect(bx, by, bw_btn, bh_btn, "stroke", WHITE)
    ct(g, geo.cx, by + 10, "确定", WHITE)
  end
end
