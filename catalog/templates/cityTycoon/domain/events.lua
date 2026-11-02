local Random = require("domain.random")

local M = {}

M.cards = {
  city = {
    { id = "festival", text = "赶上城市庙会，获得120。", effect = "cash", amount = 120 },
    { id = "repair", text = "参与古建修缮，支付80。", effect = "cash", amount = -80 },
    { id = "neighbors", text = "参加邻里茶会，每位玩家支付你20。", effect = "collect_each", amount = 20 },
    { id = "donation", text = "参加公益义卖，向每位玩家支付15。", effect = "pay_each", amount = 15 },
    { id = "pass", text = "获得一张交通通行证。", effect = "pass_card" },
    { id = "start", text = "返回华夏启程并领取收入。", effect = "move", position = 1, collect_start = true },
    { id = "park", text = "前往人民公园休整。", effect = "move", position = 21 },
    { id = "inspection", text = "遇到临时管制，前往交通管制站。", effect = "checkpoint" },
  },
  plan = {
    { id = "grant", text = "获得文旅建设补贴150。", effect = "cash", amount = 150 },
    { id = "permit", text = "办理古建施工许可，支付60。", effect = "cash", amount = -60 },
    { id = "maintenance", text = "按建筑数量支付文保维护费。", effect = "repairs", amount = 35 },
    { id = "transit", text = "乘高铁前往北京站。", effect = "move", position = 6 },
    { id = "harbor", text = "前往广州塔。", effect = "move", position = 17 },
    { id = "dividend", text = "文旅项目分红，获得100。", effect = "cash", amount = 100 },
    { id = "survey", text = "完成古迹测绘，获得70。", effect = "cash", amount = 70 },
    { id = "inspection_pass", text = "获得一张交通通行证。", effect = "pass_card" },
  },
}

function M.setup(seed)
  local decks = {}
  for name, definitions in pairs(M.cards) do
    local ids = {}; for index = 1, #definitions do ids[index] = index end
    seed, ids = Random.shuffle(seed, ids)
    decks[name] = { order = ids, cursor = 1 }
  end
  return seed, decks
end

function M.draw(state, name)
  local deck = assert(state.decks[name], "unknown event deck")
  local card_index = deck.order[deck.cursor]
  deck.cursor = deck.cursor % #deck.order + 1
  return M.cards[name][card_index]
end

function M.for_mode(card, mode)
  if mode ~= "quick" or card.effect ~= "pass_card" then return card end
  return { id = card.id .. "_easy", text = "获得交通补贴80。", effect = "cash", amount = 80 }
end

return M
