# pylint: disable=C0111
c = c  # noqa: F821
config = config  # noqa: F821

import subprocess


def read_xresources():
    props = {}
    try:
        x = subprocess.run(
            ["xrdb", "-query"],
            capture_output=True,
            text=True,
            check=True,
        )
        for line in x.stdout.split("\n"):
            if ":\t" in line:
                key, value = line.split(":\t", 1)
                props[key.strip()] = value.strip()
    except Exception:
        pass
    return props


xr = read_xresources()


def xr_color(key, fallback):
    return xr.get(key, fallback)


# --------------------------------------------------
# Esc in INSERT mode: leave insert + clear page focus
# --------------------------------------------------
config.bind(
    "<Escape>",
    "mode-leave ;; jseval -q document.activeElement && document.activeElement.blur()",
    mode="insert",
)

# ==================================================
# STATUSBAR (transparent + white text)
# ==================================================
c.colors.statusbar.normal.bg = "#00000000"
c.colors.statusbar.command.bg = "#00000000"
c.colors.statusbar.insert.bg = "#00000000"
c.colors.statusbar.passthrough.bg = "#00000000"

c.colors.statusbar.normal.fg = "#ffffff"
c.colors.statusbar.command.fg = "#ffffff"
c.colors.statusbar.insert.fg = "#ffffff"
c.colors.statusbar.passthrough.fg = "#ffffff"

c.colors.statusbar.url.fg = "#ffffff"
c.colors.statusbar.url.success.https.fg = "#a6e3a1"
c.colors.statusbar.url.hover.fg = "#89b4fa"

# ==================================================
# TABS (transparent + active highlight + indicator)
# ==================================================
c.tabs.show = "multiple"

c.colors.tabs.bar.bg = "#00000000"
c.colors.tabs.even.bg = "#00000000"
c.colors.tabs.odd.bg = "#00000000"

c.colors.tabs.even.fg = "#6c7086"
c.colors.tabs.odd.fg = "#6c7086"

# Tab indicator (underline)
c.tabs.indicator.width = 1
c.colors.tabs.indicator.start = "#89b4fa"
c.colors.tabs.indicator.stop = "#89b4fa"

c.tabs.padding = {"top": 0, "bottom": 0, "left": 0, "right": 0}
c.tabs.width = "1%"
c.tabs.title.format = "{current_title}"
# ==================================================
# COMPLETION
# ==================================================
bg = xr_color("*.background", "#111111")
fg = xr_color("*.foreground", "#ffffff")

c.colors.completion.odd.bg = bg
c.colors.completion.even.bg = bg
c.colors.completion.fg = fg
c.colors.completion.category.bg = bg
c.colors.completion.category.fg = fg

c.colors.completion.item.selected.bg = "#313244"
c.colors.completion.item.selected.fg = "#ffffff"
c.colors.completion.match.fg = "#89b4fa"

# ==================================================
# HINTS
# ==================================================
c.colors.hints.bg = "#11111b"
c.colors.hints.fg = "#89b4fa"
c.hints.border = "#89b4fa"

# ==================================================
# MESSAGES / DOWNLOADS
# ==================================================
c.colors.messages.info.bg = "#11111b"
c.colors.messages.info.fg = "#ffffff"
c.colors.messages.error.bg = "#1e1e2e"
c.colors.messages.error.fg = "#f38ba8"

c.colors.downloads.bar.bg = "#11111b"
c.colors.downloads.start.bg = "#a6e3a1"
c.colors.downloads.start.fg = "#11111b"
c.colors.downloads.stop.bg = "#f38ba8"
c.colors.downloads.stop.fg = "#11111b"

# Mode colors
c.colors.statusbar.normal.bg = "#1e1e2e"
c.colors.statusbar.command.bg = "#fab387"
c.colors.statusbar.caret.bg = "#f9e2af"

c.colors.statusbar.normal.fg = "#cdd6f4"
c.colors.statusbar.command.fg = "#1e1e2e"
c.colors.statusbar.caret.fg = "#1e1e2e"

# ==================================================
# WEBPAGE / DARK MODE
# ==================================================
c.colors.webpage.preferred_color_scheme = "dark"

# ==================================================
# FONTS
# ==================================================
c.fonts.default_size = "9pt"
c.fonts.web.size.default = 21
c.fonts.web.family.standard = "monospace"

# ==================================================
# SEARCH ENGINES
# ==================================================
c.url.searchengines = {
    "DEFAULT": "https://www.google.com/search?q={}",
    "aw": "https://wiki.archlinux.org/?search={}",
    "apkg": "https://archlinux.org/packages/?q={}",
    "gh": "https://github.com/search?q={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}
c.url.default_page = "~/.config/qutebrowser/redirectPage.html"

# ==================================================
# SESSION / AUTOCONFIG
# ==================================================
config.load_autoconfig(True)
c.auto_save.session = True

# ==================================================
# KEYBINDS
# ==================================================
config.bind("=", "cmd-set-text -s :open")
config.bind("h", "history")
config.bind("cs", "cmd-set-text -s :config-source")
config.bind("T", "hint links tab")
config.bind("<ctrl-y>", "spawn --userscript ytdl.sh")

# ==================================================
# PRIVACY / ADBLOCK
# ==================================================
config.set("content.webgl", False, "*")
config.set("content.canvas_reading", False)
config.set("content.geolocation", False)
c.content.blocking.enabled = True

# open pdfs
c.content.pdfjs = True

# Ad block
c.content.blocking.enabled = True
c.content.blocking.method = "adblock"

# Stay in insert mode even when clicking with the mouse
c.input.insert_mode.auto_load = True
c.input.insert_mode.auto_leave = False

# ==================================================
# VIM-STYLE SCROLLING & NAVIGATION
# ==================================================

# hjkl = spatial scrolling
config.bind("h", "scroll left")
config.bind("j", "scroll down")
config.bind("k", "scroll up")
config.bind("l", "scroll right")

# H / L = browser history
config.bind("H", "back")
config.bind("L", "forward")

# --------------------------------------------------
# Smooth scrolling
# --------------------------------------------------
c.scrolling.smooth = True

# --------------------------------------------------
# statusbar
# --------------------------------------------------
c.tabs.show = "always"
