import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "shared"

// Wi-Fi manager (Quickshell.Networking → NetworkManager), in the island and,
// detached with ⤢, in the floating panel (FloatPanel.qml sets `floating`).
// Tap a network: disconnect if connected, connect if saved/open, otherwise
// ask for the password inline. ⋯ on a saved network: connect / auto-connect
// (nmcli; Quickshell only has the device-wide switch) / forget.
// Scans while open; ↻ pauses/resumes. Floating adds bigger text, sections,
// signal bars, and link speed + traffic for the connected network.
// No HoverHandlers here: they would steal `hovered` from the pill.
Item {
    id: panel

    property var host                    // DynIsland window (launch / close)
    property bool active: false          // panel is showing
    property bool floating: false
    signal detach()
    signal closeRequested()

    readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property string iface: dev && dev.name ? dev.name : "wlan0"
    readonly property var allNets: !dev ? [] : dev.networks.values
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    readonly property int limit: 7
    property bool showAll: false
    readonly property var nets: showAll ? allNets : allNets.slice(0, limit)
    readonly property var connectedNets: nets.filter(n => n.connected)
    readonly property var otherNets: nets.filter(n => !n.connected)

    property var pwdNet: null            // network waiting for a password
    readonly property bool typing: pwdNet !== null
    property string openName: ""         // network whose actions are shown
    property bool scanning: true
    onActiveChanged: {
        if (active) { scanning = true; showAll = false; openName = ""; traffic.reset() }
        else pwdNet = null
    }

    // set on change only (no Binding): the island and floating copies would
    // otherwise fight over the one device
    readonly property bool wantScan: active && scanning
    onWantScanChanged: if (dev) dev.scannerEnabled = wantScan

    // ---- per-network auto-connect (nmcli) -------------------------------------
    property var autoconnect: ({})       // name -> true/false
    Process {
        id: acRead
        property string net
        command: ["nmcli", "-g", "connection.autoconnect", "connection", "show", "id", net]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = Object.assign({}, panel.autoconnect)
                m[acRead.net] = this.text.trim() === "yes"
                panel.autoconnect = m
            }
        }
    }
    function readAutoconnect(name) { acRead.net = name; acRead.running = true }
    function setAutoconnect(name, on) {
        Quickshell.execDetached(["nmcli", "connection", "modify", "id", name, "connection.autoconnect", on ? "yes" : "no"])
        const m = Object.assign({}, autoconnect); m[name] = on; autoconnect = m
    }

    // ---- link + traffic (floating only), once a second ----------------------
    property int linkDbm: 0
    property string linkRx: ""
    property string linkTx: ""
    Process {
        id: linkPoll
        command: ["sh", "-c", "cat /sys/class/net/" + panel.iface + "/statistics/rx_bytes /sys/class/net/"
                  + panel.iface + "/statistics/tx_bytes; iw dev " + panel.iface + " link"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                traffic.rx = Number(lines[0]); traffic.tx = Number(lines[1])
                traffic.sample()
                const t = this.text
                const sig = t.match(/signal:\s*(-?\d+)/)
                const rx = t.match(/rx bitrate:\s*([\d.]+)/)
                const tx = t.match(/tx bitrate:\s*([\d.]+)/)
                panel.linkDbm = sig ? Number(sig[1]) : 0
                panel.linkRx = rx ? Math.round(Number(rx[1])) + "" : ""
                panel.linkTx = tx ? Math.round(Number(tx[1])) + "" : ""
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: panel.active && panel.floating
        onTriggered: linkPoll.running = true
    }

    // text sizes: island / floating
    function fs(n) { return floating ? Math.round(n * 1.2) : n }
    readonly property int listMax: floating ? 520 : 280

    implicitWidth: 380
    implicitHeight: header.y + header.height + 6 + list.height
                    + (pwdBox.visible ? pwdBox.height + 6 : 0)
                    + (traffic.visible ? traffic.height + 18 : 0) + 16

    function strengthIcon(s) {
        return s > 0.75 ? "\u{f0928}" : s > 0.5 ? "\u{f0925}" : s > 0.25 ? "\u{f0922}" : "\u{f091f}"
    }
    function strengthWord(s) {
        return s > 0.75 ? "excellent" : s > 0.5 ? "good" : s > 0.25 ? "fair" : "weak"
    }
    function isOpen(n) {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe
    }
    function activate(n) {
        if (n.connected) n.disconnect()
        else if (n.known || isOpen(n)) n.connect()
        else { pwdNet = n; pwd.text = ""; pwd.forceActiveFocus() }
    }

    component SectionLabel: GlassText {
        size: 11; weight: Font.Bold
        color: Qt.rgba(1, 1, 1, 0.55)
    }

    component NetRow: Item {
        id: row
        required property var modelData
        readonly property var n: modelData
        readonly property bool open: panel.openName === n.name
        readonly property int lineH: panel.floating ? 40 : 32
        readonly property int baseH: lineH + (panel.floating ? meters.height + 8 : 0)
        width: col.width
        height: baseH + (open ? actions.height + 8 : 0)
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22)
                 : n.connected || row.open ? Qt.rgba(1, 1, 1, 0.12)
                 : panel.pwdNet === n ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        }

        Item {               // main line; stops short of ⋯
            width: parent.width - (more.visible ? more.width + 4 : 0)
            height: row.lineH
            GlassText {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: panel.strengthIcon(n.signalStrength)
                size: panel.fs(14)
            }
            GlassText {
                x: panel.floating ? 40 : 36
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - status.width - 16
                text: n.name
                elide: Text.ElideRight
                size: panel.fs(12)
                weight: n.connected ? Font.Bold : Font.Medium
            }
            GlassText {
                id: status
                anchors.right: parent.right
                anchors.rightMargin: more.visible ? 2 : 10
                anchors.verticalCenter: parent.verticalCenter
                size: panel.fs(10)
                color: Qt.rgba(1, 1, 1, n.connected ? 0.85 : 0.6)
                text: n.stateChanging ? "…"
                    : n.connected ? "connected"
                    : n.known ? "saved"
                    : panel.isOpen(n) ? "open" : "\u{f033e}"
            }
            TapHandler { id: tap; onTapped: panel.activate(n) }
        }

        Item {
            id: more
            visible: n.known
            anchors.right: parent.right
            width: 32; height: row.lineH
            GlassText {
                anchors.centerIn: parent
                text: "\u{f01d8}"
                size: panel.fs(14)
                color: row.open ? "white" : Qt.rgba(1, 1, 1, 0.6)
            }
            TapHandler {
                onTapped: {
                    panel.openName = row.open ? "" : n.name
                    if (panel.openName !== "") panel.readAutoconnect(n.name)
                }
            }
        }

        Column {             // floating only
            id: meters
            x: 40; y: row.lineH - 4
            spacing: 6
            visible: panel.floating
            Meter {
                icon: "\u{f0928}"
                title: "Signal"
                level: n.signalStrength
                value: Math.round(n.signalStrength * 100) + "%"
                       + (n.connected && panel.linkDbm < 0 ? "  ·  " + panel.linkDbm + " dBm" : "")
                       + "  ·  " + panel.strengthWord(n.signalStrength)
            }
            Meter {
                visible: n.connected && panel.linkRx !== ""
                icon: "\u{f04c5}"
                title: "Link"
                level: 0             // no bar, but not dimmed
                barW: 0
                value: "↓ " + panel.linkRx + "  ↑ " + panel.linkTx + " Mb/s"
            }
        }

        Row {
            id: actions
            x: panel.floating ? 40 : 36; y: row.baseH + 2
            spacing: 6
            visible: row.open
            opacity: row.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            PillButton {
                size: panel.fs(10)
                text: n.connected ? "Disconnect" : "Connect"
                onClicked: n.connected ? n.disconnect() : n.connect()
            }
            PillButton {
                readonly property var on: panel.autoconnect[n.name]
                size: panel.fs(10)
                text: on === undefined ? "Auto-connect …" : on ? "Auto-connect: on" : "Auto-connect: off"
                onClicked: if (on !== undefined) panel.setAutoconnect(n.name, !on)
            }
            PillButton {
                size: panel.fs(10)
                text: "Forget"
                danger: true
                onClicked: { panel.openName = ""; n.forget() }
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
            text: "\u{f05a9}  Wi-Fi"
            size: panel.fs(13); weight: Font.Bold
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            GlassText {          // scan: spins while scanning, tap to pause/resume
                id: scanIcon
                visible: Networking.wifiEnabled
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f0450}"
                size: panel.fs(14)
                color: panel.scanning ? "white" : Qt.rgba(1, 1, 1, 0.45)
                transformOrigin: Item.Center
                RotationAnimation on rotation {
                    running: panel.active && panel.scanning && Networking.wifiEnabled
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 1200
                    onRunningChanged: if (!running) scanIcon.rotation = 0
                }
                TapHandler { onTapped: panel.scanning = !panel.scanning }
            }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Networking.wifiEnabled
                onToggled: on => Networking.wifiEnabled = on
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

    // ---- networks -----------------------------------------------------------------
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
                visible: !Networking.wifiEnabled || panel.allNets.length === 0
                text: !Networking.wifiEnabled ? "Wi-Fi is off" : "Scanning…"
                size: panel.fs(11)
                color: Qt.rgba(1, 1, 1, 0.6)
            }

            SectionLabel {
                visible: panel.floating && Networking.wifiEnabled && panel.connectedNets.length > 0
                text: "Connected"
            }
            Repeater {
                model: Networking.wifiEnabled ? panel.connectedNets : []
                delegate: NetRow { }
            }
            SectionLabel {
                visible: panel.floating && Networking.wifiEnabled && panel.otherNets.length > 0
                text: "Available"
            }
            Repeater {
                model: Networking.wifiEnabled ? panel.otherNets : []
                delegate: NetRow { }
            }

            PillButton {
                visible: Networking.wifiEnabled && !panel.showAll && panel.allNets.length > panel.limit
                anchors.horizontalCenter: parent.horizontalCenter
                size: panel.fs(10)
                text: "Show all (" + panel.allNets.length + ")"
                onClicked: panel.showAll = true
            }
        }
    }

    // ---- password ------------------------------------------------------------------
    Item {
        id: pwdBox
        visible: panel.typing
        x: 16
        y: list.y + list.height + 6
        width: panel.width - 32
        height: panel.floating ? 40 : 34
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }
        TextInput {
            id: pwd
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            color: "white"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: panel.fs(12)
            clip: true
            Keys.onReturnPressed: {
                if (panel.pwdNet && text.length > 0) panel.pwdNet.connectWithPsk(text)
                panel.pwdNet = null
            }
            Keys.onEscapePressed: panel.pwdNet = null
        }
        GlassText {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: pwd.text.length === 0
            text: panel.pwdNet ? "Password for " + panel.pwdNet.name + " — Enter" : ""
            size: panel.fs(11)
            color: Qt.rgba(1, 1, 1, 0.5)
        }
    }

    Traffic {
        id: traffic
        visible: panel.floating && Networking.wifiEnabled && panel.connectedNets.length > 0
        x: 26
        y: (pwdBox.visible ? pwdBox.y + pwdBox.height : list.y + list.height) + 12
        note: panel.iface + (panel.connectedNets.length ? "  ·  " + panel.connectedNets[0].name : "")
    }
}
