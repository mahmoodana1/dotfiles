import QtQuick

// Small glass switch. Flips the moment it's tapped (`shown`), then follows
// `checked` once the backend reports; adapters take ~0.5s to power off.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool on)

    property bool pending: false
    property bool want: false
    readonly property bool shown: pending ? want : checked
    onCheckedChanged: pending = false
    Timer { id: giveUp; interval: 4000; onTriggered: sw.pending = false }

    implicitWidth: 34
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.shown ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Rectangle {
        width: parent.height - 4
        height: width
        radius: width / 2
        y: 2
        x: sw.shown ? parent.width - width - 2 : 2
        color: "white"
        Behavior on x { SpringAnimation { spring: 6; damping: 0.45 } }
    }
    TapHandler {
        onTapped: {
            sw.want = !sw.shown
            sw.pending = true
            giveUp.restart()
            sw.toggled(sw.want)
        }
    }
}
