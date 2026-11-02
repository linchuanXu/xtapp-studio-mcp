# 内置词库来源

四级与六级词条及中文释义来自 [WordMaster Word Lists](https://github.com/lratusa/wordmaster-wordlists) 的 `cet4-full.json` 与 `cet6_full.json`。其 README 声明数据以 MIT License 发布，并说明 CET 词库来源为 KyleBing/english-vocabulary。

本应用固定使用上游提交 `e54e976a15946e97d59aeae31ded99ee167bc477`，内置 4,544 个 CET-4 词条与 3,991 个 CET-6 词条。原始文件 SHA-256 分别为 `550a192708bcea0e5c260e4c57197251775a3e851ae1de89f7faf8a95bac4174` 与 `1fe403b7c8514d05356807983dc13f720e941a3dfb7bde0c012f3f64afaecfcd`。

生成过程会做空白归一化、重复释义清理、适合屏幕宽度的字段截断，并按难度分组后稳定打散词序；不会把第三方词库表述为官方考试大纲。数据按只读 `data/*.tsv` 分片加载，避免把数千词直接展开进入口 Lua，影响墨水屏设备的启动预算和内存。

## 界面图标来源

按钮图标选自 [Tabler Icons](https://github.com/tabler/tabler-icons) 3.46.0，采用 MIT License。构建脚本会从项目素材库中读取选定的 SVG，统一线宽和尺寸后与按钮文字、边框合成，再编码为设备使用的 1bpp XIC；应用不会打包整套图标库。

## 界面字体来源

中文功能标签使用 Google Fonts 仓库发布的 Noto Sans SC 可变字体，采用 SIL Open Font License 1.1；品牌标题保留 ZCOOL KuaiLe，英文单词使用 Kaisei Tokumin。字体仅在开发阶段栅格化为对应尺寸的 1bpp XIC，设备端不会加载或解析字体文件。
