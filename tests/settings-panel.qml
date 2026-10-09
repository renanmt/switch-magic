import QtQuick
import QtTest
import Quickshell
import "Fixtures.js" as Fixtures
import "lib/Model.js" as Model
import "components"

FloatingWindow {
    id: window
    visible: true
    implicitWidth: 1152; implicitHeight: 900
    property var savedConfig: null
    SettingsPanel {
        id: panel
        x: 26; y: 18; width: 1100; height: 850
        config: Model.duplicate(Fixtures.defaults, "list", "My list").config
        defaults: Fixtures.defaults
        themeColors: ({surface: "#080c20", text: "#ffd0b0", muted: "#7c87ae", accent: "#9691ec"})
        onSave: function(next) { window.savedConfig = next; saveCompleted(true); }
    }
    TestCase { id: events; when: false }
    function check(condition, message) { if (!condition) throw new Error(message); }
    function visualFind(item, name) {
        if (item.objectName === name) return item;
        if (item.children) for (var child of item.children) {
            var found = visualFind(child, name); if (found) return found;
        }
        return null;
    }
    function child(name) { var result = events.findChild(window, name) || visualFind(panel, name); check(!!result, "Missing " + name); return result; }
    Timer {
        interval: 300; running: true
        onTriggered: {
            try {
                window.check(!panel.validation.length, "Initial settings must be valid");
                var blur = window.child("backgroundBlurSlider");
                events.mouseClick(blur, blur.width - 1, blur.height / 2);
                window.check(panel.draft.behavior.backgroundBlur === 100, "Blur slider must save its percentage");
                var logo = window.child("displayLogoToggle");
                window.check(blur.mapToItem(panel, blur.width, 0).x < logo.mapToItem(panel, 0, 0).x, "Blur slider must sit to the left of Display logo");
                events.mouseClick(logo, 20, logo.height / 2);
                window.check(!panel.draft.behavior.showLogo, "Logo toggle must update settings");
                panel.tab = "views";
                events.wait(20);
                window.child("scopeShortcut").requested("Ctrl + Win + K");
                window.check(panel.draft.profiles.workspace.shortcut === "CTRL + SUPER + K", "Custom shortcut must normalize and apply");
                var before = JSON.stringify(panel.draft);
                panel.selectedScope = "spaces";
                window.child("scopeShortcut").requested("ALT + SHIFT + TAB");
                var conflict = window.child("shortcutConflictDialog");
                window.check(conflict.visible && JSON.stringify(panel.draft) === before, "Conflict must wait for confirmation");
                conflict.reject();
                window.check(JSON.stringify(panel.draft) === before, "Cancel must keep both assignments");
                var picker = window.child("scopeShortcut");
                var choice = events.findChild(picker, "propertyChoice");
                var index = choice.model.indexOf("Alt + Shift + Tab");
                choice.currentIndex = index; choice.activated(index);
                conflict.reject();
                window.check(choice.displayText === "Alt + Super + Tab", "Rejected dropdown choice must return to saved shortcut");
                picker.requested("ALT + SHIFT + TAB");
                conflict.accept();
                window.check(panel.draft.profiles.monitor.shortcut === "" && panel.draft.profiles.spaces.shortcut === "ALT + SHIFT + TAB", "Confirmation must move the shortcut");
                panel.requestShortcut("all", "invalid chord");
                window.check(!!panel.localError && panel.draft.profiles.all.shortcut === "CTRL + ALT + TAB", "Invalid shortcut must not be saved");
                events.wait(350);
                window.check(window.savedConfig && window.savedConfig.profiles.monitor.shortcut === "", "Assignments must autosave");
                window.child("resetSettingsButton").clicked();
                var reset = window.child("resetSettingsDialog");
                window.check(reset.visible, "Reset must ask for confirmation");
                reset.reject();
                window.check(panel.draft.profiles.monitor.shortcut === "", "Cancelled reset must keep settings");
                window.child("resetSettingsButton").clicked(); reset.accept();
                window.check(Model.equal(panel.draft.profiles, Fixtures.defaults.profiles), "Reset must restore all default assignments");
                window.check(Model.equal(panel.draft.behavior, Fixtures.defaults.behavior), "Reset must restore behavior");
                window.check(logo.checked, "Reset must update the visible logo toggle");
                window.check(blur.value === 20, "Reset must restore 20% blur");
                window.check(panel.draft.customViews.length === 1 && panel.draft.customViews[0].name === "My list", "Reset must keep custom views");
                panel.tab = "editor"; panel.editorId = "list";
                var previewBefore = window.child("studioPreviewScroll").y;
                panel.startCopy();
                events.wait(50);
                var studio = window.child("viewStudio"), preview = window.child("studioPreviewScroll");
                window.check(studio.clip && preview.clip && preview.height > 0, "Studio and preview must clip to their body");
                window.check(preview.y === previewBefore && preview.y === 0, "Duplicate form must not move the preview");
                var form = window.child("duplicateViewForm");
                window.check(form.mapToItem(studio, 0, 0).x + form.width < preview.x, "Duplicate controls must remain in the left column");
                window.check(preview.contentHeight <= preview.height, "Full-height preview should fit with the duplicate form open");
                panel.height = 650;
                events.wait(20);
                window.check(preview.contentHeight > preview.height, "Short windows must keep the preview scrollable");
                window.check(preview.y + preview.height <= studio.height, "Preview must stop above footer");
                preview.contentY = preview.contentHeight - preview.height;
                events.wait(20);
                window.check(preview.atYEnd, "Last preview controls must be reachable by scrolling");
                panel.width = 760;
                events.wait(20);
                window.check(!preview.visible, "Narrow panel must use the inline preview");
                panel.width = 1100; panel.height = 850; preview.contentY = 0;
                window.check(panel.prepareClose(), "Valid settings must flush when closing");
                console.log("SETTINGS_PANEL_TESTS_PASSED");
                var capture = Quickshell.env("SWITCH_MAGIC_TEST_CAPTURE");
                if (capture) {
                    panel.tab = Quickshell.env("SWITCH_MAGIC_TEST_TAB") || panel.tab;
                    events.wait(400);
                    panel.grabToImage(function(result) { result.saveToFile(capture); Qt.quit(); });
                    return;
                }
            } catch (error) { console.error("SETTINGS_PANEL_TESTS_FAILED: " + error); }
            Qt.quit();
        }
    }
}
