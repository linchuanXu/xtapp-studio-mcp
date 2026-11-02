local Board = require("domain.board")

local M = {}

local function eligible(state, auction, player_index)
  local player = state.players[player_index]
  return player and not player.bankrupt and not auction.passed[player_index] and player_index ~= auction.high_bidder
end

local function next_bidder(state, auction, after)
  for offset = 1, #state.players do
    local index = (after - 1 + offset) % #state.players + 1
    if eligible(state, auction, index) then return index end
  end
end

local function finish(state, auction)
  local result = { index = auction.index, winner = auction.high_bidder, amount = auction.high_bid }
  if auction.high_bidder then
    local winner = state.players[auction.high_bidder]
    winner.cash = winner.cash - auction.high_bid
    state.assets[auction.index].owner = auction.high_bidder
  end
  state.pending = nil
  state.phase = "optional_actions"
  return result
end

function M.start(state, index)
  assert(state.assets[index] and not state.assets[index].owner, "asset unavailable for auction")
  state.pending = {
    kind = "auction", index = index, high_bid = 0, high_bidder = nil,
    current_bidder = state.current, passed = {}, minimum_step = 10,
  }
  state.phase = "auction"
end

function M.minimum(state)
  local auction = assert(state.pending and state.pending.kind == "auction" and state.pending, "no auction")
  if auction.high_bid == 0 then return 1 end
  return auction.high_bid + auction.minimum_step
end

function M.bid(state, amount)
  local auction = assert(state.pending and state.pending.kind == "auction" and state.pending, "no auction")
  local bidder = auction.current_bidder
  assert(eligible(state, auction, bidder), "bidder is not eligible")
  amount = math.floor(tonumber(amount) or 0)
  assert(amount >= M.minimum(state), "bid is too low")
  assert(state.players[bidder].cash >= amount, "bid exceeds cash")
  auction.high_bid, auction.high_bidder = amount, bidder
  local next_index = next_bidder(state, auction, bidder)
  if not next_index then return finish(state, auction) else auction.current_bidder = next_index end
end

function M.pass(state)
  local auction = assert(state.pending and state.pending.kind == "auction" and state.pending, "no auction")
  local bidder = auction.current_bidder
  auction.passed[bidder] = true
  local next_index = next_bidder(state, auction, bidder)
  if not next_index then return finish(state, auction) else auction.current_bidder = next_index end
end

function M.label(state)
  local auction = assert(state.pending and state.pending.kind == "auction" and state.pending, "no auction")
  return Board.space(auction.index).name
end

return M
