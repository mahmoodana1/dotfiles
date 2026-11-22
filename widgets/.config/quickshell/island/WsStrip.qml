import QtQuick
import Quickshell.Hyprland

// Workspace numbers for one monitor. The active one sits in an accent
// capsule that slides over: its leading edge moves first and the trailing
// edge catches up, so it stretches in flight and lands clean.
Item {
    id: strip
    property var monitor
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property var list: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (w.id === activeId || (w.monitor && monitor && w.monitor.name === monitor.name)))
        .sort((a, b) => a.id - b.id)
    readonly property int idx: list.findIndex(w => w.id === activeId)

    readonly property int cell: 24
    readonly property int gap: 2
    implicitWidth: Math.max(1, list.length) * (cell + gap) - gap
    implicitHeight: 26

    // capsule edges (strip coordinates), each on its own clock
    readonly property real targetL: Math.max(0, idx) * (cell + gap)
    property real capL: targetL
    property real capR: targetL + cell
    property bool goingRight: true
    onTargetLChanged: {
        goingRight = targetL > capL
        capL = targetL; capR = targetL + cell
    }
    Behavior on capL { NumberAnimation { duration: strip.goingRight ? 230 : 140; easing.type: Easing.OutCubic } }
    Behavior on capR { NumberAnimation { duration: strip.goingRight ? 140 : 230; easing.type: Easing.OutCubic } }

    Rectangle {
        visible: strip.idx >= 0
        x: strip.capL; width: strip.capR - strip.capL
        height: strip.implicitHeight - 2; y: 1
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Look.accent }
            GradientStop { position: 1; color: Look.accent2 }
        }
    }
    Row {
        spacing: strip.gap
        height: parent.height
        Repeater {
            model: strip.list
            Txt {
                required property var modelData
                readonly property bool on: modelData.id === strip.activeId
                width: strip.cell; height: strip.implicitHeight
                horizontalAlignment: Text.AlignHCenter
                text: modelData.id
                size: 12; bold: on
                color: on ? Look.onAccent : modelData.toplevels.values.length > 0 ? Look.dim : Look.faint
                Behavior on color { ColorAnimation { duration: 140 } }
                MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
            }
        }
    }
}
