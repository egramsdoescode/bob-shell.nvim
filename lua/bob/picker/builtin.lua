--- Bob builtin two-panel floating task picker
local M = {}

local db = require("bob.db")
local preview = require("bob.preview")
local config = require("bob.config")

--- Picker state for the two-panel task history floating window
--- @type table
M.picker_state = {}

--- Close the task picker and clean up all windows, buffers, and autocmds.
M.close_picker = function()
	local ps = M.picker_state
	if ps.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, ps.augroup)
	end
	if ps.prev_win and vim.api.nvim_win_is_valid(ps.prev_win) then
		pcall(vim.api.nvim_win_close, ps.prev_win, true)
	end
	if ps.list_win and vim.api.nvim_win_is_valid(ps.list_win) then
		pcall(vim.api.nvim_win_close, ps.list_win, true)
	end
	if ps.prev_buf and vim.api.nvim_buf_is_valid(ps.prev_buf) then
		pcall(vim.api.nvim_buf_delete, ps.prev_buf, { force = true })
	end
	if ps.list_buf and vim.api.nvim_buf_is_valid(ps.list_buf) then
		pcall(vim.api.nvim_buf_delete, ps.list_buf, { force = true })
	end
	local origin = ps.origin_win
	M.picker_state = { ns_id = ps.ns_id }
	if origin and vim.api.nvim_win_is_valid(origin) then
		pcall(vim.api.nvim_set_current_win, origin)
	end
end

--- Refresh the preview panel with messages for the given task.
--- @param task_id string
M.refresh_preview = function(task_id)
	local ps = M.picker_state
	if not ps.prev_buf or not vim.api.nvim_buf_is_valid(ps.prev_buf) then
		return
	end
	local width = 60
	if ps.prev_win and vim.api.nvim_win_is_valid(ps.prev_win) then
		width = vim.api.nvim_win_get_width(ps.prev_win)
	end
	local msgs = db.load_messages_for_task(task_id, config.config.task_preview_messages)
	local lines, highlights = preview.format_preview_lines(msgs, width)
	vim.api.nvim_buf_set_option(ps.prev_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(ps.prev_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(ps.prev_buf, "modifiable", false)
	preview.apply_preview_highlights(ps.prev_buf, ps.ns_id, highlights)
end

--- Open the two-panel floating task picker.
--- Calls on_confirm(task_id) when the user selects a task.
--- @param tasks table[] List of {id, status, display_title}
--- @param on_confirm function Called with task_id on selection
M.open_picker = function(tasks, on_confirm)
	local total_cols = vim.o.columns
	local total_rows = vim.o.lines - vim.o.cmdheight - 1
	local height = math.floor(total_rows * 0.8)
	local list_w = math.floor(total_cols * 0.38)
	local prev_w = math.floor(total_cols * 0.52)
	local gap = 1
	local start_col = math.floor((total_cols - list_w - gap - prev_w) / 2)
	local start_row = math.floor((total_rows - height) / 2)

	local ps = M.picker_state
	ps.origin_win = vim.api.nvim_get_current_win()
	ps.tasks = tasks

	-- List buffer
	ps.list_buf = vim.api.nvim_create_buf(false, true)
	local list_labels = {}
	for _, t in ipairs(tasks) do
		table.insert(list_labels, string.format("%-9s  %s", t.status, t.display_title))
	end
	vim.api.nvim_buf_set_lines(ps.list_buf, 0, -1, false, list_labels)
	vim.api.nvim_buf_set_option(ps.list_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(ps.list_buf, "buftype", "nofile")

	-- Preview buffer
	ps.prev_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(ps.prev_buf, 0, -1, false, { "(move cursor to preview)" })
	vim.api.nvim_buf_set_option(ps.prev_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(ps.prev_buf, "buftype", "nofile")

	-- List window (left panel)
	ps.list_win = vim.api.nvim_open_win(ps.list_buf, true, {
		relative = "editor",
		row = start_row,
		col = start_col,
		width = list_w,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Bob tasks ",
		title_pos = "center",
	})

	-- Preview window (right panel)
	ps.prev_win = vim.api.nvim_open_win(ps.prev_buf, false, {
		relative = "editor",
		row = start_row,
		col = start_col + list_w + gap,
		width = prev_w,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Preview ",
		title_pos = "center",
	})

	-- Keymaps on list buffer
	local function confirm()
		local row = vim.api.nvim_win_get_cursor(ps.list_win)[1]
		local task = ps.tasks[row]
		M.close_picker()
		if task then
			on_confirm(task.id)
		end
	end
	local function dismiss()
		M.close_picker()
	end
	local keymap_opts = { buffer = ps.list_buf, nowait = true, silent = true }
	vim.keymap.set("n", "<CR>", confirm, keymap_opts)
	vim.keymap.set("n", "<Esc>", dismiss, keymap_opts)
	vim.keymap.set("n", "q", dismiss, keymap_opts)
	vim.keymap.set("n", "<C-c>", dismiss, keymap_opts)

	-- Augroup for CursorMoved debounce + WinClosed cleanup
	ps.augroup = vim.api.nvim_create_augroup("BobPickerAugroup_" .. tostring(os.time()), { clear = true })
	local debounce_timer = nil

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = ps.augroup,
		buffer = ps.list_buf,
		callback = function()
			if debounce_timer then
				debounce_timer:stop()
			end
			debounce_timer = vim.defer_fn(function()
				if not ps.list_win or not vim.api.nvim_win_is_valid(ps.list_win) then
					return
				end
				local row = vim.api.nvim_win_get_cursor(ps.list_win)[1]
				local task = ps.tasks[row]
				if task then
					M.refresh_preview(task.id)
				end
			end, 50)
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = ps.augroup,
		pattern = tostring(ps.list_win),
		callback = function()
			M.close_picker()
		end,
	})

	-- Initial preview for the first row
	vim.defer_fn(function()
		if ps.tasks and ps.tasks[1] then
			M.refresh_preview(ps.tasks[1].id)
		end
	end, 50)
end

return M
