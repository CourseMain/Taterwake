# Development notes

## Project layout

- `project.godot` and `scenes/`: Godot project and entry scene.
- `scripts/`: game simulation, procedural world, player and interface.
- `assets/`: fonts, original rocket audio and third-party notices.
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

Run `node tests/test_web_canvas.js` to verify browser resolution limits and aspect ratios. `test_debug_access_time.gd`, `test_stock_ceiling.gd` and `test_stock_rocket_state.gd` cover the access gate, time controls and market windows.

Additional files in `tests/` cover island activities, purchase receipts, market limits, pests, clothing, camera gestures and responsive layout. Interface and lighting checks may also need a rendered run to inspect their visual output. Read each check's setup before running it. Godot can print script errors even when its process exit status is zero; inspect the output as well.

Python and macOS launcher syntax checks:

```sh
python3 -m py_compile tools/export_web.py tools/serve_web.py
zsh -n "Play Taterland.command" "Export Web.command"
```

## Web export

The exporter uses a staging folder, validates the generated WebAssembly and required game files, then replaces the working `dist/web/` folder and `dist/Taterland-Web.zip`. An export failure leaves the previous working build available. Install the export templates matching the selected Godot release before building.

The Web preset uses the Compatibility renderer and a single-threaded WebGL build. Its local Python server binds to `127.0.0.1`; it is a preview tool rather than a public hosting service. The generated ZIP includes local launchers, offline web-app assets and third-party notices. Keep all files together when hosting or sharing it.

### Browser rendering budget

The web shell owns the root canvas (`html/canvas_resize_policy=0`) and keeps UI at up to 2× device scale, capped at 3840×2400 / 8,294,400 pixels. Graphics mode never resizes that canvas. `FarmViewport` draws the world separately at up to 1600×1000 (Smooth), 1920×1200 (Balanced), or 2560×1600 (Crisp), without exceeding the fitted game rectangle's physical size. Smooth/Balanced use 2× MSAA; Crisp uses 4×. Letterbox borders are excluded from the farm aspect ratio. Main maps logical mouse coordinates into the farm viewport before ray picking. Menus, stock effects and the rocket film remain on the root canvas.

`StaticMeshCompiler` combines tagged immutable opaque siblings across colours into one vertex-coloured surface per compatible render state. It transforms positions and inverse-transpose normals, retains shadow/layer/cull settings, excludes runtime-owned meshes and mirrored transforms, and caches up to 128 identical geometry signatures. Animated/hidden parents, colliders, labels, avatars and mutable soil/steam/light nodes stay separate. Special materials use the existing MultiMesh fallback. Idle audio submits silence in one buffer; rocket playback suspends the hidden farm viewport until the selling window begins.

Matched native fixture (Apple M4, Compatibility, 1280×800, 2× MSAA, 48 ripe Sunburst beds): v1.0.1.5 used 2,291 draw calls and median 14.91 ms; v1.0.1.75 used 843 and 8.10 ms. These forced-draw timings include scheduling and are not Safari FPS. Reproduce with `tests/benchmark_shadow_modes.gd`.

Safari was separately tested using `tools/export_browser_benchmark.py` and its isolated fixture. The copied main script is forced into integration mode; no user farms are read or saved. In the same window, full-game draw calls fell from about 2,184 to 921. After Low Power Mode was disabled, the candidate measured 59.5 FPS Balanced and 59.3 FPS Crisp over 8-second samples, with root UI 3024×1592 and fitted farm 1919×1200 / 2547×1592 respectively. While Low Power Mode was enabled, even a plain browser requestAnimationFrame probe with no Godot/WebGL measured 29.7 FPS. Do not attribute the power-mode FPS increase entirely to game optimization or generalize these numbers to every device.

### Shadows and device preferences

Balanced/Crisp use a single orthographic shadow map, zero pancake extrusion and a stable steep sun direction. Terrain shells do not cast onto the ocean. The 60-second sky/light cycle remains; Smooth disables the shadow map. `GraphicsPreferences` saves only the quality mode in `user://taterland_graphics.cfg`, independently of farm state. Existing Balanced/Smooth preferences remain valid.

`test_static_mesh_compiler.gd`, `test_farm_viewport.gd`, `test_graphics_preferences.gd`, `test_world_graphics_quality.gd` and `test_web_canvas.js` cover transformed geometry, cache reuse, all-island scaled input, letterboxing, sharp UI budgets, preference persistence and shadow bounds. Ferry and purchase input fixtures convert projected farm coordinates into logical screen coordinates before sending clicks.

Broader validation also checked existing island suites against the unmodified v1.0.1.5 sources. Two older Golden Shores layout assertions (reward card height and Sunburst sell-without-scroll), and the old feature UI fixture's Island 1 activity target assertion, already fail on that baseline; they are not introduced by the rendering update.

## GitHub Pages

The `docs/` folder includes the browser game and `.nojekyll` alongside these guides. Configure the repository's **Settings → Pages** to **Deploy from a branch**, **main**, **/docs**. Push changes using GitHub Desktop to publish them. The repository remains named Taterwake, so its expected address is `https://coursemain.github.io/Taterwake/` even though the game's title is Taterland.

After exporting an updated game, copy all `index.*` files and the license notices from `dist/web/` into `docs/`, keeping `.nojekyll` and the Markdown guides. Commit and push the updated files. The Web export excludes `docs/` to avoid bundling the published game inside the next export. No custom cross-origin headers are needed for this single-threaded build.

## Third-party notices

Nunito Sans and Noto Sans Symbols are distributed under the SIL Open Font License; see the license files in `assets/fonts/`. Godot's engine license and third-party notices are in `assets/licenses/` and are included in browser packages. These notices describe their respective dependencies.
