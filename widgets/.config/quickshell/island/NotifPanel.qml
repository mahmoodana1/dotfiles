import QtQuick
import Quickshell
import "shared"
import "lib/notifs.js" as N

// Notifications hub, drawn in the island (panel mode "notifs").
// List: one row per app, newest first. Tap a single → full view; tap a group
// of more → it expands to its notifications. ✕ dismisses a row or a group.
// Full view: whole summary + body, image, action buttons (live ones only;
// history restored from disk has none), Open (default action), Dismiss.
// Which notification is open lives in ctl.hubKey ("" = the list).
// No HoverHandlers here: they would steal `hovered` from the pill.
Item {
    id: panel

    property var ctl
    property var store                   // Notifs.qml
    property bool active: false

    // what's shown; follows ctl.hubKey only while active, so the view
    // doesn't jump back to the list while the panel fades out
    property string key: ""
    property string expanded: ""         // app whose group is open
    onActiveChanged: if (active) { key = ctl ? ctl.hubKey : ""; expanded = ""; now = Date.now() }
    Connections {
        target: panel.ctl
        function onHubKeyChanged() { if (panel.active) panel.key = panel.ctl.hubKey }
    }
    readonly property var entry: store && key !== "" ? (store.entries, store.find(key)) : null
    readonly property bool full: entry !== null
    function open(k) { if (ctl) ctl.hubKey = k }
    function back() { if (ctl) ctl.hubKey = "" }

    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: panel.active; onTriggered: panel.now = Date.now() }

    // the island window is 380 tall; past this the list / body scrolls
    readonly property int listMax: 300
    readonly property color dim: Qt.rgba(1, 1, 1, 0.6)

    implicitWidth: 400
    implicitHeight: full ? fullView.y + fullView.height + 16 : list.y + list.height + 14

    component AppIcon: Item {
        property string icon: ""
        property string app: ""
        property real size: 28
        width: size; height: size
        Image {
            id: img
            anchors.fill: parent
            source: panel.store ? panel.store.iconFor(parent.icon, parent.app) : ""
            sourceSize: Qt.size(parent.size * 2, parent.size * 2)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }
        GlassText {
            anchors.centerIn: parent
            visible: !img.visible
            text: "\u{f0f3}"
            size: Math.round(parent.size * 0.55)
        }
    }
    component Close: Item {              // ✕
        signal clicked()
        width: 26; height: 26
        GlassText { anchors.centerIn: parent; text: "\u{f0156}"; size: 12; color: Qt.rgba(1, 1, 1, 0.45) }
        TapHandler { onTapped: parent.clicked() }
    }

    // ---- list ---------------------------------------------------------------------
    Item {
        id: header
        x: 16; y: 12
        width: panel.width - 32
        height: 30
        opacity: panel.full ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 110 } }
        GlassText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f009a}  Notifications"
            size: 13; weight: Font.Bold
        }
        PillButton {
            visible: panel.store && panel.store.count > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear all"
            onClicked: { panel.expanded = ""; panel.store.clearAll() }
        }
    }

    Flickable {
        id: list
        x: 12
        y: header.y + header.height + 6
        width: panel.width - 24
        height: Math.min(col.implicitHeight, panel.listMax)
        contentHeight: col.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        opacity: panel.full ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 110 } }

        Column {
            id: col
            width: list.width
            spacing: 2

            Item {                        // empty state
                visible: !panel.store || panel.store.count === 0
                width: col.width; height: 56
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    GlassText { text: "\u{f009b}"; size: 15; color: panel.dim; anchors.verticalCenter: parent.verticalCenter }
                    GlassText { text: "No notifications"; size: 11; color: panel.dim; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Repeater {
                model: panel.store ? panel.store.groups : []
                delegate: Column {
                    id: grp
                    required property var modelData
                    readonly property var g: modelData
                    readonly property bool open: panel.expanded === g.app && g.count > 1
                    width: col.width

                    // group row: icon · app · count · time · ✕ / newest summary
                    Item {
                        width: grp.width; height: 50
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: gTap.pressed ? Qt.rgba(1, 1, 1, 0.16)
                                 : grp.open ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        }
                        AppIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; icon: grp.g.appIcon; app: grp.g.app }
                        Row {
                            x: 48; y: 8
                            spacing: 6
                            GlassText { text: grp.g.app; size: 10; color: panel.dim }
                            Rectangle {
                                visible: grp.g.count > 1
                                width: cnt.implicitWidth + 10; height: 14; radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 1, 1, 0.14)
                                GlassText { id: cnt; anchors.centerIn: parent; text: grp.g.count; size: 9; weight: Font.Bold }
                            }
                        }
                        GlassText {
                            anchors.right: gClose.left
                            y: 8
                            text: N.ago(grp.g.latest.time, panel.now)
                            size: 10; color: panel.dim
                        }
                        GlassText {
                            x: 48; y: 24
                            width: gClose.x - x - 4
                            text: grp.g.latest.summary || grp.g.latest.body
                            size: 12; weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        TapHandler {
                            id: gTap
                            onTapped: grp.g.count > 1 ? panel.expanded = grp.open ? "" : grp.g.app
                                                     : panel.open(grp.g.latest.key)
                        }
                        Close {
                            id: gClose
                            anchors.right: parent.right; anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: { if (panel.expanded === grp.g.app) panel.expanded = ""; panel.store.dismissApp(grp.g.app) }
                        }
                    }

                    // expanded: each notification of the app
                    Repeater {
                        model: grp.open ? grp.g.items : []
                        delegate: Item {
                            id: it
                            required property var modelData
                            width: grp.width; height: 42
                            Rectangle {
                                x: 40; width: parent.width - 40; height: parent.height
                                radius: 12
                                color: iTap.pressed ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            }
                            GlassText {
                                x: 48; y: 5
                                width: iTime.x - x - 8
                                text: it.modelData.summary
                                size: 11; weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            GlassText {
                                x: 48; y: 22
                                width: iClose.x - x - 4
                                visible: text !== ""
                                text: (it.modelData.body || "").replace(/\s*\n\s*/g, "  ")
                                size: 10; color: Qt.rgba(1, 1, 1, 0.8)
                                elide: Text.ElideRight
                            }
                            GlassText {
                                id: iTime
                                anchors.right: iClose.left
                                y: 5
                                text: N.ago(it.modelData.time, panel.now)
                                size: 10; color: panel.dim
                            }
                            TapHandler { id: iTap; onTapped: panel.open(it.modelData.key) }
                            Close {
                                id: iClose
                                anchors.right: parent.right; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: panel.store.dismiss(it.modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- full view ----------------------------------------------------------------
    Column {
        id: fullView
        x: 16; y: 12
        width: panel.width - 32
        spacing: 10
        opacity: panel.full ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 110 } }
        // keep the last one drawn while fading back to the list
        property var e: ({ app: "", appIcon: "", summary: "", body: "", time: 0, key: "" })
        Connections {
            target: panel
            function onEntryChanged() { if (panel.entry) fullView.e = panel.entry }
        }
        readonly property var acts: panel.store && e.key ? panel.store.actions(e.key) : []
        readonly property bool hasDefault: acts.some(a => a.identifier === "default")
        readonly property string img: panel.store && e.key ? panel.store.image(e.key) : ""

        Item {                            // ← · icon app · time
            width: parent.width; height: 28
            Item {
                width: 26; height: 28
                GlassText { anchors.centerIn: parent; text: "\u{f004d}"; size: 14 }
                TapHandler { onTapped: panel.back() }
            }
            AppIcon { x: 32; size: 20; anchors.verticalCenter: parent.verticalCenter; icon: fullView.e.appIcon; app: fullView.e.app }
            GlassText {
                x: 60; anchors.verticalCenter: parent.verticalCenter
                width: fTime.x - x - 8
                text: fullView.e.app || "Unknown"
                size: 11; color: panel.dim
                elide: Text.ElideRight
            }
            GlassText {
                id: fTime
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: fullView.e.time ? N.ago(fullView.e.time, panel.now) : ""
                size: 10; color: panel.dim
            }
        }

        GlassText {
            width: parent.width
            visible: text !== ""
            text: fullView.e.summary
            size: 14; weight: Font.Bold
            wrapMode: Text.Wrap
        }

        Flickable {
            id: bodyFlick
            visible: fullView.e.body !== ""
            width: parent.width
            height: Math.min(bodyText.implicitHeight, 150)
            contentHeight: bodyText.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            GlassText {
                id: bodyText
                width: bodyFlick.width
                text: fullView.e.body
                size: 12; color: Qt.rgba(1, 1, 1, 0.9)
                wrapMode: Text.Wrap
            }
        }

        Image {
            visible: fullView.img !== "" && status === Image.Ready
            source: fullView.img
            width: Math.min(parent.width, implicitWidth)
            height: visible ? Math.min(110, implicitHeight * width / Math.max(1, implicitWidth)) : 0
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
        }

        Flow {
            width: parent.width
            spacing: 6
            PillButton {
                visible: fullView.hasDefault
                text: "Open"
                size: 11
                onClicked: { panel.store.invoke(fullView.e.key, "default"); panel.ctl.closeHub() }
            }
            Repeater {
                model: fullView.acts.filter(a => a.identifier !== "default" && a.text !== "")
                delegate: PillButton {
                    required property var modelData
                    text: modelData.text
                    size: 11
                    onClicked: { panel.store.invoke(fullView.e.key, modelData.identifier); panel.back() }
                }
            }
            PillButton {
                text: "Dismiss"
                size: 11
                danger: true
                onClicked: { panel.store.dismiss(fullView.e.key); panel.back() }
            }
        }
    }
}
