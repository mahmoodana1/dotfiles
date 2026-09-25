import QtQuick

// White label with a faint drop so it reads on any wallpaper through glass.
Item {
    id: root
    property alias text: label.text
    property alias color: label.color
    property real size: 12
    property int weight: Font.DemiBold

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        x: 0; y: 1
        text: label.text
        font: label.font
        renderType: Text.CurveRendering
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Text {
        id: label
        renderType: Text.CurveRendering   // grayscale AA; subpixel fringes look wrong on glass
        color: "white"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.size
        font.weight: root.weight
    }
}
