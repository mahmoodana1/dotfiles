import QtQuick

// A small text button.
Press {
    id: c
    property alias text: t.text
    property bool accent: false
    width: t.implicitWidth + 24; height: 30
    radius: 15
    color: accent ? Look.alpha(Look.accent, pressed ? 0.6 : 0.4) : pressed ? Look.wellHi : Look.well
    Txt { id: t; anchors.centerIn: parent; size: 11; bold: true }
}
