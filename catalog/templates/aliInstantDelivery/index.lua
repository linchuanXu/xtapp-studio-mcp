local PkgImage = require("pkg_image")
local B,W=15,0
local nav={"首页","订单","我的"}
local cats={"闪购","超市","水果","医药"}
local cat_icons={"route","delivery_bag","store_pin","shield"}

local function round_fill(g,x,y,w,h,r,color)
  r=math.max(1,math.min(r,math.floor(w/2),math.floor(h/2)))
  g:rect(x+r,y,w-r*2,h,{fill=true,color=color}); g:rect(x,y+r,w,h-r*2,{fill=true,color=color})
  g:circle(x+r,y+r,r,{fill=true,color=color}); g:circle(x+w-1-r,y+r,r,{fill=true,color=color})
  g:circle(x+r,y+h-1-r,r,{fill=true,color=color}); g:circle(x+w-1-r,y+h-1-r,r,{fill=true,color=color})
end

local function round_stroke(g,x,y,w,h,r,color,bg)
  round_fill(g,x,y,w,h,r,color); round_fill(g,x+2,y+2,w-4,h-4,math.max(1,r-2),bg or W)
end

local function hit(x,y,l,t,w,h) return x>=l and x<=l+w and y>=t and y<=t+h end
local function split(line)
  local out={}
  for value in (line.."\t"):gmatch("([^\t]*)\t") do out[#out+1]=value end
  return out
end

local function seed_data(ctx)
  local data={stages={},items={},meta={}}
  local reader=ctx.package:open_text("delivery.tsv", {max_line_bytes=512})
  if reader then
    reader:read_line()
    while true do
      local line=reader:read_line(); if not line then break end
      local f=split(line)
      if f[1]=="stage" then data.stages[#data.stages+1]={at=tonumber(f[2]) or 0,title=f[3],detail=f[4],eta=tonumber(f[5]) or 0}
      elseif f[1]=="item" then data.items[#data.items+1]={name=f[3],count=f[4],price=f[6]}
      elseif f[1]=="meta" then data.meta[f[3]]=f[4] end
    end
    reader:close()
  end
  if #data.stages==0 then data.stages={{at=0,title="订单已确认",detail="门店正在为你拣货",eta=28},{at=360,title="订单已送达",detail="商品已放至园区前台",eta=0}} end
  return data
end

local function now(ctx) return ctx.clock:now().local_sec or math.floor(ctx.clock:millis()/1000) end
local function current(ctx,s)
  local elapsed=math.max(0,now(ctx)-(s.started or now(ctx)))
  local index,item=1,s.data.stages[1]
  for i,v in ipairs(s.data.stages) do if elapsed>=v.at then index,item=i,v end end
  return elapsed,index,item
end

local function consumer_header(g,with_search)
  g:clear(W)
  PkgImage.draw(g, "brand_mark", 20, 14)
  PkgImage.draw(g, "store_pin", 184, 18)
  g:text(238,27,"观澜湖园区",{color=B})
  g:text(420,27,"切换",{color=B})
  if with_search then
    round_stroke(g,20,82,440,54,14,B,W); round_fill(g,20,82,52,54,14,B)
    g:text(38,98,"搜",{color=W}); g:text(92,98,"搜即时好物 · 30分钟送达",{color=B})
  else g:line(20,80,460,80,{color=B}) end
end

local function bottom_nav(g,s)
  g:line(0,718,480,718,{color=B})
  for i,label in ipairs(nav) do
    local x=(i-1)*160
    if s.page==i then g:rect(x,718,160,4,{fill=true,color=B}) end
    g:text(x+61,735,label,{color=B})
    g:text(x+54,767,i==1 and "附近" or i==2 and "履约" or "服务",{color=B})
  end
end

local function home(ctx,g,s)
  consumer_header(g,true)
  for i,label in ipairs(cats) do
    local x=62+(i-1)*114
    g:circle(x,184,27,{color=B})
    if s.category==i then g:circle(x,184,31,{color=B}) end
    PkgImage.draw(g, cat_icons[i], x-24, 160)
    g:text(x-20,219,label,{color=B})
  end
  local _,index,stage=current(ctx,s)
  round_fill(g,20,254,440,150,16,B)
  g:text(40,273,stage.eta>0 and "正在配送" or "已安全送达",{color=W})
  g:text(40,310,stage.eta>0 and (stage.eta.." 分钟") or "请到前台取货",{color=W})
  g:text(40,349,stage.title.." · 尾号 "..(s.data.meta.order_no or "5086"),{color=W})
  PkgImage.draw(g, index>=#s.data.stages and "check" or "route", 388, 274, {invert=true})
  round_stroke(g,324,352,116,34,9,W,B); g:text(342,359,"设为锁屏",{color=W})
  g:text(20,430,"附近好物",{color=B}); g:text(390,430,"查看全部",{color=B})
  local rows={{"delivery_bag","园区超市","15分钟达 · 日用补给"},{"store_pin","鲜果档口","近场直送 · 今日上新"},{"shield","即时药房","隐私配送 · 夜间可用"}}
  for i,row in ipairs(rows) do
    local y=470+(i-1)*74
    PkgImage.draw(g, row[1], 24, y); g:text(90,y+2,row[2],{color=B}); g:text(90,y+34,row[3],{color=B}); g:line(90,y+62,456,y+62,{color=B})
  end
  bottom_nav(g,s)
end

local function order_page(ctx,g,s)
  consumer_header(g,false); g:text(20,103,"我的订单",{color=B})
  local _,index,stage=current(ctx,s)
  g:rect(20,142,440,174,{color=B}); PkgImage.draw(g, index>=#s.data.stages and "check" or "route", 36, 160)
  g:text(100,162,s.data.meta.store or "盒马鲜生·观澜湖店",{color=B})
  g:text(100,198,stage.title,{color=B}); g:text(36,242,stage.detail,{color=B})
  g:text(36,278,"尾号 "..(s.data.meta.order_no or "5086").."  ·  ¥"..(s.data.meta.amount or "68.40"),{color=B})
  local labels={"确认","拣货","接单","取货","配送","送达"}
  for i,label in ipairs(labels) do
    local x=38+(i-1)*81; g:circle(x,354,7,{fill=(i<=index) and true or false,color=B})
    if i<6 then g:line(x+9,354,x+71,354,{color=B}) end
    g:text(x-17,374,label,{color=B})
  end
  g:text(20,426,"订单内容",{color=B})
  for i,item in ipairs(s.data.items) do if i<=3 then
    local y=468+(i-1)*54; g:text(20,y,item.name,{color=B}); g:text(320,y,item.count,{color=B}); g:text(392,y,"¥"..item.price,{color=B}); g:line(20,y+38,460,y+38,{color=B})
  end end
  round_stroke(g,20,662,210,42,10,B,W); g:text(88,672,"重播进度",{color=B})
  round_fill(g,250,662,210,42,10,B); g:text(312,672,"隐私锁屏",{color=W})
  bottom_nav(g,s)
end

local function profile(g,s)
  consumer_header(g,false)
  g:circle(66,132,34,{fill=true,color=B}); g:text(49,119,"淘",{color=W})
  g:text(120,108,"即时生活会员",{color=B}); g:text(120,145,"号码与地址已保护",{color=B})
  local cards={{"shield","隐私中心"},{"store_pin","收货地址"},{"delivery_bag","常购清单"},{"check","售后服务"}}
  for i,c in ipairs(cards) do
    local col=(i-1)%2; local row=math.floor((i-1)/2); local x=20+col*224; local y=210+row*118
    round_stroke(g,x,y,216,100,12,B,W); PkgImage.draw(g, c[1], x+18, y+18); g:text(x+82,y+36,c[2],{color=B})
  end
  g:text(20,466,"服务与保障",{color=B})
  local rows={{"配送偏好","无接触放置"},{"消息设置","仅保留履约通知"},{"客服帮助","即时订单优先接入"}}
  for i,row in ipairs(rows) do local y=510+(i-1)*50; g:text(20,y,row[1],{color=B}); g:text(278,y,row[2],{color=B}); g:line(20,y+34,460,y+34,{color=B}) end
  round_fill(g,20,666,440,38,10,B); g:text(150,675,"启用隐私安心锁屏",{color=W})
  bottom_nav(g,s)
end


function on_load(ctx)
  if not ctx.state.ali_delivery then ctx.state.ali_delivery={page=1,category=1,started=now(ctx),private=true,data=seed_data(ctx)} end
  if not ctx.state.ali_delivery.category then ctx.state.ali_delivery.category=1 end
  ctx:set_tick(500)
end
function on_tick(ctx) if ctx.state.ali_delivery.page<=2 then ctx:invalidate() end end
function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=ctx.state.ali_delivery
  if s.page==1 then home(ctx,g,s) elseif s.page==2 then order_page(ctx,g,s) else profile(g,s) end
end
function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s=ctx.state.ali_delivery
  if ev.gesture=="swipe_left" then s.page=s.page%3+1
  elseif ev.gesture=="swipe_right" then s.page=(s.page+1)%3+1
  elseif ev.gesture=="tap" then
    if hit(ev.x,ev.y,0,718,480,82) then s.page=math.max(1,math.min(3,math.floor(ev.x/160)+1))
    elseif s.page==1 and hit(ev.x,ev.y,20,146,440,100) then s.category=math.max(1,math.min(4,math.floor((ev.x-20)/114)+1))
    elseif s.page==1 and hit(ev.x,ev.y,20,254,440,96) then s.page=2
    elseif s.page==2 and hit(ev.x,ev.y,20,654,210,58) then s.started=now(ctx)
    elseif (s.page==1 and hit(ev.x,ev.y,324,344,116,50)) or (s.page==2 and hit(ev.x,ev.y,250,654,210,58)) or (s.page==3 and hit(ev.x,ev.y,20,650,440,62)) then s.private=true; if ctx.lockscreen then ctx.lockscreen:set_default() end
    else return false end
  else return false end
  ctx:invalidate(); return true
end
