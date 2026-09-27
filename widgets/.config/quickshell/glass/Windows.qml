import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "shared"
import "lib/match.js" as Match

// SUPER+CTRL+S: every open window, live previews, all workspaces.
// Type to filter (app, title, workspace), arrows to move, Enter to jump there.
FocusScope {
    id: root
    signal closeRequested()

    readonly property int cols: 3
    readonly property real tileW: 300
    readonly property real tileH: 238
    readonly property int shownRows: Math.max(1, Math.min(3, Math.ceil(wins.length / cols)))
    implicitWidth: cols * tileW + 44
    implicitHeight: 22 + 44 + 16 + shownRows * tileH + 18
    readonly property bool centered: true

    function opened(arg) {
        Hyprland.refreshToplevels()
        search.text = ""
        grid.currentIndex = 0
        search.forceActiveFocus()
    }

    function appOf(t) { return t.wayland ? t.wayland.appId : (t.lastIpcObject.class || "") }
    function wsOf(t) { return t.workspace ? t.workspace.id : 0 }

    readonly property var wins: {
        const q = search.text.trim()
        const out = []
        for (const t of Hyprland.toplevels.values) {
            const ws = wsOf(t)
            const s = Match.best(q, [[appOf(t), 1], [t.title, 0.9, true], ["ws " + ws, 0.6, true]])
            if (s >= 0) out.push({ t: t, s: s, ws: ws })
        }
        // search: best match first; otherwise by workspace, focused window first
        out.sort((a, b) => (q ? b.s - a.s : 0) || (b.t.activated - a.t.activated) || a.ws - b.ws)
        return out.map(x => x.t)
    }

    // Focus by address through Hyprland itself: that also switches to the
    // window's workspace. (Wayland activate() is ignored here because
    // misc.focus_on_activate is off.) It runs a moment after the panel closes:
    // releasing our keyboard grab makes Hyprland refocus the previous window,
    // which would undo an earlier jump. Dispatch strings are Lua in this build.
    function focusWindow(t) {
        if (!t) return
        const addr = String(t.address).startsWith("0x") ? t.address : "0x" + t.address
        root.closeRequested()
        Quickshell.execDetached(["sh", "-c",
            "sleep 0.15; hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + addr + "\" })'"])
    }

    // ---- search pill -------------------------------------------------------
    Rectangle {
        id: pill
        x: 22; y: 22
        width: parent.width - 44
        height: 44
        radius: 22
        color: Qt.rgba(1, 1, 1, 0.10)
        border.color: Qt.rgba(1, 1, 1, search.activeFocus ? 0.28 : 0.14)

        GlassText {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f05b1}"            // window
            size: 17
            color: Qt.rgba(1, 1, 1, 0.7)
        }
        TextInput {
            id: search
            x: 46
            width: parent.width - 62
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            selectionColor: Qt.rgba(1, 1, 1, 0.3)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            focus: true
            onTextChanged: grid.currentIndex = 0

            Text {
                visible: search.text === ""
                text: root.wins.length + " windows · type to filter"
                color: Qt.rgba(1, 1, 1, 0.75)
                font: search.font
            }

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Right: grid.moveCurrentIndexRight(); break
                case Qt.Key_Left:  grid.moveCurrentIndexLeft(); break
                case Qt.Key_Down:  grid.moveCurrentIndexDown(); break
                case Qt.Key_Up:    grid.moveCurrentIndexUp(); break
                case Qt.Key_Tab:   grid.currentIndex = (grid.currentIndex + 1) % Math.max(1, root.wins.length); break
                case Qt.Key_Return:
                case Qt.Key_Enter: root.focusWindow(root.wins[grid.currentIndex]); break
                default: return
                }
                event.accepted = true
            }
        }
    }

    GridView {
        id: grid
        x: 22
        y: pill.y + pill.height + 16
        width: root.cols * root.tileW
        height: root.shownRows * root.tileH
        clip: true
        model: root.wins
        cellWidth: root.tileW
        cellHeight: root.tileH
        highlightMoveDuration: 90
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            width: root.tileW
            height: root.tileH
            readonly property bool cur: GridView.isCurrentItem

            Rectangle {   // preview frame
                id: frame
                x: 10; y: 8
                width: parent.width - 20
                height: (width) * 10 / 16
                radius: 14
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: tile.cur ? 2 : 1
                border.color: Qt.rgba(1, 1, 1, tile.cur ? 0.9 : 0.2)
                clip: true

                // The capture only exists while the switcher is open. A window
                // capture that outlives its window crashes Quickshell ("invalid
                // object") when that window closes, taking every panel with it.
                Loader {
                    id: shot
                    anchors.fill: parent
                    anchors.margins: 3
                    active: root.visible
                    readonly property bool hasContent: item !== null && item.hasContent
                    sourceComponent: ScreencopyView {
                        captureSource: tile.modelData.wayland
                        live: true
                        paintCursor: false
                        constraintSize: Qt.size(width, height)
                    }
                }
                IconImage {   // until (or if) the capture has a frame
                    visible: !shot.hasContent
                    anchors.centerIn: parent
                    implicitSize: 56
                    source: Quickshell.iconPath(root.appOf(tile.modelData), "application-x-executable")
                }
            }

            Row {
                x: 12
                y: frame.y + frame.height + 8
                spacing: 8
                IconImage {
                    implicitSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                    source: Quickshell.iconPath(root.appOf(tile.modelData), "application-x-executable")
                }
                GlassText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: tile.width - 90
                    elide: Text.ElideRight
                    text: tile.modelData.title || root.appOf(tile.modelData)
                    size: 12
                }
            }
            GlassText {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: frame.y + frame.height + 10
                text: "ws " + root.wsOf(tile.modelData)
                size: 10
                color: Qt.rgba(1, 1, 1, 0.55)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = tile.index
                onClicked: root.focusWindow(tile.modelData)
            }
        }
    }

    GlassText {
        visible: root.wins.length === 0
        anchors.centerIn: grid
        text: search.text ? "No window matches “" + search.text + "”" : "No open windows"
        color: Qt.rgba(1, 1, 1, 0.6)
        size: 14
    }
}
