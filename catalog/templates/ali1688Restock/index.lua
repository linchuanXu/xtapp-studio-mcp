local PkgImage = require("pkg_image")
local B, W = 15, 0
local NAV = {"首页", "补货", "询价", "我的"}

local function round_fill(g, x, y, w, h, r, color)
  r = math.max(1, math.min(r, math.floor(w / 2), math.floor(h / 2)))
  g:rect(x + r, y, w - r * 2, h,{fill=true,color=color}); g:rect(x, y + r, w, h - r * 2,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color}); g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
  g:circle(x + r, y + h - 1 - r, r,{fill=true,color=color}); g:circle(x + w - 1 - r, y + h - 1 - r, r,{fill=true,color=color})
end

local function round_stroke(g, x, y, w, h, r, color, bg)
  round_fill(g, x, y, w, h, r, color); round_fill(g, x + 2, y + 2, w - 4, h - 4, math.max(1, r - 2), bg or W)
end

local function split(line)
  local out = {}
  for value in (line .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = value end
  return out
end

local function load_inventory(ctx)
  local out = {}
  local reader = ctx.package:open_text("inventory.tsv", {max_line_bytes=512})
  if not reader then return out end
  reader:read_line()
  while true do
    local line = reader:read_line()
    if not line then break end
    local f = split(line)
    out[#out + 1] = {sku=f[1], name=f[2], stock=tonumber(f[3]) or 0, safe=tonumber(f[4]) or 0, moq=tonumber(f[5]) or 1, price=tonumber(f[6]) or 0, supplier=f[7], lead=f[8], status=f[9]}
  end
  reader:close()
  return out
end

local function center(g, x, y, width, text, color)
  local units, i = 0, 1
  while i <= #text do if text:byte(i) >= 0xE0 then units, i = units + 20, i + 3 else units, i = units + 10, i + 1 end end
  g:text(x + math.max(0, math.floor((width - units) / 2)), y, text, {color=color or B})
end

local function app_header(g)
  g:clear(W); PkgImage.draw(g, "brand_mark", 24, 12); g:text(350, 28, "采购工作台", {color=B}); g:line(24, 72, 456, 72,{color=B})
end

local function search_bar(g)
  round_stroke(g, 24, 86, 432, 56, 14, B, W); g:circle(48, 110, 9,{color=B}); g:line(55, 117, 63, 125,{color=B})
  g:text(74, 101, "搜索货源 / 工厂 / 货号", {color=B}); round_fill(g, 366, 86, 90, 56, 14, B); center(g, 366, 103, 90, "找货", W)
end

local function bottom_nav(g, state)
  g:line(24, 716, 456, 716,{color=B})
  for i, label in ipairs(NAV) do
    local x = (i - 1) * 120
    if i == 1 then
      g:rect(x + 51, 729, 18, 16,{fill=(state.page == i) and true or false,color=B}); g:line(x + 48, 732, x + 60, 722,{color=B}); g:line(x + 60, 722, x + 72, 732,{color=B})
    elseif i == 2 then
      g:rect(x + 50, 724, 20, 21,{fill=(state.page == i) and true or false,color=B}); g:line(x + 50, 730, x + 70, 730,{color=state.page == i and W or B})
    elseif i == 3 then
      g:rect(x + 48, 725, 24, 19,{color=B}); g:line(x + 52, 731, x + 68, 731,{color=B}); g:line(x + 52, 737, x + 64, 737,{color=B})
    else
      g:circle(x + 60, 729, 8,{fill=(state.page == i) and true or false,color=B}); g:line(x + 48, 744, x + 72, 744,{color=B})
    end
    center(g, x, 756, 120, label); if state.page == i then g:rect(x + 34, 790, 52, 4,{fill=true,color=B}) end
  end
end

local function metric(g, x, label, value, note)
  g:text(x, 190, label, {color=B}); g:text(x, 218, value, {color=B}); g:text(x, 244, note, {color=B})
end

local function supply_row(g, item, y, urgent)
  if urgent then g:rect(24, y, 5, 82,{fill=true,color=B}) end
  PkgImage.draw(g, item.stock < 20 and "icon_alert" or "icon_box", 38, y + 8)
  g:text(96, y + 2, item.name, {color=B}); g:text(96, y + 32, "库存 " .. item.stock .. " · MOQ " .. item.moq .. " 件起", {color=B})
  g:text(96, y + 60, item.supplier .. " · " .. item.lead, {color=B}); g:text(356, y + 2, "¥" .. string.format("%.2f", item.price), {color=B}); g:line(96, y + 86, 456, y + 86,{color=B})
end

local function home(g, state)
  app_header(g); search_bar(g); g:text(24, 158, "采购速览", {color=B})
  metric(g, 24, "急需补货", "2 款", "2天售罄"); metric(g, 174, "待回询价", "3 条", "1条降价"); metric(g, 334, "在途货品", "2 箱", "明日到")
  g:line(154, 186, 154, 262,{color=B}); g:line(314, 186, 314, 262,{color=B}); g:line(24, 274, 456, 274,{color=B})
  g:text(24, 290, "今日急采", {color=B}); g:text(350, 290, "按缺口排序", {color=B})
  for i=1,3 do supply_row(g, state.items[i], 326 + (i - 1) * 94, i == 1) end
  round_stroke(g, 24, 614, 432, 82, 12, B, W); PkgImage.draw(g, "icon_factory", 38, 630); g:text(98, 626, "找源头工厂", {color=B}); g:text(98, 658, "3 家供应商刚更新交期与报价", {color=B})
  round_fill(g, 358, 626, 82, 44, 10, B); center(g, 358, 638, 82, "去询价", W); bottom_nav(g, state)
end

local function restock(g, state)
  app_header(g); search_bar(g)
  round_fill(g, 24, 158, 88, 38, 10, B); center(g, 24, 168, 88, "低库存", W); round_stroke(g, 122, 158, 88, 38, 10, B, W); center(g, 122, 168, 88, "急需")
  round_stroke(g, 220, 158, 88, 38, 10, B, W); center(g, 220, 168, 88, "全部"); g:text(344, 168, "上滑查看更多", {color=B})
  local last = math.min(#state.items, state.offset + 3)
  for index=state.offset,last do supply_row(g, state.items[index], 214 + (index-state.offset)*116, index == state.offset) end
  g:text(24, 688, "轻触商品比较 MOQ、价格与交期", {color=B}); bottom_nav(g, state)
end

local function quote_card(g, y, icon, title, supplier, offer, note, active)
  g:rect(24, y, 432, 126,{color=B}); if active then g:rect(24, y, 6, 126,{fill=true,color=B}) end; PkgImage.draw(g, icon, 40, y + 14)
  g:text(102, y + 10, title, {color=B}); g:text(102, y + 40, supplier, {color=B}); g:text(40, y + 78, offer, {color=B}); g:text(264, y + 78, note, {color=B})
end

local function quotes(g, state)
  app_header(g); search_bar(g); g:text(24, 160, "找工厂 · 询价动态", {color=B}); g:text(346, 160, "3 条待处理", {color=B})
  quote_card(g, 198, "icon_quote", "多口快充插座", "深圳拓能电气", "降至 ¥41.60", "20件起 · 2天", true)
  quote_card(g, 338, "icon_factory", "桌面循环风扇", "东莞清风科技", "现货 ¥45.00", "24件起 · 3天", false)
  quote_card(g, 478, "icon_quote", "食品级保鲜盒", "台州简物塑业", "100件减 ¥0.6", "50件起 · 4天", false)
  round_fill(g, 24, 626, 432, 62, 12, B); center(g, 24, 647, 432, "查看全部询价待办", W); bottom_nav(g, state)
end

local function tasks(g, state)
  app_header(g); g:text(24, 94, "我的采购", {color=B}); g:text(350, 94, "今日 4 项", {color=B}); g:rect(24, 128, 432, 90,{color=B})
  g:text(42, 144, "待付款 1", {color=B}); g:text(174, 144, "待发货 2", {color=B}); g:text(320, 144, "在途 2", {color=B})
  g:text(42, 180, "¥1,588", {color=B}); g:text(174, 180, "预计明日", {color=B}); g:text(320, 180, "共 3 箱", {color=B})
  local rows={{"确认露营灯补货量","缺口 31 件 · 优先"},{"回复快充插座降价","报价 12:00 前有效"},{"核对保鲜盒样品","质检记录已到"},{"合并义乌供应商运费","预计节省 ¥86"}}
  for i,row in ipairs(rows) do
    local y=244+(i-1)*104; g:rect(24,y+5,38,38,{fill=(state.done[i]) and true or false,color=B}); if state.done[i] then g:text(35,y+13,"✓",{color=W}) end
    g:text(86,y,row[1],{color=B}); g:text(86,y+34,row[2],{color=B}); g:line(86,y+78,456,y+78,{color=B})
  end
  PkgImage.draw(g, "icon_truck", 24, 660); g:text(88,664,"下一批到货 · 明天 14:00",{color=B}); bottom_nav(g,state)
end

local function detail(g, state)
  local item=state.items[state.detail]; app_header(g); g:text(24,94,item.name,{color=B}); g:text(24,126,item.sku.." · "..item.status,{color=B}); g:line(24,162,456,162,{color=B})
  g:text(24,186,"当前库存",{color=B}); g:text(154,186,tostring(item.stock),{color=B}); g:text(264,186,"安全库存",{color=B}); g:text(398,186,tostring(item.safe),{color=B})
  g:text(24,234,"采购数量",{color=B}); round_stroke(g,190,220,64,48,10,B,W); center(g,190,234,64,"−"); round_fill(g,258,220,96,48,10,B); center(g,258,234,96,tostring(state.qty),W)
  round_stroke(g,358,220,64,48,10,B,W); center(g,358,234,64,"+"); g:text(24,292,"MOQ "..item.moq.." 件 · 按起订量取整",{color=B}); g:line(24,330,456,330,{color=B}); g:text(24,352,"三档工厂报价",{color=B})
  local qs={{item.supplier,item.price,item.lead},{"杭州拾光供应链",item.price+1.20,"2天"},{"金华优选工厂",math.max(1,item.price-0.80),"5天"}}
  for i,q in ipairs(qs) do local y=394+(i-1)*84; g:rect(24,y,432,68,{color=B}); if state.supplier==i then g:rect(24,y,6,68,{fill=true,color=B}) end; g:text(44,y+12,q[1],{color=B}); g:text(294,y+12,"¥"..string.format("%.2f",q[2]),{color=B}); g:text(388,y+40,q[3],{color=B}) end
  g:text(24,660,"预计货款",{color=B}); g:text(314,660,"¥"..string.format("%.2f",qs[state.supplier][2]*state.qty),{color=B}); round_stroke(g,24,708,128,64,12,B,W); center(g,24,730,128,"返回")
  round_fill(g,168,708,288,64,12,B); center(g,168,730,288,"生成采购单",W)
end

function on_load(ctx)
  if not ctx.state.ali_1688_restock then ctx.state.ali_1688_restock={page=1,offset=1,detail=nil,qty=30,supplier=1,done={false,false,false,false}} end
  ctx.state.ali_1688_restock.items=load_inventory(ctx); ctx:set_tick(0)
end


function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=ctx.state.ali_1688_restock
  if s.detail then detail(g,s) elseif s.page==1 then home(g,s) elseif s.page==2 then restock(g,s) elseif s.page==3 then quotes(g,s) else tasks(g,s) end
end

function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s=ctx.state.ali_1688_restock
  if s.detail then
    local item=s.items[s.detail]; if ev.gesture~="tap" then return false end
    if ev.y>=214 and ev.y<=282 then if ev.x>=184 and ev.x<258 then s.qty=math.max(item.moq,s.qty-item.moq) elseif ev.x>=350 and ev.x<=430 then s.qty=s.qty+item.moq else return false end
    elseif ev.y>=388 and ev.y<650 then s.supplier=math.max(1,math.min(3,math.floor((ev.y-394)/84)+1))
    elseif ev.y>=700 and ev.x<160 then s.detail=nil elseif ev.y>=700 then s.done[1]=true; s.detail=nil; s.page=4 else return false end
  elseif ev.gesture=="tap" and ev.y>=710 then s.page=math.max(1,math.min(4,math.floor(ev.x/120)+1))
  elseif ev.gesture=="tap" and ev.y>=82 and ev.y<=150 then s.page=2; s.offset=1
  elseif s.page==1 and ev.gesture=="tap" and ev.y>=320 and ev.y<608 then local selected=math.floor((ev.y-326)/94)+1; if selected<1 or selected>3 then return false end; s.detail=selected; s.qty=s.items[selected].moq; s.supplier=1
  elseif s.page==1 and ev.gesture=="tap" and ev.y>=608 and ev.y<708 then s.page=3
  elseif s.page==2 and ev.gesture=="swipe_up" then s.offset=math.min(math.max(1,#s.items-3),s.offset+1)
  elseif s.page==2 and ev.gesture=="swipe_down" then s.offset=math.max(1,s.offset-1)
  elseif s.page==2 and ev.gesture=="tap" and ev.y>=208 and ev.y<690 then local selected=s.offset+math.floor((ev.y-214)/116); if selected<1 or selected>#s.items then return false end; s.detail=selected; s.qty=s.items[selected].moq; s.supplier=1
  elseif s.page==3 and ev.gesture=="tap" and ev.y>=616 and ev.y<708 then s.page=4
  elseif s.page==4 and ev.gesture=="tap" and ev.y>=238 and ev.y<660 then local selected=math.floor((ev.y-244)/104)+1; if selected<1 or selected>4 then return false end; s.done[selected]=not s.done[selected]
  else return false end
  ctx:invalidate(); return true
end
