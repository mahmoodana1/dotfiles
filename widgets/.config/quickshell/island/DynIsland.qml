import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "shared"
import "common"

// One per screen; only the focused monitor's island shows. A single glass
// capsule springs between sizes for each mode:
//   ws     workspace numbers + sliding droplet
//   level  volume / mic / brightness with a level bar
//   notif  app icon, summary, body (hover keeps it, click opens it in the hub)
//   toast  one icon + line (charger plugged/unplugged)
//   full   (SUPER held) workspaces · clock · battery/volume
//   info   (hover the island, or push the pointer to the top-center edge)
//          wifi · bluetooth · battery · volume / cpu · ram · temp · disk · brightness
//   wifi / bt / notifs   panels (notifs: the notification hub, NotifPanel.qml;
//          click the island in info / full to open it)
PanelWindow {
    id: win

    required property var modelData
    property var ctl

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool isFocused: Hyprland.focusedMonitor !== null && monitor !== null
                                      && Hyprland.focusedMonitor.name === monitor.name
    // over a fullscreen window only workspace switches, open panels and
    // SUPER+SHIFT (held) show it
    readonly property bool fullscreenHere: monitor !== null && monitor.activeWorkspace !== null
                                           && monitor.activeWorkspace.hasFullscreen
                                           && !(ctl && ctl.ignoreFullscreen)
    // on an empty workspace the island rests on screen (workspaces · clock · …)
    readonly property bool emptyHere: monitor !== null && monitor.activeWorkspace !== null
                                      && monitor.activeWorkspace.toplevels.values.length === 0
    // After the pointer leaves the info/panels with nothing else to show, the
    // island first shrinks back to its compact bar, then pops away.
    property bool reverting: false
    Timer { id: revertTimer; interval: 220; onTriggered: win.reverting = false }
    readonly property string mode: baseMode === "hidden" && reverting ? "full" : baseMode
    readonly property string baseMode: !ctl ? "hidden"
        : !isFocused ? (emptyHere ? "full" : "hidden")
        // on an empty workspace the resting full view wins over the bare
        // workspace flash, so switching into one never squishes to numbers first
        : !fullscreenHere ? ((ctl.mode === "hidden" || ctl.mode === "ws") && emptyHere ? "full" : ctl.mode)
        : ctl.panel !== "" ? ctl.panel
        : ctl.infoOpen ? "info"                      // stays while hovered
        : ctl.held && ctl.shiftHeld ? "full"
        : ctl.mode === "notif" && ctl.notif.urgency >= 2 ? "notif"   // critical: over fullscreen too
        // a switch just happened: show it even while SUPER is held (SUPER+N
        // switches with SUPER down, which otherwise means "full", hidden here)
        : ctl.now < ctl.wsUntil ? "ws"
        : ctl.now < ctl.levelUntil ? "level"         // volume/brightness bar, over fullscreen too
        : "hidden"
    readonly property bool shown: mode !== "hidden"

    // Keep drawing the last mode while fading out (no shrink on the way out).
    property string lastMode: "ws"
    onModeChanged: if (mode !== "hidden") lastMode = mode
    readonly property string viewMode: shown ? mode : lastMode

    // Pop in/out from the top edge: starts on the same frame as the event
    // (no delay), springs slightly past full size and settles. The final
    // size is set instantly; only changes made while visible morph.
    property bool morphReady: false
    onShownChanged: {
        morphReady = false
        if (shown) {
            snap.captureFrame(); lum.kick()
            popOut.stop()
            pill.popOy = 0
            popIn.restart()
            Qt.callLater(() => win.morphReady = win.shown)
        } else {
            popIn.stop()
            pill.popOy = 0.5
            popOut.restart()
        }
    }
    ParallelAnimation {
        id: popIn
        NumberAnimation { target: pill; property: "pop"; from: 0.7; to: 1; duration: 190
                          easing.type: Easing.OutBack; easing.overshoot: 2.4 }   // quick, bubbly pop
        NumberAnimation { target: pill; property: "popC"; from: 0.88; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "fade"; to: 1; duration: 60; easing.type: Easing.OutQuad }
    }
    ParallelAnimation {
        id: popOut
        // pops inwards: glass and content collapse together into the island's
        // own centre (popOy), never past its size; solid until the last frames
        NumberAnimation { target: pill; property: "pop"; to: 0.5; duration: 55; easing.type: Easing.InCubic }
        NumberAnimation { target: pill; property: "popC"; to: 0.5; duration: 55; easing.type: Easing.InCubic }
        NumberAnimation { target: pill; property: "fade"; to: 0; duration: 55; easing.type: Easing.InQuart }
    }

    readonly property int winW: 760
    readonly property int winH: 380          // room for the wifi/bluetooth panels
    readonly property real winX: (modelData.width - winW) / 2   // layer is centered

    anchors.top: true
    // Hidden and faded out, the window shrinks to just the hover strip:
    // Hyprland blurs a blurred layer's whole box every frame (mocha style),
    // and the idle 760x380 box cost ~15% of the iGPU over a playing video.
    readonly property bool idle: !shown && pill.fade === 0
    readonly property int stripW: 260
    implicitWidth: idle ? stripW : winW
    implicitHeight: idle ? 3 : winH
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island"
    // keyboard only while typing a wifi password, or in the notification hub
    // (vim keys; NotifPanel.qml)
    WlrLayershell.keyboardFocus: (wifiPanel.typing && viewMode === "wifi") || (notifPanel.active && isFocused)
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool hubPinned: ctl !== null && ctl !== undefined && ctl.panel === "notifs" && ctl.hubPinned
    // One hover area that changes shape: a thin top-center strip while hidden
    // (off over fullscreen), the island from the top edge down while shown.
    // (Two stacked hover items don't work: only the topmost one gets hovered.)
    // explicit geometry bindings: Region { item: } didn't follow the zone
    // growing from the strip to the island, so the pointer never reached it
    readonly property Region zoneMask: Region {
        x: hoverZone.x; y: hoverZone.y
        width: hoverZone.width; height: hoverZone.height
    }
    readonly property Region noMask: Region {}
    mask: shown || !fullscreenHere ? zoneMask : noMask

    // ---- hover → info panel -------------------------------------------------
    // Pointer resting there for a moment opens the info panel; leaving
    // closes it. An open notification stays as-is so it can be read.
    Item {
        id: hoverZone
        x: win.shown ? pill.x : win.idle ? 0 : (win.winW - win.stripW) / 2
        y: 0
        width: win.shown ? pill.width : win.stripW
        height: win.shown ? pill.y + pill.height : 3
        HoverHandler { id: zoneHover }
    }
    // the pill sits above hoverZone and takes the hover while shown, so
    // count either handler
    readonly property bool pointerIn: (zoneHover.hovered || pillHover.hovered)
                                      && (shown || !fullscreenHere)
    onPointerInChanged: {
        if (pointerIn) { closeInfo.stop(); idleClose.stop(); openInfo.restart() }
        else { openInfo.stop(); closeInfo.restart() }
    }
    Timer {
        id: openInfo; interval: 60
        onTriggered: {
            if (win.pointerIn && win.isFocused && win.ctl && win.viewMode !== "notif")
                win.ctl.infoOpen = true
        }
    }
    Timer {
        id: closeInfo
        interval: 40            // just debounce handler hand-offs; leaving is instant
        onTriggered: {
            if (!win.ctl || win.pointerIn || wifiPanel.typing || win.hubPinned) return
            if (win.ctl.infoOpen || win.ctl.panel !== "") {
                win.reverting = true      // shrink first; pops out if nothing remains
                revertTimer.restart()
            }
            win.ctl.infoOpen = false
            win.ctl.panel = ""
        }
    }
    // A panel opened from outside (tray / waybar / IPC) closes by itself if
    // the pointer never comes over; once it does, leaving closes it as usual.
    readonly property string ctlPanel: ctl ? ctl.panel : ""
    onCtlPanelChanged: if (ctlPanel !== "" && !pointerIn) idleClose.restart()
    Timer {
        id: idleClose
        interval: 4000
        onTriggered: if (win.ctl && !win.pointerIn && win.isFocused && !wifiPanel.typing && !win.hubPinned) win.ctl.panel = ""
    }

    // ---- live capture of what's behind (includes us; glass samples outside) --
    // Stills, not a live stream: a live copy of the whole monitor every frame
    // cost ~16% of the Intel GPU just to refract the rim. One still when the
    // island appears, then a refresh every 1.5 s while it stays up (water
    // style only: mocha's dark tint doesn't follow the backdrop's brightness,
    // and each refresh redraws the island for ~0.7 s, ~20% CPU while resting).
    ScreencopyView {
        id: snap
        captureSource: win.modelData
        live: false
        paintCursor: false
        width: win.modelData.width
        height: win.modelData.height
    }
    Timer {
        interval: 1500; repeat: true
        running: win.shown && !Theme.mocha
        onTriggered: win.recapture()
    }
    function recapture() { snap.captureFrame(); lum.kick() }
    ShaderEffectSource {
        id: behind
        sourceItem: snap
        hideSource: true
        live: true
        sourceRect: Qt.rect(win.winX, 0, win.winW, win.winH)
        width: win.winW
        height: win.winH
        visible: false
    }

    // ---- geometry per mode ----------------------------------------------------
    readonly property real fullW: 16 + wsStrip.width + 18 + fullExtra.implicitWidth + 16
    function modeW(m) {
        return m === "ws" ? wsStrip.width + 28
            : m === "level" ? 300
            : m === "notif" ? Math.min(560, Math.max(160, notifRow.implicitWidth + 36))   // hugs the content
            : m === "toast" ? toastRow.implicitWidth + 40
            : m === "full" ? fullW
            : m === "info" ? Math.max(infoTop.implicitWidth, infoBottom.implicitWidth) + 44
            : m === "wifi" || m === "bt" ? panelW
            : m === "notifs" ? notifPanel.implicitWidth
            : 120
    }
    // wifi/bt open from the first chips on the info row: just wide enough to
    // still cover them, or the panel ends short of the pointer and closes
    readonly property real panelW: Math.min(winW, Math.max(380, infoTop.implicitWidth + 16))
    function modeH(m) {
        return m === "notif" ? Math.max(40, notifRow.implicitHeight + 18) : m === "info" ? 72
            : m === "wifi" ? wifiPanel.implicitHeight
            : m === "bt" ? btPanel.implicitHeight
            : m === "notifs" ? notifPanel.implicitHeight
            : 36
    }
    readonly property bool tall: viewMode === "wifi" || viewMode === "bt" || viewMode === "notifs" || viewMode === "notif"
    readonly property real targetW: modeW(viewMode)
    readonly property real targetH: modeH(viewMode)
    // Capsule for bars, rounded rect for the tall panels. The glass eases
    // between the two: snapping to a capsule while a panel is still shrinking
    // (hub closed back to the bar) rounds the whole panel into a blob.
    readonly property real targetR: tall ? 26 : targetH / 2
    property real cornerR: targetR
    Behavior on cornerR { enabled: win.morphReady; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Publish where the island sits (monitor coordinates, final size, not the
    // springing one) for panels that bud off it: $XDG_RUNTIME_DIR/island-<monitor>.json
    readonly property string publishText: JSON.stringify({
        shown: shown, x: Math.round((modelData.width - targetW) / 2), y: 6,
        w: targetW, h: targetH,
        r: targetR
    })
    onPublishTextChanged: publishTimer.restart()
    Timer { id: publishTimer; interval: 30; onTriggered: publishFile.setText(win.publishText) }
    FileView {
        id: publishFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/island-" + win.modelData.name + ".json"
    }
    Component.onCompleted: publishTimer.restart()

    // Each view is pinned to ITS OWN final frame, on whole pixels, in pill
    // coordinates: text never creeps while the glass springs and settles,
    // and a view fading out stays put instead of jumping to the new layout.
    function fx(m) { return Math.round((winW - modeW(m)) / 2) - pill.x }          // frame left
    function fcx(m, w) { return fx(m) + Math.round((modeW(m) - w) / 2) }          // centered x
    function fcy(m, h) { return Math.round((modeH(m) - h) / 2) }                  // centered y
    // workspace strip: slides between its ws (centered) and full (left) spots
    property string stripMode: "ws"
    onViewModeChanged: if (viewMode === "ws" || viewMode === "full") stripMode = viewMode
    readonly property real stripTargetX: stripMode === "full"
        ? Math.round((winW - modeW("full")) / 2) + 16
        : Math.round((winW - wsStrip.width) / 2)
    property real stripAbsX: stripTargetX
    Behavior on stripAbsX { enabled: win.morphReady; SpringAnimation { spring: 7.5; damping: 0.48; epsilon: 0.2 } }

    // Growing: a snappy spring that pops ~8% past its size and settles in
    // ~0.18 s. Shrinking stays stiff (1.5%), so it never cuts into the content.
    component Morph: SpringAnimation {
        property bool grow: false
        spring: grow ? 12 : 7.5
        damping: 0.48
        epsilon: 0.2
    }
    // Remember which way each side is heading when a view changes (the
    // spring itself overshoots, so the live width can't tell).
    property real lastTW: targetW
    property real lastTH: targetH
    property bool growW: false
    property bool growH: false
    onTargetWChanged: { growW = targetW > lastTW; Qt.callLater(morphed) }
    onTargetHChanged: { growH = targetH > lastTH; Qt.callLater(morphed) }
    function morphed() {
        const rw = (targetW - lastTW) / lastTW, rh = (targetH - lastTH) / lastTH
        lastTW = targetW; lastTH = targetH
        // an expand stretches the way it grew most (not on shrink)
        if (morphReady && Math.max(rw, rh) > 0.05) jellyAnim.kick(rw >= rh ? 1 : -1)
    }
    // Squash & stretch of the glass on expand: it stretches the way it grows
    // and squashes the other way, then wobbles back (content stays put).
    SequentialAnimation {
        id: jellyAnim
        property real dir: 1                 // +1 wider, -1 taller
        function kick(d) { dir = d; restart() }
        NumberAnimation { target: pill; property: "jelly"; to: jellyAnim.dir; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: pill; property: "jelly"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }

    Item {
        id: pill
        width: win.targetW
        height: win.targetH
        x: (win.winW - width) / 2
        y: 6
        property real fade: 0
        property real pop: 1                 // glass scale (springy overshoot)
        property real popC: 1                // content scale (no overshoot: text never wobbles)
        property real popOy: 0               // where the pop scales from: 0 top edge (in), 0.5 centre (out)
        property real jelly: 0               // squash & stretch: +1 stretched wide, -1 tall
        readonly property real jellyX: 1 + 0.035 * jelly
        readonly property real jellyY: 1 - 0.07 * jelly
        opacity: fade
        Behavior on width { enabled: win.morphReady; Morph { grow: win.growW } }
        Behavior on height { enabled: win.morphReady; Morph { grow: win.growH } }
        visible: opacity > 0

        HoverHandler { id: pillHover }
        Binding { target: win.ctl; property: "hoverHold"; value: pillHover.hovered; when: win.isFocused }
        // Click on the island: info / full open the notification hub, a
        // notification popup opens in it, other popups are dismissed. Decide
        // from the mode at press time: a chip tap in the same click may
        // already have switched the view (info → wifi). Handlers see taps on
        // the chips inside too, so a chip marks `innerTap` and we check after.
        TapHandler {
            property string pressMode: ""
            onPressedChanged: if (pressed) { pressMode = win.viewMode; win.innerTap = false }
            onTapped: {
                const m = pressMode
                Qt.callLater(() => {
                    if (!win.ctl || win.innerTap) return
                    if (m === "info" || m === "full") win.ctl.openHub("")
                    // a notification with a default action: the click runs it (e.g. jump to its window)
                    else if (m === "notif" && win.ctl.notif.key && win.ctl.notifs.hasDefault(win.ctl.notif.key)) {
                        win.ctl.notifs.invoke(win.ctl.notif.key, "default")
                        win.ctl.dismiss()
                    }
                    else if (m === "notif" && win.ctl.notif.key) win.ctl.openHub(win.ctl.notif.key)
                    else if (["notif", "level", "toast", "ws"].indexOf(m) >= 0) win.ctl.dismiss()
                })
            }
        }

        // glass + content, grouped so the droplet can lens both
        Item {
            id: surface
            anchors.fill: parent

            GlassLum {
                id: lum
                alwaysRun: false                 // re-measure only after a new capture
                source: behind
                shape: Qt.rect(pill.x, pill.y, pill.width, pill.height)
                srcSize: Qt.size(win.winW, win.winH)
            }

            WaterGlass {
                id: glass
                animate: false                   // still glass: no redraws while resting
                // plain see-through pill: no refracting edge
                // (the screen stills are only used to read backdrop brightness)
                edgeW: 0
                tintColor: Theme.islandTintColor
                tintColor2: Theme.islandTintColor2
                tintShade: Theme.tintShade
                tintStrength: Theme.islandTint
                lumTex: lum.texture
                radius: win.cornerR
                // text-heavy views get smoked glass so they read over busy backdrops
                // (a little everywhere there's text: clear water, still readable)
                smoke: win.viewMode === "wifi" || win.viewMode === "bt" || win.viewMode === "notifs" ? 0.5
                     : win.viewMode === "info" || win.viewMode === "notif" ? 0.22 : 0.1
                useLum: 1
                x: -pad; y: -pad
                width: pill.width + pad * 2
                height: pill.height + pad * 2
                source: behind
                sourceOrigin: Qt.point(pill.x - pad, pill.y - pad)
                sourceSize: Qt.size(win.winW, win.winH)
                // scale from the top edge, like it grows out of the bezel
                // (popping out, from its centre: popOy)
                transform: Scale { origin.x: glass.width / 2; origin.y: glass.pad + pill.height * pill.popOy
                                   xScale: pill.pop * pill.jellyX; yScale: pill.pop * pill.jellyY }
            }

            // Content pops in without overshoot (the glass keeps its bounce),
            // so text never shrinks back at the end of the pop. Views inside
            // are pinned to their own frames (fx / fcx above).
            Item {
                id: contentClip
                anchors.fill: parent
                clip: true
                transform: Scale { origin.x: pill.width / 2; origin.y: pill.height * pill.popOy; xScale: pill.popC; yScale: pill.popC }
            Item {
                id: content
                anchors.fill: parent

                // -- workspaces (ws + full) --
                WorkspaceStrip {
                    id: wsStrip
                    // geometry only: the numbers are drawn crisply above the droplet (below)
                    numbers: false
                    visible: opacity > 0.01
                    monitor: win.monitor
                    height: 36
                    x: win.stripAbsX - pill.x
                    opacity: win.viewMode === "ws" || win.viewMode === "full" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 100 } }
                    // no Behavior on x: it must track the springing pill width exactly
                }

                // -- full: clock + battery/volume --
                Row {
                    id: fullExtra
                    visible: opacity > 0.01
                    x: wsStrip.x + wsStrip.width + 18
                    y: Math.round((wsStrip.height - height) / 2)
                    spacing: 14
                    opacity: win.viewMode === "full" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 100 } }
                    GlassText {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        size: 13; weight: Font.Bold
                    }
                    Row {
                        visible: win.notifCount > 0
                        spacing: 4
                        Image {
                            id: barIcon
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            source: win.flashIcon
                            cache: false                    // icon files get edited; always read fresh
                            sourceSize: Qt.size(26, 26)
                            smooth: false
                            visible: win.flashIcon !== "" && status === Image.Ready
                        }
                        GlassText {
                            text: (barIcon.visible ? "" : "\u{f009a} ") + win.notifCount
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }
                    }
                    GlassText {
                        visible: Stats.hasBattery
                        text: (Stats.charging ? "\u{f0084} " : "\u{f0079} ") + Stats.batteryPct + "%"
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                    GlassText {
                        text: (Stats.muted ? "\u{f075f} " : "\u{f028} ") + Stats.volume + "%"
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                }

                // -- level --
                Row {
                    id: levelRow
                    visible: opacity > 0.01
                    x: win.fcx("level", width); y: win.fcy("level", height)
                    spacing: 12
                    opacity: win.viewMode === "level" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 100 } }
                    readonly property string kind: win.ctl ? win.ctl.levelKind : "volume"
                    readonly property bool muted: win.ctl ? win.ctl.levelMuted : false
                    readonly property real value: win.ctl ? Math.max(0, Math.min(1, win.ctl.levelValue)) : 0

                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 15
                        text: levelRow.kind === "brightness" ? "\u{f00e0}"
                            : levelRow.kind === "mic" ? (levelRow.muted ? "\u{f036d}" : "\u{f036c}")
                            : (levelRow.muted ? "\u{f075f}" : "\u{f028}")
                    }
                    Item {
                        width: 170; height: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }
                        Rectangle {
                            width: parent.width * (levelRow.muted ? 0 : levelRow.value)
                            height: parent.height
                            radius: 3
                            color: "white"
                            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }
                    }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        text: levelRow.muted ? "off" : Math.round(levelRow.value * 100) + "%"
                    }
                }

                // -- toast (charger) --
                Row {
                    id: toastRow
                    visible: opacity > 0.01
                    x: win.fcx("toast", width); y: win.fcy("toast", height)
                    spacing: 10
                    opacity: win.viewMode === "toast" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 110 } }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.ctl ? win.ctl.toastIcon : ""
                        size: 15
                    }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.ctl ? win.ctl.toastText : ""
                        size: 12; weight: Font.Bold
                    }
                }

                // -- info (hover) --
                Column {
                    id: infoCol
                    visible: opacity > 0.01
                    x: win.fcx("info", width); y: win.fcy("info", height)
                    spacing: 7
                    opacity: win.viewMode === "info" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 110 } }
                    readonly property color dim: Qt.rgba(1, 1, 1, 0.62)
                    readonly property color warm: "#ffb38a"

                    component Chip: Item {
                        id: chip
                        property alias icon: ic.text
                        property string img: ""           // image source shown instead of the glyph
                        property alias label: lb.text
                        property color tone: "white"
                        property string action: ""        // shell command run on click
                        signal clicked()                  // or handle it in QML
                        readonly property bool clickable: action !== "" || panelChip
                        property bool panelChip: false
                        implicitWidth: chipRow.implicitWidth + (clickable ? 14 : 0)
                        implicitHeight: 22
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            visible: chip.clickable
                            color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            GlassText { id: ic; size: 13; color: chip.tone; anchors.verticalCenter: parent.verticalCenter
                                        visible: text !== "" }
                            Image { width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                                    source: chip.img; sourceSize: Qt.size(28, 28); smooth: false; cache: false
                                    visible: chip.img !== "" && status === Image.Ready }
                            GlassText { id: lb; size: 11; color: chip.tone; anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 170); elide: Text.ElideRight }
                        }
                        TapHandler {
                            id: tap
                            enabled: chip.clickable
                            onTapped: { win.innerTap = true; chip.action !== "" ? win.launch(chip.action) : chip.clicked() }
                        }
                    }

                    Row {
                        id: infoTop
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18
                        Chip {
                            icon: Stats.wifiSsid !== "" ? "\u{f05a9}" : "\u{f05aa}"
                            label: Stats.wifiSsid !== "" ? Stats.wifiSsid + "  " + Stats.wifiSignal + "%"
                                 : Stats.online ? "wired" : "offline"
                            tone: Stats.online ? "white" : infoCol.warm
                            panelChip: true
                            onClicked: if (win.ctl) win.ctl.panel = "wifi"
                        }
                        Chip {
                            icon: !Stats.btOn ? "\u{f00b2}" : Stats.btDevices !== "" ? "\u{f00b1}" : "\u{f00af}"
                            label: !Stats.btOn ? "off" : Stats.btDevices !== "" ? Stats.btDevices : "on"
                            tone: Stats.btOn ? "white" : infoCol.dim
                            panelChip: true
                            onClicked: if (win.ctl) win.ctl.panel = "bt"
                        }
                        Chip {
                            visible: win.notifCount > 0
                            icon: win.flashIcon !== "" ? "" : "\u{f009a}"
                            img: win.flashIcon
                            label: win.notifCount
                            panelChip: true
                            onClicked: if (win.ctl) win.ctl.openHub("")
                        }
                        Chip {
                            visible: Stats.hasBattery
                            icon: Stats.charging ? "\u{f0084}" : "\u{f0079}"
                            label: Stats.batteryPct + "%"
                            tone: !Stats.charging && Stats.batteryPct <= 20 ? infoCol.warm : "white"
                        }
                        Chip {
                            icon: Stats.muted ? "\u{f075f}" : "\u{f028}"
                            label: Stats.muted ? "muted" : Stats.volume + "%"
                            action: "pavucontrol"
                        }
                    }
                    Row {
                        id: infoBottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18
                        Chip { icon: "\u{f4bc}"; label: "cpu " + Stats.cpu + "%"; tone: infoCol.dim; action: win.floatTerm + "btop" }
                        Chip { icon: "\u{f035b}"; label: "ram " + Stats.mem + "%"; tone: infoCol.dim; action: win.floatTerm + "btop" }
                        Chip {
                            icon: "\u{f2c9}"; label: Stats.temp + "°"
                            tone: Stats.temp >= 85 ? "#ff8a8a" : infoCol.dim
                            action: win.floatTerm + "btop"
                        }
                        Chip { icon: "\u{f0a0}"; label: "disk " + Stats.disk + "%"; tone: infoCol.dim; action: win.floatTerm + "btop" }
                        Chip {
                            visible: win.ctl && win.ctl.backlight !== ""
                            icon: "\u{f00e0}"
                            label: win.ctl && win.ctl.blLast >= 0 ? Math.round(100 * win.ctl.blLast / win.ctl.blMax) + "%" : ""
                            tone: infoCol.dim
                        }
                    }
                }

                // -- wifi / bluetooth panels --
                WifiPanel {
                    id: wifiPanel
                    host: win
                    x: win.fx("wifi"); y: 0
                    onDetach: win.detachPanel("wifi")
                    active: win.viewMode === "wifi" && win.shown
                    width: win.panelW
                    opacity: win.viewMode === "wifi" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 120 } }
                }
                BtPanel {
                    id: btPanel
                    host: win
                    x: win.fx("bt"); y: 0
                    onDetach: win.detachPanel("bt")
                    active: win.viewMode === "bt" && win.shown
                    width: win.panelW
                    opacity: win.viewMode === "bt" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 120 } }
                }

                // -- notification hub --
                NotifPanel {
                    id: notifPanel
                    ctl: win.ctl
                    store: win.ctl ? win.ctl.notifs : null
                    x: win.fx("notifs"); y: 0
                    active: win.viewMode === "notifs" && win.shown
                    width: implicitWidth
                    opacity: win.viewMode === "notifs" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 120 } }
                }

                // -- notification --
                Row {
                    id: notifRow
                    visible: opacity > 0.01
                    x: win.fx("notif") + 18
                    y: win.fcy("notif", height)
                    spacing: 12
                    opacity: win.viewMode === "notif" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 110 } }
                    readonly property var n: win.ctl ? win.ctl.notif : ({})
                    readonly property string iconSrc: win.ctl ? win.ctl.notifs.iconFor(n.icon, n.app) : ""

                    Item {
                        width: 22; height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: nIcon
                            anchors.fill: parent
                            source: notifRow.iconSrc
                            cache: false                    // icon files get edited; always read fresh
                            sourceSize: Qt.size(44, 44)
                            fillMode: Image.PreserveAspectFit
                            smooth: false                   // keeps pixel-art icons crisp
                            visible: status === Image.Ready
                        }
                        GlassText {
                            anchors.centerIn: parent
                            visible: !nIcon.visible
                            text: "\u{f0f3}"
                            size: 14
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        width: Math.min(440, Math.max(sum.implicitWidth, body.implicitWidth))
                        GlassText {
                            text: notifRow.n.app || ""
                            size: 10
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }
                        GlassText {
                            id: sum
                            text: notifRow.n.summary || ""
                            size: 13; weight: Font.Bold
                            width: Math.min(implicitWidth, 440)
                            elide: Text.ElideRight
                        }
                        GlassText {
                            id: body
                            visible: text !== ""
                            text: (notifRow.n.body || "").replace(/\s*\n\s*/g, "  ")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.85)
                            width: Math.min(implicitWidth, 440)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            }
        }

        // ---- droplet: lens over the surface, on the active workspace -------
        ShaderEffectSource {
            id: lensSrc
            sourceItem: surface
            live: true
            visible: false
            width: pill.width
            height: pill.height
            // 2x so the droplet's 1.25x magnification stays sharp
            textureSize: Qt.size(pill.width * 2, pill.height * 2)
            smooth: true
        }
        Glass {
            id: droplet
            readonly property real restW: 24
            readonly property real w: Math.max(restW, wsStrip.dropR - wsStrip.dropL)
            readonly property real h: (wsStrip.height - 6) * Math.pow(restW / w, 0.25)
            visible: wsStrip.hasActive && wsStrip.opacity > 0.01
            opacity: wsStrip.opacity
            pad: 6
            x: wsStrip.x + wsStrip.dropL - pad
            y: wsStrip.y + (wsStrip.height - h) / 2 - pad
            width: w + pad * 2
            height: h + pad * 2
            source: lensSrc
            sourceOrigin: Qt.point(x, y)
            sourceSize: Qt.size(pill.width, pill.height)
            mode: 1
            bezel: 7
            refraction: 3
            magnify: 1.25
            tint: 0.12
            shadow: 0.22
        }
        // Every workspace number is drawn crisply above the droplet, which
        // only has glass to magnify: a lens-magnified picture of text is
        // always soft, so the picked number is never blurry, even mid-slide.
        Item {
            anchors.fill: parent
            clip: true
            // same pop as the content the strip lives in
            transform: Scale { origin.x: pill.width / 2; origin.y: pill.height * pill.popOy; xScale: pill.popC; yScale: pill.popC }
            WorkspaceStrip {
                monitor: win.monitor
                height: wsStrip.height
                x: wsStrip.x
                visible: wsStrip.visible
                opacity: wsStrip.opacity
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    property bool innerTap: false            // a chip took this click (see the pill's TapHandler)
    readonly property int notifCount: ctl ? ctl.notifs.count : 0
    // The counters show a bell; for a few seconds after a notification arrives
    // they show that message's own icon instead ("" = bell).
    property string flashIcon: ""
    Connections {
        target: win.ctl
        function onNotifChanged() {
            const n = win.ctl.notif
            win.flashIcon = n && n.icon !== undefined ? win.ctl.notifs.iconFor(n.icon, n.app) : ""
            flashIconTimer.restart()
        }
    }
    Timer { id: flashIconTimer; interval: 4000; onTriggered: win.flashIcon = "" }

    // info-panel chip actions; the panel closes after launching
    readonly property string floatTerm: "alacritty --class alacritty-float -e "
    // ⤢ in a panel: hand it to FloatPanel, which springs out of our rect
    function detachPanel(kind) {
        ctl.floatFrom = Qt.rect(winX + pill.x, pill.y, pill.width, pill.height)
        ctl.floatScreen = monitor.name
        ctl.panel = ""
        ctl.infoOpen = false
        ctl.floating = kind
    }
    function launch(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
        if (ctl) ctl.infoOpen = false
    }
}
