-- Compact static lazy loader: 4 groups.
local M = { source = "内置六十四卦基础卦辞" }
local CACHE = {}
local LOADERS = {
  function() return require("domain.hexagram_text_group_1") end,
  function() return require("domain.hexagram_text_group_2") end,
  function() return require("domain.hexagram_text_group_3") end,
  function() return require("domain.hexagram_text_group_4") end,
}
local GROUP_BY_NAME = {
  ["地风升"] = 3,
  ["地火明夷"] = 2,
  ["地雷复"] = 2,
  ["地山谦"] = 4,
  ["地水师"] = 3,
  ["地天泰"] = 1,
  ["地泽临"] = 1,
  ["兑为泽"] = 1,
  ["风地观"] = 4,
  ["风火家人"] = 2,
  ["风雷益"] = 2,
  ["风山渐"] = 4,
  ["风水涣"] = 3,
  ["风天小畜"] = 1,
  ["风泽中孚"] = 1,
  ["艮为山"] = 4,
  ["火地晋"] = 4,
  ["火风鼎"] = 3,
  ["火雷噬嗑"] = 2,
  ["火山旅"] = 4,
  ["火水未济"] = 3,
  ["火天大有"] = 1,
  ["火泽睽"] = 1,
  ["坎为水"] = 3,
  ["坤为地"] = 4,
  ["雷地豫"] = 4,
  ["雷风恒"] = 3,
  ["雷火丰"] = 2,
  ["雷山小过"] = 4,
  ["雷水解"] = 3,
  ["雷天大壮"] = 1,
  ["雷泽归妹"] = 1,
  ["离为火"] = 2,
  ["乾为天"] = 1,
  ["山地剥"] = 4,
  ["山风蛊"] = 3,
  ["山火贲"] = 2,
  ["山雷颐"] = 2,
  ["山水蒙"] = 3,
  ["山天大畜"] = 1,
  ["山泽损"] = 1,
  ["水地比"] = 4,
  ["水风井"] = 3,
  ["水火既济"] = 2,
  ["水雷屯"] = 2,
  ["水山蹇"] = 4,
  ["水天需"] = 1,
  ["水泽节"] = 1,
  ["天地否"] = 4,
  ["天风姤"] = 3,
  ["天火同人"] = 2,
  ["天雷无妄"] = 2,
  ["天山遁"] = 4,
  ["天水讼"] = 3,
  ["天泽履"] = 1,
  ["巽为风"] = 3,
  ["泽地萃"] = 4,
  ["泽风大过"] = 3,
  ["泽火革"] = 2,
  ["泽雷随"] = 2,
  ["泽山咸"] = 4,
  ["泽水困"] = 3,
  ["泽天夬"] = 1,
  ["震为雷"] = 2,
}

function M.get(name)
  local groupIndex = GROUP_BY_NAME[name]
  if not groupIndex then return nil end
  if not CACHE[groupIndex] then CACHE[groupIndex] = LOADERS[groupIndex]() end
  return CACHE[groupIndex][name]
end

return M
