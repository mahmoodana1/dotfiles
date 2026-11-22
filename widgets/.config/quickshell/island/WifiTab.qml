import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi: the connected network as a card (band, link rate, signal, IP, live
// traffic graph, auto-connect), then every other network. Tap one to join;
// secured new ones ask for the password right in their row. ⋯ on a saved
// one: Forget. Scans while showing; ↻ pauses.
Item {
    id: w
    property var ctl
    property bool active: false
    readonly property var st: ctl.stats

    readonly property real pad: 22
    readonly property bool typing: pwdFor !== ""

    readonly property var dev: ctl.wifiDev
    readonly property var cur: ctl.wifiNet
    readonly property var others: !dev ? [] : dev.networks.values
        .filter(n => n.name && !n.connected)
        .sort((a, b) => (b.known - a.known) || (b.signalStrength - a.signalStrength))
    property string pwdFor: ""
    property string menuFor: ""
    property bool scanning: true
    readonly property bool wantScan: active && scanning && Networking.wifiEnabled
    onWantScanChanged: if (dev) dev.scannerEnabled = wantScan
    onActiveChanged: { pwdFor = ""; menuFor = ""; if (active) { scanning = true; readAuto() } }
    onCurChanged: readAuto()

    function isOpen(n) { return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe }
    function tapped(n) {
        menuFor = ""
        if (n.known || isOpen(n)) { pwdFor = ""; n.connect() }
        else pwdFor = pwdFor === n.name ? "" : n.name
    }

    // per-network auto-connect lives in NetworkManager's profile (nmcli)
    property bool auto: true
    Process {
        id: autoRead
        command: ["nmcli", "-g", "connection.autoconnect", "connection", "show", "id", w.cur ? w.cur.name : ""]
        stdout: StdioCollector { onStreamFinished: w.auto = this.text.trim() !== "no" }
    }
    function readAuto() { if (cur && active) autoRead.running = true }
    function setAuto(on) {
        auto = on
        Quickshell.execDetached(["nmcli", "connection", "modify", "id", cur.name, "connection.autoconnect", on ? "yes" : "no"])
    }

    // ---- header ----
    TabHead {
        id: head
        x: w.pad; y: 18; width: w.width - w.pad * 2
        title: "Wi-Fi"
        sub: !Networking.wifiEnabled ? "Off" : (w.others.length + (w.cur ? 1 : 0)) + " networks nearby"
        busy: w.wantScan
        onBusyClicked: w.scanning = !w.scanning
        Switch { checked: Networking.wifiEnabled; onToggled: on => Networking.wifiEnabled = on }
    }

    // ---- connected ----
    Card {
        id: now
        visible: w.cur !== null && Networking.wifiEnabled
        x: w.pad; y: head.y + head.height + 14
        width: w.width - w.pad * 2; height: visible ? 132 : 0
        Rectangle {
            width: 46; height: 46; radius: 23
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Look.accent }
                GradientStop { position: 1; color: Look.accent2 }
            }
            Txt { anchors.centerIn: parent; text: w.cur ? Glyphs.wifi(w.cur.signalStrength) : ""; size: 20; color: Look.onAccent }
        }
        Column {
            x: 60; spacing: 3
            Txt { text: w.cur ? w.cur.name : ""; size: 16; bold: true }
            Txt {
                text: ["Connected", w.st.band, w.st.bitrate, w.st.dbm ? w.st.dbm + " dBm" : ""].filter(x => x).join("  ·  ")
                size: 11; color: Look.accent2
            }
            Txt { text: w.st.ip ? "IP  " + w.st.ip : ""; size: 10; color: Look.dim }
        }
        Column {                            // live traffic
            anchors.right: parent.right; y: 0
            width: 190; spacing: 4
            Row {
                anchors.right: parent.right; spacing: 12
                Txt { text: "\u{f0045} " + w.st.rate(w.st.rx); size: 11; bold: true }
                Txt { text: "\u{f005d} " + w.st.rate(w.st.tx); size: 11; color: Look.dim }
            }
            Graph { width: parent.width; height: 34; values: w.st.rxHist; values2: w.st.txHist }
        }
        Row {
            y: 62; spacing: 8
            Chip { text: "Disconnect"; onClicked: w.cur.disconnect() }
            Chip { text: "Forget"; onClicked: w.cur.forget() }
            Item { width: 12; height: 1 }
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Auto-connect"; size: 11; color: Look.dim }
            Switch { anchors.verticalCenter: parent.verticalCenter; checked: w.auto; onToggled: on => w.setAuto(on) }
        }
    }

    // ---- others ----
    Card {
        id: list
        x: w.pad; y: (now.visible ? now.y + now.height : head.y + head.height) + 12
        width: w.width - w.pad * 2; height: w.height - y - 20
        title: Networking.wifiEnabled ? "Other networks" : ""
        Txt {
            visible: !Networking.wifiEnabled || w.others.length === 0
            anchors.centerIn: parent
            text: !Networking.wifiEnabled ? "Wi-Fi is off" : "Looking for networks…"
            size: 12; color: Look.dim
        }
        ListView {
            id: netList
            anchors.fill: parent
            cacheBuffer: 100000             // every row exists, so hjkl can reach it
            clip: true; spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Networking.wifiEnabled ? w.others : []
            delegate: Net {}
        }
    }

    component Net: Item {
        id: r
        required property var modelData
        readonly property var n: modelData
        readonly property bool pwd: w.pwdFor === n.name
        readonly property bool menu: w.menuFor === n.name
        width: ListView.view.width
        height: 40 + (pwd || menu ? 42 : 0)
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        clip: true

        Press {
            id: netPress
            width: parent.width; height: 40; radius: 12
            flat: true; on: r.pwd || r.menu
            function remove() { if (r.n.known) { w.menuFor = ""; r.n.forget() } }
            onClicked: w.tapped(r.n)
            Txt { x: 10; anchors.verticalCenter: parent.verticalCenter; text: Glyphs.wifi(r.n.signalStrength); size: 15; color: Look.dim }
            Txt { x: 38; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 200; text: r.n.name; size: 12; bold: r.n.known }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Txt { visible: r.n.stateChanging; text: "connecting…"; size: 10; color: Look.accent2 }
                Txt { visible: netPress.armed; text: "d again to forget"; size: 10; color: Look.accent2 }
                Txt { visible: r.n.known; text: "saved"; size: 10; color: Look.dim }
                Txt { text: w.isOpen(r.n) ? "open" : Glyphs.lock; size: 11; color: Look.faint }
                Txt {
                    visible: r.n.known
                    text: "\u{f01d8}"; size: 15; color: r.menu ? Look.text : Look.faint
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { w.pwdFor = ""; w.menuFor = r.menu ? "" : r.n.name } }
                }
            }
        }
        Rectangle {                         // password
            visible: r.pwd
            x: 38; y: 44; width: parent.width - 48; height: 34; radius: 12
            color: Look.well
            border.width: 1; border.color: Look.alpha(Look.accent, field.activeFocus ? 0.85 : 0.3)
            TextInput {
                id: field
                x: 12; width: parent.width - 100
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                color: Look.text; selectionColor: Look.accent
                font.family: Look.font; font.pixelSize: 12
                clip: true
                Keys.onReturnPressed: join()
                Keys.onEscapePressed: { w.pwdFor = ""; event.accepted = true }
                function join() { if (text.length) { r.n.connectWithPsk(text); w.pwdFor = "" } }
            }
            Txt { x: 12; anchors.verticalCenter: parent.verticalCenter; visible: field.text === ""; text: "Password"; size: 12; color: Look.faint }
            Chip { anchors.right: parent.right; anchors.rightMargin: 3; anchors.verticalCenter: parent.verticalCenter; height: 28; text: "Join"; accent: true; onClicked: field.join() }
        }
        onPwdChanged: if (pwd) field.forceActiveFocus()
        Row {                               // saved network's menu
            visible: r.menu
            x: 38; y: 46; spacing: 8
            Chip { text: "Connect"; accent: true; onClicked: { w.menuFor = ""; r.n.connect() } }
            Chip { text: "Forget"; onClicked: { w.menuFor = ""; r.n.forget() } }
        }
    }
}
