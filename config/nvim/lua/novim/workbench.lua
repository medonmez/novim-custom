-- novim/workbench.lua - Project Browser & Three-Area Read-Only Git Diff Workbench
-- Part of novim custom derivative

local git = require("novim.git")
local browser = require("novim.browser")
local settings = require("novim.settings")
local settings_ui = require("novim.settings_ui")
local themes = require("novim.themes")
local keymaps = require("novim.keymaps")
local uv = vim.uv or vim.loop

local M = {}
local on_left_click
local on_left_drag
local on_left_release
local install_diff_middle_maps

-- State
local state = {
  is_open = false,
  is_tab = false,
  tab_id = nil,
  view_mode = "files", -- "files" (Project Browser) or "diff" (Git Diff)
  root_dir = nil,

  -- Project Browser State
  project_files = {},
  project_stats = { file_count = 0, dir_count = 0, dot_count = 0 },
  selected_project_index = 1,
  line_to_project_index = {},
  expanded_dirs = {},

  -- Git Diff State
  is_git = false,
  repo_root = nil,
  has_head = false,
  files = {},
  stats = { modified = 0, untracked = 0, deleted = 0, added = 0, renamed = 0, total = 0 },
  err = nil,
  selected_index = 1,
  line_to_file_index = {},

  -- Source Control State (history graph + two-endpoint comparison)
  selected_history_index = 0,
  line_to_history_index = {},
  history = {},
  history_commits = {},
  history_err = nil,
  branch = nil,
  compare = {
    old = { kind = "head", ref = "HEAD", label = "HEAD" },
    new = { kind = "worktree", ref = git.WORKTREE_REF, label = "Worktree" },
    error = nil,
  },
  history_header_line_count = 0,
  buf_history = nil,
  win_history = nil,

  header_line_count = 4,
  buf_left = nil,
  buf_middle = nil,
  win_left = nil,
  win_middle = nil,
  buf_right = nil,
  win_right = nil,
  drag = nil, -- active divider drag: { boundary, start_col, start_widths }
  ns_id = vim.api.nvim_create_namespace("novim_workbench"),
}

-- Minimum usable pane widths in columns. Each visible divider consumes one
-- column, so a three-area Diff view keeps all three panes valid while dragging.
local MIN_LEFT_WIDTH = 15
local MIN_MIDDLE_WIDTH = 20
local MIN_RIGHT_WIDTH = 20


-- Logical pane geometry persistence. The workbench captures effective widths
-- after a completed drag and before any view/layout teardown, stores plain
-- column counts per view (never window or buffer IDs) through the isolated
-- settings boundary, and clamps stored widths to the current terminal and
-- the pane minimums before applying them.
local function saved_layout()
  local ok, layout = pcall(settings.get, "layout")
  if not ok or type(layout) ~= "table" then
    return nil
  end
  return layout
end

--- Apply a stored Files left width to the live two-pane layout, clamped to
--- the current terminal and the pane minimums.
---@param left_width number
local function apply_files_geometry(left_width)
  left_width = tonumber(left_width)
  if not left_width
    or not state.win_left or not vim.api.nvim_win_is_valid(state.win_left)
    or not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return
  end
  local available = vim.o.columns - 1 -- one visible divider column
  if available < MIN_LEFT_WIDTH + MIN_RIGHT_WIDTH then
    return -- terminal too narrow for a valid two-pane layout; keep defaults
  end
  local left = math.max(MIN_LEFT_WIDTH,
    math.min(math.floor(left_width), available - MIN_RIGHT_WIDTH))
  pcall(vim.api.nvim_win_set_width, state.win_left, left)
end

--- Apply stored Diff left/middle widths to the live three-pane layout,
--- clamped to the current terminal and the pane minimums so the untouched
--- right pane stays valid.
---@param left_width number
---@param middle_width number
local function apply_diff_geometry(left_width, middle_width)
  left_width = tonumber(left_width)
  middle_width = tonumber(middle_width)
  if not left_width or not middle_width
    or not state.win_left or not vim.api.nvim_win_is_valid(state.win_left)
    or not state.win_middle or not vim.api.nvim_win_is_valid(state.win_middle)
    or not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return
  end
  local available = vim.o.columns - 2 -- two visible divider columns
  local min_total = MIN_LEFT_WIDTH + MIN_MIDDLE_WIDTH + MIN_RIGHT_WIDTH
  if available < min_total then
    return -- terminal too narrow for three usable panes; keep defaults
  end
  local left = math.max(MIN_LEFT_WIDTH,
    math.min(math.floor(left_width), available - MIN_MIDDLE_WIDTH - MIN_RIGHT_WIDTH))
  local middle = math.max(MIN_MIDDLE_WIDTH,
    math.min(math.floor(middle_width), available - left - MIN_RIGHT_WIDTH))
  local right = available - left - middle
  pcall(vim.api.nvim_win_set_width, state.win_left, left)
  pcall(vim.api.nvim_win_set_width, state.win_middle, middle)
  pcall(vim.api.nvim_win_set_width, state.win_right, right)
end

--- Restore the saved geometry of the active view. Missing, malformed, or
--- impossible values are ignored and leave the built-in starting layout.
local function restore_saved_geometry()
  local layout = saved_layout()
  if not layout then
    return
  end
  if state.view_mode == "diff" then
    if type(layout.diff) == "table" and layout.diff.left and layout.diff.middle then
      apply_diff_geometry(layout.diff.left, layout.diff.middle)
    end
  else
    if type(layout.files) == "table" and layout.files.left then
      apply_files_geometry(layout.files.left)
    end
  end
end

--- Persist the effective widths of the currently visible layout. Storage
--- failures are non-fatal and never modify the live layout.
local function save_current_view_geometry()
  if not state.win_left or not vim.api.nvim_win_is_valid(state.win_left)
    or not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return
  end
  if state.view_mode == "diff"
    and state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
    pcall(settings.set_layout, {
      diff = {
        left = vim.api.nvim_win_get_width(state.win_left),
        middle = vim.api.nvim_win_get_width(state.win_middle),
      },
    })
  elseif state.view_mode == "files" then
    pcall(settings.set_layout, {
      files = { left = vim.api.nvim_win_get_width(state.win_left) },
    })
  end
end

--- Create a scratch buffer with a fixed display name.
--- Reopening the workbench in the same session would otherwise fail with
--- E95 because a leftover buffer from the previous session holds the name.
---@param name string
---@return integer buf
local function fresh_buffer(name)
  local buf = vim.api.nvim_create_buf(false, true)
  local ok = pcall(vim.api.nvim_buf_set_name, buf, name)
  if not ok then
    for _, existing in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(existing) == name then
        pcall(vim.api.nvim_buf_delete, existing, { force = true })
      end
    end
    pcall(vim.api.nvim_buf_set_name, buf, name)
  end
  return buf
end

local function configure_scratch_buffer(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
end

-- Ensure highlights are set up
-- The palette is application-owned; the persisted theme id is validated by
-- settings.load and novim.themes falls back to Tokyo Night for unknown ids.
local function setup_highlights()
  themes.apply(settings.get("theme"))
end

--- Format summary line for Git Diff
---@param stats table
---@return string
local function format_diff_summary(stats)
  if stats.total == 0 then
    return " ✓ Working tree clean (no changes vs HEAD)"
  end

  local parts = {}
  if stats.modified > 0 then
    table.insert(parts, stats.modified .. " modified")
  end
  if stats.untracked > 0 then
    table.insert(parts, stats.untracked .. " untracked")
  end
  if stats.added > 0 then
    table.insert(parts, stats.added .. " added")
  end
  if stats.deleted > 0 then
    table.insert(parts, stats.deleted .. " deleted")
  end
  if stats.renamed > 0 then
    table.insert(parts, stats.renamed .. " renamed")
  end

  return " Changes: " .. stats.total .. " (" .. table.concat(parts, ", ") .. ")"
end

--- Render the left pane (Project Files or Git Diff)
function M.render_left_pane()
  if not state.buf_left or not vim.api.nvim_buf_is_valid(state.buf_left) then
    return
  end

  vim.bo[state.buf_left].readonly = false
  vim.bo[state.buf_left].modifiable = true

  local lines = {}
  local highlights = {} -- list of { line, col_start, col_end, group }
  state.line_to_file_index = {}
  state.line_to_project_index = {}

  local is_files_view = (state.view_mode == "files")
  local show_dots = settings.get("show_dotfiles")

  -- Header Line 1: Main Title & Action Hint
  if is_files_view then
    table.insert(lines, " PROJECT BROWSER                [s: Settings]")
  else
    table.insert(lines, " DIFF WORKBENCH (vs HEAD)       [s: Settings]")
  end
  table.insert(highlights, { #lines - 1, 0, 24, "WorkbenchHeader" })
  table.insert(highlights, { #lines - 1, 28, -1, "WorkbenchTabAction" })

  -- Header Line 2: Tab Bar
  local tab_files = is_files_view and "▶ [1: Files] " or "  [1: Files] "
  local tab_diff = not is_files_view and "▶ [2: Git Diff] " or "  [2: Git Diff] "
  local tab_line = " " .. tab_files .. " " .. tab_diff
  table.insert(lines, tab_line)

  local line_idx = #lines - 1
  if is_files_view then
    table.insert(highlights, { line_idx, 1, 14, "WorkbenchTabActive" })
    table.insert(highlights, { line_idx, 15, -1, "WorkbenchTabInactive" })
  else
    table.insert(highlights, { line_idx, 1, 14, "WorkbenchTabInactive" })
    table.insert(highlights, { line_idx, 15, -1, "WorkbenchTabActive" })
  end

  -- Header Line 3: Divider
  table.insert(lines, " " .. string.rep("─", 44))
  table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

  if is_files_view then
    -- === Project Browser View ===
    local dot_status = show_dots and "dot-folders: visible" or "dot-folders: hidden"
    local summary_text = string.format(" Files: %d, Dirs: %d (%s)", state.project_stats.file_count, state.project_stats.dir_count, dot_status)
    table.insert(lines, summary_text)
    table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })

    table.insert(lines, " " .. string.rep("─", 44))
    table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

    state.header_line_count = #lines

    if #state.project_files == 0 then
      table.insert(lines, " (Project directory has no visible files)")
      table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSubHeader" })
      table.insert(lines, " Press 's' to show dot-folders or 'r' to refresh.")
      table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSummary" })
    else
      for idx, entry in ipairs(state.project_files) do
        local marker = (idx == state.selected_project_index) and "▶" or " "
        local indent = string.rep("  ", entry.depth)
        local icon = entry.is_dir and "📁 " or "📄 "
        local display_name = entry.name .. (entry.is_dir and "/" or "")

        local line_text = string.format(" %s %s%s%s", marker, indent, icon, display_name)
        table.insert(lines, line_text)

        local current_line_idx = #lines - 1
        state.line_to_project_index[current_line_idx + 1] = idx

        -- Marker highlight
        if idx == state.selected_project_index then
          table.insert(highlights, { current_line_idx, 1, 2, "WorkbenchActiveMarker" })
        end

        -- Entry highlight
        local entry_hl = "WorkbenchBrowserFile"
        if entry.is_dir then
          entry_hl = "WorkbenchBrowserDir"
        elseif entry.is_dot then
          entry_hl = "WorkbenchBrowserDot"
        end

        local text_start_col = 3 + #indent + #icon
        table.insert(highlights, { current_line_idx, text_start_col, -1, entry_hl })
      end
    end

  else
    -- === Git Diff View ===
    if not state.is_git then
      -- Not a git repo state
      table.insert(lines, " [Not a Git Repository]")
      table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchError" })

      table.insert(lines, " Current directory is not a git worktree.")
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSubHeader" })

      table.insert(lines, " ")
      table.insert(lines, " Tip: Open novim-dev inside a Git repo.")
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })
    elseif state.err then
      -- Git error state
      table.insert(lines, " [Git Status Error]")
      table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchError" })

      table.insert(lines, " " .. tostring(state.err))
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSubHeader" })
    elseif #state.files == 0 then
      -- Clean working tree state
      table.insert(lines, " ✓ Working tree clean")
      table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchClean" })

      table.insert(lines, " No changed or untracked files relative to HEAD.")
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSubHeader" })

      table.insert(lines, " ")
      table.insert(lines, " " .. string.rep("─", 44))
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

      table.insert(lines, " Press 'r' to refresh, '?' for help, 'q' to quit.")
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })
    else
      -- Summary line
      local summary = format_diff_summary(state.stats)
      table.insert(lines, summary)
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })

      -- Line: Divider
      table.insert(lines, " " .. string.rep("─", 44))
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

      state.header_line_count = #lines

      -- File entries
      for idx, file in ipairs(state.files) do
        local marker = (idx == state.selected_index) and "▶" or " "
        local status_label = file.status
        if status_label == "??" then
          status_label = "U "
        elseif #status_label == 1 then
          status_label = status_label .. " "
        end

        local display_name = file.path
        if file.orig_path then
          display_name = file.orig_path .. " -> " .. file.path
        end

        local line_text = string.format(" %s [%s] %s", marker, status_label, display_name)
        table.insert(lines, line_text)

        local current_line_idx = #lines - 1
        state.line_to_file_index[current_line_idx + 1] = idx

        -- Highlight marker
        if idx == state.selected_index then
          table.insert(highlights, { current_line_idx, 1, 2, "WorkbenchActiveMarker" })
        end

        -- Highlight status tag
        local hl_group = "WorkbenchStatusM"
        if file.status == "??" or file.status == "U" then
          hl_group = "WorkbenchStatusU"
        elseif file.status == "A" then
          hl_group = "WorkbenchStatusA"
        elseif file.status == "D" then
          hl_group = "WorkbenchStatusD"
        elseif file.status == "R" then
          hl_group = "WorkbenchStatusR"
        end

        table.insert(highlights, { current_line_idx, 3, 7, hl_group })
        table.insert(highlights, { current_line_idx, 8, -1, "WorkbenchPath" })
      end
    end
  end

  vim.api.nvim_buf_set_lines(state.buf_left, 0, -1, false, lines)
  vim.bo[state.buf_left].modifiable = false
  vim.bo[state.buf_left].readonly = true

  -- Apply syntax highlights
  vim.api.nvim_buf_clear_namespace(state.buf_left, state.ns_id, 0, -1)
  for _, h in ipairs(highlights) do
    local end_col = h[3]
    if end_col == -1 then
      end_col = #lines[h[1] + 1]
    end
    pcall(vim.api.nvim_buf_add_highlight, state.buf_left, state.ns_id, h[4], h[1], h[2], end_col)
  end

  -- Position cursor on selected file line if left window is valid
  if state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
    if is_files_view and #state.project_files > 0 then
      local target_line = state.header_line_count + state.selected_project_index
      if target_line <= #lines then
        pcall(vim.api.nvim_win_set_cursor, state.win_left, { target_line, 1 })
      end
    elseif not is_files_view and #state.files > 0 then
      local target_line = state.header_line_count + state.selected_index
      if target_line <= #lines then
        pcall(vim.api.nvim_win_set_cursor, state.win_left, { target_line, 1 })
      end
    end
  end
end

local function diff_status_lines()
  if not state.is_git then
    return { "# Not a Git repository", "# Diff panes show local changes against HEAD." }
  elseif state.err then
    return { "# Git status error", "# " .. tostring(state.err), "# Press 'r' to refresh." }
  elseif #state.files == 0 then
    return { "# Working tree is clean", "# No changed files relative to HEAD." }
  end
  return { "# No file selected" }
end

local function render_diff_content(buf, win, file, versions, side)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines
  local binary = (side == "old") and versions.old_binary or versions.new_binary
  if binary then
    local path = (side == "old") and versions.old_path or versions.new_path
    local location = (side == "old") and (versions.old_label or "HEAD") or (versions.new_label or "working tree")
    lines = {
      "# Binary file: " .. path,
      "# Content preview suppressed (" .. location .. ").",
      "# Status: " .. file.status,
    }
  else
    lines = (side == "old") and versions.old_lines or versions.new_lines
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].filetype = "conf"
  vim.api.nvim_buf_clear_namespace(buf, state.ns_id, 0, -1)

  if not versions.is_binary then
    local old_lines = versions.old_lines
    local new_lines = versions.new_lines
    for line_number = 1, #lines do
      local changed = false
      if side == "old" then
        changed = line_number > #new_lines or old_lines[line_number] ~= new_lines[line_number]
      else
        changed = line_number > #old_lines or old_lines[line_number] ~= new_lines[line_number]
      end
      if changed then
        local group = (side == "old") and "DiffDelete" or "DiffAdd"
        pcall(vim.api.nvim_buf_add_highlight, buf, state.ns_id, group, line_number - 1, 0, -1)
      end
    end
  end

  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
    pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
  end
end

local function render_diff_pane(buf, win, side)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) ~= buf then
    vim.api.nvim_win_set_buf(win, buf)
  end

  if not state.is_git or state.err or #state.files == 0 then
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_status_lines())
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = "conf"
    vim.api.nvim_buf_clear_namespace(buf, state.ns_id, 0, -1)
    return
  end

  local file = state.files[state.selected_index]
  if not file then
    return
  end
  render_diff_content(buf, win, file,
    git.get_file_versions_between(file, state.compare.old, state.compare.new, state.repo_root), side)
end

--- Render the middle old-file pane in Diff view.
function M.render_middle_pane()
  if state.view_mode ~= "diff" or not state.buf_middle then
    return
  end
  render_diff_pane(state.buf_middle, state.win_middle, "old")
end

--- Render the right pane (Project File Preview or new-file Diff pane).
function M.render_right_pane()
  if not state.buf_right or not vim.api.nvim_buf_is_valid(state.buf_right) then
    state.buf_right = fresh_buffer("[Workbench - Preview]")
    configure_scratch_buffer(state.buf_right)
  end

  if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
    local cur_buf = vim.api.nvim_win_get_buf(state.win_right)
    if cur_buf ~= state.buf_right then
      vim.api.nvim_win_set_buf(state.win_right, state.buf_right)
    end
  end

  if state.view_mode == "diff" then
    render_diff_pane(state.buf_right, state.win_right, "new")
    return
  end

  vim.bo[state.buf_right].readonly = false
  vim.bo[state.buf_right].modifiable = true
  local selected_entry = state.project_files[state.selected_project_index]
  local show_dots = settings.get("show_dotfiles")
  local lines = browser.get_preview(selected_entry, state.root_dir, show_dots)
  vim.api.nvim_buf_set_lines(state.buf_right, 0, -1, false, lines)
  vim.bo[state.buf_right].modifiable = false
  vim.bo[state.buf_right].readonly = true
  vim.bo[state.buf_right].filetype = "conf"
  vim.api.nvim_buf_clear_namespace(state.buf_right, state.ns_id, 0, -1)
end

--- Select a specific item in the active view and update preview
---@param index integer
function M.select_file(index)
  if state.view_mode == "files" then
    if #state.project_files == 0 then return end
    if index < 1 then index = 1 end
    if index > #state.project_files then index = #state.project_files end

    if state.selected_project_index ~= index then
      state.selected_project_index = index
      M.render_left_pane()
    end
    M.render_right_pane()
  else
    if #state.files == 0 then return end
    if index < 1 then index = 1 end
    if index > #state.files then index = #state.files end

    if state.selected_index ~= index then
      state.selected_index = index
      M.render_left_pane()
    end
    M.render_middle_pane()
    M.render_right_pane()
  end
end
--- Open a regular file in the editor (right pane)
---@param entry? table
---@return boolean success
function M.open_file(entry)
  entry = entry or (state.view_mode == "files" and state.project_files[state.selected_project_index] or nil)
  if not entry then
    return false
  end

  -- Directory selection must keep right pane in read-only directory inspection
  if entry.is_dir then
    M.render_right_pane()
    return false
  end

  if not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return false
  end

  local full_path = entry.full_path or (state.root_dir .. "/" .. entry.path)
  if vim.fn.filereadable(full_path) == 0 then
    return false
  end

  -- Focus right window
  vim.api.nvim_set_current_win(state.win_right)

  -- Edit the file in right window
  vim.cmd.edit(vim.fn.fnameescape(full_path))

  -- Configure standard window options for editing in the right pane
  if vim.api.nvim_win_is_valid(state.win_right) then
    vim.wo[state.win_right].number = true
    vim.wo[state.win_right].relativenumber = false
    vim.wo[state.win_right].signcolumn = "auto"
    vim.wo[state.win_right].wrap = false
    vim.wo[state.win_right].cursorline = false
    vim.wo[state.win_right].spell = false
    vim.wo[state.win_right].foldenable = false
  end

  return true
end

--- Open currently selected item if it is a regular file
---@return boolean success
function M.open_selected_file()
  if state.view_mode == "files" then
    local entry = state.project_files[state.selected_project_index]
    return M.open_file(entry)
  end
  return false
end

local function set_preview_window_options(win, role)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.wo[win].number = true
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].spell = false
  vim.wo[win].foldenable = false
  if role == "old" then
    vim.wo[win].statusline = " %f %=[Old / HEAD]  [Tab] Next  [S-Tab] Files "
  elseif role == "new" then
    vim.wo[win].statusline = " %f %=[New / Worktree]  [S-Tab] Previous "
  else
    vim.wo[win].statusline = " %f %=[Tab] Explorer  [?] Help  [Esc Esc] Quit "
  end
end

-- =========================================================================
-- Source Control (TASK-012): history graph pane and two-endpoint comparison
-- =========================================================================

--- Build the canonical default comparison endpoint pair: working tree
--- versus HEAD. A fresh Source Control entry always returns to this pair.
local function default_compare()
  return {
    old = { kind = "head", ref = "HEAD", label = "HEAD" },
    new = { kind = "worktree", ref = git.WORKTREE_REF, label = "Worktree" },
    error = nil,
  }
end

local function worktree_endpoint()
  return { kind = "worktree", ref = git.WORKTREE_REF, label = "Worktree" }
end

--- Reflect the current comparison endpoints in the old/new pane status
--- lines so the documented direction stays visible at all times.
local function apply_compare_statuslines()
  if state.view_mode ~= "diff" then
    return
  end
  if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
    vim.wo[state.win_middle].statusline =
      " %f %=[Old: " .. tostring(state.compare.old.label) .. "]  [Tab] Next  [S-Tab] Files "
  end
  if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
    vim.wo[state.win_right].statusline =
      " %f %=[New: " .. tostring(state.compare.new.label) .. "]  [S-Tab] Previous "
  end
end

local function set_history_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].spell = false
  vim.wo[win].foldenable = false
  vim.wo[win].statusline = " %f %=[History Graph]  [O]ld [N]ew [D]efault  [r] Refresh "
end

--- Handle cursor movement inside the history pane by selecting the commit
--- row the cursor rests on, mirroring the changed-file list behavior.
local function on_history_cursor_moved()
  if not state.win_history or not vim.api.nvim_win_is_valid(state.win_history) then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(state.win_history)
  local h_idx = state.line_to_history_index[cursor[1]]
  if h_idx and h_idx ~= state.selected_history_index then
    state.selected_history_index = h_idx
    M.render_history_pane()
  end
end

--- Render the bottom-left Source Control pane: comparison status on top,
--- then the full reachable current-branch graph with merge nodes and local
--- ref decorations. Rendering is read-only and never checks out anything.
function M.render_history_pane()
  if not state.buf_history or not vim.api.nvim_buf_is_valid(state.buf_history) then
    return
  end

  vim.bo[state.buf_history].readonly = false
  vim.bo[state.buf_history].modifiable = true

  local lines = {}
  local highlights = {}
  state.line_to_history_index = {}

  -- Title with the inspected branch
  if state.is_git then
    table.insert(lines, " SOURCE CONTROL (branch: " .. tostring(state.branch or "HEAD") .. ")")
  else
    table.insert(lines, " SOURCE CONTROL")
  end
  table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchHeader" })

  -- Comparison endpoint status (documented direction: old -> new)
  local compare_base = " Compare: [Old] " .. tostring(state.compare.old.label)
    .. " -> [New] " .. tostring(state.compare.new.label)
  local compare_line = compare_base
  if state.compare.error then
    compare_line = compare_base .. "  ! " .. tostring(state.compare.error)
  end
  table.insert(lines, compare_line)
  table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSummary" })
  if state.compare.error then
    table.insert(highlights, { #lines - 1, #compare_base + 2, -1, "WorkbenchError" })
  end

  -- Visible identification of the selected history entry
  local selected = state.history_commits[state.selected_history_index]
  if selected then
    table.insert(lines, " Selected: " .. selected.hash:sub(1, 7) .. " " .. selected.subject)
  else
    table.insert(lines, " Selected: (none)")
  end
  table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSummary" })

  table.insert(lines, " " .. string.rep("─", 44))
  table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

  state.history_header_line_count = #lines

  -- Bounded history states
  if not state.is_git then
    table.insert(lines, " (Not a Git repository)")
    table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSubHeader" })
    table.insert(lines, " History requires a Git repository.")
    table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })
  elseif not state.has_head then
    table.insert(lines, " (No commits yet)")
    table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSubHeader" })
    table.insert(lines, " The current branch has no commit history.")
    table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })
  elseif state.history_err then
    table.insert(lines, " [History Error]")
    table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchError" })
    table.insert(lines, " " .. tostring(state.history_err))
    table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSubHeader" })
  elseif #state.history == 0 then
    table.insert(lines, " (No history available)")
    table.insert(highlights, { #lines - 1, 1, -1, "WorkbenchSubHeader" })
  else
    local commit_idx = 0
    for _, entry in ipairs(state.history) do
      if entry.kind == "commit" then
        commit_idx = commit_idx + 1
        local marker = (commit_idx == state.selected_history_index) and "▶" or " "
        local refs_part = (entry.refs and entry.refs ~= "") and (" (" .. entry.refs .. ")") or ""
        table.insert(lines, " " .. marker .. " " .. entry.graph .. entry.hash:sub(1, 7)
          .. refs_part .. " " .. entry.subject)
        local line_no = #lines
        state.line_to_history_index[line_no] = commit_idx
        if commit_idx == state.selected_history_index then
          table.insert(highlights, { line_no - 1, 1, 2, "WorkbenchActiveMarker" })
        end
        local art_end = 3 + #entry.graph
        table.insert(highlights, { line_no - 1, 3, art_end, "WorkbenchDivider" })
        table.insert(highlights, { line_no - 1, art_end, art_end + 7, "WorkbenchPath" })
      else
        table.insert(lines, "   " .. entry.graph)
        table.insert(highlights, { #lines - 1, 3, -1, "WorkbenchDivider" })
      end
    end
  end

  vim.api.nvim_buf_set_lines(state.buf_history, 0, -1, false, lines)
  vim.bo[state.buf_history].modifiable = false
  vim.bo[state.buf_history].readonly = true

  vim.api.nvim_buf_clear_namespace(state.buf_history, state.ns_id, 0, -1)
  for _, h in ipairs(highlights) do
    local end_col = h[3]
    if end_col == -1 then
      end_col = #lines[h[1] + 1]
    end
    pcall(vim.api.nvim_buf_add_highlight, state.buf_history, state.ns_id, h[4], h[1], h[2], end_col)
  end

  -- Position the cursor on the selected (or first) history row
  if state.win_history and vim.api.nvim_win_is_valid(state.win_history) and #state.history_commits > 0 then
    local target = (state.selected_history_index > 0) and state.selected_history_index or 1
    local target_line = state.history_header_line_count + target
    if target_line <= #lines then
      pcall(vim.api.nvim_win_set_cursor, state.win_history, { target_line, 1 })
    end
  end
end

--- Select a history entry by commit index. Selection is read-only
--- inspection: it never checks out a branch or mutates the repository.
---@param index integer
function M.select_history(index)
  local count = #state.history_commits
  if count == 0 then
    return
  end
  if index < 1 then index = 1 end
  if index > count then index = count end
  if state.selected_history_index ~= index then
    state.selected_history_index = index
    M.render_history_pane()
  end
end

--- Focus the history pane (Git Diff view only).
function M.focus_history()
  if state.view_mode ~= "diff" or not state.win_history
    or not vim.api.nvim_win_is_valid(state.win_history) then
    return false
  end
  vim.api.nvim_set_current_win(state.win_history)
  return true
end

--- Resolve the comparison endpoint implied by a selection source. "history"
--- uses the selected commit; "changes" resolves to the working tree.
--- Returns nil plus a bounded reason when nothing is selectable.
local function resolve_compare_endpoint(source)
  if source == "history" then
    local selected = state.history_commits[state.selected_history_index]
    if not selected or not selected.hash then
      return nil, "select a history row first"
    end
    return { kind = "commit", ref = selected.hash, label = selected.hash:sub(1, 7) }
  end
  return worktree_endpoint()
end

--- Two endpoints conflict when both resolve to the same commit (or both are
--- the working tree). Unresolvable refs are surfaced at content-read time.
local function compare_endpoints_conflict(a, b)
  local hash_a = git.resolve_revision(a.ref, state.repo_root)
    or (a.ref == git.WORKTREE_REF and git.WORKTREE_REF or nil)
  local hash_b = git.resolve_revision(b.ref, state.repo_root)
    or (b.ref == git.WORKTREE_REF and git.WORKTREE_REF or nil)
  if not hash_a or not hash_b then
    return false
  end
  return hash_a == hash_b
end

--- Assign one comparison endpoint side from the given selection source and
--- repopulate the old/new comparison panes. Identical endpoints are
--- rejected with a visible bounded error instead of guessing.
---@param side "old" | "new"
---@param source "changes" | "history"
---@return boolean success
function M.assign_compare_endpoint(side, source)
  if side ~= "old" and side ~= "new" then
    return false
  end
  local endpoint, err = resolve_compare_endpoint(source)
  if not endpoint then
    state.compare.error = err
    M.render_history_pane()
    return false
  end

  local other = (side == "old") and state.compare.new or state.compare.old
  if compare_endpoints_conflict(endpoint, other) then
    state.compare.error = "comparison endpoints must be distinct"
    M.render_history_pane()
    return false
  end

  state.compare[side] = endpoint
  state.compare.error = nil
  M.render_history_pane()
  M.render_middle_pane()
  M.render_right_pane()
  apply_compare_statuslines()
  return true
end

--- Reset the comparison to the default working-tree-versus-HEAD pair.
---@return boolean
function M.reset_compare()
  state.compare = default_compare()
  M.render_history_pane()
  M.render_middle_pane()
  M.render_right_pane()
  apply_compare_statuslines()
  return true
end

--- Install the history pane buffer maps. j/k/Up/Down and the mouse move the
--- selection; O/N assign the old/new comparison endpoint from the selected
--- row; D resets to the default comparison. Workbench-wide keys are
--- mirrored so every pane stays fully operable.
local function install_history_maps(buf)
  local opts = { buffer = buf, silent = true, noremap = true }

  -- View switching and shared workbench actions
  vim.keymap.set("n", "1", function() M.set_view("files") end, opts)
  vim.keymap.set("n", "b", function() M.set_view("files") end, opts)
  vim.keymap.set("n", "f", function() M.set_view("files") end, opts)
  vim.keymap.set("n", "2", function() M.set_view("diff") end, opts)
  vim.keymap.set("n", "d", function() M.set_view("diff") end, opts)
  vim.keymap.set("n", "g", function() M.set_view("diff") end, opts)
  vim.keymap.set("n", "s", M.open_settings, opts)
  vim.keymap.set("n", "S", M.open_settings, opts)

  -- Deterministic history selection
  vim.keymap.set("n", "j", function() M.select_history(state.selected_history_index + 1) end, opts)
  vim.keymap.set("n", "k", function() M.select_history(state.selected_history_index - 1) end, opts)
  vim.keymap.set("n", "<Down>", function() M.select_history(state.selected_history_index + 1) end, opts)
  vim.keymap.set("n", "<Up>", function() M.select_history(state.selected_history_index - 1) end, opts)
  local function select_history_row()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local h_idx = state.line_to_history_index[cursor[1]]
    if h_idx then
      M.select_history(h_idx)
    end
  end
  vim.keymap.set("n", "<CR>", select_history_row, opts)
  vim.keymap.set("n", "<Space>", select_history_row, opts)

  -- Two-endpoint comparison
  vim.keymap.set("n", "O", function() M.assign_compare_endpoint("old", "history") end, opts)
  vim.keymap.set("n", "N", function() M.assign_compare_endpoint("new", "history") end, opts)
  vim.keymap.set("n", "D", M.reset_compare, opts)

  -- Pane switching
  vim.keymap.set("n", "<Tab>", function()
    if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
      vim.api.nvim_set_current_win(state.win_middle)
    end
  end, opts)
  vim.keymap.set("n", "<S-Tab>", function()
    if state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
      vim.api.nvim_set_current_win(state.win_left)
    end
  end, opts)

  -- Mouse
  vim.keymap.set("n", "<LeftMouse>", on_left_click, opts)
  vim.keymap.set("n", "<2-LeftMouse>", select_history_row, opts)
  vim.keymap.set("n", "<LeftDrag>", on_left_drag, opts)
  vim.keymap.set("n", "<LeftRelease>", on_left_release, opts)

  -- Actions
  vim.keymap.set("n", "r", M.refresh, opts)
  vim.keymap.set("n", "<C-r>", M.refresh, opts)
  vim.keymap.set("n", "?", M.show_help, opts)
  vim.keymap.set("n", "q", function() M.close({ quit = true }) end, opts)
  vim.keymap.set("n", "<Esc><Esc>", function() M.close({ quit = true }) end, opts)
end


--- Add the old-file pane between the navigation and preview panes.
local function ensure_diff_layout()
  if not state.win_left or not vim.api.nvim_win_is_valid(state.win_left)
    or not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return false
  end
  if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle)
    and state.win_history and vim.api.nvim_win_is_valid(state.win_history) then
    return true
  end

  state.buf_middle = fresh_buffer("[Workbench - Old]")
  configure_scratch_buffer(state.buf_middle)
  local previous_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(state.win_left)
  local ok = pcall(vim.cmd, "rightbelow vsplit")
  if not ok then
    pcall(vim.api.nvim_buf_delete, state.buf_middle, { force = true })
    state.buf_middle = nil
    if vim.api.nvim_win_is_valid(previous_win) then
      vim.api.nvim_set_current_win(previous_win)
    end
    return false
  end

  state.win_middle = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win_middle, state.buf_middle)
  -- Establish a usable three-pane starting point. Subsequent drags preserve
  -- the untouched pane and clamp the two panes adjacent to the boundary.
  local initial_left = math.max(MIN_LEFT_WIDTH, math.min(28, math.floor(vim.o.columns * 0.24)))
  local initial_middle = math.max(MIN_MIDDLE_WIDTH, math.min(35, math.floor(vim.o.columns * 0.32)))
  pcall(vim.api.nvim_win_set_width, state.win_left, initial_left)
  pcall(vim.api.nvim_win_set_width, state.win_middle, initial_middle)
  if install_diff_middle_maps then
    install_diff_middle_maps(state.buf_middle)
  end
  set_preview_window_options(state.win_middle, "old")
  set_preview_window_options(state.win_right, "new")
  if vim.api.nvim_win_is_valid(previous_win) and previous_win ~= state.win_middle then
    vim.api.nvim_set_current_win(previous_win)
  end

  -- Split the left navigation column horizontally: current changes/status
  -- above, current-branch history graph below. The split uses a fixed
  -- session-only height; logical geometry persistence stays Files/Diff only.
  if not state.win_history or not vim.api.nvim_win_is_valid(state.win_history) then
    state.buf_history = fresh_buffer("[Workbench - History]")
    configure_scratch_buffer(state.buf_history)
    vim.api.nvim_set_current_win(state.win_left)
    local ok_history = pcall(vim.cmd, "below split")
    if ok_history then
      state.win_history = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(state.win_history, state.buf_history)
      local total_height = vim.api.nvim_win_get_height(state.win_left)
        + vim.api.nvim_win_get_height(state.win_history)
      local history_height = math.max(5, math.min(math.floor(total_height * 0.45), math.max(5, total_height - 8)))
      pcall(vim.api.nvim_win_set_height, state.win_history, history_height)
      set_history_window_options(state.win_history)
      install_history_maps(state.buf_history)
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = state.buf_history,
        callback = on_history_cursor_moved,
      })
    else
      pcall(vim.api.nvim_buf_delete, state.buf_history, { force = true })
      state.buf_history = nil
    end
    if vim.api.nvim_win_is_valid(state.win_left) then
      vim.api.nvim_set_current_win(state.win_left)
    end
  end
  return true
end

local function leave_diff_layout()
  if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
    pcall(vim.api.nvim_win_close, state.win_middle, true)
  end
  if state.win_history and vim.api.nvim_win_is_valid(state.win_history) then
    pcall(vim.api.nvim_win_close, state.win_history, true)
  end
  if state.buf_middle and vim.api.nvim_buf_is_valid(state.buf_middle) then
    pcall(vim.api.nvim_buf_delete, state.buf_middle, { force = true })
  end
  if state.buf_history and vim.api.nvim_buf_is_valid(state.buf_history) then
    pcall(vim.api.nvim_buf_delete, state.buf_history, { force = true })
  end
  state.win_middle = nil
  state.buf_middle = nil
  state.win_history = nil
  state.buf_history = nil
  state.drag = nil
end

--- Switch active view mode
---@param mode "files" | "diff"
function M.set_view(mode)
  if mode ~= "files" and mode ~= "diff" then return end
  if state.view_mode == mode then return end

  -- Capture the outgoing view before any layout rebuild or teardown so the
  -- user's last effective widths survive the switch.
  save_current_view_geometry()
  state.view_mode = mode
  if mode == "diff" then
    ensure_diff_layout()
    -- Restore after ensure_diff_layout so the saved widths are applied once
    -- the final window focus has settled ('winwidth' would otherwise bump a
    -- freshly-focused pane narrower than 20 columns back up).
    restore_saved_geometry()
    -- Diff entry is an explicit refresh boundary: status and selected content
    -- must reflect the current working tree and HEAD immediately.
    M.refresh()
  else
    leave_diff_layout()
    restore_saved_geometry()
    M.render_left_pane()
    M.render_right_pane()
  end
end

--- Toggle between "files" and "diff" views
function M.toggle_view()
  if state.view_mode == "files" then
    M.set_view("diff")
  else
    M.set_view("files")
  end
end

--- Open settings modal
function M.open_settings()
  settings_ui.open(function(key, value)
    -- On settings change, refresh workbench
    M.refresh()
  end)
end

--- Rebuild the visible project list from expansion state.
--- Scans only the root directory plus currently expanded folders, so the
--- workbench never performs a recursive traversal of the whole tree.
---@param show_dots boolean
local function rebuild_project_view(show_dots)
  local visible = {}
  local seen_dirs = {}

  local function build(entries)
    for _, entry in ipairs(entries) do
      table.insert(visible, entry)
      if entry.is_dir then
        seen_dirs[entry.path] = true
        if state.expanded_dirs[entry.path] then
          build(browser.get_immediate_entries(entry.full_path, entry.path, entry.depth + 1, show_dots))
        end
      end
    end
  end

  build(browser.get_immediate_entries(state.root_dir, "", 0, show_dots))

  -- Expansion state only survives for folders that still exist
  for path in pairs(state.expanded_dirs) do
    if not seen_dirs[path] then
      state.expanded_dirs[path] = nil
    end
  end

  -- Stats describe the currently visible list
  local stats = { file_count = 0, dir_count = 0, dot_count = 0 }
  for _, entry in ipairs(visible) do
    if entry.is_dir then
      stats.dir_count = stats.dir_count + 1
    else
      stats.file_count = stats.file_count + 1
    end
    if entry.is_dot then
      stats.dot_count = stats.dot_count + 1
    end
  end

  state.project_files = visible
  state.project_stats = stats
end

--- Detect whether expanding a directory would traverse a symlink cycle.
--- True when the directory's real path matches one of its own ancestors
--- (including the workbench root), which is only possible through a loop.
---@param entry ProjectEntry
---@return boolean
local function is_symlink_cycle(entry)
  local target_real = uv.fs_realpath(entry.full_path)
  if not target_real then
    return true
  end

  local root_real = uv.fs_realpath(state.root_dir) or state.root_dir
  local parent = entry.full_path
  while true do
    parent = parent:match("^(.*)/.+$")
    if not parent or parent == "" then
      return false
    end
    local parent_real = uv.fs_realpath(parent)
    if parent_real == target_real then
      return true
    end
    if parent == state.root_dir or parent_real == root_real then
      return false
    end
  end
end

--- Expand or collapse a directory row (double-click behavior).
--- Expansion scans and reveals only the folder's immediate children; collapse
--- removes the folder and all descendants from the visible list. Files on
--- disk are never modified.
---@param entry ProjectEntry
function M.toggle_dir_expansion(entry)
  if not entry or not entry.is_dir then
    return
  end

  if state.expanded_dirs[entry.path] then
    -- Collapse: drop the folder and every descendant from expansion state
    local prefix = entry.path .. "/"
    state.expanded_dirs[entry.path] = nil
    for path in pairs(state.expanded_dirs) do
      if path:sub(1, #prefix) == prefix then
        state.expanded_dirs[path] = nil
      end
    end
  else
    -- Refuse expansion through a symlink loop
    if is_symlink_cycle(entry) then
      return
    end
    state.expanded_dirs[entry.path] = true
  end

  -- Rebuild the visible list; only expanded folders are rescanned
  rebuild_project_view(settings.get("show_dotfiles"))

  if state.selected_project_index > #state.project_files then
    state.selected_project_index = math.max(1, #state.project_files)
  end

  M.render_left_pane()
  M.render_middle_pane()
  M.render_right_pane()
end

--- Refresh workbench data (both Project Files and Git Diff)
function M.refresh()
  state.root_dir = vim.fn.getcwd()

  -- 1. Refresh Project Browser (lazy: root entries plus expanded folders only)
  rebuild_project_view(settings.get("show_dotfiles"))
  if state.selected_project_index > #state.project_files then
    state.selected_project_index = math.max(1, #state.project_files)
  end

  -- 2. Refresh Git Diff
  state.is_git, state.repo_root = git.get_repo_info()
  if state.is_git then
    state.has_head = git.has_head(state.repo_root)
    state.files, state.stats, state.err = git.get_changed_files(state.repo_root)
  else
    state.files = {}
    state.stats = { modified = 0, untracked = 0, deleted = 0, added = 0, renamed = 0, total = 0 }
    state.err = nil
  end

  -- 3. Refresh Source Control history (read-only log, refs, branch name).
  --    Endpoint selection is deliberately preserved across refreshes.
  if state.is_git then
    state.branch = git.get_current_branch(state.repo_root)
    local entries, hist_err = git.get_history(state.repo_root)
    state.history = entries or {}
    state.history_err = hist_err
  else
    state.branch = nil
    state.history = {}
    state.history_err = nil
  end
  state.history_commits = {}
  for _, entry in ipairs(state.history) do
    if entry.kind == "commit" then
      table.insert(state.history_commits, entry)
    end
  end
  if (state.selected_history_index or 0) > #state.history_commits then
    state.selected_history_index = #state.history_commits
  end

  if state.selected_index > #state.files then
    state.selected_index = math.max(1, #state.files)
  end

  M.render_left_pane()
  M.render_history_pane()
  M.render_middle_pane()
  M.render_right_pane()
  apply_compare_statuslines()
end

--- Handle cursor movement in left pane
local function on_left_cursor_moved()
  if not state.win_left or not vim.api.nvim_win_is_valid(state.win_left) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.win_left)
  local line_num = cursor[1]

  if state.view_mode == "files" then
    local p_idx = state.line_to_project_index[line_num]
    if p_idx and p_idx ~= state.selected_project_index then
      state.selected_project_index = p_idx
      M.render_left_pane()
      M.render_right_pane()
    end
  else
    local f_idx = state.line_to_file_index[line_num]
    if f_idx and f_idx ~= state.selected_index then
      state.selected_index = f_idx
      M.render_left_pane()
      M.render_middle_pane()
      M.render_right_pane()
    end
  end
end

--- Return visible divider columns in pane order.
---@return table[] dividers
local function divider_column()
  if not state.win_left or not vim.api.nvim_win_is_valid(state.win_left)
    or not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return {}
  end

  local windows = { state.win_left }
  if state.view_mode == "diff" and state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
    table.insert(windows, state.win_middle)
  end
  table.insert(windows, state.win_right)

  local dividers = {}
  for i = 1, #windows - 1 do
    local first_pos = vim.fn.win_screenpos(windows[i])
    local next_pos = vim.fn.win_screenpos(windows[i + 1])
    local sep_col = next_pos[2] - 1
    if first_pos[2] + vim.api.nvim_win_get_width(windows[i]) == sep_col then
      table.insert(dividers, { column = sep_col, boundary = i })
    end
  end
  return dividers
end

--- Resize one Diff boundary while preserving the other pane widths.
--- Boundary 1 is left/middle; boundary 2 is middle/right.
---@param boundary integer
---@param target_width number
---@return integer actual_width
function M.resize_diff_boundary(boundary, target_width)
  if state.view_mode ~= "diff" or boundary < 1 or boundary > 2
    or not state.win_left or not vim.api.nvim_win_is_valid(state.win_left)
    or not state.win_middle or not vim.api.nvim_win_is_valid(state.win_middle)
    or not state.win_right or not vim.api.nvim_win_is_valid(state.win_right) then
    return 0
  end

  local widths = {
    vim.api.nvim_win_get_width(state.win_left),
    vim.api.nvim_win_get_width(state.win_middle),
    vim.api.nvim_win_get_width(state.win_right),
  }
  local first = boundary
  local second = boundary + 1
  local minimum_first = (boundary == 1) and math.max(MIN_LEFT_WIDTH, vim.o.winminwidth or 0) or MIN_MIDDLE_WIDTH
  local minimum_second = (boundary == 1) and MIN_MIDDLE_WIDTH or MIN_RIGHT_WIDTH
  local available = widths[first] + widths[second]
  local max_first = math.max(minimum_first, available - minimum_second)
  local width = math.floor(tonumber(target_width) or 0)
  width = math.max(minimum_first, math.min(max_first, width))
  local second_width = available - width

  local first_win = ({ state.win_left, state.win_middle })[first]
  local second_win = ({ state.win_middle, state.win_right })[boundary]
  pcall(vim.api.nvim_win_set_width, first_win, width)
  pcall(vim.api.nvim_win_set_width, second_win, second_width)
  return vim.api.nvim_win_get_width(first_win)
end

--- Resize the left pane to a target width, clamped so both panes stay usable.
--- In Diff view this is the left/middle boundary; in Files view it remains
--- the accepted left/right two-pane behavior.
---@param target_width number
---@return integer actual_width
function M.resize_left_pane(target_width)
  if not state.win_left or not vim.api.nvim_win_is_valid(state.win_left) then
    return 0
  end

  if state.view_mode == "diff" and state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
    return M.resize_diff_boundary(1, target_width)
  end

  local total_cols = vim.o.columns
  local min_w = math.max(MIN_LEFT_WIDTH, vim.o.winminwidth or 0)
  local max_w = total_cols - MIN_RIGHT_WIDTH - 1
  if max_w < min_w then
    max_w = min_w
  end

  local width = math.floor(tonumber(target_width) or 0)
  width = math.max(min_w, math.min(max_w, width))

  if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
    pcall(vim.api.nvim_win_set_width, state.win_left, width)
  end
  return vim.api.nvim_win_get_width(state.win_left)
end

--- Begin a divider drag anchored at the given screen column.
---@param screencol integer
function M.pane_drag_start(screencol)
  for _, divider in ipairs(divider_column()) do
    if divider.column == screencol then
      if state.view_mode == "diff" then
        state.drag = {
          boundary = divider.boundary,
          start_col = screencol,
          start_widths = {
            vim.api.nvim_win_get_width(state.win_left),
            vim.api.nvim_win_get_width(state.win_middle),
            vim.api.nvim_win_get_width(state.win_right),
          },
        }
      else
        state.drag = {
          boundary = 1,
          start_col = screencol,
          start_widths = { vim.api.nvim_win_get_width(state.win_left) },
        }
      end
      return
    end
  end
end

--- Move an active divider drag to the given screen column and resize live.
--- Without an active drag this is a no-op, so stale drag events are harmless.
---@param screencol integer
function M.pane_drag_move(screencol)
  if not state.drag then
    return
  end
  local delta = screencol - state.drag.start_col
  if state.view_mode == "diff" then
    local boundary = state.drag.boundary
    M.resize_diff_boundary(boundary, state.drag.start_widths[boundary] + delta)
  else
    M.resize_left_pane(state.drag.start_widths[1] + delta)
  end
end

--- End the active divider drag and persist the effective widths.
function M.pane_drag_end()
  if state.drag then
    save_current_view_geometry()
  end
  state.drag = nil
end

--- Handle mouse click in the workbench panes.
on_left_click = function()
  local mouse = vim.fn.getmousepos()

  -- A press on the visible pane boundary starts a divider drag instead of
  -- changing the selection; dragging the boundary resizes both directions.
  for _, divider in ipairs(divider_column()) do
    if mouse.screencol == divider.column
      and (mouse.winid == state.win_left or mouse.winid == state.win_middle
        or mouse.winid == state.win_right or mouse.winid == 0) then
      M.pane_drag_start(mouse.screencol)
      return
    end
  end

  if mouse.winid == state.win_left then
    -- Check if click was on header tabs
    if mouse.line == 1 then
      -- Clicked on "[s: Settings]"
      if mouse.column >= 25 then
        M.open_settings()
        return
      end
    elseif mouse.line == 2 then
      -- Clicked on tab bar
      if mouse.column <= 14 then
        M.set_view("files")
        return
      else
        M.set_view("diff")
        return
      end
    end

    if state.view_mode == "files" then
      local p_idx = state.line_to_project_index[mouse.line]
      if p_idx then
        state.selected_project_index = p_idx
        M.render_left_pane()
        M.render_right_pane()
      end
    else
      local file_idx = state.line_to_file_index[mouse.line]
      if file_idx then
        state.selected_index = file_idx
        M.render_left_pane()
        M.render_middle_pane()
        M.render_right_pane()
      end
    end
  elseif mouse.winid == state.win_history then
    local h_idx = state.line_to_history_index[mouse.line]
    if h_idx then
      M.select_history(h_idx)
    end
  end
end

--- Handle mouse drag motion: resize the panes while a divider drag is active.
on_left_drag = function()
  M.pane_drag_move(vim.fn.getmousepos().screencol)
end

--- Handle mouse release: finish any active divider drag.
on_left_release = function()
  M.pane_drag_end()
end

-- Bind the dynamically-created old-file buffer. This is also called when a
-- running Files view transitions into Diff, not only during initial launch.
install_diff_middle_maps = function(buf)
  local opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "1", function() M.set_view("files") end, opts)
  vim.keymap.set("n", "b", function() M.set_view("files") end, opts)
  vim.keymap.set("n", "f", function() M.set_view("files") end, opts)
  vim.keymap.set("n", "2", function() M.set_view("diff") end, opts)
  vim.keymap.set("n", "d", function() M.set_view("diff") end, opts)
  vim.keymap.set("n", "g", function() M.set_view("diff") end, opts)
  vim.keymap.set("n", "s", M.open_settings, opts)
  vim.keymap.set("n", "S", M.open_settings, opts)
  vim.keymap.set("n", "j", function() M.select_file(state.selected_index + 1) end, opts)
  vim.keymap.set("n", "k", function() M.select_file(state.selected_index - 1) end, opts)
  vim.keymap.set("n", "<Down>", function() M.select_file(state.selected_index + 1) end, opts)
  vim.keymap.set("n", "<Up>", function() M.select_file(state.selected_index - 1) end, opts)
  vim.keymap.set("n", "<Tab>", function()
    if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
      vim.api.nvim_set_current_win(state.win_right)
    end
  end, opts)
  vim.keymap.set("n", "<S-Tab>", function()
    if state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
      vim.api.nvim_set_current_win(state.win_left)
    end
  end, opts)
  vim.keymap.set("n", "<LeftMouse>", on_left_click, opts)
  vim.keymap.set("n", "<LeftDrag>", on_left_drag, opts)
  vim.keymap.set("n", "<LeftRelease>", on_left_release, opts)
  vim.keymap.set("n", "r", M.refresh, opts)
  vim.keymap.set("n", "<C-r>", M.refresh, opts)
  vim.keymap.set("n", "?", M.show_help, opts)
  vim.keymap.set("n", "q", function() M.close({ quit = true }) end, opts)
  vim.keymap.set("n", "<Esc><Esc>", function() M.close({ quit = true }) end, opts)
end



--- Show help popup
function M.show_help()
  local help_lines = {
    " novim-dev Workbench & Project Browser",
    " ────────────────────────────────────────────────────────",
    " Views:",
    "   [1] or [b]       Project Files Browser",
    "   [2] or [d]       Git Diff Workbench (vs HEAD)",
    "   [s]              Settings (toggle dot-folders)",
    " ────────────────────────────────────────────────────────",
    " Navigation & Editing:",
    "   j / k or ↑ / ↓   Move between items",
    "   Enter / Double-Click  Open regular file in editor",
    "   Space            Preview selected item",
    "   Left Click       Select item / switch tabs",
    "   Tab / S-Tab      Switch between visible panes",
    "   Drag Divider     Resize adjacent panes with mouse",
    "   r                Refresh files and Git status",
    "   ?                Show this help",
    "   q or Esc Esc     Quit / Close workbench",
    " ────────────────────────────────────────────────────────",
    " Source Control (Git Diff view):",
    "   Changes list     Current changes/status (top-left)",
    "   History graph    Full current-branch history (bottom-left)",
    "   H                Focus the history list",
    "   O / N            Set old/new compare endpoint from selection",
    "   D                Reset compare to HEAD vs working tree",
    "   Selection is read-only; nothing is ever checked out.",
    " ────────────────────────────────────────────────────────",
    " Settings & Display:",
    "   Dot-folders & hidden files are hidden by default.",
    "   Press [s] to open Settings and toggle visibility.",
    "   Settings persist across launches in isolated state.",
    " ────────────────────────────────────────────────────────",
    " Note: Git Diff is strictly read-only inspection.",
  }

  local width = 60
  local height = #help_lines + 2
  local row = math.max(1, math.floor((vim.o.lines - height) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Workbench Help ",
    title_pos = "center",
  })

  local function close_help()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local keys = { "q", "<Esc>", "<CR>", "<Space>", "?" }
  for _, key in ipairs(keys) do
    vim.keymap.set("n", key, close_help, { buffer = buf, silent = true })
  end

end
--- Canonical workbench keymap documentation. This is the single source that
--- the settings panel key-help renders and the tests pin to actual mappings.
---@return table
function M.get_keymap_docs()
  return keymaps.workbench
end


--- Close workbench safely and preserve editor layout
---@param opts? { quit?: boolean }
function M.close(opts)
  if not state.is_open then
    return
  end

  opts = opts or {}
  -- Persist the effective layout before any teardown path runs.
  save_current_view_geometry()
  local is_tab_mode = state.is_tab
  local tab_id = state.tab_id
  local all_tabs = vim.api.nvim_list_tabpages()

  -- If opened in a dedicated tab and multiple tabs exist, close the tab cleanly
  if is_tab_mode and #all_tabs > 1 and tab_id and vim.api.nvim_tabpage_is_valid(tab_id) then
    state.is_open = false
    state.is_tab = false
    state.tab_id = nil
    state.buf_left = nil
    state.win_left = nil
    state.buf_middle = nil
    state.win_middle = nil
    state.buf_history = nil
    state.win_history = nil
    state.buf_right = nil
    state.win_right = nil
    pcall(vim.cmd, "tabclose")
    return
  end

  -- If opened as a split alongside other editor windows
  local wins = {}
  if state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
    table.insert(wins, state.win_left)
  end
  if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
    table.insert(wins, state.win_right)
  end
  if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
    table.insert(wins, state.win_middle)
  end
  if state.win_history and vim.api.nvim_win_is_valid(state.win_history) then
    table.insert(wins, state.win_history)
  end

  local all_wins = vim.api.nvim_list_wins()

  if #all_wins > #wins then
    -- Other editor windows exist: close workbench windows without exiting Neovim
    state.is_open = false
    for _, w in ipairs(wins) do
      pcall(vim.api.nvim_win_close, w, true)
    end
    state.win_left = nil
    state.win_middle = nil
    state.win_history = nil
    state.win_right = nil
    state.buf_left = nil
    state.buf_middle = nil
    state.buf_history = nil
    state.buf_right = nil
    return
  end

  -- Workbench is the only UI
  if opts.quit then
    local unsaved = false
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
        unsaved = true
        break
      end
    end

    if unsaved then
      local ok = pcall(vim.cmd, "confirm qa")
      if not ok then
        return
      end
    else
      state.is_open = false
      pcall(vim.cmd, "qa")
    end
  else
    state.is_open = false
    if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
      pcall(vim.api.nvim_win_close, state.win_middle, true)
    end
    if state.win_history and vim.api.nvim_win_is_valid(state.win_history) then
      pcall(vim.api.nvim_win_close, state.win_history, true)
    end
    if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
      pcall(vim.api.nvim_win_close, state.win_right, true)
    end
    if state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
      local empty_buf = vim.api.nvim_create_buf(true, false)
      pcall(vim.api.nvim_win_set_buf, state.win_left, empty_buf)
    end
    state.win_left = nil
    state.win_middle = nil
    state.win_history = nil
    state.win_right = nil
    state.buf_left = nil
    state.buf_middle = nil
    state.buf_history = nil
    state.buf_right = nil
  end
end

function M.open(opts)
  setup_highlights()
  opts = opts or {}

  if opts.view then
    state.view_mode = opts.view
  end

  -- If already open, focus left window and refresh
  if state.is_open and state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
    if state.tab_id and vim.api.nvim_tabpage_is_valid(state.tab_id) then
      vim.api.nvim_set_current_tabpage(state.tab_id)
    end
    vim.api.nvim_set_current_win(state.win_left)
    if state.view_mode == "diff" then
      ensure_diff_layout()
    else
      leave_diff_layout()
    end
    restore_saved_geometry()
    M.refresh()
    return
  end

  -- Ensure mouse is enabled and window minimum width is set
  vim.opt.mouse = "a"
  vim.opt.winminwidth = 15

  -- Check if we are opening from an existing editing session with active files/buffers
  local current_buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_buf)
  local is_modified = vim.bo[current_buf].modified
  local is_existing_session = (buf_name ~= "" or is_modified or #vim.api.nvim_list_wins() > 1 or #vim.api.nvim_list_tabpages() > 1)

  if is_existing_session then
    vim.cmd("tabnew")
    state.is_tab = true
    state.tab_id = vim.api.nvim_get_current_tabpage()
  else
    vim.cmd("silent! only")
    state.is_tab = false
    state.tab_id = vim.api.nvim_get_current_tabpage()
  end

  -- Create buffers (safe to reopen within the same session)
  state.buf_left = fresh_buffer("[Workbench - Navigation]")
  state.buf_right = fresh_buffer("[Workbench - Preview]")

  for _, buf in ipairs({ state.buf_left, state.buf_right }) do
    configure_scratch_buffer(buf)
  end


  -- Setup left window
  state.win_left = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win_left, state.buf_left)

  local total_cols = vim.o.columns
  local left_width = math.max(26, math.min(50, math.floor(total_cols * 0.32)))

  -- Setup right window via vertical split
  vim.cmd("rightbelow vsplit")
  state.win_right = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win_right, state.buf_right)

  -- Set left window width
  vim.api.nvim_win_set_width(state.win_left, left_width)

  if state.view_mode == "diff" then
    ensure_diff_layout()
  end

  -- Window options
  local function set_win_opts(win, is_left)
    if not vim.api.nvim_win_is_valid(win) then return end
    vim.wo[win].number = not is_left
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = is_left
    vim.wo[win].spell = false
    vim.wo[win].foldenable = false
    if is_left then
      vim.wo[win].statusline = " %f %=[1] Files  [2] Diff  [s] Settings  [r] Refresh  [?] Help "
    else
      set_preview_window_options(win, state.view_mode == "diff" and "new" or "preview")
    end
  end

  set_win_opts(state.win_left, true)
  set_win_opts(state.win_right, false)

  -- Keymaps for Left Buffer
  local function set_left_maps(buf)
    local opts = { buffer = buf, silent = true, noremap = true }

    -- View switching
    vim.keymap.set("n", "1", function() M.set_view("files") end, opts)
    vim.keymap.set("n", "b", function() M.set_view("files") end, opts)
    vim.keymap.set("n", "f", function() M.set_view("files") end, opts)
    vim.keymap.set("n", "2", function() M.set_view("diff") end, opts)
    vim.keymap.set("n", "d", function() M.set_view("diff") end, opts)
    vim.keymap.set("n", "g", function() M.set_view("diff") end, opts)
    vim.keymap.set("n", "s", M.open_settings, opts)
    vim.keymap.set("n", "S", M.open_settings, opts)

    -- Command line
    vim.keymap.set("n", ":", ":", { buffer = buf, noremap = true, silent = false })

    -- Navigation
    vim.keymap.set("n", "j", function()
      local count = (state.view_mode == "files") and #state.project_files or #state.files
      local cur_idx = (state.view_mode == "files") and state.selected_project_index or state.selected_index
      if count > 0 then
        M.select_file(math.min(count, cur_idx + 1))
      end
    end, opts)

    vim.keymap.set("n", "k", function()
      local count = (state.view_mode == "files") and #state.project_files or #state.files
      local cur_idx = (state.view_mode == "files") and state.selected_project_index or state.selected_index
      if count > 0 then
        M.select_file(math.max(1, cur_idx - 1))
      end
    end, opts)

    vim.keymap.set("n", "<Down>", function()
      local count = (state.view_mode == "files") and #state.project_files or #state.files
      local cur_idx = (state.view_mode == "files") and state.selected_project_index or state.selected_index
      if count > 0 then
        M.select_file(math.min(count, cur_idx + 1))
      end
    end, opts)

    vim.keymap.set("n", "<Up>", function()
      local count = (state.view_mode == "files") and #state.project_files or #state.files
      local cur_idx = (state.view_mode == "files") and state.selected_project_index or state.selected_index
      if count > 0 then
        M.select_file(math.max(1, cur_idx - 1))
      end
    end, opts)

    -- Source Control comparison endpoints (TASK-012)
    vim.keymap.set("n", "O", function() M.assign_compare_endpoint("old", "changes") end, opts)
    vim.keymap.set("n", "N", function() M.assign_compare_endpoint("new", "changes") end, opts)
    vim.keymap.set("n", "D", M.reset_compare, opts)
    vim.keymap.set("n", "H", function() M.focus_history() end, opts)
    vim.keymap.set("n", "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      if state.view_mode == "files" then
        local p_idx = state.line_to_project_index[cursor[1]]
        if p_idx then
          state.selected_project_index = p_idx
          local entry = state.project_files[p_idx]
          if entry and not entry.is_dir then
            M.open_file(entry)
          else
            M.render_left_pane()
            M.render_right_pane()
          end
        end
      else
        local f_idx = state.line_to_file_index[cursor[1]]
        if f_idx then M.select_file(f_idx) end
      end
    end, opts)

    vim.keymap.set("n", "o", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      if state.view_mode == "files" then
        local p_idx = state.line_to_project_index[cursor[1]]
        if p_idx then
          state.selected_project_index = p_idx
          local entry = state.project_files[p_idx]
          if entry and not entry.is_dir then
            M.open_file(entry)
          else
            M.render_left_pane()
            M.render_right_pane()
          end
        end
      else
        local f_idx = state.line_to_file_index[cursor[1]]
        if f_idx then M.select_file(f_idx) end
      end
    end, opts)

    vim.keymap.set("n", "<Space>", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      if state.view_mode == "files" then
        local p_idx = state.line_to_project_index[cursor[1]]
        if p_idx then M.select_file(p_idx) end
      else
        local f_idx = state.line_to_file_index[cursor[1]]
        if f_idx then M.select_file(f_idx) end
      end
    end, opts)

    -- Mouse navigation
    vim.keymap.set("n", "<LeftMouse>", on_left_click, opts)
    vim.keymap.set("n", "<2-LeftMouse>", function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid == state.win_left and state.view_mode == "files" then
        local p_idx = state.line_to_project_index[mouse.line]
        if p_idx then
          state.selected_project_index = p_idx
          local entry = state.project_files[p_idx]
          if entry and entry.is_dir then
            M.toggle_dir_expansion(entry)
          elseif entry then
            M.open_file(entry)
          end
        end
      end
    end, opts)

    -- Application-owned divider drag (press starts it via <LeftMouse>)
    vim.keymap.set("n", "<LeftDrag>", on_left_drag, opts)
    vim.keymap.set("n", "<LeftRelease>", on_left_release, opts)

    -- Pane switching
    vim.keymap.set("n", "<Tab>", function()
      local target = state.win_right
      if state.view_mode == "diff" and state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
        target = state.win_middle
      end
      if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
      end
    end, opts)

    -- Actions
    vim.keymap.set("n", "r", M.refresh, opts)
    vim.keymap.set("n", "<C-r>", M.refresh, opts)
    vim.keymap.set("n", "?", M.show_help, opts)
    vim.keymap.set("n", "q", function() M.close({ quit = true }) end, opts)
    vim.keymap.set("n", "<Esc><Esc>", function() M.close({ quit = true }) end, opts)
  end

  -- Keymaps for Right Buffer
  local function set_right_maps(buf)
    local opts = { buffer = buf, silent = true, noremap = true }

    -- View switching
    vim.keymap.set("n", "1", function() M.set_view("files") end, opts)
    vim.keymap.set("n", "b", function() M.set_view("files") end, opts)
    vim.keymap.set("n", "f", function() M.set_view("files") end, opts)
    vim.keymap.set("n", "2", function() M.set_view("diff") end, opts)
    vim.keymap.set("n", "d", function() M.set_view("diff") end, opts)
    vim.keymap.set("n", "g", function() M.set_view("diff") end, opts)
    vim.keymap.set("n", "s", M.open_settings, opts)
    vim.keymap.set("n", "S", M.open_settings, opts)

    -- Open file from preview pane
    vim.keymap.set("n", "<CR>", function()
      if state.view_mode == "files" then
        local entry = state.project_files[state.selected_project_index]
        if entry and not entry.is_dir then
          M.open_file(entry)
        end
      end
    end, opts)
    vim.keymap.set("n", "e", function()
      if state.view_mode == "files" then
        local entry = state.project_files[state.selected_project_index]
        if entry and not entry.is_dir then
          M.open_file(entry)
        end
      end
    end, opts)
    vim.keymap.set("n", "o", function()
      if state.view_mode == "files" then
        local entry = state.project_files[state.selected_project_index]
        if entry and not entry.is_dir then
          M.open_file(entry)
        end
      end
    end, opts)
    vim.keymap.set("n", "<2-LeftMouse>", function()
      if state.view_mode == "files" then
        local entry = state.project_files[state.selected_project_index]
        if entry and not entry.is_dir then
          M.open_file(entry)
        end
      end
    end, opts)

    vim.keymap.set("n", "<LeftMouse>", on_left_click, opts)
    vim.keymap.set("n", "<LeftDrag>", on_left_drag, opts)
    vim.keymap.set("n", "<LeftRelease>", on_left_release, opts)

    -- Pane switching
    vim.keymap.set("n", "<Tab>", function()
      local target = state.win_left
      if state.view_mode == "diff" and state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
        target = state.win_middle
      end
      if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
      end
    end, opts)

    vim.keymap.set("n", "<S-Tab>", function()
      local target = state.win_left
      if state.view_mode == "diff" and state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
        target = state.win_middle
      end
      if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
      end
    end, opts)

    -- Actions
    vim.keymap.set("n", "r", M.refresh, opts)
    vim.keymap.set("n", "<C-r>", M.refresh, opts)
    vim.keymap.set("n", "?", M.show_help, opts)
    vim.keymap.set("n", "q", function() M.close({ quit = true }) end, opts)
    vim.keymap.set("n", "<Esc><Esc>", function() M.close({ quit = true }) end, opts)
  end

  set_left_maps(state.buf_left)
  set_right_maps(state.buf_right)

  -- Autocommands for cursor movement
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = state.buf_left,
    callback = on_left_cursor_moved,
  })

  -- Switch focus to left window
  vim.api.nvim_set_current_win(state.win_left)

  -- Restore persisted geometry after the final focus switch; 'winwidth'
  -- would otherwise widen a freshly-focused pane narrower than 20 columns.
  restore_saved_geometry()
  state.is_open = true

  -- A new workbench launch always starts collapsed at the root
  state.expanded_dirs = {}

  -- A fresh Source Control entry restores the default comparison endpoints
  -- (working tree versus HEAD); custom endpoints never outlive the launch.
  state.compare = default_compare()
  state.selected_history_index = 0

  -- Populate data
  M.refresh()
end

--- Get current workbench state for diagnostics / testing
---@return table
function M.get_state()
  local active_files = (state.view_mode == "diff") and state.files or state.project_files
  local active_file = (state.view_mode == "diff") and state.files[state.selected_index] or state.project_files[state.selected_project_index]
  return {
    is_open = state.is_open,
    is_tab = state.is_tab,
    tab_id = state.tab_id,
    view_mode = state.view_mode,
    root_dir = state.root_dir,
    is_git = state.is_git,
    repo_root = state.repo_root,
    has_head = state.has_head,
    file_count = #active_files,
    git_file_count = #state.files,
    project_file_count = #state.project_files,
    files = state.files,
    project_files = state.project_files,
    stats = state.stats,
    project_stats = state.project_stats,
    expanded_dirs = state.expanded_dirs,
    selected_index = state.selected_index,
    selected_project_index = state.selected_project_index,
    selected_history_index = state.selected_history_index,
    history = state.history,
    history_commits = state.history_commits,
    history_count = #state.history_commits,
    history_err = state.history_err,
    branch = state.branch,
    compare = {
      old = vim.deepcopy(state.compare.old),
      new = vim.deepcopy(state.compare.new),
      error = state.compare.error,
    },
    history_header_line_count = state.history_header_line_count,
    line_to_history_index = state.line_to_history_index,
    win_history = state.win_history,
    buf_history = state.buf_history,
    active_file = active_file,
    settings = settings.get_all(),
    header_line_count = state.header_line_count,
    win_left = state.win_left,
    win_middle = state.win_middle,
    win_right = state.win_right,
    buf_left = state.buf_left,
    buf_middle = state.buf_middle,
    buf_right = state.buf_right,
  }
end

return M
