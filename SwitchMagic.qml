pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "components"
import "lib/Model.js" as Model
import "lib/ViewFields.js" as Fields

Item {
    id: root
    property var shell: null
    property bool registerShortcuts: true
    property var manifest: null
    property string omarchyPath: "/usr/share/omarchy"
    property bool opened: false
    property bool editing: false
    property bool demo: false
    property bool commitOnModifierRelease: false
    property string scope: "workspace"
    property var rows: []
    property int selected: 0
    property var context: ({})
    property var focusOrder: []
    property string pendingFocus: ""
    property var displayScreen: null
    property var defaults: ({})
    property var config: ({})
    property string configError: ""
    readonly property string bindingError: automaticBindings.item ? automaticBindings.item.error : ""
    Loader { id: automaticBindings; active: root.registerShortcuts; sourceComponent: Component { AutomaticBindings {} } }
    property string overrideLayout: ""
    readonly property bool ready: !!config.profiles && !!config.views
    readonly property var profile: ready ? config.profiles[scope] : ({view: "carousel", preview: "live"})
    readonly property string viewId: overrideLayout || profile.view
    readonly property var activeView: ready ? Model.view(config, viewId) : null
    readonly property string layoutName: activeView ? activeView.engine : "carousel"
    readonly property var layout: activeView ? activeView.geometry : ({})
    readonly property var animation: activeView ? activeView.animation : ({enabled: false, duration: 0, easing: "outCubic"})
    readonly property string captureMode: profile.preview === "view" && activeView ? activeView.preview : profile.preview
    readonly property int motion: animation.enabled ? animation.duration : 0
    readonly property int easing: animation.easing === "outBack" ? Easing.OutBack : animation.easing === "outQuint" ? Easing.OutQuint : animation.easing === "linear" ? Easing.Linear : Easing.OutCubic
    readonly property var themeColors: ({
        surface: Color.menu.background, text: Color.menu.text, muted: Color.muted,
        accent: activeView && activeView.scene.accent !== "theme" ? activeView.scene.accent : Color.accent
    })
    property real reveal: 1
    onOpenedChanged: if (opened && !editing) entrance.restart()
    NumberAnimation { id: entrance; target: root; property: "reveal"; from: 0; to: 1; duration: root.animation.enabled ? root.animation.entryDuration || 0 : 0; easing.type: root.easing }
    readonly property string scopeLabel: scope === "workspace" ? "Current workspace" : scope === "monitor" ? "This monitor" : scope === "spaces" ? "Spaces on this monitor" : "All workspaces"
    readonly property string fontFamily: Style.font.menuFamily
    readonly property var geometry: ready ? Model.metrics(layoutName, layout, rows.length, Math.max(280, panel.width - 100), Math.max(180, panel.height - 300)) : ({width: 1, height: 1, scale: 1, columns: 1, capacity: 1})

    FileView {
        id: defaultFile
        path: Qt.resolvedUrl("defaults.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.defaults = JSON.parse(text());
            root.loadSettings();
        }
    }
    FileView {
        id: shellFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loadSettings()
    }
    function loadSettings() {
        if (!defaults.profiles) return;
        try {
            var data = JSON.parse(shellFile.text() || "{}");
            var entry = (data.plugins || []).find(function(p) { return p.id === "renanmt.switch-magic"; }) || {};
            var next = Model.normalize(defaults, entry);
            var errors = Model.validate(next, defaults, Fields.groups);
            if (errors.length) throw new Error(errors.join("; "));
            config = next;
            configError = "";
        } catch (e) {
            if (!ready) config = Model.clone(defaults);
            configError = String(e);
            console.warn("Switch Magic: retaining last valid settings:", configError);
        }
    }
    function saveSettings(next) {
        var errors = Model.validate(next, defaults, Fields.groups);
        if (errors.length) { configError = errors.join("; "); return false; }
        if (JSON.stringify(next) === JSON.stringify(config)) { configError = ""; return true; }
        if (!shell || !shell.updateEntryInline) { configError = "Settings can be saved when running inside Omarchy."; return false; }
        if (!shell.updateEntryInline("renanmt.switch-magic", Model.persisted(next))) { configError = "Omarchy could not save settings."; return false; }
        config = Model.clone(next); configError = ""; return true;
    }
    function allWindows() {
        return Hyprland.toplevels.values.map(function(w) {
            var ipc = w.lastIpcObject || {}, workspace = w.workspace;
            return {
                address: w.address, title: w.title, appId: ipc.class || (w.wayland ? w.wayland.appId : ""),
                workspaceId: workspace ? workspace.id : -1, workspaceName: workspace ? workspace.name : "?",
                monitorId: w.monitor ? w.monitor.id : ipc.monitor,
                special: workspace ? workspace.id < 0 : true,
                mapped: ipc.mapped !== false, hidden: !!ipc.hidden, pinned: !!ipc.pinned,
                rank: root.focusOrder.indexOf(w.address) >= 0 ? root.focusOrder.indexOf(w.address) : root.focusOrder.length + (typeof ipc.focusHistoryID === "number" && ipc.focusHistoryID >= 0 ? ipc.focusHistoryID : 1e9)
            };
        });
    }
    function allWorkspaces() {
        var windows = allWindows();
        return Hyprland.workspaces.values.map(function(workspace) {
            var members = windows.filter(function(window) { return window.workspaceId === workspace.id && window.mapped && !window.hidden && !window.special; });
            var monitorId = workspace.monitor ? workspace.monitor.id : -1;
            var name = String(workspace.name || workspace.id);
            return { id: workspace.id, name: name, monitorId: monitorId, active: !!workspace.active, special: name === "special" || name.indexOf("special:") === 0, target: workspace, windows: members };
        });
    }
    function captureFor(address) {
        // Reading values establishes a reactive dependency when a window closes.
        var items = Hyprland.toplevels.values;
        for (var i = 0; i < items.length; ++i) if (items[i].address === address) return items[i].wayland;
        return null;
    }
    function screenForFocus() {
        var monitor = Hyprland.focusedMonitor;
        return Quickshell.screens.find(function(s) { return monitor && s.name === monitor.name; }) || Quickshell.screens[0];
    }
    function begin(nextScope, modifierRelease) {
        if (!ready || editing) return;
        if (opened && scope === nextScope) { step(1); return; }
        if (!opened) {
            var monitor = Hyprland.focusedMonitor;
            var workspace = Hyprland.focusedWorkspace;
            context = { monitorId: monitor ? monitor.id : -1, workspaceId: workspace ? workspace.id : -1 };
            displayScreen = screenForFocus();
        }
        demo = false; overrideLayout = ""; scope = nextScope; commitOnModifierRelease = !!modifierRelease;
        if (scope === "spaces") {
            rows = Model.selectWorkspaces(allWorkspaces(), context.monitorId);
            selected = Math.max(0, rows.findIndex(function(workspace) { return workspace.active; }));
        } else {
            rows = Model.selectWindows(allWindows(), scope, context, config.behavior.includeSpecial);
            selected = Model.initialIndex(rows, Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "");
        }
        opened = true;
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }
    function step(delta) {
        if (!opened || editing || !rows.length) return;
        selected = Model.wrap(selected + delta, rows.length);
    }
    function close() { if (editing && preferencesLoader.item && !preferencesLoader.item.prepareClose()) return; opened = false; editing = false; demo = false; commitOnModifierRelease = false; rows = []; overrideLayout = ""; }
    function commit() {
        if (!opened || editing || demo) return;
        if (scope === "spaces") {
            var selectedSpace = rows[selected];
            close();
            if (selectedSpace && Number.isInteger(selectedSpace.id)) selectedSpace.target.activate();
            return;
        }
        var address = rows[selected] ? rows[selected].address : "";
        // Only use validated compositor addresses in a dispatcher expression.
        var exists = Hyprland.toplevels.values.some(function(w) { return w.address === address; });
        close();
        if (exists && /^(0x)?[0-9a-fA-F]+$/.test(address)) {
            var full = address.indexOf("0x") === 0 ? address : "0x" + address;
            pendingFocus = full;
            focusAfterUnmap.restart();
        }
    }
    Timer {
        id: focusAfterUnmap
        interval: 35
        onTriggered: {
            // Let the exclusive layer unmap before requesting window focus.
            // Otherwise Hyprland can restore the old focus after our request.
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + root.pendingFocus + '" })']);
            root.pendingFocus = "";
        }
    }
    function reconcile() {
        if (!opened || editing || demo) return;
        if (scope === "spaces") {
            var selectedId = rows[selected] ? rows[selected].id : -1;
            rows = Model.selectWorkspaces(allWorkspaces(), context.monitorId);
            var nextIndex = rows.findIndex(function(workspace) { return workspace.id === selectedId; });
            selected = nextIndex >= 0 ? nextIndex : Math.max(0, Math.min(selected, rows.length - 1));
            return;
        }
        var result = Model.remaining(rows, Hyprland.toplevels.values.map(function(w) { return w.address; }), selected);
        rows = result.windows; selected = result.index;
    }
    function settings() {
        displayScreen = screenForFocus(); rows = []; opened = true; editing = true; demo = false;
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }
    function preview(name) {
        if (!Model.view(config, name)) return "unknown layout";
        begin("all"); demo = true; overrideLayout = name;
        return "ok";
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.reconcile(); }
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.reconcile(); }
    }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            var active = Hyprland.activeToplevel;
            if (!active) return;
            var address = active.address;
            root.focusOrder = [address].concat(root.focusOrder.filter(function(a) { return a !== address; })).slice(0, 512);
        }
        function onRawEvent(event) {
            if (event.name === "closewindow") Qt.callLater(root.reconcile);
            if (event.name === "monitorremoved") root.close();
        }
    }
    Loader {
        active: root.registerShortcuts
        sourceComponent: Component {
            Item {
    GlobalShortcut { appid: "switch-magic"; name: "monitor"; description: "Switch Magic: current monitor"; onPressed: root.begin("monitor") }
    GlobalShortcut { appid: "switch-magic"; name: "all"; description: "Switch Magic: all workspaces"; onPressed: root.begin("all") }
    GlobalShortcut { appid: "switch-magic"; name: "spaces"; description: "Switch Magic: workspace overview"; onPressed: root.begin("spaces") }
    GlobalShortcut { appid: "switch-magic"; name: "workspace-chord"; description: "Switch Magic: current workspace"; onPressed: root.begin("workspace", true) }
    GlobalShortcut { appid: "switch-magic"; name: "commit"; description: "Switch Magic: release Alt"; onPressed: root.commit() }
            }
        }
    }
    IpcHandler {
        target: "switch-magic"
        function show(scope: string): string { if (["workspace", "monitor", "all", "spaces"].indexOf(scope) < 0) return "unknown scope"; root.begin(scope); return "ok"; }
        function next(): string { root.step(1); return "ok"; }
        function previous(): string { root.step(-1); return "ok"; }
        function accept(): string { root.commit(); return "ok"; }
        function cancel(): string { root.close(); return "ok"; }
        function settings(): string { root.settings(); return "ok"; }
        function preview(layout: string): string { return root.preview(layout); }
        function state(): string { return JSON.stringify({ opened: root.opened, editing: root.editing, scope: root.scope, layout: root.layoutName, view: root.viewId, preview: root.captureMode, count: root.rows.length, selected: root.selected, addresses: root.scope === "spaces" ? [] : root.rows.map(function(w) { return w.address; }), workspaces: root.scope === "spaces" ? root.rows.map(function(w) { return w.name; }) : [], error: root.bindingError || root.configError }); }
        function configuration(): string { return JSON.stringify(Model.persisted(root.config)); }
        function configure(json: string): string {
            try { var next = Model.merge(root.config, JSON.parse(json)); return root.saveSettings(next) ? "ok" : root.configError; }
            catch (e) { return String(e); }
        }
    }
    PanelWindow {
        id: panel
        visible: root.opened
        screen: root.displayScreen || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "switch-magic"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle { anchors.fill: parent; color: Qt.alpha(Color.background, root.activeView ? root.activeView.scene.dimOpacity : 0.84) }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
        Item {
            id: keyCatcher
            anchors.fill: parent; focus: true
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) root.close();
                else if (!root.editing && event.key === Qt.Key_F2) root.settings();
                else if (!root.editing && (event.key === Qt.Key_Left || (event.key === Qt.Key_Backtab && !(event.modifiers & Qt.AltModifier)))) root.step(-1);
                else if (!root.editing && event.key === Qt.Key_Right) root.step(1);
                else if (!root.editing && event.key === Qt.Key_Up) root.step(root.layoutName === "grid" ? -root.geometry.columns : -1);
                else if (!root.editing && event.key === Qt.Key_Down) root.step(root.layoutName === "grid" ? root.geometry.columns : 1);
                else if (!root.editing && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) { if (root.demo) root.close(); else root.commit(); }
                else if (!root.editing && event.key === Qt.Key_Tab) {
                    // Hyprland owns all Alt+Tab chords. Handling the same
                    // key here can advance twice as the layer gains focus.
                    if (!(event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))) root.step(1);
                }
                event.accepted = !root.editing || event.key === Qt.Key_Escape;
            }
            Keys.onReleased: function(event) {
                // Alt release is owned by bindings.lua, including dual-Alt.
                // Consuming here prevents keys leaking into the underlying app.
                if (root.commitOnModifierRelease && (event.key === Qt.Key_Control || event.key === Qt.Key_Meta)) root.commit();
                event.accepted = true;
            }
            Item {
                id: composition
                visible: !root.editing && root.ready
                anchors.centerIn: parent
                width: parent.width
                height: root.geometry.height * root.geometry.scale + headingColumn.height + 121
                opacity: root.reveal
                scale: root.activeView ? root.activeView.animation.entryScale + (1 - root.activeView.animation.entryScale) * root.reveal : 1
                Column {
                    id: headingColumn
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                    Brand {
                        visible: !root.config.behavior || root.config.behavior.showLogo
                        anchors.horizontalCenter: parent.horizontalCenter
                        themeColors: root.themeColors; fontFamily: root.fontFamily
                        textSize: root.activeView ? root.activeView.scene.headerSize : 18
                        sparkleSize: root.activeView ? root.activeView.scene.logoSize : 30
                        tracking: root.activeView ? root.activeView.scene.headerTracking : 4
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                        Text { text: root.scopeLabel; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 12 }
                        Text { text: "·"; color: root.themeColors.accent; font.pixelSize: 12 }
                        Text { text: root.rows.length + (root.rows.length === 1 ? (root.scope === "spaces" ? " space" : " window") : (root.scope === "spaces" ? " spaces" : " windows")); color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 12 }
                    }
                }
                Item {
                    id: stage
                    y: headingColumn.height + 24; anchors.horizontalCenter: parent.horizontalCenter
                    width: root.geometry.width; height: root.geometry.height
                    scale: root.geometry.scale; transformOrigin: Item.Top
                    Repeater {
                        model: root.scope === "spaces" ? [] : root.rows
                        WindowCard {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property var place: Model.placement(root.layoutName, root.layout, index, root.selected, root.rows.length, root.geometry)
                            x: place.x; y: place.y; width: place.width; height: place.height
                            rotation: place.rotation; scale: place.scale; z: place.z; opacity: place.opacity
                            enabled: place.visible
                            transformOrigin: Item.Bottom
                            windowInfo: modelData
                            visible: root.scope !== "spaces" && opacity > 0.01
                            themeColors: root.themeColors
                            captureTarget: root.captureFor(modelData.address)
                            selected: index === root.selected
                            compact: root.layoutName === "list"
                            capturing: root.opened && !root.editing && place.visible
                            hoverSelect: root.config.behavior.hoverSelect
                            previewMode: root.captureMode
                            style: root.activeView.card
                            duration: root.motion
                            fontFamily: root.fontFamily
                            onPicked: { root.selected = index; if (!root.demo) root.commit(); }
                            onHovered: root.selected = index
                            Behavior on x { NumberAnimation { duration: root.animation.position ? root.motion : 0; easing.type: root.easing } }
                            Behavior on y { NumberAnimation { duration: root.animation.position ? root.motion : 0; easing.type: root.easing } }
                            Behavior on rotation { NumberAnimation { duration: root.animation.rotation ? root.motion : 0; easing.type: root.easing } }
                            Behavior on scale { NumberAnimation { duration: root.animation.scale ? root.motion : 0; easing.type: root.easing } }
                            Behavior on opacity { NumberAnimation { duration: root.animation.opacity ? root.motion : 0 } }
                        }
                    }
                    Repeater {
                        model: root.scope === "spaces" ? root.rows : []
                        SpaceCard {
                            required property var modelData
                            required property int index
                            readonly property var place: Model.placement(root.layoutName, root.layout, index, root.selected, root.rows.length, root.geometry)
                            x: place.x; y: place.y; width: place.width; height: place.height
                            rotation: place.rotation; scale: place.scale; z: place.z; opacity: place.opacity
                            visible: opacity > 0.01
                            enabled: place.visible
                            transformOrigin: Item.Bottom
                            compact: root.layoutName === "list"
                            hoverSelect: root.config.behavior.hoverSelect
                            workspace: modelData
                            themeColors: root.themeColors
                            style: root.activeView.card
                            previewMode: root.captureMode
                            captureFor: function(address) { return root.captureFor(address); }
                            selected: index === root.selected
                            duration: root.motion
                            fontFamily: root.fontFamily
                            onPicked: { root.selected = index; root.commit(); }
                            onHovered: root.selected = index
                            Behavior on x { NumberAnimation { duration: root.animation.position ? root.motion : 0; easing.type: root.easing } }
                            Behavior on y { NumberAnimation { duration: root.animation.position ? root.motion : 0; easing.type: root.easing } }
                            Behavior on rotation { NumberAnimation { duration: root.animation.rotation ? root.motion : 0; easing.type: root.easing } }
                            Behavior on scale { NumberAnimation { duration: root.animation.scale ? root.motion : 0; easing.type: root.easing } }
                            Behavior on opacity { NumberAnimation { duration: root.animation.opacity ? root.motion : 0 } }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: !root.rows.length; text: root.scope === "spaces" ? "No workspaces on this monitor" : "No windows in this scope"; color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 20 }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.geometry.height * root.geometry.scale + stage.y + 21
                    spacing: 18
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                        Repeater {
                            model: Math.min(root.rows.length, 15)
                            Rectangle {
                                required property int index
                                width: index === root.selected % 15 ? 22 : 5; height: 5; radius: 3
                                color: index === root.selected % 15 ? root.themeColors.accent : Qt.alpha(root.themeColors.text, 0.18)
                                Behavior on width { NumberAnimation { duration: root.motion } }
                            }
                        }
                        Text { visible: root.rows.length > 15; text: (root.selected + 1) + " / " + root.rows.length; color: root.themeColors.muted; font.pixelSize: 10 }
                    }
                    Text {
                        visible: root.activeView && root.activeView.scene.showHints
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.demo ? "LAYOUT PREVIEW     ← → browse     Esc close" : "HOLD ALT    ·    TAB browse    ·    ← → navigate    ·    RELEASE to switch    ·    F2 customize"
                        color: root.themeColors.muted; font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 0.6
                    }
                }
            }
            Loader {
                id: preferencesLoader
                anchors.centerIn: parent
                active: root.editing && root.ready
                sourceComponent: Component {
                    SettingsPanel {
                        width: Math.min(1100, panel.width - 48)
                        height: Math.min(850, panel.height - 48)
                        screenWidth: panel.width; screenHeight: panel.height
                        config: root.config; themeColors: root.themeColors; fontFamily: root.fontFamily
                        error: root.bindingError || root.configError
                        onSave: function(next) { saveCompleted(root.saveSettings(next)); }
                        onDismiss: root.close()
                    }
                }
            }
        }
    }
}
