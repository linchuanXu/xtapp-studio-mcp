local M = {}

M.action_icons = {
  open_assets = "action_assets",
  start_trade = "action_trade",
  end_turn = "action_end",
  open_help = "action_rules",
  buy = "action_buy",
  auction = "action_auction",
  asset_build = "action_build",
  asset_prev = "action_prev",
  asset_next = "action_next",
  open_game_menu = "action_menu",
}

function M.space_icon(index)
  return "space_icon_" .. string.format("%02d", tonumber(index) or index)
end

function M.token(player_index, size)
  local prefix = size == "mini" and "token_mini_" or size == "large" and "token_large_" or size == "hero" and "token_hero_" or "token_"
  return prefix .. tostring(player_index)
end

function M.player_marker(player_index)
  return "token_mini_" .. tostring(player_index)
end

function M.owner_marker(player_index)
  return "owner_badge_" .. tostring(player_index)
end

function M.landmark_art(index)
  return "landmark_" .. string.format("%02d", index)
end

local EVENT_ART_KEYS = {
  city = { neighbors = "event_city_neighbor_art", inspection = "event_city_check_art" },
  plan = { maintenance = "event_plan_maint_art", inspection_pass = "event_plan_pass_art" },
}

function M.event_art(deck, card)
  if card and card.id then
    local id = string.gsub(card.id, "_easy$", "")
    return (EVENT_ART_KEYS[deck] and EVENT_ART_KEYS[deck][id]) or ("event_" .. deck .. "_" .. id .. "_art")
  end
  return deck == "plan" and "event_plan_art" or "event_city_art"
end

M.special_art = {
  checkpoint = "special_checkpoint",
  debt = "special_debt",
}

function M.building_badge(level)
  return "building_badge_" .. tostring(level)
end

return M
