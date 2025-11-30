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
		local enabled = ctx.enabled
		if enabled == nil or enabled() then
			local value = ctx.get()
			table.insert(items, {
				name = ctx.name,
				desc = ctx.desc,
				value = value,
			})
		end
	end

	return items
end

function M.pick(on_select)
	local items = M.get_items()
	local picker = config.options.picker or pickers.snacks
	picker(items, on_select or config.options.on_select)
end

local function register_custom_getters(custom_getters)
	for name, getter in pairs(custom_getters) do
		local fn = type(getter) == "function" and getter or getter.get
		local desc = type(getter) == "table" and getter.desc or ("Custom: " .. name)
		local enabled = type(getter) == "table" and getter.enabled or nil

		local wrapped = function()
			return fn(getters.by_name)
		end

		getters.by_name[name] = wrapped
		table.insert(getters.items, { name = name, desc = desc, get = wrapped, enabled = enabled })
	end
end

function M.setup(opts)
	config.setup(opts)

	if opts and opts.getters then
		register_custom_getters(opts.getters)
	end

	vim.api.nvim_create_user_command("Context", function()
		M.pick()
	end, { desc = "Pick context item" })
end

return M
