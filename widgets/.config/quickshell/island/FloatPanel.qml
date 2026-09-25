import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// Floating panel: the island's Bluetooth or Wi-Fi panel detached (⤢) into the
// middle of the screen, in its larger, barred `floating` form. Springs out of
// the island's rect (ctl.floatFrom) to the center and back into it on close.
// Close: ✕, Esc, or a click outside. One per screen; shows on ctl.floatScreen.
// Always mapped (screencopy needs a live window); closed = empty input mask.
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

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-float"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property Region fullMask: Region { x: 0; y: 0; width: win.width; height: win.height }
    readonly property Region noMask: Region {}
    mask: open ? fullMask : noMask

    // ---- geometry ----------------------------------------------------------
    readonly property var panel: kind === "wifi" ? wifi : bt
    readonly property rect from: ctl && ctl.floatFrom.width > 0 ? ctl.floatFrom
        : Qt.rect((width - 380) / 2, 6, 380, 60)
    readonly property real toW: 500
    readonly property real toH: panel.implicitHeight
    readonly property real toX: (width - toW) / 2
    readonly property real toY: Math.max(40, (height - toH) / 2 - 40)
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
        width: win.width
        height: win.height
    }
    ShaderEffectSource {
        id: behind
        sourceItem: snap
        hideSource: true
        live: true
        width: win.width
        height: win.height
        visible: false
    }

    // click outside the card closes
    TapHandler { enabled: win.open; onTapped: win.close() }

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
        TapHandler { }

        readonly property real pad: 12
        GlassLum {
            id: lum
            source: behind
            shape: Qt.rect(card.x, card.y, card.width, card.height)
            srcSize: Qt.size(win.width, win.height)
        }
        Glass {
            lumTex: lum.texture
            useLum: 1
            radius: 26
            smoke: 0.93          // text-heavy: darker than the island panels
            x: -card.pad; y: -card.pad
            width: card.width + card.pad * 2
            height: card.height + card.pad * 2
            source: behind
            sourceOrigin: Qt.point(card.x - card.pad, card.y - card.pad)
            sourceSize: Qt.size(win.width, win.height)
        }
        // dark backing so text reads over busy screens (glass rim stays visible)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 23
            color: Qt.rgba(0.02, 0.03, 0.06, 0.62)
            opacity: Math.min(1, win.t * 1.6)
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
