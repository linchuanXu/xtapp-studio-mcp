-- Transactional action engine.
--
-- Game plugins provide setup/validate/reduce/actions. Every accepted action is
-- executed against a clone and committed only after invariant checks pass, so
-- a bad rule cannot leave a half-mutated saved match.

local State = require("core.card_state")
local Projection = require("core.card_projection")

local M = {}

local function context_for(draft, events)
  local context = {}

  function context.emit(kind, payload)
    events[#events + 1] = { kind = kind, payload = State.clone(payload or {}) }
  end

  function context.create_card(definition_id, owner, data)
    return State.create_card(draft, definition_id, owner, data)
  end

  function context.insert(zone_id, card_id, position)
    return State.insert(draft, zone_id, card_id, position)
  end

  function context.move(card_id, zone_id, position)
    local id, source, destination = State.move(draft, card_id, zone_id, position)
    if id then context.emit("card_moved", { card_id = id, source = source, destination = destination }) end
    return id
  end

  function context.draw(source, destination, count)
    local cards = State.draw(draft, source, destination, count)
    if #cards > 0 then context.emit("cards_drawn", { source = source, destination = destination, count = #cards }) end
    return cards
  end

  function context.shuffle(zone_id)
    State.shuffle(draft, zone_id)
    context.emit("zone_shuffled", { zone_id = zone_id })
  end

  function context.zone(zone_id) return State.zone(draft, zone_id) end
  function context.card(card_id) return State.card(draft, card_id) end
  function context.location(card_id) return State.location(draft, card_id) end

  return context
end

function M.bind(rules)
  assert(type(rules) == "table", "card_engine.bind: rules required")
  for _, method in ipairs({ "spec", "setup", "validate", "reduce", "actions" }) do
    assert(type(rules[method]) == "function", "card_engine.bind: rules." .. method .. " required")
  end

  local engine = {}

  function engine.new_match(options)
    options = options or {}
    local state = State.new(rules.spec(options))
    local events = {}
    local ok, err = pcall(rules.setup, state, context_for(state, events), options)
    if not ok then error("card game setup failed: " .. tostring(err), 0) end
    State.assert_valid(state)
    return state, { ok = true, events = events }
  end

  function engine.actions(state, actor)
    State.assert_valid(state)
    -- Enumeration is observational. Give the plugin a clone so a buggy helper
    -- cannot mutate the authoritative match while merely building a menu.
    local ok, actions = pcall(rules.actions, State.clone(state), actor)
    if not ok then error("card game action enumeration failed: " .. tostring(actions), 0) end
    actions = actions or {}
    return State.clone(actions)
  end

  function engine.apply(state, action)
    if type(action) ~= "table" then return state, { ok = false, reason = "invalid_action" } end
    State.assert_valid(state)
    -- Validation is also isolated. Only reduce() may propose a new state.
    local checked, valid, reason = pcall(rules.validate, State.clone(state), State.clone(action))
    if not checked then return state, { ok = false, reason = "validation_error", detail = tostring(valid) } end
    if valid ~= true then return state, { ok = false, reason = reason or "rejected" } end

    local draft = State.clone(state)
    local events = {}
    local ok, result = pcall(rules.reduce, draft, State.clone(action), context_for(draft, events))
    if not ok then return state, { ok = false, reason = "rule_error", detail = tostring(result) } end
    draft.revision = (state.revision or 0) + 1
    local valid_state, state_error = pcall(State.assert_valid, draft)
    if not valid_state then
      return state, { ok = false, reason = "invariant_error", detail = tostring(state_error) }
    end
    return draft, { ok = true, events = events, result = State.clone(result or {}) }
  end

  function engine.view(state, viewer)
    State.assert_valid(state)
    local describe = type(rules.describe_card) == "function" and rules.describe_card or nil
    local view = Projection.build(state, viewer, describe)
    if type(rules.project) == "function" then rules.project(State.clone(state), view, viewer) end
    view.actions = engine.actions(state, viewer)
    return view
  end

  engine.rules = rules
  return engine
end

return M
