pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors from ~/.config/palette/palette.conf, via the palette.json that
// `palette-apply` renders. Watched: re-running palette-apply restyles live.
//
// Tune the glass here:
//   panelTint   sea-tint strength of the glass panels (launcher, shortcuts, ...)
//   islandTint  same for the Dynamic Island (lower = clearer water)
//
// Glass style (`glass-style water|mocha|toggle`, saved in ~/.local/state/glass/style):
//   water  clear sea-tinted water (the default)
//   mocha  dark smoked glass tinted mauve -> pink (Catppuccin Mocha), over
//          Hyprland blur (hypr/lua/peek.lua adds the island's blur for it)
Singleton {
    id: pal

    property string style: "water"
    readonly property bool mocha: style === "mocha"

    property real panelTint: mocha ? 0.88 : 0.2
    property real islandTint: mocha ? 0.88 : 0.22

    // tint colours: `*Tint` top-left, `*Tint2` bottom-right; tintShade is how
    // much the tint deepens toward the bottom (1 = water's depth, 0 = flat)
    readonly property color islandTintColor: mocha ? "#1a1426" : accent
    readonly property color islandTintColor2: mocha ? "#221424" : accent
    readonly property color panelTintColor: mocha ? "#171221" : Qt.darker(accent, 1.7)   // deep water, not pale sky
    readonly property color panelTintColor2: mocha ? "#1f1221" : Qt.darker(accent, 1.7)
    readonly property real tintShade: mocha ? 0.35 : 1

    // highlight colour for text/icons that follow the theme
    readonly property color highlight: mocha ? "#cba6f7" : accent

    // how alive the panels' water is
    property real panelShade: 0.2       // smoke: higher = darker glass
    property real panelShadow: 0.45     // drop shadow under the card

    // defaults keep everything drawable if palette.json is missing or broken
    property color accent: "#64859F"
    property color background: "#00010E"
    property color foreground: "#E1E4E9"

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/palette/build/palette.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: pal.apply(text())
        onLoadFailed: console.warn("Theme: palette.json not found, using defaults (run palette-apply)")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/glass/style"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: pal.style = text().trim() === "mocha" ? "mocha" : "water"
        onLoadFailed: pal.style = "water"
    }

    function apply(json) {
        try {
            const p = JSON.parse(json)
            pal.accent = p.accent
            pal.background = p.background
            pal.foreground = p.foreground
        } catch (e) {
            // palette-apply may be mid-write; the next change event reloads
        }
    }
}
