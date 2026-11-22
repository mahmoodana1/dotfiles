// Halo — the Dynamic Island, rebuilt. A frosted pill (Hyprland blur, tinted
// from the device palette) that emerges from the top edge on events —
// workspace switch, volume / mic / brightness, notifications, charger — shows
// the full bar while SUPER is held, and opens a control center on click.
// It is also the notification daemon.
//
// Run:   qs -c island               (managed by ~/.config/hypr/scripts/bar.sh)
// IPC:   qs ipc -c island call island <fn> ...
//        down | up | shiftdown | info <bool> | panel <control|wifi|bt|sound|notifs|system|none>
//        float <wifi|bt|none> | hub <key> | hubclose | act <key> <action>
//        ws | charger | notify <summary> <body> | ignorefs <bool>
// Tests: /usr/lib/qt6/bin/qmltestrunner -input tests
// The previous liquid-glass island lives on in ../island-glass.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import "lib/mode.js" as M

ShellRoot {
    id: root

    // ---- state ---------------------------------------------------------------
    property bool held: false               // SUPER down
    property bool shift: false              // SUPER+SHIFT: show over fullscreen
    property bool ignoreFullscreen: false
    property real now: Date.now()
    property var until: ({ ws: 0, level: 0, notif: 0, toast: 0 })
    property bool hoverHold: false          // pointer on the island: events don't time out
    property string panel: ""               // control | wifi | bt | notifs
    property string panelScreen: ""         // monitor the panel opened on
    property bool pinned: false             // keyboard-driven hub: stays until closed
    property string hubKey: ""              // notification to highlight in the hub

    property string levelKind: "volume"     // volume | mic | brightness
    property real levelValue: 0
    property bool levelMuted: false
    property var notif: ({ key: "", app: "", summary: "", body: "", icon: "", urgency: 1 })
    property real notifMs: 4000
    property string toastIcon: ""
    property string toastText: ""

    readonly property bool critical: notif.urgency >= 2
    readonly property string view: M.pick({
        panel: panel, held: held, critical: critical,
        wsUntil: until.ws, levelUntil: until.level, notifUntil: until.notif, toastUntil: until.toast
    }, now)
    readonly property string focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // ---- actions ---------------------------------------------------------------
    property bool armed: false              // ignore the burst while services start
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    function pulse(which, ms) {
        if (!armed) return
        const t = Date.now()
        until = M.pulse(until, which, t, ms)
        now = t
    }
    Timer {                                 // ticks only while something is timing out
        interval: 50; repeat: true
        running: root.now < Math.max(root.until.ws, root.until.level, root.until.notif, root.until.toast)
        onTriggered: {
            const t = Date.now()
            if (root.hoverHold && ["level", "notif", "toast"].indexOf(root.view) >= 0) {
                const u = Object.assign({}, root.until)
                u[root.view] = Math.max(u[root.view], t + 500)
                root.until = u
            }
            root.now = t
        }
    }
    function openPanel(name) {
        if (!M.isPanel(name)) { closePanel(); return }
        if (panel === "") panelScreen = focusedScreen
        if (name !== "notifs") hubKey = ""
        panel = name
        if (view === "notif") until = Object.assign({}, until, { notif: 0 })
    }
    function closePanel() { panel = ""; pinned = false; hubKey = "" }
    function openHub(key) { hubKey = key || ""; openPanel("notifs") }
    function dismiss() {                    // click on a popup: close it
        if (panel !== "") { closePanel(); return }
        until = { ws: 0, level: 0, notif: 0, toast: 0 }
        now = Date.now()
    }
    function toast(icon, text, ms) { toastIcon = icon; toastText = text; pulse("toast", ms) }
    function showLevel(kind, value, muted) {
        levelKind = kind; levelValue = value; levelMuted = muted
        pulse("level", 1400)
    }

    // ---- keys ----------------------------------------------------------------
    Process {
        id: keys
        running: true
        command: ["python3", Quickshell.shellDir + "/superkeys.py"]
        stdout: SplitParser {
            onRead: line => {
                const [k, v] = line.trim().split(" ")
                if (k === "super") root.held = v === "1"
                else if (k === "shift") root.shift = v === "1"
            }
        }
        onExited: { root.held = false; root.shift = false; keysRestart.start() }
    }
    Timer { id: keysRestart; interval: 1000; onTriggered: keys.running = true }

    GlobalShortcut { appid: "island"; name: "close"; onPressed: root.closePanel() }    // SUPER+Q
    GlobalShortcut {                        // SUPER+SHIFT+N: the hub, keyboard-driven
        appid: "island"; name: "notifs"
        onPressed: {
            if (root.panel === "notifs") { root.closePanel(); return }
            root.openHub("")
            root.pinned = true
        }
    }

    // ---- workspaces --------------------------------------------------------------
    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    onFocusedWsChanged: pulse("ws", 650)

    // ---- audio -------------------------------------------------------------------
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

    // ---- brightness (sysfs has no change events: a light poll) ---------------------
    property string backlight: ""
    property int blMax: 1
    property real brightness: -1            // 0..1, -1 = no backlight
    property int blLast: -1
    Process {
        running: true
        command: ["sh", "-c", "d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1); [ -n \"$d\" ] && echo \"$d $(cat $d/max_brightness)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ")
                if (p.length === 2) { root.backlight = p[0]; root.blMax = Number(p[1]) || 1 }
            }
        }
    }
    FileView { id: blFile; path: root.backlight ? root.backlight + "/brightness" : ""; printErrors: false }
    Timer {
        interval: 200; repeat: true
        running: root.backlight !== ""
        onTriggered: {
            blFile.reload()
            const v = Number(blFile.text().trim())
            if (isNaN(v)) return
            root.brightness = v / root.blMax
            if (root.blLast >= 0 && v !== root.blLast && !root.settingBrightness) root.showLevel("brightness", v / root.blMax, false)
            root.blLast = v
        }
    }
    property bool settingBrightness: false  // our own slider: no popup over the panel
    Timer { id: blQuiet; interval: 600; onTriggered: root.settingBrightness = false }
    function setBrightness(v) {
        settingBrightness = true; blQuiet.restart()
        brightness = v
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.max(1, Math.round(v * 100)) + "%"])
    }

    // ---- battery -----------------------------------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery
    readonly property int batteryPct: !hasBattery ? 0
        : Math.round(battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage)
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging
                                                    || battery.state === UPowerDeviceState.FullyCharged)
    onChargingChanged: if (hasBattery)
        toast(charging ? Glyphs.charging : Glyphs.battery(batteryPct, false),
              (charging ? "Charging" : "On battery") + "  " + batteryPct + "%", 1800)

    // ---- network / bluetooth (touch now: they connect to D-Bus lazily) -------------
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) || null : null
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    Component.onCompleted: { Networking.wifiEnabled; Bluetooth.defaultAdapter }

    // ---- the Center's extras --------------------------------------------------------
    readonly property alias stats: statsObj
    Stats {
        id: statsObj
        active: root.panel !== ""
        iface: root.wifiDev && root.wifiDev.name ? root.wifiDev.name : "wlan0"
    }
    property bool dnd: false                // Do Not Disturb: popups only for critical ones
    property bool awake: false              // Keep awake: an idle inhibitor lock (hypridle honours it)
    Process {
        running: root.awake
        command: ["systemd-inhibit", "--what=idle", "--who=Halo", "--why=Keep awake", "sleep", "infinity"]
    }
    property bool airplane: false           // every radio soft-blocked (rfkill)
    Process {
        id: rfRead
        running: root.panel !== ""
        command: ["sh", "-c", "rfkill -n -o SOFT | sort -u"]
        stdout: StdioCollector { onStreamFinished: root.airplane = this.text.trim() === "blocked" }
    }
    function setAirplane(on) {
        airplane = on
        Quickshell.execDetached(["rfkill", on ? "block" : "unblock", "all"])
    }

    // ---- notifications -------------------------------------------------------------
    readonly property alias notifs: store
    NotifStore {
        id: store
        onPosted: e => {
            if (root.dnd && e.urgency < 2) return   // kept in the list, no popup
            root.notif = e
            const ms = e.urgency >= 2 ? 6500 : 4200
            root.notifMs = e.timeout > 0 ? Math.max(1200, Math.min(ms, e.timeout)) : ms
            root.pulse("notif", root.notifMs)
        }
    }

    // ---- IPC (same calls as the old island: keybinds and scripts use them) --------
    IpcHandler {
        target: "island"
        function down(): void { root.held = true }
        function up(): void { root.held = false; root.shift = false }
        function shiftdown(): void { root.held = true; root.shift = true }
        function info(open: bool): void { if (open) root.openPanel("compact"); else if (root.panel === "compact") root.closePanel() }
        function panel(name: string): void { root.openPanel(name) }
        function float(name: string): void { root.openPanel(name) }       // no floating card: opens in the island
        function hub(key: string): void { root.openHub(key) }
        function hubclose(): void { if (root.panel === "notifs") root.closePanel() }
        function act(key: string, action: string): void { store.invoke(key, action) }
        function ignorefs(on: bool): void { root.ignoreFullscreen = on }
        function ws(): void { root.pulse("ws", 650) }
        function charger(): void { root.toast(Glyphs.charging, "Charging  " + root.batteryPct + "%", 1800) }
        function notify(summary: string, body: string): void {
            root.notif = { key: "", app: "Test", summary: summary, body: body, icon: "", urgency: 1 }
            root.notifMs = 4200
            root.pulse("notif", 4200)
        }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: scr
            required property var modelData
            Island { id: isl; modelData: scr.modelData; ctl: root }

            // pointer at the top-middle edge peeks the island (not over fullscreen)
            PanelWindow {
                screen: scr.modelData
                visible: !isl.fullscreen && !isl.shown
                anchors.top: true
                implicitWidth: 240
                implicitHeight: 1               // 1px: barely steals clicks from windows under it
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "island-edge"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                HoverHandler { id: edge; onHoveredChanged: if (hovered) dwell.restart(); else dwell.stop() }
                Timer {                         // short dwell so flinging at top tabs doesn't pop it
                    id: dwell; interval: 120
                    onTriggered: { root.openPanel("compact"); root.panelScreen = isl.monName }
                }
            }
        }
    }
}
