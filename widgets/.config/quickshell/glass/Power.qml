import QtQuick
import Quickshell
import "shared"

// CTRL+ALT+P: power menu. Keys 1-5, arrows + Enter, or click.
// Log out / Reboot / Power off ask for a second press within 3 s.
FocusScope {
    id: root
    signal closeRequested()

    implicitWidth: 5 * 112 + 44
    implicitHeight: 176
    readonly property bool centered: true

    readonly property var actions: [
        { icon: "\u{f033e}", label: "Lock",      confirm: false, cmd: ["loginctl", "lock-session"] },
        { icon: "\u{f04b2}", label: "Sleep",     confirm: false, cmd: ["systemctl", "suspend"] },
        { icon: "\u{f0343}", label: "Log out",   confirm: true,  cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { icon: "\u{f0709}", label: "Reboot",    confirm: true,  cmd: ["systemctl", "reboot"] },
        { icon: "\u{f0425}", label: "Power off", confirm: true,  cmd: ["systemctl", "poweroff"] }
    ]
    property int current: 0
    property int armed: -1                  // index waiting for its second press

    function opened(arg) { current = 0; armed = -1; keys.forceActiveFocus() }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = -1 }

    function press(i) {
        current = i
        const a = actions[i]
        if (a.confirm && armed !== i) { armed = i; disarm.restart(); return }
        root.closeRequested()
        Quickshell.execDetached(a.cmd)
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const n = root.actions.length
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) root.press(event.key - Qt.Key_1)
            else if (event.key === Qt.Key_Left) { root.current = (root.current - 1 + n) % n; root.armed = -1 }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.current = (root.current + 1) % n; root.armed = -1 }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.press(root.current)
            else return
            event.accepted = true
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 0
        Repeater {
            model: root.actions
            delegate: Item {
                id: btn
                required property var modelData
                required property int index
                readonly property bool cur: root.current === index
                readonly property bool waiting: root.armed === index
                width: 112
                height: 130

                Rectangle {
                    id: circle
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    width: 70; height: 70
                    radius: 35
                    color: btn.waiting ? Qt.rgba(1, 0.45, 0.4, 0.28) : Qt.rgba(1, 1, 1, btn.cur ? 0.24 : 0.10)
                    border.width: btn.cur || btn.waiting ? 2 : 1
                    border.color: btn.waiting ? Qt.rgba(1, 0.78, 0.74, 0.9) : Qt.rgba(1, 1, 1, btn.cur ? 0.8 : 0.2)
                    scale: btn.cur ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    GlassText {
                        anchors.centerIn: parent
                        text: btn.modelData.icon
                        size: 28
                        weight: Font.Normal
                    }
                }
                GlassText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: circle.y + circle.height + 12
                    text: btn.waiting ? "Press again" : btn.modelData.label
                    size: 12
                    color: btn.waiting ? Qt.rgba(1, 0.85, 0.82, 1) : Qt.rgba(1, 1, 1, btn.cur ? 1 : 0.75)
                }
                GlassText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: circle.y + circle.height + 30
                    text: String(btn.index + 1)
                    size: 9
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: if (root.current !== btn.index) { root.current = btn.index; root.armed = -1 }
                    onClicked: root.press(btn.index)
                }
            }
        }
    }
}
