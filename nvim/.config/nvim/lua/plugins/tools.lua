-- ===========================================================================
--  TOOLS -- terminal, Claude Code, debugger
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. See
--  lua/core/keymaps.lua.
-- ===========================================================================

return {
    -- --- Terminal ----------------------------------------------------------
    {
        "akinsho/toggleterm.nvim",
        cmd = { "ToggleTerm", "TermExec" },
        opts = {
            size = 20,
            autochdir = true,
            direction = "float",
            start_in_insert = true,
            insert_mappings = false, -- don't hijack <C-/> while typing
            terminal_mappings = true,
            close_on_exit = true,
            float_opts = { border = "rounded" },
        },
    },

    -- --- Claude Code -------------------------------------------------------
    {
        "coder/claudecode.nvim",
        cmd = { "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend", "ClaudeCodeAdd" },
        dependencies = { "folke/snacks.nvim" },
        opts = {},
    },

    -- --- Debugger ----------------------------------------------------------
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            {
                "rcarriga/nvim-dap-ui",
                dependencies = { "nvim-neotest/nvim-nio" },
                opts = {},
            },
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")
            local mason = vim.fn.stdpath("data") .. "/mason/packages/"

            -- C / C++ via codelldb
            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = {
                    command = mason .. "codelldb/extension/adapter/codelldb",
                    args = { "--port", "${port}" },
                },
            }
            for _, lang in ipairs({ "c", "cpp" }) do
                dap.configurations[lang] = {
                    {
                        name = "Launch (C/C++)",
                        type = "codelldb",
                        request = "launch",
                        program = function()
                            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
                        end,
                        cwd = "${workspaceFolder}",
                        stopOnEntry = false,
                    },
                }
            end

            -- Python via debugpy
            dap.adapters.python = {
                type = "executable",
                command = mason .. "debugpy/venv/bin/python",
                args = { "-m", "debugpy.adapter" },
            }
            dap.configurations.python = {
                {
                    type = "python",
                    request = "launch",
                    name = "Launch file",
                    program = "${file}",
                    pythonPath = function()
                        return vim.g.python3_host_prog or "python3"
                    end,
                },
            }

            -- Open the UI when a session starts, close it when it ends.
            dap.listeners.after.event_initialized["dapui"] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui"] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui"] = function()
                dapui.close()
            end

            vim.fn.sign_define("DapBreakpoint", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
            vim.fn.sign_define("DapStopped", { text = " ", texthl = "DiagnosticWarn", linehl = "Visual", numhl = "" })
        end,
    },
}
