# 市场异动雷达

面向 X4 Pro 的真实行情异动雷达。它把同一付费数据源下的港股、A 股、美股涨幅排行拆成三个清晰市场，避免把不同交易所的代码和计价单位混在同一张表里。

```text
GET http://193.112.174.92:28473/demo/stock/ranking/xtapp?limit=12
GET http://193.112.174.92:28473/demo/market/a/ranking/xtapp?limit=12
GET http://193.112.174.92:28473/demo/market/us/ranking/xtapp?limit=12
```

## 操作

- 点击或按 `左 / 右` 在港股、A 股、美股间切换；每次切换只请求该市场的真实排行。
- 点击右上角“刷新”或按 `OK` 重新拉取当前市场。
- `BACK` 退出。

## 联网与数据边界

Manifest 声明 `net`，Lua 只用异步的 `ctx.net:request()` 调用固定 HTTP GET 路由；阿里云凭证只留在服务器端。设备端接收的是 `XTAPP_RANKING_V1` 制表符协议，不解析上游 JSON。

这是“异动候选清单”，按接口返回的涨跌幅排序，不构成投资建议。HTTP 链路只发送公开市场选择，不得用于传输任何敏感数据。
