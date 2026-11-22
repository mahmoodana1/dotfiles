pragma Singleton
import QtQuick
import Quickshell

// Nerd Font (Material Design) glyphs, picked by state.
Singleton {
    readonly property string check: "\u{f012c}"
    readonly property string close: "\u{f0156}"
    readonly property string back: "\u{f0141}"
    readonly property string next: "\u{f0142}"
    readonly property string lock: "\u{f033e}"
    readonly property string refresh: "\u{f0450}"
    readonly property string bell: "\u{f009a}"
    readonly property string bellOff: "\u{f009b}"
    readonly property string bt: "\u{f00af}"
    readonly property string btOn: "\u{f00b1}"
    readonly property string btOff: "\u{f00b2}"
    readonly property string wifiOff: "\u{f092e}"
    readonly property string sun: "\u{f00e0}"
    readonly property string charging: "\u{f0084}"
    readonly property string plug: "\u{f06a5}"

    function wifi(s) {                      // s: 0..1
        return s > 0.75 ? "\u{f0928}" : s > 0.5 ? "\u{f0925}" : s > 0.25 ? "\u{f0922}" : "\u{f091f}"
    }
    function battery(pct, charging) {
        if (charging) return "\u{f0084}"
        if (pct >= 95) return "\u{f0079}"
        const steps = ["\u{f008e}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}",
                       "\u{f007e}", "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}"]
        return steps[Math.max(0, Math.min(9, Math.floor(pct / 10)))]
    }
    function volume(v, muted) {
        return muted || v <= 0 ? "\u{f0581}" : v < 0.34 ? "\u{f057f}" : v < 0.67 ? "\u{f0580}" : "\u{f057e}"
    }
    function mic(muted) { return muted ? "\u{f036d}" : "\u{f036c}" }
    function device(icon) {                 // BlueZ icon name -> glyph
        const i = icon || ""
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "\u{f02cb}"
        if (i.indexOf("keyboard") >= 0) return "\u{f030c}"
        if (i.indexOf("mouse") >= 0) return "\u{f037d}"
        if (i.indexOf("phone") >= 0) return "\u{f011c}"
        if (i.indexOf("computer") >= 0) return "\u{f0322}"
        if (i.indexOf("audio") >= 0 || i.indexOf("speaker") >= 0) return "\u{f04c3}"
        if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0) return "\u{f0eb5}"
        return "\u{f00af}"
    }
}
