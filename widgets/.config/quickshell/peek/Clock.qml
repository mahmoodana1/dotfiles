import QtQuick
import Quickshell

Item {
    implicitWidth: label.implicitWidth + 4
    implicitHeight: parent ? parent.height : 30

    SystemClock { id: clock; precision: SystemClock.Minutes }

    GlassText {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "HH:mm")
        size: 13
        weight: Font.Bold
    }
}
