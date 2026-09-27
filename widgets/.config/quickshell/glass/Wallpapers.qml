import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "shared"

// SUPER+W: wallpaper carousel. The centred one previews full-screen behind
// the glass; Enter applies it. Effect chips underneath (SUPER+SHIFT+W opens
// with them focused): Enter applies the effect to the current wallpaper.
// All the work is done by hypr/scripts/wallpaper.sh.
FocusScope {
    id: root
    signal closeRequested()

    implicitWidth: 1040
    implicitHeight: 370
    readonly property bool centered: false

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh"
    property var walls: []                 // [{ path, thumb, name }]
    property var effects: []
    property bool chipsFocused: false
    property string current: ""            // what awww shows now

    readonly property var selected: walls[carousel.currentIndex] || null

    function opened(arg) {
        chipsFocused = arg === "effects"
        lister.running = true
        currentQuery.running = true
        effectLister.running = true
        keys.forceActiveFocus()
    }

    // ---- data from wallpaper.sh / awww ---------------------------------------
    Process {
        id: lister
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of this.text.split("\n")) {
                    if (!line) continue
                    const [path, thumb] = line.split("\t")
                    out.push({ path: path, thumb: thumb || path, name: path.split("/").pop() })
                }
                root.walls = out
                root.jumpToCurrent()
            }
        }
    }
    Process {
        id: effectLister
        command: [root.script, "effects"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "None" first, then the rest alphabetically (the script sorts them)
                const names = this.text.split("\n").filter(n => n && n !== "None")
                root.effects = ["None"].concat(names)
            }
        }
    }
    Process {
        id: currentQuery
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = this.text.match(/image: (.+)/)
                root.current = m ? m[1].trim() : ""
                root.jumpToCurrent()
            }
        }
    }
    function jumpToCurrent() {
        const i = walls.findIndex(w => w.path === current)
        if (i >= 0) carousel.positionViewAtIndex(i, ListView.Center), carousel.currentIndex = i
    }

    Process {
        id: runner
        onExited: (code) => { if (code !== 0) Quickshell.execDetached(["notify-send", "-u", "normal", "Wallpaper", "wallpaper.sh failed (exit " + code + ")"]) }
    }
    function apply() {
        if (!selected) return
        runner.command = [root.script, "set", selected.path]
        runner.running = true
        root.closeRequested()
    }
    function applyEffect(name) {
        runner.command = [root.script, "effect", name]
        runner.running = true
    }

    // ---- full-screen preview under the glass ---------------------------------
    property Component backdrop: Item {
        Image {
            id: prev
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1920
            source: root.selected && !root.chipsFocused ? "file://" + root.selected.thumb : ""
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }

    // ---- keyboard --------------------------------------------------------------
    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Left:
                if (root.chipsFocused) chips.currentIndex = Math.max(0, chips.currentIndex - 1)
                else carousel.decrementCurrentIndex()
                break
            case Qt.Key_Right:
                if (root.chipsFocused) chips.currentIndex = Math.min(root.effects.length - 1, chips.currentIndex + 1)
                else carousel.incrementCurrentIndex()
                break
            case Qt.Key_Down:
            case Qt.Key_Tab:  root.chipsFocused = true; break
            case Qt.Key_Up:
            case Qt.Key_Backtab: root.chipsFocused = false; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.chipsFocused) root.applyEffect(root.effects[chips.currentIndex])
                else root.apply()
                break
            default: return
            }
            event.accepted = true
        }
    }

    // ---- carousel --------------------------------------------------------------
    readonly property real cardW: 300
    readonly property real cardH: 186

    ListView {
        id: carousel
        x: 0; y: 22
        width: parent.width
        height: root.cardH + 20
        orientation: ListView.Horizontal
        model: root.walls
        spacing: -24                        // side cards tuck under the centre one
        clip: true
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - root.cardW) / 2
        preferredHighlightEnd: (width + root.cardW) / 2
        highlightMoveDuration: 260
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            width: root.cardW
            height: carousel.height
            z: tile.ListView.isCurrentItem ? 10 : 10 - Math.abs(index - carousel.currentIndex)

            readonly property real dist: Math.min(2, Math.abs((x - carousel.contentX + width / 2) - carousel.width / 2) / root.cardW)
            scale: 1 - 0.2 * dist
            opacity: 1 - 0.3 * dist

            Item {
                id: frame
                anchors.centerIn: parent
                width: root.cardW - 20
                height: root.cardH

                Image {
                    id: img
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 560
                    source: "file://" + tile.modelData.thumb
                    visible: false
                }
                Rectangle { id: mask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }
                MultiEffect {
                    anchors.fill: parent
                    source: img
                    maskEnabled: true
                    maskSource: mask
                }
                Rectangle {   // rim: white on the selected one
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    border.width: tile.ListView.isCurrentItem && !root.chipsFocused ? 2 : 1
                    border.color: Qt.rgba(1, 1, 1, tile.ListView.isCurrentItem && !root.chipsFocused ? 0.9 : 0.25)
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.chipsFocused = false
                    if (tile.ListView.isCurrentItem) root.apply()
                    else carousel.currentIndex = tile.index
                }
            }
        }
    }

    GlassText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: carousel.y + carousel.height + 6
        text: root.selected ? root.selected.name + (root.selected.path === root.current ? "   · current" : "") : "No wallpapers in ~/Pictures/wallpapers"
        size: 13
        color: Qt.rgba(1, 1, 1, 0.85)
    }

    // ---- effect chips ------------------------------------------------------------
    Row {
        id: chipRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 64
        spacing: 8
        Repeater {
            id: chips
            property int currentIndex: 0
            model: root.effects
            delegate: Rectangle {
                id: chip
                required property string modelData
                required property int index
                readonly property bool on: root.chipsFocused && chips.currentIndex === index
                width: label.implicitWidth + 26
                height: 32
                radius: 16
                color: Qt.rgba(1, 1, 1, on ? 0.30 : 0.10)
                border.color: Qt.rgba(1, 1, 1, on ? 0.6 : 0.18)
                Behavior on color { ColorAnimation { duration: 120 } }
                GlassText {
                    id: label
                    anchors.centerIn: parent
                    text: chip.modelData
                    size: 12
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.chipsFocused = true; chips.currentIndex = chip.index; root.applyEffect(chip.modelData) }
                }
            }
        }
    }

    GlassText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 24
        size: 10
        color: Qt.rgba(1, 1, 1, 0.45)
        text: root.chipsFocused ? "←→ effect · Enter apply to current · ↑ back to wallpapers"
                                : "←→ browse · Enter apply · ↓ effects"
    }
}
