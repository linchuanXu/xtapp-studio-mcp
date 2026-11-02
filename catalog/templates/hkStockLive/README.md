# 港股实况

面向 X4 Pro 的真实港股实时价格查询 XTApp。设备只访问固定的临时 HTTP Demo API，付费数据源凭证保留在服务器端。

默认查询美团 `03690`，可随时通过股票代码输入面板改为其他五位港股代码。

```text
GET http://193.112.174.92:28473/demo/stock/xtapp?symbol=00700
GET http://193.112.174.92:28473/demo/stock/kline/xtapp?type=1&limit=40&symbol=00700
GET http://193.112.174.92:28473/demo/stock/ranking/xtapp?limit=10
```

## 操作

- `OK` 或点击右上角齿轮：打开五位代码输入面板。
- 输入面板内 `左 / 右` 选择数字，`上 / 下` 增减，`OK` 确认并查询，`BACK` 取消。
- 点击“行情 / 涨幅榜”切换个股实况与真实港股涨幅榜；每次打开涨幅榜会刷新一次。
- 在行情页点击 `1分 / 5分 / 15分 / 30分 / 60分`，会以当前股票代码重新请求对应周期的真实 K 线。日 K 上游当前未返回足够的绘制数据，因此不作为可选周期展示。
- `BACK`：退出。
- 触控可点右上角刷新、输入面板中的数字和腾讯/阿里/美团快捷代码；长按数字会递减。

界面展示名称、实时价格、涨跌额、涨跌幅、最近 40 根真实 1 分钟 K 线的折线走势、开高低收、买卖价、成交量/额、市盈率、英文名、52 周区间和真实港股涨幅榜。

## 联网兼容性

本应用使用 2.x 联网接口：Manifest 声明 `net` 权限，Lua 调用 `ctx.net:request()`，请求结束时回调一次；同一时间只发一个请求，退出时 `job:cancel()`。

Manifest 的 `api` 为 `2.17`；联网能力由 `net` 权限开启，没有该权限时 `ctx.net` 为 nil。

当前契约仅开放异步 `http://` GET，不支持 HTTPS 或 Lua 通用网络库。Studio 预览通过受认证的同源代理访问公网 HTTP 目标，并拒绝本机、私网与链路本地地址；这只是预览兼容层，不是业务密钥代理。真机固件确实没有注册 `ctx.net` 时才显示“当前固件未提供 ScriptNet”。应用保持单文件入口，不依赖当前契约同样禁止的 `require`。

设备到 Demo 的 `http://` 链路是明文传输，不提供机密性或完整性保护。本应用只发送公开股票代码并接收公开行情；不得沿用这条链路传递密钥、令牌、账号信息或其他敏感用户数据。

## 完整数据链路

```text
港股实况 index.lua
  └─ GET http://193.112.174.92:28473/demo/stock/xtapp?symbol=00700
       └─ Demo 服务 POST https://jmqqgphqcx.market.alicloudapi.com/finance/hk-stocks-price
            └─ 阿里云市场付费港股数据源
  └─ GET http://193.112.174.92:28473/demo/stock/kline/xtapp?type=1&limit=40&symbol=00700
       └─ Demo 服务 POST https://jmqqgphqcx.market.alicloudapi.com/finance/hk-stocks-kline
            └─ 阿里云市场付费港股数据源
  └─ GET http://193.112.174.92:28473/demo/stock/ranking/xtapp?limit=10
       └─ Demo 服务 POST https://jmqqgphqcx.market.alicloudapi.com/finance/hk-shares-ranking
            └─ 阿里云市场付费港股数据源
```

- 设备端只知道 Demo API，不保存阿里云 AppCode、AppKey 或 AppSecret。
- Demo 服务将实时报价归一化为 `XTAPP_STOCK_V1`，K 线归一化为最多 40 条 `XTAPP_KLINE_V1` 制表符记录；设备端不解析 JSON。
- 每次进入、点击预设、按 `OK` 或点击刷新依次请求实时报价和当前周期 K 线；切换周期只请求当前股票的 K 线。`on_tick` 只轮询已发起的单个任务，不会重复请求付费接口。
- 接口市场中的“港股实时报价”文档与本工程使用同一 URL、字段和 ScriptNet 模式；选中后，Studio 会把安全的 `promptContext` 加入下一次 AI 请求。

主要返回字段包括 `symbol/name/enname/price/preclose/change/changeRate/open/high/low/bid/ask/volume/value/pe/52week_low/52week_high/update_time/update_text`。
