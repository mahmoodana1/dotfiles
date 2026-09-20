return {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
        -- Cursor smear feel
        stiffness = 0.85, -- 0–1, higher = snappier
        trailing_stiffness = 0.75, -- tail of the smear
        stiffness_insert_mode = 0.6, -- slightly slower in insert mode
        distance_stop_animating = 0.5, -- stop when close enough

        -- Look
        cursor_color = "none", -- inherits your terminal cursor color
        smear_between_buffers = true, -- animate across buffer jumps
        smear_between_neighbor_lines = true,
        scroll_buffer_space = true,

        -- NOTE: do NOT set `hide_target_hack = true` here. It is the fallback for
        -- setups WITHOUT termguicolors, and it is only valid together with
        -- `never_draw_over_target = true`. On its own it paints a literal block
        -- glyph at the target cell and never hides the real cursor -> stray
        -- cursor artifacts. termguicolors is on, so the default path (blend=100
        -- on SmearCursorHideable) hides the real cursor correctly.
    },
}
