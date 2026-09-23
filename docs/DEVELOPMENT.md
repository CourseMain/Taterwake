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

### Climate economy and taxes (local source update)

`scripts/blind_rules.gd` owns progression baselines, the 8% major-stock reference, 5% base tax, 5% bankruptcy allowance, three major stocks per collection, Tax Boom probability and the +150% shared pressure ceiling. Tax targets never follow the player's wealth or build. There are no separate Small/Big Blind objectives or target-miss deaths; the retained `blind_cycle` names only maintain save compatibility.

| Island | Progression baseline | Stock reference (8%) | Base tax (5%) | Severe tax ceiling (12.5%) | Bankruptcy below |
| --- | --- | --- | --- | --- | --- |
| Spud Valley | $1M: Golden Shores unlock | $80K | $50K | $125K | −$50K |
| Golden Shores | $100B: Frosthollow unlock | $8B | $5B | $12.5B | −$5B |
| Frosthollow | $5Qa: virtual late-game baseline | $400T | $250T | $625T | −$250T |

There is no Island 4. The stock reference is a haul-value balancing reference, not an automatic payout or income cap: the stock tooltip and Climate action show how many potatoes at the current quote reach it. Actual earnings still depend on crops, quantity, mutations, processing and selling. Existing decreasing-rarity stock distributions stay intact, including the +35,000%–100,000% Rocket range. Severe weather weakens ordinary sale prices but preserves explicit major/Rocket/natural stock quotes so a boom can fund a comeback.

At the first actual major boom, a 20% chance rolls a Tax Boom with a uniform integer increase from 0% through 150%. Disaster recovery adds pressure; combined pressure cannot raise the bill above 2.5× base tax. The third actual scheduled or Rocket price boom starts a full ten-second selling window before collection. Natural spikes, ordinary offers and the Rocket cinematic do not count. With scheduled stocks every three minutes, collection is about every nine minutes. Tutorials pause taxes, weather and stock pressure.

Collection deducts the displayed bill even if cash cannot cover it. Debt is playable; only crossing **strictly below** the bankruptcy line immediately ends the run. Equality survives. There is no wealth-based surplus levy. The pre-collection cash-to-tax ratio produces 2× OVERKILL, 5× ULTRA KILL, 10× GODLIKE, 25× OMNIPOTENT, 100× RULER, 1,000× COSMIC RULER and 1,000,000× REALITY BREAKER. Uncovered bills and balances show red. Signed finite double balances use suffixes through Dc, then scientific notation, up to ±1e300.

A first visit to a harder island starts three fresh stocks at its tax tier. Returning to an earlier island keeps the highest visited tier and existing collection counter, preventing lower-tax travel loops. Last receipts retain actual tax, pre-tax cash, coverage, rank and post-tax debt.

`scripts/climate_system.gd` owns climate timing, losses, market factors and local protection costs. Island 1 is free from weather disasters. First arrival at Island 2 (or an older save already on Island 3) shows a one-time introduction that pauses the simulation until acknowledged. The first warning follows 90 seconds of eligible play. Calm weather clocks pause on Island 1; an already warned disaster continues against its original island and shared barn. Drought, flood and severe storm give 45 seconds to prepare, hit once, last 30 seconds and recover over 75 seconds; another calm interval lasts 210–330 seconds. Warnings preview the estimated bill after impact. Disasters destroy a severity-dependent portion of planted beds and stored potatoes, including mutations, processed stock and processing queues. Floods also require damaged beds to be tilled again. Seed prices rise independently of weaker sale prices, ordinary market volatility increases, and growth slows. Temporary effects taper to normal during recovery; infrastructure pressure remains until the next tax collection.

Climate action funds two levels each of Rainwater Reserve, Drainage Network, Reinforced Barn and Living Windbreaks, priced relative to the local progression baseline. These reduce the relevant physical losses and recovery tax contributions. Funding during recovery can still lower a pending bill; it cannot restore destroyed crops. Damage remains attached to the warned island, while the shared barn is exposed wherever the player travels. One batched canvas layer draws drifting cloud banks, up to 100 rain streaks, wind ribbons, floodwater and drought dust. Existing 3D clouds accelerate and expand; the sky and sunlight respond. Original looped wind/rain audio and thunder accompany storms. Camera shake is bounded to 0.26 world units. No per-crop particle nodes are created.

Bankruptcy freezes the run and replaces the normal HUD with an editorial page: desaturated farm, heavy display typography, restrained cream, earth tones and muted debt red. It records the actual cause, climate phase, final balance, recent field/barn losses, tax, market conditions and build. **View Run Summary** reveals run totals and funded projects; **Try Again** resets the farm and returns to the normal tutorial. The concise educational text paraphrases [FAO's disaster and agriculture report](https://www.fao.org/publications/fao-flagship-publications/the-impact-of-disasters-on-agriculture-and-food-security/); game event rates and tax multipliers are fictional balancing choices, not claims about real-world climate or tax policy.

Mechanics revision 12 saves the introduction flags alongside weather timers, affected island, severity, initiatives, losses, recent history, recovery tax pressure, the tax cycle and collapse report. Pre-revision-11 farms receive fresh climate timing and a full three-stock preparation cycle for the new bills, while existing coins, inventory and progression are retained. An already lost run remains lost. Old Rockets retain their remaining time; pre-revision-9 factors below the new minimum migrate to 351×. Corrupt saves leave the live farm unchanged.

Focused checks (all isolated from real saves):

```sh
godot --headless --path . --script tests/test_blinds.gd -- --integration-test
godot --headless --path . --script tests/test_blinds_game.gd -- --integration-test
godot --headless --path . --script tests/test_climate.gd -- --integration-test
godot --headless --path . --script tests/test_climate_game.gd -- --integration-test
```

These cover every island baseline, tax clearing/borrowing, overkill, negative huge numbers, exact bankruptcy boundaries, tax-caused collapse, caps, full selling windows, event counting, travel, old-save migration, every weather phase, initiative benefits, processing losses, corrupted saves, warning/deadline/death reloads, controller actions, responsive composition and restart. Omit `--headless` and add `--capture` to a scene check for screenshots under `artifacts/`.

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

Fredoka, Oswald, Nunito Sans and Noto Sans Symbols are distributed under the SIL Open Font License; see the license files in `assets/fonts/`. Godot's engine license and third-party notices are in `assets/licenses/` and are included in browser packages. These notices describe their respective dependencies.

### v1.0.2 presentation preview

This revision is local and unpublished. Normal UI headings use Fredoka; disaster announcements and the collapse page use Oswald, with Nunito Sans for body copy. Both new fonts come from the Google Fonts repository under the bundled SIL Open Font Licenses. The four climate initiatives use original code-drawn icons in a two-column grid. Tax rate tables, wealth-rank definitions and detailed run statistics are tucked behind explicit detail buttons. Main-menu tiles and descriptions are shorter. The collapse page preserves its serious educational message alongside the final balance and three loss figures.

`climate_alert.gd` shows a blocking first-arrival introduction and five-second nonblocking event announcements. Intro flags and pending acknowledgments survive saves; revision-11 saves get safe defaults, and old Island-1 weather is cleared. `climate_audio.gd` uses original, locally synthesized wind and thunder WAV assets. Public Pages files in `docs/index.*` have not been replaced.
