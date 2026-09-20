-- ===========================================================================
--  GIT -- signs, blame, lazygit
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. The hunk
--  bindings are buffer-local and live in core/keymaps.lua
--  (M.on_gitsigns_attach), wired up through gitsigns' on_attach below.
-- ===========================================================================

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            current_line_blame = true,
            current_line_blame_opts = { delay = 400, virt_text_pos = "eol" },
            signs = {
                add = { text = "▎" },
                change = { text = "▎" },
                delete = { text = "" },
                topdelete = { text = "" },
                changedelete = { text = "▎" },
                untracked = { text = "▎" },
            },
            on_attach = function(bufnr)
                require("core.keymaps").on_gitsigns_attach(bufnr)
            end,
        },
    },

    {
        "kdheepak/lazygit.nvim",
        cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        init = function()
            vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
        end,
    },
}
