import QtQuick

// Notifications: filter by app on the left, full cards on the right.
// Click a card to run its default action; ✕ dismisses; action buttons under
// the text. Focus (Do Not Disturb) mutes popups except critical ones.
// Keys: j / k move, g / G ends, Enter runs, Del / Backspace / x / d dismiss,
// c clears, h / l switch app, f toggles Focus.
Item {
    id: n
    property var ctl
    property bool active: false
    readonly property real pad: 22

    property string app: ""                 // "" = all
    readonly property var all: ctl.notifs.kept
    readonly property var apps: {
        const m = {}
        all.forEach(e => { const k = e.app || "Other"; if (!m[k]) m[k] = { app: k, icon: e.icon, count: 0 }; m[k].count++ })
        return Object.values(m).sort((a, b) => b.count - a.count)
    }
    readonly property var items: app === "" ? all : all.filter(e => (e.app || "Other") === app)
    property int sel: -1
    onAppsChanged: if (app !== "" && !apps.some(a => a.app === app)) app = ""

    onActiveChanged: if (active) pick()
    Connections { target: n.ctl; function onHubKeyChanged() { if (n.active) n.pick() } }
    function pick() {
        const i = items.findIndex(e => e.key === ctl.hubKey)
        sel = i >= 0 ? i : (ctl.pinned && items.length ? 0 : -1)
        if (sel >= 0) list.positionViewAtIndex(sel, ListView.Contain)
    }
    // where hjkl starts: the notification asked for (hub key), else the newest
    function entry() { return items.length ? list.itemAtIndex(Math.max(0, items.findIndex(e => e.key === ctl.hubKey))) : null }
    function run(e) { if (ctl.notifs.hasDefault(e.key)) { ctl.notifs.invoke(e.key, "default"); ctl.closePanel() } }
    function move(d) {
        if (!items.length) return
        sel = sel < 0 ? 0 : Math.max(0, Math.min(items.length - 1, sel + d))
        list.positionViewAtIndex(sel, ListView.Contain)
    }
    function cycleApp(d) {
        const keys = [""].concat(apps.map(a => a.app))
        app = keys[(keys.indexOf(app) + d + keys.length) % keys.length]; sel = items.length ? 0 : -1
    }

    TabHead {
        id: head
        x: n.pad; y: 18; width: n.width - n.pad * 2
        title: "Notifications"; hasBusy: false
        sub: n.all.length === 0 ? "All caught up" : n.all.length + (n.all.length === 1 ? " notification" : " notifications")
             + (n.ctl.dnd ? "  ·  Focus on" : "")
        Chip { visible: n.all.length > 0; text: "Clear all"; onClicked: n.ctl.notifs.clearAll() }
        Row {
            spacing: 8
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Focus"; size: 11; color: Look.dim }
            Switch { anchors.verticalCenter: parent.verticalCenter; checked: n.ctl.dnd; onToggled: v => n.ctl.dnd = v }
        }
    }

    // ---- apps ----
    Column {
        id: side
        x: n.pad; y: head.y + head.height + 16
        width: 168; spacing: 4
        AppRow { app: ""; label: "All"; count: n.all.length; icon: "" }
        Repeater {
            model: n.apps
            AppRow { required property var modelData; app: modelData.app; label: modelData.app; count: modelData.count; icon: modelData.icon || "" }
        }
    }

    // ---- cards ----
    Column {
        visible: n.items.length === 0
        x: side.x + side.width + 16; width: n.width - x - n.pad
        y: head.y + head.height + 110
        spacing: 10
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Glyphs.bellOff; size: 34; color: Look.faint }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing here"; size: 12; color: Look.dim }
    }
    ListView {
        id: list
        x: side.x + side.width + 16; y: head.y + head.height + 16
        width: n.width - x - n.pad; height: n.height - y - 18
        clip: true; spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: n.items
        delegate: Note {}
        cacheBuffer: 100000
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        displaced: Transition { NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic } }
    }

    component AppRow: Press {
        id: ar
        property string app
        property string label
        property int count
        property string icon
        width: side.width; height: 38; radius: 12
        flat: true; on: n.app === app
        selectOnFocus: true                 // moving through the apps filters live
        onClicked: { n.app = ar.app; n.sel = -1 }
        AppIcon { visible: ar.app !== ""; x: 8; anchors.verticalCenter: parent.verticalCenter; size: 22; source: ar.icon }
        Txt { visible: ar.app === ""; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "\u{f0aa8}"; size: 14; color: Look.dim }
        Txt { x: 38; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; text: ar.label; size: 11; bold: ar.on }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            height: 18; width: Math.max(22, cnt.implicitWidth + 10); radius: 9
            color: ar.on ? Look.alpha(Look.accent, 0.6) : Look.wellHi
            Txt { id: cnt; anchors.centerIn: parent; text: ar.count; size: 9; bold: true }
        }
    }

    component Note: Press {
        id: card
        required property var modelData
        required property int index
        readonly property var e: modelData
        readonly property var acts: { n.ctl.notifs.liveRev; return n.ctl.notifs.actions(e.key).filter(a => a.identifier !== "default") }
        readonly property bool picked: focused       // the hjkl ring is on it: show the whole text
        safeRemove: false                   // Del / x dismiss at once
        function remove() { n.ctl.notifs.dismiss(e.key) }
        width: ListView.view.width
        height: body.y + body.height + (acts.length ? 48 : 14)
        radius: 16
        color: pressed ? Look.wellHi : Look.well
        border.width: 1
        border.color: e.urgency >= 2 ? Look.alpha(Look.accent, 0.6) : "transparent"
        onClicked: { n.sel = index; n.run(e) }

        AppIcon { x: 14; y: 14; size: 34; source: card.e.icon || "" }
        Txt { x: 60; y: 13; width: parent.width - x - 90; text: card.e.app || "Notification"; size: 10; color: Look.dim }
        Txt { anchors.right: close.left; anchors.rightMargin: 8; y: 13; text: n.ago(card.e.time); size: 10; color: Look.faint }
        Txt {
            id: close
            anchors.right: parent.right; anchors.rightMargin: 14; y: 11
            text: Glyphs.close; size: 13; color: Look.faint
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: n.ctl.notifs.dismiss(card.e.key) }
        }
        Txt { id: sum; x: 60; y: 29; width: parent.width - x - 16; text: card.e.summary || card.e.body; size: 13; bold: true }
        Txt {
            id: body
            x: 60; y: sum.y + sum.height + 3
            width: parent.width - x - 16
            text: card.e.summary ? (card.e.body || "") : ""
            height: text ? implicitHeight : 0
            size: 11; color: Look.dim
            wrapMode: Text.Wrap
            maximumLineCount: card.picked ? 12 : 3
            elide: Text.ElideRight
        }
        Row {
            visible: card.acts.length > 0
            x: 60; y: body.y + body.height + 10
            spacing: 6
            Repeater {
                model: card.acts
                Chip { required property var modelData; text: modelData.text; accent: true; onClicked: n.ctl.notifs.invoke(card.e.key, modelData.identifier) }
            }
        }
    }

    property real clock: Date.now()
    Timer { interval: 30000; repeat: true; running: n.active; triggeredOnStart: true; onTriggered: n.clock = Date.now() }
    function ago(t) {
        const s = Math.max(0, (clock - t) / 1000)
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m ago" : s < 86400 ? Math.floor(s / 3600) + "h ago" : Math.floor(s / 86400) + "d ago"
    }
}
