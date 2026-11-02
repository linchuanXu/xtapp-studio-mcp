local M = {}

local function repeat_blocks(g, x, y, width, start, step, block_width, height)
  for offset = start, width - 1, step do
    g:rect(x + offset, y, math.min(block_width, width - offset), height,{fill=true,color=15})
  end
end

function M.divider_h(g, x, y, width)
  repeat_blocks(g, x, y, width, 0, 8, 5, 1)
end

function M.divider_v(g, x, y, height)
  for offset = 0, height - 1, 8 do
    g:rect(x, y + offset, 1, math.min(5, height - offset),{fill=true,color=15})
  end
end

return M
