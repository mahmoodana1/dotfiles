pragma Singleton
import QtQuick
import Quickshell

// Shell-wide text settings for GlassText. Each quickshell process has its own
// copy, so a shell can change these without touching the others
// (island/shell.qml sets minWeight so its small labels read bolder).
Singleton {
    property int minWeight: 0            // e.g. Font.Bold: no GlassText lighter than this
}
