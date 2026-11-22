import QtQuick
import QtTest
import "../lib/mode.js" as M

// /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "mode"
    function s(o) { return Object.assign({ panel: "", held: false, critical: false, wsUntil: 0, levelUntil: 0, notifUntil: 0, toastUntil: 0 }, o) }

    function test_priority() {
        compare(M.pick(s({}), 10), "hidden")
        compare(M.pick(s({ wsUntil: 20 }), 10), "ws")
        compare(M.pick(s({ held: true, notifUntil: 20 }), 10), "full")
        compare(M.pick(s({ held: true, notifUntil: 20, critical: true }), 10), "notif")
        compare(M.pick(s({ held: true, levelUntil: 20 }), 10), "level")
        compare(M.pick(s({ panel: "wifi", levelUntil: 20 }), 10), "wifi")
        compare(M.pick(s({ notifUntil: 5 }), 10), "hidden")           // expired
    }
    function test_screen() {
        const o = (x) => Object.assign({ here: true, fullscreen: false, empty: false, shift: false, critical: false }, x)
        compare(M.forScreen("ws", o({})), "ws")
        compare(M.forScreen("ws", o({ empty: true })), "full")
        compare(M.forScreen("hidden", o({ here: false, empty: true })), "full")
        compare(M.forScreen("notif", o({ here: false })), "hidden")
        compare(M.forScreen("notif", o({ fullscreen: true })), "hidden")
        compare(M.forScreen("notif", o({ fullscreen: true, critical: true })), "notif")
        compare(M.forScreen("full", o({ fullscreen: true })), "hidden")
        compare(M.forScreen("full", o({ fullscreen: true, shift: true })), "full")
        compare(M.forScreen("bt", o({ fullscreen: true })), "bt")
        compare(M.pick(s({ panel: "compact", held: true }), 10), "compact")
        compare(M.forScreen("ws", o({ fullscreen: true })), "ws")
        compare(M.forScreen("hidden", o({ fullscreen: true, shift: true })), "hidden")   // Shift alone: nothing
    }
    function test_pulse() {
        const u = M.pulse({ ws: 50, level: 50, notif: 50, toast: 50 }, "level", 10, 100)
        compare(u.level, 110); compare(u.ws, 0); compare(u.notif, 0)
    }
}
