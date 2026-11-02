local M = {}

function M.get(ctx)
  local s = ctx.state
  if s.mode == nil then s.mode = "idle" end          -- idle / running / paused
  if s.elapsed_ms == nil then s.elapsed_ms = 0 end
  return s
end

-- 累计毫秒 -> {h, m, s}
function M.parts(ms)
  local total = math.floor(math.max(0, ms) / 1000)
  local h = math.floor(total / 3600)
  local m = math.floor((total % 3600) / 60)
  local s = total % 60
  return h, m, s
end

-- 累计毫秒 -> "HH:MM:SS"
function M.format(ms)
  local h, m, s = M.parts(ms)
  local function two(n) return n < 10 and "0" .. n or tostring(n) end
  return two(h) .. ":" .. two(m) .. ":" .. two(s)
end

-- 开始 / 暂停 切换
function M.toggle(s)
  s.mode = (s.mode == "running") and "paused" or "running"
end

-- 重新开始：清零并停止
function M.restart(s)
  s.elapsed_ms = 0
  s.mode = "idle"
end

-- 定时推进：运行中累加，静止时调用方控制不重绘
function M.tick(s, dt_ms)
  if s.mode ~= "running" then return false end
  s.elapsed_ms = s.elapsed_ms + dt_ms
  return true
end

function M.status(s)
  if s.mode == "running" then return "计时中" end
  if s.mode == "paused" then return "已暂停" end
  return "就绪"
end

return M
