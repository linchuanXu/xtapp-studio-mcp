local PkgImage = require("pkg_image")
local B,W=15,0
local tabs={"全部","美食","电影","休闲"}
local icons={["美食"]={"icon_hotpot","icon_sushi","icon_burger","icon_coffee"},["电影"]={"icon_movie"},["休闲"]={"icon_leisure"}}
local function rows(ctx)
  local out={}; local r=ctx.package:open_text("deals.tsv"); if not r then return out end; r:read_line()
  while true do local line=r:read_line(); if not line then break end; local f={}; for v in (line.."\t"):gmatch("([^\t]*)\t") do f[#f+1]=v end; out[#out+1]={cat=f[1],name=f[2],dist=tonumber(f[3]),old=f[4],price=tonumber(f[5]),sold=f[6],badge=f[7],valid=f[8],pack=f[9]} end; r:close(); return out
end
local function filtered(s)
  local out={}; for _,d in ipairs(s.all) do if s.tab==1 or d.cat==tabs[s.tab] then out[#out+1]=d end end
  table.sort(out,function(a,b) if s.sort==1 then return a.dist<b.dist end return (tonumber(a.old)-a.price)>(tonumber(b.old)-b.price) end); return out
end
local function logo(g) g:clear(W); PkgImage.draw(g, "brand_logo", 24, 18); g:text(350,32,"观澜湖",{color=B}); g:line(24,78,456,78,{color=B}) end
local function nav(g,s)
  local x=24; for i,t in ipairs(tabs) do g:text(x+16,102,t,{color=B}); if s.tab==i then g:line(x+10,132,x+68,132,{color=B}); g:line(x+10,135,x+68,135,{color=B}) end; x=x+104 end
end
local function list(ctx,g,s)
  logo(g); nav(g,s); PkgImage.draw(g, "feature_scene", 216, 150); g:text(24,164,"今天附近",{color=B}); g:text(24,204,#filtered(s).." 个好价",{color=B}); g:line(24,242,198,242,{color=B})
  g:text(24,270,s.sort==1 and "距离最近" or "优惠最大",{color=B}); g:text(350,270,"轻触切换",{color=B}); g:line(24,304,456,304,{color=B})
  local list=filtered(s); local start=math.max(1,math.min(s.offset,#list-3)); for i=0,3 do local d=list[start+i]; if d then local y=322+i*101; local set=icons[d.cat] or {"icon_tag"}; local icon=set[((start+i-2)%#set)+1]; PkgImage.draw(g, icon, 24, y+7); g:text(88,y,d.name,{color=B}); g:text(88,y+31,d.badge.." · "..d.dist.."m",{color=B}); g:rect(350,y+2,106,44,{fill=true,color=B}); g:text(366,y+13,"¥"..d.price,{color=W}); g:text(88,y+62,"已售"..d.sold,{color=B}); g:line(88,y+88,456,y+88,{color=B}) end end
  g:rect(24,735,204,45,{color=B}); g:text(74,748,"优惠排序",{color=B}); g:rect(252,735,204,45,{color=B}); g:text(302,748,"距离排序",{color=B}); local bx=s.sort==2 and 24 or 252; g:rect(bx,735,5,45,{fill=true,color=B})
end
local function detail(g,s,d)
  logo(g); g:text(24,102,d.cat.." · "..d.badge,{color=B}); g:text(24,140,d.name,{color=B}); g:text(24,194,"到手价",{color=B}); g:text(24,236,"¥"..d.price,{color=B}); g:text(292,236,"门市 ¥"..d.old,{color=B}); g:line(24,274,456,274,{color=B}); PkgImage.draw(g, "feature_scene", 120, 296); PkgImage.draw(g, "icon_location", 24, 466); g:text(88,468,d.dist.."m · 观澜湖商圈",{color=B}); PkgImage.draw(g, "icon_tag", 24, 526); g:text(88,528,d.valid,{color=B}); g:line(24,586,456,586,{color=B}); g:text(24,610,"套餐内容",{color=B}); g:text(24,650,d.pack,{color=B}); g:text(24,690,"月售 "..d.sold.." · 随时退",{color=B}); g:rect(24,744,432,42,{color=B}); g:rect(24,744,5,42,{fill=true,color=B}); g:text(184,754,"返回好价",{color=B})
end
function on_load(ctx) if not ctx.state.deals then ctx.state.deals={all=rows(ctx),tab=1,sort=1,offset=1,detail=nil} end; ctx:set_tick(0) end
function on_draw(ctx,g) require("pkg_image").bind(ctx); local s=ctx.state.deals; if s.detail then detail(g,s,s.detail) else list(ctx,g,s) end end
function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end; local s=ctx.state.deals
  if ev.gesture=="swipe_up" then s.offset=s.offset+1 elseif ev.gesture=="swipe_down" then s.offset=math.max(1,s.offset-1)
  elseif ev.gesture=="tap" then
    if s.detail then if ev.y>=720 then s.detail=nil else return false end
    elseif ev.y>=90 and ev.y<=140 then s.tab=math.max(1,math.min(4,math.floor((ev.x-24)/104)+1)); s.offset=1
    elseif ev.y>=250 and ev.y<=310 then s.sort=3-s.sort; s.offset=1
    elseif ev.y>=320 and ev.y<724 then local list=filtered(s); s.detail=list[s.offset+math.floor((ev.y-322)/101)]
    elseif ev.y>=720 then s.sort=ev.x<240 and 2 or 1; s.offset=1 else return false end
  else return false end; ctx:invalidate(); return true
end
