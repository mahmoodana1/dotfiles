-- ===========================================================================
--  COMPLETION -- blink.cmp with Copilot as a source
--
--  blink.cmp owns the insert-mode completion keys (<C-space>, <Tab>, <CR>,
--  <C-e>). Those are configured here rather than in core/keymaps.lua because
--  they only exist while the completion menu is open -- they are part of the
--  menu's own state machine, not global bindings. Everything that works
--  outside a popup is still in core/keymaps.lua.
-- ===========================================================================

return {
    -- --- Copilot: suggestions go into the completion menu, not as ghost text
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        opts = {
            suggestion = { enabled = false }, -- blink renders them instead
            panel = { enabled = false },
            filetypes = { markdown = true, gitcommit = true },
        },
    },

    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        version = "*", -- release build, no rust toolchain needed
        dependencies = {
            "rafamadriz/friendly-snippets",
            { "fang2hou/blink-copilot", dependencies = "zbirenbaum/copilot.lua" },
        },
        opts = {
            keymap = {
                preset = "default", -- <C-space> menu, <C-n>/<C-p> cycle, <C-e> hide
                ["<CR>"] = { "accept", "fallback" },
                ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                ["<C-j>"] = { "select_next", "fallback" },
                ["<C-k>"] = { "select_prev", "fallback" },
            },
            appearance = { nerd_font_variant = "mono" },
            completion = {
                accept = { auto_brackets = { enabled = true } },
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
                menu = {
                    border = "rounded",
                    draw = {
                        treesitter = { "lsp" },
                        columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
                    },
                },
                ghost_text = { enabled = true },
            },
            signature = { enabled = true, window = { border = "rounded" } },
            sources = {
                default = { "copilot", "lsp", "path", "snippets", "buffer" },
                providers = {
                    copilot = {
                        name = "copilot",
                        module = "blink-copilot",
                        score_offset = 100, -- float Copilot to the top
                        async = true,
                    },
                },
            },
        },
    },
}
