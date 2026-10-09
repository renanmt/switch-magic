#!/usr/bin/env python3
"""Exercise actual workspace cards offscreen using only synthetic app data."""
import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='switch-magic-cards-') as tmp:
    path = Path(tmp)
    (path / 'components').symlink_to(ROOT / 'components')
    (path / 'Fixtures.js').write_text('var views = ' + json.dumps(json.loads((ROOT / 'defaults.json').read_text())['views']) + ';\n')
    shutil.copyfile(ROOT / 'tests/space-card.qml', path / 'shell.qml')
    applications = path / 'data/applications'
    applications.mkdir(parents=True)
    icon = path / 'icon.svg'
    icon.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
                    '<rect width="32" height="32" fill="#8888ff"/></svg>')
    (applications / 'switch-magic-test.desktop').write_text(
        '[Desktop Entry]\nType=Application\nName=Test App\nExec=true\nIcon=' + str(icon) + '\n')
    env = {**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'XDG_DATA_HOME': str(path / 'data'), 'XDG_DATA_DIRS': str(path / 'data')}
    result = subprocess.run(['quickshell', '-p', str(path), '--no-color'],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    if result.returncode or 'SPACE_CARD_TESTS_PASSED' not in output or 'WARN scene:' in output:
        raise SystemExit(output)
    print('Workspace cards: app icons, fallback initials, all layout dimensions and hover preference passed.')
