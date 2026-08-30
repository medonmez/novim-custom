-- novim/git.lua - Pure read-only Git interface for Diff Workbench
-- Part of novim custom derivative

local M = {}

-- Sentinel ref for the working tree when used as a comparison endpoint.
-- It is not a valid Git revision, so revision readers can branch on it.
M.WORKTREE_REF = "@WORKTREE@"

--- Check if git binary is available
---@return boolean
function M.is_git_available()
  return vim.fn.executable("git") == 1
end

--- Run a git command safely and return output lines and exit code
---@param args string[] arguments to git
---@param cwd? string working directory
---@return string[] lines
---@return integer exit_code
---@return string raw_stdout
--- Run a git command and capture stdout and stderr separately.
--- All calls use a structured argument vector; repository paths and user
--- input are never concatenated into shell command strings.
---@param args string[] arguments to git
---@param cwd? string working directory
---@return string[] lines
---@return integer exit_code
---@return string raw_stdout
---@return string raw_stderr
local function exec_capture(args, cwd)
  if not M.is_git_available() then
    return { "git executable not found in PATH" }, 127, "", "git executable not found in PATH"
  end

  local cmd = { "git", "-c", "core.quotepath=false" }
  if cwd and cwd ~= "" then
    table.insert(cmd, "-C")
    table.insert(cmd, cwd)
  end
  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end

  local res = vim.system(cmd, { text = true }):wait()
  local stdout = res.stdout or ""
  local lines = {}
  if stdout ~= "" then
    lines = vim.split(stdout, "\n", { plain = true })
    if #lines > 0 and lines[#lines] == "" then
      table.remove(lines, #lines)
    end
  end

  return lines, res.code or 0, stdout, res.stderr or ""
end

--- Run a read-only git command safely and return output lines and exit code.
---@param args string[] arguments to git
---@param cwd? string working directory
---@return string[] lines
---@return integer exit_code
---@return string raw_stdout
function M.exec(args, cwd)
  local lines, code, stdout = exec_capture(args, cwd)
  return lines, code, stdout
end

--- Check if directory is inside a git repository
---@param cwd? string
---@return boolean is_git
---@return string? repo_root
function M.get_repo_info(cwd)
  local lines, code = M.exec({ "rev-parse", "--is-inside-work-tree", "--show-toplevel" }, cwd)
  if code ~= 0 or #lines == 0 then
    return false, nil
  end

  if lines[1] == "true" and lines[2] and lines[2] ~= "" then
    return true, lines[2]
  elseif lines[1] and lines[1] ~= "true" and lines[1] ~= "false" then
    return true, lines[1]
  end

  -- Fallback check for toplevel
  local top_lines, top_code = M.exec({ "rev-parse", "--show-toplevel" }, cwd)
  if top_code == 0 and #top_lines > 0 and top_lines[1] ~= "" then
    return true, top_lines[1]
  end

  return false, nil
end

--- Check if HEAD commit exists in the repository
---@param cwd? string
---@return boolean has_head
---@return string? head_commit
function M.has_head(cwd)
  local lines, code = M.exec({ "rev-parse", "--verify", "HEAD" }, cwd)
  if code == 0 and #lines > 0 and lines[1] ~= "" then
    return true, lines[1]
  end
  return false, nil
end

---@class ChangedFile
---@field path string relative path (exact bytes preserved)
---@field status string normalized status ("M", "A", "D", "R", "??", "U")
---@field raw_status string raw 2-character porcelain status code
---@field orig_path? string original path if renamed/copied
---@field is_untracked boolean
---@field is_deleted boolean
---@field is_staged boolean

--- Get list of changed and untracked files relative to HEAD
--- Uses NUL-delimited porcelain format (-z) to safely handle all filenames
---@param cwd? string
---@return ChangedFile[] files
---@return { modified: integer, untracked: integer, deleted: integer, added: integer, renamed: integer, total: integer } stats
---@return string? error_msg
function M.get_changed_files(cwd)
  local is_git, repo_root = M.get_repo_info(cwd)
  if not is_git then
    return {}, { modified = 0, untracked = 0, deleted = 0, added = 0, renamed = 0, total = 0 }, "Not a git repository"
  end

  -- Use -z for NUL-delimited safe parsing
  local _, code, raw = M.exec({ "status", "--porcelain=v1", "-z", "-uall" }, repo_root)
  if code ~= 0 then
    return {}, { modified = 0, untracked = 0, deleted = 0, added = 0, renamed = 0, total = 0 }, "Git status failed with code " .. code
  end

  local files = {}
  local stats = { modified = 0, untracked = 0, deleted = 0, added = 0, renamed = 0, total = 0 }

  if not raw or raw == "" then
    return files, stats, nil
  end

  local chunks = vim.split(raw, "\0", { plain = true })
  local idx = 1

  while idx <= #chunks do
    local chunk = chunks[idx]
    if not chunk or chunk == "" then
      break
    end

    if #chunk >= 3 then
      local raw_status = chunk:sub(1, 2)
      local path = chunk:sub(4)
      local orig_path = nil

      local index_char = raw_status:sub(1, 1)
      local worktree_char = raw_status:sub(2, 2)
      local is_rename_or_copy = (index_char == "R" or worktree_char == "R" or index_char == "C" or worktree_char == "C")

      if is_rename_or_copy then
        idx = idx + 1
        if idx <= #chunks and chunks[idx] ~= "" then
          orig_path = chunks[idx]
        end
      end

      local status = "M"
      local is_untracked = false
      local is_deleted = false
      local is_staged = (index_char ~= " " and index_char ~= "?" and index_char ~= "!")

      if raw_status == "??" then
        status = "??"
        is_untracked = true
        stats.untracked = stats.untracked + 1
      elseif index_char == "D" or worktree_char == "D" then
        status = "D"
        is_deleted = true
        stats.deleted = stats.deleted + 1
      elseif index_char == "A" or worktree_char == "A" then
        status = "A"
        stats.added = stats.added + 1
      elseif index_char == "R" or worktree_char == "R" then
        status = "R"
        stats.renamed = stats.renamed + 1
      elseif index_char == "U" or worktree_char == "U" or raw_status == "AA" or raw_status == "DD" then
        status = "U"
        stats.modified = stats.modified + 1
      else
        status = "M"
        stats.modified = stats.modified + 1
      end

      stats.total = stats.total + 1

      table.insert(files, {
        path = path,
        status = status,
        raw_status = raw_status,
        orig_path = orig_path,
        is_untracked = is_untracked,
        is_deleted = is_deleted,
        is_staged = is_staged,
      })
    end

    idx = idx + 1
  end

  return files, stats, nil
end

--- Get diff lines for a specific file relative to HEAD
---@param file ChangedFile
---@param cwd? string
---@return string[] lines
---@return boolean is_binary
function M.get_file_diff(file, cwd)
  local is_git, repo_root = M.get_repo_info(cwd)
  if not is_git then
    return { "# Error: Not a git repository" }, false
  end

  local head_exists = M.has_head(repo_root)

  if file.is_untracked then
    -- Untracked file: show all-additions diff using --no-index against /dev/null
    local out, _ = M.exec({ "diff", "--no-index", "--", "/dev/null", file.path }, repo_root)
    if #out == 0 then
      -- Empty file or unreadable
      local abs_path = repo_root .. "/" .. file.path
      local f = io.open(abs_path, "r")
      if f then
        local content = f:read("*a")
        f:close()
        if content == "" then
          return {
            "diff --git a/" .. file.path .. " b/" .. file.path,
            "new file mode (empty)",
            "--- /dev/null",
            "+++ b/" .. file.path,
            "@@ -0,0 +0,0 @@",
            "# (Empty untracked file)",
          }, false
        end
      end
    end

    -- Check if binary
    for _, l in ipairs(out) do
      if l:match("^Binary files ") or l:match("^GIT binary patch") then
        return out, true
      end
    end
    return out, false
  end

  -- Tracked file (modified, deleted, added, renamed)
  local diff_args = { "diff" }
  if head_exists then
    table.insert(diff_args, "HEAD")
  else
    table.insert(diff_args, "4b825dc642cb6eb9a060e54bf8d69288fbee4904")
  end
  table.insert(diff_args, "--")
  table.insert(diff_args, file.path)

  local out, code = M.exec(diff_args, repo_root)

  -- If empty output but file is added/staged without HEAD
  if #out == 0 and not head_exists then
    out, _ = M.exec({ "diff", "--staged", "--", file.path }, repo_root)
  end

  if #out == 0 then
    if file.is_deleted then
      return {
        "diff --git a/" .. file.path .. " b/" .. file.path,
        "deleted file",
        "--- a/" .. file.path,
        "+++ /dev/null",
        "# (File deleted)",
      }, false
    else
      return {
        "diff --git a/" .. file.path .. " b/" .. file.path,
        "# No textual differences against HEAD",
      }, false
    end
  end

  -- Check if binary
  for _, l in ipairs(out) do
    if l:match("^Binary files ") or l:match("^GIT binary patch") then
      return out, true
    end
  end

  return out, false
end

--- Read one file's content at a revision/location endpoint (read-only).
--- The working tree endpoint reads the file from disk; every other endpoint
--- is read through `git show <ref>:<path>` without touching the repository.
---@param ref string revision ref or the WORKTREE_REF sentinel
---@param path string repo-relative path
---@param cwd? string
---@return string? content
---@return boolean is_binary
---@return string? error_msg
function M.read_revision_content(ref, path, cwd)
  local is_git, repo_root = M.get_repo_info(cwd)
  if not is_git then
    return nil, false, "Not a git repository"
  end

  if ref == M.WORKTREE_REF then
    local handle, err = io.open(repo_root .. "/" .. path, "rb")
    if not handle then
      return nil, false, tostring(err or "unable to read working-tree file")
    end
    local content = handle:read("*a") or ""
    handle:close()
    return content, content:find("\0", 1, true) ~= nil, nil
  end

  local _, code, raw = M.exec({ "show", ref .. ":" .. path }, repo_root)
  if code ~= 0 then
    return nil, false, "unavailable revision content"
  end
  raw = raw or ""
  return raw, raw:find("\0", 1, true) ~= nil, nil
end

--- Read the old and new versions of one changed file between two explicit
--- comparison endpoints. Each endpoint is a table { kind, ref, label } where
--- kind is "head", "commit", or "worktree". The canonical default pair
--- (HEAD versus working tree) keeps the original rename-aware old-path
--- semantics and all placeholder messages unchanged.
---@param file ChangedFile
---@param old_endpoint table
---@param new_endpoint table
---@param cwd? string
---@return table versions
function M.get_file_versions_between(file, old_endpoint, new_endpoint, cwd)
  local old_label = (old_endpoint and old_endpoint.label) or "?"
  local new_label = (new_endpoint and new_endpoint.label) or "?"
  local is_git, repo_root = M.get_repo_info(cwd)
  if not is_git then
    return {
      old_lines = { "# Not a Git repository" },
      new_lines = { "# Not a Git repository" },
      old_exists = false,
      new_exists = false,
      is_binary = false,
      old_binary = false,
      new_binary = false,
      old_path = file.path,
      new_path = file.path,
      old_label = old_label,
      new_label = new_label,
    }
  end

  local function content_to_lines(content)
    if content == nil or content == "" then
      return {}
    end
    local lines = vim.split(content, "\n", { plain = true, trimempty = false })
    if lines[#lines] == "" then
      table.remove(lines, #lines)
    end
    return lines
  end

  -- Rename metadata describes the HEAD-to-worktree change, so the original
  -- path only applies to the canonical default comparison pair.
  local is_default_pair = old_endpoint.kind == "head" and new_endpoint.kind == "worktree"
  local old_path = file.path
  if is_default_pair and file.orig_path then
    old_path = file.orig_path
  end

  local old_content, old_binary, old_read_error = M.read_revision_content(old_endpoint.ref, old_path, repo_root)
  local old_exists = old_content ~= nil

  local new_content, new_binary, new_read_error
  local new_exists
  if file.is_deleted and new_endpoint.ref == M.WORKTREE_REF then
    new_content, new_binary, new_exists = nil, false, false
  else
    new_content, new_binary, new_read_error = M.read_revision_content(new_endpoint.ref, file.path, repo_root)
    new_exists = new_content ~= nil
  end

  local old_lines = content_to_lines(old_content)
  local new_lines = content_to_lines(new_content)

  if not old_exists then
    old_lines = { "# No file in " .. old_label }
  elseif #old_lines == 0 then
    old_lines = { "# (Empty file)" }
  end

  if file.is_deleted and new_endpoint.ref == M.WORKTREE_REF then
    new_lines = { "# File deleted from working tree" }
  elseif not new_exists then
    if new_endpoint.ref == M.WORKTREE_REF then
      new_lines = { "# Unable to read working-tree file" }
      if new_read_error then
        new_lines[2] = "# " .. tostring(new_read_error)
      end
    else
      new_lines = { "# No file in " .. new_label }
    end
  elseif #new_lines == 0 then
    new_lines = { "# (Empty file)" }
  end

  return {
    old_lines = old_lines,
    new_lines = new_lines,
    old_exists = old_exists,
    new_exists = new_exists,
    is_binary = old_binary or new_binary,
    old_binary = old_binary or false,
    new_binary = new_binary or false,
    old_path = old_path,
    new_path = file.path,
    old_label = old_label,
    new_label = new_label,
  }
end

--- Read the HEAD and working-tree versions of one changed file separately.
--- This keeps the Diff Workbench's two content panes independent from the
--- unified diff text while retaining the same working-tree-versus-HEAD
--- baseline and read-only Git boundary.
---@param file ChangedFile
---@param cwd? string
---@return table versions
function M.get_file_versions(file, cwd)
  return M.get_file_versions_between(file,
    { kind = "head", ref = "HEAD", label = "HEAD" },
    { kind = "worktree", ref = M.WORKTREE_REF, label = "Worktree" },
    cwd)
end

--- Resolve a revision to a full commit hash (read-only).
---@param rev string revision or ref name
---@param cwd? string
---@return string? hash
function M.resolve_revision(rev, cwd)
  if type(rev) ~= "string" or rev == "" or rev == M.WORKTREE_REF then
    return nil
  end
  local lines, code = M.exec({ "rev-parse", "--verify", "--quiet", rev .. "^{commit}" }, cwd)
  if code == 0 and #lines > 0 and lines[1] and lines[1] ~= "" then
    return lines[1]
  end
  return nil
end

--- Return the current branch name, or "HEAD" when detached (read-only).
---@param cwd? string
---@return string? branch
function M.get_current_branch(cwd)
  local is_git, repo_root = M.get_repo_info(cwd)
  if not is_git then
    return nil
  end
  local lines, code = M.exec({ "rev-parse", "--abbrev-ref", "HEAD" }, repo_root)
  if code == 0 and #lines > 0 and lines[1] and lines[1] ~= "" then
    return lines[1]
  end
  return nil
end

--- Get the full commit history reachable from the current branch, including
--- merge nodes and local ref decorations. Git's own --graph rendering is
--- preserved verbatim so merge edge lines stay accurate; fields are split
--- with unit/record separator bytes that cannot appear in commit metadata.
--- Each entry is a commit ({ kind="commit", graph, hash, parents, refs,
--- author, date, subject }) or a graph edge line ({ kind="edge", graph }).
---@param cwd? string
---@return table entries
---@return string? error_msg
function M.get_history(cwd)
  local is_git, repo_root = M.get_repo_info(cwd)
  if not is_git then
    return {}, "Not a git repository"
  end

  local lines, code = M.exec({
    "log", "--graph", "--date-order", "--no-color", "--decorate=short",
    "--format=%H%x1f%P%x1f%D%x1f%aN%x1f%at%x1f%s%x1e",
  }, repo_root)
  if code ~= 0 then
    return {}, "Git log failed with code " .. code
  end

  local entries = {}
  for _, line in ipairs(lines) do
    if line ~= "" and line:find("\31", 1, true) then
      local art, hash, fields = line:match("^(.-)([0-9a-f]+)\31(.*)$")
      if art and hash and fields then
        local parts = vim.split(fields, "\31", { plain = true })
        local parents = {}
        if parts[1] and parts[1] ~= "" then
          for parent in parts[1]:gmatch("%S+") do
            table.insert(parents, parent)
          end
        end
        local subject = parts[5] or ""
        subject = subject:gsub("\30$", "")
        table.insert(entries, {
          kind = "commit",
          graph = art,
          hash = hash,
          parents = parents,
          refs = parts[2] or "",
          author = parts[3] or "",
          date = tonumber(parts[4]),
          subject = subject,
        })
      end
    elseif line ~= "" then
      table.insert(entries, { kind = "edge", graph = line })
    end
  end

  return entries, nil
end

-- =========================================================================
-- Local write boundary (TASK-013)
-- =========================================================================
-- These functions are the only mutation entry points in this module. Each
-- call is one structured argument vector executed through exec_capture;
-- repository paths, entry names, and commit messages are passed as separate
-- argv elements and never concatenated into shell command strings. Only
-- file-level index updates and local staged commits are authorized here.

--- Collapse a Git failure into one bounded readable line. Stderr carries
--- most commit/stage failures; "nothing to commit" summaries live on stdout.
---@param stderr string
---@param stdout string
---@param code integer
---@return string message
local function summarize_git_error(stderr, stdout, code)
  local function first_line(text)
    for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed ~= "" then
        return trimmed
      end
    end
    return nil
  end

  local message = first_line(stderr)
  if not message then
    for _, line in ipairs(vim.split(stdout, "\n", { plain = true })) do
      if line:find("nothing to commit", 1, true)
        or line:find("no changes added", 1, true)
        or line:find("nothing added to commit", 1, true) then
        message = line:match("^%s*(.-)%s*$")
        break
      end
    end
  end
  if not message then
    message = first_line(stdout) or ("git failed with exit code " .. tostring(code))
  end
  if #message > 160 then
    message = message:sub(1, 157) .. "..."
  end
  return message
end

--- Validate one change entry for a file-level index update. The entry comes
--- from get_changed_files (or the workbench selection), so paths are exact
--- repository-relative bytes.
---@param entry table|nil
---@return boolean ok
---@return string? error_msg
local function validate_write_entry(entry)
  if type(entry) ~= "table" or type(entry.path) ~= "string" or entry.path == "" then
    return false, "no file selected for the requested action"
  end
  return true, nil
end

--- Stage exactly one file-level change entry (tracked, untracked, deleted,
--- renamed, or unmerged) into the index. This is a local index update only:
--- nothing is pushed, committed, checked out, or staged in bulk.
---@param entry ChangedFile
---@param cwd? string
---@return boolean ok
---@return string? error_msg
function M.stage_file(entry, cwd)
  local ok, err = validate_write_entry(entry)
  if not ok then
    return false, err
  end

  local _, code, _, stderr = exec_capture({ "add", "--", entry.path }, cwd)
  if code ~= 0 then
    return false, summarize_git_error(stderr, "", code)
  end
  return true, nil
end

--- Unstage exactly one file-level change entry, restoring its index state
--- from HEAD (or removing it from the index before the first commit). A
--- rename entry carries both of its paths, so both leave the index together
--- as one logical change. Worktree bytes are never touched.
---@param entry ChangedFile
---@param cwd? string
---@return boolean ok
---@return string? error_msg
function M.unstage_file(entry, cwd)
  local ok, err = validate_write_entry(entry)
  if not ok then
    return false, err
  end

  local args
  if M.has_head(cwd) then
    args = { "reset", "--", entry.path }
    -- One rename entry is one change: reset both of its paths together.
    if type(entry.orig_path) == "string" and entry.orig_path ~= ""
      and entry.orig_path ~= entry.path then
      table.insert(args, entry.orig_path)
    end
  else
    -- Unborn HEAD: nothing is committed yet, so unstaging removes the
    -- entries from the index entirely.
    args = { "rm", "--cached", "--force", "--quiet", "--", entry.path }
  end

  local _, code, _, stderr = exec_capture(args, cwd)
  if code ~= 0 then
    return false, summarize_git_error(stderr, "", code)
  end
  return true, nil
end

--- Create one local commit from the currently staged index. The message is
--- passed as its own argv element; unstaged files are never auto-staged and
--- nothing outside the local repository is touched.
---@param message string
---@param cwd? string
---@return boolean ok
---@return string? error_msg
---@return string? commit_hash full hash of the created commit on success
function M.commit_staged(message, cwd)
  if type(message) ~= "string" or message:match("^%s*$") then
    return false, "commit message must not be empty", nil
  end

  local _, code, stdout, stderr = exec_capture({ "commit", "-m", message }, cwd)
  if code ~= 0 then
    return false, summarize_git_error(stderr, stdout, code), nil
  end

  local hash = M.resolve_revision("HEAD", cwd)
  return true, nil, hash
end

return M
