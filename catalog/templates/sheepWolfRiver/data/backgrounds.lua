-- 1.6.0起不再为每个两岸状态准备图片。
-- 游戏始终使用一张没有羊、狼和底部数量条的纯场景背景；
-- 精确数量由界面上方的动态状态框显示。
local M = { SCENE = "scene_background" }

function M.key(...)
  return M.SCENE
end

function M.path(...)
  return M.SCENE
end

function M.initial(...)
  return M.SCENE
end

return M
