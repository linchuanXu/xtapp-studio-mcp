local PkgImage = require("pkg_image")
-- 《雾港遗书》：可复盘的单人剧本杀短本。状态只保存在 ctx.state。

local NODES = {
  opening = { chapter="序幕·封港", scene="harbor", title="钟楼的遗书", lines={"暴雨封住雾港，摆渡船停在岸外。","钟楼管理员陆槐死在零点前。","他留下的遗书只有一句：","别相信第七声钟响。"}, choices={{text="接下这桩案子", next="hub"}} },
  hub = { chapter="调查·雾港", scene="hall", title="雨夜还剩两小时", lines={"港务厅的壁钟还在走，嫌疑人分坐在灯下。","物证不能代替证词，证词也不能代替时间。","你必须自己决定何时提交推理。"}, choices={{text="前往现场调查", next="investigate"}, {text="进入问询室", next="suspects"}, {text="查看案件时间线", next="timeline"}, {text="整理证据并提交推理", next="board", min_keys=3}} },
  investigate = { chapter="调查·现场", scene="map", title="三处现场", lines={"每处现场只提供一条关键物证。","不要把嫌疑人的秘密，当作他们杀人的证据。"}, choices={{text="钟楼现场", next="tower", unless="tower"}, {text="潮汐仓货单", next="warehouse", unless="warehouse"}, {text="旧邮局寄存柜", next="post", unless="post"}, {text="返回港务厅", next="hub"}} },
  suspects = { chapter="调查·问询", scene="interrogation", title="四名嫌疑人", lines={"每个人都有值得追问的秘密。","先记录可核对的事实，再判断他们的恐惧来自哪里。"}, choices={{text="林雁 · 港务员", next="lin", unless="lin"}, {text="程野 · 摆渡人", next="cheng", unless="cheng"}, {text="苏璃 · 记者", next="su", unless="su"}, {text="许闻 · 钟表匠", next="xu", unless="xu"}} },
  timeline = { chapter="调查·时间线", scene="timeline", title="第七声之前", lines={"23:30，陆槐约许闻到钟楼维修。","23:35，许闻在潮汐仓签收一卷钢丝。","23:40，林雁在港务厅拨出通话。","23:42，苏璃在防波堤拍摄；23:50，程野见许闻下塔。"}, choices={{text="返回港务厅", next="hub"}} },
  tower = { chapter="物证·钟楼", scene="tower", prop="clock", title="停在第七声", lines={"尸体旁的钟摆沾着新鲜机油。","塔门内侧没有撬痕，却有一枚铜钥匙的划痕。","墙钟停在 23:47，比报案时间早十三分钟。","钟绳断口被细钢丝切得很整齐。"}, choices={{text="记录：钢丝与 23:47", next="hub", flags={"tower"}, clue="物证 A · 钟楼：细钢丝切断钟绳；死亡窗口约为 23:47。"}} },
  warehouse = { chapter="物证·潮汐仓", scene="warehouse", prop="wire", title="未装船的箱子", lines={"货单显示零点前有一箱钟表零件出港。","封港后，箱子仍在潮汐仓最里侧。","防水布下藏着一卷同型号细钢丝。","签收栏写着：许闻，23:35。"}, choices={{text="记录：钢丝来源与签收", next="hub", flags={"warehouse"}, clue="物证 B · 潮汐仓：细钢丝由许闻在 23:35 签收，货箱未离港。"}} },
  post = { chapter="物证·旧邮局", scene="post", prop="letter", title="没有寄出的信", lines={"陆槐的寄存柜里有一封未寄出的检举信。","信中写：有人篡改钟楼报时，替走私船制造空档。","信封背面压着维修预约：许闻，今晚 23:30。","最后一行被雨水洇开：我会在第七声后公开名单。"}, choices={{text="记录：检举信与预约", next="hub", flags={"post"}, clue="物证 C · 旧邮局：死者将公开篡改报时者；23:30 约见许闻。"}} },
  lin = { chapter="证词·林雁", scene="hall", portrait="lin", title="港务员的账本", lines={"林雁承认删改过一页泊位记录。","她说那是为掩护弟弟偷渡，不是为走私。","23:40 她在港务厅给海防队打电话。","通话记录能证明她没上钟楼。"}, choices={{text="记录：林雁有隐情但有不在场", next="hub", flags={"lin"}, clue="证词 · 林雁：篡改泊位记录，但 23:40 正在港务厅通话。"}} },
  cheng = { chapter="证词·程野", scene="hall", portrait="cheng", title="摆渡人的雨衣", lines={"程野的雨衣沾着码头泥，袖口没有机油。","他承认替人送过没有登记的箱子。","但他看见许闻 23:50 从钟楼方向下来。","许闻当时说，管理员还在修钟。"}, choices={{text="记录：程野目击", next="hub", flags={"cheng"}, clue="证词 · 程野：23:50 看见许闻离开钟楼，对方谎称管理员仍活着。"}} },
  su = { chapter="证词·苏璃", scene="hall", portrait="su", title="记者的底片", lines={"苏璃拍到港口的走私船，却没有立刻发表。","她想等陆槐的名单补齐，换一篇独家。","底片时间是 23:42，地点在防波堤。","她的相机里还有第七声钟响前的远景。"}, choices={{text="记录：苏璃的时间线", next="hub", flags={"su"}, clue="证词 · 苏璃：23:42 在防波堤拍摄，底片支持其不在场。"}} },
  xu = { chapter="证词·许闻", scene="hall", portrait="xu", title="钟表匠的手", lines={"许闻说自己 23:30 修完钟就回潮汐仓。","他的指缝有机油，也有细钢丝磨出的新痕。","他称第七声钟响在零点，和停摆时间矛盾。","问到检举信时，他第一次沉默。"}, choices={{text="记录：许闻的矛盾", next="hub", flags={"xu"}, clue="证词 · 许闻：手上有机油与钢丝痕；时间说法与钟楼停摆矛盾。"}} },
  board = { chapter="结案·证据板", scene="board", title="先锁定凶手", lines={"只有物证 A、B、C 同时成立，推理才可以提交。","先选凶手；之后还要解释手法和动机。"}, choices={{text="林雁", next="wrong_accusation", set={suspect="lin"}}, {text="程野", next="wrong_accusation", set={suspect="cheng"}}, {text="苏璃", next="wrong_accusation", set={suspect="su"}}, {text="许闻", next="method", set={suspect="xu"}}} },
  method = { chapter="结案·证据板", scene="board", title="再锁定手法", lines={"钟绳、机油和钢丝留下了怎样的现场？","错误手法不能解释 23:47 的停摆时间。"}, choices={{text="用钢丝割断钟绳，制造坠落", next="motive", set={method="wire"}}, {text="在雨衣里下毒", next="incomplete", set={method="poison"}}, {text="从仓库推落", next="incomplete", set={method="push"}}} },
  motive = { chapter="结案·证据板", scene="board", title="最后锁定动机", lines={"遗书不是遗言，而是一记留给凶手的倒计时。","你要指出他为什么必须让钟楼沉默。"}, choices={{text="阻止走私名单公开", next="hearing", set={motive="smuggle"}}, {text="夺取钟楼遗产", next="wrong_motive", set={motive="inherit"}}, {text="替林雁顶罪", next="wrong_motive", set={motive="cover"}}} },
  hearing = { chapter="结案·对质", scene="hall", portrait="xu", title="把三条物证放上桌", lines={"你把停摆时间、签收钢丝和维修预约依次放下。","许闻先否认，随后看见程野的目击记录。","他终于承认：陆槐要公开名单，他不能让第七声响起。","现在，是否以完整证据链提交指控？"}, choices={{text="提交完整指控", next="true_end"}, {text="暂缓指控，继续查证", next="incomplete"}} },
  true_end = { chapter="结案·真相", scene="tower", prop="clock", title="第七声之后", lines={"许闻用细钢丝割断钟绳，借停摆制造死亡时间错觉。","他以维修为名进入钟楼，想让名单和管理员一起沉默。","23:50 他下塔时，钟已停在 23:47。","程野的目击、货单与遗书终于扣成闭环。"}, ending="真相结局 · 钟表匠", choices={{text="查看案件复盘", next="review"}} },
  wrong_accusation = { chapter="结案·错误指控", scene="board", title="证据拒绝你的答案", lines={"你选中的人有秘密，却没有完整的作案链。","23:47 的停摆、钢丝签收和维修预约仍指向同一人。","错误指控会让真正的走私名单继续沉入雨夜。"}, ending="结局 · 被雨冲淡的名字", choices={{text="查看案件复盘", next="review"}} },
  incomplete = { chapter="结案·证据不足", scene="board", title="差最后一环", lines={"你的手法无法解释钟绳断口，或你在关键时刻放下了指控。","案件没有被误判，但也没有被终结。","下一次，请让每个结论都有物证回答。"}, ending="结局 · 未落下的钟摆", choices={{text="查看案件复盘", next="review"}} },
  wrong_motive = { chapter="结案·动机偏差", scene="board", title="你看见了动作，却没看见理由", lines={"许闻确实走进了钟楼，但你的动机无法解释遗书。","死者要公开的是篡改报时、为走私船制造空档的人。","少了这一层，指控无法经受复核。"}, ending="结局 · 错过的第七声", choices={{text="查看案件复盘", next="review"}} },
  review = { chapter="复盘·雾港", scene="board", title="你带走的证据", lines={"真相的三把钥匙：23:47 的死亡窗口、许闻签收的钢丝、23:30 的维修预约。","程野的目击把三把钥匙放回同一条时间线。","林雁、苏璃各有秘密，但证据证明她们不在钟楼。","长按可回看线索簿；重开可用不同调查顺序复核本案。"}, choices={{text="重新调查", next="__restart"}} }
}

local function reset() return { node="opening", page=0, reading_done=false, flags={}, vars={}, history={}, clues={}, clue_order={}, overlay=false, tip=false } end
local function state(ctx) if not ctx.state.mist_harbor then ctx.state.mist_harbor=reset() end return ctx.state.mist_harbor end
local function clue_count(s) return #s.clue_order end
local function key_clue_count(s) local n=0 for _,flag in ipairs({"tower","warehouse","post"}) do if s.flags[flag] then n=n+1 end end return n end
local function allowed(s, c)
  if c.unless and s.flags[c.unless] then return false end
  if c.min_clues and clue_count(s)<c.min_clues then return false end
  if c.min_keys and key_clue_count(s)<c.min_keys then return false end
  return true
end
local function choices(s) local out={} for _,c in ipairs(NODES[s.node].choices or {}) do if allowed(s,c) then out[#out+1]=c end end return out end
-- g:text 没有 width / 自动折行参数。按固件 20px 系统字体的 17 个字符阅读宽度
-- 拆分 UTF-8 文本；中文和全角标点按一个字符计，ASCII 保持逐字计数。
local TEXT_LINE_LIMIT=17
local function wrap_text(text,limit)
  local chars={};local i=1
  while i<=#text do
    local byte=string.byte(text,i);local step=byte<0x80 and 1 or (byte<0xe0 and 2 or (byte<0xf0 and 3 or 4))
    chars[#chars+1]=string.sub(text,i,i+step-1);i=i+step
  end
  local out,start={},1
  while start<=#chars do
    local used,last_break,finish=0,nil,start-1
    for index=start,#chars do
      if used+1>limit then break end
      used=used+1;finish=index
      local ch=chars[index]
      if ch=="，" or ch=="。" or ch=="；" or ch=="、" or ch=="！" or ch=="？" or ch=="：" then last_break=index end
    end
    if finish<#chars and last_break and last_break>=start then finish=last_break end
    local row={};for index=start,finish do row[#row+1]=chars[index] end
    out[#out+1]=table.concat(row);start=finish+1
  end
  return out
end
local function lines(s)
  local out={};for _,raw in ipairs(NODES[s.node].lines) do for _,part in ipairs(wrap_text(raw,TEXT_LINE_LIMIT)) do out[#out+1]=part end end
  return out
end
local function complete(s) return (s.page+1)*3>=#lines(s) end
local function add_history(s, node) local n=NODES[node]; s.history[#s.history+1]=(n.chapter or "").." · "..(n.title or ""); if #s.history>16 then table.remove(s.history,1) end end
local function apply(s,c)
  if c.flags then for _,flag in ipairs(c.flags) do s.flags[flag]=true end end
  if c.set then for k,v in pairs(c.set) do s.vars[k]=v end end
  if c.clue and not s.clues[c.clue] then s.clues[c.clue]=true;s.clue_order[#s.clue_order+1]=c.clue end
end
local function go(s,next_id)
  if next_id=="__restart" then local fresh=reset();for k,v in pairs(fresh) do s[k]=v end;return end
  add_history(s,s.node);s.node=next_id;s.page=0;s.reading_done=complete(s)
end
local function choice_y(h,count,index) return h-count*60-28+(index-1)*60 end
local SCENE_ART = {
  harbor="bg_harbor", hall="bg_hall", map="bg_harbor", interrogation="bg_hall",
  timeline="bg_board", tower="bg_tower", warehouse="bg_warehouse", post="bg_post", board="bg_board",
}

function on_load(ctx)
  ctx:set_tick(0)
  local s=state(ctx);s.reading_done=complete(s);ctx:invalidate()
end
function on_input(ctx,ev)
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  local s=state(ctx)
  if ev.gesture=="long" then s.overlay=not s.overlay;ctx:invalidate();return true end
  if s.overlay then s.overlay=false;ctx:invalidate();return true end
  local n=NODES[s.node]
  if n.ending and complete(s) then go(s,(choices(s)[1] or {}).next);ctx:invalidate();return true end
  if not complete(s) then s.page=s.page+1;s.reading_done=complete(s);s.tip=true;ctx:invalidate();return true end
  local opts=choices(s);local selected
  for i,c in ipairs(opts) do local y=choice_y(ctx.screen.height,#opts,i);if ev.y>=y and ev.y<=y+52 then selected=c end end
  if not selected and #opts==1 then selected=opts[1] end
  if selected then apply(s,selected);go(s,selected.next) end
  ctx:invalidate();return true
end
function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=state(ctx);local n=NODES[s.node];local w,h=ctx.screen.width,ctx.screen.height
  -- 1bpp XIC 的白色是透明：先铺白纸，背景的黑色线稿才能显现。
  g:clear(0);g:rect(12,12,w-24,h-24,{color=15})
  g:text(26,34,n.chapter,{color=15});g:text(26,62,n.title,{color=15})
  local stage_x=math.floor((w-448)/2)
  g:rect(stage_x-2,80,452,132,{color=15})
  PkgImage.draw(g, SCENE_ART[n.scene] or "bg_harbor", stage_x, 82, {w=448, h=128})
  if n.portrait then
    g:rect(326,90,116,100,{fill=true,color=0});g:rect(326,90,116,100,{color=15})
    PkgImage.draw(g, "char_"..n.portrait, 328, 92, {w=112, h=96})
  end
  local text_y=224
  if n.prop then
    g:rect(22,212,256,52,{fill=true,color=0});g:rect(22,212,256,52,{color=15})
    PkgImage.draw(g, "prop_"..n.prop, 24, 214, {w=252, h=48})
    text_y=272
  end
  g:rect(24,text_y,w-48,128,{fill=true,color=0});g:rect(24,text_y,w-48,128,{color=15})
  local start=s.page*3+1;for i=start,math.min(#lines(s),start+2) do g:text(40,text_y+20+(i-start)*34,lines(s)[i],{color=15}) end
  if s.overlay then
    g:rect(24,74,w-48,h-148,{fill=true,color=15});g:rect(24,74,w-48,h-148,{color=0});g:text(40,100,"线索簿 · 点按返回",{color=0})
    g:text(40,130,"物证 / 证词："..tostring(clue_count(s)).." 条 · 核心："..tostring(key_clue_count(s)).."/3",{color=0})
    local row=0;local first_clue=math.max(1,#s.clue_order-5);for i=first_clue,#s.clue_order do g:text(40,160+row*42,s.clue_order[i],{color=0});row=row+1 end
    local first=math.max(1,#s.history-3);for i=first,#s.history do g:text(40,h-210+(i-first)*34,s.history[i],{color=0}) end
    return
  end
  if not complete(s) then g:text(26,h-40,"点按继续 · 长按线索簿",{color=15});return end
  if n.ending then g:text(26,h-40,n.ending.." · 点按复盘",{color=15});return end
  local opts=choices(s);for i,c in ipairs(opts) do local y=choice_y(h,#opts,i);g:rect(24,y,w-48,52,{fill=true,color=0});g:rect(24,y,w-48,52,{color=15});g:text(42,y+18,tostring(i)..". "..c.text,{color=15}) end
end
