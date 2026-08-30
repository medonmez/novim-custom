-- novim/settings_ui.lua - Interactive Settings Modal for novim custom derivative
-- Part of novim custom derivative

local settings = require("novim.settings")
local themes = require("novim.themes")
local keymaps = require("novim.keymaps")

local M = {}

local DIVIDER = " ────────────────────────────────────────────────────────"

--- Ordered Settings controls. Focus navigation (Up/Down) moves only within
--- this list, so help and informational lines are never selectable controls.
local CONTROL_ORDER = { "dotfiles", "theme" }

--- Top-right mouse close affordance rendered on the title row.
local CLOSE_LABEL = "Close [x]"

local state = {
  win = nil,
  buf = nil,
  on_change = nil,
  last_error = nil,
  prev_win = nil,
  selected = CONTROL_ORDER[1],
  dotfiles_row = nil,
  theme_row = nil,
  close_row = nil,
  close_col = nil,
  ns_id = vim.api.nvim_create_namespace("novim_settings_ui"),
}

--- Check if settings modal is currently open
---@return boolean
function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

--- Buffer of the open settings modal (for diagnostics / testing)
---@return integer? buf
function M.get_buf()
  if M.is_open() and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  return nil
end

--- Window of the open settings modal (for diagnostics / testing)
---@return integer? win
function M.get_win()
  if M.is_open() then
    return state.win
  end
  return nil
end

--- Restore focus to the window that was current before the modal opened.
local function restore_focus()
  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
    pcall(vim.api.nvim_set_current_win, state.prev_win)
  end
  state.prev_win = nil
end

--- Close the settings modal and return focus to the workbench immediately.
--- nvim_win_hide is synchronous, so the float is gone and workbench focus is
--- restored deterministically within the same keypress.
function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_hide, state.win)
  end
  state.win = nil
  state.buf = nil
  state.last_error = nil
  restore_focus()
end

--- Selected control id (for diagnostics / testing)
---@return string
function M.get_selected_control()
  return state.selected or CONTROL_ORDER[1]
end

--- Move the focus indicator between controls (+1 down, -1 up), wrapping
--- consistently. Help and informational lines are never focused.
---@param direction integer
function M.move_focus(direction)
  if not M.is_open() then
    return
  end
  local idx = 1
  for i, id in ipairs(CONTROL_ORDER) do
    if id == state.selected then
      idx = i
      break
    end
  end
  state.selected = CONTROL_ORDER[((idx - 1 + direction) % #CONTROL_ORDER) + 1]
  M.render()
end

--- Activate the currently selected control (Space / Enter). Activating the
--- theme control cycles to the next theme, matching the theme row click.
function M.activate_selected()
  if M.get_selected_control() == "theme" then
    return M.cycle_theme(1)
  end
  return M.toggle_dotfiles()
end

--- Render settings content in buffer
function M.render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  vim.bo[state.buf].readonly = false
  vim.bo[state.buf].modifiable = true

  local cur_settings = settings.load(true)
  local show_dot = cur_settings.show_dotfiles
  local checkbox = show_dot and "[X]" or "[ ]"
  local status_text = show_dot and "ON (dot-prefixed files & folders are VISIBLE)" or "OFF (dot-prefixed files & folders are HIDDEN)"

  local theme_list = themes.list()
  local theme_pos = 1
  for i, t in ipairs(theme_list) do
    if t.id == cur_settings.theme then
      theme_pos = i
      break
    end
  end
  local theme_label = theme_list[theme_pos].label

  local path = settings.get_settings_file_path()

  -- Shorten path if very long
  local display_path = path
  if #display_path > 52 then
    display_path = "..." .. display_path:sub(#display_path - 49)
  end

  -- Title row with the top-right mouse close affordance. The button is
  -- right-aligned to the float width and closes through the same safe path
  -- as Esc/q (see handle_click).
  local title = " novim-dev Settings & Preferences"
  local win_width = 60
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    win_width = vim.api.nvim_win_get_width(state.win)
  end
  local pad = win_width - #title - #CLOSE_LABEL
  if pad < 1 then
    pad = 1
  end
  local close_prefix = title .. string.rep(" ", pad)
  state.close_row = 1
  state.close_col = #close_prefix + 1

  local lines = {
    close_prefix .. CLOSE_LABEL,
    DIVIDER,
    "",
    " Display Options:",
    "",
  }

  -- Exactly one visible selected-control indicator: only the focused row
  -- shows the ▶ marker, help text is never marked.
  local dot_row, theme_row
  local dot_prefix = (state.selected == "dotfiles") and "   ▶ " or "     "
  local theme_prefix = (state.selected == "theme") and "   ▶ " or "     "
  table.insert(lines, string.format("%s%s Show Dot-Folders & Hidden Files", dot_prefix, checkbox))
  dot_row = #lines -- 1-based window row (lines[1] renders at window row 1)
  table.insert(lines, string.format("       Status: %s", status_text))
  table.insert(lines, "")
  table.insert(lines, string.format("%sTheme:  ‹ %s ›", theme_prefix, theme_label))
  theme_row = #lines
  table.insert(lines, string.format("       Status: Palette %d of %d applied  ([h]/[l] to change)", theme_pos, #theme_list))
  table.insert(lines, "")

  local error_line_idx = nil
  if state.last_error then
    table.insert(lines, " ⚠ " .. tostring(state.last_error))
    error_line_idx = #lines - 1
    table.insert(lines, "   (Changes could not be persisted to disk)")
    table.insert(lines, "")
  end

  -- Key help is rendered below the display controls, from the canonical
  -- keymap documentation so it always matches the actual mappings.
  table.insert(lines, DIVIDER)
  table.insert(lines, " Key Bindings (Workbench):")
  local workbench_docs_start = #lines
  for _, entry in ipairs(keymaps.workbench) do
    table.insert(lines, string.format("   %-21s %s", entry.display, entry.desc))
  end
  table.insert(lines, DIVIDER)
  table.insert(lines, " Settings Panel Keys:")
  local settings_docs_start = #lines
  for _, entry in ipairs(keymaps.settings) do
    table.insert(lines, string.format("   %-21s %s", entry.display, entry.desc))
  end
  table.insert(lines, DIVIDER)
  table.insert(lines, " Storage:")
  table.insert(lines, "   Saved to: " .. display_path)

  state.dotfiles_row = dot_row
  state.theme_row = theme_row

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.bo[state.buf].readonly = true

  -- Highlights
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns_id, 0, -1)
  local function add_hl(line, col_start, col_end, group)
    pcall(vim.api.nvim_buf_add_highlight, state.buf, state.ns_id, group, line, col_start, col_end)
  end

  local function row0(row)
    return row - 1 -- window row (1-based) to buffer line (0-based)
  end

  -- Title and the top-right close affordance
  add_hl(0, 0, #title, "Title")
  add_hl(0, state.close_col - 1, -1, "WorkbenchKeyHint")
  add_hl(1, 0, -1, "WorkbenchDivider")
  add_hl(3, 0, -1, "WorkbenchHeader")

  -- Control rows: ranges are located by their text because the selected-row
  -- prefix contains a 3-byte glyph that shifts byte columns.
  local function highlight_indicator(row)
    local marker = lines[row]:find("▶", 1, true)
    if marker then
      add_hl(row0(row), marker - 1, marker - 1 + #("▶"), "WorkbenchActiveMarker")
    end
  end

  add_hl(row0(theme_row), 0, -1, "WorkbenchKeyHint")
  if state.selected == "theme" then
    highlight_indicator(theme_row)
  end
  add_hl(row0(theme_row) + 1, 7, -1, "WorkbenchSubHeader")

  local dot_line = lines[dot_row]
  local cb_col = dot_line:find(checkbox, 1, true)
  if cb_col then
    add_hl(row0(dot_row), cb_col - 1, cb_col - 1 + #checkbox, show_dot and "WorkbenchClean" or "WorkbenchSummary")
    add_hl(row0(dot_row), cb_col + #checkbox, -1, "Normal")
  end
  if state.selected == "dotfiles" then
    highlight_indicator(dot_row)
  end
  add_hl(row0(dot_row) + 1, 7, -1, show_dot and "WorkbenchClean" or "WorkbenchSubHeader")

  if error_line_idx then
    add_hl(error_line_idx, 0, -1, "WorkbenchError")
    add_hl(error_line_idx + 1, 0, -1, "WorkbenchSubHeader")
  end

  add_hl(row0(workbench_docs_start) - 1, 0, -1, "WorkbenchDivider")
  add_hl(row0(workbench_docs_start), 0, -1, "WorkbenchKeyHint")
  add_hl(row0(settings_docs_start) - 1, 0, -1, "WorkbenchDivider")
  add_hl(row0(settings_docs_start), 0, -1, "WorkbenchKeyHint")
  add_hl(row0(settings_docs_start) + #keymaps.settings + 1, 0, -1, "WorkbenchDivider")
  add_hl(row0(settings_docs_start) + #keymaps.settings + 2, 0, -1, "WorkbenchSubHeader")
end

--- Toggle the dotfiles setting and notify listeners
function M.toggle_dotfiles()
  local ok, err, effective_val = settings.toggle_dotfiles()
  if not ok then
    state.last_error = "Failed to save settings: " .. tostring(err)
    M.render()
    return
  end

  state.last_error = nil
  M.render()
  if state.on_change then
    pcall(state.on_change, "show_dotfiles", effective_val)
  end
end

--- Select a specific built-in theme, persist it, and apply its palette live.
--- On save failure the previous theme is retained and the error is rendered.
---@param id string
---@return boolean success
---@return string? error_msg
function M.set_theme(id)
  local ok, err = settings.set("theme", id)
  if not ok then
    state.last_error = "Failed to save theme: " .. tostring(err)
    M.render()
    return false, err
  end

  state.last_error = nil
  themes.apply(id)
  M.render()
  if state.on_change then
    pcall(state.on_change, "theme", id)
  end
  return true, nil
end

--- Cycle through the built-in themes (+1 next, -1 previous) with wraparound.
---@param direction integer
---@return boolean success
---@return string? error_msg
function M.cycle_theme(direction)
  local list = themes.list()
  local current = settings.get("theme")
  local pos = 1
  for i, t in ipairs(list) do
    if t.id == current then
      pos = i
      break
    end
  end
  local next_pos = ((pos - 1 + direction) % #list) + 1
  return M.set_theme(list[next_pos].id)
end

--- Handle a left mouse click inside the settings window. Clicking the
--- top-right Close affordance closes through the same safe close path as
--- Esc/q; clicking a control row focuses it and activates it. Clicks
--- elsewhere (help text, workbench panes) are ignored. Exposed as a
--- function of explicit coordinates so the hit-testing is deterministically
--- testable without a real mouse event.
---@param line integer 1-based window row
---@param column integer 1-based buffer column of the click
---@param winid integer? window the click landed in
function M.handle_click(line, column, winid)
  if winid ~= state.win then
    return
  end
  if state.close_row and line == state.close_row
      and state.close_col and column >= state.close_col then
    M.close()
    return
  end
  if state.theme_row and line == state.theme_row then
    state.selected = "theme"
    M.cycle_theme(1)
  elseif state.dotfiles_row and line == state.dotfiles_row then
    state.selected = "dotfiles"
    M.toggle_dotfiles()
  end
end

--- Open the settings modal
---@param on_change? fun(key: string, value: any)
function M.open(on_change)
  if M.is_open() then
    vim.api.nvim_set_current_win(state.win)
    M.render()
    return
  end

  state.last_error = nil
  state.selected = CONTROL_ORDER[1]
  state.on_change = on_change
  state.prev_win = vim.api.nvim_get_current_win()

  local width = 60
  local height = math.min(38, math.max(20, vim.o.lines - 4))
  local row = math.max(1, math.floor((vim.o.lines - height) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].buflisted = false

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Settings ",
    title_pos = "center",
  })

  vim.wo[state.win].cursorline = false
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"

  M.render()

  -- Keymaps
  local opts = { buffer = state.buf, silent = true, noremap = true }

  -- Focus navigation moves the indicator only between the actual controls;
  -- it never moves the cursor through the rendered help section.
  vim.keymap.set("n", "<Up>", function() M.move_focus(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() M.move_focus(1) end, opts)
  vim.keymap.set("n", "k", function() M.move_focus(-1) end, opts)
  vim.keymap.set("n", "j", function() M.move_focus(1) end, opts)

  -- Activation applies to the selected control (Space / Enter)
  vim.keymap.set("n", "<Space>", M.activate_selected, opts)
  vim.keymap.set("n", "<CR>", M.activate_selected, opts)
  vim.keymap.set("n", "t", M.toggle_dotfiles, opts)

  -- Theme changes apply only while the theme control is selected
  local function cycle_theme_if_selected(direction)
    return function()
      if state.selected == "theme" then
        M.cycle_theme(direction)
      end
    end
  end
  vim.keymap.set("n", "h", cycle_theme_if_selected(-1), opts)
  vim.keymap.set("n", "<Left>", cycle_theme_if_selected(-1), opts)
  vim.keymap.set("n", "[", cycle_theme_if_selected(-1), opts)
  vim.keymap.set("n", "l", cycle_theme_if_selected(1), opts)
  vim.keymap.set("n", "<Right>", cycle_theme_if_selected(1), opts)
  vim.keymap.set("n", "]", cycle_theme_if_selected(1), opts)

  vim.keymap.set("n", ":", ":", { buffer = state.buf, noremap = true, silent = false })

  -- Mouse: the top-right Close affordance and the control rows route through
  -- handle_click; the close button shares the safe close path with Esc/q.
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    M.handle_click(mouse.line, mouse.column, mouse.winid)
  end, opts)

  -- Single Esc closes immediately; q stays a direct close action
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)
end

return M
