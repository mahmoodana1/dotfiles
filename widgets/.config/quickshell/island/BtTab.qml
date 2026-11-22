import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth: Connected (cards with battery), Paired and Available. Tap a
// row for its actions: Connect / Disconnect, Trust, Forget, or Pair.
// Discovers while showing (↻ pauses); Discoverable makes this laptop visible.
Item {
    id: b
    property var ctl
    property bool active: false
    readonly property real pad: 22


    readonly property var adapter: ctl.btAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var all: Bluetooth.devices.values
        .filter(d => d.deviceName && d.deviceName !== d.address.replace(/:/g, "-"))
        .sort((x, y) => x.deviceName.localeCompare(y.deviceName))
    readonly property var connected: all.filter(d => d.connected)
    readonly property var paired: all.filter(d => !d.connected && (d.paired || d.trusted))
    readonly property var avail: all.filter(d => !d.connected && !d.paired && !d.trusted)
    property string openAddr: ""
    property bool scanning: true
    readonly property bool wantScan: active && scanning && on
    onWantScanChanged: if (adapter) adapter.discovering = wantScan
    onActiveChanged: { openAddr = ""; if (active) scanning = true }

    function busy(d) { return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting }
    Instantiator {                          // freshly paired → connect
        model: b.all
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() { if (modelData.paired && !modelData.connected) modelData.connect() }
        }
    }

    TabHead {
        id: head
        x: b.pad; y: 18; width: b.width - b.pad * 2
        title: "Bluetooth"
        sub: !b.adapter ? "No adapter" : !b.on ? "Off" : (b.adapter.name || "Adapter") + "  ·  " + b.connected.length + " connected"
        busy: b.wantScan
        onBusyClicked: b.scanning = !b.scanning
        Switch { checked: b.on; onToggled: v => { if (b.adapter) b.adapter.enabled = v } }
        Row {
            visible: b.on
            spacing: 8
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Visible"; size: 11; color: Look.dim }
            Switch { checked: b.on && b.adapter.discoverable; onToggled: v => b.adapter.discoverable = v }
        }
    }

    Flickable {
        id: scroll
        x: b.pad; y: head.y + head.height + 14
        width: b.width - b.pad * 2; height: b.height - y - 18
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: scroll.width; spacing: 14
            Txt {
                visible: !b.on
                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 60
                text: !b.adapter ? "No Bluetooth adapter" : "Bluetooth is off"; size: 12; color: Look.dim
            }
            // ---- connected: cards ----
            Grid {
                visible: b.on && b.connected.length > 0
                columns: 2; spacing: 10
                Repeater {
                    model: b.on ? b.connected : []
                    Card {
                        id: dc
                        required property var modelData
                        readonly property var d: modelData
                        width: (col.width - 10) / 2; height: 104
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Look.accent }
                                GradientStop { position: 1; color: Look.accent2 }
                            }
                            Txt { anchors.centerIn: parent; text: Glyphs.device(dc.d.icon); size: 18; color: Look.onAccent }
                        }
                        Column {
                            x: 52; width: parent.width - 52; spacing: 3
                            Txt { width: parent.width; text: dc.d.deviceName; size: 13; bold: true }
                            Txt { text: b.busy(dc.d) ? "…" : "Connected" + (dc.d.trusted ? "  ·  trusted" : ""); size: 10; color: Look.accent2 }
                        }
                        Row {
                            visible: dc.d.batteryAvailable
                            y: 50; spacing: 8
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: Glyphs.battery(Math.round(dc.d.battery * 100), false) + " " + Math.round(dc.d.battery * 100) + "%"; size: 10; color: Look.dim }
                            Meter { anchors.verticalCenter: parent.verticalCenter; width: 120; height: 5; value: dc.d.battery }
                        }
                        Row {
                            anchors.right: parent.right; anchors.bottom: parent.bottom
                            spacing: 6
                            Chip { height: 26; text: "Disconnect"; onClicked: dc.d.disconnect() }
                            Chip { height: 26; text: "Forget"; onClicked: dc.d.forget() }
                        }
                    }
                }
            }
            Group { title: "Paired"; devices: b.paired }
            Group { title: b.wantScan ? "Available  ·  searching" : "Available"; devices: b.avail; showEmpty: true }
        }
    }

    component Group: Card {
        id: g
        property var devices: []
        property bool showEmpty: false
        visible: b.on && (devices.length > 0 || showEmpty)
        width: col.width
        height: bodyY + Math.max(28, lv.contentHeight) + inset
        ListView {
            id: lv
            width: parent.width; height: contentHeight
            interactive: false; spacing: 2
            model: g.devices
            delegate: Dev {}
        }
        Txt { visible: g.devices.length === 0; text: "Nothing nearby yet"; size: 11; color: Look.faint; y: 6 }
    }

    component Dev: Item {
        id: r
        required property var modelData
        readonly property var d: modelData
        readonly property bool open: b.openAddr === d.address
        readonly property bool known: d.paired || d.trusted
        width: ListView.view.width
        height: 40 + (open ? 42 : 0)
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        clip: true
        Press {
            id: devPress
            width: parent.width; height: 40; radius: 12
            flat: true; on: r.open
            function remove() { if (r.known) { b.openAddr = ""; r.d.forget() } }
            onClicked: b.openAddr = r.open ? "" : r.d.address
            Txt { x: 10; anchors.verticalCenter: parent.verticalCenter; text: Glyphs.device(r.d.icon); size: 15; color: Look.dim }
            Txt { x: 38; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 160; text: r.d.deviceName; size: 12; bold: r.known }
            Txt {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: devPress.armed ? "d again to forget"
                    : b.busy(r.d) ? (r.d.pairing ? "pairing…" : "connecting…") : r.known ? (r.d.trusted ? "trusted" : "paired") : "new"
                size: 10; color: b.busy(r.d) ? Look.accent2 : Look.faint
            }
        }
        Row {
            visible: r.open
            x: 38; y: 46; spacing: 8
            Chip { visible: r.known; text: "Connect"; accent: true; onClicked: { b.openAddr = ""; r.d.connect() } }
            Chip { visible: !r.known; text: r.d.pairing ? "Pairing…" : "Pair"; accent: true; onClicked: if (!r.d.pairing) { r.d.trusted = true; r.d.pair() } }
            Chip { visible: r.known; text: r.d.trusted ? "Untrust" : "Trust"; onClicked: r.d.trusted = !r.d.trusted }
            Chip { visible: r.known; text: "Forget"; onClicked: { b.openAddr = ""; r.d.forget() } }
        }
    }
}
