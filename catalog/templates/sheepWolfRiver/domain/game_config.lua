local M = {}

M.DATA_VERSION = 9
M.MIN_ANIMALS = 3
M.MAX_ANIMALS = 52
M.LEVEL_COUNT = 50
M.MAX_HISTORY_LINES = 6
M.DESIGN_WIDTH = 480
M.DESIGN_HEIGHT = 800

-- X4 Pro 固件默认字库已经包含中文。这里统一按真机字形宽度估算，
-- 不再把 UTF-8 字节数当成文字宽度，也不捆绑桌面 TTF。
M.FONT = {
  ascii_width = 10,
  cjk_width = 20,
  line_height = 28,
}

M.COLORS = {
  white = 0,
  light = 3,
  mid = 8,
  dark = 12,
  black = 15,
}

-- 前两关使用3格，后续使用5格；最后一格固定为船夫3。
-- 路径保存会去掉0并排序，例如12003规范为123，22223代表4狼+船夫。
M.MAX_INPUT_SLOTS = 5

function M.move_digits(sheep, wolves)
  return string.rep("1", sheep) .. string.rep("2", wolves) .. "3"
end

M.RESULT_TEXT = {
  duplicate = "恭喜你成功运羊，但是此方案先前已经找到，请再加油！",
  new = "恭喜你成功运羊，而且这个是新的方案！",
  failure = "抱歉您违反了规则，此方案报废，请再努力！",
}

return M
