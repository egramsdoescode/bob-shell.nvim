--- Bob send helpers: sendToBob, bobSendFile, bobSendYank, bobSendVisual
local M = {}

local config = require("bob.config")
local terminal = require("bob.terminal")

local function get_relative_current_file()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		return nil
	end
	return vim.fn.fnamemodify(file, ":.")
end

local function get_visual_selection()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		vim.cmd([[normal! gv]])
		mode = vim.fn.visualmode()
	else
		mode = vim.fn.visualmode()
	end

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getline(start_pos[2], end_pos[2])

	if #lines == 0 then
		return nil
	end

	if mode == "v" then
		lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
		lines[1] = string.sub(lines[1], start_pos[3], -1)
	elseif mode == "V" then
		return table.concat(lines, "\n")
	else
		local start_col = vim.fn.virtcol("'<")
		local end_col = vim.fn.virtcol("'>")
		for i, line in ipairs(lines) do
			lines[i] = string.sub(line, start_col, end_col)
		end
	end

	return table.concat(lines, "\n")
end

local function build_selection_prompt(text, file, start_line, end_line)
	if not text or text == "" then
		return nil
	end
	if file and start_line then
		local location = file .. ":" .. start_line
		if end_line and end_line ~= start_line then
			location = location .. "-" .. end_line
		end
		return location .. "\n" .. text
	end
	return text
end

M.sendToBob = function(text)
	if text == nil or text == "" then
		vim.notify("Bob: nothing to send.", vim.log.levels.WARN)
		return false
	end

	local job_id = terminal.get_bob_job_id()
	if not job_id then
		vim.notify("Bob: no active terminal session.", vim.log.levels.WARN)
		return false
	end

	vim.fn.chansend(job_id, text .. "\r")

	local bs = terminal.bob_state
	if bs.win and vim.api.nvim_win_is_valid(bs.win) then
		vim.api.nvim_set_current_win(bs.win)
		if config.config.start_in_insert then
			vim.cmd("startinsert")
		end
	end

	return true
end

M.bobSendFile = function()
	local file = get_relative_current_file()
	if not file then
		vim.notify("Bob: current buffer has no file name.", vim.log.levels.WARN)
		return
	end
	M.sendToBob("@" .. file)
end

M.bobSendYank = function()
	local text = vim.fn.getreg('"')
	local prompt = build_selection_prompt(text)
	if not prompt then
		vim.notify("Bob: unnamed register is empty.", vim.log.levels.WARN)
		return
	end
	M.sendToBob(prompt)
end

M.bobSendVisual = function()
	local text = get_visual_selection()
	if not text then
		vim.notify("Bob: no visual selection found.", vim.log.levels.WARN)
		return
	end
	local file = get_relative_current_file()
	local start_line = vim.fn.getpos("'<")[2]
	local end_line = vim.fn.getpos("'>")[2]
	local prompt = build_selection_prompt(text, file, start_line, end_line)
	M.sendToBob(prompt)
end

return M
