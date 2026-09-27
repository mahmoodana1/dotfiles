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

    // Cell division: while budK > 0 the glass reaches up to `bud` (the
    // island's rect, in the same coordinates as the card) with a neck that
    // thins and pinches off as budK falls to 0. The island itself isn't drawn.
    property rect bud: Qt.rect(0, 0, 0, 0)
    property real budK: 0
    property real budR: 18
    readonly property bool budding: budK > 0 && bud.width > 0
    // the glass item covers the card and, while budding, the island too
    readonly property real gx0: (budding ? Math.min(x, bud.x) : x) - pad
    readonly property real gy0: (budding ? Math.min(y, bud.y) : y) - pad
    readonly property real gx1: (budding ? Math.max(x + width, bud.x + bud.width) : x + width) + pad
    readonly property real gy1: (budding ? Math.max(y + height, bud.y + bud.height) : y + height) + pad

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
        x: card.gx0 - card.x; y: card.gy0 - card.y
        width: card.gx1 - card.gx0
        height: card.gy1 - card.gy0
        box: Qt.rect(card.x - card.gx0, card.y - card.gy0, card.width, card.height)
        bud: Qt.rect(card.bud.x - card.gx0, card.bud.y - card.gy0, card.bud.width, card.bud.height)
        budK: card.budding ? card.budK : 0
        budR: card.budR
        source: card.source
        sourceOrigin: Qt.point(card.gx0, card.gy0)
        sourceSize: card.srcSize
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
