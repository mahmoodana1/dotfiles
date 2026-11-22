import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Sound: output and input side by side (volume + pick the device), and a
// volume slider for every app playing or recording.
Item {
    id: s
    property var ctl
    property bool active: false
    readonly property real pad: 22


    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream)
    PwObjectTracker { objects: s.active ? s.nodes : [] }

    function nodeName(n) { return n.nickname || n.description || n.name || "Device" }
    function appName(n) {
        const p = n.properties || {}
        return p["application.name"] || n.description || n.name || "App"
    }
    function appWhat(n) { const p = n.properties || {}; return p["media.name"] || "" }

    TabHead {
        id: head
        x: s.pad; y: 18; width: s.width - s.pad * 2
        title: "Sound"; hasBusy: false
        sub: s.streams.length ? s.streams.length + (s.streams.length === 1 ? " app" : " apps") + " using audio" : "Nothing playing"
    }

    Row {
        id: devs
        x: s.pad; y: head.y + head.height + 14
        spacing: 12
        readonly property real cw: (s.width - s.pad * 2 - 12) / 2
        Side { title: "Output"; node: s.ctl.sink; list: s.sinks; isOut: true }
        Side { title: "Input"; node: s.ctl.source; list: s.sources; isOut: false }
    }

    Card {
        x: s.pad; y: devs.y + devs.height + 12
        width: s.width - s.pad * 2; height: s.height - y - 20
        title: "Apps"
        Txt { visible: s.streams.length === 0; anchors.centerIn: parent; text: "No app is using audio"; size: 11; color: Look.faint }
        ListView {
            id: appList
            anchors.fill: parent
            cacheBuffer: 100000
            clip: true; spacing: 10
            boundsBehavior: Flickable.StopAtBounds
            model: s.streams
            delegate: Item {
                required property var modelData
                readonly property var a: modelData.audio
                width: ListView.view.width; height: 44
                Txt { y: 0; width: 210; text: s.appName(modelData); size: 12; bold: true }
                Txt { y: 17; width: 210; text: (modelData.isSink ? "● recording" : "▶ playing") + (s.appWhat(modelData) ? "  ·  " + s.appWhat(modelData) : ""); size: 10; color: Look.dim }
                Slider {
                    x: 222; width: parent.width - 222; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    value: parent.a ? parent.a.volume : 0
                    muted: !parent.a || parent.a.muted
                    icon: Glyphs.volume(value, muted)
                    label: muted ? "muted" : Math.round(value * 100) + "%"
                    onMoved: v => { if (parent.a) { parent.a.muted = false; parent.a.volume = v } }
                    onIconClicked: if (parent.a) parent.a.muted = !parent.a.muted
                }
            }
        }
    }

    // Output / Input: slider for the default device, then the devices to pick from.
    component Side: Card {
        id: side
        property var node
        property var list: []
        property bool isOut: true
        readonly property var a: node ? node.audio : null
        width: devs.cw
        height: Math.min(236, bodyY + 44 + list.length * 34 + inset)
        trailing: list.length + (list.length === 1 ? " device" : " devices")
        Slider {
            width: parent.width
            value: side.a ? side.a.volume : 0
            muted: !side.a || side.a.muted
            icon: side.isOut ? Glyphs.volume(value, muted) : Glyphs.mic(muted)
            label: muted ? "muted" : Math.round(value * 100) + "%"
            onMoved: v => { if (side.a) { side.a.muted = false; side.a.volume = v } }
            onIconClicked: if (side.a) side.a.muted = !side.a.muted
        }
        ListView {
            y: 44; width: parent.width; height: parent.height - 44
            clip: true; spacing: 2
            cacheBuffer: 100000
            boundsBehavior: Flickable.StopAtBounds
            model: side.list
            delegate: Press {
                required property var modelData
                readonly property bool cur: modelData === side.node
                width: ListView.view.width; height: 32; radius: 10
                flat: true; on: cur
                onClicked: {
                    if (side.isOut) Pipewire.preferredDefaultAudioSink = modelData
                    else Pipewire.preferredDefaultAudioSource = modelData
                }
                Rectangle {                 // radio
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: "transparent"; border.width: 2
                    border.color: parent.cur ? Look.accent2 : Look.faint
                    Rectangle { visible: parent.parent.cur; anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Look.accent2 }
                }
                Txt { x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; text: s.nodeName(modelData); size: 11; bold: parent.cur; color: parent.cur ? Look.text : Look.dim }
            }
        }
    }
}
