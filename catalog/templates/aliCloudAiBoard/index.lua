local PkgImage = require("pkg_image")
local B,W=15,0
local pages={"控制台","模型","资源","告警"}
local models={
  {name="Qwen3-Max",calls="82.4K",tokens="11.8M",share=48,cost="¥1,426",success="99.92%",latency="1.18s"},
  {name="Qwen3-Plus",calls="61.7K",tokens="8.6M",share=35,cost="¥812",success="99.87%",latency="0.86s"},
  {name="Qwen3-Turbo",calls="39.2K",tokens="4.2M",share=17,cost="¥286",success="99.95%",latency="0.42s"}
}

local function round_fill(g,x,y,w,h,r,color)
  r=math.max(1,math.min(r,math.floor(w/2),math.floor(h/2)))
  g:rect(x+r,y,w-r*2,h,{fill=true,color=color}); g:rect(x,y+r,w,h-r*2,{fill=true,color=color})
  g:circle(x+r,y+r,r,{fill=true,color=color}); g:circle(x+w-1-r,y+r,r,{fill=true,color=color})
  g:circle(x+r,y+h-1-r,r,{fill=true,color=color}); g:circle(x+w-1-r,y+h-1-r,r,{fill=true,color=color})
end

local function round_stroke(g,x,y,w,h,r,color,bg)
  round_fill(g,x,y,w,h,r,color); round_fill(g,x+2,y+2,w-4,h-4,math.max(1,r-2),bg or W)
end

local function text_width(text)
  local width,i=0,1
  while i<=#text do
    if text:byte(i)>=0xE0 then width,i=width+20,i+3 else width,i=width+10,i+1 end
  end
  return width
end

local function center_text(g,x,y,w,text,color)
  g:text(x+math.max(0,math.floor((w-text_width(text))/2)),y,text,{color=color or B})
end

local function button(g,x,y,w,h,text,selected)
  if selected then round_fill(g,x,y,w,h,10,B) else round_stroke(g,x,y,w,h,10,B,W) end
  center_text(g,x,y+math.floor((h-20)/2),w,text,selected and W or B)
end

local function meter(g,x,y,w,value)
  local n=math.max(0,math.min(100,value))
  g:rect(x,y,w,12,{color=B})
  if n>0 then g:rect(x+3,y+3,math.floor((w-6)*n/100),6,{fill=true,color=B}) end
end

local function console_header(g)
  g:clear(W)
  g:rect(0,0,480,132,{fill=true,color=B})
  round_fill(g,20,8,150,54,8,W)
  PkgImage.draw(g, "brand_mark", 20, 8)
  round_fill(g,348,8,52,54,8,W)
  PkgImage.draw(g, "icon_endpoint", 350, 11)
  round_fill(g,408,8,52,54,8,W)
  PkgImage.draw(g, "icon_alert", 410, 11)
  round_stroke(g,20,76,440,42,10,W,B)
  g:text(40,87,"搜索云产品 / 实例 / 工单",{color=W})
end

local function bottom_nav(g,s)
  g:line(0,741,480,741,{color=B})
  for i,label in ipairs(pages) do
    local x=(i-1)*120
    if s.page==i then g:rect(x,742,120,58,{fill=true,color=B}) end
    center_text(g,x,760,120,label,s.page==i and W or B)
  end
end

local function section_title(g,y,title,more)
  g:rect(20,y+3,5,20,{fill=true,color=B})
  g:text(36,y,title,{color=B})
  if more then g:text(382,y,more,{color=B}) end
end

local quick={
  {"icon_budget","续费管理"},
  {"icon_check","备案"},
  {"icon_cost","充值"},
  {"icon_endpoint","SSH"},
  {"icon_model","全部工具"}
}

local function draw_quick(g)
  for i,item in ipairs(quick) do
    local x=20+(i-1)*88
    PkgImage.draw(g, item[1], x+20, 146)
    center_text(g,x,202,88,item[2],B)
  end
end

local function draw_console(g,s)
  console_header(g)
  draw_quick(g)
  g:line(20,234,460,234,{color=B})

  section_title(g,252,"待处理事件","2 项")
  round_stroke(g,20,286,440,58,10,B,W)
  PkgImage.draw(g, "icon_warning", 28, 291)
  g:text(86,295,"预算接近 80% 阈值",{color=B})
  g:text(86,319,"本月预计仍有 ¥1,837 余量",{color=B})
  g:text(414,305,">",{color=B})

  section_title(g,364,"费用监控","详情")
  button(g,298,356,70,34,"7 日",s.period==7)
  button(g,376,356,84,34,"30 日",s.period==30)
  local monthly=s.period==30
  g:text(20,400,monthly and "本月 AI 支出" or "近 7 日 AI 支出",{color=B})
  g:text(20,429,monthly and "¥10,842.60" or "¥3,126.40",{color=B})
  g:text(311,429,monthly and "同比 +18.6%" or "环比 +12.8%",{color=B})
  local bars=monthly and {58,72,64,83,78,91,86} or {44,56,50,72,62,88,76}
  for i,v in ipairs(bars) do
    local x=238+(i-1)*31
    local h=math.floor(v*0.42)
    g:rect(x,493-h,17,h,{fill=true,color=B})
  end
  g:line(230,493,460,493,{color=B})

  section_title(g,516,"资源健康","运行正常")
  PkgImage.draw(g, "icon_check", 20, 548)
  g:text(82,550,"推理实例",{color=B}); g:text(374,550,"12 / 16",{color=B})
  g:text(82,580,"GPU 利用率",{color=B}); g:text(391,580,"72%",{color=B})
  g:text(82,610,"在线端点",{color=B}); g:text(391,610,"8 / 8",{color=B})
  g:line(20,642,460,642,{color=B})

  section_title(g,658,"最近使用的产品",nil)
  g:text(20,695,"模型服务",{color=B})
  g:text(172,695,"在线推理",{color=B})
  g:text(324,695,"费用中心",{color=B})
  bottom_nav(g,s)
end

local function draw_models(g,s)
  console_header(g)
  PkgImage.draw(g, "icon_model", 20, 148)
  g:text(82,151,"模型服务",{color=B})
  g:text(82,179,"百炼 · 生产空间",{color=B})
  g:line(20,212,460,212,{color=B})
  section_title(g,228,"调用排行","183.3K 次")
  for i,m in ipairs(models) do
    local y=270+(i-1)*86
    if s.model==i then g:rect(20,y-8,5,64,{fill=true,color=B}) end
    g:text(38,y,m.name,{color=B})
    g:text(352,y,m.calls,{color=B})
    meter(g,38,y+30,318,m.share)
    g:text(378,y+27,m.share.."%",{color=B})
    g:line(38,y+58,460,y+58,{color=B})
  end
  local m=models[s.model]
  round_stroke(g,20,532,440,182,10,B,W)
  g:text(38,550,m.name.." 运行详情",{color=B})
  g:line(38,582,442,582,{color=B})
  PkgImage.draw(g, "icon_token", 38, 592)
  g:text(98,597,"Tokens",{color=B}); g:text(348,597,m.tokens,{color=B})
  g:text(38,646,"成功率 "..m.success,{color=B}); g:text(260,646,"P95 "..m.latency,{color=B})
  g:text(38,682,"本期成本",{color=B}); g:text(348,682,m.cost,{color=B})
  bottom_nav(g,s)
end

local function capacity_row(g,key,y,title,value,percent,note)
  PkgImage.draw(g, key, 20, y)
  g:text(82,y+1,title,{color=B})
  g:text(368,y+1,value,{color=B})
  meter(g,82,y+31,378,percent)
  g:text(82,y+55,note,{color=B})
  g:line(82,y+84,460,y+84,{color=B})
end

local function draw_resources(g,s)
  console_header(g)
  PkgImage.draw(g, "icon_capacity", 20, 148)
  g:text(82,151,"资源中心",{color=B})
  g:text(82,179,"计算与推理容量",{color=B})
  g:line(20,212,460,212,{color=B})
  button(g,20,228,212,42,"华东 1",s.region==1)
  button(g,240,228,220,42,"华北 2",s.region==2)
  local east=s.region==1
  capacity_row(g,"icon_capacity",286,"推理实例",east and "12 / 16" or "6 / 12",east and 75 or 50,east and "峰值余量 4 台" or "峰值余量 6 台")
  capacity_row(g,"icon_gpu",402,"GPU 利用率",east and "72%" or "38%",east and 72 or 38,east and "P95 温度 67°C" or "P95 温度 58°C")
  capacity_row(g,"icon_endpoint",518,"在线端点",east and "8 / 8" or "5 / 5",100,east and "0 个异常 · 99.98% 可用" or "0 个异常 · 99.95% 可用")
  round_stroke(g,20,650,440,66,10,B,W)
  g:text(38,663,"容量建议",{color=B})
  g:text(38,690,east and "晚高峰前增加 2 台推理实例" or "当前余量充足，无需扩容",{color=B})
  bottom_nav(g,s)
end

local function switch(g,x,y,on)
  if on then round_fill(g,x,y,60,30,15,B) else round_stroke(g,x,y,60,30,15,B,W) end
  g:circle(on and x+44 or x+16,y+15,9,{fill=true,color=on and W or B})
end

local function draw_alerts(g,s)
  console_header(g)
  PkgImage.draw(g, "icon_alert", 20, 148)
  g:text(82,151,"告警中心",{color=B})
  g:text(82,179,"预算与资源规则",{color=B})
  g:line(20,212,460,212,{color=B})
  section_title(g,230,"月度预算","¥"..s.budget)
  local spent=10843
  local ratio=math.floor(spent*100/s.budget)
  meter(g,20,268,440,ratio)
  g:text(20,292,"已用 ¥10,843",{color=B})
  g:text(376,292,ratio.."%",{color=B})
  g:line(20,322,460,322,{color=B})
  section_title(g,340,"告警规则",nil)
  local rows={
    {"预算达到 80%","icon_budget"},
    {"GPU 利用率超过 85%","icon_gpu"},
    {"模型错误率超过 2%","icon_warning"}
  }
  for i,row in ipairs(rows) do
    local y=382+(i-1)*82
    PkgImage.draw(g, row[2], 20, y-9)
    g:text(80,y,row[1],{color=B})
    switch(g,400,y-7,s.rules[i])
    g:line(80,y+48,460,y+48,{color=B})
  end
  g:text(20,630,"预算调整",{color=B})
  button(g,20,658,212,48,"- ¥500",false)
  button(g,240,658,220,48,"+ ¥500",false)
  g:text(20,714,ratio>=80 and "预算接近阈值 · 建议检查费用" or "全部正常 · 暂无待处理告警",{color=B})
  bottom_nav(g,s)
end

-- Studio 在验收模式中读取这些语义区域；真机不会注入该槽位。

function on_load(ctx)
  if not ctx.state.ali_cloud_ai then
    ctx.state.ali_cloud_ai={page=1,period=7,model=1,region=1,budget=16000,rules={true,true,true}}
  end
  ctx:set_tick(0)
end


function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=ctx.state.ali_cloud_ai
  if s.page==1 then draw_console(g,s)
  elseif s.page==2 then draw_models(g,s)
  elseif s.page==3 then draw_resources(g,s)
  else draw_alerts(g,s) end
end

function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s=ctx.state.ali_cloud_ai
  local handled=false
  if ev.gesture=="swipe_left" then
    s.page=s.page%4+1; handled=true
  elseif ev.gesture=="swipe_right" then
    s.page=(s.page+2)%4+1; handled=true
  elseif ev.gesture=="tap" then
    if ev.y>=742 and ev.y<800 then
      s.page=math.max(1,math.min(4,math.floor(ev.x/120)+1)); handled=true
    elseif ev.y>=4 and ev.y<=68 and ev.x>=404 then
      s.page=4; handled=true
    elseif s.page==1 and ev.y>=140 and ev.y<=228 and ev.x>=20 and ev.x<=460 then
      local i=math.max(1,math.min(5,math.floor((ev.x-20)/88)+1))
      if i==3 then s.period=30 elseif i==5 then s.page=2 else s.page=3 end
      handled=true
    elseif s.page==1 and ev.y>=286 and ev.y<=344 then
      s.page=4; handled=true
    elseif s.page==1 and ev.y>=356 and ev.y<=390 then
      if ev.x>=298 and ev.x<=368 then s.period=7; handled=true
      elseif ev.x>=376 and ev.x<=460 then s.period=30; handled=true end
    elseif s.page==2 and ev.y>=262 and ev.y<=506 then
      local i=math.floor((ev.y-262)/86)+1
      if i>=1 and i<=3 then s.model=i; handled=true end
    elseif s.page==3 and ev.y>=228 and ev.y<=270 then
      if ev.x>=20 and ev.x<=232 then s.region=1; handled=true
      elseif ev.x>=240 and ev.x<=460 then s.region=2; handled=true end
    elseif s.page==4 and ev.y>=366 and ev.y<=612 then
      local i=math.floor((ev.y-366)/82)+1
      if i>=1 and i<=3 then s.rules[i]=not s.rules[i]; handled=true end
    elseif s.page==4 and ev.y>=658 and ev.y<=706 then
      if ev.x>=20 and ev.x<=232 then s.budget=math.max(12000,s.budget-500); handled=true
      elseif ev.x>=240 and ev.x<=460 then s.budget=math.min(20000,s.budget+500); handled=true end
    end
  end
  if handled then ctx:invalidate(); return true end
  return false
end
