-- Public Xiangqi AI facade. Search internals live in chess_ai_core.
local Core = require("domain.chess_ai_core")
local M = {}

function M.begin(state, watchdog) return Core.begin(state, watchdog) end
function M.step(session, clock, elapsed_ms, watchdog)
  return Core.step(session, clock, elapsed_ms, watchdog)
end
function M.result(session) return Core.result(session) end
function M.cancel(session) return Core.cancel(session) end
function M.eval(board, side) return Core.eval(board, side) end
function M.mood(state) return Core.mood(state) end
function M.format_diagnostics(stats) return Core.format_diagnostics(stats) end

return M
