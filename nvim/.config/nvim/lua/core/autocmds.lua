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

-- --- Notebooks: .ipynb opens as Markdown via jupytext, saves back ----------
-- Piped through stdin/stdout: no temp files beside the notebook and no
-- jupytext pairing checks. --update keeps outputs and metadata in the .ipynb.
-- Cells are ```python blocks; keys in keymaps.lua section 17.
local jupytext = vim.fn.expand("~/.virtualenvs/nvim/bin/jupytext")
local nb_filters = { "--opt", "notebook_metadata_filter=-all", "--opt", "cell_metadata_filter=-all" }
local notebook = augroup("notebook")

vim.api.nvim_create_autocmd("BufReadCmd", {
    group = notebook,
    pattern = "*.ipynb",
    callback = function(ev)
        local lines = {}
        if vim.fn.getfsize(ev.match) > 0 then
            local cmd = vim.list_extend({ jupytext, "--to", "md", "-q", "-o", "-", ev.match }, nb_filters)
            local res = vim.system(cmd, { text = true }):wait()
            if res.code ~= 0 then
                -- nofile: a half-read notebook must never be saved over the real one
                vim.bo[ev.buf].buftype = "nofile"
                vim.notify("jupytext could not read " .. ev.match .. ":\n" .. res.stderr, vim.log.levels.ERROR)
                return
            end
            lines = vim.split(res.stdout, "\n")
            if lines[#lines] == "" then
                table.remove(lines)
            end
        end
        -- no undo step for the load itself, so `u` can't blank the buffer
        local ul = vim.bo[ev.buf].undolevels
        vim.bo[ev.buf].undolevels = -1
        vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
        vim.bo[ev.buf].undolevels = ul
        vim.bo[ev.buf].modified = false
        -- acwrite: BufWriteCmd below does the saving; plugins/notebook.lua keys
        -- its render-markdown look off this, so plain .md keeps ui.lua's style
        vim.bo[ev.buf].buftype = "acwrite"
        vim.bo[ev.buf].filetype = "markdown"
    end,
})

-- Save goes through jupytext's Python API, not the CLI: `--update` from stdin
-- either trips the pairing check or drops metadata.kernelspec. This merges
-- the edited text with the old notebook (outputs, ids, counts) and keeps the
-- notebook metadata as-is, since the text view never shows it.
local nb_save = [[
import os, sys, jupytext
from jupytext.combine import combine_inputs_with_outputs
path = sys.argv[1]
new = jupytext.reads(sys.stdin.read(), fmt="md")
if os.path.exists(path) and os.path.getsize(path) > 0:
    old = jupytext.read(path, fmt="ipynb")
    new.metadata["jupytext"] = {"notebook_metadata_filter": "-all", "cell_metadata_filter": "-all"}
    new = combine_inputs_with_outputs(new, old)
    new.metadata = old.metadata
else:
    new.metadata = {"kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"}}
jupytext.write(new, path, fmt="ipynb")
]]

vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = notebook,
    pattern = "*.ipynb",
    callback = function(ev)
        local cmd = { vim.g.python3_host_prog, "-c", nb_save, ev.match }
        local text = table.concat(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false), "\n") .. "\n"
        local res = vim.system(cmd, { stdin = text, text = true }):wait()
        if res.code ~= 0 then
            vim.notify("jupytext could not save " .. ev.match .. ":\n" .. res.stderr, vim.log.levels.ERROR)
            return -- buffer stays modified, nothing lost
        end
        vim.bo[ev.buf].modified = false
    end,
})

-- --- Never leave a swapfile prompt in the way ------------------------------
vim.api.nvim_create_autocmd("SwapExists", {
    group = augroup("swap"),
    callback = function()
        vim.v.swapchoice = "e" -- edit anyway
    end,
})

-- --- Fill the terminal window edge to edge -------------------------------
-- The terminal's window padding sits outside nvim's grid, so it frames the
-- editor with a margin. While nvim runs: Alacritty's padding is dropped to 0
-- over its IPC socket (skipped inside tmux, where it would hit every pane), and
-- OSC 11 paints any remaining padding with Normal's bg. Both are undone on exit.
local alacritty_id = not vim.env.TMUX and vim.env.ALACRITTY_WINDOW_ID

local function term_fill()
    local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
    if bg then
        vim.api.nvim_ui_send(("\027]11;#%06x\027\\"):format(bg))
    end
    if alacritty_id then
        vim.system({ "alacritty", "msg", "config", "-w", alacritty_id, "window.padding.x=0", "window.padding.y=0" })
    end
end

local function term_restore()
    vim.api.nvim_ui_send("\027]111\027\\")
    if alacritty_id then
        vim.system({ "alacritty", "msg", "config", "-w", alacritty_id, "--reset" }):wait(500)
    end
end

vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme", "VimResume" }, {
    group = augroup("term_fill"),
    callback = term_fill,
})
vim.api.nvim_create_autocmd({ "UILeave", "VimSuspend" }, {
    group = augroup("term_restore"),
    callback = term_restore,
})
