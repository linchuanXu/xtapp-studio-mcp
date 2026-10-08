local QUOTES = require("quotes")
local LOCALES={{code="en-US",label="EN",w=27},{code="zh-CN",label="ZH",w=27},{code="de-DE",label="DE",w=27},{code="es-ES",label="ES",w=25},{code="fr-FR",label="FR",w=25},{code="it-IT",label="IT",w=17},{code="pt-PT",label="PT",w=25}}
local M = {}
local BLACK, WHITE = 15, 0

local function clock_parts(ctx)
  local clock = ctx.sys and ctx.sys:clock()
  if not clock or clock.valid ~= true or clock.hour == nil or clock.minute == nil then return nil end
  return { hour = clock.hour, min = clock.minute }
end
local function center(g,y,text,color) g:text(math.max(18,math.floor((480-#text*10)/2)),y,text,{color=color or BLACK}) end
local function wrap(text,limit)
  local rows, line = {}, ""
  for word in text:gmatch("[^%s]+") do
    local next_line = line == "" and word or line.." "..word
    if #next_line > limit and line ~= "" then rows[#rows+1]=line; line=word else line=next_line end
  end
  if line ~= "" then rows[#rows+1]=line end
  return rows
end
-- The runtime has no text-measure API. These are the 20px PingFang advances
-- used by the preview renderer, measured once per glyph rather than guessed
-- from a character count. The fallback keeps uncommon punctuation safe.
local ADV={
  [" "]=6.66,A=13.16,B=13.56,C=14.56,D=14.14,E=12.74,F=11.54,G=14.97,H=14.42,I=4.75,J=10.37,K=13.82,L=11.77,M=17.65,N=14.39,O=15.35,P=12.85,Q=15.35,R=13.55,S=12.67,T=12.37,U=14.29,V=12.79,W=18.63,X=12.76,Y=13.26,Z=12.48,
  a=11.19,b=11.73,c=10.95,d=11.73,e=11.11,f=7.47,g=11.82,h=11.15,i=5.15,j=5.34,k=10.59,l=4.72,m=17.13,n=11.20,o=11.74,p=11.73,q=11.73,r=7.31,s=10.11,t=7.10,u=11.22,v=9.65,w=15.12,x=10.20,y=9.94,z=9.77,
  ["0"]=11.75,["1"]=7.91,["2"]=11.85,["3"]=11.79,["4"]=11.90,["5"]=11.87,["6"]=11.97,["7"]=10.97,["8"]=11.92,["9"]=11.99,["."]=5.28,[","]=5.28,[";"]=5.28,[":"]=5.28,["!"]=6.41,["?"]=10.92,["'"]=5.32,["-"]=12.03,["("]=6.41,[")"]=6.41,["&"]=14.56,["/"]=9.68,
  ["’"]=6.80,["‘"]=6.80,["“"]=10.74,["”"]=10.74,["—"]=20,["…"]=20,["–"]=16.48,["‑"]=12.03,["["]=6.41,["]"]=6.41,["*"]=9.79,["+"]=11.90,["="]=12.09,["@"]=17.26,["$"]=11.98,["#"]=11.91,
}
local function text_width(text)
  local total=0
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do total=total+(ADV[char] or 20) end
  return total
end
local function glyph_count(text)
  local total=0
  for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do total=total+1 end
  return total
end
local function append_word_parts(words,word,limit)
  if text_width(word)<=limit then words[#words+1]=word; return end
  local part=""
  for chunk in word:gmatch("[^-]+%-?") do
    local next_part=part..chunk
    if part~="" and text_width(next_part)>limit then words[#words+1]=part; part=chunk else part=next_part end
  end
  words[#words+1]=part~="" and part or word
end
local function width_wrap(text,limit)
  local rows,line={},""
  local words={}; for word in text:gmatch("[^%s]+") do append_word_parts(words,word,limit) end
  for _,word in ipairs(words) do
    local next_line=line=="" and word or line.." "..word
    if text_width(next_line)>limit and line~="" then rows[#rows+1]=line; line=word else line=next_line end
  end
  if line~="" then rows[#rows+1]=line end
  return rows
end
local function chinese_rows(text,limit)
  local rows,line={},""; local count=0
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if count>=limit then rows[#rows+1]=line; line=""; count=0 end
    line=line..char; count=count+1
  end
  if line~="" then rows[#rows+1]=line end
  return rows
end
local function balanced_wrap(text,limit)
  local words={}
  for word in text:gmatch("[^%s]+") do append_word_parts(words,word,limit) end
  local n=#words; local widths,chars={},{}
  for i=1,n do widths[i]=text_width(words[i]); chars[i]=glyph_count(words[i]) end
  local cost,next_break={},{}
  cost[n+1]=0
  for i=n,1,-1 do
    local ink,char_count=0,0; cost[i]=99999999
    for j=i,n do
      ink=ink+widths[j]; char_count=char_count+chars[j]
      if ink+(j-i)*ADV[" "]>limit then break end
      local gaps=j-i; local is_last=j==n; local badness=0
      if is_last then
        -- A final line is never stretched, but a tiny orphan still costs.
        local fill=ink/limit
        if fill<0.42 then badness=(0.42-fill)^2*20000 end
      elseif gaps==0 then
        badness=9999999
      else
        -- TeX-like badness for word space plus a tiny, bounded tracking
        -- adjustment. This keeps the right edge true without wide word gaps.
        local wanted=(limit-ink)/gaps; local word_gap=math.min(14,math.max(3.5,wanted))
        local tracking=(limit-ink-word_gap*gaps)/math.max(1,char_count-(gaps+1))
        local gap_delta=(word_gap-7.5)/2.25; local track_delta=tracking/0.35
        badness=gap_delta^4*20+track_delta^4*30
        if tracking<-1 then badness=badness+(-1-tracking)^2*1000000 end
        if tracking>1.5 then badness=badness+(tracking-1.5)^2*1000000 end
      end
      local total=badness+(cost[j+1] or 99999999)
      if total<cost[i] then cost[i]=total; next_break[i]=j end
    end
  end
  local rows,i={},1
  while i<=n do
    local j=next_break[i] or i; rows[#rows+1]=table.concat(words," ",i,j); i=j+1
  end
  return rows
end
local function draw_justified(g,x,y,width,text,justify)
  if not justify then g:text(x,y,text,{color=BLACK}); return end
  local words,ink,chars={},0,0
  for word in text:gmatch("[^%s]+") do words[#words+1]=word; ink=ink+text_width(word); chars=chars+glyph_count(word) end
  if #words<2 then g:text(x,y,text,{color=BLACK}); return end
  local gaps=#words-1; local wanted=(width-ink)/gaps
  local gap=math.min(14,math.max(3.5,wanted))
  local tracking=(width-ink-gap*gaps)/math.max(1,chars-#words)
  if tracking<-1 or tracking>1.5 then g:text(x,y,text,{color=BLACK}); return end
  if wanted>=3.5 and wanted<=14 then tracking=0 end
  local cursor=x
  for i=1,#words do
    if tracking==0 then
      g:text(math.floor(cursor+0.5),y,words[i],{color=BLACK}); cursor=cursor+text_width(words[i])
    else
      local count=0
      for char in words[i]:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count=count+1; g:text(math.floor(cursor+0.5),y,char,{color=BLACK}); cursor=cursor+text_width(char)
        if count<glyph_count(words[i]) then cursor=cursor+tracking end
      end
    end
    if i<#words then cursor=cursor+gap end
  end
end
local function draw_time(g,p,y)
  local width, height, gap, colon_w = 44, 64, 6, 16
  local hour=p.hour%12; if hour==0 then hour=12 end
  local text=string.format("%02d:%02d",hour,p.min); local cursor=135
  for i=1,#text do local char=text:sub(i,i)
    if char==":" then g:circle(cursor+8,y+23,3,"fill",BLACK); g:circle(cursor+8,y+45,3,"fill",BLACK); cursor=cursor+colon_w
    else g:image("kaisei_digit_"..char,cursor,y); cursor=cursor+width+gap end
  end
  g:text(354,y+57,p.hour<12 and "AM" or "PM",{color=BLACK})
end
local function current(ctx,locale)
  local p = clock_parts(ctx)
  if not p then return nil, nil end
  local key=string.format("%02d:%02d",p.hour,p.min)
  local corpus=QUOTES[locale] or QUOTES["en-US"]; local values=corpus[key]
  if not values then
    for offset=1,1440 do
      local n=(p.hour*60+p.min-offset)%1440
      values=corpus[string.format("%02d:%02d",math.floor(n/60),n%60)]
      if values then break end
    end
  end
  return p, values
end
local function draw(ctx,g)
  local state=ctx.state.literature_clock or {}; local locale=LOCALES[(state.locale or 1)] or LOCALES[1]
  local p, values = current(ctx,locale.code)
  g:clear(WHITE)
  g:text(60,40,"LITERATURE CLOCK",{color=BLACK}); g:text(412-locale.w,40,locale.label,{color=BLACK})
  g:line(60,66,412,66,BLACK)
  if not p or not values then center(g,360,"TIME NOT READY"); return end
  local item=values[(state.variant or 0)%#values+1]
  local rows=locale.code=="zh-CN" and chinese_rows(item.q,17) or balanced_wrap(item.q,352); local page_size=9; local pages=math.max(1,math.ceil(#rows/page_size)); local page=(state.page or 0)%pages
  local visible_rows=math.min(page_size,#rows-page*page_size)
  local title_rows=width_wrap(item.t,352)
  local author_rows=width_wrap(item.a,352)
  local title_count=math.min(3,#title_rows); local author_count=math.min(2,#author_rows)
  -- The text forms a bottom-aligned reading column rather than a UI card.
  local author_last_y=742; local author_first_y=author_last_y-(author_count-1)*22
  local title_last_y=author_first_y-34; local title_first_y=title_last_y-(title_count-1)*22
  local rule_y=title_first_y-20; local quote_last_y=rule_y-34; local quote_y=quote_last_y-(visible_rows-1)*24
  local divider_y=quote_y-22
  local time_y=math.max(108,math.floor(70+(divider_y-70-64)/2))
  draw_time(g,p,time_y)
  g:line(60,divider_y,412,divider_y,BLACK)
  for i=1,visible_rows do local row=rows[page*page_size+i]; draw_justified(g,60,quote_y+(i-1)*24,352,row,i<visible_rows) end
  g:line(60,rule_y,180,rule_y,BLACK)
  for i=1,title_count do g:text(60,title_first_y+(i-1)*22,title_rows[i],{color=BLACK}) end
  for i=1,author_count do g:text(60,author_first_y+(i-1)*22,author_rows[i],{color=BLACK}) end
end
function on_enter(ctx) ctx.state.literature_clock=ctx.state.literature_clock or {variant=0,page=0,locale=1}; ctx:set_tick_rate("low"); ctx:invalidate() end
function on_tick(ctx,_dt) ctx:invalidate() end
function on_draw(ctx,g) draw(ctx,g) end
function on_input(ctx,ev)
  local state=ctx.state.literature_clock
  if ev.type=="touch" and ev.gesture=="tap" then
    if ev.x>=120 and ev.x<=360 and ev.y>=100 and ev.y<=420 then state.locale=(state.locale or 1)%#LOCALES+1; state.variant=0; state.page=0
    elseif ev.y>420 then state.page=state.page+1 elseif ev.x<240 then state.variant=state.variant-1; state.page=0 else state.variant=state.variant+1; state.page=0 end
  elseif ev.type=="key" and ev.state=="down" then
    if ev.key=="back" then ctx:quit(); return true end
    if ev.key=="left" then state.variant=state.variant-1; state.page=0
    elseif ev.key=="right" or ev.key=="ok" then state.variant=state.variant+1; state.page=0
    elseif ev.key=="up" then state.page=state.page-1
    elseif ev.key=="down" then state.page=state.page+1
    else return false end
  else return false end
  ctx:invalidate(); return true
end
return M
