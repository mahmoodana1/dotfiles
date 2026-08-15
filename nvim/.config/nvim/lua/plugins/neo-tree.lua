return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons", -- optional, for file icons
        "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
        { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "File Tree" },
    },
    opts = {
        filesystem = {
            follow_current_file = { enabled = true }, -- ✅ auto-switch to the opened file's folder
            use_libuv_file_watcher = true,
            filtered_items = {
                hide_dotfiles = true, -- start with dotfiles hidden
            },
            window = {
                mappings = {
                    ["H"] = "toggle_hidden", -- press H to show/hide dotfiles
                },
            },
        },
    },
}
