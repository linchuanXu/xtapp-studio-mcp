-- Orange-Light-inspired geometry for X4 Pro 480×800 (portrait e-ink).
-- Stage fills above a bottom dialog; choices float over the stage; menu is a corner button.

local M = {}

M.ART = { bg_w = 480, bg_h = 600, source_bg_w = 448, source_bg_h = 480, char_w = 280, char_h = 400 }
M.UI = {
  dialog_w = 448, dialog_h = 188,
  -- Keep the stage geometry constant while choices are visible.
  dialog_choice_h = 188,
  name_w = 148, name_h = 34,
  choice_w = 384, choice_h = 52,
  -- Small visual control, but still a 52×52 touch target. It is intentionally
  -- subordinate to the stage and no longer reads like a second title block.
  menu_w = 52, menu_h = 52,
  panel_w = 448, panel_h = 680,
}
M.LINE_PITCH = 30
M.LINES_PER_PAGE = 4
M.CHOICE_SLOT = 62
M.GLYPH_H = 24
M.EDGE = 12
-- g:text is the firmware's fixed 20px system face. These are safety budgets,
-- not a typography preference: overflow cannot be measured or clipped at runtime.
M.MAX_LINE_UNITS = 17
M.MAX_CHOICE_UNITS = 15
M.MAX_TITLE_UNITS = 10
M.MAX_SPEAKER_UNITS = 5
M.MAX_CHAPTER_UNITS = 9
M.MAX_STATUS_LABEL_UNITS = 9
M.MENU_ROW_H = 56
M.STATUS_ROWS_PER_PAGE = 5
M.MAX_CAST = 3
function M.compute(ctx, visible_choices)
  local w, h = ctx.screen.width, ctx.screen.height
  local edge = M.EDGE
  local count = visible_choices or 0
  local showing_choices = count > 0

  -- Bottom letterbox dialog (橙光底栏); shorter when choices need stage space for floating rows.
  local dialog_h = showing_choices and M.UI.dialog_choice_h or M.UI.dialog_h
  local dialog_y = h - dialog_h - edge
  local dialog_x = edge
  local dialog_w = w - edge * 2

  -- Stage is everything above the dialog — no wasted header strip.
  local stage_x, stage_y = 0, 0
  local stage_w, stage_h = w, dialog_y

  -- Pre-cropped 480×600 background art fills the stage without an out-of-
  -- bounds cover draw. Browser preview and device export now share this frame.
  local bg_w, bg_h = stage_w, stage_h
  local bg_x, bg_y = stage_x, stage_y

  -- Preserve the former cover composition for portraits: source scene art was
  -- 448×480 and was enlarged to fill this 480×600 stage before being baked.
  local char_scale = math.max(stage_w / M.ART.source_bg_w, stage_h / M.ART.source_bg_h)
  local char_w = math.floor(M.ART.char_w * char_scale + 0.5)
  local char_h = math.floor(M.ART.char_h * char_scale + 0.5)
  if char_h > stage_h then
    char_h = stage_h
    char_w = math.floor(M.ART.char_w * char_h / M.ART.char_h + 0.5)
  end
  local char_x = stage_x + math.floor((stage_w - char_w) / 2)
  local char_y = stage_y + stage_h - char_h

  local choice_w = math.min(M.UI.choice_w, dialog_w)
  local choice_x = edge + math.floor((dialog_w - choice_w) / 2)

  local menu_w, menu_h = M.UI.menu_w, M.UI.menu_h
  local menu_x = w - edge - menu_w
  local menu_y = edge
  local panel_y = menu_y + menu_h + 12
  local panel_h = h - panel_y - edge

  -- The reading gutter starts after the frame and black rule. Keep 24px of
  -- paper between rule and glyph so the first character never reads as chrome.
  local text_x = dialog_x + 42
  local text_right = dialog_x + dialog_w - 24
  local title_y = 16
  local body_y = 52
  local continue_y = dialog_h - 28
  -- Always top-align the text block to this first body row. A page can have
  -- one or two lines, so vertical centering would create a false blank line
  -- on two-line pages after choices become visible.

  return {
    w = w, h = h, m = edge, content_w = dialog_w, edge = edge,
    stage_x = stage_x, stage_y = stage_y, stage_w = stage_w, stage_h = stage_h,
    bg_x = bg_x, bg_y = bg_y, bg_w = bg_w, bg_h = bg_h,
    char_x = char_x, char_y = char_y, char_w = char_w, char_h = char_h,
    dialog_x = dialog_x, dialog_y = dialog_y, dialog_w = dialog_w, dialog_h = dialog_h,
    text_x = text_x, text_right = text_right,
    name_x = dialog_x + 28, name_y = dialog_y - 22,
    dialog_title_x = dialog_x + 188, dialog_title_y = dialog_y + title_y,
    title_y = title_y, body_y = body_y, continue_y = continue_y,
    line_pitch = M.LINE_PITCH,
    choice_x = choice_x, choice_w = choice_w,
    choice_slot = M.CHOICE_SLOT, choice_h = M.UI.choice_h,
    menu_x = menu_x, menu_y = menu_y, menu_w = menu_w, menu_h = menu_h,
    panel_x = edge, panel_y = panel_y, panel_w = dialog_w, panel_h = panel_h,
    -- Compat aliases used by older hit helpers / tests.
    status_x = menu_x, status_y = menu_y, status_w = menu_w, status_h = menu_h,
    showing_choices = showing_choices,
  }
end

--- Floating choices sit directly above the dialogue rather than crossing the
--- character's face. This keeps the portrait readable at every choice count.
function M.choice_origin(b, count)
  local stack = count * b.choice_slot
  local top_guard = 84 -- keep clear of chapter chip / corner menu
  local bottom_gap = 20 -- 12px slab edge + 8px visual breathing room
  local origin = b.dialog_y - bottom_gap - stack
  if origin < top_guard then origin = top_guard end
  return origin
end

--- Return a stable portrait rectangle for one of the left / center / right
--- stage slots. A single legacy portrait keeps the original centre geometry.
function M.character_rect(b, slot, count)
  local scale = count == 1 and 1 or (count == 2 and 0.60 or 0.45)
  local w = math.floor(b.char_w * scale + 0.5)
  local h = math.floor(b.char_h * scale + 0.5)
  local outer = count == 2 and 0.25 or 0.17
  local anchor = slot == "left" and outer or (slot == "right" and (1 - outer) or 0.50)
  local x = math.floor(b.stage_x + b.stage_w * anchor - w / 2 + 0.5)
  if x < b.stage_x then x = b.stage_x end
  if x + w > b.stage_x + b.stage_w then x = b.stage_x + b.stage_w - w end
  return { x = x, y = b.stage_y + b.stage_h - h, w = w, h = h }
end

function M.in_content_x(b, x)
  return x >= b.edge and x <= b.w - b.edge
end

function M.hit_stage(b, x, y)
  -- Whole stage + dialog advance reading; menu excluded by caller order.
  if x < 0 or x >= b.w then return false end
  return y >= 0 and y < b.dialog_y + b.dialog_h
end

function M.hit_status(b, x, y)
  return x >= b.menu_x and x <= b.menu_x + b.menu_w
    and y >= b.menu_y and y <= b.menu_y + b.menu_h
end

function M.hit_panel(b, x, y)
  return x >= b.panel_x and x <= b.panel_x + b.panel_w
    and y >= b.panel_y and y <= b.panel_y + b.panel_h
end

function M.menu_home_hit(b, x, y)
  if x < b.panel_x + 12 or x > b.panel_x + b.panel_w - 12 then return nil end
  local status_y = b.panel_y + 52
  local backlog_y = b.panel_y + 228
  local checkpoint_y = backlog_y + M.MENU_ROW_H + 12
  if y >= status_y and y < status_y + M.MENU_ROW_H then return "status" end
  if y >= backlog_y and y < backlog_y + M.MENU_ROW_H then return "backlog" end
  if y >= checkpoint_y and y < checkpoint_y + M.MENU_ROW_H then return "checkpoints" end
  return nil
end

function M.menu_status_hit(b, x, y)
  if x < b.panel_x or x > b.panel_x + b.panel_w then return nil end
  local nav_y = b.panel_y + 408
  if y >= nav_y and y < nav_y + M.MENU_ROW_H then
    if x < b.panel_x + b.panel_w / 2 then return "previous" end
    return "next"
  end
  if y >= b.panel_y + b.panel_h - 76 and y < b.panel_y + b.panel_h - 16 then return "home" end
  return nil
end

function M.menu_backlog_hit(b, x, y)
  if x < b.panel_x or x > b.panel_x + b.panel_w then return nil end
  local nav_y = b.panel_y + 316
  if y >= nav_y and y < nav_y + M.MENU_ROW_H then
    if x < b.panel_x + b.panel_w / 2 then return "previous" end
    return "next"
  end
  if y >= b.panel_y + b.panel_h - 76 and y < b.panel_y + b.panel_h - 16 then return "home" end
  return nil
end

function M.menu_checkpoint_hit(b, count, x, y)
  if x < b.panel_x + 12 or x > b.panel_x + b.panel_w - 12 then return nil end
  local first_y = b.panel_y + 96
  for index = 1, count do
    local row_y = first_y + (index - 1) * M.MENU_ROW_H
    if y >= row_y and y < row_y + M.MENU_ROW_H then return index end
  end
  if y >= b.panel_y + b.panel_h - 76 and y < b.panel_y + b.panel_h - 16 then return "home" end
  return nil
end

function M.hit_choice(b, count, x, y)
  if count < 1 then return nil end
  if x < b.choice_x or x > b.choice_x + b.choice_w then return nil end
  local sy = M.choice_origin(b, count)
  for i = 1, count do
    local top = sy + (i - 1) * b.choice_slot
    if y >= top and y <= top + b.choice_h then return i end
  end
  return nil
end

function M.ending_button(b)
  return { x = b.edge + 36, y = b.h - 104, w = b.w - (b.edge + 36) * 2, h = 60 }
end

function M.hit_ending_restart(b, x, y)
  local button = M.ending_button(b)
  return x >= button.x and x <= button.x + button.w
    and y >= button.y and y <= button.y + button.h
end

return M
