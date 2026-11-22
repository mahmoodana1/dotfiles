import QtQuick
import Quickshell

// SUPER held: workspaces · clock · status. Tap the right side for the
// control center (handled by Island.qml: any tap on this view opens it).
Item {
    id: bar
    property var ctl
    property var monitor
    implicitWidth: row.implicitWidth + 32
    implicitHeight: 40

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 16
        WsStrip { monitor: bar.monitor; anchors.verticalCenter: parent.verticalCenter }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            size: 14; bold: true
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Stat {
                visible: bar.ctl.notifs.count > 0
                icon: Glyphs.bell; label: bar.ctl.notifs.count
            }
            Stat {
                icon: !bar.ctl.wifiNet ? Glyphs.wifiOff : Glyphs.wifi(bar.ctl.wifiNet.signalStrength)
                dimmed: !bar.ctl.wifiNet
            }
            Stat {
                visible: bar.ctl.btConnected.length > 0
                icon: Glyphs.btOn
            }
            Stat {
                visible: bar.ctl.hasBattery
                icon: Glyphs.battery(bar.ctl.batteryPct, bar.ctl.charging)
                label: bar.ctl.batteryPct + "%"
                tint: bar.ctl.charging ? Look.accent2 : bar.ctl.batteryPct <= 15 ? "#ff8a7a" : Look.text
            }
            Stat {
                readonly property var a: bar.ctl.sink ? bar.ctl.sink.audio : null
                icon: Glyphs.volume(a ? a.volume : 0, a ? a.muted : true)
                label: a && !a.muted ? Math.round(a.volume * 100) + "%" : ""
                dimmed: !a || a.muted
            }
        }
    }

    component Stat: Row {
        property string icon
        property string label: ""
        property bool dimmed: false
        property color tint: Look.text
        spacing: 5
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Txt { text: parent.icon; size: 13; color: parent.dimmed ? Look.faint : parent.tint }
        Txt { visible: text !== ""; text: parent.label; size: 11; color: parent.dimmed ? Look.faint : Look.dim }
    }
}
