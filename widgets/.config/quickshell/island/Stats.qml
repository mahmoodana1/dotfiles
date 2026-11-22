import QtQuick
import Quickshell
import Quickshell.Io

// Live system numbers for the Center, polled once a second only while
// `active`: CPU (with a 60 s history), memory, swap, temperature, network
// rates (with history), uptime; disk, IP and Wi-Fi link details less often.
Scope {
    id: st
    property bool active: false
    property string iface: "wlan0"

    property real cpu: 0                    // 0..1
    property var cpuHist: []
    property real memUsed: 0                // bytes
    property real memTotal: 1
    property real swapUsed: 0
    property real swapTotal: 0
    property real temp: 0                   // °C
    property real rx: 0                     // bytes/s
    property real tx: 0
    property var rxHist: []
    property var txHist: []
    property real uptime: 0                 // s
    property real diskUsed: 0
    property real diskTotal: 1
    property string ip: ""
    property string kernel: ""
    property string host: ""
    // Wi-Fi link (iw): band, bitrate, dBm
    property string band: ""
    property string bitrate: ""
    property int dbm: 0

    readonly property int histLen: 60
    function push(arr, v) { const a = arr.concat([v]); return a.length > histLen ? a.slice(a.length - histLen) : a }

    // ---- 1 s: /proc + sysfs, read in place (no processes) ----------------------
    FileView { id: fStat; path: "/proc/stat"; printErrors: false }
    FileView { id: fMem; path: "/proc/meminfo"; printErrors: false }
    FileView { id: fUp; path: "/proc/uptime"; printErrors: false }
    FileView { id: fTemp; path: st.tempPath; printErrors: false }
    FileView { id: fRx; path: "/sys/class/net/" + st.iface + "/statistics/rx_bytes"; printErrors: false }
    FileView { id: fTx; path: "/sys/class/net/" + st.iface + "/statistics/tx_bytes"; printErrors: false }
    property var lastCpu: null
    property var lastNet: null

    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: st.active
        onTriggered: st.sample()
    }
    function sample() {
        [fStat, fMem, fUp, fTemp, fRx, fTx].forEach(f => f.reload())
        // cpu
        const c = fStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
        if (c.length >= 4) {
            const idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0)
            if (lastCpu) {
                const dt = total - lastCpu.total
                cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - lastCpu.idle) / dt)) : cpu
                cpuHist = push(cpuHist, cpu)
            }
            lastCpu = { idle: idle, total: total }
        }
        // memory
        const m = {}
        fMem.text().split("\n").forEach(l => { const p = l.split(/:\s+/); if (p.length === 2) m[p[0]] = parseInt(p[1]) * 1024 })
        if (m.MemTotal) { memTotal = m.MemTotal; memUsed = m.MemTotal - (m.MemAvailable || 0) }
        swapTotal = m.SwapTotal || 0; swapUsed = (m.SwapTotal || 0) - (m.SwapFree || 0)
        // uptime, temp
        uptime = parseFloat(fUp.text()) || uptime
        const t = parseInt(fTemp.text()); if (!isNaN(t)) temp = t / 1000
        // network
        const r = Number(fRx.text()), x = Number(fTx.text()), now = Date.now()
        if (!isNaN(r) && !isNaN(x)) {
            if (lastNet) {
                const s = (now - lastNet.t) / 1000
                if (s > 0) { rx = Math.max(0, (r - lastNet.r) / s); tx = Math.max(0, (x - lastNet.x) / s) }
                rxHist = push(rxHist, rx); txHist = push(txHist, tx)
            }
            lastNet = { r: r, x: x, t: now }
        }
    }
    onActiveChanged: if (!active) { lastCpu = null; lastNet = null } else { slow.restart(); slowP.run() }
    onIfaceChanged: lastNet = null

    // ---- once: temperature sensor, kernel, host ----------------------------------
    property string tempPath: ""
    Process {
        running: true
        command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && { echo $z/temp; break; }; done; uname -r; cat /etc/hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                if (l.length >= 3) { st.tempPath = l[0]; st.kernel = l[1]; st.host = l[2] }
                else if (l.length === 2) { st.tempPath = "/sys/class/thermal/thermal_zone0/temp"; st.kernel = l[0]; st.host = l[1] }
            }
        }
    }

    // ---- every 5 s: disk, IP, Wi-Fi link ------------------------------------------
    Timer { id: slow; interval: 5000; repeat: true; running: st.active; onTriggered: slowP.run() }
    Process {
        id: slowP
        function run() { if (!running) running = true }
        command: ["sh", "-c", "df -B1 --output=used,size / | tail -1; ip -4 -br addr show " + st.iface
                  + " | awk '{print $3}'; iw dev " + st.iface + " link 2>/dev/null | grep -E 'freq|signal|tx bitrate'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n")
                const d = (l[0] || "").trim().split(/\s+/).map(Number)
                if (d.length === 2 && d[1] > 0) { st.diskUsed = d[0]; st.diskTotal = d[1] }
                st.ip = (l[1] || "").trim().split("/")[0]
                st.band = ""; st.bitrate = ""; st.dbm = 0
                l.slice(2).forEach(s => {
                    s = s.trim()
                    if (s.startsWith("freq:")) { const f = parseFloat(s.slice(5)); st.band = f >= 5900 ? "6 GHz" : f >= 4900 ? "5 GHz" : "2.4 GHz" }
                    else if (s.startsWith("signal:")) st.dbm = parseInt(s.slice(7))
                    else if (s.startsWith("tx bitrate:")) st.bitrate = Math.round(parseFloat(s.slice(11))) + " Mb/s"
                })
            }
        }
    }

    // ---- formatting -----------------------------------------------------------------
    function bytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i]
    }
    function rate(b) { return bytes(b) + "/s" }
    function duration(s) {
        s = Math.max(0, Math.round(s))
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"
    }
}
