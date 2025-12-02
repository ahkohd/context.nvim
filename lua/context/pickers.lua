-- luacheck: globals Snacks vim

local M = {}

local function get_preview_text(item, max_len)
	max_len = max_len or 60
	if item.lazy then
		return item.desc or ("{" .. item.name .. "}")
	elseif type(item.value) == "string" and item.value ~= "" then
		return item.value:gsub("\n", " "):sub(1, max_len)
	else
		return "{" .. item.name .. "}"
	end
end

function M.snacks(items, on_select)
	local picker_items = {}
	for _, item in ipairs(items) do
		local preview_text = get_preview_text(item, 60)

		table.insert(picker_items, {
			text = string.format("%-16s %s", item.name, preview_text),
			name = item.name,
			desc = item.desc,
			value = item.value,
			lazy = item.lazy,
			get = item.get,
		})
	end

	Snacks.picker.pick({
		title = "Context",
		items = picker_items,
		format = "text",
		preview = function(ctx)
			local item = ctx.item
			if not item then
				ctx.preview:set_lines({ "{empty}" })
				return
			end
			if item.value and type(item.value) == "string" then
				ctx.preview:set_lines(vim.split(item.value, "\n", { plain = true }))
			else
				ctx.preview:set_lines({ get_preview_text(item) })
			end
		end,
		confirm = function(picker, item)
			picker:close()
			if item then
				on_select(item)
			end
		end,
	})
end

function M.vim_ui(items, on_select)
	local display = {}
	for _, item in ipairs(items) do
		table.insert(display, string.format("%-16s %s", item.name, get_preview_text(item, 50)))
	end

	vim.ui.select(display, { prompt = "Context:" }, function(_, idx)
		if idx then
			on_select(items[idx])
		end
	end)
end

function M.fzf_lua(items, on_select)
	local fzf = require("fzf-lua")
	local display = {}
	local lookup = {}

	for _, item in ipairs(items) do
		local line = string.format("%-16s %s", item.name, get_preview_text(item, 50))
		table.insert(display, line)
		lookup[line] = item
	end

	fzf.fzf_exec(display, {
		prompt = "Context> ",
		previewer = {
			_ctor = function()
				return {
					populate_preview_buf = function(self, entry)
						local item = lookup[entry]
						if item and item.value then
							local lines = vim.split(item.value, "\n", { plain = true })
							vim.api.nvim_buf_set_lines(self.tmpbuf, 0, -1, false, lines)
						end
					end,
				}
			end,
		},
		actions = {
			["default"] = function(selected)
				if selected and selected[1] then
					local item = lookup[selected[1]]
					if item and item.value then
						on_select(item)
					end
				end
			end,
		},
	})
end

function M.telescope(items, on_select)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local previewers = require("telescope.previewers")

	pickers
		.new({}, {
			prompt_title = "Context",
			finder = finders.new_table({
				results = items,
				entry_maker = function(item)
					return {
						value = item,
						display = string.format("%-16s %s", item.name, get_preview_text(item, 50)),
						ordinal = item.name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					local item = entry.value
					if item.value and type(item.value) == "string" then
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(item.value, "\n", { plain = true }))
					else
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { get_preview_text(item) })
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection and selection.value then
						on_select(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
