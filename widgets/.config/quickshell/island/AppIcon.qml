import QtQuick
import Quickshell.Widgets

// A notification's app icon / image in a soft rounded tile. The picture is
// fitted whole (never cropped), rendered at 2× so it stays sharp; a bell
// shows when nothing loads.
ClippingRectangle {
    id: ic
    property string source: ""
    property int size: 30
    width: size; height: size
    radius: Math.round(size * 0.28)
    color: img.status === Image.Ready ? Look.alpha(Look.fg, 0.06) : Look.well
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: Math.round(ic.size * 0.08)   // breathing room inside the tile
        source: ic.source
        sourceSize: Qt.size(ic.size * 2, ic.size * 2)
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        smooth: true
        mipmap: true
        asynchronous: true
        cache: false
    }
    Txt {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: Glyphs.bell; size: Math.round(ic.size * 0.5)
        color: Look.accent2
    }
}
