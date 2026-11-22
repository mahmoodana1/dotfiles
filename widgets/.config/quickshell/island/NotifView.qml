import QtQuick

// A notification popup: icon · app · summary · body, with a thin countdown
// line along the bottom that drains while it shows (and pauses on hover).
Item {
    id: nv
    property var ctl
    property bool active: false
    readonly property var n: ctl.notif
    readonly property string body: (n.body || "").replace(/\s*\n\s*/g, "  ")
    readonly property bool twoLines: (n.summary || "") !== "" && body !== ""
    // sized by the text's natural width (not a Column's, which follows its children)
    readonly property real textW: Math.max(app.implicitWidth, sum.implicitWidth, twoLines ? bod.implicitWidth : 0)
    implicitWidth: Math.round(Math.min(480, Math.max(240, textW + 52 + 20)))
    implicitHeight: twoLines ? 64 : 50

    AppIcon {
        x: 12; anchors.verticalCenter: parent.verticalCenter
        source: nv.n.icon || ""
    }
    Txt {
        id: app
        x: 52; y: nv.twoLines ? 9 : 8
        width: nv.width - x - 16
        text: nv.n.app || "Notification"
        size: 10; color: nv.ctl.critical ? Look.accent2 : Look.dim
    }
    Txt {
        id: sum
        x: 52; y: app.y + 14
        width: nv.width - x - 16
        text: nv.n.summary || nv.body
        size: 12; bold: true
    }
    Txt {
        id: bod
        visible: nv.twoLines
        x: 52; y: sum.y + 17
        width: nv.width - x - 16
        text: nv.body
        size: 11; color: Look.dim
    }

    // countdown
    Rectangle {
        id: line
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        x: 18; height: 2; radius: 1
        color: Look.alpha(Look.accent2, 0.7)
        property real k: 1
        width: (nv.width - 36) * k
    }
    NumberAnimation {
        id: drain
        target: line; property: "k"; from: 1; to: 0
        duration: nv.ctl.notifMs
        paused: running && nv.ctl.hoverHold
    }
    onNChanged: if (active) drain.restart()
    onActiveChanged: if (active) drain.restart(); else drain.stop()
}
