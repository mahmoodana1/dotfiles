return {
    { "mfussenegger/nvim-dap" },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
        config = true,
    },
    {
        "jay-babu/mason-nvim-dap.nvim",
        opts = { ensure_installed = { "codelldb", "debugpy" } },
    },
    {
        "mfussenegger/nvim-dap",
        config = function()
            local dap = require("dap")
            local mason = vim.fn.stdpath("data") .. "/mason/packages/"

            -- C/C++ adapter (codelldb)
            local codelldb_path = mason .. "codelldb/extension/adapter/codelldb"
            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = { command = codelldb_path, args = { "--port", "${port}" } },
            }

            -- Python adapter (debugpy)
            dap.adapters.python = {
                type = "executable",
                command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
                args = { "-m", "debugpy.adapter" },
            }

            dap.configurations.python = {
                {
                    type = "python",
                    request = "launch",
                    name = "Launch file",
                    program = "${file}",
                    pythonPath = function()
                        return "python"
                    end,
                },
            }

            for _, lang in ipairs({ "c", "cpp" }) do
                dap.configurations[lang] = {
                    {
                        name = "Launch (C/C++)",
                        type = "codelldb",
                        request = "launch",
                        program = function()
                            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/a.out", "file")
                        end,
                        cwd = "${workspaceFolder}",
                        stopOnEntry = false,
                    },
                }
            end

            -- Keymaps
            local map = vim.keymap.set
            map("n", "<F5>", function()
                dap.continue()
            end, { desc = "Start/Continue" })
            map("n", "<F9>", function()
                dap.toggle_breakpoint()
            end, { desc = "Toggle Breakpoint" })
            map("n", "<F10>", function()
                dap.step_over()
            end, { desc = "Step Over" })
            map("n", "<F11>", function()
                dap.step_into()
            end, { desc = "Step Into" })
            map("n", "<F12>", function()
                dap.step_out()
            end, { desc = "Step Out" })
            map("n", "<leader>du", function()
                require("dapui").toggle()
            end, { desc = "Toggle DAP UI" })
        end,
    },
}
