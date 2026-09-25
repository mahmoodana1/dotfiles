import QtQuick
import Quickshell
import Quickshell.Hyprland
import "shared"

// Workspace numbers for one monitor. Exposes the droplet's edges
// (dropL/dropR, in strip coordinates); the leading edge moves faster than
// the trailing one, so the droplet stretches in flight.
Item {
    id: strip

    property var monitor
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (w.id === activeId
                    || (w.monitor && monitor && w.monitor.name === monitor.name)))
        .sort((a, b) => a.id - b.id)
    readonly property bool hasActive: activeId > 0 && rep.count > 0

    width: row.implicitWidth
    implicitWidth: row.implicitWidth

    Row {
        id: row
        height: parent.height
        Repeater {
            id: rep
            model: strip.workspaces
            delegate: Item {
                required property var modelData
                readonly property bool isActive: modelData.id === strip.activeId
                width: 26
                height: row.height
                // a fresh (empty) workspace's button appears after the switch
                onIsActiveChanged: if (isActive) Qt.callLater(strip.moveTo, this)
                onXChanged: if (isActive) Qt.callLater(strip.moveTo, this)
                Component.onCompleted: if (isActive) Qt.callLater(strip.moveTo, this)

                GlassText {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.55)
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }
    }

    property real targetL: 0
    property real targetR: 0
    function moveTo(it) {
        if (!it || !it.isActive) return
        const movingRight = it.x > dropL
        lAnim.duration = movingRight ? 380 : 230
        rAnim.duration = movingRight ? 230 : 380
        targetL = it.x + 1
        targetR = it.x + it.width - 1
    }
    property real dropL: targetL
    property real dropR: targetR
    Behavior on dropL { NumberAnimation { id: lAnim; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
    Behavior on dropR { NumberAnimation { id: rAnim; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
}
