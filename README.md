<div align="center">

# context.nvim

Editor context for any picker.

[![Neovim](https://img.shields.io/badge/Neovim%200.10+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
<!-- Demo source: https://github.com/user-attachments/assets/5605a6bb-7b3e-4df8-a6e9-68e481475303 -->
https://github.com/user-attachments/assets/5605a6bb-7b3e-4df8-a6e9-68e481475303

</div>

## Features

- Copy editor context to clipboard via picker
- Built-in context items: file, position, selection, diagnostics, quickfix, and more
- Custom prompts with template variable expansion
- Picker-agnostic: works with Snacks, Telescope, fzf-lua, or vim.ui.select
- Tree-sitter powered function/class detection
- Visual selection aware positioning

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ahkohd/context.nvim",
  config = function()
    require("context").setup()
  end,
}
```

### Quick Setup

```lua
return {
  "ahkohd/context.nvim",
  config = function()
    local context = require("context")
    context.setup({
      picker = context.pickers.snacks,
      prompts = {
        explain = "Explain {this}",
        fix = "Fix the issue at {position}",
        review = "Review {file} for issues",
      },
    })
  end,
  keys = {
    {
      "<leader>a",
      function()
        require("context").pick()
      end,
      desc = "Context",
      mode = { "n", "v" },
    },
  },
}
```

## Configuration

```lua
require("context").setup({
  -- Picker to use (required)
  picker = require("context").pickers.snacks,
  -- picker = require("context").pickers.telescope,
  -- picker = require("context").pickers.fzf_lua,
  -- picker = require("context").pickers.vim_ui,

  -- Action when item is selected (default: copy to clipboard)
  on_select = function(item)
    vim.fn.setreg("+", item.value)
  end,

  -- Custom prompts with template variables
  prompts = {
    explain = "Explain {this}",
    fix = "Fix the issue at {position}",
    review = "Review {file} for issues",
    diagnose = "Help fix these diagnostics:\n{diagnostics}",
  },

  -- Prepend @ to position output (default: true)
  position_prefix = true,
})
```

## Context Items

| Name | Description | Example Output |
|------|-------------|----------------|
| `buffers` | List of all open buffers | `src/main.lua`<br>`src/utils.lua` |
| `file` | Current file path | `src/main.lua` |
| `position` | Cursor position | `@src/main.lua:42` |
| `line` | Current line content | `local foo = "bar"` |
| `selection` | Visual selection text | Selected text content |
| `diagnostics` | Diagnostics for current buffer | `[ERROR] msg @file:10-10` |
| `diagnostics_all` | All workspace diagnostics | All diagnostics |
| `quickfix` | Quickfix list with title | Quickfix entries |
| `function` | Function at cursor (Tree-sitter) | `function foo @file:10:1` |
| `class` | Class/struct at cursor (Tree-sitter) | `class Bar @file:5:1` |
| `this` | Position if file, else 'this' + selection | Smart context |

### Position Format

With `position_prefix = true` (default):
- Cursor: `@file:line`
- Same-line selection: `@file:line:col-col`
- Multi-line selection: `@file:start-end`

With `position_prefix = false`:
- Cursor: `file:line`
- Same-line selection: `file:line:col-col`
- Multi-line selection: `file:start-end`

## Template Variables

Use `{variable}` syntax in prompts to expand context:

```lua
prompts = {
  review = "Review {file} for issues",
  fix = "Fix the code at {position}:\n{selection}",
  diagnose = "Help with:\n{diagnostics}",
}
```

Available variables: `{buffers}`, `{file}`, `{position}`, `{line}`, `{selection}`, `{diagnostics}`, `{diagnostics_all}`, `{quickfix}`, `{function}`, `{class}`, `{this}`

## Custom Getters

Add custom context items:

```lua
require("context").setup({
  getters = {
    -- Shorthand: just a function
    my_getter = function(builtin)
      return "File: " .. (builtin.file() or "none")
    end,

    -- Full form: with description and filetype filter
    lua_module = {
      desc = "Lua module path",
      enabled = function() return vim.bo.filetype == "lua" end,
      get = function(builtin)
        local file = builtin.file()
        if not file then return nil end
        return file:gsub("^@", ""):gsub("%.lua$", ""):gsub("/", ".")
      end,
    },
  },
})
```

- `builtin` parameter provides access to all built-in getters for composition
- `enabled` function controls visibility in picker (hidden when returns `false`)

### Extras

Pre-built language-specific getters are available in `context.extras`. Each extra includes an `enabled` function that filters by filetype:

| Name | Description | Example Output |
|------|-------------|----------------|
| `python_path` | Python module path | `src.module.ClassName` |
| `rust_path` | Rust module path | `crate::module::Item` |

Usage:

```lua
local context = require("context")
local extras = require("context.extras")

context.setup({
  picker = context.pickers.snacks,
  getters = {
    python_path = extras.python_path,
    rust_path = extras.rust_path,
  },
})
```

## Custom Picker

Implement a custom picker with this signature:

```lua
local function my_picker(items, on_select)
  -- items: { { name = "file", desc = "...", value = "..." }, ... }
  -- on_select: function(item) called when user selects an item
end

require("context").setup({
  picker = my_picker,
})
```

## API

- `setup(opts)` - Initialize the plugin with configuration
- `pick(on_select?)` - Open the context picker with optional callback override
- `get_items()` - Get all context items (prompts + built-in)
- `pickers.snacks` - Snacks.nvim picker adapter
- `pickers.telescope` - Telescope picker adapter
- `pickers.fzf_lua` - fzf-lua picker adapter
- `pickers.vim_ui` - vim.ui.select fallback adapter

### Custom on_select callback

Override the default action per-call:

```lua
-- Send to a terminal instead of clipboard
require("context").pick(function(item)
  if item and item.value then
    vim.api.nvim_chan_send(term_channel, item.value)
  end
end)
```

<!-- Demo source: https://github.com/user-attachments/assets/cf13b3ef-5a47-4efc-a481-f83b1f3a035c -->
https://github.com/user-attachments/assets/cf13b3ef-5a47-4efc-a481-f83b1f3a035c
