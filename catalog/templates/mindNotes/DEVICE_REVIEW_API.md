# 老设备 HTTP 复习接口

仅供无法建立 HTTPS 连接的旧设备使用。这个兼容层只提供复习队列与 FSRS 结果提交；它不是完整的 MindNotes API，也不提供登录、笔记编辑或通用网关。

X4 客户端只发下面这些请求。安装时只填 Skill Token。

## 地址与认证

```text
POST http://api.mindnotes.cn/legacy-review/v1/{due|next|preview|submit}
Authorization: Bearer mn_sk_...
Content-Type: application/json
```

所有成功响应均为 `{"ok":true,"data":{...}}`；鉴权失败为 `401`，权限不足为 `403`。

Token 必须是用户在 HTTPS 的 `POST /api/skill/v1/tokens` 创建的 Skill Token：读取接口需要 `notes:read`，提交接口还需要 `review:write`。创建时明确传入 scopes：

```json
{"name":"旧设备复习","scopes":["notes:read","review:write"]}
```

默认新 Token 不包含 `review:write`。明文 Token 仅会在创建响应中返回一次。

## 设备实际会发什么

| 时机 | 路径 | 请求体 |
| --- | --- | --- |
| 打开应用 / 回首页 | `/due` | `{"include_new":true,"new_limit":10}` |
| 开始复习 / 继续下一批 | `/next` | `{"include_new":true,"new_limit":10,"count":20}` |
| 评分 | `/submit` | `note_id`、`status`、`client_operation_id` |
| 主路径不打 | `/preview` | — |

不传 `tags`、`before`。未传 `before` 时，服务端按北京时间当天结束判断到期。

`status` 只发 `again` / `hard` / `good` / `easy`。服务端也接受 `forgotten`（`again`）、`fuzzy`（`hard`）、`remembered`（`easy`）。

每一次提交必须带客户端生成且稳定的 `client_operation_id`。超时后用完全相同的请求重试；服务端返回首次结果，并带 `idempotent_replay: true`，不会重复推进 FSRS。

## `/due` 响应

```json
{
  "due_count": 284,
  "overdue_count": 40,
  "new_count": 12,
  "new_available_count": 12,
  "reviewed_today_count": 6
}
```

首页读 `due_count`、`overdue_count`、`new_count`、`reviewed_today_count`。`new_count` 是首页字段；`new_available_count` 为兼容别名。`/due` 只返回计数，不序列化笔记正文。

## `/next` 响应与瘦卡片

```json
{
  "due_count": 284,
  "overdue_count": 40,
  "new_count": 12,
  "remaining": 264,
  "notes": [{
    "id": "note-123",
    "note_id": "note-123",
    "title": "present perfect",
    "content": "请写出 <mark>have done</mark> 的用法",
    "memory": {"review_count": 6},
    "fsrs": {"d": 4.2, "s": 12.0, "r": 0.91},
    "preview_memory": {
      "again": {"interval_label": "10m"},
      "hard": {"interval_label": "1d"},
      "good": {"interval_label": "3d"},
      "easy": {"interval_label": "7d"}
    }
  }]
}
```

`notes` 始终存在；没有可复习卡片时为 `[]`，且 `due_count`、`remaining` 为 `0`。正文最多 8000 个 UTF-8 字节；整批最多 20 张。瘦卡片不包含 `memory.history`、`fsrs.analysis`、`fsrs_state`、图片或 deprecated 预览键。

设备按 `notes` 本地一张张评；评完看 `remaining`，大于 0 可继续下一批。

## `/submit` 响应

```json
{
  "note_id": "note-123",
  "status": "good",
  "idempotent_replay": false
}
```

设备评完后走本地队列，不读下一张卡。`status` 可能已被规范化。

## `/preview`

主路径不调用。若仍保留，应返回与 `/next` 相同的瘦卡片。

## 安全限制

HTTP 会明文传输 Token 与笔记内容。仅应在无法升级的设备上启用，使用专门、最小权限、可撤销的 Token；不要使用网页登录 JWT，也不要将同一 Token 用于其他设备或应用。遗失设备时，通过 HTTPS 的 `DELETE /api/skill/v1/tokens/{token_id}` 立即撤销 Token。

边缘 Nginx 只在 `api.mindnotes.cn:80` 放行这个精确前缀的四个 POST 路径；所有其他 HTTP 路径仍重定向到 HTTPS。
