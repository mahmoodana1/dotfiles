import QtQuick

// A thin rounded meter (0..1) with an accent gradient.
Item {
    id: m
    property real value: 0
    property color warn: "transparent"      // tint the fill past 0.85 when set
    implicitHeight: 6
    Rectangle { anchors.fill: parent; radius: height / 2; color: Look.wellHi }
    Rectangle {
        height: parent.height; radius: height / 2
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, m.value)))
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Look.accent }
            GradientStop { position: 1; color: m.value > 0.85 && m.warn.a > 0 ? m.warn : Look.accent2 }
        }
    }
}
