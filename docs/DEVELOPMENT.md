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

### Climate economy and taxes (v1.0.2)

`scripts/blind_rules.gd` owns progression baselines, the 8% major-stock reference, 5% base tax, 5% bankruptcy allowance, three major stocks per collection, Tax Boom probability and the +150% shared pressure ceiling. Tax targets never follow the player's wealth or build. There are no separate Small/Big Blind objectives or target-miss deaths; the retained `blind_cycle` names only maintain save compatibility.

| Island | Progression baseline | Stock reference (8%) | Base tax (5%) | Severe tax ceiling (12.5%) | Bankruptcy below |
| --- | --- | --- | --- | --- | --- |
| Spud Valley | $1M: Golden Shores unlock | $80K | $50K | $125K | −$50K |
| Golden Shores | $100B: Frosthollow unlock | $8B | $5B | $12.5B | −$5B |
| Frosthollow | $5Qa: virtual late-game baseline | $400T | $250T | $625T | −$250T |

There is no Island 4. The stock reference is a haul-value balancing reference, not an automatic payout or income cap: the stock tooltip and Climate action show how many potatoes at the current quote reach it. Actual earnings still depend on crops, quantity, mutations, processing and selling. Existing decreasing-rarity stock distributions stay intact, including the +35,000%–100,000% Rocket range. Active and recovering disasters apply a final sale-price clamp of 5%–100% of base value on the affected island. Severity and recovery time determine the crash, down to −95%. Scheduled and natural booms are suppressed; existing booms are cancelled and the Rocket clock pauses. Crashes do not count toward tax collection. Warning/stock timer ties resolve weather first; already-due tax collection remains scheduled.

At the first actual major boom, a 20% chance rolls a Tax Boom with a uniform integer increase from 0% through 150%. Disaster recovery adds pressure; combined pressure cannot raise the bill above 2.5× base tax. The third actual scheduled or Rocket price boom starts a full ten-second selling window before collection. Natural spikes, ordinary offers and the Rocket cinematic do not count. With scheduled stocks every three minutes, collection is about every nine minutes. Tutorials pause taxes, weather and stock pressure.

Collection deducts the displayed bill even if cash cannot cover it. Debt is playable; only crossing **strictly below** the bankruptcy line immediately ends the run. Equality survives. There is no wealth-based surplus levy. The pre-collection cash-to-tax ratio produces 2× OVERKILL, 5× ULTRA KILL, 10× GODLIKE, 25× OMNIPOTENT, 100× RULER, 1,000× COSMIC RULER and 1,000,000× REALITY BREAKER. Uncovered bills and balances show red. Signed finite double balances use suffixes through Dc, then scientific notation, up to ±1e300.

A first visit to a harder island starts three fresh stocks at its tax tier. Returning to an earlier island keeps the highest visited tier and existing collection counter, preventing lower-tax travel loops. Last receipts retain actual tax, pre-tax cash, coverage, rank and post-tax debt.

`scripts/climate_system.gd` owns climate timing, losses, market factors and local protection costs. Island 1 is free from weather disasters. First arrival at Island 2 (or an older save already on Island 3) shows a one-time introduction that pauses the simulation until acknowledged. The first warning follows 90 seconds of eligible play. Calm weather clocks pause on Island 1; an already warned disaster continues against its original island and shared barn. Drought, flood and severe storm give 45 seconds to prepare, hit once, last 30 seconds and recover over 75 seconds; another calm interval lasts 210–330 seconds. Warnings preview the estimated bill after impact. Disasters destroy a severity-dependent portion of planted beds and stored potatoes, including mutations, processed stock and processing queues. Floods also require damaged beds to be tilled again. Seed prices rise independently of weaker sale prices, ordinary market volatility increases, and growth slows. Temporary effects taper to normal during recovery; infrastructure pressure remains until the next tax collection.

Climate action funds two levels each of Rainwater Reserve, Drainage Network, Reinforced Barn and Living Windbreaks, priced relative to the local progression baseline. These reduce the relevant physical losses and recovery tax contributions. Funding during recovery can still lower a pending bill; it cannot restore destroyed crops. Damage remains attached to the warned island, while the shared barn is exposed wherever the player travels. One batched canvas layer draws drifting cloud banks, up to 100 rain streaks, wind ribbons, floodwater and drought dust. Existing 3D clouds accelerate and expand; the sky and sunlight respond. Original looped wind/rain audio and thunder accompany storms. Camera shake is bounded to 0.26 world units. No per-crop particle nodes are created.

Bankruptcy freezes the run and replaces the normal HUD with an editorial page: desaturated farm, heavy display typography, restrained cream, earth tones and muted debt red. It records the actual cause, climate phase, final balance, recent field/barn losses, tax, market conditions and build. **View Run Summary** reveals run totals and funded projects; **Try Again** resets the farm and returns to the normal tutorial. The concise educational text paraphrases [FAO's disaster and agriculture report](https://www.fao.org/publications/fao-flagship-publications/the-impact-of-disasters-on-agriculture-and-food-security/); game event rates and tax multipliers are fictional balancing choices, not claims about real-world climate or tax policy.

Mechanics revision 14 retains the introduction flags alongside weather timers, affected island, severity, initiatives, losses, recent history, recovery tax pressure, the tax cycle and collapse report. Pre-revision-11 farms receive fresh climate timing and a full three-stock preparation cycle for the new bills, while existing coins, inventory and progression are retained. An already lost run remains lost. Old Rockets retain their remaining time; pre-revision-9 factors below the new minimum migrate to 351×. Corrupt saves leave the live farm unchanged.

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

Patrick Hand, Fredoka, Oswald, Nunito Sans and Noto Sans Symbols are distributed under the SIL Open Font License; see the license files in `assets/fonts/`. Godot's engine license and third-party notices are in `assets/licenses/` and are included in browser packages. These notices describe their respective dependencies.

### v1.0.2 presentation preview

This presentation revision ships in v1.0.2. Normal UI headings use Fredoka; disaster announcements and the collapse page use Oswald, with Nunito Sans for body copy. Both new fonts come from the Google Fonts repository under the bundled SIL Open Font Licenses. The four climate initiatives use original code-drawn icons in a two-column grid. Tax rate tables, wealth-rank definitions and detailed run statistics are tucked behind explicit detail buttons. Main-menu tiles and descriptions are shorter. The collapse page preserves its serious educational message alongside the final balance and three loss figures.

`climate_alert.gd` shows a blocking first-arrival introduction and five-second nonblocking event announcements. Intro flags and pending acknowledgments survive saves; revision-11 saves get safe defaults, and old Island-1 weather is cleared. `climate_audio.gd` uses original, locally synthesized wind and thunder WAV assets. Public Pages files in `docs/index.*` have not been replaced.


### First-harvest lesson and contextual help

`first_island_tutorial.gd` now has eight stages (welcome, seed purchase, hoe, plant, water, growth, harvest, sale). The first sale ends mandatory guidance. Tools are auto-equipped with one bed cue; another empty hoe target retargets the lesson. Blocked input explains the current action. Normal no-op field actions also show their result. `TOUR` is a separate optional NPC tour: Next never requires a shop visit, transactions are blocked, and all farm timers are preserved while paused.

`farm_help.gd` stores optional tip dismissals, a tracked independent plant/water/harvest/sale cycle, first-infestation protection, and the practice quote. New lessons enable help on completion or skip; established saves get no surprise tips. Tutorial version 1 stages through first sale map to version 2; later compulsory stops retire. Mechanics revision 13 saves help state, including the remaining practice seconds and protected field indices. Malformed help data is rejected before loading.

The first natural infestation is harmless until cleared or harvested, even when its tip is dismissed or the farm reloads. Additional infestations wait until that group is resolved, then normal damage resumes. After an independent crop sale, a held crop can receive an opt-in, ten-second +100% practice quote. It neither resets nor counts the major-boom schedule, never overrides a real boom, and cannot be replayed after a successful sale. Normal market clocks continue; seeds follow the practice quote. A missed window can be tried again. Travel ends practice; the optional tour pauses and preserves it.

Context cards have no input locks, hide while shops or the seed tray are open, and sit below the stock and tax cards. Tool/duck prompts require affordability; build prompts require an owned crate or usable Farmer ability. Tax help appears within thirty seconds of the first scheduled boom or after a major boom; first debt gets separate recovery guidance. Dismissing a shop suggestion records dismissal only, not learning. The independently completed crop is the behavioral success check.

Validation: `test_tutorial_game.gd` walks the real first lesson and an unmarked second crop, then checks pests, practice sales, optional tour and migration. `test_farm_help.gd` covers persistence, timing, normal later pest damage, affordability, real-boom priority and corrupt saves. `test_tutorial_hud.gd` checks small/portrait layout and preserves stock, tax and farming controls. Run scene checks with `-- --integration-test`; add `--capture` without `--headless` for `artifacts/guide-*.png`. The local Web ZIP is rebuilt; published `docs/index.*` files remain unchanged.


### Growth, luck display and PotatoDex QoL

Base crop times are 10/25/40/50/55/60 seconds for Russet/Golden/Giant/Radioactive/Sunburst/Icecap. Each crop's active growth speed is bounded by `base_time / 60`, including weather penalties, while positive growth bonuses can still shorten the duration. Field updates and hover timers use that same bound. Dry/frozen crops and paused simulations do not consume growth time. Revision 14 validates older plots against `OLD_GROW_TIMES` before converting elapsed time by completion percentage; mature potatoes remain mature.

`luck_breakdown()` reports earned and equipped additions, normal capped luck, percentage above 1×, the debug multiplier and effective total. The HUD shows both multiplier and percentage. Debug previews the result before applying changes; optional calculation sections in Debug and the Roll House show the arithmetic, with wager/build roll-quality factors separate. Roll presentation freezes its displayed breakdown with the other wager information. The rarity-selection math is unchanged.

Authenticated `debug:island:2` / `debug:island:3` actions unlock island flags and fields without spending money, fabricating mastery or traveling. Winter also unlocks Shores. Tax promotion and the climate introduction still happen on arrival. `debug_islands_modified` persists and marks subsequent trophies DEBUG; a new farm clears it. Normal paid island unlocks remain unchanged.

PotatoDex defaults to a two-column mutation gallery and offers a separate six-variety crop gallery. Both reuse crisp `item_icon.gd` artwork. Pictures are explicitly previews until discovered; cards refresh discovery/mastery data without claiming new discoveries. `test_qol_update.gd -- --integration-test` checks migration, growth caps, luck arithmetic, authenticated unlocks, persistence and gallery layout; a native `--capture` run writes `artifacts/qol-*.png`.

### Quiet farming feedback and shop signs

Shop signs use semibold Fredoka, matching the original rounded roll-button typography, with short names and a fine contrasting outline. Valley/Shores use cream lettering; winter uses dark lettering against snow. Labels remain clickable and retain tutorial visibility. Fredoka also supplies compact shop and menu headings and buttons; Nunito Sans remains on body copy and numeric status text.

Normal field actions never create central toasts. No-op feedback (for example, “Already watered” or “Plant a seed first [2]”) shares one click-through footer slot with hover hints, expires after 1.4 seconds, and does not extend on rapid identical repeats. Successful work clears stale failure text. Plot notifications are handled through this path once; a full barn still gets a short actionable reminder. Other notifications appear in a smaller upper-right card.

Optional help is one compact row below the tax card and hides for three seconds after field input. Its button explicitly opens the full explanation and action; the × dismisses without opening anything. The opened tip retains its own action if another tip becomes relevant while reading. The normal tax card shows the bill and stock countdown; coverage, projected balance and rules remain available on hover/click. Tiny positive coverage reads `<0.01%` rather than scientific notation. Save schema and gameplay are unchanged.

`test_farm_clarity.gd -- --integration-test` checks rapid repeated actions, feedback expiry, duplicate suppression, full-barn feedback, help action stability, responsive layout, percentage formatting and all-island typography. A native `--capture` run writes `artifacts/clarity-watering.png`, `clarity-island-1.png` through `clarity-island-3.png`, and `clarity-winter-warning.png`.


### Roll House layout and visible climate projects

The Roll House uses a wider two-column layout: reel and stakes on the left, all eight live rarity percentages on the right (including Mystery). The fixed luck strip has three 0.65-second stages: roll quality, additive normal luck percentage, then the debug multiplier. The full weighting calculation remains expandable. Purchased luck and odds stay frozen throughout the animation; the backend result remains authoritative. Shop headers, buttons and signs use the bundled Fredoka font at restrained sizes.

`climate_projects.gd` builds an island-local tank, perimeter drainage, braces on the existing barn, and a rear tree windbreak from the saved project levels. Second levels add visible infrastructure. `FarmWorld.set_climate_projects()` creates/batches geometry only when local levels change, and clears it on reset or island rebuild. The controller applies purchases immediately. Structures occupy gaps and field edges, keeping existing map dimensions and all crop targets accessible.

Validation: `test_roll_luck_meter.gd` covers the three stages, frozen state, cancellation, exact visible odds, maximum luck, long rewards and four viewport sizes. `test_climate_projects.gd` checks every purchase level on both climate islands, travel, reset, geometry reuse and all 128 plot targets. Both support `-- --integration-test --capture` for native screenshots under `artifacts/`.


High-luck weighting now multiplies each non-common weight by `max(1, effective_luck / 10) ^ (0.35 * steps_above_rare)`. Ordinary 1–10× luck keeps its prior probabilities; larger debug boosts increasingly favor top collectibles instead of retaining roughly 26% Rare at 1,000×. The calculation panel explains this factor, and the three-step strip distinguishes earned/gear additions from the active boost. `test_roll_balance.gd` reproduces the reported all-in configuration, checks cumulative rarity improvement, and samples 20,000 actual paid rolls each at 1×, 1,000× and 3,000× against the displayed probabilities using binomial sampling tolerance.


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


### Build and playability audit (v1.0.2)

Profession pages now expose one concrete action, required ingredients, readiness and result. Illustrations retain their proportions. Farmer targeting highlights only eligible planted growing crops, persists until used/cancelled, and works through click-to-walk or E. Invalid clicks do not spend compost; tools, travel, equipment and other menus cancel the mode. Equipment cards avoid expanded tax forecasts; optional tips yield to equipment/targeting, and notifications dock clear of modal controls.

Build schema v3 migrates v1/v2 saves, tracking freshness by crop and harvest deadline. Selling, breeding, contracts, staking, furnace use and disaster loss remove the consumed inventory's freshness. A new harvest cannot rejuvenate old stock. Queue jobs survive partial disaster loss and reload. Wagers permit one reroll per stake, including after charm recharge and save/reload. See [BUILD_PROFESSIONS.md](BUILD_PROFESSIONS.md) for bounded bookkeeping and transaction checks.

Debug has explicit exact funding for zero/negative balances and code-gated recovery after bankruptcy. Recovery keeps farm/build progress, resets collection timing and restores 1× time. Opening Debug pauses simulation. Travel warnings expose higher tax tiers; bankruptcy shows the actual receipt and debt threshold. Old receipts remain available without being misreported as new Debug-caused tax collections.

QA covers every profession's success and blocked paths, switching, save migration, climate inventory loss, tutorial/practice, watering/upgrades, real input, Debug recovery and responsive overlays. New suites: `test_build_transactions.gd`, `test_profession_clarity_ui.gd`, `test_playability_audit.gd`, `test_debug_recovery.gd`. Scene tests require `-- --integration-test`; add `--capture` in a native run for screenshots. The Builds Lab now includes repeatable tax-debt and Debug scenarios, always in its disposable test-mode copy. Public Pages exports remain untouched.

Final automated passes also cover the ordinary simulation, ferry access/zoom, all existing equipment and market disaster rules. Two stale test assumptions were corrected: the seed-price test now funds its purchase, and sign checks follow the established Fredoka typography. The water-loop fixture waits for the audio mixer to release already-stopped streams before exit; its verbose pass has no leaked resources.

Safari verification exercised the complete Farmer compost/water/harvest flow, SSS batch loading and bankruptcy→explicit Debug recovery in the disposable export. Browser QA also caught missing text-arrow glyphs (replaced with plain wording) and an old world celebration replayed after travel (new islands now adopt the event counter quietly). Industrialist reserves its job-footer height before loading, keeping its button and bonuses drawer stable.

Performance observation on the Apple M4 with the user's separate native editor preview still rendering: Arctic with 80 ripe beds, Balanced at 1920×1199, eight seconds after warmup: current build 40.8 FPS (median 24.2 ms, p95 26.5 ms); previous commit 27e015a under the same running-editor setup 39.4 FPS (median 25.0 ms, p95 28.4 ms). Current Smooth at 1600×999 measured 42.0 FPS. No 60 FPS claim is made for this concurrent-load session; the comparison does not indicate a new slowdown. Earlier 60 FPS observations above came from a different session. The local labs expose measurements for repeatable checking on the player's device.


### Touch and fullscreen verification (v1.0.2)

`TouchControls` owns finger IDs separately from keyboard actions. The stick supports simultaneous actions, an outer sprint ring and focus/resize cancellation. Farm taps commit on release; a second finger or drag cancels tapping until the gesture ends. Pinch distance changes the same bounded camera zoom used by the wheel. Tools provides a small zoom-button fallback.

Touch uses at least 600 and at most 900 logical units on the short screen edge, with at least 68-unit buttons (44 CSS pixels on a 390px phone). Flexible menu rows stack when needed; scroll containers keep all activities, profession choices and equipment reachable. The browser shell owns fullscreen requests in a trusted DOM gesture and fits its canvas inside safe-area insets. Browser fullscreen and F11 work independently of game menus. The fallback explains Home Screen installation when the browser rejects or lacks fullscreen.

Run `test_touch_controls.gd` with `-- --integration-test --touch-controls`. It checks phone portrait/landscape, iPad portrait/landscape and laptop sizes, all menus, all five profession pages, multitouch movement and pinch cancellation. `tools/export_browser_benchmark.py --fixture mobile --label mobile --godot PATH` creates a disposable browser test build with a QA bridge; the bridge and test scene are excluded from the public export. Browser input checks use actual touch events, screenshots and enter/exit fullscreen at 390×844, 844×390, 768×1024, 1024×768 and 1366×768. These are emulated viewport checks, not claims of physical iPhone/iPad performance testing.

The release check also corrected outdated fixtures: revision-3 saves must contain their historical crop growth durations, and the collapse screen now displays the concrete tax/debt calculation. The UI-polish check now follows profession detail pages instead of removed build-card references. The optional desktop tutorial's Roll House overlap was fixed by stacking the guide heading in its narrow margin.

`tests/test_mobile_browser.cjs` automates the browser matrix with Playwright. Set `TATER_QA_URL` to the disposable mobile fixture URL and provide Playwright through `NODE_PATH` or a local installation. Captures and logs go to ignored `artifacts/mobile-qa/`.
