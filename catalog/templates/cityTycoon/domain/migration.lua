local M = {}

function M.ensure(state)
  if not state then return nil end
  local previous_schema = tonumber(state.schema) or 1

  local function as_int(v)
    local n = tonumber(v)
    if n == nil then return nil end
    return math.floor(n)
  end

  local function rekey_int_map(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
      local nk = as_int(k)
      if nk ~= nil then out[nk] = v else out[k] = v end
    end
    return out
  end

  local function coerce_int_list(src)
    if type(src) ~= "table" then return src end
    local tmp, maxn = {}, 0
    for k, v in pairs(src) do
      local nk = as_int(k)
      if nk ~= nil and nk >= 1 then
        tmp[nk] = as_int(v) or v
        if nk > maxn then maxn = nk end
      end
    end
    local out = {}
    for i = 1, maxn do out[i] = tmp[i] end
    return out
  end

  if type(state.players) == "table" then
    local players = {}
    for k, player in pairs(state.players) do
      local i = as_int(k)
      if i ~= nil and type(player) == "table" then
        player.position = as_int(player.position) or player.position or 1
        player.token = as_int(player.token) or player.token or i
        player.cash = as_int(player.cash) or player.cash or 0
        player.detained = as_int(player.detained) or 0
        player.pass_cards = as_int(player.pass_cards) or 0
        player.bankrupt = player.bankrupt == true
        player.id = player.id or ("p" .. tostring(i))
        player.name = player.name or (tostring(i) .. "号玩家")
        players[i] = player
      end
    end
    state.players = players
  end

  if type(state.assets) == "table" then
    state.assets = rekey_int_map(state.assets)
  end

  state.current = as_int(state.current) or state.current
  state.round = as_int(state.round) or state.round
  state.doubles = as_int(state.doubles) or state.doubles
  state.round_limit = as_int(state.round_limit) or state.round_limit
  state.fund = as_int(state.fund) or state.fund or 0

  if type(state.setup) == "table" then
    state.setup.players = as_int(state.setup.players) or state.setup.players
    state.setup.rounds = as_int(state.setup.rounds) or state.setup.rounds
    state.setup.names = rekey_int_map(state.setup.names or {})
    state.setup.tokens = coerce_int_list(state.setup.tokens) or { 1, 2, 3, 4, 5, 6, 7, 8 }
  end

  if type(state.pending) == "table" then
    local p = state.pending
    p.index = as_int(p.index) or p.index
    p.from = as_int(p.from) or p.from
    p.to = as_int(p.to) or p.to
    p.current_bidder = as_int(p.current_bidder) or p.current_bidder
    p.winner = as_int(p.winner) or p.winner
    p.creditor = as_int(p.creditor) or p.creditor
    p.payer = as_int(p.payer) or p.payer
    p.owner = as_int(p.owner) or p.owner
    p.cash_from = as_int(p.cash_from) or p.cash_from
    p.cash_to = as_int(p.cash_to) or p.cash_to
    p.cards_from = as_int(p.cards_from) or p.cards_from
    p.cards_to = as_int(p.cards_to) or p.cards_to
    p.high_bid = as_int(p.high_bid) or p.high_bid
    p.amount = as_int(p.amount) or p.amount
    if p.path then p.path = coerce_int_list(p.path) end
    if p.assets_from then p.assets_from = coerce_int_list(p.assets_from) end
    if p.assets_to then p.assets_to = coerce_int_list(p.assets_to) end
  end

  local function pending_ok(kind, key)
    return state.pending and state.pending.kind == kind and (key == nil or state.pending[key] ~= nil)
  end
  if state.phase == "moving" and not pending_ok("move", "path") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "property_offer" and not pending_ok("offer", "index") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "auction" and not pending_ok("auction", "index") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "trade" and not pending_ok("trade") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "event" and not pending_ok("event") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "event_result" and not pending_ok("event_result") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "rent_result" and not pending_ok("rent") then
    state.phase = "optional_actions"; state.pending = nil
  elseif state.phase == "debt_resolution" and not pending_ok("debt") then
    state.phase = "optional_actions"; state.pending = nil
  end

  state.ui = state.ui or {}
  state.schema = math.max(3, previous_schema)

  if previous_schema < 2 and state.mode == "quick" then
    for _, player in ipairs(state.players or {}) do
      player.bankrupt = false
      player.cash = math.max(0, player.cash or 0)
      player.pass_cards = 0
    end
    for _, asset in pairs(state.assets or {}) do
      asset.mortgaged = false
      asset.level = math.min(2, asset.level or 0)
    end
    if state.phase == "auction" or state.phase == "trade" or state.phase == "debt_resolution" then
      state.phase = "optional_actions"
      state.pending = nil
      state.ui.overlay = nil
      state.ui.trade_step = nil
    end
  end
  return state
end

return M
