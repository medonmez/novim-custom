-- tests/test_workbench.lua
-- Comprehensive unit and integration test suite for novim diff workbench and project browser
-- Part of novim custom derivative

local function assert_true(cond, msg)
  if not cond then
    error("Assertion failed: " .. (msg or "expected true, got false"), 2)
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("Assertion failed: %s (expected %s, got %s)", msg or "values not equal", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function create_fixture_repo()
  local fixture_dir = vim.fn.tempname() .. "_fixture_repo"
  vim.fn.mkdir(fixture_dir, "p")

  local function run_cmd(cmd)
    local out = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
      error("Command failed: " .. cmd .. "\nOutput: " .. out)
    end
    return out
  end

  run_cmd("git -C " .. vim.fn.shellescape(fixture_dir) .. " init -q")
  run_cmd("git -C " .. vim.fn.shellescape(fixture_dir) .. " config user.email 'test@example.com'")
  run_cmd("git -C " .. vim.fn.shellescape(fixture_dir) .. " config user.name 'Test Runner'")

  -- Commit 1: base files
  local file1 = fixture_dir .. "/tracked_modified.txt"
  local f1 = io.open(file1, "w")
  f1:write("initial line 1\ninitial line 2\ninitial line 3\n")
  f1:close()

  local file2 = fixture_dir .. "/tracked_deleted.txt"
  local f2 = io.open(file2, "w")
  f2:write("to be deleted\n")
  f2:close()

  local file3 = fixture_dir .. "/tracked_clean.txt"
  local f3 = io.open(file3, "w")
  f3:write("stays clean\n")
  f3:close()

  local file_rename = fixture_dir .. "/base_rename.txt"
  local f_ren = io.open(file_rename, "w")
  f_ren:write("rename base content\n")
  f_ren:close()

  run_cmd("git -C " .. vim.fn.shellescape(fixture_dir) .. " add .")
  run_cmd("git -C " .. vim.fn.shellescape(fixture_dir) .. " commit -q -m 'Initial commit'")

  -- Working tree modifications:
  -- 1. Modify tracked_modified.txt
  local f1_mod = io.open(file1, "w")
  f1_mod:write("initial line 1\nMODIFIED line 2\ninitial line 3\nNEW line 4\n")
  f1_mod:close()

  -- 2. Delete tracked_deleted.txt
  os.remove(file2)

  -- 3. Rename base_rename.txt to a path containing literal arrow ' -> '
  run_cmd("git -C " .. vim.fn.shellescape(fixture_dir) .. " mv base_rename.txt \"renamed -> destination.txt\"")

  -- 4. Create untracked file with regular name
  local file_untracked = fixture_dir .. "/untracked_new.txt"
  local f_untracked = io.open(file_untracked, "w")
  f_untracked:write("untracked line 1\nuntracked line 2\n")
  f_untracked:close()

  -- 5. Create untracked file with literal arrow
  local file_arrow = fixture_dir .. "/arrow -> name.txt"
  local f_arrow = io.open(file_arrow, "w")
  f_arrow:write("arrow content\n")
  f_arrow:close()

  -- 6. Create untracked file with quote
  local file_quote = fixture_dir .. "/quote\"name.txt"
  local f_quote = io.open(file_quote, "w")
  f_quote:write("quote content\n")
  f_quote:close()

  -- 7. Create untracked file with tab
  local file_tab = fixture_dir .. "/tab\tname.txt"
  local f_tab = io.open(file_tab, "w")
  f_tab:write("tab content\n")
  f_tab:close()

  -- 8. Create untracked file with unicode
  local file_uni = fixture_dir .. "/unicode_ğüşıöç.txt"
  local f_uni = io.open(file_uni, "w")
  f_uni:write("unicode content\n")
  f_uni:close()

  -- 9. Create untracked binary file
  local file_bin = fixture_dir .. "/binary_file.bin"
  local f_bin = io.open(file_bin, "wb")
  f_bin:write("\0\1\2\3\4\5\255\254")
  f_bin:close()

  return fixture_dir
end

--- Create a fixture project with regular files, directories, top-level dotfiles, and nested dot-folders
local function create_project_browser_fixture()
  local dir = vim.fn.tempname() .. "_browser_fixture"
  vim.fn.mkdir(dir, "p")

  -- Top-level regular files
  local f1 = io.open(dir .. "/main.lua", "w")
  f1:write("print('hello world')\n")
  f1:close()

  local f2 = io.open(dir .. "/README.md", "w")
  f2:write("# Fixture Project\nDocumentation.\n")
  f2:close()

  -- Regular subdirectories with files
  vim.fn.mkdir(dir .. "/src", "p")
  local f3 = io.open(dir .. "/src/utils.lua", "w")
  f3:write("local M = {}\nreturn M\n")
  f3:close()

  -- Nested regular folder inside src for lazy expansion tests
  vim.fn.mkdir(dir .. "/src/nested", "p")
  local f5 = io.open(dir .. "/src/nested/deep.lua", "w")
  f5:write("return 'deep'\n")
  f5:close()

  vim.fn.mkdir(dir .. "/docs", "p")
  local f4 = io.open(dir .. "/docs/guide.md", "w")
  f4:write("# User Guide\n")
  f4:close()

  -- Top-level dotfiles
  local d1 = io.open(dir .. "/.env", "w")
  d1:write("SECRET=123\n")
  d1:close()

  local d2 = io.open(dir .. "/.gitignore", "w")
  d2:write(".env\n")
  d2:close()

  -- Top-level dot-folders with nested contents
  vim.fn.mkdir(dir .. "/.vscode", "p")
  local d3 = io.open(dir .. "/.vscode/settings.json", "w")
  d3:write("{\"editor.tabSize\": 2}\n")
  d3:close()

  vim.fn.mkdir(dir .. "/.github/workflows", "p")
  local d4 = io.open(dir .. "/.github/workflows/ci.yml", "w")
  d4:write("name: CI\n")
  d4:close()

  -- Nested dot-folder inside a regular folder
  vim.fn.mkdir(dir .. "/src/.secret_module", "p")
  local d5 = io.open(dir .. "/src/.secret_module/token.lua", "w")
  d5:write("return 'secret'\n")
  d5:close()

  -- Nested dotfile inside a regular folder
  local d6 = io.open(dir .. "/docs/.hidden_note", "w")
  d6:write("hidden note\n")
  d6:close()

  return dir
end

local function cleanup_dir(dir)
  vim.fn.delete(dir, "rf")
end

--- Clear persisted pane geometry so a test starts from the built-in layout.
--- TASK-010 restore-on-open must not inherit widths saved by earlier tests
--- or earlier suite runs sharing the isolated development settings file.
local function reset_saved_layout()
  local settings = require("novim.settings")
  settings.reset_cache()
  settings.set_layout({ files = {}, diff = {} })
end

local tests = {}

-- =========================================================================
-- TASK-002 Regression Tests (Git Diff Workbench)
-- =========================================================================

function tests.test_git_module_special_paths()
  local git = require("novim.git")
  assert_true(git.is_git_available(), "git must be available")

  local fixture = create_fixture_repo()
  local is_git, repo_root = git.get_repo_info(fixture)
  assert_true(is_git, "must identify git repo")
  assert_true(git.has_head(fixture), "must detect HEAD commit")

  local files, stats, err = git.get_changed_files(fixture)
  assert_true(err == nil, "no error getting changed files: " .. tostring(err))

  local file_map = {}
  for _, f in ipairs(files) do
    file_map[f.path] = f
  end

  local f_arrow = file_map["arrow -> name.txt"]
  assert_true(f_arrow ~= nil, "arrow -> name.txt must be discovered accurately")
  assert_eq(f_arrow.status, "??", "arrow file status must be ??")
  local arrow_diff, _ = git.get_file_diff(f_arrow, fixture)
  assert_true(#arrow_diff > 0, "arrow diff must be non-empty")
  assert_true(table.concat(arrow_diff, "\n"):find("+arrow content") ~= nil, "arrow diff must render content")

  local f_quote = file_map["quote\"name.txt"]
  assert_true(f_quote ~= nil, "quote\"name.txt must be discovered accurately")
  assert_eq(f_quote.status, "??", "quote file status must be ??")
  local quote_diff, _ = git.get_file_diff(f_quote, fixture)
  assert_true(#quote_diff > 0, "quote diff must be non-empty")
  assert_true(table.concat(quote_diff, "\n"):find("+quote content") ~= nil, "quote diff must render content")

  local f_tab = file_map["tab\tname.txt"]
  assert_true(f_tab ~= nil, "tab\\tname.txt must be discovered accurately")
  assert_eq(f_tab.status, "??", "tab file status must be ??")
  local tab_diff, _ = git.get_file_diff(f_tab, fixture)
  assert_true(#tab_diff > 0, "tab diff must be non-empty")
  assert_true(table.concat(tab_diff, "\n"):find("+tab content") ~= nil, "tab diff must render content")

  local f_uni = file_map["unicode_ğüşıöç.txt"]
  assert_true(f_uni ~= nil, "unicode_ğüşıöç.txt must be discovered accurately")
  assert_eq(f_uni.status, "??", "unicode file status must be ??")
  local uni_diff, _ = git.get_file_diff(f_uni, fixture)
  assert_true(#uni_diff > 0, "unicode diff must be non-empty")
  assert_true(table.concat(uni_diff, "\n"):find("+unicode content") ~= nil, "unicode diff must render content")

  local f_ren = file_map["renamed -> destination.txt"]
  assert_true(f_ren ~= nil, "renamed -> destination.txt must be discovered")
  assert_eq(f_ren.orig_path, "base_rename.txt", "orig_path must be base_rename.txt")
  assert_eq(f_ren.status, "R", "status must be R")

  local f_bin = file_map["binary_file.bin"]
  assert_true(f_bin ~= nil, "binary_file.bin must be discovered")
  local _, is_bin = git.get_file_diff(f_bin, fixture)
  assert_true(is_bin, "binary file must be identified as binary")

  cleanup_dir(fixture)
end

function tests.test_workbench_close_editor_state()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local test_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_name(test_buf, fixture .. "/edited_unsaved.txt")
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "unsaved line 1", "unsaved line 2" })
  vim.bo[test_buf].modified = true

  workbench.open({ view = "diff" })
  local state_open = workbench.get_state()
  assert_true(state_open.is_open, "workbench must be open")
  assert_true(state_open.is_tab, "workbench must be opened in dedicated tabpage")

  workbench.close()
  local state_closed = workbench.get_state()
  assert_true(not state_closed.is_open, "workbench must be closed")

  local cur_buf = vim.api.nvim_get_current_buf()
  assert_eq(cur_buf, test_buf, "current buffer must be the original edited buffer")
  assert_true(vim.bo[cur_buf].modified, "buffer modified flag must remain true")
  local cur_lines = vim.api.nvim_buf_get_lines(cur_buf, 0, -1, false)
  assert_eq(cur_lines[1], "unsaved line 1", "unsaved content must remain intact")

  vim.bo[test_buf].modified = false
  vim.api.nvim_buf_delete(test_buf, { force = true })

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_left_pane_mouse_selection_no_e21()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "diff" })
  local state = workbench.get_state()
  assert_true(state.is_open, "workbench must be open")
  assert_true(state.git_file_count >= 4, "must have loaded changed files")

  local line_count = vim.api.nvim_buf_line_count(state.buf_left)
  for line_num = state.header_line_count + 1, math.min(line_count, state.header_line_count + 3) do
    local ok, err = pcall(vim.api.nvim_win_set_cursor, state.win_left, { line_num, 2 })
    assert_true(ok, "cursor movement on left pane must succeed without error: " .. tostring(err))
    vim.cmd("doautocmd CursorMoved")
  end

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_mouse_divider_drag_and_status_invariance()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local before_status = vim.system({ "git", "-C", fixture, "status", "--porcelain=v1", "-z", "-uall" }, { text = true }):wait().stdout
  local before_diff = vim.system({ "git", "-C", fixture, "diff", "HEAD" }, { text = true }):wait().stdout

  workbench.open({ view = "diff" })

  local state = workbench.get_state()
  assert_true(state.is_open, "workbench must be open")

  local initial_left_width = vim.api.nvim_win_get_width(state.win_left)
  assert_true(initial_left_width >= 15, "initial width must respect minimum width")

  local target_widen = initial_left_width + 10
  vim.api.nvim_win_set_width(state.win_left, target_widen)
  local widened_left_width = vim.api.nvim_win_get_width(state.win_left)
  assert_eq(widened_left_width, target_widen, "left pane width must increase on widen")

  local target_narrow = initial_left_width - 5
  vim.api.nvim_win_set_width(state.win_left, target_narrow)
  local narrowed_left_width = vim.api.nvim_win_get_width(state.win_left)
  assert_eq(narrowed_left_width, target_narrow, "left pane width must decrease on narrow")

  assert_true(vim.o.winminwidth >= 15, "winminwidth must be >= 15")
  assert_true(narrowed_left_width >= 15, "left pane width must be >= winminwidth")

  workbench.close()

  local after_status = vim.system({ "git", "-C", fixture, "status", "--porcelain=v1", "-z", "-uall" }, { text = true }):wait().stdout
  local after_diff = vim.system({ "git", "-C", fixture, "diff", "HEAD" }, { text = true }):wait().stdout

  assert_eq(after_status, before_status, "Git status --porcelain -z must be byte-for-byte identical before and after workbench interactions")
  assert_eq(after_diff, before_diff, "Git diff HEAD must be byte-for-byte identical before and after workbench interactions")

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_non_git_directory()
  local workbench = require("novim.workbench")
  workbench.close()

  local temp_dir = vim.fn.tempname() .. "_nongit"
  vim.fn.mkdir(temp_dir, "p")
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(temp_dir))

  workbench.open({ view = "diff" })

  local state = workbench.get_state()
  assert_true(not state.is_git, "must detect non-git directory")
  assert_eq(state.git_file_count, 0, "git file count must be 0")

  local left_lines = vim.api.nvim_buf_get_lines(state.buf_left, 0, -1, false)
  local left_text = table.concat(left_lines, "\n")
  assert_true(left_text:find("Not a Git Repository") ~= nil, "left pane must state not a git repository")

  local right_lines = vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false)
  local right_text = table.concat(right_lines, "\n")
  assert_true(right_text:find("Not a Git repository") ~= nil, "right pane must state not a git repository")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(temp_dir)
end

function tests.test_clean_repository()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture_dir = vim.fn.tempname() .. "_clean_repo"
  vim.fn.mkdir(fixture_dir, "p")
  vim.fn.system("git -C " .. vim.fn.shellescape(fixture_dir) .. " init -q")
  vim.fn.system("git -C " .. vim.fn.shellescape(fixture_dir) .. " config user.email 'test@example.com'")
  vim.fn.system("git -C " .. vim.fn.shellescape(fixture_dir) .. " config user.name 'Test Runner'")

  local f = io.open(fixture_dir .. "/clean.txt", "w")
  f:write("clean content\n")
  f:close()

  vim.fn.system("git -C " .. vim.fn.shellescape(fixture_dir) .. " add .")
  vim.fn.system("git -C " .. vim.fn.shellescape(fixture_dir) .. " commit -q -m 'Clean commit'")

  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture_dir))

  workbench.open({ view = "diff" })

  local state = workbench.get_state()
  assert_true(state.is_git, "must be git repo")
  assert_eq(state.git_file_count, 0, "git file count must be 0 for clean repo")

  local left_lines = vim.api.nvim_buf_get_lines(state.buf_left, 0, -1, false)
  local left_text = table.concat(left_lines, "\n")
  assert_true(left_text:find("Working tree clean") ~= nil, "left pane must show working tree clean")

  local right_lines = vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false)
  local right_text = table.concat(right_lines, "\n")
  assert_true(right_text:find("Working tree is clean") ~= nil, "right pane must show clean message")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture_dir)
end

-- =========================================================================
-- TASK-003 New Feature Tests (Project Browser & Settings Persistence)
-- =========================================================================

function tests.test_project_browser_default_hidden_dotfiles()
  local settings = require("novim.settings")
  local browser = require("novim.browser")
  local workbench = require("novim.workbench")
  workbench.close()

  -- Ensure settings are at default (show_dotfiles = false)
  settings.set("show_dotfiles", false)

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Test browser module directly: a root scan loads only immediate entries
  local root_entries = browser.get_immediate_entries(fixture, "", 0, false)
  local paths = {}
  for _, entry in ipairs(root_entries) do
    paths[entry.path] = entry
  end

  -- Regular top-level entries MUST be visible
  assert_true(paths["main.lua"] ~= nil, "main.lua must be visible")
  assert_true(paths["README.md"] ~= nil, "README.md must be visible")
  assert_true(paths["src"] ~= nil, "src/ must be visible")
  assert_true(paths["docs"] ~= nil, "docs/ must be visible")

  -- Nested descendants MUST NOT be loaded before an expansion action
  assert_true(paths["src/utils.lua"] == nil, "src/utils.lua must not load before src expands")
  assert_true(paths["docs/guide.md"] == nil, "docs/guide.md must not load before docs expands")

  -- Dot-prefixed items at root MUST be hidden by default
  assert_true(paths[".env"] == nil, ".env must be hidden by default")
  assert_true(paths[".gitignore"] == nil, ".gitignore must be hidden by default")
  assert_true(paths[".vscode"] == nil, ".vscode must be hidden by default")
  assert_true(paths[".github"] == nil, ".github must be hidden by default")

  -- Expanding src must reveal only its immediate visible children
  local src_children = browser.get_immediate_entries(fixture .. "/src", "src", 1, false)
  local src_paths = {}
  for _, entry in ipairs(src_children) do
    src_paths[entry.path] = entry
  end
  assert_true(src_paths["src/utils.lua"] ~= nil, "src/utils.lua must be visible after src expansion")
  assert_true(src_paths["src/nested"] ~= nil, "src/nested must be visible after src expansion")
  assert_true(src_paths["src/.secret_module"] == nil, "src/.secret_module must be hidden by default")
  assert_true(src_paths["src/.secret_module/token.lua"] == nil, "nested dot-folder contents must be hidden")
  assert_true(src_paths["src/nested/deep.lua"] == nil, "src/nested/deep.lua must not load before nested expands")

  local docs_children = browser.get_immediate_entries(fixture .. "/docs", "docs", 1, false)
  for _, entry in ipairs(docs_children) do
    assert_true(entry.path ~= "docs/.hidden_note", "docs/.hidden_note must be hidden by default")
  end

  -- Test Workbench Project Browser integration
  workbench.open({ view = "files" })
  local state = workbench.get_state()
  assert_true(state.is_open, "workbench must be open")
  assert_eq(state.view_mode, "files", "view mode must be files")

  for _, entry in ipairs(state.project_files) do
    assert_eq(entry.depth, 0, "initial workbench list must contain only root entries: " .. entry.path)
  end

  local left_lines = vim.api.nvim_buf_get_lines(state.buf_left, 0, -1, false)
  local left_text = table.concat(left_lines, "\n")
  assert_true(left_text:find("PROJECT BROWSER") ~= nil, "left header must show PROJECT BROWSER")
  assert_true(left_text:find("main.lua") ~= nil, "main.lua must appear in rendered pane")
  assert_true(left_text:find("src/") ~= nil, "src/ must appear in rendered pane")
  assert_true(left_text:find("utils%.lua") == nil, "descendants must NOT render before expansion")
  assert_true(left_text:find(".env") == nil, ".env must NOT appear in rendered pane")
  assert_true(left_text:find(".vscode") == nil, ".vscode must NOT appear in rendered pane")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_toggle_reveals_and_hides_dotfiles()
  local settings = require("novim.settings")
  local browser = require("novim.browser")
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Start with dotfiles hidden
  settings.set("show_dotfiles", false)
  workbench.open({ view = "files" })

  -- 1. Enable show_dotfiles via toggle
  local ok1, err1, new_val = settings.toggle_dotfiles()
  assert_true(ok1 == true, "toggle must succeed: " .. tostring(err1))
  assert_true(new_val == true, "toggle must return true")
  assert_true(settings.get("show_dotfiles") == true, "settings.get must return true")
  workbench.refresh()
  local state_revealed = workbench.get_state()

  -- Root scan with dotfiles revealed
  local root_revealed = browser.get_immediate_entries(fixture, "", 0, true)
  local paths_revealed = {}
  local revealed_dot_count = 0
  for _, entry in ipairs(root_revealed) do
    paths_revealed[entry.path] = entry
    if entry.is_dot then
      revealed_dot_count = revealed_dot_count + 1
    end
  end
  assert_true(revealed_dot_count > 0, "revealed dot entries must be visible at root")

  -- Verify root dotfiles and dot-folders are now visible
  assert_true(paths_revealed[".env"] ~= nil, ".env must be revealed")
  assert_true(paths_revealed[".gitignore"] ~= nil, ".gitignore must be revealed")
  assert_true(paths_revealed[".vscode"] ~= nil, ".vscode must be revealed")
  assert_true(paths_revealed[".github"] ~= nil, ".github must be revealed")

  -- Nested dot entries require scanning their parent directory (lazy boundary)
  local vscode_children = browser.get_immediate_entries(fixture .. "/.vscode", ".vscode", 1, true)
  local vscode_paths = {}
  for _, entry in ipairs(vscode_children) do
    vscode_paths[entry.path] = entry
  end
  assert_true(vscode_paths[".vscode/settings.json"] ~= nil, ".vscode/settings.json must be revealed")

  local src_children = browser.get_immediate_entries(fixture .. "/src", "src", 1, true)
  local src_paths = {}
  for _, entry in ipairs(src_children) do
    src_paths[entry.path] = entry
  end
  assert_true(src_paths["src/.secret_module"] ~= nil, "src/.secret_module must be revealed")

  local secret_children = browser.get_immediate_entries(fixture .. "/src/.secret_module", "src/.secret_module", 2, true)
  local secret_paths = {}
  for _, entry in ipairs(secret_children) do
    secret_paths[entry.path] = entry
  end
  assert_true(secret_paths["src/.secret_module/token.lua"] ~= nil, "nested dot-folder file must be revealed")

  local docs_children = browser.get_immediate_entries(fixture .. "/docs", "docs", 1, true)
  local docs_paths = {}
  for _, entry in ipairs(docs_children) do
    docs_paths[entry.path] = entry
  end
  assert_true(docs_paths["docs/.hidden_note"] ~= nil, "docs/.hidden_note must be revealed")

  -- Normal entries remain visible in the workbench list
  local seen_normal = {}
  for _, entry in ipairs(state_revealed.project_files) do
    seen_normal[entry.path] = true
  end
  assert_true(seen_normal["main.lua"], "main.lua must remain visible")
  assert_true(seen_normal["src"], "src must remain visible")

  -- 2. Disable show_dotfiles via toggle
  local ok2, err2, val_hidden = settings.toggle_dotfiles()
  assert_true(ok2 == true, "toggle must succeed: " .. tostring(err2))
  assert_true(val_hidden == false, "toggle must return false")
  assert_true(settings.get("show_dotfiles") == false, "settings.get must return false")
  workbench.refresh()
  local root_hidden = browser.get_immediate_entries(fixture, "", 0, false)
  local paths_hidden = {}
  for _, entry in ipairs(root_hidden) do
    paths_hidden[entry.path] = entry
  end

  assert_true(paths_hidden[".env"] == nil, ".env must be hidden again")
  assert_true(paths_hidden[".vscode"] == nil, ".vscode must be hidden again")
  assert_true(paths_hidden["main.lua"] ~= nil, "normal files must still be visible")

  local src_hidden = browser.get_immediate_entries(fixture .. "/src", "src", 1, false)
  local src_hidden_paths = {}
  for _, entry in ipairs(src_hidden) do
    src_hidden_paths[entry.path] = entry
  end
  assert_true(src_hidden_paths["src/.secret_module"] == nil, "nested dot-folder must be hidden again")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- TASK-007 New Feature Tests (Lazy Root-Only Project Browser)
-- =========================================================================

local function find_project_entry(state, path)
  for _, entry in ipairs(state.project_files) do
    if entry.path == path then
      return entry
    end
  end
  return nil
end

function tests.test_lazy_root_only_initial_state()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()
  settings.set("show_dotfiles", false)

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  assert_true(st.is_open, "workbench must be open")

  -- Only immediate root entries are visible: docs, src, main.lua, README.md
  assert_eq(#st.project_files, 4, "initial list must contain exactly the 4 visible root entries")
  local expected_order = { "docs", "src", "main.lua", "README.md" }
  for i, expected_path in ipairs(expected_order) do
    assert_eq(st.project_files[i].path, expected_path, "entry " .. i .. " must be " .. expected_path)
    assert_eq(st.project_files[i].depth, 0, "initial entries must sit at depth 0")
  end

  -- No descendant may be loaded or rendered before an expansion action
  assert_eq(next(st.expanded_dirs), nil, "a new launch must start with no expanded folders")
  local left_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_left, 0, -1, false), "\n")
  assert_true(left_text:find("utils%.lua") == nil, "src/utils.lua must not render before expansion")
  assert_true(left_text:find("guide%.md") == nil, "docs/guide.md must not render before expansion")
  assert_true(left_text:find("deep%.lua") == nil, "src/nested/deep.lua must not render before expansion")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_folder_double_click_expand_and_collapse()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()
  settings.set("show_dotfiles", false)

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  local src_entry = find_project_entry(st, "src")
  assert_true(src_entry ~= nil, "src must be visible at root")

  -- Expand: scan only immediate visible children of src
  workbench.toggle_dir_expansion(src_entry)
  st = workbench.get_state()
  assert_true(st.expanded_dirs["src"] == true, "src must be marked expanded")
  assert_eq(#st.project_files, 6, "expanding src must reveal exactly its 2 visible children")
  assert_eq(st.project_files[3].path, "src/nested", "src/nested must render right after src")
  assert_eq(st.project_files[3].depth, 1, "src/nested must render at depth 1")
  assert_eq(st.project_files[3].is_dir, true, "src/nested must be a directory entry")
  assert_eq(st.project_files[4].path, "src/utils.lua", "src/utils.lua must render after src/nested")
  assert_eq(st.project_files[4].depth, 1, "src/utils.lua must render at depth 1")
  assert_eq(st.project_files[4].is_dir, false, "src/utils.lua must be a file entry")
  assert_eq(st.project_files[5].path, "main.lua", "root ordering must be preserved after expansion")

  local left_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_left, 0, -1, false), "\n")
  assert_true(left_text:find("utils%.lua") ~= nil, "src/utils.lua must render after expansion")

  -- Collapse: remove all descendants without touching disk
  workbench.toggle_dir_expansion(find_project_entry(st, "src"))
  st = workbench.get_state()
  assert_eq(#st.project_files, 4, "collapse must restore the root-only list")
  assert_eq(next(st.expanded_dirs), nil, "collapse must clear expansion state")
  for _, entry in ipairs(st.project_files) do
    assert_eq(entry.depth, 0, "collapsed list must contain only root entries")
  end
  assert_true(vim.fn.filereadable(fixture .. "/src/utils.lua") == 1, "collapse must not delete files on disk")
  assert_true(vim.fn.isdirectory(fixture .. "/src/nested") == 1, "collapse must not delete folders on disk")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_nested_folder_expands_independently()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()
  settings.set("show_dotfiles", false)

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })

  -- Expand src; its nested folder stays collapsed
  workbench.toggle_dir_expansion(find_project_entry(workbench.get_state(), "src"))
  local st = workbench.get_state()
  assert_true(find_project_entry(st, "src/nested") ~= nil, "src/nested must be visible after src expands")
  assert_true(find_project_entry(st, "src/nested/deep.lua") == nil, "src/nested/deep.lua must stay hidden while nested is collapsed")

  -- Expand the nested folder independently
  workbench.toggle_dir_expansion(find_project_entry(st, "src/nested"))
  st = workbench.get_state()
  assert_true(st.expanded_dirs["src/nested"] == true, "src/nested must be marked expanded")
  local deep = find_project_entry(st, "src/nested/deep.lua")
  assert_true(deep ~= nil, "src/nested/deep.lua must appear after nested expands")
  assert_eq(deep.depth, 2, "src/nested/deep.lua must render at depth 2")
  assert_true(st.expanded_dirs["src"] == true, "parent expansion must be preserved")

  -- Collapsing the parent removes all descendants including nested's children
  workbench.toggle_dir_expansion(find_project_entry(st, "src"))
  st = workbench.get_state()
  assert_eq(next(st.expanded_dirs), nil, "collapsing src must clear nested expansion too")
  assert_true(find_project_entry(st, "src/nested") == nil, "descendants must disappear after parent collapse")
  assert_true(find_project_entry(st, "src/nested/deep.lua") == nil, "nested grandchildren must disappear after parent collapse")
  assert_true(vim.fn.filereadable(fixture .. "/src/nested/deep.lua") == 1, "collapse must not delete files on disk")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_refresh_preserves_expansion_new_launch_resets()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()
  settings.set("show_dotfiles", false)

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  workbench.toggle_dir_expansion(find_project_entry(workbench.get_state(), "docs"))

  -- Refresh within the same session preserves valid expansion state
  workbench.refresh()
  local st = workbench.get_state()
  assert_true(st.expanded_dirs["docs"] == true, "refresh must preserve in-session expansion")
  assert_true(find_project_entry(st, "docs/guide.md") ~= nil, "docs/guide.md must remain visible after refresh")
  assert_eq(#st.project_files, 5, "refresh must keep exactly the expanded docs child visible")

  -- New workbench launch starts collapsed at the root
  workbench.close()
  workbench.open({ view = "files" })
  st = workbench.get_state()
  assert_eq(next(st.expanded_dirs), nil, "a new launch must reset expansion state")
  assert_eq(#st.project_files, 4, "a new launch must list only root entries")
  assert_true(find_project_entry(st, "docs/guide.md") == nil, "a new launch must not show expanded descendants")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_large_fixture_startup_stays_lazy()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()
  settings.set("show_dotfiles", false)

  -- Deterministic wide/deep fixture: 12 branches, 8 files each level, 4 nested levels
  local fixture = vim.fn.tempname() .. "_lazy_large_fixture"
  vim.fn.mkdir(fixture, "p")
  for d = 1, 12 do
    local dir_path = fixture .. "/branch_" .. d
    vim.fn.mkdir(dir_path, "p")
    for f = 1, 8 do
      local fh = io.open(dir_path .. "/leaf_" .. f .. ".txt", "w")
      fh:write("filler " .. d .. " " .. f .. "\n")
      fh:close()
    end
    local deep_path = dir_path
    for level = 1, 4 do
      deep_path = deep_path .. "/deep_" .. level
      vim.fn.mkdir(deep_path, "p")
      for f = 1, 8 do
        local fh = io.open(deep_path .. "/deep_leaf_" .. f .. ".txt", "w")
        fh:write("deep filler " .. d .. " " .. level .. " " .. f .. "\n")
        fh:close()
      end
    end
  end

  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Startup observes the lazy boundary structurally, not via a wall-clock budget
  workbench.open({ view = "files" })
  local st = workbench.get_state()
  assert_eq(#st.project_files, 12, "startup must list only the 12 immediate root directories")
  for _, entry in ipairs(st.project_files) do
    assert_eq(entry.depth, 0, "no descendant may load at startup: " .. entry.path)
    assert_eq(entry.is_dir, true, "root fixture entries must be directories")
  end
  assert_eq(next(st.expanded_dirs), nil, "startup must not expand anything")

  -- Expanding one folder scans exactly its immediate children
  workbench.toggle_dir_expansion(find_project_entry(st, "branch_1"))
  st = workbench.get_state()
  assert_eq(#st.project_files, 21, "expanding branch_1 must reveal exactly its 9 immediate children")
  local expanded_dir_count = 0
  for _ in pairs(st.expanded_dirs) do
    expanded_dir_count = expanded_dir_count + 1
  end
  assert_eq(expanded_dir_count, 1, "only branch_1 may be expanded")
  assert_true(find_project_entry(st, "branch_1/deep_1/deep_leaf_1.txt") == nil, "deeper descendants must stay unloaded")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_symlink_cycle_expansion_is_refused()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  local uv = vim.uv or vim.loop
  workbench.close()
  settings.set("show_dotfiles", false)

  local fixture = create_project_browser_fixture()
  -- Symlink loop: fixture/loop_link -> fixture
  assert_true(uv.fs_symlink(fixture, fixture .. "/loop_link"), "fixture must create a root symlink loop")

  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  local loop_entry = find_project_entry(st, "loop_link")
  assert_true(loop_entry ~= nil, "loop_link must be visible at root")
  assert_eq(loop_entry.is_dir, true, "loop_link must resolve as a directory")

  -- Expanding the loop must be refused without hanging or listing descendants
  workbench.toggle_dir_expansion(loop_entry)
  st = workbench.get_state()
  assert_eq(#st.project_files, 5, "refused expansion must not add entries")
  assert_eq(st.expanded_dirs["loop_link"], nil, "loop_link must not be marked expanded")
  assert_true(find_project_entry(st, "loop_link/main.lua") == nil, "cycle children must not be listed")

  -- A normal directory still expands after the refused cycle attempt
  workbench.toggle_dir_expansion(find_project_entry(st, "src"))
  st = workbench.get_state()
  assert_true(st.expanded_dirs["src"] == true, "normal expansion must still work after a refused cycle")
  assert_true(find_project_entry(st, "src/utils.lua") ~= nil, "src/utils.lua must appear after normal expansion")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_persistence_across_launches()
  local settings = require("novim.settings")

  -- Save setting show_dotfiles = true
  settings.set("show_dotfiles", true)

  -- Verify settings file exists on disk in the isolated state path
  local path = settings.get_settings_file_path()
  assert_true(vim.fn.filereadable(path) == 1, "settings file must exist on disk at " .. path)

  -- Verify file contents is valid JSON
  local content = table.concat(vim.fn.readfile(path), "\n")
  local parsed = vim.json.decode(content)
  assert_true(type(parsed) == "table", "parsed settings must be a table")
  assert_eq(parsed.show_dotfiles, true, "saved show_dotfiles must be true")

  -- Simulate fresh process launch: reset in-memory cache and load from disk
  settings.reset_cache()
  local loaded = settings.load(true)
  assert_eq(loaded.show_dotfiles, true, "fresh load must restore show_dotfiles = true from persistent file")

  -- Set back to false and verify persistence
  settings.set("show_dotfiles", false)
  settings.reset_cache()
  local loaded_false = settings.load(true)
  assert_eq(loaded_false.show_dotfiles, false, "fresh load must restore show_dotfiles = false from persistent file")
end

function tests.test_settings_missing_or_malformed_fallback()
  local settings = require("novim.settings")
  local path = settings.get_settings_file_path()

  -- Case 1: Missing file
  os.remove(path)
  settings.reset_cache()
  local s1 = settings.load(true)
  assert_eq(s1.show_dotfiles, false, "missing settings file must fall back safely to show_dotfiles = false")

  -- Case 2: Malformed JSON file
  local dir = vim.fs.dirname(path) or vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  local f = io.open(path, "w")
  f:write("THIS IS NOT VALID JSON {{{{ ::: \n")
  f:close()

  settings.reset_cache()
  local s2 = settings.load(true)
  assert_eq(s2.show_dotfiles, false, "malformed JSON settings file must fall back safely to default false without error")

  -- Case 3: Invalid type inside JSON
  local f3 = io.open(path, "w")
  f3:write("{\"show_dotfiles\": \"string_value_not_a_boolean\"}\n")
  f3:close()

  settings.reset_cache()
  local s3 = settings.load(true)
  assert_eq(s3.show_dotfiles, false, "invalid type in settings file must fall back safely to default false")
  -- Restore clean settings file
  settings.set("show_dotfiles", false)
end

function tests.test_settings_write_failure_handling()
  local settings = require("novim.settings")
  local settings_ui = require("novim.settings_ui")
  settings.set("show_dotfiles", false)

  local path = settings.get_settings_file_path()
  os.remove(path)
  -- Create a directory at settings file path to force a write error
  vim.fn.mkdir(path, "p")

  settings.reset_cache()
  local ok, err, eff = settings.toggle_dotfiles()
  assert_true(ok == false, "toggle_dotfiles must return ok = false when write fails")
  assert_true(err ~= nil, "error message must be returned")
  assert_true(eff == false, "effective value must remain false")
  assert_true(settings.get("show_dotfiles") == false, "settings.get must remain false")

  -- Test Settings UI error rendering
  settings_ui.open()
  assert_true(settings_ui.is_open(), "settings UI must open")

  settings_ui.toggle_dotfiles()
  local state = settings.load(true)
  assert_true(state.show_dotfiles == false, "settings must not change on write failure")

  -- Clean up the blocker directory
  vim.fn.delete(path, "rf")
  settings_ui.close()
  settings.reset_cache()
  settings.set("show_dotfiles", false)
end

function tests.test_view_switching_and_header_tabs()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Open in files mode
  workbench.open({ view = "files" })
  local state1 = workbench.get_state()
  assert_eq(state1.view_mode, "files", "initial view mode must be files")

  -- Switch to diff mode
  workbench.set_view("diff")
  local state2 = workbench.get_state()
  assert_eq(state2.view_mode, "diff", "switched view mode must be diff")
  local left_lines_diff = vim.api.nvim_buf_get_lines(state2.buf_left, 0, -1, false)
  local text_diff = table.concat(left_lines_diff, "\n")
  assert_true(text_diff:find("DIFF WORKBENCH") ~= nil, "left pane must render DIFF WORKBENCH")

  -- Switch back to files mode
  workbench.set_view("files")
  local state3 = workbench.get_state()
  assert_eq(state3.view_mode, "files", "switched view mode must be files")
  local left_lines_files = vim.api.nvim_buf_get_lines(state3.buf_left, 0, -1, false)
  local text_files = table.concat(left_lines_files, "\n")
  assert_true(text_files:find("PROJECT BROWSER") ~= nil, "left pane must render PROJECT BROWSER")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_project_browser_preview()
  local browser = require("novim.browser")
  local fixture = create_project_browser_fixture()

  -- 1. Regular text file preview
  local file_entry = {
    path = "main.lua",
    name = "main.lua",
    is_dir = false,
    depth = 0,
    is_dot = false,
    full_path = fixture .. "/main.lua",
  }
  local file_preview, is_text = browser.get_preview(file_entry, fixture)
  assert_true(is_text, "text file must be recognized as text preview")
  local preview_text = table.concat(file_preview, "\n")
  assert_true(preview_text:find("File: main.lua") ~= nil, "preview must contain header with filename")
  assert_true(preview_text:find("print%('hello world'%)") ~= nil, "preview must contain file content")

  -- 2. Directory inspection preview (filtering check)
  local dir_entry = {
    path = "src",
    name = "src",
    is_dir = true,
    depth = 0,
    is_dot = false,
    full_path = fixture .. "/src",
  }

  -- 2a. With dotfiles hidden: .secret_module must NOT appear in directory preview
  local dir_preview_hidden, _ = browser.get_preview(dir_entry, fixture, false)
  local dir_text_hidden = table.concat(dir_preview_hidden, "\n")
  assert_true(dir_text_hidden:find("Directory: src/") ~= nil, "preview must contain directory header")
  assert_true(dir_text_hidden:find("utils.lua") ~= nil, "directory preview must list regular child item utils.lua")
  assert_true(dir_text_hidden:find(".secret_module") == nil, "directory preview must NOT list .secret_module when dotfiles hidden")
  assert_true(dir_text_hidden:find("1 dot%-item hidden") ~= nil, "directory preview must note hidden dot-item count")

  -- 2b. With dotfiles revealed: .secret_module MUST appear in directory preview
  local dir_preview_revealed, _ = browser.get_preview(dir_entry, fixture, true)
  local dir_text_revealed = table.concat(dir_preview_revealed, "\n")
  assert_true(dir_text_revealed:find(".secret_module") ~= nil, "directory preview MUST list .secret_module when revealed")
  assert_true(dir_text_revealed:find("utils.lua") ~= nil, "directory preview must still list utils.lua")

  -- 3. Binary file inspection
  local bin_path = fixture .. "/sample.bin"
  local f_bin = io.open(bin_path, "wb")
  f_bin:write("\0\1\2\3\4\255")
  f_bin:close()

  local bin_entry = {
    path = "sample.bin",
    name = "sample.bin",
    is_dir = false,
    depth = 0,
    is_dot = false,
    full_path = bin_path,
  }
  local bin_preview, is_bin_text = browser.get_preview(bin_entry, fixture)
  assert_true(not is_bin_text, "binary file must not be marked as text")
  local bin_text = table.concat(bin_preview, "\n")
  assert_true(bin_text:find("Binary file") ~= nil, "preview must state binary file content suppressed")

  cleanup_dir(fixture)
end

function tests.test_project_browser_read_only_invariance()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Take exact before-status snapshots
  local before_status = vim.system({ "git", "-C", fixture, "status", "--porcelain=v1", "-z", "-uall" }, { text = true }):wait().stdout
  local before_diff = vim.system({ "git", "-C", fixture, "diff", "HEAD" }, { text = true }):wait().stdout

  -- Open project browser, toggle settings, switch views, navigate items
  workbench.open({ view = "files" })
  workbench.select_file(1)
  workbench.select_file(2)

  settings.toggle_dotfiles()
  workbench.refresh()

  workbench.set_view("diff")
  workbench.select_file(1)
  workbench.select_file(2)

  settings.toggle_dotfiles()
  workbench.refresh()
  workbench.set_view("files")

  workbench.close()

  -- Take exact after-status snapshots
  local after_status = vim.system({ "git", "-C", fixture, "status", "--porcelain=v1", "-z", "-uall" }, { text = true }):wait().stdout
  local after_diff = vim.system({ "git", "-C", fixture, "diff", "HEAD" }, { text = true }):wait().stdout

  -- Assert exact byte-for-byte invariance
  assert_eq(after_status, before_status, "Git status must remain 100% byte-for-byte identical")
  assert_eq(after_diff, before_diff, "Git diff must remain 100% byte-for-byte identical")

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- TASK-004 New Feature Tests (Source Navigation, View Switching, & Editing)
-- =========================================================================

function tests.test_open_regular_file_in_editor()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  assert_true(st.is_open, "workbench must be open")
  assert_eq(st.view_mode, "files", "view mode must be files")

  -- Find a regular file entry in project_files
  local target_entry = nil
  local target_idx = nil
  for idx, entry in ipairs(st.project_files) do
    if not entry.is_dir and entry.name == "README.md" then
      target_entry = entry
      target_idx = idx
      break
    end
  end
  assert_true(target_entry ~= nil, "fixture must contain README.md")

  -- Select and open the regular file
  workbench.select_file(target_idx)
  local open_ok = workbench.open_file(target_entry)
  assert_true(open_ok, "opening a regular file must succeed")

  -- Verify right window state
  local current_win = vim.api.nvim_get_current_win()
  assert_eq(current_win, st.win_right, "opening file must focus the right window")

  local edit_buf = vim.api.nvim_win_get_buf(st.win_right)
  local buf_name = vim.api.nvim_buf_get_name(edit_buf)
  assert_true(buf_name:find("README.md") ~= nil, "right window buffer must be README.md")
  assert_eq(vim.bo[edit_buf].buftype, "", "editing buffer must be a regular buffer (buftype='')")
  assert_eq(vim.bo[edit_buf].readonly, false, "editing buffer must not be readonly")
  assert_eq(vim.bo[edit_buf].modifiable, true, "editing buffer must be modifiable")

  -- Verify left window remains intact
  assert_true(vim.api.nvim_win_is_valid(st.win_left), "left window must remain valid")
  local left_buf = vim.api.nvim_win_get_buf(st.win_left)
  assert_eq(left_buf, st.buf_left, "left window must retain navigation buffer")

  -- Verify editing capability: modify lines and verify
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { "# Modified README", "New content line" })
  local modified_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
  assert_eq(modified_lines[1], "# Modified README", "buffer lines must be editable")
  assert_eq(vim.bo[edit_buf].modified, true, "buffer must be marked modified after edits")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_directory_selection_preserves_inspection_no_file_open()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- Find a directory entry
  local dir_entry = nil
  local dir_idx = nil
  for idx, entry in ipairs(st.project_files) do
    if entry.is_dir and entry.name == "src" then
      dir_entry = entry
      dir_idx = idx
      break
    end
  end
  assert_true(dir_entry ~= nil, "fixture must contain src directory")

  -- Attempt to open directory
  workbench.select_file(dir_idx)
  local open_result = workbench.open_file(dir_entry)
  assert_eq(open_result, false, "open_file on a directory must return false")

  -- Verify right pane remains in read-only preview mode
  local current_buf = vim.api.nvim_win_get_buf(st.win_right)
  assert_eq(current_buf, st.buf_right, "right window buffer must remain preview buffer (buf_right)")
  assert_eq(vim.bo[st.buf_right].buftype, "nofile", "preview buffer buftype must remain 'nofile'")
  assert_eq(vim.bo[st.buf_right].readonly, true, "preview buffer must remain readonly")
  assert_eq(vim.bo[st.buf_right].modifiable, false, "preview buffer must remain not modifiable")

  -- Verify right pane content shows directory inspection
  local preview_lines = vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false)
  local preview_text = table.concat(preview_lines, "\n")
  assert_true(preview_text:find("Directory: src") ~= nil, "preview must contain Directory: src")
  assert_true(preview_text:find("Contents:") ~= nil, "preview must contain Contents list")
  assert_true(preview_text:find("Direct Items:") ~= nil, "preview must contain Direct Items count")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_view_switching_and_active_tab_rendering()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- 1. Open in files view
  workbench.open({ view = "files" })
  local st1 = workbench.get_state()
  assert_eq(st1.view_mode, "files", "initial view mode must be files")

  local header_files = vim.api.nvim_buf_get_lines(st1.buf_left, 1, 2, false)
  assert_true(header_files[1]:find("▶ %[1: Files%]") ~= nil, "header tab 1 must show active indicator in files view")

  -- 2. Switch to diff view
  workbench.set_view("diff")
  local st2 = workbench.get_state()
  assert_eq(st2.view_mode, "diff", "view mode must be diff after set_view('diff')")
  assert_true(st2.win_middle ~= nil and vim.api.nvim_win_is_valid(st2.win_middle),
    "switching from Files to Diff must add the middle pane")
  local middle_mouse_map = false
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(st2.buf_middle, "n")) do
    if mapping.lhs == "<LeftMouse>" then
      middle_mouse_map = true
      break
    end
  end
  assert_true(middle_mouse_map, "dynamically-added middle pane must receive mouse mappings")

  local header_diff = vim.api.nvim_buf_get_lines(st2.buf_left, 1, 2, false)
  assert_true(header_diff[1]:find("▶ %[2: Git Diff%]") ~= nil, "header tab 2 must show active indicator in diff view")

  -- 3. Verify toggle_view switches back to files
  workbench.toggle_view()
  local st3 = workbench.get_state()
  assert_eq(st3.view_mode, "files", "view mode must be files after toggle_view()")

  -- 4. Verify toggle_view switches to diff
  workbench.toggle_view()
  local st4 = workbench.get_state()
  assert_eq(st4.view_mode, "diff", "view mode must be diff after toggle_view()")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_changed_file_diff_rendering_and_return_to_files()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Start in files view with custom dotfile setting
  settings.set("show_dotfiles", false)
  workbench.open({ view = "files" })
  local initial_root = workbench.get_state().root_dir
  assert_true(vim.fs.normalize(initial_root) == vim.fs.normalize(fixture) or initial_root:find(vim.fs.basename(fixture), 1, true) ~= nil, "root_dir must match fixture path")

  -- Switch to Git Diff view
  workbench.set_view("diff")
  local st_diff = workbench.get_state()
  assert_true(st_diff.git_file_count >= 3, "must have loaded changed git files")

  -- Select a modified file and verify the separate old/new panes.
  local modified_index = nil
  for i, file in ipairs(st_diff.files) do
    if file.path == "tracked_modified.txt" then
      modified_index = i
      break
    end
  end
  assert_true(modified_index ~= nil, "modified fixture file must be present")
  workbench.select_file(modified_index)
  local old_lines = vim.api.nvim_buf_get_lines(st_diff.buf_middle, 0, -1, false)
  local new_lines = vim.api.nvim_buf_get_lines(st_diff.buf_right, 0, -1, false)
  local old_text = table.concat(old_lines, "\n")
  local new_text = table.concat(new_lines, "\n")
  assert_true(old_text:find("initial line 2", 1, true) ~= nil, "middle pane must render the HEAD version")
  assert_true(new_text:find("MODIFIED line 2", 1, true) ~= nil, "right pane must render the working-tree version")
  assert_true(new_text:find("diff --git", 1, true) == nil, "new pane must not fall back to unified diff text")

  -- Return to Files view
  workbench.set_view("files")
  local st_returned = workbench.get_state()
  assert_eq(st_returned.view_mode, "files", "view mode must be files")
  assert_eq(st_returned.root_dir, initial_root, "root directory must be preserved")
  assert_eq(settings.get("show_dotfiles"), false, "show_dotfiles setting must be preserved")
  assert_true(st_returned.project_file_count > 0, "project file list must remain intact")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_unsaved_buffer_preservation_on_navigation()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- Find and open a file
  local entry1 = nil
  for _, entry in ipairs(st.project_files) do
    if not entry.is_dir and entry.name == "README.md" then
      entry1 = entry
      break
    end
  end
  assert_true(entry1 ~= nil, "fixture must contain README.md")

  workbench.open_file(entry1)
  local edit_buf = vim.api.nvim_win_get_buf(st.win_right)

  -- Add unsaved changes to the buffer
  vim.api.nvim_buf_set_lines(edit_buf, 0, 0, false, { "UNSAVED EDITED LINE 12345" })
  assert_eq(vim.bo[edit_buf].modified, true, "buffer must have unsaved edits")

  -- Switch back to left pane and navigate/preview other items
  vim.api.nvim_set_current_win(st.win_left)
  workbench.select_file(1) -- Preview item 1 in right pane
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right, "right window should switch to preview buffer")

  -- Switch views
  workbench.set_view("diff")
  workbench.set_view("files")

  -- Re-open README.md
  workbench.open_file(entry1)
  local re_opened_buf = vim.api.nvim_win_get_buf(st.win_right)
  assert_eq(re_opened_buf, edit_buf, "re-opened buffer must be the exact same in-memory buffer")
  local lines = vim.api.nvim_buf_get_lines(re_opened_buf, 0, 1, false)
  assert_eq(lines[1], "UNSAVED EDITED LINE 12345", "unsaved modifications must be completely preserved")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_keyboard_and_mouse_shortcuts()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- Test Tab switching to right window
  vim.api.nvim_set_current_win(st.win_left)
  local tab_map = vim.fn.maparg("<Tab>", "n", false, true)
  assert_true(tab_map ~= nil and tab_map.callback ~= nil, "<Tab> keymap must exist on left buffer")
  tab_map.callback()
  assert_eq(vim.api.nvim_get_current_win(), st.win_right, "<Tab> must switch focus to right window")

  -- Test Tab switching back to left window
  local right_tab_map = vim.fn.maparg("<Tab>", "n", false, true)
  assert_true(right_tab_map ~= nil and right_tab_map.callback ~= nil, "<Tab> keymap must exist on right buffer")
  right_tab_map.callback()
  assert_eq(vim.api.nvim_get_current_win(), st.win_left, "<Tab> must switch focus back to left window")

  -- Test Enter on left pane opens regular file
  local file_idx = nil
  for idx, entry in ipairs(st.project_files) do
    if not entry.is_dir and entry.name == "README.md" then
      file_idx = idx
      break
    end
  end
  assert_true(file_idx ~= nil, "README.md must exist in fixture")

  local target_line = st.header_line_count + file_idx
  vim.api.nvim_win_set_cursor(st.win_left, { target_line, 1 })
  local cr_map = vim.fn.maparg("<CR>", "n", false, true)
  assert_true(cr_map ~= nil and cr_map.callback ~= nil, "<CR> keymap must exist on left buffer")
  cr_map.callback()

  assert_eq(vim.api.nvim_get_current_win(), st.win_right, "<CR> on regular file must focus right window")
  local edit_buf = vim.api.nvim_win_get_buf(st.win_right)
  assert_true(vim.api.nvim_buf_get_name(edit_buf):find("README.md") ~= nil, "editing buffer must be README.md")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task004_source_navigation_git_invariance()
  local workbench = require("novim.workbench")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Capture baseline git status and diff
  local before_status = vim.system({ "git", "-C", fixture, "status", "--porcelain=v1", "-z", "-uall" }, { text = true }):wait().stdout
  local before_diff = vim.system({ "git", "-C", fixture, "diff", "HEAD" }, { text = true }):wait().stdout

  -- Perform full navigation cycle: open files, open dirs, switch views
  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- Open a regular file
  for _, entry in ipairs(st.project_files) do
    if not entry.is_dir and entry.name == "main.lua" then
      workbench.open_file(entry)
      break
    end
  end

  -- Attempt to open directory
  for _, entry in ipairs(st.project_files) do
    if entry.is_dir then
      workbench.open_file(entry)
      break
    end
  end

  -- Switch views and navigate diff items
  workbench.set_view("diff")
  workbench.select_file(1)
  workbench.select_file(2)

  -- Return to files view
  workbench.set_view("files")
  workbench.select_file(1)

  workbench.close()

  -- Capture after-navigation git status and diff
  local after_status = vim.system({ "git", "-C", fixture, "status", "--porcelain=v1", "-z", "-uall" }, { text = true }):wait().stdout
  local after_diff = vim.system({ "git", "-C", fixture, "diff", "HEAD" }, { text = true }):wait().stdout

  assert_eq(after_status, before_status, "Git status must remain 100% byte-for-byte identical after navigation")
  assert_eq(after_diff, before_diff, "Git diff must remain 100% byte-for-byte identical after navigation")

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- TASK-008 New Feature Tests (Themes, Settings Key Help, Esc Close, Pane Drag)
-- =========================================================================

--- Collect the lhs strings of all Normal-mode mappings of a buffer.
--- nvim_buf_get_keymap is buffer-scoped, so every returned map belongs to it.
local function buf_local_lhs(buf)
  local lhs_set = {}
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    lhs_set[map.lhs] = true
  end
  return lhs_set
end

--- All lhs spellings nvim_buf_get_keymap may use for a documented key.
--- Space is stored as a literal space; Ctrl keys are canonicalized uppercase.
local function lhs_spellings(key)
  if key == "<Space>" then
    return { key, " " }
  elseif key == "<C-r>" then
    return { key, "<C-R>" }
  end
  return { key }
end

--- Fetch the Normal-mode buffer-local callback registered for a mapping lhs.
local function buffer_map_callback(buf, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if map.lhs == lhs then
      return map.callback
    end
  end
  return nil
end

function tests.test_theme_catalog_defaults_and_application()
  local settings = require("novim.settings")
  local themes = require("novim.themes")

  -- Exactly six built-in themes in canonical order
  local list = themes.list()
  assert_eq(#list, 6, "exactly six built-in themes must exist")
  local expected_ids = { "tokyo_night", "nord", "gruvbox_dark", "catppuccin_mocha", "one_dark", "solarized_light" }
  local expected_labels = { "Tokyo Night", "Nord", "Gruvbox Dark", "Catppuccin Mocha", "One Dark", "Solarized Light" }
  for i = 1, 6 do
    assert_eq(list[i].id, expected_ids[i], "theme " .. i .. " id must be " .. expected_ids[i])
    assert_eq(list[i].label, expected_labels[i], "theme " .. i .. " label must be " .. expected_labels[i])
  end

  assert_true(themes.is_valid("tokyo_night"), "tokyo_night must be a valid theme")
  assert_true(not themes.is_valid("dracula"), "unknown themes must be invalid")
  assert_true(not themes.is_valid(42), "non-string ids must be invalid")

  -- Missing settings file defaults to Tokyo Night
  local path = settings.get_settings_file_path()
  os.remove(path)
  settings.reset_cache()
  local defaults = settings.load(true)
  assert_eq(defaults.theme, "tokyo_night", "missing theme value must default to Tokyo Night")
  assert_eq(defaults.show_dotfiles, false, "missing settings must also default show_dotfiles")

  -- Every theme applies without error and restyles the palette highlights
  local normal_fg_per_theme = {}
  for _, id in ipairs(expected_ids) do
    local applied = themes.apply(id)
    assert_eq(applied.id, id, "apply must apply the requested theme " .. id)
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    assert_true(normal.fg ~= nil, id .. " must define Normal foreground")
    assert_true(normal.bg ~= nil, id .. " must define Normal background")
    assert_true(vim.api.nvim_get_hl(0, { name = "WorkbenchHeader" }).fg ~= nil, id .. " must define WorkbenchHeader")
    assert_true(vim.api.nvim_get_hl(0, { name = "diffAdded" }).fg ~= nil, id .. " must define diffAdded")
    normal_fg_per_theme[id] = normal.fg
  end
  assert_eq(vim.o.background, "light", "Solarized Light must switch the background to light")
  assert_true(normal_fg_per_theme["tokyo_night"] ~= normal_fg_per_theme["nord"], "different themes must produce different palettes")

  -- Unknown ids fall back to Tokyo Night without error
  local fallback = themes.apply("dracula")
  assert_eq(fallback.id, "tokyo_night", "unknown theme ids must fall back to Tokyo Night")
  assert_eq(vim.g.colors_name, "tokyo_night", "colors_name must track the applied theme")
end

function tests.test_theme_persistence_and_fallback()
  local settings = require("novim.settings")
  local themes = require("novim.themes")
  local path = settings.get_settings_file_path()

  -- Persist both settings, then restore from disk like a fresh launch
  settings.set("show_dotfiles", true)
  settings.set("theme", "nord")
  assert_true(vim.fn.filereadable(path) == 1, "settings file must exist after saving theme")
  local parsed = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  assert_eq(parsed.theme, "nord", "saved theme must be nord")
  assert_eq(parsed.show_dotfiles, true, "saved show_dotfiles must remain true")

  settings.reset_cache()
  local reloaded = settings.load(true)
  assert_eq(reloaded.theme, "nord", "theme must persist across launches")
  assert_eq(reloaded.show_dotfiles, true, "existing dot-folder setting must persist alongside the theme")

  -- Invalid theme value falls back safely WITHOUT clobbering unrelated settings
  local f = io.open(path, "w")
  f:write('{"theme": "dracula", "show_dotfiles": true}')
  f:close()
  settings.reset_cache()
  local fallback = settings.load(true)
  assert_eq(fallback.theme, "tokyo_night", "invalid theme value must fall back to the default")
  assert_eq(fallback.show_dotfiles, true, "invalid theme must not overwrite the unrelated show_dotfiles setting")

  -- Malformed JSON falls back safely
  local f2 = io.open(path, "w")
  f2:write("THIS IS NOT JSON {{{{")
  f2:close()
  settings.reset_cache()
  local malformed = settings.load(true)
  assert_eq(malformed.theme, "tokyo_night", "malformed settings file must fall back to the default theme")

  -- Non-string theme value falls back safely
  local f3 = io.open(path, "w")
  f3:write('{"theme": 42}')
  f3:close()
  settings.reset_cache()
  local wrong_type = settings.load(true)
  assert_eq(wrong_type.theme, "tokyo_night", "non-string theme value must fall back to the default")

  -- The generic setter refuses invalid themes without touching state
  local ok, err = settings.set("theme", "dracula")
  assert_true(ok == false, "setting an unknown theme must fail")
  assert_true(err ~= nil, "setting an unknown theme must return an error message")
  assert_eq(settings.get("theme"), "tokyo_night", "rejected theme must not change the current value")

  -- Saving after a fallback rewrites a clean file preserving both settings
  settings.set("show_dotfiles", false)
  settings.reset_cache()
  local after_save = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  assert_eq(after_save.theme, "tokyo_night", "post-fallback save must write the default theme")
  assert_eq(after_save.show_dotfiles, false, "post-fallback save must keep the changed show_dotfiles")

  -- Restore clean defaults for the remaining suites
  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")
  assert_true(themes.is_valid(settings.get("theme")), "restored theme must be valid")
end

function tests.test_settings_theme_control_cycles_applies_and_persists()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  local themes = require("novim.themes")
  local settings = require("novim.settings")
  workbench.close()
  settings.set("theme", "tokyo_night")

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local before_hl = vim.api.nvim_get_hl(0, { name = "WorkbenchHeader" }).fg
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must open from the workbench")

  -- Cycling forward selects the next catalog entry and re-themes live
  local ok, err = settings_ui.cycle_theme(1)
  assert_true(ok, "cycling to the next theme must succeed: " .. tostring(err))
  assert_eq(settings.get("theme"), "nord", "next theme after Tokyo Night must be Nord")
  local after_hl = vim.api.nvim_get_hl(0, { name = "WorkbenchHeader" }).fg
  assert_true(before_hl ~= after_hl, "theme switch must restyle the workbench palette live")

  -- The panel re-renders with the selected theme
  local text = table.concat(vim.api.nvim_buf_get_lines(settings_ui.get_buf(), 0, -1, false), "\n")
  assert_true(text:find("Nord", 1, true) ~= nil, "settings panel must display the selected theme name")

  -- Cycling backward wraps around the catalog
  settings_ui.cycle_theme(-1)
  assert_eq(settings.get("theme"), "tokyo_night", "previous theme before Tokyo Night must wrap to the default again")
  settings_ui.cycle_theme(-1)
  assert_eq(settings.get("theme"), "solarized_light", "previous theme from the default must wrap to Solarized Light")

  -- The selection persists across a simulated fresh launch
  settings.reset_cache()
  assert_eq(settings.load(true).theme, "solarized_light", "cycled theme must persist across launches")

  settings_ui.close()
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)

  settings.set("theme", "tokyo_night")
  themes.apply("tokyo_night")
end

function tests.test_settings_panel_key_help_below_controls_matches_mappings()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  local keymaps = require("novim.keymaps")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must be open")

  local buf = settings_ui.get_buf()
  assert_true(buf ~= nil, "settings buffer must be available")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")

  -- Controls render above the key help section
  local theme_row, help_row
  for i, line in ipairs(lines) do
    if line:find("Theme:", 1, true) then theme_row = i end
    if line:find("Key Bindings (Workbench)", 1, true) then help_row = i end
  end
  assert_true(theme_row ~= nil, "settings panel must render the theme control")
  assert_true(help_row ~= nil, "settings panel must render the key help section")
  assert_true(help_row > theme_row, "key help must render below the controls")

  -- Every documented entry is visibly present in the panel
  local documented = {}
  local function mark_documented(key)
    for _, spelling in ipairs(lhs_spellings(key)) do
      documented[spelling] = true
    end
  end
  for _, entry in ipairs(keymaps.workbench) do
    assert_true(text:find(entry.display, 1, true) ~= nil,
      "key help must document: " .. entry.display)
    for _, key in ipairs(entry.keys) do
      mark_documented(key)
    end
  end
  for _, entry in ipairs(keymaps.settings) do
    assert_true(text:find(entry.display, 1, true) ~= nil,
      "settings help must document: " .. entry.display)
    for _, key in ipairs(entry.keys) do
      mark_documented(key)
    end
  end

  local function key_is_mapped(key, lhs_set)
    for _, spelling in ipairs(lhs_spellings(key)) do
      if lhs_set[spelling] then
        return true
      end
    end
    return false
  end

  -- Every documented workbench shortcut is backed by a real buffer-local mapping
  local left_keys = buf_local_lhs(st.buf_left)
  local right_keys = buf_local_lhs(st.buf_right)
  for _, entry in ipairs(keymaps.workbench) do
    for _, key in ipairs(entry.keys) do
      assert_true(key_is_mapped(key, left_keys) or key_is_mapped(key, right_keys),
        "documented shortcut must be an actual workbench mapping: " .. key)
    end
  end

  -- Reverse direction: every workbench mapping is documented in the help
  for key in pairs(left_keys) do
    assert_true(documented[key], "workbench mapping must appear in the key help: " .. key)
  end
  for key in pairs(right_keys) do
    assert_true(documented[key], "workbench mapping must appear in the key help: " .. key)
  end

  -- The settings panel mappings themselves match their documentation
  local settings_keys = buf_local_lhs(buf)
  for _, entry in ipairs(keymaps.settings) do
    for _, key in ipairs(entry.keys) do
      assert_true(key_is_mapped(key, settings_keys),
        "documented settings shortcut must be an actual mapping: " .. key)
    end
  end

  settings_ui.close()
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_single_esc_close_restores_workbench_focus()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- One Esc press closes the panel immediately and restores workbench focus
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must be open")
  assert_eq(vim.api.nvim_get_current_win(), settings_ui.get_win(), "settings must take focus while open")

  local settings_buf = settings_ui.get_buf()
  local esc_callback = nil
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(settings_buf, "n")) do
    if map.lhs == "<Esc>" then
      esc_callback = map.callback
    end
  end
  assert_true(esc_callback ~= nil, "Esc must have a single-press close mapping in settings")

  esc_callback()
  assert_true(not settings_ui.is_open(), "one Esc press must close settings immediately")
  assert_eq(vim.api.nvim_get_current_win(), st.win_left, "Esc must restore workbench focus")

  -- q remains a direct close action
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must reopen")
  settings_buf = settings_ui.get_buf()
  local q_callback = nil
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(settings_buf, "n")) do
    if map.lhs == "q" then
      q_callback = map.callback
    end
  end
  assert_true(q_callback ~= nil, "q must have a direct close mapping in settings")

  q_callback()
  assert_true(not settings_ui.is_open(), "q must close settings directly")
  assert_eq(vim.api.nvim_get_current_win(), st.win_left, "q must restore workbench focus")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_focus_indicator_rendering_and_movement()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must be open")
  local buf = settings_ui.get_buf()
  assert_true(buf ~= nil, "settings buffer must be available")

  local function indicator_rows()
    local rows = {}
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if line:find("▶", 1, true) then
        table.insert(rows, i)
      end
    end
    return rows
  end

  local function control_rows()
    local dot_row, theme_row, help_row
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if line:find("Show Dot-Folders", 1, true) then dot_row = i end
      if line:find("Theme:", 1, true) then theme_row = i end
      if line:find("Key Bindings (Workbench)", 1, true) then help_row = i end
    end
    return dot_row, theme_row, help_row
  end

  -- Opens with exactly one visible indicator, on the first control
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "settings must open with the first control selected")
  local dot_row, theme_row, help_row = control_rows()
  assert_true(dot_row ~= nil and theme_row ~= nil and help_row ~= nil,
    "both controls and the help section must render")
  local marked = indicator_rows()
  assert_eq(#marked, 1, "exactly one selected-control indicator must be visible")
  assert_eq(marked[1], dot_row, "the initial indicator must mark the dot-folder control")

  -- Focus movement keeps exactly one indicator and never leaves the controls
  local cursor_before = vim.api.nvim_win_get_cursor(settings_ui.get_win())
  settings_ui.move_focus(1)
  assert_eq(settings_ui.get_selected_control(), "theme",
    "Down must move focus to the theme control")
  marked = indicator_rows()
  assert_eq(#marked, 1, "exactly one indicator must remain visible after movement")
  assert_eq(marked[1], theme_row, "the indicator must move to the theme control row")

  settings_ui.move_focus(1)
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "Down from the last control must wrap to the first")
  settings_ui.move_focus(-1)
  assert_eq(settings_ui.get_selected_control(), "theme",
    "Up from the first control must wrap to the last")

  -- Movement never moves the cursor through the rendered help section
  local cursor_after = vim.api.nvim_win_get_cursor(settings_ui.get_win())
  assert_true(cursor_before[1] == cursor_after[1] and cursor_before[2] == cursor_after[2],
    "focus movement must not move the buffer cursor")
  marked = indicator_rows()
  assert_true(marked[1] < help_row,
    "the indicator must never rest on a help or informational line")

  -- The real Up/Down mappings drive the same focus model
  local down_cb = buffer_map_callback(buf, "<Down>")
  local up_cb = buffer_map_callback(buf, "<Up>")
  assert_true(down_cb ~= nil and up_cb ~= nil, "Up/Down must be mapped in the settings buffer")
  down_cb()
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "the Down mapping must move focus to the next control")
  up_cb()
  assert_eq(settings_ui.get_selected_control(), "theme",
    "the Up mapping must move focus to the previous control")

  settings_ui.close()
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_arrow_theme_only_and_space_activation()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")

  workbench.open({ view = "files" })
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must be open")
  local buf = settings_ui.get_buf()
  local right_cb = buffer_map_callback(buf, "<Right>")
  local left_cb = buffer_map_callback(buf, "<Left>")
  local space_cb = buffer_map_callback(buf, " ")
  assert_true(right_cb ~= nil and left_cb ~= nil and space_cb ~= nil,
    "Left/Right/Space must be mapped in the settings buffer")

  -- Left/Right must not change the theme while a non-theme control is selected
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "the panel opens with the dot-folder control selected")
  right_cb()
  assert_eq(settings.get("theme"), "tokyo_night",
    "Right must not change the theme while the dot-folder control is selected")
  left_cb()
  assert_eq(settings.get("theme"), "tokyo_night",
    "Left must not change the theme while the dot-folder control is selected")

  -- While the theme control is selected, Left/Right cycle the persisted theme
  settings_ui.move_focus(1)
  assert_eq(settings_ui.get_selected_control(), "theme", "focus must reach the theme control")
  right_cb()
  assert_eq(settings.get("theme"), "nord",
    "Right with the theme control selected must persist the next theme")
  left_cb()
  assert_eq(settings.get("theme"), "tokyo_night",
    "Left with the theme control selected must persist the previous theme")

  -- Space activates the selected control in both directions
  space_cb()
  assert_eq(settings.get("theme"), "nord",
    "Space on the theme control must activate it (next theme)")
  settings_ui.move_focus(-1)
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "focus must return to the dot-folder control")
  space_cb()
  assert_eq(settings.get("show_dotfiles"), true,
    "Space on the dot-folder control must toggle visibility on")
  space_cb()
  assert_eq(settings.get("show_dotfiles"), false,
    "Space on the dot-folder control must toggle visibility off")

  settings_ui.close()
  workbench.close()
  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_focus_survives_failed_settings_writes()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")

  local path = settings.get_settings_file_path()
  os.remove(path)
  -- Create a directory at settings file path to force a write error
  vim.fn.mkdir(path, "p")

  settings.reset_cache()
  workbench.open({ view = "files" })
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must open even when writes fail")
  local buf = settings_ui.get_buf()

  local function panel_text()
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  end

  -- Space on the dot-folder control fails the synchronous save, renders the
  -- error, and leaves the effective value and the focus state coherent
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "a fresh panel must select the dot-folder control")
  local space_cb = buffer_map_callback(buf, " ")
  assert_true(space_cb ~= nil, "Space must be mapped in the settings buffer")
  space_cb()
  assert_eq(settings.get("show_dotfiles"), false,
    "a failed write must not change the effective value")
  assert_eq(settings_ui.get_selected_control(), "dotfiles",
    "a failed write must leave the selected control unchanged")
  assert_true(panel_text():find("Changes could not be persisted", 1, true) ~= nil,
    "a failed dot-folder write must render the persistent error line")

  -- Theme activation through the same boundary: error rendered, theme kept,
  -- focus still on the theme control
  settings_ui.move_focus(1)
  assert_eq(settings_ui.get_selected_control(), "theme", "focus must reach the theme control")
  local right_cb = buffer_map_callback(buf, "<Right>")
  assert_true(right_cb ~= nil, "Right must be mapped in the settings buffer")
  right_cb()
  assert_eq(settings.get("theme"), "tokyo_night",
    "a failed theme write must keep the effective theme")
  assert_eq(settings_ui.get_selected_control(), "theme",
    "a failed theme write must keep the theme control selected")
  assert_true(panel_text():find("Failed to save theme", 1, true) ~= nil,
    "a failed theme write must render its error line")

  -- The error stays visible while focus moves between controls
  settings_ui.move_focus(-1)
  assert_true(panel_text():find("Failed to save theme", 1, true) ~= nil,
    "the last write error must remain rendered across focus movement")

  settings_ui.close()
  workbench.close()
  vim.fn.delete(path, "rf")
  settings.reset_cache()
  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_settings_mouse_close_affordance()
  local workbench = require("novim.workbench")
  local settings_ui = require("novim.settings_ui")
  local settings = require("novim.settings")
  local themes = require("novim.themes")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must be open")

  local lines = vim.api.nvim_buf_get_lines(settings_ui.get_buf(), 0, -1, false)
  -- The affordance renders visibly in the top-right of the title row
  assert_true(lines[1]:find("Close [x]", 1, true) ~= nil,
    "the title row must render the mouse close affordance")
  assert_eq(#lines[1], vim.api.nvim_win_get_width(settings_ui.get_win()),
    "the close affordance must sit flush with the right edge of the panel")

  -- Clicking the affordance closes through the safe path without changing
  -- any setting and restores workbench focus
  local theme_before = settings.get("theme")
  local dots_before = settings.get("show_dotfiles")
  settings_ui.handle_click(1, #lines[1], settings_ui.get_win())
  assert_true(not settings_ui.is_open(), "clicking the close affordance must close settings")
  assert_eq(vim.api.nvim_get_current_win(), st.win_left,
    "the close affordance must restore workbench focus")
  assert_eq(settings.get("theme"), theme_before,
    "closing via the affordance must not change the theme")
  assert_eq(settings.get("show_dotfiles"), dots_before,
    "closing via the affordance must not change dot-folder visibility")

  -- Reopen: clicks off the controls never close the panel; clicking a
  -- control row focuses it
  workbench.open_settings()
  assert_true(settings_ui.is_open(), "settings panel must reopen")
  local buf = settings_ui.get_buf()
  lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local theme_row
  for i, line in ipairs(lines) do
    if line:find("Theme:", 1, true) then theme_row = i end
  end
  assert_true(theme_row ~= nil, "the theme control must render")
  settings_ui.handle_click(3, 1, settings_ui.get_win())
  assert_true(settings_ui.is_open(), "clicking a non-control row must not close settings")
  settings_ui.handle_click(theme_row, 6, settings_ui.get_win())
  assert_eq(settings_ui.get_selected_control(), "theme",
    "clicking the theme row must focus the theme control")
  assert_true(settings_ui.is_open(), "clicking a control row must not close settings")

  settings_ui.close()
  workbench.close()
  settings.set("show_dotfiles", false)
  settings.set("theme", "tokyo_night")
  themes.apply("tokyo_night")
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_pane_drag_both_directions_with_minimum_clamp()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()
  local total = vim.o.columns
  local w0 = vim.api.nvim_win_get_width(st.win_left)
  local sep_col = vim.fn.win_screenpos(st.win_right)[2] - 1
  assert_true(sep_col > w0, "divider column must sit right of the left pane")

  -- Simulated divider drag: press, drag right, drag left, release
  workbench.pane_drag_start(sep_col)
  workbench.pane_drag_move(sep_col + 12)
  local w_wider = vim.api.nvim_win_get_width(st.win_left)
  assert_true(w_wider > w0, "dragging the divider right must widen the left pane")

  workbench.pane_drag_move(sep_col - 8)
  local w_narrower = vim.api.nvim_win_get_width(st.win_left)
  assert_true(w_narrower < w_wider, "dragging the divider left must narrow the left pane")

  workbench.pane_drag_end()
  assert_eq(vim.api.nvim_win_get_width(st.win_left), w_narrower, "release must keep the last dragged width")

  -- Stale drag events after release are ignored
  workbench.pane_drag_move(sep_col + 100)
  assert_eq(vim.api.nvim_win_get_width(st.win_left), w_narrower, "drag move without an active drag must be a no-op")

  -- Dragging far right clamps so the right pane keeps its minimum width
  workbench.pane_drag_start(sep_col)
  workbench.pane_drag_move(total)
  local max_left = vim.api.nvim_win_get_width(st.win_left)
  local right_at_max = vim.api.nvim_win_get_width(st.win_right)
  assert_true(max_left < total, "left pane must clamp before consuming the whole width")
  assert_true(right_at_max >= 20, "right pane must keep its minimum width at the clamp")
  assert_true(vim.api.nvim_win_is_valid(st.win_right), "right window must stay valid at the clamp")

  -- Dragging far left clamps at the left pane minimum
  workbench.pane_drag_move(0)
  local min_left = vim.api.nvim_win_get_width(st.win_left)
  assert_true(min_left >= 15, "left pane must keep its minimum width at the clamp")
  assert_true(vim.api.nvim_win_is_valid(st.win_left), "left window must stay valid at the clamp")
  workbench.pane_drag_end()

  -- The resize helper clamps invalid targets without raising (no E21)
  workbench.resize_left_pane(1)
  assert_true(vim.api.nvim_win_get_width(st.win_left) >= 15, "resize below the minimum must clamp")
  workbench.resize_left_pane(total * 10)
  assert_true(vim.api.nvim_win_get_width(st.win_right) >= 20, "resize above the maximum must clamp")

  -- Dragging preserves the selection and navigation behavior
  workbench.select_file(2)
  local sel_before = workbench.get_state().selected_project_index
  workbench.pane_drag_start(sep_col)
  workbench.pane_drag_move(sep_col + 5)
  workbench.pane_drag_end()
  assert_eq(workbench.get_state().selected_project_index, sel_before, "dragging must not change the selection")
  assert_true(workbench.get_state().is_open, "workbench must remain open after a drag")

  -- The drag mappings back the documented behavior on the left buffer
  local left_keys = buf_local_lhs(st.buf_left)
  assert_true(left_keys["<LeftDrag>"] ~= nil, "<LeftDrag> must be mapped for divider dragging")
  assert_true(left_keys["<LeftRelease>"] ~= nil, "<LeftRelease> must be mapped to end dragging")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- TASK-009 New Feature Tests (Three-Area Diff, Refresh & Boundary Dragging)
-- =========================================================================

function tests.test_three_area_diff_refresh_versions_special_files_and_drag()
  local workbench = require("novim.workbench")
  local git = require("novim.git")
  workbench.close()
  reset_saved_layout()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "diff" })
  local state = workbench.get_state()
  assert_true(state.win_middle ~= nil and vim.api.nvim_win_is_valid(state.win_middle),
    "Diff view must create a valid middle pane")
  assert_true(state.buf_middle ~= nil and vim.api.nvim_buf_is_valid(state.buf_middle),
    "Diff view must create a valid old-file buffer")
  assert_true(state.win_left ~= state.win_middle and state.win_middle ~= state.win_right,
    "Diff view panes must be distinct")

  local function file_index(path)
    for i, file in ipairs(state.files) do
      if file.path == path then return i, file end
    end
    return nil, nil
  end

  local modified_index = file_index("tracked_modified.txt")
  assert_true(modified_index ~= nil, "modified file must be listed")
  workbench.select_file(modified_index)
  local old_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_middle, 0, -1, false), "\n")
  local new_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false), "\n")
  assert_true(old_text:find("initial line 2", 1, true) ~= nil, "old pane must show HEAD content")
  assert_true(new_text:find("MODIFIED line 2", 1, true) ~= nil, "new pane must show working-tree content")
  assert_true(old_text:find("MODIFIED line 2", 1, true) == nil, "old pane must not show working-tree-only content")

  local deleted_index, deleted_file = file_index("tracked_deleted.txt")
  assert_true(deleted_index ~= nil and deleted_file.is_deleted, "deleted file must retain deleted metadata")
  workbench.select_file(deleted_index)
  old_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_middle, 0, -1, false), "\n")
  new_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false), "\n")
  assert_true(old_text:find("to be deleted", 1, true) ~= nil, "deleted file old pane must retain HEAD content")
  assert_true(new_text:find("deleted from working tree", 1, true) ~= nil, "deleted file new pane must show a readable placeholder")

  local renamed_index, renamed_file = file_index("renamed -> destination.txt")
  assert_true(renamed_index ~= nil and renamed_file.orig_path == "base_rename.txt", "rename metadata must retain the original path")
  workbench.select_file(renamed_index)
  old_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_middle, 0, -1, false), "\n")
  new_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false), "\n")
  assert_true(old_text:find("rename base content", 1, true) ~= nil, "renamed file old pane must use the original HEAD path")
  assert_true(new_text:find("rename base content", 1, true) ~= nil, "renamed file new pane must use the destination path")

  local untracked_index, untracked_file = file_index("untracked_new.txt")
  assert_true(untracked_index ~= nil and untracked_file.is_untracked, "untracked file must retain untracked metadata")
  workbench.select_file(untracked_index)
  old_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_middle, 0, -1, false), "\n")
  new_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false), "\n")
  assert_true(old_text:find("No file in HEAD", 1, true) ~= nil, "untracked file old pane must show no-HEAD placeholder")
  assert_true(new_text:find("untracked line 1", 1, true) ~= nil, "untracked file new pane must show working-tree content")

  local binary_index, binary_file = file_index("binary_file.bin")
  assert_true(binary_index ~= nil and binary_file.is_untracked, "binary fixture must be listed as untracked")
  local versions = git.get_file_versions(binary_file, fixture)
  assert_true(versions.is_binary and versions.new_binary, "Git version reader must identify binary working-tree content")
  workbench.select_file(binary_index)
  new_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false), "\n")
  assert_true(new_text:find("Binary file", 1, true) ~= nil, "binary new pane must use a readable placeholder")

  -- Refresh happens on every Diff entry, not only through the manual command.
  workbench.set_view("files")
  local fresh = io.open(fixture .. "/entry_refresh.txt", "w")
  fresh:write("appeared after leaving Diff\n")
  fresh:close()
  workbench.set_view("diff")
  state = workbench.get_state()
  local refreshed_index = file_index("entry_refresh.txt")
  assert_true(refreshed_index ~= nil, "re-entering Diff must refresh newly changed files")
  workbench.select_file(refreshed_index)
  new_text = table.concat(vim.api.nvim_buf_get_lines(state.buf_right, 0, -1, false), "\n")
  assert_true(new_text:find("appeared after leaving Diff", 1, true) ~= nil,
    "re-entered Diff must render refreshed working-tree content")

  -- Both visible Diff boundaries resize independently and keep minimum widths.
  local function separator(left_win, right_win)
    return vim.fn.win_screenpos(right_win)[2] - 1
  end
  local left_width = vim.api.nvim_win_get_width(state.win_left)
  local middle_width = vim.api.nvim_win_get_width(state.win_middle)
  local first_separator = separator(state.win_left, state.win_middle)
  workbench.pane_drag_start(first_separator)
  workbench.pane_drag_move(first_separator + 5)
  assert_true(vim.api.nvim_win_get_width(state.win_left) > left_width, "first boundary drag must widen the left pane")
  assert_true(vim.api.nvim_win_get_width(state.win_middle) < middle_width, "first boundary drag must narrow the middle pane")
  assert_true(vim.api.nvim_win_get_width(state.win_middle) >= 20, "middle pane must keep its minimum width")

  local second_separator = separator(state.win_middle, state.win_right)
  local middle_before_second_drag = vim.api.nvim_win_get_width(state.win_middle)
  local right_before_second_drag = vim.api.nvim_win_get_width(state.win_right)
  workbench.pane_drag_start(second_separator)
  workbench.pane_drag_move(second_separator + 5)
  assert_true(vim.api.nvim_win_get_width(state.win_middle) > middle_before_second_drag,
    "second boundary drag must widen the middle pane")
  assert_true(vim.api.nvim_win_get_width(state.win_right) < right_before_second_drag,
    "second boundary drag must narrow the right pane")
  assert_true(vim.api.nvim_win_get_width(state.win_right) >= 20, "right pane must keep its minimum width")
  workbench.pane_drag_end()

  first_separator = separator(state.win_left, state.win_middle)
  workbench.pane_drag_start(first_separator)
  workbench.pane_drag_move(0)
  assert_true(vim.api.nvim_win_get_width(state.win_left) >= 15, "first boundary extreme must clamp left pane")
  assert_true(vim.api.nvim_win_get_width(state.win_middle) >= 20, "first boundary extreme must clamp middle pane")
  workbench.pane_drag_end()

  second_separator = separator(state.win_middle, state.win_right)
  workbench.pane_drag_start(second_separator)
  workbench.pane_drag_move(vim.o.columns)
  assert_true(vim.api.nvim_win_get_width(state.win_middle) >= 20, "second boundary extreme must clamp middle pane")
  assert_true(vim.api.nvim_win_get_width(state.win_right) >= 20, "second boundary extreme must clamp right pane")
  workbench.pane_drag_end()
  assert_true(vim.api.nvim_win_is_valid(state.win_left)
    and vim.api.nvim_win_is_valid(state.win_middle)
    and vim.api.nvim_win_is_valid(state.win_right), "all Diff panes must remain valid after dragging")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- TASK-010 New Feature Tests (Pane Layout Persistence)
-- =========================================================================

--- Run body with the settings file redirected to a run-specific path so
--- layout persistence stays deterministic regardless of test order and so
--- cleanup never touches the real isolated development settings file.
local function with_isolated_settings_path(test_settings_file, body)
  local settings = require("novim.settings")
  local workbench = require("novim.workbench")
  local orig_get_path = settings.get_settings_file_path
  settings.get_settings_file_path = function()
    return test_settings_file
  end
  settings.reset_cache()
  local ok, err = pcall(body)
  if not ok then
    pcall(workbench.close)
  end
  settings.get_settings_file_path = orig_get_path
  settings.reset_cache()
  if not ok then
    error(err)
  end
end

function tests.test_pane_layout_persists_across_view_switches_independently()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  local test_settings_file = vim.fn.tempname() .. "_layout_switch_settings.json"
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local ok, err = pcall(function()
    with_isolated_settings_path(test_settings_file, function()
      workbench.open({ view = "files" })
      local st = workbench.get_state()

      -- A completed Files drag persists only the Files geometry.
      local sep = vim.fn.win_screenpos(st.win_right)[2] - 1
      workbench.pane_drag_start(sep)
      workbench.pane_drag_move(sep - 6)
      workbench.pane_drag_end()
      local files_width = vim.api.nvim_win_get_width(st.win_left)
      assert_true(files_width >= 15, "dragged Files width must respect the minimum")

      local saved = settings.get("layout")
      assert_eq(saved.files.left, files_width, "completed Files drag must persist the effective left width")
      assert_true(saved.diff.left == nil and saved.diff.middle == nil,
        "a Files drag must not touch Diff geometry")

      -- Independent Diff boundary drags persist only the Diff geometry.
      workbench.set_view("diff")
      st = workbench.get_state()
      local sep1 = vim.fn.win_screenpos(st.win_middle)[2] - 1
      workbench.pane_drag_start(sep1)
      workbench.pane_drag_move(sep1 + 4)
      workbench.pane_drag_end()
      local diff_left = vim.api.nvim_win_get_width(st.win_left)

      local sep2 = vim.fn.win_screenpos(st.win_right)[2] - 1
      workbench.pane_drag_start(sep2)
      workbench.pane_drag_move(sep2 + 7)
      workbench.pane_drag_end()
      local diff_middle = vim.api.nvim_win_get_width(st.win_middle)
      assert_true(vim.api.nvim_win_get_width(st.win_right) >= 20,
        "Diff drag must keep the right pane minimum")

      saved = settings.get("layout")
      assert_eq(saved.diff.left, diff_left, "boundary 1 drag must persist the effective left width")
      assert_eq(saved.diff.middle, diff_middle, "boundary 2 drag must persist the effective middle width")
      assert_eq(saved.files.left, files_width, "Diff drags must not alter the saved Files geometry")

      -- Files round-trip restores the saved divider.
      workbench.set_view("files")
      st = workbench.get_state()
      assert_eq(vim.api.nvim_win_get_width(st.win_left), files_width,
        "Files divider must restore its saved width after a Diff round-trip")

      -- Diff round-trip restores both saved boundaries.
      workbench.set_view("diff")
      st = workbench.get_state()
      assert_eq(vim.api.nvim_win_get_width(st.win_left), diff_left,
        "Diff left boundary must restore its saved width")
      assert_eq(vim.api.nvim_win_get_width(st.win_middle), diff_middle,
        "Diff middle boundary must restore its saved width")

      workbench.close()
    end)
  end)

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
  vim.fn.delete(test_settings_file, "rf")
  if not ok then
    error(err)
  end
end

function tests.test_pane_layout_persists_across_workbench_reopen()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  local test_settings_file = vim.fn.tempname() .. "_layout_reopen_settings.json"
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local ok, err = pcall(function()
    with_isolated_settings_path(test_settings_file, function()
      -- First session: drag both views, then close (capture at teardown).
      workbench.open({ view = "files" })
      local st = workbench.get_state()
      local sep = vim.fn.win_screenpos(st.win_right)[2] - 1
      workbench.pane_drag_start(sep)
      workbench.pane_drag_move(sep + 8)
      workbench.pane_drag_end()
      local files_width = vim.api.nvim_win_get_width(st.win_left)

      workbench.set_view("diff")
      st = workbench.get_state()
      local sep1 = vim.fn.win_screenpos(st.win_middle)[2] - 1
      workbench.pane_drag_start(sep1)
      workbench.pane_drag_move(sep1 - 3)
      workbench.pane_drag_end()
      local diff_left = vim.api.nvim_win_get_width(st.win_left)
      local sep2 = vim.fn.win_screenpos(st.win_right)[2] - 1
      workbench.pane_drag_start(sep2)
      workbench.pane_drag_move(sep2 + 6)
      workbench.pane_drag_end()
      local diff_middle = vim.api.nvim_win_get_width(st.win_middle)

      workbench.close()

      -- The settings file on disk must hold both views' geometry.
      local parsed = vim.json.decode(table.concat(vim.fn.readfile(test_settings_file), "\n"))
      assert_eq(parsed.layout.files.left, files_width, "settings file must record the Files width")
      assert_eq(parsed.layout.diff.left, diff_left, "settings file must record the Diff left width")
      assert_eq(parsed.layout.diff.middle, diff_middle, "settings file must record the Diff middle width")

      -- A later launch with a cold settings cache restores both layouts.
      settings.reset_cache()
      workbench.open({ view = "files" })
      st = workbench.get_state()
      assert_eq(vim.api.nvim_win_get_width(st.win_left), files_width,
        "reopened workbench must restore the saved Files width")

      workbench.set_view("diff")
      st = workbench.get_state()
      assert_eq(vim.api.nvim_win_get_width(st.win_left), diff_left,
        "reopened workbench must restore the Diff left boundary")
      assert_eq(vim.api.nvim_win_get_width(st.win_middle), diff_middle,
        "reopened workbench must restore the Diff middle boundary")

      workbench.close()
    end)
  end)

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
  vim.fn.delete(test_settings_file, "rf")
  if not ok then
    error(err)
  end
end

function tests.test_pane_layout_malformed_values_fall_back_safely()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  local themes = require("novim.themes")
  workbench.close()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  local test_settings_file = vim.fn.tempname() .. "_layout_malformed_settings.json"
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local ok, err = pcall(function()
    with_isolated_settings_path(test_settings_file, function()
      -- Non-numeric, impossible, and unknown layout values degrade to the
      -- safe defaults while theme and dot-folder settings survive.
      local f = io.open(test_settings_file, "w")
      f:write(vim.json.encode({
        show_dotfiles = true,
        theme = "tokyo_night",
        layout = {
          files = { left = "wide", middle = 30 },
          diff = { left = -3, middle = true, right = 42 },
        },
      }) .. "\n")
      f:close()

      settings.reset_cache()
      local loaded = settings.load(true)
      assert_eq(loaded.show_dotfiles, true, "show_dotfiles must survive a malformed layout")
      assert_true(themes.is_valid(loaded.theme), "theme must survive a malformed layout")
      assert_true(loaded.layout.files.left == nil and loaded.layout.files.middle == nil,
        "non-numeric Files geometry must fall back to the default")
      assert_true(loaded.layout.diff.left == nil and loaded.layout.diff.middle == nil,
        "impossible Diff geometry must fall back to the default")

      -- The workbench stays usable on the built-in starting layout.
      workbench.open({ view = "files" })
      local st = workbench.get_state()
      assert_true(vim.api.nvim_win_is_valid(st.win_left) and vim.api.nvim_win_is_valid(st.win_right),
        "workbench must open with malformed persisted geometry")
      assert_true(vim.api.nvim_win_get_width(st.win_left) >= 15
        and vim.api.nvim_win_get_width(st.win_right) >= 20,
        "default start must respect the pane minimums")

      workbench.set_view("diff")
      st = workbench.get_state()
      assert_true(vim.api.nvim_win_is_valid(st.win_left)
        and vim.api.nvim_win_is_valid(st.win_middle)
        and vim.api.nvim_win_is_valid(st.win_right),
        "Diff must open with malformed persisted geometry")
      assert_true(vim.api.nvim_win_get_width(st.win_left) >= 15
        and vim.api.nvim_win_get_width(st.win_middle) >= 20
        and vim.api.nvim_win_get_width(st.win_right) >= 20,
        "Diff default start must respect the pane minimums")

      -- Saving new geometry keeps theme and dot-folder settings intact.
      workbench.set_view("files")
      local save_ok = settings.set_layout({ files = { left = 40 } })
      assert_true(save_ok, "set_layout must succeed on a writable settings file")
      settings.reset_cache()
      local reloaded = settings.load(true)
      assert_eq(reloaded.layout.files.left, 40, "valid geometry must persist")
      assert_eq(reloaded.show_dotfiles, true, "show_dotfiles must remain intact after a geometry save")
      assert_true(themes.is_valid(reloaded.theme), "theme must remain intact after a geometry save")

      -- A settings-write failure must not crash or corrupt the live layout.
      workbench.close()
      vim.fn.delete(test_settings_file)
      vim.fn.mkdir(test_settings_file, "p")
      settings.reset_cache()
      workbench.open({ view = "files" })
      local st2 = workbench.get_state()
      local before = vim.api.nvim_win_get_width(st2.win_left)
      local sep = vim.fn.win_screenpos(st2.win_right)[2] - 1
      workbench.pane_drag_start(sep)
      workbench.pane_drag_move(sep + 5)
      workbench.pane_drag_end()
      assert_true(workbench.get_state().is_open, "workbench must survive a failed settings write")
      assert_true(vim.api.nvim_win_is_valid(st2.win_left) and vim.api.nvim_win_is_valid(st2.win_right),
        "panes must stay valid when the settings write fails")
      assert_eq(vim.api.nvim_win_get_width(st2.win_left), before + 5,
        "a failed settings write must not disturb the live drag result")
      workbench.close()
      vim.fn.delete(test_settings_file, "rf")
      settings.reset_cache()
    end)
  end)

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
  vim.fn.delete(test_settings_file, "rf")
  if not ok then
    error(err)
  end
end

function tests.test_pane_layout_clamps_to_narrow_terminal()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  local old_columns = vim.o.columns
  local test_settings_file = vim.fn.tempname() .. "_layout_clamp_settings.json"
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local ok, err = pcall(function()
    with_isolated_settings_path(test_settings_file, function()
      -- Save deliberately wide geometry at a wide terminal.
      vim.o.columns = 120
      workbench.open({ view = "files" })
      local st = workbench.get_state()
      local sep = vim.fn.win_screenpos(st.win_right)[2] - 1
      workbench.pane_drag_start(sep)
      workbench.pane_drag_move(sep + 40)
      workbench.pane_drag_end()
      local saved_files_width = vim.api.nvim_win_get_width(st.win_left)

      workbench.set_view("diff")
      st = workbench.get_state()
      local sep1 = vim.fn.win_screenpos(st.win_middle)[2] - 1
      workbench.pane_drag_start(sep1)
      workbench.pane_drag_move(sep1 + 30)
      workbench.pane_drag_end()
      local saved_diff_left = vim.api.nvim_win_get_width(st.win_left)
      local sep2 = vim.fn.win_screenpos(st.win_right)[2] - 1
      workbench.pane_drag_start(sep2)
      workbench.pane_drag_move(sep2 + 30)
      workbench.pane_drag_end()
      local saved_diff_middle = vim.api.nvim_win_get_width(st.win_middle)
      workbench.close()

      -- Reopen at a much narrower terminal: widths clamp to the current
      -- width and every pane stays valid at its minimum.
      vim.o.columns = 70
      settings.reset_cache()
      workbench.open({ view = "files" })
      st = workbench.get_state()
      local left = vim.api.nvim_win_get_width(st.win_left)
      local right = vim.api.nvim_win_get_width(st.win_right)
      assert_true(left < saved_files_width, "Files width must clamp to the narrower terminal")
      assert_true(left >= 15 and right >= 20, "clamped Files layout must keep the minimums")
      assert_eq(left + right, 69, "Files panes must fill the terminal exactly")

      workbench.set_view("diff")
      st = workbench.get_state()
      left = vim.api.nvim_win_get_width(st.win_left)
      local middle = vim.api.nvim_win_get_width(st.win_middle)
      right = vim.api.nvim_win_get_width(st.win_right)
      assert_true(left < saved_diff_left and middle < saved_diff_middle,
        "Diff geometry must clamp to the narrower terminal")
      assert_true(left >= 15 and middle >= 20 and right >= 20,
        "clamped Diff layout must keep the minimums")
      assert_eq(left + middle + right, 68, "Diff panes must fill the terminal exactly")
      assert_true(vim.api.nvim_win_is_valid(st.win_left)
        and vim.api.nvim_win_is_valid(st.win_middle)
        and vim.api.nvim_win_is_valid(st.win_right),
        "all panes must stay valid after clamping")
      workbench.close()

      -- An extremely narrow terminal cannot fit three usable panes; restore
      -- degrades to the built-in start instead of creating invalid state.
      vim.o.columns = 50
      settings.reset_cache()
      workbench.open({ view = "files" })
      st = workbench.get_state()
      assert_true(vim.api.nvim_win_is_valid(st.win_left) and vim.api.nvim_win_is_valid(st.win_right),
        "extremely narrow terminal must keep both Files panes valid")
      workbench.set_view("diff")
      st = workbench.get_state()
      assert_true(vim.api.nvim_win_is_valid(st.win_left)
        and vim.api.nvim_win_is_valid(st.win_middle)
        and vim.api.nvim_win_is_valid(st.win_right),
        "extremely narrow terminal must keep all Diff panes valid")
      workbench.close()
    end)
  end)

  vim.o.columns = old_columns
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
  vim.fn.delete(test_settings_file, "rf")
  if not ok then
    error(err)
  end
end

-- =========================================================================
-- TASK-012 New Feature Tests (Source Control Graph & Two-Endpoint Comparison)
-- =========================================================================

--- Create a fixture repository whose current branch contains a real merge
--- node plus decorated local branches, and working-tree changes for the
--- default comparison. Fixture setup only touches the temporary repository.
local function create_merge_history_fixture()
  local dir = vim.fn.tempname() .. "_merge_history_fixture"
  vim.fn.mkdir(dir, "p")

  local function run_git(args)
    local out = vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " " .. args)
    if vim.v.shell_error ~= 0 then
      error("git " .. args .. " failed: " .. out)
    end
    return out
  end

  local function write_file(name, content)
    local f = io.open(dir .. "/" .. name, "wb")
    f:write(content)
    f:close()
  end

  run_git("init -q -b main")
  run_git("config user.email 'test@example.com'")
  run_git("config user.name 'Test Runner'")

  -- C1 on main: tracked content plus a binary file
  write_file("feature.txt", "base line\n")
  write_file("shared.txt", "c1 shared\n")
  write_file("binary.bin", "\0\1\2\3\255")
  run_git("add .")
  run_git("commit -q -m 'C1 base'")

  -- C2 on the feature branch
  run_git("checkout -q -b feature")
  write_file("feature.txt", "branch line\n")
  run_git("add .")
  run_git("commit -q -m 'C2 branch change'")

  -- C3 on main, then M1 merging feature (true merge node with two parents)
  run_git("checkout -q main")
  write_file("shared.txt", "c3 shared\n")
  run_git("add .")
  run_git("commit -q -m 'C3 main change'")
  run_git("merge -q --no-ff -m 'M1 merge feature' feature")

  -- C4 after the merge
  write_file("feature.txt", "post merge line\n")
  run_git("add .")
  run_git("commit -q -m 'C4 after merge'")

  -- Working-tree changes for the default comparison
  write_file("shared.txt", "worktree shared\n")
  write_file("untracked_new.txt", "untracked line\n")

  return dir
end

--- Byte-for-byte read-only snapshot: HEAD, index entries, status bytes, and
--- the full parent-annotated commit list of the inspected repository.
local function snapshot_repo_state(dir)
  local function git_capture(args)
    local cmd = { "git", "-C", dir }
    for _, a in ipairs(args) do
      table.insert(cmd, a)
    end
    local res = vim.system(cmd, { text = true }):wait()
    return res.stdout or ""
  end

  return table.concat({
    git_capture({ "rev-parse", "HEAD" }),
    git_capture({ "ls-files", "-s" }),
    git_capture({ "status", "--porcelain=v1", "-z", "-uall" }),
    git_capture({ "log", "--format=%H %P" }),
  }, "\30")
end

function tests.test_source_control_layout_graph_selection_and_readonly_invariance()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_merge_history_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local before_state = snapshot_repo_state(fixture)

  workbench.open({ view = "diff" })
  local st = workbench.get_state()

  -- Horizontal Source Control layout: changes above, history below, one column
  assert_true(st.win_history ~= nil and vim.api.nvim_win_is_valid(st.win_history),
    "Diff view must create a valid history pane")
  assert_true(st.buf_history ~= nil and vim.api.nvim_buf_is_valid(st.buf_history),
    "Diff view must create a valid history buffer")
  local pos_left = vim.fn.win_screenpos(st.win_left)
  local pos_hist = vim.fn.win_screenpos(st.win_history)
  assert_true(pos_hist[1] > pos_left[1], "history pane must sit below the changes pane")
  assert_eq(pos_hist[2], pos_left[2], "history pane must share the left Git column")
  assert_eq(vim.api.nvim_win_get_width(st.win_history), vim.api.nvim_win_get_width(st.win_left),
    "history pane must match the left column width")
  assert_true(vim.api.nvim_win_get_height(st.win_history) >= 5
    and vim.api.nvim_win_get_height(st.win_left) >= 5,
    "both left-column panes must keep a usable height")
  assert_true(st.win_middle ~= nil and vim.api.nvim_win_is_valid(st.win_middle)
    and vim.fn.win_screenpos(st.win_middle)[1] == pos_left[1],
    "old/new comparison panes must remain beside the Source Control column")
  assert_true(st.git_file_count >= 2, "changes pane must still list current changes")

  -- Full reachable ancestry: merge node present, not a first-parent list
  assert_eq(st.history_count, 5, "history must include every reachable commit")
  local merge
  for _, c in ipairs(st.history_commits) do
    if #c.parents == 2 then merge = c end
  end
  assert_true(merge ~= nil and merge.subject == "M1 merge feature",
    "history must contain the merge node with two parents")

  local hist_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
  assert_true(hist_text:find("HEAD -> main", 1, true) ~= nil,
    "history rows must render branch decorations")
  assert_true(hist_text:find("(feature)", 1, true) ~= nil,
    "history rows must render the feature branch decoration")
  assert_true(hist_text:find("|\\", 1, true) ~= nil or hist_text:find("|/", 1, true) ~= nil,
    "history must render merge graph edges, not a first-parent list")
  assert_true(hist_text:find("M1 merge feature", 1, true) ~= nil,
    "merge commit subject must be visible")
  assert_true(hist_text:find("Compare: [Old] HEAD -> [New] Worktree", 1, true) ~= nil,
    "compare status must document the default endpoint direction")

  -- Deterministic keyboard selection without checkout
  assert_eq(st.selected_history_index, 0, "fresh history must start unselected")
  local down_cb = buffer_map_callback(st.buf_history, "<Down>")
  local up_cb = buffer_map_callback(st.buf_history, "<Up>")
  assert_true(down_cb ~= nil and up_cb ~= nil, "history pane must map Up/Down selection")
  down_cb()
  st = workbench.get_state()
  assert_eq(st.selected_history_index, 1, "Down must select the first history row")
  local selected_commit = st.history_commits[1]
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
    :find("Selected: " .. selected_commit.hash:sub(1, 7), 1, true) ~= nil,
    "selection line must visibly identify the selected commit")
  down_cb()
  st = workbench.get_state()
  assert_eq(st.selected_history_index, 2, "Down must move the selection to the next row")
  up_cb()
  st = workbench.get_state()
  assert_eq(st.selected_history_index, 1, "Up must move the selection back")

  -- Exactly one visible selection marker on the selected row
  local marker_rows = {}
  for i, l in ipairs(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false)) do
    if l:find("▶", 1, true) then
      table.insert(marker_rows, i)
    end
  end
  assert_eq(#marker_rows, 1, "exactly one history row must show the selection marker")
  assert_eq(marker_rows[1], st.history_header_line_count + 1,
    "the marker must sit on the selected history row")

  -- Cursor-movement selection inside the history pane mirrors the changes list
  local commit3_line
  for line_no, idx in pairs(st.line_to_history_index) do
    if idx == 3 then commit3_line = line_no end
  end
  assert_true(commit3_line ~= nil, "the third commit row must be visible")
  vim.api.nvim_set_current_win(st.win_history)
  vim.api.nvim_win_set_cursor(st.win_history, { commit3_line, 1 })
  vim.cmd("doautocmd CursorMoved")
  st = workbench.get_state()
  assert_eq(st.selected_history_index, 3, "cursor movement must select the row under the cursor")

  -- Mouse hit-testing covers exactly the commit rows, whatever the graph edges
  local mapped_rows = 0
  for _, idx in pairs(st.line_to_history_index) do
    mapped_rows = mapped_rows + 1
    assert_true(idx >= 1 and idx <= st.history_count,
      "mapped row must reference a valid commit index")
  end
  assert_eq(mapped_rows, st.history_count, "every commit row must be mouse-selectable")

  workbench.close()

  -- Selection and rendering must be byte-for-byte read-only for the repository
  assert_eq(snapshot_repo_state(fixture), before_state,
    "Source Control interactions must leave HEAD, index, status, and history untouched")

  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_two_endpoint_comparison_direction_default_and_refresh()
  local workbench = require("novim.workbench")
  local git = require("novim.git")
  workbench.close()
  reset_saved_layout()

  local fixture = create_merge_history_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "diff" })
  local st = workbench.get_state()

  -- Fresh entry defaults to working tree versus HEAD
  assert_eq(st.compare.old.ref, "HEAD", "default old endpoint must be HEAD")
  assert_eq(st.compare.new.ref, git.WORKTREE_REF, "default new endpoint must be the working tree")

  local function file_index(path)
    for i, f in ipairs(st.files) do
      if f.path == path then return i end
    end
    return nil
  end

  local function commit_index(subject)
    for i, c in ipairs(st.history_commits) do
      if c.subject == subject then return i, c end
    end
    return nil
  end

  local function pane_text(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  end

  workbench.select_file(file_index("shared.txt"))
  local old_text = pane_text(st.buf_middle)
  local new_text = pane_text(st.buf_right)
  assert_true(old_text:find("c3 shared", 1, true) ~= nil, "default old pane must show HEAD content")
  assert_true(new_text:find("worktree shared", 1, true) ~= nil,
    "default new pane must show working-tree content")
  assert_true(old_text:find("worktree shared", 1, true) == nil,
    "default old pane must not show working-tree-only content")

  -- Existing untracked-file handling stays intact under the default comparison
  workbench.select_file(file_index("untracked_new.txt"))
  assert_true(pane_text(st.buf_middle):find("No file in HEAD", 1, true) ~= nil,
    "untracked file must keep the readable no-HEAD placeholder")

  -- Explicit two-endpoint selection from graph-visible revisions
  local _, c1 = commit_index("C1 base")
  local _, c3 = commit_index("C3 main change")
  workbench.select_history(commit_index("C1 base"))
  assert_true(workbench.assign_compare_endpoint("old", "history"),
    "old endpoint assignment from a history row must succeed")
  st = workbench.get_state()
  assert_eq(st.compare.old.ref, c1.hash, "old endpoint must become the selected commit")

  workbench.select_history(commit_index("C3 main change"))
  assert_true(workbench.assign_compare_endpoint("new", "history"),
    "new endpoint assignment from a history row must succeed")
  st = workbench.get_state()
  assert_eq(st.compare.new.ref, c3.hash, "new endpoint must become the selected commit")

  -- Documented direction: old pane shows the old endpoint, new pane the new
  workbench.select_file(file_index("shared.txt"))
  old_text = pane_text(st.buf_middle)
  new_text = pane_text(st.buf_right)
  assert_true(old_text:find("c1 shared", 1, true) ~= nil, "old pane must show old-endpoint content")
  assert_true(new_text:find("c3 shared", 1, true) ~= nil, "new pane must show new-endpoint content")
  assert_true(old_text:find("c3 shared", 1, true) == nil and old_text:find("worktree shared", 1, true) == nil,
    "old pane must not show newer content")
  hist_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
  assert_true(hist_text:find("[Old] " .. c1.hash:sub(1, 7), 1, true) ~= nil
    and hist_text:find("[New] " .. c3.hash:sub(1, 7), 1, true) ~= nil,
    "compare status must reflect both selected endpoints in order")

  -- Identical endpoints are rejected with a visible bounded error
  local old_before = st.compare.old.ref
  workbench.select_history(commit_index("C3 main change"))
  assert_true(not workbench.assign_compare_endpoint("old", "history"),
    "identical endpoints must be rejected")
  st = workbench.get_state()
  assert_true(st.compare.error ~= nil, "the rejection must surface a bounded error")
  assert_eq(st.compare.old.ref, old_before, "a rejected assignment must not change the old endpoint")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
    :find("! comparison endpoints must be distinct", 1, true) ~= nil,
    "the compare status line must render the bounded error")

  -- Refresh updates data and the comparison without silently moving endpoints
  local new_before = st.compare.new.ref
  vim.fn.writefile({ "worktree shared v2" }, fixture .. "/shared.txt")
  workbench.refresh()
  st = workbench.get_state()
  assert_eq(st.compare.old.ref, old_before, "refresh must not silently change the old endpoint")
  assert_eq(st.compare.new.ref, new_before, "refresh must not silently change the new endpoint")

  -- D restores the default pair
  assert_true(workbench.reset_compare(), "explicit reset must succeed")
  st = workbench.get_state()
  assert_eq(st.compare.old.ref, "HEAD", "reset must restore the HEAD old endpoint")
  assert_eq(st.compare.new.ref, git.WORKTREE_REF, "reset must restore the working-tree new endpoint")
  assert_true(pane_text(st.buf_right):find("worktree shared v2", 1, true) ~= nil,
    "refreshed working-tree content must render after reset")

  -- View switches keep chosen endpoints; a fresh entry restores the default
  workbench.select_history(commit_index("C2 branch change"))
  assert_true(workbench.assign_compare_endpoint("old", "history"), "custom old endpoint must apply")
  st = workbench.get_state()
  local custom_old = st.compare.old.ref
  workbench.set_view("files")
  workbench.set_view("diff")
  st = workbench.get_state()
  assert_eq(st.compare.old.ref, custom_old, "view switches must preserve chosen endpoints")
  assert_true(vim.api.nvim_win_is_valid(st.win_history),
    "re-entering Diff must recreate the history pane")

  workbench.close()
  workbench.open({ view = "diff" })
  st = workbench.get_state()
  assert_eq(st.compare.old.ref, "HEAD", "a fresh Source Control entry must default to HEAD")
  assert_eq(st.compare.new.ref, git.WORKTREE_REF,
    "a fresh Source Control entry must default to the working tree")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_source_control_empty_error_states()
  local workbench = require("novim.workbench")
  local git = require("novim.git")
  workbench.close()

  local old_cwd = vim.fn.getcwd()

  -- (a) Repository without commits
  local empty_dir = vim.fn.tempname() .. "_empty_repo_fixture"
  vim.fn.mkdir(empty_dir, "p")
  vim.fn.system("git -C " .. vim.fn.shellescape(empty_dir) .. " init -q -b main")
  vim.cmd("cd " .. vim.fn.fnameescape(empty_dir))

  workbench.open({ view = "diff" })
  local st = workbench.get_state()
  assert_eq(st.history_count, 0, "an empty repository must have no history entries")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
    :find("No commits yet", 1, true) ~= nil,
    "an empty repository must render a readable no-commits state")

  -- Endpoint assignment without a selectable history row stays bounded
  assert_true(not workbench.assign_compare_endpoint("old", "history"),
    "endpoint assignment without a history row must be rejected")
  st = workbench.get_state()
  assert_true(st.compare.error ~= nil, "the rejection must surface a visible error")
  assert_eq(st.compare.old.ref, "HEAD", "a rejected assignment must not change the old endpoint")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
    :find("! select a history row first", 1, true) ~= nil,
    "the compare status line must render the selection error")
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(empty_dir)

  -- (b) Non-Git directory keeps every pane valid and readable
  local plain_dir = vim.fn.tempname() .. "_plain_dir_fixture"
  vim.fn.mkdir(plain_dir, "p")
  vim.cmd("cd " .. vim.fn.fnameescape(plain_dir))
  workbench.open({ view = "diff" })
  st = workbench.get_state()
  assert_eq(st.history_count, 0, "a non-Git directory must have no history")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
    :find("Not a Git repository", 1, true) ~= nil,
    "a non-Git directory must render a readable history state")
  assert_true(vim.api.nvim_win_is_valid(st.win_history)
    and vim.api.nvim_win_is_valid(st.win_middle) and vim.api.nvim_win_is_valid(st.win_right),
    "all Diff panes must remain valid outside a repository")
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(plain_dir)

  local fixture = create_merge_history_fixture()

  -- (c) Unavailable revision content resolves to a bounded error, never a throw
  local content, _, read_err = git.read_revision_content(string.rep("0", 40), "feature.txt", fixture)
  assert_true(content == nil and read_err ~= nil,
    "an unavailable revision must return a readable error instead of raising")
  assert_eq(git.resolve_revision(string.rep("9", 40), fixture), nil,
    "an unresolvable revision must resolve to nil")

  -- (d) Binary content at selected endpoints stays a readable placeholder
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  workbench.open({ view = "diff" })
  st = workbench.get_state()
  local f = io.open(fixture .. "/binary.bin", "ab")
  f:write("x")
  f:close()
  workbench.refresh()
  st = workbench.get_state()
  local bin_idx
  for i, file in ipairs(st.files) do
    if file.path == "binary.bin" then bin_idx = i end
  end
  assert_true(bin_idx ~= nil, "modified binary file must be listed in the changes pane")
  workbench.select_file(bin_idx)
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_middle, 0, -1, false), "\n")
    :find("Binary file", 1, true) ~= nil,
    "binary HEAD content must stay a readable placeholder")

  local c1_idx
  for i, c in ipairs(st.history_commits) do
    if c.subject == "C1 base" then c1_idx = i end
  end
  workbench.select_history(c1_idx)
  assert_true(workbench.assign_compare_endpoint("old", "history"),
    "assigning a commit endpoint for binary content must succeed")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_middle, 0, -1, false), "\n")
    :find("Binary file", 1, true) ~= nil,
    "binary content at a commit endpoint must stay a readable placeholder")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- TASK-013: file-level stage/unstage and local staged commit
-- =========================================================================

--- Byte-exact stdout of one git subcommand run against the fixture.
local function git_bytes(dir, args)
  local cmd = { "git", "-C", dir }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then
    error("git -C " .. tostring(dir) .. " " .. table.concat(args, " ")
      .. " failed: " .. tostring(res.stderr))
  end
  return res.stdout or ""
end

--- Byte-for-byte worktree snapshot: every file outside .git with its exact
--- contents. Stage/unstage/commit must never change any of these bytes.
local function snapshot_worktree_bytes(dir)
  local chunks = {}
  local function walk(path, rel)
    for name, kind in vim.fs.dir(path) do
      if name ~= ".git" then
        local child = path .. "/" .. name
        local child_rel = (rel == "") and name or (rel .. "/" .. name)
        if kind == "directory" then
          walk(child, child_rel)
        else
          local f = io.open(child, "rb")
          local content = f and f:read("*a") or ""
          if f then f:close() end
          table.insert(chunks, child_rel .. "\0" .. content)
        end
      end
    end
  end
  walk(dir, "")
  table.sort(chunks)
  return table.concat(chunks, "\30")
end

--- Parse porcelain v1 -z status into a path -> raw-code map. Rename/copy
--- entries consume the following NUL chunk as the original path and are
--- recorded as "code|orig" so byte-level comparisons stay exact.
local function status_map(dir)
  local raw = git_bytes(dir, { "status", "--porcelain=v1", "-z", "-uall" })
  local map = {}
  local chunks = vim.split(raw, "\0", { plain = true })
  local i = 1
  while i <= #chunks do
    local chunk = chunks[i]
    if chunk == "" then break end
    if #chunk >= 3 then
      local code = chunk:sub(1, 2)
      local path = chunk:sub(4)
      if code:find("[RC]", 1) then
        i = i + 1
        map[path] = code .. "|" .. tostring(chunks[i])
      else
        map[path] = code
      end
    end
    i = i + 1
  end
  return map
end

local function index_entries(dir)
  return git_bytes(dir, { "ls-files", "-s" })
end

local function head_hash(dir)
  return (git_bytes(dir, { "rev-parse", "HEAD" }):gsub("%s+$", ""))
end

--- Exact worktree bytes of one fixture file.
local function read_worktree_file(dir, path)
  local f = io.open(dir .. "/" .. path, "rb")
  assert_true(f ~= nil, "fixture file must exist: " .. path)
  local content = f:read("*a")
  f:close()
  return content
end

local function log_count(dir)
  local n = 0
  for _, l in ipairs(vim.split(git_bytes(dir, { "log", "--format=%H %P %s" }), "\n", { plain = true })) do
    if l ~= "" then n = n + 1 end
  end
  return n
end

local function find_file_index(files, path)
  for i, f in ipairs(files) do
    if f.path == path then return i end
  end
  return nil
end

--- Raw byte-exact porcelain status output for round-trip comparisons.
local function status_bytes(dir)
  return git_bytes(dir, { "status", "--porcelain=v1", "-z", "-uall" })
end


--- Visible text of a floating window's title. nvim_win_get_config returns
--- the title as extmark chunks, so the bytes are re-joined here.
local function window_title_text(win)
  local t = vim.api.nvim_win_get_config(win).title
  if type(t) == "string" then return t end
  if type(t) == "table" then
    local parts = {}
    for _, chunk in ipairs(t) do
      table.insert(parts, type(chunk) == "table" and tostring(chunk[1]) or tostring(chunk))
    end
    return table.concat(parts)
  end
  return ""
end

function tests.test_stage_unstage_file_level_mutations_and_invariance()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Byte/state baseline before any mutation
  local before_status = status_map(fixture)
  local before_status_bytes = status_bytes(fixture)
  local before_index = index_entries(fixture)
  local before_head = head_hash(fixture)
  local before_tree = snapshot_worktree_bytes(fixture)

  workbench.open({ view = "diff" })
  local st = workbench.get_state()
  assert_true(st.is_git, "fixture must be a git repository")

  local mod_idx = find_file_index(st.files, "tracked_modified.txt")
  assert_true(mod_idx ~= nil, "fixture must list the modified tracked file")
  assert_eq(st.files[mod_idx].raw_status, " M", "fixture modification must start unstaged")

  -- Keyboard affordance: 'a' stages exactly the selected entry
  local stage_cb = buffer_map_callback(st.buf_left, "a")
  local unstage_cb = buffer_map_callback(st.buf_left, "u")
  assert_true(stage_cb ~= nil and unstage_cb ~= nil, "changes pane must map a/u stage and unstage")
  workbench.select_file(mod_idx)
  assert_true(stage_cb(), "'a' must stage the selected change")
  st = workbench.get_state()

  -- Rendered state: staged tag, staged count, preserved selection context
  local staged_idx = find_file_index(st.files, "tracked_modified.txt")
  assert_true(staged_idx ~= nil and st.files[staged_idx].is_staged, "staged state must render after 'a'")
  assert_eq(st.selected_index, staged_idx, "staging must preserve the user's selection context")
  assert_true(st.write_notice ~= nil and st.write_notice.level == "ok"
    and st.write_notice.text:find("Staged: tracked_modified%.txt") ~= nil,
    "a successful stage must surface a bounded ok notice")
  local left_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_left, 0, -1, false), "\n")
  assert_true(left_text:find("[M+]", 1, true) ~= nil, "changes rows must render the staged '+' tag")
  assert_true(left_text:find("staged: ", 1, true) ~= nil, "summary must show the staged count")

  -- Repository effect: only this entry moved into the index
  local after_stage_status = status_map(fixture)
  assert_eq(after_stage_status["tracked_modified.txt"], "M ",
    "staging must record the path in the index")
  for path, code in pairs(before_status) do
    if path ~= "tracked_modified.txt" then
      assert_eq(after_stage_status[path], code, "no other entry may change when staging: " .. path)
    end
  end
  -- Staged blob must now be the exact worktree bytes; every other index
  -- entry keeps its pre-stage bytes.
  assert_eq(git_bytes(fixture, { "show", ":tracked_modified.txt" }),
    read_worktree_file(fixture, "tracked_modified.txt"),
    "the staged blob must equal the worktree bytes")
  local function index_lines_without(text, path)
    local kept = {}
    for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
      if l ~= "" and not l:find(path, 1, true) then
        table.insert(kept, l)
      end
    end
    return table.concat(kept, "\n")
  end
  assert_eq(index_lines_without(index_entries(fixture), "tracked_modified.txt"),
    index_lines_without(before_index, "tracked_modified.txt"),
    "no other index entry may change when staging")
  assert_eq(head_hash(fixture), before_head, "staging must not create or move commits")
  assert_eq(snapshot_worktree_bytes(fixture), before_tree, "staging must never touch worktree bytes")

  -- Keyboard affordance: 'u' unstages and restores the exact prior state
  workbench.select_file(staged_idx)
  assert_true(unstage_cb(), "'u' must unstage the selected change")
  st = workbench.get_state()
  assert_true(st.write_notice ~= nil and st.write_notice.level == "ok"
    and st.write_notice.text:find("Unstaged") ~= nil, "unstage must surface an ok notice")
  local unstaged_idx = find_file_index(st.files, "tracked_modified.txt")
  assert_true(unstaged_idx ~= nil and not st.files[unstaged_idx].is_staged,
    "unstaged state must render after 'u'")
  assert_eq(status_bytes(fixture), before_status_bytes, "unstage must restore the exact porcelain state")
  assert_eq(index_entries(fixture), before_index, "unstage must restore the exact index bytes")
  assert_eq(head_hash(fixture), before_head, "unstage must not create or move commits")
  assert_eq(snapshot_worktree_bytes(fixture), before_tree, "unstage must never touch worktree bytes")

  -- Mouse affordance: double-click hit-testing covers every change row and
  -- toggles exactly the clicked entry
  st = workbench.get_state()
  local mapped_rows = 0
  for _, idx in pairs(st.line_to_file_index) do
    mapped_rows = mapped_rows + 1
    assert_true(idx >= 1 and idx <= st.git_file_count, "mapped change row must be valid")
  end
  assert_eq(mapped_rows, st.git_file_count, "every change row must be mouse-toggleable")
  local toggle_idx = find_file_index(st.files, "tracked_modified.txt")
  assert_true(workbench.toggle_stage_for_index(toggle_idx), "mouse toggle must stage an unstaged entry")
  st = workbench.get_state()
  assert_true(st.files[find_file_index(st.files, "tracked_modified.txt")].is_staged,
    "mouse toggle must leave the entry staged")
  assert_true(buffer_map_callback(st.buf_left, "<2-LeftMouse>") ~= nil,
    "double-click must be mapped as the mouse toggle affordance")
  assert_true(workbench.toggle_stage_for_index(toggle_idx), "mouse toggle must unstage a staged entry")
  assert_eq(status_bytes(fixture), before_status_bytes, "toggles must round-trip the repository state")

  workbench.close()
  assert_eq(workbench.get_state().write_notice, nil, "closing the workbench must discard the notice")
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_stage_unstage_special_paths_untracked_deleted_renamed()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_fixture_repo()
  -- Additional adversarial untracked names: option-like and spaced paths
  local dash = io.open(fixture .. "/-dash-prefixed.txt", "wb")
  dash:write("dash\n")
  dash:close()
  local spaced = io.open(fixture .. "/spaced name.txt", "wb")
  spaced:write("spaced\n")
  spaced:close()

  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local before_status_bytes = status_bytes(fixture)
  local before_head = head_hash(fixture)
  local before_tree = snapshot_worktree_bytes(fixture)

  workbench.open({ view = "diff" })
  local st = workbench.get_state()

  -- Untracked entries with spaces, quotes, tabs, unicode, option-like and
  -- arrow-bearing names: every one stages as its own entry and round-trips.
  local special_paths = {
    "untracked_new.txt",
    "spaced name.txt",
    'quote"name.txt',
    "tab\tname.txt",
    "unicode_ğüşıöç.txt",
    "-dash-prefixed.txt",
    "arrow -> name.txt",
  }
  for _, path in ipairs(special_paths) do
    st = workbench.get_state()
    local idx = find_file_index(st.files, path)
    assert_true(idx ~= nil and st.files[idx].is_untracked,
      "fixture must list the untracked path: " .. path)
    assert_true(workbench.stage_selected_file(st.files[idx]),
      "staging must succeed for: " .. path)
    assert_eq(status_map(fixture)[path], "A ", "staged entry must be added: " .. path)
    assert_true(workbench.unstage_selected_file(st.files[idx]),
      "unstaging must succeed for: " .. path)
    assert_eq(status_map(fixture)[path], "??", "unstaged entry must return to untracked: " .. path)
    assert_eq(status_bytes(fixture), before_status_bytes,
      "unstage must round-trip the exact porcelain bytes: " .. path)
  end

  -- Deleted tracked file: staging records the deletion in the index,
  -- unstaging restores the index entry without recreating worktree bytes.
  local del_before_bytes = status_bytes(fixture)
  st = workbench.get_state()
  local del_idx = find_file_index(st.files, "tracked_deleted.txt")
  assert_true(del_idx ~= nil and st.files[del_idx].is_deleted and not st.files[del_idx].is_staged,
    "fixture must list the unstaged deletion")
  assert_true(workbench.stage_selected_file(st.files[del_idx]), "staging a deletion must succeed")
  assert_eq(status_map(fixture)["tracked_deleted.txt"], "D ",
    "staged deletion must be recorded in the index")
  assert_true(index_entries(fixture):find("tracked_deleted.txt", 1, true) == nil,
    "staged deletion must remove the path from the index")
  assert_true(workbench.unstage_selected_file(st.files[del_idx]),
    "unstaging a deletion must succeed")
  assert_eq(status_bytes(fixture), del_before_bytes,
    "deletion round-trip must restore the exact porcelain bytes")
  assert_true(index_entries(fixture):find("tracked_deleted.txt", 1, true) ~= nil,
    "unstaging must restore the index entry for the deleted file")

  -- Renamed entry: unstaging splits the one logical change into its two
  -- paths (old deleted, new untracked); restaging both halves re-forms the
  -- exact staged rename.
  local rename_before_bytes = status_bytes(fixture)
  st = workbench.get_state()
  local re_idx = find_file_index(st.files, "renamed -> destination.txt")
  assert_true(re_idx ~= nil and st.files[re_idx].status == "R"
    and st.files[re_idx].orig_path == "base_rename.txt",
    "fixture must list the staged rename with its original path")
  assert_true(workbench.unstage_selected_file(st.files[re_idx]),
    "unstaging a rename must succeed")
  assert_eq(status_map(fixture)["base_rename.txt"], " D",
    "unstage must return the old rename path to a worktree deletion")
  assert_eq(status_map(fixture)["renamed -> destination.txt"], "??",
    "unstage must return the new rename path to untracked")

  st = workbench.get_state()
  local old_idx = find_file_index(st.files, "base_rename.txt")
  assert_true(old_idx ~= nil and st.files[old_idx].is_deleted,
    "the old rename path must appear as its own deletion entry")
  assert_true(workbench.stage_selected_file(st.files[old_idx]),
    "staging the old rename path must succeed")
  assert_eq(status_map(fixture)["base_rename.txt"], "D ",
    "staged old path must be a staged deletion")
  st = workbench.get_state()
  local new_idx = find_file_index(st.files, "renamed -> destination.txt")
  assert_true(new_idx ~= nil and st.files[new_idx].is_untracked,
    "the new rename path must appear as its own untracked entry")
  assert_true(workbench.stage_selected_file(st.files[new_idx]),
    "staging the new rename path must succeed")
  assert_eq(status_bytes(fixture), rename_before_bytes,
    "restaging both halves must re-form the exact staged rename")

  assert_eq(head_hash(fixture), before_head, "no commit may be created by stage/unstage actions")
  assert_eq(snapshot_worktree_bytes(fixture), before_tree, "worktree bytes must never change")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_commit_message_validation_cancel_and_local_commit()
  local workbench = require("novim.workbench")
  local git = require("novim.git")
  workbench.close()
  reset_saved_layout()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local before_head = head_hash(fixture)
  local before_tree = snapshot_worktree_bytes(fixture)
  local before_log_count = log_count(fixture)

  workbench.open({ view = "diff" })
  local st = workbench.get_state()

  -- Stage one entry through the keyboard affordance
  local mod_idx = find_file_index(st.files, "tracked_modified.txt")
  workbench.select_file(mod_idx)
  local stage_cb = buffer_map_callback(st.buf_left, "a")
  assert_true(stage_cb(), "'a' must stage the selected change")
  st = workbench.get_state()
  local index_with_staged = index_entries(fixture)

  -- Open the commit-message input through 'c'
  local commit_cb = buffer_map_callback(st.buf_left, "c")
  assert_true(commit_cb ~= nil, "changes pane must map 'c' to the commit input")
  assert_true(commit_cb(), "'c' must open the commit-message input")
  st = workbench.get_state()
  assert_true(st.commit_input.open, "commit input must be open")
  assert_eq(vim.api.nvim_get_current_win(), st.commit_input.win,
    "commit input must take bounded focus")

  local confirm_cb = buffer_map_callback(st.commit_input.buf, "<CR>")
  local cancel_cb = buffer_map_callback(st.commit_input.buf, "<Esc>")
  assert_true(confirm_cb ~= nil and cancel_cb ~= nil, "commit input must map Enter and Esc")

  -- Blank message: visible rejection, no mutation, input stays open
  vim.api.nvim_buf_set_lines(st.commit_input.buf, 0, -1, false, { "" })
  assert_true(not confirm_cb(), "blank confirm must be rejected")
  st = workbench.get_state()
  assert_true(st.commit_input.open, "blank message must keep the input open")
  assert_true(st.commit_input.error ~= nil, "blank rejection must surface a visible error")
  local title = window_title_text(st.commit_input.win)
  assert_true(title:find("cannot be empty", 1, true) ~= nil,
    "the rejection must be visible in the input title")
  assert_eq(head_hash(fixture), before_head, "blank confirm must not create a commit")

  -- Whitespace-only message: same visible rejection
  vim.api.nvim_buf_set_lines(st.commit_input.buf, 0, -1, false, { "   \t " })
  assert_true(not confirm_cb(), "whitespace-only confirm must be rejected")
  st = workbench.get_state()
  assert_true(st.commit_input.open and st.commit_input.error ~= nil,
    "whitespace-only rejection must stay visible")
  assert_eq(head_hash(fixture), before_head, "whitespace confirm must not create a commit")

  -- Cancel path: Esc closes with no Git mutation; staged state unchanged
  assert_true(cancel_cb(), "Esc must cancel the input")
  st = workbench.get_state()
  assert_true(not st.commit_input.open, "cancel must close the input")
  assert_eq(st.commit_input.buf, nil,
    "the transient input buffer must be discarded on close")
  assert_eq(head_hash(fixture), before_head, "cancel must not create a commit")
  assert_eq(index_entries(fixture), index_with_staged,
    "cancel must leave the staged index untouched")

  -- Successful commit from the staged index
  assert_true(commit_cb(), "commit input must reopen")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.commit_input.buf, 0, -1, false,
    { "fixture commit from TASK-013" })
  assert_true(confirm_cb(), "a valid message must commit")
  st = workbench.get_state()
  assert_true(not st.commit_input.open, "successful commit must close the input")

  -- Exactly one new local commit with the entered message and correct parent
  assert_true(head_hash(fixture) ~= before_head, "commit must advance HEAD")
  local log_lines = vim.split(git_bytes(fixture, { "log", "--format=%H %P %s" }), "\n", { plain = true })
  local hash, parent, subject = log_lines[1]:match("^(%x+) (%x+) (.*)$")
  assert_true(hash ~= nil, "the new log line must parse")
  assert_eq(parent, before_head, "the new commit's parent must be the previous HEAD")
  assert_eq(subject, "fixture commit from TASK-013", "the entered message must be the commit subject")
  assert_eq(log_count(fixture), before_log_count + 1, "exactly one commit must be added")

  -- Staged index became the commit: staged column empty afterwards, the
  -- committed blob holds the staged bytes, unstaged/untracked state remains.
  local after_status = status_map(fixture)
  for path, code in pairs(after_status) do
    local index_char = code:sub(1, 1)
    assert_true(index_char == " " or index_char == "?",
      "the staged index must be empty after commit: " .. path .. " -> " .. code)
  end
  assert_eq(git_bytes(fixture, { "show", "HEAD:tracked_modified.txt" }),
    read_worktree_file(fixture, "tracked_modified.txt"),
    "the commit must record the staged content bytes")
  assert_eq(after_status["tracked_deleted.txt"], " D", "unstaged deletions must remain unstaged")
  assert_eq(after_status["untracked_new.txt"], "??", "untracked files must remain untracked")
  assert_eq(snapshot_worktree_bytes(fixture), before_tree, "commit must never touch worktree bytes")
  assert_true(st.write_notice ~= nil and st.write_notice.level == "ok"
    and st.write_notice.text:find(hash:sub(1, 7), 1, true) ~= nil,
    "the success notice must carry the actual commit hash")

  -- History refreshed with the new commit; comparison stays the default
  -- read-only pair and every pane remains usable.
  assert_eq(st.history_commits[1].hash, hash, "history must list the new commit first")
  local hist_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
  assert_true(hist_text:find("fixture commit from TASK-013", 1, true) ~= nil,
    "history graph must render the new commit subject")
  assert_eq(st.compare.old.ref, "HEAD", "commit must keep the default old endpoint")
  assert_eq(st.compare.new.ref, git.WORKTREE_REF, "commit must keep the default new endpoint")
  assert_true(vim.api.nvim_win_is_valid(st.win_left) and vim.api.nvim_win_is_valid(st.win_history)
    and vim.api.nvim_win_is_valid(st.win_middle) and vim.api.nvim_win_is_valid(st.win_right),
    "all Source Control panes must remain valid after the commit")
  local untracked_idx = find_file_index(st.files, "untracked_new.txt")
  workbench.select_file(untracked_idx)
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false), "\n")
    :find("untracked line 1", 1, true) ~= nil,
    "comparison panes must still render selected entries after commit")

  -- Transient state never persists: a fresh entry starts clean
  workbench.close()
  workbench.open({ view = "diff" })
  st = workbench.get_state()
  assert_eq(st.write_notice, nil, "a fresh entry must not inherit the write notice")
  assert_true(not st.commit_input.open, "a fresh entry must not reopen the commit input")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_failed_writes_bounded_and_state_consistent()
  local workbench = require("novim.workbench")
  local git = require("novim.git")
  workbench.close()
  reset_saved_layout()

  local fixture = create_fixture_repo()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  local before_head = head_hash(fixture)
  local before_status_bytes = status_bytes(fixture)

  workbench.open({ view = "diff" })
  local st = workbench.get_state()

  -- (a) Failed stage: an unknown path fails visibly and mutates nothing
  assert_true(not workbench.stage_selected_file({ path = "missing/ghost path.txt" }),
    "staging an unknown path must fail")
  st = workbench.get_state()
  assert_true(st.write_notice ~= nil and st.write_notice.level == "error"
    and st.write_notice.text:find("Stage failed", 1, true) ~= nil
    and #st.write_notice.text <= 200,
    "a failed stage must surface a bounded error notice")
  assert_eq(status_bytes(fixture), before_status_bytes, "a failed stage must not change the index")
  assert_eq(head_hash(fixture), before_head, "a failed stage must not create commits")

  -- (b) Failed unstage before the first commit: without HEAD the unstage
  -- uses git rm --cached, which refuses a path unknown to the index with a
  -- fatal pathspec error. Nothing in the repository changes.
  workbench.close()
  local unborn = vim.fn.tempname() .. "_unborn_repo_fixture"
  vim.fn.mkdir(unborn, "p")
  vim.fn.system("git -C " .. vim.fn.shellescape(unborn) .. " init -q")
  local fresh = io.open(unborn .. "/fresh.txt", "wb")
  fresh:write("fresh\n")
  fresh:close()
  vim.cmd("cd " .. vim.fn.fnameescape(unborn))
  workbench.open({ view = "diff" })
  st = workbench.get_state()
  assert_true(st.has_head == false, "the unborn fixture must have no HEAD")
  local unborn_before = status_bytes(unborn)
  assert_true(not workbench.unstage_selected_file({ path = "never-added.txt" }),
    "unstaging an unknown path without HEAD must fail")
  st = workbench.get_state()
  assert_true(st.write_notice ~= nil and st.write_notice.level == "error"
    and st.write_notice.text:find("Unstage failed", 1, true) ~= nil,
    "a failed unstage must surface a bounded error notice")
  assert_eq(status_bytes(unborn), unborn_before,
    "a failed unstage must not change the repository state")
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  workbench.open({ view = "diff" })

  -- (c) Module boundary: blank and whitespace messages are refused before
  -- Git runs and without any repository mutation.
  assert_true(not git.commit_staged("", fixture), "the empty message must be refused by the git boundary")
  assert_true(not git.commit_staged("   \t", fixture), "a whitespace message must be refused")
  assert_eq(head_hash(fixture), before_head, "refused messages must not create commits")

  -- (d) Commit with nothing staged: the full input path fails visibly,
  -- closes the input, and leaves the repository untouched.
  workbench.close()
  local clean_repo = vim.fn.tempname() .. "_clean_repo_fixture"
  vim.fn.mkdir(clean_repo, "p")
  vim.fn.system("git -C " .. vim.fn.shellescape(clean_repo) .. " init -q")
  vim.fn.system("git -C " .. vim.fn.shellescape(clean_repo) .. " config user.email 't@example.com'")
  vim.fn.system("git -C " .. vim.fn.shellescape(clean_repo) .. " config user.name 'T'")
  local only = io.open(clean_repo .. "/only.txt", "wb")
  only:write("only\n")
  only:close()
  vim.fn.system("git -C " .. vim.fn.shellescape(clean_repo) .. " add .")
  vim.fn.system("git -C " .. vim.fn.shellescape(clean_repo) .. " commit -q -m base")
  local clean_head = head_hash(clean_repo)
  vim.cmd("cd " .. vim.fn.fnameescape(clean_repo))
  workbench.open({ view = "diff" })
  assert_true(workbench.open_commit_input(), "the commit input must open in a clean repository")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.commit_input.buf, 0, -1, false, { "no staged changes here" })
  assert_true(not buffer_map_callback(st.commit_input.buf, "<CR>")(),
    "committing an empty staged index must fail")
  st = workbench.get_state()
  assert_true(not st.commit_input.open, "a failed commit must close the input")
  assert_true(st.write_notice ~= nil and st.write_notice.level == "error"
    and st.write_notice.text:find("Commit failed", 1, true) ~= nil,
    "a failed commit must surface a bounded error")
  assert_eq(head_hash(clean_repo), clean_head, "a failed commit must not create history")
  assert_true(vim.api.nvim_win_is_valid(st.win_left) and vim.api.nvim_win_is_valid(st.win_history),
    "the workbench must stay usable after a failed commit")

  -- (e) Commit failure through a local pre-commit hook: bounded error, no
  -- history entry, staged index preserved, then success after the cause is
  -- removed proves the failure was real and nothing else broke.
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  workbench.open({ view = "diff" })
  st = workbench.get_state()
  local mod_idx = find_file_index(st.files, "tracked_modified.txt")
  workbench.select_file(mod_idx)
  assert_true(workbench.stage_selected_file(), "staging must succeed before the hook failure")
  local hook_head = head_hash(fixture)
  local hook_path = fixture .. "/.git/hooks/pre-commit"
  local hook = io.open(hook_path, "wb")
  hook:write("#!/bin/sh\nexit 1\n")
  hook:close()
  vim.fn.system("chmod +x " .. vim.fn.shellescape(hook_path))
  assert_true(not workbench.commit_staged("hook refuses this commit"),
    "a commit refused by the pre-commit hook must fail")
  st = workbench.get_state()
  assert_true(st.write_notice ~= nil and st.write_notice.level == "error"
    and st.write_notice.text:find("Commit failed", 1, true) ~= nil,
    "the hook failure must surface a bounded error")
  assert_eq(head_hash(fixture), hook_head, "the refused commit must not create history")
  assert_eq(status_map(fixture)["tracked_modified.txt"], "M ",
    "the staged entry must remain staged after the failed commit")
  os.remove(hook_path)
  assert_true(workbench.commit_staged("hook removed commit succeeds"),
    "the commit must succeed once the failure cause is removed")
  st = workbench.get_state()
  assert_true(st.write_notice ~= nil and st.write_notice.level == "ok",
    "success must be reported only on success")
  assert_true(head_hash(fixture) ~= hook_head, "the restored commit must advance HEAD")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
  cleanup_dir(clean_repo)
  cleanup_dir(unborn)
end

--- Minimal deterministic repository: commits the named base files, then
--- modifies every one of them in the worktree so each starts as an
--- unstaged change row.
local function create_modified_files_repo(names)
  local dir = vim.fn.tempname() .. "_commit_refresh_repo"
  vim.fn.mkdir(dir, "p")
  local function run(cmd)
    vim.fn.system(cmd)
    assert_true(vim.v.shell_error == 0, "fixture command failed: " .. cmd)
  end
  run("git -C " .. vim.fn.shellescape(dir) .. " init -q")
  run("git -C " .. vim.fn.shellescape(dir) .. " config user.email 'test@example.com'")
  run("git -C " .. vim.fn.shellescape(dir) .. " config user.name 'Test Runner'")
  for _, name in ipairs(names) do
    local f = io.open(dir .. "/" .. name, "wb")
    f:write("base " .. name .. "\n")
    f:close()
  end
  run("git -C " .. vim.fn.shellescape(dir) .. " add .")
  run("git -C " .. vim.fn.shellescape(dir) .. " commit -q -m base")
  for _, name in ipairs(names) do
    local f = io.open(dir .. "/" .. name, "wb")
    f:write("changed " .. name .. "\n")
    f:close()
  end
  return dir
end

function tests.test_history_pane_new_endpoint_mapping_restored()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_merge_history_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "diff" })
  local st = workbench.get_state()

  -- The documented O / N endpoint pair must both exist on the history pane
  assert_true(buffer_map_callback(st.buf_history, "O") ~= nil,
    "history pane must keep the 'O' old-endpoint mapping")
  local new_cb = buffer_map_callback(st.buf_history, "N")
  assert_true(new_cb ~= nil, "history pane must keep the 'N' new-endpoint mapping")

  -- Invoking 'N' assigns the selected history entry as the new endpoint
  local target_idx, target
  for i, c in ipairs(st.history_commits) do
    if c.subject == "C1 base" then target_idx, target = i, c end
  end
  assert_true(target ~= nil, "fixture must contain the C1 base commit")
  workbench.select_history(target_idx)
  -- The mapping callback mirrors the key handler and discards its result;
  -- the assignment is proven by the resulting comparison state.
  new_cb()
  st = workbench.get_state()
  assert_eq(st.compare.new.ref, target.hash,
    "invoking 'N' must assign the selected history commit as the new endpoint")
  assert_eq(st.compare.old.ref, "HEAD", "'N' must not move the old endpoint")
  local hist_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_history, 0, -1, false), "\n")
  assert_true(hist_text:find("[New] " .. target.hash:sub(1, 7), 1, true) ~= nil,
    "the history pane must render the assigned new endpoint")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_write_notice_renders_when_changes_list_empties()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  -- One modified tracked file: committing it empties the changes list
  local fixture = create_modified_files_repo({ "only_change.txt" })
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "diff" })
  local st = workbench.get_state()
  assert_eq(#st.files, 1, "fixture must start with exactly one change")

  -- Stage and commit the final change through the real input path
  assert_true(workbench.stage_selected_file(), "staging the only change must succeed")
  assert_true(workbench.open_commit_input(), "the commit input must open")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.commit_input.buf, 0, -1, false, { "final change commit" })
  assert_true(buffer_map_callback(st.commit_input.buf, "<CR>")(), "the commit must succeed")
  st = workbench.get_state()

  -- The commit consumed the last change: the clean-working-tree state must
  -- still render the bounded success notice in the left buffer.
  assert_eq(#st.files, 0, "the commit must leave no changed rows")
  local commit_hash = head_hash(fixture)
  local left_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_left, 0, -1, false), "\n")
  assert_true(left_text:find("Working tree clean", 1, true) ~= nil,
    "the clean-working-tree state must render after the final commit")
  assert_true(left_text:find("✓ Committed: " .. commit_hash:sub(1, 7), 1, true) ~= nil,
    "the success notice must stay visible in the clean state")
  assert_true(st.write_notice ~= nil and st.write_notice.level == "ok",
    "the success notice state must survive the refresh")

  -- A follow-up commit from the now-empty staged index must fail visibly
  -- in the same clean state, with no change rows to attach the error to.
  assert_true(workbench.open_commit_input(), "the commit input must open again")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.commit_input.buf, 0, -1, false, { "nothing staged" })
  assert_true(not buffer_map_callback(st.commit_input.buf, "<CR>")(),
    "a commit from an empty staged index must fail")
  st = workbench.get_state()
  assert_true(not st.commit_input.open, "the failed commit must close the input")
  assert_eq(head_hash(fixture), commit_hash, "the failed commit must not create history")
  left_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_left, 0, -1, false), "\n")
  assert_true(left_text:find("! Commit failed", 1, true) ~= nil,
    "the failed-commit error must be visible in the clean state")
  assert_true(left_text:find("Working tree clean", 1, true) ~= nil,
    "the clean state must render alongside the error notice")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_commit_refresh_preserves_selected_change_path()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  -- Three modified files; the alphabetically earlier one is staged and
  -- committed while the user's selection sits on a still-changed later row.
  local fixture = create_modified_files_repo({ "a_first.txt", "c_selected.txt", "d_last.txt" })
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  local before_head = head_hash(fixture)

  workbench.open({ view = "diff" })
  local st = workbench.get_state()
  local a_idx = find_file_index(st.files, "a_first.txt")
  assert_true(a_idx ~= nil, "fixture must list the earlier entry")
  assert_true(workbench.stage_selected_file(st.files[a_idx]),
    "staging the earlier entry must succeed")
  st = workbench.get_state()
  local c_idx = find_file_index(st.files, "c_selected.txt")
  assert_true(c_idx ~= nil and c_idx > a_idx,
    "the staged entry must precede the selected one in the changes list")
  workbench.select_file(c_idx)
  st = workbench.get_state()
  local selected_before = st.files[st.selected_index].path
  assert_eq(selected_before, "c_selected.txt", "the selection must sit on the later row")

  assert_true(workbench.commit_staged("commit the earlier staged entry"),
    "committing the staged entry must succeed")
  st = workbench.get_state()

  -- The committed row vanished, but the still-changed selected path must
  -- keep the selection and the comparison panes on the same file.
  assert_eq(#st.files, 2, "the committed entry must leave the changes list")
  local selected_after = st.files[st.selected_index] and st.files[st.selected_index].path or nil
  assert_eq(selected_after, selected_before,
    "the selected change path must survive the commit refresh")
  local left_text = table.concat(vim.api.nvim_buf_get_lines(st.buf_left, 0, -1, false), "\n")
  local marker_line = nil
  for _, l in ipairs(vim.split(left_text, "\n", { plain = true })) do
    if l:find("▶", 1, true) then marker_line = l end
  end
  assert_true(marker_line ~= nil and marker_line:find("c_selected.txt", 1, true) ~= nil,
    "the rendered selected row must remain c_selected.txt")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false), "\n")
    :find("changed c_selected.txt", 1, true) ~= nil,
    "the comparison pane must follow the preserved selection")

  -- Repository state: only the staged entry was committed
  assert_true(head_hash(fixture) ~= before_head, "the commit must advance HEAD")
  local log_first = vim.split(git_bytes(fixture, { "log", "--format=%s" }), "\n", { plain = true })[1]
  assert_eq(log_first, "commit the earlier staged entry", "the commit subject must match")
  assert_eq(status_map(fixture)["a_first.txt"], nil, "the committed path must be clean")
  assert_eq(status_map(fixture)["c_selected.txt"], " M", "the selected path must remain changed")
  assert_eq(status_map(fixture)["d_last.txt"], " M", "the other path must remain changed")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end


-- =========================================================================
-- TASK-014 Tests: mouse auto-copy and direct Preview exit
-- =========================================================================

--- Collect the lhs strings of all buffer-local mappings of a buffer in one mode.
local function editor_map_lhs(buf, mode)
  local lhs_set = {}
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    lhs_set[map.lhs] = true
  end
  return lhs_set
end

--- Fetch the buffer-local callback registered for a mapping lhs in one mode.
local function editor_map_callback(buf, mode, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    if map.lhs == lhs then
      return map.callback
    end
  end
  return nil
end

--- Stage a Visual selection with raw (noremap) keys, robust against any
--- mode or pending-input state left by earlier tests: normalize to Normal
--- with a raw Esc, drain, feed, and verify the Visual mode, retrying a
--- bounded number of times before giving up.
---@return boolean staged
local function stage_visual_selection(keys)
  for _ = 1, 3 do
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    vim.api.nvim_feedkeys("", "x", false)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "nx", false)
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
      return true
    end
  end
  return false
end

--- Find the project entry of a regular file by name in the Files view.
local function find_project_entry(st, name)
  for idx, entry in ipairs(st.project_files) do
    if not entry.is_dir and entry.name == name then
      return idx, entry
    end
  end
  return nil, nil
end

--- Open the Files workbench on a fresh fixture and open main.lua for editing.
--- Returns the workbench state, the editor buffer, and the entry.
local function open_editor_for_main_lua()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()
  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  workbench.open({ view = "files" })
  -- Drain any stale async typeahead left by earlier tests so the mode-sensitive
  -- feedkeys probes below execute against a clean input state.
  vim.api.nvim_feedkeys("", "x", false)
  local st = workbench.get_state()
  local idx, entry = find_project_entry(st, "main.lua")
  assert_true(idx ~= nil, "fixture must contain main.lua")
  workbench.select_file(idx)
  assert_true(workbench.open_file(entry), "opening a regular file must succeed")
  local edit_buf = vim.api.nvim_win_get_buf(st.win_right)
  assert_true(vim.bo[edit_buf].buftype == "", "the editor buffer must be a real file buffer")
  assert_true(vim.bo[edit_buf].modifiable, "the editor buffer must be editable")
  return workbench, fixture, old_cwd, st, edit_buf, entry
end

--- Tear one TASK-014 test down without touching the real clipboard contents.
local function task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
  workbench.close()
  if edit_buf and vim.api.nvim_buf_is_valid(edit_buf) then
    vim.api.nvim_buf_delete(edit_buf, { force = true })
  end
  vim.fn.setreg("+", saved_clipboard)
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task014_mouse_selection_autocopies_exact_clipboard_text()
  local workbench, fixture, old_cwd, st, edit_buf, entry = open_editor_for_main_lua()
  local saved_clipboard = vim.fn.getreg("+")

  assert_true(workbench.editing_file_buffer(), "the right pane must hold the editable file buffer")

  -- A completed mouse selection ends in Visual mode at <LeftRelease>; the
  -- keyboard path below only stages that Visual state without touching any
  -- mapping (noremap feedkeys), so nothing auto-copies yet.
  assert_true(stage_visual_selection("gg0ve"),
    "the visual selection must stage before the release")
  assert_eq(vim.fn.getreg("+"), saved_clipboard, "the active selection alone must not copy")

  -- The <LeftRelease> release completes the selection: copy exactly once.
  local release_cb = editor_map_callback(edit_buf, "v", "<LeftRelease>")
  assert_true(release_cb ~= nil, "<LeftRelease> must be mapped in the editor buffer (visual)")
  assert_true(release_cb(), "the completed mouse selection must auto-copy")

  assert_eq(vim.fn.getreg("+"), "print", "the clipboard must hold exactly the selected text")
  assert_eq(vim.fn.mode(), "v", "the selection must stay active and usable after the copy")
  st = workbench.get_state()
  assert_true(st.copy_notice ~= nil and st.copy_notice.level == "ok",
    "a bounded success notice must be recorded for the auto-copy")

  -- A plain click (release without a completed selection) stays side-effect free.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  assert_eq(vim.fn.mode(), "n", "the release probe must be back in Normal mode")
  local after_selection = vim.fn.getreg("+")
  local n_release_cb = editor_map_callback(edit_buf, "n", "<LeftRelease>")
  assert_true(n_release_cb ~= nil, "<LeftRelease> must be mapped in the editor buffer (normal)")
  assert_true(not n_release_cb(), "a release without a completed selection must not copy")
  assert_eq(vim.fn.getreg("+"), after_selection, "the clipboard must be untouched by a plain click")
  assert_true(workbench.get_state().copy_notice ~= nil
    and workbench.get_state().copy_notice.text:find("copied", 1, true) ~= nil,
    "a plain click must not record a new copy notice")

  -- The explicit Ctrl/Cmd copy keeps working beside the automatic copy.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("gg0v$", true, false, true), "nx", false)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"+ygv', true, false, true), "nx", false)
  assert_true(vim.fn.getreg("+"):find("hello world", 1, true) ~= nil,
    "the explicit copy must still yank the selection")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
end

function tests.test_task014_unavailable_clipboard_provider_shows_bounded_failure()
  local workbench, fixture, old_cwd, st, edit_buf, entry = open_editor_for_main_lua()
  local saved_clipboard = vim.fn.getreg("+")

  -- Simulate an unavailable local system clipboard provider.
  local original_check = workbench._clipboard_provider_available
  workbench._clipboard_provider_available = function() return false end

  assert_true(stage_visual_selection("gg0vww"),
    "the visual selection must stage before the failed release")
  local release_cb = editor_map_callback(edit_buf, "v", "<LeftRelease>")
  assert_true(release_cb ~= nil, "<LeftRelease> must be mapped in the editor buffer (visual)")
  assert_true(not release_cb(), "the auto-copy must fail visibly when the provider is unavailable")

  st = workbench.get_state()
  assert_true(st.copy_notice ~= nil and st.copy_notice.level == "error",
    "a bounded failure notice must be recorded when the provider is unavailable")
  assert_true(st.copy_notice.text:find("unavailable", 1, true) ~= nil,
    "the failure notice must be explicit about the unavailable clipboard")
  assert_eq(vim.fn.getreg("+"), saved_clipboard, "the clipboard must stay untouched on failure")
  assert_eq(vim.fn.mode(), "v", "the selection must survive the failed copy")

  workbench._clipboard_provider_available = original_check
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
end

function tests.test_task014_no_autocopy_in_readonly_panes_or_keyboard_selections()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()
  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  local saved_clipboard = vim.fn.getreg("+")

  workbench.open({ view = "files" })
  vim.api.nvim_feedkeys("", "x", false)
  local st = workbench.get_state()

  -- (a) Read-only Preview pane: no auto-copy side effect exists there.
  vim.api.nvim_set_current_win(st.win_right)
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right,
    "the right pane must show the read-only preview scratch")
  assert_true(stage_visual_selection("ggvww"), "the preview selection must be staged")
  assert_true(not workbench.copy_selection_to_clipboard(),
    "the auto-copy must refuse to run for the read-only preview")
  assert_eq(vim.fn.getreg("+"), saved_clipboard, "the preview selection must never copy")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  -- (b) Keyboard-only selection in the editor buffer gains no auto-copy.
  local idx, entry = find_project_entry(st, "main.lua")
  assert_true(idx ~= nil, "fixture must contain main.lua")
  workbench.select_file(idx)
  assert_true(workbench.open_file(entry), "opening a regular file must succeed")
  local edit_buf = vim.api.nvim_win_get_buf(st.win_right)
  assert_true(stage_visual_selection("gg0vww"), "the keyboard selection must be staged")
  assert_eq(vim.fn.getreg("+"), saved_clipboard,
    "a keyboard-only selection must not auto-copy")
  assert_true(workbench.get_state().copy_notice == nil,
    "a keyboard-only selection must not record a copy notice")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  -- (c) Read-only Diff panes: no auto-copy side effect exists there either.
  workbench.set_view("diff")
  st = workbench.get_state()
  assert_eq(st.view_mode, "diff", "the diff view must be active")
  if #st.files > 0 then
    workbench.select_file(1)
    vim.api.nvim_set_current_win(st.win_right)
    assert_true(stage_visual_selection("ggvww"), "the diff-pane selection must be staged")
    assert_true(not workbench.copy_selection_to_clipboard(),
      "the auto-copy must refuse to run for the read-only diff pane")
    assert_eq(vim.fn.getreg("+"), saved_clipboard, "the diff-pane selection must never copy")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end

  workbench.close()
  if edit_buf and vim.api.nvim_buf_is_valid(edit_buf) then
    vim.api.nvim_buf_delete(edit_buf, { force = true })
  end
  vim.fn.setreg("+", saved_clipboard)
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task014_direct_esc_from_all_editor_modes_returns_to_preview()
  local workbench, fixture, old_cwd, st, edit_buf, entry = open_editor_for_main_lua()
  local saved_clipboard = vim.fn.getreg("+")

  -- Binding structure: Esc is bound for the editable file buffer in every
  -- editor mode, and the mouse release for the auto-copy.
  for _, mode in ipairs({ "n", "i", "v" }) do
    assert_true(editor_map_lhs(edit_buf, mode)["<Esc>"],
      "Esc must be mapped in the editor buffer (" .. mode .. " mode)")
  end

  -- Normal mode: a single Esc returns directly to the same file's Preview.
  local esc_cb_n = editor_map_callback(edit_buf, "n", "<Esc>")
  assert_true(esc_cb_n(), "the unmodified Esc must return to Preview")
  st = workbench.get_state()
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right,
    "the right pane must show the Preview again")
  assert_true(not st.preview_return.open, "an unmodified buffer must not open a confirmation")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false), "\n")
    :find("# File: main.lua", 1, true) ~= nil,
    "the restored Preview must show the same file")

  -- Visual mode: Esc returns directly, without stopping in Normal mode.
  assert_true(workbench.open_file(entry), "reopening must restore the editor")
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), edit_buf, "the editor buffer must be back")
  assert_true(stage_visual_selection("gg0vww"), "the visual selection must be staged")
  local esc_cb_v = editor_map_callback(edit_buf, "v", "<Esc>")
  assert_true(esc_cb_v(), "the visual-mode Esc must return to Preview")
  st = workbench.get_state()
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right,
    "the right pane must show the Preview after the visual-mode Esc")
  assert_true(not st.preview_return.open, "the visual-mode return needs no confirmation")

  -- Insert mode: Esc returns directly, without a Normal-mode stop. The
  -- handler is the same mode-agnostic return; the i-mode binding itself is
  -- asserted above, and real Insert-mode Esc is exercised in the PTY run.
  assert_true(workbench.open_file(entry), "reopening must restore the editor again")
  local esc_cb_i = editor_map_callback(edit_buf, "i", "<Esc>")
  assert_true(esc_cb_i(), "the insert-mode Esc must return to Preview directly")
  st = workbench.get_state()
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right,
    "the right pane must show the Preview after the insert-mode Esc")
  assert_true(not st.preview_return.open, "the insert-mode return needs no confirmation")
  assert_true(not workbench.editing_file_buffer(), "the editor buffer must be hidden after the return")

  -- Outside the workbench context the handler falls back to the default Esc
  -- behavior instead of being hijacked (the buffer-local map survives).
  workbench.close()
  local esc_after_close = editor_map_callback(edit_buf, "n", "<Esc>")
  assert_true(esc_after_close ~= nil, "the buffer-local map persists on the file buffer")
  assert_true(not esc_after_close(), "outside the workbench the handler must report unhandled")

  task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
end
function tests.test_task014_modified_buffer_esc_confirms_and_preserves_content()
  local workbench, fixture, old_cwd, st, edit_buf, entry = open_editor_for_main_lua()
  local saved_clipboard = vim.fn.getreg("+")

  vim.api.nvim_buf_set_lines(edit_buf, 0, 0, false, { "-- UNSAVED EDIT" })
  assert_true(vim.bo[edit_buf].modified, "the buffer must be modified")

  local esc_cb_n = editor_map_callback(edit_buf, "n", "<Esc>")
  assert_true(esc_cb_n(), "the modified-buffer Esc must open the confirmation")
  st = workbench.get_state()
  assert_true(st.preview_return.open, "the confirmation must be open")
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), edit_buf,
    "the editor buffer must stay in the right pane while confirming")

  -- Esc cancels: keep editing with content and modified flag intact.
  local cancel_cb = editor_map_callback(st.preview_return.buf, "n", "<Esc>")
  assert_true(cancel_cb ~= nil, "the confirmation must map Esc")
  assert_true(cancel_cb(), "Esc must cancel the confirmation")
  st = workbench.get_state()
  assert_true(not st.preview_return.open, "the confirmation must be closed after Esc")
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), edit_buf, "Esc must keep the user editing")
  assert_eq(vim.api.nvim_buf_get_lines(edit_buf, 0, 1, false)[1], "-- UNSAVED EDIT",
    "the content must survive the cancellation")
  assert_true(vim.bo[edit_buf].modified, "the modified flag must survive the cancellation")

  -- 'n' also cancels.
  assert_true(esc_cb_n(), "the modified-buffer Esc must open the confirmation again")
  st = workbench.get_state()
  local n_cancel_cb = editor_map_callback(st.preview_return.buf, "n", "n")
  assert_true(n_cancel_cb ~= nil, "the confirmation must map 'n'")
  assert_true(n_cancel_cb(), "'n' must cancel the confirmation")
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), edit_buf, "'n' must keep the user editing")

  -- Enter confirms: return to the same file's Preview without saving or
  -- discarding the in-memory buffer.
  assert_true(esc_cb_n(), "the modified-buffer Esc must open the confirmation once more")
  st = workbench.get_state()
  local confirm_cb = editor_map_callback(st.preview_return.buf, "n", "<CR>")
  assert_true(confirm_cb ~= nil, "the confirmation must map Enter")
  assert_true(confirm_cb(), "Enter must confirm the return")
  st = workbench.get_state()
  assert_true(not st.preview_return.open, "the confirmation must be closed after confirming")
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right,
    "the right pane must show the Preview after confirming")
  assert_true(table.concat(vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false), "\n")
    :find("# File: main.lua", 1, true) ~= nil,
    "the restored Preview must show the same file")

  -- The edited buffer is preserved in memory, unsaved and undiscarded.
  assert_true(vim.api.nvim_buf_is_valid(edit_buf) and vim.api.nvim_buf_is_loaded(edit_buf),
    "the edited buffer must stay loaded for later recovery")
  assert_true(vim.bo[edit_buf].modified, "the edited buffer must remain modified")
  assert_eq(vim.api.nvim_buf_get_lines(edit_buf, 0, 1, false)[1], "-- UNSAVED EDIT",
    "the edited content must survive the confirmed return")
  local f = io.open(fixture .. "/main.lua", "r")
  local disk = f and f:read("*a") or ""
  if f then f:close() end
  assert_true(disk:find("UNSAVED EDIT", 1, true) == nil,
    "nothing may be auto-saved to disk")

  -- Reopening recovers the exact in-memory buffer.
  assert_true(workbench.open_file(entry), "reopening must succeed after the confirmed return")
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), edit_buf,
    "reopening must restore the same in-memory buffer")

  -- 'y' confirms as well.
  assert_true(esc_cb_n(), "the modified-buffer Esc must open the confirmation for 'y'")
  st = workbench.get_state()
  local y_confirm_cb = editor_map_callback(st.preview_return.buf, "n", "y")
  assert_true(y_confirm_cb ~= nil, "the confirmation must map 'y'")
  assert_true(y_confirm_cb(), "'y' must confirm the return")
  st = workbench.get_state()
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), st.buf_right,
    "the right pane must show the Preview after 'y'")

  task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
end

function tests.test_task014_statusline_documents_autocopy_and_esc_preview()
  local workbench, fixture, old_cwd, st, edit_buf, entry = open_editor_for_main_lua()
  local saved_clipboard = vim.fn.getreg("+")

  -- Normal-mode hints keep the established guidance and add the new one.
  local hints = _G.get_editor_hints()
  assert_true(hints:find("^V Paste", 1, true) ~= nil, "the existing paste hint must remain")
  assert_true(hints:find("Mouse Copy", 1, true) ~= nil,
    "the statusline must document the mouse auto-copy")
  assert_true(hints:find("Esc Preview", 1, true) ~= nil,
    "the statusline must document the direct Esc Preview exit")

  -- Modified-state hints keep Save/Undo and add the new guidance.
  vim.api.nvim_buf_set_lines(edit_buf, 0, 0, false, { "-- HINT EDIT" })
  hints = _G.get_editor_hints()
  assert_true(hints:find("^S Save", 1, true) ~= nil, "the existing save hint must remain")
  assert_true(hints:find("^Z Undo", 1, true) ~= nil, "the existing undo hint must remain")
  assert_true(hints:find("Mouse Copy", 1, true) ~= nil,
    "the modified-state statusline must document the mouse auto-copy")
  assert_true(hints:find("Esc Preview", 1, true) ~= nil,
    "the modified-state statusline must document the Esc Preview exit")

  -- Visual-mode hints keep Copy/Cut and add the new guidance.
  assert_true(stage_visual_selection("gg0vww"), "the visual selection must stage for hints")
  hints = _G.get_editor_hints()
  assert_true(hints:find("^C Copy", 1, true) ~= nil, "the existing copy hint must remain")
  assert_true(hints:find("^X Cut", 1, true) ~= nil, "the existing cut hint must remain")
  assert_true(hints:find("Mouse Copy", 1, true) ~= nil,
    "the visual-mode statusline must document the mouse auto-copy")
  assert_true(hints:find("Esc Preview", 1, true) ~= nil,
    "the visual-mode statusline must document the Esc Preview exit")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  -- The editor statusline template actually renders the guidance.
  assert_true(vim.wo[st.win_right].statusline:find("get_editor_hints", 1, true) ~= nil,
    "the editor window must use the dynamic editor hints statusline")
  local rendered = vim.api.nvim_eval_statusline(
    " %f%m%=%{v:lua.get_editor_hints()} ", { winid = st.win_right }).str
  assert_true(rendered:find("Mouse Copy", 1, true) ~= nil,
    "the rendered editor statusline must document the mouse auto-copy")
  assert_true(rendered:find("Esc Preview", 1, true) ~= nil,
    "the rendered editor statusline must document the Esc Preview exit")

  -- Non-editor surfaces keep the established hints without the new guidance.
  vim.api.nvim_set_current_win(st.win_left)
  hints = _G.get_editor_hints()
  assert_true(hints:find("Esc Preview", 1, true) == nil,
    "the new guidance must not leak into workbench navigation panes")
  assert_true(hints:find("Mouse Copy", 1, true) == nil,
    "the new guidance must not leak into workbench navigation panes")

  task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
end

function tests.test_task014_editor_keymap_docs_match_real_mappings()
  local keymaps = require("novim.keymaps")
  local workbench, fixture, old_cwd, st, edit_buf, entry = open_editor_for_main_lua()
  local saved_clipboard = vim.fn.getreg("+")

  for _, doc_entry in ipairs(keymaps.editor) do
    for _, key in ipairs(doc_entry.keys) do
      for _, mode in ipairs(doc_entry.modes) do
        assert_true(editor_map_lhs(edit_buf, mode)[key],
          string.format("the documented editor shortcut %s (%s mode) must be an actual mapping",
            key, mode))
      end
    end
  end

  -- The editor binding never leaks into the workbench scratch panes.
  st = workbench.get_state()
  assert_true(editor_map_lhs(st.buf_left, "n")["<Esc>"] == nil,
    "the navigation pane must keep its Esc Esc quit semantics")
  assert_true(editor_map_lhs(st.buf_left, "n")["<LeftRelease>"] ~= nil,
    "the navigation pane keeps its divider-drag release mapping")
  assert_true(editor_map_lhs(st.buf_right, "n")["<Esc>"] == nil,
    "the preview pane must not gain the editor Esc return")

  task014_teardown(workbench, fixture, old_cwd, edit_buf, saved_clipboard)
end

-- =========================================================================
-- TASK-020: Files Create, Rename, Context Menu & Buffer Preservation Tests
-- =========================================================================

local function find_entry_in_files(project_files, path)
  for idx, entry in ipairs(project_files) do
    if entry.path == path or entry.name == path then
      return entry, idx
    end
  end
  return nil, nil
end

function tests.test_task020_context_menu_shortcuts_and_actions()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- 1. Context menu on selected regular file exposes New File, New Folder, Rename
  local readme_entry, readme_idx = find_entry_in_files(st.project_files, "README.md")
  assert_true(readme_entry ~= nil, "fixture must contain README.md")
  workbench.select_file(readme_idx)

  assert_true(workbench.open_context_menu(), "open_context_menu must succeed")
  st = workbench.get_state()
  assert_true(st.context_menu.open, "context menu must be open")
  assert_eq(#st.context_menu.items, 3, "selected file must have 3 context menu items")
  assert_eq(st.context_menu.selected, 1, "default selection is item 1")

  -- Keyboard navigation: j moves down, k moves up
  local j_cb = buffer_map_callback(st.context_menu.buf, "j")
  local k_cb = buffer_map_callback(st.context_menu.buf, "k")
  j_cb()
  st = workbench.get_state()
  assert_eq(st.context_menu.selected, 2, "j must move selection to item 2")
  j_cb()
  st = workbench.get_state()
  assert_eq(st.context_menu.selected, 3, "j must move selection to item 3")
  k_cb()
  st = workbench.get_state()
  assert_eq(st.context_menu.selected, 2, "k must move selection back to item 2")

  -- Esc cancels context menu without action
  local esc_menu = buffer_map_callback(st.context_menu.buf, "<Esc>")
  assert_true(esc_menu(), "Esc must close context menu")
  st = workbench.get_state()
  assert_true(not st.context_menu.open, "context menu must be closed")

  -- 2. Context menu when no entry or root is targeted has no Rename item
  assert_true(workbench.open_context_menu(nil), "open_context_menu on root must succeed")
  st = workbench.get_state()
  assert_true(st.context_menu.open, "context menu must be open")
  assert_eq(#st.context_menu.items, 2, "root context menu must have exactly 2 items (no Rename)")
  esc_menu = buffer_map_callback(st.context_menu.buf, "<Esc>")
  esc_menu()

  -- 3. Direct shortcuts from buf_left: n, N, F2
  local n_cb = buffer_map_callback(st.buf_left, "n")
  local n_upper_cb = buffer_map_callback(st.buf_left, "N")
  local f2_cb = buffer_map_callback(st.buf_left, "<F2>")
  local m_cb = buffer_map_callback(st.buf_left, "m")
  local rclick_cb = buffer_map_callback(st.buf_left, "<RightMouse>")
  assert_true(n_cb ~= nil and n_upper_cb ~= nil and f2_cb ~= nil and m_cb ~= nil and rclick_cb ~= nil,
    "buf_left must map n, N, <F2>, m, <RightMouse>")

  -- 'n' opens new file input
  assert_true(n_cb(), "n must open new file input")
  st = workbench.get_state()
  assert_true(st.file_input.open, "file input must be open")
  assert_eq(st.file_input.mode, "new_file", "mode must be new_file")
  local esc_fi = buffer_map_callback(st.file_input.buf, "<Esc>")
  esc_fi()

  -- 'N' opens new folder input
  assert_true(n_upper_cb(), "N must open new folder input")
  st = workbench.get_state()
  assert_true(st.file_input.open, "file input must be open")
  assert_eq(st.file_input.mode, "new_folder", "mode must be new_folder")
  -- 'N' in Files view opens new folder input
  assert_true(n_upper_cb(), "N in Files view must open new folder input")
  st = workbench.get_state()
  assert_true(st.file_input.open, "file input must be open")
  assert_eq(st.file_input.mode, "new_folder", "mode must be new_folder")
  esc_fi = buffer_map_callback(st.file_input.buf, "<Esc>")
  esc_fi()

  -- 'N' in Diff view preserves Source Control new comparison endpoint assignment
  workbench.set_view("diff")
  st = workbench.get_state()
  assert_eq(st.view_mode, "diff", "view mode must be diff")
  local diff_n_cb = buffer_map_callback(st.buf_left, "N")
  assert_true(diff_n_cb ~= nil, "buf_left in diff view must have N callback")
  diff_n_cb()
  st = workbench.get_state()
  assert_true(not st.file_input.open, "N in diff view must NOT open new folder modal")
  workbench.set_view("files")
  workbench.select_file(readme_idx)
  assert_true(f2_cb(), "<F2> must open rename input")
  st = workbench.get_state()
  assert_true(st.file_input.open, "file input must be open")
  assert_eq(st.file_input.mode, "rename", "mode must be rename")
  esc_fi = buffer_map_callback(st.file_input.buf, "<Esc>")
  esc_fi()

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task020_new_file_and_folder_creation_and_preview()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- 1. Create regular file at project root
  assert_true(workbench.open_new_file_input(nil), "must open new file input at root")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "created_root.txt" })
  local cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming new file must succeed")

  -- Check file on disk
  local created_file_path = fixture .. "/created_root.txt"
  assert_true(vim.fn.filereadable(created_file_path) == 1, "created_root.txt must exist on disk")
  assert_eq(vim.fn.getfsize(created_file_path), 0, "new file must be empty (0 bytes)")

  -- Check refreshed tree and preview
  st = workbench.get_state()
  local selected = st.project_files[st.selected_project_index]
  assert_eq(selected.name, "created_root.txt", "created file must be selected in visible tree")
  local preview_lines = vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false)
  local preview_text = table.concat(preview_lines, "\n")
  assert_true(preview_text:find("# (Empty file)", 1, true) ~= nil, "preview must render empty file note")

  -- 2. Create directory at project root
  assert_true(workbench.open_new_folder_input(nil), "must open new folder input at root")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "created_dir" })
  cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming new folder must succeed")

  local created_dir_path = fixture .. "/created_dir"
  assert_true(vim.fn.isdirectory(created_dir_path) == 1, "created_dir must exist as directory on disk")

  st = workbench.get_state()
  selected = st.project_files[st.selected_project_index]
  assert_eq(selected.name, "created_dir", "created directory must be selected")
  preview_lines = vim.api.nvim_buf_get_lines(st.buf_right, 0, -1, false)
  preview_text = table.concat(preview_lines, "\n")
  assert_true(preview_text:find("#   (Empty directory)", 1, true) ~= nil, "preview must render empty directory note")

  -- 3. Create file inside selected directory
  assert_true(workbench.open_new_file_input(selected), "must open new file input targeting created_dir")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "child.lua" })
  cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming child file must succeed")
  assert_true(vim.fn.filereadable(created_dir_path .. "/child.lua") == 1, "child.lua must exist inside created_dir")

  -- 4. Create file when a regular file is selected (target must be file's parent)
  local f_entry = find_entry_in_files(st.project_files, "README.md")
  assert_true(f_entry ~= nil, "README.md must be visible")
  assert_true(workbench.open_new_file_input(f_entry), "open new file targeting README.md parent")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "sibling_at_root.md" })
  cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming sibling file must succeed")
  assert_true(vim.fn.filereadable(fixture .. "/sibling_at_root.md") == 1, "sibling file must be created in parent root")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task020_rename_file_and_directory_and_buffer_preservation()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- 1. Open main.lua for editing and add unsaved modifications
  local main_entry = find_entry_in_files(st.project_files, "main.lua")
  assert_true(main_entry ~= nil, "main.lua must exist")
  workbench.open_file(main_entry)
  st = workbench.get_state()
  local edit_buf = vim.api.nvim_win_get_buf(st.win_right)
  vim.api.nvim_buf_set_lines(edit_buf, 0, 0, false, { "UNSAVED_MODIFICATION_123" })
  assert_true(vim.bo[edit_buf].modified, "edit buffer must have modified flag set")

  -- Switch back to left navigation pane and rename main.lua -> app_runner.py
  vim.api.nvim_set_current_win(st.win_left)
  assert_true(workbench.open_rename_input(main_entry), "open rename input on main.lua")
  st = workbench.get_state()
  assert_eq(vim.api.nvim_buf_get_lines(st.file_input.buf, 0, 1, false)[1], "main.lua",
    "input must be pre-filled with current name")

  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "app_runner.py" })
  local cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming rename must succeed")

  -- Disk state: old file gone, new file present
  assert_true(vim.fn.filereadable(fixture .. "/main.lua") == 0, "main.lua must no longer exist")
  assert_true(vim.fn.filereadable(fixture .. "/app_runner.py") == 1, "app_runner.py must exist")

  -- No silent save to disk: disk file should have original content, not unsaved edits
  local on_disk = table.concat(vim.fn.readfile(fixture .. "/app_runner.py"), "\n")
  assert_true(on_disk:find("UNSAVED_MODIFICATION_123", 1, true) == nil,
    "rename must not silently save in-memory modifications to disk")

  -- Buffer migration: buffer name follows new path and unsaved changes remain intact
  local real_fixture = vim.uv.fs_realpath(fixture) or fixture
  local edit_buf_name = vim.api.nvim_buf_get_name(edit_buf)
  assert_true(edit_buf_name == fixture .. "/app_runner.py" or edit_buf_name == real_fixture .. "/app_runner.py",
    "buffer name must update to new path")
  assert_true(vim.bo[edit_buf].modified, "buffer must remain modified")
  assert_eq(vim.api.nvim_buf_get_lines(edit_buf, 0, 1, false)[1], "UNSAVED_MODIFICATION_123",
    "unsaved buffer content must remain intact")

  -- Reopening app_runner.py in workbench returns the exact same in-memory buffer
  st = workbench.get_state()
  local renamed_entry = find_entry_in_files(st.project_files, "app_runner.py")
  assert_true(renamed_entry ~= nil, "app_runner.py must appear in refreshed tree")
  workbench.open_file(renamed_entry)
  st = workbench.get_state()
  assert_eq(vim.api.nvim_win_get_buf(st.win_right), edit_buf,
    "reopening renamed file must reconnect to the unsaved in-memory buffer")

  -- 2. Rename directory and preserve nested open buffer
  vim.api.nvim_set_current_win(st.win_left)
  local docs_entry = find_entry_in_files(st.project_files, "docs")
  assert_true(docs_entry ~= nil, "docs folder must exist")
  workbench.toggle_dir_expansion(docs_entry)
  st = workbench.get_state()
  assert_true(st.expanded_dirs["docs"], "docs must be expanded")

  local guide_entry = find_entry_in_files(st.project_files, "docs/guide.md")
  assert_true(guide_entry ~= nil, "guide.md must be visible")
  workbench.open_file(guide_entry)
  st = workbench.get_state()
  local guide_buf = vim.api.nvim_win_get_buf(st.win_right)
  vim.api.nvim_buf_set_lines(guide_buf, 0, 0, false, { "DOCS_UNSAVED_CHANGE" })
  assert_true(vim.bo[guide_buf].modified, "guide_buf must have modified flag")

  -- Rename directory docs -> documentation
  vim.api.nvim_set_current_win(st.win_left)
  assert_true(workbench.open_rename_input(docs_entry), "open rename input on docs")
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "documentation" })
  cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming folder rename must succeed")

  -- Disk state
  assert_true(vim.fn.isdirectory(fixture .. "/docs") == 0, "old docs directory must be gone")
  assert_true(vim.fn.isdirectory(fixture .. "/documentation") == 1, "documentation directory must exist")
  assert_true(vim.fn.filereadable(fixture .. "/documentation/guide.md") == 1, "nested guide.md must exist in new folder")

  -- Expansion state migrated
  st = workbench.get_state()
  assert_true(st.expanded_dirs["documentation"], "renamed directory must keep expanded state")

  -- Nested open buffer path migrated
  local guide_buf_name = vim.api.nvim_buf_get_name(guide_buf)
  assert_true(guide_buf_name == fixture .. "/documentation/guide.md" or guide_buf_name == real_fixture .. "/documentation/guide.md",
    "open buffer path must follow renamed containing directory")
  assert_true(vim.bo[guide_buf].modified, "nested buffer must remain modified")
  assert_eq(vim.api.nvim_buf_get_lines(guide_buf, 0, 1, false)[1], "DOCS_UNSAVED_CHANGE",
    "nested buffer unsaved content must be intact")

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task020_input_validation_cancellation_and_error_handling()
  local workbench = require("novim.workbench")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- 1. Cancellation with Esc leaves filesystem and selection unchanged
  assert_true(workbench.open_new_file_input(nil))
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "cancelled_file.txt" })
  local esc_cb = buffer_map_callback(st.file_input.buf, "<Esc>")
  assert_true(esc_cb(), "Esc must close input")
  st = workbench.get_state()
  assert_true(not st.file_input.open, "file input must be closed")
  assert_true(vim.fn.filereadable(fixture .. "/cancelled_file.txt") == 0, "file must not be created")

  -- 2. Empty and whitespace-only names are rejected visibly, modal stays open
  assert_true(workbench.open_new_file_input(nil))
  st = workbench.get_state()
  local cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "" })
  assert_true(not cr_cb(), "empty name must be rejected")
  st = workbench.get_state()
  assert_true(st.file_input.open, "modal must stay open")
  assert_true(st.file_input.error ~= nil, "error must be set")
  local title = window_title_text(st.file_input.win)
  assert_true(title:find("cannot be empty", 1, true) ~= nil, "title must show cannot be empty")

  -- Whitespace-only name
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "   \t  " })
  assert_true(not cr_cb(), "whitespace-only name must be rejected")
  st = workbench.get_state()
  assert_true(st.file_input.open, "modal must stay open")

  -- 3. Reject '.' and '..'
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "." })
  assert_true(not cr_cb(), "'.' must be rejected")
  title = window_title_text(st.file_input.win)
  assert_true(title:find("cannot be '.' or '..'", 1, true) ~= nil, "title must show '.' rejection")

  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { ".." })
  assert_true(not cr_cb(), "'..' must be rejected")

  -- 4. Reject path separators
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "dir/file.txt" })
  assert_true(not cr_cb(), "slash must be rejected")
  title = window_title_text(st.file_input.win)
  assert_true(title:find("path separators", 1, true) ~= nil, "title must show path separators rejection")

  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "dir\\file.txt" })
  assert_true(not cr_cb(), "backslash must be rejected")

  -- 5. Reject NUL characters
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "bad\0name.txt" })
  assert_true(not cr_cb(), "NUL character must be rejected")

  -- 6. Reject collisions
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { "README.md" })
  assert_true(not cr_cb(), "collision with existing README.md must be rejected")
  title = window_title_text(st.file_input.win)
  assert_true(title:find("already exists", 1, true) ~= nil, "title must show collision error")

  esc_cb = buffer_map_callback(st.file_input.buf, "<Esc>")
  esc_cb()

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task020_fail_closed_security_boundaries()
  local workbench = require("novim.workbench")
  local browser = require("novim.browser")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- 1. Project root rename attempt is rejected
  local root_entry = { full_path = fixture, path = "", name = "fixture", is_dir = true }
  assert_true(not workbench.open_rename_input(root_entry), "root rename attempt must be refused")
  st = workbench.get_state()
  assert_true(not st.file_input.open, "file input must not open for root rename")
  assert_true(st.write_notice ~= nil and st.write_notice.level == "error", "error notice must be produced")
  assert_true(st.write_notice.text:find("Cannot rename the project root", 1, true) ~= nil,
    "error must identify project root rename refusal")

  -- 2. Symlink source rename attempt is rejected
  local symlink_file = fixture .. "/symlink_file.txt"
  vim.fn.system(string.format("ln -s %s %s", vim.fn.shellescape(fixture .. "/README.md"), vim.fn.shellescape(symlink_file)))
  local sym_entry = { full_path = symlink_file, path = "symlink_file.txt", name = "symlink_file.txt", is_dir = false }
  assert_true(not workbench.open_rename_input(sym_entry), "symlink rename must be refused")
  st = workbench.get_state()
  assert_true(st.write_notice.level == "error", "error notice must be produced for symlink")
  assert_true(st.write_notice.text:find("Symlink", 1, true) ~= nil, "error must identify symlink refusal")
  -- 3. Creation inside symlinked parent is rejected (both New File and New Folder)
  local symlink_dir = fixture .. "/symlink_dir"
  vim.fn.system(string.format("ln -s %s %s", vim.fn.shellescape(fixture .. "/src"), vim.fn.shellescape(symlink_dir)))
  local sym_dir_entry = { full_path = symlink_dir, path = "symlink_dir", name = "symlink_dir", is_dir = true }
  assert_true(not workbench.open_new_file_input(sym_dir_entry), "new file inside symlinked dir must be refused")
  st = workbench.get_state()
  assert_true(not st.file_input.open, "modal must not open for symlinked parent")
  assert_true(st.write_notice.level == "error", "error notice must be produced for symlinked parent")
  assert_true(st.write_notice.text:find("Symlink", 1, true) ~= nil, "error must identify symlink refusal")

  -- New Folder symlink preflight
  assert_true(not workbench.open_new_folder_input(sym_dir_entry), "new folder inside symlinked dir must be refused")
  st = workbench.get_state()
  assert_true(not st.file_input.open, "new folder modal must not open for symlinked parent")
  assert_true(st.write_notice.level == "error")
  assert_true(st.write_notice.text:find("Symlink", 1, true) ~= nil)

  -- 4. Reject non-regular special files at rename boundary (FIFO)
  local fifo_path = fixture .. "/test_named_pipe"
  vim.fn.system("mkfifo " .. vim.fn.shellescape(fifo_path))
  local fifo_entry = { full_path = fifo_path, path = "test_named_pipe", name = "test_named_pipe", is_dir = false }
  assert_true(not workbench.open_rename_input(fifo_entry), "special file rename must be refused in workbench")
  st = workbench.get_state()
  assert_true(not st.file_input.open, "rename modal must not open for special file")
  assert_true(st.write_notice.level == "error")
  assert_true(st.write_notice.text:find("Only regular files and directories can be renamed", 1, true) ~= nil)
  local ren_fifo_ok, ren_fifo_err = browser.rename_entry(fifo_entry, "renamed_pipe", fixture)
  assert_true(not ren_fifo_ok, "browser.rename_entry must refuse special files")
  assert_true(ren_fifo_err:find("Only regular files and directories can be renamed", 1, true) ~= nil)

  -- 5. Target outside project root fails closed
  local ok, out_err = browser.create_file("/tmp", "forbidden.txt", fixture)
  assert_true(not ok, "create_file outside root must fail")
  assert_true(out_err:find("outside project root", 1, true) ~= nil, "error must identify outside root")

  -- 6. Atomic no-overwrite verification for create_file and rename_entry
  local existing_file = fixture .. "/existing_target.txt"
  local f_ex = io.open(existing_file, "w"); f_ex:write("DO_NOT_TRUNCATE"); f_ex:close()
  local create_ok, create_err = browser.create_file(fixture, "existing_target.txt", fixture)
  assert_true(not create_ok, "create_file must fail when destination already exists")
  assert_true(create_err:find("already exists", 1, true) ~= nil)
  assert_eq(table.concat(vim.fn.readfile(existing_file), "\n"), "DO_NOT_TRUNCATE",
    "existing file must not be truncated on create collision")

  local source_file = fixture .. "/source_to_rename.txt"
  local f_src = io.open(source_file, "w"); f_src:write("SOURCE_DATA"); f_src:close()
  local ren_ex_ok, ren_ex_err = browser.rename_entry(
    { full_path = source_file, path = "source_to_rename.txt", name = "source_to_rename.txt", is_dir = false },
    "existing_target.txt", fixture
  )
  assert_true(not ren_ex_ok, "rename_entry must fail when destination already exists")
  assert_true(ren_ex_err:find("already exists", 1, true) ~= nil)
  assert_eq(table.concat(vim.fn.readfile(existing_file), "\n"), "DO_NOT_TRUNCATE",
    "destination file must not be overwritten or replaced")
  assert_eq(table.concat(vim.fn.readfile(source_file), "\n"), "SOURCE_DATA",
    "source file must remain intact after collision refusal")
  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

function tests.test_task020_dotfile_creation_and_visibility()
  local workbench = require("novim.workbench")
  local settings = require("novim.settings")
  workbench.close()
  reset_saved_layout()

  local fixture = create_project_browser_fixture()
  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  -- Ensure dotfiles are hidden initially
  if settings.get("show_dotfiles") then
    settings.toggle_dotfiles()
  end

  workbench.open({ view = "files" })
  local st = workbench.get_state()

  -- 1. Create .env_custom when show_dotfiles is false
  assert_true(workbench.open_new_file_input(nil))
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { ".env_custom" })
  local cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming dotfile creation must succeed")

  assert_true(vim.fn.filereadable(fixture .. "/.env_custom") == 1, ".env_custom must exist on disk")

  -- In visible tree, .env_custom is hidden because show_dotfiles is false
  st = workbench.get_state()
  local hidden_entry = find_entry_in_files(st.project_files, ".env_custom")
  assert_true(hidden_entry == nil, ".env_custom must be hidden when show_dotfiles is false")
  assert_true(st.selected_project_index >= 1 and st.selected_project_index <= #st.project_files,
    "selection index must remain valid and bounded")

  -- 2. Toggle show_dotfiles to reveal .env_custom
  settings.toggle_dotfiles()
  workbench.refresh()
  st = workbench.get_state()
  local revealed_entry, revealed_idx = find_entry_in_files(st.project_files, ".env_custom")
  assert_true(revealed_entry ~= nil, ".env_custom must be visible after dotfile toggle")

  -- 3. Rename .env_custom -> .env_renamed
  workbench.select_file(revealed_idx)
  assert_true(workbench.open_rename_input(revealed_entry))
  st = workbench.get_state()
  vim.api.nvim_buf_set_lines(st.file_input.buf, 0, -1, false, { ".env_renamed" })
  cr_cb = buffer_map_callback(st.file_input.buf, "<CR>")
  assert_true(cr_cb(), "confirming dotfile rename must succeed")

  assert_true(vim.fn.filereadable(fixture .. "/.env_custom") == 0, ".env_custom must no longer exist")
  assert_true(vim.fn.filereadable(fixture .. "/.env_renamed") == 1, ".env_renamed must exist on disk")
  st = workbench.get_state()
  local renamed_dot = find_entry_in_files(st.project_files, ".env_renamed")
  assert_true(renamed_dot ~= nil, ".env_renamed must be visible in tree")

  -- Restore dotfiles setting
  if settings.get("show_dotfiles") then
    settings.toggle_dotfiles()
  end

  workbench.close()
  vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
  cleanup_dir(fixture)
end

-- =========================================================================
-- Run all tests
-- =========================================================================

local total = 0
local passed = 0
local failed = 0

print("=== Running Diff Workbench & Project Browser Test Suite ===")
for name, fn in pairs(tests) do
  total = total + 1
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print(string.format("  ✓ PASS: %s", name))
  else
    failed = failed + 1
    print(string.format("  ✗ FAIL: %s", name))
    print(string.format("    %s", tostring(err)))
  end
end

print(string.format("=== Test Summary: %d total, %d passed, %d failed ===", total, passed, failed))

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
