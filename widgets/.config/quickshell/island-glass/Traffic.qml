import QtQuick
import "shared"

// "Traffic" block for the floating panels: ↓ Receiving / ↑ Sending bars.
// Feed it byte counters (rx / tx totals); call sample() after each update.
// Bars scale against a slowly decaying recent peak so small flows still move.
Column {
    id: tr
    property real rx: -1
    property real tx: -1
    property string note: ""             // small caption under the title

    property real rxRate: 0
    property real txRate: 0
    property real peak: 32 * 1024        // bytes/s; floor keeps idle bars near empty
    property real lastRx: -1
    property real lastTx: -1
    property real lastT: 0

    function sample() {
        const t = Date.now()
        if (lastT > 0 && lastRx >= 0 && rx >= lastRx && tx >= lastTx) {
            const dt = Math.max((t - lastT) / 1000, 0.2)
            rxRate = (rx - lastRx) / dt
            txRate = (tx - lastTx) / dt
            peak = Math.max(32 * 1024, peak * 0.9, rxRate, txRate)
        }
        lastRx = rx; lastTx = tx; lastT = t
    }
    function reset() { lastT = 0; rxRate = 0; txRate = 0; peak = 32 * 1024 }

    function human(b) {
        if (b < 1024) return Math.round(b) + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + " MB"
        return (b / 1024 / 1024 / 1024).toFixed(2) + " GB"
    }

    spacing: 6

    Row {
        spacing: 8
        GlassText {
            text: "Traffic"
            size: 11; weight: Font.Bold
            color: Qt.rgba(1, 1, 1, 0.55)
        }
        GlassText {
            anchors.baseline: parent.children[0].baseline
            visible: tr.note !== ""
            text: tr.note
            size: 10
            color: Qt.rgba(1, 1, 1, 0.4)
        }
    }
    Meter {
        icon: "\u{f0045}"                // arrow-down
        title: "Receiving"
        level: tr.rx < 0 ? -1 : tr.rxRate / tr.peak
        value: tr.rx < 0 ? "—" : tr.human(tr.rxRate) + "/s  ·  " + tr.human(tr.rx)
    }
    Meter {
        icon: "\u{f005d}"                // arrow-up
        title: "Sending"
        level: tr.tx < 0 ? -1 : tr.txRate / tr.peak
        value: tr.tx < 0 ? "—" : tr.human(tr.txRate) + "/s  ·  " + tr.human(tr.tx)
    }
}
