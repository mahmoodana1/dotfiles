import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "lib/notifs.js" as N

// The notification daemon (org.freedesktop.Notifications) + the hub's history.
// Every notification lands in `entries` (newest first, capped) and fires
// `posted` for the island popup. Transient ones popup only: they're kept out
// of the list and released (dismissed) by shell.qml once nobody shows them.
// History is saved to $XDG_STATE_HOME/island/notifications.json; restored
// entries have no live notification behind them, so no actions or image.
Scope {
    id: store

    readonly property int cap: 100
    property var entries: []
    readonly property var kept: entries.filter(e => !e.transient)
    readonly property var groups: N.groups(kept)
    readonly property int count: kept.length
    signal posted(var entry)

    // key -> Notification. Not reactive by itself: `liveRev` bumps on change.
    property var live: ({})
    property int liveRev: 0

    function find(key) {
        for (let i = 0; i < entries.length; i++) if (entries[i].key === key) return entries[i]
        return null
    }
    function actions(key) {
        liveRev                                       // re-evaluate bindings on change
        const n = live[key], out = []
        if (n) for (let i = 0; i < n.actions.length; i++) out.push(n.actions[i])   // QML list -> array
        return out
    }
    function hasDefault(key) { return actions(key).some(a => a.identifier === "default") }
    function image(key) { liveRev; const n = live[key]; return n ? N.icons("", n.image).image : "" }

    // icon name / path / URL -> image source ("" when nothing fits)
    function iconFor(icon, app) {
        const i = icon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.indexOf("://") > 0) return i
        return Quickshell.iconPath(i || (app || "").toLowerCase(), true)
    }

    function dismiss(key) {
        const n = live[key]
        forget(key)
        entries = N.remove(entries, key)
        if (n) n.dismiss()
    }
    function dismissApp(app) {
        store.groups.filter(g => g.app === app).forEach(g => g.items.forEach(e => dismiss(e.key)))
    }
    function clearAll() { kept.forEach(e => dismiss(e.key)) }
    function invoke(key, identifier) {
        const n = live[key]
        const a = actions(key).find(x => x.identifier === identifier)
        if (!n || !a) return
        const resident = n.resident
        if (!resident) { forget(key); entries = N.remove(entries, key) }
        a.invoke()
        // invoke() dismisses a non-resident notification itself; make sure
        if (!resident) Qt.callLater(() => { try { if (n.tracked) n.dismiss() } catch (e) {} })
    }
    function forget(key) {
        if (live[key] === undefined) return
        delete live[key]
        liveRev++
    }

    function receive(n) {
        if (N.isOsd(n.hints)) return               // untracked: dropped
        n.tracked = true
        const ic = N.icons(n.appIcon || n.desktopEntry, n.image)
        const e = {
            key: Date.now() + "-" + n.id, id: n.id,
            app: n.appName, appIcon: ic.appIcon,
            summary: n.summary, body: n.body, urgency: n.urgency,
            time: Date.now(), image: ic.image, live: true,
            transient: n.transient, timeout: n.expireTimeout
        }
        live[e.key] = n
        liveRev++
        entries = N.add(entries, e, cap)
        // an app replacing its notification updates the same object
        const refresh = () => {
            const cur = find(e.key)
            if (!cur) return
            const upd = Object.assign({}, cur, N.icons(cur.appIcon, n.image),
                                      { summary: n.summary, body: n.body, time: Date.now() })
            entries = [upd].concat(N.remove(entries, e.key))
            posted(upd)
        }
        n.summaryChanged.connect(() => Qt.callLater(refresh))
        n.bodyChanged.connect(() => Qt.callLater(refresh))
        n.closed.connect(reason => {
            if (live[e.key] !== n) return            // we already let it go
            forget(e.key)
            // the app took it back (read elsewhere, …): it leaves the hub too
            if (reason === NotificationCloseReason.CloseRequested)
                entries = N.remove(entries, e.key)
            else entries = entries.map(x => x.key === e.key ? Object.assign({}, x, { live: false, image: "" }) : x)
        })
        posted(e)
    }

    NotificationServer {
        keepOnReload: false
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        actionsSupported: true
        imageSupported: true
        onNotification: n => store.receive(n)
    }

    // ---- history on disk --------------------------------------------------------
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/island"
    property bool restored: false
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])
    FileView {
        id: file
        path: store.dir + "/notifications.json"
        atomicWrites: true
        printErrors: false
        onLoaded: store.restore(text())
        onLoadFailed: store.restored = true
    }
    function restore(text) {
        if (restored) return
        restored = true
        // anything that arrived while loading stays on top
        const have = {}
        entries.forEach(e => have[e.key] = true)
        entries = entries.concat(N.deserialize(text).filter(e => !have[e.key])).slice(0, cap)
    }
    onKeptChanged: if (restored) saveTimer.restart()
    onRestoredChanged: if (restored) saveTimer.restart()
    Timer { id: saveTimer; interval: 500; onTriggered: file.setText(N.serialize(store.kept)) }
}
