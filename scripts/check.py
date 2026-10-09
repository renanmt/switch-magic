#!/usr/bin/env python3
"""Local checks, without altering the desktop."""
import json
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parent.parent
for path in ROOT.glob('*.json'):
    json.loads(path.read_text())
subprocess.run(['node', 'tests/model.test.cjs'], cwd=ROOT, check=True)
subprocess.run(['lua', 'tests/bindings.test.lua'], cwd=ROOT, check=True)
subprocess.run(['python', 'tests/space-card.test.py'], cwd=ROOT, check=True)
subprocess.run(['luac', '-p', 'runtime/bindings.lua'], cwd=ROOT, check=True)
subprocess.run(['python', 'tests/installer.test.py'], cwd=ROOT, check=True)
subprocess.run(['python', 'tests/migration.test.py'], cwd=ROOT, check=True)
subprocess.run(['omarchy', 'plugin', 'validate', str(ROOT)], check=True)
# qmlformat parses without executing and avoids qmllint's unresolved internal
# Quickshell metadata warnings. Actual rendering is checked in the live host.
for path in [ROOT / 'SwitchMagic.qml', *sorted((ROOT / 'components').glob('*.qml'))]:
    subprocess.run(['/usr/lib/qt6/bin/qmlformat', str(path)], stdout=subprocess.DEVNULL, check=True)
print('JSON, behavior, Lua syntax, manifest, and QML parsing checks passed.')
