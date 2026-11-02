local PkgImage = require("pkg_image")
-- Orange-Light-inspired presentation for e-ink: stage → float choices → bottom dialog → corner menu.
-- Note: 1bpp XIC treats white as transparent, so any chrome over the stage needs an opaque g:rect fill first.

local Layout = require("domain.vn_layout")

local M = {}

local function visible_choice_count(s, cs)
  if s.show_menu then return 0 end
  if not s.reading_done then return 0 end
  return #cs
end

local function opaque(g, x, y, w, h)
  g:rect(x, y, w, h,{fill=true,color=0})
end

local function draw_stage(g, b, stage)
  if stage.bg then
    PkgImage.draw(g, stage.bg, b.bg_x, b.bg_y, { w = b.bg_w, h = b.bg_h })
  else
    g:rect(b.stage_x, b.stage_y, b.stage_w, b.stage_h,{color=15})
  end
  local count = #stage.cast
  for _, actor in ipairs(stage.cast) do
    local rect = Layout.character_rect(b, actor.slot, count)
    -- The portrait carries its own transparency; enclosed whites stay opaque.
    PkgImage.draw(g, actor.asset, rect.x, rect.y, { w = rect.w, h = rect.h })
  end
end

local function draw_menu_btn(g, b)
  -- ui_menu is a bare settings glyph. Its 52px hit target remains in layout,
  -- but it intentionally has no white backing card or outer border.
  PkgImage.draw(g, "ui_menu", b.menu_x, b.menu_y, { w = b.menu_w, h = b.menu_h, color = 0 })
end

local function draw_chapter(g, b, chapter)
  if not chapter or chapter == "" then return end
  local tw = math.min(200, b.content_w - b.menu_w - 20)
  opaque(g, b.edge, b.edge, tw, 28)
  g:rect(b.edge, b.edge, tw, 28,{color=15})
  g:text(b.edge + 10, b.edge + 6, chapter, { color = 15 })
end

local function draw_dialog(g, b, n, lines, reading_done)
  opaque(g, b.dialog_x, b.dialog_y, b.dialog_w, b.dialog_h)
  local chrome = b.showing_choices and "ui_dialog_choice" or "ui_dialog"
  -- XIC dialogue chrome is a native 448×188 bitmap. The stage has a 12px
  -- gutter on each side (456px), so keep the bitmap native and centre it
  -- instead of asking the firmware-shaped renderer to scale it by 8px.
  local chrome_w = math.min(b.dialog_w, Layout.UI.dialog_w)
  local chrome_x = b.dialog_x + math.floor((b.dialog_w - chrome_w) / 2)
  PkgImage.draw(g, chrome, chrome_x, b.dialog_y, { w = chrome_w, h = b.dialog_h })
  if n.speaker then
    opaque(g, b.name_x, b.name_y, Layout.UI.name_w, Layout.UI.name_h)
    PkgImage.draw(g, "ui_nameplate", b.name_x, b.name_y, { w = Layout.UI.name_w, h = Layout.UI.name_h })
    g:text(b.name_x + 14, b.name_y + 7, n.speaker, { color = 15 })
    if n.title then
      g:text(b.dialog_title_x, b.dialog_title_y, n.title, { color = 15 })
    end
  elseif n.title then
    g:text(b.text_x, b.dialog_y + b.title_y, n.title, { color = 15 })
  end
  for i, line in ipairs(lines) do
    g:text(b.text_x, b.dialog_y + b.body_y + (i - 1) * b.line_pitch, line, { color = 15 })
  end
  if not reading_done then
    g:text(b.dialog_x + b.dialog_w - 36, b.dialog_y + b.continue_y, "▼", { color = 15 })
  end
end

local function draw_menu_home(g, b, engine, s)
  opaque(g, b.panel_x, b.panel_y, b.panel_w, b.panel_h)
  PkgImage.draw(g, "ui_panel", b.panel_x, b.panel_y, { w = b.panel_w, h = b.panel_h })
  local x = b.panel_x + 16
  local y = b.panel_y
  g:text(x, y + 16, "状态", { color = 15 })
  local status_y = y + 52
  g:rect(x, status_y, b.panel_w - 32, Layout.MENU_ROW_H,{color=15})
  g:text(x + 14, status_y + 16, "查看状态明细", { color = 15 })
  g:text(b.panel_x + b.panel_w - 46, status_y + 16, ">", { color = 15 })
  g:rect(x, y + 132, b.panel_w - 32, 1,{fill=true,color=15})
  local n = engine.node(s)
  g:text(x, y + 156, "当前章节", { color = 15 })
  g:text(x, y + 192, (n and n.chapter) or "故事进度", { color = 15 })
  local backlog_y = y + 228
  local checkpoint_y = backlog_y + Layout.MENU_ROW_H + 12
  g:rect(x, backlog_y, b.panel_w - 32, Layout.MENU_ROW_H,{color=15})
  g:text(x + 14, backlog_y + 16, "阅读记录", { color = 15 })
  g:text(b.panel_x + b.panel_w - 46, backlog_y + 16, ">", { color = 15 })
  g:rect(x, checkpoint_y, b.panel_w - 32, Layout.MENU_ROW_H,{color=15})
  g:text(x + 14, checkpoint_y + 16, "章节书签", { color = 15 })
  g:text(b.panel_x + b.panel_w - 46, checkpoint_y + 16, ">", { color = 15 })
  g:text(x, y + b.panel_h - 40, "点右上角图标或面板外返回", { color = 15 })
end

local function draw_menu_status(g, b, engine, s)
  opaque(g, b.panel_x, b.panel_y, b.panel_w, b.panel_h)
  PkgImage.draw(g, "ui_panel", b.panel_x, b.panel_y, { w = b.panel_w, h = b.panel_h })
  local x, y = b.panel_x + 16, b.panel_y
  g:text(x, y + 16, "状态明细", { color = 15 })
  g:rect(x, y + 48, b.panel_w - 32, 1,{fill=true,color=15})
  local items, page, pages = engine.status_page(s, Layout.STATUS_ROWS_PER_PAGE)
  if #items == 0 then
    g:text(x, y + 92, "本作尚未定义状态变量", { color = 15 })
  else
    for index, item in ipairs(items) do
      local row_y = y + 80 + (index - 1) * Layout.MENU_ROW_H
      g:rect(x, row_y, b.panel_w - 32, Layout.MENU_ROW_H,{color=15})
      g:text(x + 14, row_y + 16, item.label, { color = 15 })
      g:text(x + math.floor((b.panel_w - 32) * 0.58), row_y + 16, item.value, { color = 15 })
      if item.meaning and item.meaning ~= "" then g:text(x + 14, row_y + 34, item.meaning, { color = 15 }) end
    end
  end
  local nav_y = y + 408
  local half = math.floor((b.panel_w - 40) / 2)
  g:rect(x, nav_y, half, Layout.MENU_ROW_H,{color=15})
  g:rect(b.panel_x + math.floor(b.panel_w / 2) + 4, nav_y, half, Layout.MENU_ROW_H,{color=15})
  g:text(x + 14, nav_y + 16, "< 上一页", { color = 15 })
  g:text(b.panel_x + math.floor(b.panel_w / 2) + 18, nav_y + 16, "下一页 >", { color = 15 })
  g:text(x, nav_y + 84, tostring(page) .. " / " .. tostring(pages), { color = 15 })
  g:text(x, y + b.panel_h - 40, "返回目录", { color = 15 })
end

local function draw_ending(g, b, engine, s, n)
  local ending, inset = n.ending, b.edge + 20
  g:clear(0)
  local art_x, art_y, art_w, art_h = inset, 56, b.w - inset * 2, 200
  opaque(g, art_x, art_y, art_w, art_h)
  if ending.image then PkgImage.draw(g, ending.image, art_x, art_y, { w = art_w, h = art_h }) else g:rect(art_x, art_y, art_w, art_h,{color=15}) end
  g:text(inset + 20, 284, "本轮结局", { color = 15 })
  g:rect(inset + 20, 316, b.w - inset * 2 - 40, 2,{fill=true,color=15})
  g:text(inset + 20, 336, ending.name or n.title or "结局", { color = 15 })
  for index, line in ipairs(ending.summary or {}) do g:text(inset + 20, 376 + (index - 1) * 28, line, { color = 15 }) end
  local notes_y, notes = 460, engine.ending_notes(s)
  if #notes > 0 then
    g:text(inset + 20, notes_y, "这次抉择：", { color = 15 })
    for index = 1, math.min(2, #notes) do g:text(inset + 20, notes_y + index * 28, notes[index], { color = 15 }) end
    notes_y = notes_y + math.min(2, #notes) * 28 + 34
  end
  g:text(inset + 20, notes_y, "这一轮留下：", { color = 15 })
  local items = engine.status_items(s)
  for index, item in ipairs(items) do
    local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
    g:text(inset + 20 + column * 184, notes_y + 32 + row * 26, item.label .. " " .. item.value, { color = 15 })
  end
  local button = Layout.ending_button(b)
  opaque(g, button.x, button.y, button.w, button.h)
  g:rect(button.x, button.y, button.w, button.h,{color=15})
  g:text(button.x + 132, button.y + 18, "重走这一轮", { color = 15 })
end

local function draw_menu_backlog(g, b, s)
  opaque(g, b.panel_x, b.panel_y, b.panel_w, b.panel_h)
  PkgImage.draw(g, "ui_panel", b.panel_x, b.panel_y, { w = b.panel_w, h = b.panel_h })
  local x, y = b.panel_x + 16, b.panel_y
  g:text(x, y + 16, "阅读记录", { color = 15 })
  g:rect(x, y + 48, b.panel_w - 32, 1,{fill=true,color=15})
  if #s.backlog == 0 then
    g:text(x, y + 92, "尚无阅读记录", { color = 15 })
  else
    local entry = s.backlog[s.backlog_cursor]
    g:text(x, y + 76, entry.chapter ~= "" and entry.chapter or "故事记录", { color = 15 })
    local byline = entry.speaker ~= "" and entry.speaker or entry.title
    if byline ~= "" then g:text(x, y + 112, byline, { color = 15 }) end
    g:rect(x, y + 140, b.panel_w - 32, 1,{fill=true,color=15})
    g:text(x, y + 172, entry.line1, { color = 15 })
    if entry.line2 ~= "" then g:text(x, y + 204, entry.line2, { color = 15 }) end
    g:text(x, y + 260, tostring(s.backlog_cursor) .. " / " .. tostring(#s.backlog), { color = 15 })
  end
  local nav_y = y + 316
  g:rect(x, nav_y, math.floor((b.panel_w - 40) / 2), Layout.MENU_ROW_H,{color=15})
  g:rect(b.panel_x + math.floor(b.panel_w / 2) + 4, nav_y, math.floor((b.panel_w - 40) / 2), Layout.MENU_ROW_H,{color=15})
  g:text(x + 14, nav_y + 16, "< 上一条", { color = 15 })
  g:text(b.panel_x + math.floor(b.panel_w / 2) + 18, nav_y + 16, "下一条 >", { color = 15 })
  g:text(x, y + b.panel_h - 40, "返回目录", { color = 15 })
end

local function draw_menu_checkpoints(g, b, s)
  opaque(g, b.panel_x, b.panel_y, b.panel_w, b.panel_h)
  PkgImage.draw(g, "ui_panel", b.panel_x, b.panel_y, { w = b.panel_w, h = b.panel_h })
  local x, y = b.panel_x + 16, b.panel_y
  g:text(x, y + 16, "章节书签", { color = 15 })
  g:rect(x, y + 48, b.panel_w - 32, 1,{fill=true,color=15})
  if #s.checkpoints == 0 then
    g:text(x, y + 92, "本作尚未设置检查点", { color = 15 })
  else
    for index, checkpoint in ipairs(s.checkpoints) do
      local row_y = y + 96 + (index - 1) * Layout.MENU_ROW_H
      g:rect(x, row_y, b.panel_w - 32, Layout.MENU_ROW_H,{color=15})
      g:text(x + 14, row_y + 16, checkpoint.label, { color = 15 })
    end
  end
  g:text(x, y + b.panel_h - 40, "点书签回到当时进度；返回目录", { color = 15 })
end

local function draw_menu(g, b, engine, s)
  if s.menu_screen == "backlog" then
    draw_menu_backlog(g, b, s)
  elseif s.menu_screen == "checkpoints" then
    draw_menu_checkpoints(g, b, s)
  elseif s.menu_screen == "status" then
    draw_menu_status(g, b, engine, s)
  else
    draw_menu_home(g, b, engine, s)
  end
end

local function draw_choices(g, b, cs)
  local sy = Layout.choice_origin(b, #cs)
  -- Full opaque slab behind the stack so dithered stage cannot bleed through.
  local pad = 8
  opaque(g, b.choice_x - pad, sy - pad, b.choice_w + pad * 2, #cs * b.choice_slot + pad)
  g:rect(b.choice_x - pad, sy - pad, b.choice_w + pad * 2, #cs * b.choice_slot + pad,{color=15})
  for i, c in ipairs(cs) do
    local y = sy + (i - 1) * b.choice_slot
    opaque(g, b.choice_x, y, b.choice_w, b.choice_h)
    PkgImage.draw(g, "ui_choice", b.choice_x, y, { w = b.choice_w, h = b.choice_h })
    g:text(b.choice_x + 44, y + 16, c.text, { color = 15 })
  end
end

function M.draw(ctx, g, engine)
  local s = engine.ensure(ctx)
  local n = engine.node(s)
  if not n then return end
  local cs = engine.choices(s)
  engine.refresh_ui(s)
  local visible = visible_choice_count(s, cs)
  local b = Layout.compute(ctx, visible)
  g:clear(0)

  if s.show_menu then
    draw_menu(g, b, engine, s)
    draw_menu_btn(g, b)
    return
  end

  if engine.is_ending(s) then
    draw_ending(g, b, engine, s, n)
    draw_menu_btn(g, b)
    return
  end

  draw_stage(g, b, engine.stage(s))
  if visible > 0 then draw_choices(g, b, cs) end
  draw_dialog(g, b, n, engine.page_lines(s), s.reading_done)
  draw_chapter(g, b, n.chapter or "")
  draw_menu_btn(g, b)
end

M.visible_choice_count = visible_choice_count

return M
