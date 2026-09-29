.pragma library

// Notification history for the island's hub (Notifs.qml). Pure: no QML types,
// no I/O. An entry is a plain object:
//   { key, app, appIcon, summary, body, urgency, time, image, live }
// `live` = a live Notification backs it (actions, image); never saved.

const UNKNOWN = "Unknown"

function appOf(e) { return e.app || UNKNOWN }

// newest group first, items newest first
function groups(entries) {
    const byApp = {}, order = []
    entries.slice().sort((a, b) => b.time - a.time).forEach(e => {
        const app = appOf(e)
        if (!byApp[app]) { byApp[app] = { app: app, appIcon: "", count: 0, latest: e, items: [] }; order.push(app) }
        const g = byApp[app]
        g.items.push(e)
        g.count++
        if (!g.appIcon && e.appIcon) g.appIcon = e.appIcon
    })
    return order.map(a => byApp[a])
}

function add(entries, entry, cap) { return [entry].concat(entries).slice(0, cap) }
function remove(entries, key) { return entries.filter(e => e.key !== key) }
function removeApp(entries, app) { return entries.filter(e => appOf(e) !== app) }

// the image is a live image:// URL that dies with the notification
function serialize(entries) {
    return JSON.stringify(entries.map(e => ({
        key: e.key, app: e.app, appIcon: e.appIcon, summary: e.summary,
        body: e.body, urgency: e.urgency, time: e.time
    })))
}

function deserialize(text) {
    let list
    try { list = JSON.parse(text) } catch (err) { return [] }
    if (!Array.isArray(list)) return []
    return list.filter(e => e && typeof e === "object" && typeof e.key === "string"
                            && typeof e.time === "number")
        .map(e => ({
            key: e.key, app: String(e.app || ""), appIcon: String(e.appIcon || ""),
            summary: String(e.summary || ""), body: String(e.body || ""),
            urgency: Number(e.urgency) || 1, time: e.time, image: "", live: false
        }))
}

function ago(time, now) {
    const s = Math.max(0, now - time) / 1000
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
}

// notify-send -i arrives as image "image://icon/<name>" or
// "image://icon//<path>": a name is really the app's icon (and survives a
// restart), a path is a picture (screenshot)
function icons(appIcon, image) {
    const pre = "image://icon/"
    if (!image || !image.startsWith(pre)) return { appIcon: appIcon || "", image: image || "" }
    const rest = image.slice(pre.length)
    if (rest.startsWith("/")) return { appIcon: appIcon || "", image: "file://" + rest }
    return { appIcon: appIcon || rest, image: "" }
}

// volume/brightness level popups carry a `value` hint (the island shows
// those natively). The synchronous hint alone is not enough: screenshot,
// airplane and touchpad notifications use it too.
function isOsd(hints) { return !!hints && hints.value !== undefined }

// ---- keyboard walk over the hub list --------------------------------------------
// The rows the selection moves over: each group, then (while expanded) its
// notifications. A lone notification's group row carries its key (it opens
// straight to the full view); a bigger group's doesn't (it expands).
function rows(groups, expanded) {
    const out = []
    groups.forEach(g => {
        out.push({ kind: "group", app: g.app, key: g.count > 1 ? "" : g.latest.key })
        if (g.count > 1 && g.app === expanded)
            g.items.forEach(e => out.push({ kind: "item", app: g.app, key: e.key }))
    })
    return out
}

// stable id, so the selection stays on its row when others come and go
function rowId(r) { return r ? (r.kind === "group" ? "g:" + r.app : "i:" + r.key) : "" }

// index of the row with `id`; gone → the same index, clamped
function relocate(list, id, fallback) {
    const i = list.findIndex(r => rowId(r) === id)
    if (i >= 0) return i
    return list.length === 0 ? 0 : Math.max(0, Math.min(list.length - 1, fallback))
}

// top and height of row i in the list column: groups `gap` apart, a group's
// notifications right under it
function rowSpan(list, i, groupH, itemH, gap) {
    let y = 0
    for (let j = 0; j < i; j++) {
        y += list[j].kind === "group" ? groupH : itemH
        if (list[j + 1] && list[j + 1].kind === "group") y += gap
    }
    return { y: y, h: list[i] && list[i].kind === "item" ? itemH : groupH }
}

// where the selection lands when the hub opens on `key`: its own row inside
// the expanded group, or the group row of a lone one
function selFor(groups, key) {
    const g = groups.find(g => g.items.some(e => e.key === key))
    if (!g) return { expanded: "", id: "" }
    return g.count > 1 ? { expanded: g.app, id: "i:" + key } : { expanded: "", id: "g:" + g.app }
}

// id to select once row i is dismissed: a group → the next group (else the
// previous one); a notification → its neighbour in the group, or the group
// itself when only one will be left (the group row then opens it)
function afterRemove(list, i) {
    const r = list[i]
    if (!r) return ""
    if (r.kind === "group") {
        for (let j = i + 1; j < list.length; j++) if (list[j].kind === "group") return rowId(list[j])
        for (let j = i - 1; j >= 0; j--) if (list[j].kind === "group") return rowId(list[j])
        return ""
    }
    const sibs = list.filter(x => x.kind === "item" && x.app === r.app)
    if (sibs.length <= 2) return "g:" + r.app
    const next = list[i + 1] && list[i + 1].kind === "item" ? list[i + 1] : list[i - 1]
    return rowId(next)
}
