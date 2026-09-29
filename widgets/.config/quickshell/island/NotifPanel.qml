import QtQuick
import Quickshell
import "shared"
import "lib/notifs.js" as N
import "common/keys.js" as K

// Notifications hub, drawn in the island (panel mode "notifs").
// List: one row per app, newest first. Tap a single → full view; tap a group
// of more → it expands to its notifications. ✕ dismisses a row or a group.
// Full view: whole summary + body, image, action buttons (live ones only;
// history restored from disk has none), Open (default action), Dismiss.
// Which notification is open lives in ctl.hubKey ("" = the list).
// No HoverHandlers here: they would steal `hovered` from the pill.
// Keyboard (the island grabs it while the hub is open): j/k move, g/G ends,
// l/Enter open (a group expands), h collapses, d dismisses; in the full view
// j/k scroll, Enter/o opens, 1-9 run actions, h/Esc go back. Ctrl+] closes.
Item {
    id: panel

    property var ctl
    property var store                   // Notifs.qml
    property bool active: false

    // what's shown; follows ctl.hubKey only while active, so the view
    // doesn't jump back to the list while the panel fades out
    property string key: ""
    property string expanded: ""         // app whose group is open
    onActiveChanged: {
        if (!active) return
        key = ctl ? ctl.hubKey : ""
        now = Date.now()
        // land on the notification it opened with, else the newest group
        const at = store ? N.selFor(store.groups, key) : { expanded: "", id: "" }
        expanded = at.expanded
        selId = at.id
        sel = 0
        relocate()
        list.contentY = 0
        forceActiveFocus()
    }
    Connections {
        target: panel.ctl
        function onHubKeyChanged() { if (panel.active) panel.key = panel.ctl.hubKey }
    }
    readonly property var entry: store && key !== "" ? (store.entries, store.find(key)) : null
    readonly property bool full: entry !== null
    function open(k) { if (ctl) ctl.hubKey = k }
    function back() { if (ctl) ctl.hubKey = "" }

    // ---- keyboard selection ---------------------------------------------------
    readonly property var rows: store ? N.rows(store.groups, expanded) : []
    property int sel: 0
    property string selId: ""
    readonly property var cur: rows[sel]
    readonly property bool kbd: activeFocus     // selection only drawn while we have the keyboard
    onRowsChanged: relocate()
    function relocate() {
        sel = N.relocate(rows, selId, sel)
        selId = N.rowId(rows[sel])
        reveal()
    }
    function select(i) {
        if (rows.length === 0) return
        sel = Math.max(0, Math.min(rows.length - 1, i))
        selId = N.rowId(rows[sel])
        reveal()
    }
    function reveal() {                          // scroll the list to the selection
        if (!rows[sel]) return
        const r = N.rowSpan(rows, sel, 50, 42, col.spacing)
        if (r.y < list.contentY) list.contentY = r.y
        else if (r.y + r.h > list.contentY + list.height) list.contentY = r.y + r.h - list.height
    }
    function activate() {                        // Enter / tap: open one, expand/collapse a group
        const r = cur
        if (!r) return
        if (r.key !== "") open(r.key)
        else expanded = expanded === r.app ? "" : r.app
    }
    function enter() {                           // l: into a group, or open
        const r = cur
        if (!r) return
        if (r.key !== "") open(r.key)
        else { expanded = r.app; select(sel + 1) }
    }
    function leave() {                           // h: out of a group
        const r = cur
        if (!r || expanded !== r.app) return
        selId = "g:" + r.app
        expanded = ""
    }
    function dismissCur() {
        const r = cur
        if (!r) return
        // pick the landing row first: dismissing reorders groups on the way
        selId = N.afterRemove(rows, sel)
        if (r.kind === "item") store.dismiss(r.key)
        else { if (expanded === r.app) expanded = ""; store.dismissApp(r.app) }
    }
    function dismissOpen() {                     // the one in the full view
        if (cur && cur.key === fullView.e.key) selId = N.afterRemove(rows, sel)
        store.dismiss(fullView.e.key)
        back()
    }
    function scrollBody(dy) {
        bodyFlick.contentY = Math.max(0, Math.min(bodyFlick.contentHeight - bodyFlick.height, bodyFlick.contentY + dy))
    }

    Keys.onPressed: event => {
        if (!ctl) return
        ctl.hubPinned = true                      // keyboard in use: only keys close it now
        const k = event.key
        const l = K.letter(event)
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const enterKey = k === Qt.Key_Return || k === Qt.Key_Enter
        let done = true
        if (K.isClose(event)) ctl.closeHub()
        else if (full) {
            const acts = fullView.acts.filter(a => a.identifier !== "default" && a.text !== "")
            const n = k - Qt.Key_1
            if (K.isEscape(event) || l === "h" || l === "q" || k === Qt.Key_Left || k === Qt.Key_Backspace) back()
            else if (ctrl && l === "d") scrollBody(bodyFlick.height / 2)
            else if (ctrl && l === "u") scrollBody(-bodyFlick.height / 2)
            else if (ctrl) done = false
            else if (l === "j" || k === Qt.Key_Down) scrollBody(40)
            else if (l === "k" || k === Qt.Key_Up) scrollBody(-40)
            else if (l === "g" || k === Qt.Key_Home) scrollBody(-bodyFlick.contentHeight)
            else if (l === "G" || k === Qt.Key_End) scrollBody(bodyFlick.contentHeight)
            else if ((enterKey || l === "o") && fullView.hasDefault) { store.invoke(fullView.e.key, "default"); ctl.closeHub() }
            else if (n >= 0 && n < 9 && n < acts.length) { store.invoke(fullView.e.key, acts[n].identifier); back() }
            else if (l === "d" || l === "x" || k === Qt.Key_Delete) dismissOpen()
            else done = false
        } else {
            if (K.isEscape(event) || l === "q") ctl.closeHub()
            else if (ctrl && l === "d") select(sel + 5)
            else if (ctrl && l === "u") select(sel - 5)
            else if (ctrl) done = false
            else if (l === "j" || k === Qt.Key_Down || k === Qt.Key_Tab) select(sel + 1)
            else if (l === "k" || k === Qt.Key_Up || k === Qt.Key_Backtab) select(sel - 1)
            else if (l === "g" || k === Qt.Key_Home) select(0)
            else if (l === "G" || k === Qt.Key_End) select(rows.length - 1)
            else if (enterKey || k === Qt.Key_Space) activate()
            else if (l === "l" || k === Qt.Key_Right) enter()
            else if (l === "h" || k === Qt.Key_Left) leave()
            else if (l === "d" || l === "x" || k === Qt.Key_Delete) dismissCur()
            else done = false
        }
        event.accepted = done
    }

    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: panel.active; onTriggered: panel.now = Date.now() }

    // the island window is 380 tall; past this the list / body scrolls
    readonly property int listMax: 300
    // list ⇄ full view slide sideways: the list leaves left, the notification
    // comes in from the right (the island's content clip hides what's outside)
    property real shift: full ? 1 : 0
    Behavior on shift { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
        x: 16 - panel.width * panel.shift; y: 12
        width: panel.width - 32
        height: 30
        opacity: 1 - panel.shift
        visible: opacity > 0
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
        x: 12 - panel.width * panel.shift
        y: header.y + header.height + 6
        width: panel.width - 24
        height: Math.min(col.implicitHeight, panel.listMax)
        contentHeight: col.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        opacity: 1 - panel.shift
        visible: opacity > 0

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
                            readonly property bool picked: panel.kbd && panel.selId === "g:" + grp.g.app
                            anchors.fill: parent
                            radius: 14
                            color: gTap.pressed ? Qt.rgba(1, 1, 1, 0.16)
                                 : picked ? Qt.rgba(1, 1, 1, 0.13)
                                 : grp.open ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            border.width: picked ? 1 : 0
                            border.color: Qt.rgba(1, 1, 1, 0.28)
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
                            onTapped: { panel.selId = "g:" + grp.g.app; panel.relocate(); panel.activate() }
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
                                readonly property bool picked: panel.kbd && panel.selId === "i:" + it.modelData.key
                                x: 40; width: parent.width - 40; height: parent.height
                                radius: 12
                                color: iTap.pressed ? Qt.rgba(1, 1, 1, 0.16)
                                     : picked ? Qt.rgba(1, 1, 1, 0.13) : "transparent"
                                border.width: picked ? 1 : 0
                                border.color: Qt.rgba(1, 1, 1, 0.28)
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
                            TapHandler {
                                id: iTap
                                onTapped: { panel.selId = "i:" + it.modelData.key; panel.relocate(); panel.open(it.modelData.key) }
                            }
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
        x: 16 + panel.width * (1 - panel.shift); y: 12
        width: panel.width - 32
        spacing: 10
        opacity: panel.shift
        visible: opacity > 0
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
                onClicked: panel.dismissOpen()
            }
        }
    }
}
