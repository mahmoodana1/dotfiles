import QtQuick

// A glass capsule that sizes itself to its content.
// Position it in window coordinates (the bar's content item fills the window,
// so x/y here are also coordinates in the `behind` snapshot).
Item {
    id: island

    property var behind                  // ShaderEffectSource of the screen strip
    property real hpad: 12
    default property alias contents: row.data
    readonly property alias glass: glass
    readonly property alias surface: surface
    property alias overlay: overlayItem.data   // drawn above the surface

    implicitWidth: row.implicitWidth + hpad * 2
    width: implicitWidth
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // glass + content, grouped so a lens (the droplet) can sample both
    Item {
        id: surface
        anchors.fill: parent

        Glass {
            id: glass
            x: -pad; y: -pad
            width: island.width + pad * 2
            height: island.height + pad * 2
            source: island.behind
            sourceOrigin: Qt.point(island.x - pad, island.y - pad)
            sourceSize: Qt.size(island.behind ? island.behind.width : 1,
                                island.behind ? island.behind.height : 1)
        }

        Row {
            id: row
            anchors.centerIn: parent
            height: parent.height
            spacing: 2
        }
    }

    Item { id: overlayItem; anchors.fill: parent }
}
