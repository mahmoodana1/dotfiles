import QtQuick

// Text in Halo's font. `size` in px; `bold` for the heavier weight.
Text {
    property real size: 12
    property bool bold: false
    color: Look.text
    font.family: Look.font
    font.pixelSize: size
    font.weight: bold ? Font.Bold : Font.DemiBold
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: width > 0 && width < implicitWidth ? Text.ElideRight : Text.ElideNone
}
