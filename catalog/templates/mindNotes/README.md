# MindNotes

面向 X4 的 MindNotes 复习客户端。安装时只填 Skill Token。笔记里的 mark / 加粗默认遮挡，点正文显示或重新遮挡；长笔记上下滑。翻面后点底部四档提交 Again、Hard、Good、Easy。提交超时或断网后按同一评分键重试，会沿用同一 `client_operation_id`。

首页读 `/due` 的待复习、逾期、新卡和今日已复习。开始复习时 `/next` 带 `count: 20`，一次取最多 20 张瘦卡片，本地评完再显示本轮完成；若 `remaining > 0` 可继续下一批。

应用调用 `POST http://api.mindnotes.cn/legacy-review/v1/{due,next,preview,submit}`，通过 `ctx.net:request({ url, method = "POST", body, headers }, on_done)` 发送。字段说明见 `DEVICE_REVIEW_API.md`。
