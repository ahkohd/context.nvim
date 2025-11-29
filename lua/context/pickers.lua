-- luacheck: globals Snacks vim

local M = {}

function M.snacks(items, on_select)
	local picker_items = {}
	for _, item in ipairs(items) do
		local value = item.value
		local preview_text
		if type(value) == "string" and value ~= "" then
			preview_text = value:gsub("\n", " "):sub(1, 60)
		else
			preview_text = "{" .. item.name .. "}"
		end

		table.insert(picker_items, {
			text = string.format("%-16s %s", item.name, preview_text),
			name = item.name,
			desc = item.desc,
			value = item.value,
		})
	end

	Snacks.picker.pick({
		title = "Context",
		items = picker_items,
		format = "text",
		preview = function(ctx)
			local item = ctx.item
			local value = item and item.value
			if value and type(value) == "string" then
				local lines = vim.split(value, "\n", { plain = true })
				ctx.preview:set_lines(lines)
			else
				ctx.preview:set_lines({ "{" .. (item and item.name or "empty") .. "}" })
			end
		end,
		confirm = function(picker, item)
			picker:close()
			if item and item.value then
				on_select(item)
			end
		end,
	})
end

function M.vim_ui(items, on_select)
	local display = {}
	for _, item in ipairs(items) do
		local preview
		if type(item.value) == "string" and item.value ~= "" then
			preview = item.value:gsub("\n", " "):sub(1, 50)
		else
			preview = "{" .. item.name .. "}"
		end
		table.insert(display, string.format("%-16s %s", item.name, preview))
	end

	vim.ui.select(display, { prompt = "Context:" }, function(_, idx)
		if idx then
			local item = items[idx]
			if item and item.value then
				on_select(item)
			end
		end
	end)
end

function M.fzf_lua(items, on_select)
	local fzf = require("fzf-lua")
	local display = {}
	local lookup = {}

	for _, item in ipairs(items) do
		local preview
		if type(item.value) == "string" and item.value ~= "" then
			preview = item.value:gsub("\n", " "):sub(1, 50)
		else
			preview = "{" .. item.name .. "}"
		end
		local line = string.format("%-16s %s", item.name, preview)
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
					local preview
					if type(item.value) == "string" and item.value ~= "" then
						preview = item.value:gsub("\n", " "):sub(1, 50)
					else
						preview = "{" .. item.name .. "}"
					end
					return {
						value = item,
						display = string.format("%-16s %s", item.name, preview),
						ordinal = item.name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					if entry.value and entry.value.value then
						local lines = vim.split(entry.value.value, "\n", { plain = true })
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection and selection.value and selection.value.value then
						on_select(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
