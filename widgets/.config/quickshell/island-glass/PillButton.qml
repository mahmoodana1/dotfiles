import QtQuick
import "shared"

// Small glass pill button (row actions, "Show all").
Item {
    id: btn
    property alias text: lbl.text
    property bool danger: false
    property bool selected: false        // one of a set is active (BT audio profile)
    property bool focused: false         // keyboard (Tab) is on it; Enter presses it
    property real size: 10
    signal clicked()

    implicitWidth: lbl.implicitWidth + 20
    implicitHeight: size + 12

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22)
             : btn.selected ? Qt.rgba(1, 1, 1, 0.26)
             : btn.focused ? (btn.danger ? Qt.rgba(1, 0.45, 0.4, 0.3) : Qt.rgba(1, 1, 1, 0.22))
             : btn.danger ? Qt.rgba(1, 0.45, 0.4, 0.14) : Qt.rgba(1, 1, 1, 0.08)
        border.width: btn.selected || btn.focused ? 1 : 0
        border.color: btn.focused ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.45)
    }
    GlassText {
        id: lbl
        anchors.centerIn: parent
        size: btn.size
        color: btn.danger ? Qt.rgba(1, 0.75, 0.72, 1) : "white"
        weight: btn.selected ? Font.Bold : Font.DemiBold
    }
    TapHandler { id: tap; onTapped: btn.clicked() }
}
