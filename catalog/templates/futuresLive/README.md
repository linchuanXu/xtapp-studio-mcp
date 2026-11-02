# 期货行情

真实外盘原油与内盘螺纹钢报价、最近 40 个一分钟收盘点。它独立于“全球市场”，不把商品合约混入宏观指数。

```text
GET http://193.112.174.92:28473/demo/market/quote/xtapp?kind=external|internal
GET http://193.112.174.92:28473/demo/futures/kline/xtapp?limit=40&kind=external|internal
```

路由规范：Manifest 声明 `net`；Lua 仅以 `ctx.net:request()` 发起固定 HTTP GET，结束时回调处理结果。服务器再以 HTTPS POST 使用阿里云市场；密钥不进入 Lua 或 HTTP 链路。

点击“外盘原油 / 内盘螺纹钢”切换合约。点击刷新或按 `OK` 更新；`BACK` 退出。
