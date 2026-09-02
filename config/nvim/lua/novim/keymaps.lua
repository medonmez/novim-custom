-- novim/keymaps.lua - Canonical keymap documentation for novim custom derivative
-- Part of novim custom derivative
--
-- Single source of truth shared by the settings panel key-help section and
-- the tests that pin help text to real mappings. Every entry lists the
-- actual Normal-mode buffer-local mappings backing its display label; the
-- tests assert this correspondence in both directions, so the rendered help
-- can never silently drift from the workbench behavior.

local M = {}

--- Workbench shortcuts (left navigation pane and right preview pane).
--- Each entry: { display = help text, keys = mapped lhs strings, desc = action }.
M.workbench = {
  { display = "j / k or ↑ / ↓", keys = { "j", "k", "<Up>", "<Down>" }, desc = "Move selection" },
  { display = "Left Click", keys = { "<LeftMouse>" }, desc = "Select item / switch tabs" },
  { display = "Double-Click", keys = { "<2-LeftMouse>" }, desc = "Expand folder / open file / toggle stage" },
  { display = "Enter / e / o", keys = { "<CR>", "e", "o" }, desc = "Open regular file / select" },
  { display = "Space", keys = { "<Space>" }, desc = "Preview selected item" },
  { display = "1 / b / f", keys = { "1", "b", "f" }, desc = "Project Files view" },
  { display = "2 / d / g", keys = { "2", "d", "g" }, desc = "Git Diff view (vs HEAD)" },
  { display = "H", keys = { "H" }, desc = "Focus history list (Git Diff)" },
  { display = "O / N", keys = { "O", "N" }, desc = "Set compare endpoint (old / new)" },
  { display = "D", keys = { "D" }, desc = "Reset compare (HEAD vs Worktree)" },
  { display = "a", keys = { "a" }, desc = "Stage selected change (file level)" },
  { display = "u", keys = { "u" }, desc = "Unstage selected change (file level)" },
  { display = "c", keys = { "c" }, desc = "Commit staged changes (Enter / Esc input)" },
  { display = "n", keys = { "n" }, desc = "New file (Files view)" },
  { display = "N", keys = { "N" }, desc = "New folder (Files view)" },
  { display = "F2", keys = { "<F2>" }, desc = "Rename file or folder (Files view)" },
  { display = "m or Right Click", keys = { "m", "<RightMouse>" }, desc = "Files context menu" },
  { display = "Tab / Shift-Tab", keys = { "<Tab>", "<S-Tab>" }, desc = "Switch left/right pane" },
  { display = "Drag Boundary", keys = { "<LeftDrag>", "<LeftRelease>" }, desc = "Resize panes (drag divider)" },
  { display = "r or Ctrl-R", keys = { "r", "<C-r>" }, desc = "Refresh files and Git status" },
  { display = "s or S", keys = { "s", "S" }, desc = "Open settings" },
  { display = "?", keys = { "?" }, desc = "Show workbench help" },
  { display = ":", keys = { ":" }, desc = "Command line" },
  { display = "q or Esc Esc", keys = { "q", "<Esc><Esc>" }, desc = "Quit the workbench" },
}

--- Editable file buffer shortcuts (TASK-014). These mappings live on the
--- regular file buffer opened in the right editor pane, not on the
--- workbench navigation/preview scratch buffers. Each entry lists the
--- mapped keys and the editor modes that carry them.
M.editor = {
  { display = "Mouse Selection", keys = { "<LeftRelease>" }, modes = { "n", "v" }, desc = "Auto-copy selection to system clipboard" },
  { display = "Esc", keys = { "<Esc>" }, modes = { "n", "i", "v" }, desc = "Return to Preview (unsaved changes ask first)" },
}

--- Settings panel shortcuts.
M.settings = {
  { display = "j / k or ↑ / ↓", keys = { "j", "k", "<Up>", "<Down>" }, desc = "Move control selection" },
  { display = "Space / Enter", keys = { "<Space>", "<CR>" }, desc = "Activate selected control" },
  { display = "h / ← / [", keys = { "h", "<Left>", "[" }, desc = "Previous theme (Theme selected)" },
  { display = "l / → / ]", keys = { "l", "<Right>", "]" }, desc = "Next theme (Theme selected)" },
  { display = "t", keys = { "t" }, desc = "Toggle dot-folder visibility" },
  { display = "q / Esc", keys = { "q", "<Esc>" }, desc = "Close settings (Esc closes immediately)" },
}

return M
