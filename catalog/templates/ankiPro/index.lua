-- 墨背单词 / X4 Pro
-- 离线逐词进度、每日新词、到期复习、错词回队与完成回顾。
local DECKS = {
  { title = "四级词汇", subtitle = "CET-4 完整离线词库", tag = "CET-4 · 4544 词", prefix = "cet4", total = 4544 },
  { title = "六级词汇", subtitle = "CET-6 完整离线词库", tag = "CET-6 · 3991 词", prefix = "cet6", total = 3991 },
  { title = "旅行英语", subtitle = "从出发到抵达", tag = "TRAVEL · 12 词", total = 12, cards = {
    { front="arrive", pos="v.", back="到达", example="We arrive at noon." },
    { front="board", pos="v./n.", back="登机；上车；甲板", example="Please board at gate six." },
    { front="choose", pos="v.", back="选择", example="Choose a seat by the window." },
    { front="confirm", pos="v.", back="确认；证实", example="Please confirm your booking." },
    { front="depart", pos="v.", back="离开；出发", example="The train departs at nine." },
    { front="explore", pos="v.", back="探索；游览", example="We explored the old town." },
    { front="luggage", pos="n.", back="行李", example="Your luggage is over there." },
    { front="reserve", pos="v./n.", back="预订；保留；储备", example="I would like to reserve a room." },
    { front="subway", pos="n.", back="地铁", example="Take the subway downtown." },
    { front="transfer", pos="v./n.", back="转乘；转移", example="Transfer at the next station." },
    { front="ticket", pos="n.", back="票；券", example="Keep your ticket with you." },
    { front="welcome", pos="v./adj.", back="欢迎；受欢迎的", example="Welcome to our city." },
  } },
}

local LETTER_WIDTH = { a = 42, b = 47, c = 42, d = 46, e = 42, f = 31, g = 43, h = 48, i = 28, j = 31, k = 45, l = 28, m = 68, n = 48, o = 48, p = 47, q = 46, r = 35, s = 35, t = 30, u = 48, v = 44, w = 64, x = 44, y = 46, z = 38 }
local COMPACT_LETTER_WIDTH = { a = 28, b = 31, c = 28, d = 31, e = 28, f = 21, g = 28, h = 32, i = 19, j = 21, k = 30, l = 19, m = 44, n = 32, o = 31, p = 31, q = 31, r = 24, s = 24, t = 20, u = 32, v = 29, w = 42, x = 29, y = 30, z = 25 }
local LETTER_GAP = 4
local COMPACT_LETTER_GAP = 2
local MIN_VALID_DAY = 18262
local SESSION_LIMIT = 12
local DATA_CHUNK_SIZE = 200
local INTERVALS = { 1, 3, 7, 14, 30, 60, 120 }
local HARD_INTERVALS = { 1, 2, 4, 7, 14, 30, 60 }
local DAILY_OPTIONS = { 5, 10, 15, 20, 30 }
local DIRECTION_OPTIONS = { "en_zh", "zh_en", "mixed" }

local function days_since_unix(year, month, day)
  local y, m = year, month
  if m <= 2 then y, m = y - 1, m + 12 end
  local era = y // 400
  local yoe = y - era * 400
  local doy = (153 * (m - 3) + 2) // 5 + day - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end

local function day_now(ctx)
  local clock = ctx.sys and ctx.sys.clock and ctx.sys:clock() or nil
  if type(clock) ~= "table" or clock.valid ~= true or clock.year == nil or clock.month == nil or clock.day == nil then
    return nil
  end
  local day = days_since_unix(clock.year, clock.month, clock.day)
  if day < MIN_VALID_DAY then return nil end
  return day
end

local function normalize_item(p)
  p.stage = math.max(1, math.min(#INTERVALS, math.floor(tonumber(p.stage) or 1)))
  p.interval = math.max(1, math.floor(tonumber(p.interval) or INTERVALS[p.stage]))
  p.reviews = math.max(0, math.floor(tonumber(p.reviews) or 0))
  p.lapses = math.max(0, math.floor(tonumber(p.lapses) or 0))
  if type(p.due_day) ~= "number" then p.due_day = nil end
  if type(p.last_day) ~= "number" then p.last_day = nil end
  p.mask = math.max(1,math.floor(tonumber(p.mask) or 1))
  p.pos4 = math.max(0,math.floor(tonumber(p.pos4) or 0)); p.pos6 = math.max(0,math.floor(tonumber(p.pos6) or 0)); p.pos3=math.max(0,math.floor(tonumber(p.pos3) or 0))
  return p
end

local function ensure_progress(s)
  s.progress = type(s.progress)=="table" and s.progress or {}
  for key,p in pairs(s.progress) do
    if type(p) ~= "table" or (tonumber(p.stage) or 0) <= 0 then s.progress[key] = nil else normalize_item(p) end
  end
end

local function state(ctx)
  local s = ctx.state.anki_pro
  if type(s)~="table" or s.version ~= 5 then
    s = { version=5, screen="home", deck=1, library_cursor=1, streak=0, today_new=0, today_reviews=0, total_reviews=0, progress={}, settings={daily_new=10,shuffle=true,direction="en_zh",pause_backlog=true}, favorites={}, seen={{},{},{}} }
    ctx.state.anki_pro = s
  end
  s.screen = s.screen or "home"; s.deck = math.max(1, math.min(#DECKS, math.floor(tonumber(s.deck) or 1)))
  s.library_cursor = math.max(1, math.min(#DECKS, math.floor(tonumber(s.library_cursor) or s.deck)))
  s.streak = math.max(0, math.floor(tonumber(s.streak) or 0)); s.today_new = math.max(0, math.floor(tonumber(s.today_new) or 0))
  s.today_reviews = math.max(0, math.floor(tonumber(s.today_reviews) or 0)); s.total_reviews = math.max(0, math.floor(tonumber(s.total_reviews) or 0))
  s.settings=type(s.settings)=="table" and s.settings or {}; s.settings.daily_new=math.floor(tonumber(s.settings.daily_new) or 10)
  local valid_daily=false; for _,value in ipairs(DAILY_OPTIONS) do if value==s.settings.daily_new then valid_daily=true end end; if not valid_daily then s.settings.daily_new=10 end
  s.settings.shuffle=s.settings.shuffle~=false; s.settings.pause_backlog=s.settings.pause_backlog~=false
  local valid_direction=false; for _,value in ipairs(DIRECTION_OPTIONS) do if value==s.settings.direction then valid_direction=true end end; if not valid_direction then s.settings.direction="en_zh" end
  s.favorites=type(s.favorites)=="table" and s.favorites or {}; s.favorite_cursor=math.max(1,math.floor(tonumber(s.favorite_cursor) or 1))
  ensure_progress(s)
  if type(s.seen)~="table" then
    s.seen={{},{},{}}
    for key,p in pairs(s.progress) do if p.pos4>0 then s.seen[1][tostring(p.pos4)]=key end; if p.pos6>0 then s.seen[2][tostring(p.pos6)]=key end; if p.pos3>0 then s.seen[3][tostring(p.pos3)]=key end end
  end
  for index=1,#DECKS do if type(s.seen[index])~="table" then s.seen[index]={} end end
  return s
end

local function sync_day(ctx,s)
  local day = day_now(ctx); local changed = false
  if not day then s.clock_ready = false; return s.active_day, changed end
  s.clock_ready, s.active_day = true, day
  if s.open_day ~= day then
    s.open_day, s.today_new, s.today_reviews = day, 0, 0; changed = true
    if s.last_study_day and day - s.last_study_day > 1 then s.streak = 0 end
  end
  for _,p in pairs(s.progress) do
    if p.stage > 0 and not p.due_day then p.due_day = day + math.max(1,p.interval); changed = true end
  end
  return day, changed
end

local function deck(s) return DECKS[s.deck] end
local function progress(s,card,create)
  local key=string.lower(card.front); local p=s.progress[key]
  if not p and create then p={stage=0,interval=0,reviews=0,lapses=0,mask=card.mask,pos4=card.pos4,pos6=card.pos6,pos3=card.pos3}; s.progress[key]=p end
  return p
end
local function due_now(p,day) return day ~= nil and p.stage > 0 and (not p.due_day or p.due_day <= day) end
local function in_deck(p,deck_index) local divisor=2^(deck_index-1); return math.floor((tonumber(p.mask) or 0)/divisor)%2==1 end

local function deck_stats(s,deck_index,day)
  local learned,due,mastered = 0,0,0
  for _,p in pairs(s.progress) do if in_deck(p,deck_index) then learned=learned+1; if due_now(p,day) then due=due+1 end; if p.interval>=30 then mastered=mastered+1 end end end
  return learned,due,math.max(0,DECKS[deck_index].total-learned),mastered
end

local function review_card(s)
  return s.queue and s.queue[s.queue_pos] or nil
end

local function card_at(ctx,deck_index,card_index)
  local d=DECKS[deck_index]
  if d.cards then local card=d.cards[card_index]; if card then card.mask,card.pos4,card.pos6,card.pos3=4,0,0,card_index end; return card end
  local shard=math.floor((card_index-1)/DATA_CHUNK_SIZE)+1; local row=(card_index-1)%DATA_CHUNK_SIZE+1
  local reader=ctx.data:open_text(string.format("%s_%03d.tsv",d.prefix,shard),{max_bytes=131072,max_line_bytes=1024})
  if not reader then return nil end
  local line=nil; for _=1,row do line=reader:read_line(); if not line then break end end; reader:close()
  if not line then return nil end
  local fields={}; for value in (line.."\t"):gmatch("([^\t]*)\t") do fields[#fields+1]=value end
  if not fields[1] or fields[1]=="" then return nil end
  return {front=fields[1],pos=fields[2] or "",phonetic=fields[3] or "",back=fields[4] or "",example=fields[5] or "",mask=tonumber(fields[6]) or 2^(deck_index-1),pos4=tonumber(fields[7]) or 0,pos6=tonumber(fields[8]) or 0}
end

local function queue_item(ctx,deck_index,card_index,kind)
  local card=card_at(ctx,deck_index,card_index); if not card then return nil end
  card.deck,card.card,card.kind,card.counted=deck_index,card_index,kind,false; return card
end

local function gcd(a,b) while b~=0 do local r=a%b; a,b=b,r end; return a end
local function card_position(p,deck_index) if deck_index==1 then return p.pos4 elseif deck_index==2 then return p.pos6 else return p.pos3 end end
local function card_direction(s,card)
  if s.settings.direction~="mixed" then return s.settings.direction end
  local sum=0; for index=1,#card.front do sum=sum+string.byte(card.front,index) end; return sum%2==0 and "en_zh" or "zh_en"
end
local function candidate_index(s,deck_index,day,attempt)
  local total=DECKS[deck_index].total; if not s.settings.shuffle then return attempt+1 end
  local seed=(day or (s.total_reviews+1))*97+deck_index*53; local step=seed%(total-1)+1
  while gcd(step,total)~=1 do step=step+1; if step>=total then step=1 end end
  return ((seed%total)+attempt*step)%total+1
end

local function review_layout(w,h)
  local landscape=w>h; local margin=landscape and 42 or 32; local button_h=landscape and 58 or 68; local button_y=h-button_h-(landscape and 26 or 34)
  return { margin=margin,header_line_y=landscape and 72 or 100,content_top=landscape and 94 or 132,content_bottom=button_y-(landscape and 28 or 42),button_y=button_y,button_h=button_h }
end

local function word_width(word,widths,gap)
  local width=0; for index=1,#word do width=width+(widths[word:sub(index,index)] or 40) end
  return width+math.max(0,#word-1)*gap
end

local function draw_word(g,word,w,y)
  if not word:match("^[a-z]+$") then g:text(math.max(32,math.floor((w-#word*10)/2)),y+24,word,{color=15}); return end
  local widths,gap,prefix=LETTER_WIDTH,LETTER_GAP,"letter_"
  local width=word_width(word,widths,gap)
  if width>w-64 then widths,gap,prefix=COMPACT_LETTER_WIDTH,COMPACT_LETTER_GAP,"letter_compact_"; width=word_width(word,widths,gap) end
  if width>w-64 then g:text(math.max(32,math.floor((w-#word*10)/2)),y+24,word,{color=15}); return end
  local x=math.floor((w-width)/2)
  for index=1,#word do local letter=word:sub(index,index); g:image(prefix..letter,x,y); x=x+(widths[letter] or 40)+gap end
end

local function build_queue(ctx,s,day)
  local queue={}; local deck_index=s.deck; local candidates={}
  for _,p in pairs(s.progress) do if in_deck(p,deck_index) and due_now(p,day) then candidates[#candidates+1]={card=card_position(p,deck_index),due=p.due_day or 0} end end
  table.sort(candidates,function(a,b) if a.due==b.due then return a.card<b.card end return a.due<b.due end)
  for _,candidate in ipairs(candidates) do
    if #queue>=SESSION_LIMIT then break end
    local item=queue_item(ctx,deck_index,candidate.card,"review"); if item then item.direction=card_direction(s,item); queue[#queue+1]=item end
  end
  local daily=s.settings.daily_new; local new_left=day and math.max(0,daily-s.today_new) or daily
  if s.settings.pause_backlog and #candidates>=daily then new_left=0 end
  for attempt=0,DECKS[deck_index].total-1 do
    if #queue>=SESSION_LIMIT or new_left<=0 then break end
    local card_index=candidate_index(s,deck_index,day,attempt)
    if not s.seen[deck_index][tostring(card_index)] then local item=queue_item(ctx,deck_index,card_index,"new"); if item then item.direction=card_direction(s,item); queue[#queue+1]=item; new_left=new_left-1 end end
  end
  return queue
end

local function start_session(ctx,s)
  local day=sync_day(ctx,s); s.queue=build_queue(ctx,s,day); s.queue_pos=1; s.side="front"; s.undo=nil; s.session_good=0; s.session_hard=0; s.session_again=0; s.session_new=0; s.session_reviews=0; s.session_target=#s.queue
  if #s.queue==0 then s.screen="complete"; s.complete_kind="caught_up" else s.screen="study"; s.complete_kind="session" end
end

local function mark_study_day(s,day)
  if not day or s.last_study_day==day then return end
  if s.last_study_day==day-1 then s.streak=s.streak+1 else s.streak=1 end
  s.last_study_day=day
end

local function schedule(p,rating,day,relearning)
  p.reviews=p.reviews+1
  if rating=="again" then p.lapses=p.lapses+1; p.stage=1; p.interval=1
  elseif rating=="hard" then p.stage=math.max(1,math.min(#HARD_INTERVALS,p.stage+1)); p.interval=HARD_INTERVALS[p.stage]
  elseif relearning then p.stage=1; p.interval=1
  elseif rating=="good" then p.stage=math.min(#INTERVALS,p.stage+1); p.interval=INTERVALS[p.stage]
  else p.lapses=p.lapses+1; p.stage=1; p.interval=1 end
  p.last_day=day; p.due_day=day and day+p.interval or nil
end

local function copy_table(source) local out={}; if source then for key,value in pairs(source) do out[key]=value end end; return out end
local function grade(ctx,s,rating)
  local item=s.queue[s.queue_pos]; if not item then return end
  local key=string.lower(item.front); local previous=s.progress[key] and copy_table(s.progress[key]) or nil
  local p=progress(s,item,true); local day=sync_day(ctx,s)
  s.undo={key=key,previous=previous,queue_pos=s.queue_pos,counted=item.counted,today_new=s.today_new,today_reviews=s.today_reviews,total_reviews=s.total_reviews,session_new=s.session_new,session_reviews=s.session_reviews,session_good=s.session_good,session_hard=s.session_hard,session_again=s.session_again,streak=s.streak,last_study_day=s.last_study_day,item=item}
  if not item.counted then
    if item.kind=="new" then s.today_new=s.today_new+1; s.session_new=s.session_new+1 else s.today_reviews=s.today_reviews+1; s.session_reviews=s.session_reviews+1 end
    item.counted=true
  end
  if item.pos4 and item.pos4>0 then s.seen[1][tostring(item.pos4)]=key end; if item.pos6 and item.pos6>0 then s.seen[2][tostring(item.pos6)]=key end; if item.pos3 and item.pos3>0 then s.seen[3][tostring(item.pos3)]=key end
  mark_study_day(s,day); schedule(p,rating,day,item.kind=="retry"); s.total_reviews=s.total_reviews+1
  if rating=="good" then s.session_good=s.session_good+1 elseif rating=="hard" then s.session_hard=s.session_hard+1 else s.session_again=s.session_again+1; local retry=copy_table(item); retry.kind="retry"; retry.counted=true; s.undo.inserted=math.min(#s.queue+1,s.queue_pos+2); table.insert(s.queue,s.undo.inserted,retry) end
  s.queue_pos=s.queue_pos+1; s.side="front"
  if s.queue_pos>#s.queue then s.screen="complete"; s.complete_kind="session" end
end

local function undo_grade(s)
  local u=s.undo; if not u then return false end
  if u.inserted then table.remove(s.queue,u.inserted) end
  if u.previous then s.progress[u.key]=u.previous else s.progress[u.key]=nil; if (u.item.pos4 or 0)>0 then s.seen[1][tostring(u.item.pos4)]=nil end; if (u.item.pos6 or 0)>0 then s.seen[2][tostring(u.item.pos6)]=nil end; if (u.item.pos3 or 0)>0 then s.seen[3][tostring(u.item.pos3)]=nil end end
  u.item.counted=u.counted; s.queue_pos=u.queue_pos; s.today_new=u.today_new; s.today_reviews=u.today_reviews; s.total_reviews=u.total_reviews; s.session_new=u.session_new; s.session_reviews=u.session_reviews; s.session_good=u.session_good; s.session_hard=u.session_hard; s.session_again=u.session_again; s.streak=u.streak; s.last_study_day=u.last_study_day; s.screen="study"; s.side="back"; s.undo=nil; return true
end

local function toggle_favorite(s,item)
  local key=string.lower(item.front)
  if s.favorites[key] then s.favorites[key]=nil else s.favorites[key]={front=item.front,pos=item.pos,phonetic=item.phonetic,back=item.back,example=item.example,mask=item.mask,pos4=item.pos4,pos6=item.pos6,pos3=item.pos3} end
end

local function select_deck(s,index) s.deck=index; s.library_cursor=index; s.screen="home" end
local function cycle(values,current,delta)
  local index=1; for position,value in ipairs(values) do if value==current then index=position end end
  return values[((index-1+delta)%#values)+1]
end
local function favorite_list(s) local out={}; for _,item in pairs(s.favorites) do out[#out+1]=item end; table.sort(out,function(a,b) return a.front<b.front end); return out end
local function start_favorites(s)
  local queue={}; for _,item in ipairs(favorite_list(s)) do if #queue>=SESSION_LIMIT then break end; local copy=copy_table(item); copy.deck=s.deck; copy.card=card_position(item,s.deck); copy.kind="favorite"; copy.counted=true; copy.direction=card_direction(s,copy); queue[#queue+1]=copy end
  s.queue=queue; s.queue_pos=1; s.side="front"; s.undo=nil; s.session_good=0; s.session_hard=0; s.session_again=0; s.session_new=0; s.session_reviews=0
  if #queue>0 then s.screen="study" else s.screen="favorites" end
end
local function change_setting(s,row,delta)
  if row==1 then s.settings.daily_new=cycle(DAILY_OPTIONS,s.settings.daily_new,delta)
  elseif row==2 then s.settings.shuffle=not s.settings.shuffle
  elseif row==3 then s.settings.direction=cycle(DIRECTION_OPTIONS,s.settings.direction,delta)
  elseif row==4 then s.settings.pause_backlog=not s.settings.pause_backlog end
end
local function reset_deck(s)
  s.progress={}; s.seen={{},{},{}}; s.today_new=0; s.today_reviews=0; s.total_reviews=0; s.streak=0; s.last_study_day=nil; s.undo=nil
end

local function study_touch(ctx,s,ev,w,h)
  if ev.gesture=="swipe_left" then grade(ctx,s,"good"); return true end
  if ev.gesture=="swipe_right" then grade(ctx,s,"again"); return true end
  if ev.gesture~="tap" and ev.gesture~="long" then return false end
  local l=review_layout(w,h)
  if ev.y>=24 and ev.y<68 and ev.x>w-150 then toggle_favorite(s,s.queue[s.queue_pos]); return true end
  if s.undo and ev.y>=l.header_line_y and ev.y<l.header_line_y+48 and ev.x>w-150 then return undo_grade(s) end
  if ev.y>=l.button_y and ev.y<l.button_y+l.button_h then
    if s.side=="front" then s.side="back" else local width=w-l.margin*2; local third=width/3; if ev.x<l.margin+third then grade(ctx,s,"again") elseif ev.x<l.margin+third*2 then grade(ctx,s,"hard") else grade(ctx,s,"good") end end; return true
  end
  return false
end

local function touch(ctx,s,ev,w,h)
  if s.screen=="study" then return study_touch(ctx,s,ev,w,h) end
  if s.screen=="favorites" and (ev.gesture=="swipe_up" or ev.gesture=="swipe_down") then local count=#favorite_list(s); local delta=ev.gesture=="swipe_up" and 6 or -6; s.favorite_cursor=math.max(1,math.min(math.max(1,count-5),s.favorite_cursor+delta)); return true end
  if ev.gesture~="tap" and ev.gesture~="long" then return false end
  if s.screen=="home" then
    if h>=w and ev.y>=282 and ev.y<350 then start_session(ctx,s); return true end
    if h>=w and ev.y>=394 and ev.y<482 then s.screen="library"; s.library_cursor=s.deck; return true end
    if h>=w and ev.y>=526 and ev.y<614 then
      if ev.x<165 then s.screen="library"; s.library_cursor=s.deck
      elseif ev.x<306 then s.screen="progress"
      else s.screen="settings"; s.settings_cursor=1 end
      return true
    end
    if w>h and ev.y>=216 and ev.y<284 then start_session(ctx,s); return true end
    if w>h and ev.x>=500 and ev.y>=310 and ev.y<366 then s.screen="library"; return true end
    if w>h and ev.x>=500 and ev.y>=374 and ev.y<430 then if ev.x<650 then s.screen="progress" else s.screen="settings"; s.settings_cursor=1 end; return true end
  elseif s.screen=="library" then
    local top,row_h=132,math.floor(h*0.17); local relative=ev.y-top; local index=math.floor(relative/row_h)+1
    if index>=1 and index<=#DECKS and relative%row_h<=108 then select_deck(s,index); return true end
  elseif s.screen=="settings" then
    local row=nil
    if h>=w then local relative=ev.y-112; local candidate=math.floor(relative/118)+1; if relative>=0 and candidate<=4 and relative%118<=108 then row=candidate end
    elseif ev.y>=100 and ev.y<280 then local column=ev.x<math.floor(w/2) and 1 or 2; local line=ev.y<190 and 0 or 1; row=line*2+column end
    if row then change_setting(s,row,1); s.settings_cursor=row; return true end
    if ev.y>=h-76 then s.screen="home"; return true end
  elseif s.screen=="progress" then
    local favorite_y=h>=w and 430 or 258; local reset_y=h>=w and 520 or 326
    if ev.y>=favorite_y and ev.y<favorite_y+60 then s.screen="favorites"; return true end
    if ev.y>=reset_y and ev.y<reset_y+60 then s.screen="reset_confirm"; return true end
    if ev.y>=h-76 then s.screen="home"; return true end
  elseif s.screen=="favorites" then
    if ev.y>=h-150 and ev.y<h-88 then start_favorites(s); return true end
    if ev.y>=h-76 then s.screen="progress"; return true end
  elseif s.screen=="reset_confirm" then
    local confirm_y=h>=w and 430 or 250; local cancel_y=h>=w and 520 or 326
    if ev.y>=confirm_y and ev.y<confirm_y+68 then reset_deck(s); s.screen="progress"; return true end
    if ev.y>=cancel_y and ev.y<cancel_y+56 then s.screen="progress"; return true end
  elseif s.screen=="complete" then
    local primary_y,home_y=math.floor(h*0.60),math.floor(h*0.77)
    local primary_h=s.complete_kind=="caught_up" and 56 or 68
    if ev.y>=primary_y and ev.y<primary_y+primary_h then if s.complete_kind=="caught_up" then s.screen="library" else start_session(ctx,s) end; return true end
    if ev.y>=home_y and ev.y<home_y+56 then s.screen="home"; return true end
  end
  return false
end

function on_enter(ctx) local s=state(ctx); sync_day(ctx,s); ctx:set_tick_rate("idle"); ctx:invalidate() end
function on_tick(ctx,_dt_ms) local s=state(ctx); local _,changed=sync_day(ctx,s); if changed then ctx:invalidate() end end

function on_input(ctx,ev)
  local s=state(ctx); sync_day(ctx,s)
  if ev.type=="touch" then local handled=touch(ctx,s,ev,ctx.screen.width,ctx.screen.height); if handled then ctx:invalidate() end; return handled end
  if ev.type~="key" or ev.state~="down" then return false end
  if s.screen=="home" then
    if ev.key=="ok" or ev.key=="up" then start_session(ctx,s) elseif ev.key=="right" then s.screen="library"; s.library_cursor=s.deck elseif ev.key=="down" then s.screen="progress" elseif ev.key=="left" then s.screen="settings"; s.settings_cursor=1 else return false end
  elseif s.screen=="library" then
    if ev.key=="up" then s.library_cursor=math.max(1,s.library_cursor-1) elseif ev.key=="down" then s.library_cursor=math.min(#DECKS,s.library_cursor+1)
    elseif ev.key=="ok" or ev.key=="right" then select_deck(s,s.library_cursor) elseif ev.key=="back" or ev.key=="left" then s.screen="home" else return false end
  elseif s.screen=="settings" then
    s.settings_cursor=math.max(1,math.min(4,math.floor(tonumber(s.settings_cursor) or 1)))
    if ev.key=="up" then s.settings_cursor=math.max(1,s.settings_cursor-1) elseif ev.key=="down" then s.settings_cursor=math.min(4,s.settings_cursor+1)
    elseif ev.key=="left" then change_setting(s,s.settings_cursor,-1) elseif ev.key=="right" or ev.key=="ok" then change_setting(s,s.settings_cursor,1) elseif ev.key=="back" then s.screen="home" else return false end
  elseif s.screen=="progress" then
    if ev.key=="ok" or ev.key=="right" then s.screen="favorites" elseif ev.key=="down" then s.screen="reset_confirm" elseif ev.key=="back" or ev.key=="left" then s.screen="home" else return false end
  elseif s.screen=="favorites" then
    local count=#favorite_list(s)
    if ev.key=="up" then s.favorite_cursor=math.max(1,s.favorite_cursor-1) elseif ev.key=="down" then s.favorite_cursor=math.min(math.max(1,count-5),s.favorite_cursor+1)
    elseif ev.key=="ok" or ev.key=="right" then start_favorites(s) elseif ev.key=="back" or ev.key=="left" then s.screen="progress" else return false end
  elseif s.screen=="reset_confirm" then
    if ev.key=="ok" or ev.key=="right" then reset_deck(s); s.screen="progress"
    elseif ev.key=="back" or ev.key=="left" then s.screen="progress" else return false end
  elseif s.screen=="complete" then
    if ev.key=="ok" or ev.key=="up" or ev.key=="right" then if s.complete_kind=="caught_up" then s.screen="library" else start_session(ctx,s) end
    elseif ev.key=="back" or ev.key=="down" or ev.key=="left" then s.screen="home" else return false end
  elseif s.side=="front" then
    if ev.key=="ok" or ev.key=="up" then s.side="back" elseif ev.key=="down" then toggle_favorite(s,s.queue[s.queue_pos]) elseif ev.key=="left" then grade(ctx,s,"again") elseif ev.key=="right" then grade(ctx,s,"good") elseif ev.key=="back" then if not undo_grade(s) then s.screen="home" end else return false end
  else
    if ev.key=="ok" or ev.key=="right" or ev.key=="up" then grade(ctx,s,"good") elseif ev.key=="down" then grade(ctx,s,"hard") elseif ev.key=="left" then grade(ctx,s,"again") elseif ev.key=="back" then s.side="front" else return false end
  end
  ctx:invalidate(); return true
end

local function draw_control(g,x,y,key)
  g:image(key,x,y)
end

local function draw_home_number(g,value,center_x,y)
  local text=tostring(math.max(0,math.floor(tonumber(value) or 0)))
  local x=math.floor(center_x-#text*14)
  for index=1,#text do g:image("ui_digit_"..text:sub(index,index),x,y); x=x+28 end
end

local function draw_title(g,w,key,fallback,meta)
  local margin=w>480 and 42 or 32
  if w>=480 then g:image(key,margin,28) else g:text(margin,40,fallback,{color=15}) end
  if meta then g:text(w-margin-100,45,meta,{color=15}) end
  g:line(margin,84,w-margin,84,15); return margin
end

local function draw_home(ctx,s,g,w,h)
  local day=day_now(ctx); local d=deck(s); local learned,due,new_count=deck_stats(s,s.deck,day); local daily=s.settings.daily_new; local new_today=math.min(day and math.max(0,daily-s.today_new) or daily,new_count)
  local streak_text=s.clock_ready and (s.streak>0 and string.format("连续 %d 天",s.streak) or "从今天开始") or "时间未校准"
  local portrait=h>=w; local margin=draw_title(g,w,"ui_title_home","墨背单词",streak_text)
  if portrait then
    g:image("home_scene_compact",margin,108); g:image("ui_home_today",232,108)
    draw_home_number(g,new_today,286,190); draw_home_number(g,due,394,190)
    draw_control(g,margin,282,(new_today>0 or due>0) and "ui_btn_start" or "ui_btn_summary")
    g:image("ui_home_deck",margin,394)
    g:text(margin+24,410,"当前词库",{color=15}); g:text(margin+112,410,d.title,{color=15}); g:text(w-margin-156,410,string.format("已学 %d/%d",learned,d.total),{color=15})
    g:text(margin+24,440,s.clock_ready and d.subtitle or "校准时间后启用到期复习",{color=15})
    draw_control(g,margin,526,"ui_home_library"); draw_control(g,margin+141,526,"ui_home_progress"); draw_control(g,margin+282,526,"ui_home_settings")
  else
    g:image("home_scene",margin,104); local x=500
    g:text(x,132,string.format("今日  新词 %d  ·  复习 %d",new_today,due),{color=15}); g:text(x,174,string.format("%s  已学 %d/%d",d.title,learned,d.total),{color=15})
    draw_control(g,x,216,"ui_btn_start_ls"); draw_control(g,x,310,"ui_btn_library_ls"); draw_control(g,x,374,"ui_btn_progress_ls"); draw_control(g,x+133,374,"ui_btn_settings_ls")
  end
end

local function draw_library(ctx,s,g,w,h)
  local day=day_now(ctx); local margin=draw_title(g,w,"ui_title_library","选择词库","点按切换"); local top,row_h=132,math.floor(h*0.17)
  for index,item in ipairs(DECKS) do
    local y=top+(index-1)*row_h; local learned,due=deck_stats(s,index,day)
    local suffix=w>h and "_ls" or ""
    g:image((index==s.deck and "ui_book_row_current" or "ui_book_row")..suffix,margin,y)
    g:text(margin+28,y+20,item.title,{color=15}); g:text(margin+28,y+50,string.format("已学 %d/%d  ·  待复习 %d",learned,item.total,due),{color=15})
    if index==s.deck then g:text(w-margin-92,y+20,"当前",{color=15}) end
  end
  g:text(margin,h-42,"返回键回到今日",{color=15})
end

local function draw_study(s,g,w,h)
  local c=review_card(s); if not c then return end
  local item=s.queue[s.queue_pos]; local l=review_layout(w,h); local margin=l.margin
  local favorite=s.favorites[string.lower(c.front)] and "★ 已收藏" or "☆ 收藏"
  g:text(margin,math.floor(h*0.05),deck(s).title,{color=15}); g:text(math.floor(w/2)-24,math.floor(h*0.05),string.format("%02d/%02d",math.min(s.queue_pos,#s.queue),#s.queue),{color=15}); g:text(w-margin-86,math.floor(h*0.05),favorite,{color=15}); g:line(margin,l.header_line_y,w-margin,l.header_line_y,15)
  if s.undo then g:text(w-margin-100,l.header_line_y+14,"撤销上一步",{color=15}) end
  if s.side=="back" then
    draw_word(g,c.front,w,l.content_top); g:text(margin,l.content_top+88,(c.pos or "").."  "..(c.phonetic or ""),{color=15}); g:text(margin,l.content_top+118,c.back,{color=15}); g:line(margin,l.content_top+150,w-margin,l.content_top+150,15)
    g:text(margin,l.content_top+174,"例句",{color=15}); g:text(margin,l.content_top+204,c.example~="" and c.example or "暂无例句",{color=15}); g:text(margin,l.content_bottom-18,item.kind=="new" and "新词将从明天开始复习" or "记忆间隔会按结果调整",{color=15})
  else
    if c.direction=="zh_en" then g:text(math.max(margin,math.floor((w-#c.back*16)/2)),math.floor((l.content_top+l.content_bottom)/2),c.back,{color=15}) else draw_word(g,c.front,w,math.floor((l.content_top+l.content_bottom-76)/2)-8) end
    draw_control(g,margin,l.button_y,w>h and "ui_btn_reveal_ls" or "ui_btn_reveal")
  end
  if s.side=="back" then
    g:text(margin,l.button_y-32,"这次想起来了吗？",{color=15}); local button_w=math.floor((w-margin*2-20)/3)
    local suffix=w>h and "_ls" or ""
    draw_control(g,margin,l.button_y,"ui_btn_again"..suffix); draw_control(g,margin+button_w+10,l.button_y,"ui_btn_hard"..suffix); draw_control(g,margin+(button_w+10)*2,l.button_y,"ui_btn_known"..suffix)
  end
end

local function draw_settings(s,g,w,h)
  local margin=draw_title(g,w,"ui_title_settings","学习设置","自动保存"); local labels={"每日新词","乱序学习","学习方向","积压保护"}
  local directions={en_zh="英 → 中",zh_en="中 → 英",mixed="混合"}
  local values={tostring(s.settings.daily_new).." 词",s.settings.shuffle and "开启" or "关闭",directions[s.settings.direction],s.settings.pause_backlog and "开启" or "关闭"}
  if h>=w then
    for index=1,4 do local y=112+(index-1)*118; g:image(index==s.settings_cursor and "ui_setting_row_current" or "ui_setting_row",margin,y); g:text(margin+24,y+20,labels[index],{color=15}); g:text(w-margin-104,y+20,values[index],{color=15}); if index==1 then g:text(margin+24,y+52,"点击切换 5 / 10 / 15 / 20 / 30",{color=15}) elseif index==4 then g:text(margin+24,y+52,"复习积压达到每日量时暂停新词",{color=15}) end end
  else
    local gap=16; local width=math.floor((w-margin*2-gap)/2)
    for index=1,4 do local column=(index-1)%2; local row=math.floor((index-1)/2); local x=margin+column*(width+gap); local y=100+row*90; g:image(index==s.settings_cursor and "ui_set_row_current_ls" or "ui_set_row_ls",x,y); g:text(x+22,y+16,labels[index],{color=15}); g:text(x+width-88,y+16,values[index],{color=15}) end
  end
  g:text(margin,h-40,"方向键选择，左右键修改，BACK 返回",{color=15})
end

local function draw_progress(ctx,s,g,w,h)
  local day=day_now(ctx); local margin=draw_title(g,w,"ui_title_progress","学习进度",deck(s).title); local learned,due,new_count,mastered=deck_stats(s,s.deck,day); local learning=math.max(0,learned-mastered); local days=math.ceil(new_count/s.settings.daily_new)
  if h>=w then
    g:text(margin,132,string.format("已掌握                 %d",mastered),{color=15}); g:text(margin,178,string.format("学习中                 %d",learning),{color=15}); g:text(margin,224,string.format("尚未学习               %d",new_count),{color=15}); g:text(margin,270,string.format("今日待复习             %d",due),{color=15}); g:line(margin,314,w-margin,314,15); g:text(margin,342,string.format("按当前计划，约 %d 天学完新词",days),{color=15}); g:text(margin,378,string.format("连续 %d 天 · 累计复习 %d 次",s.streak,s.total_reviews),{color=15})
  else
    g:text(margin,112,string.format("已掌握 %d     学习中 %d",mastered,learning),{color=15}); g:text(margin,154,string.format("未学习 %d     待复习 %d",new_count,due),{color=15}); g:text(margin,202,string.format("约 %d 天学完 · 连续 %d 天 · 累计 %d 次",days,s.streak,s.total_reviews),{color=15})
  end
  local favorite_y=h>=w and 430 or 258; local reset_y=h>=w and 520 or 326; local suffix=w>h and "_ls" or ""; draw_control(g,margin,favorite_y,"ui_btn_favorites"..suffix); draw_control(g,margin,reset_y,"ui_btn_reset"..suffix); draw_control(g,margin,h-76,"ui_btn_home"..suffix)
end

local function draw_favorites(s,g,w,h)
  local margin=draw_title(g,w,"ui_title_favorites","收藏词",string.format("%d 词",#favorite_list(s))); local items=favorite_list(s)
  if #items==0 then g:text(margin,170,"还没有收藏词",{color=15}); g:text(margin,212,"学习时点击右上角“收藏”。",{color=15}) else local start=math.min(s.favorite_cursor,math.max(1,#items-5)); for index=start,math.min(start+5,#items) do local item=items[index]; local y=122+(index-start)*70; g:text(margin,y,item.front,{color=15}); g:text(margin+170,y,item.back,{color=15}); g:line(margin,y+34,w-margin,y+34,15) end; if #items>6 then g:text(margin,h-174,"上下键或滑动浏览更多",{color=15}) end end
  local suffix=w>h and "_ls" or ""; draw_control(g,margin,h-150,"ui_btn_favorites"..suffix); draw_control(g,margin,h-76,"ui_btn_home"..suffix)
end

local function draw_reset(s,g,w,h)
  local margin=draw_title(g,w,"ui_title_reset","确认重置","全部词库"); g:text(margin,h>=w and 160 or 112,"将清除全部词库的学习进度。",{color=15}); g:text(margin,h>=w and 206 or 154,"收藏词会保留。此操作无法撤销。",{color=15}); local confirm_y=h>=w and 430 or 250; local cancel_y=h>=w and 520 or 326; local suffix=w>h and "_ls" or ""; draw_control(g,margin,confirm_y,"ui_btn_reset"..suffix); draw_control(g,margin,cancel_y,"ui_btn_cancel"..suffix)
end

local function draw_complete(s,g,w,h)
  local title_key=s.complete_kind=="caught_up" and "ui_title_caught_up" or "ui_title_complete"
  local margin=draw_title(g,w,title_key,s.complete_kind=="caught_up" and "今日完成" or "完成一组","今日记录"); local top=160
  if s.complete_kind=="caught_up" then
    g:text(margin,top,"这个词库今天没有到期任务",{color=15}); g:text(margin,top+48,"你可以切换词库，或明天再来。",{color=15}); g:line(margin,top+96,w-margin,top+96,15)
    draw_control(g,margin,math.floor(h*0.60),w>h and "ui_btn_library_wide" or "ui_btn_library")
  else
    g:text(margin,top,string.format("本轮新词        %d",s.session_new or 0),{color=15}); g:text(margin,top+46,string.format("到期复习        %d",s.session_reviews or 0),{color=15})
    g:text(margin,top+92,string.format("记住 / 重来     %d / %d",s.session_good or 0,s.session_again or 0),{color=15}); g:line(margin,top+136,w-margin,top+136,15)
    g:text(margin,top+168,"学习记录已更新，复习日已安排。",{color=15}); draw_control(g,margin,math.floor(h*0.60),w>h and "ui_btn_continue_ls" or "ui_btn_continue")
  end
  draw_control(g,margin,math.floor(h*0.77),w>h and "ui_btn_home_ls" or "ui_btn_home")
end

function on_draw(ctx,g)
  local s=state(ctx); sync_day(ctx,s); local w,h=ctx.screen.width,ctx.screen.height; g:clear(0)
  if s.screen=="home" then draw_home(ctx,s,g,w,h) elseif s.screen=="library" then draw_library(ctx,s,g,w,h) elseif s.screen=="settings" then draw_settings(s,g,w,h) elseif s.screen=="progress" then draw_progress(ctx,s,g,w,h) elseif s.screen=="favorites" then draw_favorites(s,g,w,h) elseif s.screen=="reset_confirm" then draw_reset(s,g,w,h) elseif s.screen=="complete" then draw_complete(s,g,w,h) else draw_study(s,g,w,h) end
end
