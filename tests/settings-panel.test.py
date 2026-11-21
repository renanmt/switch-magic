#!/usr/bin/env python3
"""Test settings interactions offscreen without writing desktop settings."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='switch-magic-settings-') as tmp:
    path = Path(tmp)
    for name in ['components', 'lib']:
        (path / name).symlink_to(ROOT / name)
    # Exercise the real host save boundary: QML var signals convert arrays to
    # QVariant lists. A mock that merely accepts the signal misses this bug.
    source = (ROOT / 'SwitchMagic.qml').read_text()
    save_function = source[source.index('    function saveSettings(next) {'):source.index('    function allWindows()')]
    (path / 'Fixtures.js').write_text(
        '.import "lib/Model.js" as Model\n.import "lib/ViewFields.js" as Fields\n'
        + 'var defaults = ' + (ROOT / 'defaults.json').read_text() + ';\n'
        + 'var config = Model.clone(defaults); var configError = "";\n'
        + 'var shell = {updateEntryInline: function(id, settings) { return true; }};\n'
        + save_function)

    shutil.copyfile(ROOT / 'tests/settings-panel.qml', path / 'shell.qml')
    result = subprocess.run(['quickshell', '-p', str(path), '--no-color'],
                            env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                            capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    if result.returncode or 'SETTINGS_PANEL_TESTS_PASSED' not in output or 'WARN scene:' in output:
        raise SystemExit(output)
    print('Settings: clipboard-safe fields, keyboard editing, validation, shortcuts, autosave, reset and studio scrolling passed.')
