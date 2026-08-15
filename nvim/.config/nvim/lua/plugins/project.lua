return {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
    config = function()
        require("project_nvim").setup({
            -- 🔍 Detect root by LSP or pattern, but skip overriding manual cwd
            detection_methods = { "lsp", "pattern" },
            patterns = { ".git", "Makefile", "pyproject.toml", "compile_commands.json" },
            manual_mode = true, -- ✅ don’t change root automatically
            silent_chdir = false,
        })

        -- 🧭 If cwd is empty (like when launched from home), fallback to project root
        vim.api.nvim_create_autocmd("BufEnter", {
            callback = function()
                local homedir = vim.fn.expand("~")
                local cwd = vim.fn.getcwd()
                local project_root = require("project_nvim.project").get_project_root()
                if cwd == homedir and project_root and project_root ~= cwd then
                    vim.cmd("lcd " .. project_root)
                end
            end,
        })
    end,
}
