-- 自选行情：本地保存自选，以虚拟键盘录入代码，按顺序请求固定 GET 报价路由。
local BLACK, WHITE = 15, 0
local HK_API = "http://193.112.174.92:28473/demo/stock/xtapp?symbol="
local DETAIL_API = "http://193.112.174.92:28473/demo/market/detail/xtapp?kind="
local PROTOCOL = "XTAPP_STOCK_V1"
local task_id, request_index = nil, nil
local on_net_done
local MARKETS = { "hk", "a", "us" }
local MARKET_LABELS = { hk="港股", a="A股", us="美股" }
local DEFAULTS = {
  { kind="hk", symbol="00700", label="腾讯控股" }, { kind="hk", symbol="03690", label="美团" },
  { kind="a", symbol="sh600519", label="贵州茅台" }, { kind="us", symbol="AAPL", label="苹果" },
}
local NUMBER_PAD = { { "1","2","3" }, { "4","5","6" }, { "7","8","9" }, { "back","0","done" } }
local A_EXCHANGES = { { "SH", "SZ", "BJ" } }
local US_KEYBOARD = {
  { "Q","W","E","R","T","Y","U","I","O","P" },
  { "A","S","D","F","G","H","J","K","L" },
  { "Z","X","C","V","B","N","M","back","done" },
}

local function fresh_items()
  local out={}; for _,item in ipairs(DEFAULTS) do out[#out+1]={kind=item.kind,symbol=item.symbol,label=item.label} end; return out
end
local function state(ctx)
  ctx.state.watchlist_live=ctx.state.watchlist_live or { items=fresh_items(), selected=1, status="idle", mode="list" }
  local s=ctx.state.watchlist_live
  s.items=s.items or fresh_items(); s.selected=math.max(1,math.min(#s.items,s.selected or 1)); s.mode=s.mode or "list"
  if s.mode=="list" and s.editor then s.editor=nil end
  return s
end
local function text_width(value)
  local n,i,value=0,1,tostring(value or "")
  while i<=#value do local b=value:byte(i); if b>=0xE0 then n,i=n+18,i+3 elseif b>=0xC0 then n,i=n+18,i+2 else n,i=n+9,i+1 end end
  return n
end
local function right(g,x,y,value,color) g:text(x-text_width(value),y,tostring(value or "--"),{color=color or BLACK}) end
local function center(g,x,y,w,value,color) g:text(x+math.max(0,math.floor((w-text_width(value))/2)),y,tostring(value),{color=color or BLACK}) end
local function dotted(g,x,y,w) for px=x,x+w,8 do g:rect(px,y,2,2,{fill=true,color=BLACK}) end end
local function fmt_price(value)
  local n=tonumber(value); if not n then return "--" end
  if math.abs(n)>=1000 then return string.format("%.1f",n) elseif math.abs(n)>=100 then return string.format("%.2f",n) else return string.format("%.3f",n) end
end
local function fmt_rate(value) local n=tonumber(value); return n and string.format("%+.2f%%",n) or "--" end
local function endpoint(item)
  if item.kind=="hk" then return HK_API..item.symbol end
  return DETAIL_API..item.kind.."&symbol="..item.symbol
end
local function parse(body)
  if type(body)~="string" or body:match("^([^\r\n]+)")~=PROTOCOL then return nil end
  local quote={}; for line in body:gmatch("[^\r\n]+") do local k,v=line:match("^([^\t]+)\t(.*)$"); if k then quote[k]=v end end
  return quote.symbol and tonumber(quote.price) and quote or nil
end
local function request_next(ctx)
  local s=state(ctx); local i=s.refresh_index
  if not i or i>#s.items then s.refresh_index=nil; s.status="ready"; ctx:invalidate(); return end
  if not ctx.net then s.status="no_net"; s.refresh_index=nil; ctx:invalidate(); return end
  local id,err=ctx.net:request({ url = endpoint(s.items[i]) }, on_net_done)
  if not id then s.items[i].quote=nil; s.status=tostring(err or "error"); s.refresh_index=nil; ctx:invalidate(); return end
  task_id,request_index,s.status=id,i,"loading"; ctx:invalidate()
end
local function refresh(ctx)
  local s=state(ctx); if task_id or #s.items==0 then return end; s.refresh_index=1; s.status="loading"; request_next(ctx)
end

-- 大号报价使用自绘七段数码字，避免主信息退回默认字形。
local SEGMENTS={ ["0"]="abcdef",["1"]="bc",["2"]="abdeg",["3"]="abcdg",["4"]="bcfg",["5"]="acdfg",["6"]="acdefg",["7"]="abc",["8"]="abcdefg",["9"]="abcdfg" }
local function has_segment(s,key) return s and s:find(key,1,true)~=nil end
local function digit_w(ch) return ch=="." and 8 or 20 end
local function quote_w(value) local total=0; for i=1,#value do total=total+digit_w(value:sub(i,i)) end; return total end
local function draw_digit(g,x,y,ch)
  if ch=="." then g:rect(x+2,y+31,4,4,{fill=true,color=BLACK}); return 8 end
  local s=SEGMENTS[ch]; if not s then return 20 end
  local w,h,t=17,35,3
  if has_segment(s,"a") then g:rect(x+3,y,w-6,t,{fill=true,color=BLACK}) end
  if has_segment(s,"b") then g:rect(x+w-t,y+3,t,12,{fill=true,color=BLACK}) end
  if has_segment(s,"c") then g:rect(x+w-t,y+20,t,12,{fill=true,color=BLACK}) end
  if has_segment(s,"d") then g:rect(x+3,y+h-t,w-6,t,{fill=true,color=BLACK}) end
  if has_segment(s,"e") then g:rect(x,y+20,t,12,{fill=true,color=BLACK}) end
  if has_segment(s,"f") then g:rect(x,y+3,t,12,{fill=true,color=BLACK}) end
  if has_segment(s,"g") then g:rect(x+3,y+16,w-6,t,{fill=true,color=BLACK}) end
  return 20
end
local function draw_quote(g,right_x,y,value)
  local shown=fmt_price(value); local x=right_x-quote_w(shown)
  for i=1,#shown do x=x+draw_digit(g,x,y,shown:sub(i,i)) end
end

local function keyboard_for(e)
  if e.kind=="us" then return US_KEYBOARD end
  if e.kind=="a" and #e.buffer<2 then return A_EXCHANGES end
  return NUMBER_PAD
end
local function keyboard_rect(keyboard,ri,ci)
  local row=keyboard[ri]; local margin,gap=18,7; local available=480-margin*2; local w=math.floor((available-gap*(#row-1))/#row); local used=w*#row+gap*(#row-1)
  local h = keyboard==NUMBER_PAD and 68 or 50
  return math.floor((480-used)/2)+(ci-1)*(w+gap), 322+(ri-1)*(h+8), w, h
end
local function key_label(key)
  if key=="back" then return "删除" elseif key=="done" then return "完成"
  elseif key=="SH" then return "沪  SH" elseif key=="SZ" then return "深  SZ" elseif key=="BJ" then return "北  BJ" end
  return key
end
local function hit_keyboard(x,y,e)
  local keyboard=keyboard_for(e)
  for ri,row in ipairs(keyboard) do for ci,key in ipairs(row) do local kx,ky,kw,kh=keyboard_rect(keyboard,ri,ci); if x>=kx and x<=kx+kw and y>=ky and y<=ky+kh then return ri,ci,key end end end
  return nil,nil,nil
end
local function valid_symbol(kind,symbol)
  if kind=="hk" then return symbol:match("^%d%d%d%d%d$") and symbol or nil end
  if kind=="a" then local lower=string.lower(symbol); return lower:match("^[sb][hz]%d%d%d%d%d%d$") and lower or nil end
  return symbol:match("^[A-Z][A-Z0-9%.%-]*$") and #symbol<=8 and symbol or nil
end
local function open_editor(ctx)
  local s=state(ctx); s.mode="editor"; s.editor={kind="hk",buffer="",kb_row=1,kb_col=1,message=""}; ctx:invalidate()
end
local function editor_key(ctx,key)
  local s=state(ctx); local e=s.editor; if not e then return end
  if key=="back" then e.buffer=e.buffer:sub(1,math.max(0,#e.buffer-1)); e.message=""
  elseif key=="done" then
    local symbol=valid_symbol(e.kind,e.buffer)
    if not symbol then e.message=e.kind=="hk" and "港股需为五位数字" or (e.kind=="a" and "A股：sh / sz / bj 加六位数字" or "美股请输入 1–8 位代码"); ctx:invalidate(); return end
    if #s.items>=5 then e.message="最多保存五只，删除后再添加"; ctx:invalidate(); return end
    for _,item in ipairs(s.items) do if item.kind==e.kind and item.symbol==symbol then e.message="这只已经在自选中"; ctx:invalidate(); return end end
    s.items[#s.items+1]={kind=e.kind,symbol=symbol,label=symbol}; s.selected=#s.items; s.mode="list"; s.editor=nil; s.status="idle"; refresh(ctx); return
  elseif key=="SH" or key=="SZ" or key=="BJ" then e.buffer=key; e.kb_row,e.kb_col=1,1; e.message=""
  elseif #e.buffer<8 then e.buffer=e.buffer..key; e.message="" end
  ctx:invalidate()
end
local function open_delete(ctx)
  local s=state(ctx); if #s.items==0 then return end; s.mode="delete"; s.delete_choice=false; ctx:invalidate()
end
local function confirm_delete(ctx,confirm)
  local s=state(ctx); if confirm and s.items[s.selected] then table.remove(s.items,s.selected); s.selected=math.max(1,math.min(#s.items,s.selected)); s.status="idle" end
  s.mode="list"; s.delete_choice=false; ctx:invalidate()
end

function on_load(ctx) local s=state(ctx); if s.status=="idle" then refresh(ctx) end end
on_net_done = function(ctx, result)
  local s=state(ctx); local index=request_index; task_id,request_index=nil,nil
  if index and s.items[index] then local quote=result.ok and parse(result.body) or nil; s.items[index].quote=quote; if quote and quote.name and quote.name~="" then s.items[index].label=quote.name end end
  s.refresh_index=(index or 0)+1; request_next(ctx)
end
function on_leave(ctx) if task_id and ctx.net then task_id:cancel() end; task_id,request_index=nil,nil end

local function move_keyboard(e,dr,dc)
  local keyboard=keyboard_for(e); local ri=math.max(1,math.min(#keyboard,(e.kb_row or 1)+dr)); local ci=math.max(1,math.min(#keyboard[ri],(e.kb_col or 1)+dc)); e.kb_row,e.kb_col=ri,ci
end
function on_input(ctx,ev)
  local s=state(ctx)
  if s.mode=="editor" then
    local e=s.editor
    if ev.type=="key" and ev.phase=="down" then
      if ev.key=="left" then move_keyboard(e,0,-1) elseif ev.key=="right" then move_keyboard(e,0,1) elseif ev.key=="up" then move_keyboard(e,-1,0) elseif ev.key=="down" then move_keyboard(e,1,0)
      elseif ev.key=="ok" then local keyboard=keyboard_for(e); editor_key(ctx,keyboard[e.kb_row][e.kb_col]); return true
      elseif ev.key=="back" then if #e.buffer>0 then editor_key(ctx,"back") else s.mode="list"; s.editor=nil end end
      ctx:invalidate(); return true
    end
    if (ev.type == "pointer" and ev.phase == "up") and ev.gesture=="tap" then
      if ev.y>=108 and ev.y<=152 then if ev.x<160 then e.kind="hk" elseif ev.x<320 then e.kind="a" else e.kind="us" end; e.buffer=""; e.kb_row,e.kb_col=1,1; e.message=""; ctx:invalidate(); return true end
      if ev.y<72 and ev.x>384 then s.mode="list"; s.editor=nil; ctx:invalidate(); return true end
      local ri,ci,key=hit_keyboard(ev.x,ev.y,e); if key then e.kb_row,e.kb_col=ri,ci; editor_key(ctx,key); return true end
    end
    return false
  end
  if s.mode=="delete" then
    if ev.type=="key" and ev.phase=="down" then if ev.key=="left" or ev.key=="right" then s.delete_choice=not s.delete_choice; ctx:invalidate(); return true elseif ev.key=="ok" then confirm_delete(ctx,s.delete_choice); return true elseif ev.key=="back" then confirm_delete(ctx,false); return true end end
    if (ev.type == "pointer" and ev.phase == "up") and ev.gesture=="tap" then confirm_delete(ctx,ev.y>=428 and ev.y<=490 and ev.x<240); return true end
    return false
  end
  if ev.type=="key" and ev.phase=="down" then
    if ev.key=="up" then s.selected=math.max(1,s.selected-1); ctx:invalidate(); return true end
    if ev.key=="down" then s.selected=math.min(#s.items,s.selected+1); ctx:invalidate(); return true end
    if ev.key=="ok" then refresh(ctx); return true end
    if ev.key=="right" then open_editor(ctx); return true end
    if ev.key=="left" then open_delete(ctx); return true end
    if ev.key=="back" then ctx:quit(); return true end
  end
  if (ev.type == "pointer" and ev.phase == "up") and ev.gesture=="tap" then
    if ev.y<70 then if ev.x>400 then open_delete(ctx) elseif ev.x>334 then open_editor(ctx) elseif ev.x>255 then refresh(ctx) end; return true end
    if ev.y>=116 then local index=math.floor((ev.y-116)/122)+1; if index>=1 and index<=#s.items then s.selected=index; ctx:invalidate(); return true end end
  end
  return false
end

local function draw_editor(g,e)
  g:text(24,26,"添加自选",{color=BLACK}); right(g,456,28,"取消"); g:text(24,54,"输入证券代码",{color=BLACK}); dotted(g,24,80,432)
  local xs={24,168,312}; for i,key in ipairs(MARKETS) do local active=e.kind==key; g:rect(xs[i],108,132,42,{fill=(active) and true or false,color=BLACK}); center(g,xs[i],120,132,MARKET_LABELS[key],active and WHITE or BLACK) end
  g:rect(24,178,432,76,{color=BLACK}); g:text(42,194,"代码",{color=BLACK}); g:text(42,222,(e.buffer=="" and "点击下方键盘输入" or e.buffer).."_",{color=BLACK})
  if e.message~="" then center(g,24,270,432,e.message,BLACK) elseif e.kind=="hk" then center(g,24,270,432,"五位数字 · 九宫格输入",BLACK) elseif e.kind=="a" and #e.buffer<2 then center(g,24,270,432,"先选择交易所",BLACK) elseif e.kind=="a" then center(g,24,270,432,"已选 "..e.buffer:sub(1,2).." · 输入六位数字",BLACK) else center(g,24,270,432,"美股：大写字母或数字",BLACK) end
  local keyboard=keyboard_for(e)
  for ri,row in ipairs(keyboard) do for ci,key in ipairs(row) do local x,y,w,h=keyboard_rect(keyboard,ri,ci); local focus=ri==e.kb_row and ci==e.kb_col; if focus then g:rect(x,y,w,h,{fill=true,color=BLACK}) else g:rect(x,y,w,h,{color=BLACK}) end; center(g,x,y+math.floor((h-16)/2),w,key_label(key),focus and WHITE or BLACK) end end
end
local function draw_delete(g,s)
  local item=s.items[s.selected]; g:text(24,26,"移除自选",{color=BLACK}); dotted(g,24,62,432)
  center(g,24,210,432,"确认删除这只自选？",BLACK); center(g,24,244,432,(item.label or item.symbol).." · "..item.symbol,BLACK)
  local confirm=s.delete_choice; g:rect(24,428,204,54,{fill=(confirm) and true or false,color=BLACK}); center(g,24,446,204,"删除",confirm and WHITE or BLACK)
  g:rect(252,428,204,54,{fill=((not confirm)) and true or false,color=BLACK}); center(g,252,446,204,"保留",(not confirm) and WHITE or BLACK)
end
local function draw_list(g,s)
  g:text(24,25,"自选行情",{color=BLACK}); right(g,308,27,s.status=="loading" and "更新中" or "刷新"); right(g,384,27,"添加"); right(g,456,27,"删除")
  local synced=0; for _,item in ipairs(s.items) do if item.quote then synced=synced+1 end end
  g:text(24,53,"我的清单",{color=BLACK}); right(g,456,53,(s.status=="loading" and "正在逐条更新" or (synced.." / "..#s.items.." 已同步")))
  dotted(g,24,82,432)
  if #s.items==0 then center(g,24,360,432,"还没有自选，点击添加",BLACK); return end
  for i,item in ipairs(s.items) do
    local y=106+(i-1)*122; if y>715 then break end; local selected=i==s.selected; local quote=item.quote
    g:rect(16,y,448,108,{color=BLACK}); if selected then g:rect(16,y,5,108,{fill=true,color=BLACK}) end
    g:text(30,y+14,item.label or item.symbol,{color=BLACK}); g:text(30,y+40,MARKET_LABELS[item.kind].."  "..item.symbol,{color=BLACK})
    if quote then
      draw_quote(g,438,y+13,quote.price); right(g,438,y+58,fmt_rate(quote.changeRate))
      -- 分隔线只服务左侧信息列，不能延伸到右侧涨跌幅与报价区域。
      dotted(g,30,y+70,350); g:text(30,y+82,"今开 "..fmt_price(quote.open),{color=BLACK}); g:text(174,y+82,"最高 "..fmt_price(quote.high),{color=BLACK}); right(g,438,y+82,"最低 "..fmt_price(quote.low))
    else center(g,190,y+48,244,s.status=="loading" and "读取中" or "暂未取得报价",BLACK) end
  end
end
function on_draw(ctx,g)
  local s=state(ctx); g:clear(WHITE)
  if s.mode=="editor" then draw_editor(g,s.editor) elseif s.mode=="delete" then draw_delete(g,s) else draw_list(g,s) end
end
