-- novim/browser.lua - Read-Only Project File Browser
-- Part of novim custom derivative

local uv = vim.uv or vim.loop

local M = {}

local ffi_ok, ffi = pcall(require, "ffi")
if ffi_ok then
  pcall(function()
    if ffi.os == "OSX" then
      ffi.cdef[[
        int renamex_np(const char *oldpath, const char *newpath, unsigned int flags);
      ]]
    elseif ffi.os == "Linux" then
      ffi.cdef[[
        int renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags);
      ]]
    end
  end)
end

--- Internal check for platform-native atomic no-replace primitive availability
--- Exposed on M so unit tests can deterministically simulate platforms
--- where native atomic rename is unavailable.
---@return boolean available
---@return string? os_name
function M._native_rename_available()
  if not ffi_ok then
    return false, nil
  end
  if ffi.os == "OSX" or ffi.os == "Linux" then
    return true, ffi.os
  end
  return false, ffi.os
end

--- Perform platform-native atomic rename without replace
--- Exposed on M for testability and platform-boundary verification.
---@param old_path string
---@param new_path string
---@return boolean? ok true on success, false on failure, nil if unavailable
---@return string? err error message if failed
function M._native_rename_noreplace(old_path, new_path)
  local avail, os_name = M._native_rename_available()
  if not avail then
    return nil, nil
  end

  if os_name == "OSX" then
    local ok, res = pcall(ffi.C.renamex_np, old_path, new_path, 4) -- RENAME_EXCL = 4
    if ok then
      if res == 0 then
        return true, nil
      else
        local err_code = ffi.errno()
        if err_code == 17 then -- EEXIST
          return false, "Destination already exists"
        else
          return false, "Failed to rename: errno " .. tostring(err_code)
        end
      end
    end
  elseif os_name == "Linux" then
    local ok, res = pcall(ffi.C.renameat2, -100, old_path, -100, new_path, 1) -- AT_FDCWD = -100, RENAME_NOREPLACE = 1
    if ok then
      if res == 0 then
        return true, nil
      else
        local err_code = ffi.errno()
        if err_code == 17 then -- EEXIST
          return false, "Destination already exists"
        else
          return false, "Failed to rename: errno " .. tostring(err_code)
        end
      end
    end
  end

  return nil, nil
end

--- Atomic, fail-closed rename that never replaces an existing destination
---@param old_path string
---@param new_path string
---@param is_dir boolean
---@return boolean ok
---@return string? error_msg
local function atomic_rename_noreplace(old_path, new_path, is_dir)
  -- 1. Try platform-native atomic no-replace primitive where supported
  local nat_ok, nat_err = M._native_rename_noreplace(old_path, new_path)
  if nat_ok ~= nil then
    return nat_ok, nat_err
  end

  -- 2. Fallback for regular files: link(old, new) followed by unlink(old)
  -- POSIX link(2) is atomically guaranteed to fail with EEXIST if new_path exists.
  if not is_dir then
    local link_ok, link_err = uv.fs_link(old_path, new_path)
    if not link_ok then
      if link_err and (link_err:find("EEXIST") or link_err:find("already exists")) then
        return false, "Destination already exists"
      end
      return false, "Failed to rename: " .. tostring(link_err)
    end
    local unlink_ok, unlink_err = uv.fs_unlink(old_path)
    if not unlink_ok then
      pcall(uv.fs_unlink, new_path)
      return false, "Failed to rename: " .. tostring(unlink_err)
    end
    return true, nil
  end

  -- 3. Fallback for directories: fail closed with a bounded error.
  -- Ordinary uv.fs_rename cannot guarantee no-replace semantics against races or
  -- empty destination directories without a kernel no-replace primitive.
  if uv.fs_lstat(new_path) ~= nil then
    return false, "Destination already exists"
  end
  return false, "Atomic directory rename without overwrite is unavailable on this platform"
end

M._atomic_rename_noreplace = atomic_rename_noreplace

---@class ProjectEntry
---@field path string relative path from project root
---@field name string basename of entry
---@field is_dir boolean
---@field depth integer 0-indexed nesting depth
---@field is_dot boolean whether name starts with '.'
---@field size? integer file size in bytes
---@field full_path string absolute path to file
---@field child_count? integer number of immediate children if directory

--- Check if a buffer/content is binary
---@param sample string
---@return boolean
local function is_binary_content(sample)
  if not sample or sample == "" then return false end
  return sample:find("\0") ~= nil
end

--- Scan a single directory and return immediate entries
---@param dir_path string
---@return { name: string, type: string }[]
local function scan_dir_entries(dir_path)
  local entries = {}
  local handle, err = uv.fs_scandir(dir_path)
  if not handle then
    -- Directory unreadable or error
    return entries
  end

  while true do
    local name, type_str = uv.fs_scandir_next(handle)
    if not name then break end
    table.insert(entries, { name = name, type = type_str or "unknown" })
  end

  return entries
end

--- Scan only the immediate visible entries of one directory (lazy model).
--- Directories are listed before files; both groups sort case-insensitively.
--- Dotfile filtering applies at every level; callers decide when to scan a
--- directory, so no traversal happens unless a parent folder was expanded.
---@param dir_path string absolute directory to scan
---@param rel_prefix string relative path prefix from project root ("" at root)
---@param depth integer 0-indexed nesting depth of the returned entries
---@param show_dotfiles boolean whether dot-prefixed entries are visible
---@return ProjectEntry[] entries
function M.get_immediate_entries(dir_path, rel_prefix, depth, show_dotfiles)
  show_dotfiles = (show_dotfiles == true)

  local raw_entries = scan_dir_entries(dir_path)

  local dirs = {}
  local files = {}

  for _, item in ipairs(raw_entries) do
    local name = item.name
    local is_dot = (name:sub(1, 1) == ".")

    -- If dotfiles are hidden, skip any entry whose name starts with '.'
    if show_dotfiles or not is_dot then
      local item_rel_path = (rel_prefix == "") and name or (rel_prefix .. "/" .. name)
      local item_full_path = dir_path .. "/" .. name

      -- Determine if directory
      local is_dir = (item.type == "directory")
      if item.type == "link" or item.type == "unknown" then
        local st = uv.fs_stat(item_full_path)
        if st and st.type == "directory" then
          is_dir = true
        end
      end

      local entry = {
        path = item_rel_path,
        name = name,
        is_dir = is_dir,
        depth = depth,
        is_dot = is_dot,
        full_path = item_full_path,
      }

      if is_dir then
        table.insert(dirs, entry)
      else
        local st = uv.fs_stat(item_full_path)
        if st then
          entry.size = st.size
        end
        table.insert(files, entry)
      end
    end
  end

  -- Sort directories and files alphabetically (case-insensitive)
  table.sort(dirs, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  table.sort(files, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  local result = {}
  for _, dir_entry in ipairs(dirs) do
    table.insert(result, dir_entry)
  end
  for _, file_entry in ipairs(files) do
    table.insert(result, file_entry)
  end
  return result
end

--- Format file size in human-readable string
---@param bytes? integer
---@return string
function M.format_size(bytes)
  if not bytes or bytes < 0 then return "0 B" end
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB (%d bytes)", bytes / 1024, bytes)
  else
    return string.format("%.2f MB (%d bytes)", bytes / (1024 * 1024), bytes)
  end
end

--- Generate read-only preview lines for a selected project entry
---@param entry? ProjectEntry
---@param root_dir? string
---@param show_dotfiles? boolean
---@return string[] lines
---@return boolean is_text_preview
function M.get_preview(entry, root_dir, show_dotfiles)
  root_dir = root_dir or vim.fn.getcwd()
  if show_dotfiles == nil then
    local s_ok, settings = pcall(require, "novim.settings")
    if s_ok and settings then
      show_dotfiles = settings.get("show_dotfiles") == true
    else
      show_dotfiles = false
    end
  else
    show_dotfiles = (show_dotfiles == true)
  end

  if not entry then
    return {
      "# ===================================================================",
      "# Project File Browser (Read-Only)",
      "# ===================================================================",
      "#",
      "# No file or directory selected.",
      "#",
      "# Navigation:",
      "#   [j] / [k] or [↑] / [↓]  Select project files and folders",
      "#   [s]                     Open Settings (toggle dot-folders)",
      "#   [r]                     Refresh project listing",
      "#   [2] or [d]              Switch to Git Diff workbench",
      "#   [?]                     Show full help",
      "#   [q] or [Esc Esc]        Close browser",
    }, false
  end

  if entry.is_dir then
    -- Directory inspection
    local raw_children = scan_dir_entries(entry.full_path)
    local child_entries = {}
    local hidden_dot_count = 0

    for _, child in ipairs(raw_children) do
      local is_dot = (child.name:sub(1, 1) == ".")
      if is_dot and not show_dotfiles then
        hidden_dot_count = hidden_dot_count + 1
      else
        table.insert(child_entries, child)
      end
    end

    local items_summary = #child_entries .. " item(s)"
    if hidden_dot_count > 0 then
      items_summary = items_summary .. string.format(" (%d dot-item%s hidden)", hidden_dot_count, hidden_dot_count > 1 and "s" or "")
    end

    local lines = {
      "# ===================================================================",
      "# Directory: " .. entry.path .. "/",
      "# ===================================================================",
      "# Relative Path: " .. entry.path .. "/",
      "# Full Path:     " .. entry.full_path,
      "# Type:          Directory" .. (entry.is_dot and " (Dot-Folder / Hidden by default)" or ""),
      "# Depth:         " .. entry.depth,
      "# Direct Items:  " .. items_summary,
      "# ───────────────────────────────────────────────────────────────────",
      "# Contents:",
    }

    if #child_entries == 0 then
      if hidden_dot_count > 0 then
        table.insert(lines, "#   (No visible items; " .. hidden_dot_count .. " dot-item(s) hidden. Press 's' to show.)")
      else
        table.insert(lines, "#   (Empty directory)")
      end
    else
      local sorted_children = vim.deepcopy(child_entries)
      table.sort(sorted_children, function(a, b)
        if (a.type == "directory") ~= (b.type == "directory") then
          return a.type == "directory"
        end
        return a.name:lower() < b.name:lower()
      end)

      for i, child in ipairs(sorted_children) do
        if i > 50 then
          table.insert(lines, string.format("#   ... and %d more items", #sorted_children - 50))
          break
        end
        local prefix = (child.type == "directory") and "📁 " or "📄 "
        table.insert(lines, string.format("#   %s%s%s", prefix, child.name, (child.type == "directory") and "/" or ""))
      end
    end

    table.insert(lines, "# ───────────────────────────────────────────────────────────────────")
    table.insert(lines, "# Press [s] to toggle dot-folder visibility in Settings.")
    return lines, false
  end

  -- File inspection
  local st = uv.fs_stat(entry.full_path)
  local size = (st and st.size) or entry.size or 0
  local size_str = M.format_size(size)

  local header = {
    "# ===================================================================",
    "# File: " .. entry.path,
    "# ===================================================================",
    "# Relative Path: " .. entry.path,
    "# Full Path:     " .. entry.full_path,
    "# Type:          Regular File" .. (entry.is_dot and " (Dot-File / Hidden by default)" or ""),
    "# Size:          " .. size_str,
    "# ───────────────────────────────────────────────────────────────────",
    "# File Content Preview (Read-Only):",
    "# ───────────────────────────────────────────────────────────────────",
  }

  -- If file size is 0
  if size == 0 then
    local lines = vim.deepcopy(header)
    table.insert(lines, "# (Empty file)")
    return lines, false
  end

  -- Read file safely
  local f, err = io.open(entry.full_path, "rb")
  if not f then
    local lines = vim.deepcopy(header)
    table.insert(lines, "# [Unable to read file: " .. tostring(err) .. "]")
    return lines, false
  end

  local sample = f:read(8192) or ""
  if is_binary_content(sample) then
    f:close()
    local lines = vim.deepcopy(header)
    table.insert(lines, "# [Binary file - content preview suppressed in text inspector]")
    table.insert(lines, "# Size: " .. size_str)
    return lines, false
  end

  -- Read text lines up to 500 lines
  f:seek("set", 0)
  local preview_lines = vim.deepcopy(header)
  local line_idx = 1
  for line in f:lines() do
    if line_idx > 500 then
      table.insert(preview_lines, string.format("# ... [Preview capped at 500 lines. Total size: %s]", size_str))
      break
    end
    table.insert(preview_lines, string.format("%4d │ %s", line_idx, line))
    line_idx = line_idx + 1
  end
  f:close()

  return preview_lines, true
end

-- =========================================================================
-- Files create and rename operations (TASK-020)
-- =========================================================================

--- Check whether a path or its realpath is strictly within root_dir
---@param path string
---@param root_dir string
function M.is_path_outside_root(path, root_dir)
  if not path or path == "" or not root_dir or root_dir == "" then
    return true, "Invalid path or root directory"
  end

  local norm_root = root_dir:gsub("/+$", "")
  local root_real = uv.fs_realpath(norm_root)
  root_real = (root_real and root_real:gsub("/+$", "")) or norm_root

  local norm_path = path:gsub("/+$", "")
  local path_real = uv.fs_realpath(norm_path)
  path_real = path_real and path_real:gsub("/+$", "") or nil

  if path_real then
    if path_real ~= root_real and path_real:sub(1, #root_real + 1) ~= root_real .. "/" then
      return true, "Target is outside project root"
    end
    return false, nil
  end

  -- If path does not exist on disk, check its existing parent directory
  local parent = vim.fs.dirname(norm_path)
  while parent and parent ~= "" do
    local parent_real = uv.fs_realpath(parent)
    if parent_real then
      parent_real = parent_real:gsub("/+$", "")
      if parent_real ~= root_real and parent_real:sub(1, #root_real + 1) ~= root_real .. "/" then
        return true, "Target is outside project root"
      end
      break
    end
    local next_p = vim.fs.dirname(parent)
    if not next_p or next_p == parent or next_p == "." or next_p == "/" then break end
    parent = next_p
  end

  return false, nil
end

--- Check if path itself is a symlink or has any symlinked parent directories below root_dir
---@param path string
---@param root_dir string
---@return boolean is_symlink
---@return string? reason
function M.is_symlink_or_has_symlink_parent(path, root_dir)
  if not path or path == "" or not root_dir or root_dir == "" then
    return true, "Invalid path"
  end

  local norm_root = root_dir:gsub("/+$", "")
  local root_real = uv.fs_realpath(norm_root)
  root_real = (root_real and root_real:gsub("/+$", "")) or norm_root

  local cur = path:gsub("/+$", "")
  -- 1. Check path itself (lstat non-following)
  local st_cur = uv.fs_lstat(cur)
  if st_cur and st_cur.type == "link" then
    return true, "Symlinks cannot be created or renamed"
  end
  local cur_real = uv.fs_realpath(cur)
  cur_real = cur_real and cur_real:gsub("/+$", "") or nil
  if cur == norm_root or (cur_real and cur_real == root_real) then
    return false, nil
  end

  -- 2. Traverse parent directories up to root_dir
  cur = vim.fs.dirname(cur)
  while cur and cur ~= "" and cur ~= "." and cur ~= "/" do
    local p_real = uv.fs_realpath(cur)
    p_real = p_real and p_real:gsub("/+$", "") or nil
    if cur == norm_root or (p_real and p_real == root_real) then
      break
    end
    local st = uv.fs_lstat(cur)
    if st and st.type == "link" then
      return true, "Symlinked parent directories are not permitted"
    end

    local parent = vim.fs.dirname(cur)
    if not parent or parent == cur then
      break
    end
    cur = parent
  end

  return false, nil
end

--- Validate an entered single path component name
---@param name any
---@return boolean ok
---@return string? error_msg
---@return string? clean_name
function M.validate_name(name)
  if name == nil then
    return false, "Name cannot be empty", nil
  end
  local clean = tostring(name):match("^%s*(.-)%s*$")
  if clean == "" then
    return false, "Name cannot be empty", nil
  end
  if clean == "." or clean == ".." then
    return false, "Name cannot be '.' or '..'", nil
  end
  if clean:find("[/\\]") then
    return false, "Name cannot contain path separators", nil
  end
  if clean:find("%z") then
    return false, "Name cannot contain NUL characters", nil
  end
  return true, nil, clean
end

--- Resolve target directory and relative path prefix for New File/Folder
---@param target_entry? ProjectEntry
---@param root_dir? string
---@return string target_dir absolute path
---@return string target_rel relative path prefix ("" for root)
function M.resolve_create_target(target_entry, root_dir)
  root_dir = root_dir or vim.fn.getcwd()
  if not target_entry then
    return root_dir, ""
  end
  if target_entry.is_dir then
    return target_entry.full_path, target_entry.path
  else
    local dir = vim.fs.dirname(target_entry.full_path)
    local rel = vim.fs.dirname(target_entry.path)
    if rel == "." then rel = "" end
    return dir, rel
  end
end

--- Create an empty regular file at target_dir with name
---@param target_dir string
---@param name string
---@param root_dir? string
---@return boolean ok
---@return string result full path on success or error string on failure
function M.create_file(target_dir, name, root_dir)
  root_dir = root_dir or vim.fn.getcwd()
  local ok, err, clean_name = M.validate_name(name)
  if not ok then
    return false, err
  end

  local is_out, out_err = M.is_path_outside_root(target_dir, root_dir)
  if is_out then
    return false, out_err
  end

  local is_sym, sym_err = M.is_symlink_or_has_symlink_parent(target_dir, root_dir)
  if is_sym then
    return false, sym_err
  end

  local st_target = uv.fs_lstat(target_dir)
  if not st_target or st_target.type ~= "directory" then
    return false, "Target directory does not exist or is not a directory"
  end

  local full_path = target_dir:gsub("/+$", "") .. "/" .. clean_name
  if uv.fs_lstat(full_path) ~= nil then
    return false, "Destination already exists"
  end

  local is_dest_out, dest_out_err = M.is_path_outside_root(full_path, root_dir)
  if is_dest_out then
    return false, dest_out_err
  end

  local flags = bit.bor(uv.constants.O_CREAT, uv.constants.O_EXCL, uv.constants.O_WRONLY)
  local fd, open_err = uv.fs_open(full_path, flags, 420)
  if not fd then
    if open_err and (open_err:find("EEXIST") or open_err:find("already exists")) then
      return false, "Destination already exists"
    end
    return false, "Failed to create file: " .. tostring(open_err)
  end
  uv.fs_close(fd)

  return true, full_path
end

--- Create a directory at target_dir with name
---@param target_dir string
---@param name string
---@param root_dir? string
---@return boolean ok
---@return string result full path on success or error string on failure
function M.create_folder(target_dir, name, root_dir)
  root_dir = root_dir or vim.fn.getcwd()
  local ok, err, clean_name = M.validate_name(name)
  if not ok then
    return false, err
  end

  local is_out, out_err = M.is_path_outside_root(target_dir, root_dir)
  if is_out then
    return false, out_err
  end

  local is_sym, sym_err = M.is_symlink_or_has_symlink_parent(target_dir, root_dir)
  if is_sym then
    return false, sym_err
  end

  local st_target = uv.fs_lstat(target_dir)
  if not st_target or st_target.type ~= "directory" then
    return false, "Target directory does not exist or is not a directory"
  end

  local full_path = target_dir:gsub("/+$", "") .. "/" .. clean_name
  if uv.fs_lstat(full_path) ~= nil then
    return false, "Destination already exists"
  end

  local is_dest_out, dest_out_err = M.is_path_outside_root(full_path, root_dir)
  if is_dest_out then
    return false, dest_out_err
  end

  local mkdir_ok, mkdir_err = uv.fs_mkdir(full_path, 493)
  if not mkdir_ok then
    if mkdir_err and (mkdir_err:find("EEXIST") or mkdir_err:find("already exists")) then
      return false, "Destination already exists"
    end
    return false, "Failed to create folder: " .. tostring(mkdir_err)
  end

  return true, full_path
end

--- Rename a file or directory to new_name
---@param entry ProjectEntry
---@param new_name string
---@param root_dir? string
---@return boolean ok
---@return string result new full path on success or error string on failure
---@return boolean unchanged true if name was identical and no mutation occurred
function M.rename_entry(entry, new_name, root_dir)
  root_dir = root_dir or vim.fn.getcwd()
  if not entry or not entry.full_path then
    return false, "No file or folder selected to rename", false
  end

  local norm_root = root_dir:gsub("/+$", "")
  local norm_entry = entry.full_path:gsub("/+$", "")
  if norm_entry == norm_root or entry.path == "" or entry.path == "." then
    return false, "Cannot rename the project root", false
  end

  local ok, err, clean_name = M.validate_name(new_name)
  if not ok then
    return false, err, false
  end

  if clean_name == entry.name then
    return true, entry.full_path, true
  end

  local is_out, out_err = M.is_path_outside_root(entry.full_path, root_dir)
  if is_out then
    return false, out_err, false
  end

  local is_sym, sym_err = M.is_symlink_or_has_symlink_parent(entry.full_path, root_dir)
  if is_sym then
    return false, sym_err, false
  end

  local st_source = uv.fs_lstat(entry.full_path)
  if not st_source then
    return false, "Source does not exist", false
  end
  if st_source.type ~= "file" and st_source.type ~= "directory" then
    return false, "Only regular files and directories can be renamed", false
  end

  local parent_dir = vim.fs.dirname(entry.full_path)
  local dest_full_path = parent_dir:gsub("/+$", "") .. "/" .. clean_name

  if uv.fs_lstat(dest_full_path) ~= nil then
    return false, "Destination already exists", false
  end

  local is_dest_out, dest_out_err = M.is_path_outside_root(dest_full_path, root_dir)
  if is_dest_out then
    return false, dest_out_err, false
  end

  local ren_ok, ren_err = atomic_rename_noreplace(entry.full_path, dest_full_path, entry.is_dir)
  if not ren_ok then
    return false, ren_err, false
  end

  return true, dest_full_path, false
end

return M
