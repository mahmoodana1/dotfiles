-- ===========================================================================
--  TREESITTER -- syntax, indentation, textobjects, folds
--
--  Your old lua/plugins/treesitter.lua contained no treesitter at all -- it
--  was a copy of ui.lua's first three lines, which is why lualine had two
--  conflicting themes. This is the real thing.
-- ===========================================================================

return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- Pinned to master on purpose. The `main` branch is a rewrite that
        -- removed `nvim-treesitter.configs`; master is the stable classic API
        -- that the docs and every example still describe.
        branch = "master",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        cmd = { "TSUpdate", "TSInstall", "TSInstallInfo" },
        dependencies = {
            { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
        },
        opts = {
            ensure_installed = {
                "bash",
                "c",
                "cpp",
                "cmake",
                "css",
                "diff",
                "gitcommit",
                "gitignore",
                "html",
                "javascript",
                "json",
                "jsonc",
                "lua",
                "luadoc",
                "make",
                "markdown",
                "markdown_inline",
                "python",
                "query",
                "regex",
                "toml",
                "tsx",
                "typescript",
                "vim",
                "vimdoc",
                "yaml",
            },
            highlight = { enable = true },
            indent = { enable = true },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        -- Textobjects, not keybindings: these only mean
                        -- anything after an operator (d, c, y, v).
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
                    goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
                },
            },
        },
        config = function(_, opts)
            require("nvim-treesitter.configs").setup(opts)
        end,
    },

    -- Auto-close and rename HTML/JSX tags.
    { "windwp/nvim-ts-autotag", ft = { "html", "javascript", "typescript", "typescriptreact", "xml" }, opts = {} },
}
