local M = {}
M.BLACK = 15
M.WHITE = 0
M.WEEKDAYS = { "日", "一", "二", "三", "四", "五", "六" }
local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local DIGITS = {
  ["0"]={"111","101","101","101","111"}, ["1"]={"010","110","010","010","111"},
  ["2"]={"111","001","111","100","111"}, ["3"]={"111","001","111","001","111"},
  ["4"]={"101","101","111","001","001"}, ["5"]={"111","100","111","001","111"},
  ["6"]={"111","100","111","101","111"}, ["7"]={"111","001","010","010","010"},
  ["8"]={"111","101","111","101","111"}, ["9"]={"111","101","111","001","111"},
}
function M.clamp(value, minimum, maximum) if value < minimum then return minimum end if value > maximum then return maximum end return value end
function M.is_leap(year) return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0 end
function M.month_days(year, month) if month == 2 and M.is_leap(year) then return 29 end return MONTH_DAYS[month] end
function M.project(ctx)
  local clock = ctx.sys:clock()
  if not clock.valid or clock.hour == nil or clock.minute == nil or clock.year == nil or clock.month == nil or clock.day == nil then return nil end
  local year_day = clock.day
  for month = 1, clock.month - 1 do year_day = year_day + M.month_days(clock.year, month) end
  return { year=clock.year, month=clock.month, day=clock.day, hour=clock.hour, min=clock.minute, wday=clock.weekday, year_day=year_day }
end
function M.first_wday(year, month)
  local days = 0
  for y = 1970, year - 1 do days = days + (M.is_leap(y) and 366 or 365) end
  for m = 1, month - 1 do days = days + M.month_days(year, m) end
  return (days + 4) % 7
end
function M.text_width(text) local width, i = 0, 1; while i <= #text do if text:byte(i) >= 0xE0 then width, i = width + 20, i + 3 else width, i = width + 10, i + 1 end end return width end
function M.center(g, x, y, width, text, color) g:text(x + math.floor((width - M.text_width(text)) / 2), y, text, { color=color or M.BLACK }) end
function M.pad(value) return string.format("%02d", value) end
function M.draw_blocks(g, text, x, y, width, max_height, color, inverted)
  local units = 0
  for i=1,#text do units = units + (text:sub(i,i) == ":" and 1 or 3) end
  local gap_units = #text - 1; local cell = math.max(2, math.floor(math.min(max_height / 5, width / (units + gap_units * 0.42))))
  local gap = math.max(2, math.floor(cell * 0.42)); local total = units * cell + gap_units * gap; local cursor = x + math.floor((width-total)/2)
  local block = math.max(2, cell - math.max(1, math.floor(cell*0.12))); local ink = color or M.BLACK
  for i=1,#text do local char=text:sub(i,i)
    if char == ":" then g:rect(cursor,y+cell,block,block,"fill",ink); g:rect(cursor,y+cell*3,block,block,"fill",ink); cursor=cursor+cell+gap
    else local rows=DIGITS[char]; if rows then for row=1,5 do for col=1,3 do if rows[row]:sub(col,col)=="1" then g:rect(cursor+(col-1)*cell,y+(row-1)*cell,block,block,"fill",ink) elseif inverted then g:rect(cursor+(col-1)*cell,y+(row-1)*cell,block,block,"stroke",ink) end end end end; cursor=cursor+cell*3+gap end
  end
end
local SEGMENTS = { ["0"]="abcedf", ["1"]="bc", ["2"]="abdeg", ["3"]="abcdg", ["4"]="bcfg", ["5"]="acdfg", ["6"]="acdefg", ["7"]="abc", ["8"]="abcdefg", ["9"]="abcdfg" }
function M.draw_segments(g,text,x,y,width,height,color)
  local digits, colons = 0, 0; for i=1,#text do if text:sub(i,i)==":" then colons=colons+1 else digits=digits+1 end end
  local unit=math.floor(width/(digits*1.25+colons*.55)); local digit_w=unit; local gap=math.floor(unit*.25); local colon_w=math.floor(unit*.55); local total=digits*(digit_w+gap)-gap+colons*colon_w
  local thick=math.max(3,math.floor(digit_w*0.075)); local digit_h=math.min(height,math.floor(digit_w*1.72)); local cursor=x+math.floor((width-total)/2)
  local function has(set,key) return set and string.find(set,key,1,true) end
  for i=1,#text do local ch=text:sub(i,i); if ch==":" then local radius=math.max(3,thick-1); g:circle(cursor+math.floor(colon_w/2),y+math.floor(digit_h*.34),radius,"fill",color); g:circle(cursor+math.floor(colon_w/2),y+math.floor(digit_h*.68),radius,"fill",color); cursor=cursor+colon_w else local s=SEGMENTS[ch]; local dw=digit_w-thick*2; local half=math.floor(digit_h/2); if has(s,"a") then g:rect(cursor+thick,y,dw,thick,"fill",color) end; if has(s,"b") then g:rect(cursor+digit_w-thick,y+thick,thick,half-thick*2,"fill",color) end; if has(s,"c") then g:rect(cursor+digit_w-thick,y+half+thick,thick,half-thick*2,"fill",color) end; if has(s,"d") then g:rect(cursor+thick,y+digit_h-thick,dw,thick,"fill",color) end; if has(s,"e") then g:rect(cursor,y+half+thick,thick,half-thick*2,"fill",color) end; if has(s,"f") then g:rect(cursor,y+thick,thick,half-thick*2,"fill",color) end; if has(s,"g") then g:rect(cursor+thick,y+half-math.floor(thick/2),dw,thick,"fill",color) end; cursor=cursor+digit_w+gap end end
end
local DOT_DIGITS = {
  ["0"]={"01110","11011","11011","11011","11011","11011","01110"},
  ["1"]={"00110","01110","00110","00110","00110","00110","01110"},
  ["2"]={"01110","11011","00011","00110","01100","11000","11111"},
  ["3"]={"11110","00011","00011","01110","00011","00011","11110"},
  ["4"]={"11011","11011","11011","11111","00011","00011","00011"},
  ["5"]={"11111","11000","11000","11110","00011","00011","11110"},
  ["6"]={"01110","11000","11000","11110","11011","11011","01110"},
  ["7"]={"11111","00011","00110","00110","01100","01100","01100"},
  ["8"]={"01110","11011","11011","01110","11011","11011","01110"},
  ["9"]={"01110","11011","11011","01111","00011","00011","01110"},
}
function M.draw_dots(g,text,x,y,width,height,color)
  local digits, colons=0,0; for i=1,#text do if text:sub(i,i)==":" then colons=colons+1 else digits=digits+1 end end
  local step=math.max(6,math.floor(math.min(height/6.4,width/(digits*6.1+colons*2.2)))); local radius=math.max(3,math.floor(step*.44)); local digit_w=step*5; local gap=math.floor(step*1.25); local colon_w=step*2
  local total=digits*(digit_w+gap)-gap+colons*colon_w; local cursor=x+math.floor((width-total)/2)
  for i=1,#text do local ch=text:sub(i,i); if ch==":" then g:circle(cursor+step,y+step*2,radius,"fill",color); g:circle(cursor+step,y+step*5,radius,"fill",color); cursor=cursor+colon_w else local rows=DOT_DIGITS[ch]; for row=1,7 do for col=1,5 do if rows[row]:sub(col,col)=="1" then g:circle(cursor+(col-1)*step,y+(row-1)*step,radius,"fill",color) end end end; cursor=cursor+digit_w+gap end end
end
local STROKE_DIGITS = {
  ["0"]={{{18,18},{82,18},{92,30},{92,130},{82,142},{18,142},{8,130},{8,30},{18,18}}},
  ["1"]={{{20,42},{50,18},{50,142},{18,142},{82,142}}},
  ["2"]={{{10,34},{20,18},{78,18},{92,32},{92,62},{8,142},{92,142}}},
  ["3"]={{{8,18},{76,18},{92,32},{92,62},{78,78},{42,78},{78,78},{92,94},{92,128},{78,142},{8,142}}},
  ["4"]={{{76,142},{76,18},{8,92},{76,92}}},
  ["5"]={{{92,18},{10,18},{10,76},{76,76},{92,92},{92,126},{76,142},{10,142}}},
  ["6"]={{{88,20},{28,20},{10,42},{10,122},{28,142},{74,142},{92,124},{92,94},{76,76},{10,76}}},
  ["7"]={{{8,18},{92,18},{40,142}}},
  ["8"]={{{24,18},{76,18},{92,34},{92,62},{76,78},{24,78},{8,62},{8,34},{24,18}},{{24,78},{76,78},{92,94},{92,126},{76,142},{24,142},{8,126},{8,94},{24,78}}},
  ["9"]={{{90,80},{24,80},{8,64},{8,36},{24,18},{72,18},{90,36},{90,118},{72,142},{16,142}}},
}
local function stroke_line(g,x0,y0,x1,y1,radius,color,rounded)
  local dx,dy=x1-x0,y1-y0
  if dy==0 then g:rect(math.min(x0,x1),y0-radius,math.abs(dx)+1,radius*2+1,"fill",color)
  elseif dx==0 then g:rect(x0-radius,math.min(y0,y1),radius*2+1,math.abs(dy)+1,"fill",color)
  else
    -- The device rasterizer anti-aliases diagonal g:line strokes differently from
    -- the preview. Build diagonals from overlapping filled rectangles instead so
    -- tube digits remain strictly black and white on e-ink hardware.
    local steps=math.max(math.abs(dx),math.abs(dy)); local stride=1; local size=radius*2+1
    for distance=0,steps,stride do
      local x=x0+math.floor(dx*distance/steps); local y=y0+math.floor(dy*distance/steps)
      g:rect(x-radius,y-radius,size,size,"fill",color)
    end
    g:rect(x1-radius,y1-radius,size,size,"fill",color)
  end
  if rounded then g:circle(x0,y0,radius,"fill",color); g:circle(x1,y1,radius,"fill",color) end
end
local function stroke_digit(g,ch,x,y,digit_w,digit_h,radius,color,rounded)
  local paths=STROKE_DIGITS[ch]; if not paths then return end
  for _,path in ipairs(paths) do
    for i=1,#path-1 do
      local a,b=path[i],path[i+1]
      stroke_line(g,x+math.floor(a[1]*digit_w/100),y+math.floor(a[2]*digit_h/160),x+math.floor(b[1]*digit_w/100),y+math.floor(b[2]*digit_h/160),radius,color,rounded)
    end
  end
end
function M.draw_stroke_time(g,text,x,y,width,height,color,variant)
  local digits,colons=0,0; for i=1,#text do if text:sub(i,i)==":" then colons=colons+1 else digits=digits+1 end end
  local gap=math.max(8,math.floor(width*.022)); local colon_w=math.max(18,math.floor(width*.055)); local digit_w=math.floor((width-colons*colon_w-(digits-1)*gap)/digits); local digit_h=math.min(height,math.floor(digit_w*1.56)); local total=digits*digit_w+(digits-1)*gap+colons*colon_w; local cursor=x+math.floor((width-total)/2); local top=y+math.floor((height-digit_h)/2)
  local radius=variant=="tube" and math.max(7,math.floor(digit_w*.105)) or variant=="chamfer" and math.max(4,math.floor(digit_w*.065)) or math.max(7,math.floor(digit_w*.12))
  for i=1,#text do local ch=text:sub(i,i)
    if ch==":" then local dot=variant=="tube" and math.max(6,radius-2) or math.max(4,radius-2); g:circle(cursor+math.floor(colon_w/2),top+math.floor(digit_h*.36),dot,"fill",color); g:circle(cursor+math.floor(colon_w/2),top+math.floor(digit_h*.68),dot,"fill",color); if variant=="tube" then g:circle(cursor+math.floor(colon_w/2),top+math.floor(digit_h*.36),math.max(2,dot-4),"fill",M.WHITE); g:circle(cursor+math.floor(colon_w/2),top+math.floor(digit_h*.68),math.max(2,dot-4),"fill",M.WHITE) end; cursor=cursor+colon_w
    else stroke_digit(g,ch,cursor,top,digit_w,digit_h,radius,color,variant~="chamfer"); if variant=="tube" then stroke_digit(g,ch,cursor,top,digit_w,digit_h,math.max(2,radius-5),M.WHITE,true) end; cursor=cursor+digit_w+gap end
  end
end
function M.draw_stroke_time_rot(g,text,cx,cy,width,height,deg,color,variant)
  local rad=deg*math.pi/180; local c,s=math.cos(rad),math.sin(rad)
  local function xf(x,y) local dx,dy=x-cx,y-cy; return math.floor(cx+dx*c-dy*s+0.5),math.floor(cy+dx*s+dy*c+0.5) end
  local function span(x0,y0,x1,y1,radius,ink)
    local ax,ay=xf(x0,y0); local bx,by=xf(x1,y1)
    local dx,dy=bx-ax,by-ay; local steps=math.max(1,math.max(math.abs(dx),math.abs(dy))); local stride=math.max(2,math.floor(radius*0.45)); local size=radius*2+1
    for distance=0,steps,stride do local x=ax+math.floor(dx*distance/steps); local y=ay+math.floor(dy*distance/steps); g:rect(x-radius,y-radius,size,size,"fill",ink) end
    g:rect(bx-radius,by-radius,size,size,"fill",ink)
  end
  local digits,colons=0,0; for i=1,#text do if text:sub(i,i)==":" then colons=colons+1 else digits=digits+1 end end
  local gap=math.max(8,math.floor(width*.022)); local colon_w=math.max(18,math.floor(width*.055)); local digit_w=math.floor((width-colons*colon_w-(digits-1)*gap)/digits); local digit_h=math.min(height,math.floor(digit_w*1.56)); local total=digits*digit_w+(digits-1)*gap+colons*colon_w; local cursor=cx-math.floor(total/2); local top=cy-math.floor(digit_h/2)
  local radius=variant=="tube" and math.max(6,math.floor(digit_w*.10)) or math.max(4,math.floor(digit_w*.07))
  local function digit(ch,x,y,ink,rad)
    local paths=STROKE_DIGITS[ch]; if not paths then return end
    for _,path in ipairs(paths) do for i=1,#path-1 do local a,b=path[i],path[i+1]; span(x+math.floor(a[1]*digit_w/100),y+math.floor(a[2]*digit_h/160),x+math.floor(b[1]*digit_w/100),y+math.floor(b[2]*digit_h/160),rad,ink) end end
  end
  for i=1,#text do local ch=text:sub(i,i)
    if ch==":" then
      local dx,dy=xf(cursor+math.floor(colon_w/2),top+math.floor(digit_h*.36)); local ex,ey=xf(cursor+math.floor(colon_w/2),top+math.floor(digit_h*.68))
      local dot=math.max(5,radius-1); g:circle(dx,dy,dot,"fill",color); g:circle(ex,ey,dot,"fill",color)
      if variant=="tube" then g:circle(dx,dy,math.max(2,dot-4),"fill",M.WHITE); g:circle(ex,ey,math.max(2,dot-4),"fill",M.WHITE) end
      cursor=cursor+colon_w
    else
      digit(ch,cursor,top,color,radius); if variant=="tube" then digit(ch,cursor,top,M.WHITE,math.max(2,radius-5)) end; cursor=cursor+digit_w+gap
    end
  end
end
function M.center_along(g,x0,y0,x1,y1,text,color)
  local tw=M.text_width(text); local line=math.max(1,math.sqrt((x1-x0)*(x1-x0)+(y1-y0)*(y1-y0))); local start=math.max(0,(line-tw)/2); local i,offset=1,0
  while i<=#text do
    local ch,step
    if text:byte(i)>=0xE0 then ch=text:sub(i,i+2); step=20; i=i+3 else ch=text:sub(i,i); step=10; i=i+1 end
    local t=math.min(1,(start+offset)/line)
    g:text(math.floor(x0+(x1-x0)*t+0.5),math.floor(y0+(y1-y0)*t+0.5),ch,{color=color or M.BLACK})
    offset=offset+step
  end
end
function M.center_along_rot(g,cx,cy,x0,y0,x1,y1,deg,text,color)
  local rad=deg*math.pi/180; local c,s=math.cos(rad),math.sin(rad)
  local function xf(x,y) local dx,dy=x-cx,y-cy; return math.floor(cx+dx*c-dy*s+0.5),math.floor(cy+dx*s+dy*c+0.5) end
  local ax,ay=xf(x0,y0); local bx,by=xf(x1,y1)
  M.center_along(g,ax,ay,bx,by,text,color)
end
local CN={ [0]="零",[1]="一",[2]="二",[3]="三",[4]="四",[5]="五",[6]="六",[7]="七",[8]="八",[9]="九",[10]="十" }
function M.cn_number(value) if value<=10 then return CN[value] end if value<20 then return "十"..CN[value-10] end local tens=math.floor(value/10); local ones=value%10; return CN[tens].."十"..(ones>0 and CN[ones] or "") end
function M.draw_calendar(g, parts, x, y, width, height, compact)
  g:rect(x,y,width,height,"stroke",M.BLACK); if not parts then M.center(g,x,y+20,width,"时间未校准"); return end
  local header=compact and 30 or 38; g:rect(x,y,width,header,"fill",M.BLACK); M.center(g,x,y+7,width,string.format("%04d / %02d",parts.year,parts.month),M.WHITE)
  local pad=8; local inner=width-pad*2; local cell=math.floor(inner/7); local week_y=y+header; local row_h=math.floor((height-header-24)/6)
  for col=0,6 do M.center(g,x+pad+col*cell,week_y+3,cell,M.WEEKDAYS[col+1],M.BLACK) end
  local grid_y=week_y+24; g:line(x+pad,grid_y-1,x+pad+cell*7,grid_y-1,M.BLACK)
  local first=M.first_wday(parts.year,parts.month)
  for day=1,M.month_days(parts.year,parts.month) do local slot=first+day-1; local col=slot%7; local row=math.floor(slot/7); local cx=x+pad+col*cell; local cy=grid_y+row*row_h
    if day==parts.day then g:rect(cx+3,cy+3,cell-6,row_h-6,"fill",M.BLACK); M.center(g,cx,cy+math.floor((row_h-20)/2),cell,tostring(day),M.WHITE) else M.center(g,cx,cy+math.floor((row_h-20)/2),cell,tostring(day),M.BLACK) end
  end
end
function M.button(ctx,top_right) if top_right then return {x=ctx.screen.width-142,y=18,w=122,h=36} end local width=math.min(180,ctx.screen.width-56); return {x=math.floor((ctx.screen.width-width)/2),y=ctx.screen.height-58,w=width,h=36} end
function M.draw_button(ctx,g,top_right) local r=M.button(ctx,top_right); g:rect(r.x,r.y,r.w,r.h,"stroke",M.BLACK); M.center(g,r.x,r.y+8,r.w,ctx.state.clock_status or "设为锁屏",M.BLACK) end
function M.handle(ctx,ev,top_right)
  if ev.type=="key" and ev.state=="down" then if ev.key=="back" then ctx:quit(); return true end if ev.key=="ok" then ctx.system:set_as_lockscreen_app(); ctx.state.clock_status="已设为锁屏"; ctx:invalidate(); return true end end
  if ev.type=="touch" and ev.gesture=="tap" then local r=M.button(ctx,top_right); if ev.x>=r.x and ev.x<r.x+r.w and ev.y>=r.y and ev.y<r.y+r.h then ctx.system:set_as_lockscreen_app(); ctx.state.clock_status="已设为锁屏"; ctx:invalidate(); return true end end
  return false
end

M.BRUSH_W = 30
M.BRUSH_H = 46
M.NUMERAL_PREFIX = "kaisei_digit_"
M.NUMERAL_WHITE_PREFIX = "kaisei_white_digit_"
function M.draw_brush_time(g,text,x,y,width,height,color)
  local ink=color or M.BLACK; local digits=0
  for i=1,#text do if text:sub(i,i) ~= ":" then digits=digits+1 end end
  local gap=math.max(4,math.floor(M.BRUSH_W*.18)); local colon_w=math.max(8,math.floor(M.BRUSH_W*.36)); local total=digits*M.BRUSH_W+(digits-1)*gap
  if string.find(text,":",1,true) then total=total+colon_w end
  local cursor=x+math.floor((width-total)/2); local top=y+math.floor((height-M.BRUSH_H)/2)
  for i=1,#text do local ch=text:sub(i,i)
    if ch == ":" then local dot=math.max(2,math.floor(M.BRUSH_W*.11)); local cx=cursor+math.floor(colon_w/2); g:circle(cx,top+math.floor(M.BRUSH_H*.36),dot,"fill",ink); g:circle(cx,top+math.floor(M.BRUSH_H*.68),dot,"fill",ink); cursor=cursor+colon_w
    else local prefix=ink == M.WHITE and M.NUMERAL_WHITE_PREFIX or M.NUMERAL_PREFIX; g:image(prefix..ch,cursor,top); cursor=cursor+M.BRUSH_W+gap end
  end
end
function M.draw_blocks(g,text,x,y,width,height,color) M.draw_brush_time(g,text,x,y,width,height,color) end
function M.draw_segments(g,text,x,y,width,height,color) M.draw_brush_time(g,text,x,y,width,height,color) end
function M.draw_dots(g,text,x,y,width,height,color) M.draw_brush_time(g,text,x,y,width,height,color) end
function M.draw_stroke_time(g,text,x,y,width,height,color) M.draw_brush_time(g,text,x,y,width,height,color) end
function M.draw_stroke_time_rot(g,text,cx,cy,width,height,_deg,color) M.draw_brush_time(g,text,cx-math.floor(width/2),cy-math.floor(height/2),width,height,color) end

return M
