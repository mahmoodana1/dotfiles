-- ===========================================================================
--  LSP + FORMATTING
--
--  Neovim 0.12 has a native LSP config API, so there is no lspconfig
--  `setup()` call anywhere here. nvim-lspconfig is installed only for the
--  server definitions it ships in its `lsp/` directory; `vim.lsp.config`
--  layers our settings on top and `vim.lsp.enable` turns them on.
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. LSP bindings
--  are buffer-local and live in core/keymaps.lua (M.on_lsp_attach), applied
--  by the LspAttach autocmd.
-- ===========================================================================

-- Servers to run. Key = name as nvim-lspconfig knows it, value = settings
-- merged over its defaults (empty table means "defaults are fine").
local servers = {
    clangd = {
        cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
    },
    lua_ls = {
        settings = {
            Lua = {
                workspace = { checkThirdParty = false },
                codeLens = { enable = true },
                hint = { enable = true },
                diagnostics = { globals = { "vim", "Snacks" } },
            },
        },
    },
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
    html = {},
    cssls = {},
    ts_ls = {},
}

return {
    -- --- Installer for servers, formatters and debug adapters --------------
    {
        "mason-org/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        opts = {
            ui = {
                border = "rounded",
                icons = { package_installed = "", package_pending = "", package_uninstalled = "" },
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "mason-org/mason.nvim",
            "neovim/nvim-lspconfig",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
        },
        config = function()
            require("mason").setup({ ui = { border = "rounded" } })

            -- Formatters and debug adapters (not LSP servers, so not handled
            -- by mason-lspconfig). stylua and black are missing system-wide,
            -- so mason provides them.
            require("mason-tool-installer").setup({
                ensure_installed = { "stylua", "black", "clang-format", "codelldb", "debugpy" },
                run_on_start = true,
            })

            require("mason-lspconfig").setup({
                ensure_installed = vim.tbl_keys(servers),
                -- We call vim.lsp.enable ourselves below so the order is
                -- explicit and visible.
                automatic_enable = false,
            })

            -- Completion capabilities from blink.cmp, applied to every server.
            local ok, blink = pcall(require, "blink.cmp")
            local capabilities = ok and blink.get_lsp_capabilities() or vim.lsp.protocol.make_client_capabilities()

            vim.lsp.config("*", { capabilities = capabilities })
            for name, cfg in pairs(servers) do
                if next(cfg) ~= nil then
                    vim.lsp.config(name, cfg)
                end
            end
            vim.lsp.enable(vim.tbl_keys(servers))

            -- --- Diagnostic presentation ---------------------------------
            vim.diagnostic.config({
                virtual_text = { spacing = 4, source = "if_many", prefix = "●" },
                severity_sort = true,
                update_in_insert = false,
                underline = true,
                float = { border = "rounded", source = "if_many" },
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = " ",
                        [vim.diagnostic.severity.WARN] = " ",
                        [vim.diagnostic.severity.INFO] = " ",
                        [vim.diagnostic.severity.HINT] = " ",
                    },
                },
            })
        end,
    },

    -- --- Lua development: types for the nvim API ---------------------------
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                { path = "snacks.nvim", words = { "Snacks" } },
            },
        },
    },

    -- --- Formatting --------------------------------------------------------
    -- Format-on-save is driven by the BufWritePre autocmd in core/autocmds.lua
    -- and toggled with <leader>uf. conform's own format_on_save is deliberately
    -- NOT used, so there is exactly one code path that formats a buffer.
    {
        "stevearc/conform.nvim",
        cmd = "ConformInfo",
        event = "BufWritePre",
        opts = {
            default_format_opts = {
                timeout_ms = 1500,
                async = false,
                quiet = false,
                lsp_format = "never",
            },
            formatters_by_ft = {
                lua = { "stylua" },
                c = { "clang-format" },
                cpp = { "clang-format" },
                python = { "black" },
                sh = { "shfmt" },
            },
            formatters = {
                ["clang-format"] = {
                    prepend_args = { "--style={BasedOnStyle: LLVM, IndentWidth: 4, TabWidth: 4, UseTab: Never}" },
                },
                stylua = { prepend_args = { "--indent-width", "4", "--indent-type", "Spaces" } },
                black = { prepend_args = { "--line-length", "100" } },
            },
        },
    },
}
