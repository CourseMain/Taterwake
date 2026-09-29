# Taterwake redirect: the honest potato farm

Design plan for turning Taterland from a big-number market game into a hard,
legible farming survival game where climate change is the antagonist. Written
as a handoff for implementation.

## 0. Locked decisions

- **Real-time seasons, all four.** Each season is a short real-time phase
  with the avatar and tools. Winter is a working season too: the ground is
  frozen, the accounts open as it begins, and there is Winter work to do.
- **Ten-year run.** Foreclosure is game over. The run ends with the ten-year
  ledger and then the **fifty-year epilogue** (§4b).
- **One farm.** The climate shifts in place on a single farm. Other islands
  may return later as selectable regions at new-run time, not as progression.
- **Professions are cut.** The five builds, their activities, levels, XP and
  bonuses are removed. A mild run-start "farming style" with ±10–25% tilts
  may be revisited after the core is tuned. The Gambler does not return.

## 1. The pitch

**A farming game where you lose money.** You inherit a small potato farm and a
mortgage. Every year you decide what to plant, when to sell and what to protect.
Every year the weather gets a little worse. At the end of every year the
accountant shows you the ledger. Most years the number is small or negative.
Surviving ten years is the win.

The moment that makes people say "oh, that's different" is the **annual
accounts screen**: a plain ledger, line by line, ending in a net figure like
`−1,340` or `+212`. That screen is the scoreboard, the story and the thing
players screenshot. Everything else in the game exists to make that number
honest and to make the player feel they earned it or could have avoided it.

Tone: keep the potato humour, the round farmer, the NPC voices. The numbers are
the harsh part. Clarkson's Farm is funny and still says "we made £144".

## 2. What changes and what stays

### Keep (already built, reusable)
- 3D world, procedural islands, farmer avatar, five manual tools, beds, day and
  night cycle, touch and desktop controls, camera.
- Climate system skeleton: warning → active → recovery phases, drought, flood,
  storm, freeze, stress accrual per bed, protection projects with levels.
- Water loop: rain → tank → can → crop, sprinklers, drainage.
- Weather station, furnace, ducks and pests, NPC roster and conversation
  system, market price chart, tutorial framework, save and migration
  framework, headless test harness.

### Remove
- Scheduled stock booms, natural spikes, the Stock Rocket and its cutscene.
- Roll House, Spudions jackpots, all-in, luck, crates, trophies, mutation gear,
  clothing bonuses, the Gambler build, the mythic crate.
- Exponential island economies (millions → quadrillions), large-number
  suffixes (Qa, Qi, Sx…), the "tax after every third boom" collector.
- Combo multipliers up to 16×, mastery yield bonuses up to +1000%.

### Rescale
- Money becomes small and legible: hundreds and low thousands. A sack of
  potatoes sells for roughly 15–30. A year's fixed costs are a few thousand.
- Any bonus that survives (tool rank, a build perk) is worth ±10–25%, never a
  multiplier.
- Time moves from 60-second days to **seasons**. A year is four seasons; a
  season is a short real-time work phase. See §4.

## 3. The player's three decisions

The player never needs farming theory. Every choice is one of these:

1. **What to plant.** Each variety is a card with three visible dials: water
   need, heat and cold tolerance, price and price volatility. Better price
   means more fragile. Seed cost is shown. Four to six varieties total.
2. **When to sell.** Sell at harvest (glut, low price) or store (storage fee,
   spoilage, price climbs through winter). Contracts offer a fixed price now
   with a penalty per sack short. Nothing else about the market exists.
3. **What to protect.** Money is scarce, so each protection is a bet on which
   disaster comes: rainwater tank (drought), drainage (flood), windbreak
   (storm), frost cover (freeze), plus insurance (premium, partial payout).
   The forecast gives probabilities with error bars. Better weather station
   means narrower error.

A fourth, mid-game decision gives the game its strategic spine:

4. **Diversify or double down.** From year three, income beyond crops unlocks:
   a farm shop (steady, weather-proof, eats labour), contract growing (steady,
   penalties), lodging for tourists (needs the farm to look good). Spending on
   these means not spending on protection. This is the real-world story and
   most farming games skip it.

Every loss shows a cause card so difficulty is legible:
`Drought, Season 3. Lost 38% of Russet. The tank was empty. A full tank would
have saved about 60%.` Hard is fine. Unexplained is not.

## 4. Structure of a run

- **Year** = Spring (plant), Summer (tend, first disasters), Autumn (harvest,
  sell or store), Winter (accounts, clear ice, build protection, sell stored
  sacks, repairs).
- Each season is a real-time phase of about **2 to 3 minutes**. The season
  length is the labour budget: you cannot water, hoe and harvest every bed
  if the farm is big. Hiring a hand costs money and buys time. Sprint stays.
- **Winter** is a working season with frozen ground. The annual accounts
  open as Winter begins and pause the clock until closed; then the player is
  back on the farm in the snow. The year rolls over automatically when
  Winter ends.
- A run is **ten years**, roughly 90 minutes of play across sessions, saved
  every season. Foreclosure is game over.
- Foreclosure happens when the overdraft passes the bank's limit. The bank is
  the second antagonist and is polite about it.
- End of run: a ten-year ledger, the climate record, a title for how you
  farmed (Adapter, Shopkeeper, Stubborn, Sold Up), then the epilogue.

Islands: one farm whose climate shifts in place over the ten years, because
"the villain is coming to your farm" is the story. Later, the other two islands
can become selectable **regions** at new-run time (Shores = heat and flood,
Frosthollow = cold and storm) with their own climate curve.

## 4b. The fifty-year epilogue

After the ten-year ledger, the game fast-forwards forty more years with no
player input and shows what the farm became. This is the villain's ending and
the reason the run mattered.

How it is decided. The epilogue runs the same simulation the player just
played, on the player's final state, with the climate curve continuing to
climb, and with a simple caretaker policy: keep doing what the player was doing
(same crops, same protections, same diversification, repairs when affordable).
The player never sees a dice roll; the outcome is earned by the final state.
Four axes decide the picture:

- **Solvency**: cash and debt at year 10, and the caretaker's net trend.
- **Adaptation**: which protections exist and at what level versus the
  disasters the curve will bring.
- **Diversification**: how much income does not depend on the weather.
- **Land health**: soil stress carried over from repeated disasters, tank and
  drainage condition, tree cover.

Possible futures, rendered on the same 3D map with new visual states:

- **Dust**: cracked pale soil, dead furrows, empty tank, collapsed roof, the
  sea pulled back. Drought-heavy curve, no water protection.
- **Drowned**: beds under standing water, silted paths, the ferry jetty gone.
  Flood-heavy curve, no drainage.
- **Deserted**: sound farm, nobody home, sign reads "For sale". Solvent but
  no diversification and the caretaker went under around year 25.
- **Sold to the estate**: beds replaced by one giant monoculture field, the
  village buildings turned into storage, potatoes gone. Foreclosed early with
  land still healthy.
- **Holding on**: smaller farm, windbreaks grown tall, tanks and drains
  everywhere, a few beds, a modest ledger. Adapted, not rich.
- **The shop village**: farm shop, lodgings, a market square, fields half
  wild. Diversified, weather nearly irrelevant to income.
- **Thriving**: rare. Every axis strong. Full fields under cover, the NPCs
  older, a plaque with the player's name.

Presentation: the ten-year climate strip extends to fifty with the front-page
headlines of the intervening decades, then the camera fades up on the future
farm and slowly pans. A final ledger line: `Farm value, 50 years on`. Reuse the
existing flood, ice, snowbank and sand visuals; add dust, standing water,
overgrowth, abandoned and estate variants for buildings and beds. One
screenshot button on this screen.

## 5. Climate as the villain

Climate is a **trend, not a dice roll**. The player can see it coming and can
only adapt, never stop it.

- Disaster chance per working season starts around 15% in year 1 and rises
  about 4 points per year; mean severity rises too. By year 10 expect about two
  disasters a year. Exact curve is a tuning constant.
- The villain has a face: the year-start forecast is a newspaper front page or
  an NPC weather report that gets grimmer every year, with a visible ten-year
  climate strip showing past years' disasters.
- Foreshadowing beats randomness: a drought year is preceded by a dry spring
  (tank fills slower), a flood year by a wet one. Reading the farm is a skill.
- Protection is a **treadmill**: to keep net income near zero by year six the
  player must have invested a few thousand, which only a good early year plus
  restraint affords. That is the honest message, delivered by the ledger rather
  than by text.

## 6. Economy model (starting numbers, to be tuned by simulation)

| Line | Per year |
| --- | ---: |
| Mortgage interest + principal | 2,000 |
| Land tax and rent | 500 |
| Living costs | 1,500 |
| Equipment upkeep | 500 |
| Seed (24 beds) | ~1,200 |
| Water, fuel | ~300 |
| **Costs, total** | **~6,000** |
| Gross sales, good year, no disaster | ~6,500 |
| Gross sales, one moderate disaster | ~4,900 |
| Gross sales, two disasters | ~3,200 |

So a clean year nets about +500, an average year about −1,100, a bad year about
−2,800. Start with 2,000 cash and a −5,000 overdraft limit. Naive play should
foreclose around year 4 to 5; careful play should survive year 10 with a total
ten-year net somewhere near zero and one or two proud years. Storage: +40%
spring price, 10% spoilage, 200 fee. Contract: fixed 22 per sack, penalty 5 per
sack short. Protections: 1,500 to 2,500 each, 100 per year upkeep, each cuts
its disaster's loss by 50 to 60%. Insurance: 400 premium, pays 40% of loss.

## 7. Codex segments

Each segment below is one Codex conversation. Paste the **standing preamble**
first, then the segment's brief. Segments are ordered by dependency; do not
start one until the previous segment's acceptance checks pass. Each segment
must leave the game runnable and the test suite green, so that a broken
session can be discarded without losing earlier work.

Strategy: strip first, then build. The old systems are threaded through four
god files (`game_state.gd` 3.7k lines, `game_hud.gd` 4k, `farm_world.gd`
2.6k, `main.gd` 1.7k), so each removal segment deletes one system end to end:
its scripts, its state fields, its save validation, its HUD panel, its main
action routing, its world visuals and its tests. Only once the game is small
does the new core go in.

### Standing preamble (paste into every Codex session)

```
Project: Taterland, Godot 4.7.2, GL Compatibility renderer, GDScript only,
exported to the browser. Everything is built in code from scenes/main.tscn
(one Node3D running scripts/main.gd). Read docs/REDESIGN_PLAN.md first: we
are turning this big-number market game into a hard, honest farming survival
game with a ten-year run, an annual ledger and climate change as the villain.

Rules for this session:
- Do only the segment I paste. Do not start the next one.
- Leave the game runnable at the end. Boot check: `godot --headless --path .
  --script res://tests/test_game.gd -- --integration-test` must pass.
- Run the suites named in the segment with tools/run_tests.sh (Segment 1
  creates it). Delete tests that cover removed systems; never skip or
  disable a test to get green.
- Never touch docs/index.* (the published web build) or the web/ folder.
- Keep commits small with plain messages. No AI attribution lines.
- Keep the visual identity: the round potato farmer, the villagers, the
  hand-built 3D islands, the cream UI. Remove systems, not charm.
- If a removal reveals code that only served the removed system (a helper,
  a shader, an audio file, a font glyph), remove that too.
- Update docs/GAMEPLAY.md and docs/DEVELOPMENT.md paragraphs that describe
  what you removed or added; delete rather than rewrite when unsure.
```

### Segment 1: Safety rails and test runner

```
Goal: make it safe to tear the game apart. Three deliverables.

1. Save protection in scripts/game_state.gd. Today load_game() rejects a
   save that fails _valid_save() and returns false; main.gd then starts a
   fresh farm and its 10-second autosave overwrites the rejected file at
   the same path. Change it so:
   - save_game() moves the existing file to <path>.bak before renaming the
     .tmp into place (remove an older .bak first). One rolling backup.
   - load_game() moves a candidate that fails size, JSON parse or
     validation to <path>.rejected (never the legacy v2 path), and the
     notice says the save was set aside. Add backup_path() and
     rejected_path() helpers.
   - New tests/test_save_safety.gd: damaged JSON is set aside; invalid but
     parseable JSON replaces the older .rejected; a fresh farm saves after a
     rejected load without touching .rejected; the second save creates
     .bak equal to the first save; .bak loads.
2. tools/run_tests.sh: runs every tests/test_*.gd except *_browser.* files
   with `godot --headless --path . --script res://tests/<name>.gd --
   --integration-test`, honours GODOT_BIN, imports the project once if
   .godot/imported is missing, runs N suites in parallel (-j, default 4),
   prints one line per suite (PASS/FAIL/TIMEOUT/ERRORS, the suite's own
   "NAME: n checks, m failures" line) and exits non-zero if any suite is
   not PASS. Match summary lines with `^[^:]+: ([0-9]+ checks?, )?[0-9]+
   failures?` because suite names contain spaces, slashes and plus signs.
   Document it in docs/DEVELOPMENT.md and replace the ad-hoc test commands.
3. Repair the stale fixtures. Commit d8d525a added a validator rule
   (game_state.gd, _valid_plots, mechanics revision 21): an unlocked bed in
   the upper half of Island 2 or 3 must be justified by
   data.field_expansions[island] or data.retained_beds. Only
   tests/test_blinds.gd, test_debug_money.gd, test_stock_ceiling.gd and
   test_tax_credit_land.gd were updated. Every other fixture that unlocks
   all beds on island 2 or 3 and then round-trips a save fails. Add
   `state.field_expansions[id] = true` beside the unlock loop in:
   test_climate.gd (two sites), test_climate_game.gd (two sites),
   test_climate_operations.gd, test_climate_visuals.gd,
   test_debug_trophies.gd, test_gear_rewards.gd, test_stock_rarity.gd,
   test_stock_rocket_state.gd, test_water_loop_state.gd (inside fresh(),
   after debug_unlock_island), test_roll_balance.gd (two sites). Leave
   test_tax_credit_land.gd's legacy fixture alone; it tests the migration.

Then run the whole suite serially (-j 1) and record the result in
docs/DEVELOPMENT.md under a "Baseline" heading: which suites pass, which
fail and one line on why. A partial parallel run at HEAD showed failures in
test_climate, test_climate_lesson, test_climate_operations,
test_clothing_abilities, test_debug_access_time, test_equipment_ui,
test_farm_viewport, test_ferry_access, test_fullscreen_controls,
test_gear_rewards, test_island2, test_island_features_game,
test_latest_game, test_pest_audio and test_playability_audit; some of those
may be load-induced timing failures, so confirm serially. Fix the ones
caused by the fixture rule. For the rest, do not fix them here: they cover
systems the next segments delete, or headless rendering limits. List them.

Acceptance: test_save_safety passes; every suite you touched passes;
tools/run_tests.sh reports the baseline; the game boots.
```

### Segment 2: Remove the Roll House

```
Goal: delete the gacha completely. No luck, no crates, no jackpots, no
trophies, no all-in.

Remove:
- scripts/roll_spinner.gd, roll_luck_meter.gd, casino_surface.gd.
- In game_state.gd: the Roll House block (roll stakes, tier odds, stake
  luck bonus, _grant_roll_reward, jackpot cap, consolation refunds, relic
  and mystery duplicate refunds, trophies, roll history, _rolling_reward
  guards), the `luck` field and effective_luck(), Build Crate granting,
  and every _valid_save rule for those fields. Bump MECHANICS_REVISION and
  migrate old saves by dropping the fields.
- In game_hud.gd: _build_roll, the "roll" branch of _refresh_panel, the
  luck meter, trophy cabinet, receipt, the Roll House button and its R
  shortcut, the CASINO colours.
- In main.gd: every "roll:" action, the reward celebration hooks that only
  the Roll House used (world.play_reward gem bursts for rolls,
  reward_feedback.gd if nothing else uses it).
- farm_world.gd: the Roll House building, sign and interior props; NPC Rook
  and his roster lines in npc_roster.gd; the Roll House NPC voice clip if
  it is Rook's alone.
- island_activities.gd: anything that awards rolls or luck.
- docs/GACHA_PROPOSAL.md.
- Tests: test_roll_balance.gd, test_debug_trophies.gd,
  test_debug_trophies_ui.gd, test_pest_audio.gd's reel checks (keep the
  pest checks), and any check elsewhere that asserts luck or roll state.

Keep: the item catalogue and gear for now (Segment 3 removes them), the
quest boards (Segment 6 rescales them).

Acceptance: `grep -rn "roll\|luck\|jackpot\|trophy\|crate" scripts/`
returns only unrelated words (e.g. "scroll", "stroll"). The game boots, the
menu has no Roll House, tools/run_tests.sh is green.
```

### Segment 3: Remove gear, clothing bonuses and mutations

```
Goal: no item multipliers. The avatar stays; the wardrobe and its bonuses go.

Remove:
- ITEM_CATALOG, equipment, collectibles, relics, artifacts, the Gear tab in
  Inventory, equip/unequip actions, item_stock_factor, item_seed_factor,
  best_gear_hat, harvest and growth bonuses from items, the Aurora Crown
  free roll (already gone), the Trader Token.
- scripts/equipment_preview.gd and its SubViewport; the garment meshes in
  farmer_avatar.gd (keep the body, face, walk and turn blends);
  set_gear_hat in farm_world.gd; the clothing families in item_icon.gd
  (keep icons still used by seeds, tools and shops).
- Mutations: Golden, Crystal, Rainbow, Radioactive; mutation crates in the
  barn; mutation multipliers on sale; mutation quests; the PotatoDex
  "Special mutations" tab (keep "Crop varieties" as the seed reference).
- _valid_save rules for all of the above; bump MECHANICS_REVISION; migrate
  by dropping fields and converting stored mutation potatoes to plain
  potatoes of the same variety.
- Tests: test_equipment.gd, test_equipment_ui.gd, test_gear_rewards.gd,
  test_clothing_abilities.gd, test_wardrobe_world.gd, test_harvest_identity.gd
  checks that assert mutations.

Acceptance: Inventory shows crops and tools only. `grep -rn "mutation\|
equip\|wardrobe\|garment" scripts/` is empty apart from unrelated words.
Suite green, game boots.
```

### Segment 4: Remove stock booms, the Stock Rocket and market events

```
Goal: the market stops being a slot machine. Prices become a placeholder
until Segment 11 builds the real sell/store decision.

Remove:
- Scheduled surges (SURGE_INTERVAL, SURGE_DURATION, _boom_roll, boom tail
  shape), natural spikes, the Stock Rocket (ROCKET_*, _prepare_rocket,
  complete_rocket_launch, rocket_pending), stock caps and
  MAX_PRICE_MULTIPLIER, surge_kind/surge_crop/surge_factor/surge_remaining,
  market events (seed_panic, seed_fair and the rest), the 40-quote history,
  _valid_stock_events, _saved_stock_cap, stock_opportunity(), surge_info().
- scripts/stock_rocket_cutscene.gd, market_impact.gd, market_aura.gdshader,
  market_chart.gd (the full chart page); assets/audio/stock-rocket-launch.wav;
  the stock groove and fanfare synthesis in main.gd's _pump_audio (keep tool
  and harvest foley from farm_audio.gd).
- HUD: the stock countdown, mist and pulse tiers, the market feedback
  colours, tracked seed prices tray, the sell chart page, the
  "practice stock boom" help. Keep Buy Seeds and Sell Potatoes pages but
  strip them to price, quantity and confirm.
- main.gd: camera shake from surges (keep storm shake), rocket layer,
  surge-band effects; the debug speed and access-code controls can stay.
- Placeholder price model: each variety has a base price; the live price
  is base × a slow seasonal drift in [0.85, 1.15] with no spikes. Seeds
  cost 75% of base, not of the live quote.

KEEP the price information the player needs to decide when to sell:
- scripts/price_sparkline.gd and a short per-variety price history (the
  last 12 quotes is enough). Show the sparkline on each Sell Potatoes card
  and each Buy Seeds card.
- The signed percentage against the variety's base price, next to the
  price, e.g. "39 · −8%", green above base, red below. The top bar's crop
  quote keeps the same percentage.
- These stay small and quiet: no colours beyond the sign, no animation, no
  mist. Segment 11 extends the same sparkline to show last Spring's stored
  price so the sell-or-store choice is visible on the card.
If an earlier session already deleted price_sparkline.gd, restore it from
the commit before Segment 4 with `git checkout <that commit> --
scripts/price_sparkline.gd` and re-wire it.
- Tests: test_stock_ceiling.gd, test_stock_rarity.gd, test_stock_rocket_*.gd,
  test_stock_impact_tiers.gd, test_seed_market.gd checks about quotes,
  test_disaster_markets.gd (rewrite the climate price-collapse checks against
  the placeholder model or drop them until Segment 12).

Acceptance: no surge or rocket words in scripts/; the market page shows a
stable price; suite green; game boots.
```

### Segment 5: Remove professions and builds

```
Goal: delete the five builds and everything they own.

Remove: scripts/player_builds.gd, build_professions.gd, build_pages.gd,
build_illustration.gd, profession_world.gd; build_system injection in
main.gd and every has_method("...") duck-typing of it in game_state.gd;
build XP and levels; compost and giant potatoes (cultivated ×3 and hearty
×1.5 multipliers); processing batches and F–SSS grades; the seed bank and
crossbreeding; Investor reservations; Gambler stakes; the Builds menu,
the C shortcut, the workshop, lab, exchange desk and stake table props in
farm_world.gd; Ada, and the other NPC lines that only exist to sell a
profession (keep the characters if they have non-profession dialogue);
the "builds" save block and its validation; the Play Builds Lab.command
launcher and tests/browser_builds_scene.gd; tests test_build*.gd,
test_builds.gd, test_profession_clarity_ui.gd, test_build_transactions.gd,
and profession checks inside other suites.

Keep: climate_system.gd and island_activities.gd, minus the branches that
consulted the build system.

Acceptance: `grep -rln "build_system\|profession\|PlayerBuilds" scripts/`
is empty; suite green; game boots; the menu has no Builds entry.
```

### Segment 6: Flatten the economy and remove taxes-by-boom

```
Goal: small, legible numbers and no systems that only made sense with
booms.

Remove: blind_rules.gd and the whole tax cycle (BOOMS_PER_BLIND,
_record_major_boom, _resolve_blind, tax multiplier rolls, tax tiers by
island, buying on account, purchase_review.gd, recovery orders and
deliver_recovery); combo multipliers (combo window, ×2 to ×16); mastery
levels and their yield and mutation bonuses; the large-number formatter
suffixes above K (M, B, T, Qa, Qi and so on) and the "scientific" coin
storage; quest cash rewards scaled to island baselines (keep quest boards
but pay small flat amounts for now); barn upgrade costs 500·5^level (make
it three levels at 300, 800, 2,000).

Rescale: coins start at 2,000. Crop base prices 15 to 30 per sack
(Segment 13b widens this to 15 to 50). Seeds
cost 75% of base. Tool upgrades 300 to 1,500. Field expansion 1,200.
Yields: one bed gives 3 to 5 sacks. Keep the island yield multipliers out:
1× everywhere. Money renders as an integer with a thousands separator and
the Spudion glyph.

Keep climate_collapse.gd (the editorial bankruptcy page) but make it fire
from a simple overdraft limit of −5,000 until Segment 9 wires the ledger.

Tests: delete test_blinds*.gd, test_tax_credit_land.gd, test_debug_money.gd,
test_purchase_receipts.gd checks about credit; add a small
test_economy_scale.gd that asserts the price table, seed ratio, starting
cash and the overdraft limit.

Acceptance: no number over 100,000 anywhere in scripts/ except timers and
sizes; suite green; game boots.
```

### Segment 7: One farm

```
Goal: a single farm on the Spud Valley map. Islands 2 and 3 stop being
progression.

Remove from state: island2_unlocked, island3_unlocked, island_plots keyed
by id (keep one plots array), travel_to, ferry boarding and the E-at-ferry
path, unlock thresholds (1e6 and 500 harvested etc.), field_expansions and
retained_beds (replace with the single expansion flag), export ships,
Frostbreak, the furnace and furnace_view.gd, the Golden Shores buyer
contracts (Segment 11 rebuilds contracts properly), duck caps per island
(one flock, up to 2 ducks), the Island 2 arrival cinematic
(climate_intro.gd; keep its subtitle system for Segment 13's year-start
page), Sunburst and Icecap as island-locked varieties (keep them as
ordinary varieties with their own dials, added by Segment 10).

Keep in farm_world.gd: the Island 2 and 3 builders and island_terrain.gd,
disabled behind a REGION constant, so regions can return later. Do not
delete the geometry. Remove the ferry routes, jetty interaction and ferry
NPC lines.

Climate: climate_system.gd currently starts disasters only from Island 2.
Make them start on the single farm from year 1 at the low rate Segment 13
will define; for now, a constant 15% per season.

Save: bump MECHANICS_REVISION; older saves are not migrated. Change
DEFAULT_SAVE_PATH to user://taterland_save_v4.json so old farms are never
misread, and delete the v2 and v3 loaders.

Tests: delete test_island2*.gd, test_ferry_access.gd,
test_island_features_game.gd, test_stock_* leftovers, island activity
checks about ships, Frostbreak and the furnace. Update fixtures that used
debug_unlock_island.

Acceptance: the menu has no Travel entry; the game boots on the valley
with 12 open beds and 12 locked; suite green.
```

### Segment 8: Seasons replace the sixty-second day

```
Goal: the clock that the ledger and the climate need.

Add scripts/season_clock.gd (RefCounted, owned by game_state.gd): year
(1..10), season index (0 Spring, 1 Summer, 2 Autumn, 3 Winter), seconds
into the season, SEASON_SECONDS = 150 for working seasons, and a
`winter_menu` flag. Spring, Summer and Autumn are real-time; Winter is a
menu phase that ends when the player presses "Start next year". The
season boundary saves the game. `state.update()` advances the clock; the
farm sim pauses during winter and during any modal that already pauses it
(conversations, collapse page).

Growth: crop grow times rescale so a fast variety ripens within one
season and a slow one needs two. Anything unharvested at the end of
Autumn is lost (a legible loss with a cause card in Segment 12; for now a
notice). Beds can be tilled and planted only in Spring and Summer.

Presentation: the day-night cycle in farm_world.set_day_time now maps to
the position within the season (dawn at season start, dusk at the end) so
the sun tells the player how much labour time is left. Add a season and
year strip at the top of the HUD in place of the old stock countdown.
Snow in Winter is reused from the Frosthollow visuals.

Tests: new test_season_clock.gd (boundaries, saving at boundaries, winter
pause, planting gates, end-of-Autumn loss). Update test_day_night.gd to
the new mapping.

Acceptance: a full year plays through headless in
test_season_clock.gd; suite green; game boots.
```

### Segment 9: The ledger, fixed costs and foreclosure

```
Goal: the scoreboard.

Add scripts/ledger.gd: entries {year, season, category, label, amount},
categories: sales, seeds, water_fuel, labour, upkeep, protection,
insurance, mortgage, rent, living, storage, contracts, other. Every coin
movement in game_state.gd goes through ledger.post(); coins becomes a
derived value (starting cash plus the sum of entries) so the ledger can
never disagree with the purse. Year totals, category totals, best and
worst year.

Fixed costs posted at the start of Winter: mortgage 2,000 (interest 1,000
+ principal 1,000 on a 20,000 loan), rent and land tax 500, living 1,500,
equipment upkeep 500. Constants in one place, docs/REDESIGN_PLAN.md §6 is the
source.

Overdraft: the bank allows −5,000. Crossing it in Winter (after fixed
costs) forecloses: reuse climate_collapse.gd's editorial page with the
ledger's last year, the cause, and Try Again.

Annual accounts screen: a panel that opens as Winter begins (Segment 9b
makes it pause the clock), listing every category for the year, a running ten-year table, and the net figure in large type. Plain,
paper-like, in the existing cream UI. Screenshot-friendly: no HUD chrome
behind it.

Ten-year end screen: after year 10's accounts, a summary page with the
ten-year net, years in profit, worst year, and a placeholder for the
epilogue (Segment 16). Then New Run.

Tests: test_ledger.gd asserts that coins always equals starting cash plus
entry sum, that winter posts the fixed costs, that foreclosure fires at
the boundary and not one coin before, and that ten years end the run.

Acceptance: play a year headless, see fixed costs in the ledger; suite
green; game boots.
```

### Segment 9b: Working Winter (run before Segment 11)

```
Goal: Winter becomes a fourth real-time working season. This corrects
Segment 8, which made Winter a menu phase.

Clock (scripts/season_clock.gd): Winter is season 3 with the same
SEASON_SECONDS as the others. Remove winter_menu and start_next_year().
advance() rolls the year over automatically when Winter ends (year += 1,
season = 0) and the boundary save fires as for any other season. Year 10
ends when its Winter ends: set the run-complete condition to "year 10
Winter finished" and show the ten-year summary then. Keep can_plant()
false in Winter. Tilling is also blocked in Winter.

Accounts at Winter start: when the Autumn to Winter boundary fires, open
the annual accounts panel from Segment 9 and pause the simulation while it
is open, exactly as NPC conversations pause it. Fixed costs post at that
boundary as before. Closing the panel resumes the clock. The panel stays
reachable from the farm menu all Winter. Foreclosure still checks after
the fixed costs post.

Frozen fields: at the Autumn to Winter boundary, unharvested crops are
lost as now, then every bed ices over (reuse the frost visuals and the
"hoe the ice" action kept from the old Frostbreak). Hoe [1] on an iced
bed clears it. A bed cleared in Winter is ready to till on the first
second of Spring; a bed still iced at Spring start must be cleared first,
costing Spring labour. That is the reason to work in Winter.

Water: the tank refills at a quarter rate in Winter (snow, not rain). The
watering can and sprinklers are not needed since nothing grows, except
Icecap (Segment 10 gives it "grows through Winter"; until then nothing).

Visuals: the Segment 8 snow cover and roof snow appear for the whole
season; the sun still runs dawn to dusk, lower and paler.

HUD: remove the Winter panel's "Start next year" button and the pause
menu's Winter entry; the season strip shows "Year N · Winter" like any
other season. The old Winter panel becomes the accounts panel's host.

Tests: rewrite test_season_clock.gd for four working seasons, automatic
rollover, the year-10 end condition, and ice clearing carrying into
Spring. Update test_ledger.gd for accounts-at-start pausing.

Acceptance: a full year of four seasons plays through headless; ice
cleared in Winter is tillable at Spring start; suite green; game boots.
```

### Segment 10: Crop cards and the planting decision

```
Goal: the first player decision, with no theory.

Data: a CROPS table with five varieties (Russet, Giant, Golden, Sunburst,
Icecap) each with: seed cost, base price, price volatility (low/mid/high),
water need (1 to 3), heat tolerance (1 to 3), cold tolerance (1 to 3), grow
seasons (1 or 2), sacks per bed. Fragile varieties pay more. Icecap is the
exception card: it can be planted in Autumn and keeps growing through
Winter on an iced bed, harvested in Winter or early Spring, so it is the
only crop that turns Winter labour into sales. Put the table
in scripts/crop_table.gd and make game_state.gd read it; remove the old
CROPS constants and GROW_TIMES.

Mechanics: water need sets how fast an unwatered bed accrues stress and
how much drought hurts; heat and cold tolerance scale the existing climate
stress rates (climate_operations.gd) per variety; volatility sets the
seasonal price drift range (Segment 4's placeholder) and how far the
spring storage price can rise (Segment 11).

UI: the Buy Seeds page becomes a row of cards, one per variety, with the
three dials drawn as three short bars, seed cost and last year's price.
Selecting a card selects the seed tool. Keep seed_slot.gd for the hotbar.

Tests: test_crop_table.gd (table sanity: higher price implies lower total
tolerance; every variety can ripen in the season budget) and updates to
the planting checks in test_simulation.gd.

Acceptance: five cards visible, dials readable on a phone-width layout;
suite green; game boots.
```

### Segment 11: Selling, storage and contracts

```
Goal: the second decision.

Selling at harvest pays the current (glut) price. Storing costs 200 per
Winter, loses 10% of stored sacks to spoilage, and the stored price climbs
through Winter from base × 1.0 at the start to base × (1.2 to 1.6 depending
on volatility) by late Winter, then falls back at Spring. Selling stored
sacks is a Winter action at the barn, so timing within Winter matters. Storage
capacity is the barn level. Contracts: in Spring, one buyer offers a fixed
price per sack (base × 1.1) for a quantity due at Autumn; a shortfall costs
5 per sack. One contract at a time.

UI: the Sell Potatoes page shows per variety: sell now at X, or store; the
card's sparkline (kept in Segment 4) gains a dashed marker for the expected
Spring storage price and the signed percentage against base stays beside
the live price; the Winter accounts show storage cost and spoilage; a
Contracts panel on the buyer board (reuse the Golden Shores board visuals).

Ledger: sales, storage, contracts categories.

Tests: test_market_decisions.gd: storing then selling in Spring pays more
than selling at harvest in a calm year; spoilage and fee are posted;
contract shortfall penalty posts; capacity is enforced.

Acceptance: suite green; game boots.
```

### Segment 12: Protection, insurance, forecast and cause cards

```
Goal: the third decision, and legible losses.

Map the existing climate projects (climate_projects.gd, two levels each)
to: Rainwater tank (drought), Drainage (flood), Windbreak (storm), Frost
cover (freeze). Cost 1,500 to 2,500 for level 1, roughly double for level
2, upkeep 100 per year posted at Winter start. Building is Winter work:
paying reserves the project, then the player walks to its site and spends
labour (a few hoe-style actions) to finish it before Spring; unfinished
work carries to the next Winter. Frost covers are placed per bed in
Winter and protect that bed against the Spring freeze. Level 1 cuts that disaster's field
loss by 50%, level 2 by 75%. Insurance: 400 per year, pays 40% of the
season's crop loss at Winter. Keep the water loop (tank, can, sprinklers)
as the manual side of drought.

Forecast: the weather station (weather_station.gd, weather_pages.gd)
shows next season's disaster chance as a range, e.g. "Drought 20 to 50%".
Station level 0 gives ±20 points, level 1 ±10, level 2 ±5. The true
chance comes from Segment 13's curve; until then, use the constant.

Cause cards: every crop loss produces a card in the season's notice list
and in the Winter accounts: event, season, variety, sacks lost, what was
unprotected, and what the missing protection would have saved. Compute the
counterfactual from the same loss formula with the protection applied.

Tests: test_protection.gd (loss reduction per level, insurance payout,
upkeep posting, forecast ranges bracket the true chance, cause card
counterfactual equals the formula).

Acceptance: suite green; game boots.
```

### Segment 13: Climate escalation and the villain's face

```
Goal: the trend the player can see.

Curve: per season, disaster chance = 0.15 + 0.04 × (year − 1), capped at
0.6; severity mean = 0.5 + 0.03 × (year − 1). Event mix by season: Spring
flood or freeze, Summer drought or storm, Autumn storm or flood, Winter
deep freeze or blizzard (these hit the barn's stored sacks and any Icecap
in the ground, not empty beds). Constants in climate_system.gd, read by the forecast.

Foreshadowing: the season before a drought, the tank fills at half rate
and the ground colour dries; before a flood, rain visuals run more often;
before a storm, wind ribbons appear. The signal is present 70% of the time
so it is a hint, not a promise.

Villain presentation: a year-start front page (reuse climate_intro.gd's
subtitle and skip mechanics) with a headline that grows grimmer by year
and a ten-year climate strip showing each past year's disasters as icons.
The same strip lives in the Winter accounts.

Season character: Spring, Summer and Autumn must look different at a
glance, not only through the sky. Spring: blossom on the fruit trees,
fresh green grass tint, small flowers in the verges. Summer: warmer grass,
a faint heat haze over the field on hot days, the tank level visibly
mattering. Autumn: orange and brown tree canopies, fallen leaves on the
paths, longer dusk. Winter keeps the Segment 8 snow. Implement as per-season
tints and a few swapped meshes in farm_world.gd, driven by the season
clock, with a one-second crossfade at each boundary so the sky and grass
do not snap. Foreshadowing signals sit on top of these looks. Later years
should also show the trend: by year 6 the Summer grass is drier and the
haze stronger even in calm seasons, so the villain is visible without a
disaster.

Frequency cap: warning 45 s + active 30 s + recovery 75 s fills one
150 s season, so at most one disaster per season and three per year. Keep
that cap in this segment. Shortening the phases to allow more is a
decision for after Segment 14's tuning results.

Tests: test_climate_curve.gd (chance and severity by year, event mix,
foreshadowing rate over many seeded seasons, season tint values by season
and by year).

Acceptance: suite green; game boots.
```

### Segment 13b: Potato grades (run before Segment 14)

```
Goal: the reward for farming well, and a wider spread between varieties.
Harvested potatoes get a grade that changes their price, decided by how
the crop was treated. A well-kept crop earns more; a neglected one earns
less. Must land before the tuning bot because it moves the economy.

Grades and prices, per sack, relative to the variety's base price:
- Table: base × 1.5. Clean, undamaged, harvested on time.
- Standard: base × 1.0.
- Feed: base × 0.5. Bitten, stressed or left too long.
Also "Keep as seed": at the barn, a Standard or Table sack of a variety
can be kept over Winter and becomes one seed of that variety next Spring.
Kept sacks are not sold and are not counted as storage for spoilage.

Widen the variety spread in scripts/crop_table.gd so base prices run 15
to 50: Russet 15, Giant 20, Golden 28, Sunburst 38, Icecap 50. Seeds stay
at 75% of base. Higher base still means more fragile (Segment 10 dials).

Quality score per bed: starts at 100 when planted, stored on the plot.
Deductions, each scaled by the variety's fragility (inverse of its
tolerance dials) and reduced by the relevant protection with the same
formula used for field loss:
- each pest bite tick: −6
- drought or flood stress while active: −4 per 10 s of stress
- freeze on the bed: −15 once, further −4 per 10 s
- storm lightning row hit: −25 once
- unwatered while growing: −2 per 10 s
- ripe and left in the field: −5 per 10 s after the first 30 s
Grade at harvest: 80 to 100 Table, 40 to 79 Standard, below 40 Feed.
Storage: every Winter in storage costs −10 quality, so Table can become
Standard; this replaces part of the 10% spoilage (keep 5% spoilage).

Legibility: a small tag on each growing bed shows its current grade word
(Table / Standard / Feed) in the bed's hover and near-player context; the
harvest pop shows the grade; the annual accounts show sales split by
grade with sacks and totals; a cause line explains the largest deduction
on a downgraded bed ("Pests took it to Standard").

Wiring: storage becomes per variety per grade; the Sell Potatoes page
lists each grade with its price; contracts (Segment 11) require Standard
or better; the farm shop (Segment 15) sells Table only at base × 1.8;
the ledger sales category records grade in the label.

Tests: test_grades.gd (score deductions and thresholds, protection
reduces deductions, kept seed appears next Spring, storage downgrade,
contract refuses Feed, sales by grade sum to the ledger).

Acceptance: a bed hovered mid-season shows its grade; a harvest shows
the grade; suite green; game boots.
```

### Segment 14: The tuning bot

```
Goal: prove the numbers instead of arguing about them.

Write tests/test_tuning_bot.gd: a headless bot that plays full ten-year
runs on game_state.gd with four fixed strategies:
- naive: plant the highest-price variety, never protect, sell at harvest;
- cautious: plant mid variety, buy tank then drainage in the first two
  affordable winters, store half the harvest, insure from year 2;
- tidy: like cautious but sprays pests promptly, waters on time and
  harvests within 30 s of ripening, so most sacks reach Table grade;
- (placeholder until Segment 15) diversifier: same as cautious.
Tidy must out-earn cautious by a clear margin (15 to 30% over ten years)
and still never get rich; if it does not, grade prices are too flat.
Run each over 30 seeds. Assert: naive forecloses by year 6 on the median
seed; cautious survives year 10 on at least 24 of 30 seeds; no strategy
ends year 10 with more than 8,000 cash; for every run, every year's ledger
sums to the cash delta exactly.

Expose the constants the bot depends on (fixed costs, prices, protection
costs, curve) in one scripts/balance.gd so tuning is one file. Adjust the
values until the assertions hold, and record the final values in
docs/REDESIGN_PLAN.md §6.

Acceptance: test_tuning_bot.gd passes; the constants are documented.
```

### Segment 15: Diversification and run titles

```
Goal: the mid-game strategic decision.

From year 3, the accounts panel offers: Farm shop (3,000 to build, +800 per
year, consumes one season's worth of labour each year by shortening
Summer by 30 seconds), Contract grower (unlocks two simultaneous
contracts and a 1.2× contract price), Lodging (2,500, +600 per year, income
scales with how many protections exist because guests like a farm that
looks kept). Each posts to the ledger under its own label.

Run titles at year 10: Adapter (three or more protections), Shopkeeper
(most income from diversification), Stubborn (no protections, survived),
Sold Up (foreclosed).

Add the diversifier strategy to the tuning bot and re-run its assertions.

Acceptance: test_tuning_bot.gd passes with all three strategies; game
boots.
```

### Segment 16: The fifty-year epilogue

```
Goal: the ending. See docs/REDESIGN_PLAN.md §4b for the design.

Simulation: after the ten-year summary, run 40 more years headless on the
final state with a caretaker policy (same crops, same protections, same
diversification, repairs when affordable) and the climate curve continuing.
Compute four axes in [0,1]: solvency, adaptation, diversification, land
health. Map them to one of seven outcomes: Dust, Drowned, Deserted, Sold to
the estate, Holding on, The shop village, Thriving. Thriving requires all
four axes above 0.75.

Presentation: the climate strip extends to fifty years with one headline
per decade; the camera fades up on the future farm and pans slowly; each
axis gets one verdict line under the scene; a final ledger line "Farm
value, 50 years on"; a screenshot button.

Visuals in farm_world.gd: future states for beds (cracked, flooded,
overgrown, monoculture), buildings (collapsed, boarded, estate storage,
shop village), water (dry tank, standing water), reusing the flood, ice,
snowbank and sand visuals.

Tests: test_epilogue.gd: the bot's three strategies land in three
different outcomes; Thriving is unreachable without all four axes; the
epilogue is deterministic for a given final state.

Acceptance: suite green; the ending plays headless and on screen.
```

### Segment 17: Cast, first year and store copy

```
Goal: make it speak.

NPCs: rewrite npc_roster.gd for the new roles. The accountant reads the
ledger in Winter (two lines, honest, dry). The farmhand tells you what the
weather did and what it cost. The bank manager appears when the overdraft
passes half its limit. The weather forecaster fronts the year-start page.
Keep the potato voices and the existing conversation system.

First year: rewrite first_island_tutorial.gd as a guided first year that
ends at the first annual accounts: plant one card, water, one small
disaster in Summer with its cause card, harvest, choose sell or store, then
Winter and the ledger. All later help stays optional.

README and store copy: lead with the ledger screenshot. Tagline: "A farming
game where you lose money." Update docs/GAMEPLAY.md to describe the run,
the three decisions, the ledger and the epilogue, and remove every
paragraph about removed systems.

Acceptance: test_tutorial_*.gd rewritten and green; a new player can reach
the first accounts screen headless in the tutorial test.
```

### Segment 18: Farm visuals pass (run after Segment 15)

```
Goal: every new mechanic gets real art on the island, in the existing
low-poly, vertex-coloured style of farm_world.gd. No new asset pipeline;
build from the same primitives and the static mesh compiler.

Replace and add:
- Winter: replace the flat white sheet with snow that sits on things.
  Drifts against fences and walls, snow caps on every roof and tree, bare
  fruit trees, frozen tank surface, footprints on the paths the farmer
  walks, ice on beds drawn as a cracked glaze that Hoe visibly breaks.
- Seasons (from Segment 13): make blossom, summer haze, autumn canopies
  and fallen leaves read at the default zoom, not only up close.
- Beds: a small grade marker on each growing bed (green leaf for Table,
  plain for Standard, brown for Feed) that matches the hover tag; stress
  reads on the plant (wilting for drought, yellowing for flood, frost
  rime for freeze), not only on the border.
- Barn: stored sacks visibly stack inside the open barn door in Winter;
  sacks kept for seed sit in a separate crate; spoiled sacks show as a
  darker heap that shrinks.
- Buyer board: the contract shows as a crate with a chalk tag by the
  road; on collection a cart arrives and leaves.
- Protections: the tank, drainage channels, windbreak rows and frost
  covers are visible buildings and objects that appear as they are built
  in Winter, with an under-construction state while unfinished.
- Weather station: the forecast range shows on the instrument face.
- Farmer: a Winter coat and hat in Winter, straw hat in Summer, from the
  fixed-outfit system kept in Segment 3.

Keep draw calls near the current count: everything static goes through
the batcher; only animated pieces stay separate. Check the web build.

Tests: test_farm_visuals.gd (season and Winter states build without
errors, grade markers match state, batcher counts within a budget).

Acceptance: a screenshot of Winter, of a stressed bed and of a built tank
each look finished; suite green; web export runs.
```

### Segment 19: Interface visuals pass

```
Goal: the new screens look designed, in the cream paper and ink style of
UI_STYLE.md, on desktop and phone.

- Annual accounts: a ledger page. Ruled lines, category rows with dot
  leaders, the net figure in the display font, a stamped year, the
  ten-year table as a small column, the climate strip beneath, cause
  cards as pinned notes. This is the screenshot screen: no HUD chrome
  behind it, a screenshot button that saves to the user folder.
- Crop cards: illustrated potato per variety (item_icon.gd), the three
  dials as short bars with icons (drop, sun, snowflake), seed cost, last
  year's price, and a grade preview line; selected card lifts.
- Sell page: one row per variety, then per grade; the sparkline with the
  dashed Winter marker; a single line explaining storage.
- Contracts and Winter stores: paper order slip and a barn tally board.
- Front page (Segment 13): a newspaper layout with masthead, headline,
  the ten-year strip as a weather column, and a skip control.
- Forecast: the range as a bracket on a scale, not text only.
- Foreclosure and ten-year summary: keep the editorial page, add the
  final ledger and the epilogue lead-in.
- Season strip: a small four-segment bar under the wordmark with the
  current season lit and the year number.
- Phone layouts for every page above; touch targets at least 44 px.

Remove leftover copy from the old game wherever it appears (stock words,
island names other than Spud Valley, quest names from the market era).

Tests: update the HUD layout and responsive suites for the new pages at
the existing viewport set.

Acceptance: every panel screenshotted at desktop and phone width looks
consistent; suite green.
```

### Segment 20: Feel, sound and performance

```
Goal: the last mile before the tutorial rewrite.

- Transitions: one-second crossfade at season boundaries (sky, grass,
  snow); accounts page slides in from the ledger book; front page fades.
- Sound: a short seasonal ambience loop each (birds, cicadas, wind,
  muffled snow), the existing tool foley, a paper sound for the ledger,
  a low note for foreclosure. Reuse climate_audio.gd for weather.
- Harvest and grade feedback: the harvest pop shows the grade stamp with
  a distinct sound per grade.
- Epilogue (Segment 16): the fifty-year pan, headlines fading in per
  decade, the four verdict lines typed on.
- Camera: gentle push-in on the accounts open; storm shake stays bounded.
- Performance: profile the web build at phone resolution; the per-frame
  costs noted in the original analysis (day-time rewrite, nearby-station
  scan on every frame, per-sample audio synthesis) are fixed here if
  still present. Target 60 fps on a mid-range phone in Summer with rain.
- Save: confirm the boundary save never hitches longer than a frame;
  move it off the main thread if it does.

Tests: test_feel.gd for transition timing and audio presence; a
benchmark script that reports frame time in the browser fixture.

Acceptance: a full year played on a phone without a visible hitch; suite
green; web export runs.
```

## 8. Logic checks on the original plan

- **Hard versus unfair.** "Barely any money" only works if every loss is
  attributable to a decision the player could have made differently. Cause
  cards and foreshadowing are not polish; they are what makes the difficulty
  acceptable.
- **Villain versus RNG.** A random disaster is bad luck. A trend the player
  watched climb for five years is a villain. The ten-year strip is essential.
- **Simple versus trade-offs.** These only coexist when the dials are few:
  three per crop, five protections, three diversifications. Resist adding.
- **Big numbers out means multipliers out.** Every existing 3×, 8×, 16× and
  luck system is meaningless in a small-number economy. Cut rather than
  rescale; rescaled versions still push players to chase one lever.
- **Real-time days versus annual pacing.** The current 60-second day cannot
  carry a year structure. Seasons must come before any economy tuning.
- **Browser sessions are short.** A season of two to three minutes with a
  save at every season boundary fits phone play. A year should never require
  one sitting.
- **Do not tune by hand.** The economy in §6 is a guess. Phase 5's bot is how
  the numbers get proven, and it reuses the existing headless test harness.
