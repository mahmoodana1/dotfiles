import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// One bar per screen: three liquid-glass islands (workspaces · clock · info).
// Shown only while `held` (SUPER down). The glass refracts a snapshot of the
// screen taken just before showing, since a layer surface cannot see what
// the compositor draws beneath it.
PanelWindow {
    id: bar

    required property var modelData
    property bool held: false

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    readonly property int barH: 30
    readonly property int topGap: 6
    readonly property int sideGap: 8
    readonly property int stripH: barH + topGap + 12

    anchors { top: true; left: true; right: true }
    implicitHeight: stripH
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "peek"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Always mapped (screencopy needs a live window); hidden = transparent
    // and click-through. Content shows only while SUPER is held.
    property bool shown: false
    readonly property Region islandsMask: Region {
        Region { item: leftIsland }
        Region { item: centerIsland }
        Region { item: rightIsland }
    }
    readonly property Region noMask: Region {}
    mask: shown ? islandsMask : noMask

    // ---- show / hide ----------------------------------------------------
    // The capture runs live only while shown, so the glass tracks whatever
    // is behind it (workspace switches, video) frame by frame.
    onHeldChanged: shown = held

    // ---- live capture of the screen behind the bar ----------------------
    // It includes the bar itself; glass.frag only samples outside the islands.
    ScreencopyView {
        id: snap
        captureSource: bar.modelData
        live: bar.shown
        paintCursor: false
        width: bar.modelData.width
        height: bar.modelData.height
    }
    ShaderEffectSource {
        id: behind
        sourceItem: snap
        hideSource: true
        live: true
        sourceRect: Qt.rect(0, 0, bar.modelData.width, bar.stripH)
        width: bar.modelData.width
        height: bar.stripH
        visible: false
    }

    // ---- islands ----------------------------------------------------------
    Item {
        id: content
        anchors.fill: parent
        opacity: bar.shown ? 1 : 0
        visible: opacity > 0

        WorkspacesIsland {
            id: leftIsland
            behind: behind
            monitor: bar.monitor
            x: bar.sideGap; y: bar.topGap; height: bar.barH
        }

        Island {
            id: centerIsland
            behind: behind
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.topGap; height: bar.barH
            Clock { }
        }

        Island {
            id: rightIsland
            behind: behind
            x: bar.width - bar.sideGap - width
            y: bar.topGap; height: bar.barH
            HoverHandler { id: infoHover }
            Info { expanded: infoHover.hovered }
        }
    }
}
