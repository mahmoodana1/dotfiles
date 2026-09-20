-- ===========================================================================
--  EDITOR -- snacks, telescope, flash, trouble, todo, sessions, multi-cursor
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. See
--  lua/core/keymaps.lua.
-- ===========================================================================

return {
    -- --- snacks: explorer, dashboard, indent guides, scratch, zen, ... ------
    -- Eager, because core/keymaps.lua calls Snacks.toggle at startup to build
    -- the <leader>u bindings.
    {
        "folke/snacks.nvim",
        lazy = false,
        priority = 900,
        opts = {
            bigfile = { enabled = true }, -- disable heavy features on huge files
            quickfile = { enabled = true }, -- render the file before plugins load
            indent = { enabled = true },
            scope = { enabled = true },
            scroll = { enabled = true },
            words = { enabled = true }, -- ]] / [[ jump between references
            input = { enabled = true },
            notifier = { enabled = true, timeout = 3000 },
            statuscolumn = { enabled = true },
            bufdelete = { enabled = true },
            rename = { enabled = true },
            gitbrowse = { enabled = true },
            zen = { enabled = true },
            scratch = { enabled = true },
            toggle = { enabled = true },

            -- The file tree. Picker must be on for it; the picker keymaps are
            -- ours (telescope), so there is nothing for it to collide with.
            explorer = { enabled = true, replace_netrw = true },
            picker = {
                enabled = true,
                sources = {
                    explorer = {
                        layout = { preset = "sidebar", preview = false },
                        hidden = false, -- H toggles dotfiles
                        follow_file = true,
                        watch = true,
                    },
                },
            },

            dashboard = {
                enabled = true,
                preset = {
                    keys = {
                        { icon = " ", key = "f", desc = "Find file", action = ":lua Snacks.dashboard.pick('files')" },
                        { icon = " ", key = "n", desc = "New file", action = ":ene | startinsert" },
                        {
                            icon = " ",
                            key = "g",
                            desc = "Find text",
                            action = ":lua Snacks.dashboard.pick('live_grep')",
                        },
                        {
                            icon = " ",
                            key = "r",
                            desc = "Recent files",
                            action = ":lua Snacks.dashboard.pick('oldfiles')",
                        },
                        {
                            icon = " ",
                            key = "c",
                            desc = "Config",
                            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
                        },
                        { icon = " ", key = "s", desc = "Restore session", section = "session" },
                        { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy" },
                        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
                    },
                },
                sections = {
                    { section = "header" },
                    { section = "keys", gap = 1, padding = 1 },
                    { section = "startup" },
                },
            },
        },
    },

    -- --- Picker ------------------------------------------------------------
    {
        "nvim-telescope/telescope.nvim",
        cmd = "Telescope",
        dependencies = {
            "nvim-lua/plenary.nvim",
            {
                -- Native fzf sorter: makes large repos feel instant.
                "nvim-telescope/telescope-fzf-native.nvim",
                build = "make",
                enabled = vim.fn.executable("make") == 1,
            },
        },
        opts = function()
            local actions = require("telescope.actions")
            return {
                defaults = {
                    prompt_prefix = "   ",
                    selection_caret = "  ",
                    path_display = { "truncate" },
                    sorting_strategy = "ascending",
                    layout_config = {
                        horizontal = { prompt_position = "top", preview_width = 0.55 },
                        width = 0.87,
                        height = 0.80,
                    },
                    file_ignore_patterns = { "%.git/", "node_modules/", "__pycache__/", "%.venv/" },
                    mappings = {
                        i = {
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
                            ["<Esc>"] = actions.close, -- one Esc, not two
                            ["<C-u>"] = false, -- let <C-u> clear the prompt
                        },
                    },
                },
                pickers = {
                    find_files = { hidden = true },
                    buffers = { sort_mru = true, ignore_current_buffer = true },
                },
            }
        end,
        config = function(_, opts)
            local telescope = require("telescope")
            telescope.setup(opts)
            pcall(telescope.load_extension, "fzf")
        end,
    },

    -- --- Jump motions ------------------------------------------------------
    { "folke/flash.nvim", event = "VeryLazy", opts = {} },

    -- --- Diagnostics / quickfix list ---------------------------------------
    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        opts = { focus = true },
    },

    -- --- TODO / FIXME highlighting + :TodoTelescope ------------------------
    {
        "folke/todo-comments.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {},
    },

    -- --- Sessions ----------------------------------------------------------
    {
        "folke/persistence.nvim",
        event = "BufReadPre",
        opts = {},
    },

    -- --- Multiple cursors --------------------------------------------------
    -- Self-contained \\c / <C-n> bindings of its own; left as-is deliberately
    -- because remapping them to <leader> would fight its visual-mode machinery.
    { "mg979/vim-visual-multi", event = "VeryLazy" },

    -- --- Search and replace across files ( :GrugFar ) ----------------------
    { "MagicDuck/grug-far.nvim", cmd = "GrugFar", opts = { headerMaxWidth = 80 } },

    -- --- Small editing helpers ---------------------------------------------
    { "echasnovski/mini.pairs", event = "InsertEnter", opts = {} },
    { "echasnovski/mini.ai", event = "VeryLazy", opts = {} },
    { "folke/ts-comments.nvim", event = "VeryLazy", opts = {} },
}
