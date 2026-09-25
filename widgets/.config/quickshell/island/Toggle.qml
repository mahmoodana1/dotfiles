import QtQuick

// Small glass switch.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 34
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Rectangle {
        width: parent.height - 4
        height: width
        radius: width / 2
        y: 2
        x: sw.checked ? parent.width - width - 2 : 2
        color: "white"
        Behavior on x { SpringAnimation { spring: 6; damping: 0.45 } }
    }
    TapHandler { onTapped: sw.toggled(!sw.checked) }
}
