--- @since 25.5.31

local M = {}

local state = {
  script = nil,
  cached_cwd = nil,
  cached_text = 'hi',
  debug = true,
}

local function to_string(url)
  return url and tostring(url) or ""
end

local function run_script(cwd)
  local script = state.script
  if not script or script == "" then
    return nil
  end

  -- Prefer a simple popen to avoid async context restrictions
  local cmdline = string.format("%s %s", ya.quote(script), ya.quote(cwd))
  local handle = io.popen(cmdline .. " 2>/dev/null", "r")
  if not handle then
    if state.debug then ya.err("custom-status: popen failed for", cmdline) end
    return nil
  end
  local line = handle:read("*l") or ""
  handle:close()
  line = line:gsub("\r", "")
  if line == "" then
    return nil
  end
  return line
end

local function update_cache()
  local cwd = to_string(cx.active.current.cwd)
  if cwd == state.cached_cwd then
    return
  end
  state.cached_cwd = cwd
  state.cached_text = run_script(cwd)
end

function M:setup(opts)
  opts = opts or {}
  -- Default script path
  state.script = opts.script or (os.getenv("HOME") .. "/.local/bin/echos")
  state.debug = not not opts.debug

  -- Warm up once
  pcall(update_cache)

  -- Register a right-aligned status child that prints cached text
  if Status and Status.children_add then
    Status:children_add(function()
      local text = state.cached_text
      if not text or text == "" then
        return ""
      end
      return ui.Line { " ", ui.Span(text), " " }
    end, opts.order or 20, Status.RIGHT)
  end

  -- Refresh when CWD changes and re-render the UI
  if ps and ps.sub then
    ps.sub("cd", function()
      pcall(update_cache)
      pcall(ya.render)
    end)
  end

  return self
end

return M
