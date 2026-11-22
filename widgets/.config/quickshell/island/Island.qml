import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "lib/mode.js" as M

// One monitor's island: a frosted pill that emerges from the top edge,
// morphs between faces (bar, level, popup, panels) and tucks back in.
//
//   body   palette-tinted gradient over Hyprland's blur (layer rule "island")
//   aura   accent light from the left; it spreads with the volume level and
//          brightens for popups. Panels get it from the top instead.
//   rim    hairline edge + a lit top lip
PanelWindow {
    id: win
    required property var modelData
    property var ctl

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property string monName: monitor ? monitor.name : ""
    readonly property var aws: monitor ? monitor.activeWorkspace : null
    readonly property bool fullscreen: aws !== null && aws.hasFullscreen && !ctl.ignoreFullscreen
    readonly property bool empty: aws !== null && aws.toplevels.values.length === 0
    readonly property bool here: monName !== "" && monName === (M.isPanel(ctl.view) ? ctl.panelScreen : ctl.focusedScreen)
    readonly property string view: M.forScreen(ctl.view, {
        here: here, fullscreen: fullscreen, empty: empty, shift: ctl.held && ctl.shift, critical: ctl.critical   // Shift alone never shows it
    })
    readonly property bool shown: view !== "hidden"

    // what the pill shows; kept while it tucks away so the content doesn't vanish first
    property string face: "ws"
    onViewChanged: if (view !== "hidden") face = view
    readonly property bool panelFace: M.isPanel(face)

    // ---- the layer -----------------------------------------------------------
    // Unmapped when idle (no surface, no blur work). It stays mapped a few
    // seconds after hiding, so popping again soon doesn't wait on a new surface.
    property bool linger: false
    Timer { id: lingerT; interval: 4000; onTriggered: win.linger = false }
    onShownChanged: {
        if (shown) { lingerT.stop(); linger = true; entered = false; if (panelFace) idleT.restart() }
        else lingerT.restart()
        pill.closing = !shown           // set before `open` so the right easing runs
        pill.open = shown
    }
    anchors.top: true
    implicitWidth: 820
    implicitHeight: 620
    visible: shown || linger
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island"
    WlrLayershell.keyboardFocus: !shown || !panelFace ? WlrKeyboardFocus.None
        : ctl.pinned || face !== "compact" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand   // the Center takes the keys
    Region { id: pillMask; item: pill }
    Region { id: noMask }
    mask: pill.open ? pillMask : noMask

    // ---- panels close when left alone ------------------------------------------
    property bool entered: false
    onFaceChanged: if (panelFace && shown && !hover.hovered) { entered = false; idleT.restart() }
    Timer {                                 // opened from outside and never visited
        id: idleT; interval: 4000
        onTriggered: if (win.panelFace && !win.entered && !win.ctl.pinned && !center.typing) win.ctl.closePanel()
    }
    // hovering the bar or the workspace pill grows it into the compact peek
    readonly property bool peekable: face === "full" || face === "ws"
    Timer {
        id: peekT; interval: 220
        onTriggered: if (hover.hovered && win.peekable && win.shown) win.ctl.openPanel("compact")
    }
    Timer {                                 // pointer left (the peek lets go sooner)
        id: leaveT; interval: win.face === "compact" ? 350 : 650
        onTriggered: if (win.panelFace && !hover.hovered && !win.ctl.pinned && !center.typing) win.ctl.closePanel()
    }

    // ---- the pill ----------------------------------------------------------------
    Item {
        id: pill
        property bool open: false
        property bool closing: false
        readonly property Item faceItem: win.faceFor(win.face)
        readonly property real tw: faceItem ? faceItem.implicitWidth : 120
        readonly property real th: faceItem ? faceItem.implicitHeight : 36

        width: open ? tw : Math.min(tw, 140) * 0.55        // tucks into a small bead
        height: open ? th : 10
        x: Math.round((win.implicitWidth - width) / 2)   // not win.width: unset on the first mapped frame
        y: open ? 8 : 0
        opacity: open ? 1 : 0
        Behavior on width { NumberAnimation { duration: pill.closing ? 170 : Look.morph
            easing.type: pill.closing ? Easing.InCubic : Easing.OutBack; easing.overshoot: Look.settle } }
        Behavior on height { NumberAnimation { duration: pill.closing ? 170 : Look.morph
            easing.type: pill.closing ? Easing.InCubic : Easing.OutBack; easing.overshoot: Look.settle } }
        Behavior on y { NumberAnimation { duration: pill.closing ? 170 : Look.morph; easing.type: pill.closing ? Easing.InCubic : Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: pill.closing ? 170 : 90; easing.type: pill.closing ? Easing.InQuart : Easing.OutQuad } }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) { win.entered = true; leaveT.stop(); idleT.stop(); if (win.peekable) peekT.restart() }
                else { peekT.stop(); if (win.panelFace) leaveT.restart() }
            }
        }
        Binding { target: win.ctl; property: "hoverHold"; value: hover.hovered; when: win.here }

        readonly property real r: Math.min(height / 2, 24)

        Rectangle {                         // body
            anchors.fill: parent
            radius: pill.r
            gradient: Gradient {
                GradientStop { position: 0; color: Look.surfaceTop }
                GradientStop { position: 1; color: Look.surfaceBottom }
            }
        }
        Rectangle {                         // aura, from the left (bars and popups)
            id: aura
            anchors.fill: parent
            radius: pill.r
            opacity: win.panelFace ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
            readonly property bool loud: ["level", "notif", "toast"].indexOf(win.face) >= 0
            readonly property color tone: win.face === "notif" && win.ctl.critical ? Look.accent2 : Look.accent
            property real strength: loud ? 0.30 : 0.14
            property real spread: win.face === "level" ? 0.12 + 0.75 * (win.ctl.levelMuted ? 0 : Math.min(1, win.ctl.levelValue))
                                : loud ? 0.6 : 0.42
            Behavior on strength { NumberAnimation { duration: 260 } }
            Behavior on spread { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Look.alpha(aura.tone, aura.strength) }
                GradientStop { position: Math.max(0.05, aura.spread); color: Look.alpha(aura.tone, 0) }
            }
        }
        Rectangle {                         // aura, from the top (panels)
            anchors.fill: parent
            radius: pill.r
            opacity: win.panelFace ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            gradient: Gradient {
                GradientStop { position: 0; color: Look.alpha(Look.accent, 0.20) }
                GradientStop { position: Math.min(0.5, 90 / Math.max(1, pill.height)); color: Look.alpha(Look.accent, 0) }
            }
        }
        Rectangle {                         // rim
            anchors.fill: parent
            radius: pill.r
            color: "transparent"
            border.width: 1
            border.color: Look.rim
        }
        Rectangle {                         // lit top lip
            x: pill.r * 0.8; width: pill.width - x * 2; y: 1; height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Look.lip }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // ---- faces ----
        FocusScope {
            id: stage
            anchors.fill: parent
            clip: true
            focus: true
            Keys.onEscapePressed: win.ctl.closePanel()

            Face {
                id: fWs
                name: "ws"
                implicitWidth: wsStrip.implicitWidth + 28; implicitHeight: 36
                MouseArea { z: -1; anchors.fill: parent; onClicked: win.ctl.dismiss() }
                WsStrip { id: wsStrip; anchors.centerIn: parent; monitor: win.monitor }
            }
            Face {
                id: fFull
                name: "full"
                implicitWidth: full.implicitWidth; implicitHeight: full.implicitHeight
                MouseArea { z: -1; anchors.fill: parent; onClicked: win.ctl.openPanel("control") }
                FullBar { id: full; anchors.fill: parent; ctl: win.ctl; monitor: win.monitor }
            }
            Face {
                id: fLevel
                name: "level"
                implicitWidth: level.implicitWidth; implicitHeight: level.implicitHeight
                MouseArea { z: -1; anchors.fill: parent; onClicked: win.ctl.dismiss() }
                LevelView { id: level; anchors.fill: parent; ctl: win.ctl }
            }
            Face {
                id: notifFace
                name: "notif"
                implicitWidth: notif.implicitWidth; implicitHeight: notif.implicitHeight
                MouseArea {
                    z: -1; anchors.fill: parent
                    onClicked: {
                        const k = win.ctl.notif.key
                        if (k && win.ctl.notifs.hasDefault(k)) { win.ctl.notifs.invoke(k, "default"); win.ctl.dismiss() }
                        else if (k) win.ctl.openHub(k)
                        else win.ctl.dismiss()
                    }
                }
                NotifView { id: notif; anchors.fill: parent; ctl: win.ctl; active: notifFace.on }
            }
            Face {
                id: fToast
                name: "toast"
                implicitWidth: toast.implicitWidth; implicitHeight: toast.implicitHeight
                MouseArea { z: -1; anchors.fill: parent; onClicked: win.ctl.dismiss() }
                ToastView { id: toast; anchors.fill: parent; ctl: win.ctl }
            }
            Face {
                id: compactFace
                name: "compact"; pinTop: true
                implicitWidth: compact.implicitWidth; implicitHeight: compact.implicitHeight
                Compact { id: compact; anchors.fill: parent; ctl: win.ctl }
            }
            Face {
                id: centerFace
                name: "center"; pinTop: true
                want: win.panelFace && win.face !== "compact"   // every other panel is a tab of the Center
                implicitWidth: center.implicitWidth; implicitHeight: center.implicitHeight
                Center { id: center; anchors.fill: parent; ctl: win.ctl; active: centerFace.on; focus: centerFace.on }
            }
        }
    }

    function faceFor(name) {
        if (name === "compact") return compactFace
        if (M.isPanel(name)) return centerFace
        return { ws: fWs, full: fFull, level: fLevel, notif: notifFace, toast: fToast }[name] || null
    }

    // A face sits at its own final size, centred in the pill (panels pinned to
    // the top), so nothing reflows while the pill morphs around it. It fades
    // and settles in as it takes over; the outgoing one fades out faster.
    component Face: Item {
        id: f
        property string name
        property bool pinTop: false
        property bool want: win.face === name
        readonly property bool on: want && pill.open
        width: implicitWidth; height: implicitHeight
        x: Math.round((pill.width - width) / 2)
        y: pinTop ? 0 : Math.round((pill.height - height) / 2)
        opacity: on ? 1 : 0
        scale: on ? 1 : 0.96
        visible: opacity > 0.01
        enabled: on
        Behavior on opacity { NumberAnimation { duration: f.on ? Look.fadeIn : Look.fadeOut; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: Look.morph; easing.type: Easing.OutCubic } }
    }
}
