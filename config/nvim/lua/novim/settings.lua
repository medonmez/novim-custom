-- novim/settings.lua - Persistent local settings for novim custom derivative
-- Part of novim custom derivative

local themes = require("novim.themes")

local M = {}

-- Default settings
local DEFAULTS = {
  show_dotfiles = false,
  theme = themes.default_id,
  -- Logical pane geometry (plain column counts) per view. Empty per-view
  -- tables mean "use the built-in starting layout"; the workbench clamps any
  -- stored width to the current terminal before applying it.
  layout = { files = {}, diff = {} },
}

-- Logical layout shape: the per-view pane widths the workbench may persist.
-- Only these keys are ever read or written; unknown fields in the settings
-- file are ignored, so older and newer file shapes both degrade safely.
local LAYOUT_SPEC = {
  files = { "left" },
  diff = { "left", "middle" },
}

--- Return the width when it is a usable finite positive integer, else nil.
--- Non-numbers, NaN, infinities, and out-of-range values are treated as
--- missing geometry and fall back to the built-in defaults.
local function sanitize_width(value)
  if type(value) ~= "number" then
    return nil
  end
  if value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  local width = math.floor(value)
  if width < 1 or width > 10000 then
    return nil
  end
  return width
end

--- Normalize a raw persisted layout into { files = {}, diff = {} } holding
--- only validated integer widths. Malformed or impossible values are dropped
--- instead of being applied.
local function sanitize_layout(raw)
  local layout = { files = {}, diff = {} }
  if type(raw) ~= "table" then
    return layout
  end
  for view, keys in pairs(LAYOUT_SPEC) do
    local raw_view = raw[view]
    if type(raw_view) == "table" then
      for _, key in ipairs(keys) do
        local width = sanitize_width(raw_view[key])
        if width then
          layout[view][key] = width
        end
      end
    end
  end
  return layout
end
-- In-memory cache of current settings
local current_settings = nil

--- Get the persistent settings file path under Neovim isolated state path
---@return string path
function M.get_settings_file_path()
  local state_dir = vim.fn.stdpath("state")
  if not state_dir or state_dir == "" then
    state_dir = os.getenv("XDG_STATE_HOME") or (vim.fn.stdpath("data") .. "/state")
  end
  return state_dir .. "/novim_settings.json"
end

--- Safely load settings from persistent storage.
--- If the file is missing, empty, or contains malformed JSON,
--- safely returns default settings without throwing errors.
---@param force_reload? boolean
---@return { show_dotfiles: boolean, theme: string, layout: table } settings
function M.load(force_reload)
  if current_settings and not force_reload then
    return vim.deepcopy(current_settings)
  end

  local settings = vim.deepcopy(DEFAULTS)
  local path = M.get_settings_file_path()

  if vim.fn.filereadable(path) == 1 then
    local ok, content = pcall(function()
      local f = io.open(path, "r")
      if not f then return nil end
      local text = f:read("*a")
      f:close()
      return text
    end)

    if ok and content and content ~= "" then
      local decode_ok, decoded = pcall(vim.json.decode, content)
      if decode_ok and type(decoded) == "table" then
        if type(decoded.show_dotfiles) == "boolean" then
          settings.show_dotfiles = decoded.show_dotfiles
        end
        if type(decoded.theme) == "string" and themes.is_valid(decoded.theme) then
          settings.theme = decoded.theme
        end
        settings.layout = sanitize_layout(decoded.layout)
      end
    end
  end

  current_settings = vim.deepcopy(settings)
  return settings
end

--- Safely save settings to persistent storage.
--- Returns success flag and optional error message.
---@param new_settings table
---@return boolean success
---@return string? error_msg
function M.save(new_settings)
  if type(new_settings) ~= "table" then
    return false, "Invalid settings table"
  end

  local path = M.get_settings_file_path()
  local dir = vim.fs.dirname(path) or vim.fn.fnamemodify(path, ":h")

  if vim.fn.isdirectory(dir) == 0 then
    local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, dir, "p")
    if not mkdir_ok then
      return false, "Failed to create settings directory: " .. tostring(mkdir_err)
    end
  end

  local settings_to_save = vim.deepcopy(current_settings or DEFAULTS)
  if type(new_settings.show_dotfiles) == "boolean" then
    settings_to_save.show_dotfiles = new_settings.show_dotfiles
  end
  if type(new_settings.theme) == "string" and themes.is_valid(new_settings.theme) then
    settings_to_save.theme = new_settings.theme
  end
  if type(new_settings.layout) == "table" then
    settings_to_save.layout = sanitize_layout(new_settings.layout)
  end

  local encode_ok, json_str = pcall(vim.json.encode, settings_to_save)
  if not encode_ok or not json_str then
    return false, "Failed to encode settings to JSON"
  end

  local write_ok, write_err = pcall(function()
    local f = io.open(path, "w")
    if not f then
      error("Cannot open " .. path .. " for writing")
    end
    f:write(json_str .. "\n")
    f:close()
  end)

  if not write_ok then
    return false, "Failed to write settings file: " .. tostring(write_err)
  end

  current_settings = vim.deepcopy(settings_to_save)
  return true, nil
end

--- Get a specific setting value
---@param key string
---@return any
function M.get(key)
  local s = M.load()
  return s[key]
end

--- Get all current settings
---@return table
function M.get_all()
  return M.load()
end

--- Set a specific setting value and save it.
--- Theme values are validated against the built-in catalog before persisting.
---@param key string
---@param value any
---@return boolean success
---@return string? error_msg
function M.set(key, value)
  if key == "theme" and (type(value) ~= "string" or not themes.is_valid(value)) then
    return false, "Invalid theme: " .. tostring(value)
  end
  local s = M.load()
  s[key] = value
  return M.save(s)
end

--- Merge logical pane geometry into the persisted settings and save.
--- Each view named in `layout` is replaced wholesale with its validated
--- widths; views not named are preserved, so Files and Diff geometry stay
--- independent. Values must be finite positive numbers; anything else is
--- dropped, so malformed input cannot corrupt persisted geometry. On a
--- settings-write failure the in-memory layout is left unchanged.
---@param layout table partial layout, e.g. { files = { left = 40 }, diff = { left = 30, middle = 35 } }
---@return boolean success
---@return string? error_msg
function M.set_layout(layout)
  if type(layout) ~= "table" then
    return false, "Invalid layout table"
  end

  local s = M.load()
  local merged = vim.deepcopy(s.layout or { files = {}, diff = {} })
  for view, keys in pairs(LAYOUT_SPEC) do
    local incoming = layout[view]
    if type(incoming) == "table" then
      local view_layout = {}
      for _, key in ipairs(keys) do
        if incoming[key] ~= nil then
          view_layout[key] = incoming[key]
        end
      end
      merged[view] = view_layout
    end
  end

  return M.save({ layout = merged })
end

--- Toggle dotfiles visibility setting and save immediately.
--- Returns success flag, optional error message, and effective boolean value.
--- If save fails, the in-memory setting is NOT updated and the previous value is retained.
---@return boolean success
---@return string? error_msg
---@return boolean effective_value
function M.toggle_dotfiles()
  local cur = M.get("show_dotfiles")
  local target = not cur
  local ok, err = M.set("show_dotfiles", target)
  if not ok then
    return false, err, cur
  end
  return true, nil, target
end

--- Reset in-memory cache (for testing)
function M.reset_cache()
  current_settings = nil
end

return M
