return {
    { "nvim-lualine/lualine.nvim", opts = { options = { theme = "auto" } } },
    { "akinsho/bufferline.nvim", version = "*", opts = { options = { diagnostics = "nvim_lsp" } } },
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

    -- Icons: LazyVim already ships `mini.icons` and installs a `package.preload`
    -- shim so every `require("nvim-web-devicons")` transparently resolves to it.
    -- Don't re-declare or re-mock it here: doing so raced with that shim and made
    -- icons differ between the explorer / bufferline / lualine from session to session.
    -- Only extend its glyph table.
    {
        "nvim-mini/mini.icons",
        opts = {
            file = {
                -- re-stating LazyVim's own two overrides: its opts for this
                -- plugin are not merged into ours
                [".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
                ["devcontainer.json"] = { glyph = "", hl = "MiniIconsAzure" },
                [".gitignore"] = { glyph = "", hl = "MiniIconsGrey" },
                ["stylua.toml"] = { glyph = "󰢱", hl = "MiniIconsBlue" },
            },
            filetype = {
                dotenv = { glyph = "", hl = "MiniIconsYellow" },
            },
        },
    },
}
