//@ pragma IconTheme Flat-Remix-Blue-Dark
// Glass panels: launcher, shortcuts, wallpaper, windows, power, HUD.
// Water glass (common/WaterGlass.qml) tinted from the palette, pouring from the top.
// Run:   qs -c glass              (autostarted from hypr/lua/startup.lua)
// Use:   qs ipc -c glass call glass toggle|open|dismiss <panel>[:arg]
//        panels: launcher shortcuts wallpaper[:effects] windows power hud
//        (hypr/scripts/glass.sh wraps this for keybinds)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "common"

ShellRoot {
    id: root

    property string current: ""      // open panel, "" = none
    property string arg: ""          // e.g. "effects" for wallpaper:effects
    property string screenName: ""   // monitor it shows on
    property int serial: 0           // bumps on every open, so re-opening resets the panel

    function open(spec) {
        const parts = spec.split(":")
        const mon = Hyprland.focusedMonitor
        if (!mon) return
        arg = parts[1] || ""
        screenName = mon.name
        current = parts[0]
        serial++
    }
    function close() { current = "" }

    // HUD is hold-to-show: the held key re-sends `open hud` at the repeat rate,
    // and it hides itself if those stop (Hyprland drops some release events).
    Timer { id: hudWatchdog; interval: 600; onTriggered: if (root.current === "hud") root.close() }

    IpcHandler {
        target: "glass"
        function toggle(spec: string): void {
            if (root.current === spec.split(":")[0]) root.close(); else root.open(spec)
        }
        function open(spec: string): void {
            if (spec === "hud") {
                hudWatchdog.restart()
                if (root.current === "hud") return
            }
            root.open(spec)
        }
        function dismiss(spec: string): void {
            if (root.current === spec.split(":")[0]) root.close()
        }
    }

    // Keybinds arrive as Hyprland global shortcuts: the key goes straight to
    // this running shell, no process spawned per press (qs ipc costs ~120 ms).
    // Bound in hypr/lua/keybinds.lua as hl.dsp.global("glass:<name>").
    component Toggle: GlobalShortcut {
        property string spec
        appid: "glass"
        onPressed: if (root.current === spec.split(":")[0]) root.close(); else root.open(spec)
    }
    // SUPER+Q closes whichever panel is open (hypr/lua/keybinds.lua checks first)
    GlobalShortcut { appid: "glass"; name: "close"; onPressed: root.close() }
    Toggle { name: "launcher";  spec: "launcher" }
    Toggle { name: "shortcuts"; spec: "shortcuts" }
    Toggle { name: "wallpaper"; spec: "wallpaper" }
    Toggle { name: "effects";   spec: "wallpaper:effects" }
    Toggle { name: "windows";   spec: "windows" }
    Toggle { name: "power";     spec: "power" }
    // HUD: shown while the key is held
    GlobalShortcut {
        appid: "glass"; name: "hud"
        onPressed: root.open("hud")
        onReleased: if (root.current === "hud") root.close()
    }

    // ~/.local/state/glass holds the launcher's launch counts
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/glass"]
    }

    Variants {
        model: Quickshell.screens
        GlassWindow { ctl: root }
    }
}
