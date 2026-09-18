# Development notes

## Project layout

- `project.godot` and `scenes/`: Godot project and entry scene.
- `scripts/`: game simulation, procedural world, player and interface.
- `assets/`: fonts and third-party notices.
- `tests/`: isolated simulation and scene regression checks.
- `tools/`: portable Web exporter and local preview server.
- `dist/` and `artifacts/`: generated builds and local verification output, excluded from Git.

## Saves

Taterland retains its earlier save names for compatibility: `user://spud_valley_save_v3.json` and the original `spud_valley_save.json` backup. Existing farms retain their coins, crops, builds, equipment and island progress. Browser and native saves remain separate.

The native user-data directory is explicitly pinned to the existing **Spud Valley** location under Godot's application data. Renaming the game therefore continues to use the same desktop farm instead of creating a separate Taterland save folder. Browser saves still depend on the host address and browser profile.

Saves, private configuration, local recordings and generated builds do not belong in the source repository. Do not run a scene check against a real player save. Scene checks use `-- --integration-test` to skip normal save loading and automatic saving.

## Checks

Import the project once before running tests. Substitute your Godot executable for `godot` if needed:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_simulation.gd
godot --headless --path . --script res://tests/test_gear_rewards.gd
godot --headless --path . --script res://tests/test_equipment.gd
godot --headless --path . --script res://tests/test_game.gd -- --integration-test
```

Additional files in `tests/` cover island activities, purchase receipts, market limits, pests, clothing, camera gestures and responsive layout. Interface and lighting checks may also need a rendered run to inspect their visual output. Read each check's setup before running it. Godot can print script errors even when its process exit status is zero; inspect the output as well.

Python and macOS launcher syntax checks:

```sh
python3 -m py_compile tools/export_web.py tools/serve_web.py
zsh -n "Play Taterland.command" "Export Web.command"
```

## Web export

The exporter uses a staging folder, validates the generated WebAssembly and required game files, then replaces the working `dist/web/` folder and `dist/Taterland-Web.zip`. An export failure leaves the previous working build available. Install the export templates matching the selected Godot release before building.

The Web preset uses the Compatibility renderer and a single-threaded WebGL build. Its local Python server binds to `127.0.0.1`; it is a preview tool rather than a public hosting service. The generated ZIP includes local launchers, offline web-app assets and third-party notices. Keep all files together when hosting or sharing it.

## GitHub Pages

The `docs/` folder includes the browser game and `.nojekyll` alongside these guides. Configure the repository's **Settings → Pages** to **Deploy from a branch**, **main**, **/docs**. Push changes using GitHub Desktop to publish them. The repository remains named Taterwake, so its expected address is `https://coursemain.github.io/Taterwake/` even though the game's title is Taterland.

After exporting an updated game, copy all `index.*` files and the license notices from `dist/web/` into `docs/`, keeping `.nojekyll` and the Markdown guides. Commit and push the updated files. The Web export excludes `docs/` to avoid bundling the published game inside the next export. No custom cross-origin headers are needed for this single-threaded build.

## Third-party notices

Nunito Sans and Noto Sans Symbols are distributed under the SIL Open Font License; see the license files in `assets/fonts/`. Godot's engine license and third-party notices are in `assets/licenses/` and are included in browser packages. These notices describe their respective dependencies.
