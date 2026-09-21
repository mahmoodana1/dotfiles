-- ===========================================================================
--  OPTIONS -- every vim.opt / vim.g setting in the config
-- ===========================================================================

-- Leader must be set before lazy.nvim loads anything.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

-- --- UI --------------------------------------------------------------------
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes" -- never let the gutter shift the text
opt.cursorline = true
opt.termguicolors = true
opt.showmode = false -- lualine already shows it
opt.laststatus = 3 -- one statusline for all windows
opt.cmdheight = 0 -- noice renders the cmdline
opt.pumheight = 12 -- cap completion popup height
opt.scrolloff = 6
opt.sidescrolloff = 8
opt.wrap = false
-- foldopen/foldclose want exactly one character each; nerd-font glyphs that
-- render as one cell can still be multi-codepoint, which nvim rejects.
opt.fillchars = { eob = " ", fold = " ", foldsep = " " }
opt.list = true
opt.listchars = { tab = "  ", trail = "·", nbsp = "␣" }

-- --- Editing ---------------------------------------------------------------
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftround = true
opt.smartindent = true
opt.virtualedit = "block"
opt.completeopt = "menu,menuone,noselect"
opt.confirm = true -- ask instead of failing on :q with unsaved changes

-- --- Search ----------------------------------------------------------------
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "nosplit" -- live preview for :s

-- --- Splits ----------------------------------------------------------------
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"

-- --- Files & undo ----------------------------------------------------------
opt.undofile = true
opt.undolevels = 10000
opt.swapfile = true
opt.directory = vim.fn.stdpath("state") .. "/swap//"
opt.updatetime = 200 -- also drives CursorHold
opt.timeoutlen = 400 -- which-key popup delay
opt.autowrite = true

-- --- Folds (treesitter-driven, all open at start) --------------------------
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldtext = ""

-- --- Misc ------------------------------------------------------------------
opt.shortmess:append("AcCI") -- A: no swap-exists prompt, I: no intro
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.wildmode = "longest:full,full"
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "folds" }

-- --- LSP log ---------------------------------------------------------------
-- Nothing rotates ~/.local/state/nvim/lsp.log and it had grown to 246 MB,
-- almost entirely copilot logging routine request cancellations
-- ("AbortError: The operation was aborted") at ERROR level -- a logging bug
-- on their side, not a real failure.
--
-- OFF rather than WARN: WARN is already the default, and ERROR outranks it,
-- so every level except OFF keeps writing exactly the lines that filled the
-- file. Flip this to "WARN" or "DEBUG" for the session when an LSP actually
-- misbehaves, then look at :LspLog.
-- vim.lsp.set_log_level() is deprecated in 0.12, gone in 0.13.
vim.lsp.log.set_level("OFF")

-- --- Providers -------------------------------------------------------------
-- Only the python provider is used; disabling the rest shaves off startup
-- checks and keeps :checkhealth quiet.
vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/nvim/bin/python")
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
