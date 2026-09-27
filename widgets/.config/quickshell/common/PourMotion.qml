import QtQuick

// Panels pop in: the card sits at its final size and place and fades in
// while scaling up a little from its top edge; closing fades and shrinks it
// back. Nothing changes shape mid-way, so it stays crisp and cheap to draw.
// Drive it with open()/close(); give the card `cardScale` (transformOrigin:
// Item.Top) as scale and `cardOpacity` as opacity, and read `rect`/`radius` for its geometry.
Item {
    id: m
    visible: false

    // tune here
    property int openMs: 160
    property int closeMs: 110
    property real fromScale: 0.94           // how small it starts (1 = no scale)

    property rect mother: Qt.rect(0, 0, 0, 0)   // unused now (the island's rect)
    property rect to: Qt.rect(0, 0, 100, 100)
    property real toRadius: 26

    property real t: 0                      // 0 closed .. 1 open (eased)
    readonly property bool running: openAnim.running || closeAnim.running
    signal closed()

    function open() { closeAnim.stop(); openAnim.restart() }
    function close() { openAnim.stop(); closeAnim.restart() }
    function snapOpen() { closeAnim.stop(); openAnim.stop(); t = 1 }

    readonly property rect rect: to
    readonly property real radius: toRadius
    readonly property real budK: 0
    readonly property real cardScale: fromScale + (1 - fromScale) * t
    readonly property real cardOpacity: Math.min(1, t * 1.6)
    readonly property real contentOpacity: 1

    NumberAnimation { id: openAnim; target: m; property: "t"; to: 1; duration: m.openMs; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: m; property: "t"; to: 0; duration: m.closeMs; easing.type: Easing.InCubic }
        ScriptAction { script: m.closed() }
    }
}
