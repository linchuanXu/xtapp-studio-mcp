-- Story-agnostic VN session: state, paging, choices, effects, navigation.
-- Bind a story table once; never require a concrete story module here.

local Layout = require("domain.vn_layout")

local M = {}

local RESTART = "__restart"
local MAX_CHOICES_DEFAULT = 4
local HISTORY_LIMIT_DEFAULT = 16
local BACKLOG_LIMIT_DEFAULT = 32
local CHECKPOINT_LIMIT_DEFAULT = 6

local function copy_vars(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for k, v in pairs(src) do out[k] = v end
  return out
end

local function copy_array(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for index, value in ipairs(src) do out[index] = value end
  return out
end

local function copy_backlog(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for index, entry in ipairs(src) do
    out[index] = {
      chapter = entry.chapter or "",
      speaker = entry.speaker or "",
      title = entry.title or "",
      line1 = entry.line1 or "",
      line2 = entry.line2 or "",
    }
  end
  return out
end

local function copy_stage(src)
  local out = { bg = nil, cast = {} }
  if type(src) ~= "table" then return out end
  if type(src.bg) == "string" then out.bg = src.bg end
  if type(src.cast) == "table" then
    for index, actor in ipairs(src.cast) do
      out.cast[index] = {
        id = actor.id or "",
        asset = actor.asset,
        slot = actor.slot or "center",
        expression = actor.expression or "",
      }
    end
  end
  return out
end

local function default_vars_of(story)
  if type(story.default_vars) == "table" then return copy_vars(story.default_vars) end
  return {}
end

-- The firmware exposes only a fixed 20px face and no text measurement or clip.
-- Chinese glyphs take one readable unit; ASCII takes a conservative fraction.
-- Keep the parser byte-based so it works in the restricted Lua environment.
local function text_units(text)
  local units, index = 0, 1
  while index <= #text do
    local byte = string.byte(text, index)
    if byte < 0x80 then
      units = units + (byte == 0x20 and 0.5 or 0.65)
      index = index + 1
    elseif byte < 0xe0 then
      units = units + 1
      index = index + 2
    elseif byte < 0xf0 then
      units = units + 1
      index = index + 3
    else
      units = units + 1
      index = index + 4
    end
  end
  return units
end

local function assert_text_fits(text, limit, label)
  assert(text_units(text) <= limit, label .. " exceeds readable width; pre-wrap it")
end

local function assert_effects(effects, label)
  if effects == nil then return end
  assert(type(effects) == "table", label .. ".effects must be a table")
  if effects.flags ~= nil then
    assert(type(effects.flags) == "table", label .. ".effects.flags must be a table")
    for index, flag in ipairs(effects.flags) do
      assert(type(flag) == "string" and flag ~= "", label .. ".effects.flags[" .. tostring(index) .. "] must be a non-empty string")
    end
  end
  if effects.vars ~= nil then
    assert(type(effects.vars) == "table", label .. ".effects.vars must be a table")
    for key, amount in pairs(effects.vars) do
      assert(type(key) == "string" and key ~= "", label .. ".effects.vars keys must be non-empty strings")
      assert(type(amount) == "number", label .. ".effects.vars." .. tostring(key) .. " must be a number")
    end
  end
  if effects.set ~= nil then
    assert(type(effects.set) == "table", label .. ".effects.set must be a table")
    for key, value in pairs(effects.set) do
      assert(type(key) == "string" and key ~= "", label .. ".effects.set keys must be non-empty strings")
      assert(type(value) == "string" or type(value) == "number" or type(value) == "boolean", label .. ".effects.set values must be simple")
    end
  end
end

local function assert_string_list(value, label)
  assert(type(value) == "table", label .. " must be a table")
  for index, item in ipairs(value) do
    assert(type(item) == "string" and item ~= "", label .. "[" .. tostring(index) .. "] must be a non-empty string")
  end
end

local function assert_number_map(value, label)
  assert(type(value) == "table", label .. " must be a table")
  for key, amount in pairs(value) do
    assert(type(key) == "string" and key ~= "", label .. " keys must be non-empty strings")
    assert(type(amount) == "number", label .. "." .. tostring(key) .. " must be a number")
  end
end

local function assert_requirements(requirements, label)
  if requirements == nil then return end
  assert(type(requirements) == "table", label .. ".requires must be a table")
  if requirements.all_flags ~= nil then assert_string_list(requirements.all_flags, label .. ".requires.all_flags") end
  if requirements.none_flags ~= nil then assert_string_list(requirements.none_flags, label .. ".requires.none_flags") end
  if requirements.any_flags ~= nil then assert_string_list(requirements.any_flags, label .. ".requires.any_flags") end
  if requirements.min_vars ~= nil then assert_number_map(requirements.min_vars, label .. ".requires.min_vars") end
  if requirements.max_vars ~= nil then assert_number_map(requirements.max_vars, label .. ".requires.max_vars") end
  if requirements.equals ~= nil then
    assert(type(requirements.equals) == "table", label .. ".requires.equals must be a table")
    for key, value in pairs(requirements.equals) do
      assert(type(key) == "string" and key ~= "", label .. ".requires.equals keys must be non-empty strings")
      assert(type(value) == "string" or type(value) == "number" or type(value) == "boolean", label .. ".requires.equals values must be simple")
    end
  end
end

local function assert_story(story, max_choices)
  assert(type(story.nodes[story.start_id]) == "table", "vn_engine.bind: story.start_id must name a node")
  if story.default_vars ~= nil then
    assert(type(story.default_vars) == "table", "vn_engine.bind: story.default_vars must be a table")
    for key, value in pairs(story.default_vars) do
      assert(type(key) == "string" and key ~= "", "vn_engine.bind: story.default_vars keys must be non-empty strings")
      assert(type(value) == "string" or type(value) == "number" or type(value) == "boolean", "vn_engine.bind: story.default_vars." .. tostring(key) .. " must be simple")
    end
  end
  if story.status_vars ~= nil then
    assert(type(story.status_vars) == "table", "vn_engine.bind: story.status_vars must be a table")
    for index, key in ipairs(story.status_vars) do
      assert(type(key) == "string" and key ~= "", "vn_engine.bind: story.status_vars[" .. tostring(index) .. "] must be a non-empty string")
    end
  end
  if story.status_labels ~= nil then
    assert(type(story.status_labels) == "table", "vn_engine.bind: story.status_labels must be a table")
    for key, label in pairs(story.status_labels) do
      assert(type(key) == "string" and key ~= "", "vn_engine.bind: story.status_labels keys must be non-empty strings")
      assert(type(label) == "string" and label ~= "", "vn_engine.bind: story.status_labels." .. tostring(key) .. " must be a non-empty string")
      assert_text_fits(label, Layout.MAX_STATUS_LABEL_UNITS, "vn_engine.bind: story.status_labels." .. tostring(key))
    end
  end
  if story.status_meanings ~= nil then
    assert(type(story.status_meanings) == "table", "vn_engine.bind: story.status_meanings must be a table")
    for key, meaning in pairs(story.status_meanings) do
      assert(type(key) == "string" and key ~= "", "vn_engine.bind: story.status_meanings keys must be non-empty strings")
      assert(type(meaning) == "string" and meaning ~= "", "vn_engine.bind: story.status_meanings." .. tostring(key) .. " must be a non-empty string")
      assert_text_fits(meaning, Layout.MAX_LINE_UNITS, "vn_engine.bind: story.status_meanings." .. tostring(key))
    end
  end
  for id, node in pairs(story.nodes) do
    local label = "vn_engine.bind: story.nodes." .. tostring(id)
    assert(type(id) == "string" and id ~= "", label .. " id must be a non-empty string")
    assert(type(node) == "table", label .. " must be a table")
    if node.lines ~= nil then
      assert(type(node.lines) == "table", label .. ".lines must be a table")
      for index, line in ipairs(node.lines) do
        assert(type(line) == "string", label .. ".lines[" .. tostring(index) .. "] must be a string")
        assert_text_fits(line, Layout.MAX_LINE_UNITS, label .. ".lines[" .. tostring(index) .. "]")
      end
    end
    for _, field in ipairs({ "bg", "char", "speaker", "title", "chapter" }) do
      if node[field] ~= nil then assert(type(node[field]) == "string", label .. "." .. field .. " must be a string") end
    end
    if node.speaker then assert_text_fits(node.speaker, Layout.MAX_SPEAKER_UNITS, label .. ".speaker") end
    if node.title then assert_text_fits(node.title, Layout.MAX_TITLE_UNITS, label .. ".title") end
    if node.chapter then assert_text_fits(node.chapter, Layout.MAX_CHAPTER_UNITS, label .. ".chapter") end
    if node.checkpoint ~= nil then
      assert(type(node.checkpoint) == "boolean" or type(node.checkpoint) == "string", label .. ".checkpoint must be a boolean or string")
      if type(node.checkpoint) == "string" then
        assert_text_fits(node.checkpoint, Layout.MAX_LINE_UNITS, label .. ".checkpoint")
      end
    end
    if node.ending ~= nil then
      assert(type(node.ending) == "table", label .. ".ending must be a table")
      assert(type(node.ending.name) == "string" and node.ending.name ~= "", label .. ".ending.name required")
      assert_text_fits(node.ending.name, Layout.MAX_LINE_UNITS, label .. ".ending.name")
      if node.ending.image ~= nil then
        assert(type(node.ending.image) == "string" and node.ending.image ~= "", label .. ".ending.image must be a non-empty asset key")
      end
      if node.ending.summary ~= nil then
        assert_string_list(node.ending.summary, label .. ".ending.summary")
        for index, line in ipairs(node.ending.summary) do
          assert_text_fits(line, Layout.MAX_LINE_UNITS, label .. ".ending.summary[" .. tostring(index) .. "]")
        end
      end
      if node.ending.notes ~= nil then
        assert(type(node.ending.notes) == "table", label .. ".ending.notes must be a table")
        for index, note in ipairs(node.ending.notes) do
          local note_label = label .. ".ending.notes[" .. tostring(index) .. "]"
          assert(type(note) == "table", note_label .. " must be a table")
          assert(type(note.text) == "string" and note.text ~= "", note_label .. ".text required")
          assert_text_fits(note.text, Layout.MAX_LINE_UNITS, note_label .. ".text")
          if note.when ~= nil then assert(type(note.when) == "string", note_label .. ".when must be a string") end
          if note.unless ~= nil then assert(type(note.unless) == "string", note_label .. ".unless must be a string") end
          assert_requirements(note.requires, note_label)
        end
      end
    end
    if node.scene ~= nil then
      assert(type(node.scene) == "table", label .. ".scene must be a table")
      local scene = node.scene
      if scene.bg ~= nil then assert(type(scene.bg) == "string" and scene.bg ~= "", label .. ".scene.bg must be a non-empty string") end
      if scene.clear_cast ~= nil then assert(type(scene.clear_cast) == "boolean", label .. ".scene.clear_cast must be a boolean") end
      if scene.cast ~= nil then
        assert(type(scene.cast) == "table", label .. ".scene.cast must be a table")
        assert(#scene.cast <= Layout.MAX_CAST, label .. ".scene.cast exceeds the " .. tostring(Layout.MAX_CAST) .. " portrait limit")
        local occupied = {}
        for index, actor in ipairs(scene.cast) do
          local actor_label = label .. ".scene.cast[" .. tostring(index) .. "]"
          assert(type(actor) == "table", actor_label .. " must be a table")
          assert(type(actor.asset) == "string" and actor.asset ~= "", actor_label .. ".asset required")
          if actor.id ~= nil then assert(type(actor.id) == "string", actor_label .. ".id must be a string") end
          if actor.expression ~= nil then assert(type(actor.expression) == "string", actor_label .. ".expression must be a string") end
          local slot = actor.slot or "center"
          assert(slot == "left" or slot == "center" or slot == "right", actor_label .. ".slot must be left, center, or right")
          assert(not occupied[slot], actor_label .. ".slot duplicates another portrait")
          occupied[slot] = true
        end
      end
    end
    if node.choices ~= nil then
      assert(type(node.choices) == "table", label .. ".choices must be a table")
      assert(#node.choices <= max_choices, label .. ".choices exceeds the " .. tostring(max_choices) .. " visible-choice limit")
      for index, choice in ipairs(node.choices) do
        local choice_label = label .. ".choices[" .. tostring(index) .. "]"
        assert(type(choice) == "table", choice_label .. " must be a table")
        assert(type(choice.text) == "string" and choice.text ~= "", choice_label .. ".text required")
        assert_text_fits(choice.text, Layout.MAX_CHOICE_UNITS, choice_label .. ".text")
        assert(type(choice.next) == "string" and choice.next ~= "", choice_label .. ".next required")
        assert(choice.next == RESTART or type(story.nodes[choice.next]) == "table", choice_label .. ".next names no node")
        if choice.when ~= nil then assert(type(choice.when) == "string", choice_label .. ".when must be a string") end
        if choice.unless ~= nil then assert(type(choice.unless) == "string", choice_label .. ".unless must be a string") end
        if choice.min_var ~= nil then
          assert(type(choice.min_var) == "table", choice_label .. ".min_var must be a table")
          for key, need in pairs(choice.min_var) do
            assert(type(key) == "string" and key ~= "", choice_label .. ".min_var keys must be non-empty strings")
            assert(type(need) == "number", choice_label .. ".min_var." .. tostring(key) .. " must be a number")
          end
        end
        assert_requirements(choice.requires, choice_label)
        assert_effects(choice.effects, choice_label)
      end
    end
    assert_effects(node.effects, label)
  end
end

--- Bind engine to one story table.
--- story: { title, start_id, nodes, default_vars?, status_vars? }
--- opts:  { state_key, max_choices?, history_limit? }
function M.bind(story, opts)
  assert(type(story) == "table" and type(story.nodes) == "table", "vn_engine.bind: story.nodes required")
  assert(type(story.start_id) == "string" and story.start_id ~= "", "vn_engine.bind: story.start_id required")
  opts = opts or {}
  local state_key = opts.state_key or "vn"
  local max_choices = opts.max_choices or MAX_CHOICES_DEFAULT
  local history_limit = opts.history_limit or HISTORY_LIMIT_DEFAULT
  local backlog_limit = opts.backlog_limit or BACKLOG_LIMIT_DEFAULT
  local checkpoint_limit = opts.checkpoint_limit or CHECKPOINT_LIMIT_DEFAULT
  local lines_per_page = Layout.LINES_PER_PAGE
  assert(type(max_choices) == "number" and max_choices >= 1, "vn_engine.bind: max_choices must be positive")
  assert(type(backlog_limit) == "number" and backlog_limit >= 1, "vn_engine.bind: backlog_limit must be positive")
  assert(type(checkpoint_limit) == "number" and checkpoint_limit >= 1, "vn_engine.bind: checkpoint_limit must be positive")
  assert_story(story, max_choices)

  local E = {
    story = story,
    STATE_KEY = state_key,
    RESTART = RESTART,
  }

  local function node_of(s)
    return story.nodes[s.node_id]
  end

  local function legacy_stage(n)
    local cast = {}
    if n and n.char then
      cast[1] = { asset = n.char, slot = "center", id = "", expression = "" }
    end
    return { bg = n and n.bg or nil, cast = cast }
  end

  local function apply_scene(s)
    local n = node_of(s)
    if not n or not n.scene then
      s.stage = legacy_stage(n)
      return
    end
    local stage = copy_stage(s.stage)
    local scene = n.scene
    if scene.bg ~= nil then stage.bg = scene.bg end
    if scene.clear_cast then stage.cast = {} end
    if scene.cast ~= nil then
      stage.cast = {}
      for index, actor in ipairs(scene.cast) do
        stage.cast[index] = {
          id = actor.id or "",
          asset = actor.asset,
          slot = actor.slot or "center",
          expression = actor.expression or "",
        }
      end
    end
    s.stage = stage
  end

  local function apply_effects(s, effects)
    if not effects then return end
    if effects.flags then
      for _, f in ipairs(effects.flags) do s.flags[f] = true end
    end
    if effects.vars then
      for k, v in pairs(effects.vars) do
        s.vars[k] = (s.vars[k] or 0) + v
      end
    end
    if effects.set then
      for k, v in pairs(effects.set) do s.vars[k] = v end
    end
  end

  local function can_show(s, c)
    if c.when and not s.flags[c.when] then return false end
    if c.unless and s.flags[c.unless] then return false end
    if c.min_var then
      for k, need in pairs(c.min_var) do
        if (s.vars[k] or 0) < need then return false end
      end
    end
    local requires = c.requires
    if not requires then return true end
    if requires.all_flags then
      for _, flag in ipairs(requires.all_flags) do if not s.flags[flag] then return false end end
    end
    if requires.none_flags then
      for _, flag in ipairs(requires.none_flags) do if s.flags[flag] then return false end end
    end
    if requires.any_flags then
      local matched = false
      for _, flag in ipairs(requires.any_flags) do if s.flags[flag] then matched = true break end end
      if not matched then return false end
    end
    if requires.min_vars then
      for key, amount in pairs(requires.min_vars) do if (s.vars[key] or 0) < amount then return false end end
    end
    if requires.max_vars then
      for key, amount in pairs(requires.max_vars) do if (s.vars[key] or 0) > amount then return false end end
    end
    if requires.equals then
      for key, value in pairs(requires.equals) do if s.vars[key] ~= value then return false end end
    end
    return true
  end

  local function choices_of(s)
    local n = node_of(s)
    if not n then return {} end
    local out = {}
    for _, c in ipairs(n.choices or {}) do
      if can_show(s, c) then out[#out + 1] = c end
    end
    return out
  end

  local function sync_reading(s)
    local n = node_of(s)
    local lines = (n and n.lines) or {}
    local total = #lines
    if total <= 0 then
      s.page = 0
      s.reading_done = true
      return
    end
    local pages = math.max(1, math.ceil(total / lines_per_page))
    if s.page > (pages - 1) then s.page = pages - 1 end
    s.reading_done = (s.page + 1) * lines_per_page >= total
  end

  local function page_lines(s)
    local n = node_of(s)
    local lines = (n and n.lines) or {}
    local start = s.page * lines_per_page + 1
    local out = {}
    for i = start, math.min(#lines, start + lines_per_page - 1) do
      out[#out + 1] = lines[i]
    end
    return out
  end

  local function remember(s, text)
    s.history[#s.history + 1] = text
    if #s.history > history_limit then table.remove(s.history, 1) end
  end

  local function remember_page(s)
    local n = node_of(s)
    if not n then return end
    local lines = page_lines(s)
    s.backlog[#s.backlog + 1] = {
      chapter = n.chapter or "",
      speaker = n.speaker or "",
      title = n.title or "",
      line1 = lines[1] or "",
      line2 = lines[2] or "",
    }
    if #s.backlog > backlog_limit then table.remove(s.backlog, 1) end
    s.backlog_cursor = #s.backlog
  end

  local function checkpoint_label(n)
    if type(n.checkpoint) == "string" and n.checkpoint ~= "" then return n.checkpoint end
    if n.chapter and n.chapter ~= "" then return n.chapter end
    if n.title and n.title ~= "" then return n.title end
    return "故事检查点"
  end

  local function snapshot_of(s)
    return {
      node_id = s.node_id,
      page = s.page,
      reading_done = s.reading_done,
      flags = copy_vars(s.flags),
      vars = copy_vars(s.vars),
      history = copy_array(s.history),
      backlog = copy_backlog(s.backlog),
      stage = copy_stage(s.stage),
      tip_seen = s.tip_seen,
    }
  end

  local function remember_checkpoint(s)
    local n = node_of(s)
    if not n or not n.checkpoint then return end
    local id = s.node_id
    local entry = { id = id, label = checkpoint_label(n), snapshot = snapshot_of(s) }
    for index, saved in ipairs(s.checkpoints) do
      if saved.id == id then
        s.checkpoints[index] = entry
        return
      end
    end
    s.checkpoints[#s.checkpoints + 1] = entry
    if #s.checkpoints > checkpoint_limit then table.remove(s.checkpoints, 1) end
  end

  local function refresh_ui(s)
    sync_reading(s)
    -- Expose only choices the reader can actually tap. Keeping the hidden
    -- count in persisted state made a half-read page look actionable to
    -- host tools even though the view correctly withheld the choice cards.
    s.ui_choice_count = s.reading_done and #choices_of(s) or 0
  end

  local function enter(s, id)
    assert(type(story.nodes[id]) == "table", "vn_engine.enter: node missing")
    s.node_id = id
    s.page = 0
    s.reading_done = false
    s.show_menu = false
    s.focus = 1
    apply_scene(s)
    apply_effects(s, node_of(s).effects)
    refresh_ui(s)
    remember_page(s)
    remember_checkpoint(s)
  end

  local function reset_progress(s)
    s.flags = {}
    s.vars = default_vars_of(story)
    s.history = {}
    s.backlog = {}
    s.checkpoints = {}
    enter(s, story.start_id)
  end

  function E.ensure(ctx)
    local s = ctx.state[state_key]
    local fresh = not s
    if not s then
      s = {}
      ctx.state[state_key] = s
    end
    -- JSON round-trip may turn empty maps into arrays; keep map semantics.
    if type(s.flags) ~= "table" then s.flags = {} end
    if type(s.vars) ~= "table" then s.vars = default_vars_of(story) end
    if type(s.history) ~= "table" then s.history = {} end
    if type(s.backlog) ~= "table" then s.backlog = {} end
    if type(s.checkpoints) ~= "table" then s.checkpoints = {} end
    s.schema = 2
    if fresh then
      -- Enter the first node through the normal path so its effects are not
      -- accidentally skipped on a brand-new save.
      enter(s, story.start_id)
      return s
    end
    s.node_id = s.node_id or story.start_id
    if not story.nodes[s.node_id] then
      reset_progress(s)
      return s
    end
    s.page = s.page or 0
    s.reading_done = s.reading_done or false
    s.show_menu = s.show_menu or false
    s.tip_seen = s.tip_seen or false
    s.ui_choice_count = s.ui_choice_count or 0
    s.focus = s.focus or 1
    s.menu_screen = s.menu_screen or "home"
    s.backlog_cursor = s.backlog_cursor or #s.backlog
    s.status_page = s.status_page or 1
    if type(s.stage) ~= "table" then apply_scene(s) end
    for k, v in pairs(default_vars_of(story)) do
      if s.vars[k] == nil then s.vars[k] = v end
    end
    return s
  end

  function E.node(s) return node_of(s) end
  function E.stage(s) return s.stage or legacy_stage(node_of(s)) end
  function E.choices(s) return choices_of(s) end
  function E.page_lines(s) return page_lines(s) end
  function E.is_ending(s)
    local n = node_of(s)
    return n and type(n.ending) == "table" and s.reading_done
  end
  function E.sync_reading(s) sync_reading(s) end
  function E.refresh_ui(s) refresh_ui(s) end

  function E.boot(ctx)
    local s = E.ensure(ctx)
    refresh_ui(s)
  end

  function E.choose(s, index)
    local cs = choices_of(s)
    local c = cs[index]
    if not c then return false end
    apply_effects(s, c.effects)
    remember(s, c.text)
    s.tip_seen = true
    s.focus = index
    if c.next == RESTART then
      reset_progress(s)
    else
      enter(s, c.next)
    end
    return true
  end

  function E.advance(s)
    sync_reading(s)
    if s.reading_done then
      local cs = choices_of(s)
      if #cs == 1 then return E.choose(s, 1) end
      return false
    end
    s.page = s.page + 1
    s.tip_seen = true
    refresh_ui(s)
    remember_page(s)
    return true
  end

  function E.toggle_menu(s)
    s.show_menu = not s.show_menu
    if s.show_menu then s.menu_screen = "home" end
  end

  function E.close_menu(s)
    s.show_menu = false
    s.menu_screen = "home"
  end

  function E.open_backlog(s)
    s.menu_screen = "backlog"
    s.backlog_cursor = #s.backlog
  end

  function E.open_status(s)
    s.menu_screen = "status"
    s.status_page = 1
  end

  -- Return structured rows rather than a preformatted line.  The view owns
  -- pagination and placement, while stories retain a stable, ordered status
  -- contract through status_vars/status_labels.
  function E.status_items(s)
    local keys = story.status_vars
    if type(keys) ~= "table" or #keys == 0 then
      keys = {}
      for k in pairs(default_vars_of(story)) do keys[#keys + 1] = k end
      table.sort(keys)
    end
    local labels = story.status_labels or {}
    local meanings = story.status_meanings or {}
    local items = {}
    for _, k in ipairs(keys) do
      items[#items + 1] = {
        key = k,
        label = tostring(labels[k] or k),
        value = tostring(s.vars[k] or 0),
        meaning = tostring(meanings[k] or ""),
      }
    end
    return items
  end

  -- Optional ending notes turn accumulated state into readable consequences.
  -- Their condition grammar intentionally matches choices, keeping stories
  -- declarative and the renderer ignorant of any one game's variables.
  function E.ending_notes(s)
    local n = node_of(s)
    local ending = n and n.ending
    local out = {}
    if type(ending) ~= "table" then return out end
    for _, note in ipairs(ending.notes or {}) do
      if can_show(s, note) then out[#out + 1] = note.text end
    end
    return out
  end

  function E.status_page(s, page_size)
    local items = E.status_items(s)
    local size = math.max(1, page_size or 1)
    local pages = math.max(1, math.ceil(#items / size))
    local page = math.max(1, math.min(pages, s.status_page or 1))
    s.status_page = page
    local first = (page - 1) * size + 1
    local visible = {}
    for index = first, math.min(#items, first + size - 1) do
      visible[#visible + 1] = items[index]
    end
    return visible, page, pages
  end

  function E.move_status_page(s, amount, page_size)
    local items = E.status_items(s)
    local pages = math.max(1, math.ceil(#items / math.max(1, page_size or 1)))
    local next_page = math.max(1, math.min(pages, (s.status_page or 1) + amount))
    if next_page == s.status_page then return false end
    s.status_page = next_page
    return true
  end

  function E.move_backlog(s, amount)
    if #s.backlog == 0 then return false end
    local next_cursor = math.max(1, math.min(#s.backlog, (s.backlog_cursor or #s.backlog) + amount))
    if next_cursor == s.backlog_cursor then return false end
    s.backlog_cursor = next_cursor
    return true
  end

  function E.open_checkpoints(s)
    s.menu_screen = "checkpoints"
  end

  function E.restore_checkpoint(s, index)
    local saved = s.checkpoints[index]
    if not saved or type(saved.snapshot) ~= "table" then return false end
    local snapshot = saved.snapshot
    if type(story.nodes[snapshot.node_id]) ~= "table" then return false end
    s.node_id = snapshot.node_id
    s.page = snapshot.page or 0
    s.reading_done = snapshot.reading_done == true
    s.flags = copy_vars(snapshot.flags)
    s.vars = copy_vars(snapshot.vars)
    s.history = copy_array(snapshot.history)
    s.backlog = copy_backlog(snapshot.backlog)
    if type(snapshot.stage) == "table" then
      s.stage = copy_stage(snapshot.stage)
    else
      apply_scene(s)
    end
    s.tip_seen = snapshot.tip_seen == true
    s.show_menu = false
    s.menu_screen = "home"
    s.backlog_cursor = #s.backlog
    refresh_ui(s)
    return true
  end

  function E.status_lines(s)
    local parts = {}
    for _, item in ipairs(E.status_items(s)) do
      parts[#parts + 1] = item.label .. ":" .. item.value
    end
    return table.concat(parts, "  ")
  end

  return E
end

return M
