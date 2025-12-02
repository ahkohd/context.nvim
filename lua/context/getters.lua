-- luacheck: globals vim

local config = require("context.config")

local M = {}

local function get_prefix()
	return config.options.path_prefix or ""
end

function M.buffers()
	local prefix = get_prefix()
	local bufs = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				table.insert(bufs, prefix .. vim.fn.fnamemodify(name, ":."))
			end
		end
	end
	return table.concat(bufs, "\n")
end

function M.file()
	local file = vim.fn.expand("%:.")
	if file == "" then
		return nil
	end
	return get_prefix() .. file
end

function M.file_absolute()
	local file = vim.fn.expand("%:p")
	if file == "" then
		return nil
	end
	return file
end

local function get_selection_range()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		return nil
	end

	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local start_row, start_col = start_pos[2], start_pos[3]
	local end_row, end_col = end_pos[2], end_pos[3]

	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	return { start_row = start_row, start_col = start_col, end_row = end_row, end_col = end_col }
end

local function format_position(file, range)
	if range then
		if range.start_row == range.end_row then
			return string.format("%s:%d:%d-%d", file, range.start_row, range.start_col, range.end_col)
		else
			return string.format("%s:%d-%d", file, range.start_row, range.end_row)
		end
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	return string.format("%s:%d", file, cursor[1])
end

function M.position()
	local file = M.file()
	if not file then
		return nil
	end
	return format_position(file, get_selection_range())
end

function M.position_absolute()
	local file = M.file_absolute()
	if not file then
		return nil
	end
	return format_position(file, get_selection_range())
end

function M.line()
	return vim.api.nvim_get_current_line()
end

function M.selection()
	local range = get_selection_range()
	if not range then
		return nil
	end

	local lines = vim.api.nvim_buf_get_lines(0, range.start_row - 1, range.end_row, false)
	if #lines == 0 then
		return nil
	end

	if #lines == 1 then
		lines[1] = lines[1]:sub(range.start_col, range.end_col)
	else
		lines[1] = lines[1]:sub(range.start_col)
		lines[#lines] = lines[#lines]:sub(1, range.end_col)
	end

	return table.concat(lines, "\n")
end

local function format_diagnostic(d, bufnr)
	local severity = vim.diagnostic.severity[d.severity] or "UNKNOWN"
	local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local end_line = d.end_lnum and d.end_lnum + 1 or d.lnum + 1
	return string.format("[%s] %s @%s:%d-%d", severity, d.message, file, d.lnum + 1, end_line)
end

function M.diagnostics()
	local buf = vim.api.nvim_get_current_buf()
	local diags = vim.diagnostic.get(buf)
	if #diags == 0 then
		return nil
	end
	local lines = {}
	for _, d in ipairs(diags) do
		table.insert(lines, format_diagnostic(d, buf))
	end
	return table.concat(lines, "\n")
end

function M.diagnostics_all()
	local all_diags = vim.diagnostic.get()
	if #all_diags == 0 then
		return nil
	end

	local diags_by_buf = {}
	for _, d in ipairs(all_diags) do
		local bufnr = d.bufnr
		if not diags_by_buf[bufnr] then
			diags_by_buf[bufnr] = {}
		end
		table.insert(diags_by_buf[bufnr], d)
	end

	local lines = {}
	for bufnr, diags in pairs(diags_by_buf) do
		for _, d in ipairs(diags) do
			table.insert(lines, format_diagnostic(d, bufnr))
		end
	end
	return table.concat(lines, "\n")
end

function M.quickfix()
	local qf = vim.fn.getqflist({ title = 1, items = 1 })
	if not qf.items or #qf.items == 0 then
		return nil
	end

	local lines = {}
	if qf.title and qf.title ~= "" then
		table.insert(lines, "Title: " .. qf.title)
	end
	for _, item in ipairs(qf.items) do
		local bufname = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or ""
		local file = vim.fn.fnamemodify(bufname, ":.")
		local text = item.text or ""
		table.insert(lines, string.format("%s:%d:%d: %s", file, item.lnum, item.col, text))
	end
	return table.concat(lines, "\n")
end

local function get_treesitter_node(node_types)
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local parser_ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not parser_ok or not parser then
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	local root = tree:root()
	local node = root:named_descendant_for_range(row, col, row, col)

	while node do
		local node_type = node:type()
		for _, target_type in ipairs(node_types) do
			if node_type:match(target_type) then
				local start_row, start_col = node:start()
				local file = M.file() or ""

				local name = ""
				for child in node:iter_children() do
					local child_type = child:type()
					if child_type == "identifier" or child_type == "name" or child_type:match("name") then
						name = vim.treesitter.get_node_text(child, buf)
						break
					end
				end

				if name ~= "" then
					return string.format("%s %s %s:%d:%d", node_type, name, file, start_row + 1, start_col + 1)
				else
					return string.format("%s %s:%d:%d", node_type, file, start_row + 1, start_col + 1)
				end
			end
		end
		node = node:parent()
	end
	return nil
end

function M.func()
	return get_treesitter_node({
		"function",
		"method",
		"arrow_function",
		"function_declaration",
		"function_definition",
		"method_definition",
		"function_item",
	})
end

function M.class()
	return get_treesitter_node({
		"class",
		"struct",
		"class_declaration",
		"class_definition",
		"struct_item",
		"impl_item",
		"interface",
		"type_alias",
	})
end

function M.this()
	local file = M.file()
	if file then
		return M.position()
	end
	local selection = M.selection()
	if selection then
		return "this\n" .. selection
	end
	return "this"
end

M.items = {
	{ name = "buffers", desc = "List of all open buffers", get = M.buffers },
	{ name = "file", desc = "Current file path (relative)", get = M.file },
	{ name = "file_absolute", desc = "Current file path (absolute)", get = M.file_absolute },
	{ name = "position", desc = "Cursor position (relative)", get = M.position },
	{ name = "position_absolute", desc = "Cursor position (absolute)", get = M.position_absolute },
	{ name = "line", desc = "Current line content", get = M.line },
	{ name = "selection", desc = "Visual selection", get = M.selection },
	{ name = "diagnostics", desc = "Diagnostics for current buffer", get = M.diagnostics },
	{ name = "diagnostics_all", desc = "All workspace diagnostics", get = M.diagnostics_all },
	{ name = "quickfix", desc = "Quickfix list with title", get = M.quickfix },
	{ name = "function", desc = "Function at cursor (Tree-sitter)", get = M.func },
	{ name = "class", desc = "Class/struct at cursor (Tree-sitter)", get = M.class },
	{ name = "this", desc = "Position if file, else 'this' + selection", get = M.this },
}

M.by_name = {
	buffers = M.buffers,
	file = M.file,
	file_absolute = M.file_absolute,
	position = M.position,
	position_absolute = M.position_absolute,
	line = M.line,
	selection = M.selection,
	diagnostics = M.diagnostics,
	diagnostics_all = M.diagnostics_all,
	quickfix = M.quickfix,
	["function"] = M.func,
	class = M.class,
	this = M.this,
}

return M
