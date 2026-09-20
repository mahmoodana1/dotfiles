-- ===========================================================================
--  AUTOCOMMANDS -- every autocmd in the config
-- ===========================================================================

local keymaps = require("core.keymaps")

---@param name string
local function augroup(name)
    return vim.api.nvim_create_augroup("mahmood_" .. name, { clear = true })
end

-- --- Briefly highlight whatever was just yanked ----------------------------
vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function()
        vim.hl.on_yank({ timeout = 150 })
    end,
})

-- --- Restore the cursor to its last position in a file ---------------------
vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("last_location"),
    callback = function(ev)
        if vim.b[ev.buf].last_loc then
            return
        end
        vim.b[ev.buf].last_loc = true
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- --- LSP: attach the buffer-local keymaps from core/keymaps.lua ------------
vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup("lsp_attach"),
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client then
            keymaps.on_lsp_attach(client, ev.buf)
        end
    end,
})

-- --- Format on save --------------------------------------------------------
-- Toggled with <leader>uf. vim.g.autoformat is the default, b:autoformat is a
-- per-buffer override; `nil` on the buffer means "follow the global".
vim.g.autoformat = true
vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("format_on_save"),
    callback = function(ev)
        local enabled = vim.b[ev.buf].autoformat
        if enabled == nil then
            enabled = vim.g.autoformat
        end
        if enabled then
            require("conform").format({ bufnr = ev.buf, lsp_format = "never", timeout_ms = 1500 })
        end
    end,
})

-- --- Terminal windows ------------------------------------------------------
vim.api.nvim_create_autocmd("TermOpen", {
    group = augroup("terminal"),
    callback = function(ev)
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
        vim.opt_local.spell = false
        keymaps.on_term_open(ev.buf)
    end,
})

-- --- Close throwaway windows with plain `q` --------------------------------
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = {
        "help",
        "man",
        "qf",
        "checkhealth",
        "lspinfo",
        "startuptime",
        "dap-float",
        "notify",
        "grug-far",
    },
    callback = function(ev)
        vim.bo[ev.buf].buflisted = false
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true, desc = "Close window" })
    end,
})

-- --- Wrap and spellcheck in prose buffers ----------------------------------
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("prose"),
    pattern = { "markdown", "gitcommit", "text" },
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.spell = true
        vim.opt_local.linebreak = true
    end,
})

-- --- Two-space indent where that is the community norm ---------------------
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("indent_width"),
    pattern = { "html", "css", "scss", "javascript", "typescript", "typescriptreact", "json", "jsonc", "yaml", "lua" },
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
        vim.opt_local.softtabstop = 2
    end,
})

-- --- Create missing parent directories on save -----------------------------
vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("auto_mkdir"),
    callback = function(ev)
        if ev.match:match("^%w%w+://") then
            return
        end
        vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
    end,
})

-- --- Resize splits when the terminal window changes size -------------------
vim.api.nvim_create_autocmd("VimResized", {
    group = augroup("resize_splits"),
    callback = function()
        local current = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current)
    end,
})

-- --- Never leave a swapfile prompt in the way ------------------------------
vim.api.nvim_create_autocmd("SwapExists", {
    group = augroup("swap"),
    callback = function()
        vim.v.swapchoice = "e" -- edit anyway
    end,
})
