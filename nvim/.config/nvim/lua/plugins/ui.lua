-- ===========================================================================
--  UI -- colourscheme, statusline, bufferline, icons, notifications, which-key
--
--  Reminder: no `keys = {}` and no vim.keymap.set in this file. See
--  lua/core/keymaps.lua.
-- ===========================================================================

-- How much lighter to make the dark end of the palette, in HSL lightness
-- points. 0 = stock catppuccin mocha. Raise this one number if it is still too
-- dark, lower it if it has gone washed out.
--
-- The shift is done in HSL so hue and saturation are untouched: the background
-- keeps catppuccin's blue-purple tint instead of drifting to flat grey, which
-- is what happens if you just blend toward white. Only the neutral ramp moves;
-- accent colours (red, green, blue, ...) ship unchanged, so syntax looks normal.
local LIGHTEN = 5

local function rgb_to_hsl(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local l = (max + min) / 2
    if max == min then
        return 0, 0, l
    end
    local d = max - min
    local s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    local h
    if max == r then
        h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    return h / 6, s, l
end

local function hsl_to_rgb(h, s, l)
    if s == 0 then
        local v = math.floor(l * 255 + 0.5)
        return v, v, v
    end
    local function hue(p, q, t)
        if t < 0 then
            t = t + 1
        end
        if t > 1 then
            t = t - 1
        end
        if t < 1 / 6 then
            return p + (q - p) * 6 * t
        end
        if t < 1 / 2 then
            return q
        end
        if t < 2 / 3 then
            return p + (q - p) * (2 / 3 - t) * 6
        end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return math.floor(hue(p, q, h + 1 / 3) * 255 + 0.5),
        math.floor(hue(p, q, h) * 255 + 0.5),
        math.floor(hue(p, q, h - 1 / 3) * 255 + 0.5)
end

---@param hex string "#rrggbb"
---@param points number lightness points to add (0-100 scale)
local function lighten(hex, points)
    local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
    local h, s, l = rgb_to_hsl(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
    l = math.min(1, l + points / 100)
    return ("#%02x%02x%02x"):format(hsl_to_rgb(h, s, l))
end

-- How much punchier to make the accent colours (red, green, blue, ...).
-- 0 = stock catppuccin mocha. Catppuccin's accents are pastels: quite light
-- AND fairly desaturated, so raising saturation alone barely shows. This adds
-- saturation and, in the same proportion, pulls lightness down toward
-- VIVID_TARGET_L -- which is what actually reads as "lively" rather than
-- "slightly less washed out".
local VIVID = 10
local VIVID_TARGET_L = 0.62

-- How much to blend every accent toward a single shared anchor colour, in
-- percent. This is the "make them compliment one another" knob: mixing each
-- accent a little way toward one common point pulls them closer together as a
-- family, lifts them lighter, and softens the contrast between them -- without
-- flattening hue differences the way desaturating everything would.
-- 0 = accents keep their own separate intensity.
local BLEND = 20
local BLEND_ANCHOR = "#cdd6f4" -- catppuccin mocha `text`, a neutral light lavender

---@param hex string "#rrggbb"
local function vivid(hex, points)
    local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
    local h, s, l = rgb_to_hsl(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
    local f = points / 100
    s = math.min(1, s + f)
    l = l - (l - VIVID_TARGET_L) * f
    return ("#%02x%02x%02x"):format(hsl_to_rgb(h, s, math.max(0, math.min(1, l))))
end

---@param hex string "#rrggbb"
---@param anchor string "#rrggbb" the colour to mix toward
---@param pct number how far to mix, 0-100
local function blend(hex, anchor, pct)
    local f = pct / 100
    local r1, g1, b1 = hex:match("#(%x%x)(%x%x)(%x%x)")
    local r2, g2, b2 = anchor:match("#(%x%x)(%x%x)(%x%x)")
    local function mix(a, b)
        return math.floor(tonumber(a, 16) + (tonumber(b, 16) - tonumber(a, 16)) * f + 0.5)
    end
    return ("#%02x%02x%02x"):format(mix(r1, r2), mix(g1, g2), mix(b1, b2))
end

-- Only the background layers of catppuccin mocha, darkest to lightest.
-- The overlay greys (#6c7086 / #7f849c / #9399b2) are deliberately NOT in
-- here: overlay2 is the Comment colour, and lifting it too made comments as
-- bright as ordinary code.
local mocha_backgrounds = {
    crust = "#11111b",
    mantle = "#181825",
    base = "#1e1e2e", -- the editor background
    surface0 = "#313244",
    surface1 = "#45475a",
    surface2 = "#585b70",
}

-- The accent colours of catppuccin mocha.
local mocha_accents = {
    rosewater = "#f5e0dc",
    flamingo = "#f2cdcd",
    pink = "#f5c2e7",
    mauve = "#cba6f7",
    red = "#f38ba8",
    maroon = "#eba0ac",
    peach = "#fab387",
    yellow = "#f9e2af",
    green = "#a6e3a1",
    teal = "#94e2d5",
    sky = "#89dceb",
    sapphire = "#74c7ec",
    blue = "#89b4fa",
    lavender = "#b4befe",
}

local overrides = {}
for name, hex in pairs(mocha_backgrounds) do
    overrides[name] = lighten(hex, LIGHTEN)
end
for name, hex in pairs(mocha_accents) do
    overrides[name] = blend(vivid(hex, VIVID), BLEND_ANCHOR, BLEND)
end

return {
    -- --- Colourscheme ------------------------------------------------------
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        opts = {
            flavour = "mocha",
            color_overrides = { mocha = overrides },
            transparent_background = false,
            styles = {
                comments = { "italic" },
                conditionals = { "italic" },
            },
            integrations = {
                blink_cmp = true,
                gitsigns = true,
                lsp_trouble = true,
                mason = true,
                mini = { enabled = true },
                native_lsp = { enabled = true, underlines = { errors = { "undercurl" } } },
                noice = true,
                notify = true,
                snacks = true,
                telescope = { enabled = true },
                treesitter = true,
                which_key = true,
            },
        },
        config = function(_, opts)
            require("catppuccin").setup(opts)
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- --- Icons -------------------------------------------------------------
    -- mini.icons is the single icon provider. The package.preload shim makes
    -- every `require("nvim-web-devicons")` -- from telescope, bufferline,
    -- lualine, snacks -- resolve here, so one glyph table drives the whole UI.
    -- Registering the shim in `init` (not `config`) is what keeps it
    -- deterministic: it is in place before any plugin can ask for icons.
    {
        "nvim-mini/mini.icons",
        lazy = true,
        opts = {
            file = {
                [".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
                [".gitignore"] = { glyph = "", hl = "MiniIconsGrey" },
                ["stylua.toml"] = { glyph = "󰢱", hl = "MiniIconsBlue" },
                ["compile_commands.json"] = { glyph = "", hl = "MiniIconsYellow" },
            },
            filetype = {
                dotenv = { glyph = "", hl = "MiniIconsYellow" },
            },
        },
        init = function()
            package.preload["nvim-web-devicons"] = function()
                require("mini.icons").mock_nvim_web_devicons()
                return package.loaded["nvim-web-devicons"]
            end
        end,
    },

    -- --- Statusline --------------------------------------------------------
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = function()
            return {
                options = {
                    -- Catppuccin ships its lualine themes per flavour
                    -- (catppuccin-mocha/-frappe/...) plus "catppuccin-nvim",
                    -- which follows whichever flavour is active. There is no
                    -- plain "catppuccin" module, so that name silently fell
                    -- back to `auto` and lualine warned about it on startup.
                    -- The flavour is pinned to mocha above, so name it.
                    theme = "catppuccin-mocha",
                    globalstatus = true,
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" },
                    disabled_filetypes = { statusline = { "snacks_dashboard" } },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch" },
                    lualine_c = {
                        {
                            "diagnostics",
                            symbols = { error = " ", warn = " ", info = " ", hint = " " },
                        },
                        { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                        { "filename", path = 1 },
                    },
                    lualine_x = {
                        -- Shows the spinner while an LSP or formatter is busy.
                        {
                            function()
                                return require("noice").api.status.command.get()
                            end,
                            cond = function()
                                return package.loaded["noice"] and require("noice").api.status.command.has()
                            end,
                        },
                        { "diff", symbols = { added = " ", modified = " ", removed = " " } },
                    },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
                extensions = { "lazy", "mason", "trouble", "toggleterm", "nvim-dap-ui" },
            }
        end,
    },

    -- --- Bufferline --------------------------------------------------------
    {
        "akinsho/bufferline.nvim",
        event = "VeryLazy",
        opts = {
            options = {
                diagnostics = "nvim_lsp",
                always_show_bufferline = false,
                show_buffer_close_icons = false,
                separator_style = "slant",
                -- Reserve the sidebar's width so the buffer tabs start to the
                -- right of the explorer instead of sliding under it. No `text`
                -- on purpose: snacks already draws "Explorer" as its own border
                -- title, and setting one here printed the label twice once a
                -- second buffer made the bufferline visible.
                offsets = {
                    { filetype = "snacks_layout_box", text = "", separator = true },
                },
            },
        },
    },

    -- --- Command line, messages, popupmenu ---------------------------------
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = { "MunifTanjim/nui.nvim" },
        opts = {
            lsp = {
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                },
            },
            presets = {
                bottom_search = true,
                command_palette = true,
                long_message_to_split = true,
                lsp_doc_border = true,
            },
            routes = {
                -- "written" / "N lines" noise on every save.
                { filter = { event = "msg_show", find = "written" }, opts = { skip = true } },
                { filter = { event = "msg_show", find = "lines" }, opts = { skip = true } },
            },
        },
    },

    -- --- Key hints ---------------------------------------------------------
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "helix",
            -- Group labels live next to the bindings they describe.
            spec = require("core.keymaps").groups,
        },
    },

    -- --- Cursor sugar ------------------------------------------------------
    {
        "sphamba/smear-cursor.nvim",
        event = "VeryLazy",
        opts = {
            stiffness = 0.8,
            trailing_stiffness = 0.5,
            distance_stop_animating = 0.5,
        },
    },
    {
        "ya2s/nvim-cursorline",
        event = "VeryLazy",
        opts = {
            cursorline = { enable = true, timeout = 1000, number = false },
            cursorword = { enable = true, min_length = 3, hl = { underline = true } },
        },
        config = function(_, opts)
            require("nvim-cursorline").setup(opts)
        end,
    },
}
