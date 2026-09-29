# Taterland

**v2.0.0(undeveloped:b) — Game redesign**

Taterland is being redesigned from a big-number market game into a farming survival game with a ten-year run and climate change as its central threat. This is an unfinished source prerelease on the `redesign` branch. Follow the [redesign plan](docs/REDESIGN_PLAN.md) and [release notes](CHANGELOG.md#200-undeveloped-b).

The `v2.0.0-undeveloped-b` source prerelease implements redesign Segments 1–11:

- One Spud Valley farm, with 12 open beds and 12 available through expansion.
- Small prices, ordinary crops and tools; no gacha, gear multipliers, professions or market booms.
- All four seasons last 150 seconds. Annual accounts pause at Winter start; the year rolls over automatically after Winter. The tenth Winter ends the run.
- Five crop cards with water, heat and cold dials; Icecap plants in Autumn and grows through Winter ice.
- Seasonal crop growth, Autumn harvest losses, Winter ice clearing, changing sunlight and snow.
- Annual accounts, ledger-backed cash, fixed Winter costs, foreclosure and a ten-year summary.
- Winter storage prices, fees and spoilage; one Spring buyer contract due at Autumn start.
- Warned climate disasters, water management and protection projects.
- Save backups, rejected-save protection and a separate v4 save file. Older farms are not migrated.

Deeper climate systems and the remaining redesign segments are still to come. The round potato farmer, villagers, handmade 3D farm and cream interface remain.

**[Play the existing v1.0.3.1 browser build](https://coursemain.github.io/Taterwake/)** — this is the previous game, not the v2 redesign. The live site and downloadable v1 build remain unchanged. To try v2, use the prerelease source with Godot 4.7.2 as described below.

## Download the previous browser release

For a local copy of v1.0.3.1, use **Taterland-Web.zip** from its [release](https://github.com/CourseMain/Taterwake/releases/tag/v1.0.3.1). To build the v2 development source, follow [Build the browser edition](#build-the-browser-edition). Extract the entire archive. On macOS, double-click **Play Web.command**; on Windows, double-click **Play Web.bat**. These local launchers need Python 3. Keep their terminal open while playing.

You can also run `python3 serve.py --open` from the extracted folder. Open the printed HTTP address instead of opening `index.html` directly.

Browser saves belong to your browser and the address you use. Return through the same localhost port to continue your farm. Browser saves are separate from desktop saves.

Touch screens get a compact interface with large controls and scrolling menus. Desktop keeps keyboard, mouse and trackpad controls. Both support map pan, zoom and fullscreen. The angled 3D view stays fixed for readable farming.

## Run the source

Check out the `redesign` branch or the `v2.0.0-undeveloped-b` tag. Use **Godot 4.7.2** with the Compatibility renderer. Import `project.godot` into Godot and press **F5**, or run:

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
| E / Space | Interact with the nearby NPC/shop, use a tool beside a bed, or use nearby equipment |
| Mouse drag / two-finger trackpad scroll | Pan the map |
| One- or two-finger touch drag | Pan the map |
| Pinch / mouse wheel | Zoom the map |
| Home / Touch Tools → Recenter | Restore the camera |
| Top-left expand/× icon / F11 | Toggle fullscreen |
| Touch Tools drawer | Select tools and seeds, zoom +/−, recenter, cancel a task |
| I | Crops and tools |
| B / U | Market / tool upgrades |
| F | Sell the selected crop |
| Escape / ☰ | Main menu and remaining activities |

Start by hoeing a bed, selecting seeds, planting and watering. Harvest a ripe crop, then sell it to buy your next round of seeds. Visit the toolsmith for larger tool areas. Till during Spring and Summer. Icecap can also be planted into prepared Autumn beds and harvested through Winter ice; bring other crops in before Winter.

See the [gameplay guide](docs/GAMEPLAY.md) for prices, local activities and Debug controls.

## Build the browser edition

Install the Web export templates matching your Godot version, then run:

```sh
python3 tools/export_web.py
python3 tools/serve_web.py --open
```

On macOS, **Export Web.command** runs both steps. Use `--godot /path/to/godot` or `GODOT_BIN` to choose an engine. The exporter creates `dist/web/` and `dist/Taterland-Web.zip`, and keeps the previous working build if export fails. Python 3.10 or newer is recommended.

The exported game can also run on a static HTTP/HTTPS host. Upload `index.html` and its supporting files together, preserving their relative paths. The ZIP includes font and Godot license notices.

See [development notes](docs/DEVELOPMENT.md) for saves, checks and project layout.
