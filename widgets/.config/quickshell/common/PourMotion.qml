import QtQuick

// "Pours from the top": a drop at the top edge springs down into the target
// rect like a bubble (overshoots, wobbles once, settles); closing snaps it
// back up. Height and width spring out of phase, which gives the jelly squish.
// Drive it with open()/close(); read `rect` (current geometry) and `contentOpacity`.
Item {
    id: m
    visible: false

    // tune here
    property int openMs: 260
    property int closeMs: 120
    property real bounce: 1.0               // wobble amount: 0 = none, 1 = bubbly, 1.5 = very
    property real dropWidth: 140
    property real dropHeight: 34
    property real dropRadius: 17

    property rect from: Qt.rect(0, 6, dropWidth, dropHeight)   // set to the top-centre drop
    property rect to: Qt.rect(0, 0, 100, 100)
    property real toRadius: 26

    property real t: 0                      // 0 closed .. 1 open (linear timeline)
    readonly property bool running: openAnim.running || closeAnim.running
    signal closed()

    function open() { closeAnim.stop(); openAnim.restart() }
    function close() { openAnim.stop(); closeAnim.restart() }
    function snapOpen() { closeAnim.stop(); openAnim.stop(); t = 1 }

    // curves
    function outCubic(x) { return 1 - Math.pow(1 - x, 3) }
    function inOutCubic(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }
    // damped spring: overshoots ~12%, dips back ~2%, lands exactly on 1 at x = 1
    function spring(x, freq) {
        if (x >= 1) return 1
        const k = 1 - Math.exp(-6 * x) * Math.cos(freq * x)
        return 1 + (k - 1 + Math.exp(-6) * Math.cos(freq) * x) * bounce + (1 - bounce) * (outCubic(x) - 1)
    }
    function lerp(a, b, k) { return a + (b - a) * k }

    readonly property real kw: spring(t, 8)      // width lags a little behind height
    readonly property real kh: spring(t, 10)
    readonly property real ky: outCubic(t)
    readonly property rect rect: Qt.rect(
        lerp(from.x + from.width / 2, to.x + to.width / 2, ky) - lerp(from.width, to.width, kw) / 2,
        lerp(from.y, to.y, ky),
        lerp(from.width, to.width, kw),
        Math.max(1, lerp(from.height, to.height, kh)))
    readonly property real radius: lerp(dropRadius, toRadius, Math.min(1, t * 1.5))
    readonly property real contentOpacity: Math.max(0, Math.min(1, (t - 0.2) * 3))

    NumberAnimation { id: openAnim; target: m; property: "t"; to: 1; duration: m.openMs }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: m; property: "t"; to: 0; duration: m.closeMs; easing.type: Easing.InQuad }
        ScriptAction { script: m.closed() }
    }
}
