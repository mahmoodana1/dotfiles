return {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    -- LazyVim registers its snacks-picker keymaps whenever `vim.g.lazyvim_picker`
    -- resolves to snacks (the `auto` default) -- the `picker.enabled` flag below
    -- only gates auto-setup, not the keys. These three are also declared by
    -- telescope.lua, and whichever plugin got mapped last won, so <leader>ff
    -- flipped between the two pickers between launches. Give them to telescope;
    -- everything else (dashboard buttons, <leader>fc, searches) stays on snacks.
    keys = {
        { "<leader>ff", false },
        { "<leader>fg", false },
        { "<leader>fb", false },
    },
    opts = {
        bigfile = { enabled = true },
        dashboard = { enabled = true },
        -- Snacks.explorer owns <leader>e / <leader>E / <leader>fe / <leader>fE
        -- (declared by LazyVim's snacks spec). Enabled here so it also replaces
        -- netrw when you open a directory.
        explorer = { enabled = true },
        indent = { enabled = true },
        input = { enabled = false },
        notifier = { enabled = false },
        -- Left off deliberately: turning this on makes LazyVim register its own
        -- <leader>ff / <leader>fb picker maps, which would collide with the ones
        -- telescope.lua declares -- the same double-ownership bug <leader>e had.
        picker = { enabled = false },
        quickfile = { enabled = true },
        scope = { enabled = true },
        scroll = { enabled = true },
        statuscolumn = { enabled = true },
        toggle = { enabled = true },
        words = { enabled = true },
    },
    config = function(_, opts)
        local snacks = require("snacks")
        snacks.setup(opts)

        local map = vim.keymap.set
        map("n", "<leader>z", function()
            snacks.zen()
        end, { desc = "Toggle Zen Mode" })
        map("n", "<leader>Z", function()
            snacks.zen.zoom()
        end, { desc = "Toggle Zoom" })
        map("n", "<leader>.", function()
            snacks.scratch()
        end, { desc = "Scratch Buffer" })
        map("n", "<leader>S", function()
            snacks.scratch.select()
        end, { desc = "Select Scratch Buffer" })
        map({ "n", "t" }, "]]", function()
            snacks.words.jump(vim.v.count1)
        end, { desc = "Next Reference" })
        map({ "n", "t" }, "[[", function()
            snacks.words.jump(-vim.v.count1)
        end, { desc = "Previous Reference" })

        snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        snacks.toggle.diagnostics():map("<leader>ud")
        snacks.toggle.line_number():map("<leader>ul")
        snacks.toggle
            .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
            :map("<leader>uc")
        snacks.toggle.treesitter():map("<leader>uT")
        snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
        snacks.toggle.inlay_hints():map("<leader>uh")
        snacks.toggle.indent():map("<leader>ug")
        snacks.toggle.dim():map("<leader>uD")
    end,
}
