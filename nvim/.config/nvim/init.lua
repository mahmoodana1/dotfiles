-- ===========================================================================
--  Neovim config -- mahmood
--
--  Layout:
--    lua/core/options.lua    every vim.opt setting
--    lua/core/keymaps.lua    EVERY keybinding, in labelled sections
--    lua/core/autocmds.lua   every autocommand
--    lua/core/lazy.lua       plugin-manager bootstrap
--    lua/plugins/*.lua       one file per concern, plugins only -- no keymaps
--
--  Rule that keeps this understandable: plugin files never call vim.keymap.set
--  and never declare lazy.nvim `keys = {}`. Keybindings exist in exactly one
--  place. Plugins load on demand anyway, because lazy.nvim hooks `require`.
-- ===========================================================================

require("core.options")
require("core.lazy") -- plugins (also sets the colorscheme)
require("core.keymaps").setup()
require("core.autocmds")
