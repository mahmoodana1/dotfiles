import QtQuick
import "shared"

// Small glass pill button (row actions, "Show all").
Item {
    id: btn
    property alias text: lbl.text
    property bool danger: false
    property real size: 10
    signal clicked()

    implicitWidth: lbl.implicitWidth + 20
    implicitHeight: size + 12

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: tap.pressed ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.09)
        border.width: 1
        border.color: btn.danger ? Qt.rgba(1, 0.55, 0.5, 0.45) : Qt.rgba(1, 1, 1, 0.12)
    }
    GlassText {
        id: lbl
        anchors.centerIn: parent
        size: btn.size
        color: btn.danger ? Qt.rgba(1, 0.75, 0.72, 1) : "white"
    }
    TapHandler { id: tap; onTapped: btn.clicked() }
}
