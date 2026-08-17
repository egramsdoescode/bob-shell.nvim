--- Bob preview formatting and highlight helpers
local M = {}

--- Format message rows into box-drawing display lines with highlight specs.
--- Returns lines[] and highlights[] where each highlight is
--- {line = 0-based row, col_start, col_end, hl_group}.
--- @param msgs table[]|nil List of {role, content} rows
--- @param preview_width number|nil Width available for the fill dashes (default 40)
--- @return string[] lines, table[] highlights
M.format_preview_lines = function(msgs, preview_width)
	local width = (preview_width or 40) - 2 -- subtract borders
	if not msgs or #msgs == 0 then
		return { "(no messages)" }, {}
	end

	local lines = {}
	local highlights = {}

	for _, m in ipairs(msgs) do
		local is_user = m.role == "user"
		local label = is_user and " You " or " Bob "
		local hl = is_user and "BobPreviewUserBorder" or "BobPreviewBobBorder"

		-- Header: ╭─ You ──────────────────────
		local dash_count = math.max(0, width - #label - 2) -- 2 = "╭─"
		local header = "╭─" .. label .. string.rep("─", dash_count)
		table.insert(lines, header)
		table.insert(highlights, {
			line = #lines - 1,
			col_start = 0,
			col_end = #header,
			hl_group = hl,
		})

		-- Body lines: │ content, max 2 lines, truncate with … if needed
		local content = m.content:gsub("\n", " ")
		local body_width = math.max(20, width - 2) -- 2 = "│ "
		local max_lines = 2
		for i = 1, max_lines do
			local chunk_start = (i - 1) * body_width + 1
			if chunk_start > #content then
				break
			end
			local chunk = content:sub(chunk_start, chunk_start + body_width - 1)
			local is_last_allowed = (i == max_lines)
			local has_more = chunk_start + body_width - 1 < #content
			if is_last_allowed and has_more then
				chunk = content:sub(chunk_start, chunk_start + body_width - 4) .. "…"
			end
			local body_line = "│ " .. chunk
			table.insert(lines, body_line)
			table.insert(highlights, {
				line = #lines - 1,
				col_start = 0,
				col_end = 2, -- just the "│ " gutter
				hl_group = hl,
			})
		end

		-- Blank separator
		table.insert(lines, "")
	end

	return lines, highlights
end

--- Apply highlight specs to a buffer, clearing previous highlights first.
--- @param buf number Buffer handle
--- @param ns_id number Namespace ID
--- @param highlights table[] List of {line, col_start, col_end, hl_group}
M.apply_preview_highlights = function(buf, ns_id, highlights)
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	for _, h in ipairs(highlights) do
		pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, h.hl_group, h.line, h.col_start, h.col_end)
	end
end

return M
