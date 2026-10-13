#!/usr/bin/env python3
"""Compile a clipboard retrieval probe against installed Qt; no desktop access."""
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
flags = shlex.split(subprocess.check_output(
    ['pkg-config', '--cflags', '--libs', 'Qt6Quick', 'Qt6Test'], text=True))
with tempfile.TemporaryDirectory(prefix='switch-magic-clipboard-') as tmp:
    binary = str(Path(tmp) / 'clipboard-test')
    subprocess.run(['g++', '-std=c++17', '-fPIC', str(ROOT / 'tests/clipboard.test.cpp'),
                    '-o', binary, *flags], check=True, timeout=60)
    subprocess.run([binary, str(ROOT)], check=True, timeout=20)
