pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    property int strength: 0
    property bool pending: false
    readonly property bool hasContent: capture.item ? capture.item.hasContent : false
    property var targetScreen: null
    clip: true

    // Freeze the desktop while the overlay is still transparent, avoiding
    // recursive captures of the picker itself. The frame stays in memory until the picker closes.
    function prepare(screen, enabled) {
        clear();
        if (!enabled || !screen) return;
        targetScreen = screen;
        pending = true;
        deadline.start();
        capture.active = true;
    }
    function clear() {
        deadline.stop();
        capture.active = false;
        targetScreen = null;
        pending = false;
    }
    Timer {
        id: deadline
        interval: 250
        onTriggered: root.clear() // Unavailable capture must never block opening.
    }
    Loader {
        id: capture
        anchors.fill: parent
        active: false
        visible: false
        sourceComponent: ScreencopyView {
            captureSource: root.targetScreen
            live: false
            paintCursor: false
            onHasContentChanged: if (hasContent) { deadline.stop(); root.pending = false; }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: capture.item
        visible: root.strength > 0 && root.hasContent
        blurEnabled: true
        blurMax: 64
        blur: root.strength / 100
        autoPaddingEnabled: false
    }
}
