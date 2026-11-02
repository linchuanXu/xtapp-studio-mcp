-- 查字典 · XTEINK X4 Pro 480x800
-- 离线词典、例句收藏、文件夹管理和记忆复习

local SW = 480
local SH = 800
local BLACK = 0
local DARK = 3
local MID = 8
local LIGHT = 12
local WHITE = 15

-- Dictionary shards are stored in data/A.txt through data/Z.txt.
-- They are listed in manifest.data_files and read through ctx.package.
local function open_shard_reader(ctx, letter)
  local name = string.upper(letter) .. ".txt"
  return ctx.package:open_text(name)
end

local COMPACT_WORD_COUNT = 20966
local ENCOURAGEMENTS = {
  "每一次回想，都在让记忆更牢固。",
  "今天的复习已经为明天铺好了路。",
  "记住一点点，也是一段很好的进步。",
  "继续保持，你正在建立自己的词汇库。",
  "困难的词只是需要再见几次面。",
  "稳定复习，比一次记住更重要。",
  "你刚刚完成了一次有效的记忆训练。",
  "把模糊的词再读一遍，就会更清楚。",
  "每个例句都在帮你真正理解单词。",
  "今天多记一个，未来就多一种表达。",
  "做得很好，休息一下再继续也可以。",
  "遗忘不是失败，而是复习的提醒。",
  "你正在把陌生单词变成自己的语言。",
  "慢慢来，长期记忆需要一点时间。",
  "愿你下次看到这些词时更加熟悉。",
  "完成比完美更重要，今天已经完成。",
  "再小的积累，也会变成明显的成长。",
  "给自己一点掌声，这组复习结束了。",
  "记忆会波动，坚持会留下痕迹。",
  "今天的努力不会被大脑轻易忘记。",
  "用例句理解，比孤立背词更有力量。",
  "你已经比开始复习前更进一步。",
  "模糊意味着正在形成记忆，不必着急。",
  "把忘记的词留给下一次重新认识。",
  "专注这一组，就是很扎实的学习。",
  "你的词汇正在一个一个地增加。",
  "复习结束，但记忆正在继续整理。",
  "每次主动回忆都会加强记忆连接。",
  "保持这个节奏，你会看到长期变化。",
  "今天认识的词，会在阅读中再次相遇。",
  "认真完成一轮，就值得肯定。",
  "别怕忘记，大脑正需要这样的练习。",
  "你的坚持正在让英语变得更自然。",
  "把难词标出来，就是聪明的学习方法。",
  "再复习一次，模糊就会慢慢变清晰。",
  "你为每个词都找到了真实的语境。",
  "继续积累，表达会越来越丰富。",
  "今天的专注是一份很好的礼物。",
  "记忆需要间隔，你已经迈出关键一步。",
  "每轮复习都让你更了解自己的掌握度。",
  "不错，这些词已经离你更近了。",
  "能辨认模糊和忘记，本身就是进步。",
  "下一次复习会比这一次更加轻松。",
  "让重复成为习惯，让记忆自然发生。",
  "你完成的不只是任务，还有一次成长。",
  "认真对待一个词，也是在丰富一个世界。",
  "记得的词值得庆祝，忘记的词值得再见。",
  "一步一步来，你的基础正在变稳。",
  "今天的学习已经足够有价值。",
  "愿这些词在需要时准确地出现。",
  "你正在练习真正有效的主动回忆。",
  "每个被记住的例句都能带来新表达。",
  "保持好奇，单词会变得越来越有趣。",
  "这次完成得很好，下次继续巩固。",
  "给大脑一点时间，它正在认真整理。",
  "坚持复习的人，会得到稳定的回报。",
  "难点已经被看见，下一步就是加强。",
  "你已经完成今天最重要的一小步。",
  "把这份节奏带到下一次学习中。",
  "今天辛苦了，你的积累正在发芽。",
}

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
  yi = { "一", "忆", "以", "已", "意", "易", "亿" },
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
  mingitian = { "明天" },
  mingitian2 = { "明天" },
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

-- 文件夹命名常用字扩展；与基础音节库合并并自动去重。
local PINYIN_EXTRA = {
  ai = { "爱", "艾", "碍", "挨", "矮" },
  an = { "安", "按", "案", "暗", "岸" },
  bao = { "包", "保", "宝", "报", "抱", "薄" },
  bei = { "被", "北", "备", "背", "杯", "倍", "贝", "悲" },
  bi = { "比", "必", "笔", "闭", "避", "壁", "毕", "彼" },
  biao = { "表", "标", "彪", "飙" },
  cang = { "藏", "仓", "苍" },
  ce = { "册", "测", "侧", "策" },
  chang = { "长", "常", "场", "唱", "厂", "畅" },
  cheng = { "成", "城", "程", "称", "承", "诚" },
  chu = { "出", "处", "初", "除", "楚", "储" },
  ci = { "词", "次", "此", "辞", "慈" },
  da = { "大", "达", "打", "答", "搭" },
  dai = { "代", "带", "待", "袋", "戴" },
  de = { "的", "得", "德" },
  dian = { "点", "电", "店", "典", "殿" },
  du = { "读", "度", "独", "都", "督", "渡" },
  fa = { "发", "法", "罚", "乏" },
  fang = { "方", "放", "房", "访", "防", "芳" },
  fen = { "分", "份", "粉", "奋", "纷" },
  fu = { "复", "附", "父", "负", "福", "服", "副", "符" },
  gai = { "改", "该", "盖", "概" },
  ge = { "个", "歌", "格", "各", "哥", "隔" },
  gong = { "工", "共", "公", "功", "供", "宫" },
  guan = { "关", "管", "观", "馆", "官", "冠" },
  gao = { "高", "搞", "告", "稿", "糕", "膏", "郜" },
  hu = { "呼", "湖", "户", "护", "互", "忽", "胡", "虎", "乎", "壶" },
  hua = { "话", "花", "画", "华", "化", "划", "滑", "桦" },
  huan = { "欢", "换", "环", "还", "缓", "幻", "患", "唤" },
  huang = { "黄", "慌", "皇", "荒", "晃", "煌", "凰" },
  hui = { "会", "回", "汇", "挥", "辉", "惠", "慧", "绘", "灰", "悔", "毁", "徽" },
  ji = { "记", "集", "机", "级", "己", "计", "技", "季", "纪", "极" },
  jia = { "家", "加", "夹", "佳", "假", "价", "架", "甲", "嫁" },
  jian = { "件", "见", "间", "建", "简", "检", "减", "坚", "剑", "键" },
  jie = { "节", "解", "界", "结", "接", "街", "借", "姐" },
  ku = { "库", "苦", "酷", "哭" },
  le = { "了", "乐", "勒" },
  lei = { "类", "累", "泪", "雷" },
  li = { "里", "力", "理", "利", "立", "历", "礼", "离", "例" },
  liao = { "了", "料", "聊", "辽" },
  lu = { "录", "路", "陆", "露", "鲁", "炉", "鹿", "卢" },
  ming = { "名", "明", "命", "鸣", "铭" },
  mu = { "目", "木", "母", "幕", "墓", "牧", "慕" },
  nei = { "内", "哪" },
  qu = { "取", "去", "区", "曲", "趣", "趋" },
  ri = { "日" },
  shan = { "山", "删", "善", "闪", "扇" },
  sheng = { "生", "声", "省", "升", "胜", "圣", "盛", "剩", "绳" },
  shi = { "是", "时", "事", "市", "使", "式", "十", "实", "世", "师", "诗", "识", "史", "石", "试", "视", "室", "食", "示", "适", "士", "失", "始" },
  shu = { "书", "数", "树", "属", "熟", "术", "输" },
  sou = { "搜" },
  suo = { "所", "索", "锁", "缩" },
  ti = { "题", "体", "提", "替", "梯" },
  tian = { "天", "田", "填", "甜" },
  tu = { "图", "土", "途", "突" },
  wen = { "文", "问", "闻", "稳", "温", "纹", "吻" },
  xi = { "习", "西", "系", "喜", "细", "息", "希", "析" },
  xue = { "学", "雪", "血", "穴" },
  yi = { "一", "忆", "意", "义", "艺", "易", "已", "以", "衣", "医", "依", "议" },
  yong = { "用", "永", "勇", "拥", "泳" },
  yuan = { "原", "元", "员", "园", "远", "愿", "源", "圆" },
  zhi = { "知", "只", "之", "指", "纸", "直", "值", "志", "制", "置" },
  zhong = { "中", "种", "重", "终", "众", "钟" },
  zi = { "字", "自", "子", "资", "紫", "仔" },
  zu = { "组", "足", "族", "祖" },
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

local function merge_pinyin_table(extra)
  for syllable, characters in pairs(extra) do
    if not PINYIN_DICT[syllable] then PINYIN_DICT[syllable] = {} end
    local existing = {}
    for i = 1, #PINYIN_DICT[syllable] do
      existing[PINYIN_DICT[syllable][i]] = true
    end
    for i = 1, #characters do
      if not existing[characters[i]] then
        PINYIN_DICT[syllable][#PINYIN_DICT[syllable] + 1] = characters[i]
        existing[characters[i]] = true
      end
    end
  end
end
merge_pinyin_table(PINYIN_EXTRA)
merge_pinyin_table(PINYIN_RICH)

local KEYBOARD_ROWS = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
  { "z", "x", "c", "v", "b", "n", "m" },
  { "back", "space", "go", "close" },
}

local RENAME_KEYBOARD_ROWS = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
  { "z", "x", "c", "v", "b", "n", "m" },
  { "back", "space", "mode", "go", "close" },
}

local function utf8_len(s)
  local count = 0
  local i = 1
  while i <= #s do
    local c = string.byte(s, i)
    if c < 0x80 then i = i + 1
    elseif c < 0xE0 then i = i + 2
    elseif c < 0xF0 then i = i + 3
    else i = i + 4 end
    count = count + 1
  end
  return count
end

local function utf8_sub(s, first, last)
  local start_byte = 1
  local end_byte = #s
  local char = 1
  local i = 1
  while i <= #s do
    if char == first then start_byte = i end
    if last and char == last + 1 then end_byte = i - 1 break end
    local c = string.byte(s, i)
    if c < 0x80 then i = i + 1
    elseif c < 0xE0 then i = i + 2
    elseif c < 0xF0 then i = i + 3
    else i = i + 4 end
    char = char + 1
  end
  if first > char then return "" end
  return string.sub(s, start_byte, end_byte)
end

local function utf8_chop(s)
  local n = utf8_len(s)
  if n <= 1 then return "" end
  return utf8_sub(s, 1, n - 1)
end

local function refresh_rename_candidates(ms)
  ms.rename_candidates = {}
  ms.rename_candidate_page = 1
  if not ms.rename_pinyin or ms.rename_pinyin == "" then return end
  local prefix = string.lower(ms.rename_pinyin)
  local syllables = {}
  for syllable in pairs(PINYIN_DICT) do
    if string.sub(syllable, 1, #prefix) == prefix then
      syllables[#syllables + 1] = syllable
    end
  end
  table.sort(syllables, function(a, b)
    if a == b then return false end
    if a == prefix then return true end
    if b == prefix then return false end
    if #a ~= #b then return #a < #b end
    return a < b
  end)
  for s = 1, #syllables do
    local syllable = syllables[s]
    local candidates = PINYIN_DICT[syllable]
    for i = 1, #candidates do
      ms.rename_candidates[#ms.rename_candidates + 1] = {
        char = candidates[i],
        pinyin = syllable,
      }
    end
  end
end

local function commit_rename_candidate(ms, index)
  local value = ms.rename_candidates and ms.rename_candidates[index]
  if not value then return false end
  ms.edit_buffer = ms.edit_buffer .. (value.char or value)
  ms.rename_pinyin = ""
  ms.rename_candidates = {}
  ms.rename_candidate_page = 1
  return true
end

local function flush_rename_pinyin(ms)
  if not ms.rename_pinyin or ms.rename_pinyin == "" then return end
  if ms.rename_candidates and #ms.rename_candidates > 0 then
    commit_rename_candidate(ms, 1)
  else
    ms.edit_buffer = ms.edit_buffer .. ms.rename_pinyin
    ms.rename_pinyin = ""
    ms.rename_candidates = {}
  end
end

local function lower_ascii(s)
  return string.lower(s or "")
end

local function starts_with(text, prefix)
  return string.sub(text, 1, #prefix) == prefix
end

local function now_sec(ctx)
  local ok, value = pcall(function() return ctx.clock:now().epoch_sec end)
  if ok and tonumber(value) then return tonumber(value) end
  return 0
end

local function app_state(ctx)
  if not ctx.state.dictionary_app then
    ctx.state.dictionary_app = {
      page = "home",
      query = "",
      editing = false,
      edit_mode = "search",
      edit_buffer = "",
      suggestions = {},
      history = {},
      selected_word = nil,
      current_data = nil,
      sense_scroll = 1,
      pending_sense = 1,
      picker_saved_to = nil,
      folders = {
        { id = 1, name = "默认文件夹", items = {} }
      },
      next_folder_id = 2,
      folder_scroll = 0,
      picker_scroll = 0,
      active_folder_id = nil,
      study_index = 1,
      study_stage = 0,
      review_results = {},
      summary_message = 1,
      rename_folder_id = nil,
      return_page = "folders",
      last_tap_id = nil,
      last_tap_time = -10,
      last_opened_folder_id = nil,
      last_opened_folder_time = -10,
      last_opened_folder_x = nil,
      last_opened_folder_y = nil,
      pressed_key = nil,
      rename_ime_cn = true,
      rename_pinyin = "",
      rename_candidates = {},
      rename_candidate_page = 1,
      notice = nil,
    }
  end
  local ms = ctx.state.dictionary_app
  if ms.rename_ime_cn == nil then ms.rename_ime_cn = true end
  if ms.rename_pinyin == nil then ms.rename_pinyin = "" end
  if ms.rename_candidates == nil then ms.rename_candidates = {} end
  if ms.rename_candidate_page == nil then ms.rename_candidate_page = 1 end
  return ms
end

local function find_folder(ms, id)
  for i = 1, #ms.folders do
    if ms.folders[i].id == id then return ms.folders[i], i end
  end
  return nil, nil
end

local function parse_compact_line(line)
  local word, phonetic, blob =
    string.match(line, "^([^\t]+)\t([^\t]*)\t(.*)$")
  if not word then return nil end
  local senses = {}
  for packed in string.gmatch(blob .. "~", "(.-)~") do
    local pos, meaning, example =
      string.match(packed, "^([^|]*)|([^|]*)|(.*)$")
    if meaning and meaning ~= "" then
      if not example then example = "" end
      senses[#senses + 1] = {
        pos = pos or "",
        meaning = meaning,
        example = example
      }
    end
  end
  if #senses == 0 then return nil end
  return { word = word, phonetic = phonetic or "", senses = senses }
end

local function dictionary_lookup(ctx, word)
  word = lower_ascii(word)
  if word == "" then return nil end

  local letter = string.sub(word, 1, 1)
  if not string.match(letter, "^[a-z]$") then return nil end

  local reader = open_shard_reader(ctx, letter)
  if not reader then return nil end

  local marker = word .. "\t"
  while true do
    local line = reader:read_line()
    if not line then break end
    if starts_with(line, marker) then
      reader:close()
      return parse_compact_line(line)
    end
  end

  reader:close()
  return nil
end

-- 单字母分卷索引缓存：每个字母分卷的"第二字母→代表词"只构建一次
-- 真机每次按键都会查关联，不能反复全分卷扫描（ESP32 上极慢）
local SECOND_INDEX = {}

local function get_second_index(ctx, letter)
  if SECOND_INDEX[letter] then return SECOND_INDEX[letter] end
  local idx = { groups = {}, order = {} }
  local reader = open_shard_reader(ctx, letter)
  if reader then
    while true do
      local line = reader:read_line()
      if not line then break end
      local tab_at = string.find(line, "\t", 1, true)
      if tab_at then
        local candidate = string.sub(line, 1, tab_at - 1)
        local first = string.sub(candidate, 1, 1)
        if first == letter and #candidate >= 2 then
          local second = string.sub(candidate, 2, 2)
          if string.match(second, "^[a-z]$") and not idx.groups[second] then
            idx.groups[second] = candidate
            idx.order[#idx.order + 1] = second
          end
        end
      end
    end
    reader:close()
  end
  SECOND_INDEX[letter] = idx
  return idx
end

local function dictionary_suggest(ctx, prefix, limit)
  prefix = lower_ascii(prefix)
  local result = {}
  if prefix == "" then return result end

  local letter = string.sub(prefix, 1, 1)
  if not string.match(letter, "^[a-z]$") then return result end

  if #prefix == 1 then
    -- 单字母：直接从缓存索引取各第二字母的代表词，秒回
    local idx = get_second_index(ctx, letter)
    for i = 1, #idx.order do
      result[#result + 1] = idx.groups[idx.order[i]]
      if #result >= limit then break end
    end
    return result
  end

  -- 多字母：完整前缀匹配（前缀收窄后命中少，扫描可控）
  local reader = open_shard_reader(ctx, letter)
  if not reader then return result end
  while true do
    local line = reader:read_line()
    if not line then break end
    local tab_at = string.find(line, "\t", 1, true)
    if tab_at then
      local candidate = string.sub(line, 1, tab_at - 1)
      if starts_with(candidate, prefix) then
        result[#result + 1] = candidate
        if #result >= limit then break end
      end
    end
  end
  reader:close()
  return result
end
local function refresh_suggestions(ctx, ms)
  ms.suggestions = {}
  local prefix = lower_ascii(ms.edit_buffer)
  if prefix == "" then return end
  ms.suggestions = dictionary_suggest(ctx, prefix, 5)
end

local function add_history(ms, word)
  local result = { word }
  for i = 1, #ms.history do
    if ms.history[i] ~= word and #result < 4 then
      result[#result + 1] = ms.history[i]
    end
  end
  ms.history = result
end

local function open_definition(ctx, ms, word)
  local data = dictionary_lookup(ctx, word)
  if not data then return false end
  ms.selected_word = word
  ms.current_data = data
  ms.query = word
  ms.edit_buffer = word
  ms.editing = false
  ms.page = "definition"
  ms.sense_scroll = 1
  ms.notice = nil
  add_history(ms, word)
  return true
end

local function submit_search(ctx, ms)
  local query = lower_ascii(ms.edit_buffer)
  if dictionary_lookup(ctx, query) then return open_definition(ctx, ms, query) end
  if #ms.suggestions > 0 then return open_definition(ctx, ms, ms.suggestions[1]) end
  ms.notice = "没有找到这个词，请尝试其他拼写"
  return false
end

local function add_folder(ms)
  local id = ms.next_folder_id
  local number = id - 1
  ms.next_folder_id = id + 1
  ms.folders[#ms.folders + 1] = {
    id = id,
    name = "默认文件" .. tostring(number),
    items = {}
  }
  return ms.folders[#ms.folders]
end

local function save_pending_item(ms, folder)
  local word = ms.selected_word
  local data = ms.current_data
  local sense_index = ms.pending_sense
  local sense = data and data.senses[sense_index]
  if not word or not sense then return false end

  for i = 1, #folder.items do
    local old = folder.items[i]
    if old.word == word and old.sense_index == sense_index then
      ms.notice = "已经收藏在“" .. folder.name .. "”"
      ms.picker_saved_to = folder.id
      return true
    end
  end

  folder.items[#folder.items + 1] = {
    word = word,
    phonetic = data.phonetic,
    sense_index = sense_index,
    meaning = sense.meaning,
    example = sense.example,
  }
  ms.notice = "已收藏到“" .. folder.name .. "”"
  ms.picker_saved_to = folder.id
  return true
end

local function begin_rename(ms, folder_id, return_page)
  local folder = find_folder(ms, folder_id)
  if not folder then return end
  ms.rename_folder_id = folder_id
  ms.return_page = return_page or "folders"
  ms.edit_mode = "rename"
  ms.edit_buffer = folder.name
  ms.rename_ime_cn = true
  ms.rename_pinyin = ""
  ms.rename_candidates = {}
  ms.rename_candidate_page = 1
  ms.pressed_key = nil
  ms.editing = true
  ms.page = "rename"
  ms.notice = nil
end

local function finish_rename(ms)
  flush_rename_pinyin(ms)
  local folder = find_folder(ms, ms.rename_folder_id)
  local value = ms.edit_buffer
  if folder and value and value ~= "" then folder.name = value end
  ms.editing = false
  ms.page = ms.return_page or "folders"
  ms.notice = nil
end

local function begin_study(ms, folder_id)
  local folder = find_folder(ms, folder_id)
  if not folder then return end
  ms.active_folder_id = folder_id
  ms.study_index = 1
  ms.study_stage = 0
  ms.review_results = {}
  ms.page = "study"
  ms.notice = nil
end

local function complete_study(ms, ctx)
  local seed = now_sec(ctx) + (ms.active_folder_id or 0) * 17
  ms.summary_message = (seed % #ENCOURAGEMENTS) + 1
  ms.page = "summary"
end

local function next_study_item(ms, ctx)
  local folder = find_folder(ms, ms.active_folder_id)
  if not folder then ms.page = "folders" return end
  if ms.study_index >= #folder.items then
    complete_study(ms, ctx)
  else
    ms.study_index = ms.study_index + 1
    ms.study_stage = 0
    ms.notice = nil
  end
end

-- ==================== 基础绘图 ====================

local function fill_pill(g, x, y, w, h, color)
  local r = math.floor(h / 2)
  g:rect(x + r, y, w - 2 * r, h,{fill=true,color=color})
  g:circle(x + r, y + r, r,{fill=true,color=color})
  g:circle(x + w - 1 - r, y + r, r,{fill=true,color=color})
end

local function outline_pill(g, x, y, w, h, color, background)
  fill_pill(g, x, y, w, h, color)
  fill_pill(g, x + 2, y + 2, w - 4, h - 4, background)
end

local function text_pixel_width(text, ascii_w)
  local width = 0
  local i = 1
  local aw = ascii_w or 8
  while i <= #text do
    local c = string.byte(text, i)
    if c < 0x80 then
      width = width + aw
      i = i + 1
    elseif c < 0xE0 then
      width = width + 16
      i = i + 2
    elseif c < 0xF0 then
      width = width + 16
      i = i + 3
    else
      width = width + 16
      i = i + 4
    end
  end
  return width
end

local function draw_center_text(g, x, y, w, text, color, char_w)
  local tw = text_pixel_width(text, char_w or 8)
  g:text(x + math.max(0, math.floor((w - tw) / 2)), y, text, { color = color })
end

local function draw_bold_text(g, x, y, text, color)
  g:text(x, y, text, { color = color })
  g:text(x + 1, y, text, { color = color })
end

local function draw_search_icon(g, cx, cy, color)
  g:circle(cx - 4, cy - 4, 10,{color=color})
  g:line(cx + 3, cy + 3, cx + 13, cy + 13,{color=color})
  g:line(cx + 4, cy + 2, cx + 14, cy + 12,{color=color})
end

local function draw_bookmark(g, x, y, w, h, color)
  g:line(x, y, x + w, y,{color=color})
  g:line(x, y, x, y + h,{color=color})
  g:line(x + w, y, x + w, y + h,{color=color})
  g:line(x, y + h, x + math.floor(w / 2), y + h - 8,{color=color})
  g:line(x + math.floor(w / 2), y + h - 8, x + w, y + h,{color=color})
end

local function draw_back(g)
  g:line(28, 27, 15, 40,{color=BLACK})
  g:line(15, 40, 28, 53,{color=BLACK})
end

local function draw_plus(g, cx, cy, size, color)
  local half = math.floor(size / 2)
  g:line(cx - half, cy, cx + half, cy,{color=color})
  g:line(cx, cy - half, cx, cy + half,{color=color})
end

local function draw_strong_line(g, x1, y1, x2, y2, color)
  g:line(x1, y1, x2, y2,{color=color})
  if y1 == y2 then
    g:line(x1, y1 + 1, x2, y2 + 1,{color=color})
  elseif x1 == x2 then
    g:line(x1 + 1, y1, x2 + 1, y2,{color=color})
  end
end

local function draw_strong_rect(g, x, y, w, h, color)
  g:rect(x, y, w, h,{color=color})
  if w > 4 and h > 4 then g:rect(x + 1, y + 1, w - 2, h - 2,{color=color}) end
end

local function draw_dashed_rect(g, x, y, w, h, color)
  local dash = 10
  local gap = 7
  local i = 0
  while i < w do
    local x2 = math.min(x + w, x + i + dash)
    g:line(x + i, y, x2, y,{color=color})
    g:line(x + i, y + h, x2, y + h,{color=color})
    i = i + dash + gap
  end
  i = 0
  while i < h do
    local y2 = math.min(y + h, y + i + dash)
    g:line(x, y + i, x, y2,{color=color})
    g:line(x + w, y + i, x + w, y2,{color=color})
    i = i + dash + gap
  end
end

local function draw_folder_icon(g, x, y, w, h, selected)
  local fill = selected and BLACK or WHITE
  local ink = selected and WHITE or BLACK
  g:rect(x + 12, y, math.floor(w * 0.42), 24,{fill=true,color=BLACK})
  g:rect(x + 14, y + 2, math.floor(w * 0.42) - 4, 22,{fill=true,color=fill})
  g:rect(x, y + 17, w, h - 17,{fill=true,color=BLACK})
  g:rect(x + 3, y + 20, w - 6, h - 23,{fill=true,color=fill})
  g:rect(x + 24, y + 34, w - 48, h - 47,{color=ink})
  g:line(x + 36, y + 47, x + w - 36, y + 47,{color=ink})
  g:line(x + 36, y + 59, x + w - 48, y + 59,{color=ink})
end

local function wrapped_lines(text, max_chars, max_lines)
  local lines = {}
  local words = {}
  for word in string.gmatch(text, "%S+") do words[#words + 1] = word end

  local function can_add()
    return not max_lines or #lines < max_lines
  end

  local function add_line(value)
    if value ~= "" and can_add() then
      lines[#lines + 1] = value
      return true
    end
    return false
  end

  if #words > 1 then
    local current = ""
    for i = 1, #words do
      local word = words[i]

      -- 中文释义经常只有很少的空格；单个片段超过边界时也必须拆行。
      if utf8_len(word) > max_chars then
        if current ~= "" then
          add_line(current)
          current = ""
        end
        local total = utf8_len(word)
        local start = 1
        while start <= total - max_chars and can_add() do
          add_line(utf8_sub(word, start, start + max_chars - 1))
          start = start + max_chars
        end
        word = utf8_sub(word, start, total)
      end

      if not can_add() then break end
      local candidate = current == "" and word or current .. " " .. word
      if utf8_len(candidate) <= max_chars then
        current = candidate
      else
        if current ~= "" then add_line(current) end
        current = word
      end
    end
    add_line(current)
  else
    local total = utf8_len(text)
    local start = 1
    while start <= total and can_add() do
      add_line(utf8_sub(text, start, math.min(total, start + max_chars - 1)))
      start = start + max_chars
    end
  end
  return lines
end

local function draw_wrapped(g, text, x, y, max_chars, max_lines, color, line_h)
  local lines = wrapped_lines(text, max_chars, max_lines)
  local lh = line_h or 23
  for i = 1, #lines do
    g:text(x, y + (i - 1) * lh, lines[i], { color = color or BLACK })
  end
  return #lines
end

local function draw_header(g, title, right_text)
  draw_back(g)
  draw_bold_text(g, 54, 29, title, BLACK)
  if right_text then g:text(390, 31, right_text, { color = BLACK }) end
  g:line(0, 68, SW, 68,{color=BLACK})
end

-- ==================== 键盘 ====================

local KB_TOP = 500
local KB_ROW_H = 58
local KB_GAP = 5

local function keyboard_rows(ms)
  if ms and ms.edit_mode == "rename" then return RENAME_KEYBOARD_ROWS end
  return KEYBOARD_ROWS
end

local function keyboard_key_rect(row_index, col_index, ms)
  local row = keyboard_rows(ms)[row_index]
  local margin = 8
  local available = SW - margin * 2
  local gap = 4
  local width = math.floor((available - gap * (#row - 1)) / #row)
  local used = width * #row + gap * (#row - 1)
  local start_x = math.floor((SW - used) / 2)
  local x = start_x + (col_index - 1) * (width + gap)
  local y = KB_TOP + (row_index - 1) * (KB_ROW_H + KB_GAP)
  return x, y, width, KB_ROW_H
end

local function key_label(key, ms)
  if key == "back" then return "删除" end
  if key == "space" then return "空格" end
  if key == "mode" then return ms and ms.rename_ime_cn and "中" or "英" end
  if key == "go" then return "确定" end
  if key == "close" then return "收起" end
  return key
end

local function draw_keyboard(g, ms)
  local rows = keyboard_rows(ms)
  g:line(0, KB_TOP - 10, SW, KB_TOP - 10,{color=BLACK})
  for ri = 1, #rows do
    for ci = 1, #rows[ri] do
      local x, y, w, h = keyboard_key_rect(ri, ci, ms)
      local key = rows[ri][ci]
      local pressed = ms and ms.pressed_key == key
      if pressed then g:rect(x, y, w, h,{fill=true,color=BLACK}) end
      draw_center_text(
        g,
        x,
        y + 18,
        w,
        key_label(key, ms),
        pressed and WHITE or BLACK,
        key == "space" and 8 or 7
      )
    end
  end
end

local function hit_keyboard(px, py, ms)
  local rows = keyboard_rows(ms)
  for ri = 1, #rows do
    for ci = 1, #rows[ri] do
      local x, y, w, h = keyboard_key_rect(ri, ci, ms)
      if px >= x and px <= x + w and py >= y and py <= y + h then
        return rows[ri][ci]
      end
    end
  end
  return nil
end

local function handle_keyboard_key(ctx, ms, key)
  ms.pressed_key = key

  if ms.edit_mode == "rename" then
    if key == "mode" then
      flush_rename_pinyin(ms)
      ms.rename_ime_cn = not ms.rename_ime_cn
    elseif key == "back" then
      if ms.rename_pinyin and ms.rename_pinyin ~= "" then
        ms.rename_pinyin = string.sub(ms.rename_pinyin, 1, #ms.rename_pinyin - 1)
        refresh_rename_candidates(ms)
      else
        ms.edit_buffer = utf8_chop(ms.edit_buffer)
      end
    elseif key == "space" then
      if ms.rename_ime_cn and ms.rename_pinyin ~= "" then
        flush_rename_pinyin(ms)
      else
        ms.edit_buffer = ms.edit_buffer .. " "
      end
    elseif key == "go" or key == "close" then
      finish_rename(ms)
    else
      if ms.rename_ime_cn then
        ms.rename_pinyin = ms.rename_pinyin .. key
        refresh_rename_candidates(ms)
      else
        ms.edit_buffer = ms.edit_buffer .. key
      end
    end
    return
  end

  if key == "back" then
    ms.edit_buffer = utf8_chop(ms.edit_buffer)
  elseif key == "space" then
    if ms.edit_mode == "rename" then ms.edit_buffer = ms.edit_buffer .. " " end
  elseif key == "close" then
    if ms.edit_mode == "search" then
      ms.query = ms.edit_buffer
      ms.editing = false
    else
      finish_rename(ms)
    end
  elseif key == "go" then
    if ms.edit_mode == "search" then submit_search(ctx, ms)
    else finish_rename(ms) end
  else
    ms.edit_buffer = ms.edit_buffer .. key
  end

  if ms.edit_mode == "search" then refresh_suggestions(ctx, ms) end
end

-- 编辑键盘的按键焦点导航（语义键兜底：方向键移动、ok 输入/提交、back 删除）
local function kb_move(ms, dr, dc)
  local rows = keyboard_rows(ms)
  local ri = math.max(1, math.min(#rows, (ms.kb_row or 1) + dr))
  local ci = math.max(1, math.min(#rows[ri], (ms.kb_col or 1) + dc))
  ms.kb_row, ms.kb_col = ri, ci
  return true
end

local function kb_press_focus(ctx, ms)
  local rows = keyboard_rows(ms)
  local ri = math.max(1, math.min(#rows, ms.kb_row or 1))
  local ci = math.max(1, math.min(#rows[ri], ms.kb_col or 1))
  handle_keyboard_key(ctx, ms, rows[ri][ci])
  return true
end

local function kb_back(ctx, ms)
  if #ms.edit_buffer > 0 then
    handle_keyboard_key(ctx, ms, "back")
    return true
  end
  return false
end

-- ==================== 页面绘制 ====================

local function draw_home(g, ms)
  g:clear(WHITE)
  draw_bold_text(g, 24, 24, "查字典", BLACK)
  g:text(344, 26, "20966词·超1MB版", { color = MID })
  g:line(20, 58, 460, 58,{color=BLACK})

  local input_y = 82
  outline_pill(g, 24, input_y, 432, 62, BLACK, WHITE)
  local display = ms.editing and ms.edit_buffer or ms.query
  if display == "" then
    g:text(48, input_y + 20, "输入英文单词", { color = MID })
  else
    g:text(48, input_y + 20, display .. (ms.editing and "_" or ""), { color = BLACK })
  end
  draw_search_icon(g, 421, input_y + 31, BLACK)

  if ms.editing then
    draw_bold_text(g, 26, 166, "关联搜索", BLACK)
    g:line(24, 195, 456, 195,{color=LIGHT})
    if #ms.suggestions == 0 then
      g:text(32, 220, ms.edit_buffer == "" and "输入前几个英文字母" or "暂无匹配词", { color = MID })
    else
      for i = 1, #ms.suggestions do
        local y = 198 + (i - 1) * 54
        g:text(36, y + 16, ms.suggestions[i], { color = BLACK })
        local data = nil
        g:text(235, y + 16, data and data.phonetic or "", { color = MID })
        g:text(428, y + 16, ">", { color = BLACK })
        g:line(24, y + 53, 456, y + 53,{color=LIGHT})
      end
    end
    if ms.notice then g:text(28, 462, ms.notice, { color = DARK }) end
    draw_keyboard(g, ms)
    return
  end

  draw_bold_text(g, 26, 178, "历史搜索", BLACK)
  if #ms.history == 0 then
    g:text(28, 216, "搜索过的单词会显示在这里", { color = MID })
  else
    local gap = 8
    local chip_w = 101
    for i = 1, math.min(4, #ms.history) do
      local x = 24 + (i - 1) * (chip_w + gap)
      fill_pill(g, x, 210, chip_w, 42, BLACK)
      local text = ms.history[i]
      if #text > 11 then text = string.sub(text, 1, 9) .. ".." end
      draw_center_text(g, x, 223, chip_w, text, WHITE, 7)
    end
  end

  g:line(24, 292, 456, 292,{color=LIGHT})
  draw_bold_text(g, 26, 318, "使用提示", BLACK)
  g:text(28, 356, "输入字母查看联想词，点击即可打开释义。", { color = DARK })
  g:text(28, 388, "点击加号可收藏词条到文件夹。", { color = DARK })
  g:text(28, 420, "在回忆录中逐词复习并记录掌握情况。", { color = DARK })

  g:rect(386, 700, 58, 58,{color=BLACK})
  draw_bookmark(g, 403, 714, 24, 29, BLACK)
  draw_center_text(g, 386, 768, 58, "回忆录", BLACK, 8)
end

local function draw_sense_card(g, sense, sense_index, y)
  local h = 250
  g:rect(20, y, 440, h,{color=BLACK})
  g:rect(32, y + 16, 52, 28,{fill=true,color=BLACK})
  draw_center_text(g, 32, y + 23, 52, tostring(sense_index), WHITE, 8)
  g:text(100, y + 22, sense.pos, { color = BLACK })

  draw_wrapped(g, sense.meaning, 34, y + 63, 23, 2, BLACK, 24)
  g:line(32, y + 118, 448, y + 118,{color=LIGHT})
  g:text(34, y + 134, "例句", { color = MID })
  local ex_text = (sense.example and sense.example ~= "") and sense.example or "（口袋版暂无例句）"
  draw_wrapped(g, ex_text, 34, y + 166, 40, 3, BLACK, 23)
  g:rect(416, y + 160, 30, 30,{color=BLACK})
  draw_plus(g, 431, y + 175, 7, BLACK)
end

local function draw_definition(g, ms)
  g:clear(WHITE)
  draw_header(g, "词语释义", "↑↓翻页")
  local data = ms.current_data
  if not data then
    g:text(30, 120, "词条不存在", { color = BLACK })
    return
  end

  draw_bold_text(g, 26, 88, ms.selected_word, BLACK)
  g:text(28, 121, data.phonetic, { color = MID })
  g:line(20, 151, 460, 151,{color=BLACK})

  local first = ms.sense_scroll
  local y1 = 168
  draw_sense_card(g, data.senses[first], first, y1)
  if data.senses[first + 1] then
    draw_sense_card(g, data.senses[first + 1], first + 1, y1 + 270)
  end

  local footer = tostring(first) .. "-" .. tostring(math.min(#data.senses, first + 1)) .. "/" .. tostring(#data.senses)
  g:text(410, 765, footer, { color = MID })
end

local function draw_picker(g, ms)
  g:clear(WHITE)
  draw_header(g, "收藏到文件夹", "双击改名")
  if ms.notice then
    g:rect(18, 80, 444, 42,{fill=true,color=BLACK})
    draw_center_text(g, 18, 93, 444, ms.notice, WHITE, 8)
  else
    g:text(24, 92, "单击文件夹立即保存当前例句", { color = MID })
  end

  local start = ms.picker_scroll + 1
  local y = 138
  local visible = 4
  for slot = 1, visible do
    local index = start + slot - 1
    local folder = ms.folders[index]
    if folder then
      local selected = ms.picker_saved_to == folder.id
      draw_folder_icon(g, 30, y, 112, 92, selected)
      draw_bold_text(g, 164, y + 18, folder.name, BLACK)
      g:text(164, y + 53, tostring(#folder.items) .. " 条收藏", { color = MID })
      g:text(418, y + 36, selected and "✓" or ">", { color = BLACK })
      g:line(20, y + 108, 460, y + 108,{color=LIGHT})
      y = y + 128
    elseif index == #ms.folders + 1 then
      draw_dashed_rect(g, 28, y, 424, 104, MID)
      draw_plus(g, 240, y + 43, 13, BLACK)
      draw_center_text(g, 28, y + 69, 424, "新增文件夹", BLACK, 8)
      y = y + 128
    end
  end
  g:text(22, 770, "使用上下键查看后续文件夹", { color = MID })
end

local function draw_folders(g, ms)
  g:clear(WHITE)
  draw_header(g, "回忆录", "＋新建")

  if #ms.folders == 0 then
    g:text(128, 360, "还没有文件夹", { color = MID })
    return
  end

  local start = ms.folder_scroll * 2 + 1
  local card_w = 168
  local card_h = 128
  local row_gap = 92
  local y0 = 96
  for slot = 1, 6 do
    local index = start + slot - 1
    local folder = ms.folders[index]
    if folder then
      local col = (slot - 1) % 2
      local row = math.floor((slot - 1) / 2)
      local x = col == 0 and 42 or 270
      local y = y0 + row * (card_h + row_gap)
      draw_folder_icon(g, x, y, card_w, card_h, false)
      draw_center_text(g, x, y + card_h + 14, card_w, folder.name, BLACK, 8)
      draw_center_text(g, x, y + card_h + 39, card_w, tostring(#folder.items) .. " 个词条", MID, 8)
    end
  end
  g:text(20, 770, "单击开始复习 · 双击文件夹改名 · ↑↓滚动", { color = MID })
end

local function rename_candidate_hit(ms, x, y)
  if y < 350 or y > 410 then return nil end
  local page = ms.rename_candidate_page or 1
  local start = (page - 1) * 5 + 1
  if x >= 420 then
    local pages = math.max(1, math.ceil(#ms.rename_candidates / 5))
    if pages > 1 then return "next" end
    return nil
  end
  local slot = math.floor((x - 20) / 80) + 1
  if slot < 1 or slot > 5 then return nil end
  local index = start + slot - 1
  if ms.rename_candidates[index] then return index end
  return nil
end

local function draw_rename_candidates(g, ms)
  if not ms.rename_ime_cn then
    g:text(28, 316, "英文模式：字母直接进入文件夹名称", { color = MID })
    return
  end

  local pinyin = ms.rename_pinyin or ""
  if pinyin == "" then
    g:text(28, 316, "中文模式：输入单字拼音，再点击候选字", { color = MID })
    return
  end

  g:text(28, 312, "拼音前缀 " .. pinyin, { color = BLACK })
  g:line(20, 342, 460, 342,{color=LIGHT})
  if #ms.rename_candidates == 0 then
    g:text(28, 364, "暂无候选；空格可保留原拼音", { color = MID })
    return
  end

  local page = ms.rename_candidate_page or 1
  local start = (page - 1) * 5 + 1
  for slot = 1, 5 do
    local index = start + slot - 1
    local candidate = ms.rename_candidates[index]
    if candidate then
      local x = 20 + (slot - 1) * 80
      local value = candidate.char or candidate
      local pinyin_value = candidate.pinyin or pinyin
      draw_center_text(g, x, 356, 76, tostring(slot) .. "." .. value, BLACK, 8)
      draw_center_text(g, x, 383, 76, pinyin_value, MID, 7)
    end
  end
  local pages = math.max(1, math.ceil(#ms.rename_candidates / 5))
  if pages > 1 then
    g:text(424, 358, "->", { color = BLACK })
    draw_center_text(g, 416, 387, 44, tostring(page) .. "/" .. tostring(pages), MID, 7)
  end
  g:line(20, 410, 460, 410,{color=LIGHT})
end

local function draw_rename(g, ms)
  g:clear(WHITE)
  draw_header(g, "修改文件夹名称", "完成")
  local folder = find_folder(ms, ms.rename_folder_id)
  if folder then draw_folder_icon(g, 184, 94, 112, 90, false) end

  outline_pill(g, 28, 218, 424, 62, BLACK, WHITE)
  local composing = ms.rename_ime_cn and (ms.rename_pinyin or "") or ""
  local display = ms.edit_buffer .. composing
  if display == "" then display = "输入新名称" end
  g:text(52, 238, display .. "_", { color = ms.edit_buffer ~= "" and BLACK or MID })
  draw_rename_candidates(g, ms)
  draw_keyboard(g, ms)
end

local function draw_mask(g, x, y, w, h, label)
  g:rect(x, y, w, h,{fill=true,color=BLACK})
  draw_center_text(g, x, y + math.floor(h / 2) - 8, w, label, WHITE, 8)
end

local function study_label_rect(index)
  local w = 112
  local gap = 18
  local x = 36 + (index - 1) * (w + gap)
  return x, 612, w, 64
end

local function draw_study(g, ms)
  g:clear(WHITE)
  local folder = find_folder(ms, ms.active_folder_id)
  if not folder then draw_header(g, "复习", nil) return end
  draw_header(g, folder.name, tostring(ms.study_index) .. "/" .. tostring(#folder.items))

  if #folder.items == 0 then
    draw_bold_text(g, 150, 318, "文件夹还是空的", BLACK)
    g:text(110, 360, "先在释义页收藏一些例句吧", { color = MID })
    return
  end

  local item = folder.items[ms.study_index]
  draw_bold_text(g, 30, 98, item.word, BLACK)
  g:text(32, 137, item.phonetic or "", { color = MID })
  g:line(24, 170, 456, 170,{color=BLACK})

  g:text(28, 192, "词义", { color = MID })
  if ms.study_stage >= 2 then
    draw_wrapped(g, item.meaning, 30, 230, 25, 3, BLACK, 28)
  else
    draw_mask(g, 26, 224, 428, 96, "第二次点击显示词义")
  end

  g:text(28, 354, "收藏例句", { color = MID })
  if ms.study_stage >= 1 then
    local ex_text = (item.example and item.example ~= "") and item.example or "（口袋版暂无例句）"
    draw_wrapped(g, ex_text, 30, 396, 45, 5, BLACK, 28)
  else
    draw_mask(g, 26, 386, 428, 142, "第一次点击显示例句")
  end

  if ms.study_stage >= 3 then
    local names = { "记住", "模糊", "忘记" }
    local key = tostring(ms.study_index)
    local selected = ms.review_results[key]
    for i = 1, 3 do
      local x, y, w, h = study_label_rect(i)
      local active = selected == i
      g:rect(x, y, w, h,{fill=(active) and true or false,color=BLACK})
      draw_center_text(g, x, y + 23, w, names[i], active and WHITE or BLACK, 8)
    end
    if selected then
      g:text(82, 704, "已选择；点击其他区域进入下一个词", { color = MID })
    else
      g:text(106, 704, "请选择本词的掌握情况", { color = MID })
    end
  else
    local hints = {
      "点击页面，先显示收藏例句",
      "再点击一次，显示词义",
      "再点击一次，选择掌握情况"
    }
    g:text(92, 704, hints[ms.study_stage + 1], { color = MID })
  end
end

local function summary_words(folder, results, rating)
  local words = {}
  for i = 1, #folder.items do
    if results[tostring(i)] == rating then words[#words + 1] = folder.items[i].word end
  end
  if #words == 0 then return "暂无" end
  return table.concat(words, " · ")
end

local function draw_summary(g, ms)
  g:clear(WHITE)
  local folder = find_folder(ms, ms.active_folder_id)
  draw_header(g, "本轮记忆总结", "完成")
  if not folder then return end

  draw_bold_text(g, 24, 92, string.upper(folder.name), BLACK)
  g:text(356, 96, tostring(#folder.items) .. " WORDS", { color = MID })
  draw_strong_line(g, 20, 132, 460, 132, BLACK)

  local counts = { 0, 0, 0 }
  for i = 1, #folder.items do
    local rating = ms.review_results[tostring(i)]
    if rating then counts[rating] = counts[rating] + 1 end
  end

  local labels = { "记住", "模糊", "忘记" }
  local y = 158
  for i = 1, 3 do
    draw_strong_rect(g, 22, y, 436, 120, BLACK)
    g:rect(24, y + 2, 100, 116,{fill=true,color=BLACK})
    draw_strong_line(g, 124, y, 124, y + 120, BLACK)
    draw_center_text(g, 24, y + 25, 100, labels[i], WHITE, 8)
    draw_center_text(g, 24, y + 65, 100, tostring(counts[i]), WHITE, 13)
    draw_wrapped(g, summary_words(folder, ms.review_results, i), 142, y + 25, 29, 3, BLACK, 25)
    y = y + 136
  end

  draw_strong_line(g, 20, 586, 460, 586, BLACK)
  draw_bold_text(g, 24, 608, "KEEP GOING.", BLACK)
  draw_wrapped(g, ENCOURAGEMENTS[ms.summary_message], 24, 652, 25, 3, BLACK, 29)
  g:rect(298, 730, 158, 46,{fill=true,color=BLACK})
  draw_center_text(g, 298, 745, 158, "返回回忆录", WHITE, 8)
end

local function draw_page(ctx, g)
  local ms = app_state(ctx)
  if ms.page == "home" then draw_home(g, ms)
  elseif ms.page == "definition" then draw_definition(g, ms)
  elseif ms.page == "picker" then draw_picker(g, ms)
  elseif ms.page == "folders" then draw_folders(g, ms)
  elseif ms.page == "rename" then draw_rename(g, ms)
  elseif ms.page == "study" then draw_study(g, ms)
  elseif ms.page == "summary" then draw_summary(g, ms)
  else ms.page = "home" draw_home(g, ms) end
end

-- ==================== 命中检测与交互 ====================

local function go_back(ms)
  if ms.page == "home" then
    if ms.editing then
      ms.editing = false
      ms.query = ms.edit_buffer
      return true
    end
    return false
  elseif ms.page == "definition" then
    ms.page = "home"
  elseif ms.page == "picker" then
    ms.page = "definition"
    ms.notice = nil
  elseif ms.page == "folders" then
    ms.page = "home"
  elseif ms.page == "rename" then
    ms.editing = false
    ms.page = ms.return_page or "folders"
  elseif ms.page == "study" then
    ms.page = "folders"
  elseif ms.page == "summary" then
    ms.page = "folders"
  else
    ms.page = "home"
  end
  return true
end

local function home_tap(ctx, ms, x, y)
  if ms.editing then
    local key = hit_keyboard(x, y, ms)
    if key then handle_keyboard_key(ctx, ms, key) return true end

    if y >= 198 and y < 198 + #ms.suggestions * 54 then
      local index = math.floor((y - 198) / 54) + 1
      if ms.suggestions[index] then open_definition(ctx, ms, ms.suggestions[index]) end
      return true
    end

    if x >= 24 and x <= 456 and y >= 82 and y <= 144 then return true end
    return true
  end

  if x >= 24 and x <= 456 and y >= 82 and y <= 144 then
    ms.editing = true
    ms.edit_mode = "search"
    ms.edit_buffer = ms.query or ""
    ms.pressed_key = nil
    ms.notice = nil
    refresh_suggestions(ctx, ms)
    return true
  end

  if y >= 205 and y <= 258 and #ms.history > 0 then
    local index = math.floor((x - 24) / 109) + 1
    if index >= 1 and index <= #ms.history then open_definition(ctx, ms, ms.history[index]) end
    return true
  end

  if x >= 360 and y >= 680 then
    ms.page = "folders"
    ms.notice = nil
    return true
  end
  return false
end

local function definition_tap(ms, x, y)
  if x <= 62 and y <= 68 then return go_back(ms) end
  local first = ms.sense_scroll
  local y1 = 168
  for slot = 0, 1 do
    local sense_index = first + slot
    local data = ms.current_data
    if data and data.senses[sense_index] then
      local card_y = y1 + slot * 270
      if x >= 405 and x <= 460 and y >= card_y + 145 and y <= card_y + 205 then
        ms.pending_sense = sense_index
        ms.picker_saved_to = nil
        ms.picker_scroll = 0
        ms.notice = nil
        ms.page = "picker"
        return true
      end
    end
  end
  return false
end

local function picker_hit(ms, y)
  if y < 138 then return nil, nil end
  local slot = math.floor((y - 138) / 128) + 1
  if slot < 1 or slot > 4 then return nil, nil end
  local index = ms.picker_scroll + slot
  if index <= #ms.folders then return "folder", index end
  if index == #ms.folders + 1 then return "add", index end
  return nil, nil
end

local function picker_tap(ms, ctx, x, y)
  if x <= 62 and y <= 68 then return go_back(ms) end
  local kind, index = picker_hit(ms, y)
  if kind == "add" then
    local folder = add_folder(ms)
    ms.notice = "已创建“" .. folder.name .. "”，双击可改名"
    return true
  elseif kind == "folder" then
    local folder = ms.folders[index]
    local time = now_sec(ctx)
    if ms.last_tap_id == folder.id and time - ms.last_tap_time <= 1 then
      begin_rename(ms, folder.id, "picker")
    else
      save_pending_item(ms, folder)
      ms.last_tap_id = folder.id
      ms.last_tap_time = time
    end
    return true
  end
  return false
end

local function folder_grid_hit(ms, x, y)
  for slot = 1, 6 do
    local col = (slot - 1) % 2
    local row = math.floor((slot - 1) / 2)
    local left = col == 0 and 30 or 258
    local top = 88 + row * 220
    -- 覆盖文件夹图标、名称和词条数量，三处双击都能改名。
    if x >= left and x <= left + 192 and y >= top and y <= top + 202 then
      local index = ms.folder_scroll * 2 + slot
      if ms.folders[index] then return ms.folders[index] end
    end
  end
  return nil
end

local function folders_tap(ms, ctx, x, y)
  if x <= 62 and y <= 68 then return go_back(ms) end
  if x >= 350 and y <= 68 then
    local folder = add_folder(ms)
    begin_rename(ms, folder.id, "folders")
    return true
  end
  local folder = folder_grid_hit(ms, x, y)
  if folder then
    ms.last_opened_folder_id = folder.id
    ms.last_opened_folder_time = now_sec(ctx)
    ms.last_opened_folder_x = x
    ms.last_opened_folder_y = y
    begin_study(ms, folder.id)
    return true
  end
  -- 文件夹之外的空白区域返回搜索首页。
  ms.page = "home"
  ms.notice = nil
  return true
end

local function rename_tap(ctx, ms, x, y)
  if x <= 62 and y <= 68 then return go_back(ms) end
  if x >= 370 and y <= 68 then finish_rename(ms) return true end
  local candidate = rename_candidate_hit(ms, x, y)
  if candidate == "next" then
    local pages = math.max(1, math.ceil(#ms.rename_candidates / 5))
    ms.rename_candidate_page = ((ms.rename_candidate_page or 1) % pages) + 1
    return true
  elseif type(candidate) == "number" then
    commit_rename_candidate(ms, candidate)
    return true
  end
  local key = hit_keyboard(x, y, ms)
  if key then handle_keyboard_key(ctx, ms, key) return true end
  return true
end

local function hit_study_label(x, y)
  for i = 1, 3 do
    local lx, ly, lw, lh = study_label_rect(i)
    if x >= lx and x <= lx + lw and y >= ly and y <= ly + lh then return i end
  end
  return nil
end

local function study_tap(ms, ctx, x, y)
  if x <= 62 and y <= 68 then return go_back(ms) end
  local folder = find_folder(ms, ms.active_folder_id)
  if not folder or #folder.items == 0 then return true end

  if ms.study_stage >= 3 then
    local label = hit_study_label(x, y)
    if label then
      ms.review_results[tostring(ms.study_index)] = label
      ms.notice = nil
      return true
    end
    if ms.review_results[tostring(ms.study_index)] then
      next_study_item(ms, ctx)
    else
      ms.notice = "请先选择掌握情况"
    end
  else
    ms.study_stage = ms.study_stage + 1
  end
  return true
end

local function summary_tap(ms, x, y)
  -- 总结展示完成后，点击屏幕任意位置返回文件夹页面。
  ms.page = "folders"
  ms.notice = nil
  return true
end

local function handle_double_tap(ms, x, y, ctx)
  if ms.page == "picker" then
    local kind, index = picker_hit(ms, y)
    if kind == "folder" then begin_rename(ms, ms.folders[index].id, "picker") return true end
  elseif ms.page == "folders" then
    local folder = folder_grid_hit(ms, x, y)
    if folder then begin_rename(ms, folder.id, "folders") return true end
  elseif ms.page == "study" then
    -- 有些固件先发送一次 tap，再发送 double_tap；第一次 tap 已进入复习页，
    -- 因此在短时间内仍把第二次识别为“文件夹双击改名”。
    local opened_at = ms.last_opened_folder_time or -10
    local same_place = ms.last_opened_folder_x and ms.last_opened_folder_y
      and math.abs(x - ms.last_opened_folder_x) <= 36
      and math.abs(y - ms.last_opened_folder_y) <= 36
    if ms.last_opened_folder_id == ms.active_folder_id
      and same_place
      and now_sec(ctx) - opened_at <= 2 then
      begin_rename(ms, ms.active_folder_id, "folders")
      ms.last_opened_folder_id = nil
      return true
    end
    if ms.study_stage >= 3 then
      local label = hit_study_label(x, y)
      if label and ms.review_results[tostring(ms.study_index)] == label then
        ms.review_results[tostring(ms.study_index)] = nil
        return true
      end
    end
  end
  return false
end

local function scroll_page(ms, direction)
  if ms.page == "definition" then
    local data = ms.current_data
    local max_start = math.max(1, #data.senses - 1)
    if direction > 0 then ms.sense_scroll = math.min(max_start, ms.sense_scroll + 1)
    else ms.sense_scroll = math.max(1, ms.sense_scroll - 1) end
    return true
  elseif ms.page == "picker" then
    local max_scroll = math.max(0, #ms.folders + 1 - 4)
    if direction > 0 then ms.picker_scroll = math.min(max_scroll, ms.picker_scroll + 1)
    else ms.picker_scroll = math.max(0, ms.picker_scroll - 1) end
    return true
  elseif ms.page == "folders" then
    local rows = math.ceil(#ms.folders / 2)
    local max_scroll = math.max(0, rows - 3)
    if direction > 0 then ms.folder_scroll = math.min(max_scroll, ms.folder_scroll + 1)
    else ms.folder_scroll = math.max(0, ms.folder_scroll - 1) end
    return true
  end
  return false
end

local function handle_ok(ms, ctx)
  if ms.page == "home" then
    if ms.editing then submit_search(ctx, ms)
    else
      ms.editing = true
      ms.edit_mode = "search"
      ms.edit_buffer = ms.query or ""
      ms.pressed_key = nil
      refresh_suggestions(ctx, ms)
    end
  elseif ms.page == "study" then
    study_tap(ms, ctx, 240, 400)
  elseif ms.page == "summary" then
    ms.page = "folders"
  end
  return true
end

-- ==================== 框架生命周期 ====================

function on_load(ctx)
  app_state(ctx)
  local probe = open_shard_reader(ctx, "a")
  local readable = probe ~= nil
  if probe then probe:close() end
  ctx.log:info(
    "compact dictionary ready: " .. tostring(COMPACT_WORD_COUNT) ..
    ", A-shard readable=" .. tostring(readable)
  )
end


function on_input(ctx, ev)
  local ms = app_state(ctx)

  if ev.type == "key" and ev.phase == "down" then
    local handled = false
    if ms.page == "home" and ms.editing and ms.edit_mode == "search" then
      if ev.key == "up" then handled = kb_move(ms, -1, 0)
      elseif ev.key == "down" then handled = kb_move(ms, 1, 0)
      elseif ev.key == "left" then handled = kb_move(ms, 0, -1)
      elseif ev.key == "right" then handled = kb_move(ms, 0, 1)
      elseif ev.key == "ok" then handled = kb_press_focus(ctx, ms)
      elseif ev.key == "back" then handled = kb_back(ctx, ms) end
    elseif ev.key == "back" then
      handled = go_back(ms)
    elseif ev.key == "up" then
      handled = scroll_page(ms, -1)
    elseif ev.key == "down" then
      handled = scroll_page(ms, 1)
    elseif ev.key == "ok" then
      handled = handle_ok(ms, ctx)
    end
    if handled then ctx:invalidate() end
    return handled
  end

  if (ev.type == "pointer" and ev.phase == "up") then
    local gesture = ev.gesture

    if gesture == "double_tap" or gesture == "long" then
      if handle_double_tap(ms, ev.x, ev.y, ctx) then ctx:invalidate() return true end
      return true
    elseif gesture == "swipe_left" or gesture == "swipe_up" then
      if scroll_page(ms, 1) then ctx:invalidate() return true end
      return true
    elseif gesture == "swipe_down" then
      if scroll_page(ms, -1) then ctx:invalidate() return true end
      return true
    elseif gesture == "swipe_right" then
      if go_back(ms) then ctx:invalidate() return true end
      return true
    elseif gesture == "tap" then
      local handled = false
      if ms.page == "home" then handled = home_tap(ctx, ms, ev.x, ev.y)
      elseif ms.page == "definition" then handled = definition_tap(ms, ev.x, ev.y)
      elseif ms.page == "picker" then handled = picker_tap(ms, ctx, ev.x, ev.y)
      elseif ms.page == "folders" then handled = folders_tap(ms, ctx, ev.x, ev.y)
      elseif ms.page == "rename" then handled = rename_tap(ctx, ms, ev.x, ev.y)
      elseif ms.page == "study" then handled = study_tap(ms, ctx, ev.x, ev.y)
      elseif ms.page == "summary" then handled = summary_tap(ms, ev.x, ev.y) end
      if handled then ctx:invalidate() return true end
      return true
    end
  end
  return false
end

function on_draw(ctx, g)
  draw_page(ctx, g)
end
