--- Bob default configuration
--- @class BobConfig
--- @field split_direction string Window split direction (left|right|above|below)
--- @field split_size number|nil Fixed split size in columns/rows
--- @field chat_mode string Default chat mode for Bob Shell
--- @field auto_focus boolean Auto-focus Bob window on open
--- @field start_in_insert boolean Enter insert mode when focusing the Bob terminal
--- @field task_history_limit number Max tasks shown in task history picker
--- @field db_path string|nil Override path to bob.db (nil = use default ~/.bob/db/bob.db)
--- @field task_preview_messages number Max messages shown in task preview panel
--- @field task_preview boolean Enable two-panel floating task picker
--- @field picker string Picker backend: "auto" | "builtin" | "telescope" | "snacks"
--- @field team_id string|nil Team ID — required when using a general API key (not an Inference key)
local M = {}

M.config = {
	split_direction = "right",
	split_size = 50,
	chat_mode = "agent",
	auto_focus = true,
	start_in_insert = true,
	task_history_limit = 50,
	db_path = nil,
	task_preview_messages = 20,
	task_preview = true,
	picker = "auto",
	team_id = nil,
}

return M
