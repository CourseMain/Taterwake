"""Encode the offline-authored nature beds and wind at 96 kbps Vorbis."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
NAMES = [f"nature-{kind}" for kind in ("breeze", "leaves", "stream", "rain", "hush", "cicadas")] + ["climate-wind"]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ffmpeg", default="ffmpeg")
parser.add_argument("--source", type=Path, default=ROOT / "artifacts/audio-source")
args = parser.parse_args()
for name in NAMES:
    source = args.source / (name + ".wav")
    target = ROOT / "assets/audio" / (name + ".ogg")
    subprocess.run([args.ffmpeg, "-y", "-v", "error", "-i", str(source), "-map_metadata", "-1", "-ar", "44100", "-c:a", "libvorbis", "-b:a", "96k", str(target)], check=True)
    print(f"{name}: {target.stat().st_size:,} bytes")
