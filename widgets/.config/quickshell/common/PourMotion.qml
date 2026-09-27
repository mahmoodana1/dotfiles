import QtQuick

// Panels pour out of the Dynamic Island: the card grows straight out of the
// island's bottom edge and springs into place (width and height out of
// phase: a jelly squish), joined to the island by a gooey neck that snaps
// early on. Closing runs it backwards and the card is sucked back in.
// While the island is hidden, `mother` is a strip just above the screen
// (IslandSpot), so panels pour from the bezel.
// Drive it with open()/close(); read `rect`, `radius`, `budK` (neck reach,
// for GlassCard / WaterGlass) and `contentOpacity`.
Item {
    id: m
    visible: false

    // tune here
    property int openMs: 220
    property int closeMs: 150
    property real bounce: 1.0               // wobble amount: 0 = none, 1 = bubbly, 1.5 = very
    property real neckReach: 40             // px, how far the neck stretches before it snaps

    property rect mother: Qt.rect(0, 0, 0, 0)   // the island (or the bezel strip)
    property rect to: Qt.rect(0, 0, 100, 100)
    property real toRadius: 26

    // the card starts as a lip tucked under the island's bottom edge
    readonly property real lipW: Math.min(Math.max(40, mother.width * 0.55), to.width)
    readonly property rect from: Qt.rect(mother.x + (mother.width - lipW) / 2,
                                         mother.y + mother.height - 14, lipW, 22)

    property real t: 0                      // 0 closed .. 1 open (linear timeline)
    readonly property bool running: openAnim.running || closeAnim.running
    signal closed()

    function open() { closeAnim.stop(); openAnim.restart() }
    function close() { openAnim.stop(); closeAnim.restart() }
    function snapOpen() { closeAnim.stop(); openAnim.stop(); t = 1 }

    // curves
    function clamp01(x) { return Math.max(0, Math.min(1, x)) }
    function smooth(x) { return x * x * (3 - 2 * x) }
    function outCubic(x) { return 1 - Math.pow(1 - x, 3) }
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
    readonly property real radius: lerp(11, toRadius, clamp01(t * 2))

    // the neck: full reach at the start, snapped by 45% of the way
    readonly property real budK: mother.width > 0 ? neckReach * (1 - smooth(clamp01((t - 0.08) / 0.37))) : 0
    readonly property real contentOpacity: clamp01((t - 0.25) * 3)

    NumberAnimation { id: openAnim; target: m; property: "t"; to: 1; duration: m.openMs }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: m; property: "t"; to: 0; duration: m.closeMs; easing.type: Easing.InQuad }
        ScriptAction { script: m.closed() }
    }
}
