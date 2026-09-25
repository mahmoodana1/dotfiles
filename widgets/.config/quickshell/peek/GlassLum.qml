import QtQuick

// Smoothed backdrop brightness for one glass capsule, as a 1x1 texture
// (`texture`) for Glass { lumTex; useLum: 1 }. Feedback loop: the effect
// reads its own previous output and eases toward the new measurement.
// Snaps to the current value whenever it becomes visible, so a freshly shown
// island never fades from a stale tint.
Item {
    id: root

    property var source                 // texture provider of the screen behind
    property rect shape                 // capsule rect in source px
    property size srcSize: Qt.size(1, 1)
    property real margin: 13            // pad + a little: outside the shadow
    property real tau: 0.12             // seconds; ~90% of a change in ~0.3 s, any refresh rate
    readonly property alias texture: lumSrc

    width: 1
    height: 1

    // time-based per-frame blend: k = 1 - e^(-dt/tau)
    property real k: 1
    FrameAnimation {
        running: root.visible
        onTriggered: root.k = root.snapping ? 1 : 1 - Math.exp(-Math.max(frameTime, 0.001) / root.tau)
    }

    property bool snapping: true
    onVisibleChanged: if (visible) { snapping = true; snapTimer.restart() }
    Timer { id: snapTimer; interval: 60; onTriggered: root.snapping = false }
    Component.onCompleted: snapTimer.restart()

    ShaderEffect {
        id: eff
        width: 1
        height: 1
        property var source: root.source
        property var prev: lumSrc
        property rect shape: root.shape
        property size srcSize: root.srcSize
        property real margin: root.margin
        property real k: root.k
        fragmentShader: Qt.resolvedUrl("shaders/lum.frag.qsb")
    }
    ShaderEffectSource {
        id: lumSrc
        sourceItem: eff
        recursive: true
        live: true
        hideSource: true
        textureSize: Qt.size(1, 1)
        width: 1
        height: 1
        visible: false
    }
}
