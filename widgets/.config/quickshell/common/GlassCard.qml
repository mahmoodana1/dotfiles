import QtQuick
import "../shared"   // each config links shared -> ../peek

// A sea-tinted water-glass card. Put content inside it like any Item.
// Placement contract: the card's parent covers the whole capture (window
// coordinates), `source` is the live screen capture and `srcSize` its size.
Item {
    id: card

    property var source
    property size srcSize: Qt.size(1, 1)
    property real radius: 26
    property real pad: 26                  // room for the drop shadow
    property real tint: Theme.panelTint
    property real smoke: Theme.panelShade   // darker glass so text reads, like the island
    default property alias content: inner.data

    // call after a new backdrop capture so the tint re-reads the brightness
    function refresh() { lum.kick() }

    GlassLum {
        id: lum
        alwaysRun: false
        source: card.source
        shape: Qt.rect(card.x, card.y, card.width, card.height)
        srcSize: card.srcSize
        margin: card.pad + 3            // sample just outside the shadow
    }

    WaterGlass {
        animate: false                        // still glass (no waves): no per-frame redraws
        lumTex: lum.texture
        useLum: 1
        radius: card.radius
        smoke: card.smoke
        tintColor: Theme.panelTintColor
        tintColor2: Theme.panelTintColor2
        tintShade: Theme.tintShade
        tintStrength: card.tint
        edgeW: 6
        shadow: Theme.panelShadow
        x: -card.pad; y: -card.pad
        width: card.width + card.pad * 2
        height: card.height + card.pad * 2
        source: card.source
        sourceOrigin: Qt.point(card.x - card.pad, card.y - card.pad)
        sourceSize: card.srcSize
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
