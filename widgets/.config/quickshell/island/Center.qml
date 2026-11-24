import QtQuick
import Quickshell

// The Center: the island's large panel. A rail of tabs on the left (the
// accent capsule slides between them, like the workspace strip), the
// current tab on the right, and a power sheet behind the rail's ⏻.
// Tabs = ctl.panel: control (Home) | wifi | bt | sound | notifs | system.
//
// Keys: hjkl move the focus ring to whatever sits in that direction — across
// the rail and the tab alike (landing on a rail tab opens it). Enter / Space
// act: click, flip a switch, grab a slider (then h / l adjust, Enter or j / k
// let go). Del / x dismiss a notification, dd forgets a network / device,
// m mutes a slider, o opens a Home toggle's tab, Esc steps back (slider → power sheet → close).
// Shortcuts: 1-6 tabs, H / L previous / next tab, p power. Any key pins it open.
FocusScope {
    id: c
    property var ctl
    property bool active: false
    readonly property string tab: ctl.panel
    implicitWidth: 780
    implicitHeight: 540

    readonly property var tabs: [
        { id: "control", icon: "\u{f02dc}", label: "Home" },
        { id: "wifi", icon: "\u{f05a9}", label: "Wi-Fi" },
        { id: "bt", icon: Glyphs.bt, label: "Bluetooth" },
        { id: "sound", icon: "\u{f057e}", label: "Sound" },
        { id: "notifs", icon: Glyphs.bell, label: "Alerts" },
        { id: "system", icon: "\u{f061a}", label: "System" }
    ]
    readonly property int tabIndex: Math.max(0, tabs.findIndex(t => t.id === tab))
    property bool power: false
    readonly property var curTab: ({ control: homeTab, wifi: wifiTab, bt: btTab, sound: soundTab, notifs: notifTab, system: sysTab })[tab] || null
    readonly property bool typing: wifiTab.typing   // a password is being typed: don't auto-close
    onTypingChanged: if (!typing && active) forceActiveFocus()   // back from the password field
    onActiveChanged: { power = false; clearFocus(); if (active) forceActiveFocus() }
    onTabChanged: { power = false; if (focusItem && !focusItem.isRail) clearFocus() }
    onPowerChanged: { clearFocus(); Qt.callLater(() => { if (c.active) setFocus(power ? first() : powerBtn) }) }

    // ---- hjkl: spatial focus ---------------------------------------------------
    property Item focusItem: null
    property point lastPos: Qt.point(0, 0)
    property Item armedItem: null           // first d of dd
    Timer { id: disarm; interval: 1500; onTriggered: c.arm(null) }
    function arm(it) { if (armedItem) armedItem.armed = false; armedItem = it; if (it) { it.armed = true; disarm.restart() } }

    function collect() {                    // every reachable, visible item: rail + current tab (or the power sheet)
        const out = []
        const walk = it => {
            for (let i = 0; i < it.children.length; i++) {
                const ch = it.children[i]
                if (!ch.visible || ch.opacity < 0.05) continue
                if (ch.navigable === true && ch.width > 0) out.push(ch)
                walk(ch)
            }
        }
        if (power) walk(sheet)
        else { walk(rail); if (curTab) walk(curTab) }
        return out
    }
    function box(it) { const p = it.mapToItem(c, 0, 0); return { x: p.x, y: p.y, w: it.width, h: it.height, cx: p.x + it.width / 2, cy: p.y + it.height / 2 } }
    property bool ringOn: false             // a ring is meant to be showing (focusItem may have just died)
    function clearFocus() { ringOn = false; grab(false); arm(null); if (focusItem) focusItem.focused = false; focusItem = null }
    // A list rebuilt under us (Bluetooth/Wi-Fi scans reset their models) destroys
    // the focused row: put the ring back on whatever now sits where it was,
    // without clicking it, so the next j/k steps from there.
    onFocusItemChanged: if (!focusItem && ringOn) regainT.restart()
    Timer { id: regainT; interval: 40; onTriggered: c.regain() }   // let the rebuilt list lay out first
    function regain() {
        if (focusItem || !ringOn || !active) return
        const it = nearest(collect(), lastPos)
        if (!it) return
        focusItem = it; it.focused = true
    }
    function setFocus(it) {
        if (!it) return
        ringOn = true
        grab(false); arm(null)
        if (focusItem) focusItem.focused = false
        focusItem = it
        it.focused = true
        const b = box(it); lastPos = Qt.point(b.cx, b.cy)
        reveal(it)
        if (it.selectOnFocus) it.clicked()
    }
    function first() {                      // where a fresh ring starts: the tab's entry, else top-left
        const items = collect()
        const e = !power && curTab && curTab.entry ? curTab.entry() : null
        if (e && items.indexOf(e) >= 0) return e
        const content = items.filter(it => !it.isRail && it !== powerBtn)
        const pool = content.length ? content : items
        let best = null, bs = 1e9
        pool.forEach(it => { const b = box(it); const s = b.y * 2 + b.x; if (s < bs) { bs = s; best = it } })
        return best
    }
    function nearest(items, p) {
        let best = null, bs = 1e9
        items.forEach(it => { const b = box(it); const s = Math.hypot(b.cx - p.x, b.cy - p.y); if (s < bs) { bs = s; best = it } })
        return best
    }
    // the closest item whose centre lies in `dir`, preferring ones lined up with us
    function move(dir) {
        const items = collect()
        if (!focusItem && ringOn) regain()                        // row was rebuilt: carry on from its stand-in
        if (!focusItem) { setFocus(first()); return }             // first key: just show where we are
        if (items.indexOf(focusItem) < 0) { focusItem.focused = false; focusItem = nearest(items, lastPos); if (!focusItem) return; focusItem.focused = true }
        // from the rail, l dives into the tab at its natural start
        if (dir === "l" && (focusItem.isRail || focusItem === powerBtn) && !power) { const f = first(); if (f) setFocus(f); return }
        const a = box(focusItem)
        const vert = dir === "j" || dir === "k"
        // Edge to edge: a candidate must lie wholly past our edge (so a wide
        // slider's h goes to the rail, not the tile above it). If nothing
        // does, fall back to centres, but only for items lined up with us
        // (overlapping layouts) — never a jump to some far corner.
        const pick = strict => {
            let best = null, bs = 1e9
            items.forEach(it => {
                if (it === focusItem) return
                const b = box(it)
                const d = strict
                    ? (dir === "j" ? b.y - (a.y + a.h) : dir === "k" ? a.y - (b.y + b.h) : dir === "l" ? b.x - (a.x + a.w) : a.x - (b.x + b.w))
                    : (dir === "j" ? b.cy - a.cy : dir === "k" ? a.cy - b.cy : dir === "l" ? b.cx - a.cx : a.cx - b.cx)
                if (strict ? d < -3 : d <= 2) return
                // stay in a ~45° cone: no diagonal leaps to a far corner
                // sideways gap: 0 when the two overlap across the direction of travel
                const gap = vert ? Math.max(0, Math.max(a.x, b.x) - Math.min(a.x + a.w, b.x + b.w))
                                 : Math.max(0, Math.max(a.y, b.y) - Math.min(a.y + a.h, b.y + b.h))
                if (!strict && gap > 0) return
                if (gap > Math.max(0, d) * 1.2 + 24) return
                const off = vert ? Math.abs(b.cx - a.cx) : Math.abs(b.cy - a.cy)
                const s = Math.max(0, d) + gap * 4 + off * 0.15
                if (s < bs) { bs = s; best = it }
            })
            return best
        }
        let best = pick(true) || pick(false)
        // back out to the rail on the open tab, not whichever icon lines up
        // (landing on another rail item would switch tabs under you)
        if (best && best.isRail && !focusItem.isRail && focusItem !== powerBtn) {
            const cur = items.find(it => it.isRail && it.on)
            if (cur) best = cur
        }
        if (best) setFocus(best)
    }
    function reveal(it) {                   // scroll the nearest Flickable so the ring is in view
        for (let p = it.parent; p && p !== c; p = p.parent) {
            if (p.contentItem === undefined || p.contentY === undefined || p.flickableDirection === undefined) continue
            const y = it.mapToItem(p.contentItem, 0, 0).y
            const lo = p.originY, hi = p.originY + Math.max(0, p.contentHeight - p.height)
            if (y - 6 < p.contentY) p.contentY = Math.max(lo, y - 6)
            else if (y + it.height + 6 > p.contentY + p.height) p.contentY = Math.min(hi, y + it.height + 6 - p.height)
            return
        }
    }
    function grab(on) { if (focusItem && focusItem.isSlider) focusItem.grabbed = on }
    readonly property bool grabbing: focusItem !== null && focusItem.isSlider === true && focusItem.grabbed
    function act() {
        const f = focusItem
        if (!f) { setFocus(first()); return }
        if (f.isSlider) grab(!f.grabbed)
        else if (f.isSwitch) f.toggled(!f.checked)
        else if (f.activated) f.activated()
        else if (f.clicked) f.clicked()
        // the item may have gone (dismissed, list changed): land on its neighbour
        Qt.callLater(refocus)
    }
    function refocus() { if (active && (!focusItem || collect().indexOf(focusItem) < 0)) { focusItem = null; setFocus(nearest(collect(), lastPos)) } }
    Timer { id: refocusLater; interval: 180; onTriggered: c.refocus() }   // after list transitions

    function goTab(d) { ctl.openPanel(tabs[(tabIndex + d + tabs.length) % tabs.length].id) }
    Keys.onPressed: ev => {
        const t = ev.text, k = ev.key
        const ctrlJ = k === Qt.Key_J && ev.modifiers & Qt.ControlModifier   // Ctrl+J = Enter
        const dir = ctrlJ ? "" : t === "h" || k === Qt.Key_Left ? "h" : t === "j" || k === Qt.Key_Down ? "j"
                  : t === "k" || k === Qt.Key_Up ? "k" : t === "l" || k === Qt.Key_Right ? "l" : ""
        ctl.pinned = true                   // keyboard-driven: stays until closed
        if (t !== "d") arm(null)
        if (k === Qt.Key_Escape || t === "q" || (k === Qt.Key_BracketLeft && ev.modifiers & Qt.ControlModifier)) {
            if (grabbing) grab(false)
            else if (power) power = false
            else ctl.closePanel()
        }
        else if (grabbing && (dir === "h" || dir === "l")) focusItem.nudge(dir === "h" ? -0.05 : 0.05)
        else if (dir) { grab(false); move(dir) }
        else if (ctrlJ || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) act()
        else if ((t === "x" || k === Qt.Key_Delete || k === Qt.Key_Backspace) && focusItem && focusItem.remove && !focusItem.safeRemove) {
            focusItem.remove(); refocusLater.restart()
        }
        else if (t === "d" && focusItem && focusItem.remove) {
            if (!focusItem.safeRemove || armedItem === focusItem) { arm(null); focusItem.remove(); refocusLater.restart() }
            else arm(focusItem)
        }
        else if (t === "m" && focusItem && focusItem.isSlider) focusItem.iconClicked()
        else if (t === "o" && focusItem && focusItem.hasMore) focusItem.more()   // a Home toggle's own tab
        else if (!power && k >= Qt.Key_1 && k <= Qt.Key_6 && !(ev.modifiers & Qt.ShiftModifier)) ctl.openPanel(tabs[k - Qt.Key_1].id)
        else if (t === "H") goTab(-1)
        else if (t === "L") goTab(1)
        else if (t === "p") power = !power
        else return
        ev.accepted = true
    }

    // ---- rail ------------------------------------------------------------------
    Item {
        id: rail
        width: 84; height: parent.height
        readonly property int cell: 62
        Rectangle {                         // sliding capsule
            x: 12; width: 60; height: 56
            y: 18 + c.tabIndex * rail.cell + 3
            radius: 18
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Look.alpha(Look.accent, 0.85) }
                GradientStop { position: 1; color: Look.alpha(Look.accent2, 0.85) }
            }
        }
        Repeater {
            model: c.tabs
            Press {
                required property var modelData
                required property int index
                readonly property bool isRail: true
                selectOnFocus: true             // passing over a tab opens it
                on: c.tabIndex === index
                color: "transparent"; radius: 18
                x: 12; y: 18 + index * rail.cell
                width: 60; height: rail.cell - 4
                onClicked: c.ctl.openPanel(modelData.id)
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 12
                    text: modelData.icon; size: 18
                    color: parent.on ? Look.onAccent : Look.dim
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 36
                    text: modelData.label; size: 9; bold: parent.on
                    color: parent.on ? Look.onAccent : Look.faint
                }
                Rectangle {                 // unread badge
                    visible: modelData.id === "notifs" && c.ctl.notifs.count > 0 && !parent.on
                    x: 36; y: 7; height: 15; width: Math.max(15, badge.implicitWidth + 8); radius: 8
                    color: Look.accent2
                    Txt { id: badge; anchors.centerIn: parent; text: c.ctl.notifs.count; size: 9; bold: true; color: Look.onAccent }
                }
            }
        }
        Press {                             // ⏻
            id: powerBtn
            x: 22; width: 40; height: 40; radius: 20
            y: parent.height - height - 18
            on: c.power
            Txt { anchors.centerIn: parent; text: "\u{f0425}"; size: 17; color: c.power ? Look.accent2 : Look.dim }
            onClicked: c.power = !c.power
        }
        Rectangle {                         // divider
            x: parent.width - 1; y: 20; width: 1; height: parent.height - 40
            color: Look.alpha(Look.fg, 0.07)
        }
    }

    // ---- tabs --------------------------------------------------------------------
    Item {
        id: pane
        x: rail.width; width: parent.width - x; height: parent.height
        clip: true

        Tab { name: "control"; HomeTab { id: homeTab; anchors.fill: parent; ctl: c.ctl; active: parent.on } }
        Tab { name: "wifi"; WifiTab { id: wifiTab; anchors.fill: parent; ctl: c.ctl; active: parent.on } }
        Tab { name: "bt"; BtTab { id: btTab; anchors.fill: parent; ctl: c.ctl; active: parent.on } }
        Tab { name: "sound"; SoundTab { id: soundTab; anchors.fill: parent; ctl: c.ctl; active: parent.on } }
        Tab { name: "notifs"; NotifTab { id: notifTab; anchors.fill: parent; ctl: c.ctl; active: parent.on } }
        Tab { name: "system"; SystemTab { id: sysTab; anchors.fill: parent; ctl: c.ctl; active: parent.on } }

        PowerSheet { id: sheet; anchors.fill: parent; open: c.power; onDone: { c.power = false; c.ctl.closePanel() } }
    }

    // A tab slides up a touch and fades in; the old one fades out quicker.
    component Tab: Item {
        id: t
        property string name
        readonly property bool on: c.active && c.tab === name
        width: pane.width; height: pane.height
        opacity: on ? 1 : 0
        y: on ? 0 : 10
        visible: opacity > 0.01
        enabled: on
        Behavior on opacity { NumberAnimation { duration: t.on ? 170 : 90; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
