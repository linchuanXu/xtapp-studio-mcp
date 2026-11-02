local PkgImage = require("pkg_image")
-- 全球市场：固定 ScriptNet GET 路由，凭据只存在服务器端。
local BLACK, WHITE = 15, 0
local API = "http://193.112.174.92:28473/demo/market/pulse/xtapp"
local DETAIL_API = "http://193.112.174.92:28473/demo/market/detail/xtapp?kind="
local KLINE_API = "http://193.112.174.92:28473/demo/market/detail/kline/xtapp?limit=40&kind="
local FOREX_KLINE_API = "http://193.112.174.92:28473/demo/market/kline/xtapp?limit=40&kind=forex"
local QUOTE_API = "http://193.112.174.92:28473/demo/market/quote/xtapp?kind="
local PROTOCOL = "XTAPP_MARKET_PULSE_V1"
local task_id = nil
local on_net_done
local task_kind = nil

local function state(ctx)
  ctx.state.market_pulse_live = ctx.state.market_pulse_live or { snapshot = nil, status = "idle" }
  return ctx.state.market_pulse_live
end

local function width(text)
  local n, i, text = 0, 1, tostring(text or "")
  while i <= #text do
    local b = text:byte(i)
    if b >= 0xE0 then n, i = n + 20, i + 3 elseif b >= 0xC0 then n, i = n + 20, i + 2 else n, i = n + 10, i + 1 end
  end
  return n
end
local function right(g, x, y, text) g:text(x - width(text), y, text, { color = BLACK }) end
local function center(g, x, y, w, text, color) g:text(x + math.max(0, math.floor((w - width(text)) / 2)), y, text, { color = color or BLACK }) end
local function price(value) local n = tonumber(value); return n and string.format("%.2f", n) or "--" end
local function signed(value) local n = tonumber(value); return n and string.format("%+.2f%%", n) or "--" end

-- 黑白屏没有字号层级，报价以数码字形承担主视觉；其余信息保持安静。
local SEGMENTS = {
  ["0"] = "ab cdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg", ["4"] = "bcfg",
  ["5"] = "acdfg", ["6"] = "acdefg", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg",
}
local function has_segment(segments, segment) return segments and segments:find(segment, 1, true) ~= nil end
local function quote_width(text)
  local total = 0
  for i = 1, #tostring(text or "") do total = total + (tostring(text):sub(i, i) == "." and 14 or 32) end
  return total
end
local function draw_quote_digit(g, x, y, char)
  local w, h, t = 26, 50, 5
  if char == "." then g:rect(x + 2, y + h - t, t, t,{fill=true,color=BLACK}); return 14 end
  local segments = SEGMENTS[char]
  if not segments then return 32 end
  if has_segment(segments, "a") then g:rect(x + 4, y, w - 8, t,{fill=true,color=BLACK}) end
  if has_segment(segments, "b") then g:rect(x + w - t, y + 5, t, 19,{fill=true,color=BLACK}) end
  if has_segment(segments, "c") then g:rect(x + w - t, y + 27, t, 19,{fill=true,color=BLACK}) end
  if has_segment(segments, "d") then g:rect(x + 4, y + h - t, w - 8, t,{fill=true,color=BLACK}) end
  if has_segment(segments, "e") then g:rect(x, y + 27, t, 19,{fill=true,color=BLACK}) end
  if has_segment(segments, "f") then g:rect(x, y + 5, t, 19,{fill=true,color=BLACK}) end
  if has_segment(segments, "g") then g:rect(x + 4, y + 23, w - 8, t,{fill=true,color=BLACK}) end
  return 32
end
local function draw_quote(g, right_x, y, value)
  local text = price(value)
  local x = right_x - quote_width(text)
  for i = 1, #text do x = x + draw_quote_digit(g, x, y, text:sub(i, i)) end
end
local function dotted_rule(g, x, y, w)
  for px = x, x + w, 10 do g:rect(px, y, 2, 2,{fill=true,color=BLACK}) end
end

local function parse(body)
  if type(body) ~= "string" or body:match("^([^\r\n]+)") ~= PROTOCOL then return nil end
  local snapshot = { rows = {}, times = {} }
  for line in body:gmatch("[^\r\n]+") do
    local market, symbol, name, last, change_rate = line:match("^market\t([^\t]+)\t([^\t]*)\t([^\t]+)\t([^\t]+)\t([^\t]+)")
    local city, clock = line:match("^time\t([^\t]+)\t([^\t]+)$")
    if market and name and tonumber(last) then snapshot.rows[#snapshot.rows + 1] = { market = market, symbol = symbol, name = name, price = last, changeRate = change_rate }
    elseif city and clock then snapshot.times[city] = clock end
  end
  return #snapshot.rows > 0 and snapshot or nil
end

local function request(ctx)
  local s = state(ctx)
  if task_id then return end
  if not ctx.net then s.status = "no_net"; ctx:invalidate(); return end
  local id, err = ctx.net:request({ url = API }, on_net_done)
  if not id then s.status = tostring(err or "error"); ctx:invalidate(); return end
  task_id, task_kind, s.status = id, "pulse", "loading"; ctx:invalidate()
end
local function request_detail(ctx, kind)
  local s = state(ctx)
  if task_id or not ctx.net then return end
  local use_detail_api = kind == "a" or kind == "us"
  local has_chart = use_detail_api or kind == "forex"
  local id, err = ctx.net:request({ url = (use_detail_api and DETAIL_API or QUOTE_API) .. kind }, on_net_done)
  s.mode, s.detail_kind, s.detail, s.candles, s.detail_has_chart = "detail", kind, nil, nil, has_chart
  if not id then s.status = tostring(err or "error"); ctx:invalidate(); return end
  task_id, task_kind, s.status = id, "detail", "detail_loading"; ctx:invalidate()
end
local function draw_kline(g, candles)
  local x,y,w,h=24,500,432,184
  if type(candles)~="table" or #candles<2 then center(g,x,y+76,w,"正在整理分时数据",BLACK); return end
  local lo,hi=nil,nil; for _,v in ipairs(candles) do lo=lo and math.min(lo,v) or v; hi=hi and math.max(hi,v) or v end
  if hi==lo then hi,lo=hi+.01,lo-.01 end
  dotted_rule(g, x, y + 20, w); dotted_rule(g, x, y + math.floor(h / 2), w); dotted_rule(g, x, y + h - 20, w)
  local px,py=nil,nil; for i,v in ipairs(candles) do local cx=x+8+math.floor((i-1)*(w-16)/(#candles-1)); local cy=y+12+math.floor((hi-v)*(h-24)/(hi-lo)); if px then g:line(px,py,cx,cy,{color=BLACK}) end; px,py=cx,cy end
end

function on_load(ctx) request(ctx) end
on_net_done = function(ctx, result)
  local finished_kind = task_kind
  task_id, task_kind = nil, nil
  local s = state(ctx)
  if finished_kind == "detail" then
    local q = {}; for line in (result.body or ""):gmatch("[^\r\n]+") do local k,v=line:match("^([^\t]+)\t(.*)$"); if k then q[k]=v end end
    s.detail = result.ok and q or nil
    if s.detail and s.detail_has_chart and ctx.net then
      local id = ctx.net:request({ url = s.detail_kind == "forex" and FOREX_KLINE_API or KLINE_API .. s.detail_kind }, on_net_done)
      if id then task_id, task_kind, s.status = id, "kline", "chart_loading"; ctx:invalidate(); return end
    end
    s.status = s.detail and "detail" or "error"
  elseif finished_kind == "kline" then
    local points={}; for line in (result.body or ""):gmatch("[^\r\n]+") do local close=line:match("^candle\t[^\t]+\t[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)"); if tonumber(close) then points[#points+1]=tonumber(close) end end
    s.candles=points; s.status="detail"
  else
    s.snapshot = result.ok and parse(result.body) or nil
    s.status = s.snapshot and "ready" or "error"
  end
  ctx:invalidate()
end
function on_leave(ctx) if task_id and ctx.net then task_id:cancel() end; task_id, task_kind = nil, nil end
function on_input(ctx, ev)
  local s = state(ctx)
  if s.mode == "detail" and ((ev.type == "key" and ev.phase == "down" and ev.key == "back") or ((ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" and ev.y < 100)) then
    if task_id and ctx.net then task_id:cancel() end
    task_id, task_kind, s.mode, s.status, s.detail, s.candles = nil, nil, nil, "ready", nil, nil
    ctx:invalidate(); return true
  end
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" then
    if ev.y >= 76 and ev.y <= 222 then request_detail(ctx,"dow")
    elseif ev.y >= 240 and ev.y <= 374 then request_detail(ctx,"nasdaq")
    elseif ev.y >= 408 and ev.y <= 488 then request_detail(ctx,"forex")
    elseif ev.y >= 502 and ev.y <= 594 then request_detail(ctx,"external")
    elseif ev.y >= 630 and ev.y <= 692 then request_detail(ctx,"hsi")
    elseif ev.y >= 720 and ev.y <= 742 then request_detail(ctx, (ev.x or 0) < 240 and "eurusd" or "usdjpy")
    elseif ev.y >= 743 then request_detail(ctx,"usdcnh")
    else return false end
    return true
  end
  if (ev.type == "key" and ev.phase == "down" and ev.key == "ok") or ((ev.type == "pointer" and ev.phase == "up") and ev.gesture == "tap" and ev.y <= 98) then request(ctx); return true end
  if ev.type == "key" and ev.phase == "down" and ev.key == "back" then ctx:quit(); return true end
  return false
end
function on_draw(ctx, g) require("pkg_image").bind(ctx);
  local s = state(ctx)
  g:clear(WHITE)
  PkgImage.draw(g, "type_title", 24, 10); right(g, 456, 28, s.status == "loading" and "更新中" or "刷新")
  if s.mode == "detail" then
    g:text(24, 62, "‹ 返回", { color = BLACK })
  end
  if s.mode == "detail" then
    if not s.detail then
      center(g, 24, 360, 432, s.status == "detail_loading" and "正在更新报价" or "暂时无法读取报价", BLACK)
      return
    end
    local q=s.detail
    g:text(24,108,q.name or "市场报价",{color=BLACK}); right(g,456,108,q.symbol or "")
    draw_quote(g,456,144,q.price); right(g,440,216,signed(q.changeRate))
    dotted_rule(g,24,258,432)
    g:text(24,286,"开盘",{color=BLACK}); g:text(182,286,"最高",{color=BLACK}); g:text(332,286,"最低",{color=BLACK})
    g:text(24,316,price(q.open),{color=BLACK}); g:text(182,316,price(q.high),{color=BLACK}); g:text(332,316,price(q.low),{color=BLACK})
    if s.detail_has_chart then
      g:text(24,424,"1 分钟走势",{color=BLACK}); right(g,456,424,s.status == "chart_loading" and "更新中" or "最近 40 根")
      draw_kline(g,s.candles)
    else
      g:text(24,416,"昨收",{color=BLACK}); right(g,456,416,price(q.preclose))
      dotted_rule(g,24,452,432)
      g:text(24,486,"成交量",{color=BLACK}); right(g,456,486,q.volume or "--")
      g:text(24,556,"该品种暂未提供已验证分时数据",{color=BLACK})
    end
    return
  end
  if not s.snapshot then center(g, 24, 340, 432, s.status == "loading" and "正在更新全球报价" or "暂时无法获取市场数据", BLACK); return end
  local by_market = {}; for _, row in ipairs(s.snapshot.rows) do by_market[row.market] = row end
  local dow, nasdaq = by_market["道琼斯指数"], by_market["纳斯达克综合指数"]
  local forex, oil = by_market["美元指数"], by_market["纽约原油"]
  local hsi = by_market["恒生指数"]
  local eurusd, usdjpy, usdcnh = by_market["欧元兑美元"], by_market["美元兑日元"], by_market["美元兑离岸人民币"]
  if dow then
    PkgImage.draw(g, "type_dow", 24, 78); right(g,440,124,signed(dow.changeRate)); draw_quote(g,456,150,dow.price)
  end
  dotted_rule(g,24,222,432)
  if nasdaq then
    PkgImage.draw(g, "type_nasdaq", 24, 242); right(g,440,276,signed(nasdaq.changeRate)); draw_quote(g,456,302,nasdaq.price)
  end
  dotted_rule(g,24,374,432)
  PkgImage.draw(g, "type_macro", 24, 396)
  local function draw_macro(row, y)
    if not row then return end
    PkgImage.draw(g, row.market == "美元指数" and "type_dollar" or "type_oil", 24, y); draw_quote(g,456,y-8,row.price); right(g,440,y+52,signed(row.changeRate))
  end
  draw_macro(forex,426)
  draw_macro(oil,518)
  dotted_rule(g,24,602,432)
  PkgImage.draw(g, "type_asia", 24, 614)
  if hsi then
    PkgImage.draw(g, "type_hsi", 24, 650); right(g,456,650,price(hsi.price)); right(g,456,676,signed(hsi.changeRate))
  end
  PkgImage.draw(g, "type_fx", 24, 698)
  local function draw_fx_pair(left, left_code, right_row, right_code, y)
    local left_text = left and left_code .. "  " .. price(left.price) or left_code .. "  --"
    g:text(24,y,left_text,{color=BLACK})
    if right_code ~= "" then
      local right_text = right_row and right_code .. "  " .. price(right_row.price) or right_code .. "  --"
      right(g,456,y,right_text)
    end
  end
  draw_fx_pair(eurusd,"EUR/USD",usdjpy,"USD/JPY",730)
  draw_fx_pair(usdcnh,"USD/CNH",nil,"",754)
end
