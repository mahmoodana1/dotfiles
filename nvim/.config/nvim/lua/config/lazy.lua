local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        -- add LazyVim and import its plugins
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        -- import/override with your plugins
        { import = "plugins" },
    },
    defaults = {
        -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
        -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
        lazy = false,
        -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
        -- have outdated releases, which may break your Neovim install.
        version = false, -- always use the latest git commit
        -- version = "*", -- try installing the latest stable version for plugins that support semver
    },
    install = { colorscheme = { "tokyonight", "habamax" } },
    checker = {
        enabled = true, -- check for plugin updates periodically
        notify = false, -- notify on update
    }, -- automatically check for plugin updates
    performance = {
        rtp = {
            -- disable some rtp plugins
            disabled_plugins = {
                "gzip",
                -- "matchit",
                -- "matchparen",
                -- "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})

vim.bo.modifiable = true
vim.bo.readonly = false
vim.opt.termguicolors = true

-- Custom LSP configurations
local lspconfig = require("lspconfig")

-- 🐍 Python LSP (pyright — basedpyright was broken in Mason)
lspconfig.pyright.setup({
    settings = {
        pyright = {
            disableOrganizeImports = false,
        },
        python = {
            analysis = {
                autoSearchPaths = true,
                typeCheckingMode = "basic",
                diagnosticMode = "openFilesOnly",
                useLibraryCodeForTypes = true,
            },
        },
    },
})

-- ⚙️ Global diagnostic settings
vim.diagnostic.config({
    virtual_text = true, -- show inline warnings
    severity_sort = true, -- sort by severity
    update_in_insert = false, -- don't recheck while typing (keep it light)
})

-- Helper: keymap to toggle diagnostics on/off
vim.keymap.set("n", "<leader>ud", function()
    local state = vim.diagnostic.config().virtual_text
    vim.diagnostic.config({ virtual_text = not state })
    vim.notify("Diagnostics " .. (state and "hidden" or "visible"), vim.log.levels.INFO)
end, { desc = "Toggle diagnostics" })
