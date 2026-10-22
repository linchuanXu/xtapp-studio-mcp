-- DeepSeek 聊天：仿豆包的气泡界面。自己的话在右边黑底气泡里，回答铺在左边；
-- 底部圆角输入条停靠系统键盘，回车或点发送键发出；回答用实验接口 ctx.net:request 的 on_data 流式显示。
-- 上 / 下键或上下滑动翻看记录；回答时按返回键或点停止键停下。记录和密钥存在 ctx.state 里。
-- 第一次打开先让用户填写自己的 DeepSeek 密钥，密钥只留在这台设备上。
local API_URL = "https://api.deepseek.com/chat/completions"
local MODEL = "deepseek-chat"
local SYSTEM = "你在一台黑白墨水屏的小阅读器上和用户聊天。回答简洁、口语化，用纯文本："
  .. "不要用 Markdown（不要 #、**、表格、代码块），列表用「1.」或「·」开头。"
local HISTORY = 12          -- 发给模型的最近几条
local SAVE_MAX = 7000       -- 存进 ctx.state 的记录字节数（JSON 上限 16384，留出转义的余量）
local SUGGEST = { "给我讲个冷笑话", "推荐一本睡前读的书", "用三句话解释量子纠缠" }

local PAD = 16
local GAP = 20              -- 消息之间
local BAR_H = 64            -- 输入条高
local BUBBLE_TEXT = 320     -- 气泡里文字最宽

local W, H, KH, FONT, BIG, LH, ROW
local msgs = {}             -- { role = "user" / "assistant" / "note", content = "" }
local ed, draft = nil, ""
local job, sse, answer = nil, "", nil
local scroll = 0            -- 离最新内容多少像素，0 表示贴着底部
local last_total = 0
local redraw_due = false
local hits = {}             -- 这一帧能点的地方
local api_key = ""
local setup = false         -- 正在填写密钥
local key_ed, key_draft = nil, ""

-- 布局 ---------------------------------------------------------------

local function bar_y()
  return ed and (H - KH - BAR_H - 10) or (H - BAR_H - 14)
end

local function chat_area()
  return 64, bar_y() - 8
end

local function clean(s)
  s = s:gsub("%*%*", ""):gsub("```%w*", ""):gsub("`", "")
  s = s:gsub("\n#+[ \t]*", "\n"):gsub("^#+[ \t]*", "")
  s = s:gsub("\n[ \t]*[-*][ \t]+", "\n· "):gsub("^[ \t]*[-*][ \t]+", "· ")
  return s
end

-- 折成一行一行；正文只在末尾增长时沿用前面的行，只重排最后一行。
local function view_of(m, w)
  local src = m.role == "assistant" and clean(m.content) or m.content
  local v = m.view
  if v and v.w == w and v.src == src then return v end
  local lines, starts, from = {}, {}, 1
  if v and v.w == w and #v.lines > 0 and src:sub(1, #v.src) == v.src then
    lines, starts = v.lines, v.starts
    from = starts[#starts]
    lines[#lines], starts[#starts] = nil, nil
  end
  while from <= #src do
    local rest = src:sub(from)
    local _, _, used = FONT:layout(rest, w, LH, { wrap = "word" })
    if not used or used <= 0 then used = (utf8.offset(rest, 2) or (#rest + 1)) - 1 end
    starts[#starts + 1] = from
    lines[#lines + 1] = (rest:sub(1, used):gsub("\n$", ""))
    from = from + used
  end
  v = { w = w, src = src, lines = lines, starts = starts }
  m.view = v
  return v
end

local function layout_all()
  local blocks, y = {}, 0
  for _, m in ipairs(msgs) do
    local b = { m = m, y = y }
    if m.role == "user" then
      local v = view_of(m, BUBBLE_TEXT)
      if not v.tw then
        v.tw = 0
        for _, l in ipairs(v.lines) do v.tw = math.max(v.tw, FONT:measure(l)) end
      end
      b.v, b.h = v, math.max(1, #v.lines) * ROW + 20
    elseif m.role == "assistant" then
      b.v = view_of(m, W - 2 * PAD)
      b.h = math.max(1, #b.v.lines) * ROW
    else
      b.v = view_of(m, W - 2 * PAD - 40)
      b.h = #b.v.lines * ROW
    end
    blocks[#blocks + 1] = b
    y = y + b.h + GAP
  end
  return blocks, math.max(0, y - GAP)
end

local function redraw(ctx)
  -- 流式时不要每一小段都刷墨水屏：最多 0.4 秒一次。
  if redraw_due then return end
  redraw_due = true
  ctx:after(400, function(c) redraw_due = false; c:invalidate() end)
end

-- 记录 ---------------------------------------------------------------

local function persist(ctx)
  local out, size = {}, 0
  for i = #msgs, 1, -1 do
    local m = msgs[i]
    if m.role ~= "note" and m ~= answer then
      size = size + #m.content + 24
      if size > SAVE_MAX then break end
      table.insert(out, 1, { r = m.role == "user" and "u" or "a", c = m.content })
    end
  end
  ctx.state.msgs = out
end

local function note(text)
  msgs[#msgs + 1] = { role = "note", content = text }
end

-- 联网 ---------------------------------------------------------------

local function on_sse(ctx, chunk)
  sse = sse .. chunk
  while true do
    local nl = sse:find("\n", 1, true)
    if not nl then break end
    local line = sse:sub(1, nl - 1):gsub("\r$", "")
    sse = sse:sub(nl + 1)
    local data = line:match("^data:%s?(.*)$")
    if data and data ~= "[DONE]" then
      local obj = ctx.json:decode(data)
      local ch = obj and obj.choices and obj.choices[1]
      local piece = ch and ch.delta and ch.delta.content
      if type(piece) == "string" and answer then
        answer.content = answer.content .. piece
      end
    end
  end
  redraw(ctx)
end

local HTTP_HINT = { [401] = "key 无效", [402] = "余额不足", [429] = "请求太频繁", [500] = "服务器出错", [503] = "服务器繁忙" }

local open_edit
local open_key_edit

local function send(ctx, text)
  local history = { { role = "system", content = SYSTEM } }
  local recent = {}
  for i = #msgs, 1, -1 do
    local m = msgs[i]
    if m.role ~= "note" then table.insert(recent, 1, { role = m.role, content = m.content }) end
    if #recent >= HISTORY then break end
  end
  for _, m in ipairs(recent) do history[#history + 1] = m end
  history[#history + 1] = { role = "user", content = text }
  local body = ctx.json:encode({ model = MODEL, messages = history, stream = true })
  sse = ""
  local j, err = ctx.net:request({
    url = API_URL,
    method = "POST",
    headers = {
      ["content-type"] = "application/json",
      ["authorization"] = "Bearer " .. api_key,
      ["accept"] = "text/event-stream",
    },
    body = body,
    on_data = on_sse,
  }, function(c, res)
    job = nil
    if res.ok and res.status == 200 then
      on_sse(c, "\n")
      if answer and answer.content == "" then answer.content = "（没有内容）" end
    else
      local why
      if res.status then
        why = "HTTP " .. res.status .. (HTTP_HINT[res.status] and ("，" .. HTTP_HINT[res.status]) or "")
      elseif res.err == "no_network" then
        why = "没联网，先在设置里连 Wi-Fi"
      elseif res.err == "io_error" and not c.clock:now().valid then
        why = "时钟没校准，先联网校时"
      else
        why = tostring(res.err)
      end
      local bad_key = res.status == 401
      if answer and answer.content == "" then
        table.remove(msgs)            -- 去掉空回答
        table.remove(msgs)            -- 和这次提问，放回输入框方便重发
        if bad_key then
          if ed then ed:close(); ed = nil end
          draft = text
        elseif ed then
          local cur = ed:close()
          ed = nil
          draft = (cur and cur ~= "") and cur or text
          open_edit(c)
        else
          draft = text
        end
      end
      note("出错：" .. why)
      if bad_key then open_key_edit(c) end
    end
    answer = nil
    persist(c)
    c:save_state()
    c:invalidate()
  end)
  if not j then
    note("发不出去：" .. tostring(err))
    ctx:invalidate()
    return false
  end
  job = j
  msgs[#msgs + 1] = { role = "user", content = text }
  answer = { role = "assistant", content = "" }
  msgs[#msgs + 1] = answer
  scroll = 0
  ctx:invalidate()
  return true
end

local function submit(ctx, text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return false end
  if api_key == "" then
    open_key_edit(ctx)
    return false
  end
  if job then
    ctx.dialog:toast("等这条回答完")
    return false
  end
  return send(ctx, text)
end

local function stop(ctx)
  if not job then return end
  job:cancel()
  job = nil
  if answer and answer.content == "" then answer.content = "（已停止）" end
  answer = nil
  persist(ctx)
  ctx:invalidate()
end

local function new_chat(ctx)
  stop(ctx)
  msgs, scroll = {}, 0
  persist(ctx)
  ctx:save_state()
  ctx:invalidate()
end

local function send_button(ctx)
  if job then return stop(ctx) end
  local t = ed and ed:text() or draft
  if submit(ctx, t) then
    draft = ""
    if ed then ed:set_text("") end
  elseif not ed and not setup then
    open_edit(ctx)
  end
end

open_edit = function(ctx)
  local by = H - KH - BAR_H - 10
  local err
  ed, err = ctx.input:edit({
    rect = { x = PAD + 14, y = by + 18, w = W - 2 * PAD - 14 - 64, h = BAR_H - 30 },
    text = draft, multiline = true, enter = "done", max_chars = 512,
    placeholder = "发消息…",
    on_change = function(c, t) draft = t end,
    on_end = function(c, t, how)
      ed = nil
      draft = t
      if how == "enter" then
        if submit(c, t) then draft = "" end
        open_edit(c)
      end
      c:invalidate()
    end,
  })
  if not ed then note("输入框打不开：" .. tostring(err)) end
  ctx:invalidate()
end

local function key_ok(text)
  text = (text or ""):gsub("%s+", "")
  if text == "" then return nil, "先填写密钥" end
  if not text:find("^sk%-") or #text < 12 or #text > 128 or text:find("[^%w%-_]") then
    return nil, "密钥应以 sk- 开头"
  end
  return text
end

local function save_key(ctx, text)
  local key, why = key_ok(text)
  if not key then
    ctx.dialog:toast(why)
    return false
  end
  api_key = key
  ctx.state.key = key
  setup = false
  key_draft = ""
  ctx:save_state()
  ctx.dialog:toast("密钥已保存在本机")
  return true
end

local function key_rect()
  local w, h = W - 2 * PAD, 56
  local y = (KH > 0) and (H - KH - h - 16) or (H // 2 - h // 2)
  if y < 96 then y = 96 end
  return PAD, y, w, h
end

open_key_edit = function(ctx)
  if ed then
    draft = ed:close() or draft
    ed = nil
  end
  setup = true
  local x, y, w, h = key_rect()
  local err
  key_ed, err = ctx.input:edit({
    rect = { x = x + 16, y = y + 10, w = w - 32, h = h - 20 },
    text = key_draft,
    kind = "secret",
    enter = "save",
    max_chars = 128,
    placeholder = "sk-…",
    on_change = function(_, t) key_draft = t end,
    on_end = function(c, t, how)
      key_ed = nil
      key_draft = t or ""
      if how == "enter" then
        if save_key(c, key_draft) then
          open_edit(c)
        else
          open_key_edit(c)
        end
      elseif api_key ~= "" then
        setup = false
        key_draft = ""
        open_edit(c)
      end
      c:invalidate()
    end,
  })
  if not key_ed then note("密钥框打不开：" .. tostring(err)) end
  ctx:invalidate()
end

local function change_key(ctx)
  if job then
    ctx.dialog:toast("等这条回答完")
    return
  end
  key_draft = ""
  open_key_edit(ctx)
end

local function mask(s)
  local n = utf8.len(s)
  if not n then n = #s end
  return string.rep("*", n)
end

-- 生命周期 -----------------------------------------------------------

function on_load(ctx)
  W, H = ctx.screen.width, ctx.screen.height
  KH = ctx.input.keyboard_h or 0
  FONT, BIG = ctx.fonts.medium, ctx.fonts.large
  LH = FONT.line_height
  ROW = LH + 4
  for _, s in ipairs(ctx.state.msgs or {}) do
    if type(s) == "table" and type(s.c) == "string" then
      msgs[#msgs + 1] = { role = s.r == "u" and "user" or "assistant", content = s.c }
    end
  end
  local saved = ctx.state.key
  api_key = (type(saved) == "string") and saved:gsub("%s+", "") or ""
  if api_key == "" then
    open_key_edit(ctx)
  else
    open_edit(ctx)
  end
end

function on_leave(ctx)
  persist(ctx)
end

local function page()
  local top, bottom = chat_area()
  return math.floor((bottom - top) * 0.75)
end

function on_input(ctx, ev)
  if ev.type == "key" then
    if ev.key == "back" then
      -- 只看 up：回答中按返回停止，否则交给宿主弹退出确认。
      if ev.phase ~= "up" then return true end
      if setup then
        if api_key ~= "" then
          setup = false
          key_draft = ""
          if key_ed then key_ed:close(); key_ed = nil end
          open_edit(ctx)
          return true
        end
        return false
      end
      if job then stop(ctx); return true end
      return false
    end
    if setup then
      if ev.phase == "down" and ev.key == "ok" and not key_ed then
        if save_key(ctx, key_draft) then open_edit(ctx) else open_key_edit(ctx) end
      end
      return true
    end
    if ev.phase ~= "down" then return true end
    if ev.key == "up" or ev.key == "left" then
      scroll = scroll + page(); ctx:invalidate()
    elseif ev.key == "down" or ev.key == "right" then
      scroll = math.max(0, scroll - page()); ctx:invalidate()
    elseif ev.key == "ok" and not ed then
      open_edit(ctx)
    end
    return true
  end
  if ev.type == "pointer" and ev.phase == "up" then
    if not setup and ev.gesture == "swipe_up" then
      scroll = math.max(0, scroll - page()); ctx:invalidate()
    elseif not setup and ev.gesture == "swipe_down" then
      scroll = scroll + page(); ctx:invalidate()
    else
      for i = #hits, 1, -1 do
        local h = hits[i]
        if ev.x >= h.x and ev.x < h.x + h.w and ev.y >= h.y and ev.y < h.y + h.h then
          h.fn(ctx)
          break
        end
      end
    end
  end
  return true
end

-- 绘制 ---------------------------------------------------------------

local function hit(x, y, w, h, fn)
  hits[#hits + 1] = { x = x, y = y, w = w, h = h, fn = fn }
end

local function draw_welcome(ctx, g, top, bottom)
  local logo = bottom - top > 380
  local total = (logo and 76 or 0) + BIG.line_height + 8 + LH + 24 + #SUGGEST * 52 - 12
  local y = top + math.max(0, (bottom - top - total) // 2)
  if logo then
    g:circle(W // 2, y + 30, 30, { fill = true })
    g:text(W // 2, y + 30, "D", { font = BIG, color = 0, align = "center", valign = "middle" })
    y = y + 76
  end
  g:text(W // 2, y, "你好，我是 DeepSeek", { font = BIG, align = "center" })
  y = y + BIG.line_height + 8
  g:text(W // 2, y, "有什么可以帮你？", { font = FONT, align = "center" })
  y = y + LH + 24
  for _, s in ipairs(SUGGEST) do
    local w = FONT:measure(s) + 40
    local x = (W - w) // 2
    g:rect(x, y, w, 40, { radius = 20, line_width = 2 })
    g:text(W // 2, y + 20, s, { font = FONT, align = "center", valign = "middle" })
    hit(x, y, w, 40, function(c) submit(c, s) end)
    y = y + 52
  end
end

local function draw_chat(ctx, g, top, bottom)
  local V = bottom - top
  local blocks, T = layout_all()
  -- 往回翻着看时新内容进来，画面不跟着跑。
  if scroll > 0 and T > last_total then scroll = scroll + (T - last_total) end
  last_total = T
  local maxs = math.max(0, T - V)
  scroll = math.max(0, math.min(scroll, maxs))
  local y0 = top - (maxs - scroll)
  for _, b in ipairs(blocks) do
    local by = y0 + b.y
    if by + b.h >= top and by <= bottom then
      local m, v = b.m, b.v
      if m.role == "user" then
        local bw = v.tw + 28
        local bx = W - PAD - bw
        g:rect(bx, by, bw, b.h, { fill = true, radius = 18 })
        for i, l in ipairs(v.lines) do
          g:text(bx + 14, by + 10 + (i - 1) * ROW + 2, l, { font = FONT, color = 0 })
        end
      elseif m.role == "assistant" then
        if #v.lines == 0 then
          g:text(PAD, by + 2, "思考中…", { font = FONT })
        end
        for i, l in ipairs(v.lines) do
          local ly = by + (i - 1) * ROW + 2
          if ly + LH >= top and ly <= bottom then g:text(PAD, ly, l, { font = FONT }) end
        end
      else
        for i, l in ipairs(v.lines) do
          g:text(W // 2, by + (i - 1) * ROW + 2, l, { font = FONT, align = "center" })
        end
      end
    end
  end
  -- 进度条
  if maxs > 0 then
    local th = math.max(24, V * V // T)
    local ty = top + (V - th) * (maxs - scroll) // maxs
    g:rect(W - 5, ty, 3, th, { fill = true })
  end
  return maxs
end

local function draw_setup(g)
  g:rect(0, 0, W, 64, { fill = true, color = 0 })
  g:text(W // 2, 30, "DeepSeek", { font = BIG, align = "center", valign = "middle" })
  g:line(0, 60, W, 60)

  local y = 88
  g:text(W // 2, y, "先填写密钥", { font = BIG, align = "center" })
  y = y + BIG.line_height + 16
  local rest = "到 platform.deepseek.com 创建 API key。密钥只存在这台设备上，用来调用 DeepSeek。"
  while rest ~= "" do
    local _, _, used = FONT:layout(rest, W - 2 * PAD, LH, { wrap = "word" })
    if not used or used <= 0 then used = #rest end
    g:text(PAD, y, (rest:sub(1, used):gsub("\n$", "")), { font = FONT })
    y = y + ROW
    rest = rest:sub(used + 1)
  end

  local x, fy, w, h = key_rect()
  g:rect(x, fy, w, h, { radius = 16, line_width = 2 })
  if not key_ed then
    local shown = key_draft ~= "" and mask(key_draft) or "sk-…"
    g:text(x + 16, fy + h // 2, shown, { font = FONT, valign = "middle" })
    hit(x, fy, w, h, open_key_edit)
  end

  local bw = FONT:measure("保存") + 48
  local bx = (W - bw) // 2
  local by = fy - 56
  if by < y + 8 then by = fy + h + 16 end
  g:rect(bx, by, bw, 40, { fill = true, radius = 20 })
  g:text(W // 2, by + 20, "保存", { font = FONT, color = 0, align = "center", valign = "middle" })
  hit(bx, by, bw, 40, function(c)
    local t = key_ed and key_ed:text() or key_draft
    if key_ed then key_ed:close(); key_ed = nil end
    if save_key(c, t) then
      open_edit(c)
    else
      open_key_edit(c)
    end
  end)
  if api_key ~= "" then
    local hint_y = (by > fy) and (by + 52) or (fy + h + 16)
    g:text(W // 2, hint_y, "返回键取消，继续用已保存的密钥", { font = FONT, align = "center" })
  end
end

function on_draw(ctx, g)
  g:clear()
  hits = {}
  if setup then
    draw_setup(g)
    return
  end
  local top, bottom = chat_area()
  local scrolled = false
  if #msgs == 0 then
    draw_welcome(ctx, g, top, bottom)
  else
    scrolled = draw_chat(ctx, g, top, bottom) > 0 and scroll > 0
  end

  -- 顶栏和输入条盖住超出聊天区的部分。
  g:rect(0, 0, W, top, { fill = true, color = 0 })
  g:rect(0, bottom, W, H - bottom, { fill = true, color = 0 })

  g:text(W // 2, 30, "DeepSeek", { font = BIG, align = "center", valign = "middle" })
  if job then
    g:text(PAD, 30, "回答中…", { font = FONT, valign = "middle" })
  else
    local kw = FONT:measure("密钥") + 24
    g:rect(PAD, 12, kw, 36, { radius = 18, line_width = 2 })
    g:text(PAD + kw // 2, 30, "密钥", { font = FONT, align = "center", valign = "middle" })
    hit(PAD - 4, 0, kw + 8, 60, change_key)
  end
  if #msgs > 0 then
    local w = FONT:measure("新对话") + 24
    g:rect(W - PAD - w, 12, w, 36, { radius = 18, line_width = 2 })
    g:text(W - PAD - w // 2, 30, "新对话", { font = FONT, align = "center", valign = "middle" })
    hit(W - PAD - w - 8, 0, w + 16, 60, new_chat)
  end
  g:line(0, 60, W, 60)

  if scrolled then
    local w = FONT:measure("回到最新") + 32
    local x, y = (W - w) // 2, bottom - 48
    g:rect(x, y, w, 38, { fill = true, radius = 19 })
    g:text(W // 2, y + 19, "回到最新", { font = FONT, color = 0, align = "center", valign = "middle" })
    hit(x, y, w, 38, function(c) scroll = 0; c:invalidate() end)
  end

  local by = bar_y()
  g:rect(PAD - 4, by, W - 2 * PAD + 8, BAR_H, { radius = 26, line_width = 2 })
  if not ed then
    local t = draft ~= "" and draft:gsub("\n", " ") or "发消息…"
    g:text_box(PAD + 14, by + 8, W - 2 * PAD - 14 - 64, BAR_H - 16, t,
      { font = FONT, valign = "middle", overflow = "ellipsis" })
    hit(0, by, W - 80, BAR_H, open_edit)
  end
  local cx, cy, r = W - PAD - 30, by + BAR_H // 2, 22
  g:circle(cx, cy, r, { fill = true })
  if job then
    g:rect(cx - 7, cy - 7, 14, 14, { fill = true, color = 0 })
  else
    g:polygon({ cx, cy - 12, cx - 10, cy - 1, cx + 10, cy - 1 }, { fill = true, color = 0 })
    g:rect(cx - 2, cy - 2, 5, 14, { fill = true, color = 0 })
  end
  hit(cx - r - 10, by, 2 * r + 20, BAR_H, send_button)
end
