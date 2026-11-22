import QtQuick

// A one-line toast (charger plugged / unplugged).
Item {
    property var ctl
    implicitWidth: row.implicitWidth + 36
    implicitHeight: 40
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Txt { text: ctl.toastIcon; size: 15; color: Look.accent2 }
        Txt { text: ctl.toastText; size: 12; bold: true }
    }
}
