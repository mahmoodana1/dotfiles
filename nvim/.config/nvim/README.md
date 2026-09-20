# nvim

Personal Neovim config. No distro — every plugin here was chosen on purpose.

## Layout

```
init.lua                 entry point, 4 lines of real work
lua/core/
  options.lua            every vim.opt / vim.g setting
  keymaps.lua            EVERY keybinding, in numbered sections
  autocmds.lua           every autocommand
  lazy.lua               plugin-manager bootstrap
lua/plugins/
  ui.lua                 colourscheme, lualine, bufferline, icons, noice, which-key
  editor.lua             snacks, telescope, flash, trouble, sessions, multi-cursor
  lsp.lua                servers, mason, diagnostics, conform (formatting)
  completion.lua         blink.cmp + Copilot
  treesitter.lua         parsers, textobjects
  git.lua                gitsigns, lazygit
  tools.lua              toggleterm, claudecode, nvim-dap
```

## The one rule

**All keybindings live in `lua/core/keymaps.lua`.** Plugin files never call
`vim.keymap.set` and never declare a lazy.nvim `keys = {}` block.

This is not a style preference — it is the thing that stops the class of bug
where two plugins claim the same key and whichever loads last silently wins.
That bug produced `<leader>e` sometimes opening one explorer and sometimes
another, and `<leader>ff` flipping between two pickers between launches.

Lazy-loading still works, because lazy.nvim hooks `require`. A binding written
as:

```lua
map("n", "<leader>ff", function() require("telescope.builtin").find_files() end, "Find files")
```

loads telescope on the first press and not a moment sooner.

Three sets of bindings are buffer-local and cannot be set at startup, so
`keymaps.lua` exposes them as functions that `autocmds.lua` (or the plugin's
own `on_attach`) calls. They are still written in `keymaps.lua`:

| Function | Applied by | Covers |
|---|---|---|
| `M.on_lsp_attach` | `LspAttach` autocmd | `gd`, `K`, `<leader>ca`, … |
| `M.on_gitsigns_attach` | gitsigns `on_attach` | `]h`, `<leader>ghs`, … |
| `M.on_term_open` | `TermOpen` autocmd | `<C-h/j/k/l>` out of a terminal |

The one deliberate exception is `blink.cmp`'s insert-mode keys (`<Tab>`,
`<CR>`, `<C-space>`). Those exist only while the completion popup is open and
are part of its state machine, so they are configured in
`lua/plugins/completion.lua` and documented there.

## Finding a keybinding

- `<leader>sk` — searchable picker of every active keymap.
- `<Space>` then wait — which-key shows the group under your fingers.
- Or just read `lua/core/keymaps.lua`; it has a section index at the top.

## Adding a plugin

1. Put the spec in whichever `lua/plugins/*.lua` file matches its job.
2. Give it a lazy trigger — `event`, `cmd` or `ft`. Do **not** add `keys`.
3. If it needs bindings, add them to the right section of `core/keymaps.lua`,
   calling `require("the.plugin")` inside the function.
4. If it introduces a new `<leader>x` prefix, add a label to `M.groups` at the
   bottom of `keymaps.lua` so which-key names it.

## Requirements

`git`, `rg`, `fd`, `gcc`/`g++`, `make`, `node` (Copilot), and a Nerd Font.
Language servers, formatters and debug adapters install themselves through
mason on first launch; `:Mason` shows the list.
