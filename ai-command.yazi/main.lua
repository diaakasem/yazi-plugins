local function notify(level, message)
	ya.notify({
		title = "AICommand",
		content = message,
		level = level or "info",
		timeout = 5,
	})
end

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function get_cwd()
	if not cx or not cx.active or not cx.active.current then
		return nil
	end

	local cwd = cx.active.current.cwd
	return cwd and tostring(cwd) or nil
end

local LAUNCH_SCRIPT = [[
set -eu

TARGET_DIR="${AI_TARGET_DIR:-.}"
USER_COMMAND="${AI_USER_COMMAND:-}"

# Allow overriding the full AI command that runs after `nohup` and
# before output redirection. If not set, default to Codex CLI.
# The command may reference $TARGET_DIR and $USER_COMMAND which will be
# provided as environment variables to the subshell.
AI_RUN_CMD=${AI_RUN_CMD:-"codex exec -m gpt-5 --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -C \"$TARGET_DIR\" \"$USER_COMMAND\""}

LOG_ROOT=${XDG_STATE_HOME:-"$HOME/.local/state"}
LOG_DIR="$LOG_ROOT/yazi"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/ai-command-$(date +%Y%m%d-%H%M%S).log"

(
	cd "$TARGET_DIR"
	TARGET_DIR="$TARGET_DIR" USER_COMMAND="$USER_COMMAND" nohup sh -c "$AI_RUN_CMD" >"$LOG_FILE" 2>&1 &
) >/dev/null 2>&1

printf 'log:%s\n' "$LOG_FILE"
]]

return {
	entry = function()
		local input, event = ya.input({
			title = "AI Command:",
			position = { "top-center", y = 3, w = 60 },
		})

		if event ~= 1 then
			return
		end

		input = input or ""
		local trimmed = trim(input)
		if trimmed == "" then
			notify("warn", "No AI command provided")
			return
		end

		local cwd = get_cwd()
		local target_dir = (cwd and cwd ~= "" and cwd) or "."

		local summary = trimmed
		if #summary > 60 then
			summary = summary:sub(1, 57) .. "..."
		end

		local launcher = Command("sh")
			:arg("-c")
			:arg(LAUNCH_SCRIPT)
			:env("AI_TARGET_DIR", target_dir)
			:env("AI_USER_COMMAND", trimmed)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)

		local child, err = launcher:spawn()
		if not child then
				notify("error", "Failed to launch AI helper: " .. tostring(err))
			return
		end

		local output, wait_err = child:wait_with_output()
		if not output then
			notify("error", "AI helper error: " .. tostring(wait_err))
			return
		end

		if not output.status.success then
			local message = trim(output.stderr or "")
			if message == "" then
				local code = output.status.code and tostring(output.status.code) or "unknown"
				message = "exit code " .. code
			end
			notify("error", "AI helper failed: " .. message)
			return
		end

		local result = trim(output.stdout or "")
		if result:sub(1, 4) == "log:" then
			local log_path = result:sub(5)
			if log_path == "" then
					notify("info", "AI command running in background: " .. summary)
			else
				notify("info", "AI command running; log: " .. log_path)
			end
		else
			notify("info", "AI command launched: " .. summary)
		end
	end,
}
