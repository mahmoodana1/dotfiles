return {
    "stevearc/conform.nvim",
    opts = function(_, opts)
        -- NOTE: do NOT set `opts.format_on_save` / `opts.format_after_save` here.
        -- LazyVim strips them at setup and warns every launch, which is why
        -- format-on-save behaved differently from session to session.
        -- LazyVim already runs conform on BufWritePre; toggle it with <leader>uf.
        opts.default_format_opts = vim.tbl_extend("force", opts.default_format_opts or {}, {
            timeout_ms = 1000,
            lsp_format = "never", -- was `lsp_fallback = false`
        })

        opts.formatters_by_ft = vim.tbl_extend("force", opts.formatters_by_ft or {}, {
            lua = { "stylua" },
            c = { "clang-format" },
            cpp = { "clang-format" },
            python = { "black" },
        })

        opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
            ["clang-format"] = {
                prepend_args = { "--style={BasedOnStyle: LLVM, IndentWidth: 4, TabWidth: 4, UseTab: Never}" },
            },
            stylua = { prepend_args = { "--indent-width", "4", "--indent-type", "Spaces" } },
            black = { prepend_args = { "--line-length", "100" } },
        })
    end,
}
