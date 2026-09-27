import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"
import "common"

// Floating panel: the island's Bluetooth or Wi-Fi panel detached (⤢) into the
// middle of the screen, in its larger, barred `floating` form. Springs out of
// the island's rect (ctl.floatFrom) to the center and back into it on close.
// Close: ✕, Esc, or a click outside. One per screen; shows on ctl.floatScreen.
// Full-screen while open (or springing back); idle it shrinks to 1x1 px.
PanelWindow {
    id: win

    required property var modelData
    property var ctl

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool wanted: ctl !== null && ctl.floating !== ""
                                   && monitor !== null && ctl.floatScreen === monitor.name
    // `open` + `kind` outlive `wanted` through the close animation
    property bool open: false
    property string kind: ""             // "bt" | "wifi"
    onWantedChanged: {
        if (wanted) {
            kind = ctl.floating
            open = true
            motion.open()
            keys.forceActiveFocus()
        } else if (open) motion.close()
    }
    function close() { if (ctl) ctl.floating = "" }

    // Idle = a 1x1 px window at the top-left (never unmap: Quickshell segfaults
    // when a window with a ScreencopyView unmaps). Hyprland blurs whatever
    // box a blurred layer covers on every frame, transparent or not, so a
    // full-screen idle layer cost ~10-15% of the iGPU with video playing.
    margins {
        right: win.expanded ? 0 : win.sw - 1
        bottom: win.expanded ? 0 : win.sh - 1
    }
    // stay full-size a few seconds after closing, so opening again soon
    // doesn't wait on a resize (that costs the first frames of the pour)
    property bool lingering: false
    readonly property bool expanded: open || lingering
    onOpenChanged: if (open) lingerTimer.stop(); else { lingering = true; lingerTimer.restart() }
    Timer { id: lingerTimer; interval: 5000; onTriggered: win.lingering = false }
    // the monitor's size, valid before the window is mapped and configured
    readonly property real sw: modelData.width
    readonly property real sh: modelData.height

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-float"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property Region fullMask: Region { x: 0; y: 0; width: win.sw; height: win.sh }
    readonly property Region noMask: Region {}
    mask: open ? fullMask : noMask

    // ---- geometry ----------------------------------------------------------
    readonly property var panel: kind === "wifi" ? wifi : bt
    // buds off the island like a dividing cell and merges back on close (common/PourMotion.qml)
    IslandSpot {
        id: island
        monitorName: win.monitor ? win.monitor.name : ""
        screenWidth: win.sw
    }
    readonly property real toW: 500
    readonly property real toH: panel.implicitHeight
    readonly property real toX: (sw - toW) / 2
    readonly property real toY: Math.max(40, (sh - toH) / 2 - 40)
    PourMotion {
        id: motion
        mother: island.rect
        to: Qt.rect(win.toX, win.toY, win.toW, win.toH)
        onClosed: { win.open = false; win.kind = "" }
    }

    // ---- live capture of what's behind (includes us; glass samples outside) --
    ScreencopyView {
        id: snap
        captureSource: win.modelData
        live: win.open
        paintCursor: false
        width: win.sw
        height: win.sh
    }
    ShaderEffectSource {
        id: behind
        sourceItem: snap
        hideSource: true
        live: true
        width: win.sw
        height: win.sh
        visible: false
    }

    // click outside the card closes
    // (a MouseArea, not a TapHandler: handlers see taps on the buttons inside
    // the card too, so every click in the panel closed it)
    MouseArea { anchors.fill: parent; enabled: win.open; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: win.close()
    }

    Item {
        id: card
        visible: win.open
        x: motion.rect.x; y: motion.rect.y
        width: motion.rect.width; height: motion.rect.height
        // swallow taps so they don't reach the close-on-outside handler
        MouseArea { anchors.fill: parent }   // clicks inside the card stop here

        readonly property real pad: 12
        // the glass covers the card and, while budding, the island too
        readonly property rect bud: island.rect
        readonly property bool budding: motion.budK > 0
        readonly property real gx0: (budding ? Math.min(x, bud.x) : x) - pad
        readonly property real gy0: (budding ? Math.min(y, bud.y) : y) - pad
        readonly property real gx1: (budding ? Math.max(x + width, bud.x + bud.width) : x + width) + pad
        readonly property real gy1: (budding ? Math.max(y + height, bud.y + bud.height) : y + height) + pad
        GlassLum {
            id: lum
            source: behind
            shape: Qt.rect(card.x, card.y, card.width, card.height)
            srcSize: Qt.size(win.sw, win.sh)
        }
        WaterGlass {
            tintColor: Theme.islandTintColor
            tintColor2: Theme.islandTintColor2
            tintShade: Theme.tintShade
            tintStrength: Theme.islandTint
            lumTex: lum.texture
            useLum: 1
            radius: motion.radius
            smoke: 1             // text-heavy: the most smoke the water glass gives
            x: card.gx0 - card.x; y: card.gy0 - card.y
            width: card.gx1 - card.gx0
            height: card.gy1 - card.gy0
            box: Qt.rect(card.x - card.gx0, card.y - card.gy0, card.width, card.height)
            bud: Qt.rect(card.bud.x - card.gx0, card.bud.y - card.gy0, card.bud.width, card.bud.height)
            budK: card.budding ? motion.budK : 0
            budR: island.radius
            source: behind
            sourceOrigin: Qt.point(card.gx0, card.gy0)
            sourceSize: Qt.size(win.sw, win.sh)
        }
        Item {
            anchors.fill: parent
            clip: true
            opacity: motion.contentOpacity
            BtPanel {
                id: bt
                visible: win.kind === "bt"
                active: win.open && win.kind === "bt"
                floating: true
                width: card.width
                onCloseRequested: win.close()
            }
            WifiPanel {
                id: wifi
                visible: win.kind === "wifi"
                active: win.open && win.kind === "wifi"
                floating: true
                width: card.width
                onCloseRequested: win.close()
            }
        }
    }
}
