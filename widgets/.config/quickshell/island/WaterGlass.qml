import QtQuick

// The island's clear-water glass (shaders/water.frag): one clear surface with
// a thin refracting meniscus and slow drifting caustic light. Same placement
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

    // drifting light; runs only while drawn
    property real time: 0
    FrameAnimation {
        running: glass.visible && glass.opacity > 0
        onTriggered: glass.time += frameTime
    }

    // uniforms (names must match the shader's buffer)
    readonly property size itemSize: Qt.size(width, height)
    readonly property point itemPos: sourceOrigin
    readonly property size srcSize: sourceSize

    fragmentShader: Qt.resolvedUrl("shaders/water.frag.qsb")
}
