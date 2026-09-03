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
local on_right_click
local install_diff_middle_maps
local install_editor_maps
local rebuild_project_view

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

  -- Local write state (TASK-013): one bounded notice about the last write
  -- attempt and the transient commit-message input. Neither is persisted
  -- across launches; the notice survives refreshes until the next attempt.
  write_notice = nil, -- { level = "ok" | "error", text = string }
  commit_input = nil, -- { buf, win, prev_win, error }

  -- Editor interaction state (TASK-014): a transient notice about the last
  -- mouse auto-copy attempt and the bounded unsaved-changes confirmation.
  -- Both are session-only and never persisted.
  copy_notice = nil,    -- { level = "ok" | "error", text = string }
  preview_return = nil, -- { buf, win, prev_win }

  -- Files create/rename and context menu state (TASK-020)
  file_input = nil,   -- { buf, win, prev_win, mode = "new_file"|"new_folder"|"rename", target, error, config }
  context_menu = nil, -- { buf, win, prev_win, selected, items, target }
  -- Files copy/paste/move clipboard (TASK-021)
  -- Session-only in-memory single-source clipboard: { full_path, path, name, is_dir }
  files_clipboard = nil,

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

    -- Bounded, visible notice about the last attempted Files write action (TASK-020).
    if state.write_notice then
      local is_error = (state.write_notice.level == "error")
      table.insert(lines, (is_error and " ! " or " ✓ ") .. tostring(state.write_notice.text))
      table.insert(highlights, { #lines - 1, 0, -1, is_error and "WorkbenchError" or "WorkbenchClean" })
    end

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
      -- A write attempt that emptied the changes list (a final commit, or a
      -- failed commit with nothing staged) must still render its bounded
      -- notice here, not only when change rows exist.
      if state.write_notice then
        local is_error = (state.write_notice.level == "error")
        table.insert(lines, (is_error and " ! " or " ✓ ") .. tostring(state.write_notice.text))
        table.insert(highlights, { #lines - 1, 0, -1, is_error and "WorkbenchError" or "WorkbenchClean" })
      end

      table.insert(lines, " ")
      table.insert(lines, " " .. string.rep("─", 44))
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

      table.insert(lines, " Press 'r' to refresh, '?' for help, 'q' to quit.")
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })
    else
      -- Summary line, extended with the staged-entry count (TASK-013)
      local summary = format_diff_summary(state.stats)
      local staged_count = 0
      for _, f in ipairs(state.files) do
        if f.is_staged then staged_count = staged_count + 1 end
      end
      if staged_count > 0 then
        summary = summary .. " | staged: " .. staged_count
      end
      table.insert(lines, summary)
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchSummary" })

      -- Bounded, visible notice about the last attempted write action. A
      -- failed write renders an error here and never claims success.
      if state.write_notice then
        local is_error = (state.write_notice.level == "error")
        table.insert(lines, (is_error and " ! " or " ✓ ") .. tostring(state.write_notice.text))
        table.insert(highlights, { #lines - 1, 0, -1, is_error and "WorkbenchError" or "WorkbenchClean" })
      end

      -- Line: Divider
      table.insert(lines, " " .. string.rep("─", 44))
      table.insert(highlights, { #lines - 1, 0, -1, "WorkbenchDivider" })

      state.header_line_count = #lines

      -- File entries: "[M ]" = unstaged, "[M+]" = something staged for this
      -- path, "[U ]" = untracked; rename rows show old -> new exactly.
      for idx, file in ipairs(state.files) do
        local marker = (idx == state.selected_index) and "▶" or " "
        local status_code = (file.status == "??") and "U" or file.status
        -- Two-column code: the second column is "+" when something for this
        -- path is staged, " " when it is unstaged ("[M ]" / "[M+]" / "[U ]").
        if #status_code < 2 then
          status_code = status_code .. (file.is_staged and "+" or " ")
        elseif file.is_staged then
          status_code = status_code .. "+"
        end
        local tag = "[" .. status_code .. "]"

        local display_name = file.path
        if file.orig_path then
          display_name = file.orig_path .. " -> " .. file.path
        end

        local line_text = string.format(" %s %s %s", marker, tag, display_name)
        table.insert(lines, line_text)

        local current_line_idx = #lines - 1
        state.line_to_file_index[current_line_idx + 1] = idx

        -- Highlight marker
        if idx == state.selected_index then
          table.insert(highlights, { current_line_idx, 1, 2, "WorkbenchActiveMarker" })
        end

        -- Highlight status tag (columns depend on the tag width)
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

        table.insert(highlights, { current_line_idx, 3, 3 + #tag, hl_group })
        table.insert(highlights, { current_line_idx, 4 + #tag, -1, "WorkbenchPath" })
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
  M.update_statusline()
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

  -- TASK-014 editor interaction on the editable file buffer: a completed
  -- mouse selection auto-copies to the local system clipboard and Esc
  -- returns directly to the same file's Preview from every editor mode.
  if vim.api.nvim_win_is_valid(state.win_right) then
    install_editor_maps(vim.api.nvim_win_get_buf(state.win_right))
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
-- Editor interaction (TASK-014): mouse auto-copy and direct Preview exit
-- =========================================================================

--- The editable regular-file buffer currently shown in the right pane, or
--- nil. The application-owned Preview scratch buffer, nofile/scratch
--- buffers, and unnamed buffers never qualify, so auto-copy and the direct
--- Preview exit stay bound to the editable file buffer only.
---@return integer|nil buf
local function editable_editor_buffer()
  if not state.is_open or not state.win_right
    or not vim.api.nvim_win_is_valid(state.win_right) then
    return nil
  end
  local buf = vim.api.nvim_win_get_buf(state.win_right)
  if buf == state.buf_right then
    return nil
  end
  if vim.bo[buf].buftype ~= "" then
    return nil
  end
  if vim.api.nvim_buf_get_name(buf) == "" then
    return nil
  end
  return buf
end

--- Whether the current buffer is the workbench editable file buffer. Used by
--- the bottom editor statusline hints to keep the new guidance scoped to the
--- surface where the behavior exists.
---@return boolean
function M.editing_file_buffer()
  local buf = editable_editor_buffer()
  return buf ~= nil and buf == vim.api.nvim_get_current_buf()
end

--- Local clipboard provider seam. Checked before every auto-copy so an
--- unavailable local system clipboard produces a bounded failure notice
--- instead of a silent one. A function field so tests can simulate an
--- unavailable provider without touching the real machine clipboard.
function M._clipboard_provider_available()
  local ok, exec = pcall(vim.fn["provider#clipboard#Executable"])
  return ok and type(exec) == "string" and exec ~= ""
end

-- =========================================================================
-- Context-aware statusline rendering (TASK-021)
-- =========================================================================

--- Format dynamic statusline hints bounded to available window width, prioritizing notices.
---@param width integer
---@param hints string[]
---@param notice? { level: string, text: string }
---@return string
local function format_statusline_hints(width, hints, notice)
  local parts = {}
  local avail = width - 2
  if notice then
    local is_err = (notice.level == "error")
    local n_prefix = is_err and "! " or "✓ "
    local n_text = n_prefix .. tostring(notice.text)
    if width < 50 then
      if #n_text > avail - 4 then
        n_text = n_text:sub(1, math.max(4, avail - 5)) .. "…"
      end
      return " [" .. n_text .. "] "
    else
      local bound_n = n_text
      if #bound_n > 28 then bound_n = bound_n:sub(1, 27) .. "…" end
      table.insert(parts, "[" .. bound_n .. "]")
    end
  end

  for _, h in ipairs(hints) do
    local cand = (#parts > 0) and (table.concat(parts, "  ") .. "  " .. h) or h
    if #cand <= avail then
      table.insert(parts, h)
    else
      break
    end
  end

  if #parts == 0 then
    return " "
  end
  return " " .. table.concat(parts, "  ") .. " "
end

--- Update the dynamic statusline across active workbench windows according to context.
function M.update_statusline()
  if not state.is_open then return end

  -- 1. Left window (Files navigation or Diff changes list)
  if state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
    local width = vim.api.nvim_win_get_width(state.win_left)
    if state.view_mode == "files" then
      local p_entry = (state.selected_project_index and state.project_files[state.selected_project_index])
      local can_rename_or_copy = false
      if p_entry and p_entry.full_path then
        local norm_root = state.root_dir and state.root_dir:gsub("/+$", "") or ""
        local norm_entry = p_entry.full_path:gsub("/+$", "")
        local st = uv.fs_lstat(p_entry.full_path)
        local is_reg = st and (st.type == "file" or st.type == "directory")
        if norm_entry ~= norm_root and p_entry.path ~= "" and p_entry.path ~= "." and is_reg then
          can_rename_or_copy = true
        end
      end
      local has_clip = (state.files_clipboard ~= nil)

      local full = (width >= 85)
      local hints = {}
      table.insert(hints, full and "[n] New File" or "[n] New")
      table.insert(hints, full and "[N] New Folder" or "[N] Folder")
      if can_rename_or_copy then
        table.insert(hints, "[F2] Rename")
        table.insert(hints, "[y] Copy")
      end
      if has_clip then
        table.insert(hints, "[p] Paste")
        table.insert(hints, "[M] Move")
      end
      table.insert(hints, "[m] Menu")
      table.insert(hints, "[r] Refresh")

      vim.wo[state.win_left].statusline = format_statusline_hints(width, hints, state.write_notice)
    else
      local hints = { "[a] Stage", "[u] Unstage", "[c] Commit", "[H] History", "[r] Refresh" }
      vim.wo[state.win_left].statusline = format_statusline_hints(width, hints, state.write_notice)
    end
  end

  -- 2. Right window (Preview or Diff working tree)
  if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
    if state.view_mode == "files" then
      if M.editing_file_buffer() then
        vim.wo[state.win_right].statusline = " %f%m%=%{v:lua.get_editor_hints()} "
      else
        vim.wo[state.win_right].statusline = " %f %=[Tab] Explorer  [?] Help  [Esc Esc] Quit "
      end
    else
      if state.win_middle and vim.api.nvim_win_is_valid(state.win_middle) then
        vim.wo[state.win_middle].statusline =
          " %f %=[Old: " .. tostring(state.compare.old.label) .. "]  [Tab] Next  [S-Tab] Files "
      end
      vim.wo[state.win_right].statusline =
        " %f %=[New: " .. tostring(state.compare.new.label) .. "]  [S-Tab] Previous "
    end
  end

  -- 3. History window
  if state.win_history and vim.api.nvim_win_is_valid(state.win_history) then
    vim.wo[state.win_history].statusline = " %f %=[History Graph]  [O]ld [N]ew [D]efault  [r] Refresh "
  end

  -- 4. Context menu window
  if state.context_menu and state.context_menu.win and vim.api.nvim_win_is_valid(state.context_menu.win) then
    local cm_w = vim.api.nvim_win_get_width(state.context_menu.win)
    if cm_w < 40 then
      vim.wo[state.context_menu.win].statusline = " [Enter] Sel  [Esc] X "
    else
      vim.wo[state.context_menu.win].statusline = " [j/k] Move  [Enter] Select  [Esc] Cancel "
    end
  end

  -- 5. File input modal
  if state.file_input and state.file_input.win and vim.api.nvim_win_is_valid(state.file_input.win) then
    if state.file_input.error then
      vim.wo[state.file_input.win].statusline = " [! " .. tostring(state.file_input.error) .. "]  [Enter] Confirm  [Esc] Cancel "
    else
      vim.wo[state.file_input.win].statusline = " [Enter] Confirm  [Esc] Cancel "
    end
  end

  -- 6. Commit input modal
  if state.commit_input and state.commit_input.win and vim.api.nvim_win_is_valid(state.commit_input.win) then
    if state.commit_input.error then
      vim.wo[state.commit_input.win].statusline = " [! " .. tostring(state.commit_input.error) .. "]  [Enter] Commit  [Esc] Cancel "
    else
      vim.wo[state.commit_input.win].statusline = " [Enter] Commit  [Esc] Cancel "
    end
  end

  -- 7. Preview return confirm modal
  if state.preview_return and state.preview_return.win and vim.api.nvim_win_is_valid(state.preview_return.win) then
    vim.wo[state.preview_return.win].statusline = " [Enter/y] Return  [Esc/n] Cancel "
  end
end

--- Get the rendered statusline for a given workbench window role or id
---@param target string|integer "left"|"right"|"middle"|"history"|"context_menu"|"file_input"|"commit_input" or window id
---@return string
function M.get_statusline_text(target)
  local win = nil
  if type(target) == "number" then
    win = target
  elseif target == "left" then
    win = state.win_left
  elseif target == "right" then
    win = state.win_right
  elseif target == "middle" then
    win = state.win_middle
  elseif target == "history" then
    win = state.win_history
  elseif target == "context_menu" then
    win = state.context_menu and state.context_menu.win
  elseif target == "file_input" then
    win = state.file_input and state.file_input.win
  elseif target == "commit_input" then
    win = state.commit_input and state.commit_input.win
  end
  if not win or not vim.api.nvim_win_is_valid(win) then
    return ""
  end
  local sl = vim.wo[win].statusline or ""
  local ok, res = pcall(vim.api.nvim_eval_statusline, sl, { winid = win })
  if ok and res and res.str then
    return res.str
  end
  return sl
end

--- Record and echo one bounded, session-only copy notice.
local function show_copy_notice(notice)
  state.copy_notice = notice
  local hl = (notice.level == "error") and "WarningMsg" or "String"
  vim.api.nvim_echo({ { notice.text, hl } }, false, {})
end

--- Copy the completed mouse selection of the editable file buffer to the
--- configured local system clipboard ("+). The mapping runs once at
--- <LeftRelease>, so dragging never copies per event, a plain click (no
--- selection) does nothing, and keyboard-only selections gain no automatic
--- side effect. The yank mirrors the explicit Ctrl/Cmd copy and then
--- reselects, so the selection stays active and usable afterwards.
---@return boolean copied
function M.copy_selection_to_clipboard()
  local buf = editable_editor_buffer()
  if not buf or vim.api.nvim_get_current_buf() ~= buf then
    return false
  end
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return false
  end
  if not M._clipboard_provider_available() then
    show_copy_notice({ level = "error", text = "Mouse Copy: system clipboard unavailable" })
    return false
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"+ygv', true, false, true), "nx", false)
  show_copy_notice({ level = "ok", text = "Mouse Copy: selection copied to system clipboard" })
  return true
end

--- Restore the read-only Preview of the edited file in the right pane. The
--- edited buffer is only hidden: it stays loaded in memory with its content
--- and modified flag intact for later recovery/reopening. Nothing is saved
--- or discarded here.
local function restore_preview_buffer()
  local buf = editable_editor_buffer()
  if not buf or state.view_mode ~= "files" then
    return false
  end
  local path = vim.api.nvim_buf_get_name(buf)
  -- Keep the Preview on the same file the user was editing.
  local selected = state.project_files[state.selected_project_index]
  local selected_path = selected
    and (selected.full_path or (state.root_dir .. "/" .. selected.path)) or nil
  if selected_path ~= path then
    for idx, entry in ipairs(state.project_files) do
      local entry_path = entry.full_path or (state.root_dir .. "/" .. entry.path)
      if entry_path == path then
        state.selected_project_index = idx
        break
      end
    end
  end
  M.render_right_pane()
  if state.win_right and vim.api.nvim_win_is_valid(state.win_right) then
    set_preview_window_options(state.win_right, "preview")
  end
  return true
end

local PREVIEW_RETURN_TITLE = " Unsaved changes "
local PREVIEW_RETURN_LINE1 = " Enter / y: Return to Preview (without saving) "
local PREVIEW_RETURN_LINE2 = " Esc / n: Keep editing "

--- Whether the bounded unsaved-changes confirmation is currently open.
---@return boolean
function M.preview_return_confirm_open()
  return state.preview_return ~= nil and state.preview_return.win ~= nil
    and vim.api.nvim_win_is_valid(state.preview_return.win)
end

--- Close the unsaved-changes confirmation without saving or discarding
--- anything and restore focus to the editor buffer.
local function close_preview_return_confirm()
  local pr = state.preview_return
  if not pr then
    return
  end
  state.preview_return = nil
  if pr.win and vim.api.nvim_win_is_valid(pr.win) then
    pcall(vim.api.nvim_win_hide, pr.win)
  end
  if pr.buf and vim.api.nvim_buf_is_valid(pr.buf) then
    pcall(vim.api.nvim_buf_delete, pr.buf, { force = true })
  end
  if pr.prev_win and vim.api.nvim_win_is_valid(pr.prev_win) then
    pcall(vim.api.nvim_set_current_win, pr.prev_win)
  end
end

--- Confirm the bounded unsaved-changes confirmation: return to the same
--- file's Preview without saving or discarding the in-memory buffer.
local function confirm_preview_return()
  if not M.preview_return_confirm_open() then
    return false
  end
  close_preview_return_confirm()
  return restore_preview_buffer()
end

--- Open the bounded unsaved-changes confirmation. The float takes focus;
--- Enter/y confirms the return, Esc/n/q cancels and keeps editing with
--- content, cursor context, and modified flag intact. The buffer is
--- transient scratch state and is never persisted.
local function open_preview_return_confirm()
  if M.preview_return_confirm_open() then
    vim.api.nvim_set_current_win(state.preview_return.win)
    return true
  end

  local prev_win = vim.api.nvim_get_current_win()
  local width = math.max(#PREVIEW_RETURN_LINE1, #PREVIEW_RETURN_LINE2) + 2
  local height = 2
  local row = math.max(1, math.floor((vim.o.lines - 8) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  local buf = fresh_buffer("[Workbench - Unsaved Changes]")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { PREVIEW_RETURN_LINE1, PREVIEW_RETURN_LINE2 })
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = PREVIEW_RETURN_TITLE,
    title_pos = "center",
  }
  local ok, win = pcall(vim.api.nvim_open_win, buf, true, config)
  if not ok or not win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return false
  end

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].spell = false
  vim.wo[win].statusline = " [Enter/y] Return  [Esc/n] Cancel "
  state.preview_return = { buf = buf, win = win, prev_win = prev_win }
  -- The confirmation is a key-choice float, not a text input: whatever mode
  -- the editor was in, its Enter/y/Esc/n/q choices must be decisive, so the
  -- float always takes focus in Normal mode and never inherits Insert.
  vim.cmd("stopinsert")

  local opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<CR>", function() return confirm_preview_return() end, opts)
  vim.keymap.set("n", "y", function() return confirm_preview_return() end, opts)
  vim.keymap.set("n", "<Esc>", function()
    close_preview_return_confirm()
    return true
  end, opts)
  vim.keymap.set("n", "n", function()
    close_preview_return_confirm()
    return true
  end, opts)
  vim.keymap.set("n", "q", function()
    close_preview_return_confirm()
    return true
  end, opts)
  return true
end

--- Return from the editable file buffer directly to the same file's
--- read-only Preview. A modified buffer first opens the bounded
--- unsaved-changes confirmation; confirming returns without saving or
--- discarding, cancelling keeps editing. Returns false when there is no
--- editable file buffer to leave, in which case the caller keeps the
--- default key behavior.
---@return boolean handled
function M.return_to_preview()
  local buf = editable_editor_buffer()
  if not buf then
    return false
  end
  if M.preview_return_confirm_open() then
    vim.api.nvim_set_current_win(state.preview_return.win)
    return true
  end
  if vim.bo[buf].modified then
    return open_preview_return_confirm()
  end
  return restore_preview_buffer()
end

--- Install the TASK-014 editor interaction maps on the editable regular
--- file buffer: a completed mouse selection auto-copies once at release,
--- and Esc returns directly to the same file's Preview from Insert, Normal,
--- and Visual modes. All maps stay buffer-local; each handler falls back to
--- the default key behavior when the workbench context is gone (for
--- example after the workbench was closed without quitting), so Esc is
--- never hijacked outside the workbench or in workbench navigation panes.
install_editor_maps = function(buf)
  local opts = { buffer = buf, silent = true, noremap = true }

  -- Auto-copy once at the completed mouse selection.
  vim.keymap.set({ "n", "v" }, "<LeftRelease>", function()
    return M.copy_selection_to_clipboard()
  end, opts)

  -- Direct return to the same file's Preview from every editor mode.
  local function esc_return()
    if M.return_to_preview() then
      return true
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    return false
  end
  vim.keymap.set("n", "<Esc>", esc_return, opts)
  vim.keymap.set("i", "<Esc>", esc_return, opts)
  vim.keymap.set("v", "<Esc>", esc_return, opts)
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

-- =========================================================================
-- Local writes (TASK-013): file-level stage/unstage and staged commits
-- =========================================================================

--- Bound rendered write text to one readable line.
---@param text string
---@param cap integer
---@return string
local function bounded_write_text(text, cap)
  text = tostring(text or "")
  if #text > cap then
    return text:sub(1, cap - 3) .. "..."
  end
  return text
end

local function trim_message(text)
  return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

--- Find the current changes index of a repository-relative path.
local function file_index_for_path(path)
  for idx, file in ipairs(state.files) do
    if file.path == path then
      return idx
    end
  end
  return nil
end

--- Perform one file-level index action ("stage" or "unstage") on the given
--- change entry (default: the selected row). Exactly one entry is targeted;
--- nothing is staged or unstaged in bulk. Both outcomes refresh the Source
--- Control view, keep the user's selection context where the entry still
--- exists, and surface a bounded notice that never claims a failed write
--- succeeded.
---@param kind "stage" | "unstage"
---@param entry? ChangedFile
---@return boolean ok
local function perform_change_action(kind, entry)
  if state.view_mode ~= "diff" or not state.is_git then
    return false
  end
  entry = entry or state.files[state.selected_index]
  if not entry then
    return false
  end

  local target_path = entry.path
  local ok, err
  if kind == "stage" then
    ok, err = git.stage_file(entry, state.repo_root)
  else
    ok, err = git.unstage_file(entry, state.repo_root)
  end

  if ok then
    state.write_notice = {
      level = "ok",
      text = (kind == "stage" and "Staged: " or "Unstaged: ")
        .. bounded_write_text(target_path, 90),
    }
  else
    state.write_notice = {
      level = "error",
      text = (kind == "stage" and "Stage failed: " or "Unstage failed: ")
        .. bounded_write_text(err or "unknown error", 110),
    }
  end

  -- Reconcile the visible status with the actual repository result.
  M.refresh()
  local new_idx = file_index_for_path(target_path)
  if new_idx then
    state.selected_index = new_idx
    M.render_left_pane()
    M.render_middle_pane()
    M.render_right_pane()
  end
  return ok
end

--- Stage the currently selected change entry at file granularity.
---@param entry? ChangedFile
---@return boolean ok
function M.stage_selected_file(entry)
  return perform_change_action("stage", entry)
end

--- Unstage the currently selected change entry at file granularity.
---@param entry? ChangedFile
---@return boolean ok
function M.unstage_selected_file(entry)
  return perform_change_action("unstage", entry)
end

--- Toggle the staged state of one change row (the mouse double-click
--- affordance). The caller resolves the row through the application-owned
--- line hit-testing table, so the targeted entry is deterministic.
---@param index integer
---@return boolean ok
function M.toggle_stage_for_index(index)
  local entry = state.files[index]
  if not entry then
    return false
  end
  if entry.is_staged then
    return perform_change_action("unstage", entry)
  end
  return perform_change_action("stage", entry)
end

--- Whether the transient commit-message input is open.
---@return boolean
function M.commit_input_open()
  return state.commit_input ~= nil and state.commit_input.win ~= nil
    and vim.api.nvim_win_is_valid(state.commit_input.win)
end

local COMMIT_INPUT_TITLE = " Commit message — Enter: commit, Esc: cancel "
local COMMIT_INPUT_ERROR_TITLE = " ! Commit message cannot be empty "

--- Close the commit-message input without any Git mutation and restore
--- focus to the changes pane.
local function close_commit_input()
  local ci = state.commit_input
  if not ci then
    return
  end
  state.commit_input = nil
  if ci.win and vim.api.nvim_win_is_valid(ci.win) then
    pcall(vim.api.nvim_win_hide, ci.win)
  end
  if ci.buf and vim.api.nvim_buf_is_valid(ci.buf) then
    pcall(vim.api.nvim_buf_delete, ci.buf, { force = true })
  end
  if ci.prev_win and vim.api.nvim_win_is_valid(ci.prev_win) then
    pcall(vim.api.nvim_set_current_win, ci.prev_win)
  end
end

--- Re-apply the full float config with one title. Passing the stored
--- config keeps position, size, and border deterministic across updates.
local function set_commit_input_title(title)
  local ci = state.commit_input
  if ci and ci.config and ci.win and vim.api.nvim_win_is_valid(ci.win) then
    local cfg = vim.deepcopy(ci.config)
    cfg.title = title
    pcall(vim.api.nvim_win_set_config, ci.win, cfg)
    if ci.error then
      vim.wo[ci.win].statusline = " [! " .. tostring(ci.error) .. "]  [Enter] Commit  [Esc] Cancel "
    else
      vim.wo[ci.win].statusline = " [Enter] Commit  [Esc] Cancel "
    end
  end
end

--- Confirm the commit-message input. Blank or whitespace-only messages are
--- rejected visibly while the input stays open; a valid message closes the
--- input and creates one local staged commit.
local function confirm_commit_message()
  local ci = state.commit_input
  if not ci or not ci.buf or not vim.api.nvim_buf_is_valid(ci.buf) then
    return false
  end
  local raw_lines = vim.api.nvim_buf_get_lines(ci.buf, 0, -1, false)
  local message = trim_message(table.concat(raw_lines, " "))
  if message == "" then
    ci.error = "Commit message cannot be empty"
    set_commit_input_title(COMMIT_INPUT_ERROR_TITLE)
    return false
  end
  close_commit_input()
  return M.commit_staged(message)
end

--- Open the bounded commit-message input (Git Diff view only). The float
--- takes focus immediately for typing; Enter confirms, Esc cancels with no
--- Git mutation. The buffer is transient scratch state and is never
--- persisted or reused as durable memory.
---@return boolean success
function M.open_commit_input()
  if state.view_mode ~= "diff" or not state.is_git then
    return false
  end
  if M.commit_input_open() then
    vim.api.nvim_set_current_win(state.commit_input.win)
    return true
  end

  local prev_win = vim.api.nvim_get_current_win()
  local width = math.max(30, math.min(64, vim.o.columns - 8))
  local height = 1
  local row = math.max(1, math.floor((vim.o.lines - 8) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  local buf = fresh_buffer("[Workbench - Commit Message]")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })

  local input_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = COMMIT_INPUT_TITLE,
    title_pos = "center",
  }
  local ok, win = pcall(vim.api.nvim_open_win, buf, true, input_config)
  if not ok or not win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return false
  end

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].spell = false
  vim.wo[win].statusline = " [Enter] Commit  [Esc] Cancel "
  state.commit_input = {
    buf = buf, win = win, prev_win = prev_win, error = nil, config = input_config,
  }

  local opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<CR>", function() return confirm_commit_message() end, opts)
  vim.keymap.set("n", "<Esc>", function()
    close_commit_input()
    return true
  end, opts)
  vim.keymap.set("i", "<CR>", function()
    vim.cmd("stopinsert")
    return confirm_commit_message()
  end, opts)
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
    close_commit_input()
    return true
  end, opts)
  -- Clear a visible rejection as soon as the message is edited again.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = function()
      local ci = state.commit_input
      if ci and ci.error then
        ci.error = nil
        set_commit_input_title(COMMIT_INPUT_TITLE)
      end
    end,
  })

  vim.cmd("startinsert")
  return true
end

--- Create one local commit from the currently staged index. Unstaged files
--- are never auto-staged; failures surface a bounded error, refresh the
--- view, and never fabricate a history entry or a success notice.
---@param message string
---@return boolean ok
function M.commit_staged(message)
  if state.view_mode ~= "diff" or not state.is_git then
    return false
  end

  local ok, err, hash = git.commit_staged(message, state.repo_root)
  if not ok then
    state.write_notice = {
      level = "error",
      text = "Commit failed: " .. bounded_write_text(err or "unknown error", 110),
    }
    M.render_left_pane()
    M.render_history_pane()
    return false
  end

  -- Capture the selected change path before the commit: the refresh below
  -- only clamps the numeric index, so rows removed by the commit would
  -- silently move the selection onto a different file.
  local selected_entry = state.files[state.selected_index]
  local selected_path = selected_entry and selected_entry.path or nil

  state.write_notice = {
    level = "ok",
    text = "Committed: " .. (hash and hash:sub(1, 7) or "?")
      .. " " .. bounded_write_text(trim_message(message), 70),
  }
  -- Refresh reconciles status, history, and the selected comparison with
  -- the new HEAD; the comparison stays the user's chosen read-only pair.
  M.refresh()

  -- Restore the captured path when it still exists in the refreshed list;
  -- the numeric index alone may now point at a different change row.
  if selected_path then
    local restored_idx = file_index_for_path(selected_path)
    if restored_idx then
      state.selected_index = restored_idx
      M.render_left_pane()
      M.render_middle_pane()
      M.render_right_pane()
    end
  end
  return true
end

-- =========================================================================
-- Files local mutations (TASK-020): create file/folder, rename, context menu
-- =========================================================================

--- Whether the bounded file input modal is currently open.
---@return boolean
function M.file_input_open()
  return state.file_input ~= nil and state.file_input.win ~= nil
    and vim.api.nvim_win_is_valid(state.file_input.win)
end

--- Whether the Files context menu is currently open.
---@return boolean
function M.context_menu_open()
  return state.context_menu ~= nil and state.context_menu.win ~= nil
    and vim.api.nvim_win_is_valid(state.context_menu.win)
end

--- Close the file input modal without filesystem mutation and restore focus.
local function close_file_input()
  local fi = state.file_input
  if not fi then return end
  state.file_input = nil
  if fi.win and vim.api.nvim_win_is_valid(fi.win) then
    pcall(vim.api.nvim_win_hide, fi.win)
  end
  if fi.buf and vim.api.nvim_buf_is_valid(fi.buf) then
    pcall(vim.api.nvim_buf_delete, fi.buf, { force = true })
  end
  if fi.prev_win and vim.api.nvim_win_is_valid(fi.prev_win) then
    pcall(vim.api.nvim_set_current_win, fi.prev_win)
  end
end

--- Close the Files context menu and restore focus.
local function close_context_menu()
  local cm = state.context_menu
  if not cm then return end
  state.context_menu = nil
  if cm.win and vim.api.nvim_win_is_valid(cm.win) then
    pcall(vim.api.nvim_win_hide, cm.win)
  end
  if cm.buf and vim.api.nvim_buf_is_valid(cm.buf) then
    pcall(vim.api.nvim_buf_delete, cm.buf, { force = true })
  end
  if cm.prev_win and vim.api.nvim_win_is_valid(cm.prev_win) then
    pcall(vim.api.nvim_set_current_win, cm.prev_win)
  end
end

--- Update the title of the active file input modal float.
local function set_file_input_title(title)
  local fi = state.file_input
  if fi and fi.config and fi.win and vim.api.nvim_win_is_valid(fi.win) then
    local cfg = vim.deepcopy(fi.config)
    cfg.title = title
    pcall(vim.api.nvim_win_set_config, fi.win, cfg)
    if fi.error then
      vim.wo[fi.win].statusline = " [! " .. tostring(fi.error) .. "]  [Enter] Confirm  [Esc] Cancel "
    else
      vim.wo[fi.win].statusline = " [Enter] Confirm  [Esc] Cancel "
    end
  end
end

--- Update in-memory buffers when a file or directory is renamed so open buffers follow the new path.
local function migrate_open_buffers_on_rename(old_full, new_full, is_dir)
  old_full = old_full:gsub("/+$", "")
  new_full = new_full:gsub("/+$", "")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local b_name = vim.api.nvim_buf_get_name(buf):gsub("/+$", "")
      if not is_dir and b_name == old_full then
        pcall(vim.api.nvim_buf_set_name, buf, new_full)
        pcall(function()
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("filetype detect")
          end)
        end)
      elseif is_dir and (b_name == old_full or b_name:sub(1, #old_full + 1) == old_full .. "/") then
        local rest = b_name:sub(#old_full + 1)
        local updated_name = new_full .. rest
        pcall(vim.api.nvim_buf_set_name, buf, updated_name)
        pcall(function()
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("filetype detect")
          end)
        end)
      end
    end
  end
end

--- Migrate expansion state when a directory is renamed so unaffected folders stay expanded.
local function migrate_expanded_dirs_on_rename(old_rel, new_rel)
  local updated = {}
  for path, v in pairs(state.expanded_dirs) do
    if path == old_rel then
      updated[new_rel] = v
    elseif path:sub(1, #old_rel + 1) == old_rel .. "/" then
      updated[new_rel .. path:sub(#old_rel + 1)] = v
    else
      updated[path] = v
    end
  end
  state.expanded_dirs = updated
end

--- Confirm the entered name in file_input.
local function confirm_file_input()
  local fi = state.file_input
  if not fi or not fi.buf or not vim.api.nvim_buf_is_valid(fi.buf) then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(fi.buf, 0, 1, false)
  local raw_name = lines[1] or ""
  local ok_name, err_name, clean_name = browser.validate_name(raw_name)
  if not ok_name then
    fi.error = err_name
    set_file_input_title(" ! " .. err_name .. " ")
    return false
  end

  local show_dots = settings.get("show_dotfiles")

  if fi.mode == "new_file" then
    local ok, res = browser.create_file(fi.target_dir, clean_name, state.root_dir)
    if not ok then
      fi.error = res
      set_file_input_title(" ! " .. res .. " ")
      return false
    end
    local target_rel = (fi.target_rel ~= "" and (fi.target_rel .. "/") or "") .. clean_name
    close_file_input()
    state.write_notice = { level = "ok", text = "Created file: " .. target_rel }
    rebuild_project_view(show_dots)
    M.render_left_pane()
    local found_idx = nil
    for idx, e in ipairs(state.project_files) do
      if e.full_path == res then
        found_idx = idx
        break
      end
    end
    if found_idx then
      M.select_file(found_idx)
    else
      M.render_right_pane()
    end
    return true

  elseif fi.mode == "new_folder" then
    local ok, res = browser.create_folder(fi.target_dir, clean_name, state.root_dir)
    if not ok then
      fi.error = res
      set_file_input_title(" ! " .. res .. " ")
      return false
    end
    local target_rel = (fi.target_rel ~= "" and (fi.target_rel .. "/") or "") .. clean_name
    close_file_input()
    state.write_notice = { level = "ok", text = "Created folder: " .. target_rel }
    rebuild_project_view(show_dots)
    M.render_left_pane()
    local found_idx = nil
    for idx, e in ipairs(state.project_files) do
      if e.full_path == res then
        found_idx = idx
        break
      end
    end
    if found_idx then
      M.select_file(found_idx)
    else
      M.render_right_pane()
    end
    return true

  elseif fi.mode == "rename" then
    local entry = fi.entry
    local ok, res, unchanged = browser.rename_entry(entry, clean_name, state.root_dir)
    if not ok then
      fi.error = res
      set_file_input_title(" ! " .. res .. " ")
      return false
    end
    if unchanged then
      close_file_input()
      return true
    end

    local old_full = entry.full_path
    local old_rel = entry.path
    local new_full = res
    local is_dir = entry.is_dir
    local parent_rel = vim.fs.dirname(old_rel)
    local new_rel = (parent_rel ~= "" and parent_rel ~= "." and (parent_rel .. "/") or "") .. clean_name

    migrate_open_buffers_on_rename(old_full, new_full, is_dir)
    if is_dir then
      migrate_expanded_dirs_on_rename(old_rel, new_rel)
    end

    close_file_input()
    state.write_notice = { level = "ok", text = "Renamed: " .. entry.name .. " -> " .. clean_name }
    rebuild_project_view(show_dots)
    M.render_left_pane()
    local found_idx = nil
    for idx, e in ipairs(state.project_files) do
      if e.full_path == new_full then
        found_idx = idx
        break
      end
    end
    if found_idx then
      M.select_file(found_idx)
    else
      M.render_right_pane()
    end
    return true
  end

  return false
end

--- Open the bounded single-line input float for New File, New Folder, or Rename.
local function open_file_input_modal(mode, default_title, initial_text, data)
  if M.file_input_open() then
    vim.api.nvim_set_current_win(state.file_input.win)
    return true
  end

  local prev_win = vim.api.nvim_get_current_win()
  local width = math.max(30, math.min(64, vim.o.columns - 8))
  local height = 1
  local row = math.max(1, math.floor((vim.o.lines - 8) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  local buf = fresh_buffer("[Workbench - File Input]")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { initial_text or "" })

  local input_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = default_title,
    title_pos = "center",
  }
  local ok, win = pcall(vim.api.nvim_open_win, buf, true, input_config)
  if not ok or not win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return false
  end

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].spell = false
  vim.wo[win].statusline = " [Enter] Confirm  [Esc] Cancel "

  state.file_input = {
    buf = buf,
    win = win,
    prev_win = prev_win,
    mode = mode,
    target_dir = data.target_dir,
    target_rel = data.target_rel,
    entry = data.entry,
    default_title = default_title,
    config = input_config,
    error = nil,
  }

  local opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<CR>", function() return confirm_file_input() end, opts)
  vim.keymap.set("n", "<Esc>", function()
    close_file_input()
    return true
  end, opts)
  vim.keymap.set("i", "<CR>", function()
    vim.cmd("stopinsert")
    return confirm_file_input()
  end, opts)
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
    close_file_input()
    return true
  end, opts)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = function()
      local fi = state.file_input
      if fi and fi.error then
        fi.error = nil
        set_file_input_title(fi.default_title)
      end
    end,
  })

  vim.cmd("startinsert!")
  return true
end

--- Open New File input modal for selected entry or project root.
---@param target_entry? ProjectEntry
---@return boolean success
function M.open_new_file_input(...)
  local target_entry = ...
  local num_args = select("#", ...)
  if state.view_mode ~= "files" then return false end
  close_context_menu()
  if num_args == 0 then
    target_entry = (state.selected_project_index and state.project_files[state.selected_project_index])
  end
  local target_dir, target_rel = browser.resolve_create_target(target_entry, state.root_dir)
  local is_sym, sym_err = browser.is_symlink_or_has_symlink_parent(target_dir, state.root_dir)
  if is_sym then
    state.write_notice = { level = "error", text = sym_err }
    M.render_left_pane()
    return false
  end
  local is_out, out_err = browser.is_path_outside_root(target_dir, state.root_dir)
  if is_out then
    state.write_notice = { level = "error", text = out_err }
    M.render_left_pane()
    return false
  end

  local title = " New File — Enter: create, Esc: cancel "
  return open_file_input_modal("new_file", title, "", {
    target_dir = target_dir,
    target_rel = target_rel,
  })
end

--- Open New Folder input modal for selected entry or project root.
---@param target_entry? ProjectEntry
---@return boolean success
function M.open_new_folder_input(...)
  local target_entry = ...
  local num_args = select("#", ...)
  if state.view_mode ~= "files" then return false end
  close_context_menu()
  if num_args == 0 then
    target_entry = (state.selected_project_index and state.project_files[state.selected_project_index])
  end
  local target_dir, target_rel = browser.resolve_create_target(target_entry, state.root_dir)
  local is_sym, sym_err = browser.is_symlink_or_has_symlink_parent(target_dir, state.root_dir)
  if is_sym then
    state.write_notice = { level = "error", text = sym_err }
    M.render_left_pane()
    return false
  end
  local is_out, out_err = browser.is_path_outside_root(target_dir, state.root_dir)
  if is_out then
    state.write_notice = { level = "error", text = out_err }
    M.render_left_pane()
    return false
  end

  local title = " New Folder — Enter: create, Esc: cancel "
  return open_file_input_modal("new_folder", title, "", {
    target_dir = target_dir,
    target_rel = target_rel,
  })
end

--- Open Rename input modal for selected entry.
---@param target_entry? ProjectEntry
---@return boolean success
function M.open_rename_input(target_entry)
  if state.view_mode ~= "files" then return false end
  close_context_menu()
  target_entry = target_entry or (state.selected_project_index and state.project_files[state.selected_project_index])
  if not target_entry or not target_entry.full_path then
    state.write_notice = { level = "error", text = "No file or folder selected to rename" }
    M.render_left_pane()
    return false
  end

  local norm_root = state.root_dir:gsub("/+$", "")
  local norm_entry = target_entry.full_path:gsub("/+$", "")
  if norm_entry == norm_root or target_entry.path == "" or target_entry.path == "." then
    state.write_notice = { level = "error", text = "Cannot rename the project root" }
    M.render_left_pane()
    return false
  end
  local is_out, out_err = browser.is_path_outside_root(target_entry.full_path, state.root_dir)
  if is_out then
    state.write_notice = { level = "error", text = out_err }
    M.render_left_pane()
    return false
  end

  local is_sym, sym_err = browser.is_symlink_or_has_symlink_parent(target_entry.full_path, state.root_dir)
  if is_sym then
    state.write_notice = { level = "error", text = sym_err }
    M.render_left_pane()
    return false
  end

  local st_source = uv.fs_lstat(target_entry.full_path)
  if not st_source then
    state.write_notice = { level = "error", text = "Source does not exist" }
    M.render_left_pane()
    return false
  end
  if st_source.type ~= "file" and st_source.type ~= "directory" then
    state.write_notice = { level = "error", text = "Only regular files and directories can be renamed" }
    M.render_left_pane()
    return false
  end

  local title = " Rename — Enter: confirm, Esc: cancel "
  return open_file_input_modal("rename", title, target_entry.name, {
    entry = target_entry,
  })
end

--- Copy a selected regular file or directory into the session-local Files clipboard.
---@param target_entry? ProjectEntry
---@return boolean success
function M.copy_entry(target_entry)
  if state.view_mode ~= "files" then return false end
  close_context_menu()
  target_entry = target_entry or (state.selected_project_index and state.project_files[state.selected_project_index])
  local ok, err = browser.validate_copy_source(target_entry, state.root_dir)
  if not ok then
    state.write_notice = { level = "error", text = err }
    M.render_left_pane()
    return false
  end

  state.files_clipboard = {
    full_path = target_entry.full_path,
    path = target_entry.path,
    name = target_entry.name,
    is_dir = target_entry.is_dir,
  }
  state.write_notice = { level = "ok", text = "Copied: " .. target_entry.name }
  M.render_left_pane()
  return true
end

--- Expand all directory components in a relative path so its children remain visible in the tree.
---@param expanded_dirs table<string, boolean>
---@param rel_dir string
local function expand_ancestors(expanded_dirs, rel_dir)
  if not rel_dir or rel_dir == "" then return end
  local acc = ""
  for part in rel_dir:gmatch("[^/]+") do
    acc = (acc == "") and part or (acc .. "/" .. part)
    expanded_dirs[acc] = true
  end
end

--- Paste the session-local copied source into the resolved target directory.
---@param target_entry? ProjectEntry
---@return boolean success
function M.paste_entry(target_entry)
  if state.view_mode ~= "files" then return false end
  close_context_menu()
  if not state.files_clipboard then
    state.write_notice = { level = "error", text = "No file or folder in clipboard to paste" }
    M.render_left_pane()
    return false
  end

  local st_clip = uv.fs_lstat(state.files_clipboard.full_path)
  if not st_clip then
    state.write_notice = { level = "error", text = "Source in clipboard no longer exists" }
    M.render_left_pane()
    return false
  end

  target_entry = target_entry or (state.selected_project_index and state.project_files[state.selected_project_index])
  local target_dir, target_rel = browser.resolve_create_target(target_entry, state.root_dir)

  local ok, res = browser.copy_entry(state.files_clipboard.full_path, target_dir, state.root_dir)
  if not ok then
    state.write_notice = { level = "error", text = res }
    M.render_left_pane()
    return false
  end

  expand_ancestors(state.expanded_dirs, target_rel)
  state.write_notice = { level = "ok", text = "Pasted: " .. state.files_clipboard.name }
  local show_dots = settings.get("show_dotfiles")
  rebuild_project_view(show_dots)
  M.render_left_pane()

  local found_idx = nil
  for idx, p in ipairs(state.project_files) do
    if p.full_path == res then
      found_idx = idx
      break
    end
  end
  if found_idx then
    M.select_file(found_idx)
  else
    M.render_right_pane()
  end
  return true
end

--- Move a regular file or directory (from clipboard or explicit source) into the resolved target directory.
---@param target_entry? ProjectEntry
---@param source_entry? ProjectEntry
---@return boolean success
function M.move_entry(target_entry, source_entry)
  if state.view_mode ~= "files" then return false end
  close_context_menu()
  local source = source_entry or state.files_clipboard
  if not source or not source.full_path then
    state.write_notice = { level = "error", text = "No file or folder in clipboard to move" }
    M.render_left_pane()
    return false
  end

  local ok_src, src_err = browser.validate_move_source(source, state.root_dir)
  if not ok_src then
    state.write_notice = { level = "error", text = src_err }
    M.render_left_pane()
    return false
  end

  target_entry = target_entry or (state.selected_project_index and state.project_files[state.selected_project_index])
  local target_dir, target_rel = browser.resolve_create_target(target_entry, state.root_dir)

  local ok, res = browser.move_entry(source.full_path, target_dir, state.root_dir)
  if not ok then
    state.write_notice = { level = "error", text = res }
    M.render_left_pane()
    return false
  end

  migrate_open_buffers_on_rename(source.full_path, res, source.is_dir)
  if source.is_dir then
    local norm_root = state.root_dir:gsub("/+$", "")
    local old_rel = source.path
    local new_rel = res:sub(#norm_root + 2)
    migrate_expanded_dirs_on_rename(old_rel, new_rel)
  end

  if state.files_clipboard and state.files_clipboard.full_path == source.full_path then
    state.files_clipboard = nil
  end

  expand_ancestors(state.expanded_dirs, target_rel)
  state.write_notice = { level = "ok", text = "Moved: " .. source.name }
  local show_dots = settings.get("show_dotfiles")
  rebuild_project_view(show_dots)
  M.render_left_pane()

  local found_idx = nil
  for idx, p in ipairs(state.project_files) do
    if p.full_path == res then
      found_idx = idx
      break
    end
  end
  if found_idx then
    M.select_file(found_idx)
  else
    M.render_right_pane()
  end
  return true
end

--- Get a copy of the current Files clipboard item.
---@return table?
function M.get_files_clipboard()
  return state.files_clipboard and vim.deepcopy(state.files_clipboard) or nil
end

--- Clear the current Files clipboard item.
function M.clear_files_clipboard()
  state.files_clipboard = nil
  M.update_statusline()
end

--- Render the context menu buffer lines and highlights.
local function render_context_menu()
  local cm = state.context_menu
  if not cm or not cm.buf or not vim.api.nvim_buf_is_valid(cm.buf) then
    return
  end
  vim.bo[cm.buf].modifiable = true
  local lines = {}
  for idx, item in ipairs(cm.items) do
    local marker = (idx == cm.selected) and "▶" or " "
    table.insert(lines, string.format(" %s %s", marker, item.label))
  end
  vim.api.nvim_buf_set_lines(cm.buf, 0, -1, false, lines)
  vim.bo[cm.buf].modifiable = false

  pcall(vim.api.nvim_buf_clear_namespace, cm.buf, state.ns_id, 0, -1)
  if cm.selected and cm.selected >= 1 and cm.selected <= #cm.items then
    pcall(vim.api.nvim_buf_add_highlight, cm.buf, state.ns_id, "PmenuSel", cm.selected - 1, 0, -1)
  end
end

--- Confirm the active context menu item.
local function confirm_context_menu()
  local cm = state.context_menu
  if not cm then return false end
  local item = cm.items[cm.selected]
  local target = cm.target
  close_context_menu()
  if not item then return false end
  if item.action == "new_file" then
    return M.open_new_file_input(target)
  elseif item.action == "new_folder" then
    return M.open_new_folder_input(target)
  elseif item.action == "rename" then
    return M.open_rename_input(target)
  elseif item.action == "copy" then
    return M.copy_entry(target)
  elseif item.action == "paste" then
    return M.paste_entry(target)
  elseif item.action == "move" then
    return M.move_entry(target)
  end
  return false
end

--- Open the Files context menu.
---@param target_entry? ProjectEntry
---@param pos? { screenrow?: integer, screencol?: integer }
---@return boolean success
function M.open_context_menu(...)
  local target_entry, pos = ...
  local num_args = select("#", ...)
  if state.view_mode ~= "files" then return false end
  if M.context_menu_open() then
    close_context_menu()
  end

  if num_args == 0 then
    target_entry = (state.selected_project_index and state.project_files[state.selected_project_index])
  end

  local items = {}
  table.insert(items, { label = "New File     (n)", action = "new_file" })
  table.insert(items, { label = "New Folder   (N)", action = "new_folder" })
  if target_entry and target_entry.full_path then
    local norm_root = state.root_dir:gsub("/+$", "")
    local norm_entry = target_entry.full_path:gsub("/+$", "")
    local st = uv.fs_lstat(target_entry.full_path)
    local is_regular_or_dir = st and (st.type == "file" or st.type == "directory")
    if norm_entry ~= norm_root and target_entry.path ~= "" and target_entry.path ~= "." and is_regular_or_dir then
      table.insert(items, { label = "Rename       (F2)", action = "rename" })
      table.insert(items, { label = "Copy         (y)", action = "copy" })
    end
  end
  if state.files_clipboard ~= nil then
    table.insert(items, { label = "Paste        (p)", action = "paste" })
    table.insert(items, { label = "Move         (M)", action = "move" })
  end

  local width = math.min(vim.o.columns - 4, math.max(44, 24))
  local height = #items
  local row, col

  if pos and pos.screenrow and pos.screencol then
    row = math.min(vim.o.lines - height - 2, math.max(1, pos.screenrow))
    col = math.min(vim.o.columns - width - 2, math.max(1, pos.screencol))
  elseif state.win_left and vim.api.nvim_win_is_valid(state.win_left) then
    local win_pos = vim.api.nvim_win_get_position(state.win_left)
    local cursor = vim.api.nvim_win_get_cursor(state.win_left)
    row = math.min(vim.o.lines - height - 2, math.max(1, win_pos[1] + cursor[1]))
    col = math.min(vim.o.columns - width - 2, math.max(1, win_pos[2] + 4))
  else
    row = math.max(1, math.floor((vim.o.lines - height) / 2))
    col = math.max(1, math.floor((vim.o.columns - width) / 2))
  end

  local prev_win = vim.api.nvim_get_current_win()
  local buf = fresh_buffer("[Workbench - Context Menu]")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Files ",
    title_pos = "center",
  }
  local ok, win = pcall(vim.api.nvim_open_win, buf, true, win_config)
  if not ok or not win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return false
  end

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].spell = false
  vim.wo[win].cursorline = false
  vim.wo[win].statusline = " [j/k] Move  [Enter] Select  [Esc] Cancel "

  state.context_menu = {
    buf = buf,
    win = win,
    prev_win = prev_win,
    selected = 1,
    items = items,
    target = target_entry,
  }

  render_context_menu()

  local opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "j", function()
    local cm = state.context_menu
    if cm then
      cm.selected = (cm.selected % #cm.items) + 1
      render_context_menu()
    end
  end, opts)
  vim.keymap.set("n", "<Down>", function()
    local cm = state.context_menu
    if cm then
      cm.selected = (cm.selected % #cm.items) + 1
      render_context_menu()
    end
  end, opts)
  vim.keymap.set("n", "k", function()
    local cm = state.context_menu
    if cm then
      cm.selected = (cm.selected - 2 + #cm.items) % #cm.items + 1
      render_context_menu()
    end
  end, opts)
  vim.keymap.set("n", "<Up>", function()
    local cm = state.context_menu
    if cm then
      cm.selected = (cm.selected - 2 + #cm.items) % #cm.items + 1
      render_context_menu()
    end
  end, opts)
  vim.keymap.set("n", "<CR>", confirm_context_menu, opts)
  vim.keymap.set("n", "<Space>", confirm_context_menu, opts)
  vim.keymap.set("n", "<Esc>", function()
    close_context_menu()
    return true
  end, opts)
  vim.keymap.set("n", "q", function()
    close_context_menu()
    return true
  end, opts)
  vim.keymap.set("n", "n", function()
    local target = state.context_menu and state.context_menu.target or nil
    close_context_menu()
    return M.open_new_file_input(target)
  end, opts)
  vim.keymap.set("n", "N", function()
    local target = state.context_menu and state.context_menu.target or nil
    close_context_menu()
    return M.open_new_folder_input(target)
  end, opts)
  vim.keymap.set("n", "<F2>", function()
    local cm = state.context_menu
    local has_rename = false
    if cm then
      for _, it in ipairs(cm.items) do
        if it.action == "rename" then has_rename = true end
      end
    end
    local target = cm and cm.target or nil
    close_context_menu()
    if has_rename then
      return M.open_rename_input(target)
    end
    return false
  end, opts)
  vim.keymap.set("n", "y", function()
    local cm = state.context_menu
    local has_copy = false
    if cm then
      for _, it in ipairs(cm.items) do
        if it.action == "copy" then has_copy = true end
      end
    end
    local target = cm and cm.target or nil
    close_context_menu()
    if has_copy then
      return M.copy_entry(target)
    end
    return false
  end, opts)
  vim.keymap.set("n", "p", function()
    local cm = state.context_menu
    local has_paste = false
    if cm then
      for _, it in ipairs(cm.items) do
        if it.action == "paste" then has_paste = true end
      end
    end
    local target = cm and cm.target or nil
    close_context_menu()
    if has_paste then
      return M.paste_entry(target)
    end
    return false
  end, opts)
  vim.keymap.set("n", "M", function()
    local cm = state.context_menu
    local has_move = false
    if cm then
      for _, it in ipairs(cm.items) do
        if it.action == "move" then has_move = true end
      end
    end
    local target = cm and cm.target or nil
    close_context_menu()
    if has_move then
      return M.move_entry(target)
    end
    return false
  end, opts)
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local cm = state.context_menu
    if cm and mouse.winid == cm.win then
      local idx = mouse.line
      if cm.items[idx] then
        cm.selected = idx
        confirm_context_menu()
      end
    else
      close_context_menu()
    end
  end, opts)

  return true
end

--- Handle right click mouse event in workbench
on_right_click = function()
  if state.view_mode ~= "files" then return end
  local mouse = vim.fn.getmousepos()
  if mouse.winid == state.win_left then
    local p_idx = state.line_to_project_index[mouse.line]
    if p_idx then
      state.selected_project_index = p_idx
      M.render_left_pane()
      M.render_right_pane()
    end
    M.open_context_menu(p_idx and state.project_files[p_idx] or nil, {
      screenrow = mouse.screenrow,
      screencol = mouse.screencol,
    })
  end
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

  -- Local write actions (TASK-013): stage/unstage act on the selected
  -- change row; commit opens the transient message input.
  vim.keymap.set("n", "a", function() return M.stage_selected_file() end, opts)
  vim.keymap.set("n", "u", function() return M.unstage_selected_file() end, opts)
  vim.keymap.set("n", "c", function() return M.open_commit_input() end, opts)

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
  M.update_statusline()
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
rebuild_project_view = function(show_dots)
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
    "   Mouse Select     Auto-copy selection (editable file buffer)",
    "   Esc              Return to Preview (editable file buffer)",
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
    "   a                Stage the selected change (file level)",
    "   u                Unstage the selected change (file level)",
    "   c                Commit staged changes (message input)",
    "   Double-Click     Toggle stage/unstage on a change row",
    "   History stays read-only; nothing is ever checked out.",
    " ────────────────────────────────────────────────────────",
    " Settings & Display:",
    "   Dot-folders & hidden files are hidden by default.",
    "   Press [s] to open Settings and toggle visibility.",
    "   Settings persist across launches in isolated state.",
    " ────────────────────────────────────────────────────────",
    " Note: Git writes are limited to file-level stage/unstage",
    " and local commits; remote and history actions stay out.",
    " Commit input: Enter commits, Esc cancels with no change.",
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
  -- The commit-message input is transient session state: closing the
  -- workbench discards any open input and the last write notice without a
  -- Git mutation. Layout persistence is unaffected.
  close_commit_input()
  close_preview_return_confirm()
  close_file_input()
  close_context_menu()
  state.write_notice = nil
  state.copy_notice = nil
  state.files_clipboard = nil
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
    if not is_left then
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
    vim.keymap.set("n", "N", function()
      if state.view_mode == "files" then
        return M.open_new_folder_input()
      else
        return M.assign_compare_endpoint("new", "changes")
      end
    end, opts)
    vim.keymap.set("n", "D", M.reset_compare, opts)
    vim.keymap.set("n", "H", function() M.focus_history() end, opts)

    -- Local write actions (TASK-013): file-level stage/unstage of the
    -- selected change row and the transient commit-message input.
    vim.keymap.set("n", "a", function() return M.stage_selected_file() end, opts)
    vim.keymap.set("n", "u", function() return M.unstage_selected_file() end, opts)
    vim.keymap.set("n", "c", function() return M.open_commit_input() end, opts)

    -- Files view mutations (TASK-020 and TASK-021): create, rename, copy, paste, move, context menu
    vim.keymap.set("n", "n", function() return M.open_new_file_input() end, opts)
    vim.keymap.set("n", "<F2>", function() return M.open_rename_input() end, opts)
    vim.keymap.set("n", "y", function()
      if state.view_mode == "files" then
        return M.copy_entry()
      end
    end, opts)
    vim.keymap.set("n", "p", function()
      if state.view_mode == "files" then
        return M.paste_entry()
      end
    end, opts)
    vim.keymap.set("n", "M", function()
      if state.view_mode == "files" then
        return M.move_entry()
      end
    end, opts)
    vim.keymap.set("n", "m", function() return M.open_context_menu() end, opts)
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
    vim.keymap.set("n", "<RightMouse>", on_right_click, opts)
    vim.keymap.set("n", "<2-LeftMouse>", function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid ~= state.win_left then
        return
      end
      if state.view_mode == "files" then
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
      else
        -- Diff view: double-click on a change row toggles file-level
        -- stage/unstage for exactly that entry (TASK-013).
        local f_idx = state.line_to_file_index[mouse.line]
        if f_idx then
          M.toggle_stage_for_index(f_idx)
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

  -- Write notices belong to the session that attempted the write; a fresh
  -- Source Control entry starts with no transient notice.
  state.write_notice = nil

  -- A fresh workbench launch starts with no transient copy notice; any
  -- leftover unsaved-changes confirmation was already discarded by close.
  state.copy_notice = nil

  -- Populate data
  state.file_input = nil
  state.context_menu = nil
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
    write_notice = state.write_notice and {
      level = state.write_notice.level,
      text = state.write_notice.text,
    } or nil,
    copy_notice = state.copy_notice and {
      level = state.copy_notice.level,
      text = state.copy_notice.text,
    } or nil,
    files_clipboard = state.files_clipboard and vim.deepcopy(state.files_clipboard) or nil,
    preview_return = {
      open = M.preview_return_confirm_open(),
      buf = state.preview_return and state.preview_return.buf or nil,
      win = state.preview_return and state.preview_return.win or nil,
    },
    commit_input = {
      open = M.commit_input_open(),
      buf = state.commit_input and state.commit_input.buf or nil,
      win = state.commit_input and state.commit_input.win or nil,
      error = state.commit_input and state.commit_input.error or nil,
    },
    compare = {
      old = vim.deepcopy(state.compare.old),
      new = vim.deepcopy(state.compare.new),
      error = state.compare.error,
    },
    file_input = {
      open = M.file_input_open(),
      buf = state.file_input and state.file_input.buf or nil,
      win = state.file_input and state.file_input.win or nil,
      mode = state.file_input and state.file_input.mode or nil,
      error = state.file_input and state.file_input.error or nil,
    },
    context_menu = {
      open = M.context_menu_open(),
      buf = state.context_menu and state.context_menu.buf or nil,
      win = state.context_menu and state.context_menu.win or nil,
      selected = state.context_menu and state.context_menu.selected or nil,
      items = state.context_menu and vim.deepcopy(state.context_menu.items) or nil,
    },
    history_header_line_count = state.history_header_line_count,
    line_to_history_index = state.line_to_history_index,
    win_history = state.win_history,
    buf_history = state.buf_history,
    active_file = active_file,
    settings = settings.get_all(),
    header_line_count = state.header_line_count,
    line_to_file_index = state.line_to_file_index,
    win_left = state.win_left,
    win_middle = state.win_middle,
    win_right = state.win_right,
    buf_left = state.buf_left,
    buf_middle = state.buf_middle,
    buf_right = state.buf_right,
  }
end

return M
