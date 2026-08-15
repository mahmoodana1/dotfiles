-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "D", vim.diagnostic.open_float, { desc = "Show diagnostics" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]e", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Next error" })
vim.keymap.set("n", "[e", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Previous error" })

-- Compile and Run C/C++ in tmux window
-- <leader>car = Compile And Run
vim.keymap.set("n", "<leader>car", function()
    local filepath = vim.fn.expand("%:p")
    local filename = vim.fn.expand("%:t")
    local basename = vim.fn.expand("%:t:r")
    local extension = vim.fn.expand("%:e")
    local dir = vim.fn.expand("%:p:h")

    -- Determine compiler and flags
    local compiler = ""
    local flags = "-Wall -Wextra"
    if extension == "c" then
        compiler = "gcc"
    elseif extension == "cpp" or extension == "cc" or extension == "cxx" then
        compiler = "g++"
    else
        vim.notify("Not a C/C++ file", vim.log.levels.ERROR)
        return
    end

    -- Compile command
    local compile_cmd = string.format("%s %s %s -o %s", compiler, flags, filename, basename)

    -- Check if we're inside tmux
    if vim.env.TMUX == nil then
        vim.notify("Not running inside tmux. Using built-in terminal.", vim.log.levels.WARN)
        -- Fallback to terminal split in nvim
        vim.cmd("split")
        vim.cmd("term " .. compile_cmd .. " && ./" .. basename)
        vim.cmd("startinsert")
        return
    end

    -- Inside tmux: create or reuse a window named "run"
    -- Check if window exists
    local window_exists =
        vim.fn.system('tmux list-windows -F "#{window_name}" 2>/dev/null | grep -q "^run$" && echo "yes"')

    if vim.v.shell_error == 0 then
        -- Window exists, switch to it
        vim.fn.system("tmux select-window -t 'run'")
        -- Clear the window (send Ctrl+l)
        vim.fn.system("tmux send-keys -t 'run' C-l")
    else
        -- Create new window named "run"
        vim.fn.system("tmux new-window -n 'run' -c '" .. dir .. "'")
    end

    -- Send compile and run commands
    vim.fn.system(string.format("tmux send-keys -t 'run' 'cd %s' Enter", dir))
    vim.fn.system(string.format("tmux send-keys -t 'run' '%s' Enter", compile_cmd))
    vim.fn.system(string.format("tmux send-keys -t 'run' './%s' Enter", basename))

    vim.notify("Compiled and running in tmux window 'run'", vim.log.levels.INFO)
end, { desc = "Compile and run C/C++ in tmux window" })
