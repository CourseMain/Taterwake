# Development notes

## Project layout

- `project.godot` and `scenes/`: Godot project and entry scene.
- `scripts/`: game simulation, procedural world, player and interface.
- `assets/`: fonts, farm/weather audio and third-party notices.
- `tests/`: isolated simulation and scene regression checks.
- `tools/`: portable Web exporter and local preview server.
- `dist/` and `artifacts/`: generated builds and local verification output, excluded from Git.

## Development release

The redesign source is version `2.0.0-undeveloped-d`, published as the GitHub prerelease **v2.0.0(undeveloped:d)** from the `redesign` branch. This tag covers Segments 1–13 plus harvest quality and seed saving before economy tuning. The earlier `v2.0.0-undeveloped-c` tag covers Segments 1–12, `v2.0.0-undeveloped-b` covers Segments 1–11, and `v2.0.0-indevelopment` covers Segments 1–8. The public browser build remains v1.0.3.1; source prereleases do not deploy `docs/index.*` or change `web/`.

## Saves

Current saves use `user://taterland_save_v4.json`, schema 4 and mechanics revision 37. Earlier saves, including revision 36, are set aside as incompatible. There is no stored `coins` field: the journal reconstructs the purse. Older schemas are rejected, with no migration or fallback loader. The original v2 and v3 paths are protected from reads, writes and rejection moves. Browser and native saves remain separate.

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

#### Harvest grades — current

Godot 4.7.2, `tools/run_tests.sh -j 4`: **78 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS** (`artifacts/release-d-baseline.txt`). After the final hint sizing fix, all six affected suites pass again: grades, touch controls, HUD layout, farm interaction, branding and boot (`artifacts/grades-flicker-check.txt`). `test_grades` passes 82 checks, including growth/grade hover content, compact wrapping and stable hint geometry/visibility across repeated refreshes.

The required explicit headless boot passes 39 checks (`artifacts/grades-flicker-boot.txt`). Native GL Compatibility with touch controls passes all 82 grade checks (`artifacts/grades-flicker-native.txt`). The smaller explicit grade tag, growth/grade hint, harvest label, desktop/phone sale rows, barn seed controls and Winter grade totals were visually inspected. Browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 13 — historical

Godot 4.7.2, `tools/run_tests.sh -j 4`: **77 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS** (`artifacts/segment13-baseline.txt`). The new `test_climate_curve` passes 81 checks, including seeded curve/signal sampling, seasonal pools and caps, saved outlook, Winter stored-sack/Icecap losses, incremental insurance, untouched fresh harvests and empty beds, seasonal palettes, crossfades, front-page pause/skip and shared accounts history. The updated protection suite passes 246 checks. No tests are skipped or disabled.

The required headless boot passes 39 checks (`artifacts/segment13-boot.txt`). Native GL Compatibility with touch controls passes all 81 climate-curve checks (`artifacts/segment13-native.txt`); all seasons in years one and six and desktop/phone front pages were captured and visually inspected. Browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 12 follow-up — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **76 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. `test_protection` passes 267 checks, including all four disasters across Spring/Summer/Autumn with barn stock intact, no barn weather cause cards or claims, unchanged Winter spoilage, Hoe-only ice clearing, batch-cover eligibility and the single-bed context action. Climate, foreclosure, touch, NPC and weather-page suites also pass. No tests are skipped or disabled. The serial report is `artifacts/segment12-followup-baseline.txt`.

The explicit headless boot passes 39 checks (`artifacts/segment12-followup-boot.txt`), with the existing ObjectDB teardown warning. Native GL Compatibility with touch controls passes all 267 protection checks (`artifacts/segment12-followup-native.txt`); the phone weather page’s dedicated cover control was visually checked. Browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 12 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **76 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. The new `test_protection` passes 207 checks, including actual protected harvests, aggregate rounding across reloads, site labour, unfinished work, covers, insurance, upkeep, forecast ranges and cause-card arithmetic. Existing climate, water, ledger, season and UI suites also pass. No tests are skipped or disabled. The serial report is `artifacts/segment12-baseline.txt`.

The explicit headless boot passes 39 checks (`artifacts/segment12-boot.txt`), with the existing five-instance ObjectDB teardown warning. Native GL Compatibility passes all 207 protection checks with touch controls (`artifacts/segment12-native.txt`). Construction sites, bed covers and desktop/phone forecast, notice and accounts pages were visually inspected. Browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 11 follow-up — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **75 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. This includes `test_market_decisions` (110 checks), `test_ledger` (118), `test_season_clock` (123), `test_seed_market` (216), `test_single_farm` (265) and `test_game` (39). No tests are skipped or disabled. The serial report is `artifacts/segment11-followup-baseline.txt`.

Regressions cover Autumn harvests filling buyer orders, active Autumn saves, collection before storage fees and spoilage, whole-barn nearest rounding, a lone sack surviving, largest-pile allocation and deterministic ties. Ledger checks cover running balance updates, rejected/zero postings, reload replacement and independent overflow validation. The explicit headless boot passes 39 checks with the existing ObjectDB teardown warning. Native GL Compatibility passes 110 market checks with touch controls; desktop and phone sell pages and the phone buyer board were visually inspected. Browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 11 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **75 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including the new `test_market_decisions` (75 checks in the serial baseline), `test_ledger` (110), `test_season_clock` (123) and `test_game` (39). The final retained-sale-quest regression then passes 76 market-decision checks plus all seven quest HUD checks in a focused runner pass. No tests are skipped or disabled. The complete serial report is `artifacts/segment11-baseline.txt`.

The first serial run exposed an old recovery assertion that expected pre-spoilage stock, overlapping buyer/duck interaction targets, and a phone fixture using desktop logical scaling. Recovery now checks surviving stores, the restored board sits beside the northern shops, and the phone fixture uses the game's minimum logical width. The calendar fixture now expects Winter spoilage. All affected suites pass.

The explicit headless boot passes 39 checks, with the existing ObjectDB teardown warning. Native GL Compatibility passes the desktop/phone market-decision checks with touch controls; the dashed price marker, reachable storage actions, buyer result and Winter fee/spoilage account lines were visually inspected. The temporary Web resource pack passes all 76 market-decision checks. Browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 10 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **74 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_crop_table` (136 checks), `test_simulation` (54), `test_season_clock` (123), `test_seed_market` (216) and `test_game` (39). No tests are skipped or disabled. The serial report is `artifacts/segment10-baseline.txt`.

Fixtures now read the shared table and expect five varieties and per-variety drift. Windbreak comparisons use watered crops so ordinary dry stress does not obscure storm protection. The tutorial fixture uses single-farm protected-bed indices and a fixed RNG, clearing disaster ice before spraying; the initial serial run exposed its attempt to spray frozen beds.

The explicit headless boot passes 39 checks, with the existing ObjectDB teardown warning. Native GL Compatibility checks pass all 136 crop checks at desktop and phone widths, including the actual touch layout. The five-card desktop row and readable phone dials were visually inspected. A temporary Web resource pack also passes 136 crop checks; this verifies packaged resources, not a browser runtime. Published `docs/index.*` and `web/` remain untouched.

#### Working Winter correction — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **73 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_season_clock` (125 checks), `test_ledger` (110), `test_day_night` (318) and `test_game` (39). No tests are skipped or disabled. The serial report is `artifacts/working-winter-baseline.txt`.

The clock suite now plays four-season years, preserves cleared/uncleared ice through saves and Spring weather, checks quarter-rate Winter tank replenishment, pauses and reopens annual accounts, and completes ten full years at 30×. The market fixture now expects six years and six bills from a 3,600-second simulation instead of stopping at the first Winter. NPC prompt assertions were unchanged; their teardown now waits for the audio mixer, resolving an intermittent resource-in-use exit error.

The explicit headless boot passes 39 checks; Godot still emits the existing ObjectDB teardown warning. Native Compatibility checks pass for the working Winter scene and phone accounts (112 ledger checks). Snow, bed ice, cleared ground and the reachable Return to farm button were visually inspected. A temporary Web resource pack passes all 125 clock checks; browser runtime automation was not rerun. Published `docs/index.*` and `web/` remain untouched.

#### Segment 9 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **73 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_ledger` (108 checks), `test_season_clock` (118) and `test_game` (39). No tests are skipped or disabled. The complete serial result is `artifacts/segment9-baseline.txt`.

Older fixtures now expect journal saves, bounded overdraft purchases and foreclosure after the complete Winter bill. Funded calendar fixtures cover ten years without accidentally foreclosing. The conversation fixture pauses the main loop before its first frame and uses a deterministic RNG: previously a random Spring warning followed by a manual calm phase could create an invalid save. Ledger scene teardown allows the audio mixer to release its final playback before exit.

The explicit headless boot passes all 39 checks (Godot still reports an ObjectDB teardown warning). Native GL Compatibility passes 108 ledger checks on desktop and 110 with touch controls. Desktop accounts and portrait accounts, foreclosure and ten-year summary captures were visually inspected. A temporary Web resource pack also passes all 108 ledger checks; this is packed-resource validation, not a browser runtime test. Published `docs/index.*` and `web/` remain unchanged.

#### Segment 8 — historical

Godot 4.7.2, `tools/run_tests.sh -j 1`: **72 PASS, 0 FAIL, 0 TIMEOUT, 0 ERRORS**. Every discovered suite passes, including `test_season_clock` (118 checks), `test_day_night` (314) and `test_game` (39). No tests are skipped or disabled. That segment’s complete serial result is `artifacts/season-display-baseline.txt`; the initial Segment 8 result remains in `artifacts/segment8-baseline.txt`.

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

`climate_system.gd` retains warnings, physical field-crop losses, protection, weather phases and the collapse report. Weather never changes prices or generates a bill. Protection uses the Winter construction and annual upkeep rules described in Segment 12 below. `save_validation.gd` supplies finite-number validation shared with climate saves.

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

Base crop times are 75/105/135/195/225 seconds for Russet/Golden/Giant/Sunburst/Icecap. Active growth speed is bounded by `base_time / 450`, including weather penalties. Field updates and hover timers use the same bound. Dry crops, disaster-frozen crops and paused simulations do not consume growth time. Icecap grows through seasonal bed ice. The calendar format does not migrate earlier save revisions.

### Quiet farming feedback and shop signs

Shop signs use semibold Fredoka, matching the original rounded roll-button typography, with short names and a fine contrasting outline. Valley/Shores use cream lettering; winter uses dark lettering against snow. Labels remain clickable and retain tutorial visibility. Fredoka also supplies compact shop and menu headings and buttons; Nunito Sans remains on body copy and numeric status text.

Normal field actions never create central toasts. No-op feedback (for example, “Already watered” or “Plant a seed first [2]”) shares one click-through footer slot with hover hints, expires after 1.4 seconds, and does not extend on rapid identical repeats. Successful work clears stale failure text. Plot notifications are handled through this path once; a full barn still gets a short actionable reminder. Other notifications appear in a smaller upper-right card.

`test_farm_clarity.gd -- --integration-test` checks rapid repeated actions, feedback expiry, duplicate suppression, full-barn feedback, help action stability, responsive layout and Valley typography. A native `--capture` run writes `artifacts/clarity-watering.png`, `clarity-island-1.png` through `clarity-island-3.png`, and `clarity-winter-warning.png`.

`climate_projects.gd` builds a farm tank, perimeter drainage, a rear tree windbreak, a frost-cover rack and per-bed covers. `FarmWorld.set_climate_projects()` creates/batches geometry only when completed levels change, and clears it on reset or world rebuild. Paid reservations have separate marked work sites; completion replaces those sites with the upgraded geometry. Retired sites unregister their interaction targets before leaving the tree. Structures occupy gaps and field edges, keeping existing map dimensions and all crop targets accessible.


### v1.0.2 operational climate implementation

`climate_field_visuals.gd` adds one instanced floodwater draw and two batched triangle surfaces for rings, scorch marks, pipe flow, screens and lightning. `flood_water.gdshader` uses ordinary Compatibility spatial shading, analytic waves, foam and farmer-proximity ripples; it requires no compute shaders, screen readback, fluid solver or per-droplet physics. Surface markings rebuild at most ten times per second. The full-screen canvas effect adds a drawn sun and heat ribbons and synchronizes lightning flashes to actual strikes. The field console offers nonmodal controls; the scrollable equipment panel places operations before purchases.


### Optional water practice

Validation for the simplified flow: 33 lesson checks, 119 climate checks, 42 game checks, 23 operations checks and 196 responsive-layout checks passed, plus the climate visual checks. Safari browser QA completed both practice actions and flood drainage. Both the isolated lab and regular Web ZIP were rebuilt successfully.

### Connected water loop (mechanics revision 18)

Manual watering spends carried can water in all weather. Refilling conserves tank plus can water. Connected sprinklers consume the same reserve; drought stops rain replenishment. Frozen and locked beds are excluded. Drain opening is idempotent. Completed windbreaks reduce storm field losses across the farm. Reinforced barn projects, automatic shutters and their dedicated geometry, illustrations and save flag have been removed.

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

`shop_pages.gd` extends the seed counter's timber trays, item illustrations and button styles to Bram's workbench and Nell's barn. Tool upgrades retain their live costs and readiness; Barn offers Crops and Tools tabs, showing its crop ledger on Crops and keeping capacity expansion available on both shelves. Desktop trays become single-column phone shelves. Purchase receipts wrap in the remaining desktop margin, keeping the wider counters' controls clear. Receipt details use the shared body-font variation with its Spudion fallback; overriding it with the raw Nunito font produces a missing-character box for U+E000. The purchase HUD suite checks glyph coverage. The focused purchase HUD, purchase scene and boot suites pass (23/16/39 checks); native receipt captures also pass.

Shop filler quotes and all-island duck-limit lists are removed. `duck_pond_view.gd` draws the local flock on an animated pond; hiring and training keep their existing actions. Full storage shows a persistent red banner with a Sell crops action, and blocking farm reminders use red on desktop and touch. `test_farm_alerts.gd -- --integration-test` checks the full/sell/clear flow; add `--touch-controls` to cover portrait and landscape bounds and touch targets. Normal harvesting again plays the escalating streak chime alongside the pull/pop foley.

Run `tools/run_tests.sh -j 1 test_harvest_identity test_village_identity test_crop_growth` for first-harvest yield, save/reload, partial/full barns, continuous growth, matching harvest models, animation cleanup and budgets, audio samples and bed/shop picking on the Valley farm. Native `--capture` records screenshots in `artifacts/`.


### Purchases and weather console

`GameState.can_purchase()` accepts finite, nonnegative costs only when the resulting balance stays at or above the ledger’s −5,000 overdraft limit and the run is active. Shop buttons share that predicate; failed actions emit rejection feedback without inventory changes or success receipts. Account warnings, review overlays and recovery orders are removed.

`weather_pages.gd` uses the cream UI for next-season probability ranges, live tank levels, protection, construction, insurance, costs and timers. `test_weather_dashboard.gd` checks telemetry, purchase limits, warnings and desktop/phone layout; native `--capture` writes isolated previews.

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

Barn capacity is recomputed from purchased barn levels alone. Existing crops are preserved even when the removed bonuses leave storage over capacity; further harvesting waits until room is available. Current saves therefore permit stored totals above capacity, bounded by `MAX_INVENTORY`, and overfull farms can save/reload. Those migration-era orders were removed with the islands. Segment 11 introduces a new single-farm contract format.

Inventory contains crop/seed shelves and five usable tools. The PotatoDex shows the five crop varieties without a discovery tab. The farmer keeps its base body, face and walk/turn animation. Fixed villager costumes live in `npc_avatar.gd`; `npc_portrait.gd` owns only the conversation viewport, lighting and adaptive resolution. The wardrobe preview, wearable meshes and clothing icon families are deleted.

`test_item_removal.gd` covers crop conversion, retired-field removal, overfull saves, corrupted legacy crops, converted contract accounting, ordinary sale prices, inventory actions and crop references. `test_round_avatar.gd` retains body, geometry and animation checks. Dedicated equipment/wardrobe suites and assertions for removed systems are deleted; ordinary farming, climate machinery and quest tests remain.


### Placeholder market (Segment 4)

`price_sparkline.gd` is restored for each Buy Seeds and Sell Potatoes card. Each variety’s history contains up to 12 quotes: prior 15-second sample boundaries plus the current quote. The deterministic price curve reconstructs these samples from saved elapsed time, so reloads retain the same history without a new save field or frame-rate-dependent sampling. A fresh farm starts with one quote. The shared percentage is `round((price / base - 1) × 100)`, with an explicit sign; only the comparison text is green above base or red below. Sparklines use neutral ink and no animation; card bounce tweens are removed.

The stock countdown, tracked-price tray, full chart page, market aura, launch presentation, launch audio and audio baker are removed. The main audio generator retains short action tones; farm foley and storm shake remain. Starter seed-buying and potato-selling quests now count ordinary transactions under their original save IDs. Their quest rewards are flat after Segment 6.


### Profession removal (Segment 5)

The Builds menu, C shortcut, workshop, lab, exchange desk, stake table, profession-only effects and Ada are gone. Shared NPC voices, the farmer, other villagers, crop varieties, climate, quest boards and island activities remain. Modal height measurement now belongs to `GameHUD`, shared by shops and touch help.

`test_profession_removal.gd` checks legacy loading, dropped fields, retained progress, ordinary yield/growth/tool coverage, missing world targets, the menu and the C key. Run it and the boot check through `tools/run_tests.sh -j 1 test_profession_removal test_game`.


### Small economy (Segment 6)

The tax cycle, account purchasing, recovery orders, timed harvest chains, mastery bonuses and scientific coin storage are removed. Healthy beds yield 3–5 sacks. Harvest-bed quests count cumulative beds without a timer; every quest pays 100 Spudions.

Starting cash is 2,000. Base prices are Russet 15, Giant 18, Golden 21, Sunburst 27 and Icecap 30. The 75% base seed ratio, bounded seasonal drift, twelve-quote sparklines and signed percentage remain. Tool upgrades cost 300–1,500; each field expansion costs 1,200. Three barn upgrades cost 300/800/2,000, giving 400/1,200/4,400 capacity. All money labels use rounded integers, thousands separators and the Spudion glyph; actual fractional seed costs and sale proceeds are retained.

Obsolete blind, tax-credit-land, debt-credit, purchase-review and debug-large-money suites are deleted. Mixed suites retain ordinary purchase, weather, layout and save coverage with the new values. `test_economy_scale.gd` covers prices, yields, exact seed ratio, starting funds, upgrades, integer display, bounded overdraft purchases, Winter foreclosure and legacy-field removal.


### One farm (Segment 7)

`FarmWorld.REGION` is fixed to 1. The Valley has one 24-bed array, twelve beds open initially and one 1,200-Spudion expansion for the remainder. All five varieties and all tool ranks are available here. The tropical and winter geometry builders, their terrain and decorative shore structures remain behind the region constant. Travel UI, boarding paths, ferry NPCs and regional state are removed.

There is one flock of at most two ducks, one set of climate projects and one water supply. Export ships, buyer contracts, Frostbreak, the furnace and their dedicated tests are deleted. Mixed suites keep their surviving checks on Valley fixtures. Freeze ice is cleared directly with the hoe. The arrival cinematic is removed; `chapter_subtitles.gd` preserves its timed text and skip control for the later year-start page.

Weather makes one year-based probability draw at each season start, including the first Spring and Winter, up to three disasters per year. The seasonal pools and escalation constants live in `climate_system.gd` (Segment 13 below). Existing 45-second warning, 30-second active and 75-second recovery phases remain. Tutorials, the annual front page and optional practice pause the calendar. Season time, pending outlook and RNG state round-trip through v4 saves.

`test_single_farm.gd` checks bed access, expansion, ordinary Sunburst/Icecap planting, absent regional save fields, rejection of old schemas, protected old paths, seasonal probability and reload continuity, reusable subtitles, Valley boot and the menu. `test_island_activities.gd` now covers only duck purchases, training, patrols and validation. Run with `tools/run_tests.sh -j 1 test_single_farm test_island_activities test_save_safety test_game`.


### Segment 8: seasonal calendar

`season_clock.gd` is owned and serialized by GameState. All four seasons last 150 seconds, and Winter rolls into the next Spring automatically. The clock stays at year 10, season 3, second 150 only when the run is complete. Save validation admits this terminal time only for the completed outcome. The old `winter_menu` flag and `start_next_year()` action are removed.

State splits updates at every boundary, finishes clearing/billing, synchronously saves through `boundary_save_path`, then emits `season_changed`. At Winter start, Main sets the transient `accounts_open` pause before another simulation step can run; HUD opening/closing owns that pause thereafter. Accounts interrupt excess time even at 30×. Standalone state simulations without a UI can advance a complete 600-second year in one update. The pause is not serialized: opening a saved Winter displays accounts again, and closing them resumes its saved second. Conversations, practice and foreclosure retain their pauses.

Autumn clears non-Icecap growing/ripe crops and prepared soil, records the loss notice, preserves living Icecap and barn stock, and calms weather. Each plot then receives a saved `winter_ice` boolean. `ClimateOperations.frozen()` combines that flag with disaster ice; Hoe clears either kind, with tilling requiring a later action. Weather resets, recovery and crop clearing cannot erase seasonal ice. Climate presentation combines both sources for the existing frost meshes. All plots freeze, including locked beds; normal access limits still apply.

Tilling remains Spring/Summer only. Icecap also plants in Autumn and grows and harvests through seasonal Winter ice; other varieties plant only in Spring/Summer. Winter tank replenishment is 1.5 units per second versus the normal 6, halved during a drought precursor. Winter can draw deep freeze or blizzard. The market and clock continue. Snow ground/roofs remain through the season, and the seasonal sun traverses a lower, paler arc instead of holding at dusk.

Run `tools/run_tests.sh -j 1 test_season_clock test_day_night test_ledger test_game` for four-season boundaries and saves, accounts pausing/reopening, automatic rollover, persistent ice and Spring labour, quarter-rate water, seasonal growth, final completion and rendering. The 30× regression plays all ten years and deliberately misses callbacks to verify HUD reconciliation for accounts and completion. Native `test_season_clock.gd -- --integration-test --capture` records the working Winter in `artifacts/working-winter.png`.


### Segment 9: annual ledger

`ledger.gd` owns signed entries `{year, season, category, label, amount}` and the constants from REDESIGN_PLAN §6: 2,000 opening cash, a −5,000 overdraft, the 20,000 original loan and all five fixed-cost postings. It supplies category/year totals, closed years, years in profit and best/worst year. The annual 4,500 bill includes two mortgage entries (1,000 interest and 1,000 principal), 500 rent/tax, 1,500 living and 500 upkeep. Loan principal falls by 1,000 for each billed Winter.

`GameState.coins` reads the ledger’s cached running balance in O(1). Successful postings update it, and loading reconstructs it from entries; the cache is never saved. The validator independently recomputes the balance from journal entries. Production transactions use `post_money()` with their category and label, including climate protection and duck purchases. Debug/fixture assignments to `coins` post an adjustment; they never store a second balance. Sales post their full actual receipts without the former wallet cap. Returned entries are deep copies so presentation cannot mutate the journal. Ended runs reject further state transactions.

Autumn clearing and all fixed costs finish before the boundary save and notifications. Closed-year markers prevent duplicate bills after reload. A balance strictly below −5,000 then sets `run_outcome = "foreclosed"`; equality survives. The end of a surviving year-10 Winter sets `completed`; its start only posts the bill and opens accounts. Foreclosure reports include the same ledger year, net, categories and balance. Save validation rejects independent balances, future or malformed entries, inconsistent closure/cost records and outcomes that disagree with the calendar or journal.

Winter’s cream accounts page shows all thirteen categories, a ten-year table and a large net figure. Its opaque background hides HUD chrome, including fullscreen controls; phone layouts scroll the body while keeping navigation reachable. Year-10 accounts open at Winter start; the final summary and New Run open after that Winter has been played. Regular HUD refreshes still reconcile the calendar after missed callbacks, including the final transition at 30× debug speed. Before year 10, Debug recovery posts an adjustment and returns to Winter without erasing history or charging bills again; finished year-10 runs require a new farm.

Run `tools/run_tests.sh -j 1 test_ledger test_season_clock test_game` for journal/purse equality, actual transaction categories, annual billing, exact foreclosure boundaries, boundary-save ordering, reload idempotence, ten-year completion and accounts navigation. Native `test_ledger.gd -- --integration-test --capture` writes accounts, foreclosure and final-summary previews to `artifacts/`; add `--touch-controls` for portrait bounds and reachable actions.


### Segment 10: crop cards

`crop_table.gd` is the single source for the five varieties, seed costs, base prices, volatility, water/heat/cold dials, grow seasons, growth seconds and sacks per bed. State, HUD, world growth and fixtures read that table. Radioactive is removed, including its icon and field decoration. Base growth is 75–225 seconds, within the stated one- or two-season budget. Combined resilience is `(4 − water_need) + heat_tolerance + cold_tolerance`: 9/8/7/6/5 as prices rise from Russet to Icecap. High water need means lower resilience; high heat/cold tolerance means higher resilience.

Ordinary unwatered stress accrues at `0.0025 × water_need` per second. Watering or sprinklers relieve that dry stress. Drought multiplies its existing rate by `(0.5 + 0.5 × water_need)` and the heat factor; freeze uses the cold factor. Each tolerance factor is `1.75 − 0.25 × tolerance`. Flood/storm stress rates remain; protection now reduces the resulting sack loss through the shared Segment 12 formula. Price drift amplitudes are 5%/10%/15% for low/mid/high volatility. The same data holds 1.2/1.4/1.6 `storage_peak_factor` values used by the Winter storage curve in Segment 11.

Icecap can be planted in prepared Autumn beds. Autumn clearing preserves its live crop, water and growth, and the Winter notice explains the exception. `crop_frozen()` distinguishes disaster ice from seasonal ice, letting Icecap grow, receive water and be harvested in Winter or early Spring without hoeing. An empty iced bed still needs clearing before new planting. Winter save validation permits Icecap; mechanics revision 31 rejects older crop tables through the existing save protection.

Buy Seeds shows five cards in a desktop row and a scrolling column at phone width. Each has three short bar dials, seed cost, live sack price/percentage, twelve-quote sparkline, growth/yield and last year’s average. Clicking a card selects the seed tool without a purchase. The previous annual mean is base under the current deterministic 600-second sine curve; year one shows a dash. This is a price average, not a realized sale receipt, and remains valid for ordinary sale quotes; the separate Winter storage quote is not part of this average. The existing seed hotbar remains.

Run `tools/run_tests.sh -j 1 test_crop_table test_simulation test_season_clock test_seed_market test_game` for table bounds, resilience ordering, growth budgets, stress, volatility, planting gates, Winter saves/harvests and card layout. Native `test_crop_table.gd -- --integration-test --capture` writes desktop/phone card captures to `artifacts/`; add `--touch-controls` to check the real touch layout.


### Segment 11: storage and buyer orders

`market_decisions.gd`, owned by GameState as `trading`, tracks Winter stores (`held`, a subset of `storage`, empty outside Winter), yearly Winter reports, one active contract and settled orders. Harvest capacity is still the purchased barn capacity; Winter stores never duplicate sacks or create extra capacity. Ordinary sales exclude held quality cohorts; stored sales remove matching cohorts from both inventories. All sacks left after buyer collection at Winter start automatically become stores. Empty barns pay nothing; other barns pay 200 and lose `round(total sacks × 0.05)` across the whole barn, deducted from the largest pile first with catalogue order breaking ties. A lone sack does not spoil. Surviving cohorts lose ten quality and are regraded; kept seed is outside both inventories. Fee and spoilage finish before fixed costs, foreclosure, the boundary save and accounts opening. Reports prevent repeated charges after reload.

Cash charges go through the ledger’s storage category. Spoilage uses `ledger.post(..., 0, true)` to retain a non-cash journal note, with the lost sack count in its label; purse and net are unchanged by that note. Validation checks report/fee/spoilage agreement. Ordinary and stored sales use sales; buyer deliveries and penalties use contracts. The purse remains derived from the journal.

Stored quotes interpolate linearly from base at Winter second 0 toward base × `storage_peak_factor` (1.2/1.4/1.6) at second 150, multiplied by the cohort’s current grade. `sell_stored()` is gated to Winter and exposed through the barn’s stores panel. Generic sales and F cannot sell that pool in Winter. Icecap harvested during Winter remains ordinary stock. Spring releases unsold stores to ordinary inventory and removes the premium. The user’s Winter-selling amendment takes precedence over the old Spring-sale test/marker wording: the new test compares a late-Winter sale, net of fee and spoilage, with the calm harvest sale and separately verifies Spring reset.

The Sell Potatoes card retains its live signed percentage and history; `price_sparkline.gd` draws a labelled, dashed expected late-Winter level within its scale. One line explains automatic Winter storage, its fee, whole-barn spoilage and the dashed late-Winter price. The manual Store action and pre-Winter held marker are removed. The barn lists stored quantities and changing Winter quotes. Annual accounts include storage fee and spoiled sacks. The restored Golden Shores board geometry sits beside the Valley’s northern shops, clear of the duck station and weather controls; it opens Contracts through the same station interaction path. No gacha props were restored.

One Spring offer per year requests 20 sacks, rotates varieties by year, and fixes base × 1.1. The card and accept message state collection at the end of Autumn. Settlement runs at the Autumn-to-Winter boundary before spoilage or storage fees, so Autumn harvests can fill the order. It takes Standard sacks then Table sacks once, refuses Feed, pays for deliveries, and charges 5 per missing sack. Contract postings belong to Winter; active orders remain valid throughout Autumn. Active and settled orders round-trip; malformed prices, quantities, future records and inconsistent postings are rejected. Mechanics revision 33 sets older saves aside through the existing protection.

Run `tools/run_tests.sh -j 1 test_market_decisions test_ledger test_season_clock test_seed_market test_game`. New checks cover net storage benefit, monotonic quotes, Spring reset, new Winter harvests, spoilage notes, fee idempotence, overdraft boundaries including storage, shared capacity, contract collection/penalties, save corruption and UI actions. Native `test_market_decisions.gd -- --integration-test --capture --touch-controls` writes desktop/phone market, board, stores and accounts captures to `artifacts/`.


### Segment 12: Winter protection, insurance and cause cards

`farm_protection.gd` owns construction, per-bed covers, loss arithmetic, annual insurance, upkeep and forecast ranges. Its state lives under `climate.protection`: pending work, covers, loss records, policy years, settled Winters and station level. Mechanics revision 37 rejects earlier saves through the existing rejected-save protection. Validation checks types, calendar bounds, cover ownership, loss and counterfactual arithmetic, policy payments, and payout/upkeep agreement with the ledger.

Four completed protections have two levels: rainwater 1,500 / 3,000, drainage 2,000 / 4,000, windbreak 2,500 / 5,000, frost cover 1,500 / 3,000. `ClimateSystem.fund()` reserves them only in Winter, without granting a level. Three site actions complete a reservation; each controller action walks through the existing route system and spends 0.6 seconds on a hoe animation. Leaving the site or crossing Spring cannot complete Winter work. Progress persists until a later Winter. The existing can, starter tank and manually operated sprinklers remain; irrigation still costs 500 / 1,000 and installs immediately. Each completed protection posts 100 upkeep at Winter start, once per project rather than per level.

Frost-cover materials are a completed project. The weather page’s “Cover all cleared beds” action places covers on every eligible bed; the nearby-bed context action places one. Both use the same eligibility rule: Winter, completed frost project, unlocked bed, no remaining ice and no matching cover already placed. Accounts, tutorials and ended runs block placement. The E badge and touch action identify “Cover bed”; ordinary Hoe actions only clear Winter ice. Batch placement emits one refresh and persists through the existing checkpoint path. A cover stores its level and the following Spring’s year, survives saves/crop clearing, and expires at Summer. The renderer keeps per-bed cover meshes separate from crops and ice so harvesting or planting cannot erase them. Other seasons’ freeze losses can be prevented by manual ice clearing, but receive no passive cover benefit.

The existing quarter-second stress simulation and rescue controls remain. Reaching the danger threshold calls `loss(exposed_sacks, reduction) = round(exposed_sacks × (1 − reduction))`, clamped to the exposed stock. Reductions are 0 / 0.5 / 0.75. Matching event, season, variety, protection level and insured status accumulate in saved `operations.loss_groups`; each bed loses the difference between the new and previous rounded totals. This gives twelve three-sack beds exactly 36 / 18 / 9 lost sacks, including across reloads. Each bed is assessed at most once per disaster; the saved `operations.damaged` map prevents repeated strikes from charging its protected loss again. Surviving crop sacks persist as `weather_lost` on the plot and are deducted from later harvesting and pest losses. Whole-bed destruction metrics remain available in the older climate receipt. Protection no longer also reduces stress/growth, avoiding two passive reductions on the same loss.

Every actual field loss and storage-spoilage loss records a cause card with its exposed sacks, actual reduction, alternative reduction and saved sacks. Disaster groups update their existing card as affected beds accumulate. Both actual and alternative use `loss()` on the same total; alternative project protection is the next level, capped at two. Manual prevention uses the same formula with reduction 1. Climate damage, unwatered beds, pests, Autumn clearing and whole-barn storage spoilage all feed this record. A saved revision counter refreshes open season notices on additions and updates; Winter accounts include the full year. The displayed weather-loss remainder also respects previous pest damage and partial harvests.

Spring insurance posts a 400 premium once per year and marks later field losses and Winter weather losses in stored sacks as insured. Winter-start settlement pays 40% of accrued base-price losses; subsequent Winter claims post incremental payouts immediately and update that year’s settlement. Pre-policy losses and storage spoilage are excluded. Validation sums initial and incremental claim postings and independently compares the total with insured cause cards. Policy membership compares integer years so JSON numeric types cannot allow duplicate premiums after reload. Insurance settlement and protection upkeep run after Autumn clearing and storage, before fixed costs, foreclosure and the boundary save. Recorded Winter reports prevent duplicate charges or payouts.

Forecasts read the next season’s year-based chance from `climate_system.gd`, divided equally between its two possible events. Ranges use ±20 / ±10 / ±5 percentage points at station levels 0 / 1 / 2 and clip to 0–100%. Reaching the annual three-event cap makes the remaining same-year forecast zero. Sensor upgrades cost 500 / 1,000 and post under Protection.

Run `tools/run_tests.sh -j 1 test_protection test_climate test_climate_game test_climate_projects test_climate_operations test_water_loop_state test_weather_dashboard test_ledger test_game`. `test_protection` covers the loss formula and counterfactual, protected harvests, repeated strikes, Winter-only reservations, walked labour, carryover, per-bed cover expiry, insurance/policy reloads, annual upkeep, forecast bounds, corruption rejection and phone-width pages. Native `test_protection.gd -- --integration-test --capture --touch-controls` writes construction, cover, forecast, notices and accounts previews under `artifacts/`.

### Segment 12 follow-up: safe barn stock and explicit frost covers

Growing-season drought, flood, storm and freeze no longer remove barn stock. Their barn rates, loss helper, weather-history/collapse barn counters and foreclosure barn metric are removed. No growing-season barn weather cause cards or insurance claims are generated. Winter-start storage spoilage is now 5%, alongside the quality-ageing rules below. Segment 13 adds separate, insurable Winter events.


### Segment 13: the visible climate trend

`climate_system.gd` owns chance `min(0.6, 0.15 + 0.04 × (year − 1))`, severity mean `0.5 + 0.03 × (year − 1)` and the seasonal event pairs: flood/freeze, drought/storm, storm/flood, deep_freeze/blizzard. Severity samples uniformly within ±0.15 of the mean, clamped to 0–1. Automatic weather allows one saved draw per season and at most three events per year. The 45/30/75-second phases still fill the 150-second season. Explicit debug warnings retain their test/scenario override.

Saved `climate.outlook` stores the last drawn season ordinal, next potential event, precursor signal, actual warning records and last seen front-page year. The potential event is selected one season ahead, with a 70% signal chance for drought/flood/storm. The actual disaster probability is drawn only at the next boundary. Thus hints can precede calm seasons and are not promises. A drought signal halves tank refill, a flood signal draws frequent rain and a storm signal adds wind ribbons. The station reads the same chance constants and respects the annual cap.

Winter impact removes `round(stored sacks × event rate × severity)` per variety and the same fraction of remaining living Icecap per bed. Rates are 0.20 for deep freeze and 0.30 for blizzard. Fresh Winter harvests in the barn and empty beds are unaffected. Damage updates stored quantities, harvest remainders, cause cards and insured payouts together; saved active weather cannot repeat its impact. Winter cause cards use the same counterfactual loss function, naming sale or harvest before impact as prevention. Frost covers remain protection against Spring freeze only.

`climate_intro.gd` reuses `chapter_subtitles.gd` timing and keyboard skip for a cream year-start front page. It sits above touch controls, pauses the simulation, and shows a worsening headline plus `climate_strip.gd`'s ten-year procedural disaster icons. Winter accounts reuse the strip. The seen-year marker prevents replay after a completed presentation; the transient presentation pause is cleared on reset/load.

`farm_world.gd` owns calendar palettes and a one-second real-time blend of grass, sky and sunlight. Orchard canopy shades, blossoms, verge flowers and path leaves share mutable seasonal materials; static mesh compilation excludes those materials to preserve later recolouring. Winter ground snow blends through its existing terrain shader. Summer dryness and faint field haze increase with year even when weather is calm; Autumn extends twilight. Precursors overlay these seasonal looks. Existing tank level, can, sprinklers, villagers and farm geometry remain.

Run `tools/run_tests.sh -j 1 test_climate_curve test_protection test_season_clock test_day_night test_static_mesh_compiler test_world_rendering_optimization test_game`. Seeded curve tests cover chance, severity, event pools, frequency caps, precursor rate, forecast bounds, saved outlook, Winter claims and palette/crossfade values. Native `test_climate_curve.gd -- --integration-test --capture --touch-controls` captures all four seasons in years one and six and the desktop/phone front page under `artifacts/`. No Segment 14 tuning is included.


### Harvest grades before economy tuning

`crop_quality.gd` owns the 100-point bed score, Table/Standard/Feed thresholds (80/40), multipliers (1.5/1/0.5), deduction causes, ten-second fractional clocks and once-per-disaster freeze/lightning markers. Fragility is `9 / CropTable.total_tolerance(crop)`, so the existing resilience sequence 9/8/7/6/5 produces increasing quality risk. Each scaled deduction is rounded to integer exposure, then passed through `FarmProtection.loss()` with the matching project or Spring bed-cover reduction. Manual dry/late/pest deductions have no passive project reduction. Loss totals must sum to `100 − quality` in save validation.

Actual pest bites deduct 6, active drought/flood stress 4 per ten seconds, disaster freeze 15 once plus 4 per ten seconds on ice, lightning-row hits 25 once, unwatered growth 2 per ten seconds and ripe neglect 5 per ten seconds after thirty seconds. The quality ripe-age clock is independent of pest timing, so spraying and ducks cannot renew the harvest grace period. Harvesting stores the current score; partial harvests preserve the remaining crop’s timers and deductions. Crop clearing/replanting resets them. Tutorials retain their damage protection.

`graded_stock.gd` replaces scalar crop inventory with `variety → grade → score → sack count`. Bounded score cohorts preserve exact ageing without one object per sack or a second aggregate balance. `stock_count()` supplies existing hotbar, tutorial, capacity and inventory totals. Ordinary sales exclude matching held cohorts, including when fresh and stored sacks have identical scores. Winter weather removes held cohorts from both stores and barn stock. Save validation rejects malformed grades/scores/counts and held quantities exceeding their matching barn cohort. Revision 37 rejects older saves through existing save protection.

Base prices are Russet 15, Giant 20, Golden 28, Sunburst 38 and Icecap 50; seeds remain 75% of base. Ordinary seasonal quotes and Winter storage quotes receive the grade multiplier. Winter storage now spoils 5% of the total, rounded nearest and deducted from the largest variety pile first, then subtracts ten quality from surviving cohorts and rebuilds their grade buckets. Within a variety, lower-quality sacks leave first. Buyer contracts take Standard before Table at their fixed contract price and refuse Feed.

The barn’s per-grade seed action transfers Standard/Table sacks into `trading.kept_seed`, outside sales, capacity, spoilage, quality ageing and Winter barn damage. Winter-held sacks are removed from both inventories. Spring transfers each to one matching seed and clears the pending stock before saving. Seed purchases reserve capacity for pending seed. Existing return-to-Spring handling releases ordinary stores separately. The future Segment 15 farm shop must consume Table only at `base × 1.8`; that shop is not implemented in this segment.

Sales post `Sold <sacks> <grade> <variety> sacks` under the existing Sales ledger category. Annual accounts derive grade sack counts and receipts directly from those entries; no duplicate sales journal is saved. Contracts remain in their own category. Sell Potatoes lists/selects each grade and scales its price, sparkline and Winter marker. Barn stores provide separate graded Winter-sale and seed actions. The hover/near-player hint is assembled once per refresh, with growth time and explicit “Grade:” wording; its layout is recalculated only when content, viewport or controls change. A smaller world tag also says “Grade:”. This avoids the growth-only/grade hint flicker and repeated container resizing. Downgraded hints name the largest deduction; harvest feedback includes a grade label.

Run `tools/run_tests.sh -j 1 test_grades`. It covers thresholds, actual timed growth/pest/weather deductions, protection, deadline preservation after spraying, saved fractional clocks and markers, healthy and downgraded harvests, prices, cohort corruption, exact Winter downgrades, kept seed conversion/planting, Feed-refusing contracts, mixed fresh/stored sales and ledger reconciliation. Native `test_grades.gd -- --integration-test --capture --touch-controls` captures the desktop/phone grade market. Existing fixtures now use explicit Standard-quality cohorts where they test ordinary stock, and prices/spoilage assertions reflect the new economy. No tests are skipped or disabled; no tuning bot or farm-shop feature is introduced.
