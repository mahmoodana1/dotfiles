import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// One per screen; only the focused monitor's island shows. A single glass
// capsule springs between sizes for each mode:
//   ws     workspace numbers + sliding droplet
//   level  volume / mic / brightness with a level bar
//   notif  app icon, summary, body (hover keeps it, click dismisses)
//   toast  one icon + line (charger plugged/unplugged)
//   full   (SUPER held) workspaces · clock · battery/volume
//   info   (hover the island, or push the pointer to the top-center edge)
//          wifi · bluetooth · battery · volume / cpu · ram · temp · disk · brightness
PanelWindow {
    id: win

    required property var modelData
    property var ctl

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool isFocused: Hyprland.focusedMonitor !== null && monitor !== null
                                      && Hyprland.focusedMonitor.name === monitor.name
    // over a fullscreen window only SUPER+SHIFT (held) shows it, as the full view
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
        : !fullscreenHere ? (ctl.mode === "hidden" && emptyHere ? "full" : ctl.mode)
        : ctl.panel !== "" ? ctl.panel
        : ctl.infoOpen ? "info"                      // stays while hovered
        : ctl.held && ctl.shiftHeld ? "full"
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
            popOut.stop()
            popIn.restart()
            Qt.callLater(() => win.morphReady = win.shown)
        } else {
            popIn.stop()
            popOut.restart()
        }
    }
    ParallelAnimation {
        id: popIn
        NumberAnimation { target: pill; property: "pop"; from: 0.78; to: 1; duration: 280
                          easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        NumberAnimation { target: pill; property: "fade"; to: 1; duration: 90; easing.type: Easing.OutQuad }
    }
    ParallelAnimation {
        id: popOut
        NumberAnimation { target: pill; property: "pop"; to: 0.86; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: pill; property: "fade"; to: 0; duration: 130; easing.type: Easing.InQuad }
    }

    readonly property int winW: 760
    readonly property int winH: 380          // room for the wifi/bluetooth panels
    readonly property real winX: (modelData.width - winW) / 2   // layer is centered

    anchors.top: true
    implicitWidth: winW
    implicitHeight: winH
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island"
    // keyboard only while typing a wifi password
    WlrLayershell.keyboardFocus: wifiPanel.typing && viewMode === "wifi" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        x: win.shown ? pill.x : (win.winW - 260) / 2
        y: 0
        width: win.shown ? pill.width : 260
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
            if (!win.ctl || win.pointerIn || wifiPanel.typing) return
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
        onTriggered: if (win.ctl && !win.pointerIn && win.isFocused && !wifiPanel.typing) win.ctl.panel = ""
    }

    // ---- live capture of what's behind (includes us; glass samples outside) --
    ScreencopyView {
        id: snap
        captureSource: win.modelData
        live: win.shown || pill.opacity > 0
        paintCursor: false
        width: win.modelData.width
        height: win.modelData.height
    }
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
    readonly property real targetW: viewMode === "ws" ? wsStrip.width + 28
        : viewMode === "level" ? 300
        : viewMode === "notif" ? Math.min(560, Math.max(340, notifRow.implicitWidth + 40))
        : viewMode === "toast" ? toastRow.implicitWidth + 40
        : viewMode === "full" ? fullW
        : viewMode === "info" ? Math.max(infoTop.implicitWidth, infoBottom.implicitWidth) + 44
        : viewMode === "wifi" ? wifiPanel.implicitWidth
        : viewMode === "bt" ? btPanel.implicitWidth
        : 120
    readonly property real targetH: viewMode === "notif" ? 64 : viewMode === "info" ? 72
        : viewMode === "wifi" ? wifiPanel.implicitHeight
        : viewMode === "bt" ? btPanel.implicitHeight
        : 36

    // stiff + well damped: responsive, one soft overshoot, settles in ~0.25 s
    component Spring: SpringAnimation { spring: 7.5; damping: 0.48; epsilon: 0.2 }

    Item {
        id: pill
        width: win.targetW
        height: win.targetH
        x: (win.winW - width) / 2
        y: 6
        property real fade: 0
        property real pop: 1
        opacity: fade
        // scale from the top edge, like it grows out of the bezel
        transform: Scale { origin.x: pill.width / 2; origin.y: 0; xScale: pill.pop; yScale: pill.pop }
        Behavior on width { enabled: win.morphReady; Spring { } }
        Behavior on height { enabled: win.morphReady; Spring { } }
        visible: opacity > 0

        HoverHandler { id: pillHover }
        Binding { target: win.ctl; property: "hoverHold"; value: pillHover.hovered; when: win.isFocused }
        // Click-to-dismiss for event popups only. Decide from the mode at
        // press time: a chip tap in the same click may already have switched
        // the view (info → wifi), which must not be dismissed.
        TapHandler {
            property string pressMode: ""
            onPressedChanged: if (pressed) pressMode = win.viewMode
            onTapped: if (win.ctl && ["notif", "level", "toast", "ws", "full"].indexOf(pressMode) >= 0)
                win.ctl.dismiss()
        }

        // glass + content, grouped so the droplet can lens both
        Item {
            id: surface
            anchors.fill: parent

            GlassLum {
                id: lum
                source: behind
                shape: Qt.rect(pill.x, pill.y, pill.width, pill.height)
                srcSize: Qt.size(win.winW, win.winH)
            }

            Glass {
                id: glass
                lumTex: lum.texture
                // capsule for bars; rounded rect for the tall panels
                radius: win.viewMode === "wifi" || win.viewMode === "bt" || win.viewMode === "notif" ? 26 : 999
                // text-heavy views get smoked glass so they read over busy backdrops
                smoke: win.viewMode === "wifi" || win.viewMode === "bt" ? 0.85
                     : win.viewMode === "info" || win.viewMode === "notif" ? 0.4 : 0
                useLum: 1
                x: -pad; y: -pad
                width: pill.width + pad * 2
                height: pill.height + pad * 2
                source: behind
                sourceOrigin: Qt.point(pill.x - pad, pill.y - pad)
                sourceSize: Qt.size(win.winW, win.winH)
            }

            Item {
                id: content
                anchors.fill: parent
                clip: true

                // -- workspaces (ws + full) --
                WorkspaceStrip {
                    id: wsStrip
                    visible: opacity > 0.01
                    monitor: win.monitor
                    height: pill.height
                    x: win.viewMode === "full" ? 16 : (pill.width - width) / 2
                    opacity: win.viewMode === "ws" || win.viewMode === "full" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 100 } }
                    // no Behavior on x: it must track the springing pill width exactly
                }

                // -- full: clock + battery/volume --
                Row {
                    id: fullExtra
                    visible: opacity > 0.01
                    x: wsStrip.x + wsStrip.width + 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    opacity: win.viewMode === "full" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 100 } }
                    GlassText {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        size: 13; weight: Font.Bold
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
                    anchors.centerIn: parent
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
                    anchors.centerIn: parent
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
                    anchors.centerIn: parent
                    spacing: 7
                    opacity: win.viewMode === "info" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 110 } }
                    readonly property color dim: Qt.rgba(1, 1, 1, 0.62)
                    readonly property color warm: "#ffb38a"

                    component Chip: Item {
                        id: chip
                        property alias icon: ic.text
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
                            color: tap.pressed ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.09)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            GlassText { id: ic; size: 13; color: chip.tone; anchors.verticalCenter: parent.verticalCenter }
                            GlassText { id: lb; size: 11; color: chip.tone; anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 170); elide: Text.ElideRight }
                        }
                        TapHandler {
                            id: tap
                            enabled: chip.clickable
                            onTapped: chip.action !== "" ? win.launch(chip.action) : chip.clicked()
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
                    active: win.viewMode === "wifi" && win.shown
                    width: implicitWidth
                    opacity: win.viewMode === "wifi" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 120 } }
                }
                BtPanel {
                    id: btPanel
                    host: win
                    active: win.viewMode === "bt" && win.shown
                    width: implicitWidth
                    opacity: win.viewMode === "bt" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 120 } }
                }

                // -- notification --
                Row {
                    id: notifRow
                    visible: opacity > 0.01
                    anchors.verticalCenter: parent.verticalCenter
                    x: 18
                    spacing: 12
                    opacity: win.viewMode === "notif" ? 1 : 0
                    Behavior on opacity { enabled: win.morphReady; NumberAnimation { duration: 110 } }
                    readonly property var n: win.ctl ? win.ctl.notif : ({})
                    readonly property string iconSrc: {
                        const i = n.icon || ""
                        if (i.startsWith("/")) return "file://" + i
                        if (i.startsWith("file://")) return i
                        return Quickshell.iconPath(i || (n.app || "").toLowerCase(), true)
                    }

                    Item {
                        width: 34; height: 34
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: nIcon
                            anchors.fill: parent
                            source: notifRow.iconSrc
                            sourceSize: Qt.size(68, 68)
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }
                        GlassText {
                            anchors.centerIn: parent
                            visible: !nIcon.visible
                            text: "\u{f0f3}"
                            size: 18
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
            readonly property real h: (pill.height - 6) * Math.pow(restW / w, 0.25)
            visible: wsStrip.hasActive && wsStrip.opacity > 0.01
            opacity: wsStrip.opacity
            pad: 6
            x: wsStrip.x + wsStrip.dropL - pad
            y: (pill.height - h) / 2 - pad
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
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // info-panel chip actions; the panel closes after launching
    readonly property string floatTerm: "alacritty --class alacritty-float -e "
    function launch(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
        if (ctl) ctl.infoOpen = false
    }
}
