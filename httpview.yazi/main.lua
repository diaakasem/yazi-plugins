local M = {}

function M:peek(job)
	local command = " gsed 's/^# //g' '" .. tostring(job.file.url) .. "' | mdcat  "
	local child = Command("nu")
			:args({
				"-c",
				command
			})
			:env("CLICOLOR_FORCE", "1")
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:spawn()

	local limit = job.area.h
	local i, lines = 0, ""
	repeat
		local next, event = child:read_line()
		if event == 1 then
			ya.err(tostring(event))
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines = lines .. next
		end
	until i >= job.skip + limit

	child:start_kill()
	if job.skip > 0 and i < job.skip + limit then
		ya.mgr_emit(
			"peek",
			{
				math.max(0, i - limit),
				only_if = job.file.url,
				upper_bound = true
			}
		)
	else
		lines = lines:gsub("\t", string.rep(" ", rt.preview.tab_size or PREVIEW.tab_size or 4))
		ya.preview_widgets(job, { ui.Text.parse(lines):area(job.area) })
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = math.floor(job.units * job.area.h / 10)
		ya.mgr_emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = job.file.url,
		})
	end
end

return M
