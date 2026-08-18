--- Bob terminal management: bobSearch, bobToggle, bobClose
local M = {}

local config = require("bob.config")

--- Bob state tracking
--- @type table
M.bob_state = {
	win = nil,
	buf = nil,
	prev_win = nil,
}

--- Escape shell argument for safe command execution
--- @param arg string The argument to escape
--- @return string Escaped argument
local function escape_shell_arg(arg)
	-- Escape single quotes and wrap in single quotes for shell safety
	return "'" .. arg:gsub("'", "'\\''") .. "'"
end

--- Build Bob command with flags
--- @param searchText string|nil Optional search text
--- @param resume_id string|nil Task ID to resume
--- @return string Complete bob command
local function build_bob_command(searchText, resume_id)
	local bobCmd = "bob chat"
	local flags = ""

	if config.config.chat_mode then
		flags = flags .. " --mode " .. escape_shell_arg(config.config.chat_mode)
	end

	if config.config.team_id and config.config.team_id ~= "" then
		flags = flags .. " --team-id " .. escape_shell_arg(config.config.team_id)
	end

	if resume_id and resume_id ~= "" then
		return bobCmd .. " --resume " .. escape_shell_arg(resume_id)
	elseif searchText and searchText ~= "" then
		return bobCmd .. " " .. escape_shell_arg(searchText) .. flags
	else
		return bobCmd .. flags
	end
end

--- Get the terminal job ID for the active Bob buffer, or nil.
M.get_bob_job_id = function()
	local bs = M.bob_state
	if not bs.buf or not vim.api.nvim_buf_is_valid(bs.buf) then
		return nil
	end
	local ok, job_id = pcall(vim.api.nvim_buf_get_var, bs.buf, "terminal_job_id")
	if not ok then
		return nil
	end
	return job_id
end

--- Open Bob Shell with optional search text or resumed task ID
--- @param searchText string|nil Optional text to send to Bob
--- @param resume_id string|nil Task ID to resume
M.bobSearch = function(searchText, resume_id)
	if vim.fn.executable("bob") == 0 then
		vim.notify("Bob Shell not found. Please install it first.", vim.log.levels.ERROR)
		return
	end

	local bs = M.bob_state
	local ok, err = pcall(function()
		if bs.win and vim.api.nvim_win_is_valid(bs.win) then
			vim.api.nvim_win_close(bs.win, true)
		end
		if bs.buf and vim.api.nvim_buf_is_valid(bs.buf) then
			vim.api.nvim_buf_delete(bs.buf, { force = true })
		end

		bs.prev_win = vim.api.nvim_get_current_win()

		local split_cmd = ({
			left = "topleft vnew",
			right = "botright vnew",
			above = "topleft new",
			below = "botright new",
		})[config.config.split_direction] or "botright new"
		vim.cmd(split_cmd)
		bs.win = vim.api.nvim_get_current_win()

		if config.config.split_direction == "left" or config.config.split_direction == "right" then
			vim.wo[bs.win].winfixwidth = true
		else
			vim.wo[bs.win].winfixheight = true
		end

		if config.config.split_size then
			-- Bob's TUI needs at least 50 columns/rows to render without crashing
			local size = math.max(config.config.split_size, 50)
			if config.config.split_direction == "left" or config.config.split_direction == "right" then
				vim.api.nvim_win_set_width(bs.win, size)
			else
				vim.api.nvim_win_set_height(bs.win, size)
			end
		end

		local cmd = build_bob_command(searchText, resume_id)
		vim.cmd.term(cmd)

		bs.buf = vim.api.nvim_get_current_buf()

		vim.cmd("normal! G")
		vim.bo[bs.buf].buflisted = false

		-- Allow normal window-navigation keys to escape terminal mode
		local nav_keys = {
			["<C-h>"] = "<C-w>h",
			["<C-j>"] = "<C-w>j",
			["<C-k>"] = "<C-w>k",
			["<C-l>"] = "<C-w>l",
			["<C-w>"] = "<C-w>w",
		}
		for lhs, rhs in pairs(nav_keys) do
			vim.keymap.set("t", lhs, function()
				vim.cmd("stopinsert")
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(rhs, true, false, true), "n", false)
			end, { buffer = bs.buf, desc = "Navigate away from Bob terminal" })
		end

		if config.config.auto_focus then
			if config.config.start_in_insert then
				vim.cmd("startinsert")
			end
		elseif bs.prev_win and vim.api.nvim_win_is_valid(bs.prev_win) then
			vim.api.nvim_set_current_win(bs.prev_win)
		end
	end)

	if not ok then
		vim.notify("Failed to open Bob Shell: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- Toggle Bob Shell window
M.bobToggle = function()
	local bs = M.bob_state
	if bs.win and vim.api.nvim_win_is_valid(bs.win) then
		vim.api.nvim_win_close(bs.win, true)
	else
		M.bobSearch()
	end
end

--- Close Bob Shell window
M.bobClose = function()
	local bs = M.bob_state
	if bs.win and vim.api.nvim_win_is_valid(bs.win) then
		vim.api.nvim_win_close(bs.win, true)
	end
end

return M
