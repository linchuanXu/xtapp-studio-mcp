local Random = require("domain.random")

local Events = {}

local function scale(value, numerator, denominator)
  return math.floor(value * numerator / denominator)
end

function Events.price_event(state, rng)
  local roll = Random.next(rng)

  if roll < 0.10 then
    local down = Random.next(rng) < 0.5
    for i, price in ipairs(state.house_prices) do
      state.house_prices[i] = down and scale(price, 95, 100) or scale(price, 110, 100)
    end
    return { kind = down and "houses_all_down" or "houses_all_up" }
  end

  if roll < 0.15 then
    local index = Random.int(rng, 1, #state.house_prices)
    local down = Random.next(rng) < 0.5
    local price = state.house_prices[index]
    state.house_prices[index] = down and scale(price, 80, 100) or scale(price, 120, 100)
    return {
      kind = down and "house_single_down" or "house_single_up",
      house_id = index,
    }
  end

  if #state.market == 0 then
    return { kind = "none" }
  end

  local index = Random.int(rng, 1, #state.market)
  local up = Random.next(rng) < 0.5
  local offer = state.market[index]
  if up then
    offer.price = math.max(1, math.floor(offer.price * 3 + 0.5))
  else
    offer.price = math.max(1, math.floor(offer.price / 2))
  end
  return {
    kind = up and "goods_up" or "goods_down",
    goods_id = offer.goods_id,
  }
end

local GOODS_TEXTS = {
  [1] = {
    up = "    新冠肺炎全球爆发， 口罩成了生活必需品， 医用口罩严重断货。",
    down = "    国内疫情逐渐平息， 人们纷纷脱下口罩， 过剩的口罩出现滞销。",
  },
  [2] = {
    up = "    最新研究表明： 鸡肉是优质蛋白的最佳来源， 饲料肉鸡供不应求。",
    down = "    H7N9禽流感病例再次出现， 全城灭杀活禽， 没人敢吃饲料肉鸡了。",
  },
  [3] = {
    up = "    百年一遇吉日将至， 扎堆结婚潮出现， 喜烟需求推动高档香烟价格上涨。",
    down = "    统计数据表明： 吸烟者中的一半将最终死于这种恶习， 而其中的一半将死于中年. 吸烟人群纷纷戒烟。",
  },
  [4] = {
    up = "    二胎政策放开， 奶粉需求大增， 进口奶粉价格一路上涨。",
    down = "    进口奶粉被检测出有毒物质， 进口奶粉价格下跌。",
  },
  [5] = {
    up = "    重度雾霾连续7天笼罩不散， 防毒面具卖脱销了！",
    down = "    雾霾治理初现成效， 蓝天白云风景如画， 防毒面具无人问津。",
  },
  [6] = {
    up = "    中国大妈掀起抢金热潮， 黄金首饰价格飙涨！",
    down = "    欧美经济持续好转， 国际金价一路下跌， 黄金首饰价格走低。",
  },
  [7] = {
    up = "    肾牌手机又出新款， 大家纷纷卖肾抢购， 新货供不应求！",
    down = "    砖家说：“ 卖肾影响性生活质量， 卖肾需谨慎。” 大家纷纷持肾观望， 肾牌手机降价销售。",
  },
  [8] = {
    up = "    汽车经销商说：“工厂产能不足， 提车必须加价！”",
    down = "    各地陆续推出购车摇号政策， 机动车销量下滑。",
  },
}

local HOUSE_TEXTS = {
  [1] = {
    down = "    城市居民收入不断提高， 单身公寓难以满足年轻人需求， 单身公寓价格下跌20%。",
    up = "    房价太高年轻人更青睐小面积住宅， 单身公寓价格上涨20%。",
  },
  [2] = {
    down = "    二手房交易手续费大幅提高， 二手房交易市场冷清， 二手旧房价格下跌20%。",
    up = "    国家出台二手房交易契税补贴政策， 二手房交易火爆， 二手旧房价格上涨20%。",
  },
  [3] = {
    down = "    开发商资金链断裂， 市场频现烂尾楼， 高档小区价格下跌20%。",
    up = "    刚需推动中小户型房产大卖， 高档小区价格上涨20%。",
  },
  [4] = {
    down = "    大面积住宅将被征收更高的房产税， 跃层大房价格下跌20%。",
    up = "    大面积住宅不额外征收房产税， 跃层大房价格上涨20%。",
  },
  [5] = {
    down = "    排屋属于豪宅范畴， 将被征收豪宅税， 四联排屋价格下跌20%。",
    up = "    对排屋征收豪宅税的政策暂缓执行， 四联排屋价格上涨20%。",
  },
  [6] = {
    down = "    经济进入下行通道， 高级白领面临失业危机， 豪华住宅销售遇冷， 一线江景豪宅价格下跌20%。",
    up = "    最大互联网企业上市造就大批新富， 豪华住宅销售火爆， 一线江景豪宅价格上涨20%。",
  },
  [7] = {
    down = "    民间借贷危机快速蔓延， 不断出现企业老板跑路传闻， 内环高端大宅价格下跌20%。",
    up = "    国家经济转型成功， 大批高科技企业如雨后春笋崛起， 内环高端大宅价格上涨20%。",
  },
  [8] = {
    down = "    富人移民热潮不断， 单体泳池别墅价格下跌20%。",
    up = "    巨额热钱涌入国内， 高端房产成抢手资产， 单体泳池别墅价格上涨20%。",
  },
  [9] = {
    down = "    个人购买小岛产权政策不明朗， 热带小岛别墅价格下跌20%。",
    up = "    国家出台政策个人可购买岛屿永久归属权， 热带小岛别墅价格上涨20%。",
  },
  [10] = {
    down = "    权威科技杂志公布最新科研成果， 地球在一千年内不会毁灭， 火星移民基地价格下跌20%。",
    up = "    科学家分析最近10年地壳活动数据得出结论， 地球将在一百年内毁灭， 火星移民基地价格上涨20%。",
  },
}

local LIFE_TEXTS = {
  emergency_aid = "    我身无分文流落街头， 走投无路之际， 一个好心人看我可怜， 给了我3000块！",
  street_singer = "    我喜欢大街上卖唱小伙的歌， 忍不住掏了些钱给他。 现金减少5%！",
  minor_illness = "    飞涨的房价让我揪心。 健康减1！",
  petty_theft = "    双十一来临没管住手， 现金减少10%！",
  traffic_accident = "    为了多卖一点货， 赶路太急遭遇车祸。 健康减少3！",
  food_poisoning = "    商场打折我去抢购， 人太多挤得我喘不过气来。 健康减少2！",
  overwork = "    走路玩手机没看路， 掉路边沟里了， 摔得我头破血流。 健康减少2！",
  major_theft = "    不小心落入传销陷阱， 幸好我找机会逃了出来， 现金减少15%！",
  bank_fee = "    银行： 小额账户要收管理费！ 存款减少1%！",
  fraud = "    开发商倒闭， 我的集资款全打了水漂。 现金减少20%！",
  poor_diet = "    为了攒钱每天只能吃咸菜馒头。 健康减1！",
  insomnia = "    我走在人行道上， 天上掉下一个花盆把我砸晕了。 健康减少1！",
  small_windfall = "    我突然想起两年前随手花500买的比特币， 今天一看居然涨了100倍。 现金增加5万！",
  large_windfall = "    买彩票中了10万块！ 发啦！",
  bank_loss = "    遭遇金融危机， 百年银行倒闭！ 存款减少50%！",
  deposit_bonus = "    我用闲钱买了余额宝，  存款增加5%！",
  unexpected_expense = "    正骑着车呢， 一位大妈突然往我身上摔了过来。 现金减少10%！",
  found_money = "    我因为经常扶老奶奶过马路， 赢得了社区好青年称号， 现金增加1万！",
  hijack_reward = "    坐飞机遇到歹徒劫机， 我果断出手制止， 公司奖励我见义勇为， 现金增加100万！",
}

function Events.price_text(event)
  if not event then return nil end
  if event.kind == "houses_all_down" then
    return "    小道消息疯传：“房产税即将出台！”购房者纷纷持币观望， 房价下跌5%。"
  end
  if event.kind == "houses_all_up" then
    return "    专家说：“中国房地产市场在2100年以前不会出现泡沫！ 房价将持续上涨， 房价上涨10%。”"
  end
  if event.kind == "house_single_up" or event.kind == "house_single_down" then
    local house = HOUSE_TEXTS[event.house_id]
    return house and house[event.kind == "house_single_up" and "up" or "down"] or nil
  end
  if event.kind == "goods_up" or event.kind == "goods_down" then
    local goods = GOODS_TEXTS[event.goods_id]
    return goods and goods[event.kind == "goods_up" and "up" or "down"] or nil
  end
  return nil
end

function Events.life_text(id)
  return LIFE_TEXTS[id]
end

function Events.death_text()
  return "    一个漆黑寒冷的夜晚， 我再次晕倒在街头。 长期的咸菜馒头和揪心的房价摧毁了我的健康， 让我再也没能醒过来。。。"
end

function Events.blackout_text(aid)
  if not aid or aid.kind == "unaffordable" then
    return "    我由于劳累过度晕倒在街头， 没有一个人敢来扶我。 健康减少1！"
  end
  return "    我由于劳累过度晕倒在街头， 好心人送我去了医院， 花掉急救费" .. tostring(aid.cost) .. "元！"
end

local LIFE_EVENTS = {
  { last = 13, id = "street_singer", target = "cash", numerator = 95, denominator = 100 },
  { last = 27, id = "minor_illness", target = "health", delta = -1 },
  { last = 41, id = "petty_theft", target = "cash", numerator = 90, denominator = 100 },
  { last = 55, id = "traffic_accident", target = "health", delta = -3 },
  { last = 69, id = "food_poisoning", target = "health", delta = -2 },
  { last = 83, id = "overwork", target = "health", delta = -2 },
  { last = 97, id = "major_theft", target = "cash", numerator = 85, denominator = 100 },
  { last = 111, id = "bank_fee", target = "deposit", numerator = 99, denominator = 100 },
  { last = 125, id = "fraud", target = "cash", numerator = 80, denominator = 100 },
  { last = 139, id = "poor_diet", target = "health", delta = -1 },
  { last = 153, id = "insomnia", target = "health", delta = -1 },
  { last = 158, id = "small_windfall", target = "cash", delta = 50000 },
  { last = 163, id = "large_windfall", target = "cash", delta = 100000 },
  { last = 168, id = "bank_loss", target = "deposit", numerator = 50, denominator = 100 },
  { last = 182, id = "deposit_bonus", target = "deposit", numerator = 105, denominator = 100 },
  { last = 196, id = "unexpected_expense", target = "cash", numerator = 90, denominator = 100 },
  { last = 201, id = "found_money", target = "cash", delta = 10000 },
  { last = 202, id = "hijack_reward", target = "cash", delta = 1000000 },
}

function Events.life_event(state, rng)
  if #state.inventory == 0 and state.cash + state.deposit < 500 then
    state.cash = state.cash + 3000
    return { id = "emergency_aid" }
  end

  local point = math.floor(Random.next(rng) * 1000)
  for _, event in ipairs(LIFE_EVENTS) do
    if point <= event.last then
      if event.numerator ~= nil then
        state[event.target] = scale(state[event.target], event.numerator, event.denominator)
      else
        state[event.target] = state[event.target] + event.delta
      end
      return { id = event.id }
    end
  end

  return { id = "none" }
end

function Events.sickness(state, rng)
  local point = math.floor(Random.next(rng) * 100)
  local health = state.health

  if health < 95 and point < 95 - health then
    return "dead"
  end
  if point < 100 - health then
    return "blackout"
  end
  return "none"
end

function Events.apply_blackout_aid(state)
  local missing_health = 100 - state.health
  local full_cost = missing_health * 10000

  if state.cash >= full_cost then
    state.cash = state.cash - full_cost
    state.health = 100
    return { ok = true, kind = "full", recovered = missing_health, cost = full_cost }
  end

  local recovered = math.floor(state.cash / 10000)
  if recovered > 0 then
    local cost = recovered * 10000
    state.cash = state.cash - cost
    state.health = state.health + recovered
    return { ok = true, kind = "partial", recovered = recovered, cost = cost }
  end

  state.health = state.health - 1
  return { ok = false, kind = "unaffordable", recovered = -1, cost = 0 }
end

return Events
