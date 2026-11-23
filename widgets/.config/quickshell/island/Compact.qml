import QtQuick
import Quickshell
import Quickshell.Networking

// The hover peek: clock + battery, Wi-Fi / Bluetooth, volume / brightness,
// notifications. Sliders work in place; any other click (or icon) expands
// into the Center at the matching tab.
Item {
    id: cp
    property var ctl
    implicitWidth: 400
    implicitHeight: col.implicitHeight + 32

    SystemClock { id: clock; precision: SystemClock.Minutes }
    function expand(tab) { ctl.openPanel(tab || "control") }

    MouseArea { z: -1; anchors.fill: parent; onClicked: cp.expand("control") }

    Column {
        id: col
        x: 16; y: 16; width: cp.width - 32
        spacing: 12

        Item {
            width: parent.width; height: 44
            Txt { id: time; anchors.verticalCenter: parent.verticalCenter; text: Qt.formatTime(clock.date, "HH:mm"); size: 30; bold: true }
            Column {
                anchors.left: time.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Txt { text: Qt.formatDate(clock.date, "dddd"); size: 11; bold: true }
                Txt { text: Qt.formatDate(clock.date, "d MMMM"); size: 11; color: Look.dim }
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Txt {
                    visible: cp.ctl.hasBattery
                    anchors.verticalCenter: parent.verticalCenter
                    text: Glyphs.battery(cp.ctl.batteryPct, cp.ctl.charging) + " " + cp.ctl.batteryPct + "%"
                    size: 12; bold: true; color: Look.dim
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cp.expand("system") }
                }
                Press {                     // ⤢ expand
                    width: 30; height: 30; radius: 15
                    Txt { anchors.centerIn: parent; text: "\u{f0293}"; size: 14; color: Look.dim }
                    onClicked: cp.expand("control")
                }
            }
        }

        Row {
            width: parent.width; spacing: 10
            Tile {
                on: Networking.wifiEnabled && cp.ctl.wifiNet !== null
                icon: !Networking.wifiEnabled || !cp.ctl.wifiNet ? Glyphs.wifiOff : Glyphs.wifi(cp.ctl.wifiNet.signalStrength)
                title: "Wi-Fi"
                sub: !Networking.wifiEnabled ? "Off" : cp.ctl.wifiNet ? cp.ctl.wifiNet.name : "Not connected"
                onClicked: cp.expand("wifi")
            }
            Tile {
                readonly property var a: cp.ctl.btAdapter
                on: a !== null && a.enabled
                icon: !on ? Glyphs.btOff : cp.ctl.btConnected.length ? Glyphs.btOn : Glyphs.bt
                title: "Bluetooth"
                sub: !a ? "Unavailable" : !a.enabled ? "Off"
                    : cp.ctl.btConnected.length === 1 ? cp.ctl.btConnected[0].deviceName
                    : cp.ctl.btConnected.length > 1 ? cp.ctl.btConnected.length + " devices" : "On"
                onClicked: cp.expand("bt")
            }
        }

        Slider {
            readonly property var a: cp.ctl.sink ? cp.ctl.sink.audio : null
            width: parent.width
            value: a ? a.volume : 0
            muted: !a || a.muted
            icon: Glyphs.volume(value, muted)
            label: muted ? "muted" : Math.round(value * 100) + "%"
            onMoved: v => { if (a) { a.muted = false; a.volume = v } }
            onIconClicked: cp.expand("sound")
        }
        Slider {
            visible: cp.ctl.brightness >= 0
            width: parent.width
            value: cp.ctl.brightness
            icon: Glyphs.sun
            label: Math.round(value * 100) + "%"
            onMoved: v => cp.ctl.setBrightness(Math.max(0.01, v))
        }

        Press {
            width: parent.width; height: 40; radius: 14
            onClicked: cp.expand("notifs")
            Txt {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: cp.ctl.notifs.count > 0 ? Glyphs.bell : Glyphs.bellOff
                size: 14; color: cp.ctl.notifs.count > 0 ? Look.accent2 : Look.faint
            }
            Txt {
                x: 38; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 70
                text: cp.ctl.notifs.count === 0 ? "No notifications"
                    : (cp.ctl.notifs.count === 1 ? "1 notification" : cp.ctl.notifs.count + " notifications")
                      + "  ·  " + (cp.ctl.notifs.kept[0].summary || cp.ctl.notifs.kept[0].app)
                size: 12; color: cp.ctl.notifs.count > 0 ? Look.text : Look.dim
            }
            Txt {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: Glyphs.next; size: 15; color: Look.faint
            }
        }
    }

    component Tile: Press {
        id: t
        property string icon
        property string title
        property string sub
        width: (col.width - 10) / 2; height: 62; radius: 18
        Rectangle {
            x: 10; anchors.verticalCenter: parent.verticalCenter
            width: 38; height: 38; radius: 19
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: t.on ? Look.accent : Look.wellHi }
                GradientStop { position: 1; color: t.on ? Look.accent2 : Look.wellHi }
            }
            Txt { anchors.centerIn: parent; text: t.icon; size: 16; color: t.on ? Look.onAccent : Look.dim }
        }
        Column {
            x: 58; anchors.verticalCenter: parent.verticalCenter
            width: t.width - x - 22; spacing: 2
            Txt { text: t.title; size: 12; bold: true }
            Txt { width: parent.width; text: t.sub; size: 10; color: Look.dim }
        }
        Txt {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            text: Glyphs.next; size: 13; color: Look.faint
        }
    }
}
