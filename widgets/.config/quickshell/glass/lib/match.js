.pragma library

// Fuzzy matching for the launcher and the other searchable panels.
// score(query, text): higher is better, -1 = no match, 0 = empty query.

function isBoundary(ch) { return ch === " " || ch === "-" || ch === "_" || ch === "." || ch === "/" }

// Next occurrence of ch at or after `from`, preferring one that starts a word.
function nextStart(t, ch, from) {
    for (let j = t.indexOf(ch, from); j >= 0; j = t.indexOf(ch, j + 1))
        if (j === 0 || isBoundary(t[j - 1])) return j
    return t.indexOf(ch, from)
}

function score(query, text) {
    if (!query) return 0
    if (!text) return -1
    const q = query.toLowerCase()
    const t = String(text).toLowerCase()

    // whole-query substring: prefix beats word start beats anywhere
    const idx = t.indexOf(q)
    if (idx === 0) return 1000 - t.length
    if (idx > 0) return (isBoundary(t[idx - 1]) ? 800 : 600) - idx - t.length * 0.1

    // subsequence: every query char in order; reward streaks and word starts.
    // Scattered letters don't count: the match must be tight (span within ~2x
    // the query) unless every letter starts a word or continues a streak
    // (initials: "vsc" -> Visual Studio Code).
    let ti = 0, s = 0, streak = 0, first = -1, last = -1, allStarts = true
    for (let i = 0; i < q.length; i++) {
        const found = t[ti] === q[i] && i > 0 ? ti : nextStart(t, q[i], ti)
        if (found < 0) return -1
        const start = found === 0 || isBoundary(t[found - 1])
        const cont = i > 0 && found === ti
        if (!start && !cont) allStarts = false
        if (cont) { streak++; s += 5 * streak } else { streak = 0; s -= found - ti }
        if (start) s += 10
        if (first < 0) first = found
        last = found
        ti = found + 1
    }
    if (!allStarts && last - first + 1 > q.length * 2 + 1) return -1
    return 300 + s - t.length * 0.1
}

// Best score across weighted fields: [[text, weight, strict], ...]
// text may be an array (e.g. keywords). strict = only a whole-query substring
// counts, so long descriptions don't match on scattered letters.
function best(query, fields) {
    let top = -1
    for (const f of fields) {
        const texts = Array.isArray(f[0]) ? f[0] : [f[0]]
        for (const text of texts) {
            if (f[2] && query && String(text).toLowerCase().indexOf(query.toLowerCase()) < 0) continue
            const sc = score(query, text)
            if (sc >= 0) top = Math.max(top, query ? sc * f[1] : 0)
        }
    }
    return top
}
