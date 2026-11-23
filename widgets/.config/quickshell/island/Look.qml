pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Halo's look: every colour comes from the device palette
// (~/.config/palette/build/palette.json, written by palette-apply; watched,
// so re-theming restyles live). Motion timings live here too.
Singleton {
    id: look

    // ---- palette (defaults keep it drawable without palette.json) ----------
    property color bg: "#00010E"
    property color fg: "#E1E4E9"
    property color accent: "#64859F"
    property color accent2: "#AAB1BF"       // color14: the light end of gradients
    property color deep: "#13547B"          // color10: depth in the surface

    FileView {
        path: Quickshell.env("HOME") + "/.config/palette/build/palette.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const p = JSON.parse(text())
                look.bg = p.background; look.fg = p.foreground; look.accent = p.accent
                if (p.color14) look.accent2 = p.color14
                if (p.color10) look.deep = p.color10
            } catch (e) { /* palette-apply mid-write: the next change reloads */ }
        }
    }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

    // ---- surface: tinted over Hyprland's blur (hypr/lua/peek.lua) -----------
    // alphas stay above the blur's ignore_alpha (0.3) so the whole body frosts
    readonly property color surfaceTop: alpha(mix(bg, deep, 0.22), 0.62)
    readonly property color surfaceBottom: alpha(mix(bg, deep, 0.08), 0.78)
    readonly property color rim: alpha(fg, 0.10)
    readonly property color lip: alpha(fg, 0.22)          // light catching the top edge

    // ---- text / fills -------------------------------------------------------
    readonly property color text: fg
    readonly property color dim: alpha(fg, 0.62)
    readonly property color faint: alpha(fg, 0.34)
    readonly property color well: alpha(fg, 0.07)         // tiles, tracks, rows
    readonly property color wellHi: alpha(fg, 0.13)       // pressed / picked
    readonly property color onAccent: bg

    readonly property string font: "JetBrainsMono Nerd Font"

    // ---- motion: snappy, a hair of settle, never a wobble --------------------
    readonly property int morph: 260        // shape changes
    readonly property real settle: 0.9      // OutBack overshoot (0 = none)
    readonly property int fadeIn: 140
    readonly property int fadeOut: 90
    readonly property int quick: 120        // small UI (rows, switches, fills)
}
