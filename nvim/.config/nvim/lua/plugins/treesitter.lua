return {
    { "nvim-lualine/lualine.nvim", opts = { options = { theme = "catppuccin" } } },
    { "akinsho/bufferline.nvim", version = "*", opts = { options = { diagnostics = "nvim_lsp" } } },
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
}
