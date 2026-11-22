import QtQuick

// A soft container on the Center's surface; optional small caps title.
Rectangle {
    id: c
    property string title: ""
    property string trailing: ""            // small text at the title's right
    property bool navigable: false          // opt in: Enter then fires `activated`
    property bool focused: false
    signal activated()
    default property alias content: inner.data
    readonly property real inset: 14
    readonly property real bodyY: title !== "" ? 34 : inset
    radius: 16
    color: Look.alpha(Look.fg, 0.045)
    border.width: 1
    border.color: Look.alpha(Look.fg, 0.05)

    Txt {
        visible: c.title !== ""
        x: c.inset; y: 11
        text: c.title.toUpperCase(); size: 9; bold: true
        color: Look.faint
        font.letterSpacing: 1.2
    }
    Txt {
        visible: c.trailing !== ""
        anchors.right: parent.right; anchors.rightMargin: c.inset; y: 10
        text: c.trailing; size: 10; color: Look.dim
    }
    Item {
        id: inner
        x: c.inset; y: c.bodyY
        width: c.width - c.inset * 2
        height: c.height - c.bodyY - c.inset
    }
    // keyboard focus ring (vim keys in the Center)
    Rectangle {
        z: 10
        anchors.fill: parent             // inside the edge: rows clip their content
        radius: c.radius
        color: "transparent"
        border.width: 2; border.color: Look.accent2
        opacity: c.focused ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }
}
