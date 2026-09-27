import QtQuick
import QtQuick.Effects

// White label with a soft dark halo, so it reads on any wallpaper through
// glass, bright or dark. `halo` 0..1 sets how strong the halo is.
// Text is always drawn opaque: a translucent white passed as `color` comes
// out plain white (greys wash out on glass); real colours keep their hue.
Item {
    id: root
    property alias text: label.text
    property color color: "white"
    property real size: 12
    property int weight: Font.DemiBold
    property alias elide: label.elide     // set `width` too for eliding
    property alias horizontalAlignment: label.horizontalAlignment
    property alias wrapMode: label.wrapMode
    property alias maximumLineCount: label.maximumLineCount
    property real halo: 0.85

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // Halo: a hidden black copy of the text, blurred into a soft shadow.
    // The real text is drawn crisply on top, never through the effect
    // (resampling through an effect makes glyphs blurry).
    Text {
        id: haloSrc
        width: label.width
        visible: false
        text: label.text
        font: label.font
        elide: label.elide
        horizontalAlignment: label.horizontalAlignment
        wrapMode: label.wrapMode
        maximumLineCount: label.maximumLineCount
        renderType: Text.NativeRendering
        color: "black"
    }
    MultiEffect {
        source: haloSrc
        anchors.fill: haloSrc
        opacity: root.halo
        shadowEnabled: true
        shadowColor: "black"
        shadowBlur: 0.45                  // soft halo around each glyph, not a hard outline
        blurMax: 10
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0.5
        // no shadowScale: it scales from the item's centre, so on wide text
        // (launcher rows) the halo drifts sideways into a ghost letter
    }
    Text {
        id: label
        width: root.width
        // Native (hinted) rendering: stems snap to whole pixels, so small labels
        // are crisp. (Curve rendering looked thin and grainy at 11-12 px.)
        renderType: Text.NativeRendering
        color: Qt.rgba(root.color.r, root.color.g, root.color.b, 1)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.size
        font.weight: Math.max(root.weight, TextStyle.minWeight)
        font.hintingPreference: Font.PreferFullHinting
    }
}
