return {
    "stevearc/conform.nvim",
    opts = function(_, opts)
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
        opts.format_on_save = function(_)
            return { lsp_fallback = false, timeout_ms = 1000 }
        end
    end,
}
