--- Bob Shell integration for Neovim
--- @class Bob
local M = {}

local config = require("bob.config")
local db = require("bob.db")
local builtin = require("bob.picker.builtin")
local terminal = require("bob.terminal")
local send = require("bob.send")

--- Setup Bob plugin with user configuration
--- @param opts BobConfig|nil User configuration options
M.setup = function(opts)
	config.config = vim.tbl_deep_extend("force", config.config, opts or {})
	builtin.picker_state.ns_id = vim.api.nvim_create_namespace("bob_task_preview")
	-- Define highlight groups once; link to semantic groups so any colorscheme works.
	-- Users can override these after setup() if they want custom colors.
	vim.api.nvim_set_hl(0, "BobPreviewUserBorder", { link = "Title", default = true })
	vim.api.nvim_set_hl(0, "BobPreviewBobBorder", { link = "@function", default = true })
end

--- Open Bob Shell with optional search text or resumed task ID
--- @param searchText string|nil Optional text to send to Bob
--- @param resume_id string|nil Task ID to resume
M.bobSearch = function(searchText, resume_id)
	terminal.bobSearch(searchText, resume_id)
end

--- Toggle Bob Shell window
M.bobToggle = function()
	terminal.bobToggle()
end

--- Close Bob Shell window
M.bobClose = function()
	terminal.bobClose()
end

--- Send text to the active Bob terminal session
--- @param text string Text to send
--- @return boolean success
M.sendToBob = function(text)
	return send.sendToBob(text)
end

--- Send current file reference to Bob
M.bobSendFile = function()
	send.bobSendFile()
end

--- Send yanked text to Bob
M.bobSendYank = function()
	send.bobSendYank()
end

--- Send visual selection to Bob
M.bobSendVisual = function()
	send.bobSendVisual()
end

--- Resume the most recent Bob conversation in the current workspace
M.bobResumeLatest = function()
	terminal.bobSearch(nil, "latest")
end

--- Show task history picker and resume the selected conversation
M.bobTaskHistory = function()
	if vim.fn.executable("bob") == 0 then
		vim.notify("Bob Shell not found. Please install it first.", vim.log.levels.ERROR)
		return
	end

	local tasks, err = db.load_tasks_from_db(config.config.task_history_limit, vim.fn.getcwd())
	if not tasks then
		vim.notify("Bob: failed to load task history: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	if #tasks == 0 then
		vim.notify("Bob: no task history found.", vim.log.levels.WARN)
		return
	end

	-- Build display labels for the vim.ui.select fallback path
	local items = {}
	for _, t in ipairs(tasks) do
		table.insert(items, string.format("%-9s  %s", t.status, t.display_title))
	end

	-- Picker dispatch. Priority for "auto": snacks → telescope → builtin float → vim.ui.select.
	-- "snacks"    forces snacks.nvim picker (error if absent).
	-- "telescope" forces Telescope (error if absent).
	-- "builtin"   always uses the raw two-panel float (or vim.ui.select on small terminals).
	local configured_picker = config.config.picker
	local picker = configured_picker

	-- Resolve "auto": prefer snacks → telescope → builtin
	if picker == "auto" then
		if pcall(require, "snacks") then
			picker = "snacks"
		elseif pcall(require, "telescope") then
			picker = "telescope"
		else
			picker = "builtin"
		end
	end

	local ns_id = builtin.picker_state.ns_id

	-- snacks.nvim picker path
	if picker == "snacks" then
		local ok, result = require("bob.picker.snacks").open(tasks, ns_id, function(task_id)
			M.bobSearch(nil, task_id)
		end)
		if not ok then
			vim.notify("Bob: snacks picker failed, falling back to builtin. " .. tostring(result), vim.log.levels.WARN)
			picker = "builtin"
		end
	end

	-- Telescope picker path
	if picker == "telescope" then
		local ok, result = require("bob.picker.telescope").open(tasks, ns_id, function(task_id)
			M.bobSearch(nil, task_id)
		end)
		if not ok then
			-- When telescope was forced (not auto-resolved), treat absence as a hard error.
			if configured_picker == "telescope" and result and result:find("not installed") then
				vim.notify("Bob: " .. tostring(result), vim.log.levels.ERROR)
				return
			end
			vim.notify(
				"Bob: Telescope picker failed, falling back to builtin. " .. tostring(result),
				vim.log.levels.WARN
			)
			picker = "builtin"
		end
	end

	-- Raw builtin floating picker (or vim.ui.select on small terminals)
	if picker == "builtin" then
		if not config.config.task_preview or vim.o.columns < 100 or vim.o.lines < 30 then
			vim.ui.select(items, {
				prompt = "Bob task history",
				format_item = function(item)
					return item
				end,
			}, function(_, idx)
				if not idx then
					return
				end
				M.bobSearch(nil, tasks[idx].id)
			end)
		else
			builtin.open_picker(tasks, function(task_id)
				M.bobSearch(nil, task_id)
			end)
		end
	end
end

-- User commands
vim.api.nvim_create_user_command("BobShell", function(opts)
	M.bobSearch(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", desc = "Open Bob Shell with optional search text" })

vim.api.nvim_create_user_command("BobToggle", function()
	M.bobToggle()
end, { desc = "Toggle Bob Shell window" })

vim.api.nvim_create_user_command("BobClose", function()
	M.bobClose()
end, { desc = "Close Bob Shell window" })

vim.api.nvim_create_user_command("BobTaskHistory", function()
	M.bobTaskHistory()
end, { desc = "Pick a previous Bob task to resume" })

vim.api.nvim_create_user_command("BobResumeLatest", function()
	M.bobResumeLatest()
end, { desc = "Resume the most recent Bob conversation" })

vim.api.nvim_create_user_command("BobSendFile", function()
	M.bobSendFile()
end, { desc = "Send current file reference to Bob" })

vim.api.nvim_create_user_command("BobSendYank", function()
	M.bobSendYank()
end, { desc = "Send yanked text to Bob" })

vim.api.nvim_create_user_command("BobSendVisual", function()
	M.bobSendVisual()
end, { range = true, desc = "Send visual selection to Bob" })

return M
