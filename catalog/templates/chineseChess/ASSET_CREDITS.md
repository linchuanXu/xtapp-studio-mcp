# 素材与数据来源说明（ASSET CREDITS）

## 中国象棋开局库（data/openings.txt）

发布开局库由 XTApp Studio 离线生成：语料写入 `data/openings.txt`，`domain/chess_opening.lua` 只负责分片扫描。`chinese-chess-opening-book.mjs` 是另一套手工/BOOK 数据生成工具，不是当前发布库的权威生成链路。

### 数据分级（许可硬门槛）

| 级别 | 说明 | 是否入库/发布 |
| --- | --- | --- |
| A 类 | 手工整理的经典开局主线（`chinese-chess-opening-lines.json`，约 20 条） | 是 |
| B 类 | 许可证明确允许再分发与衍生数据的开源棋谱 | 是，itlwei/Chess MIT 前缀库 |
| C 类 | 许可证不明确的第三方棋谱（仅人工研究参考） | 否 |

### A 类：手工整理开局线

- 来源：人工整理的经典中国象棋开局主线（中炮对屏风马、顺炮、列炮、仙人指路、飞相局、过宫炮、士角炮、反宫马、起马局等）。
- 记谱：UCCI 坐标记法（`h2e2` 等）。
- 校验：每条线均经 `domain/chess_state.lua` 复放校验合法后才会进入开局库。
- 许可：自编数据，无第三方版权。

### B 类：itlwei/Chess MIT 棋谱前缀

- 来源：[itlwei/Chess](https://github.com/itlwei/Chess) 的 `js/gambit.all.js`，MIT License，`Copyright (c) 2021 liwei`。
- 导入：使用 `chinese-chess-itlwei-book.mjs` 将上游 `x,y,newX,newY` 坐标转为本项目坐标；不镜像、不改写原始着法语义。
- 校验：每一条导入前缀均由 `domain/chess_state.lua` 复放，非法线路不会进入发布库。
- 发布语料：保留 7,189 条经过当前生成器整理的完整 gambit 行，共 575,052 个坐标数字；运行时仍只累计每个 pace 的前 8 个唯一候选。
- 压缩格式：每个四位坐标移动使用两个可打印字符编码，保留原始行顺序、行边界和 `corpus_index`；该编码只改变存储，不改变候选、support 或 AI 排序。
- 原始 canonical fixture 与黄金快照只参与开发测试，不进入 catalog 或设备包；发布模块由生成器确定性重建。

### 未收录的第三方棋谱（C 类）

以下仓库仅作人工研究参考，**未导入仓库、未进入发布包**：

- [CGLemon/chinese-chess-PGN](https://github.com/CGLemon/chinese-chess-PGN)：大量 ICCS 棋谱，但页面未给出许可证，且棋谱来自第三方站点。
- [wukong-xiangqi/xqdb](https://github.com/maksimKorzh/wukong-xiangqi/tree/main/xqdb)：约 4.4 万局 UCCI 棋谱，许可未明确。

### 重新生成开局库

生成器会先将每步坐标压缩为两字符，写入 `data/openings.txt`，并生成不含语料字面量的 `domain/chess_opening.lua`；随后必须重新生成 `chineseChess.catalog.js`。

## AI 逐格估值表（domain/chess_itlwei.lua）

`domain/chess_itlwei.lua` 基于 [itlwei/Chess](https://github.com/itlwei/Chess)
的 `js/common.js` 中车、马、象、士、将、炮、兵的 10×9 位置分值表改写为 Lua。
原项目采用 **MIT License**，版权声明为 `Copyright (c) 2021 liwei`。
本应用保留上述来源与许可声明；算法调度、合法着生成、分片搜索及额外局面特征均为本项目实现。

## 头像素材

AI 对手头像（`portrait_child` / `portrait_adult` / `portrait_elder` 及各自表情）由仓库内原始图经 4×4 Bayer 有序网点重建为 1bpp XIC，重建脚本为 XTApp Studio。
