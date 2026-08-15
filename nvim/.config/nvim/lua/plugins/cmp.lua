return {
    "hrsh7th/nvim-cmp",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",

        -- 1. Add Copilot and the Copilot-CMP bridge
        "zbirenbaum/copilot-cmp",
        {
            "zbirenbaum/copilot.lua",
            cmd = "Copilot",
            config = function()
                require("copilot").setup({
                    -- Disable default suggestions and panel to avoid clashes
                    suggestion = { enabled = false },
                    panel = { enabled = false },
                })
            end,
        },
    },
    event = "InsertEnter",
    config = function()
        local cmp = require("cmp")

        -- 2. Initialize the copilot-cmp bridge
        require("copilot_cmp").setup()

        cmp.setup({
            snippet = {
                expand = function(args)
                    require("luasnip").lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                ["<C-Space>"] = cmp.mapping.complete(),
                ["<C-e>"] = cmp.mapping.abort(),
                ["<CR>"] = cmp.mapping.confirm({ select = true }),
            }),
            -- 3. Add 'copilot' to your sources list
            sources = cmp.config.sources({
                { name = "copilot", group_index = 2 },
                { name = "nvim_lsp", group_index = 2 },
                { name = "luasnip", group_index = 2 },
            }, {
                { name = "buffer" },
            }),
        })
    end,
}
