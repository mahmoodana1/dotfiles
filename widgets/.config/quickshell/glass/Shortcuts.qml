import QtQuick
import Quickshell
import Quickshell.Io
import "shared"
import "common/keys.js" as K
import "lib/match.js" as Match
import "lib/shortcuts.js" as Parser

// SUPER+H: ~/dotfiles/shortcuts.md as a browsable cheat sheet.
// Left: sections. Right: that section's shortcuts. Vim keys: j/k move,
// h/l switch pane, g/G ends, Ctrl+D/U page, / searches every section at once
// (Enter or Esc leaves the box, Esc again clears it), q closes.
// Edit shortcuts.md; this reloads.
FocusScope {
    id: root
    signal closeRequested()

    implicitWidth: 900
    implicitHeight: 600
    readonly property bool centered: true

    property var parsed: ({ sections: [], skipped: 0 })
    property int section: 0
    property bool listPane: false                       // j/k walk the rows, not the sections
    readonly property bool inList: query !== "" || listPane
    onSectionChanged: list.currentIndex = 0

    // vim keys: focus the scope itself. (root.forceActiveFocus() alone would
    // hand focus back to `search`, the scope's remembered focus child.)
    function normalMode() { search.focus = false; root.forceActiveFocus() }

    function opened(arg) {
        search.text = ""
        root.section = 0
        root.listPane = false
        list.currentIndex = 0
        normalMode()
    }
    function move(d) {
        if (inList) list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + d))
        else { const n = parsed.sections.length; if (n) section = (section + d + n) % n }
    }
    function jump(last) {
        if (inList) list.currentIndex = last ? Math.max(0, list.count - 1) : 0
        else section = last ? Math.max(0, parsed.sections.length - 1) : 0
    }

    Keys.onPressed: event => {
        const k = event.key
        const l = K.letter(event)
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        let done = true
        if (K.isClose(event)) root.closeRequested()
        else if (K.isEscape(event)) { if (root.query) search.text = ""; else root.closeRequested() }
        else if (ctrl && l === "d") list.currentIndex = Math.min(list.count - 1, list.currentIndex + 8)
        else if (ctrl && l === "u") list.currentIndex = Math.max(0, list.currentIndex - 8)
        else if (ctrl) done = false
        else if (l === "j" || k === Qt.Key_Down) move(1)
        else if (l === "k" || k === Qt.Key_Up) move(-1)
        else if (l === "g" || k === Qt.Key_Home) jump(false)
        else if (l === "G" || k === Qt.Key_End) jump(true)
        else if (l === "l" || k === Qt.Key_Right) root.listPane = true
        else if (l === "h" || k === Qt.Key_Left) root.listPane = false
        else if (k === Qt.Key_Slash || event.nativeScanCode === 61 || l === "i") search.forceActiveFocus()
        else if (l === "q") root.closeRequested()
        else done = false
        event.accepted = done
    }

    FileView {
        path: Quickshell.env("HOME") + "/dotfiles/shortcuts.md"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parsed = Parser.parse(text())
    }

    readonly property string query: search.text.trim()
    readonly property var rows: {
        if (!query) {
            const s = root.parsed.sections[section]
            return s ? s.rows : []
        }
        const out = []
        for (const s of root.parsed.sections)
            for (const r of s.rows) {
                const sc = Match.best(query, [[r.action, 1, true], [r.keys, 0.9], [s.title, 0.4, true]])
                if (sc >= 0) out.push({ r: r, sc: sc })
            }
        out.sort((a, b) => b.sc - a.sc)
        return out.map(x => x.r)
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

        MouseArea { anchors.fill: parent; onClicked: search.forceActiveFocus() }
        GlassText {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f030c}"            // keyboard
            size: 17
            color: Qt.rgba(1, 1, 1, 0.7)
        }
        TextInput {
            id: search
            x: 46
            width: parent.width - 62
            y: Math.round((parent.height - height) / 2)     // whole pixel: a half-pixel y blurs the glyphs
            color: "white"
            selectionColor: Qt.rgba(1, 1, 1, 0.3)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            onTextChanged: list.currentIndex = 0

            Text {
                visible: search.text === ""
                text: search.activeFocus ? "Search shortcuts" : "/ to search"
                color: Qt.rgba(1, 1, 1, 0.75)
                font: search.font
            }

            // insert mode: keys type; Esc / Ctrl+[ / Enter go back to the vim keys
            Keys.onPressed: event => {
                if (K.isClose(event)) root.closeRequested()
                else if (K.isEscape(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.normalMode()
                else if (event.key === Qt.Key_Up) root.move(-1)
                else if (event.key === Qt.Key_Down) root.move(1)
                else if (event.key === Qt.Key_PageDown) list.currentIndex = Math.min(list.count - 1, list.currentIndex + 8)
                else if (event.key === Qt.Key_PageUp) list.currentIndex = Math.max(0, list.currentIndex - 8)
                else return
                event.accepted = true
            }
        }
    }

    // ---- sections ------------------------------------------------------------
    ListView {
        id: sections
        x: 22
        y: pill.y + pill.height + 16
        width: 210
        height: parent.height - y - 36
        clip: true
        spacing: 2
        model: root.parsed.sections
        currentIndex: root.section
        opacity: root.query ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        highlight: Rectangle {
            radius: 12
            color: Qt.rgba(1, 1, 1, root.inList ? 0.08 : 0.16)
            border.color: Qt.rgba(1, 1, 1, root.inList ? 0.12 : 0.24)
        }
        delegate: Item {
            id: sec
            required property var modelData
            required property int index
            width: sections.width
            height: 34
            GlassText {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24
                elide: Text.ElideRight
                text: sec.modelData.title
                size: 13
                weight: sec.index === root.section ? Font.DemiBold : Font.Medium
                color: sec.index === root.section ? "white" : Qt.rgba(1, 1, 1, 0.7)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { search.text = ""; root.listPane = false; root.section = sec.index; root.normalMode() }
            }
        }
    }

    Rectangle {   // divider
        x: sections.x + sections.width + 12
        y: sections.y + 4
        width: 1
        height: sections.height - 8
        color: Qt.rgba(1, 1, 1, 0.12)
    }

    // ---- shortcuts -----------------------------------------------------------
    ListView {
        id: list
        x: sections.x + sections.width + 26
        y: sections.y
        width: parent.width - x - 22
        height: sections.height
        clip: true
        spacing: 2
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 90
        highlight: Rectangle {
            visible: root.inList
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        delegate: Item {
            id: row
            required property var modelData
            width: list.width
            height: Math.max(36, action.implicitHeight + 16)

            Row {
                id: keys
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: row.modelData.groups
                    delegate: Row {
                        id: grp
                        required property var modelData
                        required property int index
                        spacing: 4
                        GlassText {
                            visible: grp.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "/"
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }
                        Repeater {
                            model: grp.modelData
                            delegate: Rectangle {   // keycap
                                required property string modelData
                                width: cap.implicitWidth + 14
                                height: 24
                                radius: 7
                                color: Qt.rgba(0, 0, 0, 0.35)          // dark glass: white keys read on bright backdrops
                                border.color: Qt.rgba(1, 1, 1, 0.28)
                                GlassText {
                                    id: cap
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    size: 11
                                }
                            }
                        }
                    }
                }
            }

            GlassText {
                id: action
                x: Math.max(250, keys.width + 24)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (root.query ? 130 : 8)
                wrapMode: Text.WordWrap
                text: row.modelData.action
                size: 13
                weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.9)
            }
            GlassText {   // which section a search hit came from
                visible: root.query !== ""
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.section
                size: 10
                color: Qt.rgba(1, 1, 1, 0.45)
            }
        }
    }

    GlassText {
        visible: root.rows.length === 0
        anchors.centerIn: list
        text: root.query ? "Nothing matches “" + root.query + "”" : ""
        color: Qt.rgba(1, 1, 1, 0.6)
        size: 14
    }

    GlassText {   // footer
        x: 26
        y: parent.height - 26
        size: 10
        color: Qt.rgba(1, 1, 1, 0.45)
        text: "j/k move · h/l pane · g/G ends · ^d/^u page · / search all · q close · edit ~/dotfiles/shortcuts.md"
              + (root.parsed.skipped ? "   ·   " + root.parsed.skipped + " lines skipped" : "")
    }
}
