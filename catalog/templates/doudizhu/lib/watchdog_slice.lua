-- 长计算切片：每次 ctx.budget:extend() 把当前回调的截止时间推到 11 秒后
-- （单个回调最长 30 秒）。应用仍须维护更短的独立决策预算，到点返回当前最佳结果。
-- extend 只对当前回调有效。
local M = {
  ctx = nil,
  started_ms = 0,
  last_ms = 0,
  interval_ms = 1000,
  max_runtime_ms = 2000,
}

local function now_ms(ctx)
  return ctx.clock:millis()
end

local function elapsed_ms(now, started)
  if now < started then return 0 end
  return now - started
end

function M.begin(ctx, options)
  if M.ctx ~= nil then return nil, "already_active" end
  local ok, err = ctx.budget:extend()
  if ok ~= true then return nil, err or "inactive" end
  options = options or {}
  M.interval_ms = math.max(1000, math.min(2000, math.floor(tonumber(options.feed_interval_ms) or 1000)))
  M.max_runtime_ms = math.max(1, math.min(10000, math.floor(tonumber(options.max_runtime_ms) or 2000)))
  M.ctx = ctx
  M.started_ms = now_ms(ctx)
  M.last_ms = M.started_ms
  return true
end

function M.checkpoint()
  local ctx = M.ctx
  if type(ctx) ~= "table" then return nil, "inactive" end
  local now = now_ms(ctx)
  if elapsed_ms(now, M.started_ms) >= M.max_runtime_ms then return false, "app_budget_exhausted" end
  if elapsed_ms(now, M.last_ms) < M.interval_ms then return true end
  local ok, err = ctx.budget:extend()
  if ok ~= true then error("budget extend failed: " .. tostring(err or "inactive"), 0) end
  M.last_ms = now
  return true
end

-- 兼容既有策略调用点；新代码统一把它当可返回 false 的检查点。
M.feed = M.checkpoint

function M.finish()
  M.ctx = nil
  M.started_ms = 0
  M.last_ms = 0
end

return M
