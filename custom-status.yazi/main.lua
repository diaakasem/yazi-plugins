--- @since 25.5.31

local state = {
  script = nil,
  cached_cwd = nil,
  cached_text = nil,
  debug = true,
  token = 0, -- increase on every request to drop stale results
  sync = false, -- optional fallback to synchronous execution
}

local function to_string(url)
  return url and tostring(url) or ""
end

-- Synchronous runner for fallback mode
local function run_script_sync(script, cwd)
  if not script or script == "" then return nil end
  local cmdline = string.format("%s %s", ya.quote(script), ya.quote(cwd))
  local handle = io.popen(cmdline .. " 2>/dev/null", "r")
  if not handle then return nil end
  local line = handle:read("*l") or ""
  handle:close()
  line = line:gsub("\r", "")
  if line == "" then return nil end
  return line
end

-- Apply a new value to the cache from async context safely
local apply_update = ya.sync(function(st, token, cwd, text)
  ---@cast st table
  if token ~= st.token then
    return
  end
  st.cached_cwd = cwd
  st.cached_text = text
  -- Debug log
  if st.debug then ya.dbg(string.format("custom-status: applied token=%d cwd=%s text=%s", token, tostring(cwd), tostring(text))) end
  ya.render()
end)

-- Apply immediately in sync context (used by sync fallback)
local function apply_now(cwd, text)
  state.cached_cwd = cwd
  state.cached_text = text
  if state.debug then ya.dbg(string.format("custom-status: sync apply cwd=%s text=%s", tostring(cwd), tostring(text))) end
  ya.render()
end

local function setup(self, opts)
  opts = opts or {}
  -- Default script path
  state.script = opts.script or (os.getenv("HOME") .. "/.local/bin/echos")
  state.debug = not not opts.debug
  state.sync = not not opts.sync

  if state.debug then ya.dbg(string.format("custom-status: setup script=%s", tostring(state.script))) end

  -- Initial run on startup
  if state.sync then
    local ok, url = pcall(function()
      return cx and cx.active and cx.active.current and cx.active.current.cwd
    end)
    local cwd0 = to_string(ok and url or nil)
    local line = run_script_sync(state.script, cwd0)
    apply_now(cwd0, line)
  else
    state.token = state.token + 1
    if self and self._id then
      if state.debug then ya.dbg(string.format("custom-status: emit startup update token=%d id=%s", state.token, tostring(self._id))) end
      ya.emit("plugin", { self._id, "update", tostring(state.token) })
    else
      if state.debug then ya.dbg("custom-status: no self._id at setup; skipping initial async emit") end
    end
  end

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

  -- Refresh when CWD changes
  if ps and ps.sub then
    ps.sub("cd", function()
      if state.sync then
        local ok, url = pcall(function()
          return cx and cx.active and cx.active.current and cx.active.current.cwd
        end)
        local cwd = to_string(ok and url or nil)
        local line = run_script_sync(state.script, cwd)
        apply_now(cwd, line)
      else
        state.token = state.token + 1
        if self and self._id then
          if state.debug then ya.dbg(string.format("custom-status: cd event → emit token=%d id=%s", state.token, tostring(self._id))) end
          ya.emit("plugin", { self._id, "update", tostring(state.token) })
        else
          if state.debug then ya.dbg("custom-status: cd event but no self._id; skipping async emit") end
        end
      end
    end)
  end

  return self
end

-- Async entry point to execute the external script without blocking the UI
local function entry(self, job)
  local args = job and job.args or {}
  if not args or args[1] ~= "update" then
    return
  end
  local token = tonumber(args[2]) or 0
  local cwd
  do
    local url, _ = fs.cwd()
    cwd = to_string(url)
  end
  if state.debug then ya.dbg(string.format("custom-status: entry start token=%d cwd=%s", token, tostring(cwd))) end

  local script = state.script
  if not script or script == "" then
    apply_update(state, token, cwd, nil)
    return
  end

  -- Run the script via Command in async context
  local function first_line(s)
    if not s or s == "" then return "" end
    return (s:match("^[^\r\n]*") or ""):gsub("\r", "")
  end

  local output, err = Command(script)
    :arg(cwd)
    :stdout(Command.PIPED)
    :stderr(Command.NULL)
    :output()

  local line = output and first_line(output.stdout) or nil

  -- Fallback to shell if direct exec fails (e.g., missing shebang or not executable)
  if (not output) or (line == nil) or (line == "") then
    local cmdline = string.format("%s %s", ya.quote(script), ya.quote(cwd))
    local out2, err2 = Command("sh")
      :arg("-c")
      :arg(cmdline)
      :stdout(Command.PIPED)
      :stderr(Command.NULL)
      :output()
    if not out2 then
      if state.debug then ya.err(string.format("custom-status: failed: %s; fallback sh -c errored: %s", tostring(err), tostring(err2))) end
      apply_update(state, token, cwd, nil)
      return
    end
    line = first_line(out2.stdout)
  end

  if not line or line == "" then
    apply_update(state, token, cwd, nil)
    return
  end
  if state.debug then ya.dbg(string.format("custom-status: entry done token=%d text=%s", token, tostring(line))) end
  apply_update(state, token, cwd, line)
end

-- Also expose as a fetcher so it can run in async context without explicit emits
---@type UnstableFetcher
local function fetch(_, job)
  local base = job and job.files and job.files[1] and job.files[1].url and job.files[1].url.base
  local cwd = to_string(base)
  if cwd == "" then
    return false
  end
  local token = state.token + 1
  state.token = token
  if state.debug then ya.dbg(string.format("custom-status: fetch start token=%d cwd=%s", token, tostring(cwd))) end

  -- Reuse the same execution logic as in entry
  local script = state.script
  if not script or script == "" then
    apply_update(state, token, cwd, nil)
    return false
  end

  local function first_line(s)
    if not s or s == "" then return "" end
    return (s:match("^[^\r\n]*") or ""):gsub("\r", "")
  end

  local output, err = Command(script)
    :arg(cwd)
    :stdout(Command.PIPED)
    :stderr(Command.NULL)
    :output()

  local line = output and first_line(output.stdout) or nil
  if (not output) or (line == nil) or (line == "") then
    local cmdline = string.format("%s %s", ya.quote(script), ya.quote(cwd))
    local out2, err2 = Command("sh")
      :arg("-c")
      :arg(cmdline)
      :stdout(Command.PIPED)
      :stderr(Command.NULL)
      :output()
    if not out2 then
      if state.debug then ya.err(string.format("custom-status: fetch fallback failed: %s", tostring(err2))) end
      apply_update(state, token, cwd, nil)
      return false
    end
    line = first_line(out2.stdout)
  end

  if not line or line == "" then
    apply_update(state, token, cwd, nil)
    return false
  end
  if state.debug then ya.dbg(string.format("custom-status: fetch done token=%d text=%s", token, tostring(line))) end
  apply_update(state, token, cwd, line)

  return false
end

return { setup = setup, entry = entry, fetch = fetch }
