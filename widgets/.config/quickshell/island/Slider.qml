import QtQuick

// A thick pill slider (0..1): the accent fills from the left with the glyph
// riding inside it. Drag or click anywhere; tap the glyph for `iconClicked`.
Item {
    id: s
    property real value: 0
    property string icon: ""
    property string label: ""               // shown at the right end
    property bool muted: false
    property bool navigable: true           // hjkl (Center.qml)
    property bool focused: false
    readonly property bool isSlider: true
    property bool grabbed: false            // Enter grabs: h / l then adjust it
    signal moved(real v)
    function nudge(d) { moved(Math.max(0, Math.min(1, value + d))) }
    signal iconClicked()
    implicitHeight: 34

    readonly property real shown: drag.pressed ? drag.live : value
    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Look.well
    }
    Rectangle {                             // fill: never thinner than the round end
        height: parent.height
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, s.muted ? 0 : s.shown)))
        radius: height / 2
        opacity: s.muted ? 0.35 : 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Look.accent }
            GradientStop { position: 1; color: Look.accent2 }
        }
        Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Look.quick; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        property real live: 0
        function at(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: m => { live = at(m.x); s.moved(live) }
        onPositionChanged: m => { if (pressed) { live = at(m.x); s.moved(live) } }
    }
    Txt {                                   // over the fill: dark on accent
        x: 12; anchors.verticalCenter: parent.verticalCenter
        text: s.icon; size: 15
        color: s.muted ? Look.dim : Look.onAccent
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: s.iconClicked() }
    }
    Txt {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: s.label; size: 11
        color: s.shown > 0.86 && !s.muted ? Look.onAccent : Look.dim
    }
    // keyboard focus ring (vim keys in the Center)
    Rectangle {
        z: 10
        anchors.fill: parent             // inside the edge: rows clip their content
        radius: height / 2
        color: "transparent"
        border.width: s.grabbed ? 3 : 2; border.color: s.grabbed ? Look.accent : Look.accent2
        opacity: s.focused ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }
}
