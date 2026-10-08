-- 情绪记录器 - 简约情绪日记
-- X4 Pro 480x800 竖屏

local MOODS = {
  { label = "开心", image_normal = "happy_188", image_edit = "happy_128" },
  { label = "平静", image_normal = "calm_188",  image_edit = "calm_128" },
  { label = "难过", image_normal = "sad_188",   image_edit = "sad_128" },
  { label = "焦虑", image_normal = "worry_188", image_edit = "worry_128" },
  { label = "生气", image_normal = "mad_188",   image_edit = "mad_128" },
  { label = "无奈", image_normal = "emmm_188",  image_edit = "emmm_128" },
}

-- 每种周心情对应20条寄语。使用周起始日期稳定抽取，
-- 同一周不会因为墨水屏重绘而反复变化。
local WEEK_MESSAGES = {
  [1] = {
    "这一周的好心情，是你认真生活的回音。",
    "恭喜你收获了明亮的一周，继续保持热爱。",
    "笑意常在，说明你正在把日子过成喜欢的样子。",
    "这周的快乐值得收藏，也值得带到下一周。",
    "愿你记住这些轻盈时刻，继续自在前行。",
    "你的好状态正在发光，也在温暖身边的人。",
    "快乐不是偶然，是你照顾好自己的成果。",
    "这一周很有光，愿下周依旧有期待。",
    "为这份好心情鼓掌，你做得很不错。",
    "愿本周的笑容，成为下周的能量。",
    "生活正在回应你的热情，请继续向前。",
    "这一周甜度刚好，愿好运继续陪着你。",
    "你把平凡日子过出了亮色，值得庆祝。",
    "快乐占了上风，记得感谢努力的自己。",
    "愿这份轻松被好好保存，随时为你充电。",
    "这一周的你闪闪发亮，请继续相信生活。",
    "好心情正在累积，未来也会更加明朗。",
    "愿你带着这一周的喜悦，轻快走进明天。",
    "你拥有发现快乐的能力，这是一份珍贵天赋。",
    "本周幸福感满格，愿你一直被温柔以待。",
  },
  [2] = {
    "这一周安稳从容，平静本身就是力量。",
    "你找到了自己的节奏，请继续慢慢走。",
    "平静不是平淡，而是内心有了确定。",
    "这一周波澜不惊，也是很好的生活。",
    "愿你守住这份安宁，不被喧闹轻易打扰。",
    "稳定的心，会带你走向更远的地方。",
    "这一周的从容，是你送给自己的礼物。",
    "不慌不忙地生活，也是一种了不起的能力。",
    "愿心中有静气，脚下有方向。",
    "你正在温柔地接住生活，做得很好。",
    "保持呼吸和节奏，一切都会慢慢清晰。",
    "这一周很安静，也藏着扎实的成长。",
    "愿你在平常日子里，继续感受细小幸福。",
    "内心安定时，世界也会变得柔和。",
    "你不必追赶，按自己的速度前进就好。",
    "这份平和很珍贵，请好好珍惜。",
    "愿下周依旧从容，忙时有序，闲时安心。",
    "稳定不是停下，而是在积蓄力量。",
    "你已经找到了平衡，继续照顾好自己。",
    "本周状态平稳，愿每一步都踏实安心。",
  },
  [3] = {
    "难过可以被允许，你不必马上振作。",
    "这一周辛苦了，先抱抱认真撑过来的自己。",
    "眼泪不是软弱，是情绪在帮你释放重量。",
    "不开心的日子也会过去，请给自己一点时间。",
    "今天先好好休息，明天再慢慢向前。",
    "你可以难过，但不要忘记自己值得被爱。",
    "低落只是暂时停靠，不是旅程的终点。",
    "请把要求放低一点，你已经很努力了。",
    "愿你被理解，也愿你温柔理解自己。",
    "有些路很难走，但你并不是一个人。",
    "这一周不容易，允许自己慢一点。",
    "把心事放下来一会儿，先照顾好身体。",
    "阴天不会一直持续，光会重新出现。",
    "你不需要证明坚强，真实地感受就很好。",
    "愿下周多一点轻松，少一点独自承受。",
    "难过时先停一停，世界不会因此责怪你。",
    "请相信，情绪会流动，疼痛也会变轻。",
    "你已经走过这一周，这本身就很勇敢。",
    "给自己一顿好饭和一次好眠，再慢慢出发。",
    "愿所有没说出口的委屈，都被温柔接住。",
  },
  [4] = {
    "焦虑是在提醒你休息，不是在否定你。",
    "先处理眼前的一小步，不必一次想完所有事。",
    "把呼吸放慢，事情会一点点变得清楚。",
    "你担心的许多事情，并不会真的发生。",
    "先回到此刻，今天只完成今天的任务。",
    "允许计划有变化，你依然能够应对。",
    "这一周绷得有些紧，请给自己松一松。",
    "不确定并不可怕，你可以边走边调整。",
    "把问题写下来，会比放在心里轻一些。",
    "你不必时刻正确，也不必时刻准备充分。",
    "慢一点呼吸，慢一点决定，心会安定下来。",
    "焦虑不是命令，你可以选择暂时不回应它。",
    "先吃饭、喝水、睡觉，再处理复杂的问题。",
    "把注意力带回身体，你此刻是安全的。",
    "不要预支明天的压力，今天已经足够。",
    "你拥有解决问题的能力，只需一步一步来。",
    "给大脑一点留白，答案可能随后出现。",
    "这一周辛苦了，下周请为自己留些余地。",
    "不用和时间赛跑，稳定前进同样有效。",
    "愿你放下过度担心，把心带回当下。",
  },
  [5] = {
    "生活不需要那么多高气压，让自己安定一下吧。",
    "怒火升起时先停一停，别让情绪替你决定。",
    "你可以生气，也可以选择更温和地表达。",
    "先离开冲突几分钟，给心一点降温时间。",
    "深呼吸，把声音放轻，力量不会因此减少。",
    "愤怒背后常有委屈，请先听听自己的需要。",
    "别急着回应，平静之后的话会更有分量。",
    "这一周火气有些重，请把休息排进日程。",
    "让身体先放松，心里的结才更容易打开。",
    "生气不是错误，但不必让它伤害自己。",
    "把拳头松开，把肩膀放下，慢慢呼吸。",
    "有些事情不值得消耗你整天的好心情。",
    "先照顾情绪，再处理问题，顺序很重要。",
    "真正的力量，是能让自己重新平静。",
    "给自己十分钟安静，再决定下一步。",
    "愿你把锋利收好，也把委屈说清楚。",
    "不是所有争执都需要立刻分出输赢。",
    "把怒气写下来，比把它压在心里更轻松。",
    "这一周辛苦了，愿下周多些柔和与理解。",
    "请为自己降降压，平静会带回清醒。",
  },
  [6] = {
    "无奈的时候先歇一歇，不必强求立刻改变。",
    "有些事无法控制，但你仍能照顾好自己。",
    "接受暂时无解，也是一种成熟的勇敢。",
    "这一周已经尽力，别再苛责自己。",
    "做得到的先做好，做不到的暂时放下。",
    "你不需要扛住一切，可以向别人求助。",
    "当下的无力不会永久停留，请给变化时间。",
    "先把自己从疲惫里接回来，再想办法。",
    "不是你的错，也不是所有事都需要你负责。",
    "允许事情暂时停在这里，生活仍会向前。",
    "你已经做了能做的部分，这就足够了。",
    "面对无法改变的事，保护自己同样重要。",
    "愿你放下一些负担，给心腾出空间。",
    "无奈并不代表失败，只是需要换个方向。",
    "这一周不容易，请对自己更宽容一点。",
    "别把所有答案都逼在今天出现。",
    "有时顺其自然，也是在认真生活。",
    "你可以暂时不知道怎么办，先好好休息。",
    "愿下周出现新的出口，也出现帮助你的人。",
    "慢慢来，困住你的事情终会有所松动。",
  },
}

-- 轻量拼音词库（情绪日记常用，控制内存）
local PINYIN_DICT = {
  a = { "啊", "阿" },
  ai = { "爱", "唉", "哀" },
  an = { "安", "按" },
  ba = { "把", "吧", "爸" },
  bai = { "白", "百" },
  bang = { "帮", "棒" },
  bei = { "被", "北", "悲" },
  ben = { "本" },
  bi = { "比", "必" },
  bie = { "别" },
  bu = { "不", "步" },
  cai = { "才", "彩" },
  can = { "惨" },
  chao = { "超" },
  chi = { "吃", "迟" },
  chong = { "冲" },
  chu = { "出", "处" },
  da = { "大", "打" },
  dai = { "带", "呆" },
  dan = { "但", "单" },
  dang = { "当" },
  dao = { "到", "倒" },
  de = { "的", "得", "地" },
  dei = { "得" },
  deng = { "等" },
  di = { "低", "地", "弟" },
  dian = { "点", "电" },
  dong = { "东", "懂", "动" },
  dou = { "都", "斗" },
  dui = { "对", "队" },
  duo = { "多" },
  e = { "饿", "恶" },
  en = { "嗯" },
  er = { "而", "儿", "二" },
  fa = { "发" },
  fan = { "烦", "饭", "反" },
  fang = { "放", "方" },
  fei = { "非", "飞" },
  fen = { "分", "奋" },
  feng = { "风", "疯" },
  fu = { "服", "复" },
  gan = { "感", "干", "敢" },
  gang = { "刚" },
  gao = { "高", "搞" },
  ge = { "个", "哥", "各" },
  gei = { "给" },
  gen = { "跟", "根" },
  geng = { "更" },
  gong = { "工", "公" },
  gou = { "够", "狗" },
  gu = { "顾", "古" },
  guo = { "过", "国" },
  hai = { "还", "海", "害" },
  hao = { "好", "号" },
  he = { "和", "何", "喝" },
  hen = { "很", "恨" },
  hou = { "后", "候" },
  hu = { "呼", "糊" },
  hua = { "话", "花", "画" },
  huai = { "坏" },
  huan = { "欢", "换" },
  huang = { "慌", "黄" },
  hui = { "会", "回", "灰" },
  hun = { "混", "昏" },
  huo = { "活", "或", "火" },
  ji = { "及", "己", "急", "鸡" },
  jia = { "家", "加", "假" },
  jian = { "见", "间", "简" },
  jiao = { "觉", "叫", "交" },
  jie = { "借", "姐", "解" },
  jin = { "进", "近", "今", "紧" },
  jing = { "静", "经", "精", "惊" },
  jiu = { "就", "久", "九" },
  ju = { "就", "惧", "局" },
  jue = { "觉", "决" },
  kai = { "开", "凯" },
  kan = { "看" },
  kao = { "靠", "考" },
  ke = { "可", "课", "渴" },
  ken = { "肯" },
  kong = { "空", "恐" },
  ku = { "哭", "苦" },
  kuai = { "快", "块" },
  kun = { "困" },
  lai = { "来" },
  lao = { "老", "劳" },
  le = { "了", "乐" },
  lei = { "累", "泪", "类" },
  leng = { "冷" },
  li = { "里", "力", "理", "离" },
  lian = { "连", "脸" },
  liang = { "两", "亮" },
  liao = { "了", "聊" },
  ling = { "另", "零" },
  liu = { "六", "留", "流" },
  long = { "龙", "笼" },
  lu = { "路", "录" },
  luan = { "乱" },
  lue = { "略" },
  lun = { "论" },
  luo = { "落", "罗" },
  lv = { "绿", "旅" },
  ma = { "吗", "妈", "麻" },
  mai = { "买", "卖" },
  man = { "满", "慢", "漫" },
  mang = { "忙", "茫" },
  mao = { "毛", "冒" },
  mei = { "没", "美", "每" },
  men = { "们", "门" },
  meng = { "梦", "猛" },
  mi = { "迷", "米" },
  mian = { "面", "免" },
  miao = { "妙", "描" },
  ming = { "明", "名", "命" },
  mo = { "莫", "摸" },
  mu = { "目", "木" },
  na = { "那", "拿", "哪" },
  nai = { "乃", "耐" },
  nan = { "难", "男", "南" },
  nao = { "脑", "闹" },
  ne = { "呢" },
  nei = { "内", "那" },
  neng = { "能" },
  ni = { "你", "尼" },
  nian = { "年", "念" },
  niang = { "娘" },
  niao = { "鸟" },
  nin = { "您" },
  ning = { "宁" },
  niu = { "牛" },
  nong = { "弄", "浓" },
  nu = { "怒", "努" },
  nuan = { "暖" },
  nuo = { "诺" },
  nv = { "女" },
  ou = { "偶", "欧" },
  pa = { "怕", "爬" },
  pai = { "排", "拍" },
  pan = { "盼", "盘" },
  pang = { "旁", "胖" },
  pao = { "跑", "泡" },
  pei = { "陪", "配" },
  peng = { "朋", "碰" },
  pi = { "皮", "疲" },
  pian = { "偏", "片" },
  piao = { "漂", "票" },
  pin = { "拼", "品" },
  ping = { "平", "评" },
  po = { "破", "迫" },
  pu = { "普", "铺" },
  qi = { "起", "气", "奇", "七" },
  qia = { "恰" },
  qian = { "前", "钱", "千" },
  qiang = { "强", "墙" },
  qiao = { "桥", "巧" },
  qie = { "且", "切" },
  qin = { "亲", "勤" },
  qing = { "请", "情", "清", "轻" },
  qiong = { "穷" },
  qiu = { "求", "球", "秋" },
  qu = { "去", "取", "区" },
  quan = { "全", "权" },
  que = { "却", "确" },
  qun = { "群" },
  ran = { "然", "燃" },
  rang = { "让" },
  rao = { "绕" },
  re = { "热", "惹" },
  ren = { "人", "认", "忍" },
  reng = { "仍" },
  ri = { "日" },
  rong = { "容", "荣" },
  rou = { "肉", "柔" },
  ru = { "如", "入" },
  ruan = { "软" },
  rui = { "瑞" },
  run = { "润" },
  ruo = { "若", "弱" },
  sa = { "撒" },
  sai = { "赛" },
  san = { "三", "散" },
  sang = { "丧" },
  sao = { "扫" },
  se = { "色", "涩" },
  sen = { "森" },
  sha = { "啥", "沙", "杀" },
  shan = { "山", "善" },
  shang = { "上", "伤", "商" },
  shao = { "少", "烧" },
  she = { "社", "设" },
  shen = { "什", "身", "深", "神" },
  sheng = { "生", "声", "省" },
  shi = { "是", "时", "事", "十", "使", "实" },
  shou = { "手", "受", "收" },
  shu = { "书", "树", "数" },
  shua = { "刷" },
  shuai = { "帅", "摔" },
  shuang = { "双", "爽" },
  shui = { "谁", "水", "睡" },
  shun = { "顺" },
  shuo = { "说" },
  si = { "思", "四", "死", "似" },
  song = { "送", "松" },
  sou = { "搜" },
  su = { "诉", "速", "苏" },
  sui = { "虽", "随", "岁" },
  sun = { "孙", "损" },
  suo = { "所", "锁" },
  ta = { "他", "她", "它", "塔" },
  tai = { "太", "态" },
  tan = { "谈", "弹", "叹" },
  tang = { "烫", "躺", "糖" },
  tao = { "套", "逃", "讨" },
  te = { "特" },
  teng = { "疼", "腾" },
  ti = { "提", "体", "题" },
  tian = { "天", "田", "甜" },
  tiao = { "条", "跳", "调" },
  tie = { "贴", "铁" },
  ting = { "听", "停", "挺" },
  tong = { "同", "通", "痛" },
  tou = { "头", "偷", "透" },
  tu = { "图", "土", "突" },
  tuan = { "团" },
  tui = { "退", "推" },
  tun = { "吞" },
  tuo = { "托", "拖" },
  wa = { "哇", "挖" },
  wai = { "外", "歪" },
  wan = { "完", "玩", "晚", "万" },
  wang = { "往", "望", "王", "忘" },
  wei = { "为", "位", "未", "微", "喂" },
  wen = { "问", "文", "稳", "闻" },
  wo = { "我", "握" },
  wu = { "无", "五", "物", "误" },
  xi = { "喜", "西", "希", "息", "洗" },
  xia = { "下", "夏", "吓" },
  xian = { "先", "现", "闲", "线" },
  xiang = { "想", "向", "像", "相", "香" },
  xiao = { "小", "笑", "消", "晓" },
  xie = { "些", "写", "谢", "斜" },
  xin = { "心", "新", "信", "欣" },
  xing = { "行", "兴", "星", "性", "醒" },
  xiong = { "兄", "胸", "凶" },
  xiu = { "休", "修", "秀" },
  xu = { "需", "许", "续" },
  xuan = { "选", "宣" },
  xue = { "学", "雪", "血" },
  xun = { "寻", "训" },
  ya = { "呀", "压", "牙" },
  yan = { "眼", "言", "严", "演" },
  yang = { "样", "阳", "养", "扬" },
  yao = { "要", "药", "耀", "腰" },
  ye = { "也", "页", "夜", "业" },
  yi = { "一", "以", "已", "意", "易", "亿" },
  yin = { "因", "引", "音", "银" },
  ying = { "应", "影", "硬", "英" },
  yo = { "哟" },
  yong = { "用", "永", "勇" },
  you = { "有", "又", "友", "右", "由" },
  yu = { "与", "于", "雨", "语", "遇" },
  yuan = { "员", "原", "远", "愿", "园" },
  yue = { "月", "乐", "越", "约" },
  yun = { "云", "运" },
  za = { "杂", "砸" },
  zai = { "在", "再", "载" },
  zan = { "咱", "赞" },
  zang = { "脏" },
  zao = { "早", "造", "糟" },
  ze = { "则", "责" },
  zei = { "贼" },
  zen = { "怎" },
  zeng = { "增" },
  zha = { "炸", "扎" },
  zhai = { "摘", "窄" },
  zhan = { "站", "占", "战" },
  zhang = { "长", "张", "丈" },
  zhao = { "找", "着", "照" },
  zhe = { "这", "着", "者" },
  zhen = { "真", "针", "震" },
  zheng = { "正", "整", "争" },
  zhi = { "之", "只", "知", "直", "纸", "指" },
  zhong = { "中", "种", "重", "终" },
  zhou = { "周", "州", "昼" },
  zhu = { "住", "主", "注", "助" },
  zhua = { "抓" },
  zhuai = { "拽" },
  zhuan = { "转", "专" },
  zhuang = { "装", "状", "壮" },
  zhui = { "追" },
  zhun = { "准" },
  zhuo = { "桌", "着" },
  zi = { "字", "自", "子", "紫" },
  zong = { "总", "宗" },
  zou = { "走" },
  zu = { "组", "足", "族" },
  zuan = { "钻" },
  zui = { "最", "嘴", "罪" },
  zun = { "尊" },
  zuo = { "做", "作", "坐", "左" },
  -- 常用短语
  kaixin = { "开心" },
  nanguo = { "难过" },
  jiaolv = { "焦虑" },
  shengqi = { "生气" },
  wunai = { "无奈" },
  pingjing = { "平静" },
  haole = { "好了" },
  bushufu = { "不舒服" },
  henlei = { "很累" },
  henhao = { "很好" },
  xiangjia = { "想家" },
  gudan = { "孤单" },
  jinzhang = { "紧张" },
  fangsong = { "放松" },
  shuijiao = { "睡觉" },
  gongzuo = { "工作" },
  pengyou = { "朋友" },
  jintian = { "今天" },
  zuotian = { "昨天" },
  mingtian = { "明天" },
  xianzai = { "现在" },
  yidian = { "一点" },
  yidianr = { "一点儿" },
  weishenme = { "为什么" },
  zenme = { "怎么" },
  shenme = { "什么" },
  keyi = { "可以" },
  buhao = { "不好" },
  henbang = { "很棒" },
  xinqing = { "心情" },
  ganjue = { "感觉" },
}

-- 扩展常用字词、心情短语和连续拼音句子。
-- 与基础词库分开维护，后续增加词语时只需改这里。
local PINYIN_EXTRA = {
  ai = { "哎", "矮", "碍" },
  an = { "俺", "岸", "暗", "案" },
  ao = { "熬", "奥", "傲" },
  bo = { "波", "播", "伯" },
  chen = { "沉", "陈", "晨" },
  chou = { "愁", "丑" },
  cuo = { "错" },
  dan = { "担", "淡" },
  fan = { "凡" },
  gan = { "赶", "甘" },
  ji = { "记", "纪", "挤" },
  jiao = { "焦", "教", "较" },
  jue = { "绝" },
  lei = { "雷" },
  lou = { "楼", "漏" },
  men = { "闷" },
  qing = { "晴" },
  shi = { "失", "试", "室", "世" },
  suan = { "酸", "算" },
  xiang = { "享" },
  xie = { "歇" },
  xing = { "幸" },
  yan = { "验" },

  gaoxing = { "高兴" },
  kuaile = { "快乐" },
  xingfu = { "幸福" },
  manzu = { "满足" },
  qidai = { "期待" },
  xingfen = { "兴奋" },
  gandong = { "感动" },
  anxin = { "安心" },
  qingsong = { "轻松" },
  bucuo = { "不错" },
  shangxin = { "伤心" },
  shiluo = { "失落" },
  weiqu = { "委屈" },
  gudu = { "孤独" },
  jimo = { "寂寞" },
  fanzao = { "烦躁" },
  yali = { "压力" },
  pilao = { "疲劳" },
  pibei = { "疲惫" },
  kunjuan = { "困倦" },
  haipa = { "害怕" },
  danxin = { "担心" },
  bengkui = { "崩溃" },
  mimang = { "迷茫" },
  yumen = { "郁闷" },

  xuexi = { "学习" },
  shangban = { "上班" },
  xiaban = { "下班" },
  jiaban = { "加班" },
  kaoshi = { "考试" },
  kaihui = { "开会" },
  xiuxi = { "休息" },
  shimian = { "失眠" },
  chifan = { "吃饭" },
  yundong = { "运动" },
  sanbu = { "散步" },
  tianqi = { "天气" },
  jiaren = { "家人" },
  tongshi = { "同事" },
  lingdao = { "领导" },
  haizi = { "孩子" },
  shenti = { "身体" },
  zaoshang = { "早上" },
  zhongwu = { "中午" },
  xiawu = { "下午" },
  wanshang = { "晚上" },
  zhongyu = { "终于" },
  jiejue = { "解决" },
  shunli = { "顺利" },
  shibai = { "失败" },
  chenggong = { "成功" },
  bangzhu = { "帮助" },
  liaotian = { "聊天" },
  youyidian = { "有一点" },
  youxie = { "有些" },
  butai = { "不太" },
  xiwang = { "希望" },
  xuyao = { "需要" },
  xiangyao = { "想要" },
  juede = { "觉得" },
  meiguanxi = { "没关系" },
  xiexie = { "谢谢" },
  juhao = { "。" },
  douhao = { "，" },
  gantanhao = { "！" },
  wenhao = { "？" },

  jintianhenkaixin = { "今天很开心" },
  jintianyouyidianlei = { "今天有一点累" },
  jintianxinqingbucuo = { "今天心情不错" },
  jintianxinqingbuhao = { "今天心情不好" },
  wohenkaixin = { "我很开心" },
  woyoudiannanguo = { "我有点难过" },
  ganjuehenfangsong = { "感觉很放松" },
  ganjuehenjiaolv = { "感觉很焦虑" },
  gongzuoyalihenda = { "工作压力很大" },
  xuexiyoudianlei = { "学习有点累" },
  shuidehenhao = { "睡得很好" },
  meishuhao = { "没睡好" },
  xiangxiuxiyixia = { "想休息一下" },
  xiangyigerenjingjing = { "想一个人静静" },
  shiqingzhongyujiejuele = { "事情终于解决了" },
  xiwangmingtianhuigenghao = { "希望明天会更好" },
  jintianfashenglehenduo = { "今天发生了很多事" },
  hepengyouliaotian = { "和朋友聊天" },
  shentibutaishufu = { "身体不太舒服" },
  tianqihenhao = { "天气很好" },
  jintianjiabanle = { "今天加班了" },
}

-- 高频命名字扩展。基础表负责覆盖音节，这里增加每个常用音节的候选深度。
local PINYIN_RICH = {
  bai = { "白", "百", "败", "摆", "柏", "拜" },
  ban = { "班", "半", "版", "办", "板", "伴", "般" },
  bang = { "帮", "棒", "榜", "邦", "绑", "磅" },
  bian = { "边", "变", "便", "遍", "编", "辨", "扁" },
  bo = { "波", "博", "播", "伯", "薄", "勃", "玻" },
  bu = { "不", "部", "步", "布", "补", "簿", "捕" },
  cai = { "才", "采", "彩", "菜", "财", "材", "裁" },
  cha = { "查", "差", "茶", "插", "察", "叉", "岔" },
  chi = { "吃", "持", "迟", "赤", "池", "尺", "齿" },
  chong = { "充", "冲", "重", "虫", "宠", "崇" },
  chun = { "春", "纯", "唇", "淳", "醇" },
  dao = { "到", "道", "导", "岛", "倒", "刀", "稻" },
  deng = { "等", "灯", "登", "邓", "瞪", "凳" },
  di = { "第", "地", "低", "底", "的", "弟", "帝", "递" },
  ding = { "定", "订", "顶", "丁", "盯", "钉" },
  dong = { "动", "东", "懂", "冬", "洞", "栋" },
  duo = { "多", "朵", "夺", "躲", "度", "堕" },
  fan = { "反", "饭", "翻", "范", "凡", "烦", "返" },
  fei = { "非", "飞", "费", "废", "肥", "菲", "沸" },
  feng = { "风", "封", "峰", "丰", "疯", "锋", "凤" },
  gan = { "感", "干", "敢", "赶", "甘", "杆", "肝" },
  gang = { "刚", "港", "钢", "岗", "缸", "纲" },
  gu = { "古", "故", "顾", "固", "股", "鼓", "谷" },
  guang = { "光", "广", "逛", "犷" },
  gui = { "归", "贵", "规", "鬼", "桂", "柜", "轨" },
  guo = { "国", "过", "果", "锅", "郭", "裹" },
  hai = { "还", "海", "害", "孩", "嗨", "骇" },
  hao = { "好", "号", "浩", "豪", "毫", "耗", "皓" },
  he = { "和", "合", "何", "河", "喝", "核", "贺", "荷" },
  hong = { "红", "宏", "洪", "虹", "鸿", "哄" },
  hou = { "后", "候", "厚", "侯", "吼", "喉" },
  jiang = { "将", "讲", "江", "奖", "降", "姜", "疆" },
  jing = { "经", "京", "静", "精", "景", "竟", "境", "警" },
  jiu = { "就", "九", "久", "旧", "酒", "救", "究" },
  ju = { "句", "具", "局", "举", "居", "据", "聚", "巨" },
  kai = { "开", "凯", "慨", "楷", "恺" },
  kan = { "看", "刊", "堪", "砍", "坎" },
  kao = { "考", "靠", "烤", "拷" },
  ke = { "可", "科", "课", "客", "刻", "克", "颗" },
  kong = { "空", "控", "孔", "恐" },
  kuai = { "快", "块", "筷", "会", "脍" },
  lai = { "来", "赖", "莱", "睐" },
  lan = { "蓝", "兰", "览", "懒", "栏", "篮" },
  lao = { "老", "劳", "牢", "姥", "捞" },
  lian = { "连", "脸", "练", "联", "恋", "莲", "廉" },
  lin = { "林", "临", "邻", "琳", "淋", "麟" },
  ling = { "零", "领", "令", "灵", "另", "铃", "龄" },
  long = { "龙", "隆", "笼", "聋" },
  lun = { "论", "轮", "伦", "仑" },
  luo = { "落", "罗", "洛", "络", "逻", "裸" },
  mei = { "没", "每", "美", "妹", "梅", "眉", "媒" },
  meng = { "梦", "蒙", "猛", "盟", "孟", "萌" },
  nian = { "年", "念", "粘", "碾" },
  qian = { "前", "千", "钱", "签", "浅", "欠", "迁" },
  qiang = { "强", "枪", "墙", "抢", "腔" },
  qiao = { "桥", "巧", "敲", "乔", "俏", "翘" },
  qing = { "情", "请", "清", "轻", "青", "庆", "晴" },
  quan = { "全", "权", "圈", "劝", "泉", "拳", "犬" },
  ren = { "人", "认", "任", "仁", "忍", "刃" },
  rong = { "容", "荣", "融", "绒", "蓉" },
  ru = { "如", "入", "乳", "儒", "辱" },
  shao = { "少", "烧", "绍", "稍", "哨" },
  shen = { "身", "深", "神", "什", "审", "申", "甚" },
  shou = { "手", "受", "收", "首", "守", "授", "寿" },
  shui = { "水", "谁", "睡", "税" },
  shuo = { "说", "硕", "朔", "烁" },
  tai = { "太", "台", "态", "抬", "泰", "胎" },
  tao = { "套", "逃", "桃", "讨", "陶", "涛" },
  tong = { "同", "通", "童", "痛", "统", "铜", "桶" },
  wan = { "万", "完", "晚", "玩", "弯", "碗", "湾" },
  wang = { "望", "王", "往", "网", "忘", "旺" },
  wei = { "为", "位", "未", "味", "微", "围", "伟", "卫" },
  wu = { "无", "五", "物", "务", "午", "舞", "屋", "武" },
  xian = { "先", "现", "线", "显", "县", "限", "鲜", "闲" },
  xiang = { "想", "向", "相", "像", "象", "香", "乡", "响" },
  xiao = { "小", "笑", "校", "消", "晓", "效", "销", "肖" },
  xin = { "心", "新", "信", "欣", "辛", "薪" },
  xing = { "行", "性", "形", "星", "兴", "醒", "姓" },
  yang = { "样", "阳", "养", "羊", "洋", "杨", "仰" },
  yao = { "要", "药", "摇", "咬", "腰", "邀", "耀" },
  yin = { "因", "音", "引", "印", "银", "阴", "饮" },
  ying = { "应", "英", "影", "营", "迎", "硬", "赢", "映" },
  you = { "有", "又", "由", "友", "右", "游", "优", "油" },
  yu = { "与", "于", "语", "雨", "育", "余", "鱼", "预" },
  yue = { "月", "越", "阅", "约", "乐", "岳" },
  yun = { "云", "运", "允", "韵", "孕", "匀" },
  zhan = { "站", "展", "战", "占", "沾", "斩" },
  zhang = { "长", "张", "章", "掌", "涨", "账", "丈" },
  zhao = { "找", "照", "招", "赵", "朝", "兆" },
  zhen = { "真", "镇", "阵", "针", "振", "珍", "震" },
  zheng = { "正", "整", "证", "争", "政", "征", "郑" },
  zhou = { "周", "州", "洲", "轴", "舟", "皱" },
  zhu = { "主", "住", "助", "注", "祝", "竹", "逐", "朱" },
  zhuan = { "转", "专", "传", "赚", "砖" },
  zhuang = { "装", "状", "庄", "壮", "撞" },
}

-- 合并扩展词库并去重，保留前面的常用候选优先级。
for key, words in pairs(PINYIN_EXTRA) do
  local target = PINYIN_DICT[key]
  if not target then
    target = {}
    PINYIN_DICT[key] = target
  end

  for i = 1, #words do
    local word = words[i]
    local exists = false
    for j = 1, #target do
      if target[j] == word then
        exists = true
        break
      end
    end
    if not exists then
      target[#target + 1] = word
    end
  end
end

-- 合并高频命名字扩展并去重，保留前面的常用候选优先级。
for key, words in pairs(PINYIN_RICH) do
  local target = PINYIN_DICT[key]
  if not target then
    target = {}
    PINYIN_DICT[key] = target
  end

  for i = 1, #words do
    local word = words[i]
    local exists = false
    for j = 1, #target do
      if target[j] == word then
        exists = true
        break
      end
    end
    if not exists then
      target[#target + 1] = word
    end
  end
end


-- 选词后的上下文联想。选中后仍可直接点下一条候选继续上屏。
local WORD_ASSOCIATIONS = {
  ["我"] = { "很开心", "有点难过", "感觉很累", "想休息一下" },
  ["今天"] = { "很开心", "有点累", "心情不错", "发生了很多事" },
  ["感觉"] = { "很好", "很放松", "有点累", "有点焦虑" },
  ["心情"] = { "很好", "不错", "不太好", "有些低落" },
  ["有点"] = { "开心", "难过", "焦虑", "生气", "疲惫" },
  ["很"] = { "开心", "平静", "难过", "焦虑", "疲惫" },
  ["想"] = { "休息一下", "一个人静静", "和朋友聊天", "早点睡觉" },
  ["希望"] = { "明天会更好", "事情顺利", "自己放松一点" },
  ["工作"] = { "很顺利", "压力很大", "有点忙", "终于完成了" },
  ["学习"] = { "很顺利", "有点累", "很有收获", "需要继续努力" },
  ["睡觉"] = { "睡得很好", "没睡好", "有点失眠" },
  ["朋友"] = { "陪我聊天", "让我很开心", "给了我帮助" },
  ["家人"] = { "很关心我", "让我很安心", "陪在我身边" },
  ["天气"] = { "很好", "有点热", "有点冷", "让我很舒服" },
  ["开心"] = { "因为事情很顺利", "想把快乐记录下来", "。" },
  ["平静"] = { "感觉很放松", "想慢慢休息", "。" },
  ["难过"] = { "想一个人静静", "希望明天会更好", "。" },
  ["焦虑"] = { "需要放松一下", "想出去走走", "。" },
  ["生气"] = { "需要冷静一下", "想让自己平静", "。" },
  ["无奈"] = { "但我会慢慢调整", "希望事情有转机", "。" },
}

-- 固定候选补全顺序，避免 pairs() 导致每次显示顺序不同。
local PINYIN_SORTED_KEYS = {}
for key in pairs(PINYIN_DICT) do
  PINYIN_SORTED_KEYS[#PINYIN_SORTED_KEYS + 1] = key
end
table.sort(PINYIN_SORTED_KEYS, function(a, b)
  if #a == #b then return a < b end
  return #a < #b
end)

local CANDIDATES_PER_PAGE = 4

local KEYBOARD_ROWS = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
  { "zh", "z", "x", "c", "v", "b", "n", "m", "back" },
  { "cancel", "space", "done", "mode" },
}

-- 布局常量
local LAYOUT = {
  title_y = 18,
  date_y = 720,
  mood_y = 340,
  textbox_y = 400,
  textbox_y_edit = 280,
  textbox_h = 44,
  cand_y = 330,
  cand_h = 40,
  kb_top = 380,
  kb_row_h = 52,
  kb_row_gap = 6,
  kb_key_w = 42,
  kb_key_gap = 3,
  img_y = 191,
  img_y_edit = 160, --编辑模式图片中心
  image_size = 188,
  image_size_edit = 162,
}

-- 将 Unix epoch 的“天数”转换为真实公历日期。
-- 不使用被沙箱禁用的 os/io/package。
local function civil_from_days(days)
  local z = days + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor(
    (doe
      - math.floor(doe / 1460)
      + math.floor(doe / 36524)
      - math.floor(doe / 146096)) / 365
  )
  local year = yoe + era * 400
  local doy = doe
    - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local day = doy - math.floor((153 * mp + 2) / 5) + 1
  local month

  if mp < 10 then
    month = mp + 3
  else
    month = mp - 9
  end

  if month <= 2 then
    year = year + 1
  end

  return year, month, day
end

local function pad2(value)
  if value < 10 then
    return "0" .. tostring(value)
  end
  return tostring(value)
end

-- 仅当固件取时失败时使用的兜底值：2026-07-31。
local TODAY_DAY = 20665

-- 将公历日期转换为“天数”（civil_from_days 的逆运算），供跳转定位日期。
local function days_from_civil(year, month, day)
  local y = year
  local m = month
  if m <= 2 then
    y = y - 1
    m = m + 12
  end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = m - 3
  local doy = math.floor((153 * mp + 2) / 5) + day - 1
  local doe = yoe * 365
    + math.floor(yoe / 4)
    - math.floor(yoe / 100)
    + doy
  return era * 146097 + doe - 719468
end

local function sync_today(ctx)
  local ok, clock = pcall(function()
    return ctx.sys:clock()
  end)
  if not ok or type(clock) ~= "table" or clock.valid ~= true then return end
  if clock.year == nil or clock.month == nil or clock.day == nil then return end
  TODAY_DAY = days_from_civil(clock.year, clock.month, clock.day)
end

local function date_to_offset(ms, date_str)
  local year, month, day =
    string.match(date_str, "^(%d+)%-(%d+)%-(%d+)$")
  year = tonumber(year)
  month = tonumber(month)
  day = tonumber(day)
  if not year or not month or not day then return nil end
  return days_from_civil(year, month, day) - TODAY_DAY
end

local function date_from_offset(offset_days)
  local year, month, day = civil_from_days(TODAY_DAY + offset_days)
  return tostring(year) .. "-" .. pad2(month) .. "-" .. pad2(day)
end

local function mood_state(ctx)
  sync_today(ctx)

  if not ctx.state.moodlog then
    ctx.state.moodlog = {
      entries = {},
      current_offset = 0,
      editing = false,
      edit_buffer = "",
      shift = false,
      ime_cn = true,       -- 中文拼音模式
      pinyin = "",         -- 正在输入的拼音
      candidates = {},     -- 候选字
      cand_page = 1,
      edit_view = "input", -- input / year / radar
      stats_year = nil,
    }
    local cd = date_from_offset(0)
    ctx.state.moodlog.entries[cd] = {
      mood = 2,
      reason = "",
      recorded = false
    }
  end
  local ms = ctx.state.moodlog
  if not ms.edit_view then ms.edit_view = "input" end
  return ms
end

local function current_date(ms)
  return date_from_offset(ms.current_offset)
end

local function current_entry(ms)
  local cd = current_date(ms)
  if not ms.entries[cd] then
    ms.entries[cd] = {
      mood = 2,
      reason = "",
      recorded = false
    }
  end
  return ms.entries[cd]
end

local function utf8_len(s)
  local n = 0
  local i = 1
  while i <= #s do
    local c = string.byte(s, i)
    if c < 128 then i = i + 1
    elseif c < 224 then i = i + 2
    elseif c < 240 then i = i + 3
    else i = i + 4 end
    n = n + 1
  end
  return n
end

local function utf8_sub(s, start_char, end_char)
  local i = 1
  local char_i = 1
  local start_byte, end_byte
  while i <= #s do
    if char_i == start_char then start_byte = i end
    local c = string.byte(s, i)
    local step = 1
    if c >= 240 then step = 4
    elseif c >= 224 then step = 3
    elseif c >= 192 then step = 2 end
    if char_i == end_char then
      end_byte = i + step - 1
      break
    end
    i = i + step
    char_i = char_i + 1
  end
  if not start_byte then return "" end
  return string.sub(s, start_byte, end_byte or #s)
end

local function utf8_chop_last(s)
  if s == "" then return "" end
  local i = 1
  local last = 1
  while i <= #s do
    last = i
    local c = string.byte(s, i)
    if c < 128 then i = i + 1
    elseif c < 224 then i = i + 2
    elseif c < 240 then i = i + 3
    else i = i + 4 end
  end
  return string.sub(s, 1, last - 1)
end

-- 候选栏最多预览 4 个汉字；长句点击后仍会上屏完整内容。
local function candidate_preview(text)
  local i = 1
  local count = 0
  local last = 0

  while i <= #text and count < 4 do
    local c = string.byte(text, i)
    if c < 128 then i = i + 1
    elseif c < 224 then i = i + 2
    elseif c < 240 then i = i + 3
    else i = i + 4 end
    count = count + 1
    last = i - 1
  end

  local preview = string.sub(text, 1, last)
  if i <= #text then preview = preview .. "…" end
  return preview
end

local function add_candidate(list, word, limit)
  if not word or word == "" then return false end

  for i = 1, #list do
    if list[i] == word then return false end
  end

  if #list >= limit then return false end
  list[#list + 1] = word
  return true
end

-- 把没有整词命中的连续拼音自动拆成已知字词。
-- 例如：wojintianhenkaixin → 我今天很开心。
local function segment_pinyin_sentence(text)
  if not text or #text < 4 then return nil end

  local memo = {}

  local function solve(pos)
    if pos > #text then
      return { value = "", parts = 0, score = 0 }
    end

    if memo[pos] ~= nil then return memo[pos] end

    local best = nil
    for i = #PINYIN_SORTED_KEYS, 1, -1 do
      local key = PINYIN_SORTED_KEYS[i]
      local key_end = pos + #key - 1

      if key_end <= #text
        and string.sub(text, pos, key_end) == key then
        local rest = solve(key_end + 1)
        local first = PINYIN_DICT[key]
          and PINYIN_DICT[key][1]

        if rest and first then
          local candidate = {
            value = first .. rest.value,
            parts = rest.parts + 1,
            score = rest.score + #key * #key,
          }

          if not best
            or candidate.parts < best.parts
            or (
              candidate.parts == best.parts
              and candidate.score > best.score
            ) then
            best = candidate
          end
        end
      end
    end

    memo[pos] = best or false
    return memo[pos]
  end

  local result = solve(1)
  return result and result.value or nil
end

local function refresh_candidates(ms)
  ms.candidates = {}
  ms.cand_page = 1
  if ms.pinyin == "" then return end

  local limit = 30
  local exact = PINYIN_DICT[ms.pinyin]

  -- 1. 完整拼音精确命中，始终排在最前面。
  if exact then
    for i = 1, #exact do
      add_candidate(ms.candidates, exact[i], limit)
    end
  end

  -- 2. 连续拼音自动拆词，支持不加空格输入一句话。
  local sentence = segment_pinyin_sentence(ms.pinyin)
  add_candidate(ms.candidates, sentence, limit)

  -- 3. 按稳定顺序补充以当前拼音开头的字词。
  for i = 1, #PINYIN_SORTED_KEYS do
    local key = PINYIN_SORTED_KEYS[i]
    if key ~= ms.pinyin
      and string.sub(key, 1, #ms.pinyin) == ms.pinyin then
      local words = PINYIN_DICT[key]
      for j = 1, #words do
        add_candidate(ms.candidates, words[j], limit)
        if #ms.candidates >= limit then break end
      end
    end
    if #ms.candidates >= limit then break end
  end
end

local function commit_candidate(ms, idx)
  local page = ms.cand_page or 1
  local real = (page - 1) * CANDIDATES_PER_PAGE + idx
  local word = ms.candidates[real]
  if not word then return false end
  ms.edit_buffer = ms.edit_buffer .. word
  ms.pinyin = ""
  ms.candidates = {}
  ms.cand_page = 1

  -- 上屏后提供与该词相关的下一段表达。
  local related = WORD_ASSOCIATIONS[word]
  if related then
    for i = 1, #related do
      add_candidate(ms.candidates, related[i], 30)
    end
  end

  return true
end

local function exit_editing(ms, save)
  if save then
    local entry = current_entry(ms)
    entry.reason = ms.edit_buffer
    entry.recorded = true
  end
  ms.editing = false
  ms.pinyin = ""
  ms.candidates = {}
  ms.cand_page = 1
  ms.shift = false
  ms.edit_view = "input"
end

local function kb_layout()
  return {
    sw = 480,
    top = LAYOUT.kb_top,
    row_h = LAYOUT.kb_row_h,
    row_gap = LAYOUT.kb_row_gap,
    key_w = LAYOUT.kb_key_w,
    key_gap = LAYOUT.kb_key_gap,
  }
end

local function key_rect(row_idx, col_idx)
  local kl = kb_layout()
  local row = KEYBOARD_ROWS[row_idx]
  local n_keys = #row
  local total_w, start_x, x, w

  if row_idx == 4 then
    -- cancel(70) space(180) done(90) mode(70)
    local widths = { 70, 180, 90, 70 }
    local gap = 8
    total_w = 70 + 180 + 90 + 70 + gap * 3
    start_x = math.floor((kl.sw - total_w) / 2)
    x = start_x
    for i = 1, col_idx - 1 do
      x = x + widths[i] + gap
    end
    w = widths[col_idx]
  else
    total_w = kl.key_w * n_keys + kl.key_gap * (n_keys - 1)
    if row_idx == 3 then
      total_w = total_w + 20 -- zh / back 稍宽
    end
    start_x = math.floor((kl.sw - total_w) / 2)
    x = start_x + (col_idx - 1) * (kl.key_w + kl.key_gap)
    w = kl.key_w
    if row_idx == 3 then
      if col_idx == 1 then w = 52; x = start_x end
      if col_idx == 9 then w = 52 end
      if col_idx > 1 then
        x = start_x + 52 + kl.key_gap + (col_idx - 2) * (kl.key_w + kl.key_gap)
      end
    end
  end

  local y = kl.top + (row_idx - 1) * (kl.row_h + kl.row_gap)
  return x, y, w, kl.row_h
end

local function hit_keyboard(px, py)
  for ri = 1, #KEYBOARD_ROWS do
    for ci = 1, #KEYBOARD_ROWS[ri] do
      local kx, ky, kw, kh = key_rect(ri, ci)
      if px >= kx and px <= kx + kw and py >= ky and py <= ky + kh then
        return KEYBOARD_ROWS[ri][ci]
      end
    end
  end
  return nil
end

local function hit_candidates(px, py, ms)
  if not ms.editing or #ms.candidates == 0 then return nil end
  local y = LAYOUT.cand_y
  local h = LAYOUT.cand_h
  if py < y or py > y + h then return nil end

  -- 4 个加宽候选 + 右侧翻页区，短语不容易重叠。
  local cell_w = 88
  local start_x = 20
  for i = 1, CANDIDATES_PER_PAGE do
    local x = start_x + (i - 1) * cell_w
    if px >= x and px < x + cell_w then
      return i
    end
  end

  if px >= 380 and px <= 440 then
    return "next"
  end

  return nil
end

local function hit_mood(px, py)
  local sw = 480
  local mood_y = LAYOUT.mood_y
  local mood_h = 52
  if py < mood_y or py > mood_y + mood_h then return nil end
  local n = #MOODS
  local area_w = sw
  local cell_w = math.floor(area_w / n)
  local start_x = 0
  local idx = math.floor((px - start_x) / cell_w) + 1
  if idx > n and px <= sw then idx = n end
  if idx >= 1 and idx <= n then return idx end
  return nil
end

local function hit_textbox(px, py, editing)
  local sw = 480
  local tb_x = 40
  local tb_w = sw - 80
  local tb_y = editing and LAYOUT.textbox_y_edit or LAYOUT.textbox_y
  local tb_h = LAYOUT.textbox_h
  if px >= tb_x and px <= tb_x + tb_w and py >= tb_y and py <= tb_y + tb_h then
    return true
  end
  return false
end

local function hit_date_arrow(px, py)
  local sw = 480
  local arrow_y = LAYOUT.date_y
  local arrow_h = 44
  if py < arrow_y or py > arrow_y + arrow_h then return nil end
  if px >= 0 and px <= 80 then return "left" end
  if px >= sw - 80 and px <= sw then return "right" end
  return nil
end

local function hit_calendar_body(px, py)
  local sw = 480
  local y = LAYOUT.date_y
  local h = 80

  if py < y or py > y + h then
    return nil
  end

  -- 左右箭头区域仍交给 hit_date_arrow。
  if px >= 80 and px <= sw - 80 then
    if px < sw / 2 then
      return "left"
    end
    return "right"
  end

  return nil
end

-- ==================== 生命周期 ====================

function on_load(ctx)
  mood_state(ctx)
  ctx.log:info("mood tracker ready")
end

function on_enter(ctx)
  ctx:invalidate()
end

local hit_year_dot -- 前向声明，供 on_input 引用（定义在文件后部）

function on_input(ctx, ev)
  local ms = mood_state(ctx)

  -- 年度页和六维页属于编辑模式的两个统计子页面。
  if ms.editing and ms.edit_view ~= "input" then
    if ev.type == "key" and ev.state == "down" then
      if ms.edit_view == "year" then
        if ev.key == "left" then
          ms.stats_year = (ms.stats_year or 2026) - 1
        elseif ev.key == "right" then
          ms.stats_year = (ms.stats_year or 2026) + 1
        elseif ev.key == "down"
          or ev.key == "back"
          or ev.key == "ok" then
          ms.edit_view = "input"
        end
      elseif ms.edit_view == "radar" then
        if ev.key == "up"
          or ev.key == "back"
          or ev.key == "ok" then
          ms.edit_view = "input"
        end
      end

      ctx:invalidate()
      return true
    end

    if ev.type == "touch" then
      if ms.edit_view == "year" then
        if ev.gesture == "tap" and ev.y <= 70 then
          if ev.x <= 100 then
            ms.stats_year = (ms.stats_year or 2026) - 1
          elseif ev.x >= 380 then
            ms.stats_year = (ms.stats_year or 2026) + 1
          end
        elseif ev.gesture == "swipe_left" then
          ms.stats_year = (ms.stats_year or 2026) + 1
        elseif ev.gesture == "swipe_right" then
          ms.stats_year = (ms.stats_year or 2026) - 1
        elseif ev.gesture == "tap" and ev.y > 70 then
          local dstr = hit_year_dot(ms, ev.x, ev.y)
          if dstr then
            local off = date_to_offset(ms, dstr)
            if off then
              ms.current_offset = off
              ms.edit_view = "input"
            end
          end
        end
      end

      ctx:invalidate()
      return true
    end

    return true
  end

  if ev.type == "key" and ev.state == "down" then
    if ms.editing then
      if ev.key == "up" then
        local selected_date = current_date(ms)
        local year_text = string.match(
          selected_date,
          "^(%d%d%d%d)"
        )
        ms.stats_year = tonumber(year_text) or 2026
        ms.edit_view = "year"
        ctx:invalidate()
        return true
      elseif ev.key == "down" then
        ms.edit_view = "radar"
        ctx:invalidate()
        return true
      elseif ev.key == "back" then
        -- 实体返回键：放弃编辑并退出键盘
        exit_editing(ms, false)
        ctx:invalidate()
        return true
      elseif ev.key == "ok" then
        exit_editing(ms, true)
        ctx:invalidate()
        return true
      end
      return false
    end

    if ev.key == "left" then
      ms.current_offset = ms.current_offset - 1
      ctx:invalidate()
      return true
    elseif ev.key == "right" then
      ms.current_offset = ms.current_offset + 1
      ctx:invalidate()
      return true
    elseif ev.key == "up" then
      local entry = current_entry(ms)
      entry.mood = entry.mood > 1 and entry.mood - 1 or #MOODS
      entry.recorded = true
      ctx:invalidate()
      return true
    elseif ev.key == "down" then
      local entry = current_entry(ms)
      entry.mood = entry.mood < #MOODS and entry.mood + 1 or 1
      entry.recorded = true
      ctx:invalidate()
      return true
    elseif ev.key == "ok" then
      local entry = current_entry(ms)
      entry.recorded = true
      ms.edit_buffer = entry.reason or ""
      ms.editing = true
      ms.edit_view = "input"
      ms.shift = false
      ms.ime_cn = true
      ms.pinyin = ""
      ms.candidates = {}
      ctx:invalidate()
      return true
    end
    return false
  end

  if ev.type == "touch" and ev.gesture == "tap" then
    local tx, ty = ev.x, ev.y

    if ms.editing then
      -- 候选字
      local ci = hit_candidates(tx, ty, ms)
      if ci == "next" then
        local pages = math.max(
          1,
          math.ceil(#ms.candidates / CANDIDATES_PER_PAGE)
        )
        ms.cand_page = (ms.cand_page % pages) + 1
        ctx:invalidate()
        return true
      elseif type(ci) == "number" then
        commit_candidate(ms, ci)
        ctx:invalidate()
        return true
      end

      local key = hit_keyboard(tx, ty)
      if key then
        if key == "mode" then
          ms.ime_cn = not ms.ime_cn
          ms.pinyin = ""
          ms.candidates = {}
        elseif key == "cancel" then
          exit_editing(ms, false)
        elseif key == "done" then
          -- 有拼音未上屏时先上屏拼音原文，再保存
          if ms.pinyin ~= "" then
            ms.edit_buffer = ms.edit_buffer .. ms.pinyin
            ms.pinyin = ""
            ms.candidates = {}
          end
          exit_editing(ms, true)
        elseif key == "back" then
          if ms.pinyin ~= "" then
            ms.pinyin = string.sub(ms.pinyin, 1, #ms.pinyin - 1)
            refresh_candidates(ms)
          else
            ms.edit_buffer = utf8_chop_last(ms.edit_buffer)
            ms.candidates = {}
            ms.cand_page = 1
          end
        elseif key == "space" then
          if ms.ime_cn and ms.pinyin ~= "" and #ms.candidates > 0 then
            commit_candidate(ms, 1)
          else
            ms.edit_buffer = ms.edit_buffer .. " "
            ms.candidates = {}
            ms.cand_page = 1
          end
        elseif key == "zh" then
          if ms.ime_cn then
            ms.pinyin = ms.pinyin .. "zh"
            refresh_candidates(ms)
          else
            ms.edit_buffer = ms.edit_buffer .. "zh"
          end
        else
          -- 字母键
          if ms.ime_cn then
            ms.pinyin = ms.pinyin .. key
            refresh_candidates(ms)
          else
            if ms.shift then
              ms.edit_buffer = ms.edit_buffer .. string.upper(key)
              ms.shift = false
            else
              ms.edit_buffer = ms.edit_buffer .. key
            end
          end
        end
        ctx:invalidate()
        return true
      end
      -- 编辑态点空白不关闭，避免误触
      return true
    end

    -- 非编辑模式
    local arrow = hit_date_arrow(tx, ty)
    if arrow == "left" then
      ms.current_offset = ms.current_offset - 1
      ctx:invalidate()
      return true
    elseif arrow == "right" then
      ms.current_offset = ms.current_offset + 1
      ctx:invalidate()
      return true
    end

    local calendar_side = hit_calendar_body(tx, ty)
    if calendar_side == "left" then
      ms.current_offset = ms.current_offset - 1
      ctx:invalidate()
      return true
    elseif calendar_side == "right" then
      ms.current_offset = ms.current_offset + 1
      ctx:invalidate()
      return true
    end

    local mi = hit_mood(tx, ty)
    if mi then
      local entry = current_entry(ms)
      entry.mood = mi
      entry.recorded = true
      ctx:invalidate()
      return true
    end

    if hit_textbox(tx, ty, false) then
      local entry = current_entry(ms)
      entry.recorded = true
      ms.edit_buffer = entry.reason or ""
      ms.editing = true
      ms.edit_view = "input"
      ms.shift = false
      ms.ime_cn = true
      ms.pinyin = ""
      ms.candidates = {}
      ctx:invalidate()
      return true
    end

    return false
  end

  if ev.type == "touch" then
    if ev.gesture == "swipe_left" then
      ms.current_offset = ms.current_offset - 1
      ctx:invalidate()
      return true
    elseif ev.gesture == "swipe_right" then
      ms.current_offset = ms.current_offset + 1
      ctx:invalidate()
      return true
    elseif ev.gesture == "swipe_up" then
      local entry = current_entry(ms)
      entry.mood = entry.mood > 1 and entry.mood - 1 or #MOODS
      entry.recorded = true
      ctx:invalidate()
      return true
    elseif ev.gesture == "swipe_down" then
      local entry = current_entry(ms)
      entry.mood = entry.mood < #MOODS and entry.mood + 1 or 1
      entry.recorded = true
      ctx:invalidate()
      return true
    end
  end

  return false
end

-- ==================== 绘制 ====================

-- 简洁分区：只保留上下横线，不画左右竖线。
local function draw_section_lines(g, y, h)
  g:line(0, y, 480, y, 15)
  g:line(0, y + h, 480, y + h, 15)
end

-- 固件没有字体粗细接口，用1像素错位重绘强调标题。
local function draw_emphasis_text(g, x, y, text, color)
  local c = color or 15
  g:text(x, y, text, { color = c })
  g:text(x + 1, y, text, { color = c })
end

-- 按真机默认字体估算：中文约20px，英文、数字和符号约10px。
local function estimated_display_width(text)
  local width = 0
  local i = 1

  while i <= #text do
    local c = string.byte(text, i)
    if c < 128 then
      width = width + 10
      i = i + 1
    elseif c < 224 then
      width = width + 20
      i = i + 2
    elseif c < 240 then
      width = width + 20
      i = i + 3
    else
      width = width + 20
      i = i + 4
    end
  end

  return width
end

local function draw_centered_text(g, y, text, color)
  local x = math.floor(
    (480 - estimated_display_width(text)) / 2
  )
  g:text(x, y, text, { color = color or 15 })
end

-- 各心情预制图形（优先 g:image 加载 assets；失败则画矢量）
local function draw_mood_icon(
  g,
  mood_idx,
  cx,
  cy,
  image_size
)
  local mood = MOODS[mood_idx]
  local key = mood and (
    image_size >= 180 and mood.image_normal or mood.image_edit
  )

  local padding = 6
  local label_h = 30
  local frame_w = image_size + padding * 2
  local frame_h = image_size + padding * 2 + label_h
  local frame_x = math.floor(cx - frame_w / 2)
  local frame_y = math.floor(cy - frame_h / 2)
  local image_x = frame_x + padding
  local image_y = frame_y + padding
  -- 工作台生成的 128 图像内容在真机上约偏左 18px。
  -- 只移动编辑态图片内容，外框仍严格以屏幕中轴线为中心。
  local image_offset_x = image_size < 180 and 18 or 0
  local render_image_x = image_x + image_offset_x
  local label_y = frame_y + padding + image_size + padding

  g:rect(
    frame_x,
    frame_y,
    frame_w,
    frame_h,
    "stroke",
    15
  )

  -- 底部心情名称使用独立的细框，文字在框内居中。
  g:line(
    frame_x,
    label_y,
    frame_x + frame_w,
    label_y,
    15
  )

  if key then
    local image_ok = pcall(function()
      g:image(key, render_image_x, image_y, {
        width = image_size,
        height = image_size
      })
    end)

    if image_ok then
      if image_offset_x > 0 then
        -- 覆盖右侧溢出的部分，再把居中的内外边框画回来。
        g:rect(
          image_x + image_size,
          image_y,
          image_offset_x + padding + 2,
          image_size,
          "fill",
          0
        )
        g:rect(
          frame_x,
          frame_y,
          frame_w,
          frame_h,
          "stroke",
          15
        )
        g:line(
          frame_x,
          label_y,
          frame_x + frame_w,
          label_y,
          15
        )
      end

      g:rect(
        image_x,
        image_y,
        image_size,
        image_size,
        "stroke",
        15
      )
      g:text(
        cx - 16,
        label_y + 7,
        mood.label,
        { color = 15 }
      )
      return
    end
  end

  -- 图片加载失败时使用简单矢量表情兜底。
  g:rect(
    image_x,
    image_y,
    image_size,
    image_size,
    "stroke",
    15
  )

  local face_cy = image_y + math.floor(image_size / 2)
  local r = math.floor(image_size * 0.28)
  local eye_y = face_cy - math.floor(r * 0.25)
  local eye_dx = math.floor(r * 0.35)
  local eye_r = math.max(2, math.floor(r * 0.12))

  g:circle(cx, face_cy, r, "stroke", 15)
  g:circle(cx - eye_dx, eye_y, eye_r, "fill", 15)
  g:circle(cx + eye_dx, eye_y, eye_r, "fill", 15)
  g:line(
    cx - math.floor(r * 0.35),
    face_cy + math.floor(r * 0.35),
    cx + math.floor(r * 0.35),
    face_cy + math.floor(r * 0.35),
    15
  )
  g:text(
    cx - 16,
    label_y + 7,
    mood.label,
    { color = 15 }
  )
end

local function draw_mood_selector(g, current_mood)
  local sw = 480
  local n = #MOODS
  local area_w = sw
  local cell_w = math.floor(area_w / n)
  local start_x = 0
  local y = LAYOUT.mood_y

  -- 六个选择区共用两条横线，减少连续小方框。
  g:line(0, y, sw, y, 15)
  g:line(
    0,
    y + 52,
    sw,
    y + 52,
    15
  )

  for i = 1, n do
    local mx = start_x + (i - 1) * cell_w
    local mw = cell_w
    local mh = 52
    local selected = (i == current_mood)
    local text_w = 32
    local text_x = mx + math.floor((mw - text_w) / 2)
    local text_y = y + math.floor((mh - 20) / 2)

    if selected then
      g:rect(mx, y, mw, mh, "fill", 15)
      g:text(text_x, text_y, MOODS[i].label, { color = 0 })
    else
      g:text(text_x, text_y, MOODS[i].label, { color = 15 })
    end
  end
end

local function format_short_date(date_str)
  local year, month, day =
    string.match(date_str, "^(%d+)%-(%d+)%-(%d+)$")

  if not year then
    return date_str
  end

  return tostring(tonumber(year))
    .. "/"
    .. tostring(tonumber(month))
    .. "/"
    .. tostring(tonumber(day))
end

local function weekday_index(date_str)
  local year, month, day =
    string.match(date_str, "^(%d+)%-(%d+)%-(%d+)$")

  year = tonumber(year)
  month = tonumber(month)
  day = tonumber(day)

  if not year or not month or not day then
    return 1
  end

  local month_code = {
    0, 3, 2, 5, 0, 3,
    5, 1, 4, 6, 2, 4
  }

  if month < 3 then
    year = year - 1
  end

  local weekday = (
    year
    + math.floor(year / 4)
    - math.floor(year / 100)
    + math.floor(year / 400)
    + month_code[month]
    + day
  ) % 7

  -- 1到7依次对应：日、一、二、三、四、五、六。
  return weekday + 1
end

local function draw_date_bar(g, date_str)
  local sw = 480
  local x = 0
  local w = sw
  local y = LAYOUT.date_y

  local year, month =
    string.match(date_str, "^(%d%d%d%d)%-(%d%d)")

  year = year or "2026"
  month = month or "07"

  local selected_weekday = weekday_index(date_str)

  -- 深色年月栏。
  g:rect(x, y, w, 38, "fill", 15)
  g:text(x + 10, y + 9, "<", { color = 0 })
  g:text(x + w - 24, y + 9, ">", { color = 0 })

  local month_text = year .. " / " .. month
  g:text(
    x + math.floor((w - 80) / 2),
    y + 9,
    month_text,
    { color = 0 }
  )

  -- 星期栏，当前选中日期对应的整格使用阴影。
  local weekdays = { "日", "一", "二", "三", "四", "五", "六" }
  local cell_w = math.floor(w / 7)
  local week_y = y + 38
  local week_h = 42

  for i = 1, 7 do
    local cell_x = x + (i - 1) * cell_w
    local current_w = cell_w

    if i == 7 then
      current_w = x + w - cell_x
    end

    local text_color = 15

    if i == selected_weekday then
      g:rect(
        cell_x,
        week_y,
        current_w,
        week_h,
        "fill",
        15
      )
      text_color = 0
    end

    local text_x =
      cell_x + math.floor((current_w - 16) / 2)

    g:text(
      text_x,
      week_y + 12,
      weekdays[i],
      { color = text_color }
    )
  end

  g:line(x, week_y, x + w, week_y, 15)
  g:line(x, week_y + week_h, x + w, week_y + week_h, 15)
end

local function entry_is_recorded(entry)
  if not entry then
    return false
  end

  -- 兼容升级前没有 recorded 字段的已有记录。
  if entry.recorded == nil then
    return true
  end

  return entry.recorded == true
end

local function stable_message_index(seed, count)
  local hash = 7

  for i = 1, #seed do
    hash = (hash * 33 + string.byte(seed, i)) % 2147483647
  end

  return (hash % count) + 1
end

local function weekly_summary(ms)
  local selected_date = current_date(ms)
  local selected_weekday = weekday_index(selected_date)

  -- weekday_index：日=1、一=2……六=7。
  local days_after_monday = (selected_weekday + 5) % 7
  local monday_offset = ms.current_offset - days_after_monday
  local days = {}
  local counts = { 0, 0, 0, 0, 0, 0 }
  local total = 0

  for i = 1, 7 do
    local date_str = date_from_offset(monday_offset + i - 1)
    local entry = ms.entries[date_str]
    local recorded = entry_is_recorded(entry)
    local mood = entry and entry.mood or 2

    days[i] = {
      date = date_str,
      mood = mood,
      recorded = recorded
    }

    if recorded then
      counts[mood] = counts[mood] + 1
      total = total + 1
    end
  end

  local dominant_mood
  local dominant_count = 0

  for mood = 1, #MOODS do
    if counts[mood] > dominant_count then
      dominant_mood = mood
      dominant_count = counts[mood]
    end
  end

  return {
    days = days,
    counts = counts,
    total = total,
    dominant_mood = dominant_mood,
    dominant_count = dominant_count,
    selected_weekday = selected_weekday,
    monday_date = days[1].date
  }
end

-- 从第一次使用开始累计统计不同的记录日期，跨周、跨月不清零。
local function total_recorded_days(ms)
  local total = 0

  for _, entry in pairs(ms.entries) do
    if entry_is_recorded(entry) then
      total = total + 1
    end
  end

  return total
end

local function draw_wrapped_message(
  g,
  text,
  x,
  y,
  max_chars,
  max_lines
)
  local total_chars = utf8_len(text)
  local line = 1
  local start_char = 1

  while start_char <= total_chars and line <= max_lines do
    local end_char = math.min(
      total_chars,
      start_char + max_chars - 1
    )
    local part = utf8_sub(text, start_char, end_char)
    g:text(x, y + (line - 1) * 21, part, { color = 15 })
    start_char = end_char + 1
    line = line + 1
  end
end

local function draw_weekly_chart(g, ms)
  local summary = weekly_summary(ms)
  local x = 20
  local y = 455
  local w = 440
  local h = 240

  draw_section_lines(g, y, h)
  local chart_title = "本周心情统计"
  local total_text = tostring(summary.total) .. "/7天"
  local title_x = x + 12
  local title_center = title_x
    + estimated_display_width(chart_title) / 2
  local total_center = 480 - title_center
  local total_x = math.floor(
    total_center - estimated_display_width(total_text) / 2
  )

  draw_emphasis_text(g, title_x, y + 12, chart_title, 15)
  g:text(
    total_x,
    y + 12,
    total_text,
    { color = 15 }
  )

  local weekdays = { "一", "二", "三", "四", "五", "六", "日" }
  local mood_short = { "乐", "静", "忧", "焦", "怒", "奈" }
  local mood_level = { 5, 4, 2, 2, 1, 3 }
  local chart_left = x + 30
  local chart_right = x + w - 20
  local chart_top = y + 54
  local baseline = y + 140
  local slot_w = math.floor((chart_right - chart_left) / 7)
  local max_bar_h = 68
  local bar_w = 22

  g:line(chart_left, chart_top, chart_left, baseline, 15)
  g:line(chart_left, baseline, chart_right, baseline, 15)

  for i = 1, 7 do
    local day = summary.days[i]
    local center_x =
      chart_left + (i - 1) * slot_w + math.floor(slot_w / 2)

    if day.recorded then
      local level = mood_level[day.mood] or 3
      local bar_h = math.floor(max_bar_h * level / 5)
      local bar_y = baseline - bar_h

      g:rect(
        center_x - math.floor(bar_w / 2),
        bar_y,
        bar_w,
        bar_h,
        "fill",
        15
      )
      g:text(
        center_x - 8,
        bar_y - 20,
        mood_short[day.mood],
        { color = 15 }
      )
    else
      g:rect(
        center_x - math.floor(bar_w / 2),
        baseline - 8,
        bar_w,
        8,
        "stroke",
        15
      )
      g:text(center_x - 4, baseline - 29, "-", { color = 15 })
    end

    g:text(
      center_x - 8,
      baseline + 8,
      weekdays[i],
      { color = 15 }
    )
  end

  if summary.dominant_mood then
    local summary_text =
      "当前最多："
      .. MOODS[summary.dominant_mood].label
      .. " "
      .. tostring(summary.dominant_count)
      .. "天"

    g:text(x + 12, y + 170, summary_text, { color = 15 })
  else
    g:text(x + 12, y + 170, "本周还没有心情记录", { color = 15 })
  end

  local sunday_finished =
    summary.selected_weekday == 1
    and summary.days[7].recorded
    and summary.dominant_mood ~= nil

  if sunday_finished then
    local messages = WEEK_MESSAGES[summary.dominant_mood]
    local seed =
      summary.monday_date
      .. ":"
      .. tostring(summary.dominant_mood)
      .. ":"
      .. tostring(summary.total)
    local message_index =
      stable_message_index(seed, #messages)
    local message = messages[message_index]

    draw_wrapped_message(
      g,
      message,
      x + 12,
      y + 194,
      24,
      2
    )
  else
    g:text(
      x + 12,
      y + 194,
      "周日完成记录后，生成本周专属寄语。",
      { color = 15 }
    )
  end
end

-- 编辑模式下的全年记录热力图，放在键盘下方。
local function draw_edit_year_heatmap(g, ms)
  local y = 625
  local h = 170
  local selected_date = current_date(ms)
  local year_text = string.match(selected_date, "^(%d%d%d%d)")
  local year = tonumber(year_text) or 2026
  local all_total = total_recorded_days(ms)

  local function leap_year(value)
    return value % 400 == 0
      or (value % 4 == 0 and value % 100 ~= 0)
  end

  local month_days = {
    31, leap_year(year) and 29 or 28, 31, 30,
    31, 30, 31, 31, 30, 31, 30, 31
  }
  draw_section_lines(g, y, h)
  draw_emphasis_text(
    g,
    12,
    y + 8,
    tostring(year) .. " 年度记录热力图",
    15
  )
  g:text(
    340,
    y + 8,
    "累计记录 " .. tostring(all_total) .. " 天",
    { color = 15 }
  )
  g:line(0, y + 31, 480, y + 31, 15)

  -- 53 周横向铺满屏幕，不再预留左侧星期标签。
  local grid_x = 4
  local grid_y = y + 58
  local cell_size = 5
  local cell_step_x = 9
  local cell_step_y = 9
  local jan_first = tostring(year) .. "-01-01"
  local jan_weekday = weekday_index(jan_first)
  local start_row = (jan_weekday + 5) % 7
  local day_index = 0

  for month = 1, 12 do
    for day = 1, month_days[month] do
      local slot = start_row + day_index
      local column = math.floor(slot / 7)
      local row = slot % 7
      local date_str = tostring(year)
        .. "-" .. pad2(month)
        .. "-" .. pad2(day)
      local recorded = entry_is_recorded(ms.entries[date_str])
      local cell_x = grid_x + column * cell_step_x
      local cell_y = grid_y + row * cell_step_y

      if recorded then
        g:rect(
          cell_x,
          cell_y,
          cell_size,
          cell_size,
          "fill",
          15
        )
      else
        -- 空心小方框表示尚未打卡；方块间保留 4 像素空隙。
        g:rect(
          cell_x,
          cell_y,
          cell_size,
          cell_size,
          "stroke",
          10
        )
      end

      day_index = day_index + 1
    end
  end

  -- 十二个月等分整行显示，保证 1 月到 12 月都完整可见。
  local month_y = y + 37
  local month_cell_w = 40
  for month = 1, 12 do
    local label_w = month < 10 and 24 or 32
    local label_x = (month - 1) * month_cell_w
      + math.floor((month_cell_w - label_w) / 2)
    g:text(
      label_x,
      month_y,
      tostring(month) .. "月",
      { color = 15 }
    )
  end

  -- 图例分居屏幕左右两半，不画中间竖线。
  g:line(0, y + 132, 480, y + 132, 15)

  local legend_y = y + 148
  local legend_size = 10

  -- 左半屏：未打卡。
  g:rect(86, legend_y, legend_size, legend_size, "stroke", 10)
  g:text(106, legend_y - 3, "未打卡", { color = 15 })

  -- 右半屏：已打卡。
  g:rect(326, legend_y, legend_size, legend_size, "fill", 15)
  g:text(346, legend_y - 3, "已打卡", { color = 15 })
end

-- 新版编辑页底部只显示一句居中的提示语。
local function draw_edit_prompt(g)
  local text = "Put pen to paper to ease your mood"
  -- 真机默认英文字体平均宽度约为 10px。
  local estimated_w = #text * 10
  local x = math.floor((480 - estimated_w) / 2)
  g:text(x, 700, text, { color = 15 })
end

local function is_leap_year(year)
  return year % 400 == 0
    or (year % 4 == 0 and year % 100 ~= 0)
end

local function days_in_month(year, month)
  local days = {
    31, 28, 31, 30, 31, 30,
    31, 31, 30, 31, 30, 31
  }
  if month == 2 and is_leap_year(year) then return 29 end
  return days[month]
end


-- 定位年度打卡总览中被点中的日期点，返回 "YYYY-MM-DD"；未命中返回 nil。
-- 几何与 draw_year_record_page 完全一致。
hit_year_dot = function(ms, tx, ty)
  local year = ms.stats_year or 2026
  local start_x = 10
  local start_y = 72
  local block_w = 153
  local block_h = 166
  local dot_step_x = 18
  local dot_step_y = 17
  local hit_r = 9

  for month = 1, 12 do
    local month_index = month - 1
    local block_col = month_index % 3
    local block_row = math.floor(month_index / 3)
    local block_x = start_x + block_col * block_w
    local block_y = start_y + block_row * block_h
    local first_date = tostring(year) .. "-" .. pad2(month) .. "-01"
    local first_weekday = weekday_index(first_date) - 1
    local day_total = days_in_month(year, month)

    for day = 1, day_total do
      local slot = first_weekday + day - 1
      local dot_col = slot % 7
      local dot_row = math.floor(slot / 7)
      local dot_x = block_x + 20 + dot_col * dot_step_x
      local dot_y = block_y + 38 + dot_row * dot_step_y
      local dx = tx - dot_x
      local dy = ty - dot_y
      if dx * dx + dy * dy <= hit_r * hit_r then
        return tostring(year) .. "-" .. pad2(month) .. "-" .. pad2(day)
      end
    end
  end
  return nil
end

-- 12 个月年度打卡总览：空心表示未记录，实心表示已记录。
local function draw_year_record_page(g, ms)
  local year = ms.stats_year or 2026

  g:clear(0)
  g:rect(12, 8, 54, 42, "stroke", 15)
  g:text(34, 18, "<", { color = 15 })
  g:rect(414, 8, 54, 42, "stroke", 15)
  g:text(436, 18, ">", { color = 15 })

  local title = tostring(year) .. " 年度打卡记录"
  local title_w = 4 * 9 + 7 * 16
  draw_emphasis_text(
    g,
    math.floor((480 - title_w) / 2),
    18,
    title,
    15
  )

  g:rect(8, 58, 464, 682, "stroke", 10)

  local start_x = 10
  local start_y = 72
  local block_w = 153
  local block_h = 166
  local dot_step_x = 18
  local dot_step_y = 17
  local dot_radius = 4

  for month = 1, 12 do
    local month_index = month - 1
    local block_col = month_index % 3
    local block_row = math.floor(month_index / 3)
    local block_x = start_x + block_col * block_w
    local block_y = start_y + block_row * block_h
    local month_text = tostring(month) .. "月"
    local month_text_w = month < 10 and 32 or 40

    draw_emphasis_text(
      g,
      block_x + math.floor((block_w - month_text_w) / 2),
      block_y,
      month_text,
      15
    )

    local first_date = tostring(year)
      .. "-" .. pad2(month) .. "-01"
    local first_weekday = weekday_index(first_date) - 1
    local day_total = days_in_month(year, month)

    for day = 1, day_total do
      local slot = first_weekday + day - 1
      local dot_col = slot % 7
      local dot_row = math.floor(slot / 7)
      local dot_x = block_x + 20 + dot_col * dot_step_x
      local dot_y = block_y + 38 + dot_row * dot_step_y
      local date_str = tostring(year)
        .. "-" .. pad2(month)
        .. "-" .. pad2(day)

      if entry_is_recorded(ms.entries[date_str]) then
        g:circle(dot_x, dot_y, dot_radius, "fill", 15)
      else
        g:circle(dot_x, dot_y, dot_radius, "stroke", 10)
      end
    end
  end

  g:circle(114, 757, 5, "stroke", 10)
  g:text(128, 750, "未打卡", { color = 15 })
  g:circle(304, 757, 5, "fill", 15)
  g:text(318, 750, "已打卡", { color = 15 })
  g:text(176, 776, "按下键返回编辑", { color = 15 })
end

local function radar_point(cx, cy, radius, index)
  local angle = -math.pi / 2 + (index - 1) * math.pi / 3
  local x = math.floor(cx + math.cos(angle) * radius + 0.5)
  local y = math.floor(cy + math.sin(angle) * radius + 0.5)
  return x, y
end

local function draw_radar_hexagon(g, cx, cy, radius, color)
  local first_x, first_y = radar_point(cx, cy, radius, 1)
  local prev_x, prev_y = first_x, first_y

  for i = 2, 6 do
    local x, y = radar_point(cx, cy, radius, i)
    g:line(prev_x, prev_y, x, y, color)
    prev_x, prev_y = x, y
  end
  g:line(prev_x, prev_y, first_x, first_y, color)
end

-- 六维心情雷达图，统计全部已经打卡的日期。
local function draw_mood_radar_page(g, ms)
  local counts = { 0, 0, 0, 0, 0, 0 }
  local total = 0

  for _, entry in pairs(ms.entries) do
    if entry_is_recorded(entry)
      and entry.mood
      and entry.mood >= 1
      and entry.mood <= 6 then
      counts[entry.mood] = counts[entry.mood] + 1
      total = total + 1
    end
  end

  local axis_moods = { 1, 3, 5, 6, 4, 2 }
  local axis_labels = {
    "开心", "难过", "生气",
    "无奈", "焦虑", "平静"
  }
  local max_count = 0
  for i = 1, 6 do
    if counts[i] > max_count then max_count = counts[i] end
  end
  local scale_max = math.max(7, max_count)

  g:clear(0)
  draw_emphasis_text(g, 20, 18, "心情六维统计", 15)
  g:text(352, 18, "累计 " .. tostring(total) .. " 天", { color = 15 })
  g:line(0, 48, 480, 48, 15)

  local cx = 240
  local cy = 385
  local max_radius = 145

  for level = 1, 4 do
    draw_radar_hexagon(
      g,
      cx,
      cy,
      math.floor(max_radius * level / 4),
      level == 4 and 10 or 6
    )
  end

  for i = 1, 6 do
    local axis_x, axis_y = radar_point(cx, cy, max_radius, i)
    g:line(cx, cy, axis_x, axis_y, 8)
  end

  if total > 0 then
    local first_x, first_y = nil, nil
    local prev_x, prev_y = nil, nil

    for i = 1, 6 do
      local mood_index = axis_moods[i]
      local value_radius = math.floor(
        max_radius * counts[mood_index] / scale_max
      )
      local x, y = radar_point(cx, cy, value_radius, i)

      if not first_x then
        first_x, first_y = x, y
      else
        g:line(prev_x, prev_y, x, y, 15)
      end

      g:circle(x, y, 5, "fill", 15)
      prev_x, prev_y = x, y
    end

    g:line(prev_x, prev_y, first_x, first_y, 15)
  else
    g:text(184, cy - 8, "还没有心情记录", { color = 15 })
  end

  local label_x = { 202, 374, 374, 202, 34, 34 }
  local label_y = { 204, 268, 500, 566, 500, 268 }
  for i = 1, 6 do
    local mood_index = axis_moods[i]
    local label = axis_labels[i]
      .. " " .. tostring(counts[mood_index])
    g:text(label_x[i], label_y[i], label, { color = 15 })
  end

  g:line(40, 700, 440, 700, 10)
  draw_centered_text(
    g,
    720,
    "维度大小按累计记录次数变化",
    15
  )
  draw_centered_text(g, 760, "按上键返回编辑", 15)
end

local function draw_textbox(g, text, is_editing, edit_buf, pinyin)
  local sw = 480
  local x = 40
  local w = sw - 80
  local y = is_editing and LAYOUT.textbox_y_edit or LAYOUT.textbox_y
  local h = LAYOUT.textbox_h

  -- 输入区使用贯穿屏幕的上下横线，不画左右边框。
  draw_section_lines(g, y, h)

  local display_text
  if is_editing then
    if pinyin and pinyin ~= "" then
      display_text = edit_buf .. pinyin .. "_"
    else
      display_text = edit_buf .. "_"
    end
  elseif text and text ~= "" then
    display_text = text
  else
    display_text = "点击输入原因..."
  end

  -- 粗略截断（中文按字节，显示约 20 字宽）
  if #display_text > 36 then
    display_text = ".." .. string.sub(display_text, #display_text - 33)
  end

  g:text(20, y + 12, display_text, { color = 15 })
end

local function draw_candidates(g, ms)
  local x = 20
  local y = LAYOUT.cand_y
  local w = 400
  local h = LAYOUT.cand_h

  -- 候选区同样只保留上下横线。
  draw_section_lines(g, y, h)

  if #ms.candidates == 0 then
    g:text(
      20,
      y + 10,
      ms.ime_cn and "候选区（输入拼音后点选）" or "英文模式",
      { color = 15 }
    )
    return
  end

  local page = ms.cand_page or 1
  local start = (page - 1) * CANDIDATES_PER_PAGE + 1
  local cell_w = 88

  for i = 0, CANDIDATES_PER_PAGE - 1 do
    local idx = start + i
    local word = ms.candidates[idx]
    if word then
      local cell_x = x + i * cell_w
      g:text(
        cell_x + 6,
        y + 10,
        tostring(i + 1) .. "." .. candidate_preview(word),
        { color = 15 }
      )
    end
  end

  local pages = math.max(
    1,
    math.ceil(#ms.candidates / CANDIDATES_PER_PAGE)
  )
  g:text(
    386,
    y + 10,
    ">" .. page .. "/" .. pages,
    { color = 15 }
  )
end

local function draw_keyboard(g, ms)
  local function key_display(k)
    if k == "back" then return "<-"
    elseif k == "space" then return "空格"
    elseif k == "done" then return "完成"
    elseif k == "cancel" then return "取消"
    elseif k == "mode" then return ms.ime_cn and "中" or "英"
    elseif k == "zh" then return "zh"
    else return k end
  end

  for ri = 1, #KEYBOARD_ROWS do
    local _, row_y = key_rect(ri, 1)
    draw_section_lines(g, row_y, LAYOUT.kb_row_h)

    for ci = 1, #KEYBOARD_ROWS[ri] do
      local kx, ky, kw, kh = key_rect(ri, ci)
      local key_label = KEYBOARD_ROWS[ri][ci]
      local disp = key_display(key_label)
      local highlight = (key_label == "mode" and ms.ime_cn)

      if highlight then
        g:rect(kx, ky, kw, kh, "fill", 15)
        g:text(kx + math.floor((kw - 14) / 2), ky + math.floor((kh - 14) / 2), disp, { color = 0 })
      else
        local tw = #disp * 7
        g:text(kx + math.max(4, math.floor((kw - tw) / 2)), ky + math.floor((kh - 14) / 2), disp, { color = 15 })
      end
    end
  end
end

function on_draw(ctx, g)
  local ms = mood_state(ctx)
  local sw = ctx.screen.width
  local entry = current_entry(ms)
  local cd = current_date(ms)

  g:clear(0)

  if ms.editing and ms.edit_view == "year" then
    draw_year_record_page(g, ms)
    return
  elseif ms.editing and ms.edit_view == "radar" then
    draw_mood_radar_page(g, ms)
    return
  end

  draw_emphasis_text(g, 20, LAYOUT.title_y, "情绪记录", 15)

  -- 标题右侧显示当前选中的完整日期，例如 2026/7/31。
  local top_date = format_short_date(cd)
  -- 按稍宽字符估算，确保日期不会越过下方横线的右端。
  local top_date_w = #top_date * 9
  g:text(
    sw - 40 - top_date_w,
    LAYOUT.title_y,
    top_date,
    { color = 15 }
  )

  g:line(0, 44, sw, 44, 15)

  local img_y = ms.editing and LAYOUT.img_y_edit or LAYOUT.img_y
  local image_size = ms.editing
    and LAYOUT.image_size_edit
    or LAYOUT.image_size

  draw_mood_icon(
    g,
    entry.mood,
    math.floor(sw / 2),
    img_y,
    image_size
  )

  if ms.editing then
    -- 编辑模式隐藏六个心情按钮。
    -- 顺序固定为：输入结果框 → 候选框 → 键盘。
    draw_textbox(g, entry.reason, true, ms.edit_buffer, ms.pinyin)
    draw_candidates(g, ms)
    draw_keyboard(g, ms)
    draw_edit_prompt(g)
  else
    draw_mood_selector(g, entry.mood)
    draw_textbox(g, entry.reason, false, ms.edit_buffer, "")

    draw_weekly_chart(g, ms)
    draw_date_bar(g, cd)
  end
end
