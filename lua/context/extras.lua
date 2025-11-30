-- luacheck: globals vim

local M = {}

local function extract_name(treesitter_output)
	if not treesitter_output then
		return nil
	end
	return treesitter_output:match("^%S+%s+(%S+)")
end

local function extract_file(treesitter_output)
	if not treesitter_output then
		return nil
	end
	return treesitter_output:match("@([^:]+)")
end

local function ft_is(...)
	local targets = { ... }
	return function()
		local ft = vim.bo.filetype
		for _, t in ipairs(targets) do
			if ft == t then
				return true
			end
		end
		return false
	end
end

M.python_path = {
	desc = "Python module path (e.g. src.module.ClassName)",
	enabled = ft_is("python"),
	get = function(builtin)
		local class = builtin.class()
		local func = builtin["function"]()
		local file = builtin.file()

		local source_file = extract_file(class) or extract_file(func) or file
		if not source_file then
			return nil
		end

		local module = source_file:gsub("^@", ""):gsub("%.py$", ""):gsub("/", ".")

		local name = extract_name(class) or extract_name(func)
		if name then
			return module .. "." .. name
		end
		return module
	end,
}

M.rust_path = {
	desc = "Rust module path (e.g. crate::module::Item)",
	enabled = ft_is("rust"),
	get = function(builtin)
		local class = builtin.class()
		local func = builtin["function"]()
		local file = builtin.file()

		local source_file = extract_file(class) or extract_file(func) or file
		if not source_file then
			return nil
		end

		local module = source_file
			:gsub("^@", "")
			:gsub("%.rs$", "")
			:gsub("/mod$", "")
			:gsub("^src/", "crate::")
			:gsub("/", "::")

		local name = extract_name(class) or extract_name(func)
		if name then
			return module .. "::" .. name
		end
		return module
	end,
}

return M
