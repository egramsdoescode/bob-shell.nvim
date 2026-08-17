--- Bob Telescope picker integration
local M = {}

local db = require("bob.db")
local preview = require("bob.preview")
local config = require("bob.config")

--- Open the Telescope task picker.
--- Calls on_confirm(task_id) when the user selects a task.
--- Returns false if Telescope is not installed.
--- @param tasks table[] List of {id, status, display_title}
--- @param ns_id number Namespace ID for preview highlights
--- @param on_confirm function Called with task_id on selection
--- @return boolean ok, string|nil err
M.open = function(tasks, ns_id, on_confirm)
	local telescope_ok = pcall(require, "telescope")
	if not telescope_ok then
		return false, "picker = 'telescope' but Telescope is not installed."
	end

	local ok, result = pcall(function()
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		local previewers = require("telescope.previewers")

		local previewer = previewers.new_buffer_previewer({
			define_preview = function(self, entry)
				if not self.state.bufnr then
					return
				end
				local msgs = db.load_messages_for_task(entry.value.id, config.config.task_preview_messages)
				local win_width = self.state.winid
						and vim.api.nvim_win_is_valid(self.state.winid)
						and vim.api.nvim_win_get_width(self.state.winid)
					or 60
				local lines, highlights = preview.format_preview_lines(msgs, win_width)
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
				local ns = ns_id or vim.api.nvim_create_namespace("bob_task_preview")
				preview.apply_preview_highlights(self.state.bufnr, ns, highlights)
			end,
		})

		pickers
			.new({}, {
				prompt_title = "Bob task history",
				finder = finders.new_table({
					results = tasks,
					entry_maker = function(t)
						local display = string.format("%-9s  %s", t.status, t.display_title)
						return { value = t, display = display, ordinal = display }
					end,
				}),
				sorter = conf.generic_sorter({}),
				previewer = previewer,
				attach_mappings = function(prompt_buf, _)
					actions.select_default:replace(function()
						actions.close(prompt_buf)
						local sel = action_state.get_selected_entry()
						if sel then
							on_confirm(sel.value.id)
						end
					end)
					return true
				end,
			})
			:find()
	end)

	return ok, ok and nil or tostring(result)
end

return M
