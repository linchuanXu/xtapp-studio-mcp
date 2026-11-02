local PkgImage = require("pkg_image")
local B,W=15,0
local stages={{0,"商家制作中",32},{35,"骑手赶往商家",26},{85,"骑手正在取餐",18},{145,"骑手配送中",9},{215,"即将送达",2},{255,"订单已送达",0}}
local function current(ctx) local s=ctx.state.delivery or {}; local now=ctx.clock:now().local_sec or 0; local elapsed=math.max(0,now-(s.started or now)); local item=stages[1]; for _,v in ipairs(stages) do if elapsed>=v[1] then item=v end end; return item end
function on_draw(ctx,g) require("pkg_image").bind(ctx); local s=current(ctx); g:clear(W); PkgImage.draw(g, "brand_logo", 26, 28); g:line(26,96,454,96,{color=B}); g:text(26,142,s[3]>0 and "预计送达" or "订单已送达",{color=B}); g:text(26,202,s[3]>0 and (s[3].." 分钟") or "请到园区前台取餐",{color=B}); PkgImage.draw(g, s[3]>0 and "icon_rider" or "icon_done", 382, 170); g:line(26,270,454,270,{color=B}); PkgImage.draw(g, "feature_scene", 120, 310); g:text(26,486,s[2],{color=B}); g:text(26,530,"炙味烤肉 · 观澜湖店 · 6281",{color=B}); g:text(26,574,"骑手周师傅 · 尾号7312",{color=B}); end
