return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            -- Global diagnostic settings live here so they win: LazyVim applies
            -- its own vim.diagnostic.config() on VeryLazy and used to clobber
            -- anything set earlier in config/lazy.lua.
            diagnostics = {
                virtual_text = true,
                severity_sort = true,
                update_in_insert = false,
            },
            servers = {
                -- pyright (basedpyright was broken in Mason)
                pyright = {
                    settings = {
                        pyright = { disableOrganizeImports = false },
                        python = {
                            analysis = {
                                autoSearchPaths = true,
                                typeCheckingMode = "basic",
                                diagnosticMode = "openFilesOnly",
                                useLibraryCodeForTypes = true,
                            },
                        },
                    },
                },
            },
        },
    },
    {
        "mason-org/mason.nvim",
        opts = { ui = { border = "rounded" } },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "clangd",
                "lua_ls",
                "pyright",
                "html",
                "cssls",
                "ts_ls",
            },
            automatic_installation = true,
        },
        config = function(_, opts)
            require("mason-lspconfig").setup(opts)
        end,
    },
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
        },
    },
}
