-- A Dark Room parity catalogue.
-- Derived from doublespeakgames/adarkroom commit 1fada46 (MPL-2.0).
-- Data lives separately so the X4 UI can paginate the full game instead of
-- silently reducing it to the earlier prototype's short menu.
local C = {}

C.upstream_commit = "1fada46"
C.resources = {
  "wood", "fur", "meat", "scales", "teeth", "cloth", "charm", "leather", "cured meat", "bait",
  "iron", "coal", "sulphur", "steel", "bullets", "medicine", "energy cell", "bolas",
  "grenade", "alien alloy",
}

-- `cost(n)` receives the current number of the item, matching Room.Craftables.
C.craftables = {
  {id="trap", group="building", maximum=10, cost=function(n) return {wood=10+n*10} end},
  {id="cart", group="building", maximum=1, cost=function() return {wood=30} end},
  {id="hut", group="building", maximum=20, cost=function(n) return {wood=100+n*50} end},
  {id="lodge", group="building", maximum=1, cost=function() return {wood=200,fur=10,meat=5} end},
  {id="trading post", group="building", maximum=1, cost=function() return {wood=400,fur=100} end},
  {id="tannery", group="building", maximum=1, cost=function() return {wood=500,fur=50} end},
  {id="smokehouse", group="building", maximum=1, cost=function() return {wood=600,meat=50} end},
  {id="workshop", group="building", maximum=1, cost=function() return {wood=800,leather=100,scales=10} end},
  {id="steelworks", group="building", maximum=1, cost=function() return {wood=1500,iron=100,coal=100} end},
  {id="armoury", group="building", maximum=1, cost=function() return {wood=3000,steel=100,sulphur=50} end},
  {id="torch", group="tool", cost=function() return {wood=1,cloth=1} end},
  {id="waterskin", group="upgrade", maximum=1, cost=function() return {leather=50} end},
  {id="cask", group="upgrade", maximum=1, cost=function() return {leather=100,iron=20} end},
  {id="water tank", group="upgrade", maximum=1, cost=function() return {iron=100,steel=50} end},
  {id="bone spear", group="weapon", cost=function() return {wood=100,teeth=5} end},
  {id="rucksack", group="upgrade", maximum=1, cost=function() return {leather=200} end},
  {id="wagon", group="upgrade", maximum=1, cost=function() return {wood=500,iron=100} end},
  {id="convoy", group="upgrade", maximum=1, cost=function() return {wood=1000,iron=200,steel=100} end},
  {id="l armour", group="upgrade", maximum=1, cost=function() return {leather=200,scales=20} end},
  {id="i armour", group="upgrade", maximum=1, cost=function() return {leather=200,iron=100} end},
  {id="s armour", group="upgrade", maximum=1, cost=function() return {leather=200,steel=100} end},
  {id="iron sword", group="weapon", cost=function() return {wood=200,leather=50,iron=20} end},
  {id="steel sword", group="weapon", cost=function() return {wood=500,leather=100,steel=20} end},
  {id="rifle", group="weapon", cost=function() return {wood=200,steel=50,sulphur=50} end},
}

C.trade_goods = {
  {id="scales", cost={fur=150}}, {id="teeth", cost={fur=300}},
  {id="iron", cost={fur=150,scales=50}}, {id="coal", cost={fur=200,teeth=50}},
  {id="steel", cost={fur=300,scales=50,teeth=50}}, {id="medicine", cost={scales=50,teeth=30}},
  {id="bullets", cost={scales=10}}, {id="energy cell", cost={scales=10,teeth=10}},
  {id="bolas", cost={teeth=10}}, {id="grenade", cost={scales=100,teeth=50}},
  {id="bayonet", cost={scales=500,teeth=250}},
  {id="alien alloy", cost={fur=1500,scales=750,teeth=300}},
  {id="compass", maximum=1, cost={fur=400,scales=20,teeth=10}},
}

C.workers = {
  {id="gatherer", delta={wood=1}}, {id="hunter", delta={fur=0.5,meat=0.5}},
  {id="trapper", delta={meat=-1,bait=1}}, {id="tanner", delta={fur=-5,leather=1}},
  {id="charcutier", delta={meat=-5,wood=-5,["cured meat"]=1}},
  {id="iron miner", delta={["cured meat"]=-1,iron=1}},
  {id="coal miner", delta={["cured meat"]=-1,coal=1}},
  {id="sulphur miner", delta={["cured meat"]=-1,sulphur=1}},
  {id="steelworker", delta={iron=-1,coal=-1,steel=1}},
  {id="armourer", delta={steel=-1,sulphur=-1,bullets=1}},
}

C.trap_drops = {
  {under=0.5,id="fur"}, {under=0.75,id="meat"}, {under=0.85,id="scales"},
  {under=0.93,id="teeth"}, {under=0.995,id="cloth"}, {under=1.0,id="charm"},
}

C.weapons = {
  fists={damage=1,cooldown=2}, ["bone spear"]={damage=2,cooldown=2}, ["iron sword"]={damage=4,cooldown=2},
  ["steel sword"]={damage=6,cooldown=2}, bayonet={damage=8,cooldown=2}, rifle={damage=5,cooldown=1,cost={bullets=1}},
  ["laser rifle"]={damage=8,cooldown=1,cost={["energy cell"]=1}}, grenade={damage=15,cooldown=5,cost={grenade=1}},
  bolas={damage="stun",cooldown=15,cost={bolas=1}}, ["plasma rifle"]={damage=12,cooldown=1,cost={["energy cell"]=1}},
  ["energy blade"]={damage=10,cooldown=2}, disruptor={damage="stun",cooldown=15},
}

C.world = {
  radius=30, village_x=30, village_y=30, base_water=10, moves_per_food=2, moves_per_water=1,
  base_health=10, base_hit_chance=0.8, meat_heal=8, meds_heal=20, hypo_heal=30, fight_chance=0.2,
  tiles={village="A",iron_mine="I",coal_mine="C",sulphur_mine="S",forest=";",field=",",barrens=".",road="#",
    house="H",cave="V",town="O",city="Y",outpost="P",ship="W",borehole="B",battlefield="F",swamp="M",cache="U",executioner="X"},
  landmarks={
    {id="ironmine",tile="I",num=1,min=5,max=5}, {id="coalmine",tile="C",num=1,min=10,max=10},
    {id="sulphurmine",tile="S",num=1,min=20,max=20}, {id="house",tile="H",num=10,min=0,max=45},
    {id="cave",tile="V",num=5,min=3,max=10}, {id="town",tile="O",num=10,min=10,max=20},
    {id="city",tile="Y",num=20,min=20,max=45}, {id="outpost",tile="P",num=3,min=12,max=35},
    {id="ship",tile="W",num=1,min=28,max=28}, {id="borehole",tile="B",num=10,min=15,max=45},
    {id="battlefield",tile="F",num=5,min=18,max=45}, {id="swamp",tile="M",num=1,min=15,max=45},
    {id="cache",tile="U",num=3,min=8,max=32}, {id="executioner",tile="X",num=1,min=28,max=28},
  },
}

C.ship = {base_hull=0,base_thrusters=1,alloy_per_hull=1,alloy_per_thruster=1}
C.fabricator = {
  {id="energy blade",group="weapon",cost={ ["alien alloy"]=1 }},
  {id="fluid recycler",group="upgrade",maximum=1,cost={ ["alien alloy"]=2 }},
  {id="cargo drone",group="upgrade",maximum=1,cost={ ["alien alloy"]=2 }},
  {id="kinetic armour",group="upgrade",maximum=1,blueprint=true,cost={ ["alien alloy"]=2 }},
  {id="disruptor",group="weapon",blueprint=true,cost={ ["alien alloy"]=1 }},
  {id="hypo",group="tool",blueprint=true,quantity=5,cost={ ["alien alloy"]=1 }},
  {id="stim",group="tool",blueprint=true,cost={ ["alien alloy"]=1 }},
  {id="plasma rifle",group="weapon",blueprint=true,cost={ ["alien alloy"]=1 }},
  {id="glow stone",group="tool",blueprint=true,cost={ ["alien alloy"]=1 }},
}
return C
