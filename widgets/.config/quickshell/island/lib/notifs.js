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
