#!/usr/bin/env python3
"""Render README images in an isolated session with fictional data; never capture the desktop."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'docs/images'
with tempfile.TemporaryDirectory(prefix='switch-magic-docs-') as directory:
    path = Path(directory)
    for name in ['components', 'lib', 'defaults.json']:
        (path / name).symlink_to(ROOT / name)
    commons = path / 'Commons'
    commons.mkdir()
    (commons / 'qmldir').write_text('module Commons\nsingleton Color 1.0 Color.qml\nsingleton Style 1.0 Style.qml\n')
    (commons / 'Color.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    readonly property color background: "#080c20"
    readonly property color accent: "#8586df"
    readonly property color muted: "#7c87ae"
    readonly property var menu: ({background: "#080c20", text: "#ffd0b0"})
}
''')
    (commons / 'Style.qml').write_text('''pragma Singleton
import QtQuick
QtObject { readonly property var font: ({menuFamily: "JetBrains Mono"}) }
''')
    (path / 'omarchy').mkdir()
    (path / 'omarchy/shell.json').write_text('{"plugins":[]}')
    titles = ['Design notes', 'Switch Magic — studio', 'Ideas worth exploring',
              'Project files', 'Build something beautiful', 'The next chapter']
    apps = ['org.gnome.TextEditor', 'code', 'firefox', 'org.gnome.Nautilus',
            'com.mitchellh.ghostty', 'org.gnome.TextEditor']
    windows = [dict(address=f'{i+1:08x}', title=title, appId=apps[i],
                    workspaceId=i//2+1, workspaceName=str(i//2+1), monitorId=0,
                    special=False, mapped=True, hidden=False, pinned=False, rank=i)
               for i, title in enumerate(titles)]
    source = (ROOT / 'SwitchMagic.qml').read_text()
    source = source.replace('id: root\n', 'id: root\n    property alias screenshotItem: keyCatcher\n    property alias preferences: preferencesLoader.item\n', 1)
    source = re.sub(r'    function allWindows\(\).*?    function screenForFocus\(\)',
                    '    function allWindows() { return ' + json.dumps(windows, ensure_ascii=False) + '; }\n'
                    '    function allWorkspaces() { return [1,2,3].map(function(id) { return {id:id, name:String(id), monitorId:0, active:id===2, special:false, windows:allWindows().filter(function(w){return w.workspaceId===id;})}; }); }\n'
                    '    function captureFor(address) { return null; }\n'
                    '    function screenForFocus()', source, flags=re.S)
    source = re.sub(r'context = \{ monitorId:.*?\};', 'context = {monitorId:0, workspaceId:1};', source)
    source = re.sub(r'^.*desktopBackdrop.prepare.*\n', '', source, flags=re.M)
    source = source.replace('anchors { top: true; bottom: true; left: true; right: true }', 'implicitWidth: 1440; implicitHeight: 900')
    source = source.replace('screen: root.displayScreen || Quickshell.screens[0]', 'screen: Quickshell.screens.slice().sort(function(a,b){return b.width-a.width;})[0]')
    source = source.replace('WlrLayershell.namespace: "switch-magic"', 'WlrLayershell.namespace: "switch-magic-docs"')
    source = source.replace('root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None', 'WlrKeyboardFocus.None')
    source = source.replace('color: "transparent"', 'color: Color.background', 1)
    source = source.replace('id: keyCatcher', 'id: keyCatcher\n            Rectangle { anchors.fill: parent; color: Color.background; z: -1 }')
    source = source.replace('id: card\n', 'id: card\n                            sample: true\n', 1)
    (path / 'SwitchMagic.qml').write_text(source)
    (path / 'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    id: harness
    property int scene: -1
    property var names: ["carousel", "grid", "fan", "list", "spaces", "views", "view-studio"]
    function updateEntryInline(id, patch) { return true; }
    SwitchMagic { id: service; registerShortcuts: false; shell: harness }
    Timer {
        interval: 600; running: true; repeat: true
        onTriggered: {
            if (!service.ready) return;
            stop(); harness.scene++;
            if (harness.scene === harness.names.length) { console.log("SCREENSHOTS_SAVED"); Qt.quit(); return; }
            var name = harness.names[harness.scene];
            service.close();
            if (name === "views" || name === "view-studio") {
                service.settings();
                service.preferences.tab = name === "views" ? "views" : "editor";
                if (name === "view-studio") {
                    service.preferences.editorId = "grid";
                    service.preferences.startCopy();
                    service.preferences.copyName = "Midnight gallery";
                    service.preferences.createView();
                    service.preferences.changeField("card.radius", 24);
                }
            } else if (name === "spaces") {
                service.config.profiles.spaces.preview = "icon"; service.begin("spaces");
            } else {
                service.preview(name); service.selected = 2;
            }
            captureTimer.start();
        }
        id: nextScene
    }
    Timer {
        id: captureTimer; interval: 600
        onTriggered: {
            var name = harness.names[harness.scene];
            var item = harness.scene >= 5 ? service.preferences : service.screenshotItem;
            item.grabToImage(function(result) {
                if (!result.saveToFile(Quickshell.env("SCREENSHOT_OUTPUT") + "/" + name + ".png")) throw new Error("Capture failed");
                nextScene.start();
            });
        }
    }
}
''')
    try:
        result = subprocess.run(['quickshell', '-p', str(path), '--no-color'],
                            env={**os.environ, 'QT_QPA_PLATFORM': 'wayland',
                                 'XDG_CONFIG_HOME': str(path), 'SCREENSHOT_OUTPUT': str(OUTPUT)},
                            capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired as error:
        raise SystemExit((error.stdout or b'').decode() + (error.stderr or b'').decode())
    log = result.stdout + result.stderr
    if result.returncode or 'SCREENSHOTS_SAVED' not in log or 'WARN scene:' in log or 'ERROR' in log:
        raise SystemExit(log)
    print('Rendered seven screenshots with fictional data.')
