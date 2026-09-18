#!/usr/bin/env python3
"""Export the Web preset and package a self-contained, shareable game folder."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

PROJECT = Path(__file__).resolve().parent.parent
PRESET = "Web"
ERROR_LINE = re.compile(r"(?im)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|Compile Error:)")
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
WEB_SUFFIXES = {".html", ".js", ".mjs", ".wasm", ".pck", ".png", ".svg", ".ico", ".json", ".webmanifest", ".css", ".webp", ".woff", ".woff2", ".ttf", ".ogg", ".mp3", ".wav"}


class BuildError(RuntimeError):
    pass


def find_engine(explicit: str | None = None) -> Path:
    selected = explicit or os.environ.get("GODOT_BIN")
    if selected:
        resolved = shutil.which(selected) or str(Path(selected).expanduser())
        engine = Path(resolved).resolve()
        if not engine.is_file() or not os.access(engine, os.X_OK):
            raise BuildError(f"GODOT_BIN is not an executable Godot binary: {engine}")
        return engine
    candidates = [
        PROJECT / ".tools/Godot.app/Contents/MacOS/Godot",
        PROJECT / ".tools/godot-web-engine/Godot.app/Contents/MacOS/Godot",
    ]
    candidates.extend(Path(path) for name in ("godot", "godot4") if (path := shutil.which(name)))
    candidates.extend([
        Path("/Applications/Godot.app/Contents/MacOS/Godot"),
        # Preserve the original local checkout's launcher after renaming.
        PROJECT.parent / "maths/.tools/Godot.app/Contents/MacOS/Godot",
    ])
    for engine in candidates:
        if engine.is_file() and os.access(engine, os.X_OK):
            return engine.resolve()
    raise BuildError("Godot was not found. Set GODOT_BIN to the Godot executable used by this project.")


def run_engine(engine: Path, arguments: list[str], timeout: int = 300) -> str:
    try:
        result = subprocess.run(
            [str(engine), *arguments], cwd=PROJECT,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise BuildError(f"Godot did not finish within {timeout} seconds.") from error
    output = ANSI_ESCAPE.sub("", result.stdout)
    if result.returncode != 0 or ERROR_LINE.search(output):
        raise BuildError(f"Godot reported an export error (exit {result.returncode}):\n{output.strip()}")
    return output.strip()


def engine_release(engine: Path) -> str:
    output = run_engine(engine, ["--version"], timeout=30)
    for line in output.splitlines():
        match = re.match(r"^(\d+\.\d+(?:\.\d+)?\.[A-Za-z][A-Za-z0-9]*)(?:\.|$)", line.strip())
        if match:
            return match.group(1)
    raise BuildError(f"Could not read the Godot release from --version:\n{output}")


def preset_options() -> dict[str, str]:
    path = PROJECT / "export_presets.cfg"
    if not path.is_file():
        raise BuildError("export_presets.cfg is missing; the project needs a Web export preset.")
    # Only simple Web values matter here; other presets may contain Godot
    # multiline scripts and Variant expressions that are not Python INI values.
    sections: dict[str, dict[str, str]] = {}
    section = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        header = re.match(r"^\[([^]]+)\]\s*$", line.strip())
        if header:
            section = header.group(1)
            sections.setdefault(section, {})
            continue
        entry = re.match(r"^([A-Za-z0-9_/]+)\s*=\s*(.*?)\s*$", line.strip())
        if entry and section:
            sections[section][entry.group(1)] = entry.group(2)
    for section, values in sections.items():
        if re.fullmatch(r"preset\.\d+", section) and unquote(values.get("name", '""')) == PRESET:
            if unquote(values.get("platform", '""')) != "Web":
                raise BuildError("The preset named Web is not a Web-platform preset.")
            return sections.get(section + ".options", {})
    raise BuildError('No export preset named "Web" was found.')


def unquote(value: str) -> str:
    if value.startswith('"'):
        try:
            return str(json.loads(value))
        except json.JSONDecodeError as error:
            raise BuildError(f"Invalid string in Web export options: {value}") from error
    return value


def template_roots(engine: Path) -> list[Path]:
    roots: list[Path] = []
    for directory in (engine.parent, *list(engine.parents)[:4]):
        if (directory / "_sc_").exists() or (directory / "._sc_").exists():
            roots.append(directory / "editor_data/export_templates")
    if sys.platform == "darwin":
        roots.append(Path.home() / "Library/Application Support/Godot/export_templates")
    elif os.name == "nt":
        roots.append(Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming"))) / "Godot/export_templates")
    else:
        roots.append(Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/export_templates")
    return roots


def verify_template(engine: Path, release: str, options: dict[str, str]) -> Path:
    custom = unquote(options.get("custom_template/release", '""')).strip()
    if custom:
        path = Path(custom.removeprefix("res://")).expanduser()
        if not path.is_absolute():
            path = PROJECT / path
        candidates = [path.resolve()]
    else:
        # Same naming rule as Godot's Web export plugin: extension and thread
        # variants are different binaries, not interchangeable templates.
        name = "web"
        if options.get("variant/extensions_support", "false").lower() == "true":
            name += "_dlink"
        if options.get("variant/thread_support", "false").lower() != "true":
            name += "_nothreads"
        name += "_release.zip"
        candidates = [root / release / name for root in template_roots(engine)]
    for candidate in candidates:
        if not candidate.is_file():
            continue
        try:
            with zipfile.ZipFile(candidate) as archive:
                names = archive.namelist()
                if not all(any(name.endswith(extension) for name in names) for extension in (".wasm", ".js", ".html")):
                    raise BuildError(f"The selected Web template is incomplete: {candidate}")
                if any(Path(name).is_absolute() or ".." in Path(name).parts for name in names):
                    raise BuildError(f"The selected template has an invalid archive path: {candidate}")
        except zipfile.BadZipFile as error:
            raise BuildError(f"The selected Web template is not a valid ZIP: {candidate}") from error
        return candidate
    locations = "\n".join(f"  {path}" for path in candidates)
    raise BuildError(f"Install the matching Godot {release} release Web export template. Expected:\n{locations}")


def verify_export(directory: Path) -> None:
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        path = directory / name
        if not path.is_file() or path.stat().st_size == 0:
            raise BuildError(f"Godot did not create the required nonempty file {name}.")
    with (directory / "index.wasm").open("rb") as wasm:
        if wasm.read(4) != b"\0asm":
            raise BuildError("The exported index.wasm has an invalid WebAssembly header.")
    for path in directory.rglob("*"):
        relative = path.relative_to(directory)
        if path.is_symlink() or any(part.startswith(".") for part in relative.parts):
            raise BuildError(f"Unexpected hidden or linked export output: {relative}")
        if path.is_file() and path.suffix.lower() not in WEB_SUFFIXES:
            raise BuildError(f"Unexpected non-Web file in export output: {relative}")


def package_readme(release: str) -> str:
    return f"""TATERLAND — BROWSER EDITION
Built from the game's Web preset using Godot {release}.

PLAY THIS DOWNLOAD
1. Extract the whole ZIP into one folder.
2. Double-click Play Web.command (macOS) or Play Web.bat (Windows).
3. Keep the terminal open while playing. Ctrl+C stops the preview.
   Python 3 is required for these local launchers.

Alternatively, open a terminal in the extracted folder and run:
  python3 serve.py --open
On Windows you can use: py -3 serve.py --open

The included server binds only to this computer (127.0.0.1). It starts at
port 8080 and tries the next local port if 8080 is busy.
Open the printed HTTP address; opening index.html as a file will not run
the game's WebAssembly assets correctly.

CONTROLS
Click to walk and use the selected tool. Keys 1–5 select farm tools.
I opens inventory, B market, C builds, R rolling, and Esc the menu.
The three-line menu contains the remaining panels and activities.

SAVES
Browser saves belong to this browser and address. Use the same localhost
port when returning to your farm. Browser and native-game saves are separate.
A private browser session or clearing site data can remove browser saves.

WEB HOSTING
The game files are static. Put index.html and all its supporting assets
at the same relative paths on a static HTTP/HTTPS host. serve.py is only
for local preview and is not a production hosting service.
The ZIP has index.html at its root for static game-host upload forms.

FONT LICENSES
Nunito Sans and Noto Sans Symbols 1/2 are distributed under the SIL Open
Font License. Their complete licenses are included in the three
LICENSE-*.txt files alongside this README.

ENGINE LICENSE
Godot Engine is provided under the MIT license. See LICENSE-Godot.txt
and COPYRIGHT-Godot.txt for the engine and its third-party notices.

SOURCE REBUILD
In the source project run: python3 tools/export_web.py
Or double-click Export Web.command on macOS.
Set GODOT_BIN to select another matching Godot executable. Keep that
engine's matching release Web export template installed, or configure
a custom release template in the Web export preset.
"""


def complete_offline_assets(directory: Path) -> None:
    """Include splash/installation artwork in Godot's generated PWA cache."""
    worker = directory / "index.service.worker.js"
    if not worker.is_file():
        return
    source = worker.read_text(encoding="utf-8")
    match = re.search(r"const CACHED_FILES = (\[[^\n]*\]);", source)
    if not match:
        raise BuildError("The Web service-worker template has changed; its offline asset list needs updating.")
    names = json.loads(match.group(1))
    for path in sorted(directory.iterdir()):
        if path.suffix == ".png" or path.name == "index.manifest.json":
            if path.name not in names:
                names.append(path.name)
    source = source[:match.start(1)] + json.dumps(names) + source[match.end(1):]
    worker.write_text(source, encoding="utf-8")


def add_launchers(directory: Path) -> None:
    mac = directory / "Play Web.command"
    mac.write_text('''#!/bin/zsh
set -u
web_folder="${0:A:h}"
cd "$web_folder" || exit 1
if ! command -v python3 >/dev/null 2>&1; then
  print 'Python 3 is required to preview this game locally.'
  read -r '?Press Return to close.'
  exit 1
fi
python3 "$web_folder/serve.py" --open
preview_status=$?
if (( preview_status != 0 )); then
  read -r '?Press Return to close.'
fi
exit "$preview_status"
''', encoding="utf-8")
    mac.chmod(0o755)
    (directory / "Play Web.bat").write_text('''@echo off
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 "%~dp0serve.py" --open
) else (
  python "%~dp0serve.py" --open
)
if errorlevel 1 (
  echo Python 3 is required to preview this game locally.
  pause
)
''', encoding="utf-8")


def build(engine: Path) -> tuple[Path, Path]:
    if not (PROJECT / "project.godot").is_file():
        raise BuildError(f"No Godot project in {PROJECT}.")
    release = engine_release(engine)
    template = verify_template(engine, release, preset_options())
    print(f"Godot: {engine}\nRelease: {release}\nWeb template: {template}", flush=True)
    distribution = PROJECT / "dist"
    distribution.mkdir(exist_ok=True)
    destination = distribution / "web"
    archive_destination = distribution / "Taterland-Web.zip"
    if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
        raise BuildError(f"Expected an ordinary export folder at {destination}.")
    with tempfile.TemporaryDirectory(prefix=".web-build-", dir=distribution) as temporary:
        scratch = Path(temporary)
        staging = scratch / "web"
        staging.mkdir()
        output = run_engine(engine, ["--headless", "--path", str(PROJECT), "--export-release", PRESET, str(staging / "index.html")])
        (distribution / "web-export.log").write_text(output + "\n", encoding="utf-8")
        verify_export(staging)
        complete_offline_assets(staging)
        shutil.copyfile(PROJECT / "tools/serve_web.py", staging / "serve.py")
        font_licenses = {
            "OFL.txt": "LICENSE-NunitoSans.txt",
            "OFL-NotoSymbols.txt": "LICENSE-NotoSansSymbols2.txt",
            "OFL-NotoSymbols1.txt": "LICENSE-NotoSansSymbols1.txt",
        }
        for source, packaged in font_licenses.items():
            shutil.copyfile(PROJECT / "assets/fonts" / source, staging / packaged)
        shutil.copyfile(PROJECT / "assets/licenses/Godot-LICENSE.txt", staging / "LICENSE-Godot.txt")
        shutil.copyfile(PROJECT / "assets/licenses/Godot-COPYRIGHT.txt", staging / "COPYRIGHT-Godot.txt")
        (staging / "README-WEB.txt").write_text(package_readme(release), encoding="utf-8")
        add_launchers(staging)
        archive_path = scratch / "Taterland-Web.zip"
        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(staging.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(staging).as_posix())
        backup = scratch / "previous-web"
        if destination.exists():
            destination.rename(backup)
        try:
            staging.rename(destination)
            archive_path.replace(archive_destination)
        except OSError:
            if destination.exists():
                shutil.rmtree(destination)
            if backup.exists():
                backup.rename(destination)
            raise
    return destination, archive_destination


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Godot executable; otherwise use GODOT_BIN, PATH, or a standard install location")
    args = parser.parse_args(argv)
    try:
        directory, archive = build(find_engine(args.godot))
    except (BuildError, OSError) as error:
        print(f"Web export failed: {error}", file=sys.stderr)
        return 1
    print(f"\nWeb build: {directory}\nShareable ZIP: {archive}")
    print("Preview: python3 tools/serve_web.py --open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
