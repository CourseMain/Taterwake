#!/usr/bin/env python3
"""Bake the three short NPC utterances with eSpeak NG and Python's stdlib.

Source: eSpeak NG 1.52.0, https://github.com/espeak-ng/espeak-ng
Reference commit: 4870adfa25b1a32b4361592f1be8a40337c58d6c.
Only the single authored word "potato" is synthesized; no recordings or
proprietary system voices are used. eSpeak itself is not bundled with the game.

Usage:
  ESPEAK_DATA_PATH=/path/to/espeak/build python3 tools/generate_npc_potato_audio.py \
      --espeak /path/to/espeak/build/src/espeak-ng

The output is mono PCM16 at 22050 Hz, trimmed, lightly pitch-lifted, and faded.
NPC-specific pitch and sound volume are applied by the game at playback time.
"""

from __future__ import annotations

import argparse
import array
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import wave


VARIANTS = (
    # voice, speech pitch, words/minute, playback rate, phrase, expression
    ("en-us+f3", 65, 190, 1.05, "Potato!", "bright"),
    ("en-us+m3", 88, 160, 1.40, "Potato?", "curious"),
    ("en-us+f2", 60, 195, 1.07, "Potato.", "matter-of-fact"),
)


def load_pcm(path: Path) -> tuple[list[float], int]:
    with wave.open(str(path), "rb") as audio:
        assert audio.getnchannels() == 1 and audio.getsampwidth() == 2
        rate = audio.getframerate()
        samples = array.array("h", audio.readframes(audio.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    return [sample / 32768.0 for sample in samples], rate


def finish(samples: list[float], rate: int, speed: float) -> list[float]:
    # Retain the initial plosive and the quiet tail, without TTS sentence silence.
    active = [index for index, value in enumerate(samples) if abs(value) > 0.003]
    assert active, "Synthesizer returned silence"
    start = max(0, active[0] - round(rate * 0.012))
    end = min(len(samples), active[-1] + round(rate * 0.024))
    source = samples[start:end]
    output: list[float] = []
    position = 0.0
    while position < len(source) - 1:
        index = int(position)
        fraction = position - index
        output.append(source[index] * (1.0 - fraction) + source[index + 1] * fraction)
        position += speed

    # Remove DC, soften only the extreme high end, and keep comfortable headroom.
    dc = sum(output) / len(output)
    alpha = 1.0 - math.exp(-2.0 * math.pi * 6500.0 / rate)
    previous = 0.0
    for index, value in enumerate(output):
        previous += alpha * (value - dc - previous)
        output[index] = previous
    gain = 0.78 / max(abs(value) for value in output)
    attack = round(rate * 0.006)
    release = round(rate * 0.018)
    for index, value in enumerate(output):
        fade = min(1.0, index / attack, (len(output) - 1 - index) / release)
        output[index] = value * gain * max(0.0, fade)
    return output


def write_pcm(path: Path, samples: list[float], rate: int) -> None:
    pcm = array.array("h", (round(value * 32767) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--espeak", default="espeak-ng")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "assets/audio")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tater-voices-") as temporary:
        raw = Path(temporary) / "raw.wav"
        for number, (voice, pitch, speed, playback, phrase, expression) in enumerate(VARIANTS, 1):
            subprocess.run(
                [args.espeak, "-D", "-v", voice, "-p", str(pitch), "-s", str(speed), "-a", "100", "-w", str(raw), phrase],
                check=True,
            )
            samples, rate = load_pcm(raw)
            samples = finish(samples, rate, playback)
            duration = len(samples) / rate
            assert 0.30 <= duration <= 0.75, f"Unexpected duration: {duration}"
            output = args.output / f"npc-potato-{number}.wav"
            write_pcm(output, samples, rate)
            print(f"{output.name}: {expression}, {duration:.3f}s, peak {max(abs(x) for x in samples):.3f}, {rate}Hz")


if __name__ == "__main__":
    main()
