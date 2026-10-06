TATERLAND — BROWSER EDITION
Built from the game's Web preset using Godot 4.7.2.stable.

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
WASD moves your farmer. Click beds and shops to interact; hold and drag
the farm to pan the camera. Keys 1–5 select farm tools.
I opens inventory, F meets Mara to buy or sell, and Esc opens Menu.
Meet the keepers before entering their services.
Touch: drag the stick to move (outer edge sprints), tap the farm to interact,
and pinch with two fingers to zoom. Tools holds tools, seeds and zoom +/-.
Swipe menus to scroll. Full screen or F11 expands the game; unsupported
mobile browsers explain the Add to Home Screen option.

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
Atkinson Hyperlegible and Noto Sans Symbols 1/2 use the SIL Open
Font License. Slackey uses Apache 2.0. Their complete licenses are included in the
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
