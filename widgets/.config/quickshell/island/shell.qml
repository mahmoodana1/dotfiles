// Dynamic Island — a liquid-glass pill that pops out of the top edge on
// events (workspace switch, volume/mic/brightness, notifications,
// charger) and shows
// everything while SUPER is held. Hidden otherwise.
// Run:    qs -c island         (managed by ~/.config/hypr/scripts/bar.sh)
// Shares glass/text/stats with the Peek bar through the `shared` -> ../peek link.
// It's also the notification daemon (Notifs.qml): popups on the island, a
// hub (NotifPanel.qml) on click or SUPER+SHIFT+N.
// Test:   qs ipc -c island call island down|up|shiftdown|info <true|false>|panel <wifi|bt|notifs|>|float <bt|wifi|none>|ws|charger|notify <summary> <body>|hub <key>|hubclose|act <key> <action>
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
    property string panel: ""                // "wifi" | "bt" | "notifs": list panel in the island
    property string floating: ""             // "bt" | "wifi": panel detached to the middle (FloatPanel.qml)
    // SUPER+Q closes the floating panel (hypr/lua/keybinds.lua checks first)
    GlobalShortcut { appid: "island"; name: "close"; onPressed: root.floating = "" }
    // SUPER+SHIFT+N: the hub, pinned: it holds the keyboard and stays until
    // Ctrl+] / Esc (or the shortcut again), not just while hovered
    GlobalShortcut {
        appid: "island"; name: "notifs"
        onPressed: {
            if (root.panel === "notifs") { root.closeHub(); return }
            root.openHub("")
            root.hubPinned = true
        }
    }
    property rect floatFrom: Qt.rect(0, 0, 0, 0)   // island rect it springs out of / back into
    property string floatScreen: ""          // monitor name it shows on

    property string levelKind: "volume"      // volume | mic | brightness
    property real levelValue: 0              // 0..1
    property bool levelMuted: false
    property var notif: ({ key: "", app: "", summary: "", body: "", icon: "", urgency: 1 })
    property string hubKey: ""               // notification open in the hub ("" = the list)
    property bool hubPinned: false           // hub driven by keyboard: pointer leaving / idling won't close it
    property string toastIcon: ""
    property string toastText: ""

    // what the island shows, by priority
    readonly property string mode: panel !== "" ? panel
        : infoOpen ? "info"
        : now < levelUntil ? "level"             // volume/brightness: always shown the moment it changes
        : held ? "full"
        : now < notifUntil ? "notif"
        : now < toastUntil ? "toast"
        : now < wsUntil ? "ws"
        : "hidden"

    // Networking/Bluetooth connect to D-Bus lazily on first access; touch them
    // now so the panels have data when opened.
    Component.onCompleted: {
        Networking.wifiEnabled; Bluetooth.defaultAdapter
        TextStyle.minWeight = Font.Bold      // small island labels read better bold
    }

    // ignore the burst of property changes while services start up
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    Timer {
        interval: 50
        repeat: true
        running: root.now < Math.max(root.wsUntil, root.levelUntil, root.notifUntil, root.toastUntil)
        onTriggered: {
            const t = Date.now()
            // hovering keeps whatever is showing open (not workspace switches: those never linger)
            if (root.hoverHold && root.mode !== "hidden" && root.mode !== "full") {
                const keep = t + 400
                if (root.mode === "notif") root.notifUntil = Math.max(root.notifUntil, keep)
                else if (root.mode === "toast") root.toastUntil = Math.max(root.toastUntil, keep)
                else if (root.mode === "level") root.levelUntil = Math.max(root.levelUntil, keep)
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
    function openHub(key) {
        hubKey = key
        panel = "notifs"
        if (mode === "notif") notifUntil = 0     // the popup becomes the hub
    }
    function closeHub() { if (panel === "notifs") panel = "" }
    onPanelChanged: if (panel !== "notifs") { hubKey = ""; hubPinned = false }
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
    onFocusedWsChanged: pulse("ws", 300)   // flash on every switch, then gone at once

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

    // ---- notifications (we're the daemon: Notifs.qml) ----------------------
    readonly property alias notifs: notifStore
    Notifs {
        id: notifStore
        onPosted: e => {
            root.notif = { key: e.key, app: e.app, summary: e.summary, body: e.body,
                           icon: e.image || e.appIcon, urgency: e.urgency }
            // the app's own timeout when it's shorter (screenshot countdown)
            const ms = e.urgency >= 2 ? 6000 : 4000
            root.pulse("notif", e.timeout > 0 ? Math.max(1000, Math.min(ms, e.timeout)) : ms)
            root.sweep()
        }
    }
    // A transient notification lives only while its popup or its full view
    // in the hub shows it; then it's dismissed (notify-send -A gets its answer).
    function sweep() {
        notifStore.entries.filter(e => e.transient).forEach(e => {
            const shown = (mode === "notif" && notif.key === e.key) || (panel === "notifs" && hubKey === e.key)
            if (!shown) notifStore.dismiss(e.key)
        })
    }
    onModeChanged: Qt.callLater(sweep)
    onHubKeyChanged: Qt.callLater(sweep)

    // ---- manual control / testing -----------------------------------------
    IpcHandler {
        target: "island"
        function down(): void { root.held = true }
        function up(): void { root.held = false; root.shiftHeld = false }
        function info(open: bool): void { root.infoOpen = open }
        function panel(name: string): void { root.panel = name === "none" ? "" : name }   // wifi | bt | notifs | none
        function hub(key: string): void { root.openHub(key) }
        function hubclose(): void { root.closeHub() }
        function act(key: string, action: string): void { notifStore.invoke(key, action) }
        function float(name: string): void {                                                // bt | wifi | none
            if (name !== "none" && Hyprland.focusedMonitor) {
                root.floatFrom = Qt.rect(0, 0, 0, 0)
                root.floatScreen = Hyprland.focusedMonitor.name
            }
            root.floating = name === "none" ? "" : name
        }
        function ignorefs(on: bool): void { root.ignoreFullscreen = on }   // testing only
        function shiftdown(): void { root.held = true; root.shiftHeld = true }
        function ws(): void { root.pulse("ws", 300) }
        function charger(): void { root.toast("\u{f0084}", "Charging  " + Stats.batteryPct + "%", 1600) }
        function notify(summary: string, body: string): void {
            root.notif = { key: "", app: "Test", summary: summary, body: body, icon: "", urgency: 1 }
            root.pulse("notif", 4000)
        }
    }

    Variants {
        model: Quickshell.screens
        DynIsland { ctl: root }
    }
    Variants {                               // after the islands: stacks above them
        model: Quickshell.screens
        FloatPanel { ctl: root }
    }
}
