import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "shared"
import "lib/match.js" as Match

// SUPER+D: app list, names only (the selected row also shows its icon).
// Most-launched first; typing fuzzy-filters by name, generic name, keywords and
// description. Up/Down or Ctrl+J/K move, Enter launches.
FocusScope {
    id: root
    signal closeRequested()

    implicitWidth: 520
    implicitHeight: 540
    readonly property bool centered: true

    property var counts: ({})

    function opened(arg) {
        search.text = ""
        grid.currentIndex = 0
        grid.positionViewAtBeginning()
        search.forceActiveFocus()
    }

    FileView {
        id: countsFile
        path: Quickshell.env("HOME") + "/.local/state/glass/launches.json"
        printErrors: false
        onLoaded: { try { root.counts = JSON.parse(text()) } catch (e) { root.counts = {} } }
    }

    readonly property var apps: {
        const q = search.text.trim()
        const c = root.counts
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            const s = Match.best(q, [[e.name, 1], [e.genericName || "", 0.7, true], [e.keywords || [], 0.8, true], [e.comment || "", 0.5, true]])
            if (s >= 0) out.push({ e: e, s: s, n: c[e.id] || 0 })
        }
        out.sort((a, b) => (q ? b.s - a.s : 0) || b.n - a.n || a.e.name.localeCompare(b.e.name))
        return out.map(x => x.e)
    }

    function launch(entry) {
        if (!entry) return
        const c = root.counts
        c[entry.id] = (c[entry.id] || 0) + 1
        root.counts = c
        countsFile.setText(JSON.stringify(c))
        // Apps go to the NVIDIA card (hypr/lua/env.lua); this shell itself runs
        // on Intel, so switch offload back on for what it launches.
        let cmd = Array.prototype.slice.call(entry.command)
        if (entry.runInTerminal) cmd = [Quickshell.env("TERMINAL") || "alacritty", "-e"].concat(cmd)
        // (list form: the {command, workingDirectory} form of execDetached does nothing here)
        Quickshell.execDetached(["env", "-C", entry.workingDirectory || Quickshell.env("HOME"),
                                 "__NV_PRIME_RENDER_OFFLOAD=1"].concat(cmd))
        root.closeRequested()
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
            text: "\u{f0349}"            // magnify
            size: 17
            color: Qt.rgba(1, 1, 1, 0.7)
        }
        TextInput {
            id: search
            x: 44
            width: parent.width - 60
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            selectionColor: Qt.rgba(1, 1, 1, 0.3)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            focus: true
            onTextChanged: grid.currentIndex = 0

            Text {
                visible: search.text === ""
                text: "Search apps"
                color: Qt.rgba(1, 1, 1, 0.75)
                font: search.font
            }

            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) { grid.incrementCurrentIndex(); event.accepted = true }
                    else if (event.key === Qt.Key_K) { grid.decrementCurrentIndex(); event.accepted = true }
                    if (event.accepted) return
                }
                switch (event.key) {
                case Qt.Key_Down:     grid.incrementCurrentIndex(); break
                case Qt.Key_Up:       grid.decrementCurrentIndex(); break
                case Qt.Key_PageDown: grid.currentIndex = Math.min(root.apps.length - 1, grid.currentIndex + 8); break
                case Qt.Key_PageUp:   grid.currentIndex = Math.max(0, grid.currentIndex - 8); break
                case Qt.Key_Return:
                case Qt.Key_Enter: root.launch(root.apps[grid.currentIndex]); break
                default: return
                }
                event.accepted = true
            }
        }
    }

    // ---- app list: names only, icon on the selected row ----------------------
    ListView {
        id: grid
        x: 22
        y: pill.y + pill.height + 14
        width: parent.width - 44
        height: parent.height - y - 18
        clip: true
        spacing: 2
        model: root.apps
        highlightMoveDuration: 90
        boundsBehavior: Flickable.StopAtBounds

        highlight: Rectangle {
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.14)
            border.color: Qt.rgba(1, 1, 1, 0.26)
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: grid.width
            height: 38

            readonly property bool current: row.ListView.isCurrentItem

            IconImage {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 20
                visible: opacity > 0
                opacity: row.current ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 90 } }
                // only the selected row asks for its icon
                source: row.current ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
            }
            GlassText {
                x: row.current ? 44 : 16
                Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 16
                text: row.modelData.name
                size: 14
                weight: row.current ? Font.DemiBold : Font.Medium
                color: row.current ? "white" : Qt.rgba(1, 1, 1, 0.8)
                elide: Text.ElideRight
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = row.index
                onClicked: root.launch(row.modelData)
            }
        }
    }

    GlassText {
        visible: root.apps.length === 0
        anchors.centerIn: grid
        text: "No apps match “" + search.text + "”"
        color: Qt.rgba(1, 1, 1, 0.6)
        size: 14
    }
}
