# 全球市场

真实联网市场速览：一次通过固定 HTTP GET 请求道琼斯、纳斯达克综合指数、恒生指数、美元指数、纽约原油，以及 EUR/USD、USD/JPY、USD/CNH 三组主要汇率。设备端不保存任何密钥。

```text
GET http://193.112.174.92:28473/demo/market/pulse/xtapp
GET http://193.112.174.92:28473/demo/market/quote/xtapp?kind=dow|nasdaq|hsi|forex|eurusd|usdjpy|usdcnh|external
GET http://193.112.174.92:28473/demo/market/kline/xtapp?limit=40&kind=forex
```

路由规范：Manifest 声明 `net`；Lua 仅以 `ctx.net:request()` 请求固定 HTTP 路由，结束时回调处理结果；服务器再以 HTTPS POST 调用阿里云市场。HTTP 链路不得承载密钥或敏感数据。

道琼斯、纳斯达克、恒生、美元指数、纽约原油与三组主要汇率都可打开真实报价详情。当前套餐已实际验证道琼斯、纳斯达克综合指数与恒生指数可用；标普 500 的候选代码返回空对象，因此不展示为真实数据。尚未有已验证走势时，页面会明确说明而不会绘制模拟曲线。内盘期货属于独立的期货工具，不混入本应用。详情页顶部“返回”或 `BACK` 回到总览。顶部刷新或 `OK` 更新总览；总览 `BACK` 退出。
