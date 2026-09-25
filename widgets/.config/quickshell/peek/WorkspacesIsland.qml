import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace numbers with an iOS-26-style glass droplet that slides to the
// active one. The leading edge moves faster than the trailing edge, so the
// droplet stretches in flight and settles back into a bead.
Island {
    id: island

    property var monitor
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1

    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (w.id === activeId
                    || (w.monitor && monitor && w.monitor.name === monitor.name)))
        .sort((a, b) => a.id - b.id)

    Repeater {
        id: rep
        model: island.workspaces
        delegate: Item {
            required property var modelData
            readonly property bool isActive: modelData.id === island.activeId
            width: 26
            height: island.height
            // A fresh (empty) workspace's button appears after the switch;
            // it moves the droplet to itself once active and positioned.
            onIsActiveChanged: if (isActive) Qt.callLater(island.moveTo, this)
            onXChanged: if (isActive) Qt.callLater(island.moveTo, this)
            Component.onCompleted: if (isActive) Qt.callLater(island.moveTo, this)

            GlassText {
                anchors.centerIn: parent
                text: modelData.id
                color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.55)
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            TapHandler {
                onTapped: Hyprland.dispatch(`hl.dsp.focus({workspace="${modelData.id}"})`)
            }
        }
    }

    // ---- droplet ----------------------------------------------------------
    // target edges, in island coordinates
    property real targetL: 0
    property real targetR: 0
    function moveTo(it) {
        if (!it || !it.isActive) return
        const p = it.mapToItem(island, 0, 0)
        const movingRight = p.x > dropL
        lAnim.duration = movingRight ? 380 : 230
        rAnim.duration = movingRight ? 230 : 380
        targetL = p.x + 1
        targetR = p.x + it.width - 1
    }
    onWidthChanged: {
        for (let i = 0; i < rep.count; i++)
            if (rep.itemAt(i) && rep.itemAt(i).isActive) Qt.callLater(moveTo, rep.itemAt(i))
    }

    property real dropL: targetL
    property real dropR: targetR
    Behavior on dropL { NumberAnimation { id: lAnim; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
    Behavior on dropR { NumberAnimation { id: rAnim; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }

    overlay: [
    ShaderEffectSource {
        id: lensSrc
        sourceItem: island.surface
        live: true
        visible: false
        width: island.width
        height: island.height
    },

    // glass bead; squashes a little vertically while stretched
    Glass {
        id: droplet
        readonly property real restW: 24
        readonly property real w: Math.max(restW, island.dropR - island.dropL)
        readonly property real h: (island.height - 6) * Math.pow(restW / w, 0.25)
        visible: island.activeId > 0 && rep.count > 0
        pad: 6
        x: island.dropL - pad
        y: (island.height - h) / 2 - pad
        width: w + pad * 2
        height: h + pad * 2
        source: lensSrc
        sourceOrigin: Qt.point(x, y)
        sourceSize: Qt.size(island.width, island.height)
        mode: 1
        bezel: 7
        refraction: 3
        magnify: 1.25
        blurPx: 0
        tint: 0.12
        shadow: 0.22
    }
    ]
}
