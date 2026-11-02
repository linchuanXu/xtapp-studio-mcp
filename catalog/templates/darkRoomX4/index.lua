-- A Dark Room · Ink Edition / X4 community port
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- Studio-authored Lua for XTApp API 2.x. See NOTICE.md and LICENSE.md.
-- Designed for sparse redraws: every action produces one decisive black/white frame.
local ADR = require("domain.adr_catalog")

-- Upstream World uses a radius of 30 (61×61 cells). The map remains
-- deterministic so a saved X4 game never moves landmarks after a reboot.
local WORLD_SIZE = ADR.world.radius * 2 + 1
local WORLD_CENTER = ADR.world.radius + 1
local TILE = {
  ["."]="荒地", [";"]="森林", [","]="草原", ["#"]="旧路", A="村庄", I="铁矿", C="煤矿", S="硫磺矿",
  H="废屋", V="洞穴", O="小镇", Y="城市", P="前哨", W="坠毁飞船", B="钻井", F="战场", M="沼泽", U="补给箱", X="行刑者",
}
local ICON = {
  ["."]="·", [";"]="F", [","]="·", ["#"]="#", A="A", I="I", C="C", S="S", H="H", V="V", O="O", Y="Y", P="P", W="W", B="B", F="F", M="M", U="U", X="X",
}
local NAME = {
  wood="木头",fur="毛皮",meat="肉",scales="鳞片",teeth="牙齿",cloth="布料",charm="护符",leather="皮革",["cured meat"]="肉干",iron="铁",coal="煤",sulphur="硫磺",steel="钢",bullets="子弹",medicine="药草",bait="诱饵",["energy cell"]="能量",bolas="流星索",grenade="手雷",["alien alloy"]="异星合金",alloy="异星合金",
  trap="陷阱",cart="货车",hut="小屋",lodge="猎舍",["trading post"]="贸易站",tannery="制革坊",smokehouse="熏肉房",workshop="工坊",steelworks="炼钢厂",armoury="军械库",torch="火把",waterskin="水袋",cask="木桶",["water tank"]="水箱",["bone spear"]="骨矛",rucksack="背包",wagon="篷车",convoy="车队",["l armour"]="皮甲",["i armour"]="铁甲",["s armour"]="钢甲",["iron sword"]="铁剑",["steel sword"]="钢剑",rifle="步枪",bayonet="刺刀",compass="指南针",
  gatherer="采集者",hunter="猎人",trapper="诱捕者",tanner="制革师",charcutier="熏肉师",["iron miner"]="铁矿工",["coal miner"]="煤矿工",["sulphur miner"]="硫磺矿工",steelworker="炼钢工",armourer="军械师",
  ["energy blade"]="能量刃",["fluid recycler"]="流体回收器",["cargo drone"]="货运无人机",["kinetic armour"]="动能甲",disruptor="扰乱器",hypo="急救针",stim="兴奋剂",["plasma rifle"]="等离子步枪",["glow stone"]="辉光石",fists="徒手",
}
local SHORT = {wood="木",fur="毛",meat="肉",scales="鳞",teeth="牙",cloth="布",charm="符",leather="皮",["cured meat"]="肉干",iron="铁",coal="煤",sulphur="硫",steel="钢",bullets="弹",medicine="药",bait="饵",["energy cell"]="能",alloy="合",["alien alloy"]="合"}
local function display_name(id) return NAME[id] or id end

local function clamp(n, lo, hi) if n < lo then return lo elseif n > hi then return hi end return n end
local function world_row(chars) return table.concat(chars) end
local function make_world()
  local map={}; local occupied={}
  for y=1,WORLD_SIZE do
    local row={}
    for x=1,WORLD_SIZE do
      local d=math.abs(x-WORLD_CENTER)+math.abs(y-WORLD_CENTER)
      local noise=(x*17+y*31+x*y*7)%100
      row[x]=(d<7 and ",") or (noise<22 and ";") or (noise<32 and ",") or "."
    end
    map[y]=world_row(row)
  end
  local function place(x,y,tile) map[y]=string.sub(map[y],1,x-1)..tile..string.sub(map[y],x+1); occupied[x..":"..y]=true end
  -- A sparse cross-road is the low-risk route out from the village; landmarks
  -- still overwrite it, matching the original map's road/landmark layering.
  for i=1,WORLD_SIZE do place(i,WORLD_CENTER,"#"); place(WORLD_CENTER,i,"#") end
  place(WORLD_CENTER,WORLD_CENTER,"A")
  for kind,landmark in ipairs(ADR.world.landmarks) do
    for count=1,landmark.num do
      local placed=false; local attempt=0
      while not placed and attempt<300 do
        attempt=attempt+1
        local seed=kind*911+count*179+attempt*67
        local x=(seed*37)%WORLD_SIZE+1; local y=(seed*71+kind*13)%WORLD_SIZE+1
        local d=math.abs(x-WORLD_CENTER)+math.abs(y-WORLD_CENTER)
        if d>=landmark.min and d<=landmark.max and not occupied[x..":"..y] then place(x,y,landmark.tile); placed=true end
      end
      -- The arithmetic probe walks a diagonal residue class. For a tight
      -- distance ring (notably the first mines), that class can miss every
      -- legal cell. Finish with a deterministic full-board scan so every
      -- declared landmark is reachable in every new save.
      if not placed then
        local offset=(kind*97+count*31)%(WORLD_SIZE*WORLD_SIZE)
        for scan=0,WORLD_SIZE*WORLD_SIZE-1 do
          local at=(offset+scan)%(WORLD_SIZE*WORLD_SIZE)
          local x=at%WORLD_SIZE+1; local y=math.floor(at/WORLD_SIZE)+1
          local d=math.abs(x-WORLD_CENTER)+math.abs(y-WORLD_CENTER)
          if d>=landmark.min and d<=landmark.max and not occupied[x..":"..y] then place(x,y,landmark.tile); placed=true; break end
        end
      end
    end
  end
  return map
end
local function cell(map,x,y) if y<1 or y>#map or x<1 or x>#map[y] then return "#" end return string.sub(map[y],x,x) end
local function set_cell(map,x,y,c) map[y]=string.sub(map[y],1,x-1)..c..string.sub(map[y],x+1) end
local function store_key(k)
  if k=="alien alloy" then return "alloy" end
  return k
end
local function add(s,k,n) k=store_key(k); s.store[k] = math.max(0, (s.store[k] or 0) + n) end
local function afford(s,cost) for k,n in pairs(cost) do if (s.store[store_key(k)] or 0) < n then return false end end return true end
local function pay(s,cost) for k,n in pairs(cost) do add(s,k,-n) end end
local function say(s, text) s.log=text; s.log_age=0 end
local function event_intro(id)
  return ({wanderer="一个陌生人站在火边。", illness="村里有人发烧。", signal="荒野深处传来断续信号。",
    trader="一辆旧货车在村口停下。", surveyor="一位测绘员摊开了一张残缺地图。", ruined_trap="几只陷阱被巨大的爪痕撕开。",
    beggar="一个裹着破毛皮的乞者来到火边。", beast_attack="林线外传来一阵低沉的咆哮。", nomad="一名背着粗布袋的游牧商停在门外。", noises="墙外传来窸窣的脚步和拖拽声。", store_noises="储物间里传来抓挠木板的声音。"})[id] or "村庄里发生了一件事。"
end

local function fresh()
  return { page="room", lit=false, fire=0, warmth=0, builder=false, villagers=0, workers={wood=0, fur=0, iron=0}, work_mode=1,
    worker_assign={}, village_panel="build", buildings={hut=0, trap=0, cart=0}, owned={}, store={wood=0, fur=0, meat=0, leather=0, iron=0, alloy=0, medicine=0},
    gear={sword=false, armor=false, water=false}, unlock={village=false,path=false,world=false,ship=false,fabricator=false}, ship={hull=ADR.ship.base_hull,thrusters=ADR.ship.base_thrusters,warned=false}, blueprints={},
    world_version=3, map=make_world(), x=WORLD_CENTER, y=WORLD_CENTER, visited={}, landmarks={}, mines={}, travel_steps=0, food=0, water=0, hp=ADR.world.base_health, maxhp=ADR.world.base_health, enemy=nil, event=nil, site=nil, events={}, selected=1,
    clue=false, rng=17, combat_cooldowns={}, log="醒来。房间很冷。", log_age=0, turns=0, ending=false }
end
local function state(ctx)
  if not ctx.state.dark_room_x4 then ctx.state.dark_room_x4=fresh() end
  local s=ctx.state.dark_room_x4
  -- Forward-compatible saves from the earlier vertical slice receive the new endgame state.
  s.ship=s.ship or {hull=ADR.ship.base_hull,thrusters=ADR.ship.base_thrusters,warned=false}; s.blueprints=s.blueprints or {}
  s.unlock.fabricator=s.unlock.fabricator or false; s.owned=s.owned or {}; s.landmarks=s.landmarks or {}; s.mines=s.mines or {}; s.worker_assign=s.worker_assign or {}; s.combat_cooldowns=s.combat_cooldowns or {}
  -- Earlier saves only retained `warmth`; it becomes the initial fire level
  -- so a player never loses progress when this room-state loop is introduced.
  s.fire=s.fire or s.warmth or 0; s.builder=s.builder or false
  -- Preserve economy and story state while rebuilding pre-v3 worlds. V3 adds
  -- a guaranteed placement fallback for every mine and landmark, so a save
  -- can never become impossible merely because its old map missed a ring.
  if (s.world_version or 0)<3 then
    s.map=make_world(); s.x=WORLD_CENTER; s.y=WORLD_CENTER; s.visited={}; s.landmarks={}; s.mines={}; s.travel_steps=0; s.world_version=3
    say(s,"荒野地图已校正。旧的脚印散在新的地标之间。")
  end
  return s
end
-- Upstream stores are not capped by the small early-game bundle; the cart
-- changes gathering yield. Keep a generous guard only for corrupt saves.
local function cap(_s) return 9999 end
local function worker_total(s) return s.workers.wood+s.workers.fur+s.workers.iron end
local function work_label(s) return ({"均衡：木与毛皮", "伐木：全员木头", "采铁：保底木头、其余采铁"})[s.work_mode or 1] end
local function assign_workers(s)
  local people=math.max(0,s.villagers)
  local mode=s.work_mode or 1
  if mode==2 then
    s.workers.wood=people; s.workers.fur=0; s.workers.iron=0
  elseif mode==3 then
    s.workers.wood=people>0 and 1 or 0; s.workers.fur=0; s.workers.iron=math.max(0,people-1)
  else
    -- 默认沿用原来的轻量双产出，确保刚起步的村庄不会因分工而卡死。
    s.workers.wood=math.min(1,people); s.workers.fur=(s.buildings.trap or 0)>0 and math.min(1,people) or 0; s.workers.iron=0
  end
end
local function cycle_workers(s)
  s.work_mode=((s.work_mode or 1) % 3)+1; assign_workers(s); say(s,"村民分工改为："..work_label(s))
end

local function build(s, name, cost)
  if not afford(s,cost) then say(s,"资源不足") return end
  pay(s,cost); s.buildings[name]=s.buildings[name]+1
  if name=="hut" then s.villagers=s.villagers+1; say(s,"新的小屋亮起灯火。")
  elseif name=="trap" then add(s,"fur",4); say(s,"陷阱已布置。第一批毛皮挂在门外。")
  else say(s,"货车就绪。储备上限提高。") end
end

local function craft(s, name, cost)
  if s.gear[name] then say(s,"已经拥有。") return end
  if not afford(s,cost) then say(s,"资源不足") return end
  pay(s,cost); s.gear[name]=true
  if name=="sword" then say(s,"粗糙的钢刃在火光中成形。")
  elseif name=="armor" then s.maxhp=14; s.hp=s.maxhp; say(s,"皮甲让你多了一点余地。")
  else say(s,"水袋装满。现在可以走得更远。") end
end

local function catalog_count(s, thing)
  if thing.group=="building" then return s.buildings[thing.id] or 0 end
  return s.owned[thing.id] or 0
end
local function catalog_cost(s, thing) return thing.cost(catalog_count(s,thing)) end
local function label_cost(cost)
  local out={}; for k,n in pairs(cost) do out[#out+1]=(SHORT[k] or display_name(k))..n end
  table.sort(out); return table.concat(out," ")
end
local function own_catalog_item(s, thing)
  if thing.group=="building" then
    s.buildings[thing.id]=(s.buildings[thing.id] or 0)+1
  else
    s.owned[thing.id]=(s.owned[thing.id] or 0)+1
    if thing.id=="iron sword" or thing.id=="steel sword" or thing.id=="bone spear" or thing.id=="rifle" then s.gear.sword=true end
    if thing.id=="l armour" then s.maxhp=14; s.hp=s.maxhp end
    if thing.id=="i armour" then s.maxhp=18; s.hp=s.maxhp end
    if thing.id=="s armour" then s.maxhp=22; s.hp=s.maxhp end
    if thing.id=="waterskin" then s.gear.water=true end
  end
end
local function build_catalog(s, thing)
  if thing.group~="building" and (s.buildings.workshop or 0)<1 then say(s,"需要先建造工坊。") return end
  if thing.maximum and catalog_count(s,thing)>=thing.maximum then say(s,"已经达到上限："..display_name(thing.id)) return end
  local cost=catalog_cost(s,thing)
  if not afford(s,cost) then say(s,"资源不足："..label_cost(cost)) return end
  pay(s,cost); own_catalog_item(s,thing); say(s,"完成："..display_name(thing.id))
end
local function buy_trade_good(s, good)
  if good.maximum and (s.owned[good.id] or 0)>=good.maximum then say(s,"已经拥有："..display_name(good.id)) return end
  if not afford(s,good.cost) then say(s,"商队要价："..label_cost(good.cost)) return end
  pay(s,good.cost)
  if good.id=="bayonet" or good.id=="compass" then s.owned[good.id]=1
  else add(s,good.id,1) end
  if good.id=="compass" then s.unlock.path=true; say(s,"指南针指向林间小径。")
  else say(s,"商队交付："..display_name(good.id)) end
end
local function worker_available(s, job)
  if job.id=="gatherer" or job.id=="hunter" then return true end
  if job.id=="trapper" then return (s.buildings.lodge or 0)>0 end
  if job.id=="tanner" then return (s.buildings.tannery or 0)>0 end
  if job.id=="charcutier" then return (s.buildings.smokehouse or 0)>0 end
  if job.id=="iron miner" then return (s.buildings.workshop or 0)>0 and s.mines.iron end
  if job.id=="coal miner" then return (s.buildings.workshop or 0)>0 and s.mines.coal end
  if job.id=="sulphur miner" then return (s.buildings.workshop or 0)>0 and s.mines.sulphur end
  if job.id=="steelworker" then return (s.buildings.steelworks or 0)>0 end
  if job.id=="armourer" then return (s.buildings.armoury or 0)>0 end
  return false
end
local function assigned_workers(s)
  local n=0; for _,v in pairs(s.worker_assign or {}) do n=n+v end; return n
end
local function work_catalog(s)
  for _,job in ipairs(ADR.workers) do
    local amount=(s.worker_assign and s.worker_assign[job.id]) or 0
    if amount>0 then
      local possible=true
      for k,v in pairs(job.delta) do if v<0 and (s.store[store_key(k)] or 0)<(-v*amount) then possible=false end end
      if possible then for k,v in pairs(job.delta) do add(s,k,v*amount) end end
    end
  end
end
local function village_actions(s)
  if s.village_panel=="build" then
    local a={}; for _,thing in ipairs(ADR.craftables) do if thing.group=="building" then a[#a+1]=thing end end; return a
  elseif s.village_panel=="craft" then
    local a={}; for _,thing in ipairs(ADR.craftables) do if thing.group~="building" then a[#a+1]=thing end end; return a
  elseif s.village_panel=="trade" then return ADR.trade_goods
  elseif s.village_panel=="workers" then
    local a={{id="清空职业分配",clear=true}}; for _,job in ipairs(ADR.workers) do a[#a+1]=job end; return a
  end
  return {{id="带补给出发",kind="travel"},{id="返回房间",kind="room"}}
end
local function cycle_village_panel(s)
  local p={"build","craft","trade","workers","travel"}; local at=1
  for i=1,#p do if p[i]==s.village_panel then at=i end end
  s.village_panel=p[(at%#p)+1]; s.selected=1
  say(s,"村庄账本："..({build="建造",craft="制造",trade="贸易",workers="职业",travel="远征"})[s.village_panel])
end
local function assign_catalog_worker(s, job)
  if job.clear then s.worker_assign={}; say(s,"所有村民回到空闲状态。") return end
  if not worker_available(s,job) then say(s,"此职业尚未解锁："..display_name(job.id)) return end
  s.worker_assign=s.worker_assign or {}
  if assigned_workers(s)>=s.villagers then say(s,"没有空闲村民；先清空分配。") return end
  s.worker_assign[job.id]=(s.worker_assign[job.id] or 0)+1; say(s,display_name(job.id).." +1")
end
local function unassign_catalog_worker(s, job)
  if job.clear then return end
  s.worker_assign=s.worker_assign or {}
  local assigned=s.worker_assign[job.id] or 0
  if assigned<=0 then say(s,display_name(job.id).." 尚无人手。") return end
  s.worker_assign[job.id]=assigned-1
  say(s,display_name(job.id).." -1")
end
local function fabricate(s, thing)
  if thing.maximum and (s.owned[thing.id] or 0)>=thing.maximum then say(s,"已经拥有："..display_name(thing.id)) return end
  if thing.blueprint and not s.blueprints[thing.id] then say(s,"缺少蓝图："..display_name(thing.id)) return end
  if not afford(s,thing.cost) then say(s,"制造器需要："..label_cost(thing.cost)) return end
  pay(s,thing.cost); s.owned[thing.id]=(s.owned[thing.id] or 0)+(thing.quantity or 1)
  if thing.id=="energy blade" or thing.id=="plasma rifle" then s.gear.sword=true end
  if thing.id=="kinetic armour" then s.maxhp=28; s.hp=s.maxhp end
  say(s,"制造完成："..display_name(thing.id))
end
local function reinforce_hull(s)
  if not afford(s,{alloy=ADR.ship.alloy_per_hull}) then say(s,"需要 1 异星合金加固船体。") return end
  pay(s,{alloy=ADR.ship.alloy_per_hull}); s.ship.hull=s.ship.hull+1; say(s,"船体加固至 "..s.ship.hull)
end
local function upgrade_thrusters(s)
  if not afford(s,{alloy=ADR.ship.alloy_per_thruster}) then say(s,"需要 1 异星合金升级推进器。") return end
  pay(s,{alloy=ADR.ship.alloy_per_thruster}); s.ship.thrusters=s.ship.thrusters+1; say(s,"推进器升级至 "..s.ship.thrusters)
end

local function choose_late_event(s)
  local ids={}
  if not s.events.trader then ids[#ids+1]="trader" end
  if not s.events.surveyor then ids[#ids+1]="surveyor" end
  if not s.events.ruined_trap and (s.buildings.trap or 0)>0 then ids[#ids+1]="ruined_trap" end
  if not s.events.beggar and (s.store.fur or 0)>=50 then ids[#ids+1]="beggar" end
  if not s.events.beast_attack and s.villagers>=4 then ids[#ids+1]="beast_attack" end
  if #ids==0 then return nil end
  -- 可复现的伪随机：存档不会因重启而改变，同一套策略仍可能因资源和行动数不同
  -- 先后遇到商人或测绘员。避免直接使用未定义种子的 math.random。
  s.rng=((s.rng or 17)*37+s.turns*11+s.store.wood*3+s.store.fur*5+s.store.meat) % 97
  return ids[(s.rng % #ids)+1]
end

local function population_cap(s) return (s.buildings.hut or 0)*4 end
local function increase_population(s)
  local space=population_cap(s)-s.villagers; if space<=0 then return end
  s.rng=((s.rng or 17)*29+s.turns*13)%997
  local gained=math.max(1,math.floor(space/2)+((s.rng or 0)%math.max(1,math.ceil(space/2))))
  s.villagers=math.min(population_cap(s),s.villagers+gained)
  say(s,gained==1 and "夜里有陌生人来到村庄。" or "一小群风尘仆仆的旅人住进了小屋。")
end
local function collect_traps(s)
  local traps=s.buildings.trap or 0; if traps<=0 then return end
  local baited=math.min(traps,s.store.bait or 0)
  -- Upstream bait creates one additional drop per baited trap, then is used
  -- up. This keeps the trapper job and nomad bait trade economically real.
  for n=1,traps+baited do
    s.rng=((s.rng or 17)*41+s.turns*17+n*7)%1000; local roll=s.rng/1000; local drop="charm"
    for _,entry in ipairs(ADR.trap_drops) do if roll<entry.under then drop=entry.id; break end end
    add(s,drop,1)
  end
  if baited>0 then add(s,"bait",-baited); say(s,"诱饵让 "..baited.." 个陷阱带回额外猎物。") else say(s,"陷阱带回了新的猎物。") end
end

local function advance(s)
  s.turns=s.turns+1; s.log_age=s.log_age+1
  for weapon,remaining in pairs(s.combat_cooldowns or {}) do
    if remaining>0 then s.combat_cooldowns[weapon]=remaining-1 end
  end
  if s.unlock.village then
    work_catalog(s)
    if s.store.wood>cap(s) then s.store.wood=cap(s) end
    if s.store.fur>cap(s) then s.store.fur=cap(s) end
    if s.store.iron>cap(s) then s.store.iron=cap(s) end
    if s.turns%6==0 then collect_traps(s) end
    if s.turns%12==0 then increase_population(s) end
  end
  if s.lit and not s.unlock.village then
    -- The fire consumes a unit only every three turns. That leaves deliberate
    -- gather/stoke decisions without turning e-ink play into a timer race.
    if s.turns%3==0 and s.fire>0 then
      s.fire=s.fire-1; s.warmth=s.fire
      if s.fire==0 then s.lit=false; say(s,"火熄了。黑暗重新填满房间。") end
    end
    if not s.builder and s.fire>=2 and s.turns>=5 then
      s.builder=true; say(s,"一个建造者在火边停下：这里能盖一间小屋。")
    end
    if s.builder and s.store.wood>=8 then
      s.unlock.village=true; s.buildings.hut=math.max(1,s.buildings.hut or 0); s.villagers=1; say(s,"建造者搭起第一间小屋；村庄开始成形。")
    end
  end
  -- The upstream path is found by buying a compass from the trading post,
  -- not by an arbitrary hut/weapon threshold.
  if s.unlock.path and not s.unlock.world and s.gear.water and s.buildings.cart>=1 then s.unlock.world=true; say(s,"地图摊在桌上。荒野在等待。") end
  -- Village events are modal on X4; never let them interrupt combat, a world
  -- move, or the launch sequence. They surface on the next village visit.
  if s.unlock.village and s.page=="village" and not s.event then
    if s.turns >= 12 and not s.events.wanderer then
      s.event={ id="wanderer", selected=1 }; s.page="event"; say(s,"一个陌生人站在火边。")
    elseif s.turns >= 24 and not s.events.illness then
      s.event={ id="illness", selected=1 }; s.page="event"; say(s,"村里有人发烧。")
    elseif s.turns >= 40 and not s.events.signal then
      s.event={ id="signal", selected=1 }; s.page="event"; say(s,"荒野深处传来断续信号。")
    elseif s.turns >= 52 and s.turns % 12 == 4 then
      local id=choose_late_event(s)
      if id then s.event={ id=id, selected=1 }; s.page="event"; say(s,event_intro(id)) end
    end
  end
  -- Room events surface only while the player is actually by the fire. Store
  -- their return page so a one-off trade never teleports a player to another
  -- part of the game after the choice is made.
  if s.unlock.village and s.page=="room" and not s.event then
    if not s.events.nomad and s.turns>=32 and (s.store.fur or 0)>=5 then
      s.event={ id="nomad", selected=1, return_page="room" }; s.page="event"; say(s,event_intro("nomad"))
    elseif not s.events.noises and s.turns>=48 and (s.store.wood or 0)>0 then
      s.event={ id="noises", selected=1, return_page="room" }; s.page="event"; say(s,event_intro("noises"))
    elseif not s.events.store_noises and s.turns>=56 and (s.store.wood or 0)>0 then
      s.event={ id="store_noises", selected=1, return_page="room" }; s.page="event"; say(s,event_intro("store_noises"))
    end
  end
end

local function resolve_event(s)
  local e=s.event; if not e then return end
  if e.id=="wanderer" then
    if e.selected==1 and s.villagers<population_cap(s) then s.villagers=s.villagers+1; say(s,"陌生人留下来，先替你添满柴堆。")
    else add(s,"wood",12); say(s,"没有空床位；陌生人留下木头，消失在雾里。") end
  elseif e.id=="illness" then
    if e.selected==1 and s.store.medicine>0 then add(s,"medicine",-1); say(s,"药草救回了病人；村庄躲过了一场失去。")
    elseif e.selected==1 then say(s,"没有药草。火边多了一把空椅子。")
    else add(s,"fur",4); say(s,"你选择守住储备，病人留下了毛皮。") end
  elseif e.id=="signal" then
    if e.selected==1 then add(s,"iron",3); say(s,"你循着信号找回一箱旧铁。") else add(s,"medicine",1); say(s,"你没有出门，反而在屋后发现药草。") end
  elseif e.id=="trader" then
    if e.selected==1 then
      if afford(s,{fur=4}) then pay(s,{fur=4}); add(s,"iron",6); say(s,"皮毛换成了六块可用的铁。") else say(s,"皮毛不够，商人留下了一句路标。") end
    else
      if afford(s,{meat=2}) then pay(s,{meat=2}); add(s,"medicine",1); say(s,"肉干换来一小包药草。") else say(s,"肉干不够，交易没有发生。") end
    end
  elseif e.id=="ruined_trap" then
    local lost=math.max(1,math.floor((s.buildings.trap or 1)/3))
    s.buildings.trap=math.max(0,(s.buildings.trap or 0)-lost)
    if e.selected==1 then add(s,"fur",30); add(s,"meat",30); add(s,"teeth",3); say(s,"你循着爪印找到受伤的巨兽。失去 "..lost.." 个陷阱，带回了猎物。")
    else say(s,"你守住村庄。"..lost.." 个毁坏的陷阱留在林边。") end
  elseif e.id=="beggar" then
    if e.selected==1 and afford(s,{fur=50}) then
      pay(s,{fur=50}); s.rng=((s.rng or 17)*43+s.turns*3)%3
      if s.rng==0 then add(s,"scales",20); say(s,"乞者留下了一包鳞片。") elseif s.rng==1 then add(s,"teeth",20); say(s,"乞者留下了一包兽牙。") else add(s,"cloth",20); say(s,"乞者留下了一卷干净布料。") end
    else say(s,"你没有交出毛皮。乞者走进了夜里。") end
  elseif e.id=="beast_attack" then
    local lost=math.max(1,math.floor(s.villagers/4))
    if e.selected==2 and s.store.medicine>0 then add(s,"medicine",-1); lost=math.max(0,lost-1); say(s,"药草稳住了伤员。")
    else say(s,"村民击退野兽，但付出了代价。") end
    s.villagers=math.max(0,s.villagers-lost); add(s,"fur",20); add(s,"meat",20); add(s,"teeth",2)
  elseif e.id=="nomad" then
    if e.selected==1 and afford(s,{fur=5}) then pay(s,{fur=5}); add(s,"bait",1); say(s,"游牧商交出一包诱饵：陷阱会更有效。")
    else say(s,"游牧商收紧背袋，消失在雾里。") end
  elseif e.id=="noises" then
    if e.selected==1 then
      s.rng=((s.rng or 17)*31+s.turns*19)%100
      if s.rng<30 then add(s,"wood",100); add(s,"fur",10); say(s,"门槛外留着一捆木柴和粗毛皮。夜里重新安静下来。")
      else say(s,"模糊的影子越过林线，什么也没有留下。") end
    else say(s,"你没有开门。脚步声渐渐远去。") end
  elseif e.id=="store_noises" then
    if e.selected==1 then
      local lost=math.max(1,math.floor((s.store.wood or 0)*0.1)); add(s,"wood",-lost)
      s.rng=((s.rng or 17)*47+s.turns*5)%3
      local found=math.max(1,math.floor(lost/5))
      if s.rng==0 then add(s,"scales",found); say(s,"少了一些木头，地上却散着鳞片。")
      elseif s.rng==1 then add(s,"teeth",found); say(s,"少了一些木头，地上却散着兽牙。")
      else add(s,"cloth",found); say(s,"少了一些木头，地上却散着布料。") end
    else say(s,"你把门闩得更紧。储物间很快安静下来。") end
  else
    if e.selected==1 then add(s,"iron",2); s.clue=true; say(s,"你帮他补全路线，飞船方向被圈了出来。") else add(s,"fur",3); say(s,"你收下了他留下的备用毛毡。") end
  end
  local return_page=e.return_page or "village"
  s.events[e.id]=true; s.event=nil; s.page=return_page; s.selected=1
end

local function prepare(s)
  if not s.unlock.world then say(s,"先修好村庄、准备水袋和货车。") return end
  s.page="world"; s.x=WORLD_CENTER; s.y=WORLD_CENTER
  s.food=s.owned["cargo drone"] and 80 or s.owned.convoy and 60 or s.owned.wagon and 40 or s.owned.rucksack and 24 or 12
  s.water=s.owned["fluid recycler"] and 80 or s.owned["water tank"] and 50 or s.owned.cask and 20 or s.gear.water and 10 or 5
  s.hp=s.maxhp; s.enemy=nil; s.travel_steps=0; say(s,"带着补给离开村庄。")
end
local function enemy_for(tile)
  if tile==";" then return {name="林狼",hp=5,atk=1,reward={fur=3,meat=2}} end
  if tile=="," then return {name="草原拾荒者",hp=4,atk=1,reward={meat=2,teeth=1}} end
  if tile=="." then return {name="荒原流浪者",hp=6,atk=2,reward={cloth=1,scales=1}} end
  if tile=="I" or tile=="C" or tile=="S" then return {name="矿坑掠夺者",hp=8,atk=2,reward={iron=4}} end
  if tile=="H" or tile=="V" or tile=="O" then return {name="废墟守卫",hp=11,atk=2,reward={iron=5,alloy=1}} end
  if tile=="Y" or tile=="X" then return {name=tile=="X" and "行刑者" or "城市守卫",hp=18,atk=3,reward={steel=2,alloy=2}} end
  return nil
end
local function return_home(s, text) s.page="village"; s.enemy=nil; s.food=0; s.water=0; say(s,text) end
local function site_intro(tile)
  return ({H="废屋里还有没有熄灭的灯。",V="洞穴深处传来金属摩擦声。",O="小镇的街道被风沙填满。",Y="城市的高楼像空洞的骨头。",P="前哨还留着一张作战图。",B="钻井的压力表仍在跳动。",F="战场上散着旧时代的弹壳。",M="沼泽吞没了脚印。",U="一只补给箱埋在灰里。",X="巨大战舰残骸嵌进了大地。"})[tile] or "这里留下了一段旧世界的痕迹。"
end
local function site_depth(tile) return ({H=2,V=3,O=3,Y=4,P=3,B=2,F=2,M=2,U=1,X=4})[tile] or 1 end
local function site_stage_text(tile,stage)
  local stories={
    H={"褪色的门牌在风里拍打。", "床板下藏着没被带走的东西。"},
    V={"洞壁渗水，矿车轨道通向黑暗。", "废弃钻机还留着余温。", "最深处传来金属摩擦。"},
    O={"路牌被沙埋住，橱窗后有影子移动。", "药店与五金铺之间有一条窄巷。", "钟楼下堆着旧世界的交换物。"},
    Y={"空楼群把风声折成低语。", "一部停摆电梯通向地下。", "档案室里仍有应急灯闪烁。", "市政厅核心锁着最后一扇门。"},
    P={"前哨的旗帜早已褪成灰色。", "作战图上标着一条撤离路线。", "弹药箱后有一间封死的指挥室。"},
    B={"压力表跳动，地下仍在呼吸。", "管线旁散着硫磺色结晶。"},
    F={"壕沟里只剩雨水和弹壳。", "装甲残骸把战场切成狭窄通道。"},
    M={"泥沼冒出细小气泡。", "倒下的树根围住了一处干地。"},
    U={"箱盖上还有褪色的补给编号。"},
    X={"舰体裂缝像一道通往天外的伤口。", "坠毁的甲板下仍有防御系统。", "反应堆舱室被异星金属封住。", "控制台前只剩离开的坐标。"},
  }
  local lines=stories[tile] or {"这里留着一段旧世界的痕迹。"}
  return TILE[tile].." · "..(lines[math.min(stage,#lines)] or lines[#lines]).."（"..stage.."/"..site_depth(tile).."）"
end
local function site_guard(tile,stage)
  if tile=="Y" or tile=="P" then return {name="巡逻兵",hp=8+stage*3,atk=2,reward={bullets=2,steel=1}} end
  if tile=="V" or tile=="B" then return {name="洞穴掠夺者",hp=6+stage*2,atk=2,reward={iron=3,coal=1}} end
  if tile=="F" or tile=="X" then return {name="旧军队残影",hp=9+stage*3,atk=3,reward={bullets=3,steel=1}} end
  if tile=="M" then return {name="沼泽猎手",hp=6+stage*2,atk=2,reward={medicine=1,scales=2}} end
  return {name="遗迹守卫",hp=5+stage*3,atk=2,reward={iron=2,alloy=1}}
end
local function resolve_site(s)
  local tile=s.site and s.site.tile; if not tile then return end
  local reward=({H={fur=8,meat=4},V={iron=8,coal=3},O={scales=12,teeth=6},Y={steel=4,alloy=2},P={bullets=8,medicine=1},B={sulphur=8,iron=4},F={bullets=12,steel=2},M={medicine=2,scales=4},U={meat=8,medicine=1},X={alloy=6,steel=5,bullets=20}})[tile] or {}
  for k,n in pairs(reward) do add(s,k,n) end
  if tile=="Y" then s.blueprints["kinetic armour"]=true; s.blueprints.disruptor=true end
  if tile=="P" then s.blueprints.hypo=true; s.blueprints.stim=true end
  if tile=="B" then s.blueprints["plasma rifle"]=true; s.blueprints["glow stone"]=true end
  s.landmarks=s.landmarks or {}; s.landmarks[tile]=(s.landmarks[tile] or 0)+1
  set_cell(s.map,s.x,s.y,"."); s.site=nil; s.page="world"
  local endings={H="你把废屋里还能用的物资带回包里。",V="洞穴的回声终于停下。",O="小镇的风又重新穿过空街。",Y="城市的灯彻底熄灭。",P="前哨的旧地图成为新的路线。",B="钻井的压力表缓缓归零。",F="战场留下的东西足够让人继续前行。",M="沼泽松开了脚印。",U="补给箱的封条在掌心碎开。",X="舰体记录了离开这颗星球的最后条件。"}
  say(s,(endings[tile] or "探索完成："..TILE[tile]).."  获得战利品。")
end
local function advance_site(s)
  local site=s.site; if not site then return end
  if site.stage>=site_depth(site.tile) then resolve_site(s); return end
  site.stage=site.stage+1
  -- Every deeper layer can hide a guard. The final layer is always contested for major sites.
  local guarded=site.tile~="U" and (site.stage%2==0 or site.stage==site_depth(site.tile))
  if guarded then s.enemy=site_guard(site.tile,site.stage); s.page="fight"; say(s,s.enemy.name.."挡住了更深处的路。")
  else say(s,site_stage_text(site.tile,site.stage)) end
end
local function retreat_site(s)
  local tile=s.site and s.site.tile; s.site=nil; s.page="world"; say(s,"你从"..(TILE[tile] or "地标").."撤回荒野。")
end
local function find_tile(s,tile)
  if tile=="W" then s.unlock.ship=true; s.unlock.fabricator=true; set_cell(s.map,s.x,s.y,"."); say(s,"坠毁飞船与制造器仍有一点反应。你标下了位置。")
  elseif tile=="A" then return_home(s,"回到村庄。火还亮着。")
  elseif tile=="I" then s.mines=s.mines or {}; s.mines.iron=true; add(s,"iron",6); set_cell(s.map,s.x,s.y,"."); say(s,"找到铁矿。村庄的矿工现在可以开采铁。")
  elseif tile=="C" then s.mines=s.mines or {}; s.mines.coal=true; add(s,"coal",6); set_cell(s.map,s.x,s.y,"."); say(s,"找到煤矿。村庄的矿工现在可以开采煤。")
  elseif tile=="S" then s.mines=s.mines or {}; s.mines.sulphur=true; add(s,"sulphur",6); set_cell(s.map,s.x,s.y,"."); say(s,"找到硫磺矿。村庄的矿工现在可以开采硫磺。")
  elseif tile=="H" or tile=="V" or tile=="O" or tile=="Y" or tile=="P" or tile=="B" or tile=="F" or tile=="M" or tile=="U" or tile=="X" then
    s.site={tile=tile,stage=1}; s.page="site"; s.selected=1; say(s,site_intro(tile))
  else
    local e=enemy_for(tile)
    local encounter=((s.x*19+s.y*23+s.turns*7)%1000)/1000<ADR.world.fight_chance
    if e and (tile=="X" or encounter) then s.enemy=e; s.page="fight"; say(s,e.name.."挡住了去路。") else say(s,"只有风穿过荒地。") end
  end
end
local function move_world(s,dx,dy)
  local nx,ny=s.x+dx,s.y+dy
  if nx<1 or ny<1 or nx>#s.map or ny>#s.map[1] then say(s,"荒野在这里终止。") return end
  s.x,s.y=nx,ny; s.travel_steps=(s.travel_steps or 0)+1
  if s.travel_steps%ADR.world.moves_per_food==0 then s.food=s.food-1 end
  if s.travel_steps%ADR.world.moves_per_water==0 then s.water=s.water-1 end
  if s.food<0 or s.water<0 then return_home(s,"补给耗尽。你踉跄着回到火边。") return end
  local k=nx..":"..ny; local tile=cell(s.map,nx,ny)
  if not s.visited[k] then s.visited[k]=true; find_tile(s,tile) else say(s,"脚印还在。") end
end
local function weapon_options(s)
  local options={"fists"}
  for _,id in ipairs({"bone spear","iron sword","steel sword","bayonet","rifle","energy blade","plasma rifle","disruptor","bolas","grenade"}) do
    if (s.owned[id] or 0)>0 or ((id=="bolas" or id=="grenade") and (s.store[id] or 0)>0) then options[#options+1]=id end
  end
  return options
end
local function active_weapon(s)
  local options=weapon_options(s); s.weapon_slot=clamp(s.weapon_slot or 1,1,#options)
  return options[s.weapon_slot], options
end
local function switch_weapon(s,d)
  local _,options=active_weapon(s); s.weapon_slot=clamp((s.weapon_slot or 1)+d,1,#options); say(s,"武器："..display_name(active_weapon(s)))
end
local function fight(s, action)
  local e=s.enemy; if not e then return end
  if action=="heal" then
    if (s.owned.hypo or 0)>0 then s.owned.hypo=s.owned.hypo-1; s.hp=math.min(s.maxhp,s.hp+ADR.world.hypo_heal); say(s,"急救针迅速止住了血。")
    elseif s.store.medicine>0 then add(s,"medicine",-1); s.hp=math.min(s.maxhp,s.hp+ADR.world.meds_heal); say(s,"药草止住了血。") else say(s,"没有药草或急救针。") end
    return
  end
  if action=="stim" then
    if (s.owned.stim or 0)>0 then s.owned.stim=s.owned.stim-1; e.stunned=2; say(s,"兴奋剂让时间慢了下来；敌人被压制。") else say(s,"没有兴奋剂。") end
    return
  end
  if action=="eat" then
    if s.store["cured meat"] and s.store["cured meat"]>0 then add(s,"cured meat",-1); s.hp=math.min(s.maxhp,s.hp+ADR.world.meat_heal); say(s,"吃下肉干，恢复体力。")
    elseif s.store.meat and s.store.meat>0 then add(s,"meat",-1); s.hp=math.min(s.maxhp,s.hp+4); say(s,"吃下肉。") else say(s,"没有可吃的补给。") end
    return
  end
  local weapon=active_weapon(s); local spec=ADR.weapons[weapon] or ADR.weapons.fists
  local cooldown=(s.combat_cooldowns or {})[weapon] or 0
  if cooldown>0 then say(s,display_name(weapon).."还需冷却 "..cooldown.." 回合。") return end
  if spec.cost and not afford(s,spec.cost) then say(s,display_name(weapon).."缺少消耗品。") return end
  if spec.cost then pay(s,spec.cost) end
  s.combat_cooldowns=s.combat_cooldowns or {}; s.combat_cooldowns[weapon]=spec.cooldown or 1
  s.rng=((s.rng or 17)*53+(s.turns or 0)*7+(s.weapon_slot or 1))%997
  if (s.rng/997)>ADR.world.base_hit_chance then
    s.hp=s.hp-e.atk
    if s.hp<=0 then s.hp=0; return_home(s,"攻击落空。荒野把你击倒，又有人把你拖回村庄。") else say(s,"攻击落空；"..e.name.."反击"..e.atk.."。") end
    return
  end
  local hit=spec.damage
  if hit=="stun" then e.stunned=1; hit=0 else e.hp=e.hp-hit end
  if e.hp<=0 then
    for k,n in pairs(e.reward) do add(s,k,n) end
    s.page=s.site and "site" or "world"; s.enemy=nil; say(s,e.name.."倒下。你可以继续探索。") return
  end
  if e.stunned and e.stunned>0 then e.stunned=e.stunned-1; say(s,display_name(weapon).."使敌人暂时失去行动。") return end
  s.hp=s.hp-e.atk
  if s.hp<=0 then s.hp=0; return_home(s,"你被荒野击倒，但有人把你拖回村庄。") else say(s,"你造成"..hit.."伤害；"..e.name.."反击"..e.atk.."。") end
end
local function next_space_hazard(space)
  -- The next wave is intentionally deterministic and independent from the
  -- chosen lane. Players can read it on the e-ink display and steer one lane
  -- at a time, so the flight is a skill check rather than a hidden die roll.
  space.rng=(space.rng*37+space.altitude*17)%997
  return (space.rng%5)+1
end
local function new_space(s)
  local space={altitude=0,hull=s.ship.hull,lane=3,hazards={},rng=(s.rng or 17)}
  space.next_lane=next_space_hazard(space)
  return space
end
local function space_step(s, direction)
  local space=s.space; if not space then return end
  if direction=="left" then space.lane=math.max(1,space.lane-1) elseif direction=="right" then space.lane=math.min(5,space.lane+1) end
  local hazard_lane=space.next_lane or next_space_hazard(space)
  space.hazards=space.hazards or {}
  for _,hazard in ipairs(space.hazards) do hazard.age=(hazard.age or 0)+1 end
  space.hazards[#space.hazards+1]={lane=hazard_lane,age=0}
  while #space.hazards>5 do table.remove(space.hazards,1) end
  local altitude_gain=3+s.ship.thrusters
  space.altitude=space.altitude+altitude_gain
  if hazard_lane==space.lane and (space.rng%3~=0) then
    space.hull=space.hull-1; say(s,"碎片击中船体。剩余 "..space.hull)
    if space.hull<=0 then s.page="ship"; s.space=nil; say(s,"飞船坠回地面；需要重新加固船体。") return end
  else say(s,"穿过碎片云。高度 "..math.min(60,space.altitude).."/60") end
  if space.altitude>=60 then s.ending=true; s.page="ending"; s.space=nil; say(s,"星球缩成一粒光。") end
  if s.page=="space" then space.next_lane=next_space_hazard(space) end
end
local function launch(s)
  if not s.unlock.ship then say(s,"先在荒野找到坠毁飞船。") return end
  if s.ship.hull<=0 then say(s,"船体还没有加固；至少需要一块异星合金。") return end
  if not s.ship.warned then s.page="liftoff"; s.selected=1; say(s,"这次起飞后，不会再回到地面。") return end
  s.space=new_space(s); s.page="space"; say(s,"再次点火，穿过碎片云。")
end

local function choose(s, d)
  local n = s.page=="room" and 1 or (s.page=="village" and #village_actions(s) or (s.page=="fabricator" and #ADR.fabricator or (s.page=="liftoff" or s.page=="site") and 2 or (s.page=="path" and 4 or 3)))
  s.selected=clamp(s.selected+d,1,n)
end
local function act(s)
  if s.page=="room" then
    if not s.lit then s.lit=true; s.fire=4; s.warmth=s.fire; say(s,"火被点亮。先找些木头。")
    elseif s.store.wood<=0 then say(s,"没有木头可添。按 LEFT 收集木头。")
    else add(s,"wood",-1); s.fire=math.min(8,s.fire+3); s.warmth=s.fire; say(s,"你添了一根木头。火焰更旺了。") end
  elseif s.page=="village" then
    local action=village_actions(s)[s.selected]
    if s.village_panel=="build" or s.village_panel=="craft" then build_catalog(s,action)
    elseif s.village_panel=="trade" then
      if (s.buildings["trading post"] or 0)<1 then say(s,"需要先建造 trading post。") else buy_trade_good(s,action) end
    elseif s.village_panel=="workers" then assign_catalog_worker(s,action)
    elseif action.kind=="travel" then prepare(s) else s.page="room"; say(s,"回到房间。") end
  elseif s.page=="path" then
    if s.selected==1 then local yield=(s.buildings.cart or 0)>0 and 50 or 10; add(s,"wood",yield); say(s,"带回 "..yield.." 木头。")
    elseif s.selected==2 then
      if (s.buildings.trap or 0)<=0 then say(s,"还没有布置陷阱。") else collect_traps(s) end
    elseif s.selected==3 then add(s,"iron",2); say(s,"从浅矿层挖到铁。")
    else s.page="village"; say(s,"回到村庄。") end
  elseif s.page=="fabricator" then fabricate(s,ADR.fabricator[s.selected])
  elseif s.page=="ship" then
    if s.selected==1 then reinforce_hull(s) elseif s.selected==2 then upgrade_thrusters(s) else launch(s) end
  elseif s.page=="liftoff" then
    if s.selected==1 then s.ship.warned=true; s.space=new_space(s); s.page="space"; say(s,"推进器点火。穿过碎片云。")
    else s.page="ship"; say(s,"你在舷窗前多停留了一会。") end
  end
end
local function gather_room_wood(s)
  add(s,"wood",2); say(s,"你从屋外抱回 2 木头。")
end

local function tabs(s)
  local t={"房间"}; if s.unlock.village then t[#t+1]="村庄" end; if s.unlock.path then t[#t+1]="小径" end
  if s.unlock.world then t[#t+1]="荒野" end; if s.unlock.fabricator then t[#t+1]="制造器" end; if s.unlock.ship then t[#t+1]="飞船" end return t
end
local function tab(s,d)
  local t=tabs(s); local labels={room="房间",village="村庄",path="小径",world="荒野",fabricator="制造器",ship="飞船"}; local current=1
  for i=1,#t do if t[i]==labels[s.page] then current=i end end
  current=clamp(current+d,1,#t); s.page=({["房间"]="room",["村庄"]="village",["小径"]="path",["荒野"]="world",["制造器"]="fabricator",["飞船"]="ship"})[t[current]]; s.selected=1
end

function on_load(ctx) ctx:set_tick(500); ctx:invalidate() end
function on_tick(ctx, _dt) local s=state(ctx); advance(s); ctx:invalidate() end
function on_input(ctx, ev)
  if ev.type~="key" or ev.phase~="down" then return false end
  local s=state(ctx)
  if s.ending then if ev.key=="ok" then ctx.state.dark_room_x4=fresh() else ctx:quit() end; ctx:invalidate(); return true end
  if s.page=="event" then
    if ev.key=="up" then s.event.selected=1 elseif ev.key=="down" then s.event.selected=2 elseif ev.key=="ok" then resolve_event(s) else return false end
  elseif s.page=="site" then
    if ev.key=="up" then s.selected=1 elseif ev.key=="down" then s.selected=2 elseif ev.key=="ok" then if s.selected==1 then advance_site(s) else retreat_site(s) end elseif ev.key=="back" then retreat_site(s) else return false end
  elseif s.page=="fight" then
    if ev.key=="ok" then fight(s,"attack") elseif ev.key=="back" then fight(s,"heal") elseif ev.key=="left" then fight(s,"eat") elseif ev.key=="right" then fight(s,"stim") elseif ev.key=="up" then switch_weapon(s,-1) elseif ev.key=="down" then switch_weapon(s,1) else return false end
  elseif s.page=="space" then
    if ev.key=="left" or ev.key=="right" then space_step(s,ev.key) elseif ev.key=="ok" then space_step(s,"none") else return false end
  elseif s.page=="world" then
    if ev.key=="left" then move_world(s,-1,0) elseif ev.key=="right" then move_world(s,1,0) elseif ev.key=="up" then move_world(s,0,-1) elseif ev.key=="down" then move_world(s,0,1) elseif ev.key=="ok" then return_home(s,"你沿着记忆中的路折返。") elseif ev.key=="back" then
      if s.unlock.ship then s.page="ship"; s.selected=1; say(s,"飞船的信号仍在等待。") else s.page="village" end
    else return false end
  elseif s.page=="village" and ev.key=="back" then cycle_village_panel(s)
  elseif s.page=="village" and s.village_panel=="workers" and ev.key=="left" then unassign_catalog_worker(s,village_actions(s)[s.selected])
  elseif s.page=="room" and ev.key=="left" then gather_room_wood(s)
  elseif ev.key=="left" then tab(s,-1) elseif ev.key=="right" then tab(s,1) elseif ev.key=="up" then choose(s,-1) elseif ev.key=="down" then choose(s,1) elseif ev.key=="ok" then act(s) elseif ev.key=="back" then ctx:quit() else return false end
  advance(s); ctx:invalidate(); return true
end

local function text(g,x,y,v,c) g:text(x,y,v,{color=c or 15}) end
local function row(g,s,y,label,value,focus)
  if focus then
    -- X4's system_small glyphs extend farther below their draw origin than
    -- the old 34px highlight assumed. Give every row a real text safe area
    -- and put the divider after the glyph, never through it.
    g:rect(20,y-10,440,42,{fill=true,color=15}); text(g,32,y,label,0); text(g,406,y,value,0)
  else
    g:line(24,y+32,456,y+32,{color=15}); text(g,32,y,label); text(g,406,y,value)
  end
end
local function stock(s) return "木"..s.store.wood.." 毛"..s.store.fur.." 铁"..s.store.iron end
local function draw_head(g,s,title,sw,show_stock)
  -- X4 的圆角面板会遮住最上方约 40 像素；把首行放进安全区，避免标题被硬件边框吃掉。
  g:clear(0); g:rect(0,42,sw,62,{fill=true,color=15}); text(g,20,76,title,0)
  if show_stock~=false then text(g,sw-180,76,stock(s),0) end
  g:line(20,116,sw - 20,116,{color=15})
end
local function draw_room(g,s,sw)
  draw_head(g,s,"房间",sw); text(g,30,136,s.lit and ("火焰 "..s.fire.." / 8") or "黑暗。寒冷。",15); g:rect(30,162,sw-60,180,{color=15})
  if s.lit then
    g:circle(240,244,48,{color=15}); g:circle(240,244,33,{fill=true,color=15}); g:circle(240,244,15,{fill=true,color=0})
    g:line(240,178,240,166,{color=15}); g:line(222,184,214,174,{color=15}); g:line(258,184,266,174,{color=15})
  else g:circle(240,244,12,{color=15}) end
  text(g,35,390,s.lit and "OK 添柴（消耗 1 木）" or "OK 点燃火堆",15)
  text(g,35,430,"LEFT 收集木头 +2；火焰每 3 回合消耗 1。",15)
  text(g,35,470,s.builder and "建造者在等待足够木材。" or "让火持续燃烧，建造者会到来。",15)
end
local function draw_village(g,s,sw)
  local panel_name={build="建造",craft="制造",trade="商队",workers="职业",travel="远征"}
  local actions=village_actions(s); local start=math.max(1,s.selected-5); start=math.min(start,math.max(1,#actions-9))
  draw_head(g,s,"村庄·"..panel_name[s.village_panel].." 人"..s.villagers.." 闲"..(s.villagers-assigned_workers(s)),sw)
  for line=0,9 do
    local i=start+line; local action=actions[i]; if action then
      local label, value=action.id, ""
      if s.village_panel=="build" or s.village_panel=="craft" then
        local count=catalog_count(s,action); local cost=catalog_cost(s,action)
        label=display_name(action.id).."  "..label_cost(cost); value=(action.maximum and count.."/"..action.maximum or count>0 and "有" or "")
      elseif s.village_panel=="trade" then label=display_name(action.id).."  "..label_cost(action.cost)
      elseif s.village_panel=="workers" then
        if action.clear then label="清空职业分配"; value="OK"
        else
          local enabled=worker_available(s,action); label=(enabled and "" or "锁 ")..display_name(action.id)
          value=((s.worker_assign and s.worker_assign[action.id]) or 0).." 人"
        end
      elseif action.kind=="travel" then value="OK" end
      row(g,s,142+line*40,label,value,s.selected==i)
    end
  end
  text(g,30,560,"BACK 切换账本  ·  ↑ ↓ 选择  ·  OK 执行",15)
  if s.village_panel=="workers" then text(g,30,600,"OK +1  ·  LEFT -1 ；职业产出每回合结算。",15)
  elseif s.village_panel=="trade" then text(g,30,600,"商队需要 trading post；价格沿用原作资源结构。",15)
  elseif s.village_panel=="craft" then text(g,30,600,"制造页以工坊为起点；武器与远征升级在这里完成。",15)
  else text(g,30,600,"建筑会解锁职业、贸易与远征能力。",15) end
  text(g,30,632,"储备：肉"..s.store.meat.." 皮"..s.store.leather.." 铁"..s.store.iron.." 煤"..(s.store.coal or 0).." 硫"..(s.store.sulphur or 0).." 钢"..(s.store.steel or 0),15)
end
local function draw_path(g,s,sw)
  draw_head(g,s,"小径",sw); local wood=(s.buildings.cart or 0)>0 and 50 or 10; local items={"收集木头 +"..wood,"检查陷阱","浅矿开采 +2 铁","返回村庄"}
  for i=1,#items do row(g,s,130+(i-1)*62,items[i],"OK",s.selected==i) end
  -- A quiet visual landmark makes this supply page feel like a path through
  -- the woods rather than a fourth ledger. It stays static for e-ink.
  g:rect(30,378,420,70,{color=15}); g:line(42,432,438,432,{color=15}); g:line(96,448,164,378,{color=15}); g:line(384,448,316,378,{color=15})
  for _,x in ipairs({64,110,370,416}) do g:line(x,430,x,394,{color=15}); g:line(x-12,414,x,394,{color=15}); g:line(x+12,414,x,394,{color=15}) end
  g:rect(224,414,32,18,{color=15}); g:line(224,414,240,398,{color=15}); g:line(256,414,240,398,{color=15})
  text(g,30,480,"小径是稳定补给；荒野才是远方。",15)
  text(g,30,524,"库存：木"..s.store.wood.." 肉"..s.store.meat.." 毛"..s.store.fur.." 铁"..s.store.iron.." 煤"..(s.store.coal or 0).." 硫"..(s.store.sulphur or 0),15)
end
local function draw_world(g,s,sw)
  draw_head(g,s,"荒野 "..s.x..","..s.y.."  食"..s.food.." 水"..s.water.." HP"..s.hp.."/"..s.maxhp,sw,false); local radius=s.owned["glow stone"] and 7 or 6; local u=radius==7 and 24 or 27; local ox=240-radius*u; local oy=138
  -- The complete map is 61×61; the glow stone earns a wider 15×15 ink view.
  for dy=-radius,radius do for dx=-radius,radius do
    local wx,wy=s.x+dx,s.y+dy; local k=wx..":"..wy; local tile=cell(s.map,wx,wy)
    local c=(dx==0 and dy==0) and "@" or (s.visited[k] and (ICON[tile] or "·") or ((tile=="#" or tile=="A") and (ICON[tile] or "#") or "?"))
    text(g,ox+(dx+radius)*u,oy+(dy+radius)*u,c,15)
  end end
  text(g,24,510,"A村庄  I/C/S矿点  H/V/O/Y遗迹  W飞船",15)
  text(g,24,548,"P前哨  B钻井  F战场  M沼泽  U补给  X行刑者",15)
  text(g,24,586,s.unlock.ship and "方向移动；OK 返回村庄；BACK 查看飞船。" or "方向移动；OK 或 BACK 返回村庄。",15)
end
local function draw_site(g,s,sw)
  local site=s.site; local tile=site.tile; draw_head(g,s,"地标探索",sw); text(g,34,158,site_stage_text(tile,site.stage),15); text(g,34,208,site.stage==1 and site_intro(tile) or "空气越来越冷。前面还有路。",15)
  g:rect(34,246,412,126,{color=15}); text(g,56,294,"深入可能遭遇守卫；抵达尽头才会带回战利品。",15)
  row(g,s,436,site.stage>=site_depth(tile) and "搜寻战利品" or "继续深入","OK",s.selected==1)
  row(g,s,484,"撤回荒野","BACK",s.selected==2)
  text(g,34,552,"↑ ↓ 选择；OK 确认。",15)
end
local function draw_fight(g,s,sw)
  local e=s.enemy; local weapon,options=active_weapon(s); local spec=ADR.weapons[weapon] or ADR.weapons.fists; local maxhp=e.maxhp or e.hp
  e.maxhp=e.maxhp or e.hp; draw_head(g,s,"遭遇",sw); text(g,35,150,e.name,15); g:rect(35,178,410,22,{color=15}); g:rect(36,179,math.floor(408*e.hp/e.maxhp),20,{fill=true,color=15})
  local cooling=(s.combat_cooldowns or {})[weapon] or 0
  text(g,35,245,"你："..s.hp.." / "..s.maxhp,15); text(g,35,306,"武器 "..display_name(weapon).."  "..s.weapon_slot.."/"..#options,15)
  text(g,35,350,cooling>0 and ("冷却 "..cooling.." 回合 · 可切换武器") or ("OK 攻击 "..(spec.damage=="stun" and "眩晕" or "伤害 "..spec.damage)),15)
  text(g,35,392,"↑ ↓ 切换武器  ·  ← 吃补给  ·  → 兴奋剂",15); text(g,35,432,"BACK 急救针/药草（优先急救针）",15)
  -- Opponent marker: a calm, high-contrast target that gives the encounter
  -- screen a focal point without animation or image assets.
  g:rect(154,480,172,122,{color=15}); g:circle(240,523,28,{color=15}); g:circle(240,523,9,{fill=true,color=15})
  g:line(190,574,290,574,{color=15}); g:line(214,602,240,551,{color=15}); g:line(266,602,240,551,{color=15})
  text(g,172,620,"锁定目标",15)
end
local function draw_event(g,s,sw)
  local e=s.event; draw_head(g,s,"村庄事件",sw)
  local title,body,a,b
  if e.id=="wanderer" then title="雾里的陌生人"; body="他问：这里还有位置吗？"; a="让他留下（+村民）"; b="给他一点火（+木头）"
  elseif e.id=="illness" then title="空椅子"; body="病人的呼吸很轻。"; a="用药草救他"; b="保住储备（+毛皮）"
  elseif e.id=="signal" then title="远方信号"; body="有东西在荒野另一端回应。"; a="跟随信号（+铁）"; b="留在村里（+药草）"
  elseif e.id=="trader" then title="雾中的商人"; body="他把铁块与药草平码在车板上。"; a="4 毛皮换 6 铁"; b="2 肉换一份药草"
  elseif e.id=="ruined_trap" then title="被毁的陷阱"; body="爪痕通向树林；损失已无法避免。"; a="追踪野兽（猎物更多）"; b="留守村庄（只失去陷阱）"
  elseif e.id=="beggar" then title="火边的乞者"; body="他请求五十张毛皮换取一点温暖。"; a="给 50 毛皮（随机回礼）"; b="请他离开"
  elseif e.id=="beast_attack" then title="野兽来袭"; body="村民正在抵挡林线外冲出的猛兽。"; a="一起反击（会有伤亡）"; b="用药草救治伤员（1 药草）"
  elseif e.id=="nomad" then title="门外的游牧商"; body="他只愿用毛皮交换一点实用的东西。"; a="5 毛皮换诱饵"; b="道别"
  elseif e.id=="noises" then title="墙外异响"; body="隔着门板，无法判断外面留下了什么。"; a="出去查看"; b="留在火边"
  elseif e.id=="store_noises" then title="储物间异响"; body="有什么东西躲在木料之间。"; a="进去查看（会少木头）"; b="把门闩紧"
  else title="残缺地图"; body="测绘员缺少最后一段路线。"; a="帮他补图（+铁、飞船线索）"; b="留下备用毛毡（+毛皮）" end
  text(g,30,130,title,15); text(g,30,180,body,15)
  row(g,s,300,a,"OK",e.selected==1); row(g,s,355,b,"OK",e.selected==2)
  text(g,30,430,"上下选择；OK 做出决定。",15)
end
local function draw_ship(g,s,sw)
  draw_head(g,s,"旧飞船",sw); text(g,35,150,"船体 "..s.ship.hull.."   推进器 "..s.ship.thrusters,15); g:rect(35,182,410,178,{color=15})
  -- Static line-art hull: nose, cockpit, cargo body and two engines remain
  -- legible in a one-bit refresh while making the upgrade screen feel owned.
  g:rect(126,266,228,52,{color=15}); g:line(126,266,172,226,{color=15}); g:line(172,226,310,226,{color=15}); g:line(310,226,354,266,{color=15})
  g:line(182,226,202,266,{color=15}); g:line(298,226,278,266,{color=15}); g:rect(216,238,48,20,{color=15})
  g:circle(142,292,20,{color=15}); g:circle(338,292,20,{color=15}); g:line(162,292,216,292,{color=15}); g:line(264,292,318,292,{color=15})
  g:line(188,318,158,350,{color=15}); g:line(292,318,322,350,{color=15}); g:line(236,318,236,350,{color=15}); g:line(252,318,252,350,{color=15})
  row(g,s,430,"加固船体  1 异星合金",s.ship.hull,s.selected==1)
  row(g,s,476,"升级推进器  1 异星合金",s.ship.thrusters,s.selected==2)
  row(g,s,522,"起飞",s.ship.hull>0 and "OK" or "需船体",s.selected==3)
  text(g,35,580,"船体至少为 1 才能离开。",15)
end
local function draw_fabricator(g,s,sw)
  draw_head(g,s,"嗡鸣制造器",sw); local start=math.max(1,s.selected-5); start=math.min(start,math.max(1,#ADR.fabricator-9))
  for line=0,8 do
    local i=start+line; local thing=ADR.fabricator[i]; if thing then
      local locked=thing.blueprint and not s.blueprints[thing.id]; local value=locked and "蓝图" or label_cost(thing.cost)
      row(g,s,142+line*42,(locked and "锁 " or "")..display_name(thing.id),value,s.selected==i)
    end
  end
  text(g,30,560,"Y 城市、P 前哨、B 钻井可找到后期蓝图。",15)
end
local function draw_liftoff(g,s,sw)
  draw_head(g,s,"准备离开",sw); text(g,34,170,"该离开这颗星球了。",15); text(g,34,218,"这次起飞后，不会再回来。",15)
  row(g,s,330,"起飞","OK",s.selected==1); row(g,s,380,"再停留一会","BACK",s.selected==2)
end
local function draw_space(g,s,sw)
  local space=s.space; draw_head(g,s,"碎片云",sw); text(g,34,146,"高度 "..math.min(60,space.altitude).." / 60",15); text(g,300,146,"船体 "..space.hull.."/"..s.ship.hull,15)
  text(g,34,178,"下一波碎片：第 "..(space.next_lane or "?").." 道（提前换道避开）",15)
  for lane=1,5 do
    local x=48+(lane-1)*88; g:line(x,194,x,460,{color=15})
    if lane==space.lane then g:rect(x-18,414,36,30,{fill=true,color=15}); text(g,x-6,436,"@",0) end
  end
  for _,hazard in ipairs(space.hazards or {}) do
    local hx=48+(hazard.lane-1)*88; local hy=250+(hazard.age or 0)*38
    if hy<396 then text(g,hx-6,hy,"*",15) end
  end
  text(g,34,526,"← → 换道并推进  ·  OK 保持航向",15)
end
function on_draw(ctx,g)
  local s=state(ctx); local sw=ctx.screen.width
  if s.page=="room" then draw_room(g,s,sw) elseif s.page=="village" then draw_village(g,s,sw) elseif s.page=="path" then draw_path(g,s,sw) elseif s.page=="world" then draw_world(g,s,sw) elseif s.page=="fight" then draw_fight(g,s,sw) elseif s.page=="event" then draw_event(g,s,sw) elseif s.page=="site" then draw_site(g,s,sw) elseif s.page=="fabricator" then draw_fabricator(g,s,sw) elseif s.page=="ship" then draw_ship(g,s,sw) elseif s.page=="liftoff" then draw_liftoff(g,s,sw) elseif s.page=="space" then draw_space(g,s,sw)
  else
    g:clear(0); g:rect(26,74,428,448,{color=15}); g:line(26,132,454,132,{color=15})
    text(g,46,112,"离开",15); g:circle(240,238,54,{color=15}); g:line(240,184,240,292,{color=15}); g:line(186,238,294,238,{color=15})
    g:line(205,332,240,278,{color=15}); g:line(275,332,240,278,{color=15}); text(g,46,388,"你离开了那颗星球。",15)
    text(g,46,428,"地面上的火会继续亮着。",15); text(g,46,486,"OK 再次醒来  BACK 退出",15)
  end
  if s.log and s.page~="ending" then
    -- Keep the feedback panel inside the physical bottom safe area. The old
    -- 82px box placed a 20px hint below its border, which made long X4 pages
    -- look clipped and visually noisy.
    g:rect(20,660,440,120,{color=15}); g:line(20,710,460,710,{color=15})
    local hint="← → 切页  ·  ↑ ↓ 选择  ·  OK 行动"
    if s.page=="room" then hint="LEFT 收木  ·  OK 点火/添柴"
    elseif s.page=="village" then hint=s.village_panel=="workers" and "OK +1 · LEFT -1 · BACK账本" or "↑↓选择 · OK执行 · BACK账本"
    elseif s.page=="path" then hint="↑↓选择 · OK行动 · ←→切页"
    elseif s.page=="world" then hint=s.unlock.ship and "方向移动 · OK返村 · BACK飞船" or "方向移动 · OK/BACK返村"
    elseif s.page=="fight" then hint="↑↓武器 · ←补给 · →兴奋剂 · BACK治疗"
    elseif s.page=="event" then hint="↑↓选择 · OK决定"
    elseif s.page=="site" then hint="↑↓选择 · OK深入 · BACK撤回"
    elseif s.page=="fabricator" then hint="↑↓选择 · OK制造 · ←→切页"
    elseif s.page=="ship" then hint="↑↓选择 · OK改装/起飞 · ←→切页"
    elseif s.page=="liftoff" then hint="↑↓选择 · OK确认"
    elseif s.page=="space" then hint="←→换道推进 · OK保持航向"
    end
    text(g,32,678,s.log,15); text(g,32,726,hint,15)
  end
end
