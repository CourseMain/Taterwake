# Taterland

**[Play Taterland in your browser — no download needed](https://coursemain.github.io/Taterwake/)**

Open the link on a phone, tablet, or computer. Allow the first load to finish, then start farming. Your browser saves your farm automatically; return with the same browser and address to continue.

**v1.0.2:** Touch movement, pinch zoom, accessible menus and a **Full screen** button join five expanded professions, playable climate disasters, connected water equipment and a simpler first harvest. See [all changes](CHANGELOG.md#102).

On touch screens, drag the bottom-left stick to move; push it to the edge to sprint. Tap a bed, building or piece of equipment to interact. **Tools** contains all five tools, seed choices, zoom buttons and Cancel task. Pinch the farm with two fingers to zoom. **Menu** opens every activity; swipe menus to see more. **Use** works beside beds, the tank and the ferry; **Sell** sells your selected crop. Landscape gives phones a wider farm view; portrait is also supported.

Choose **Full screen** to enter or leave browser fullscreen, or press **F11** on a laptop. Where iPhone/iPad Safari does not provide fullscreen, the button explains **Share → Add to Home Screen**; launch that icon for an app-sized view. The layout respects screen cutouts and home-indicator safe areas.

If Safari feels capped at 30 FPS, check **System Settings → Battery → Low Power Mode**. Chrome/Firefox or [running locally in Godot](#run-the-source) are alternatives; the downloadable Web ZIP still runs through a browser. Close all game tabs and reopen the play link after an update. Keep the same browser profile to retain your farm.

The opening tutorial teaches one harvest and ends at your first sale. Then farm freely, with optional help for your first pests, a practice stock boom, taxes and usable upgrades. **H → Optional Valley tour** keeps meeting the NPCs optional.

Small potatoes. Big possibilities.

Five illustrated profession pages offer giant potatoes, F–SSS production batches, a permanent seed bank, reserved-price shipments and explicit harvest stakes. Each explains its cost and readiness, with optional bonus details. The Farmer guides planted crop → compost → water → giant harvest. See [profession details](docs/BUILD_PROFESSIONS.md).

Climate disasters begin on **Island 2**, with warnings, rain, wind, storm clouds and camera shake. Learn the visible **rain → tank → can → crop** loop on Island 1, then connect sprinklers, open drainage and protect harvests on later islands. A visiting tax collector arrives after every third major stock; the forecast shows bills and recovery costs. Debt is playable until the bankruptcy limit. See the [water-loop guide](docs/CLIMATE_WATER_LOOP.md).

A 3D potato farming game about growing crops, riding wild markets and building your own kind of farmer. Start in Spud Valley, sail to Golden Shores, and chase frozen fortunes in Frosthollow.

- Work your fields with five manual tools; train ducks to chase pests.
- Catch island stock booms up to **+10,000%**, then ride Frosthollow's **+35,000%–100,000% Stock Rocket**.
- Choose from **five player builds** and collect clothing with farming, market and mutation bonuses.
- Take buyer contracts, fire up a winter furnace, and discover rare rewards at the Roll House.
- Farm through a **60-second day–night cycle** across three islands.
- Fund rainwater reserves, drainage, reinforced barns and windbreaks to protect harvests and reduce recovery taxes.

The Roll House uses coins earned in the game. There are no real-money purchases.

## Download and play locally

For a local copy, use **Taterland-Web.zip** from the [latest release](https://github.com/CourseMain/Taterwake/releases/latest), or [build it from source](#build-the-browser-edition) using the steps below. Extract the entire archive. On macOS, double-click **Play Web.command**; on Windows, double-click **Play Web.bat**. These local launchers need Python 3. Keep their terminal open while playing.

You can also run `python3 serve.py --open` from the extracted folder. Open the printed HTTP address instead of opening `index.html` directly.

Browser saves belong to your browser and the address you use. Return through the same localhost port to continue your farm. Browser saves are separate from desktop saves.

Touch screens get a compact interface with large controls and scrolling menus. Desktop keeps keyboard, mouse and trackpad controls. Both support map zoom and fullscreen.

## Run the source

Use **Godot 4.7.2** with the Compatibility renderer. Import `project.godot` into Godot and press **F5**, or run:

```sh
godot --path .
```

On macOS, **Play Taterland.command** locates Godot automatically. Set `GODOT_BIN` if your engine is installed elsewhere.

## Controls

| Control | Action |
| --- | --- |
| Touch stick / WASD / arrow keys | Move (outer stick edge sprints) |
| Hold Shift | Sprint while moving or following a clicked destination |
| Click a bed | Walk over and use the selected tool |
| Click a tank | Walk over and refill the watering can |
| Click a sprinkler / drain / trees | See connected beds and equipment actions |
| 1 / 2 / 3 / 4 / 5 | Hoe / seeds / water / harvest / pest sprayer |
| E / Space | Use the selected tool nearby / board the ferry |
| Two-finger pinch / trackpad scroll / mouse wheel | Zoom the map |
| Full screen button / F11 | Toggle fullscreen |
| Touch Tools drawer | Select tools and seeds, zoom +/−, cancel a task |
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
