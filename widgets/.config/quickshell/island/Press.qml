import QtQuick

// A rounded pressable surface: soft well when `on`, brighter while pressed.
// Put content inside; handle `clicked`.
Rectangle {
    id: b
    property bool on: false
    property bool flat: false               // no well at rest, only on press / on
    // keyboard (hjkl) navigation in the Center, see Center.qml
    property bool navigable: true           // reachable with hjkl
    property bool focused: false            // set by the Center: draws the ring
    property bool selectOnFocus: false      // landing on it clicks it (rail tabs, filters)
    property bool safeRemove: true          // remove() needs dd (false: Del / x at once)
    property bool armed: false              // first d of dd
    readonly property alias pressed: tap.pressed
    signal clicked()

    radius: 12
    color: tap.pressed ? Look.wellHi : on ? Look.well : flat ? "transparent" : Look.well
    Behavior on color { ColorAnimation { duration: Look.quick } }
    scale: tap.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Look.quick; easing.type: Easing.OutCubic } }

    // keyboard focus ring (vim keys in the Center)
    Rectangle {
        z: 10
        anchors.fill: parent             // inside the edge: rows clip their content
        radius: b.radius
        color: "transparent"
        border.width: 2; border.color: b.armed ? Look.accent : Look.accent2
        opacity: b.focused ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }
    // MouseArea, not TapHandler: an inner MouseArea (a tile's toggle) then
    // takes the click alone instead of both firing
    MouseArea { id: tap; z: -1; anchors.fill: parent; onClicked: b.clicked() }   // under the content
}
