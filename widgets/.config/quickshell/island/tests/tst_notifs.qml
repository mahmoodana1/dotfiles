import QtQuick
import QtTest
import "../lib/notifs.js" as N

// Run:  /usr/lib/qt6/bin/qmltestrunner -input ~/.config/quickshell/island/tests
TestCase {
    name: "Notifs"

    function e(key, app, time, extra) {
        return Object.assign({ key: key, app: app, appIcon: "", summary: "s" + key, body: "",
                               urgency: 1, time: time, image: "", live: true }, extra || {})
    }

    // ---- groups -------------------------------------------------------------
    function test_groups_empty() { compare(N.groups([]).length, 0) }
    function test_groups_by_app_newest_first() {
        const g = N.groups([e("c", "Discord", 30), e("b", "Mail", 20), e("a", "Discord", 10)])
        compare(g.length, 2)
        compare(g[0].app, "Discord")
        compare(g[0].count, 2)
        compare(g[0].latest.key, "c")
        compare(g[0].items.map(i => i.key).join(","), "c,a")
        compare(g[1].app, "Mail")
    }
    function test_groups_order_follows_newest_item() {
        // entries arrive out of order (restored + live): still newest group first
        const g = N.groups([e("a", "Mail", 10), e("b", "Discord", 50), e("c", "Mail", 40)])
        compare(g[0].app, "Discord")
        compare(g[1].items[0].key, "c")
    }
    function test_groups_unknown_app() { compare(N.groups([e("a", "", 1)])[0].app, "Unknown") }
    function test_groups_icon_from_latest_with_icon() {
        const g = N.groups([e("b", "X", 2), e("a", "X", 1, { appIcon: "x-icon" })])
        compare(g[0].appIcon, "x-icon")
    }

    // ---- add / remove ---------------------------------------------------------
    function test_add_puts_first() {
        compare(N.add([e("a", "X", 1)], e("b", "X", 2), 100).map(i => i.key).join(","), "b,a")
    }
    function test_add_caps_dropping_oldest() {
        const l = N.add([e("b", "X", 2), e("a", "X", 1)], e("c", "X", 3), 2)
        compare(l.map(i => i.key).join(","), "c,b")
    }
    function test_add_does_not_mutate() {
        const l = [e("a", "X", 1)]
        N.add(l, e("b", "X", 2), 100)
        compare(l.length, 1)
    }
    function test_remove() {
        compare(N.remove([e("a", "X", 1), e("b", "X", 2)], "a").map(i => i.key).join(","), "b")
    }
    function test_remove_app() {
        const l = N.removeApp([e("a", "X", 1), e("b", "Y", 2), e("c", "", 3)], "X")
        compare(l.map(i => i.key).join(","), "b,c")
        compare(N.removeApp(l, "Unknown").map(i => i.key).join(","), "b")
    }

    // ---- persistence ------------------------------------------------------------
    function test_serialize_drops_live_and_image() {
        const back = JSON.parse(N.serialize([e("a", "X", 1, { image: "image://qsimage/1" })]))
        compare(back.length, 1)
        compare(back[0].live, undefined)
        compare(back[0].image, undefined)
        compare(back[0].summary, "sa")
    }
    function test_roundtrip_not_live() {
        const l = N.deserialize(N.serialize([e("a", "X", 1, { body: "hi" })]))
        compare(l.length, 1)
        compare(l[0].body, "hi")
        compare(l[0].live, false)
        compare(l[0].image, "")
    }
    function test_deserialize_garbage() {
        compare(N.deserialize("").length, 0)
        compare(N.deserialize("{not json").length, 0)
        compare(N.deserialize("{\"a\":1}").length, 0)
    }
    function test_deserialize_drops_partial_entries() {
        const l = N.deserialize(JSON.stringify([{ key: "a", time: 1 }, { key: "b" }, { time: 2 }, null, 5]))
        compare(l.length, 1)
        compare(l[0].key, "a")
        compare(l[0].summary, "")
        compare(l[0].app, "")
    }

    // ---- ago ------------------------------------------------------------------
    function test_ago() {
        const now = 10 * 86400000
        compare(N.ago(now - 10000, now), "now")
        compare(N.ago(now - 5 * 60000, now), "5m")
        compare(N.ago(now - 3 * 3600000, now), "3h")
        compare(N.ago(now - 2 * 86400000, now), "2d")
        compare(N.ago(now + 5000, now), "now")        // clock skew
    }

    // ---- icons ------------------------------------------------------------------
    function test_icons_named_icon_becomes_app_icon() {
        const r = N.icons("", "image://icon/mail-unread")
        compare(r.appIcon, "mail-unread")
        compare(r.image, "")
    }
    function test_icons_keeps_real_app_icon() { compare(N.icons("discord", "image://icon/x").appIcon, "discord") }
    function test_icons_path_becomes_file_image() {
        const r = N.icons("", "image://icon//tmp/shot.png")
        compare(r.appIcon, "")
        compare(r.image, "file:///tmp/shot.png")
    }
    function test_icons_other_images_untouched() {
        compare(N.icons("a", "image://qsimage/1/2").image, "image://qsimage/1/2")
        compare(N.icons("a", "").image, "")
    }

    // ---- isOsd --------------------------------------------------------------------
    function test_is_osd() {
        verify(N.isOsd({ value: 40 }))
        // synchronous alone is just "replace my last one" (screenshot, airplane…)
        verify(!N.isOsd({ "x-canonical-private-synchronous": "shot" }))
        verify(!N.isOsd({ urgency: 1 }))
        verify(!N.isOsd(null))
        verify(!N.isOsd(undefined))
    }
}
