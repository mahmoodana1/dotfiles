import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "shared"

// Bluetooth devices inside the island (Quickshell.Bluetooth → BlueZ).
// Tap a device: disconnect if connected, connect if paired, pair otherwise.
// The adapter discovers only while the panel is open.
// No HoverHandlers here: they would steal `hovered` from the pill.
Item {
    id: panel

    property var host                    // DynIsland window (launch / close)
    property bool active: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var devs: Bluetooth.devices.values
        .filter(d => d.deviceName && d.deviceName !== d.address.replace(/:/g, "-"))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                        || a.deviceName.localeCompare(b.deviceName))
        .slice(0, 7)

    Binding { target: panel.adapter; property: "discovering"; value: panel.active && panel.on; when: panel.adapter !== null }

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 24

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

    Column {
        id: col
        x: 16; y: 12
        width: panel.width - 32
        spacing: 4

        Item {
            width: parent.width
            height: 30
            GlassText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f00af}  Bluetooth"
                size: 13; weight: Font.Bold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panel.on
                    onToggled: on => { if (panel.adapter) panel.adapter.enabled = on }
                }
                GlassText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f01d9}"
                    size: 14
                    color: Qt.rgba(1, 1, 1, 0.7)
                    TapHandler { onTapped: panel.host.launch("blueman-manager") }
                }
            }
        }

        GlassText {
            visible: !panel.on || panel.devs.length === 0
            text: !panel.on ? "Bluetooth is off" : "Searching…"
            size: 11
            color: Qt.rgba(1, 1, 1, 0.6)
        }

        Repeater {
            model: panel.on ? panel.devs : []
            delegate: Item {
                required property var modelData
                readonly property var d: modelData
                readonly property bool busy: d.pairing || d.state === BluetoothDeviceState.Connecting
                                              || d.state === BluetoothDeviceState.Disconnecting
                width: col.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22)
                         : d.connected ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                }
                GlassText {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.kindIcon(d.icon || "")
                    size: 14
                }
                GlassText {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36 - status.width - 20
                    text: d.deviceName
                    elide: Text.ElideRight
                    size: 12
                    weight: d.connected ? Font.Bold : Font.Medium
                }
                GlassText {
                    id: status
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    size: 10
                    color: Qt.rgba(1, 1, 1, 0.65)
                    text: busy ? "…"
                        : d.connected ? (d.batteryAvailable ? Math.round(d.battery * 100) + "%  connected" : "connected")
                        : d.paired ? "paired" : "pair"
                }
                TapHandler { id: tap; onTapped: panel.activate(d) }
            }
        }
    }
}
