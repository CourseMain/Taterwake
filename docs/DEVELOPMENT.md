# Development notes

## Project layout

- `project.godot` and `scenes/`: Godot project and entry scene.
- `scripts/`: game simulation, procedural world, player and interface.
- `assets/`: fonts, farm/weather audio and third-party notices.
- `tests/`: isolated simulation and scene regression checks.
- `tools/`: portable Web exporter and local preview server.
- `dist/` and `artifacts/`: generated builds and local verification output, excluded from Git.

## Saves

Current saves use `user://taterland_save_v4.json`, schema 4 and mechanics revision 28. Saves without the new calendar, including revision 27, are set aside as incompatible. Older schemas are rejected, with no migration or fallback loader. The original v2 and v3 paths are protected from reads, writes and rejection moves. Browser and native saves remain separate.

Each successful save moves the previous file to `<path>.bak`, replacing the older rolling backup. A load rejected for size, malformed JSON or invalid data moves the candidate to `<path>.rejected`, replacing the previous rejected file and reporting that it was set aside. New-farm autosaves leave that file alone. The original v2 and v3 paths are never moved or overwritten. `GameState.backup_path()` and `rejected_path()` also accept disposable test paths; pass the backup path to `load_game()` to recover the previous farm.

The native user-data directory is explicitly pinned to the existing **Spud Valley** location under Godot's application data. The new v4 filename separates this redesign from older farms in that directory. Browser saves still depend on the host address and browser profile.

Saves, private configuration, local recordings and generated builds do not belong in the source repository. Do not run a scene check against a real player save. Scene checks use `-- --integration-test` to skip normal save loading and automatic saving.

## Checks

Run the headless suites through `tools/run_tests.sh` (requires Python 3 and Godot 4.7.2):

```sh
tools/run_tests.sh                         # all suites, four at a time
tools/run_tests.sh -j 1                    # serial baseline
GODOT_BIN=/path/to/godot tools/run_tests.sh # select an executable
tools/run_tests.sh -j 1 test_save_safety test_game
```

The runner imports once when `.godot/imported` is missing, discovers every `tests/test_*.gd` except `*_browser.*`, and passes `-- --integration-test` to each suite. Optional suite names can include `tests/` and `.gd`. `--timeout 180` sets the per-process timeout in seconds (180 by default, also used for import). Each suite prints one PASS/FAIL/TIMEOUT/ERRORS line with its own check/failure summary, including names containing spaces, slashes and plus signs. Nonzero failure counts or process exits fail; missing summaries and engine/script errors also fail, even with exit code zero. Full logs and `results.json` are in `artifacts/test-results/` and are replaced for the suites run. The runner exits nonzero unless every selected suite passes.

### Baseline

#### Segment 8 — current

Godot 4.7.2, `tools/run_tests.sh -j 1`: **72 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_season_clock` (118 checks), `test_day_night` (314) and `test_game` (39). No tests are skipped or disabled. The latest complete serial result is `artifacts/season-display-baseline.txt`; the initial Segment 8 result remains in `artifacts/segment8-baseline.txt`.

Growth fixtures now use seasonal durations, sky checks follow the moving sun, and market simulation stops at Winter. Fixtures for explicit weather and practice scenarios begin with a deterministic calm Spring; separate state tests still exercise the 15% disaster draw and saved RNG continuity. Scene teardown allows audio playback to finish releasing before engine exit.

The explicit headless boot command passes all 39 checks. Initial Segment 8 native GL Compatibility and temporary Web resource pack checks each passed all 65 calendar checks. The Winter panel and dawn/midday/dusk captures were visually inspected. Packed-resource validation is not a browser runtime test; browser automation was not rerun. Published `docs/index.*` and `web/` remain unchanged.

#### Segment 7 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **71 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes. Seven dedicated regional suites were deleted, mixed fixtures now use the single Valley field, and `test_single_farm` was added. No tests are skipped or disabled. The full serial result is `artifacts/segment7-baseline.txt`.

The explicit headless `test_game` boot check passes all 39 checks. Native GL Compatibility passed the single-farm scene with menu and Valley captures; both were visually inspected. The temporary Web resource pack passes all 264 single-farm checks, including saved seasonal RNG continuity. Browser fixture and benchmark scripts pass Godot parse checks; browser interaction automation was not rerun. Packed-resource validation is not a browser runtime test. Published `docs/index.*` and `web/` remain unchanged.

#### Segment 6 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **77 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. All surviving suites pass, including the boot test and the new economy-scale suite. Retired-system tests were deleted; mixed tests retain purchase, weather, UI, migration and save-safety coverage with the new economy. The local result is `artifacts/segment6-baseline.txt`.

Native GL Compatibility passes the climate/collapse scene check (51 checks); the menu has no tax entry, and the final receipt shows the grouped balance and common overdraft limit. A temporary Web resource pack passes all 64 economy checks. This checks packed resources, not a browser runtime. Published `docs/index.*` and `web/` remain untouched.

#### Segment 5 — historical

2026-09-28, macOS, Godot `4.7.2.stable.official.ed1daf0bf`, branch `redesign`: `GODOT_BIN=/path/to/Godot tools/run_tests.sh -j 1` completed with **82 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_profession_removal` (241 checks), `test_game` (41), `test_climate` (112), `test_seed_market` (248) and `test_save_safety` (28). Seven profession-only suites were deleted and a save/UI removal regression added. Surviving suites retain their non-profession checks; none are skipped or disabled.

The first pass exposed obsolete workshop sign counts, old tour indices, processor fuel and Frostgold expectations, plus a crop-node naming regression. All are resolved. The full serial report is in ignored `artifacts/segment5-final-baseline.txt`; final focused boot/removal/winter/touch checks are in `artifacts/segment5-final-checks.txt`.

Native GL Compatibility and a temporary Web resource pack each pass all 241 removal checks. The native menu capture has no Builds entry. The requested `build_system|profession|PlayerBuilds` audit is empty in `scripts/`. Python export helpers and updated browser-test JavaScript pass syntax checks; browser automation was not rerun. Published `docs/index.*` and `web/` are untouched.

#### Segment 4 — historical

2026-09-28, macOS, Godot `4.7.2.stable.official.ed1daf0bf`, branch `redesign`: `GODOT_BIN=/path/to/Godot tools/run_tests.sh -j 1` completed with **88 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_placeholder_market` (282 checks), `test_seed_market` (248), `test_disaster_markets` (24), `test_save_safety` (28) and the required `test_game` boot check (41). Seven dedicated stock/chart suites were deleted; the placeholder model suite was added. No tests are skipped or disabled.

The initial failures referenced removed APIs, countdowns, charts and price multipliers. Surviving fixtures now construct legacy tax obligations directly, expect ordinary seed-purchase quest milestones and use fixed base seed prices. Storm protection checks retain barn-loss reductions while recognizing that trees cannot prevent lightning losses. All failures and stale-reference timeouts are resolved. The complete serial result is in ignored `artifacts/segment4-amendment-baseline.txt`, with per-suite logs in `artifacts/test-results/`.

After the price-information amendment, native GL Compatibility market checks pass all 248 checks both on desktop and with touch controls. Desktop, portrait and landscape Buy/Sell captures were inspected. A temporary Web resource pack exports successfully and passes all 248 market integration checks, including the restored sparklines. The source audit finds no `surge` or `rocket` matches in `scripts/`. Published `docs/index.*` and `web/` remain untouched; browser automation was not rerun.

#### Segment 3 — historical

2026-09-28, macOS, Godot `4.7.2.stable.official.ed1daf0bf`, branch `redesign`: `GODOT_BIN=/path/to/Godot tools/run_tests.sh -j 1` completed with **94 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered headless suite passes, including `test_item_removal` (46 checks), `test_save_safety` (28 checks), `test_round_avatar` (12 checks) and the required `test_game` boot check (42 checks). Six dedicated wardrobe/equipment suites were deleted, and the migration/removal suite was added. No tests are skipped or disabled.

The first run exposed stale assertions for gear-adjusted stock distributions, inventory excluding tools, and production links in Inventory. The surviving tests now check base stock distributions, five farming tools and production controls on Builds. All failures and the resulting fixture timeout are resolved in the complete rerun. Logs are in ignored `artifacts/segment3-final-baseline.txt` and `artifacts/test-results/`.

Native GL Compatibility runs passed `test_latest_game` with captures (77 checks) and `test_npc_conversations` (380 checks). Crop/tool shelves and Mara/Bram portraits were visually inspected. The migration suite also passed all 46 checks against a temporary Web resource pack, including its exported legacy-field data. The published `docs/index.*` and `web/` were not changed. Browser fixture tab names were updated; browser automation was not rerun for this segment.

#### Segment 2 — historical

2026-09-28, macOS, Godot `4.7.2.stable.official.ed1daf0bf`, branch `redesign`: the complete `GODOT_BIN=/path/to/Godot tools/run_tests.sh -j 1` run exited zero with **99 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered headless suite passes, including `test_save_safety` (28 checks), `test_gacha_removal` (27 checks) and the required `test_game` boot check (43 checks). Five dedicated Roll House suites were deleted and the migration/removal suite was added.

The remaining tests now use valid current and historical field-access fixtures, current quest/gear/capacity values, mouse release events and NPC conversation flows. Sprinkler checks supply living crops after weather/pest damage; the first-pest tutorial check waits through the full scheduling range. Scene teardown allows audio resources to finish releasing. These fixture changes resolve the earlier baseline failures without changing the surviving gameplay systems.

The touch suite launches with `--touch-controls` and preserves native/capture arguments. Headless fullscreen checks assert the dummy display's actual response; a separate native Compatibility run passed all eight fullscreen checks. The ocean test checks that horizon water intersects the camera's depth interval, while retaining complete depth containment for other geometry. A temporary Web resource pack also passed a saved-cap migration check with the exported alias file. No published browser build was replaced.

Local logs are `artifacts/segment2-baseline.log`, `artifacts/segment2-baseline-results.json` and the per-suite files in `artifacts/test-results/`. These ignored artifacts supplement this committed baseline record.

#### Segment 1 — historical

Segment 1, 2026-09-28: macOS, Godot `4.7.2.stable.official.ed1daf0bf`, source branch `redesign` from `e85f746`. Ran all 103 discovered suites with `GODOT_BIN=/path/to/Godot tools/run_tests.sh -j 1`, using the default 180-second timeout. The full run returned nonzero: **72 PASS, 24 FAIL, 5 TIMEOUT, 2 ERRORS**. A subsequent serial recheck of `test_climate_operations` and `test_water_loop_state` passed after completing their field-access fixture repairs. The reconciled result below is **74 PASS, 22 FAIL, 5 TIMEOUT, 2 ERRORS**; this is not a green baseline.

`test_save_safety` passes all 28 checks, including malformed/invalid/oversized saves, rejected-file replacement and preservation, rolling backup contents/recovery, aborted backup moves and the legacy-path guard. `test_game` passes all 59 boot/integration checks. The runner was also smoke-tested with an isolated fake engine for all four statuses, missing summaries, names with spaces/slashes/plus signs, browser exclusion, suite selection, integration arguments, `GODOT_BIN` and one-time import.

The requested fixtures now record field expansion beside their bed unlocks. The operations/water fixtures open all islands needed by their simulated old saves; the water migration check also verifies that revision 21 reclaims empty upper beds while preserving real crops and other progress. The legacy fixture in `test_tax_credit_land.gd` is unchanged. All suites changed for this segment pass **except `test_stock_rarity`**, whose nine existing Investor outfit-bonus assertions are unrelated to field access. Those assertions remain intact under the instruction to leave unrelated failures for later segments; the acceptance condition that every touched suite passes is therefore not fully met.

Passing suites (all assertions passed and no engine/script errors were reported):

```text
test_blinds.gd                            test_blinds_game.gd
test_branding.gd                          test_build_overview.gd
test_build_professions.gd                 test_build_professions_game.gd
test_build_transactions.gd                test_build_xp.gd
test_builds.gd                            test_clarity.gd
test_climate.gd                           test_climate_game.gd
test_climate_operations.gd                test_climate_visuals.gd
test_crop_growth.gd                       test_day_night.gd
test_debt_credit.gd                       test_debug_money.gd
test_debug_money_ui.gd                    test_debug_recovery.gd
test_debug_trophies.gd                    test_debug_trophies_ui.gd
test_disaster_markets.gd                  test_equipment.gd
test_equipment_preview_motion.gd          test_farm_alerts.gd
test_farm_clarity.gd                      test_farm_help.gd
test_farm_interaction.gd                  test_furnace_warmth.gd
test_game.gd                              test_gear_rewards.gd
test_graphics_preferences.gd              test_guidance_polish.gd
test_harvest_identity.gd                  test_hud_layout.gd
test_island_activities.gd                 test_island_rewards.gd
test_map_pan.gd                           test_map_zoom.gd
test_market_curves.gd                     test_npc_conversations.gd
test_npc_prompts.gd                       test_pest_schedule.gd
test_profession_clarity_ui.gd             test_purchase_activity_hud.gd
test_purchase_review.gd                   test_purchase_world.gd
test_qol_state.gd                         test_quest_rewards_hud.gd
test_responsive_fit.gd                    test_roll_balance.gd
test_roll_clarity_ui.gd                   test_roll_luck_meter.gd
test_round_avatar.gd                      test_save_safety.gd
test_seed_market.gd                       test_simulation.gd
test_static_mesh_compiler.gd              test_stock_ceiling.gd
test_stock_impact_tiers.gd                test_stock_rocket_cutscene.gd
test_stock_rocket_game.gd                 test_stock_rocket_state.gd
test_tax_credit_land.gd                   test_tutorial_barn.gd
test_tutorial_game.gd                     test_ui_audit.gd
test_village_identity.gd                  test_wardrobe_world.gd
test_water_loop_game.gd                   test_water_loop_state.gd
test_world_feedback.gd                    test_world_rendering_optimization.gd
```

Remaining failures are recorded below without disabling assertions or changing the covered systems. TIMEOUT means the process failed to finish within 180 seconds; these five logs contain script errors before the timeout. ERRORS distinguishes engine errors or a missing conforming summary from assertion failures.

| Suite | Result | Observed reason |
| --- | --- | --- |
| `test_climate_lesson.gd` | FAIL | Irrigation coverage/resource assertions and the old-save lesson migration assertion fail. |
| `test_climate_projects.gd` | TIMEOUT | Irrigation purchase does not create the expected project node; accessing its missing dictionary key raises a script error, then the suite times out. |
| `test_clothing_abilities.gd` | FAIL | Scientist experiment description and mutation outcomes disagree with the fixture's clothing/ability expectations. |
| `test_debug_access_time.gd` | FAIL | 2×/5×/10×/30× button selection and subsequent simulation-speed assertions fail. |
| `test_equipment_ui.gd` | FAIL | Passive-item tab, build-linked bonus header and unequip-total assertions fail. |
| `test_farm_viewport.gd` | FAIL | Scaled screen clicks fail to queue the expected plots across islands and graphics modes in headless runs. |
| `test_feature_ui.gd` | TIMEOUT | Activity picking fails, then the unfinished reel has no revealed title; the script errors and times out. |
| `test_ferry_access.gd` | FAIL | Click-to-board, arrival travel panel and E-at-ferry assertions fail on all islands. |
| `test_fullscreen_controls.gd` | FAIL | The headless display does not enter native fullscreen or show the corresponding exit action. |
| `test_island2.gd` | FAIL | Assumes fully open Shores fields and older quests/rewards; field-work, save and migration assertions fail. |
| `test_island2_game.gd` | TIMEOUT | Island picking, quest/crop/export controls fail; a missing button causes a null get_global_rect() call and timeout. |
| `test_island_features_game.gd` | FAIL | Duck purchase/patrol, furnace fuel/processing and batch-reveal/retired-counter assertions fail. |
| `test_latest_game.gd` | FAIL | Paid Roll House controls and Scientist build selection are not available as expected after a crate. |
| `test_market_dialogue.gd` | ERRORS | All 27 assertions pass, but Godot reports one resource still in use at exit. |
| `test_pest_audio.gd` | FAIL | Reward reels do not finish as expected, cascading into later reel and higher-tier celebration/audio assertions; pest checks pass. |
| `test_playability_audit.gd` | FAIL | Tax-warning wording and notification clearance above the roll panel fail. |
| `test_purchase_game.gd` | TIMEOUT | Rejected-purchase feedback/tool-shop clicks fail; an absent receipt kind raises a script error, then the suite times out. |
| `test_purchase_receipts.gd` | FAIL | Barn capacity/upgrade receipt expectations and all-48/all-80-bed island-unlock receipt expectations fail. |
| `test_qol_update.gd` | FAIL | Expects debug island unlocks to open entire fields; the synthetic pre-rebalance save is rejected, so crop-growth migration assertions also fail. |
| `test_stock_rarity.gd` | FAIL | Nine repetitions of the Investor outfit stock-bonus assertion fail; save/bed validation passes after the fixture repair. This is an unrelated remaining failure in a touched suite. |
| `test_touch_controls.gd` | TIMEOUT | The standard headless invocation does not enable touch controls; target-size and UI assertions fail, then a missing control causes get_global_rect() on Nil and timeout. |
| `test_tutorial_hud.gd` | FAIL | Normal-menu repeatable guided-introduction assertion fails. |
| `test_tutorial_state.gd` | ERRORS | All 55 checks report zero failures, but the suite emits a nonstandard summary (Tutorial state checks: 55; failures: 0) that does not match the required runner pattern. |
| `test_tutorial_world.gd` | FAIL | Opening the tutorial does not hide station clutter as expected. |
| `test_ui_polish.gd` | FAIL | Quest claim payout/status assertion fails. |
| `test_weather_dashboard.gd` | FAIL | Debt-funded equipment installation and resulting water-tank telemetry assertions fail. |
| `test_weather_station.gd` | FAIL | Revision-18 equipment migration is rejected, and the expected shared highest sprinkler level is not restored. |
| `test_winter.gd` | FAIL | Winter quest control/seed reward, crop maturation/harvest and full-field tool-area assertions fail. |
| `test_world_graphics_quality.gd` | FAIL | Camera depth bounds do not contain all island/offshore geometry in three assertions. |

Raw local outputs are `artifacts/segment1-baseline.log`, `artifacts/segment1-baseline-results.json`, the per-suite logs in `artifacts/test-results/`, and `artifacts/segment1-final-results.json` with the two successful rechecks reconciled. Artifacts are ignored by Git; this section is the committed baseline record.

### Climate and the temporary overdraft rule

`climate_system.gd` retains warnings, physical crop/barn losses, protection, weather phases and the collapse report. Weather never changes prices or generates a bill. Protection has flat costs of 500–1,000 per first level and twice that for the second level. `save_validation.gd` supplies finite-number validation shared with climate saves.

A balance strictly below −5,000 ends the run immediately. `run_over` and the final climate receipt persist in saves; equality remains playable. The editorial collapse page shows the final balance, overdraft limit and weather losses, with run summary, restart and authenticated debug recovery. The annual ledger is not implemented in this segment.

Focused checks: `tools/run_tests.sh -j 1 test_economy_scale test_climate test_climate_game test_debug_recovery`. These cover exact overdraft boundaries, cash purchases, ended-run persistence, price/yield tables, weather phases, protection, corrupted saves, responsive collapse composition and restart. A native scene check with `--capture` writes screenshots under `artifacts/`.

The runner handles the initial import. For a focused simulation and boot check:

```sh
tools/run_tests.sh -j 1 test_simulation test_item_removal test_round_avatar test_game
```

Run `node tests/test_web_canvas.js` to verify browser resolution limits and aspect ratios. `test_debug_access_time.gd` covers the access gate and time controls; `test_placeholder_market.gd` covers bounded drift, price history and save round-trips.

Additional files in `tests/` cover island activities, purchase receipts, market transactions, pests, avatar animation, camera gestures and responsive layout. Interface and lighting checks may also need a rendered run to inspect their visual output. Read each check's setup before running it. The runner detects Godot errors even when its process exit status is zero; inspect the saved log for details.

Python and macOS launcher syntax checks:

```sh
python3 -m py_compile tools/export_web.py tools/serve_web.py
zsh -n "Play Taterland.command" "Export Web.command"
```

## Web export

The exporter uses a staging folder, validates the generated WebAssembly and required game files, then replaces the working `dist/web/` folder and `dist/Taterland-Web.zip`. An export failure leaves the previous working build available. Install the export templates matching the selected Godot release before building.

The Web preset uses the Compatibility renderer and a single-threaded WebGL build. Its local Python server binds to `127.0.0.1`; it is a preview tool rather than a public hosting service. The generated ZIP includes local launchers, offline web-app assets and third-party notices. Keep all files together when hosting or sharing it.

### Browser rendering budget

The web shell owns the root canvas (`html/canvas_resize_policy=0`) and keeps UI at up to 2× device scale, capped at 3840×2400 / 8,294,400 pixels. Graphics mode never resizes that canvas. `FarmViewport` draws the world separately at up to 1600×1000 (Smooth), 1920×1200 (Balanced), or 2560×1600 (Crisp), without exceeding the fitted game rectangle's physical size. Smooth/Balanced use 2× MSAA; Crisp uses 4×. Letterbox borders are excluded from the farm aspect ratio. Main maps logical mouse coordinates into the farm viewport before ray picking. Menus remain on the root canvas.

`StaticMeshCompiler` combines tagged immutable opaque siblings across colours into one vertex-coloured surface per compatible render state. It transforms positions and inverse-transpose normals, retains shadow/layer/cull settings, excludes runtime-owned meshes and mirrored transforms, and caches up to 128 identical geometry signatures. Animated/hidden parents, colliders, labels, avatars and mutable soil/steam/light nodes stay separate. Special materials use the existing MultiMesh fallback. Idle audio submits silence in one buffer.

Matched native fixture (Apple M4, Compatibility, 1280×800, 2× MSAA, 48 ripe Sunburst beds): v1.0.1.5 used 2,291 draw calls and median 14.91 ms; v1.0.1.75 used 843 and 8.10 ms. These forced-draw timings include scheduling and are not Safari FPS. Reproduce with `tests/benchmark_shadow_modes.gd`.

Safari was separately tested using `tools/export_browser_benchmark.py` and its isolated fixture. The copied main script is forced into integration mode; no user farms are read or saved. In the same window, full-game draw calls fell from about 2,184 to 921. After Low Power Mode was disabled, the candidate measured 59.5 FPS Balanced and 59.3 FPS Crisp over 8-second samples, with root UI 3024×1592 and fitted farm 1919×1200 / 2547×1592 respectively. While Low Power Mode was enabled, even a plain browser requestAnimationFrame probe with no Godot/WebGL measured 29.7 FPS. Do not attribute the power-mode FPS increase entirely to game optimization or generalize these numbers to every device.

### Shadows and device preferences

Balanced/Crisp use a single orthographic shadow map and zero pancake extrusion. Terrain shells do not cast onto the ocean. The sun direction follows progress through each 150-second working season; quality changes preserve its position. Smooth disables the shadow map. `GraphicsPreferences` saves only the quality mode in `user://taterland_graphics.cfg`, independently of farm state. Existing Balanced/Smooth preferences remain valid.

`test_static_mesh_compiler.gd`, `test_farm_viewport.gd`, `test_graphics_preferences.gd`, `test_world_graphics_quality.gd` and `test_web_canvas.js` cover transformed geometry, cache reuse, scaled Valley input, letterboxing, sharp UI budgets, preference persistence and shadow bounds. Purchase input fixtures convert projected farm coordinates into logical screen coordinates before sending clicks.

Broader validation also checked existing island suites against the unmodified v1.0.1.5 sources. Two older Golden Shores layout assertions (reward card height and Sunburst sell-without-scroll), and the old feature UI fixture's Island 1 activity target assertion, already fail on that baseline; they are not introduced by the rendering update.

## GitHub Pages

The `docs/` folder includes the browser game and `.nojekyll` alongside these guides. Configure the repository's **Settings → Pages** to **Deploy from a branch**, **main**, **/docs**. Push changes using GitHub Desktop to publish them. The repository remains named Taterwake, so its expected address is `https://coursemain.github.io/Taterwake/` even though the game's title is Taterland.

After exporting an updated game, copy all `index.*` files and the license notices from `dist/web/` into `docs/`, keeping `.nojekyll` and the Markdown guides. Commit and push the updated files. The Web export excludes `docs/` to avoid bundling the published game inside the next export. No custom cross-origin headers are needed for this single-threaded build.

## Third-party notices

Patrick Hand, Fredoka, Oswald, Nunito Sans and Noto Sans Symbols are distributed under the SIL Open Font License; see the license files in `assets/fonts/`. Godot's engine license and third-party notices are in `assets/licenses/` and are included in browser packages. These notices describe their respective dependencies.

### First-harvest lesson and contextual help

`first_island_tutorial.gd` now has eight stages (welcome, seed purchase, hoe, plant, water, growth, harvest, sale). The first sale ends mandatory guidance. Tools are auto-equipped with one bed cue; another empty hoe target retargets the lesson. Blocked input explains the current action. Normal no-op field actions also show their result. `TOUR` is a separate optional NPC tour: Next never requires a shop visit, transactions are blocked, and all farm timers are preserved while paused.

`farm_help.gd` stores optional tip dismissals, a tracked independent plant/water/harvest/sale cycle, first-infestation protection. New lessons enable help on completion or skip; established saves get no surprise tips. Tutorial version 1 stages through first sale map to version 2; later compulsory stops retire. Mechanics revision 13 saves help state, including protected field indices. Malformed help data is rejected before loading.

The first natural infestation is harmless until cleared or harvested, even when its tip is dismissed or the farm reloads. Additional infestations wait until that group is resolved, then normal damage resumes.

Contextual advice is available only through Help → Current farm help. The former FarmHelp overlay is an empty hidden compatibility node, so existing layout callers cannot restore the floating debt/tool reminders. Useful action feedback, bankruptcy information and full-barn alerts remain separate. Saved first-pest protection, independent farming progress are unchanged. Dismissing a suggestion records dismissal only, not learning.

Base crop times are 75/105/135/165/195/225 seconds for Russet/Golden/Giant/Radioactive/Sunburst/Icecap. Active growth speed is bounded by `base_time / 450`, including weather penalties. Field updates and hover timers use the same bound. Dry/frozen crops and paused simulations do not consume growth time. The calendar format does not migrate earlier save revisions.

### Quiet farming feedback and shop signs

Shop signs use semibold Fredoka, matching the original rounded roll-button typography, with short names and a fine contrasting outline. Valley/Shores use cream lettering; winter uses dark lettering against snow. Labels remain clickable and retain tutorial visibility. Fredoka also supplies compact shop and menu headings and buttons; Nunito Sans remains on body copy and numeric status text.

Normal field actions never create central toasts. No-op feedback (for example, “Already watered” or “Plant a seed first [2]”) shares one click-through footer slot with hover hints, expires after 1.4 seconds, and does not extend on rapid identical repeats. Successful work clears stale failure text. Plot notifications are handled through this path once; a full barn still gets a short actionable reminder. Other notifications appear in a smaller upper-right card.

`test_farm_clarity.gd -- --integration-test` checks rapid repeated actions, feedback expiry, duplicate suppression, full-barn feedback, help action stability, responsive layout and Valley typography. A native `--capture` run writes `artifacts/clarity-watering.png`, `clarity-island-1.png` through `clarity-island-3.png`, and `clarity-winter-warning.png`.

`climate_projects.gd` builds a farm tank, perimeter drainage, braces on the existing barn, and a rear tree windbreak from the saved project levels. Second levels add visible infrastructure. `FarmWorld.set_climate_projects()` creates/batches geometry only when local levels change, and clears it on reset or world rebuild. The controller applies purchases immediately. Structures occupy gaps and field edges, keeping existing map dimensions and all crop targets accessible.


### v1.0.2 operational climate implementation

`climate_field_visuals.gd` adds one instanced floodwater draw and two batched triangle surfaces for rings, scorch marks, pipe flow, screens and lightning. `flood_water.gdshader` uses ordinary Compatibility spatial shading, analytic waves, foam and farmer-proximity ripples; it requires no compute shaders, screen readback, fluid solver or per-droplet physics. Surface markings rebuild at most ten times per second. The full-screen canvas effect adds a drawn sun and heat ribbons and synchronizes lightning flashes to actual strikes. The field console offers nonmodal controls; the scrollable equipment panel places operations before purchases.


### Optional water practice

Validation for the simplified flow: 33 lesson checks, 119 climate checks, 42 game checks, 23 operations checks and 196 responsive-layout checks passed, plus the climate visual checks. Safari browser QA completed both practice actions and flood drainage. Both the isolated lab and regular Web ZIP were rebuilt successfully.

### Connected water loop (mechanics revision 18)

Manual watering spends carried can water in all weather. Refilling conserves tank plus can water. Connected sprinklers consume the same reserve; drought stops rain replenishment. Frozen and locked beds are excluded. Drain opening is idempotent, trees shelter their fixed far patch and barn shutters close automatically.

Weather warning/impact announcements are now brief, nonblocking strips above the farm; recovery uses the existing field status card instead of a second large announcement.


### Pretest polish: stable buttons, spacious islands, sprint and carried tools

The climate console keeps active button visibility stable across resource/timer updates; previously `hide()` cancelled a held press before its release. `test_farm_interaction.gd` reproduces that failure with real viewport mouse input, then covers both invitation choices, sprinkler practice, sprint speed/arrival/menu blocking and can pose continuity. The field practice now has a brief destination label and arrow to remain readable at the expanded overview.

Hold Shift for an eased 1.65× sprint on WASD/arrows or click routes. Avatar running stride responds to sprint blend. The persistent can follows the carrying hand, performs the pour itself, and interpolates to/from the tap; temporary tools use a soft pickup/stroke/put-away envelope. All animations remain code-native and use existing batched world effects. The isolated Climate Lab offers Valley farming, practice and four weather scenarios. Local Web exports only; no public files or remote branches are updated.


### Playability and debug

Notifications dock clear of modal controls. Debug has bounded funding for zero/negative balances and code-gated recovery after bankruptcy. Recovery preserves farm progress, clears the final receipt and restores 1× time. Opening Debug pauses simulation.

Run `tools/run_tests.sh -j 1 test_playability_audit test_debug_recovery` to check these flows.

### Touch and fullscreen verification (v1.0.2)

`TouchControls` owns finger IDs separately from keyboard actions. The stick supports simultaneous actions, an outer sprint ring and focus/resize cancellation. Farm taps commit on release; a second finger or drag cancels tapping until the gesture ends. Pinch distance changes the same bounded camera zoom used by the wheel; moving the two-finger center pans the map. Tools provides zoom buttons and Recenter. Desktop right/middle drag and two-finger trackpad scroll pan while Home restores the camera.

Touch uses at least 600 and at most 900 logical units on the short screen edge, with at least 68-unit buttons (44 CSS pixels on a 390px phone). Flexible menu rows stack when needed; scroll containers keep all activities and equipment reachable. The browser shell owns fullscreen requests in a trusted DOM gesture and fits its canvas inside safe-area insets. Native and browser controls draw an expand icon or exit cross on a transparent background; the visible mark is compact while the invisible hit target remains accessible. Browser fullscreen and F11 work independently of game menus. The fallback explains Home Screen installation when the browser rejects or lacks fullscreen.

Run `test_touch_controls.gd` with `-- --integration-test --touch-controls`. It checks phone portrait/landscape, iPad portrait/landscape and laptop sizes, all menus, multitouch movement and pinch cancellation. `tools/export_browser_benchmark.py --fixture mobile --label mobile --godot PATH` creates a disposable browser test build with a QA bridge; the bridge and test scene are excluded from the public export. Browser input checks use actual touch events, screenshots and enter/exit fullscreen at 390×844, 844×390, 768×1024, 1024×768 and 1366×768. These are emulated viewport checks, not claims of physical iPhone/iPad performance testing.

`tests/test_mobile_browser.cjs` automates the browser matrix with Playwright. Set `TATER_QA_URL` to the disposable mobile fixture URL and provide Playwright through `NODE_PATH` or a local installation. Captures and logs go to ignored `artifacts/mobile-qa/`.


### Buy Seeds and Sell Potatoes

`market_pages.gd` owns the Buy Seeds and Sell Potatoes pages with prices, quantities and confirmation controls. `market_quantity.gd` validates whole amounts and bounds them by available crops. Trading calls `FarmState.buy_seeds` and `sell_crop`; an explicit amount above inventory is rejected and `-1` means sell all. Committed receipts drive short transaction feedback.

`test_market_dialogue.gd -- --integration-test` verifies first meetings, repeated tab switches, saved memory and deliberate Mara revisits. All scene tests use isolated state.

### Village identity and harvest feedback (source)

`harvest_feedback.gd` animates committed harvest snapshots without owning inventory: a short pull, release, soil scatter and landing. It caps concurrent receipts at 12 and soil clods at 64; repeat partial harvests replace the same bed’s receipt, and world rebuilds clear effects. `farm_audio.gd` creates cached PCM foley for five tools and ordinary/Giant harvests. Every crop uses the same potato model with growth tied to actual crop progress. Dry or frozen crops do not grow visually. Live plot references refresh after loading; growth scales the plant alone. The first lesson plants and harvests an ordinary Russet.

`village_details.gd` shares the world’s materials and compiled geometry for Mara’s stitched sacks, patched awning and potato-supported crate. Villagers retain deliberate positions and headings at their counters and entrances. `exchange_surface.gd` supplies the timber counter and chalk board; crop portraits share the palette of `item_icon.gd`. Help uses ruled barn notes.

`shop_pages.gd` extends the seed counter's timber trays, item illustrations and button styles to Bram's workbench and Nell's barn. Tool upgrades retain their live costs and readiness; Barn offers Crops and Tools tabs, showing its crop ledger on Crops and keeping capacity expansion available on both shelves. Desktop trays become single-column phone shelves. Purchase receipts wrap in the remaining desktop margin, keeping the wider counters' controls clear.

Shop filler quotes and all-island duck-limit lists are removed. `duck_pond_view.gd` draws the local flock on an animated pond; hiring and training keep their existing actions. Full storage shows a persistent red banner with a Sell crops action, and blocking farm reminders use red on desktop and touch. `test_farm_alerts.gd -- --integration-test` checks the full/sell/clear flow; add `--touch-controls` to cover portrait and landscape bounds and touch targets. Normal harvesting again plays the escalating streak chime alongside the pull/pop foley.

Run `tools/run_tests.sh -j 1 test_harvest_identity test_village_identity test_crop_growth` for first-harvest yield, save/reload, partial/full barns, continuous growth, matching harvest models, animation cleanup and budgets, audio samples and bed/shop picking on the Valley farm. Native `--capture` records screenshots in `artifacts/`.


### Cash purchases and weather console

`GameState.can_purchase()` accepts finite, nonnegative costs only when the farm has enough cash and the run is active. Shop buttons share that predicate; failed actions emit rejection feedback without inventory changes or success receipts. Account warnings, review overlays and recovery orders are removed.

`weather_pages.gd` retains the navy/cyan dashboard with live tank levels, physical protection, costs and timers. `test_weather_dashboard.gd` checks telemetry, cash checkout, warnings and desktop/phone layout; native `--capture` writes isolated previews.

### Island surfaces and camera movement

`island_terrain.gdshader` adds filtered grain and soft, irregular surface variation to sand and snow. Sand has a neutral dry/damp transition; winter uses cool powder shading and smoothly feathered snowbank geometry. Scallop and spiral shells sit in small tide-line clusters outside the working paths. Static shells are batched; ground shader meshes retain their own material and do no per-frame geometry work.

The orthographic angle remains fixed. Main owns a bounded ground-plane pan offset, the original camera home transform and shared zoom target. Right/middle drag, trackpad pan and two-finger touch movement cannot trigger farming taps. Home and Tools → Recenter restore the view; loading resets gesture ownership. Modal screens, conversations and the Tools drawer block map navigation. The fullscreen control keeps a large invisible input target around its compact vector icon.

Manual help replaces the floating FarmHelp banner. `test_farm_clarity.gd` checks that on-demand advice still opens and preserves its selected action while debt priorities change; `test_tutorial_hud.gd` checks the guide handoff without returning automatic banners. Existing full-barn warnings and blocked-action feedback remain available.


### v1.0.2.75 release

Mouse and single-finger island drags now pan, while short bed/shop taps retain their actions. Blank-ground taps never walk. Pointer deltas set a bounded camera destination and the render loop follows it with exponential damping (24/s), avoiding event-by-event jumps. Focus and resize cancel navigation. Pan checks cover intermediate frames, monotonic settling, gesture cancellation and picking.

## Gacha removal

Mechanics revision 22 removes random reward purchases, their UI and world building, Rook, reward-only effects and save validation. Save loading retains understood fields and drops retired NPC history. Saved optional tours retain their place after the removed stop. Surviving farm data still passes strict validation before state changes. Save backups and rejected-file protection remain intact.


### Item and special-crop removal

Mechanics revision 23 drops the item catalogue, wearable slots, passive collectibles, item multipliers and mutation discovery/quest fields. `assets/retired_save_fields.json` names legacy crop-storage and order fields solely for conversion; export presets include it. Stored special potatoes merge into ordinary storage by crop and quantity before validation. Malformed quantities and overflow are rejected through the existing rejected-save path. New saves contain no retired fields.

Barn capacity is recomputed from purchased barn levels alone. Existing crops are preserved even when the removed bonuses leave storage over capacity; further harvesting waits until room is available. Current saves therefore permit stored totals above capacity, bounded by `MAX_INVENTORY`, and overfull farms can save/reload. An unfinished special-crop order becomes a bulk order with its original target, delivered count and earned credit. Remaining shipments use ordinary quotes and the normal 25% premium. New bulk offers still start at 400 potatoes.

Inventory contains crop/seed shelves and five usable tools. The PotatoDex shows the six crop varieties without a discovery tab. The farmer keeps its base body, face and walk/turn animation. Fixed villager costumes live in `npc_avatar.gd`; `npc_portrait.gd` owns only the conversation viewport, lighting and adaptive resolution. The wardrobe preview, wearable meshes and clothing icon families are deleted.

`test_item_removal.gd` covers crop conversion, retired-field removal, overfull saves, corrupted legacy crops, converted contract accounting, ordinary sale prices, inventory actions and crop references. `test_round_avatar.gd` retains body, geometry and animation checks. Dedicated equipment/wardrobe suites and assertions for removed systems are deleted; ordinary farming, climate machinery and quest tests remain.


### Placeholder market (Segment 4)

`price_sparkline.gd` is restored for each Buy Seeds and Sell Potatoes card. Each variety’s history contains up to 12 quotes: prior 15-second sample boundaries plus the current quote. The deterministic price curve reconstructs these samples from saved elapsed time, so reloads retain the same history without a new save field or frame-rate-dependent sampling. A fresh farm starts with one quote. The shared percentage is `round((price / base - 1) × 100)`, with an explicit sign; only the comparison text is green above base or red below. Sparklines use neutral ink and no animation; card bounce tweens are removed.

The stock countdown, tracked-price tray, full chart page, market aura, launch presentation, launch audio and audio baker are removed. The main audio generator retains short action tones; farm foley and storm shake remain. Starter seed-buying and potato-selling quests now count ordinary transactions under their original save IDs. Their quest rewards are flat after Segment 6.


### Profession removal (Segment 5)

The Builds menu, C shortcut, workshop, lab, exchange desk, stake table, profession-only effects and Ada are gone. Shared NPC voices, the farmer, other villagers, crop varieties, climate, quest boards and island activities remain. Modal height measurement now belongs to `GameHUD`, shared by shops and touch help.

`test_profession_removal.gd` checks legacy loading, dropped fields, retained progress, ordinary yield/growth/tool coverage, missing world targets, the menu and the C key. Run it and the boot check through `tools/run_tests.sh -j 1 test_profession_removal test_game`.


### Small economy (Segment 6)

The tax cycle, account purchasing, recovery orders, timed harvest chains, mastery bonuses and scientific coin storage are removed. Healthy beds yield 3–5 sacks. Harvest-bed quests count cumulative beds without a timer; every quest pays 100 Spudions.

Starting cash is 2,000. Base prices are Russet 15, Giant 18, Golden 21, Radioactive 24, Sunburst 27 and Icecap 30. The 75% base seed ratio, bounded seasonal drift, twelve-quote sparklines and signed percentage remain. Tool upgrades cost 300–1,500; each field expansion costs 1,200. Three barn upgrades cost 300/800/2,000, giving 400/1,200/4,400 capacity. All money labels use rounded integers, thousands separators and the Spudion glyph; actual fractional seed costs and sale proceeds are retained.

Obsolete blind, tax-credit-land, debt-credit, purchase-review and debug-large-money suites are deleted. Mixed suites retain ordinary purchase, weather, layout and save coverage with the new values. `test_economy_scale.gd` covers prices, yields across all islands, exact seed ratio, starting funds, upgrades, integer display, cash-only purchases, overdraft persistence and legacy-field removal.


### One farm (Segment 7)

`FarmWorld.REGION` is fixed to 1. The Valley has one 24-bed array, twelve beds open initially and one 1,200-Spudion expansion for the remainder. All six varieties and all tool ranks are available here. The tropical and winter geometry builders, their terrain and decorative shore structures remain behind the region constant. Travel UI, boarding paths, ferry NPCs and regional state are removed.

There is one flock of at most two ducks, one set of climate projects and one water supply. Export ships, buyer contracts, Frostbreak, the furnace and their dedicated tests are deleted. Mixed suites keep their surviving checks on Valley fixtures. Freeze ice is cleared directly with the hoe. The arrival cinematic is removed; `chapter_subtitles.gd` preserves its timed text and skip control for the later year-start page.

Weather uses a constant 15% probability at the beginning of each working season, including the first Spring, when weather is calm. Any of the four disasters can occur. Existing 45-second warning, 30-second active and 75-second recovery phases remain. Tutorials and optional practice pause the calendar. Season time and RNG state round-trip through v4 saves.

`test_single_farm.gd` checks bed access, expansion, ordinary Sunburst/Icecap planting, absent regional save fields, rejection of old schemas, protected old paths, seasonal probability and reload continuity, reusable subtitles, Valley boot and the menu. `test_island_activities.gd` now covers only duck purchases, training, patrols and validation. Run with `tools/run_tests.sh -j 1 test_single_farm test_island_activities test_save_safety test_game`.


### Segment 8: seasonal calendar

`season_clock.gd` is a RefCounted object owned and serialized by GameState. Years are 1–10; Spring, Summer and Autumn each last 150 seconds. State splits simulation updates at season boundaries and discards excess time on entering Winter. Winter lasts until `start_next_year()` succeeds; year 10 remains in its final Winter. Existing conversation, practice and collapse pauses also pause the calendar. The first-harvest lesson keeps its protected growing time without advancing the calendar.

GameState finishes each boundary, synchronously saves through `boundary_save_path`, then emits `season_changed`. Main assigns the live save path; isolated tests leave it empty or use a disposable path. Thus Winter is persisted before its panel opens. Autumn clearing records the number of lost beds for a persistent, visible Winter notice, preserves barn inventory and resets weather to calm. Save validation checks calendar ranges, Winter's empty fields and calm weather. The next season's probability draw occurs on its first positive update, preserving RNG continuity across boundary saves.

Tilling and planting are limited to Spring and Summer; Autumn still allows harvest, watering, pest treatment and weather rescue. Crop times run from 75 to 225 seconds before weather penalties. The HUD shows year and season without a countdown, and maps the sun from dawn to dusk using calendar seconds. Winter reuses Frosthollow snow materials, roof cover and flakes on the Valley. Escape and the farm menu remain usable, including at the year-10 cap. HUD refreshes reconcile the displayed calendar and open Winter once per transition, so a missed season callback can recover without restarting. The main callback still cancels field actions and dismisses weather alerts.

Run `tools/run_tests.sh -j 1 test_season_clock test_day_night test_game` for the full working year, boundary save ordering, Autumn loss, Winter pause/reload, planting gates, seasonal growth, UI navigation, snow, sky mapping and boot. Older growth fixtures now wait for the selected variety's seasonal duration; calm-weather fixtures use deterministic RNG or an already-started season.


The accelerated calendar regression plays all ten years through the real 30× debug control and next-year buttons, checking each boundary save, both year displays, dismissal and completion. It also deliberately misses state notifications to verify recovery on the next regular HUD refresh. A fresh run did not reproduce the reported original display glitch; this test covers the missed-presentation failure mode without assuming its original trigger. After this change, all 72 suites pass serially and the explicit headless boot passes 39 checks. The touch-input harvest fixture now starts in calm weather so a random Spring disaster cannot obscure its input assertions.
