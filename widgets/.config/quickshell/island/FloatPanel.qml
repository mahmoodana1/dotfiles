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
            closeAnim.stop(); openAnim.restart()
            keys.forceActiveFocus()
        } else if (open) { openAnim.stop(); closeAnim.restart() }
    }
    function close() { if (ctl) ctl.floating = "" }

    // Idle = a 1x1 px window at the top-left (never unmap: Quickshell segfaults
    // when a window with a ScreencopyView unmaps). Hyprland blurs whatever
    // box a blurred layer covers on every frame, transparent or not, so a
    // full-screen idle layer cost ~10-15% of the iGPU with video playing.
    margins {
        right: win.open ? 0 : win.sw - 1
        bottom: win.open ? 0 : win.sh - 1
    }
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
    readonly property rect from: ctl && ctl.floatFrom.width > 0 ? ctl.floatFrom
        : Qt.rect((sw - 380) / 2, 6, 380, 60)
    readonly property real toW: 500
    readonly property real toH: panel.implicitHeight
    readonly property real toX: (sw - toW) / 2
    readonly property real toY: Math.max(40, (sh - toH) / 2 - 40)
    property real t: 0
    function lerp(a, b) { return a + (b - a) * t }

    NumberAnimation {
        id: openAnim
        target: win; property: "t"; to: 1; duration: 420
        easing.type: Easing.OutBack; easing.overshoot: 1.1
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: win; property: "t"; to: 0; duration: 240; easing.type: Easing.InCubic }
        ScriptAction { script: { win.open = false; win.kind = "" } }
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
        x: win.lerp(win.from.x, win.toX)
        y: win.lerp(win.from.y, win.toY)
        width: win.lerp(win.from.width, win.toW)
        height: win.lerp(win.from.height, win.toH)
        // swallow taps so they don't reach the close-on-outside handler
        MouseArea { anchors.fill: parent }   // clicks inside the card stop here

        readonly property real pad: 12
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
            radius: 26
            smoke: 1             // text-heavy: the most smoke the water glass gives
            x: -card.pad; y: -card.pad
            width: card.width + card.pad * 2
            height: card.height + card.pad * 2
            source: behind
            sourceOrigin: Qt.point(card.x - card.pad, card.y - card.pad)
            sourceSize: Qt.size(win.sw, win.sh)
        }
        Item {
            anchors.fill: parent
            clip: true
            opacity: Math.min(1, win.t * 1.6)
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
