import QtQuick

// The island's clear-water glass (shaders/water.frag): one clear surface with
// a thin refracting meniscus and a sheen along the top. Same placement
// contract as shared/Glass.qml: `pad` px larger than the shape on every side,
// `source` is the live capture, `sourceOrigin` this item's top-left in it.
ShaderEffect {
    id: glass

    property var source
    property point sourceOrigin: Qt.point(0, 0)
    property size sourceSize: Qt.size(1, 1)
    property var lumTex: source          // GlassLum.texture
    property real useLum: 0

    property real pad: 10
    property real radius: 999
    property real edgeW: 3.5
    property real smoke: 0               // minimum smoke, for text-heavy surfaces
    property real shadow: 0.06
    Behavior on smoke { NumberAnimation { duration: 180 } }

    // sea tint (see Theme.qml): color + strength 0..1, 0 = clear water
    property color tintColor: "#64859F"
    property real tintStrength: 0
    readonly property vector4d tint: Qt.vector4d(tintColor.r, tintColor.g, tintColor.b, tintStrength)
    // tint colour toward the bottom-right (default: same as tintColor) and how
    // much the tint deepens toward the bottom (1 = water, 0 = flat colour)
    property color tintColor2: tintColor
    property real tintShade: 1
    readonly property vector4d tint2: Qt.vector4d(tintColor2.r, tintColor2.g, tintColor2.b, tintShade)

    property real darkLift: Theme.mocha ? 0 : 1   // milky lift over dark backdrops (off for dark glass)

    // drifting light; runs only while drawn. animate: false freezes it, so a
    // still surface costs no redraws at all (the island rests on screen a lot).
    property bool animate: true
    property real time: 0
    FrameAnimation {
        running: glass.animate && glass.visible && glass.opacity > 0
        onTriggered: glass.time += frameTime
    }

    // uniforms (names must match the shader's buffer)
    readonly property size itemSize: Qt.size(width, height)
    readonly property point itemPos: sourceOrigin
    readonly property size srcSize: sourceSize

    fragmentShader: Qt.resolvedUrl("shaders/water.frag.qsb")
}
