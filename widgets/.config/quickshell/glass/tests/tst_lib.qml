import QtQuick
import QtTest
import "../lib/match.js" as Match
import "../lib/shortcuts.js" as Shortcuts

// Run:  /usr/lib/qt6/bin/qmltestrunner -input ~/.config/quickshell/glass/tests
TestCase {
    name: "GlassLib"

    // ---- match.js ----------------------------------------------------------
    function test_empty_query_matches_everything() { compare(Match.score("", "Firefox"), 0) }
    function test_no_match() { compare(Match.score("xyz", "Firefox"), -1) }
    function test_prefix_beats_substring() {
        verify(Match.score("fire", "Firefox") > Match.score("fox", "Firefox"))
    }
    function test_word_start_beats_mid_word() {
        verify(Match.score("term", "Alacritty Terminal") > Match.score("term", "Aftermath"))
    }
    function test_subsequence() {
        verify(Match.score("ffx", "Firefox") > 0)
        verify(Match.score("ffx", "Firefox") < Match.score("fire", "Firefox"))
    }
    function test_case_insensitive() { verify(Match.score("FIRE", "firefox") > 900) }
    function test_scattered_letters_dont_match() {
        compare(Match.score("fire", "LibreOffice Impress"), -1)
        verify(Match.score("vsc", "Visual Studio Code") > 0)
        verify(Match.score("ffx", "Firefox") > 0)
    }
    function test_strict_fields_need_a_substring() {
        // "fire" is scattered through this description, but isn't in it
        compare(Match.best("fire", [["LibreOffice Impress", 1], ["Create and edit presentations for slideshows, meeting and Web pages", 0.5, true]]), -1)
        verify(Match.best("slide", [["LibreOffice Impress", 1], ["Create presentations for slideshows", 0.5, true]]) > 0)
    }
    function test_best_uses_weights() {
        const name = Match.best("web", [["Firefox", 1], [["browser", "web"], 0.8]])
        verify(name > 0)
        compare(Match.best("zzz", [["Firefox", 1]]), -1)
    }

    // ---- shortcuts.js ------------------------------------------------------
    readonly property string md: [
        "# Title", "",
        "## Hyprland — Windows", "",
        "| Keys | Action |", "|---|---|",
        "| `SUPER + SPACE` | Float / tile window |",
        "| `SUPER + SHIFT + F` / `F11` | **Fullscreen** |",
        "| broken row |", "",
        "## tmux", "",
        "| `C-a` `|` | Split pane |", "",
        "## Notes for Claude (auto-maintenance)", "",
        "| `x` | never shown |"
    ].join("\n")

    function test_sections_and_prefix_dropped() {
        const r = Shortcuts.parse(md)
        compare(r.sections.length, 2)
        compare(r.sections[0].title, "Windows")
        compare(r.sections[1].title, "tmux")
    }
    function test_rows_and_markdown_cleaned() {
        const rows = Shortcuts.parse(md).sections[0].rows
        compare(rows.length, 2)
        compare(rows[0].action, "Float / tile window")
        compare(rows[1].action, "Fullscreen")
        compare(JSON.stringify(rows[1].groups), JSON.stringify([["SUPER", "SHIFT", "F"], ["F11"]]))
    }
    function test_pipe_inside_backticks() {
        const row = Shortcuts.parse(md).sections[1].rows[0]
        compare(row.action, "Split pane")
        compare(JSON.stringify(row.groups), JSON.stringify([["C-a"], ["|"]]))
    }
    function test_skipped_counted_and_notes_hidden() {
        const r = Shortcuts.parse(md)
        compare(r.skipped, 1)
        for (const s of r.sections) verify(s.title.indexOf("Notes") < 0)
    }

    // the real file parses, with every section non-empty
    function test_real_file() {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///home/mahmood/dotfiles/shortcuts.md", false)
        xhr.send()
        const r = Shortcuts.parse(xhr.responseText)
        verify(r.sections.length >= 10, "sections: " + r.sections.length)
        let rows = 0
        for (const s of r.sections) rows += s.rows.length
        verify(rows > 200, "rows: " + rows)
    }
}
