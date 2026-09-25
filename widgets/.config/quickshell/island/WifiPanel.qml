import QtQuick
import Quickshell
import Quickshell.Networking
import "shared"

// Wi-Fi list inside the island (Quickshell.Networking → NetworkManager).
// Tap a network: disconnect if connected, connect if saved/open, otherwise
// ask for the password inline. The panel scans only while it is open.
// No HoverHandlers here: they would steal `hovered` from the pill.
Item {
    id: panel

    property var host                    // DynIsland window (launch / close)
    property bool active: false          // panel is showing

    readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var nets: !dev ? [] : dev.networks.values
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
        .slice(0, 7)

    property var pwdNet: null            // network waiting for a password
    readonly property bool typing: pwdNet !== null
    onActiveChanged: if (!active) pwdNet = null

    Binding { target: panel.dev; property: "scannerEnabled"; value: panel.active; when: panel.dev !== null }

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 24

    function strengthIcon(s) {
        return s > 0.75 ? "\u{f0928}" : s > 0.5 ? "\u{f0925}" : s > 0.25 ? "\u{f0922}" : "\u{f091f}"
    }
    function isOpen(n) {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe
    }
    function activate(n) {
        if (n.connected) n.disconnect()
        else if (n.known || isOpen(n)) n.connect()
        else { pwdNet = n; pwd.text = ""; pwd.forceActiveFocus() }
    }

    Column {
        id: col
        x: 16; y: 12
        width: panel.width - 32
        spacing: 4

        // ---- header ----
        Item {
            width: parent.width
            height: 30
            GlassText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f05a9}  Wi-Fi"
                size: 13; weight: Font.Bold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Networking.wifiEnabled
                    onToggled: on => Networking.wifiEnabled = on
                }
                GlassText {      // full settings
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f01d9}"
                    size: 14
                    color: Qt.rgba(1, 1, 1, 0.7)
                    TapHandler { onTapped: panel.host.launch(panel.host.floatTerm + "nmtui connect") }
                }
            }
        }

        GlassText {
            visible: !Networking.wifiEnabled || panel.nets.length === 0
            text: !Networking.wifiEnabled ? "Wi-Fi is off" : "Scanning…"
            size: 11
            color: Qt.rgba(1, 1, 1, 0.6)
        }

        // ---- networks ----
        Repeater {
            model: Networking.wifiEnabled ? panel.nets : []
            delegate: Item {
                required property var modelData
                readonly property var n: modelData
                width: col.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22)
                         : n.connected ? Qt.rgba(1, 1, 1, 0.12)
                         : panel.pwdNet === n ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                }
                GlassText {
                    id: sig
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.strengthIcon(n.signalStrength)
                    size: 14
                }
                GlassText {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36 - status.width - 20
                    text: n.name
                    elide: Text.ElideRight
                    size: 12
                    weight: n.connected ? Font.Bold : Font.Medium
                }
                GlassText {
                    id: status
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    size: 10
                    color: Qt.rgba(1, 1, 1, 0.65)
                    text: n.stateChanging ? "…"
                        : n.connected ? "connected"
                        : n.known ? "saved"
                        : panel.isOpen(n) ? "open" : "\u{f033e}"
                }
                TapHandler { id: tap; onTapped: panel.activate(n) }
            }
        }

        // ---- password ----
        Item {
            visible: panel.typing
            width: col.width
            height: visible ? 34 : 0
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
                font.pixelSize: 12
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
                size: 11
                color: Qt.rgba(1, 1, 1, 0.5)
            }
        }
    }
}
