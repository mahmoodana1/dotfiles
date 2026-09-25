import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// Floating Bluetooth panel: the island's BtPanel detached (⤢) into the middle
// of the screen, with battery/signal bars. Springs out of the island's rect
// (ctl.floatFrom) to the center and back into it on close.
// Close: ✕, Esc, or a click outside. One per screen; shows on ctl.floatScreen.
// Always mapped (screencopy needs a live window); closed = empty input mask.
PanelWindow {
    id: win

    required property var modelData
    property var ctl

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool wanted: ctl !== null && ctl.floating === "bt"
                                   && monitor !== null && ctl.floatScreen === monitor.name
    // `open` drives the content; the card animates on `t` (0 island … 1 center)
    property bool open: false
    onWantedChanged: {
        if (wanted) { open = true; closeAnim.stop(); openAnim.restart(); keys.forceActiveFocus() }
        else if (open) { openAnim.stop(); closeAnim.restart() }
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
    readonly property rect from: ctl && ctl.floatFrom.width > 0 ? ctl.floatFrom
        : Qt.rect((width - 380) / 2, 6, 380, 60)
    readonly property real toW: 460
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
        ScriptAction { script: win.open = false }
    }

    // ---- signal strength (only while open) ---------------------------------
    property var signals: ({})
    Process {
        running: win.open
        command: ["python3", Qt.resolvedUrl("btsignal.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => { try { win.signals = JSON.parse(line) } catch (e) { } }
        }
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
            smoke: 0.85
            x: -card.pad; y: -card.pad
            width: card.width + card.pad * 2
            height: card.height + card.pad * 2
            source: behind
            sourceOrigin: Qt.point(card.x - card.pad, card.y - card.pad)
            sourceSize: Qt.size(win.width, win.height)
        }
        Item {
            anchors.fill: parent
            clip: true
            BtPanel {
                id: panel
                active: win.open
                floating: true
                signals: win.signals
                width: card.width
                opacity: Math.min(1, win.t * 1.6)
                onCloseRequested: win.close()
            }
        }
    }
}
