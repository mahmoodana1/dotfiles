import QtQuick
import Quickshell
import Quickshell.Io
import "shared"
import "common"

// Hold SUPER+SHIFT+P: prayer times. Content comes from the prayer daemon
// (hypr/panel/panel.py) as $XDG_RUNTIME_DIR/hud.json; this only draws it.
// Passive: no keyboard or mouse, it disappears when the key is released.
Item {
    id: root

    implicitWidth: 640
    implicitHeight: 500
    readonly property bool centered: true

    property var hud: null
    property real now: Date.now()
    // missing, broken, or older than 2 minutes: don't show stale times
    readonly property bool stale: !hud || (now / 1000 - hud.generated) > 120

    function opened(arg) { file.reload(); now = Date.now() }

    FileView {
        id: file
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hud.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.hud = JSON.parse(text()) } catch (e) { root.hud = null } }
        onLoadFailed: root.hud = null
    }
    Timer { interval: 5000; repeat: true; running: root.visible; onTriggered: root.now = Date.now() }

    readonly property color amber: "#f0b968"
    readonly property color iqamaColor: Theme.mocha ? Theme.highlight : Qt.lighter(Theme.accent, 1.45)

    // ---- dimmed screen with rain running down it -------------------------------
    property Component backdrop: Item {
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.30) }
        Canvas {
            id: rain
            anchors.fill: parent
            property real t: 0
            FrameAnimation { running: rain.visible; onTriggered: { rain.t += frameTime; rain.requestPaint() } }
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Qt.rgba(0.78, 0.88, 1.0, 0.16)
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.beginPath()
                const cols = Math.floor(width / 30)
                const cycle = height + 100
                for (let c = 0; c < cols; c++) {
                    const x = c * 30 + ((c * 17) % 30)
                    const seed = (c * 137) % 100
                    const speed = 400 + seed * 3
                    for (let i = 0; i < 2; i++) {
                        const pos = (t * speed + seed * 40 + i * (cycle / 2)) % cycle - 50
                        ctx.moveTo(x, pos)
                        ctx.lineTo(x, pos + 25)
                    }
                }
                ctx.stroke()
            }
        }
    }

    // ---- unavailable ---------------------------------------------------------------
    Column {
        visible: root.stale
        anchors.centerIn: parent
        spacing: 8
        GlassText { anchors.horizontalCenter: parent.horizontalCenter; text: "Prayer times unavailable"; size: 18 }
        GlassText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "the prayer daemon (hypr/panel/panel.py) isn't writing hud.json"
            size: 11
            color: Qt.rgba(1, 1, 1, 0.55)
        }
    }

    Column {
        visible: !root.stale
        x: 34; y: 30
        width: parent.width - 68
        spacing: 22

        // header: clock + dates, location on the right
        Item {
            width: parent.width
            height: clock.implicitHeight + dates.implicitHeight + 2
            GlassText { id: clock; text: root.hud ? root.hud.clock : ""; size: 30; weight: Font.Bold }
            GlassText {
                id: dates
                y: clock.implicitHeight + 2
                text: root.hud ? root.hud.dates : ""
                size: 12
                color: Qt.rgba(1, 1, 1, 0.65)
            }
            Column {
                anchors.right: parent.right
                y: 4
                GlassText {
                    anchors.right: parent.right
                    text: root.hud ? root.hud.location : ""
                    size: 11
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
                GlassText {
                    visible: root.hud && root.hud.fallback
                    anchors.right: parent.right
                    text: "offline · computed ±1 min"
                    size: 10
                    color: root.amber
                }
            }
        }

        // hero: what's next and how long
        Rectangle {
            readonly property bool urgent: root.hud && root.hud.hero.urgent
            width: parent.width
            height: heroCol.implicitHeight + 26
            radius: 18
            color: urgent ? Qt.rgba(0.88, 0.64, 0.35, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            border.color: urgent ? Qt.rgba(0.94, 0.72, 0.41, 0.7) : Qt.rgba(1, 1, 1, 0.16)
            Column {
                id: heroCol
                x: 20; y: 13
                spacing: 2
                Row {
                    spacing: 14
                    GlassText {
                        text: root.hud ? root.hud.hero.caption : ""
                        size: 12
                        color: parent.parent.parent.urgent ? root.amber : Qt.rgba(1, 1, 1, 0.65)
                    }
                    GlassText { text: root.hud ? root.hud.hero.arabic : ""; size: 14 }
                }
                GlassText {
                    text: root.hud ? root.hud.hero.big : ""
                    size: 40
                    weight: Font.Bold
                    color: parent.parent.urgent ? root.amber : "white"
                }
                GlassText { text: root.hud ? root.hud.hero.detail : ""; size: 13; color: Qt.rgba(1, 1, 1, 0.8) }
            }
        }

        // the day's table: marker | name | arabic | adhan | iqama
        Column {
            spacing: 8
            readonly property var colW: [22, 110, 110, 90, 90]

            Row {
                GlassText { width: 22 + 110 + 110; text: "" }
                GlassText { width: 90; horizontalAlignment: Text.AlignRight; text: "ADHAN"; size: 10; color: Qt.rgba(1, 1, 1, 0.5) }
                GlassText { width: 90; horizontalAlignment: Text.AlignRight; text: "IQAMA"; size: 10; color: root.iqamaColor }
            }
            Repeater {
                model: root.hud ? root.hud.rows : []
                delegate: Row {
                    id: r
                    required property var modelData
                    readonly property string st: modelData.state
                    readonly property bool live: st === "live"
                    readonly property real sz: st === "sunrise" ? 12 : 16
                    readonly property int wt: live ? Font.Bold : Font.Medium
                    opacity: st === "past" ? 0.38 : st === "sunrise" ? 0.5 : 1
                    GlassText { width: 22; text: r.live ? "\u25B6" : ""; size: 12; anchors.verticalCenter: parent.verticalCenter }
                    GlassText { width: 110; text: r.modelData.name; size: r.sz; weight: r.wt }
                    GlassText { width: 110; text: r.modelData.arabic; size: r.sz; weight: r.wt }
                    GlassText { width: 90; horizontalAlignment: Text.AlignRight; text: r.modelData.adhan; size: r.sz; weight: r.wt }
                    GlassText {
                        width: 90; horizontalAlignment: Text.AlignRight
                        text: r.modelData.iqama; size: r.sz; weight: r.wt
                        color: r.st === "sunrise" ? "white" : root.iqamaColor
                    }
                }
            }
        }
    }
}
