import QtQuick

// Volume / mic / brightness: glyph · glowing fill · percent.
Item {
    id: lv
    property var ctl
    readonly property real v: Math.max(0, Math.min(1, ctl.levelValue))
    readonly property bool muted: ctl.levelMuted
    implicitWidth: 300
    implicitHeight: 42

    Row {
        anchors.centerIn: parent
        spacing: 12
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: 18; horizontalAlignment: Text.AlignHCenter
            size: 15
            color: lv.muted ? Look.faint : Look.text
            text: lv.ctl.levelKind === "brightness" ? Glyphs.sun
                : lv.ctl.levelKind === "mic" ? Glyphs.mic(lv.muted)
                : Glyphs.volume(lv.v, lv.muted)
        }
        Item {
            width: 190; height: 8
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.fill: parent; radius: 4; color: Look.wellHi }
            Rectangle {                     // soft glow under the fill
                width: fill.width + 8; height: 16; x: -4; y: -4
                radius: 8
                color: Look.alpha(Look.accent, 0.22)
                visible: fill.width > 0
            }
            Rectangle {
                id: fill
                height: parent.height; radius: 4
                width: parent.width * (lv.muted ? 0 : lv.v)
                Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Look.accent }
                    GradientStop { position: 1; color: Look.accent2 }
                }
            }
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: 38; horizontalAlignment: Text.AlignRight
            size: 12; bold: true
            color: lv.muted ? Look.faint : Look.text
            text: lv.muted ? "off" : Math.round(lv.v * 100) + "%"
        }
    }
}
