import QtQuick
import QtTest
import "../lib/flash.js" as F

// Run:  /usr/lib/qt6/bin/qmltestrunner -input ~/.config/quickshell/island/tests
TestCase {
    name: "Flash"

    readonly property var idle: ({ ws: 0, level: 0, notif: 0, toast: 0 })

    function test_pulse_sets_its_deadline() {
        compare(F.pulse(idle, "level", 1000, 1500).level, 2500)
    }
    function test_pulse_leaves_input_alone() {
        const u = { ws: 0, level: 2500, notif: 0, toast: 0 }
        F.pulse(u, "ws", 1200, 300)
        compare(u.level, 2500)
    }
    // volume bar up, then a workspace switch: the bar must not come back
    function test_ws_ends_level() {
        const u = F.pulse(F.pulse(idle, "level", 1000, 1500), "ws", 1200, 300)
        compare(u.ws, 1500)
        compare(u.level, 0)
    }
    function test_level_ends_ws_and_toast() {
        const u = F.pulse({ ws: 1300, level: 0, notif: 0, toast: 2600 }, "level", 1200, 1500)
        compare(u.level, 2700)
        compare(u.ws, 0)
        compare(u.toast, 0)
    }
    function test_toast_ends_level() {
        compare(F.pulse({ ws: 0, level: 2500, notif: 0, toast: 0 }, "toast", 1200, 1600).level, 0)
    }
    // a notification is something to read: a flash covers it, then it's back
    function test_flash_keeps_notif() {
        const u = F.pulse({ ws: 0, level: 0, notif: 5000, toast: 0 }, "ws", 1200, 300)
        compare(u.notif, 5000)
    }
    function test_notif_keeps_flashes() {
        const u = F.pulse({ ws: 0, level: 2500, notif: 0, toast: 0 }, "notif", 1200, 4000)
        compare(u.level, 2500)
        compare(u.notif, 5200)
    }
}
