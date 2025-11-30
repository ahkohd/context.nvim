-- luacheck: globals vim

local M = {}

M.defaults = {
	on_select = function(item)
		vim.fn.setreg("+", item.value)
	end,
	picker = nil,
	prompts = {},
	getters = {},
	position_prefix = true,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
