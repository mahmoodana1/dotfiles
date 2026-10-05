-- ===========================================================================
--  KEYBINDINGS -- all of them, for the whole config
--
--  Nothing else in this config calls vim.keymap.set. Plugin files do not
--  declare lazy.nvim `keys = {}` either. If a key does something, it is
--  written down in this file.
--
--  Leader is <Space>. localleader is \
--
--  Most plugin bindings call require("plugin") inside a function. lazy.nvim
--  hooks `require`, so the plugin loads on the first press and not before --
--  you get lazy-loading without scattering keys across plugin specs.
--
--  Sections:
--     1. General editing          9. Git
--     2. Windows & splits        10. Toggles (<leader>u)
--     3. Buffers & tabs          11. Terminal
--     4. Find / search           12. Debug (DAP)
--     5. File explorer           13. Build & run
--     6. LSP (buffer-local)      14. AI / Claude
--     7. Diagnostics & Trouble   15. Sessions & scratch
--     8. Treesitter / motion     16. which-key group labels
--
--  Tip: <leader>sk opens a searchable picker of every active keymap.
-- ===========================================================================

local M = {}

---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
---@param opts? table
local function map(mode, lhs, rhs, desc, opts)
    opts = vim.tbl_extend("force", { silent = true, desc = desc }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
end

-- Root of the current project: nearest ancestor with a VCS/build marker,
-- else the cwd. Used by the "root dir" pickers below.
local function root()
    local markers = { ".git", "Makefile", "pyproject.toml", "compile_commands.json", "package.json", "Cargo.toml" }
    local found = vim.fs.find(markers, { upward = true, path = vim.fn.expand("%:p:h") })[1]
    return found and vim.fs.dirname(found) or vim.uv.cwd()
end
M.root = root

function M.setup()
    -- =======================================================================
    --  1. GENERAL EDITING
    -- =======================================================================
    map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")
    map({ "n", "i", "x", "s" }, "<C-s>", "<cmd>write<cr><esc>", "Save file")
    map("n", "<leader>qq", "<cmd>qa<cr>", "Quit all")

    -- Move by visual line when the line is wrapped, unless a count was given.
    map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
    map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })

    -- Keep the selection after indenting so you can repeat it.
    map("x", "<", "<gv", "Indent left")
    map("x", ">", ">gv", "Indent right")

    -- Move the selected lines up/down, reindenting as they go.
    map("n", "<A-j>", "<cmd>m .+1<cr>==", "Move line down")
    map("n", "<A-k>", "<cmd>m .-2<cr>==", "Move line up")
    map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", "Move line down")
    map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", "Move line up")
    map("x", "<A-j>", ":m '>+1<cr>gv=gv", "Move selection down")
    map("x", "<A-k>", ":m '<-2<cr>gv=gv", "Move selection up")

    -- Centre the view when jumping around, so you never lose the cursor.
    map("n", "<C-d>", "<C-d>zz", "Half page down")
    map("n", "<C-u>", "<C-u>zz", "Half page up")
    map("n", "n", "nzzzv", "Next search result")
    map("n", "N", "Nzzzv", "Prev search result")

    -- Paste over a selection without clobbering the unnamed register.
    map("x", "p", [["_dP]], "Paste without yanking")

    map({ "n", "x" }, "<leader>y", [["+y]], "Yank to system clipboard")
    map("n", "<leader>Y", [["+Y]], "Yank line to system clipboard")
    -- Whole buffer; clipboard=unnamedplus sends it to the system clipboard.
    -- :%yank rather than ggyG, so the cursor stays where it is.
    map("n", "yig", "<cmd>%yank<cr>", "Yank whole buffer")

    -- =======================================================================
    --  2. WINDOWS & SPLITS
    -- =======================================================================
    map("n", "<C-h>", "<C-w>h", "Go to left window")
    map("n", "<C-j>", "<C-w>j", "Go to lower window")
    map("n", "<C-k>", "<C-w>k", "Go to upper window")
    map("n", "<C-l>", "<C-w>l", "Go to right window")

    map("n", "<C-Up>", "<cmd>resize +2<cr>", "Increase height")
    map("n", "<C-Down>", "<cmd>resize -2<cr>", "Decrease height")
    map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", "Decrease width")
    map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", "Increase width")

    map("n", "<leader>-", "<C-w>s", "Split window below")
    map("n", "<leader>|", "<C-w>v", "Split window right")
    map("n", "<leader>wd", "<C-w>c", "Close window")
    map("n", "<leader>wm", function()
        Snacks.zen.zoom()
    end, "Maximise window (toggle)")

    -- =======================================================================
    --  3. BUFFERS & TABS
    -- =======================================================================
    map("n", "<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
    map("n", "<S-l>", "<cmd>bnext<cr>", "Next buffer")
    map("n", "[b", "<cmd>bprevious<cr>", "Previous buffer")
    map("n", "]b", "<cmd>bnext<cr>", "Next buffer")
    map("n", "<leader>bb", "<cmd>e #<cr>", "Switch to other buffer")
    map("n", "<leader>bd", function()
        Snacks.bufdelete()
    end, "Delete buffer")
    map("n", "<leader>bo", function()
        Snacks.bufdelete.other()
    end, "Delete other buffers")
    map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", "Pin/unpin buffer")

    map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", "New tab")
    map("n", "<leader><tab>d", "<cmd>tabclose<cr>", "Close tab")
    map("n", "<leader><tab>]", "<cmd>tabnext<cr>", "Next tab")
    map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", "Previous tab")

    -- =======================================================================
    --  4. FIND / SEARCH   (telescope)
    -- =======================================================================
    local function pick(builtin, opts)
        return function()
            require("telescope.builtin")[builtin](opts and opts() or {})
        end
    end
    local in_root = function()
        return { cwd = root() }
    end

    map("n", "<leader><space>", pick("find_files", in_root), "Find files (root)")
    map("n", "<leader>ff", pick("find_files", in_root), "Find files (root)")
    map("n", "<leader>fF", pick("find_files"), "Find files (cwd)")
    map("n", "<leader>fg", pick("live_grep", in_root), "Live grep (root)")
    map("n", "<leader>fb", pick("buffers"), "Buffers")
    map("n", "<leader>fr", pick("oldfiles"), "Recent files")
    map("n", "<leader>fh", pick("help_tags"), "Help tags")
    map("n", "<leader>fc", function()
        require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
    end, "Find config file")

    map("n", "<leader>/", pick("live_grep", in_root), "Grep (root)")
    map("n", "<leader>sg", pick("live_grep", in_root), "Grep (root)")
    map("n", "<leader>sG", pick("live_grep"), "Grep (cwd)")
    map("n", "<leader>sb", pick("current_buffer_fuzzy_find"), "Grep current buffer")
    map({ "n", "x" }, "<leader>sw", pick("grep_string", in_root), "Grep word under cursor")
    map("n", "<leader>sk", pick("keymaps"), "Keymaps")
    map("n", "<leader>sc", pick("commands"), "Commands")
    map("n", "<leader>sd", pick("diagnostics"), "Diagnostics (workspace)")
    map("n", "<leader>sm", pick("marks"), "Marks")
    map("n", "<leader>sR", pick("resume"), "Resume last picker")
    map("n", "<leader>ss", pick("lsp_document_symbols"), "Document symbols")
    map("n", "<leader>sS", pick("lsp_dynamic_workspace_symbols"), "Workspace symbols")
    map("n", "<leader>sh", pick("highlights"), "Highlight groups")
    map("n", "<leader>st", "<cmd>TodoTelescope<cr>", "Todo comments")

    -- Message history. noice routes messages into its own log, so `:messages`
    -- can look empty even when something errored. These two show the real
    -- thing, scrollable and untruncated.
    -- sN rather than sne: a two-key prefix would make <leader>sn wait out
    -- timeoutlen on every press.
    map("n", "<leader>sn", "<cmd>Noice history<cr>", "Notifications (all)")
    map("n", "<leader>sN", "<cmd>Noice errors<cr>", "Notifications (errors only)")

    -- =======================================================================
    --  5. FILE EXPLORER   (snacks explorer)
    -- =======================================================================
    map("n", "<leader>e", function()
        Snacks.explorer({ cwd = root() })
    end, "Explorer (root)")
    map("n", "<leader>E", function()
        Snacks.explorer({ cwd = vim.uv.cwd() })
    end, "Explorer (cwd)")

    -- =======================================================================
    --  6. LSP -- see M.on_lsp_attach below (buffer-local, set on LspAttach)
    -- =======================================================================
    map("n", "<leader>cm", "<cmd>Mason<cr>", "Mason (LSP/tool installer)")
    map("n", "<leader>cl", "<cmd>checkhealth vim.lsp<cr>", "LSP info")
    map("n", "<leader>L", "<cmd>Lazy<cr>", "Lazy (plugin manager)")

    -- =======================================================================
    --  7. DIAGNOSTICS & TROUBLE
    -- =======================================================================
    map("n", "D", vim.diagnostic.open_float, "Show diagnostic under cursor")
    map("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")

    -- vim.diagnostic.jump is the 0.11+ API; goto_next/goto_prev are deprecated.
    local function diag_jump(count, severity)
        return function()
            vim.diagnostic.jump({
                count = count,
                float = true,
                severity = severity and vim.diagnostic.severity[severity] or nil,
            })
        end
    end
    map("n", "]d", diag_jump(1), "Next diagnostic")
    map("n", "[d", diag_jump(-1), "Previous diagnostic")
    map("n", "]e", diag_jump(1, "ERROR"), "Next error")
    map("n", "[e", diag_jump(-1, "ERROR"), "Previous error")
    map("n", "]w", diag_jump(1, "WARN"), "Next warning")
    map("n", "[w", diag_jump(-1, "WARN"), "Previous warning")

    map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics (Trouble)")
    map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer diagnostics")
    map("n", "<leader>xs", "<cmd>Trouble symbols toggle<cr>", "Symbols (Trouble)")
    map("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", "Location list")
    map("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", "Quickfix list")
    map("n", "<leader>xt", "<cmd>Trouble todo toggle<cr>", "Todo comments")

    -- =======================================================================
    --  8. TREESITTER / MOTION
    -- =======================================================================
    map({ "n", "x", "o" }, "s", function()
        require("flash").jump()
    end, "Flash jump")
    map({ "n", "x", "o" }, "S", function()
        require("flash").treesitter()
    end, "Flash treesitter")
    map("o", "r", function()
        require("flash").remote()
    end, "Remote flash")
    map("c", "<C-s>", function()
        require("flash").toggle()
    end, "Toggle flash search")

    map("n", "<leader>ui", vim.show_pos, "Inspect syntax under cursor")

    -- Treesitter textobjects. These used to be declared inside the treesitter
    -- spec's `opts.textobjects`; the `main` branch dropped that table, so they
    -- are plain keymaps now -- which is where they belonged anyway.
    --
    -- af/if/ac/ic/aa/ia are textobjects, not commands: they only mean
    -- something after an operator (d, c, y) or in visual mode.
    local function select_to(obj)
        return function()
            require("nvim-treesitter-textobjects.select").select_textobject(obj, "textobjects")
        end
    end
    local function goto_start(obj)
        return function()
            require("nvim-treesitter-textobjects.move").goto_next_start(obj, "textobjects")
        end
    end
    local function goto_prev_start(obj)
        return function()
            require("nvim-treesitter-textobjects.move").goto_previous_start(obj, "textobjects")
        end
    end

    map({ "x", "o" }, "af", select_to("@function.outer"), "A function")
    map({ "x", "o" }, "if", select_to("@function.inner"), "Inner function")
    map({ "x", "o" }, "ac", select_to("@class.outer"), "A class")
    map({ "x", "o" }, "ic", select_to("@class.inner"), "Inner class")
    map({ "x", "o" }, "aa", select_to("@parameter.outer"), "A parameter")
    map({ "x", "o" }, "ia", select_to("@parameter.inner"), "Inner parameter")

    map({ "n", "x", "o" }, "]f", goto_start("@function.outer"), "Next function")
    map({ "n", "x", "o" }, "]c", goto_start("@class.outer"), "Next class")
    map({ "n", "x", "o" }, "[f", goto_prev_start("@function.outer"), "Previous function")
    map({ "n", "x", "o" }, "[c", goto_prev_start("@class.outer"), "Previous class")

    -- =======================================================================
    --  9. GIT
    -- =======================================================================
    map("n", "<leader>gg", "<cmd>LazyGit<cr>", "LazyGit")
    map("n", "<leader>lg", "<cmd>LazyGit<cr>", "LazyGit (alias)")
    map("n", "<leader>gf", "<cmd>LazyGitCurrentFile<cr>", "LazyGit (current file)")
    map("n", "<leader>gc", pick("git_commits"), "Git commits")
    map("n", "<leader>gs", pick("git_status"), "Git status")
    map("n", "<leader>gB", pick("git_branches"), "Git branches")
    -- Hunk bindings are buffer-local; see M.on_gitsigns_attach below.

    -- =======================================================================
    --  10. TOGGLES  (<leader>u)
    -- =======================================================================
    -- Snacks.toggle gives each of these an on/off notification and a which-key
    -- entry that shows current state.
    Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
    Snacks.toggle.option("relativenumber", { name = "Relative number" }):map("<leader>uL")
    Snacks.toggle.line_number():map("<leader>ul")
    Snacks.toggle.diagnostics():map("<leader>ud")
    Snacks.toggle.treesitter():map("<leader>uT")
    Snacks.toggle.inlay_hints():map("<leader>uh")
    Snacks.toggle.indent():map("<leader>ug")
    Snacks.toggle.dim():map("<leader>uD")
    Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark background" }):map("<leader>ub")
    Snacks.toggle
        .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2, name = "Conceal" })
        :map("<leader>uc")

    -- Format-on-save. vim.g.autoformat is read by the BufWritePre autocmd in
    -- core/autocmds.lua; b:autoformat overrides it for one buffer.
    Snacks.toggle({
        name = "Format on save",
        get = function()
            return vim.b.autoformat ~= false and (vim.b.autoformat or vim.g.autoformat)
        end,
        set = function(state)
            vim.b.autoformat = state
            vim.g.autoformat = state
        end,
    }):map("<leader>uf")

    -- Copilot in the regular completion menu. Off by default; <C-g> in insert
    -- mode asks for AI suggestions once regardless (plugins/completion.lua).
    -- <S-Space> needs the terminal to send it as CSI u (kitty.conf,
    -- alacritty.toml) and tmux extended-keys. Insert-mode <S-Space> lives in
    -- blink's keymap (plugins/completion.lua).
    local ai_toggle = Snacks.toggle({
        name = "AI completion",
        get = function() return vim.g.ai_complete == true end,
        set = function(state) vim.g.ai_complete = state end,
    })
    ai_toggle:map("<leader>ua")
    ai_toggle:map("<S-Space>", { mode = { "n", "x" } })

    map("n", "<leader>un", function()
        Snacks.notifier.hide()
    end, "Dismiss notifications")
    map("n", "<leader>ur", "<cmd>nohlsearch<bar>diffupdate<bar>normal! <C-l><cr>", "Redraw / clear highlights")

    -- =======================================================================
    --  11. TERMINAL
    -- =======================================================================
    -- <C-/> is what most terminals send; <C-_> is the same chord on others.
    map({ "n", "t" }, "<C-/>", "<cmd>ToggleTerm<cr>", "Toggle terminal")
    map({ "n", "t" }, "<C-_>", "<cmd>ToggleTerm<cr>", "Toggle terminal")
    map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", "Terminal (float)")
    map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", "Terminal (horizontal)")
    map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", "Terminal (vertical)")

    -- Escape terminal mode. Terminal-local window navigation is set by the
    -- TermOpen autocmd in core/autocmds.lua, which calls M.on_term_open.
    map("t", "<Esc><Esc>", [[<C-\><C-n>]], "Exit terminal mode")

    -- =======================================================================
    --  12. DEBUG (DAP)
    -- =======================================================================
    local function dap(fn)
        return function()
            require("dap")[fn]()
        end
    end
    map("n", "<F5>", dap("continue"), "Debug: start/continue")
    map("n", "<F9>", dap("toggle_breakpoint"), "Debug: toggle breakpoint")
    map("n", "<F10>", dap("step_over"), "Debug: step over")
    map("n", "<F11>", dap("step_into"), "Debug: step into")
    map("n", "<F12>", dap("step_out"), "Debug: step out")

    map("n", "<leader>dc", dap("continue"), "Continue")
    map("n", "<leader>db", dap("toggle_breakpoint"), "Toggle breakpoint")
    map("n", "<leader>dB", function()
        require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, "Conditional breakpoint")
    map("n", "<leader>do", dap("step_over"), "Step over")
    map("n", "<leader>di", dap("step_into"), "Step into")
    map("n", "<leader>dO", dap("step_out"), "Step out")
    map("n", "<leader>dr", dap("repl.toggle"), "Toggle REPL")
    map("n", "<leader>dt", dap("terminate"), "Terminate")
    map("n", "<leader>du", function()
        require("dapui").toggle()
    end, "Toggle DAP UI")
    map("n", "<leader>de", function()
        require("dapui").eval(nil, { enter = true })
    end, "Eval expression")

    -- =======================================================================
    --  13. BUILD & RUN
    -- =======================================================================
    -- NOTE: this used to be <leader>car. It moved because <leader>ca is code
    -- action -- every code action would have waited 400ms for the 'r'.
    map("n", "<leader>rr", function()
        M.compile_and_run(true)
    end, "Compile and run (C/C++) in tmux")
    map("n", "<leader>rb", function()
        M.compile_and_run(false)
    end, "Compile only (C/C++)")
    map("n", "<leader>rp", function()
        M.run_in_tmux("python3 " .. vim.fn.shellescape(vim.fn.expand("%:t")), vim.fn.expand("%:p:h"))
    end, "Run current Python file in tmux")

    -- =======================================================================
    --  14. AI / CLAUDE
    -- =======================================================================
    map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", "Toggle Claude")
    map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", "Focus Claude")
    map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", "Resume Claude")
    map("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", "Continue Claude")
    map("x", "<leader>as", "<cmd>ClaudeCodeSend<cr>", "Send selection to Claude")
    map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", "Add current buffer to Claude")

    -- =======================================================================
    --  15. SESSIONS & SCRATCH
    -- =======================================================================
    map("n", "<leader>qs", function()
        require("persistence").load()
    end, "Restore session for cwd")
    map("n", "<leader>ql", function()
        require("persistence").load({ last = true })
    end, "Restore last session")
    map("n", "<leader>qd", function()
        require("persistence").stop()
    end, "Don't save current session")

    map("n", "<leader>.", function()
        Snacks.scratch()
    end, "Toggle scratch buffer")
    map("n", "<leader>S", function()
        Snacks.scratch.select()
    end, "Select scratch buffer")
    map("n", "<leader>z", function()
        Snacks.zen()
    end, "Zen mode")
    map("n", "<leader>Z", function()
        Snacks.zen.zoom()
    end, "Zoom")
    map({ "n", "t" }, "]]", function()
        Snacks.words.jump(vim.v.count1)
    end, "Next reference")
    map({ "n", "t" }, "[[", function()
        Snacks.words.jump(-vim.v.count1)
    end, "Previous reference")

    map("n", "<leader>cR", function()
        Snacks.rename.rename_file()
    end, "Rename file")
    map("n", "<leader>gy", function()
        Snacks.gitbrowse()
    end, "Open in browser (git)")
end

-- ===========================================================================
--  LSP -- buffer-local, applied by the LspAttach autocmd
-- ===========================================================================

-- Telescope's LSP pickers, deferred so telescope loads on first use.
local function pick_lsp(builtin)
    return function()
        require("telescope.builtin")[builtin]({ reuse_win = true })
    end
end

---@param bufnr integer
function M.on_lsp_attach(client, bufnr)
    local function lmap(mode, lhs, rhs, desc)
        map(mode, lhs, rhs, desc, { buffer = bufnr })
    end

    lmap("n", "gd", pick_lsp("lsp_definitions"), "Goto definition")
    lmap("n", "gr", pick_lsp("lsp_references"), "Goto references")
    lmap("n", "gI", pick_lsp("lsp_implementations"), "Goto implementation")
    lmap("n", "gy", pick_lsp("lsp_type_definitions"), "Goto type definition")
    lmap("n", "gD", vim.lsp.buf.declaration, "Goto declaration")

    lmap("n", "K", function()
        vim.lsp.buf.hover({ border = "rounded" })
    end, "Hover documentation")
    lmap("n", "gK", function()
        vim.lsp.buf.signature_help({ border = "rounded" })
    end, "Signature help")
    lmap("i", "<C-k>", function()
        vim.lsp.buf.signature_help({ border = "rounded" })
    end, "Signature help")

    lmap({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    lmap("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
    lmap({ "n", "x" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_format = "never" })
    end, "Format buffer")

    -- Only bind what the attached server can actually do.
    if client:supports_method("textDocument/codeLens") then
        lmap("n", "<leader>cc", vim.lsp.codelens.run, "Run code lens")
    end
end

-- ===========================================================================
--  GIT HUNKS -- buffer-local, applied by gitsigns' on_attach
-- ===========================================================================
function M.on_gitsigns_attach(bufnr)
    local gs = require("gitsigns")
    local function gmap(mode, lhs, rhs, desc)
        map(mode, lhs, rhs, desc, { buffer = bufnr })
    end

    gmap("n", "]h", function()
        gs.nav_hunk("next")
    end, "Next hunk")
    gmap("n", "[h", function()
        gs.nav_hunk("prev")
    end, "Previous hunk")

    gmap({ "n", "x" }, "<leader>ghs", gs.stage_hunk, "Stage hunk")
    gmap({ "n", "x" }, "<leader>ghr", gs.reset_hunk, "Reset hunk")
    gmap("n", "<leader>ghS", gs.stage_buffer, "Stage buffer")
    gmap("n", "<leader>ghR", gs.reset_buffer, "Reset buffer")
    gmap("n", "<leader>ghp", gs.preview_hunk_inline, "Preview hunk")
    gmap("n", "<leader>ghb", function()
        gs.blame_line({ full = true })
    end, "Blame line")
    gmap("n", "<leader>ghd", gs.diffthis, "Diff this")
    gmap("n", "<leader>gb", function()
        gs.blame_line({ full = true })
    end, "Blame line")
end

-- ===========================================================================
--  TERMINAL WINDOWS -- buffer-local, applied by the TermOpen autocmd
-- ===========================================================================
function M.on_term_open(bufnr)
    local function tmap(lhs, rhs, desc)
        map("t", lhs, rhs, desc, { buffer = bufnr })
    end
    tmap("<C-h>", [[<C-\><C-n><C-w>h]], "Go to left window")
    tmap("<C-j>", [[<C-\><C-n><C-w>j]], "Go to lower window")
    tmap("<C-k>", [[<C-\><C-n><C-w>k]], "Go to upper window")
    tmap("<C-l>", [[<C-\><C-n><C-w>l]], "Go to right window")
end

-- ===========================================================================
--  BUILD & RUN helpers (used by section 13)
-- ===========================================================================

--- Send a command to a dedicated tmux window named "run", creating it if
--- needed. Falls back to a split :terminal when not inside tmux.
function M.run_in_tmux(cmd, dir)
    if vim.env.TMUX == nil then
        vim.notify("Not inside tmux -- using a split terminal", vim.log.levels.WARN)
        vim.cmd("botright split | resize 15")
        vim.cmd("terminal " .. cmd)
        vim.cmd("startinsert")
        return
    end

    vim.fn.system([[tmux list-windows -F '#{window_name}' | grep -qx run]])
    if vim.v.shell_error == 0 then
        vim.fn.system("tmux select-window -t run")
        vim.fn.system("tmux send-keys -t run C-l")
    else
        vim.fn.system(("tmux new-window -n run -c %s"):format(vim.fn.shellescape(dir)))
    end

    vim.fn.system(("tmux send-keys -t run %s Enter"):format(vim.fn.shellescape("cd " .. dir)))
    vim.fn.system(("tmux send-keys -t run %s Enter"):format(vim.fn.shellescape(cmd)))
    vim.notify("Running in tmux window 'run'", vim.log.levels.INFO)
end

--- Compile the current C/C++ file, optionally running it afterwards.
function M.compile_and_run(run)
    local ext = vim.fn.expand("%:e")
    local compiler = (ext == "c") and "gcc" or ((ext == "cpp" or ext == "cc" or ext == "cxx") and "g++" or nil)
    if not compiler then
        vim.notify("Not a C/C++ file", vim.log.levels.ERROR)
        return
    end

    vim.cmd("write")
    local file, bin, dir = vim.fn.expand("%:t"), vim.fn.expand("%:t:r"), vim.fn.expand("%:p:h")
    local cmd = ("%s -Wall -Wextra -g %s -o %s"):format(compiler, file, bin)
    if run then
        cmd = cmd .. (" && ./%s"):format(bin)
    end
    M.run_in_tmux(cmd, dir)
end

-- ===========================================================================
--  16. WHICH-KEY GROUP LABELS
--  Read by the which-key spec in lua/plugins/ui.lua -- the labels live here so
--  that adding a <leader>x group and its label is a one-file change.
-- ===========================================================================
M.groups = {
    { "<leader>a", group = "ai / claude", icon = "󰚩" },
    { "<leader>b", group = "buffer", icon = "" },
    { "<leader>c", group = "code", icon = "" },
    { "<leader>d", group = "debug", icon = "" },
    { "<leader>f", group = "file / find", icon = "" },
    { "<leader>g", group = "git", icon = "" },
    { "<leader>gh", group = "hunks", icon = "" },
    { "<leader>q", group = "quit / session", icon = "" },
    { "<leader>r", group = "run / build", icon = "" },
    { "<leader>s", group = "search", icon = "" },
    { "<leader>t", group = "terminal", icon = "" },
    { "<leader>u", group = "ui / toggle", icon = "" },
    { "<leader>w", group = "window", icon = "" },
    { "<leader>x", group = "diagnostics / quickfix", icon = "" },
    { "<leader><tab>", group = "tabs", icon = "󰓩" },
    { "[", group = "prev" },
    { "]", group = "next" },
    { "g", group = "goto" },
    { "z", group = "fold" },
}

return M
