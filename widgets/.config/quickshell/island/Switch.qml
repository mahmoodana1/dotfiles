import QtQuick

// On/off switch; the knob slides, the track fills with the accent.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool on)
    property bool navigable: true           // hjkl (Center.qml): Enter flips it
    property bool focused: false
    readonly property bool isSwitch: true
    implicitWidth: 36; implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: sw.checked ? Look.accent : Look.wellHi }
            GradientStop { position: 1; color: sw.checked ? Look.accent2 : Look.wellHi }
        }
    }
    Rectangle {
        width: 14; height: 14; radius: 7
        y: 3
        x: sw.checked ? sw.width - width - 3 : 3
        color: sw.checked ? Look.onAccent : Look.dim
        Behavior on x { NumberAnimation { duration: Look.quick + 40; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on color { ColorAnimation { duration: Look.quick } }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: sw.toggled(!sw.checked) }
    Rectangle {
        anchors.fill: parent; anchors.margins: -3; radius: height / 2 + 3
        color: "transparent"; border.width: 2; border.color: Look.accent2
        opacity: sw.focused ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }
}
