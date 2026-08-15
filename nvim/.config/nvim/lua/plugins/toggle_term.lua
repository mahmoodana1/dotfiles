return {
    "akinsho/toggleterm.nvim",
    version = "*",
    event = "VeryLazy",
    config = function()
        require("toggleterm").setup({
            size = 20,
            autochdir = true,
            direction = "float",
            start_in_insert = true,
            insert_mappings = false, -- 👈 IMPORTANT
            close_on_exit = true,
        })
    end,
}
