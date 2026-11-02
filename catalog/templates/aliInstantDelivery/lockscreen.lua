local PkgImage = require("pkg_image")
local B,W=15,0
local stages={{0,"订单处理中",28},{45,"商品准备中",24},{105,"骑手取货中",18},{170,"正在送来",12},{245,"正在送来",7},{315,"即将送达",2},{360,"已安全送达",0}}

local function current(ctx)
  local state=ctx.state.ali_delivery or {}
  local now=ctx.clock:now().local_sec or math.floor(ctx.clock:millis()/1000)
  local elapsed=math.max(0,now-(state.started or now))
  local item=stages[1]
  for _,v in ipairs(stages) do if elapsed>=v[1] then item=v end end
  return item
end

function on_draw(ctx,g) require("pkg_image").bind(ctx);
  local item=current(ctx)
  g:clear(W)
  PkgImage.draw(g, "brand_mark", 26, 28)
  g:text(342,42,"闪购履约提醒",{color=B})
  g:line(26,96,454,96,{color=B})
  g:text(26,142,item[3]>0 and "预计送达" or "一笔订单已送达",{color=B})
  g:text(26,198,item[3]>0 and (item[3].." 分钟") or "请查看交付位置",{color=B})
  PkgImage.draw(g, item[3]>0 and "route" or "check", 372, 160)
  g:line(26,262,454,262,{color=B})
  PkgImage.draw(g, "feature_scene", 120, 302)
  g:text(26,482,item[2],{color=B})
  g:text(26,526,"一笔即时零售订单",{color=B})
  g:text(26,570,"商品、金额、地址均已隐藏",{color=B})
  g:line(26,626,454,626,{color=B})
  PkgImage.draw(g, "shield", 26, 662)
  g:text(90,674,"隐私模式 · 安心送",{color=B})
  g:text(90,710,"解锁后查看订单详情",{color=B})
  ctx.lock:set_interval(30)
  end
