.pragma library

// Bluetooth audio profiles for BtPanel.qml, from `pactl -f json list cards`.
// Pure: no QML types, no I/O. parse() gives address -> card:
//   { card: "bluez_card.…", active: "a2dp-sink", options: [{ name, label, call }] }
// options: Hi-Fi (A2DP) codecs by priority, then the headset (HSP/HFP, has a
// mic) ones; "off" and unavailable profiles are left out.

function codec(desc) {
    const m = /codec ([^)]+)\)/.exec(desc || "")
    return m ? m[1] : ""
}

function options(profiles) {
    const hifi = [], call = []
    Object.keys(profiles || {}).forEach(name => {
        const p = profiles[name]
        if (!p.available) return
        if (name.indexOf("a2dp-sink") === 0) hifi.push({ name: name, p: p })
        else if (name.indexOf("headset-head-unit") === 0) call.push({ name: name, p: p })
    })
    const byPrio = (a, b) => b.p.priority - a.p.priority
    hifi.sort(byPrio); call.sort(byPrio)
    return hifi.map(x => ({ name: x.name, label: codec(x.p.description) || "Hi-Fi", call: false }))
        .concat(call.map(x => ({
            name: x.name,
            label: call.length > 1 && codec(x.p.description) ? "Headset " + codec(x.p.description) : "Headset",
            call: true
        })))
}

function parse(json) {
    let cards
    try { cards = JSON.parse(json) } catch (e) { return {} }
    const out = {}
    ;(cards || []).forEach(c => {
        const addr = c.properties && c.properties["api.bluez5.address"]
        if (!addr || (c.name || "").indexOf("bluez_card.") !== 0) return
        out[addr] = { card: c.name, active: c.active_profile, options: options(c.profiles) }
    })
    return out
}

function activeLabel(c) {
    if (!c) return ""
    const o = c.options.find(x => x.name === c.active)
    return o ? o.label : ""
}
