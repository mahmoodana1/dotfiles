// Peek — liquid-glass top bar, visible only while SUPER is held.
// Run:     qs -c peek          (managed by ~/.config/hypr/scripts/WaybarPeek.sh)
// Shader:  shaders/glass.frag → recompile to .qsb after editing (command inside)
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool held: false

    // evdev SUPER watcher; restarts if it ever dies
    Process {
        id: superwatch
        running: true
        command: ["python3", Qt.resolvedUrl("superwatch.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.held = line.trim() === "down"
        }
        onExited: { root.held = false; restart.start() }
    }
    Timer { id: restart; interval: 1000; onTriggered: superwatch.running = true }

    // manual control / testing:  qs -c peek ipc call peek down|up
    IpcHandler {
        target: "peek"
        function down(): void { root.held = true }
        function up(): void { root.held = false }
    }

    Binding { target: Stats; property: "active"; value: root.held }

    Variants {
        model: Quickshell.screens
        Bar {
            held: root.held
        }
    }
}
