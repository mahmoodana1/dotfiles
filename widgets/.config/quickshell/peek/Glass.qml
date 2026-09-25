import QtQuick

// A liquid-glass capsule drawn by shaders/glass.frag.
// `source` is a texture provider (ShaderEffectSource) holding what lies
// behind; `sourceOrigin` is where this item's top-left sits in that texture.
// The item is `pad` px larger than the visible shape on every side, for the
// shadow, so place it with x/y offset by -pad.
ShaderEffect {
    id: glass

    property var source
    property point sourceOrigin: Qt.point(0, 0)
    property size sourceSize: Qt.size(1, 1)

    property real pad: 10
    property real radius: 999
    property real bezel: 10
    property real refraction: 8
    property real magnify: 1.0
    property real blurPx: 0
    property real tint: 0.07       // island: interior tint opacity; lens: whitening
    property real shadow: 0.10
    property real mode: 0          // 0 island (clear, live refracted rim), 1 lens

    // uniforms (names must match the shader's buffer)
    readonly property size itemSize: Qt.size(width, height)
    readonly property point itemPos: sourceOrigin
    readonly property size srcSize: sourceSize

    fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
}
