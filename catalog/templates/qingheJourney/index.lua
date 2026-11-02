local PkgImage = require("pkg_image")
-- 清河问道·第一卷「药篓与旧令」：X4 Pro 触屏专用的关系驱动图文修仙游戏。

local STORY = {
  opening = {art="bg_village",chapter="序章·清河雨",title="三道脚印",
    lines={"阿梨的药炉熄了，白尾从窗下掠过。","残祠方向另有一串陌生脚印，正通往云岚。","祖父留下的旧药篓在你掌心发烫。","今夜带走它的人，也许会改写三个人的命。"},
    choices={{text="守住阿梨的药炉",next="ali_open",rel={ali=1}},{text="去残祠追那串脚印",next="shrine"},{text="跟着白尾穿过竹林",next="beast_open",rel={beast=1}}}},
  ali_open = {art="char_ali",chapter="序章·清河雨",title="药炉边的人",
    lines={"阿梨咳得发白，却把最后一包止血散塞给你。","“别因为我误了云岚招人。”她说得很轻。","你知道她从小最怕欠人情，","也知道这场病不像普通风寒。"},
    choices={{text="留下止血散，答应回来",next="shrine",flags={"ali_promise"},rel={ali=1}},{text="带她一起去残祠问个明白",next="shrine",flags={"ali_honest"},rel={ali=1}}}},
  shrine = {art="bg_shrine",chapter="序章·残祠",title="乌木令",
    lines={"破像掌心压着乌木令，令下是半页药经。","雨中青年先一步踏进祠门，自称沈照。","他看见药篓，神色像是认出了旧债。","“这枚令，会害死一个人。”他说。"},
    choices={{text="先问他是谁，不碰令牌",next="shen_open",rel={shen=1}},{text="拿起乌木令，逼他说明白",next="shen_open",flags={"has_token"}},{text="抄下药经残页，令牌留在原处",next="shen_open",flags={"has_page"}}}},
  beast_open = {art="char_linghu",chapter="序章·竹林",title="白尾引路",
    lines={"白尾被兽夹划破了腿，却没有逃。","它用爪子拨开泥土，露出一角药经残页。","随后它望向残祠，耳尖压低。","像在提醒你：那里的人比妖更难辨。"},
    choices={{text="替它包扎，再去残祠",next="shrine",flags={"beast_saved"},rel={beast=1}},{text="带走残页，先赶去云岚",next="gate",flags={"has_page"}}}},
  shen_open = {art="char_shenzhao",chapter="序章·残祠",title="失令之人",
    lines={"沈照承认自己在找令，却不肯说用途。","他只说沈家因一场疫火获罪，姐姐至今未归。","药经里记的正是同一种疫火。","雨停时，他替你挡开了追来的黑衣人。"},
    choices={{text="相信他一次，与他同上云岚",next="gate",flags={"shen_trust"},rel={shen=1}},{text="不交底，各走各的山道",next="gate",flags={"shen_distance"}}}},
  gate = {art="bg_gate",chapter="第一章·云岚门",title="外门牌",
    lines={"云岚只收一个人，沈照却把试炼名额让给你。","他低声说：令牌和药篓若落入执事手里，","清河疫火会被定成邪修遗祸，所有证据都没了。","你拿到外门牌，也拿到一桩不能说的秘密。"},
    choices={{text="入门后先追查疫火",next="arrival",flags={"entered"}},{text="先向执事坦白令牌",next="arrival",flags={"told_steward"}}}},
  arrival = {art="bg_path",chapter="第一章·外门夜",title="三封短笺",
    lines={"入门第一夜，三封短笺同时落到你案上。","阿梨病势变快；沈照约你查旧档；白尾在药园留下血印。","你不能把他们当成待刷新的差事。"},
    choices={{text="今夜先决定见谁",next="seek"}}},
  seek = {art="bg_path",chapter="第一章·未尽的话",title="今夜只能先走一条路",
    lines={"明日执事就会封存药经。","雨还在下，你带不走所有人的夜晚。","先听完谁的话，就会先欠下谁的债。"},
    choices={{text="去药园见阿梨",next="ali_visit",unless="seen_ali",tag="见阿梨"},{text="去旧档房见沈照",next="shen_visit",unless="seen_shen",tag="见沈照"},{text="循白尾脚印去后山",next="beast_visit",unless="seen_beast",tag="寻霜枝"},{text="回清河核对受害者名簿",next="victim_book",when="has_page",unless="victim_book",tag="清河名簿"},{text="摊开线索，拼一张案图",next="evidence_board",min_seen=2,tag="摊开案图"}}},
  victim_book = {art="bg_village",chapter="调查线·清河名簿",title="被划去的名字",
    lines={"清河祠后的名簿被雨水泡胀，十七个名字被朱砂划去。","守祠老人说他们都领过“净血散”，随后便被云岚带走。","末页盖着药堂副印——这已是不能再被说成谣言的证据。","老人不肯上山，却肯把名字念给你听。"},
    choices={{text="留下听完供词，带走完整名单",next="seek",flags={"victim_book","victim_testimony"},rel={ali=1},tag="保住名字",ripple="名簿上的朱砂像还没干透。"},{text="先带副印回山，免得证据再失",next="seek",flags={"victim_book","victim_seal"},tag="保住副印",ripple="副印在袖中发沉，像一口未闭的井。"}}},
  ali_visit = {art="char_ali",chapter="人物线·阿梨",title="药园里的谎",
    lines={"阿梨已被留作记名弟子。她承认病根在自己体内，","疫火每发一次，附近草药都会枯死。","她偷偷配出压制方，却少一味“回魂露”。","那味药，正藏在封存药经的夹层。"},
    choices={{text="陪她配一次压制方，先看病根",next="ali_distill",rel={ali=1}},{text="劝她把病情交给宗门处置",next="ali_report"}}},
  ali_distill = {art="char_ali",chapter="人物线·阿梨",title="火候之外",
    lines={"药炉里的赤叶草一触即黑。阿梨把银针递到你手中。","半页药经写着：疫火是被人种下的印。","临走时她塞进一张旧方——回魂露旁写着沈家封疫人。","留下印，还是先压住火，都会跟着你进药堂。"},
    choices={{text="留下印痕，冒险等它发作",next="seek",flags={"ali_mark","ali_cure","seen_ali"},rel={ali=1},tag="留印",ripple="阿梨把药篓又背紧了些。"},{text="先压住疫火，保她今晚无恙",next="seek",flags={"ali_cure","seen_ali"},tag="先压火",ripple="药炉的热气在袖口停了一会儿。"}}},
  ali_report = {art="char_ali",chapter="人物线·阿梨",title="不肯交出的手",
    lines={"阿梨听完只把药炉盖紧：送进药堂的人，名字会从簿上消失。","窗外纸鹤盘旋。她塞给你一张写着回魂露的旧方。","你可以替她争一夜，也可以把选择交还给她。"},
    choices={{text="毁掉纸鹤，给她一夜",next="seek",flags={"ali_hidden","seen_ali"},rel={ali=1},tag="护一夜",ripple="纸鹤的灰落进雨里。"},{text="把选择交还给阿梨",next="seek",flags={"ali_report","seen_ali"},rel={ali=1},tag="交还选择",ripple="阿梨没有道谢，只点了点头。"}}},
  shen_visit = {art="char_shenzhao",chapter="人物线·沈照",title="旧档房的名字",
    lines={"旧档写着：封疫的人是沈照的姐姐。","她带走乌木令，是为证明疫火源自药堂。","沈照把开匣木签交给你，等你的回答。"},
    choices={{text="与他共担风险，一起开档匣",next="shen_archive",rel={shen=1}},{text="要他先交出所有隐瞒",next="shen_oath"}}},
  shen_archive = {art="bg_archive",chapter="人物线·沈照",title="档匣第一层",
    lines={"匣中不是供词，而是药堂调运簿。","每一批净血散后，都有清河失踪者。","沈照点亮角落灵识火，把木签留给你。","抄下副本，或带走原件——都会惊动药堂。"},
    choices={{text="抄下调运簿，留下原件作饵",next="seek",flags={"shen_record","shen_copy","seen_shen"},rel={shen=1},tag="抄簿",ripple="墨迹未干，像还在渗血。"},{text="直接带走原件，今晚就揭发",next="seek",flags={"shen_record","shen_risk","seen_shen"},tag="夺簿",ripple="档匣空响一声，像缺了牙。"}}},
  shen_oath = {art="char_shenzhao",chapter="人物线·沈照",title="他没有说完的事",
    lines={"沈照承认：姐姐还活着，关在禁地。","他要用乌木令换她出来——清河的证据会随之消失。","他把木签留给你，没有求原谅。"},
    choices={{text="答应先救人，再谈证据",next="seek",flags={"shen_sister","seen_shen"},rel={shen=1},tag="先救人",ripple="沈照终于肯看你一眼。"},{text="告诉他不能再让别人被牺牲",next="seek",flags={"shen_pressure","seen_shen"},rel={shen=1},tag="止牺牲",ripple="灵识火偏了一下，又稳住。"}}},
  beast_visit = {art="char_linghu",chapter="人物线·白尾",title="不会说话的证人",
    lines={"白尾带你到废井。井壁刻着：疫火可转入灵兽血脉，代价是忘掉灵智。","它把前爪放在你的鞋尖——不是求救，是请你别替它决定。"},
    choices={{text="答应先找别的路，不拿它换人命",next="beast_river",rel={beast=1}},{text="请它留在身边，等真相揭开再决定",next="beast_cage"}}},
  beast_river = {art="bg_well",chapter="人物线·白尾",title="井下灵脉",
    lines={"钉上刻着药堂印，灵脉每跳一次，阿梨便咳血。","白尾能咬断一枚钉，却会惊动山门。","它在泥上划出两个字：霜枝。"},
    choices={{text="让霜枝咬断灵钉，留下痕迹",next="seek",flags={"beast_choice","beast_trace","seen_beast"},rel={beast=1},tag="断钉",ripple="井壁的回声像一声短鸣。"},{text="拓下印记，暂不惊动他们",next="seek",flags={"beast_mark","seen_beast"},tag="拓印",ripple="霜枝把背后重新交给你。"}}},
  beast_cage = {art="bg_well",chapter="人物线·白尾",title="旧笼未锁",
    lines={"废井旁旧笼里留着幼兽爪痕。","白尾曾被药堂养大，也曾看同类被当作药引。","它在泥上划出名字：霜枝——愿等你，不愿再被拥有。"},
    choices={{text="拆掉笼子，带走铁牌",next="seek",flags={"beast_wait","beast_tag","seen_beast"},rel={beast=1},tag="拆笼",ripple="铁牌在掌心发凉。"},{text="留下笼子，先记住位置",next="seek",flags={"beast_wait","seen_beast"},tag="记笼",ripple="霜枝耳尖动了动，没有躲开。"}}},
  evidence_board = {art="bg_path",chapter="第一章·案图",title="被撕开的路",
    lines={"钟楼地上摊着药经残页、调运簿与铁牌拓印。","它们本是一张图，被人撕开后才显得像三件麻烦。","先对上两处墨迹，明晨才有话可说。"},
    choices={{text="对照阿梨的药方与药经残页",next="map_ali",when="seen_ali",unless="map_ali",tag="案图·药方"},{text="对照沈照的调运簿与乌木令",next="map_shen",when="seen_shen",unless="map_shen",tag="案图·调运"},{text="对照霜枝的铁牌与井下灵脉",next="map_beast",when="seen_beast",unless="map_beast",tag="案图·灵脉"},{text="把完整案图封进钟楼钟芯",next="map_full",min_map=3,unless="final_map",tag="封存钟芯"},{text="收起案图，去钟楼等人",next="last_night",min_map=2}}},
  map_ali = {art="char_ali",chapter="案图·药方",title="同一种药渣",
    lines={"阿梨将药渣撒在残页边缘，墨迹立刻泛出暗红。","净血散并不是治疫的药，它先让血脉能承受疫火，","再把承受不住的人从名簿上划掉。若你抄过清河名簿，","那十七个名字终于有了同一份药方作证。"},
    choices={{text="圈出药渣的批次，写进案图",next="evidence_board",flags={"map_ali"},rel={ali=1}}}},
  map_shen = {art="char_shenzhao",chapter="案图·调运",title="同一枚副印",
    lines={"沈照把乌木令压在调运簿末页，封蜡纹路严丝合缝。","清河的净血散由药堂副印放行，却从未记入外门账。","这不是某个执事一时的恶意，而是一条被藏起来的路。","他问你：明晨念出这条路，还是先救路上的人。"},
    choices={{text="拓下副印，把经手人留在案图上",next="evidence_board",flags={"map_shen"},rel={shen=1}}}},
  map_beast = {art="char_linghu",chapter="案图·灵脉",title="同一根钉",
    lines={"铁牌的齿痕正好卡进井下灵脉的镇魂钉。","药堂没有只在村民身上试药；它还把疫火导进山脉，","让灵兽替人承受多余的痛。霜枝把爪按在拓印上，","像在告诉你：这张案图也该有它的一格。"},
    choices={{text="添上灵脉走向，不再把霜枝写成药引",next="evidence_board",flags={"map_beast"},rel={beast=1}}}},
  map_full = {art="bg_bell",chapter="案图·钟芯",title="没有无名页",
    lines={"三处墨迹终于在钟芯内侧合成一张完整的路图。","药渣、调运副印与灵脉镇魂钉，把清河与云岚连在一起。","你把案图封进钟芯，不是为了明晨赢一场争辩，","而是让后来的人能沿着它追问：谁曾被抹去。"},
    choices={{text="留下钟芯副本，带完整案卷去等人",next="last_night",flags={"final_map"},rel={ali=1,shen=1,beast=1}}}},
  last_night = {art="bg_bell",chapter="第一章·钟楼夜",title="进门以前",
    lines={"药堂的灯还亮着，执事却还没来拿人。","这是今夜最后一段不必逃跑的时间。","门后每多一句承诺，明晨就多一桩代价。"},
    choices={{text="去药园，听阿梨说完",next="last_ali",when="seen_ali",unless="last_ali_done"},{text="去档房，拆开沈照的旧信",next="last_shen",when="seen_shen",unless="last_shen_done"},{text="去井边，陪霜枝等一场雨",next="last_beast",when="seen_beast",unless="last_beast_done"},{text="带着承诺，推开药堂门",next="hearing",min_last=2,tag="推开药堂"}}},
  last_ali = {art="char_ali",chapter="钟楼夜·阿梨",title="药方上的空白",
    lines={"阿梨摊开药方：最后一味始终空着。","祖父故意没写——若药要用别人的命换，就不配有完整名字。","她把空白写成两行：药量，与试药人的名字。","明晨若她害怕，你是替她勇敢，还是只守住她开口的机会？"},
    choices={{text="答应只替她守住开口的机会",next="last_night",flags={"ali_voice","last_ali_done"},rel={ali=1},tag="守开口",ripple="阿梨把药篓背得更稳了。"},{text="承认自己也会怕，但不再瞒着她",next="last_night",flags={"ali_truth","last_ali_done"},rel={ali=1},tag="同怕",ripple="“明天我自己说。”她说。"}}},
  last_shen = {art="char_shenzhao",chapter="钟楼夜·沈照",title="姐姐没寄出的信",
    lines={"暗格里是一封没有署名的家书：若真相只能靠一个人去死，","那真相也会变成另一种药堂。","沈照第一次把姐姐的名字读完，灵识火微微亮起。","明晨，他是否还要把灵火推到所有人面前？"},
    choices={{text="请他先问姐姐愿不愿意留下证言",next="last_night",flags={"shen_consent","last_shen_done"},rel={shen=1},tag="问意愿",ripple="家书叠进袖中，像多了一点重量。"},{text="告诉他先活下来，证据可以一起再找",next="last_night",flags={"shen_patience","last_shen_done"},rel={shen=1},tag="先求活",ripple="沈照没有反驳，只把木签握紧。"}}},
  last_beast = {art="char_linghu",chapter="钟楼夜·霜枝",title="雨前的井口",
    lines={"霜枝伏在井沿，把旧铁牌推到你掌心。","它闻得见咬断镇魂钉后谁会追捕它。","雨点落下时它跳上横梁又回头——若逃便一起逃；若留，也不是为换一味药。"},
    choices={{text="把铁牌还给它，明晨由它自己决定",next="last_night",flags={"beast_consent","last_beast_done"},rel={beast=1},tag="还牌",ripple="霜枝没有躲进药篓。"},{text="收下铁牌，答应给它留一条退路",next="last_night",flags={"beast_shelter","last_beast_done"},rel={beast=1},tag="留退路",ripple="铁牌贴着脉搏，一下一下。"}}},
  hearing = {art="bg_medicine_hall",chapter="第二章·药堂灯",title="同一场疫火",
    lines={"你推开药堂门。档匣、残页与脉象指向同一件事：","药堂曾把疫火试在村民身上。","执事要收走所有东西，也要把阿梨带走。","你只能先亮出一样——亮出什么，就守什么。"},
    choices={{text="亮出完整案图，逼药堂逐页回应",next="act2_intro",when="final_map",flags={"stance_full"},rel={ali=1,shen=1,beast=1},tag="亮出案图",ripple="钟芯里的案图像还在发热。"},{text="亮出档匣，让旧案被当众拆开",next="act2_intro",when="shen_record",unless="final_map",flags={"stance_record"},tag="亮出旧档"},{text="念出清河名簿，不让人名被抹去",next="act2_intro",when="victim_book",unless="final_map",flags={"stance_victims"},rel={ali=1},tag="念出名簿",ripple="十七个名字在堂上站了一会儿。"},{text="先把回魂露交给阿梨",next="act2_intro",when="ali_cure",unless="final_map",flags={"stance_medicine"},tag="先救人"},{text="护住霜枝，带证据冲出药堂",next="act2_intro",when="beast_choice",unless="final_map",flags={"stance_beast"},tag="护住霜枝"},{text="暂时交出证据，换所有人活着",next="act2_intro",unless="final_map",flags={"stance_compromise"},tag="先求活"}}},
  act2_intro = {art="bg_council",chapter="第二章·停牌",title="外门除名",
    lines={"药堂没有当场杀人，只收走外门牌，把你们分开看管。","阿梨回药园，沈照锁进旧档，霜枝藏进药篓夹层。","明晨听审前，先留下能被看懂的信号——怕有人独自上台。"},
    choices={{text="分头留下安全信号",next="act2_watch",flags={"act2_started"}}}},
  act2_watch = {art="bg_path",chapter="第二章·停牌",title="先让人找得到你",
    lines={"钟楼下多了巡守。案图不能跟着任何一人一起断掉。","留下两处信号，再谈听审。"},
    choices={{text="给阿梨留一盏药炉暗火",next="watch_ali",unless="watch_ali_done"},{text="替沈照在窗下留木签",next="watch_shen",unless="watch_shen_done"},{text="让霜枝在兽道留下雨痕",next="watch_beast",unless="watch_beast_done"},{text="信号已齐，去准备听审",next="act2_seek",min_watch=2}}},
  watch_ali = {art="char_ali",chapter="停牌夜·药园",title="暗火不灭",
    lines={"阿梨把赤叶草埋进炉灰：熟悉药性的人找得到她。","她递来另一半药方——若她先被带走，别替她烧掉名字。"},
    choices={{text="记住暗火，转身去留下一处信号",next="act2_watch",flags={"watch_ali_done"},rel={ali=1},ripple="炉灰里的暗火只亮给你看。"}}},
  watch_shen = {art="char_shenzhao",chapter="停牌夜·档房",title="木签朝北",
    lines={"沈照把木签插在窗缝，尖端朝向禁地。","姐姐教的记号：人不求你来送死，只说门还没锁死。"},
    choices={{text="记下方位，转身去留下一处信号",next="act2_watch",flags={"watch_shen_done"},rel={shen=1},ripple="木签尖端轻轻偏了一下。"}}},
  watch_beast = {art="char_linghu",chapter="停牌夜·兽道",title="雨痕向山",
    lines={"霜枝扫出三道逆风雨痕——那是它自己选的退路。","你在最后一痕旁压下手印，没有拴回铁牌。"},
    choices={{text="把退路留给霜枝，再去别处",next="act2_watch",flags={"watch_beast_done"},rel={beast=1},ripple="雨痕很快就被新雨盖住一半。"}}},
  act2_seek = {art="bg_path",chapter="第二章·听审前夜",title="只能再救两桩事",
    lines={"夜只够走两条路。每走一条，就有一个人相信你不是来取证的。","另一条路上的人，只能靠信号找到你。"},
    choices={{text="潜回药园，帮阿梨找回药方底稿",next="act2_ali",unless="act2_ali_done"},{text="潜进档房，替沈照取出姐姐的灵识火",next="act2_shen",unless="act2_shen_done"},{text="顺灵脉下井，替霜枝拆掉最后一枚钉",next="act2_beast",unless="act2_beast_done"},{text="带着证据去钟楼会合",next="pre_council",min_act2=2}}},
  act2_ali = {art="char_ali",chapter="听审前夜·阿梨",title="药方底稿",
    lines={"灰烬里的原始药方：回魂露能救她，也会放大疫火印。","听审台服下，所有人看得见印从何来；今夜服下，她平安却少了证词。","阿梨把底稿一分为二，一半塞进你袖中。"},
    choices={{text="让阿梨在听审台自己作证",next="act2_seek",flags={"ali_testify","act2_ali_done"},rel={ali=1},tag="阿梨上台",ripple="袖中的药方还带着炉温。"},{text="先服药保命，不逼她再受一次",next="act2_seek",flags={"ali_safe","act2_ali_done"},rel={ali=1},tag="先保阿梨",ripple="阿梨咳了一声，没有再推辞。"}}},
  act2_shen = {art="char_shenzhao",chapter="听审前夜·沈照",title="姐姐的火",
    lines={"灵识火说：是她把疫火封进清河，因药堂要杀光全村。","揭开封印她会消散；不揭开，药堂永不认罪。","信里只有一句：别替我活成仇人。"},
    choices={{text="请她留下证言，哪怕灵火会散",next="act2_seek",flags={"shen_testify","act2_shen_done"},rel={shen=1},tag="灵火作证",ripple="袖中的火亮了一下，又压低。"},{text="先护住灵火，寻找活下去的办法",next="act2_seek",flags={"shen_safe","act2_shen_done"},rel={shen=1},tag="护住灵火",ripple="沈照第一次没有急着往前冲。"}}},
  act2_beast = {art="char_linghu",chapter="听审前夜·霜枝",title="最后一枚钉",
    lines={"最后一枚镇魂钉：咬断则全山看见疫火流向，药堂也会循气找来。","霜枝把铁牌压在你掌心——它听懂了你没有替它下令。"},
    choices={{text="让霜枝自己决定是否咬断",next="act2_seek",flags={"beast_testify","act2_beast_done"},rel={beast=1},tag="霜枝自决",ripple="地脉像一根绷紧的弦。"},{text="带它离开，先活下去",next="act2_seek",flags={"beast_safe","act2_beast_done"},rel={beast=1},tag="先走",ripple="霜枝跳回肩头，没有回头。"}}},
  pre_council = {art="bg_bell",chapter="第三章·钟楼",title="上台以前",
    lines={"门内已有人翻卷宗。你还剩一口气，去问愿意上台的人。","别把勇气想当然地塞进谁手里——至少听完两个人的回答。"},
    choices={{text="问阿梨：你还想亲口说吗",next="pre_ali",when="act2_ali_done",unless="pre_ali_done"},{text="问沈照：姐姐愿意留下什么",next="pre_shen",when="act2_shen_done",unless="pre_shen_done"},{text="问霜枝：它愿不愿留下爪印",next="pre_beast",when="act2_beast_done",unless="pre_beast_done"},{text="推开钟楼门，让愿意的人开口",next="council",min_pre=2}}},
  pre_ali = {art="char_ali",chapter="钟楼·阿梨",title="不是替我说",
    lines={"阿梨仍怕那道疫火印被众人看见，却不愿再被替她沉默。","若开口，她要先念试药人的名字，再说自己的病。"},
    choices={{text="答应先把名字交给她",next="pre_council",flags={"pre_ali_done"},rel={ali=1},ripple="药方上的空白被她按住。"}}},
  pre_shen = {art="char_shenzhao",chapter="钟楼·沈照",title="火会自己说",
    lines={"沈照不替姐姐回答：她若愿意，火会偏向卷宗。","火焰动了一下，停在门槛前——她终于被问了一次。"},
    choices={{text="让火停在门前，等她自己决定",next="pre_council",flags={"pre_shen_done"},rel={shen=1},ripple="门槛前多了一点热。"}}},
  pre_beast = {art="char_linghu",chapter="钟楼·霜枝",title="爪印不是口供",
    lines={"霜枝绕钟楼一圈，才把爪悬在泥上：留下爪印后，谁保证它不再是一味药？","你只能答应先拆笼门——没有别的保证。"},
    choices={{text="告诉它：没有保证，但你会先拆掉笼门",next="pre_council",flags={"pre_beast_done"},rel={beast=1},ripple="爪印终于落下，很浅。"}}},
  council = {art="bg_gate",chapter="第三章·钟楼听审",title="谁的证词",
    lines={"雨停了。药方、灵火、灵脉与旧档都在手中，","却护不住所有人同时站上听审台。","谁开口，谁就要被所有人看见。"},
    choices={{text="让阿梨先说，她有权说自己的病",next="ending_ali",when="ali_testify",unless="final_map",flags={"final_ali"},tag="阿梨结局"},{text="让沈照的姐姐留下证言",next="ending_shen",when="shen_testify",unless="final_map",flags={"final_shen"},tag="旧案结局"},{text="让霜枝决定是否展示灵脉",next="ending_beast",when="beast_testify",unless="final_map",flags={"final_beast"},tag="霜枝结局"},{text="三人共同作证，互相补全真相",next="ending_true",min_act2=3,min_rel=2,unless="final_map",flags={"final_together"},tag="共证"},{text="将案图与三份证言存入云岚行记",next="ending_casebook",when="final_map",min_act2=3,min_map=3,min_rel=2,flags={"final_casebook"},tag="案卷"},{text="带走还能带走的人",next="ending_wanderer",tag="离山"}}},
  atlas = {art="bg_path",chapter="行记·云岚之后",title="下一段路",
    lines={"第一卷的结局已写入行记。雨停之后，云岚没有恢复原样，","而你们也没有回到最初的自己。","药堂空出的职位、未解的禁地与山下的新病户，","都在等你决定下一步走向哪里。"},
    choices={{text="续写第三卷：筑基前夜",next="v3_intro",when="volume3_unlocked",action="start_v3"},{text="重走第二卷：云岚外门",next="v2_intro",when="volume2_unlocked",action="start_v2"},{text="重走第一卷：清河疫火",next="opening",action="restart_v1"}}},
  v2_intro = {art="bg_gate",chapter="第二卷·云岚外门",title="留察弟子",
    lines={"三个月后，药堂旧案暂封，你被留在外门观察。","执事给一枚临时药牌：一份药材，或一次人情——用掉就不能两全。","上一卷你守住的立场，仍会在今夜压着你的手。"},
    choices={{text="接下药牌，去看外门的新案",next="v2_seek",flags={"v2_started"}}}},
  v2_seek = {art="bg_path",chapter="第二卷·外门差事",title="两难急报",
    lines={"药园病苗、禁地来信、夜巡失踪——同一枚未注销的药堂印。","你带不走三份完美答案。走两步，就得在评议台上承认舍弃了哪一步。"},
    choices={{text="去药园，与阿梨处理病苗",next="v2_ali",unless="v2_ali_done"},{text="去禁地边缘，回应沈照的来信",next="v2_shen",unless="v2_shen_done"},{text="参加夜巡，寻找霜枝留下的爪痕",next="v2_beast",unless="v2_beast_done"},{text="回外门参加去留评议",next="v2_council",min_v2=2}}},
  v2_ali = {art="bg_garden",chapter="外门线·阿梨",title="病苗不是病",
    lines={"幼苗同时枯萎——疫火逆印。","烧掉灵药可救园，却耗尽药牌；留下逆印可追暗室，苗会死一批。","做了前者，评议就只能以药园为证；做了后者，便没有“救园”可交。"},
    choices={{text="烧掉灵药，先救药园",next="v2_seek",herb=-1,flags={"v2_ali_save","v2_ali_done"},rel={ali=1},tag="耗药救园",ripple="药牌一热，灵药成了灰。"},{text="留下逆印，追查暗室",next="v2_seek",flags={"v2_ali_trace","v2_ali_done"},rel={ali=1},tag="追暗室",ripple="枯苗的气味像一条细线。"}}},
  v2_shen = {art="bg_forbidden",chapter="外门线·沈照",title="禁地回信",
    lines={"坐标旁写着：别一个人来。灵识碎片能证明药堂仍在运作，","却要耗一次人情才能取出。用人情，便欠执事一桩无法拒的差；","不用，就只剩一张拓下的坐标，难逼宗门认错。"},
    choices={{text="动用人情，取出灵识碎片",next="v2_seek",favor=-1,flags={"v2_shen_proof","v2_shen_done"},rel={shen=1},tag="耗情取证",ripple="人情牌裂开一道细纹。"},{text="不惊动执事，先拓下坐标",next="v2_seek",flags={"v2_shen_map","v2_shen_done"},rel={shen=1},tag="只留坐标",ripple="石壁冷得像不肯开口。"}}},
  v2_beast = {art="bg_cloud_stream",chapter="外门线·霜枝",title="夜巡空位",
    lines={"兽道上：新鲜脚印，与药堂铁牌划痕。","救人则铁牌将被雨水冲走；留牌则可能错过夜巡者最后的呼救。","两边都是证据，也是人命——不能两全。"},
    choices={{text="先救夜巡者，霜枝带路",next="v2_seek",flags={"v2_beast_save","v2_beast_done"},rel={beast=1},tag="先救人",ripple="铁牌的气味被雨冲淡了。"},{text="留下铁牌证据，再追踪",next="v2_seek",flags={"v2_beast_tag","v2_beast_done"},rel={beast=1},tag="留铁牌",ripple="脚印很快被新泥盖住。"}}},
  v2_council = {art="bg_council",chapter="第二卷·去留评议",title="外门牌归谁",
    lines={"执事说外门牌可随时收回。","你今夜舍弃了什么，台面上就只剩什么可交。","选一种立场，就要承认另一种安全已经放弃。"},
    choices={{text="以药园为证，争取药堂留察",next="ending_v2_medicine",when="v2_ali_save",tag="药圃结局"},{text="以禁地为证，要求公开追查",next="ending_v2_truth",when="v2_shen_proof",tag="禁地结局"},{text="以夜巡为证，申请云涧巡行",next="ending_v2_wild",when="v2_beast_save",tag="云涧结局"},{text="暂不站队，保留外门牌",next="ending_v2_wait",tag="暂留"}}},
  ending_v2_medicine = {art="bg_garden",chapter="第二卷结局·药圃",title="留在火边",lines={"你烧掉了灵药、救下药园，因而只剩这条路可走。","阿梨接过临时钥匙：任何药方都要写下试药人的名字。","云岚没有变好，但有人开始不再沉默。"},ending=true},
  ending_v2_truth = {art="bg_forbidden",chapter="第二卷结局·禁地",title="把门推开",lines={"你耗尽人情取出碎片，才把禁地证据送上长老会。","沈照没有等来姐姐，只等来正式追查与矿脉钥匙。","下一卷的路，比云岚更深——因为你选了逼问，不是安稳。"},ending=true},
  ending_v2_wild = {art="bg_cloud_stream",chapter="第二卷结局·云涧",title="夜巡新路",lines={"你先救人，铁牌被雨冲淡，却换来一条不在图上的兽道。","霜枝跑在前面又回头：云涧旧笼与灵脉还在跳动。","这是证词的开头，也是你放弃“铁证”的代价。"},ending=true},
  ending_v2_wait = {art="bg_council",chapter="第二卷结局·暂留",title="未落的牌",lines={"你没有交出任何一边的完整证据，只保住了外门牌。","身后还有人需要时间——药牌灵光未熄，下次会更难。"},ending=true},
  v3_intro = {art="bg_vein",chapter="第三卷·筑基前夜",title="矿脉开门",
    lines={"矿脉自行裂开。长老会要你筑基封疫；沈照说那会重演旧案。","阿梨有慢药，霜枝闻见笼中呼救。","你只能把一种选择刻进经脉——另外两种，将成为别人的路。"},
    choices={{text="接下矿脉令，先看清代价",next="v3_seek",flags={"v3_started"}}}},
  v3_seek = {art="bg_vein",chapter="第三卷·矿脉前夜",title="只能认一种根",
    lines={"慢药、共阵、兽道——每条路都会改写你是谁。","走两条，是为了看清代价；入脉时，仍只能认下一种根。"},
    choices={{text="去药室，试炼阿梨的慢药法",next="v3_ali",unless="v3_ali_done"},{text="去矿脉口，重绘沈照的旧阵",next="v3_shen",unless="v3_shen_done"},{text="去兽道，与霜枝面对笼锁",next="v3_beast",unless="v3_beast_done"},{text="带着准备进入矿脉",next="v3_gate",min_v3=2}}},
  v3_ali = {art="bg_pharmacy",chapter="筑基法·阿梨",title="慢药入脉",
    lines={"慢药把疫火拆细，筑基要慢数年，也无法一口封脉。","饮下，就是承认有些路不够快、却不再拿别人试药。","只记方不饮，则这条根尚未认下。"},
    choices={{text="饮下慢药，留下更长的路",next="v3_seek",flags={"v3_ali_slow","v3_ali_done"},rel={ali=1},tag="认慢药",ripple="药印在手背发热。"},{text="记下药方，先不饮药",next="v3_seek",flags={"v3_ali_formula","v3_ali_done"},rel={ali=1},tag="只记方",ripple="药碗未凉，你没有端起。"}}},
  v3_shen = {art="bg_array",chapter="筑基法·沈照",title="旧阵重绘",
    lines={"旧阵能立刻封脉，代价是一人独担余毒——沈照说那人是他自己。","改成两半阵眼，便是拒绝再让任何人独自站满。","允他守阵而留退路，则共阵之根未成。"},
    choices={{text="和他一起改阵，拒绝单人承担",next="v3_seek",flags={"v3_shen_shared","v3_shen_done"},rel={shen=1},tag="认共阵",ripple="阵眼裂成两半，风灌进来。"},{text="允许他守阵，但留下退路",next="v3_seek",flags={"v3_shen_guard","v3_shen_done"},rel={shen=1},tag="留退路",ripple="一盏灯灭了，另一盏还亮着。"}}},
  v3_beast = {art="bg_cages",chapter="筑基法·霜枝",title="笼门之后",
    lines={"笼锁与矿脉同源。霜枝可用灵智开尽笼门，却可能失去化形。","把选择还给它，兽道才能成你的根；请它留力先救人，则根在别处。"},
    choices={{text="告诉霜枝，选择属于它自己",next="v3_seek",flags={"v3_beast_free","v3_beast_done"},rel={beast=1},tag="认兽道",ripple="笼锁接连轻响。"},{text="请它留下力量，先救更多人",next="v3_seek",flags={"v3_beast_power","v3_beast_done"},rel={beast=1},tag="留力",ripple="霜枝把爪从锁上移开。"}}},
  v3_gate = {art="bg_vein",chapter="第三卷·筑基",title="最后一道脉",
    lines={"中心只有写满名字的旧试药簿。","你认下的根会决定云岚以后如何承受裂缝——","慢药、共阵、兽道，三选一；若三人印记齐备，也可合为一路。"},
    choices={{text="以慢药筑基，先让所有名字被看见",next="ending_v3_medicine",when="v3_ali_slow",unless="v3_root_picked",flags={"v3_root_picked"},tag="终局·慢火"},{text="以共阵筑基，谁也不独自站在阵眼",next="ending_v3_shared",when="v3_shen_shared",unless="v3_root_picked",flags={"v3_root_picked"},tag="终局·共阵"},{text="以兽道筑基，先打开所有笼门",next="ending_v3_free",when="v3_beast_free",unless="v3_root_picked",flags={"v3_root_picked"},tag="终局·兽道"},{text="带着三人的印记，一起入脉",next="ending_v3_true",min_v3=3,min_rel=2,unless="v3_root_picked",flags={"v3_root_picked"},tag="终局·问道"}}},
  ending_v3_medicine = {art="bg_pharmacy",chapter="终卷结局·慢火",title="筑基未急",lines={"你认下慢药为根，放弃了速封矿脉的捷径。","药印留住被抹去的名字；阿梨在矿外开起新药房。","后来的人终于不必为修行先交出自己。"},ending=true},
  ending_v3_shared = {art="bg_array",chapter="终卷结局·共阵",title="两半阵眼",lines={"你认下共阵为根，拒绝再让一人独站阵眼。","姐姐的灵火散去，却不再无名；云岚多了一条共修规矩。","你的筑基，是与人并肩的开始。"},ending=true},
  ending_v3_free = {art="bg_cages",chapter="终卷结局·兽道",title="霜枝化形",lines={"你认下兽道为根，笼门全开。","霜枝是否化形不再需要许可；山比从前难管，也更像活着。"},ending=true},
  ending_v3_true = {art="bg_vein",chapter="终卷结局·问道",title="清河之外",lines={"你把药印、阵图与兽道合为一路，不单取其中一种捷径。","阿梨、沈照与霜枝走在前方，又都回头等你。","清河问道，至此终于有了后来。"},ending=true},
  ending_ali = {art="char_ali",chapter="结局·药火未熄",title="阿梨的路",lines={"因你让她在听审台自己作证，回魂露放大了印记，也救下了她。","她未原谅你曾替她冒险，却在离山船上接过新药篓。","“下次，我自己选。”——这条路，从她开口的那一刻定下。"},ending=true},
  ending_shen = {art="char_shenzhao",chapter="结局·旧案重开",title="沈照的名字",lines={"因你请灵火留下证言，沈照当众念出姐姐的名字。","旧案重开，他也随之被逐出外门。","木签留给你：真相不是他的私产，是你们一起守住的。"},ending=true},
  ending_beast = {art="char_linghu",chapter="结局·白尾无言",title="灵兽的选择",lines={"因你把咬钉的决定还给霜枝，疫火沉入它的血脉。","它忘了你的名字，却仍在桥边等雨——你不曾把它写成药引。"},ending=true},
  ending_true = {art="bg_bell",chapter="结局·共证",title="云岚雨霁",lines={"因三人线与承诺齐备，阿梨、沈照、霜枝同台补全真相。","药堂再不能把任何一个人写成代价。","你们未立刻变强，却各自得到选择未来的权利。"},ending=true},
  ending_casebook = {art="bg_bell",chapter="结局·案卷",title="钟芯未冷",lines={"因完整案图封进钟芯，三份证言与名簿一并写入行记。","药堂无法再把罪写成无主疫火；他们各自署名，留下追问的路。"},ending=true},
  ending_wanderer = {art="bg_path",chapter="结局·未完",title="带着问题上路",lines={"你选择带走还能带走的人，焚药经离山。","真相未终——因你拒绝再把任何人送上唯一的听审台。"},ending=true},
}

-- Preview font is 20px with textBaseline=top; CJK font boxes are ~28px tall.
local HEADER_PITCH=28
local LINE_PITCH=44
local LINES_PER_PAGE=2
-- All story XICs are authored at 448×230; never stretch to a flatter slot.
local ART_W,ART_H=448,230
local function remember(s,text) s.history[#s.history+1]=text if #s.history>18 then table.remove(s.history,1) end end
local function game(ctx)
  local s=ctx.state.qinghe
  if not s then s={} ctx.state.qinghe=s end
  s.chronicle=s.chronicle or {endings={},chapters={}}
  s.chronicle.endings=s.chronicle.endings or {};s.chronicle.chapters=s.chronicle.chapters or {};s.chronicle.awards=s.chronicle.awards or {};s.chronicle.progress=s.chronicle.progress or {realm=0,insight=0,post="清河散修"};s.chronicle.bonds=s.chronicle.bonds or {ali=0,shen=0,beast=0};s.chronicle.tags=s.chronicle.tags or {}
  if not STORY[s.node_id] then s.node_id="opening" end
  s.schema_version=8;s.flags=s.flags or {};s.history=s.history or {};s.rel=s.rel or {ali=0,shen=0,beast=0};s.resources=s.resources or {herb=0,favor=0};s.ending=s.ending or nil;s.show_history=s.show_history or false
  s.page=s.page or 0;s.reading_done=s.reading_done or false;s.ripple=s.ripple or nil;s.tip_seen=s.tip_seen or false
  return s
end
local function current(s) return STORY[s.node_id] end
local function seen_count(s) local n=0 for _,k in ipairs({"seen_ali","seen_shen","seen_beast"}) do if s.flags[k] then n=n+1 end end return n end
local function act2_count(s) local n=0 for _,k in ipairs({"act2_ali_done","act2_shen_done","act2_beast_done"}) do if s.flags[k] then n=n+1 end end return n end
local function watch_count(s) local n=0 for _,k in ipairs({"watch_ali_done","watch_shen_done","watch_beast_done"}) do if s.flags[k] then n=n+1 end end return n end
local function pre_count(s) local n=0 for _,k in ipairs({"pre_ali_done","pre_shen_done","pre_beast_done"}) do if s.flags[k] then n=n+1 end end return n end
local function last_count(s) local n=0 for _,k in ipairs({"last_ali_done","last_shen_done","last_beast_done"}) do if s.flags[k] then n=n+1 end end return n end
local function map_count(s) local n=0 for _,k in ipairs({"map_ali","map_shen","map_beast"}) do if s.flags[k] then n=n+1 end end return n end
local function v2_count(s) local n=0 for _,k in ipairs({"v2_ali_done","v2_shen_done","v2_beast_done"}) do if s.flags[k] then n=n+1 end end return n end
local function v3_count(s) local n=0 for _,k in ipairs({"v3_ali_done","v3_shen_done","v3_beast_done"}) do if s.flags[k] then n=n+1 end end return n end
local function min_relation(s) return math.min(s.rel.ali or 0,s.rel.shen or 0,s.rel.beast or 0) end
local function ending_count(s) local n=0 for _,id in ipairs({"ending_ali","ending_shen","ending_beast","ending_true","ending_casebook","ending_wanderer"}) do if s.chronicle.endings[id] then n=n+1 end end return n end
local function realm_label(s) return (s.chronicle.progress.realm or 0)>=2 and "筑基" or ((s.chronicle.progress.realm or 0)>=1 and "炼气" or "凡骨") end
local function bond_word(n) if (n or 0)>=3 then return "并肩" elseif (n or 0)>=1 then return "信任" else return "生疏" end end
local function bond_header(s) return "阿梨·"..bond_word(s.rel.ali).."  沈照·"..bond_word(s.rel.shen).."  霜枝·"..bond_word(s.rel.beast) end
local function chapter_record(s)
  local c=s.chronicle.chapters
  local out={}
  if c.volume1 then out[#out+1]="清河疫火" end
  if c.volume2 then out[#out+1]="云岚外门" end
  if s.chronicle.volume3_unlocked then out[#out+1]="筑基前夜" end
  return #out>0 and table.concat(out,"、") or "尚未写入卷章"
end
local function ending_record(s)
  local labels={ending_ali="药火",ending_shen="旧案",ending_beast="白尾",ending_true="共证",ending_casebook="案卷",ending_wanderer="未完",ending_v2_medicine="药圃",ending_v2_truth="禁地",ending_v2_wild="云涧",ending_v2_wait="留察",ending_v3_medicine="慢火",ending_v3_shared="共阵",ending_v3_free="兽道",ending_v3_true="问道"}
  local out={}
  for _,id in ipairs({"ending_ali","ending_shen","ending_beast","ending_true","ending_casebook","ending_wanderer","ending_v2_medicine","ending_v2_truth","ending_v2_wild","ending_v2_wait","ending_v3_medicine","ending_v3_shared","ending_v3_free","ending_v3_true"}) do if s.chronicle.endings[id] then out[#out+1]=labels[id] end end
  if #out==0 then return "尚无结局" end
  if #out>6 then return table.concat({out[1],out[2],out[3],out[4],out[5],out[6]},"、").."等"..#out.."种" end
  return table.concat(out,"、")
end
local function tag_record(s)
  local tags=s.chronicle.tags or {}
  if #tags==0 then return "尚无关键选择" end
  local start=math.max(1,#tags-5)
  local out={}
  for i=start,#tags do out[#out+1]=tags[i] end
  return table.concat(out," · ")
end
local function stance_lead(s)
  local stance=s.chronicle.last_stance
  if stance=="full" then return "钟芯案图仍在——药堂抹不掉那张路。" end
  if stance=="victims" then return "十七个名字还压在袖中，外门不敢当它们是谣言。" end
  if stance=="record" then return "旧档封蜡已裂，禁地那边仍欠一个回答。" end
  if stance=="medicine" then return "回魂露救下了火种，也让药堂盯得更紧。" end
  if stance=="beast" then return "霜枝的爪印还留在药堂门槛上。" end
  if stance=="compromise" then return "你曾先求活——今夜的药牌更沉。" end
  return nil
end
local function atlas_lines(s)
  local stance=s.chronicle.last_stance
  if stance=="full" then return {"完整案图被封进钟楼钟芯，云岚多了一份不能销毁的行记。","它不替任何人原谅，也不允许任何人继续无名。","阿梨、沈照与霜枝各自带走一页副本。","下一卷仍要为这些名字付出代价。"} end
  if stance=="victims" then return {"你念出的十七个名字被抄进外门行记。","药堂再也不能把清河写成一场无主的疫祸。","阿梨把名簿副本留在药篓最底层。","下一卷里，每一个被救下的人都有了来处。"} end
  if stance=="record" then return {"旧档的封蜡被当众拆开，沈家的名字不再只在暗处。","禁地仍锁着姐姐留下的灵识火。","药堂空职、未解禁地与山下新病户，","都在等你决定下一步。"} end
  if stance=="medicine" then return {"回魂露保住了阿梨的火种，也让药堂看到她仍可被利用。","她把药方拆成两页：一页救人，一页追问来处。","药堂空职、未解禁地与山下新病户，","都在等你决定下一步。"} end
  if stance=="beast" then return {"霜枝的爪印划过药堂门槛，山里开始有人记起旧笼。","它仍会在雨夜竖起耳朵，等你别替它下令。","药堂空职、未解禁地与山下新病户，","都在等你决定下一步。"} end
  return {"第一卷的结局已写入行记。雨停之后，云岚没有恢复原样。","你们也没有回到最初的自己。","药堂空职、未解禁地与山下新病户，","都在等你决定下一步。"}
end
local function node_lines(s)
  if s.node_id=="atlas" then return atlas_lines(s) end
  if s.node_id=="v2_intro" then
    local lead=stance_lead(s)
    local lines={}
    if lead then lines[#lines+1]=lead end
    for _,line in ipairs(STORY.v2_intro.lines) do lines[#lines+1]=line end
    return lines
  end
  return current(s).lines or {}
end
local function sync_reading(s)
  local lines=node_lines(s)
  local total=#lines
  if total<=0 then s.page=0;s.reading_done=true;return end
  local pages=math.max(1,math.ceil(total/LINES_PER_PAGE))
  if s.page>(pages-1) then s.page=pages-1 end
  s.reading_done=(s.page+1)*LINES_PER_PAGE>=total
end
local function page_lines(s)
  local lines=node_lines(s)
  local start=s.page*LINES_PER_PAGE+1
  local out={}
  for i=start,math.min(#lines,start+LINES_PER_PAGE-1) do out[#out+1]=lines[i] end
  return out
end
local function can_show(s,c)
  if c.when and not s.flags[c.when] then return false end
  if c.unless and s.flags[c.unless] then return false end
  if c.min_seen and seen_count(s)<c.min_seen then return false end
  if c.min_act2 and act2_count(s)<c.min_act2 then return false end
  if c.min_watch and watch_count(s)<c.min_watch then return false end
  if c.min_pre and pre_count(s)<c.min_pre then return false end
  if c.min_last and last_count(s)<c.min_last then return false end
  if c.min_map and map_count(s)<c.min_map then return false end
  if c.min_v2 and v2_count(s)<c.min_v2 then return false end
  if c.min_v3 and v3_count(s)<c.min_v3 then return false end
  if c.min_rel and min_relation(s)<c.min_rel then return false end
  if c.herb and (s.resources.herb or 0)+c.herb<0 then return false end
  if c.favor and (s.resources.favor or 0)+c.favor<0 then return false end
  return true
end
local function choice_label(c)
  local text=c.text
  if c.herb and c.herb<0 then text=text.." ·耗药" end
  if c.favor and c.favor<0 then text=text.." ·耗人情" end
  return text
end
local function choices(s)
  local out={}
  for _,c in ipairs(current(s).choices or {}) do if can_show(s,c) then out[#out+1]=c end end
  if #out>4 then
    local capped={}
    for i=1,#out do
      if #capped>=4 then break end
      local soft=false
      if out[i].flags then for _,f in ipairs(out[i].flags) do if f=="stance_compromise" then soft=true end end end
      if out[i].next=="ending_wanderer" then soft=true end
      if soft then
        -- fill later
      else
        capped[#capped+1]=out[i]
      end
    end
    for i=1,#out do
      if #capped>=4 then break end
      local seen=false
      for _,x in ipairs(capped) do if x==out[i] then seen=true break end end
      if not seen then capped[#capped+1]=out[i] end
    end
    out=capped
  end
  return out
end
local function enter(s,id)
  s.node_id=id;s.show_history=false;s.page=0;s.reading_done=false
  sync_reading(s);s.ui_choice_count=#choices(s)
  if STORY[id].ending then
    s.ending=id;s.chronicle.endings[id]=true;s.chronicle.last_ending=id
    for who,value in pairs(s.rel) do s.chronicle.bonds[who]=math.max(s.chronicle.bonds[who] or 0,value or 0) end
    if string.sub(id,1,10)=="ending_v2_" then
      s.chronicle.chapters.volume2=true;s.chronicle.volume3_unlocked=true;s.flags.volume3_unlocked=true
      if not s.chronicle.awards.volume2 then s.chronicle.awards.volume2=true;s.chronicle.progress.insight=(s.chronicle.progress.insight or 0)+1 end
      s.chronicle.progress.post=({ending_v2_medicine="药圃执记",ending_v2_truth="禁地听录",ending_v2_wild="云涧巡行",ending_v2_wait="外门留察"})[id] or s.chronicle.progress.post
    elseif string.sub(id,1,10)=="ending_v3_" then
      s.chronicle.progress.realm=2;s.chronicle.progress.post="云岚行走"
      if not s.chronicle.awards.volume3 then s.chronicle.awards.volume3=true;s.chronicle.progress.insight=(s.chronicle.progress.insight or 0)+1 end
    else
      s.chronicle.progress.realm=math.max(1,s.chronicle.progress.realm or 0);s.chronicle.progress.post="外门候补"
      if not s.chronicle.awards.volume1 then s.chronicle.awards.volume1=true;s.chronicle.progress.insight=(s.chronicle.progress.insight or 0)+1 end
      s.chronicle.chapters.volume1=true;s.chronicle.volume2_unlocked=true;s.flags.volume2_unlocked=true
      if s.flags.stance_full then s.chronicle.last_stance="full"
      elseif s.flags.stance_victims then s.chronicle.last_stance="victims"
      elseif s.flags.stance_record then s.chronicle.last_stance="record"
      elseif s.flags.stance_medicine then s.chronicle.last_stance="medicine"
      elseif s.flags.stance_beast then s.chronicle.last_stance="beast"
      else s.chronicle.last_stance="compromise" end
    end
  end
  remember(s,STORY[id].title)
end
local function begin_volume(s,volume)
  local bonds=s.chronicle.bonds or {ali=0,shen=0,beast=0}
  s.flags={};s.history={};s.rel=volume==1 and {ali=0,shen=0,beast=0} or {ali=bonds.ali or 0,shen=bonds.shen or 0,beast=bonds.beast or 0};s.resources={herb=volume==2 and 1 or 0,favor=volume==2 and 1 or 0};s.ending=nil;s.show_history=false;s.page=0;s.reading_done=false;s.ripple=nil
  if volume==1 then s.chronicle.tags={} end
  if volume==3 then s.node_id="v3_intro";s.flags.volume3_unlocked=s.chronicle.volume3_unlocked;remember(s,"第三卷：筑基前夜")
  elseif volume==2 then s.node_id="v2_intro";s.flags.volume2_unlocked=s.chronicle.volume2_unlocked;remember(s,"第二卷：云岚外门")
  else s.node_id="opening";remember(s,"第一卷：清河疫火") end
  sync_reading(s);s.ui_choice_count=#choices(s)
end
local function choose(s,i)
  local c=choices(s)[i] if not c then return false end
  if c.flags then for _,f in ipairs(c.flags) do s.flags[f]=true end end
  if c.rel then for who,delta in pairs(c.rel) do s.rel[who]=(s.rel[who] or 0)+delta end end
  s.resources.herb=math.max(0,(s.resources.herb or 0)+(c.herb or 0));s.resources.favor=math.max(0,(s.resources.favor or 0)+(c.favor or 0))
  if c.tag then
    s.chronicle.tags=s.chronicle.tags or {}
    s.chronicle.tags[#s.chronicle.tags+1]=c.tag
    if #s.chronicle.tags>12 then table.remove(s.chronicle.tags,1) end
  end
  if c.ripple then s.ripple=c.ripple
  elseif c.rel then
    if c.rel.ali then s.ripple="阿梨把药篓又背紧了些。"
    elseif c.rel.shen then s.ripple="沈照没有立刻说话。"
    elseif c.rel.beast then s.ripple="霜枝的耳尖动了动。"
    else s.ripple=nil end
  else s.ripple=nil end
  s.tip_seen=true
  remember(s,choice_label(c))
  if c.action=="restart_v1" then begin_volume(s,1) elseif c.action=="start_v2" then begin_volume(s,2) elseif c.action=="start_v3" then begin_volume(s,3) else enter(s,c.next) end
  return true
end
local function layout(ctx,choice_count)
  local w,h=ctx.screen.width,ctx.screen.height
  local m=math.max(16,math.floor(w*.04))
  local content_w=w-m*2
  local count=choice_count or 0
  local choice_slot,choice_h=62,56
  local choice_reserve=(count>0) and (count*choice_slot+32) or 40
  local header_y=10
  local image_y=header_y+HEADER_PITCH*2+10
  local text_min=20+LINE_PITCH+LINES_PER_PAGE*LINE_PITCH+LINE_PITCH+12
  local max_img_h=h-image_y-text_min-choice_reserve-8
  local img_w=content_w
  local img_h=math.floor(ART_H*img_w/ART_W+0.5)
  if img_h>max_img_h then
    img_h=math.max(96,max_img_h)
    img_w=math.floor(ART_W*img_h/ART_H+0.5)
  end
  local image_x=m+math.floor((content_w-img_w)/2)
  local text_y=image_y+img_h+12
  local text_h=h-text_y-choice_reserve
  return{
    w=w,h=h,m=m,content_w=content_w,
    header_y=header_y,header_step=HEADER_PITCH,
    image_x=image_x,image_y=image_y,image_w=img_w,image_h=img_h,
    text_y=text_y,text_h=text_h,
    line_pitch=LINE_PITCH,title_y=14,body_y=58,
    choice_slot=choice_slot,choice_h=choice_h,choice_reserve=choice_reserve
  }
end
local function choice_origin(b,count) return b.h-(count*b.choice_slot)-32 end
local function draw_choice(g,b,y,index,label)
  g:rect(b.m,y,b.content_w,b.choice_h,{fill=true,color=0})
  g:rect(b.m,y,b.content_w,b.choice_h,{color=15})
  g:rect(b.m+10,y+18,16,16,{color=15})
  g:text(b.m+14,y+18,tostring(index),{color=15})
  g:text(b.m+36,y+18,label,{color=15})
end
function on_load(ctx)
  ctx:set_tick(0)
  local s=game(ctx);sync_reading(s);s.ui_choice_count=#choices(s);ctx:invalidate()
end
function on_input(ctx,ev)
  local s=game(ctx);local n=current(s);local cs=choices(s);s.ui_choice_count=#cs
  if not (ev.type == "pointer" and ev.phase == "up") then return false end
  if ev.gesture=="long" then s.show_history=not s.show_history;ctx:invalidate();return true end
  if ev.gesture~="tap" then return false end
  if s.show_history then s.show_history=false;ctx:invalidate();return true end
  if n.ending then enter(s,"atlas");ctx:invalidate();return true end
  sync_reading(s)
  local b=layout(ctx,#cs)
  if not s.reading_done then
    if ev.x>=b.m and ev.x<=b.w-b.m and ev.y>=b.image_y and ev.y<=b.text_y+b.text_h then
      s.page=s.page+1;sync_reading(s);s.tip_seen=true;s.ui_choice_count=#choices(s);ctx:invalidate();return true
    end
    return false
  end
  if #cs==1 then
    local sy=choice_origin(b,1)
    local on_btn=ev.x>=b.m and ev.x<=b.w-b.m and ev.y>=sy and ev.y<=sy+b.choice_h
    local on_read=ev.x>=b.m and ev.x<=b.w-b.m and ev.y>=b.image_y and ev.y<=b.text_y+b.text_h
    if on_btn or on_read then choose(s,1);ctx:invalidate();return true end
    return false
  end
  local sy=choice_origin(b,#cs)
  for i=1,#cs do local y=sy+(i-1)*b.choice_slot if ev.x>=b.m and ev.x<=b.w-b.m and ev.y>=y and ev.y<=y+b.choice_h then choose(s,i);ctx:invalidate();return true end end
  return false
end
function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local s=game(ctx);local n=current(s);local cs=choices(s)
  sync_reading(s);s.ui_choice_count=#cs
  local b=layout(ctx,#cs)
  g:clear(0)
  g:text(b.m,b.header_y,n.chapter,{color=15})
  g:text(b.m,b.header_y+b.header_step,s.ripple or bond_header(s),{color=15})
  g:line(b.m,b.image_y-6,b.w-b.m,b.image_y-6,{color=15})
  g:rect(b.image_x-2,b.image_y-2,b.image_w+4,b.image_h+4,{color=15})
  PkgImage.draw(g, n.art, b.image_x, b.image_y, {w=b.image_w,h=b.image_h})
  g:rect(b.m,b.text_y,b.content_w,b.text_h,{fill=true,color=0})
  g:rect(b.m,b.text_y,b.content_w,b.text_h,{color=15})
  g:text(b.m+12,b.text_y+b.title_y,n.title,{color=15})
  g:line(b.m+12,b.text_y+b.title_y+26,b.m+12+72,b.text_y+b.title_y+26,{color=15})
  local shown=page_lines(s)
  for i,line in ipairs(shown) do g:text(b.m+12,b.text_y+b.body_y+(i-1)*b.line_pitch,line,{color=15}) end
  if not s.reading_done and not n.ending then
    g:text(b.m+12,b.text_y+b.text_h-b.line_pitch,"点按继续",{color=15})
  end
  if s.show_history then
    local hy=b.header_y+b.header_step+8
    local hh=b.h-hy-36
    g:rect(b.m,hy,b.content_w,hh,{fill=true,color=0});g:rect(b.m,hy,b.content_w,hh,{color=15})
    g:text(b.m+12,hy+14,"行记·持久档案（点按关闭）",{color=15})
    g:line(b.m+12,hy+40,b.w-b.m-12,hy+40,{color=15})
    g:text(b.m+12,hy+14+b.line_pitch,"境:"..realm_label(s).."  位:"..(s.chronicle.progress.post or "清河散修").."  悟:"..(s.chronicle.progress.insight or 0),{color=15})
    g:text(b.m+12,hy+14+b.line_pitch*2,"缘分  阿梨·"..bond_word(s.chronicle.bonds.ali).."  沈照·"..bond_word(s.chronicle.bonds.shen).."  霜枝·"..bond_word(s.chronicle.bonds.beast),{color=15})
    g:text(b.m+12,hy+14+b.line_pitch*3,"药:"..(s.resources.herb or 0).."  情:"..(s.resources.favor or 0).."  结局:"..ending_count(s).."/6",{color=15})
    g:text(b.m+12,hy+14+b.line_pitch*4,"卷章："..chapter_record(s),{color=15})
    g:text(b.m+12,hy+14+b.line_pitch*5,"结局："..ending_record(s),{color=15})
    g:text(b.m+12,hy+14+b.line_pitch*6,"当卷："..tag_record(s),{color=15})
    local first=math.max(1,#s.history-5);for i=first,#s.history do g:text(b.m+12,hy+14+b.line_pitch*7+(i-first)*b.line_pitch,s.history[i],{color=15}) end;return
  end
  if n.ending then g:text(b.m,b.h-36,"结局已记入行记  点按选择下一卷",{color=15});return end
  if not s.reading_done then
    if not s.tip_seen then g:text(b.m,b.h-36,"点选推进 · 长按行记",{color=15}) end
    return
  end
  if #cs==1 then
    draw_choice(g,b,choice_origin(b,1),1,choice_label(cs[1]))
    if not s.tip_seen then g:text(b.m,b.h-36,"点选推进 · 长按行记",{color=15}) end
    return
  end
  local sy=choice_origin(b,#cs)
  for i,c in ipairs(cs) do draw_choice(g,b,sy+(i-1)*b.choice_slot,i,choice_label(c)) end
  if not s.tip_seen then g:text(b.m,b.h-36,"点选推进 · 长按行记",{color=15}) end
end
