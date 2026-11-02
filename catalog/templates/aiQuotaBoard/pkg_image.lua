-- pkg_image.lua: draw a packaged image by key (2.x g:image takes an image object)
local M = {}

function M.bind(ctx)
  M.package = ctx.package
end

function M.draw(g, key, x, y, opts)
  local img = key and M.package and M.package:image(key)
  if img then g:image(img, x, y, opts) end
end

return M
