import QtQuick

// Right island: alert icons only when something needs attention, plus a dot.
// Hovering the island slides out the details.
Row {
    id: info

    property bool expanded: false
    readonly property color warm: "#ffb38a"
    readonly property color hot: "#ff8a8a"

    spacing: 10
    height: parent ? parent.height : 30

    component Stat: GlassText {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // ---- details (hover) ------------------------------------------------
    Row {
        spacing: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: opacity > 0
        opacity: info.expanded ? 1 : 0
        width: info.expanded ? implicitWidth : 0
        clip: true
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Stat { text: "\u{f4bc} " + Stats.cpu + "%" }
        Stat { text: "\u{f035b} " + Stats.mem + "%" }
        Stat {
            text: "\u{f2c9} " + Stats.temp + "°"
            color: Stats.temp >= 85 ? info.hot : "white"
        }
        Stat { text: "\u{f0a0} " + Stats.disk + "%" }
        Stat {
            visible: Stats.hasBattery
            text: (Stats.charging ? "\u{f0084} " : "\u{f0079} ") + Stats.batteryPct + "%"
        }
        Stat { text: (Stats.muted ? "\u{f075f} " : "\u{f028} ") + Stats.volume + "%" }
    }

    // ---- alerts (always, when relevant) ---------------------------------
    Stat {
        visible: !info.expanded && !Stats.online
        text: "\u{f092e} offline"
        color: info.warm
    }
    Stat {
        visible: !info.expanded && Stats.muted
        text: "\u{f075f}"
        color: info.warm
    }
    Stat {
        visible: !info.expanded && Stats.hasBattery && !Stats.charging && Stats.batteryPct <= 20
        text: "\u{f007a} " + Stats.batteryPct + "%"
        color: Stats.batteryPct <= 10 ? info.hot : info.warm
    }

    // the dot
    Stat {
        text: "\u{f444}"
        size: 10
        color: info.expanded ? "white" : Qt.rgba(1, 1, 1, 0.75)
    }
}
