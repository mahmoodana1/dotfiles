import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "common"
import "common/keys.js" as K

// One per monitor. Full-screen while a panel is open (or pouring out); idle
// it shrinks to 1x1 px (see `margins`) with no input and no keyboard focus.
// Panels stay loaded while idle, so opening is still instant.
// Shows ctl.current when ctl.screenName is this monitor.
PanelWindow {
    id: win
    required property var modelData
    property var ctl
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    readonly property bool wanted: ctl !== null && ctl.current !== ""
                                   && monitor !== null && ctl.screenName === monitor.name
    property bool open: false        // outlives `wanted` through the close animation
    property string kind: ""         // panel being drawn
    readonly property bool passive: kind === "hud"   // hold-to-show: no input at all

    // Every panel is built once at startup and kept warm; opening one only
    // reveals it (no QML compile, no rebuilding its lists on each keypress).
    readonly property var panelFiles: ({
        launcher: "Launcher.qml", shortcuts: "Shortcuts.qml", wallpaper: "Wallpapers.qml",
        windows: "Windows.qml", power: "Power.qml", hud: "Hud.qml"
    })
    property int loadedCount: 0              // bumps as panels finish loading
    readonly property var item: {
        loadedCount
        for (let i = 0; i < panels.count; i++) {
            const l = panels.itemAt(i)
            if (l && l.kind === win.kind) return l.item
        }
        return null
    }

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
    WlrLayershell.namespace: "glass"
    WlrLayershell.keyboardFocus: wanted && !passive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property Region fullMask: Region { x: 0; y: 0; width: win.sw; height: win.sh }
    readonly property Region noMask: Region {}
    mask: open && !passive ? fullMask : noMask

    // ---- open / close / swap -------------------------------------------------
    function startOpen() {
        kind = ctl.current
        open = true
        snap.captureFrame()                  // one still of what's behind, for the rim
        card.refresh()
        motion.open()
        if (item) { item.forceActiveFocus(); if (item.opened) item.opened(ctl.arg) }
    }
    onWantedChanged: {
        if (wanted) startOpen()
        else if (open) motion.close()
    }
    Connections {
        target: win.ctl
        // another panel requested while one is open: pour out, then in
        function onCurrentChanged() { if (win.wanted && win.open && win.kind !== win.ctl.current) motion.close() }
        function onSerialChanged() {
            if (win.wanted && win.open && win.kind === win.ctl.current && win.item && win.item.opened)
                win.item.opened(win.ctl.arg)
        }
    }
    function requestClose() { if (ctl.current === kind) ctl.close() }

    // panels bud off the island like a dividing cell (off the top edge while it's hidden)
    IslandSpot {
        id: island
        monitorName: win.monitor ? win.monitor.name : ""
        screenWidth: win.sw
    }

    PourMotion {
        id: motion
        mother: island.rect
        to: Qt.rect((win.sw - card.wantW) / 2,
                    card.centered ? Math.max(40, (win.sh - card.wantH) / 2 - 30) : 70,
                    card.wantW, card.wantH)
        onClosed: {
            if (win.wanted) win.startOpen()          // swap to the newly requested panel
            else { win.open = false; win.kind = "" }
        }
    }

    // ---- what's behind us (the glass rim refracts it) --------------------------
    // One still per open, not a live stream: copying the whole screen every
    // frame while a panel is up costs GPU time and made opening stutter.
    // The body's frost comes from Hyprland's blur, which is live anyway.
    ScreencopyView {
        id: snap
        captureSource: win.modelData
        live: false
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

    // panels may draw a full-screen layer under the card (wallpaper preview)
    Loader {
        id: backdrop
        anchors.fill: parent
        active: win.open && win.item !== null && win.item.backdrop !== undefined
        sourceComponent: win.item ? win.item.backdrop : null
        opacity: motion.cardOpacity
    }

    // click outside the card closes
    MouseArea {
        anchors.fill: parent
        enabled: win.open && !win.passive
        onClicked: win.requestClose()
    }

    GlassCard {
        id: card
        // pop in: fade + a slight scale up from the top edge (PourMotion)
        transformOrigin: Item.Top
        scale: motion.cardScale
        opacity: motion.cardOpacity
        visible: win.open
        source: behind
        srcSize: Qt.size(win.sw, win.sh)
        x: motion.rect.x; y: motion.rect.y
        width: motion.rect.width; height: motion.rect.height
        radius: motion.radius
        bud: island.rect
        budK: motion.budK
        budR: island.radius
        smoke: win.item && win.item.smoke !== undefined ? win.item.smoke : Theme.panelShade

        readonly property real wantW: win.item ? win.item.implicitWidth : 400
        readonly property real wantH: win.item ? win.item.implicitHeight : 300
        readonly property bool centered: win.item !== null && win.item.centered === true

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close us

        Item {
            // content is laid out at full size; the growing card reveals it
            anchors.fill: parent
            clip: true

            Repeater {
                id: panels
                model: Object.keys(win.panelFiles)
                delegate: Loader {
                    id: pl
                    required property string modelData
                    readonly property string kind: modelData
                    source: win.panelFiles[modelData]
                    asynchronous: true
                    visible: win.kind === kind
                    enabled: visible
                    focus: visible
                    width: item ? item.implicitWidth : 0
                    height: item ? item.implicitHeight : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: motion.contentOpacity
                    onLoaded: win.loadedCount++
                    Connections {
                        target: pl.item
                        ignoreUnknownSignals: true
                        function onCloseRequested() { win.requestClose() }
                    }
                    // Escape or Ctrl+[ closes (keys the panel didn't use end up here)
                    Keys.onPressed: event => { if (K.isEscape(event)) { win.requestClose(); event.accepted = true } }
                }
            }
        }
    }
}
