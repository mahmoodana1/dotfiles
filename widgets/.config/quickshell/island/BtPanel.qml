import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "shared"
import "lib/btaudio.js" as BtAudio

// Bluetooth manager (Quickshell.Bluetooth → BlueZ), in the island and, detached
// with ⤢, in the floating panel (FloatPanel.qml sets `floating`).
// Tap a device to open its actions inline: connect / trust / forget (pair for a
// new one), plus, for a connected audio device, its profile: a Hi-Fi codec or
// the headset (mic). Nothing connects until an action is picked.
// The adapter scans while the panel is open; ↻ pauses/resumes.
// Floating adds bigger text, sections, battery/signal bars and adapter traffic.
// No HoverHandlers here: they would steal `hovered` from the pill.
Item {
    id: panel

    property var host                    // DynIsland window (launch / close)
    property bool active: false
    property bool floating: false
    signal detach()
    signal closeRequested()

    property bool scanning: true
    property bool showAll: false
    property string openAddr: ""         // device whose actions are shown
    onActiveChanged: if (active) { scanning = true; showAll = false; openAddr = ""; traffic.reset() }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var allDevs: Bluetooth.devices.values
        .filter(d => d.deviceName && d.deviceName !== d.address.replace(/:/g, "-"))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                        || a.deviceName.localeCompare(b.deviceName))
    readonly property int limit: 7
    readonly property var devs: showAll ? allDevs : allDevs.slice(0, limit)
    readonly property var connectedDevs: devs.filter(d => d.connected)
    readonly property var otherDevs: devs.filter(d => !d.connected)

    // set on change only (no Binding): the island and floating copies would
    // otherwise fight over the one adapter
    readonly property bool wantScan: active && on && scanning
    onWantScanChanged: if (adapter) adapter.discovering = wantScan

    // ---- signal + traffic (floating only): btsignal.py, once a second ------
    property var signals: ({})           // address -> RSSI dBm or null
    Process {
        running: panel.active && panel.floating
        command: ["python3", Qt.resolvedUrl("btsignal.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                let j
                try { j = JSON.parse(line) } catch (e) { return }
                panel.signals = j.rssi
                traffic.rx = j.rx; traffic.tx = j.tx
                traffic.sample()
            }
        }
    }

    // ---- audio profiles (pactl): read on open and on every card event ------
    property var audio: ({})             // address -> { card, active, options }
    Process {
        id: cardsRead
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector { onStreamFinished: panel.audio = BtAudio.parse(this.text) }
    }
    Timer { id: cardsSoon; interval: 150; onTriggered: cardsRead.running = true }
    Process {
        running: panel.active && panel.on
        command: ["pactl", "subscribe"]
        onRunningChanged: if (running) cardsSoon.restart()
        stdout: SplitParser { onRead: line => { if (line.indexOf(" on card ") >= 0) cardsSoon.restart() } }
    }
    function setProfile(addr, name) {
        const c = audio[addr]
        if (!c || c.active === name) return
        Quickshell.execDetached(["pactl", "set-card-profile", c.card, name])
        const m = Object.assign({}, audio)
        m[addr] = Object.assign({}, c, { active: name })
        audio = m
    }

    // text sizes: island / floating
    function fs(n) { return floating ? Math.round(n * 1.2) : n }
    // the island window is 380 tall; past this the list scrolls
    readonly property int listMax: floating ? 520 : 280

    implicitWidth: 380
    implicitHeight: header.y + header.height + 6 + list.height
                    + (traffic.visible ? traffic.height + 18 : 0) + 16

    function kindIcon(icon) {
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0) return "\u{f02cb}"
        if (icon.indexOf("keyboard") >= 0) return "\u{f030c}"
        if (icon.indexOf("mouse") >= 0) return "\u{f037d}"
        if (icon.indexOf("phone") >= 0) return "\u{f03f2}"
        if (icon.indexOf("audio") >= 0) return "\u{f04c3}"
        return "\u{f00af}"
    }
    // RSSI dBm -> 0..1  (-90 weak … -40 excellent)
    function signalLevel(dbm) { return Math.max(0, Math.min(1, (dbm + 90) / 50)) }
    function signalWord(dbm) {
        return dbm >= -55 ? "excellent" : dbm >= -67 ? "good" : dbm >= -78 ? "fair" : "weak"
    }
    function pair(d) { d.trusted = true; d.pair() }
    // after pairing, connect right away
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() { if (modelData.paired && !modelData.connected) modelData.connect() }
        }
    }

    component SectionLabel: GlassText {
        size: 11; weight: Font.Bold
        color: Qt.rgba(1, 1, 1, 0.55)
    }

    component DeviceRow: Item {
        id: row
        required property var modelData
        readonly property var d: modelData
        readonly property bool busy: d.pairing || d.state === BluetoothDeviceState.Connecting
                                      || d.state === BluetoothDeviceState.Disconnecting
        readonly property bool known: d.paired || d.trusted
        readonly property bool open: panel.openAddr === d.address
        readonly property bool bars: panel.floating && d.connected
        readonly property var audio: d.connected ? panel.audio[d.address] : undefined
        readonly property string profile: BtAudio.activeLabel(audio)
        readonly property int lineH: panel.floating ? 40 : 32
        readonly property int baseH: lineH + (bars ? meters.height + 8 : 0)
        width: col.width
        height: baseH + (open ? actions.height + 8 : 0)
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: tap.pressed ? Qt.rgba(1, 1, 1, 0.16)
                 : d.connected || row.open ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        }

        // main line: tap opens / closes the actions
        Item {
            width: parent.width
            height: row.lineH
            GlassText {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: panel.kindIcon(d.icon || "")
                size: panel.fs(14)
            }
            GlassText {
                x: panel.floating ? 40 : 36
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - status.width - more.width - 8
                text: d.deviceName
                elide: Text.ElideRight
                size: panel.fs(12)
                weight: d.connected ? Font.Bold : Font.Medium
            }
            GlassText {
                id: status
                anchors.right: more.left
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                size: panel.fs(10)
                color: Qt.rgba(1, 1, 1, d.connected ? 0.85 : 0.6)
                text: row.busy ? "…"
                    : d.connected ? (d.batteryAvailable && !panel.floating ? Math.round(d.battery * 100) + "%  " : "")
                                    + "connected" + (row.profile ? "  ·  " + row.profile : "")
                    : d.paired ? "paired" : "new"
            }
            Item {
                id: more
                anchors.right: parent.right
                width: 32; height: row.lineH
                GlassText {
                    anchors.centerIn: parent
                    text: "\u{f01d8}"
                    size: panel.fs(14)
                    color: row.open ? "white" : Qt.rgba(1, 1, 1, 0.6)
                }
            }
            TapHandler { id: tap; onTapped: panel.openAddr = row.open ? "" : d.address }
        }

        Column {             // floating only: battery + signal
            id: meters
            x: 40; y: row.lineH - 4
            spacing: 6
            visible: row.bars
            Meter {
                icon: "\u{f0079}"
                title: "Battery"
                level: d.batteryAvailable ? d.battery : -1
                value: d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "not reported"
            }
            Meter {
                readonly property var dbm: panel.signals[d.address]
                readonly property bool has: dbm !== undefined && dbm !== null
                icon: "\u{f08bf}"
                title: "Signal"
                level: has ? panel.signalLevel(dbm) : -1
                value: has ? dbm + " dBm  ·  " + panel.signalWord(dbm) : "n/a for LE devices"
            }
        }

        Column {
            id: actions
            x: panel.floating ? 40 : 36; y: row.baseH + 2
            width: row.width - x - 10
            spacing: 8
            visible: row.open
            opacity: row.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Row {
                spacing: 6
                PillButton {
                    visible: !row.known
                    size: panel.fs(10)
                    text: d.pairing ? "Pairing…" : "Pair"
                    onClicked: if (!d.pairing) panel.pair(d)
                }
                PillButton {
                    visible: row.known
                    size: panel.fs(10)
                    text: d.connected ? "Disconnect" : "Connect"
                    onClicked: d.connected ? d.disconnect() : d.connect()
                }
                PillButton {
                    visible: row.known
                    size: panel.fs(10)
                    text: d.trusted ? "Untrust" : "Trust"
                    onClicked: d.trusted = !d.trusted
                }
                PillButton {
                    visible: row.known
                    size: panel.fs(10)
                    text: "Forget"
                    danger: true
                    onClicked: { panel.openAddr = ""; d.forget() }
                }
            }
            Flow {           // audio profile: Hi-Fi codecs, then headset (mic)
                visible: row.audio !== undefined && row.audio.options.length > 1
                width: parent.width
                spacing: 6
                Repeater {
                    model: row.audio ? row.audio.options : []
                    delegate: PillButton {
                        required property var modelData
                        size: panel.fs(10)
                        text: (modelData.call ? "\u{f036c} " : "") + modelData.label
                        selected: row.audio.active === modelData.name
                        onClicked: panel.setProfile(d.address, modelData.name)
                    }
                }
            }
        }
    }

    // ---- header -----------------------------------------------------------------
    Item {
        id: header
        x: 16; y: panel.floating ? 16 : 12
        width: panel.width - 32
        height: panel.floating ? 34 : 30
        GlassText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f00af}  Bluetooth"
            size: panel.fs(13); weight: Font.Bold
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            GlassText {          // scan: spins while discovering, tap to pause/resume
                id: scanIcon
                visible: panel.on
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f0450}"
                size: panel.fs(14)
                color: panel.scanning ? "white" : Qt.rgba(1, 1, 1, 0.45)
                transformOrigin: Item.Center
                RotationAnimation on rotation {
                    running: panel.active && panel.adapter !== null && panel.adapter.discovering
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 1200
                    onRunningChanged: if (!running) scanIcon.rotation = 0
                }
                TapHandler { onTapped: panel.scanning = !panel.scanning }
            }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: panel.on
                onToggled: on => { if (panel.adapter) panel.adapter.enabled = on }
            }
            GlassText {          // ⤢ detach to the floating panel / ✕ close it
                anchors.verticalCenter: parent.verticalCenter
                text: panel.floating ? "\u{f0156}" : "\u{f03cc}"
                size: panel.fs(14)
                color: Qt.rgba(1, 1, 1, 0.7)
                TapHandler { onTapped: panel.floating ? panel.closeRequested() : panel.detach() }
            }
        }
    }

    // ---- devices ------------------------------------------------------------------
    Flickable {
        id: list
        x: 16
        y: header.y + header.height + 6
        width: panel.width - 32
        height: Math.min(col.implicitHeight, panel.listMax)
        contentHeight: col.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: list.width
            spacing: panel.floating ? 6 : 4
            topPadding: panel.floating ? 4 : 0

            GlassText {
                visible: !panel.on || panel.allDevs.length === 0
                text: !panel.on ? "Bluetooth is off" : "Searching…"
                size: panel.fs(11)
                color: Qt.rgba(1, 1, 1, 0.6)
            }

            SectionLabel {
                visible: panel.floating && panel.on && panel.connectedDevs.length > 0
                text: "Connected"
            }
            Repeater {
                model: panel.on ? panel.connectedDevs : []
                delegate: DeviceRow { }
            }
            SectionLabel {
                visible: panel.floating && panel.on && panel.otherDevs.length > 0
                text: "Other devices"
            }
            Repeater {
                model: panel.on ? panel.otherDevs : []
                delegate: DeviceRow { }
            }

            PillButton {
                visible: panel.on && !panel.showAll && panel.allDevs.length > panel.limit
                anchors.horizontalCenter: parent.horizontalCenter
                size: panel.fs(10)
                text: "Show all (" + panel.allDevs.length + ")"
                onClicked: panel.showAll = true
            }
        }
    }

    Traffic {
        id: traffic
        visible: panel.floating && panel.on
        x: 26
        y: list.y + list.height + 12
        note: "all Bluetooth devices"
    }
}
