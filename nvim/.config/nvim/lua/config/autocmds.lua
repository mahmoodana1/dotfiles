-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Kept this minimal; BufEnter `lcd` was removed as it can interfere with LSP project-root detection.

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*",
    callback = function()
        if vim.bo.buftype ~= "" then
            vim.bo.swapfile = false
        end
    end,
})

vim.api.nvim_create_autocmd("SwapExists", {
    callback = function()
        vim.v.swapchoice = "e" -- edit anyway
    end,
})
