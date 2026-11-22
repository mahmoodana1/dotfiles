import QtQuick

// A tab's header: big title + subtitle on the left; on the right an
// optional ↻ (spins while `busy`) and whatever children you put inside.
Item {
    id: th
    property string title
    property string sub: ""
    property bool busy: false
    property bool hasBusy: true
    signal busyClicked()
    default property alias trailing: tools.data
    height: 44

    Txt { y: 0; text: th.title; size: 20; bold: true }
    Txt { y: 26; text: th.sub; size: 11; color: Look.dim }
    Row {
        id: tools
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 14
        layoutDirection: Qt.RightToLeft
    }
    Txt {
        visible: th.hasBusy
        anchors.right: tools.left; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Glyphs.refresh; size: 16
        color: th.busy ? Look.accent2 : Look.faint
        RotationAnimation on rotation { running: th.busy; loops: Animation.Infinite; from: 0; to: 360; duration: 1100 }
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: th.busyClicked() }
    }
}
