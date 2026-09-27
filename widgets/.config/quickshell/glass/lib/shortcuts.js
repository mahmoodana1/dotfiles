.pragma library

// Parses ~/dotfiles/shortcuts.md for the SUPER+H viewer.
//   "## Title"              -> a section ("Hyprland — " prefix dropped)
//   "| `keys` | action |"   -> a row in the current section
// Header rows (| Keys | Action |, |---|) are ignored; rows that can't be
// split into keys + action are counted in `skipped`.

const SKIP_SECTIONS = /^Notes for Claude/

// Split a table row on | outside backticks, so `C-a` `|` stays one cell.
function splitRow(line) {
    const cells = []
    let cur = "", tick = false
    for (const ch of line.trim()) {
        if (ch === "`") tick = !tick
        if (ch === "|" && !tick) { cells.push(cur.trim()); cur = "" } else cur += ch
    }
    cells.push(cur.trim())
    if (cells.length && cells[0] === "") cells.shift()
    if (cells.length && cells[cells.length - 1] === "") cells.pop()
    return cells
}

function clean(s) { return s.replace(/\*\*/g, "").replace(/`/g, "").trim() }

// "`SUPER + SHIFT + F` / `F11`" -> [["SUPER","SHIFT","F"], ["F11"]]
function keyGroups(cell) {
    const ticks = cell.match(/`[^`]+`/g)
    const groups = ticks ? ticks.map(t => t.slice(1, -1)) : [clean(cell)]
    return groups.map(g => g.split(/\s\+\s/).map(k => k.trim()).filter(k => k.length))
}

function parse(text) {
    const sections = []
    let current = null, skipped = 0
    for (const raw of String(text).split("\n")) {
        const line = raw.replace(/\s+$/, "")
        if (line.startsWith("## ")) {
            const title = line.slice(3).trim()
            current = SKIP_SECTIONS.test(title) ? null
                : { title: title.replace(/^Hyprland\s+—\s+/, ""), rows: [] }
            if (current) sections.push(current)
            continue
        }
        if (!current || !line.startsWith("|")) continue
        const cells = splitRow(line)
        if (cells.length && (/^:?-{2,}:?$/.test(cells[0]) || /^keys?$/i.test(cells[0]))) continue
        if (cells.length < 2 || !cells[0] || !cells[1]) { skipped++; continue }
        current.rows.push({
            keys: clean(cells[0]),
            groups: keyGroups(cells[0]),
            action: clean(cells.slice(1).join(" — ")),
            section: current.title
        })
    }
    return { sections: sections.filter(s => s.rows.length), skipped: skipped }
}
