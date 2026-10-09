pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    property string error: ""
    required property string bindingCode
    property string appliedCode: ""
    property string installingCode: ""
    onBindingCodeChanged: refresh()
    readonly property string owner: "sm-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    property string program: ""
    property bool migrated: false
    property bool shuttingDown: false
    readonly property string detachCode: "local s=_G.__switch_magic_runtime_v1; if s and s.owner==" + JSON.stringify(owner) + " then s:stop(true) end"
    function refresh() {
        if (!migrated || !program || !bindingCode || install.running || reload.running || shuttingDown) return;
        // Restore saved actions for shortcuts that were removed before taking
        // ownership of the new set. A config reload also clears Lua callbacks.
        if (appliedCode && appliedCode !== bindingCode) {
            appliedCode = "";
            reload.running = true;
            return;
        }
        installingCode = bindingCode;
        install.command = ["hyprctl", "eval", "assert(load(" + JSON.stringify(program) + "))(" + JSON.stringify(owner) + "," + installingCode + ")"];
        install.running = true;
    }
    FileView {
        path: Qt.resolvedUrl("../runtime/bindings.lua")
        onLoaded: { root.program = text(); root.refresh(); }
    }
    Process {
        id: migration
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../scripts/migrate-bindings.py").toString().replace(/^file:\/\//, ""))]
        running: true
        stdout: StdioCollector { id: migrationOut }
        stderr: StdioCollector { id: migrationError }
        onExited: function(code, status) {
            if (code !== 0) { root.error = migrationError.text.trim() || "Could not migrate the old shortcut setup."; return; }
            if (migrationOut.text.trim() === "migrated") reload.running = true;
            else { root.migrated = true; root.refresh(); }
        }
    }
    Process {
        id: reload
        command: ["hyprctl", "reload", "config-only"]
        onExited: function(code, status) {
            if (code !== 0) { root.error = "Could not reload the migrated shortcut configuration."; return; }
            root.migrated = true; afterReload.restart();
        }
    }
    Process {
        id: install
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: stderrOutput }
        onExited: function(code, status) {
            root.error = code === 0 && output.text.trim() === "ok" ? "" : (stderrOutput.text.trim() || output.text.trim() || "Could not register Switch Magic shortcuts.");
            if (!root.error) root.appliedCode = root.installingCode;
            if (root.bindingCode !== root.installingCode) Qt.callLater(root.refresh);
        }
    }
    Timer { id: afterReload; interval: 150; onTriggered: root.refresh() }
    Timer { interval: 2000; repeat: true; running: root.migrated; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") afterReload.restart(); }
    }
    Component.onDestruction: {
        root.shuttingDown = true;
        Quickshell.execDetached(["hyprctl", "eval", root.detachCode]);
    }
}
