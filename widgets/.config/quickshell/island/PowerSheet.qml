import QtQuick
import Quickshell

// Power actions over the Center's tabs. Tap once to arm (the button lights
// and says "Tap again"), tap again within 3 s to run it.
Item {
    id: ps
    property bool open: false
    signal done()
    property string armed: ""
    property int cur: 0
    onOpenChanged: { armed = ""; cur = 0 }
    function fire(a) {
        if (armed !== a.id) { armed = a.id; disarm.restart(); return }
        Quickshell.execDetached(a.cmd)
        done()
    }
    visible: opacity > 0.01
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    readonly property var actions: [
        { id: "lock", icon: "\u{f033e}", label: "Lock", cmd: ["loginctl", "lock-session"] },
        { id: "suspend", icon: "\u{f04b2}", label: "Suspend", cmd: ["systemctl", "suspend"] },
        { id: "logout", icon: "\u{f0343}", label: "Log out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { id: "reboot", icon: "\u{f0709}", label: "Restart", cmd: ["systemctl", "reboot"] },
        { id: "off", icon: "\u{f0425}", label: "Shut down", cmd: ["systemctl", "poweroff"] }
    ]
    Timer { id: disarm; interval: 3000; onTriggered: ps.armed = "" }

    Rectangle { anchors.fill: parent; color: Look.alpha(Look.bg, 0.82) }
    MouseArea { anchors.fill: parent; onClicked: ps.done() }   // swallow + close on the backdrop

    Column {
        anchors.centerIn: parent
        spacing: 26
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Power"; size: 16; bold: true }
        Row {
            spacing: 18
            Repeater {
                model: ps.actions
                Column {
                    required property var modelData
                    required property int index
                    readonly property bool hot: ps.armed === modelData.id
                    spacing: 10
                    scale: ps.open ? 1 : 0.9
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Press {
                        width: 72; height: 72; radius: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: parent.hot ? Look.alpha(Look.accent, 0.9) : pressed ? Look.wellHi : Look.well
                        Txt { anchors.centerIn: parent; text: modelData.icon; size: 24; color: parent.parent.hot ? Look.onAccent : Look.text }
                        onClicked: ps.fire(modelData)
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.hot ? "Tap again" : modelData.label
                        size: 11; color: parent.hot ? Look.accent2 : Look.dim; bold: parent.hot
                    }
                }
            }
        }
    }
}
