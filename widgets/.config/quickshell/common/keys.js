.pragma library

// Ctrl+[ acts like Escape (vim-style) in every panel. Matched on the key
// and on the physical key (XKB keycode 34 = the [ key), so it also works on
// the Arabic layout, where that key types a letter instead of "[".
function isEscape(event) {
    if (event.key === Qt.Key_Escape) return true
    return (event.modifiers & Qt.ControlModifier) !== 0
        && (event.key === Qt.Key_BracketLeft || event.nativeScanCode === 34)
}
