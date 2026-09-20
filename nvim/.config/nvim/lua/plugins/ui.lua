-- ===========================================================================
--  UI -- colourscheme, statusline, bufferline, icons, notifications, which-key
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. See
--  lua/core/keymaps.lua.
-- ===========================================================================

return {
    -- --- Colourscheme ------------------------------------------------------
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        opts = {
            flavour = "mocha",
            -- Let the terminal's own background (and its opacity) show
            -- through instead of painting #1e1e2e over it. This is what makes
            -- nvim match alacritty's translucent look.
            transparent_background = true,
            styles = {
                comments = { "italic" },
                conditionals = { "italic" },
            },
            integrations = {
                blink_cmp = true,
                gitsigns = true,
                lsp_trouble = true,
                mason = true,
                mini = { enabled = true },
                native_lsp = { enabled = true, underlines = { errors = { "undercurl" } } },
                noice = true,
                notify = true,
                snacks = true,
                telescope = { enabled = true },
                treesitter = true,
                which_key = true,
            },
        },
        config = function(_, opts)
            require("catppuccin").setup(opts)
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- --- Icons -------------------------------------------------------------
    -- mini.icons is the single icon provider. The package.preload shim makes
    -- every `require("nvim-web-devicons")` -- from telescope, bufferline,
    -- lualine, snacks -- resolve here, so one glyph table drives the whole UI.
    -- Registering the shim in `init` (not `config`) is what keeps it
    -- deterministic: it is in place before any plugin can ask for icons.
    {
        "nvim-mini/mini.icons",
        lazy = true,
        opts = {
            file = {
                [".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
                [".gitignore"] = { glyph = "", hl = "MiniIconsGrey" },
                ["stylua.toml"] = { glyph = "󰢱", hl = "MiniIconsBlue" },
                ["compile_commands.json"] = { glyph = "", hl = "MiniIconsYellow" },
            },
            filetype = {
                dotenv = { glyph = "", hl = "MiniIconsYellow" },
            },
        },
        init = function()
            package.preload["nvim-web-devicons"] = function()
                require("mini.icons").mock_nvim_web_devicons()
                return package.loaded["nvim-web-devicons"]
            end
        end,
    },

    -- --- Statusline --------------------------------------------------------
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = function()
            return {
                options = {
                    theme = "catppuccin",
                    globalstatus = true,
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" },
                    disabled_filetypes = { statusline = { "snacks_dashboard" } },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch" },
                    lualine_c = {
                        {
                            "diagnostics",
                            symbols = { error = " ", warn = " ", info = " ", hint = " " },
                        },
                        { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                        { "filename", path = 1 },
                    },
                    lualine_x = {
                        -- Shows the spinner while an LSP or formatter is busy.
                        {
                            function()
                                return require("noice").api.status.command.get()
                            end,
                            cond = function()
                                return package.loaded["noice"] and require("noice").api.status.command.has()
                            end,
                        },
                        { "diff", symbols = { added = " ", modified = " ", removed = " " } },
                    },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
                extensions = { "lazy", "mason", "trouble", "toggleterm", "nvim-dap-ui" },
            }
        end,
    },

    -- --- Bufferline --------------------------------------------------------
    {
        "akinsho/bufferline.nvim",
        event = "VeryLazy",
        opts = {
            options = {
                diagnostics = "nvim_lsp",
                always_show_bufferline = false,
                show_buffer_close_icons = false,
                separator_style = "slant",
                offsets = {
                    { filetype = "snacks_layout_box", text = "Explorer", highlight = "Directory" },
                },
            },
        },
    },

    -- --- Command line, messages, popupmenu ---------------------------------
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = { "MunifTanjim/nui.nvim" },
        opts = {
            lsp = {
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                },
            },
            presets = {
                bottom_search = true,
                command_palette = true,
                long_message_to_split = true,
                lsp_doc_border = true,
            },
            routes = {
                -- "written" / "N lines" noise on every save.
                { filter = { event = "msg_show", find = "written" }, opts = { skip = true } },
                { filter = { event = "msg_show", find = "lines" }, opts = { skip = true } },
            },
        },
    },

    -- --- Key hints ---------------------------------------------------------
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "helix",
            -- Group labels live next to the bindings they describe.
            spec = require("core.keymaps").groups,
        },
    },

    -- --- Cursor sugar ------------------------------------------------------
    {
        "sphamba/smear-cursor.nvim",
        event = "VeryLazy",
        opts = {
            stiffness = 0.8,
            trailing_stiffness = 0.5,
            distance_stop_animating = 0.5,
        },
    },
    {
        "ya2s/nvim-cursorline",
        event = "VeryLazy",
        opts = {
            cursorline = { enable = true, timeout = 1000, number = false },
            cursorword = { enable = true, min_length = 3, hl = { underline = true } },
        },
        config = function(_, opts)
            require("nvim-cursorline").setup(opts)
        end,
    },
}
