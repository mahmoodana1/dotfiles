import QtQuick
import Quickshell.Services.UPower

// System: CPU and network graphs, memory / temperature / disk, battery
// details and the power profile.
Item {
    id: sys
    property var ctl
    property bool active: false
    readonly property var st: ctl.stats

    readonly property real pad: 22
    readonly property real fullW: width - pad * 2
    readonly property real halfW: (fullW - 12) / 2
    readonly property real thirdW: (fullW - 24) / 3

    TabHead {
        id: head
        x: sys.pad; y: 18; width: sys.fullW
        title: "System"; hasBusy: false
        sub: sys.st.host + "  ·  Linux " + sys.st.kernel + "  ·  up " + sys.st.duration(sys.st.uptime)
    }

    // ---- graphs ----
    Card {
        id: cpu
        x: sys.pad; y: head.y + head.height + 14; width: sys.halfW; height: 140
        title: "Processor"
        trailing: "60 s"
        Txt { text: Math.round(sys.st.cpu * 100) + "%"; size: 26; bold: true }
        Graph { y: 38; width: parent.width; height: parent.height - 38; values: sys.st.cpuHist; max: 1 }
    }
    Card {
        x: cpu.x + cpu.width + 12; y: cpu.y; width: sys.halfW; height: 140
        title: "Network"
        trailing: sys.st.iface + (sys.st.ip ? "  ·  " + sys.st.ip : "")
        Row {
            spacing: 16
            Txt { text: "\u{f0045} " + sys.st.rate(sys.st.rx); size: 15; bold: true }
            Txt { anchors.baseline: parent.children[0].baseline; text: "\u{f005d} " + sys.st.rate(sys.st.tx); size: 12; color: Look.dim }
        }
        Graph { y: 38; width: parent.width; height: parent.height - 38; values: sys.st.rxHist; values2: sys.st.txHist }
    }

    // ---- gauges ----
    Row {
        id: gauges
        x: sys.pad; y: cpu.y + cpu.height + 12
        spacing: 12
        Gauge {
            title: "Memory"
            big: sys.st.bytes(sys.st.memUsed)
            small: "of " + sys.st.bytes(sys.st.memTotal)
            value: sys.st.memUsed / sys.st.memTotal
            foot: sys.st.swapTotal > 0 ? "Swap " + sys.st.bytes(sys.st.swapUsed) + " / " + sys.st.bytes(sys.st.swapTotal) : "No swap"
        }
        Gauge {
            title: "Temperature"
            big: Math.round(sys.st.temp) + "°C"
            small: "package"
            value: sys.st.temp / 100
            foot: sys.st.temp >= 85 ? "Running hot" : sys.st.temp >= 70 ? "Warm" : "Cool"
        }
        Gauge {
            title: "Disk"
            big: sys.st.bytes(sys.st.diskUsed)
            small: "of " + sys.st.bytes(sys.st.diskTotal)
            value: sys.st.diskUsed / sys.st.diskTotal
            foot: sys.st.bytes(sys.st.diskTotal - sys.st.diskUsed) + " free on /"
        }
    }

    // ---- battery · power profile ----
    Card {
        id: bat
        x: sys.pad; y: gauges.y + gauges.height + 12
        width: sys.halfW; height: sys.height - y - 20
        title: "Battery"
        readonly property var b: sys.ctl.battery
        trailing: b && b.healthSupported ? "health " + Math.round(b.healthPercentage) + "%" : ""
        Txt { visible: !sys.ctl.hasBattery; text: "No battery"; size: 12; color: Look.dim }
        Column {
            visible: sys.ctl.hasBattery
            width: parent.width; spacing: 8
            Row {
                spacing: 10
                Txt { text: sys.ctl.batteryPct + "%"; size: 24; bold: true }
                Txt {
                    anchors.baseline: parent.children[0].baseline
                    text: !bat.b ? "" : sys.ctl.charging ? (bat.b.timeToFull > 0 ? sys.st.duration(bat.b.timeToFull) + " to full" : "Charging")
                        : bat.b.timeToEmpty > 0 ? sys.st.duration(bat.b.timeToEmpty) + " left" : "On battery"
                    size: 11; color: Look.dim
                }
            }
            Meter { width: parent.width; height: 6; value: sys.ctl.batteryPct / 100 }
            Txt {
                text: !bat.b ? "" : [Math.abs(bat.b.changeRate) > 0.05 ? Math.abs(bat.b.changeRate).toFixed(1) + " W" : "",
                                     bat.b.energyCapacity > 0 ? bat.b.energy.toFixed(1) + " / " + bat.b.energyCapacity.toFixed(1) + " Wh" : ""].filter(x => x).join("  ·  ")
                size: 10; color: Look.faint
            }
        }
    }
    Card {
        x: bat.x + bat.width + 12; y: bat.y
        width: sys.halfW; height: bat.height
        title: "Power mode"
        Row {
            width: parent.width; spacing: 6
            Repeater {
                model: [
                    { p: PowerProfile.PowerSaver, icon: "\u{f032a}", label: "Saver" },
                    { p: PowerProfile.Balanced, icon: "\u{f05d1}", label: "Balanced" },
                    { p: PowerProfile.Performance, icon: "\u{f0e4e}", label: "Boost" }
                ]
                Press {
                    required property var modelData
                    readonly property bool cur: PowerProfiles.profile === modelData.p
                    visible: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                    width: (parent.width - 12) / 3; height: 64; radius: 14
                    color: cur ? Look.alpha(Look.accent, 0.4) : pressed ? Look.wellHi : Look.well
                    border.width: 1; border.color: cur ? Look.alpha(Look.accent2, 0.6) : "transparent"
                    onClicked: PowerProfiles.profile = modelData.p
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 12; text: modelData.icon; size: 18; color: parent.cur ? Look.text : Look.dim }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 38; text: modelData.label; size: 10; bold: parent.cur; color: parent.cur ? Look.text : Look.dim }
                }
            }
        }
    }

    component Gauge: Card {
        id: gg
        property string big
        property string small
        property real value: 0
        property string foot
        width: sys.thirdW; height: 112
        Txt { text: gg.big; size: 17; bold: true }
        Txt { y: 4; anchors.right: parent.right; text: gg.small; size: 10; color: Look.faint }
        Meter { y: 30; width: parent.width; height: 6; value: gg.value; warn: "#ff8a7a" }
        Txt { y: 44; width: parent.width; text: gg.foot; size: 10; color: Look.dim }
    }
}
