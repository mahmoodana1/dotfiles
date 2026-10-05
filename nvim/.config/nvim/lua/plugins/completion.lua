-- ===========================================================================
--  COMPLETION -- blink.cmp with Copilot as an on-demand source
--
--  blink.cmp owns the insert-mode completion keys (<C-space>, <Tab>, <CR>,
--  <C-e>). Those are configured here rather than in core/keymaps.lua because
--  they only exist while the completion menu is open -- they are part of the
--  menu's own state machine, not global bindings. Everything that works
--  outside a popup is still in core/keymaps.lua.
-- ===========================================================================

-- Copilot's language server needs Node 22+. nvim started outside a shell
-- (launcher, file manager) has no nvm on PATH and finds the system node (20),
-- so hand it the newest nvm node instead when PATH's is too old.
local function copilot_node()
    local function major(bin)
        local out = vim.fn.system({ bin, "--version" })
        return vim.v.shell_error == 0 and tonumber(out:match("v(%d+)")) or 0
    end
    if vim.fn.executable("node") == 1 and major("node") >= 22 then return "node" end
    local best, best_major = "node", 0
    for _, bin in ipairs(vim.fn.glob("~/.config/nvm/versions/node/*/bin/node", false, true)) do
        local m = major(bin)
        if m > best_major then best, best_major = bin, m end
    end
    return best
end

return {
    -- --- Copilot: suggestions go into the completion menu, not as ghost text
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        opts = function()
            return {
                copilot_node_command = copilot_node(),
                suggestion = { enabled = false }, -- blink renders them instead
                panel = { enabled = false },
                filetypes = { markdown = true, gitcommit = true },
            }
        end,
    },

    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        version = "*", -- release build, no rust toolchain needed
        dependencies = {
            "rafamadriz/friendly-snippets",
            { "fang2hou/blink-copilot", dependencies = "zbirenbaum/copilot.lua" },
        },
        opts = {
            keymap = {
                preset = "default", -- <C-space> menu, <C-n>/<C-p> cycle, <C-e> hide
                ["<CR>"] = { "accept", "fallback" },
                ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                ["<C-j>"] = { "select_next", "fallback" },
                ["<C-k>"] = { "select_prev", "fallback" },
                ["<C-g>"] = { function(cmp) return cmp.show({ providers = { "copilot" } }) end },
                -- Same toggle as <leader>ua / normal-mode <S-Space> (core/keymaps.lua),
                -- mid-typing: the menu is rebuilt with the new sources -- opened when
                -- turning AI on, kept open (minus Copilot) when turning it off.
                ["<S-Space>"] = {
                    function(cmp)
                        local was_open = cmp.is_menu_visible()
                        vim.g.ai_complete = not vim.g.ai_complete
                        vim.notify((vim.g.ai_complete and "Enabled" or "Disabled") .. " AI completion",
                            vim.log.levels.INFO, { title = "AI completion" })
                        cmp.hide()
                        if vim.g.ai_complete or was_open then vim.schedule(function() cmp.show() end) end
                        return true
                    end,
                },
            },
            appearance = { nerd_font_variant = "mono" },
            completion = {
                accept = { auto_brackets = { enabled = true } },
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
                menu = {
                    border = "rounded",
                    draw = {
                        treesitter = { "lsp" },
                        columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
                    },
                },
                ghost_text = { enabled = true },
            },
            signature = { enabled = true, window = { border = "rounded" } },
            sources = {
                -- Copilot is on-demand: <C-g> pops an AI-only menu. <leader>ua
                -- (vim.g.ai_complete) mixes it back into the regular menu.
                default = function()
                    local regular = { "lsp", "path", "snippets", "buffer" }
                    if vim.g.ai_complete then table.insert(regular, 1, "copilot") end
                    return regular
                end,
                providers = {
                    copilot = {
                        name = "copilot",
                        module = "blink-copilot",
                        score_offset = 100, -- float Copilot to the top
                        async = true,
                    },
                },
            },
        },
    },
}
