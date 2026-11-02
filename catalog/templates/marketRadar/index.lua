-- 市场异动雷达：每个市场一条固定 ScriptNet GET 路由。
local BLACK, WHITE = 15, 0
local APIs = {
  hk = "http://193.112.174.92:28473/demo/stock/ranking/xtapp?limit=12",
  a = "http://193.112.174.92:28473/demo/market/a/ranking/xtapp?limit=12",
  us = "http://193.112.174.92:28473/demo/market/us/ranking/xtapp?limit=12",
}
local LABELS = { hk = "港股", a = "A股", us = "美股" }
local ORDER = { "hk", "a", "us" }
local PROTOCOL = "XTAPP_RANKING_V1"
local task_id, requested_market = nil, nil
local on_net_done

local function state(ctx)
  ctx.state.market_radar_live = ctx.state.market_radar_live or { market = "hk", rows = {}, status = "idle" }
  return ctx.state.market_radar_live
end
local function text_width(value)
  local n, i, value = 0, 1, tostring(value or "")
  while i <= #value do local b=value:byte(i); if b>=0xE0 then n,i=n+18,i+3 elseif b>=0xC0 then n,i=n+18,i+2 else n,i=n+9,i+1 end end
  return n
end
local function right(g,x,y,value) g:text(x-text_width(value),y,tostring(value or "--"),{color=BLACK}) end
local function center(g,x,y,w,value,color) g:text(x+math.max(0,math.floor((w-text_width(value))/2)),y,tostring(value),{color=color or BLACK}) end
local function dotted(g,x,y,w) for px=x,x+w,9 do g:rect(px,y,2,2,{fill=true,color=BLACK}) end end
local function format_price(value)
  local n=tonumber(value); if not n then return "--" end
  if math.abs(n)>=1000 then return string.format("%.1f",n) end
  if math.abs(n)>=100 then return string.format("%.2f",n) end
  return string.format("%.3f",n)
end
local function format_rate(value)
  local n=tonumber(value); return n and string.format("%+.2f%%",n) or "--"
end
local function parse(body)
  if type(body)~="string" or body:match("^([^\r\n]+)")~=PROTOCOL then return nil end
  local rows={}
  for line in body:gmatch("[^\r\n]+") do
    local symbol,name,price,rate,change=line:match("^stock\t([^\t]+)\t([^\t]*)\t([^\t]+)\t([^\t]+)\t([^\t]+)")
    if symbol and tonumber(price) then rows[#rows+1]={symbol=symbol,name=name,price=price,rate=rate,change=change} end
  end
  return #rows>0 and rows or nil
end
local function request(ctx)
  local s=state(ctx)
  if task_id then return end
  if not ctx.net then s.status="no_net"; ctx:invalidate(); return end
  local id,err=ctx.net:request({ url = APIs[s.market] }, on_net_done)
  if not id then s.status=tostring(err or "error"); ctx:invalidate(); return end
  task_id,requested_market,s.status=id,s.market,"loading"; ctx:invalidate()
end
local function switch_market(ctx, delta)
  local s=state(ctx); local index=1
  for i,key in ipairs(ORDER) do if key==s.market then index=i end end
  index=((index-1+delta)%#ORDER)+1
  if task_id and ctx.net then task_id:cancel() end
  task_id,requested_market=nil,nil; s.market=ORDER[index]; s.rows={}; s.status="idle"; request(ctx)
end
local function choose_market(ctx, market)
  local s=state(ctx)
  if s.market==market then request(ctx); return end
  if task_id and ctx.net then task_id:cancel() end
  task_id,requested_market=nil,nil; s.market=market; s.rows={}; s.status="idle"; request(ctx)
end
function on_load(ctx) request(ctx) end
on_net_done = function(ctx, result)
  local finished=task_id; task_id=nil
  local s=state(ctx); local rows=result.ok and parse(result.body) or nil
  if requested_market==s.market then s.rows=rows or {}; s.status=rows and "ready" or "error" end
  requested_market=nil; ctx:invalidate()
end
function on_leave(ctx) if task_id and ctx.net then task_id:cancel() end; task_id,requested_market=nil,nil end
function on_input(ctx,ev)
  if ev.type=="key" and ev.phase=="down" then
    if ev.key=="left" then switch_market(ctx,-1); return true end
    if ev.key=="right" then switch_market(ctx,1); return true end
    if ev.key=="ok" then request(ctx); return true end
    if ev.key=="back" then ctx:quit(); return true end
  end
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture=="tap" then
    if ev.y<62 and ev.x>360 then request(ctx); return true end
    if ev.y>=76 and ev.y<=126 then
      if ev.x<160 then choose_market(ctx,"hk") elseif ev.x<320 then choose_market(ctx,"a") else choose_market(ctx,"us") end
      return true
    end
  end
  return false
end
function on_draw(ctx,g)
  local s=state(ctx); g:clear(WHITE)
  g:text(24,24,"市场异动",{color=BLACK}); right(g,456,26,s.status=="loading" and "更新中" or "刷新")
  g:text(24,48,"真实涨跌幅排行",{color=BLACK})
  local xs={24,168,312}; for i,key in ipairs(ORDER) do
    local active=s.market==key; g:rect(xs[i],76,132,40,{fill=(active) and true or false,color=active and BLACK or BLACK})
    center(g,xs[i],88,132,LABELS[key],active and WHITE or BLACK)
  end
  g:text(24,146,"排名",{color=BLACK}); g:text(82,146,"名称",{color=BLACK}); right(g,336,146,"最新价"); right(g,456,146,"涨跌幅")
  dotted(g,24,166,432)
  if #s.rows==0 then
    center(g,24,350,432,s.status=="loading" and "正在扫描市场异动" or "暂时没有可展示的排行",BLACK)
    center(g,24,382,432,"点击刷新后重试",BLACK)
    return
  end
  for i,row in ipairs(s.rows) do
    local y=178+(i-1)*49; if y>760 then break end
    g:text(24,y,string.format("%02d",i),{color=BLACK}); g:text(82,y,row.name~="" and row.name or row.symbol,{color=BLACK})
    g:text(82,y+21,row.symbol,{color=BLACK}); right(g,336,y+8,format_price(row.price)); right(g,456,y+8,format_rate(row.rate)); dotted(g,24,y+43,432)
  end
end
