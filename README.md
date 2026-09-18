# Taterland

**[Play Taterland in your browser — no download needed](https://coursemain.github.io/Taterwake/)**

Open the link on a computer with a keyboard and mouse or trackpad. Allow the first load to finish, then start farming. Your browser saves your farm automatically; return with the same browser and address to continue.

**v1.0.0:** New farms begin with a gentle, interactive first-island tutorial. Grow and sell one harvest, meet every Valley helper, and learn the tools a little at a time. Pests wait for their protected practice lesson; stock surges wait until you finish. Existing players can choose **☰ → First island guided tour** while visiting the Valley.

Small potatoes. Big possibilities.

A 3D potato farming game about growing crops, riding wild markets and building your own kind of farmer. Start in Spud Valley, sail to Golden Shores, and chase frozen fortunes in Frosthollow.

- Work your fields with five manual tools; train ducks to chase pests.
- Time harvests around stock surges of up to **+3,000%**.
- Choose from **five player builds** and collect clothing with farming, market and mutation bonuses.
- Take buyer contracts, fire up a winter furnace, and discover rare rewards at the Roll House.
- Farm through a **60-second day–night cycle** across three islands.

The Roll House uses coins earned in the game. There are no real-money purchases.

## Download and play locally

For a local copy, use **Taterland-Web.zip** from a release, or [build it from source](#build-the-browser-edition) using the steps below. Extract the entire archive. On macOS, double-click **Play Web.command**; on Windows, double-click **Play Web.bat**. These local launchers need Python 3. Keep their terminal open while playing.

You can also run `python3 serve.py --open` from the extracted folder. Open the printed HTTP address instead of opening `index.html` directly.

Browser saves belong to your browser and the address you use. Return through the same localhost port to continue your farm. Browser saves are separate from desktop saves.

The complete game view scales to fit the window while keeping its proportions. Depending on your screen shape, borders may appear around the game. A keyboard and mouse or trackpad are required.

## Run the source

Use **Godot 4.7.2** with the Compatibility renderer. Import `project.godot` into Godot and press **F5**, or run:

```sh
godot --path .
```

On macOS, **Play Taterland.command** locates Godot automatically. Set `GODOT_BIN` if your engine is installed elsewhere.

## Controls

| Control | Action |
| --- | --- |
| WASD / arrow keys | Move |
| Click a bed | Walk over and use the selected tool |
| 1 / 2 / 3 / 4 / 5 | Hoe / seeds / water / harvest / pest sprayer |
| E / Space | Use the selected tool nearby |
| Trackpad scroll / pinch / mouse wheel | Zoom the map |
| I | Inventory and clothing |
| B / U / R | Market / tool upgrades / Roll House |
| F | Sell the selected crop |
| Escape / ☰ | Main menu and remaining activities |

Start by hoeing a bed, selecting seeds, planting and watering. Harvest a ripe crop, then sell it to buy your next round of seeds. Visit the toolsmith on each island for larger tool areas.

See the [gameplay guide](docs/GAMEPLAY.md) for builds, gear, prices, local activities and Debug controls.

## Build the browser edition

Install the Web export templates matching your Godot version, then run:

```sh
python3 tools/export_web.py
python3 tools/serve_web.py --open
```

On macOS, **Export Web.command** runs both steps. Use `--godot /path/to/godot` or `GODOT_BIN` to choose an engine. The exporter creates `dist/web/` and `dist/Taterland-Web.zip`, and keeps the previous working build if export fails. Python 3.10 or newer is recommended.

The exported game can also run on a static HTTP/HTTPS host. Upload `index.html` and its supporting files together, preserving their relative paths. The ZIP includes font and Godot license notices.

See [development notes](docs/DEVELOPMENT.md) for saves, checks and project layout.
