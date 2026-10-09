import QtQuick
import QtTest
import Quickshell
import "Fixtures.js" as Fixtures
import "components"

// Quickshell links its QML plugins into the executable, so qmltestrunner
// cannot load them. Run these checks in an offscreen Quickshell window.
FloatingWindow {
    id: root
    visible: true
    implicitWidth: 1000
    implicitHeight: 700
    property var views: Fixtures.views
    property int hoverCount: 0
    readonly property var card: cardLoader.item
    Loader {
        id: cardLoader
        active: DesktopEntries.applications.values.length > 0
        onLoaded: checks.start()
        sourceComponent: SpaceCard {
            width: 700; height: 92
            compact: true
            workspace: ({id: 1, name: "1", active: true, windows: [
                {address: "a", appId: "switch-magic-test"},
                {address: "b", appId: "SwitchMagicMissingApp"},
                {address: "c", appId: "SwitchMagicMissingApp"},
                {address: "d", appId: "SwitchMagicMissingApp"}
            ]})
            themeColors: ({surface: "#222222", text: "#ffffff", muted: "#aaaaaa", accent: "#8888ff"})
            style: root.views[0].card
            previewMode: "icon"
            captureFor: function(address) { throw new Error("Icons only must not request a capture"); }
            onHovered: root.hoverCount++
        }
    }
    TestCase { id: events; when: false }
    function check(condition, message) { if (!condition) throw new Error(message); }
    function descendants(item) {
        var result = [item];
        if (item.children) for (var i = 0; i < item.children.length; i++)
            result = result.concat(descendants(item.children[i]));
        return result;
    }
    Timer {
        id: checks
        interval: 300
        onTriggered: {
            try {
                var tiles = root.descendants(card).filter(function(item) { return item.appName !== undefined; });
                root.check(tiles.length === 4, "Four window tiles must be created");
                root.check(tiles[0].appIcon.length > 0, "Synthetic desktop entry must resolve its icon");
                var icon = root.descendants(tiles[0]).find(function(item) { return item.source !== undefined && String(item.source) === tiles[0].appIcon; });
                root.check(icon && icon.visible && icon.status === Image.Ready, "App icon must be displayed");
                var fallback = root.descendants(tiles[1]).find(function(item) { return item.text === "S"; });
                root.check(fallback && fallback.visible, "Missing icons must display an app initial");
                for (var v of root.views) {
                    card.style = v.card;
                    card.width = v.geometry.cardWidth; card.height = v.geometry.cardHeight;
                    card.compact = v.engine === "list";
                    events.wait(20);
                    for (var tile of tiles) {
                        root.check(tile.width >= 25 && tile.height >= 25, v.id + ": previews must have usable dimensions");
                        var pos = tile.mapToItem(card, 0, 0);
                        root.check(pos.x >= 0 && pos.y >= 0 && pos.x + tile.width <= card.width && pos.y + tile.height <= card.height, v.id + ": preview must fit inside card");
                    }
                    for (var item of root.descendants(card))
                        root.check(item.width >= 0 && item.height >= 0, v.id + ": negative child dimensions");
                }
                events.mouseMove(card, 10, 10);
                events.mouseMove(card, 20, 20);
                root.check(root.hoverCount === 0, "Hover must not select when disabled");
                card.hoverSelect = true;
                events.mouseMove(card, 30, 30);
                root.check(root.hoverCount > 0, "Hover must select when enabled");
                console.log("SPACE_CARD_TESTS_PASSED");
            } catch (error) { console.error("SPACE_CARD_TESTS_FAILED: " + error); }
            Qt.quit();
        }
    }
}
