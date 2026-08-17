--- Bob snacks.nvim picker integration
local M = {}

local db = require("bob.db")
local preview = require("bob.preview")
local config = require("bob.config")

--- Open the snacks.nvim task picker.
--- Calls on_confirm(task_id) when the user selects a task.
--- Returns false if snacks is not installed.
--- @param tasks table[] List of {id, status, display_title}
--- @param ns_id number Namespace ID for preview highlights
--- @param on_confirm function Called with task_id on selection
--- @return boolean ok, string|nil err
M.open = function(tasks, ns_id, on_confirm)
	local ok, result = pcall(function()
		local snacks = require("snacks")
		snacks.picker.pick({
			title = "Bob task history",
			items = (function()
				local snacks_items = {}
				for _, t in ipairs(tasks) do
					table.insert(snacks_items, {
						text = string.format("%-9s  %s", t.status, t.display_title),
						task = t,
					})
				end
				return snacks_items
			end)(),
			format = function(item, _)
				return { { item.text } }
			end,
			preview = function(ctx)
				local msgs = db.load_messages_for_task(ctx.item.task.id, config.config.task_preview_messages)
				local win_width = ctx.preview.win
						and ctx.preview.win:valid()
						and vim.api.nvim_win_get_width(ctx.preview.win.win)
					or 60
				local lines, highlights = preview.format_preview_lines(msgs, win_width)
				ctx.preview:reset()
				ctx.preview:set_lines(lines)
				if ctx.preview.win and ctx.preview.win:valid() then
					vim.wo[ctx.preview.win.win].number = false
					vim.wo[ctx.preview.win.win].relativenumber = false
				end
				local ns = ns_id or vim.api.nvim_create_namespace("bob_task_preview")
				preview.apply_preview_highlights(ctx.buf, ns, highlights)
			end,
			confirm = function(picker_obj, item)
				picker_obj:close()
				if item then
					on_confirm(item.task.id)
				end
			end,
		})
	end)

	return ok, ok and nil or tostring(result)
end

return M
