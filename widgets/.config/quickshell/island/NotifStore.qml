import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon + history. `entries` is newest first; each is a
// plain object { key, app, summary, body, icon, urgency, time, kept }.
// `kept` ones land in the hub and are saved to $XDG_STATE_HOME/halo/notifs.json;
// transient / synchronous (OSD-style) ones only pop up. Restored entries have
// no live notification behind them, so no actions.
Scope {
    id: store

    readonly property int cap: 80
    property var entries: []
    readonly property var kept: entries.filter(e => e.kept)
    readonly property int count: kept.length
    signal posted(var entry)

    property var live: ({})                 // key -> Notification
    property int liveRev: 0                 // bumps when `live` changes (it isn't reactive)

    function find(key) { return entries.find(e => e.key === key) || null }
    function actions(key) {
        liveRev
        const n = live[key], out = []
        if (n) for (let i = 0; i < n.actions.length; i++) out.push(n.actions[i])
        return out
    }
    function hasDefault(key) { return actions(key).some(a => a.identifier === "default") }

    function iconFor(n) {
        const img = n.image || ""
        if (img) return img
        const i = n.appIcon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.indexOf("://") > 0) return i
        return Quickshell.iconPath(i || (n.appName || "").toLowerCase(), true)
    }

    function drop(key) {
        if (!(key in live)) return
        const m = Object.assign({}, live); delete m[key]; live = m; liveRev++
    }
    function remove(key) { entries = entries.filter(e => e.key !== key); save() }
    function dismiss(key) {
        const n = live[key]
        drop(key); remove(key)
        if (n) n.dismiss()
    }
    function clearAll() { kept.forEach(e => dismiss(e.key)) }
    function invoke(key, identifier) {
        const a = actions(key).find(x => x.identifier === identifier)
        if (a) a.invoke()
        if (identifier === "dismiss" || a) dismiss(key)
    }

    property int seq: 0
    function receive(n) {
        n.tracked = true
        const key = n.id + ":" + Date.now() + ":" + (++seq)   // unique across restarts (history)
        const hints = n.hints || {}
        const osd = hints.value !== undefined || hints["x-canonical-private-synchronous"] !== undefined
        const e = {
            key: key, app: n.appName || "", summary: n.summary || "", body: n.body || "",
            icon: iconFor(n), urgency: n.urgency, time: Date.now(),
            kept: !n.transient && !osd, timeout: n.expireTimeout
        }
        const m = Object.assign({}, live); m[key] = n; live = m; liveRev++
        n.closed.connect(() => { drop(key); if (!e.kept) remove(key) })
        // a synchronous update replaces the previous one of its kind
        entries = [e].concat(entries.filter(x => x.kept || x.app !== e.app)).slice(0, cap)
        save()
        store.posted(e)
    }

    NotificationServer {
        keepOnReload: false
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => store.receive(n)
    }

    // ---- history on disk -----------------------------------------------------
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/halo"
    FileView {
        id: file
        path: store.dir + "/notifs.json"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const old = JSON.parse(text())
                if (Array.isArray(old)) store.entries = old.filter(e => e && e.key && e.kept).concat(store.entries).slice(0, store.cap)
            } catch (err) {}
            store.loaded = true
        }
        onLoadFailed: store.loaded = true
    }
    property bool loaded: false
    Process { running: true; command: ["mkdir", "-p", store.dir] }
    Timer { id: saveTimer; interval: 400; onTriggered: file.setText(JSON.stringify(store.kept.map(e =>
        ({ key: e.key, app: e.app, summary: e.summary, body: e.body, icon: e.icon.startsWith("image://") ? "" : e.icon,
           urgency: e.urgency, time: e.time, kept: true })))) }
    function save() { if (loaded) saveTimer.restart() }
}
