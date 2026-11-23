.pragma library
// What the island shows. Pure functions, tested in tests/tst_mode.qml.

const PANELS = ["compact", "control", "wifi", "bt", "sound", "notifs", "system"]   // the hover peek + the Center's tabs
function isPanel(v) { return PANELS.indexOf(v) >= 0 }

// The global view, by priority. s: { panel, held, critical, wsUntil,
// levelUntil, notifUntil, toastUntil }, t: now (ms).
function pick(s, t) {
    if (s.panel) return s.panel
    if (t < s.levelUntil) return "level"
    if (t < s.notifUntil && s.critical) return "notif"   // critical beats SUPER held
    if (s.held) return "full"
    if (t < s.notifUntil) return "notif"
    if (t < s.toastUntil) return "toast"
    if (t < s.wsUntil) return "ws"
    return "hidden"
}

// What one monitor draws. o: { here (events/panels target this monitor),
// fullscreen, empty (no windows on its workspace), shift (Shift held WITH SUPER),
// critical }.
function forScreen(view, o) {
    if (view === "full") return o.fullscreen && !o.shift ? "hidden" : "full"   // held: every monitor
    if (!o.here) return o.empty && !o.fullscreen ? "full" : "hidden"
    if (o.fullscreen) {
        // over a fullscreen window: workspace switches, panels, levels and critical popups only
        if (isPanel(view) || view === "ws" || view === "level" || (view === "notif" && o.critical)) return view
        return "hidden"                      // (SUPER+SHIFT arrives as view "full", above)
    }
    // an empty workspace keeps the bar out
    if ((view === "hidden" || view === "ws") && o.empty) return "full"
    return view
}

// A new flash ends the others (nothing pops back after it).
function pulse(u, which, t, ms) {
    const out = { ws: 0, level: 0, notif: 0, toast: 0 }
    out[which] = t + ms
    return out
}
