return {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
        bigfile = { enabled = true },
        dashboard = { enabled = true },
        explorer = { enabled = true },
        indent = { enabled = true },
        input = { enabled = true },
        notifier = { enabled = true },
        picker = { enabled = true },
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
        map("n", "<leader>sf", function()
            snacks.picker.files()
        end, { desc = "Snacks Files" })
        map("n", "<leader>sg", function()
            snacks.picker.grep()
        end, { desc = "Snacks Grep" })
        map("n", "<leader>sb", function()
            snacks.picker.buffers()
        end, { desc = "Snacks Buffers" })
        map("n", "<leader>sd", function()
            snacks.picker.diagnostics()
        end, { desc = "Snacks Diagnostics" })
        map("n", "<leader>sn", function()
            snacks.notifier.show_history()
        end, { desc = "Notification History" })
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
        map("n", "<leader>un", function()
            snacks.notifier.hide()
        end, { desc = "Dismiss Notifications" })

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
