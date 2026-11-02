local PkgImage = require("pkg_image")
local B, W = 15, 0
local NAV = {"首页", "账单", "待办", "我的"}

local function round_fill(g,x,y,w,h,r,color)
  r=math.max(1,math.min(r,math.floor(w/2),math.floor(h/2)))
  g:rect(x+r,y,w-r*2,h,{fill=true,color=color}); g:rect(x,y+r,w,h-r*2,{fill=true,color=color})
  g:circle(x+r,y+r,r,{fill=true,color=color}); g:circle(x+w-1-r,y+r,r,{fill=true,color=color})
  g:circle(x+r,y+h-1-r,r,{fill=true,color=color}); g:circle(x+w-1-r,y+h-1-r,r,{fill=true,color=color})
end

local function round_stroke(g,x,y,w,h,r,color,bg)
  round_fill(g,x,y,w,h,r,color); round_fill(g,x+2,y+2,w-4,h-4,math.max(1,r-2),bg or W)
end

local function split(line)
  local out={}; for value in (line.."\t"):gmatch("([^\t]*)\t") do out[#out+1]=value end; return out
end

local function read_rows(ctx,filename,limit)
  local out={}; local reader=ctx.package:open_text(filename, {max_line_bytes=512}); if not reader then return out end; reader:read_line()
  while true do local line=reader:read_line(); if not line then break end; out[#out+1]=split(line) end; reader:close(); return out
end

local function center(g,x,y,width,text,color)
  local units,i=0,1; while i<=#text do if text:byte(i)>=0xE0 then units,i=units+20,i+3 else units,i=units+10,i+1 end end
  g:text(x+math.max(0,math.floor((width-units)/2)),y,text,{color=color or B})
end

local function money(state,amount) if not state.show_amount then return "¥ ••••" end return amount end

local function app_header(g,state)
  g:clear(W); PkgImage.draw(g, "brand_mark", 24, 12); g:text(290,28,state.show_amount and "金额已展开" or "隐私模式",{color=B}); PkgImage.draw(g, "icon_eye", 416, 16); g:line(24,72,456,72,{color=B})
end

local function bottom_nav(g,state)
  g:line(24,716,456,716,{color=B})
  for i,label in ipairs(NAV) do
    local x=(i-1)*120
    if i==1 then g:rect(x+50,726,20,18,{fill=(state.page==i) and true or false,color=B}); g:line(x+47,730,x+60,720,{color=B}); g:line(x+60,720,x+73,730,{color=B})
    elseif i==2 then g:rect(x+49,724,22,22,{color=B}); g:line(x+53,730,x+67,730,{color=B}); g:line(x+53,736,x+67,736,{color=B})
    elseif i==3 then g:circle(x+60,731,10,{fill=(state.page==i) and true or false,color=B}); g:line(x+60,719,x+60,724,{color=B})
    else g:circle(x+60,728,7,{fill=(state.page==i) and true or false,color=B}); g:line(x+48,744,x+72,744,{color=B}) end
    center(g,x,756,120,label); if state.page==i then g:rect(x+34,790,52,4,{fill=true,color=B}) end
  end
end

local function scan_icon(g,cx,cy,color)
  g:line(cx-18,cy-18,cx-6,cy-18,{color=color}); g:line(cx-18,cy-18,cx-18,cy-6,{color=color}); g:line(cx+6,cy-18,cx+18,cy-18,{color=color}); g:line(cx+18,cy-18,cx+18,cy-6,{color=color})
  g:line(cx-18,cy+18,cx-6,cy+18,{color=color}); g:line(cx-18,cy+18,cx-18,cy+6,{color=color}); g:line(cx+6,cy+18,cx+18,cy+18,{color=color}); g:line(cx+18,cy+18,cx+18,cy+6,{color=color})
  g:rect(cx-7,cy-7,14,14,{fill=true,color=color})
end

local function services(g)
  round_fill(g,24,88,432,126,16,B)
  local centers={78,186,294,402}
  for _,cx in ipairs(centers) do g:circle(cx,130,30,{fill=true,color=W}) end
  scan_icon(g,78,130,B); PkgImage.draw(g, "icon_wallet", 162, 106); PkgImage.draw(g, "icon_bill", 270, 106); PkgImage.draw(g, "icon_shield", 378, 106)
  center(g,24,174,108,"扫一扫",W); center(g,132,174,108,"付款",W); center(g,240,174,108,"账单",W); center(g,348,174,108,"安全",W)
end

local function account_card(g,state)
  round_stroke(g,24,256,432,116,12,B,W); g:rect(24,268,6,92,{fill=true,color=B})
  g:text(44,270,"本月支出",{color=B}); g:text(44,306,money(state,"¥3,286"),{color=B}); g:text(44,340,"预算使用 68%",{color=B})
  g:line(238,272,238,354,{color=B}); g:text(264,270,"待付款",{color=B}); g:text(264,306,money(state,"¥1,454"),{color=B}); g:text(264,340,"2 项需确认",{color=B})
end

local function home(g,state)
  app_header(g,state); services(g); g:text(24,228,"我的账务",{color=B}); g:text(360,228,"8月31日",{color=B}); account_card(g,state)
  g:text(24,396,"生活服务",{color=B}); g:line(24,428,456,428,{color=B})
  local labels={{"余额","安全保护中"},{"还款","今晚20:00"},{"缴费","本周1项"},{"出行","今日地铁1次"}}
  for i,item in ipairs(labels) do local x=24+(i-1)*108; center(g,x,446,108,item[1]); center(g,x,478,108,item[2]); if i<4 then g:line(x+108,440,x+108,510,{color=B}) end end
  g:line(24,520,456,520,{color=B}); PkgImage.draw(g, "icon_reminder", 24, 542); g:text(88,544,"下一项 · 信用卡还款",{color=B}); g:text(88,578,"今天 20:00 前 · 已预留余额",{color=B})
  round_stroke(g,24,624,432,66,12,B,W); g:rect(24,636,6,42,{fill=true,color=B}); g:text(48,638,state.notice or "消费节奏稳定，本月仍在预算线内",{color=B}); g:text(378,656,"查看 >",{color=B})
  bottom_nav(g,state)
end

local function bills(g,state)
  app_header(g,state); g:text(24,96,"账单",{color=B}); g:text(368,96,"8月账单",{color=B})
  round_fill(g,24,132,84,38,10,B); center(g,24,142,84,"全部",W); round_stroke(g,118,132,84,38,10,B,W); center(g,118,142,84,"支出"); round_stroke(g,212,132,84,38,10,B,W); center(g,212,142,84,"收入")
  g:text(334,142,"上滑查看更多",{color=B}); g:line(24,184,456,184,{color=B})
  local last=math.min(#state.transactions,state.bill_offset+3)
  for index=state.bill_offset,last do
    local row=state.transactions[index]; local slot=index-state.bill_offset; local y=204+slot*118; local incoming=string.sub(row[4],1,1)=="+"
    g:circle(50,y+22,20,{fill=(incoming) and true or false,color=B}); g:text(44,y+12,incoming and "+" or "−",{color=incoming and W or B})
    g:text(86,y,row[2],{color=B}); g:text(86,y+34,row[1].." · "..row[3],{color=B}); g:text(348,y,state.show_amount and row[4] or "••••",{color=B}); g:text(348,y+34,state.show_amount and row[5] or "方式隐藏",{color=B}); g:line(86,y+84,456,y+84,{color=B})
  end
  g:text(24,690,state.show_amount and "右上角可隐藏金额" or "金额与支付方式已保护",{color=B}); bottom_nav(g,state)
end

local function reminders(g,state)
  app_header(g,state); local done=0; for i=1,#state.reminders do if state.reminder_done[i] then done=done+1 end end
  g:text(24,96,"付款待办",{color=B}); g:text(374,96,done.."/"..#state.reminders,{color=B}); g:line(24,132,456,132,{color=B})
  for i,row in ipairs(state.reminders) do
    local y=158+(i-1)*128; g:rect(24,y+5,40,40,{fill=(state.reminder_done[i]) and true or false,color=B}); if state.reminder_done[i] then g:text(35,y+13,"✓",{color=W}) end
    g:text(84,y,row[2],{color=B}); g:text(84,y+34,row[1].." · "..row[4],{color=B}); g:text(84,y+68,row[5],{color=B}); g:text(350,y,money(state,"¥"..row[3]),{color=B}); g:line(84,y+100,456,y+100,{color=B})
  end
  g:rect(24,674,432,30,{color=B}); center(g,24,680,432,"轻触方框标记已处理"); bottom_nav(g,state)
end

local function toggle(g,x,y,on)
  if on then round_fill(g,x,y,82,38,19,B) else round_stroke(g,x,y,82,38,19,B,W) end
  g:circle(on and (x+63) or (x+19),y+19,13,{fill=true,color=on and W or B})
end

local function security(g,state)
  app_header(g,state); g:text(24,96,"我的 · 隐私与安全",{color=B}); g:line(24,132,456,132,{color=B})
  PkgImage.draw(g, "icon_eye", 24, 158); g:text(88,160,"主应用显示完整金额",{color=B}); g:text(88,194,state.show_amount and "已展开，可随时关闭" or "默认隐藏，避免旁人瞥见",{color=B}); toggle(g,374,164,state.show_amount)
  g:line(24,234,456,234,{color=B}); PkgImage.draw(g, "icon_shield", 24, 258); g:text(88,260,"锁屏隐私级别 · 始终严格",{color=B}); g:text(88,296,"不显示金额、商户、尾号或支付方式",{color=B})
  round_stroke(g,24,344,432,132,12,B,W); g:text(44,360,"安全中心",{color=B}); g:text(44,396,"账户保护正常",{color=B}); g:text(264,396,"设备管理  1 台",{color=B}); g:text(44,432,"最近登录无异常",{color=B})
  g:text(24,506,"隐私锁屏只回答",{color=B}); g:text(24,544,"· 有没有待处理付款",{color=B}); g:text(24,578,"· 最近的时间窗口",{color=B}); g:text(24,612,"· 本月是否仍在预算内",{color=B})
  round_fill(g,24,650,432,54,12,B); center(g,24,667,432,state.lock_status,W); bottom_nav(g,state)
end

function on_load(ctx)
  if not ctx.state.alipay_money_brief then ctx.state.alipay_money_brief={page=1,show_amount=false,bill_offset=1,reminder_done={false,false,false,false},lock_status="设为隐私锁屏",notice=nil} end
  local s=ctx.state.alipay_money_brief; s.transactions=read_rows(ctx,"transactions.tsv",12288); s.reminders=read_rows(ctx,"reminders.tsv",8192); ctx:set_tick(0)
end


function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=ctx.state.alipay_money_brief
  if s.page==1 then home(g,s) elseif s.page==2 then bills(g,s) elseif s.page==3 then reminders(g,s) else security(g,s) end
end

function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s=ctx.state.alipay_money_brief
  if ev.gesture=="tap" and ev.y>=710 then s.page=math.max(1,math.min(4,math.floor(ev.x/120)+1))
  elseif ev.gesture=="tap" and ev.y>=8 and ev.y<=72 and ev.x>=386 then s.show_amount=not s.show_amount
  elseif s.page==1 and ev.gesture=="tap" and ev.y>=82 and ev.y<=220 then
    local action=math.max(1,math.min(4,math.floor((ev.x-24)/108)+1)); if action==1 then s.notice="扫一扫为离线界面演示" elseif action==2 then s.notice="付款码为离线界面演示" elseif action==3 then s.page=2 else s.page=4 end
  elseif s.page==1 and ev.gesture=="tap" and ev.y>=614 and ev.y<710 then s.page=3
  elseif s.page==2 and ev.gesture=="swipe_up" then s.bill_offset=math.min(math.max(1,#s.transactions-3),s.bill_offset+1)
  elseif s.page==2 and ev.gesture=="swipe_down" then s.bill_offset=math.max(1,s.bill_offset-1)
  elseif s.page==3 and ev.gesture=="tap" and ev.y>=152 and ev.y<670 then local selected=math.floor((ev.y-158)/128)+1; if selected<1 or selected>#s.reminders then return false end; s.reminder_done[selected]=not s.reminder_done[selected]
  elseif s.page==4 and ev.gesture=="tap" and ev.y>=150 and ev.y<=226 then s.show_amount=not s.show_amount
  elseif s.page==4 and ev.gesture=="tap" and ev.y>=640 and ev.y<710 then if ctx.lockscreen then ctx.lockscreen:set_default() end; s.lock_status="已设为隐私锁屏"
  else return false end
  ctx:invalidate(); return true
end
