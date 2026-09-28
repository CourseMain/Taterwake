#!/usr/bin/env python3
"""Build and open a disposable browser climate lab; never load a player's farm."""
from pathlib import Path
import argparse
import subprocess
import sys
from export_web import find_engine
from serve_web import main as serve

root = Path(__file__).resolve().parent.parent
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', choices=['climate'], default='climate')
    fixture = parser.parse_args().fixture
    subprocess.run([
        sys.executable, str(root / 'tools/export_browser_benchmark.py'),
        '--godot', str(find_engine()), '--label', fixture, '--fixture', fixture,
    ], check=True)
    raise SystemExit(serve([
        '--directory', str(root / f'artifacts/browser-benchmark-{fixture}-web'),
        '--port', '8093', '--open',
    ]))
