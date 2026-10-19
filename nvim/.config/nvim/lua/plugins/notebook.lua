-- ===========================================================================
--  NOTEBOOKS -- .ipynb in nvim, looking like a notebook
--
--  core/autocmds.lua opens a notebook as Markdown through jupytext (text
--  cells are Markdown, code cells are ```python blocks) and saves it back.
--  render-markdown draws that like JupyterLab: headings, bold, grey code
--  boxes. molten-nvim runs the code in a real kernel and shows output under
--  each block. Python deps live in ~/.virtualenvs/nvim (pynvim,
--  jupyter_client, jupytext, nbformat, pillow).
--
--  Alacritty has no image protocol, so plots don't render inline -- open them
--  with <leader>jp (MoltenImagePopup) instead.
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. See
--  lua/core/keymaps.lua, section 17.
-- ===========================================================================

return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = "markdown",
        dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
        opts = {
            latex = { enabled = false }, -- no latex parser installed
            -- the default "hide" conceals the closing ``` line, and molten's
            -- output (attached to that line) vanishes with it
            code = { border = "thin" },
        },
    },

    {
        "benlubas/molten-nvim",
        version = "^1.0.0",
        build = ":UpdateRemotePlugins",
        lazy = false, -- remote plugin: must be on rtp when :UpdateRemotePlugins runs
        init = function()
            vim.g.molten_output_win_max_height = 20
            vim.g.molten_wrap_output = true
            -- keep output visible under each cell, like Jupyter, instead of a popup
            vim.g.molten_virt_text_output = true
            vim.g.molten_auto_open_output = false
            -- draw it below the closing ``` rather than inside the code box
            vim.g.molten_virt_lines_off_by_1 = true
        end,
    },
}
