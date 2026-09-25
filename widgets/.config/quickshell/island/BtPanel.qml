import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "shared"

// Bluetooth manager inside the island (Quickshell.Bluetooth → BlueZ).
// Tap a device: disconnect if connected, connect if paired, pair otherwise.
// ⋯ on a known device opens its actions (trust / forget) inline.
// The adapter scans while the panel is open; the ↻ button pauses/resumes.
// No HoverHandlers here: they would steal `hovered` from the pill.
Item {
    id: panel

    property var host                    // DynIsland window (launch / close)
    property bool active: false

    property bool scanning: true
    property bool showAll: false
    property string openAddr: ""         // device whose actions are shown
    onActiveChanged: if (active) { scanning = true; showAll = false; openAddr = "" }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var allDevs: Bluetooth.devices.values
        .filter(d => d.deviceName && d.deviceName !== d.address.replace(/:/g, "-"))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                        || a.deviceName.localeCompare(b.deviceName))
    readonly property int limit: 7
    readonly property var devs: showAll ? allDevs : allDevs.slice(0, limit)

    Binding {
        target: panel.adapter; property: "discovering"
        value: panel.active && panel.on && panel.scanning
        when: panel.adapter !== null
    }

    // the island window is 380 tall; past this the list scrolls
    readonly property int listMax: 280

    implicitWidth: 380
    implicitHeight: header.height + 4 + list.height + 24

    function kindIcon(icon) {
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0) return "\u{f02cb}"
        if (icon.indexOf("keyboard") >= 0) return "\u{f030c}"
        if (icon.indexOf("mouse") >= 0) return "\u{f037d}"
        if (icon.indexOf("phone") >= 0) return "\u{f03f2}"
        if (icon.indexOf("audio") >= 0) return "\u{f04c3}"
        return "\u{f00af}"
    }
    function activate(d) {
        if (d.connected) d.disconnect()
        else if (d.paired) d.connect()
        else { d.trusted = true; d.pair() }
    }
    // after pairing, connect right away
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() { if (modelData.paired && !modelData.connected) modelData.connect() }
        }
    }

    // small glass pill button (row actions, "show all")
    component Action: Item {
        id: act
        property alias text: lbl.text
        property bool danger: false
        signal clicked()
        implicitWidth: lbl.implicitWidth + 20
        implicitHeight: 22
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: actTap.pressed ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            border.color: act.danger ? Qt.rgba(1, 0.55, 0.5, 0.45) : Qt.rgba(1, 1, 1, 0.12)
        }
        GlassText {
            id: lbl
            anchors.centerIn: parent
            size: 10
            color: act.danger ? Qt.rgba(1, 0.75, 0.72, 1) : "white"
        }
        TapHandler { id: actTap; onTapped: act.clicked() }
    }

    Item {
        id: header
        x: 16; y: 12
        width: panel.width - 32
        height: 30
        GlassText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f00af}  Bluetooth"
            size: 13; weight: Font.Bold
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
                size: 14
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
        }
    }

    Flickable {
        id: list
        x: 16
        y: header.y + header.height + 4
        width: panel.width - 32
        height: Math.min(col.implicitHeight, panel.listMax)
        contentHeight: col.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: list.width
            spacing: 4

            GlassText {
                visible: !panel.on || panel.allDevs.length === 0
                text: !panel.on ? "Bluetooth is off" : "Searching…"
                size: 11
                color: Qt.rgba(1, 1, 1, 0.6)
            }

            Repeater {
                model: panel.on ? panel.devs : []
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property var d: modelData
                    readonly property bool busy: d.pairing || d.state === BluetoothDeviceState.Connecting
                                                  || d.state === BluetoothDeviceState.Disconnecting
                    readonly property bool known: d.paired || d.trusted
                    readonly property bool open: panel.openAddr === d.address
                    width: col.width
                    height: 32 + (open ? actions.height + 6 : 0)
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22)
                             : d.connected || row.open ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    }

                    // main line; tap area stops short of ⋯ so the two never both fire
                    Item {
                        width: parent.width - (more.visible ? more.width + 4 : 0)
                        height: 32
                        GlassText {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.kindIcon(d.icon || "")
                            size: 14
                        }
                        GlassText {
                            x: 36
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36 - status.width - 16
                            text: d.deviceName
                            elide: Text.ElideRight
                            size: 12
                            weight: d.connected ? Font.Bold : Font.Medium
                        }
                        GlassText {
                            id: status
                            anchors.right: parent.right
                            anchors.rightMargin: more.visible ? 2 : 10
                            anchors.verticalCenter: parent.verticalCenter
                            size: 10
                            color: Qt.rgba(1, 1, 1, 0.65)
                            text: row.busy ? "…"
                                : d.connected ? (d.batteryAvailable ? Math.round(d.battery * 100) + "%  connected" : "connected")
                                : d.paired ? "paired" : "pair"
                        }
                        TapHandler { id: tap; onTapped: panel.activate(d) }
                    }

                    Item {
                        id: more
                        visible: row.known
                        anchors.right: parent.right
                        width: 30; height: 32
                        GlassText {
                            anchors.centerIn: parent
                            text: "\u{f01d8}"
                            size: 14
                            color: row.open ? "white" : Qt.rgba(1, 1, 1, 0.6)
                        }
                        TapHandler { onTapped: panel.openAddr = row.open ? "" : d.address }
                    }

                    Row {
                        id: actions
                        x: 36; y: 34
                        spacing: 6
                        visible: row.open
                        opacity: row.open ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Action {
                            text: d.connected ? "Disconnect" : "Connect"
                            onClicked: d.connected ? d.disconnect() : d.connect()
                        }
                        Action {
                            text: d.trusted ? "Untrust" : "Trust"
                            onClicked: d.trusted = !d.trusted
                        }
                        Action {
                            text: "Forget"
                            danger: true
                            onClicked: { panel.openAddr = ""; d.forget() }
                        }
                    }
                }
            }

            Action {
                visible: panel.on && !panel.showAll && panel.allDevs.length > panel.limit
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Show all (" + panel.allDevs.length + ")"
                onClicked: panel.showAll = true
            }
        }
    }
}
