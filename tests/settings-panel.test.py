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
    (path / 'Fixtures.js').write_text('var defaults = ' + (ROOT / 'defaults.json').read_text() + ';\n')
    shutil.copyfile(ROOT / 'tests/settings-panel.qml', path / 'shell.qml')
    result = subprocess.run(['quickshell', '-p', str(path), '--no-color'],
                            env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                            capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    if result.returncode or 'SETTINGS_PANEL_TESTS_PASSED' not in output or 'WARN scene:' in output:
        raise SystemExit(output)
    print('Settings: branding, custom shortcuts, conflict confirmation, autosave, reset and studio scrolling passed.')
