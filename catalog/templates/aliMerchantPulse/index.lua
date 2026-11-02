local PkgImage = require("pkg_image")
local B,W=15,0
local nav={"首页","商品","营销","任务"}

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

local function load_data(ctx)
  local out={metric={},product={},campaign={},task={}}
  local reader=ctx.package:open_text("merchant.tsv", {max_line_bytes=512})
  if reader then
    reader:read_line()
    while true do
      local line=reader:read_line(); if not line then break end
      local f=split(line)
      if out[f[1]] then out[f[1]][#out[f[1]]+1]={name=f[2],a=f[3],b=f[4],status=f[5],note=f[6]} end
    end
    reader:close()
  end
  return out
end

local function identity_header(g)
  g:clear(W)
  g:circle(50,42,30,{fill=true,color=B}); g:text(34,29,"店",{color=W})
  g:text(92,18,"云栖日用旗舰店",{color=B}); g:text(92,51,"千牛商家工作台",{color=B})
  g:text(390,18,"经营中",{color=B}); g:text(390,51,"消息 3",{color=B})
  g:line(20,88,460,88,{color=B})
end

local function bottom_nav(g,s)
  g:line(0,718,480,718,{color=B})
  for i,label in ipairs(nav) do
    local x=(i-1)*120
    if s.page==i then g:rect(x,718,120,4,{fill=true,color=B}) end
    g:text(x+43,735,label,{color=B}); g:text(x+36,767,i==1 and "经营" or i==2 and "管理" or i==3 and "推广" or "待办",{color=B})
  end
end

local function home(g,s)
  identity_header(g)
  round_fill(g,20,108,440,132,14,B)
  g:text(40,126,"今日成交额",{color=W}); g:text(40,160,"¥18,642",{color=W}); g:text(40,204,"较昨日 +18.6%",{color=W})
  g:text(260,128,"访客",{color=W}); g:text(260,160,"4,860",{color=W})
  g:text(366,128,"支付订单",{color=W}); g:text(366,160,"327",{color=W})
  g:text(260,204,"转化 6.7%  ·  ROI 4.3",{color=W})
  local states={{"待付款","4"},{"待发货","19"},{"售后","2"},{"待评价","8"}}
  for i,v in ipairs(states) do local x=20+(i-1)*110; g:rect(x,258,110,72,{color=B}); g:text(x+29,269,v[2],{color=B}); g:text(x+22,301,v[1],{color=B}) end
  round_stroke(g,20,350,440,48,10,B,W); g:text(34,362,"公告",{color=B}); g:line(82,358,82,390,{color=B}); g:text(96,362,"大促报名今晚 20:00 截止",{color=B})
  g:text(20,420,"新商必做",{color=B}); g:text(382,420,"2/4完成",{color=B})
  local todo={{"完善店铺基础信息","提升搜索曝光"},{"设置首单优惠券","预计提升转化 12%"}}
  for i,v in ipairs(todo) do local y=460+(i-1)*52; g:rect(20,y,34,34,{color=B}); g:text(70,y,v[1],{color=B}); g:text(286,y,v[2],{color=B}); g:line(70,y+38,460,y+38,{color=B}) end
  g:text(20,570,"基础工具",{color=B})
  local tools={{"product_box","商品"},{"campaign","营销"},{"alert","订单"},{"trend_up","数据"}}
  for i,v in ipairs(tools) do local x=34+(i-1)*108; PkgImage.draw(g, v[1], x, 610); g:text(x+4,668,v[2],{color=B}) end
  bottom_nav(g,s)
end

local function products(g,s)
  identity_header(g); PkgImage.draw(g, "product_box", 20, 108); g:text(82,111,"商品管理",{color=B}); g:text(342,111,"按成交排序",{color=B}); g:line(20,164,460,164,{color=B})
  for i,item in ipairs(s.data.product) do if i<=4 then
    local y=184+(i-1)*112
    g:circle(38,y+12,15,{fill=(i==1) and true or false,color=B}); g:text(33,y+4,tostring(i),{color=i==1 and W or B})
    g:text(70,y,item.name,{color=B}); g:text(70,y+34,item.a.." 单 · 转化 "..item.b,{color=B})
    g:text(348,y,item.status,{color=B}); g:text(348,y+34,item.note,{color=B}); g:line(70,y+78,460,y+78,{color=B})
  end end
  round_fill(g,20,658,440,46,10,B); g:text(92,670,"晴雨伞库存仅 18 · 立即补货",{color=W})
  bottom_nav(g,s)
end

local function campaigns(g,s)
  identity_header(g); PkgImage.draw(g, "campaign", 20, 108); g:text(82,111,"营销推广",{color=B}); g:text(344,111,"整体 ROI 4.3",{color=B}); g:line(20,164,460,164,{color=B})
  for i,item in ipairs(s.data.campaign) do if i<=3 then
    local y=190+(i-1)*138
    g:text(20,y,item.name,{color=B}); g:text(294,y,"消耗 ¥"..item.a,{color=B})
    g:text(20,y+34,"ROI "..item.b,{color=B}); g:text(130,y+34,item.status,{color=B}); g:text(294,y+34,item.note,{color=B})
    local width=math.max(24,math.min(410,(tonumber(item.a) or 0)*410/1200)); g:rect(20,y+72,410,10,{color=B}); g:rect(20,y+72,width,10,{fill=true,color=B})
  end end
  PkgImage.draw(g, "trend_up", 20, 608); g:text(82,608,"通勤包搜索转化连续 3 小时上涨",{color=B}); g:text(82,646,"建议新品加速预算提高 15%",{color=B})
  bottom_nav(g,s)
end

local function tasks(g,s)
  identity_header(g); PkgImage.draw(g, "alert", 20, 108); g:text(82,111,"经营任务",{color=B}); g:text(390,111,(#s.data.task-s.done).." 项",{color=B}); g:line(20,164,460,164,{color=B})
  for i,item in ipairs(s.data.task) do if i<=4 then
    local y=182+(i-1)*108; local finished=i<=s.done
    g:rect(20,y,42,42,{fill=(finished) and true or false,color=B}); g:text(finished and 31 or 34,y+10,finished and "OK" or item.b,{color=finished and W or B})
    g:text(80,y,item.name,{color=B}); g:text(80,y+34,item.note,{color=B}); g:text(390,y,item.a,{color=B}); g:line(80,y+74,460,y+74,{color=B})
  end end
  local active=s.done<#s.data.task
  if active then round_fill(g,20,658,440,46,10,B) else round_stroke(g,20,658,440,46,10,B,W) end
  g:text(active and 126 or 142,670,active and "完成最上方经营任务" or "今日任务已全部完成",{color=active and W or B})
  bottom_nav(g,s)
end


function on_load(ctx)
  if not ctx.state.ali_merchant then ctx.state.ali_merchant={page=1,task_index=1,done=0,data=load_data(ctx)} end
  ctx:set_tick(0)
end
function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=ctx.state.ali_merchant
  if s.page==1 then home(g,s) elseif s.page==2 then products(g,s) elseif s.page==3 then campaigns(g,s) else tasks(g,s) end
end
function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s=ctx.state.ali_merchant
  if ev.gesture=="swipe_left" then s.page=s.page%4+1
  elseif ev.gesture=="swipe_right" then s.page=(s.page+2)%4+1
  elseif ev.gesture=="tap" then
    if hit(ev.x,ev.y,0,718,480,82) then s.page=math.max(1,math.min(4,math.floor(ev.x/120)+1))
    elseif s.page==1 and hit(ev.x,ev.y,130,258,110,72) then s.page=4
    elseif s.page==1 and hit(ev.x,ev.y,20,414,440,104) then s.page=4
    elseif s.page==1 and hit(ev.x,ev.y,20,600,94,104) then s.page=2
    elseif s.page==1 and hit(ev.x,ev.y,128,600,94,104) then s.page=3
    elseif s.page==1 and hit(ev.x,ev.y,236,600,94,104) then s.page=4
    elseif s.page==4 and hit(ev.x,ev.y,20,650,440,62) and s.done<#s.data.task then s.done=s.done+1
    else return false end
  else return false end
  ctx:invalidate(); return true
end
