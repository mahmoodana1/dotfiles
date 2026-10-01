.pragma library

// Deadlines of the island's timed events, for shell.qml's pulse().
// Pure: no QML types, no I/O. `until` is { ws, level, notif, toast } in ms.
// The short flashes (workspace switch, level bar, charger toast) replace each
// other: a new one ends the rest, so when it's over the island goes away
// instead of falling back to an older flash that still had time left.
// A notification is something to read: a flash covers it, then it's back.

const flashes = ["ws", "level", "toast"]

function pulse(until, which, t, ms) {
    const out = Object.assign({}, until)
    if (flashes.indexOf(which) >= 0) flashes.forEach(k => out[k] = 0)
    out[which] = t + ms
    return out
}
