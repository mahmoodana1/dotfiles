import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower

// Home: clock, quick toggles, volume / brightness, live vitals on the left;
// battery, a month calendar and the latest notifications on the right.
Item {
    id: h
    property var ctl
    property bool active: false
    readonly property var st: ctl.stats

    readonly property real pad: 22
    readonly property real leftW: 392
    readonly property real rightX: pad + leftW + 16
    readonly property real rightW: width - rightX - pad

    SystemClock { id: clock; precision: SystemClock.Seconds; enabled: h.active }

    // ================= left =================
    // ---- clock ----
    Item {
        id: head
        x: h.pad; y: 20; width: h.leftW; height: 58
        Txt {
            id: time
            text: Qt.formatTime(clock.date, "HH:mm")
            size: 46; bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            anchors.left: time.right; anchors.leftMargin: 2
            anchors.baseline: time.baseline
            text: Qt.formatTime(clock.date, ":ss"); size: 18; color: Look.faint
        }
        Column {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Txt { anchors.right: parent.right; text: Qt.formatDate(clock.date, "dddd, d MMMM"); size: 12; bold: true }
            Txt { anchors.right: parent.right; text: "up " + h.st.duration(h.st.uptime) + "  ·  " + h.st.host; size: 10; color: Look.dim }
        }
    }

    // ---- toggles ----
    Grid {
        id: toggles
        x: h.pad; y: head.y + head.height + 14
        columns: 3; spacing: 8
        readonly property real tw: (h.leftW - 16) / 3
        Toggle {
            id: t0; slot: 0
            on: Networking.wifiEnabled
            icon: !Networking.wifiEnabled ? Glyphs.wifiOff : h.ctl.wifiNet ? Glyphs.wifi(h.ctl.wifiNet.signalStrength) : "\u{f05a9}"
            label: "Wi-Fi"
            sub: !Networking.wifiEnabled ? "Off" : h.ctl.wifiNet ? h.ctl.wifiNet.name : "No network"
            onToggle: Networking.wifiEnabled = !Networking.wifiEnabled
            hasMore: true
            onMore: h.ctl.openPanel("wifi")
        }
        Toggle {
            id: t1; slot: 1
            readonly property var a: h.ctl.btAdapter
            on: a !== null && a.enabled
            icon: !on ? Glyphs.btOff : h.ctl.btConnected.length ? Glyphs.btOn : Glyphs.bt
            label: "Bluetooth"
            sub: !on ? "Off" : h.ctl.btConnected.length === 1 ? h.ctl.btConnected[0].deviceName
                : h.ctl.btConnected.length > 1 ? h.ctl.btConnected.length + " devices" : "On"
            onToggle: if (a) a.enabled = !a.enabled
            hasMore: true
            onMore: h.ctl.openPanel("bt")
        }
        Toggle {
            id: t2; slot: 2
            on: h.ctl.airplane
            icon: "\u{f001d}"; label: "Airplane"; sub: on ? "Radios off" : "Off"
            onToggle: h.ctl.setAirplane(!h.ctl.airplane)
        }
        Toggle {
            id: t3; slot: 3
            on: h.ctl.dnd
            icon: on ? "\u{f009b}" : Glyphs.bell; label: "Focus"; sub: on ? "Popups muted" : "Off"
            onToggle: h.ctl.dnd = !h.ctl.dnd
            hasMore: true
            onMore: h.ctl.openPanel("notifs")
        }
        Toggle {
            id: t4; slot: 4
            on: h.ctl.awake
            icon: "\u{f0176}"; label: "Keep awake"; sub: on ? "No sleep" : "Off"
            onToggle: h.ctl.awake = !h.ctl.awake
        }
        Toggle {
            id: t5; slot: 5
            readonly property var a: h.ctl.source ? h.ctl.source.audio : null
            on: a !== null && !a.muted
            icon: Glyphs.mic(!on); label: "Microphone"; sub: on ? Math.round(a.volume * 100) + "%" : "Muted"
            onToggle: if (a) a.muted = !a.muted
            hasMore: true
            onMore: h.ctl.openPanel("sound")
        }
    }

    // ---- sliders ----
    Column {
        id: sliders
        x: h.pad; y: toggles.y + toggles.height + 14
        width: h.leftW; spacing: 8
        Slider {
            id: volS
            readonly property var a: h.ctl.sink ? h.ctl.sink.audio : null
            width: parent.width
            value: a ? a.volume : 0
            muted: !a || a.muted
            icon: Glyphs.volume(value, muted)
            label: (h.ctl.sink ? (h.ctl.sink.nickname || h.ctl.sink.description || "") : "") + "   " + (muted ? "muted" : Math.round(value * 100) + "%")
            onMoved: v => { if (a) { a.muted = false; a.volume = v } }
            onIconClicked: if (a) a.muted = !a.muted
        }
        Slider {
            id: briS
            visible: h.ctl.brightness >= 0
            width: parent.width
            value: h.ctl.brightness
            icon: Glyphs.sun
            label: "Screen   " + Math.round(value * 100) + "%"
            onMoved: v => h.ctl.setBrightness(Math.max(0.01, v))
        }
    }

    // ---- vitals ----
    Row {
        id: vitals
        x: h.pad; y: sliders.y + sliders.height + 14
        spacing: 8
        readonly property real vw: (h.leftW - 24) / 4
        Vital { label: "CPU"; value: Math.round(h.st.cpu * 100) + "%"; level: h.st.cpu; series: h.st.cpuHist; max: 1 }
        Vital { label: "Memory"; value: Math.round(h.st.memUsed / h.st.memTotal * 100) + "%"; level: h.st.memUsed / h.st.memTotal }
        Vital { label: "Temp"; value: Math.round(h.st.temp) + "°"; level: h.st.temp / 100 }
        Vital { label: "Network"; value: h.st.rate(h.st.rx).replace(" ", ""); series: h.st.rxHist; level: -1 }
    }

    // ================= right =================
    // ---- battery ----
    Card {
        id: batt
        x: h.rightX; y: 20; width: h.rightW; height: 96
        visible: h.ctl.hasBattery
        Canvas {
            id: ring
            width: 64; height: 64
            anchors.verticalCenter: parent.verticalCenter
            property real v: h.ctl.batteryPct / 100
            property color c1: Look.accent2
            property color c2: Look.wellHi
            onVChanged: requestPaint(); onC1Changed: requestPaint()
            onPaint: {
                const g = getContext("2d"); g.reset()
                g.lineWidth = 5; g.lineCap = "round"
                g.strokeStyle = c2; g.beginPath(); g.arc(32, 32, 27, 0, Math.PI * 2); g.stroke()
                g.strokeStyle = c1; g.beginPath(); g.arc(32, 32, 27, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.02, v)); g.stroke()
            }
            Txt { anchors.centerIn: parent; text: Glyphs.battery(h.ctl.batteryPct, h.ctl.charging); size: 18 }
        }
        Column {
            x: 78; anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Txt { text: h.ctl.batteryPct + "%"; size: 22; bold: true }
            Txt {
                readonly property var b: h.ctl.battery
                text: !b ? "" : h.ctl.charging ? (b.timeToFull > 0 ? h.st.duration(b.timeToFull) + " to full" : "Charging")
                    : b.timeToEmpty > 0 ? h.st.duration(b.timeToEmpty) + " left" : "On battery"
                size: 11; color: Look.dim
            }
            Txt {
                visible: h.ctl.battery && Math.abs(h.ctl.battery.changeRate) > 0.05
                text: h.ctl.battery ? Math.abs(h.ctl.battery.changeRate).toFixed(1) + " W" : ""
                size: 10; color: Look.faint
            }
        }
    }

    // ---- calendar ----
    Card {
        id: cal
        x: h.rightX; y: batt.visible ? batt.y + batt.height + 12 : 20
        width: h.rightW; height: 226
        title: Qt.formatDate(clock.date, "MMMM yyyy")
        readonly property var today: clock.date
        readonly property var cells: {
            const d = new Date(today.getFullYear(), today.getMonth(), 1)
            const lead = (d.getDay() + 6) % 7                      // Monday first
            const days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
            const out = []
            for (let i = 0; i < 42; i++) { const n = i - lead + 1; out.push(n >= 1 && n <= days ? n : 0) }
            return out
        }
        Grid {
            columns: 7
            readonly property real cw: parent.width / 7
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Txt { required property string modelData; width: parent.cw; height: 20; text: modelData; size: 9; bold: true; color: Look.faint; horizontalAlignment: Text.AlignHCenter }
            }
            Repeater {
                model: cal.cells
                Item {
                    required property int modelData
                    readonly property bool today: modelData === cal.today.getDate()
                    width: parent.cw; height: 26
                    Rectangle {
                        visible: parent.today
                        anchors.centerIn: parent; width: 24; height: 24; radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Look.accent }
                            GradientStop { position: 1; color: Look.accent2 }
                        }
                    }
                    Txt {
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? parent.modelData : ""
                        size: 10; bold: parent.today
                        color: parent.today ? Look.onAccent : Look.dim
                    }
                }
            }
        }
    }

    // ---- latest notifications ----
    Card {
        x: h.rightX; y: cal.y + cal.height + 12
        width: h.rightW; height: h.height - y - 20
        title: "Notifications"
        trailing: h.ctl.notifs.count > 0 ? "See all ›" : ""
        navigable: true
        onActivated: h.ctl.openPanel("notifs")
        MouseArea { anchors.fill: parent; anchors.topMargin: -34; onClicked: h.ctl.openPanel("notifs") }
        Txt {
            visible: h.ctl.notifs.count === 0
            anchors.centerIn: parent
            text: "All caught up"; size: 11; color: Look.faint
        }
        Column {
            width: parent.width; spacing: 8
            Repeater {
                model: h.ctl.notifs.kept.slice(0, Math.max(1, Math.floor((parent.parent.height + 8) / 42)))
                Row {
                    required property var modelData
                    spacing: 8
                    width: parent.width
                    AppIcon { size: 24; source: modelData.icon || ""; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        width: parent.width - 32
                        Txt { width: parent.width; text: modelData.summary || modelData.body; size: 11; bold: true }
                        Txt { width: parent.width; text: modelData.app + (modelData.body && modelData.summary ? "  ·  " + modelData.body.replace(/\s*\n\s*/g, " ") : ""); size: 10; color: Look.dim }
                    }
                }
            }
        }
    }

    // ================= pieces =================
    // A quick toggle: tap to switch; the › corner (when `more` is connected) opens its tab.
    component Toggle: Press {
        id: tg
        property string icon
        property string label
        property string sub
        property bool hasMore: false
        property int slot: -1
        signal toggle()
        signal more()
        width: toggles.tw; height: 70
        radius: 18
        color: pressed ? Look.wellHi : on ? Look.alpha(Look.accent, 0.30) : Look.well
        border.width: 1
        border.color: on ? Look.alpha(Look.accent2, 0.45) : "transparent"
        onClicked: tg.toggle()
        Rectangle {
            x: 10; y: 10; width: 28; height: 28; radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: tg.on ? Look.accent : Look.wellHi }
                GradientStop { position: 1; color: tg.on ? Look.accent2 : Look.wellHi }
            }
            Txt { anchors.centerIn: parent; text: tg.icon; size: 14; color: tg.on ? Look.onAccent : Look.dim }
        }
        Txt {
            visible: tg.hasMore
            anchors.right: parent.right; anchors.rightMargin: 4; y: 6
            width: 24; height: 24; horizontalAlignment: Text.AlignHCenter
            text: Glyphs.next; size: 14; color: Look.faint
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: tg.more() }
        }
        Txt { x: 10; y: 42; width: parent.width - 20; text: tg.label; size: 11; bold: true }
        Txt { x: 10; y: 55; width: parent.width - 20; text: tg.sub; size: 9; color: Look.dim }
    }

    // A vital: label, value, a meter or a sparkline. Tap → System.
    component Vital: Press {
        id: vt
        property string label
        property string value
        property real level: 0              // -1 = no meter
        property var series: []
        property real max: 0
        width: vitals.vw; height: 74
        radius: 16
        onClicked: h.ctl.openPanel("system")
        Txt { x: 10; y: 9; text: vt.label; size: 9; bold: true; color: Look.faint }
        Txt { x: 10; y: 23; text: vt.value; size: 15; bold: true }
        Graph {
            visible: vt.series.length > 1
            x: 8; y: 46; width: parent.width - 16; height: 20
            values: vt.series; max: vt.max
        }
        Meter {
            visible: vt.series.length <= 1 && vt.level >= 0
            x: 10; y: 56; width: parent.width - 20; height: 5
            value: vt.level
            warn: "#ff8a7a"
        }
    }
}
