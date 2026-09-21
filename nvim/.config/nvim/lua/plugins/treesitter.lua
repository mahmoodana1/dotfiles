-- ===========================================================================
--  TREESITTER -- syntax, indentation, textobjects, folds
--
--  On the `main` branch. The old `master` branch is frozen at the Neovim
--  0.10/0.11 query API and breaks on 0.12: its query directives still ask for
--  `{ all = false }`, which 0.12 removed, so `match[id]` arrives as a node
--  LIST and every shim that treats it as a single node dies with
--  "attempt to call method 'range' (a nil value)" on each redraw. That hit
--  markdown fences, html <script type=...> and bash heredocs.
--
--  `main` is a full rewrite, so this file looks nothing like the classic
--  setup:
--    * no `nvim-treesitter.configs`, no `ensure_installed`, no modules table
--    * parsers/queries install into stdpath('data')/site, not the plugin dir
--    * nothing is enabled for you -- highlight/indent are switched on by the
--      FileType autocmd below, folds by core/options.lua
--    * it cannot be lazy-loaded (upstream says so), hence `lazy = false`
--
--  Textobject keymaps live in core/keymaps.lua like every other key.
-- ===========================================================================

-- Parsers to keep installed. `install()` is a no-op for ones already present.
local ensure = {
    "bash",
    "c",
    "cpp",
    "cmake",
    "css",
    "diff",
    "gitcommit",
    "gitignore",
    "html",
    "javascript",
    "json",
    -- `main` has no `jsonc` parser (master did). json5 is a superset that
    -- accepts comments and trailing commas, so it parses jsonc correctly --
    -- see the language.register below.
    "json5",
    "lua",
    "luadoc",
    "make",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "regex",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
}

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        -- Upstream: "This plugin does not support lazy-loading."
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local ts = require("nvim-treesitter")

            ts.setup({
                install_dir = vim.fn.stdpath("data") .. "/site",
            })

            -- Filetypes whose name isn't the parser name.
            vim.treesitter.language.register("json5", { "jsonc" })

            -- Async, and a no-op once everything is present, so it is cheap to
            -- run on every start and means a fresh machine self-heals.
            local missing = vim.tbl_filter(function(lang)
                return not vim.tbl_contains(ts.get_installed("parsers"), lang)
            end, ensure)
            if #missing > 0 then
                -- `force` because install() decides what to skip from the
                -- UNION of the parser and query dirs. A failed compile still
                -- leaves the queries behind, so without this a parser that
                -- never built is treated as installed forever and silently
                -- never retried. `missing` is already parser-dir-only, so
                -- nothing gets needlessly rebuilt.
                ts.install(missing, { force = true })
            end

            -- `main` enables nothing on its own. Turn on highlighting (and
            -- treesitter indent, where a language actually ships an indents
            -- query) for any buffer whose parser is installed.
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("ts_attach", { clear = true }),
                callback = function(args)
                    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
                    if not lang then
                        return
                    end
                    -- Errors when the parser isn't installed; that's the
                    -- "no treesitter for this filetype" case, not a problem.
                    if not pcall(vim.treesitter.start, args.buf, lang) then
                        return
                    end
                    if vim.treesitter.query.get(lang, "indents") then
                        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                    end
                end,
            })
        end,
    },

    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        -- Loads on the first textobject keypress: core/keymaps.lua requires
        -- this module inside the mapping, and lazy.nvim hooks `require`.
        -- (Deliberately NOT setting vim.g.no_plugin_maps -- none of our
        -- bindings collide with the built-in ftplugin maps.)
        opts = {
            select = {
                lookahead = true,
            },
            move = {
                set_jumps = true,
            },
        },
    },

    -- Auto-close and rename HTML/JSX tags.
    { "windwp/nvim-ts-autotag", ft = { "html", "javascript", "typescript", "typescriptreact", "xml" }, opts = {} },
}
