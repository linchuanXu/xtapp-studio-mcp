-- 期货行情：Lua 仅访问固定 HTTP GET；阿里云凭据仅在服务器端。
local BLACK, WHITE = 15, 0
local QUOTE_API = "http://193.112.174.92:28473/demo/market/quote/xtapp?kind="
local KLINE_API = "http://193.112.174.92:28473/demo/futures/kline/xtapp?limit=40&kind="
local task_id, task_kind = nil, nil
local on_net_done
local MARKETS = {{ kind="external", label="外盘原油" }, { kind="internal", label="内盘螺纹钢" }}

local function state(ctx)
  ctx.state.futures_live = ctx.state.futures_live or { selected=1, status="idle", quote=nil, candles=nil }
  return ctx.state.futures_live
end
local function width(text) local n,i,text=0,1,tostring(text or ""); while i<=#text do local b=text:byte(i); if b>=0xE0 then n,i=n+20,i+3 elseif b>=0xC0 then n,i=n+20,i+2 else n,i=n+10,i+1 end end; return n end
local function center(g,x,y,w,text,color) g:text(x+math.max(0,math.floor((w-width(text))/2)),y,text,{color=color or BLACK}) end
local function right(g,x,y,text) g:text(x-width(text),y,text,{color=BLACK}) end
local function price(value) local n=tonumber(value); return n and string.format("%.2f",n) or "--" end
local function signed(value) local n=tonumber(value); return n and string.format("%+.2f%%",n) or "--" end
local function selected(s) return MARKETS[s.selected] end
local function parse_quote(body)
  if type(body)~="string" or body:match("^([^\r\n]+)")~="XTAPP_STOCK_V1" then return nil end
  local q={}; for line in body:gmatch("[^\r\n]+") do local k,v=line:match("^([^\t]+)\t(.*)$"); if k then q[k]=v end end
  return q.price and q or nil
end
local function parse_kline(body)
  if type(body)~="string" or body:match("^([^\r\n]+)")~="XTAPP_KLINE_V1" then return nil end
  local values={}; for line in body:gmatch("[^\r\n]+") do local close=line:match("^candle\t[^\t]+\t[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)"); if tonumber(close) then values[#values+1]=tonumber(close) end end
  return #values>=2 and values or nil
end
local function request_quote(ctx)
  if task_id or not ctx.net then return end
  local s=state(ctx); local id=ctx.net:request({ url = QUOTE_API..selected(s).kind }, on_net_done); if not id then s.status="error"; ctx:invalidate(); return end
  task_id,task_kind,s.status=id,"quote","loading"; s.quote=nil; s.candles=nil; ctx:invalidate()
end
local function draw_chart(g, values)
  local x,y,w,h=24,470,432,190; g:rect(x,y,w,h,{color=BLACK})
  if not values then center(g,x,y+80,w,"走势加载中",BLACK); return end
  local lo,hi=values[1],values[1]; for _,v in ipairs(values) do lo=math.min(lo,v); hi=math.max(hi,v) end; if hi==lo then lo,hi=lo-.01,hi+.01 end
  local px,py=nil,nil; for i,v in ipairs(values) do local cx=x+8+math.floor((i-1)*(w-16)/(#values-1)); local cy=y+12+math.floor((hi-v)*(h-24)/(hi-lo)); if px then g:line(px,py,cx,cy,{color=BLACK}) end; px,py=cx,cy end
end
function on_load(ctx) request_quote(ctx) end
on_net_done = function(ctx, result)
  local done=task_kind; task_id,task_kind=nil,nil; local s=state(ctx)
  if done=="quote" then s.quote=result.ok and parse_quote(result.body) or nil; if s.quote and ctx.net then local id=ctx.net:request({ url = KLINE_API..selected(s).kind }, on_net_done); if id then task_id,task_kind,s.status=id,"kline","chart_loading"; ctx:invalidate(); return end end else s.candles=result.ok and parse_kline(result.body) or nil end
  s.status=s.quote and "ready" or "error"; ctx:invalidate()
end
function on_leave(ctx) if task_id and ctx.net then task_id:cancel() end; task_id,task_kind=nil,nil end
function on_input(ctx,ev)
  local s=state(ctx); if (ev.type == "pointer" and ev.phase == "up") and ev.gesture=="tap" then
    if ev.y>=76 and ev.y<=112 then local i=ev.x<240 and 1 or 2; if i~=s.selected then s.selected=i; request_quote(ctx) end; return true end
    if ev.y<=62 then request_quote(ctx); return true end
  end
  if ev.type=="key" and ev.phase=="down" and ev.key=="back" then ctx:quit(); return true end
  if ev.type=="key" and ev.phase=="down" and ev.key=="ok" then request_quote(ctx); return true end
  return false
end
function on_draw(ctx,g)
  local s=state(ctx); g:clear(WHITE); g:text(24,26,"期货行情",{color=BLACK}); right(g,456,26,"LIVE · FUTURES"); g:rect(382,48,74,30,{color=BLACK}); center(g,382,54,74,"刷新",BLACK)
  for i,item in ipairs(MARKETS) do local x=i==1 and 24 or 248; local active=i==s.selected; g:rect(x,76,208,36,{fill=(active) and true or false,color=BLACK}); center(g,x,84,208,item.label,active and WHITE or BLACK) end
  if not s.quote then center(g,24,340,432,s.status=="loading" and "正在获取真实期货数据" or "请求失败，点击刷新重试",BLACK); return end
  local q=s.quote; g:text(24,144,q.name or selected(s).label,{color=BLACK}); right(g,456,144,q.symbol or ""); center(g,24,215,432,price(q.price),BLACK); center(g,24,278,432,signed(q.changeRate),BLACK)
  g:text(24,350,"开盘  "..price(q.open),{color=BLACK}); g:text(24,390,"最高  "..price(q.high),{color=BLACK}); g:text(24,430,"最低  "..price(q.low),{color=BLACK}); g:text(24,448,"实时 1 分钟走势",{color=BLACK}); draw_chart(g,s.candles); center(g,24,742,432,s.status=="chart_loading" and "正在加载曲线" or "OK 刷新 · BACK 退出",BLACK)
end
