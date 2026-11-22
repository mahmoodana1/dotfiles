import QtQuick
import "shared"

// Labeled level bar for the floating panels:   icon  Title  ▰▰▰▱▱  value
// level 0..1, or -1 when unavailable (dimmed, empty bar). Titles share one
// column width so the bars line up across rows.
Row {
    id: meter
    property string icon
    property string title
    property real level: 0
    property string value
    property int titleW: 78
    property int barW: 90

    readonly property bool off: level < 0
    spacing: 8

    GlassText {
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        text: meter.icon
        size: 12
        color: Qt.rgba(1, 1, 1, meter.off ? 0.35 : 0.8)
    }
    GlassText {
        anchors.verticalCenter: parent.verticalCenter
        width: meter.titleW
        text: meter.title
        size: 12
        weight: Font.Medium
        color: Qt.rgba(1, 1, 1, meter.off ? 0.4 : 0.75)
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: meter.barW; height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.14)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, meter.level))
            height: parent.height; radius: 3
            color: Qt.rgba(1, 1, 1, 0.85)
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
    }
    GlassText {
        anchors.verticalCenter: parent.verticalCenter
        text: meter.value
        size: 12
        color: Qt.rgba(1, 1, 1, meter.off ? 0.4 : 0.9)
    }
}
