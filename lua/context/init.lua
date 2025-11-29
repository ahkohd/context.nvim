-- luacheck: globals vim

local config = require("context.config")
local getters = require("context.getters")
local pickers = require("context.pickers")

local M = {}

M.pickers = pickers

local function expand_template(template)
	return template:gsub("{(%w+)}", function(key)
		local getter = getters.by_name[key]
		if getter then
			return getter() or ""
		end
		return "{" .. key .. "}"
	end)
end

function M.get_items()
	local items = {}

	-- Add prompts first
	for name, template in pairs(config.options.prompts) do
		table.insert(items, {
			name = name,
			desc = "prompt",
			value = expand_template(template),
			is_prompt = true,
		})
	end

	-- Add context items
	for _, ctx in ipairs(getters.items) do
		local value = ctx.get()
		table.insert(items, {
			name = ctx.name,
			desc = ctx.desc,
			value = value,
		})
	end

	return items
end

function M.pick(on_select)
	local items = M.get_items()
	local picker = config.options.picker or pickers.snacks
	picker(items, on_select or config.options.on_select)
end

function M.setup(opts)
	config.setup(opts)

	vim.api.nvim_create_user_command("Context", function()
		M.pick()
	end, { desc = "Pick context item" })
end

return M
