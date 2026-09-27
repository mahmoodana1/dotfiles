import QtQuick
import Quickshell
import Quickshell.Io

// Where the Dynamic Island sits on one monitor (monitor coordinates), for
// panels that bud off it. The island publishes it to
// $XDG_RUNTIME_DIR/island-<monitor>.json (island/DynIsland.qml). While the
// island is hidden (or not running), `rect` is a strip just above the top
// edge, so panels bud off the bezel instead.
Item {
    id: spot
    visible: false

    property string monitorName: ""
    property real screenWidth: 1920

    property var data: null
    readonly property bool shown: data !== null && data.shown === true
    readonly property rect rect: shown ? Qt.rect(data.x, data.y, data.w, data.h)
                                       : Qt.rect(screenWidth / 2 - 90, -40, 180, 40)
    readonly property real radius: shown ? data.r : 0

    FileView {
        path: spot.monitorName === "" ? ""
            : Quickshell.env("XDG_RUNTIME_DIR") + "/island-" + spot.monitorName + ".json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { spot.data = JSON.parse(text()) } catch (e) { } }
        onLoadFailed: spot.data = null
    }
}
