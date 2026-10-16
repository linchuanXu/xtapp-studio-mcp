# 图片素材：从公开资源到 PNG/XIC

XTApp 的设备图像使用 XIC。API 2.x 的 XIC 自带透明位面；目前开放的 X4 Pro / Classic 都只呈现黑白两阶，所以图片会抖动成黑白。高效流程是：找到有明确许可证的公开资源，整理成适合电子纸的 PNG，再生成 XIC，并用 PNG 作为审计预览。

## 1. 选择来源

优先使用自己绘制的 SVG/PNG，或许可证明确的开源图标库，例如 Lucide、Material Symbols。emoji 也不是天然无版权：Unicode 字符标准与具体字体图形是两件事，转换前要确认字体的再分发许可。不要把搜索结果页的图片、品牌 Logo 或来源不明的图片提交到公共仓库。

## 2. 设计 PNG

- 先确定实际显示尺寸，再绘图或缩放；不要最后才强行压缩。
- API 2.x：保留 PNG 的透明背景即可，透明会写进 XIC；不透明度不低于 50% 的像素算不透明，不透明的白色照样画成白色。半透明边缘要处理干净，避免出现脏边。
- API 0.8（旧项目）：XIC 只有 1bpp、没有透明，透明图要先合成白色背景，或由 Studio 生成配套 matte。
- 保留清晰轮廓和留白，避免细线、低对比渐变和密集纹理。
- 动态数字、日期、玩家名交给 `g:text`，不要烘焙进大图。
- 素材 key 使用英文、数字、连字符或下划线，最长 23 个字符且保持唯一。

## 3. 生成 XIC

用 XTApp Studio 的图片转换把 SVG 或整理好的 PNG 做成 XIC。SVG 是推荐输入；HTML 只在确实需要浏览器排版时使用。

转换成功后应同时得到 `.xic` 和同名 `.png` 审计图。结果几乎全白或全黑时，先修输入图再转。

如果只在 Studio 中制作素材，也可以通过素材导入流程上传 PNG/JPEG/WebP，Studio 会负责生成 XIC。2.x 项目直接 `g:image(ctx.package:image(key), x, y)` 绘制，不需要另画白底。0.8 项目还会生成配套的 `<key>_matte`，不要手工覆盖它。

## 4. 接入项目

把素材 key 写进 `manifest.json` 的字段或 Lua 引用，并把启动和首屏会用到的高频图片放入 `preload_assets`：

```json
{ "preload_assets": ["weather_sun"] }
```

2.x 里 `ctx.package:image(key)` 返回同一个图像对象，宿主最多缓存 320 张、合计 524288 字节，超出时卸下最久没画过的图，下次画时再重新解码；所以首屏图片要放进 `preload_assets`，别指望每次都现解码。提交前检查 XIC 能被 Studio 预览、Manifest 引用了真实 key、`preload_assets` 没有重复项，并在 X4 Pro 与 X4 Classic 上跑过关键页面。

## 5. 经验记录模板

```text
来源：URL / 作者 / 许可证
输入：SVG、PNG 或 HTML；原始尺寸
目标：X4 Pro/Classic；目标尺寸和用途
处理：透明背景（0.8 为白底）、缩放、阈值/抖动、对比度
输出：PNG 审计图、XIC、素材 key
验证：Studio 版本、预览页面、真机结果
限制：授权、细节丢失、尺寸或性能问题
```

