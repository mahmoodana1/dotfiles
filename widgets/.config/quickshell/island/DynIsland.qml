import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "shared"

// One per screen; only the focused monitor's island shows. A single glass
// capsule springs between sizes for each mode:
//   ws     workspace numbers + sliding droplet
//   level  volume / mic / brightness with a level bar
//   notif  app icon, summary, body (hover keeps it, click dismisses)
//   media  album art, title, artist
//   toast  one icon + line (charger plugged/unplugged)
//   full   (SUPER held) workspaces · clock · now playing · battery/volume
PanelWindow {
    id: win

    required property var modelData
    property var ctl

    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool isFocused: Hyprland.focusedMonitor !== null && monitor !== null
                                      && Hyprland.focusedMonitor.name === monitor.name
    readonly property string mode: isFocused && ctl ? ctl.mode : "hidden"
    readonly property bool shown: mode !== "hidden"

    readonly property int winW: 760
    readonly property int winH: 110
    readonly property real winX: (modelData.width - winW) / 2   // layer is centered

    anchors.top: true
    implicitWidth: winW
    implicitHeight: winH
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property Region pillMask: Region { item: pill }
    readonly property Region noMask: Region {}
    mask: shown ? pillMask : noMask

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
    readonly property real targetW: mode === "ws" ? wsStrip.width + 28
        : mode === "level" ? 300
        : mode === "notif" ? Math.min(560, Math.max(340, notifRow.implicitWidth + 40))
        : mode === "media" ? Math.min(460, Math.max(260, mediaRow.implicitWidth + 36))
        : mode === "toast" ? toastRow.implicitWidth + 40
        : mode === "full" ? fullW
        : 120
    readonly property real targetH: mode === "notif" ? 64 : mode === "media" ? 52
                                  : mode === "hidden" ? 26 : 36

    component Spring: SpringAnimation { spring: 5.0; damping: 0.36; epsilon: 0.25 }

    Item {
        id: pill
        width: win.targetW
        height: win.targetH
        x: (win.winW - width) / 2
        y: win.shown ? 6 : -height - 14
        opacity: win.shown ? 1 : 0
        Behavior on width { Spring { } }
        Behavior on height { Spring { } }
        Behavior on y { Spring { spring: 6.0; damping: 0.42 } }
        Behavior on opacity { NumberAnimation { duration: win.shown ? 70 : 150 } }
        visible: opacity > 0

        HoverHandler { id: pillHover }
        Binding { target: win.ctl; property: "hoverHold"; value: pillHover.hovered; when: win.isFocused }
        TapHandler { onTapped: if (win.ctl) win.ctl.dismiss() }

        // glass + content, grouped so the droplet can lens both
        Item {
            id: surface
            anchors.fill: parent

            Glass {
                id: glass
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
                    monitor: win.monitor
                    height: pill.height
                    x: win.mode === "full" ? 16 : (pill.width - width) / 2
                    opacity: win.mode === "ws" || win.mode === "full" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    // no Behavior on x: it must track the springing pill width exactly
                }

                // -- full: clock + battery/volume --
                Row {
                    id: fullExtra
                    x: wsStrip.x + wsStrip.width + 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    opacity: win.mode === "full" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    GlassText {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        size: 13; weight: Font.Bold
                    }
                    GlassText {
                        readonly property var pl: win.ctl ? win.ctl.player : null
                        visible: pl !== null && pl.isPlaying && (pl.trackTitle || "") !== ""
                        text: "\u{f075a} " + (pl ? pl.trackTitle || "" : "")
                        width: Math.min(implicitWidth, 190)
                        elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, 0.85)
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
                    anchors.centerIn: parent
                    spacing: 12
                    opacity: win.mode === "level" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
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

                // -- media --
                Row {
                    id: mediaRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    spacing: 12
                    opacity: win.mode === "media" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    readonly property var pl: win.ctl ? win.ctl.player : null

                    ClippingRectangle {
                        width: 36; height: 36
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.14)
                        Image {
                            id: art
                            anchors.fill: parent
                            source: mediaRow.pl ? mediaRow.pl.trackArtUrl || "" : ""
                            sourceSize: Qt.size(72, 72)
                            fillMode: Image.PreserveAspectCrop
                        }
                        GlassText {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "\u{f075a}"
                            size: 16
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        GlassText {
                            text: mediaRow.pl ? mediaRow.pl.trackTitle || "" : ""
                            size: 13; weight: Font.Bold
                            width: Math.min(implicitWidth, 330)
                            elide: Text.ElideRight
                        }
                        GlassText {
                            visible: text !== ""
                            text: mediaRow.pl ? mediaRow.pl.trackArtist || mediaRow.pl.identity || "" : ""
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.7)
                            width: Math.min(implicitWidth, 330)
                            elide: Text.ElideRight
                        }
                    }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 14
                        text: mediaRow.pl && mediaRow.pl.isPlaying ? "\u{f03e4}" : "\u{f040a}"
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }
                }

                // -- toast (charger) --
                Row {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 10
                    opacity: win.mode === "toast" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
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

                // -- notification --
                Row {
                    id: notifRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 18
                    spacing: 12
                    opacity: win.mode === "notif" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
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
}
