--- @since 25.5.31

local state = {
	script = nil,
	cached_cwd = nil,
	cached_text = nil,
	debug = true,
	token = 0, -- increase on every request to drop stale results
	sync = false, -- optional fallback to synchronous execution
	show_steps = true, -- show placeholder + step updates
	timeout_ms = 2000, -- read_line timeout for async child
	notify_error = true,
	error_cooldown = 5,
	_last_err_at = 0,
	_last_err_msg = nil,
}

local function to_string(url)
    return url and tostring(url) or ""
end

-- Forward declarations for cross-references
local build_argline
local selected_or_hovered_sync

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
local apply_update = ya.sync(function(_, token, cwd, text)
	if token ~= state.token then
		return
	end
	state.cached_cwd = cwd
	state.cached_text = text
	-- Debug log
	if state.debug then ya.dbg(string.format("custom-status: applied token=%d cwd=%s text=%s", token, tostring(cwd), tostring(text))) end
	if ui and ui.render then ui.render() else ya.render() end
end)

-- Apply immediately in sync context (used by sync fallback)
local function apply_now(cwd, text)
	state.cached_cwd = cwd
	state.cached_text = text
	if state.debug then ya.dbg(string.format("custom-status: sync apply cwd=%s text=%s", tostring(cwd), tostring(text))) end
	if ui and ui.render then ui.render() else ya.render() end
end

local function notify_error(msg)
	if not state.notify_error then return end
	local now = os.time()
	if (now - (state._last_err_at or 0)) < (state.error_cooldown or 0) and state._last_err_msg == msg then
		return
	end
	state._last_err_at = now
	state._last_err_msg = msg
	ya.notify { title = "Custom Status", content = msg, timeout = 5, level = "error" }
end

local function active_cwd_sync()
  local ok, url = pcall(function()
    return cx and cx.active and cx.active.current and cx.active.current.cwd
  end)
  return to_string(ok and url or nil)
end

local function setup(self, opts)
	opts = opts or {}
	-- Default script path
	state.script = opts.script or (os.getenv("HOME") .. "/.local/bin/echos")
	state.debug = not not opts.debug
	state.sync = not not opts.sync
	if opts.show_steps ~= nil then state.show_steps = not not opts.show_steps end
	if opts.timeout_ms ~= nil then state.timeout_ms = tonumber(opts.timeout_ms) or state.timeout_ms end
	if opts.notify_error ~= nil then state.notify_error = not not opts.notify_error end
	if opts.error_cooldown ~= nil then state.error_cooldown = tonumber(opts.error_cooldown) or state.error_cooldown end

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
			-- Placeholder: show a loading indicator before async job starts
			if state.show_steps then
				apply_update(state.token, active_cwd_sync(), "… loading …")
			end
    if state.debug then ya.dbg(string.format("custom-status: emit startup update token=%d id=%s", state.token, tostring(self._id))) end
    local argline = build_argline(state.token, state.script or "", selected_or_hovered_sync())
    ya.emit("plugin", { self._id, argline })
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
					if state.show_steps then
						apply_update(state.token, active_cwd_sync(), "… loading …")
					end
          if state.debug then ya.dbg(string.format("custom-status: cd event → emit token=%d id=%s", state.token, tostring(self._id))) end
          local argline = build_argline(state.token, state.script or "", selected_or_hovered_sync())
          ya.emit("plugin", { self._id, argline })
				else
					if state.debug then ya.dbg("custom-status: cd event but no self._id; skipping async emit") end
				end
			end
		end)

		-- Refresh when hover changes (selection/hover updates arguments)
		ps.sub("hover", function(_)
			state.token = state.token + 1
			if self and self._id then
				if state.show_steps then
					apply_update(state.token, active_cwd_sync(), "… loading …")
				end
				if state.debug then ya.dbg(string.format("custom-status: hover event → emit token=%d id=%s", state.token, tostring(self._id))) end
				local argline = build_argline(state.token, state.script or "", selected_or_hovered_sync())
				ya.emit("plugin", { self._id, argline })
			else
				if state.debug then ya.dbg("custom-status: hover event but no self._id; skipping async emit") end
			end
		end)
	end

	return self
end

-- Build an argline to emit: update TOKEN SCRIPT [FILES...]
build_argline = function(token, script, files)
  local parts = { "update", tostring(token), ya.quote(script or "", true) }
  if files then
    for _, p in ipairs(files) do
      parts[#parts + 1] = ya.quote(tostring(p), true)
    end
  end
  return table.concat(parts, " ")
end

-- Collect selected file paths, or hovered if none.
selected_or_hovered_sync = ya.sync(function()
  local tab = cx and cx.active
  local list = {}
  if tab and tab.selected then
    for _, u in pairs(tab.selected) do
      list[#list + 1] = tostring(u)
    end
  end
  if #list == 0 and tab and tab.current and tab.current.hovered then
    list[1] = tostring(tab.current.hovered.url)
  end
  return list
end)

-- Async entry point to execute the external script without blocking the UI
local function entry(self, job)
	local args = job and job.args or {}
	if not args or args[1] ~= "update" then
		return
	end
	local token = tonumber(args[2]) or 0
	-- Resolve the user's active cwd from the UI context; fs.cwd() can lag
	local get_active_cwd = ya.sync(function()
		return cx and cx.active and cx.active.current and cx.active.current.cwd
	end)
  -- Be defensive: cx may be temporarily unavailable
  local ok, url = pcall(function()
    return get_active_cwd()
  end)
  local cwd = to_string(ok and url or nil)
	if state.debug then ya.dbg(string.format("custom-status: entry start token=%d cwd=%s", token, tostring(cwd))) end
	if state.show_steps then apply_update(token, cwd, "start…") end

  -- Prefer script from args[3] (sent from setup), fallback to state.script
  local function unquote(s)
    if type(s) ~= "string" then return s end
    s = s:match("^%s*(.-)%s*$")
    local q = s:sub(1, 1)
    if (q == '"' or q == "'") and s:sub(-1) == q and #s >= 2 then
      return s:sub(2, -2)
    end
    return s
  end
  local script = unquote((args and args[3]) or state.script)
  if not script or script == "" then
    if state.show_steps then
      apply_update(token, cwd, "no script…")
    else
      apply_update(token, cwd, nil)
    end
    return
  end
  if state.debug then ya.dbg(string.format("custom-status: using script=%s", tostring(script))) end

  -- Validate script existence to avoid spawn errors
  local ok_script = false
  do
    local cha = select(1, fs.cha(Url(script)))
    ok_script = cha ~= nil
  end
  if not ok_script then
    if state.show_steps then apply_update(token, cwd, "not found…") end
    notify_error(string.format("custom-status script not found: %s", tostring(script)))
    return
  end

	-- Run the script via Command in async context
	local function first_line(s)
		if not s or s == "" then return "" end
		return (s:match("^[^\r\n]*") or ""):gsub("\r", "")
	end

  -- Collect file targets from args[4..]
  local targets = {}
  if args then
    for i = 4, #args do targets[#targets + 1] = args[i] end
  end
  if state.debug then ya.dbg(string.format("custom-status: targets=%s", tostring(#targets))) end

  -- Prefer a short-lived child process: grab first line then end
  local cmd = Command(script)
  if cwd ~= "" then cmd = cmd:cwd(cwd) end
  if #targets > 0 then cmd = cmd:arg(targets) end
  local child, err = cmd
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()

  local line
  if child then
    if state.show_steps then apply_update(token, cwd, "spawned…") end
    -- Try to read one line with a timeout to avoid hanging
    local l, ev = child:read_line_with { timeout = state.timeout_ms }
    if ev == 0 then
      if state.show_steps then apply_update(token, cwd, "reading…") end
      line = first_line(l)
    elseif ev == 3 then
      if state.show_steps then apply_update(token, cwd, "timeout…") end
    else
      if state.show_steps then apply_update(token, cwd, "no data…") end
    end
    -- Ensure the child doesn't linger
    child:start_kill()
    child:wait()
  end

  -- Fallback to shell if direct exec fails (or produced no line)
  if (not child) or (not line or line == "") then
    if not child then
      if state.debug then ya.err(string.format("custom-status: spawn failed: %s", tostring(err))) end
      notify_error(string.format("custom-status script failed: %s", tostring(err)))
    else
      if state.debug then ya.err("custom-status: script produced no output") end
    end
    -- Build shell command with quoted args
    local pieces = { ya.quote(script) }
    for _, p in ipairs(targets) do pieces[#pieces + 1] = ya.quote(p) end
    local cmdline = table.concat(pieces, " ")
    if state.show_steps then apply_update(token, cwd, "fallback…") end
    local sh = Command("sh")
    if cwd ~= "" then sh = sh:cwd(cwd) end
    local out2, err2 = sh
      :arg("-c")
      :arg(cmdline)
      :stdout(Command.PIPED)
      :stderr(Command.PIPED)
      :output()
    if not out2 or not out2.status or not out2.status.success then
      if state.debug then ya.err(string.format("custom-status: fallback failed: %s", tostring(err2 or (out2 and out2.stderr)))) end
      notify_error(string.format("custom-status fallback failed: %s", tostring(err2 or (out2 and out2.stderr))))
      apply_update(token, cwd, "failed…")
      return
    end
    line = first_line(out2.stdout)
  end

  if not line or line == "" then
    if state.show_steps then
      apply_update(token, cwd, "empty…")
    else
      apply_update(token, cwd, nil)
    end
    return
  end
	if state.debug then ya.dbg(string.format("custom-status: entry done token=%d text=%s", token, tostring(line))) end
	apply_update(token, cwd, line)
end

return { setup = setup, entry = entry }
