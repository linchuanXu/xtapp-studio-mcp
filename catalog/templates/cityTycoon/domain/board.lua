local M = {}

M.start_cash = 1500
M.start_income = 200
M.labels = { "启程", "长城", "见闻", "故宫", "天坛", "京站", "西湖", "提案", "乌镇", "拙园", "管制", "都江", "南水", "武侯", "宽窄", "沪站", "广塔", "见闻", "港桥", "鼓浪", "公园", "雁塔", "三峡", "莫高", "嘉关", "维护", "外滩", "陆嘴" }
M.build_costs = { dawn = 50, spring = 75, ink = 100, harbor = 125, brocade = 150, skyline = 175 }

M.districts = {
  dawn = { name = "京华区", spaces = { 2, 4, 5 } },
  spring = { name = "江南区", spaces = { 7, 9, 10 } },
  ink = { name = "巴蜀区", spaces = { 12, 14, 15 } },
  harbor = { name = "岭南区", spaces = { 17, 19, 20 } },
  brocade = { name = "丝路区", spaces = { 22, 24, 25 } },
  skyline = { name = "东方区", spaces = { 27, 28 } },
}

M.spaces = {
  { kind = "start", name = "华夏启程" },
  { kind = "property", name = "八达岭长城", district = "dawn", price = 100, rent = { 10, 30, 90, 160 } },
  { kind = "event", name = "城市见闻", deck = "city" },
  { kind = "property", name = "故宫", district = "dawn", price = 110, rent = { 12, 36, 100, 180 } },
  { kind = "property", name = "天坛", district = "dawn", price = 120, rent = { 14, 42, 120, 200 } },
  { kind = "transit", name = "北京站", price = 180 },
  { kind = "property", name = "杭州西湖", district = "spring", price = 140, rent = { 16, 48, 140, 240 } },
  { kind = "event", name = "建设提案", deck = "plan" },
  { kind = "property", name = "乌镇", district = "spring", price = 150, rent = { 18, 54, 160, 270 } },
  { kind = "property", name = "拙政园", district = "spring", price = 160, rent = { 20, 60, 180, 300 } },
  { kind = "checkpoint", name = "交通管制站" },
  { kind = "property", name = "都江堰", district = "ink", price = 180, rent = { 22, 66, 200, 340 } },
  { kind = "utility", name = "南水北调", price = 160 },
  { kind = "property", name = "武侯祠", district = "ink", price = 190, rent = { 24, 72, 220, 370 } },
  { kind = "property", name = "宽窄巷子", district = "ink", price = 200, rent = { 26, 78, 240, 400 } },
  { kind = "transit", name = "上海站", price = 180 },
  { kind = "property", name = "广州塔", district = "harbor", price = 220, rent = { 30, 90, 270, 450 } },
  { kind = "event", name = "城市见闻", deck = "city" },
  { kind = "property", name = "港珠澳大桥", district = "harbor", price = 230, rent = { 32, 96, 290, 480 } },
  { kind = "property", name = "鼓浪屿", district = "harbor", price = 240, rent = { 34, 102, 310, 520 } },
  { kind = "park", name = "人民公园" },
  { kind = "property", name = "大雁塔", district = "brocade", price = 260, rent = { 38, 114, 340, 570 } },
  { kind = "utility", name = "三峡电站", price = 160 },
  { kind = "property", name = "莫高窟", district = "brocade", price = 270, rent = { 40, 120, 360, 600 } },
  { kind = "property", name = "嘉峪关", district = "brocade", price = 280, rent = { 42, 126, 380, 640 } },
  { kind = "tax", name = "文旅维护", amount = 120 },
  { kind = "property", name = "上海外滩", district = "skyline", price = 320, rent = { 50, 150, 450, 750 } },
  { kind = "property", name = "陆家嘴", district = "skyline", price = 340, rent = { 54, 162, 490, 820 } },
}

function M.space(index)
  local n = tonumber(index) or index
  return assert(M.spaces[n], "unknown board space: " .. tostring(index))
end

function M.is_asset(space)
  return space.kind == "property" or space.kind == "transit" or space.kind == "utility"
end

function M.asset_spaces()
  local out = {}
  for index, space in ipairs(M.spaces) do if M.is_asset(space) then out[#out + 1] = index end end
  return out
end

return M
