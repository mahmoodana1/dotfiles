// Dynamic Island — a liquid-glass pill that pops out of the top edge on
// events (workspace switch, volume/mic/brightness, notifications,
// charger) and shows
// everything while SUPER is held. Hidden otherwise.
// Run:    qs -c island         (managed by ~/.config/hypr/scripts/PeekBar.sh)
// Shares glass/text/stats with the Peek bar through the `shared` -> ../peek link.
// Test:   qs ipc -c island call island down|up|shiftdown|info <true|false>|panel <wifi|bt|>|ws|charger|notify <summary> <body>
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import "shared"

ShellRoot {
    id: root

    // ---- state ------------------------------------------------------------
    property bool held: false
    property bool shiftHeld: false           // SUPER+SHIFT shows the island over fullscreen
    property real now: Date.now()
    property real wsUntil: 0
    property real levelUntil: 0
    property real notifUntil: 0
    property real toastUntil: 0
    property bool hoverHold: false           // pointer on the island: don't time out
    property bool ignoreFullscreen: false    // testing: show even over fullscreen
    property bool infoOpen: false            // hover panel (cpu/mem/wifi/bluetooth...)
    property string panel: ""                // "wifi" | "bt": list panel opened from the info chips

    property string levelKind: "volume"      // volume | mic | brightness
    property real levelValue: 0              // 0..1
    property bool levelMuted: false
    property var notif: ({ app: "", summary: "", body: "", icon: "", urgency: 1 })
    property string toastIcon: ""
    property string toastText: ""

    // what the island shows, by priority
    readonly property string mode: panel !== "" ? panel
        : infoOpen ? "info"
        : held ? "full"
        : now < notifUntil ? "notif"
        : now < toastUntil ? "toast"
        : now < levelUntil ? "level"
        : now < wsUntil ? "ws"
        : "hidden"

    // Networking/Bluetooth connect to D-Bus lazily on first access; touch them
    // now so the panels have data when opened.
    Component.onCompleted: { Networking.wifiEnabled; Bluetooth.defaultAdapter }

    // ignore the burst of property changes while services start up
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    Timer {
        interval: 50
        repeat: true
        running: root.now < Math.max(root.wsUntil, root.levelUntil, root.notifUntil, root.toastUntil)
        onTriggered: {
            const t = Date.now()
            // hovering keeps whatever is showing open
            if (root.hoverHold && root.mode !== "hidden" && root.mode !== "full") {
                const keep = t + 400
                if (root.mode === "notif") root.notifUntil = Math.max(root.notifUntil, keep)
                else if (root.mode === "toast") root.toastUntil = Math.max(root.toastUntil, keep)
                else if (root.mode === "level") root.levelUntil = Math.max(root.levelUntil, keep)
                else if (root.mode === "ws") root.wsUntil = Math.max(root.wsUntil, keep)
            }
            root.now = t
        }
    }

    function pulse(which, ms) {
        if (!armed) return
        const t = Date.now()
        if (which === "ws") wsUntil = t + ms
        else if (which === "level") levelUntil = t + ms
        else if (which === "notif") notifUntil = t + ms
        else if (which === "toast") toastUntil = t + ms
        now = t
    }
    function dismiss() {
        // click: close the current event
        if (panel !== "") { panel = ""; return }
        if (infoOpen) { infoOpen = false; return }
        if (mode === "notif") notifUntil = 0
        else if (mode === "toast") toastUntil = 0
        else if (mode === "level") levelUntil = 0
        else if (mode === "ws") wsUntil = 0
        now = Date.now()
    }
    function toast(icon, text, ms) {
        toastIcon = icon; toastText = text
        pulse("toast", ms)
    }
    function showLevel(kind, value, muted) {
        levelKind = kind; levelValue = value; levelMuted = muted
        pulse("level", 1500)
    }

    // ---- SUPER held (evdev) -----------------------------------------------
    Process {
        id: superwatch
        running: true
        command: ["python3", Qt.resolvedUrl("shared/superwatch.py").toString().replace("file://", ""), "--shift"]
        stdout: SplitParser {
            onRead: line => {
                const l = line.trim()
                if (l === "down" || l === "up") root.held = l === "down"
                else if (l === "shift down" || l === "shift up") root.shiftHeld = l === "shift down"
            }
        }
        onExited: { root.held = false; root.shiftHeld = false; superRestart.start() }
    }
    Timer { id: superRestart; interval: 1000; onTriggered: superwatch.running = true }
    Binding { target: Stats; property: "active"; value: root.held || root.infoOpen }

    // ---- workspace switches -----------------------------------------------
    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    onFocusedWsChanged: pulse("ws", 350)   // droplet lands in ~0.2s, then go

    // ---- volume / mic -----------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }
    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.showLevel("volume", root.sink.audio.volume, root.sink.audio.muted) }
        function onMutedChanged() { root.showLevel("volume", root.sink.audio.volume, root.sink.audio.muted) }
    }
    Connections {
        target: root.source ? root.source.audio : null
        function onVolumeChanged() { root.showLevel("mic", root.source.audio.volume, root.source.audio.muted) }
        function onMutedChanged() { root.showLevel("mic", root.source.audio.volume, root.source.audio.muted) }
    }

    // ---- brightness (sysfs has no change events; a tiny poll) -------------
    property string backlight: ""
    property int blMax: 1
    property int blLast: -1
    Process {
        running: true
        command: ["sh", "-c", "d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1); [ -n \"$d\" ] && echo \"$d $(cat $d/max_brightness)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(" ")
                if (parts.length === 2) { root.backlight = parts[0]; root.blMax = Number(parts[1]) || 1 }
            }
        }
    }
    FileView { id: blFile; path: root.backlight ? root.backlight + "/brightness" : "" }
    Timer {
        interval: 200; repeat: true
        running: root.backlight !== ""
        onTriggered: {
            blFile.reload()
            const v = Number(blFile.text().trim())
            if (isNaN(v)) return
            if (root.blLast >= 0 && v !== root.blLast) root.showLevel("brightness", v / root.blMax, false)
            root.blLast = v
        }
    }

    // ---- charger plugged / unplugged --------------------------------------
    readonly property bool charging: Stats.charging
    onChargingChanged: if (Stats.hasBattery)
        toast(charging ? "\u{f0084}" : "\u{f0079}",
              (charging ? "Charging  " : "On battery  ") + Stats.batteryPct + "%", 1600)

    // ---- notifications (swaync stays the daemon; we eavesdrop) ------------
    Process {
        id: notifwatch
        running: true
        command: ["python3", Qt.resolvedUrl("notifwatch.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                let n
                try { n = JSON.parse(line) } catch (e) { return }
                if (n.osd) return
                root.notif = n
                root.pulse("notif", n.urgency >= 2 ? 6000 : 4000)
            }
        }
        onExited: notifRestart.start()
    }
    Timer { id: notifRestart; interval: 1000; onTriggered: notifwatch.running = true }

    // ---- manual control / testing -----------------------------------------
    IpcHandler {
        target: "island"
        function down(): void { root.held = true }
        function up(): void { root.held = false; root.shiftHeld = false }
        function info(open: bool): void { root.infoOpen = open }
        function panel(name: string): void { root.panel = name === "none" ? "" : name }   // wifi | bt | none
        function ignorefs(on: bool): void { root.ignoreFullscreen = on }   // testing only
        function shiftdown(): void { root.held = true; root.shiftHeld = true }
        function ws(): void { root.pulse("ws", 350) }
        function charger(): void { root.toast("\u{f0084}", "Charging  " + Stats.batteryPct + "%", 1600) }
        function notify(summary: string, body: string): void {
            root.notif = { app: "Test", summary: summary, body: body, icon: "", urgency: 1 }
            root.pulse("notif", 4000)
        }
    }

    Variants {
        model: Quickshell.screens
        DynIsland { ctl: root }
    }
}
