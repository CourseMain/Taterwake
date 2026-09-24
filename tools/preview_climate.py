#!/usr/bin/env python3
"""Build and open a disposable browser climate lab; never load a player's farm."""
from pathlib import Path
import subprocess
import sys
from export_web import find_engine
from serve_web import main as serve

root = Path(__file__).resolve().parent.parent
if __name__ == '__main__':
    subprocess.run([
        sys.executable, str(root / 'tools/export_browser_benchmark.py'),
        '--godot', str(find_engine()), '--label', 'climate', '--fixture', 'climate',
    ], check=True)
    raise SystemExit(serve([
        '--directory', str(root / 'artifacts/browser-benchmark-climate-web'),
        '--port', '8093', '--open',
    ]))
