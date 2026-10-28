-- Rounded border around all three panes.
require("full-border"):setup({ type = ui.Border.ROUNDED })

-- Git status signs next to file names (styled in theme.toml).
require("git"):setup({ order = 1500 })
