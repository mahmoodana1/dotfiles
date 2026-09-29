.pragma library

// Ctrl+[ acts like Escape (vim-style) in every panel. Matched on the key
// and on the physical key (XKB keycode 34 = the [ key), so it also works on
// the Arabic layout, where that key types a letter instead of "[".
function isEscape(event) {
    if (event.key === Qt.Key_Escape) return true
    return (event.modifiers & Qt.ControlModifier) !== 0
        && (event.key === Qt.Key_BracketLeft || event.nativeScanCode === 34)
}

// Ctrl+] closes a panel that holds the keyboard. Same physical-key match
// (XKB keycode 35 = the ] key).
function isClose(event) {
    return (event.modifiers & Qt.ControlModifier) !== 0
        && (event.key === Qt.Key_BracketRight || event.nativeScanCode === 35)
}

// Vim motions: the Latin letter typed, else (Arabic layout, or Ctrl held)
// the one on that physical key (XKB keycodes of a US layout). Shift gives
// the capital (G). "" for anything else.
const LETTERS = {
    24: "q", 25: "w", 26: "e", 27: "r", 28: "t", 29: "y", 30: "u", 31: "i", 32: "o", 33: "p",
    38: "a", 39: "s", 40: "d", 41: "f", 42: "g", 43: "h", 44: "j", 45: "k", 46: "l",
    52: "z", 53: "x", 54: "c", 55: "v", 56: "b", 57: "n", 58: "m"
}
function letter(event) {
    if (/^[a-zA-Z]$/.test(event.text)) return event.text
    const l = event.key >= Qt.Key_A && event.key <= Qt.Key_Z
        ? String.fromCharCode(event.key).toLowerCase()
        : LETTERS[event.nativeScanCode] || ""
    return (event.modifiers & Qt.ShiftModifier) !== 0 ? l.toUpperCase() : l
}
