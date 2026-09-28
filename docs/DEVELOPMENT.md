# Development notes

## Project layout

- `project.godot` and `scenes/`: Godot project and entry scene.
- `scripts/`: game simulation, procedural world, player and interface.
- `assets/`: fonts, farm/weather audio and third-party notices.
- `tests/`: isolated simulation and scene regression checks.
- `tools/`: portable Web exporter and local preview server.
- `dist/` and `artifacts/`: generated builds and local verification output, excluded from Git.

## Saves

Taterland retains its earlier save names for compatibility: `user://spud_valley_save_v3.json` and the original `spud_valley_save.json` backup. Existing farms retain their coins, crops, tools and island progress. Browser and native saves remain separate.

Each successful save moves the previous file to `<path>.bak`, replacing the older rolling backup. A load rejected for size, malformed JSON or invalid data moves the candidate to `<path>.rejected`, replacing the previous rejected file and reporting that it was set aside. New-farm autosaves leave that file alone. The original v2 path is never moved or overwritten. `GameState.backup_path()` and `rejected_path()` also accept disposable test paths; pass the backup path to `load_game()` to recover the previous farm.

The native user-data directory is explicitly pinned to the existing **Spud Valley** location under Godot's application data. Renaming the game therefore continues to use the same desktop farm instead of creating a separate Taterland save folder. Browser saves still depend on the host address and browser profile.

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

#### Segment 5 — current

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

### Climate economy and taxes (v1.0.2)

`scripts/blind_rules.gd` retains progression baselines, 5% base tax, the bankruptcy allowance and saved collection state until Segment 6. Market events no longer advance the old counter. An already-due bill still finishes its remaining ten-second deadline; weather can contribute to that bill within the existing +150% pressure ceiling.

Collection deducts the displayed bill even if cash cannot cover it. Debt is playable; only crossing **strictly below** the bankruptcy line immediately ends the run. Equality survives. There is no wealth-based surplus levy. The pre-collection cash-to-tax ratio produces 2× OVERKILL, 5× ULTRA KILL, 10× GODLIKE, 25× OMNIPOTENT, 100× RULER, 1,000× COSMIC RULER and 1,000,000× REALITY BREAKER. Uncovered bills and balances show red. Signed finite double balances use suffixes through Dc, then scientific notation, up to ±1e300.

A first visit to a harder island resets the old collection counter at its tax tier. Returning to an earlier island keeps the highest visited tier and existing collection counter, preventing lower-tax travel loops. Last receipts retain actual tax, pre-tax cash, coverage, rank and post-tax debt.

`scripts/climate_system.gd` owns climate timing, losses and local protection costs. Island 1 is free from weather disasters. First arrival at Island 2 (or an older save already on Island 3) shows a one-time introduction that pauses the simulation until acknowledged. The first warning follows 90 seconds of eligible play. Calm weather clocks pause on Island 1; an already warned disaster continues against its original island and shared barn. Drought, flood and severe storm give 45 seconds to prepare, hit once, last 30 seconds and recover over 75 seconds; another calm interval lasts 210–330 seconds. Warnings preview the estimated bill after impact. Disasters destroy a severity-dependent portion of planted beds and stored potatoes. Floods also require damaged beds to be tilled again. Growth slows; placeholder prices are independent of climate. Temporary effects taper to normal during recovery; infrastructure pressure remains until the next tax collection.

Climate action funds two levels each of Rainwater Reserve, Drainage Network, Reinforced Barn and Living Windbreaks, priced relative to the local progression baseline. These reduce the relevant physical losses and recovery tax contributions. Funding during recovery can still lower a pending bill; it cannot restore destroyed crops. Damage remains attached to the warned island, while the shared barn is exposed wherever the player travels. One batched canvas layer draws drifting cloud banks, up to 100 rain streaks, wind ribbons, floodwater and drought dust. Existing 3D clouds accelerate and expand; the sky and sunlight respond. Original looped wind/rain audio and thunder accompany storms. Camera shake is bounded to 0.26 world units. No per-crop particle nodes are created.

Bankruptcy freezes the run and replaces the normal HUD with an editorial page: desaturated farm, heavy display typography, restrained cream, earth tones and muted debt red. It records the actual cause, climate phase, final balance, recent field/barn losses, tax and build. **View Run Summary** reveals run totals and funded projects; **Try Again** resets the farm and returns to the normal tutorial. The concise educational text paraphrases [FAO's disaster and agriculture report](https://www.fao.org/publications/fao-flagship-publications/the-impact-of-disasters-on-agriculture-and-food-security/); game event rates and tax multipliers are fictional balancing choices, not claims about real-world climate or tax policy.

Mechanics revision 14 retains the introduction flags alongside weather timers, affected island, severity, initiatives, losses, recent history, recovery tax pressure, the tax cycle and collapse report. Pre-revision-11 farms receive fresh climate timing and a fresh collection counter, while existing coins, inventory and progression are retained. An already lost run remains lost. Corrupt saves leave the live farm unchanged.

Focused checks (all isolated from real saves):

```sh
tools/run_tests.sh -j 1 test_blinds test_blinds_game test_climate test_climate_game
```

These cover every island baseline, tax clearing/borrowing, overkill, negative huge numbers, exact bankruptcy boundaries, tax-caused collapse, caps, full selling windows, event counting, travel, old-save migration, every weather phase, initiative benefits, corrupted saves, warning/deadline/death reloads, controller actions, responsive composition and restart. Omit `--headless` and add `--capture` to a scene check for screenshots under `artifacts/`.

The runner handles the initial import. For a focused simulation and boot check:

```sh
tools/run_tests.sh -j 1 test_simulation test_item_removal test_round_avatar test_game
```

Run `node tests/test_web_canvas.js` to verify browser resolution limits and aspect ratios. `test_debug_access_time.gd` covers the access gate and time controls; `test_placeholder_market.gd` covers bounded drift and retired-market save migration.

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

Balanced/Crisp use a single orthographic shadow map, zero pancake extrusion and a stable steep sun direction. Terrain shells do not cast onto the ocean. The 60-second sky/light cycle remains; Smooth disables the shadow map. `GraphicsPreferences` saves only the quality mode in `user://taterland_graphics.cfg`, independently of farm state. Existing Balanced/Smooth preferences remain valid.

`test_static_mesh_compiler.gd`, `test_farm_viewport.gd`, `test_graphics_preferences.gd`, `test_world_graphics_quality.gd` and `test_web_canvas.js` cover transformed geometry, cache reuse, all-island scaled input, letterboxing, sharp UI budgets, preference persistence and shadow bounds. Ferry and purchase input fixtures convert projected farm coordinates into logical screen coordinates before sending clicks.

Broader validation also checked existing island suites against the unmodified v1.0.1.5 sources. Two older Golden Shores layout assertions (reward card height and Sunburst sell-without-scroll), and the old feature UI fixture's Island 1 activity target assertion, already fail on that baseline; they are not introduced by the rendering update.

## GitHub Pages

The `docs/` folder includes the browser game and `.nojekyll` alongside these guides. Configure the repository's **Settings → Pages** to **Deploy from a branch**, **main**, **/docs**. Push changes using GitHub Desktop to publish them. The repository remains named Taterwake, so its expected address is `https://coursemain.github.io/Taterwake/` even though the game's title is Taterland.

After exporting an updated game, copy all `index.*` files and the license notices from `dist/web/` into `docs/`, keeping `.nojekyll` and the Markdown guides. Commit and push the updated files. The Web export excludes `docs/` to avoid bundling the published game inside the next export. No custom cross-origin headers are needed for this single-threaded build.

## Third-party notices

Patrick Hand, Fredoka, Oswald, Nunito Sans and Noto Sans Symbols are distributed under the SIL Open Font License; see the license files in `assets/fonts/`. Godot's engine license and third-party notices are in `assets/licenses/` and are included in browser packages. These notices describe their respective dependencies.

### v1.0.2 presentation preview

This presentation revision ships in v1.0.2. Normal UI headings use Fredoka; disaster announcements and the collapse page use Oswald, with Nunito Sans for body copy. Both new fonts come from the Google Fonts repository under the bundled SIL Open Font Licenses. The four climate initiatives use original code-drawn icons in a two-column grid. Tax rate tables, wealth-rank definitions and detailed run statistics are tucked behind explicit detail buttons. Main-menu tiles and descriptions are shorter. The collapse page preserves its serious educational message alongside the final balance and three loss figures.

`climate_alert.gd` shows a blocking first-arrival introduction and five-second nonblocking event announcements. Intro flags and pending acknowledgments survive saves; revision-11 saves get safe defaults, and old Island-1 weather is cleared. `climate_audio.gd` uses original, locally synthesized wind and thunder WAV assets. Public Pages files in `docs/index.*` have not been replaced.


### First-harvest lesson and contextual help

`first_island_tutorial.gd` now has eight stages (welcome, seed purchase, hoe, plant, water, growth, harvest, sale). The first sale ends mandatory guidance. Tools are auto-equipped with one bed cue; another empty hoe target retargets the lesson. Blocked input explains the current action. Normal no-op field actions also show their result. `TOUR` is a separate optional NPC tour: Next never requires a shop visit, transactions are blocked, and all farm timers are preserved while paused.

`farm_help.gd` stores optional tip dismissals, a tracked independent plant/water/harvest/sale cycle, first-infestation protection. New lessons enable help on completion or skip; established saves get no surprise tips. Tutorial version 1 stages through first sale map to version 2; later compulsory stops retire. Mechanics revision 13 saves help state, including protected field indices. Malformed help data is rejected before loading.

The first natural infestation is harmless until cleared or harvested, even when its tip is dismissed or the farm reloads. Additional infestations wait until that group is resolved, then normal damage resumes.

Contextual advice is available only through Help → Current farm help. The former FarmHelp overlay is an empty hidden compatibility node, so existing layout callers cannot restore the floating debt/tool reminders. Useful action feedback, bankruptcy/tax information and full-barn alerts remain separate. Saved first-pest protection, independent farming progress are unchanged. Dismissing a suggestion records dismissal only, not learning.

Validation: `test_tutorial_game.gd` walks the real first lesson and an unmarked second crop, then checks pests, optional tour and migration. `test_farm_help.gd` covers persistence, timing, normal later pest damage, affordability and corrupt saves. `test_tutorial_hud.gd` checks small/portrait layout and preserves tax and farming controls. Run scene checks with `-- --integration-test`; add `--capture` without `--headless` for `artifacts/guide-*.png`. The local Web ZIP is rebuilt; published `docs/index.*` files remain unchanged.

Base crop times are 10/25/40/50/55/60 seconds for Russet/Golden/Giant/Radioactive/Sunburst/Icecap. Each crop's active growth speed is bounded by `base_time / 60`, including weather penalties, while positive growth bonuses can still shorten the duration. Field updates and hover timers use that same bound. Dry/frozen crops and paused simulations do not consume growth time. Revision 14 validates older plots against `OLD_GROW_TIMES` before converting elapsed time by completion percentage; mature potatoes remain mature.

### Quiet farming feedback and shop signs

Shop signs use semibold Fredoka, matching the original rounded roll-button typography, with short names and a fine contrasting outline. Valley/Shores use cream lettering; winter uses dark lettering against snow. Labels remain clickable and retain tutorial visibility. Fredoka also supplies compact shop and menu headings and buttons; Nunito Sans remains on body copy and numeric status text.

Normal field actions never create central toasts. No-op feedback (for example, “Already watered” or “Plant a seed first [2]”) shares one click-through footer slot with hover hints, expires after 1.4 seconds, and does not extend on rapid identical repeats. Successful work clears stale failure text. Plot notifications are handled through this path once; a full barn still gets a short actionable reminder. Other notifications appear in a smaller upper-right card.

Optional help is one compact row below the tax card and hides for three seconds after field input. Its button explicitly opens the full explanation and action; the × dismisses without opening anything. The opened tip retains its own action if another tip becomes relevant while reading. The normal tax card shows any pending bill; coverage, projected balance and rules remain available on hover/click. Tiny positive coverage reads `<0.01%` rather than scientific notation. Save schema and gameplay are unchanged.

`test_farm_clarity.gd -- --integration-test` checks rapid repeated actions, feedback expiry, duplicate suppression, full-barn feedback, help action stability, responsive layout, percentage formatting and all-island typography. A native `--capture` run writes `artifacts/clarity-watering.png`, `clarity-island-1.png` through `clarity-island-3.png`, and `clarity-winter-warning.png`.

`climate_projects.gd` builds an island-local tank, perimeter drainage, braces on the existing barn, and a rear tree windbreak from the saved project levels. Second levels add visible infrastructure. `FarmWorld.set_climate_projects()` creates/batches geometry only when local levels change, and clears it on reset or island rebuild. The controller applies purchases immediately. Structures occupy gaps and field edges, keeping existing map dimensions and all crop targets accessible.


### v1.0.2 operational climate implementation

The hands-on climate preview supersedes the earlier instant field-loss behavior above. `climate_operations.gd` stores local reserves and operating settings, and advances drought/flood stress and warned lightning on deterministic quarter-second boundaries. Actual losses update the existing disaster receipt/history; onset still handles shared barn inventory and recovery-tax pressure. Simulation revision 16 saves operations alongside climate state. Older farms gain full basic supplies with their progress preserved; malformed reserves and hazard maps are rejected before loading.

`climate_field_visuals.gd` adds one instanced floodwater draw and two batched triangle surfaces for rings, scorch marks, pipe flow, screens and lightning. `flood_water.gdshader` uses ordinary Compatibility spatial shading, analytic waves, foam and farmer-proximity ripples; it requires no compute shaders, screen readback, fluid solver or per-droplet physics. Surface markings rebuild at most ten times per second. The full-screen canvas effect adds a drawn sun and heat ribbons and synchronizes lightning flashes to actual strikes. The field console offers nonmodal controls; the scrollable equipment panel places operations before purchases.

Checks: `test_climate_operations.gd` (reserves, tool rescues, irrigation, gates, lightning, saves and migration), `test_climate_visuals.gd` (renderable world effects/controls, optional `--capture`), and the updated climate/project/market regressions. `tools/preview_climate.py` builds the isolated browser fixture through `export_browser_benchmark.py --fixture climate`; its copied controller forces integration mode, so no real farm is loaded or saved. The regular Web export remains single-threaded WebGL Compatibility. Public `docs/index.*` files are intentionally unchanged until publication.

Final local QA used Safari on the Apple M4, Balanced, UI 3028×1604 and farm viewport 1919×1200. The 48-ripe-bed flood fixture measured 46.7 FPS, median 21.7 ms / p95 22.7 ms, 1,008 draw calls over eight seconds after warmup. A separate drought run with replanted beds measured 57.9 FPS; these are different scenes, not a controlled performance comparison. Water rendering, lightning scenes and operating irrigation were exercised in the exported single-threaded browser game. These observations do not guarantee a frame rate on other devices.


### Simplified Island 2 climate controls

This supersedes the blocking introduction and operating grid described above. `climate_lesson.gd` offers optional two-action practice on Island 2, with visual crop copies and paused simulation. The invitation itself permits normal farming; its weather timer waits for a choice. Practice advances from a single Water action to a direct area choice, shows the recovered crops briefly, then disappears. It is skippable and replayable during calm weather. Accepting grants a level-one tank if needed.

The compact field panel exposes one contextual action: drought area watering, flood drains, or storm shelter placement. Area watering is a one-time 8/6/4-water purchase based on irrigation level; mouse targeting and E support it, Escape cancels. No hidden flow is enabled. Reinforced shutters close automatically. Recovery has no emergency buttons. The equipment shop contains purchases and an Island 2 practice replay button, with no duplicate control grid.

Mechanics revision 17 persists lesson stages and rejects active practice layered over a real disaster. Older saves quietly mark an already-introduced farm's lesson done and disable legacy automatic irrigation, retaining reserves, projects and progress. `test_climate_lesson.gd` covers optional arrival, pause boundaries, real crop preservation, save/reload, skipped practice, direct area rescue, resource costs, contextual UI, recovery and migration. The browser lab now opens at the invitation and can reset it without loading or writing a real farm. Local exports use the existing WebGL Compatibility pipeline; published `docs/index.*` files remain unchanged.

Validation for the simplified flow: 33 lesson checks, 119 climate checks, 42 game checks, 23 operations checks and 196 responsive-layout checks passed, plus the climate visual checks. Safari browser QA completed both practice actions and flood drainage. Both the isolated lab and regular Web ZIP were rebuilt successfully.

### Connected water loop (mechanics revision 18)

This supersedes the previous climate console and area-targeting descriptions. See [the water-loop guide](CLIMATE_WATER_LOOP.md) for playtesting, balance choices and migration details. `water_loop_world.gd` owns dynamic gauges, carried can, shutter/gate motion and resource-flow drawings; its flow is batched into the existing 10 Hz climate marking mesh. `water_story.gd` draws the small before/action/after illustrations without external textures. Equipment has separate ray targets and fixed world connections. The nearby action card occupies the margin beside the farm so the highlighted beds remain visible.

Manual watering now spends the can in all weather. Refill is a walk-to-tank action that conserves tank plus can water. Normal sprinklers consume the shared tank only when their fixed patch needs watering. Drought stops tank replenishment only on the affected island. Water cannot relieve flood/storm damage or another island's hazards; frozen/locked beds are excluded. The first natural event is drought; starter irrigation arrives on Island 2 before it. Drain opening is idempotent and reduces actual danger. Trees protect their fixed far patch and shutters are automatic. Ordinary replenishment continues on Island 1 while its disaster clock remains disabled.

The isolated browser lab now has clean per-scenario resets, ordinary farming on both islands, optional practice, weather presets, an empty-can shortcut and upgrade access. Its collapsed toolbar avoids covering the equipment cards. Export still forces the copied controller into integration mode; real farms are neither read nor written. Published `docs/index.*` files remain unchanged.

Weather warning/impact announcements are now brief, nonblocking strips above the farm; recovery uses the existing field status card instead of a second large announcement.


### Pretest polish: stable buttons, spacious islands, sprint and carried tools

The climate console keeps active button visibility stable across resource/timer updates; previously `hide()` cancelled a held press before its release. `test_farm_interaction.gd` reproduces that failure with real viewport mouse input, then covers both invitation choices, sprinkler practice, sprint speed/arrival/menu blocking and can pose continuity. The field practice now has a brief destination label and arrow to remain readable at the expanded overview.

`FarmWorld.LAND_SPACING` is sqrt(1.5), giving each island 50% more land area. Terrain, roads, pier geometry, route anchors and peripheral prop positions expand together. Crop-grid geometry/indices and building dimensions stay intact; rain gutters, tank pipes and shoreline outlets use the new locations. Village crates/fences remain assembled rather than separating component meshes. Camera framing/limits and walking bounds expand too. Layout-only changes need no additional save migration.

Hold Shift for an eased 1.65× sprint on WASD/arrows or click routes. Avatar running stride responds to sprint blend. The persistent can follows the carrying hand, performs the pour itself, and interpolates to/from the tap; temporary tools use a soft pickup/stroke/put-away envelope. All animations remain code-native and use existing batched world effects. The isolated Climate Lab adds the winter scenario and movement hints. Local Web exports only; no public files or remote branches are updated.


### Playability and debug

Equipment cards avoid expanded tax forecasts, and notifications dock clear of modal controls. Debug has explicit funding for zero/negative balances and code-gated recovery after bankruptcy. Recovery keeps farm progress, resets collection timing and restores 1× time. Opening Debug pauses simulation. Travel warnings expose higher tax tiers; bankruptcy shows the actual receipt and debt threshold. Old receipts remain available without being misreported as new Debug-caused tax collections.

Run `tools/run_tests.sh -j 1 test_playability_audit test_debug_recovery` to check these flows.

### Touch and fullscreen verification (v1.0.2)

`TouchControls` owns finger IDs separately from keyboard actions. The stick supports simultaneous actions, an outer sprint ring and focus/resize cancellation. Farm taps commit on release; a second finger or drag cancels tapping until the gesture ends. Pinch distance changes the same bounded camera zoom used by the wheel; moving the two-finger center pans the map. Tools provides zoom buttons and Recenter. Desktop right/middle drag and two-finger trackpad scroll pan while Home restores the camera.

Touch uses at least 600 and at most 900 logical units on the short screen edge, with at least 68-unit buttons (44 CSS pixels on a 390px phone). Flexible menu rows stack when needed; scroll containers keep all activities and equipment reachable. The browser shell owns fullscreen requests in a trusted DOM gesture and fits its canvas inside safe-area insets. Native and browser controls draw an expand icon or exit cross on a transparent background; the visible mark is compact while the invisible hit target remains accessible. Browser fullscreen and F11 work independently of game menus. The fallback explains Home Screen installation when the browser rejects or lacks fullscreen.

Run `test_touch_controls.gd` with `-- --integration-test --touch-controls`. It checks phone portrait/landscape, iPad portrait/landscape and laptop sizes, all menus, multitouch movement and pinch cancellation. `tools/export_browser_benchmark.py --fixture mobile --label mobile --godot PATH` creates a disposable browser test build with a QA bridge; the bridge and test scene are excluded from the public export. Browser input checks use actual touch events, screenshots and enter/exit fullscreen at 390×844, 844×390, 768×1024, 1024×768 and 1366×768. These are emulated viewport checks, not claims of physical iPhone/iPad performance testing.

`tests/test_mobile_browser.cjs` automates the browser matrix with Playwright. Set `TATER_QA_URL` to the disposable mobile fixture URL and provide Playwright through `NODE_PATH` or a local installation. Captures and logs go to ignored `artifacts/mobile-qa/`.


### Buy Seeds and Sell Potatoes

`market_pages.gd` owns the Buy Seeds and Sell Potatoes pages with prices, quantities and confirmation controls. `market_quantity.gd` validates whole amounts and bounds them by available crops. Trading calls `FarmState.buy_seeds` and `sell_crop`; an explicit amount above inventory is rejected and `-1` means sell all. Committed receipts drive short transaction feedback.

Run `tools/run_tests.sh -j 1 test_seed_market test_placeholder_market test_disaster_markets`. Native `test_seed_market.gd -- --integration-test --capture` also captures desktop, portrait and landscape layouts. Tests cover purchases, payouts, quantity rejection, stable ordering, arrows, touch swipes, layout, drift bounds, climate independence and save migration. They also check the 12-quote limit, chronological samples, step-size independence, restored history after loading, and the displayed signed percentage and colours on cards and the top bar.

Balance note: base yields remain Russet 3, Giant 8, Golden 2, Radioactive 4, Sunburst 3 and Icecap 4. At an unchanged quote this yields about 2.67–10.67 times the seed spend before combos, mastery or island bonuses. Those remaining multipliers and harvest yields have not been rebalanced.

`test_market_dialogue.gd -- --integration-test` verifies first meetings, repeated tab switches, saved memory and deliberate Mara revisits. All scene tests use isolated state.

### Village identity and harvest feedback (source)

`harvest_feedback.gd` animates committed harvest snapshots without owning inventory: a short pull, release, soil scatter and landing. It caps concurrent receipts at 12 and soil clods at 64; repeat partial harvests replace the same bed’s receipt, and travel clears effects. `farm_audio.gd` creates cached PCM foley for five tools and ordinary/Giant harvests. Every crop uses the same potato model with growth tied to actual crop progress. Dry or frozen crops do not grow visually. Live plot references refresh after loading; growth scales the plant alone. The first lesson plants and harvests an ordinary Russet.

`village_details.gd` shares the world’s materials and compiled geometry for Mara’s stitched sacks, patched awning and potato-supported crate. Villagers retain deliberate positions and headings at their counters, entrances and pier. `exchange_surface.gd` supplies the timber counter and chalk board; crop portraits share the palette of `item_icon.gd`. Help uses ruled barn notes.

`shop_pages.gd` extends the seed counter's timber trays, item illustrations and button styles to Bram's workbench and Nell's barn. Tool upgrades retain their live costs and readiness; Barn offers Crops and Tools tabs, showing its crop ledger on Crops and keeping capacity expansion available on both shelves. Desktop trays become single-column phone shelves. Purchase receipts wrap in the remaining desktop margin, keeping the wider counters' controls clear.

Shop filler quotes and all-island duck-limit lists are removed. `duck_pond_view.gd` draws the local flock on an animated pond; hiring and training keep their existing actions. Full storage shows a persistent red banner with a Sell crops action, and blocking farm reminders use red on desktop and touch. `test_farm_alerts.gd -- --integration-test` checks the full/sell/clear flow; add `--touch-controls` to cover portrait and landscape bounds and touch targets. Normal harvesting again plays the escalating streak chime alongside the pull/pop foley.

Run `tools/run_tests.sh -j 1 test_harvest_identity test_village_identity test_crop_growth` for first-harvest yield, save/reload, partial/full barns, continuous growth, matching harvest models, animation cleanup and budgets, audio samples and bed/shop picking across islands. Native `--capture` records screenshots in `artifacts/`.


### Farm credit and weather console

`GameState.can_purchase()` validates finite costs against the existing bankruptcy boundary. Seeds, tools, barn/field expansion, duck hiring/training and climate equipment share this check; their HUD buttons use the same predicate and mark borrowed purchases. The tutorial keeps cash-only purchases. No save schema changes are required: the existing signed balance persists credit normally.

Recovery orders consume ordinary stored potatoes from lowest base price upward, paying 1% of the current tax-tier debt limit per potato, capped at outstanding debt. They neither generate positive cash nor count as market sales/quest sales. Free recovery seeds require an active indebted farm with no seeds, ordinary crops or growing plants. Bankruptcy remains final for ordinary actions.

`weather_pages.gd` owns the navy/cyan station dashboard; `weather_display.gd` draws the live radar and equipment schematics without raster assets or illustration captions. Protection values, water, costs and timers come from the existing climate state. `weather_station.gd` keeps its interaction footprint while adding photovoltaic fins, emissive instrument lines and a scanning dish. The Tools hotbar footer and contract partial-delivery footer have been removed.

`test_debt_credit.gd` covers real shop actions, exact credit limits, atomic rejection, free-seed farming through repayment, all tax tiers, save/load and ended runs. `test_weather_dashboard.gd` covers live telemetry, pointer checkout, warnings and desktop/phone layout; native `--capture` writes isolated previews. Existing purchase/climate fixtures now test exhausted credit instead of empty cash. Legacy receipt assertions for removed scouting/market-call services were retired..


### Island surfaces and camera movement

`island_terrain.gdshader` adds filtered grain and soft, irregular surface variation to sand and snow. Sand has a neutral dry/damp transition; winter uses cool powder shading and smoothly feathered snowbank geometry. Scallop and spiral shells sit in small tide-line clusters outside the working paths. Static shells are batched; ground shader meshes retain their own material and do no per-frame geometry work.

The orthographic angle remains fixed. Main owns a bounded ground-plane pan offset, the original camera home transform and shared zoom target. Right/middle drag, trackpad pan and two-finger touch movement cannot trigger farming taps. Home and Tools → Recenter restore the view; travel/load resets gesture ownership. Modal screens, conversations and the Tools drawer block map navigation. The fullscreen control keeps a large invisible input target around its compact vector icon.

Manual help replaces the floating FarmHelp banner. `test_farm_clarity.gd` checks that on-demand advice still opens and preserves its selected action while debt priorities change; `test_tutorial_hud.gd` checks the guide handoff without returning automatic banners. Existing full-barn warnings and blocked-action feedback remain available.


### v1.0.2.75 release

Mouse and single-finger island drags now pan, while short bed/shop taps retain their actions. Blank-ground taps never walk. Pointer deltas set a bounded camera destination and the render loop follows it with exponential damping (24/s), avoiding event-by-event jumps. Focus and resize cancel navigation. Pan checks cover intermediate frames, monotonic settling, gesture cancellation and picking.

The weather footer uses a VBox and expanding buttons so wrapped labels cannot collapse into tall, narrow Grid columns. Furnace UI uses a code-drawn animated hearth; the exterior uses batched brick/copper geometry with persistent embers. The 25-Icecap, 20-second burst, 60-second cooldown and free thawing bellows are unchanged.

Quest cash uses explicit shares of each island’s progression baseline. Valley cash: $5K/$15K/$30K; Shores: $200M/$2.5B/$1B/$5B; Frosthollow: $10T/$125T/$250T. Ground-breaking quests also award seeds. Claims remain one-time across save migration.

Browser verification uses an isolated QA export, real Chromium mouse/touch events and screenshots at desktop/phone sizes. `test_update_browser.cjs` checks motion between input events, lower weather controls, furnace and all three graphics modes. `test_release_browser.cjs` checks the production export, version, fullscreen and absence of the QA bridge; set `TATER_RELEASE_URL` to run it against GitHub Pages. These are browser checks, not physical-device performance claims.

## Gacha removal

Mechanics revision 22 removes random reward purchases, their UI and world building, Rook, reward-only effects and save validation. Save loading retains understood fields and drops retired NPC history. Saved optional tours retain their place after the removed stop. Surviving farm data still passes strict validation before state changes. Save backups and rejected-file protection remain intact.

`test_gacha_removal.gd` covers migration from revision 21, retained farm/quest progress, discarded fields, the menu, the R key and all three island rebuilds. Pest audio retains its own coverage. Run the full baseline with `tools/run_tests.sh -j 1`.


### Item and special-crop removal

Mechanics revision 23 drops the item catalogue, wearable slots, passive collectibles, item multipliers and mutation discovery/quest fields. `assets/retired_save_fields.json` names legacy crop-storage and order fields solely for conversion; export presets include it. Stored special potatoes merge into ordinary storage by crop and quantity before validation. Malformed quantities and overflow are rejected through the existing rejected-save path. New saves contain no retired fields.

Barn capacity is recomputed from purchased barn levels alone. Existing crops are preserved even when the removed bonuses leave storage over capacity; further harvesting waits until room is available. Current saves therefore permit stored totals above capacity, bounded by `MAX_INVENTORY`, and overfull farms can save/reload. An unfinished special-crop order becomes a bulk order with its original target, delivered count and earned credit. Remaining shipments use ordinary quotes and the normal 25% premium. New bulk offers still start at 400 potatoes.

Inventory contains crop/seed shelves and five usable tools. Build activities and production queues remain on their own pages. The PotatoDex shows the six crop varieties without a discovery tab. The farmer keeps its base body, face and walk/turn animation. Fixed villager costumes live in `npc_avatar.gd`; `npc_portrait.gd` owns only the conversation viewport, lighting and adaptive resolution. The wardrobe preview, wearable meshes and clothing icon families are deleted.

`test_item_removal.gd` covers crop conversion, retired-field removal, overfull saves, corrupted legacy crops, converted contract accounting, ordinary sale prices, inventory actions and crop references. `test_round_avatar.gd` retains body, geometry and animation checks. Dedicated equipment/wardrobe suites and assertions for removed systems are deleted; ordinary farming, climate machinery, quests and build tests remain.


### Placeholder market (Segment 4)

Mechanics revision 24 drops the old saved market quotes/history, temporary price events, tracked-price preferences and practice-boom help. Prices are derived from saved `elapsed`: `base × (1 + 0.15 × sin(TAU × phase))`, with a 600-second cycle. Seed cost is always 75% of base, rounded to cents. Weather damage, ship visits and Frostbreak no longer multiply prices. Existing coins, crops, progression and pending tax deadlines survive migration.

`price_sparkline.gd` is restored for each Buy Seeds and Sell Potatoes card. Each variety’s history contains up to 12 quotes: prior 15-second sample boundaries plus the current quote. The deterministic price curve reconstructs these samples from saved elapsed time, so reloads retain the same history without a new save field or frame-rate-dependent sampling. A fresh farm starts with one quote. The shared percentage is `round((price / base - 1) × 100)`, with an explicit sign; only the comparison text is green above base or red below. Sparklines use neutral ink and no animation; card bounce tweens are removed.

The stock countdown, tracked-price tray, full chart page, market aura, launch presentation, launch audio and audio baker are removed. The main audio generator retains short action tones; farm foley and storm shake remain. Starter seed-buying and potato-selling quests now count ordinary transactions under their original save IDs. Their rewards and all other quest scaling remain for Segment 6.


### Profession removal (Segment 5)

Mechanics revision 25 removes the five builds, XP and levels, compost bonuses, seed-bank traits, processing, reserved buyers and harvest stakes. Old saves drop the entire `builds` block, including its queued/processed inventory; ordinary stored crops, coins, quests and island progress remain. Per-bed cultivation/trait fields, Ada’s dialogue memory and the Builds tip are removed before validation. Old optional tours retain their next surviving stop; current saves never shift twice. The first-harvest lesson now uses an ordinary Russet.

The Builds menu, C shortcut, workshop, lab, exchange desk, stake table, profession-only effects and Ada are gone. Shared NPC voices, the farmer, other villagers, crop varieties, climate, quest boards and island activities remain. Furnace heat affects crop growth only. Modal height measurement now belongs to `GameHUD`, shared by shops and touch help.

`test_profession_removal.gd` checks legacy loading, dropped fields, retained progress, ordinary yield/growth/tool coverage, missing world targets, the menu and the C key. Run it and the boot check through `tools/run_tests.sh -j 1 test_profession_removal test_game`.
