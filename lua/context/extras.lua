-- luacheck: globals vim

local config = require("context.config")

local M = {}

M.lsp = {}

local function get_position_encoding()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if clients[1] then
		return clients[1].offset_encoding or "utf-16"
	end
	return "utf-16"
end

local function get_lsp_definition_location(transform_fn)
	local timeout = config.options.lsp.timeout
	local params = vim.lsp.util.make_position_params(0, get_position_encoding())
	local results = vim.lsp.buf_request_sync(0, "textDocument/definition", params, timeout)

	if not results then
		return nil
	end

	for _, res in pairs(results) do
		local result = res.result
		if result and result[1] then
			local loc = result[1]
			local uri = loc.uri or loc.targetUri
			local range = loc.range or loc.targetSelectionRange
			if uri then
				local filepath = vim.uri_to_fname(uri)
				local symbol = vim.fn.expand("<cword>")
				local line = range and (range.start.line + 1) or nil
				return transform_fn(filepath, symbol, line)
			end
		end
	end
	return nil
end

M.lsp.definition = {
	desc = "Path to symbol definition via LSP",
	lazy = true,
	enabled = function()
		return config.options.lsp.enabled
	end,
	get = function()
		return get_lsp_definition_location(function(filepath, _, line)
			local rel_path = vim.fn.fnamemodify(filepath, ":.")
			local prefix = config.options.path_prefix or ""
			local result = prefix .. rel_path
			if line then
				result = result .. ":" .. line
			end
			return result
		end)
	end,
}

local function get_lsp_locations(method, params_modifier)
	local timeout = config.options.lsp.timeout
	local params = vim.lsp.util.make_position_params(0, get_position_encoding())
	if params_modifier then
		params_modifier(params)
	end
	local results = vim.lsp.buf_request_sync(0, method, params, timeout)

	if not results then
		return nil
	end

	local prefix = config.options.path_prefix or ""
	local locations = {}
	for _, res in pairs(results) do
		if res.result then
			for _, loc in ipairs(res.result) do
				local uri = loc.uri
				local range = loc.range
				if uri and range then
					local filepath = vim.uri_to_fname(uri)
					local rel_path = vim.fn.fnamemodify(filepath, ":.")
					local line = range.start.line + 1
					table.insert(locations, prefix .. rel_path .. ":" .. line)
				end
			end
		end
	end

	if #locations == 0 then
		return nil
	end
	return table.concat(locations, "\n")
end

M.lsp.references = {
	desc = "All references to symbol via LSP",
	lazy = true,
	enabled = function()
		return config.options.lsp.enabled
	end,
	get = function()
		return get_lsp_locations("textDocument/references", function(params)
			params.context = { includeDeclaration = false }
		end)
	end,
}

return M
