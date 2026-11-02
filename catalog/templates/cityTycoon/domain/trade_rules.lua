local Board = require("domain.board")

local M = {}

local function contains(values, target)
  for _, value in ipairs(values or {}) do if value == target then return true end end
  return false
end

local function validate_assets(state, owner, indexes)
  local seen = {}
  for _, index in ipairs(indexes or {}) do
    assert(not seen[index], "duplicate trade asset"); seen[index] = true
    local asset = assert(state.assets[index], "unknown trade asset")
    assert(asset.owner == owner, "trade asset owner mismatch")
    local space = Board.space(index)
    if space.kind == "property" then
      for _, other_index in ipairs(Board.districts[space.district].spaces) do assert(state.assets[other_index].level == 0, "district still has buildings") end
    end
  end
end

function M.start(state, target)
  assert(state.phase == "pre_roll" or state.phase == "optional_actions", "trade not allowed now")
  assert(target ~= state.current and state.players[target] and not state.players[target].bankrupt, "invalid trade target")
  state.pending = { kind = "trade", from = state.current, to = target, cash_from = 0, cash_to = 0, assets_from = {}, assets_to = {}, cards_from = 0, cards_to = 0, return_phase = state.phase }
  state.phase = "trade"
end

function M.set_offer(state, offer)
  local trade = assert(state.pending and state.pending.kind == "trade" and state.pending, "no trade")
  trade.cash_from = math.max(0, math.floor(offer.cash_from or 0)); trade.cash_to = math.max(0, math.floor(offer.cash_to or 0))
  trade.cards_from = math.max(0, math.floor(offer.cards_from or 0)); trade.cards_to = math.max(0, math.floor(offer.cards_to or 0))
  trade.assets_from = offer.assets_from or {}; trade.assets_to = offer.assets_to or {}
  validate_assets(state, trade.from, trade.assets_from); validate_assets(state, trade.to, trade.assets_to)
  assert(state.players[trade.from].cash >= trade.cash_from and state.players[trade.to].cash >= trade.cash_to, "trade cash unavailable")
  assert(state.players[trade.from].pass_cards >= trade.cards_from and state.players[trade.to].pass_cards >= trade.cards_to, "trade cards unavailable")
  assert(not (trade.cash_from > 0 and trade.cash_to > 0), "cash cannot flow both ways")
  for _, index in ipairs(trade.assets_from) do assert(not contains(trade.assets_to, index), "asset on both sides") end
end

function M.accept(state)
  local trade = assert(state.pending and state.pending.kind == "trade" and state.pending, "no trade")
  validate_assets(state, trade.from, trade.assets_from); validate_assets(state, trade.to, trade.assets_to)
  local from, to = state.players[trade.from], state.players[trade.to]
  assert(from.cash >= trade.cash_from and to.cash >= trade.cash_to, "trade cash changed")
  from.cash = from.cash - trade.cash_from + trade.cash_to; to.cash = to.cash - trade.cash_to + trade.cash_from
  from.pass_cards = from.pass_cards - trade.cards_from + trade.cards_to; to.pass_cards = to.pass_cards - trade.cards_to + trade.cards_from
  for _, index in ipairs(trade.assets_from) do state.assets[index].owner = trade.to end
  for _, index in ipairs(trade.assets_to) do state.assets[index].owner = trade.from end
  state.phase = trade.return_phase; state.pending = nil
end

function M.decline(state)
  local trade = assert(state.pending and state.pending.kind == "trade" and state.pending, "no trade")
  state.phase = trade.return_phase; state.pending = nil
end

return M
