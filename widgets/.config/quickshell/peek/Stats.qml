pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

// System info for the right island. Polls only while `active`.
Singleton {
    id: stats

    property bool active: false

    property int cpu: 0
    property int mem: 0
    property int temp: 0
    property int disk: 0
    property bool online: true
    property string wifiSsid: ""             // "" = not on wifi
    property int wifiSignal: 0
    property bool btOn: false
    property string btDevices: ""            // connected device names, comma separated

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery
    // UPower percentage is 0..1 in current Quickshell; tolerate 0..100
    readonly property int batteryPct: !hasBattery ? 0
        : Math.round(battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage)
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    PwObjectTracker { objects: [stats.sink] }

    property var _prevCpu: null

    Process {
        id: proc
        command: [Qt.resolvedUrl("stats.sh").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    const eq = line.indexOf("=")
                    if (eq < 0) continue
                    const k = line.slice(0, eq), v = line.slice(eq + 1)
                    if (k === "cpu") {
                        const [busy, total] = v.split(" ").map(Number)
                        if (stats._prevCpu && total > stats._prevCpu[1])
                            stats.cpu = Math.round(100 * (busy - stats._prevCpu[0]) / (total - stats._prevCpu[1]))
                        else
                            quickResample.restart()   // first sample: need a delta soon
                        stats._prevCpu = [busy, total]
                    }
                    else if (k === "mem") stats.mem = Number(v)
                    else if (k === "temp") stats.temp = Number(v)
                    else if (k === "disk") stats.disk = Number(v)
                    else if (k === "net") stats.online = v === "" || v.startsWith("connected")
                    else if (k === "wifi") {
                        const bar = v.lastIndexOf("|")
                        stats.wifiSsid = bar < 0 ? "" : v.slice(0, bar).replace(/\\:/g, ":")
                        stats.wifiSignal = bar < 0 ? 0 : Number(v.slice(bar + 1)) || 0
                    }
                    else if (k === "bt") {
                        stats.btOn = v.startsWith("on")
                        stats.btDevices = stats.btOn ? v.slice(3) : ""
                    }
                }
            }
        }
    }

    Timer { id: quickResample; interval: 300; onTriggered: if (!proc.running) proc.running = true }

    Timer {
        interval: 2000
        repeat: true
        running: stats.active
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
