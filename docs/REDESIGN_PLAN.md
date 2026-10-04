# Taterwake redirect: the honest potato farm

Design plan for turning Taterland from a big-number market game into a hard,
legible farming survival game where climate change is the antagonist. Written
as a handoff for implementation.

## 0. Locked decisions

- **Real-time seasons.** Each working season is a short real-time phase with
  the avatar and tools, including Winter. Annual accounts pause only while open.
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
  sell or store), Winter (accounts, plan, buy protection, repairs).
- Each working season is a real-time phase of about **2 to 3 minutes**. The
  season length is the labour budget: you cannot water, hoe and harvest every
  bed if the farm is big. Hiring a hand costs money and buys time. Sprint stays.
- **Winter** is a real-time working season: accounts pause at its start, then ice clearing and repairs prepare the next Spring. The year rolls over automatically.
- A run is **ten years**, roughly 100 minutes of working time across sessions, saved
  every season. Foreclosure is game over.
- Foreclosure happens when the overdraft passes the bank's limit. The bank is
  the second antagonist and is polite about it.
- End of run: a ten-year ledger, the climate record, a title for how you
  farmed (Adapter, Shopkeeper, Stubborn, Sold Up), then the epilogue.

One connected Valley island whose climate shifts in place over ten years. Home is sheltered; Low Field dips toward the front-right shore, and Hill Field occupies three shallow terraces behind the village. Additional land is a Winter lease decision, not travel or a new region.

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

## 6. Economy model (including pace and land tuning)

All tuning lives in `scripts/balance.gd`; game systems and the headless bot
read the same constants. `MONEY_SCALE = 40` multiplies every monetary constant;
the earlier unit rescale left ratios, yields, quantities, calendar and climate unchanged. The current pacing and field changes are recorded below. Tool, barn,
duck, irrigation, station and quest money also lives in this file. These values
replace the original starting guesses.
Opening cash is **80,000**, the overdraft boundary is **−200,000**, and foreclosure
is assessed at Winter start after storage, insurance, upkeep, business income and fixed bills.

| Fixed annual payment | Spudions |
| --- | ---: |
| Mortgage interest | 24,000 |
| Mortgage principal | 24,000 |
| Rent and land tax | 12,000 |
| Living costs | 32,000 |
| Equipment upkeep | 12,000 |
| **Fixed total** | **104,000** |

The initial loan is 480,000; ten principal payments leave 240,000. Opening the
remaining twelve beds costs 48,000. Seeds and protection are additional costs.

| Variety | Seed | Standard base / tonne | Tonnes / bed | Grow seconds | Volatility |
| --- | ---: | ---: | ---: | ---: | --- |
| Russet | 270 | 360 | 3 | 60 | Low |
| Giant | 360 | 480 | 5 | 110 | Low |
| Golden | 504 | 672 | 4 | 90 | Mid |
| Sunburst | 684 | 912 | 3 | 160 | High |
| Icecap | 1,200 | 1,200 | 2 | 200 | High |

Table / Standard / Feed multipliers are **1.2 / 1 / 0.5**, with the existing
80 / 40 quality thresholds. Icecap's higher seed cost and smaller harvest
make price-chasing expensive. Two complete Golden sowings cost 24,192 in
seed and produce at most 192 tonnes before weather, pests or spoilage.
Volatility remains 5% / 10% / 15% ordinary drift and 1.2 / 1.4 / 1.6 late-Winter
storage factors. Nonempty Winter storage costs **4,800**, spoils **5%** rounded
across the whole barn, and deducts ten quality. Contracts pay base × 1.1
and penalize missing tonnes by 200.

| Protection | Level 1 | Level 2 |
| --- | ---: | ---: |
| Rainwater tank | 36,000 | 72,000 |
| Drainage | 48,000 | 96,000 |
| Windbreak | 60,000 | 120,000 |
| Frost cover | 36,000 | 72,000 |

Each completed project costs **2,400 annual upkeep**, regardless of level, and
reduces matching field losses by **50% / 75%**. Annual insurance costs **9,600**
and pays **40%** of insured losses at base prices.

The climate curve remains `min(0.6, 0.15 + 0.04 × (year − 1))` per season;
severity mean is `0.5 + 0.03 × (year − 1)`, with uniform ±0.15 variation
clamped to 0–1. There are at most three disasters per year. True precursor
signals appear 70% of the time, false signals 10%. Winter deep freeze and
blizzard remove 20% / 30% times severity of exposed stored tonnes and living
Icecap. These constants also live in `balance.gd`.

Current balance results (Godot 4.7.2, seeds 1–30, 40% dry growth and Segment 20 pace controls):

| Policy | Completes year 10 | Median ending year | Mean ending cash | Maximum ending cash | Mean crop sales |
| --- | ---: | ---: | ---: | ---: | ---: |
| Naive | 0 / 30 | 4 | -245,170.12 | -201,127.63 | 388,763.21 |
| Cautious | 30 / 30 | 10 | -26,996.95 | 56,594.15 | 1,372,380.97 |
| Tidy | 30 / 30 | 10 | 271,118.27 | 319,021.66 | 1,759,191.23 |
| Diversifier | 28 / 30 | 10 | 28,661.22 | 143,980.64 | 1,284,880.84 |
| Expander | 29 / 30 | 10 | 87,956.58 | 215,971.19 | 2,018,396.42 |

All **1,679 bot checks** pass across 150 runs, including exact annual journal replay. Tidy's mean crop-sales advantage is **28.19%**. Expander's mean cash is between cautious and tidy, near positive 100,000, with 29 survivors against the required 24. Diversifier's mean cash exceeds cautious by **55,658.17** and remains below tidy. Ending statistics include foreclosures; receipts stop when a farm closes. No funding, forced weather, yield changes or strategy shortcuts were added.

Low Field rent is **55,000 a year**; Hill Field remains **9,000**. The preceding 44,000 rate left expander mean cash at 207,828.24, close to tidy, and one seed above the 320,000 cash ceiling after dry growth changed. Raising rent creates a distinct expansion trade-off while keeping survival above 24/30. Leases pay ahead in Winter, starting with Winter 1 for the expander's year-two planting. Each lease opens twelve beds; the other twelve cost the existing 48,000 expansion price. Home's fixed rent and tax remain in the annual bills above. Low's yield multiplier is 1.25; field exposure and cancellation rules are listed in `GAMEPLAY.md`.

The single pest chance is **16%**, **24% in Summer**, and **zero in Winter**,
with its deadline uniformly between 25% and 60% of base grow time. The old
22% chance failed cautious survival after the pacing change, so it was reduced.
Seasons remain 150 seconds; the current crop durations are in the table above.

Historical baseline before pace and land (Godot 4.7.2, seeds 1–30, growth 75/135/105/195/225 seconds):

| Policy | Completes year 10 | Median ending year | Mean ending cash | Maximum ending cash | Mean crop sales |
| --- | ---: | ---: | ---: | ---: | ---: |
| Naive | 0 / 30 | 5 | -241,172.67 | -206,131.20 | 523,334.00 |
| Cautious | 28 / 30 | 10 | -57,366.49 | 44,222.40 | 1,333,000.66 |
| Tidy | 30 / 30 | 10 | 222,203.62 | 289,769.79 | 1,693,136.10 |
| Diversifier | 29 / 30 | 10 | -36,979.83 | 116,663.30 | 1,270,999.05 |

Tidy earns **27.02%** more crop receipts across the cohort, or **25.07%**
on the 28 matched seeds where both policies complete ten years. Tidy harvests
**96.27% Table tonnes** overall (minimum per seed 86.65%). Ending statistics
include the two cautious foreclosures and one diversifier foreclosure; naive receipts stop at foreclosure. Every year's
journal reconciles exactly. The maximum completed-run cash is **289,769.79**.
Diversifier enrols on all 30 seeds, builds 28 shops and 27 lodgings, and earns
mean diversification receipts of **278,414.93**. Seed 25 forecloses in year nine;
seed 17, which cautious loses, survives. All **1,045 annual journals** reconcile
exactly, with **1,836 bot checks** passing. Construction can remain unaffordable
on a bad seed; the bot receives no credit or income outside the game rules.

The September 29 Table-price follow-up (before the 40× rescale; amounts in
this historical paragraph use the original units) tested **1.5× at quality 85**, with
Feed unchanged at **0.5×** and the tidy crop-sales advantage ceiling raised
to **40%**. Cautious still completed **28/30** and tidy **30/30**, but tidy's
mean ending cash reached **14,424.72** (minimum **10,822.40**, maximum
**17,972.26**), failing the requested mean below 8,000. Its crop-sales advantage
was **53.95%**, also above the new ceiling. Naive median foreclosure slipped
to year **7**, failing the existing by-year-six check. The experiment was
rejected: **Table remains 1.2× at quality 80**. The bot retains the new **15–40%**
advantage range and an explicit **tidy mean cash < 320,000** assertion in the scaled units, alongside
its existing individual cash limits. `TABLE_THRESHOLD` now lives in
`balance.gd` with the multiplier so both knobs can be tuned in one file.

From year three, Winter accounts offer these permanent businesses, with
benefits beginning the following year. Values live in `balance.gd`.

| Business | Build/enrolment | Annual benefit |
| --- | ---: | --- |
| Farm shop | 120,000 | 34,000; Summer loses 30 seconds (120 remain) |
| Contract grower | 0 | Two simultaneous orders; contract quote × 1.2 |
| Lodging | 100,000 | 28,000 × completed protection types / 4 |

Lodging counts tank, drainage, windbreak and frost cover once each, ignoring
levels and sprinklers. Annual shop/lodging income posts before foreclosure;
construction Winter pays nothing. Each has its own ledger label.

The regression is `tools/run_tests.sh -j 1 --timeout 1500 test_tuning_bot`.
It runs seeds 1–30 for all five policies on the real `game_state.gd`.
Every policy pays to open 24 beds and plants each bed once in Spring and
once in Summer when the previous crop has cleared. Naive chooses Icecap,
waters after 30 seconds, harvests immediately, sells everything and buys no
protection. Cautious chooses Golden, waters after 30 seconds, harvests after
35 ripe seconds, leaves pests untreated, stores half cumulatively and sells
stores at Winter second 149. It buys tank then drainage, at most one in each
of the first two affordable Winters, and renews insurance from year two.
Tidy uses the same planting, selling and investment rules, but checks watering
and pests every second and harvests within one second of ripening. All policies
clear ice and use actual can/tank reserves. Diversifier keeps cautious crop
care, then enrols and buys at most one business at Winter second 149 from year
three, after store sales: shop first, lodging second, retaining 40,000 of credit
above the overdraft boundary. It accepts only matching Golden premium orders
and reserves promised tonnes at harvest. Other policies take no contracts.
The original four policies rent no land. Expander follows cautious with the same Golden crop and leases Low Field at Winter 1 for years 2–10, using its first twelve beds. No policy uses kept seed, quests, hired help or free funds.

“Out-earns” means total **crop sales receipts** over the ten-year cohort;
a percentage of net profit would be undefined or misleading when it is zero
or negative. The bot also checks majority-Table tidy harvests, the 320,000 per-run cash
ceiling, tidy mean cash strictly below 320,000, the 15–40% advantage range, survival and exact annual journal replay against observed purse changes. It additionally requires expander survival of at least 24/30, expander mean cash of 80,000–120,000 between cautious and tidy, and diversifier mean cash at least 40,000 above cautious and below tidy.
It uses ordinary IEEE float transaction order, with no approximate-equality
allowance. Reports under `artifacts/test-results/tuning_<strategy>.json` include
each seed's annual opening, closing and category totals. The obsolete pre-scale outcome fixture was removed when pacing changed; annual ledger replay stays exact. This tests state-level
strategies; it does not model avatar walking time or prove that every possible
human policy stays below 320,000.

The debug money cap is **4,000,000**. Monetary displays round to whole
Spudions with separators; internal transaction precision is unchanged. Cards
and receipts use **t**, prose uses **tonnes**, and the underlying integer
quantities stay unchanged (including Icecap's two-tonne yield). Mechanics
revision **42** safely sets earlier saves aside, including revision 41 farms without field leases. The economy suite
rejects non-rate balance values below one in magnitude, except explicitly
free contract-grower enrolment, and checks phone/desktop prices and accounts.


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
into the season, SEASON_SECONDS = 150 for all four seasons. Winter rolls
into the next Spring automatically; the run ends after year 10 Winter.
Every boundary saves. Annual accounts open and pause at Winter start;
closing them resumes work. Conversations and collapse also pause the sim.
This working-Winter amendment replaces the original menu-phase design.

Growth: crop grow times rescale so a fast variety ripens within one
season and a slow one needs two. Anything unharvested at the end of
Autumn is lost (a legible loss with a cause card in Segment 12; for now a
notice). Beds can be tilled and planted only in Spring and Summer.

Presentation: the day-night cycle in farm_world.set_day_time now maps to
the position within the season (dawn at season start, dusk at the end) so
the sun tells the player how much labour time is left. Add a season and
year strip at the top of the HUD in place of the old stock countdown.
Snow in Winter is reused from the Frosthollow visuals. The sun stays lower
and paler but still moves dawn to dusk. Autumn loss freezes every bed; Hoe
clears the ice, and uncleared ice survives into Spring. Tilling is blocked
in Winter. The tank refills at one quarter rate; no crop grows yet.

Tests: new test_season_clock.gd (boundaries, saving at boundaries, accounts
pause, automatic rollover, ice clearing, planting gates, end-of-Autumn loss). Update test_day_night.gd to
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

Ten-year end screen: after year 10's Winter finishes, a summary page with the
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
exception: it can be planted in Autumn and keeps growing through Winter
on an iced bed, harvested in Winter or early Spring. Put the table
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
late-Winter storage price and the signed percentage against base stays beside
the live price; the Winter accounts show storage cost and spoilage; a
Contracts panel on the buyer board (reuse the Golden Shores board visuals).

Ledger: sales, storage, contracts categories.

Tests: test_market_decisions.gd: storing then selling in late Winter pays more
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
- tidy: like cautious, but sprays promptly, waters on time and harvests
  within 30 seconds; most sacks should be Table grade.
- (placeholder until Segment 15) diversifier: same as cautious.
Tidy must out-earn cautious by 15–30% over ten years without getting rich.
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

### Segment 14b: Farm-scale money (run before Segment 16)

```
Goal: the same economy in realistic units. The tuned numbers are the right
shape but read like pocket money; a decade of careful farming ending at
minus 1,400 is not a farm. Scale every money constant by one factor and
rename the unit so the ledger reads like real accounts.

Scale factor: 40. Apply it to every money constant in scripts/balance.gd
and nowhere else: crop base and seed prices, opening cash, overdraft,
loan, fixed costs, protection costs and upkeep, insurance premium,
storage fee, shortfall fee, field expansion, business costs and incomes.
Ratios, grade multipliers, volatility, climate constants and quantities
stay exactly as they are. Also scale the debug money cap (MAX_MONEY) and
the tuning bot's cash ceiling (8,000 becomes 320,000) and any other
absolute money threshold in tests. Quantities are unchanged.

Units: a "sack" becomes a "tonne" everywhere in copy (t on cards and
receipts, "tonnes" in sentences). A bed yields 3 to 5 tonnes. Prices are
per tonne. Money keeps the Spudion glyph and thousands separators; no
decimals anywhere on screen.

Expected result after scaling: Russet 360 per tonne, Icecap 1,200;
opening cash 80,000; fixed costs 104,000 a year; overdraft 200,000;
careful play ends the decade near minus 57,000, perfect play near plus
220,000, naive play forecloses owing about 240,000.

Tests: run the whole suite; the tuning bot must print the same survival
counts and the same means multiplied by 40. Add a check that no balance
constant is below 1 after scaling except quantities and rates.

Acceptance: ledger and sell page show farm-sized figures with separators;
tuning bot statistics are the old ones times 40; suite green.
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

### Segment 17b: Pace and land (run before Segment 18)

```
Goal: more happens between planting and harvest, on a farm big enough
that the player cannot do everything. Fixes three complaints from play:
the guided year is slow, growing is slow, and pests arrive after harvest.

1. Pest timing (bug). Pest delays are still tuned for the old ten-second
   crops. Rescale: a planted bed's first pest chance opens at 25% of its
   grow time and pests must arrive, if at all, by 60% of grow time; pest
   pressure is highest in Summer (multiply the chance by 1.5) and zero in
   Winter. Ducks keep their patrol. Every pest bite still costs quality.
   Test: over many seeded beds, first pests land inside 25 to 60% of grow
   time and never after ripening.

2. Three fields with different exposure. Bring the preserved Golden
   Shores and Frosthollow geometry onto the same island as two more
   fields so the map is roughly twice its current size:
   - Home Field: the current 24 beds. Sheltered: storm and flood stress
     × 0.8.
   - Low Field: 24 beds on the shore side using the Shores ground.
     Yield × 1.25. Flood stress × 1.5 and floods hit it first; drought
     × 0.8.
   - Hill Field: 24 beds on higher ground using the Frosthollow ground
     without snow. Drought stress × 1.5 and it dries first; flood × 0.5;
     storm wind × 1.3; freeze × 1.2.
   Home Field starts with 12 beds open as now. Each other field is
   rented in Winter from the accounts page: Low Field 12,000 a year,
   Hill Field 9,000 a year (scaled money), posted under rent, cancellable
   any Winter. Beds inside a rented field open in two halves as Home
   Field does, at the existing expansion cost. Protections cover the
   whole farm at their level; per-field exposure multiplies the loss.
   Cause cards name the field. The forecast page shows the three fields
   with their exposure words (Floods first / Dries first / Sheltered).
   The walkable area, camera bounds and recenter grow with the map;
   sprint stays. Ducks patrol all rented fields.

3. Grow times. Keep the season at 150 s but let the fast crops turn
   twice: Russet 60, Golden 90, Giant 110, Sunburst 160, Icecap 200. A
   bed that ripens in Spring can be replanted in Spring. Hoe on a
   harvested bed re-tills without waiting.

4. Guided first year. Time runs at 3× while a "wait" step is active
   (grow, and the run-up to the storm), back to 1× the moment a decision
   or a cause card is on screen. The scripted storm lands at second 40
   of Summer. Target: a new player reaches the first accounts in about
   four minutes. Reduce the scripted loss to one tonne of three.

5. Re-run the tuning bot after all of the above. The bot's strategies
   rent no fields (Home Field only) so the published survival numbers
   stay comparable; add a fifth strategy "expander" that rents the Low
   Field from year 2 and plants it with the same crop, and assert it
   survives at least 20 of 30 seeds and out-earns cautious in mean sales
   while never exceeding the cash ceiling. Adjust rents until it holds.

Tests: test_pace_and_land.gd covering pest windows, field exposure
multipliers, rent posting and cancellation, bed opening per field, cause
cards naming the field, and the guided-year timing.

Acceptance: pests appear mid-growth; three fields walkable and rentable;
guided year under five minutes; tuning bot green with the expander row
recorded in §6; suite green; web export runs.
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
- Fields (from Segment 17b): the Low Field reads wet and lush, the Hill
  Field pale and windswept, with a signpost naming each; rented fields
  show a fence line, unrented ones an overgrown "To let" board.
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
Goal: the new screens look designed and read at a glance. Reference: the
Duck patrol page (a picture of the thing, coloured blocks with one action
each, a status badge, no paragraph). Every page follows seven rules:

SHAPE      Each place is an object: chalkboard + seed packets (Mara),
           timber barn with crates (Nell), pegboard workbench (Bram),
           instrument panel (Iris), cork board with pinned notes (Tess),
           paper ledger (accounts), newspaper (front page).
ACCENT     One accent colour per place, on the header band and the
           primary button only; body stays cream. Crop ribbons use the
           crop's own colour.
EDGES      Paper 6 to 8 px rounded, buttons full pills, boards and
           instruments squarer. Mixed on purpose.
FACTS      Only what applies: no zero rows, no repeated boilerplate, no
           "—" placeholders. Big number, small label. Icons for thirst,
           heat, cold and weather events. Explanations behind a ? tooltip.
LINES      At most two facts joined by "·".
ENTRANCES  One way in per thing.
CHARACTERS The keeper's portrait small in a corner of their page.

Per page:
1. Seeds (Mara): chalkboard background; one seed PACKET per variety with
   a crop-coloured ribbon, illustration, price per seed large, season
   pips and tonnes, three icon dials, one volatility badge, what you
   own, Buy 1 / Buy 5 pills. Remove: grade thresholds, live /t and %,
   sparkline, "Last year avg", "Price swings" text, "In barn".
2. Sell (market): one row per variety: icon, name, price/t with a
   signed % chip, sparkline with the Winter dash, then grade chips ONLY
   for grades with stock ("Table 12 t", "Standard 4 t"); tapping a chip
   opens the amount stepper. The storage sentence becomes a ? tooltip,
   shown as one line only in Winter.
3. Tess's board: Tess is the quest keeper. The quest board on the map
   opens her cork board with two tabs, Quests and Losses; each item is a
   pinned note (event icon, tonnes, field, worth, one counterfactual
   line). Remove "Crop loss notices" from the weather station and from
   Tess's conversation. Fix the bug where the panel shows a loss and
   then "No crop losses recorded".
4. Weather station (Iris): instrument panel. Top: radar + the forecast
   bracket as one visual with the event names. Then three field chips
   with exposure icons. Then a 2×2 grid of protection tiles (icon, name,
   level pips, one-line effect with its %, one button). Then one
   insurance toggle row and a small station-upgrade line. Remove the
   damage-reduction table, the loss-notices button and "Cover all
   cleared beds" (that lives on the Winter jobs card).
5. Buyer board: the order is a paper slip pinned with a tack: crop icon,
   "20 t Russet", price, "due Autumn end", penalty small, Accept as a
   stamp button. The explanatory paragraph becomes a tooltip.
6. Front page: keep the layout; replace the ten "—" rows with a single
   ten-box strip with icons; legend behind a tooltip; add last year's
   net in a small Accounts box.
7. Barn (Nell): lighter timber frame, cream interior; ONE Sell button
   that opens the market (on stores in Winter); remove the second "Barn
   stores" button; items as a grid of crate tiles, not one wide card.
8. Workbench (Bram): pegboard; smaller tool tiles with level pips;
   "Garden beds" becomes "Open 12 more beds" with the field named;
   PotatoDex moves to the farm menu.
9. Annual accounts: a ledger page. Ruled lines, category rows with dot
   leaders, the net figure in the display font, a stamped year, the
   ten-year table as a small column, the climate strip beneath, cause
   notes as pinned slips. No HUD chrome behind it; a screenshot button.
10. Season strip: a small four-segment bar under the wordmark with the
    current season lit and the year number.
11. Winter jobs card: when Winter opens (after the accounts close), a
    pinned card under the season strip lists every Winter action that is
    actually available, with live numbers, one line each: iced beds to
    clear; stored tonnes with the current and late-Winter price; paid
    projects with work done of three; cleared beds that can take a frost
    cover; ripe Icecap; sacks that can be kept as seed; businesses on
    offer from year three; the blizzard warning when one is coming. Each
    line is a button that walks the farmer there or opens the right
    page. Lines tick off as they are done and the card collapses to
    "Winter · N jobs left" on request. Other seasons may show at most
    two lines (a contract due, a disaster warning), never a to-do list.
12. World signs: field boards show the field name only; exposure is an
    icon on the post. To Let boards show "TO LET" only. All Label3D text
    must fit its board: measure and shrink, never overflow.
13. Phone: packets become a horizontal swipe row; tiles a single column;
    44 px touch targets.

Copy sweep: remove leftover words from the old game (stock, boom,
islands other than Spud Valley, market-era quest names). Ledger labels
are frozen strings the save validator checks: never change them.

One page per commit, screenshot at desktop and phone width after each.
If a line does not change what the player does next, it goes.

Tests: update the HUD layout and responsive suites for the new pages at
the existing viewport set; add a Label3D fit check for every world sign.

Acceptance: every page screenshotted at both widths looks consistent and
follows the seven rules; suite green.
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
- Pace controls: "Sleep until Spring" button in Winter, on the jobs card
  and the farm menu; it resolves any active weather first, then jumps to
  the Spring boundary with the normal boundary save; stored sacks are
  not sold automatically, and a confirm line states the tonnes still in
  store and the price they would reach by late Winter. "Hold to hurry":
  holding H (desktop) or a touch button runs the simulation at 3× while
  held, in any season, never during the accounts, a conversation, a
  cause card or the tutorial's own waits; a small "3×" badge shows.
- Growth feel: a bed waiting for water shows a clear droplet marker at
  default zoom and the hover tag says "Needs water · growth paused"; dry
  beds grow at 40% speed instead of 0%. Guided-year wait speed is at most
  5×, and 1× from the storm warning through the cause card.
- Shadow cost on phones: the 4096 shadow map and soft filter are also set
  for mobile; measure on a real phone and drop to 2048 on web if frame
  time rises.

Tests: test_feel.gd for transition timing and audio presence; a
benchmark script that reports frame time in the browser fixture.

Acceptance: a full year played on a phone without a visible hitch; suite
green; web export runs.
```

### Segment 21: Balance and playthrough (after Segment 20)

```
Goal: tune what the bot cannot feel, then play it as a stranger.

Balance (bot-verified):
1. Low Field rent: raise it until the expander strategy's mean ending
   cash lands between cautious and tidy (about +100,000 scaled), not at
   tidy's shoulder. Keep expander survival at least 24 of 30.
2. Diversification: nudge shop income and lodging income until the
   diversifier's mean ending cash is clearly above cautious (at least
   +40,000 scaled) and still below tidy. The fork must be a real fork.
3. Only if play still drags after Segment 20's pace controls: cut grow
   times by a quarter (Russet 45, Golden 70, Giant 85, Sunburst 120,
   Icecap 150), re-run the bot, re-tune seed prices or fixed costs until
   survival numbers match, re-record the table.
4. Then shorten Winter to 100 s only if it still feels empty with the
   jobs card and Sleep until Spring in place.

Playthrough (human):
- On the web build on a phone, as a new player: tutorial, ten years,
  epilogue. Write down every moment of confusion or boredom with the
  season and screen it happened on. That list becomes the final fixes.
- Check the epilogue wait on a phone; if it exceeds 20 seconds, reduce
  the caretaker's per-year tick budget or show the ten-year ledger while
  it computes.

Release:
- Follow PUBLISHING.md; fresh web export into docs/; tag v2.0.0; README
  play link points at the new build; the old v1.0.3.1 build moves to a
  release asset only.
```

### Segment 21 follow-up: tag j fixes (run before Segment 22 step 0)

```
Goal: close what the tag j review found, so the three fresh testers in
Segment 22 step 0 trip only on things we do not already know about.

Suite:
1. tests/test_climate_operations.gd line 80 still asserts the retired
   rule that an unwatered seedling stays at stage 1. Under dry growth
   (DRY_GROWTH_SPEED 0.4) a dry seedling becomes stage 2 on its first
   update, so "hoe drains living flooded beds without destroying crop"
   fails at tag j although the hoe is correct (stress 0.47 to 0.0, crop
   kept). Assert the crop is alive (stage in [1, 2], crop unchanged)
   instead of stage == 1. Re-run the suite; DEVELOPMENT.md says 84
   suites pass, which is not true at tag j.
2. tests/test_harvest_identity.gd line 61 advances once by 1000 s and
   expects the guided storm to have landed. Since bce5f1d the calendar
   runs at 1x from the storm warning, so one advance stops at the
   warning and the next six checks cascade (storm-lost tonne, receipt,
   foley, grade cue). Advance until current_id() is "loss" (at most six
   calls); with that change all 22 checks pass at tag j. Both of these
   tests were not re-run after the last commits; run the full suite
   before tagging, not the focused ones.
3. tools/run_tests.sh only imports when .godot/imported is missing. A
   checkout that already has one never sees new assets, so the audio
   added in cb5c2bb makes almost every suite report ERRORS ("Cannot
   open file res://.godot/imported/farm-harvest.wav-...sample") on any
   stale clone. Import when any *.import file under assets/ is newer
   than .godot/imported, or always run the editor import step when
   --import is passed; document it in DEVELOPMENT.md.
4. Tuning bot at tag j, standalone: 1,679 checks, 0 failures. Expander
   survives 29 of 30 with max cash 215,971, inside the 320,000 ceiling;
   the earlier over-ceiling seed is resolved. Record that in
   DEVELOPMENT.md and drop the "left failing" note.

Copy:
5. main.gd shows "Needs water · growth paused" while a dry bed grows at
   40%. Say what is true: "Dry · growing slowly" (Segment 19: only
   applicable facts).

Stall:
6. Cold accounts boundary frame is 404 ms. Build the accounts panel
   during the last ten seconds of Autumn, off the boundary frame, or
   show "Opening the books…" and build it over the next frames. Measure
   again; the target is under 100 ms on the M4 baseline.

Before testers (from PLAYTEST_J.md, highest quit risk first):
7. The guide asks the player to buy seeds while twelve starter seeds
   are already in the pouch. Either start with none (the guide buys
   them) or have the guide say plant the starter seeds.
8. Starter beds die to Autumn Cold while the guide still locks the
   player out of harvesting. The guided year must never lose a bed the
   player could not act on: either the guide's lock lifts when a bed
   ripens, or the first Autumn Cold is delayed until the guided harvest
   is done.
9. "Calendar running…" dead wait and the ripe bed waiting through the
   guided storm: the guide hands control back the moment the thing it
   is waiting on arrives; no screen may show a wait with nothing to do.
10. Blocked-action text replaces the instruction. Keep the instruction on
   screen; show the blocked reason underneath it, not instead of it.
11. Seed shop tap target on a phone; the horizontal card scroll with no
    hint. Make the counter's tap area the whole stall and show the
    first card half cut off so the scroll is obvious.
12. "Skip" label says what it skips (the guided year, not the season).

Phone:
13. Awaiting owner measurement (owner override: no remote phone available).
    Default phones to 2048 now; keep 4096 as a Graphics choice. Debug's
    one-tap "Measure a year" records every frame until the next Winter
    accounts close, shows device/OS, actual shadow size, resolution, mean
    fps, 1% low fps, worst frame and its season, and copies the same text.
    No measurement enters the farm save. Export a branch-only Web test
    build outside docs/ and web/. DEVELOPMENT.md keeps the real-phone
    row open with exact local-serve and recording steps for the owner.

Done when: the full suite passes with no known failing check, the
guided year cannot lose a bed the player could not act on, and the
phone recorder and test build are ready for the owner's real-device
measurement. "Real-phone year measured" remains open until they paste
the card text into DEVELOPMENT.md.
```

### Segment 21c: Surfaces and voice (after Segment 21b, before Segment 22)

```
Goal: the interface stops looking white and generic. Testers in Segment
22 step 0 must meet the finished look, or their boredom notes will be
about paint instead of play.

Why: every surface is one of four creams (fffbed, fffdf4, f3efdf,
f9f7e9) tinted at most 7% toward an accent. One tone, used as base,
paper and highlight at once. The first screen is the same 752x634 modal
the accounts use, so the game opens on a settings dialog.

1. Title scene. Delete the "Welcome to Taterland" modal. Open on the
   farm at golden hour with a slow pan. The name sits on the gate sign
   as a world object, not a label. Two bottom buttons only: "Walk to
   the farm" and "Continue · Year N, Season" (the farm's own state). No
   box, no close button, no body text. The world keeps moving behind
   the buttons.
2. Three tones. Promote INK (17382d) to a surface colour for frames and
   the outer band of large panels; add one wood tone. Rule: never three
   cream surfaces stacked; the third must be wood or ink. Cream is the
   highlight, on about a third of the pixels, not the base.
3. Material. Give the shared panel style a subtle paper texture
   (StyleBoxTexture, 9-slice, a 64x64 grain) and a 1 px darker inner
   edge. One edit, every panel. No flat colour boxes larger than a
   button remain.
4. One drawing per thing. Every crop card, the barn, the forecast and
   the ledger get a small picture, so cards differ before they are
   read. Keeper portraits already exist; match their style.
5. Voice. Rewrite the twenty most-seen strings in Nell's or Tess's voice
   at half the length. Buttons get verbs that belong to the world
   ("Walk out to the field", not "Continue"). Ban the single card shape
   "title / line / line / button" for everything; at least three card
   shapes across the interface.
6. Motion from the source. A panel slides in from the building that
   was tapped and the farm stays live behind it. No panel appears from
   nowhere on a frozen backdrop.
7. Style board. Before touching code, pin ten screenshots of games with
   the wanted feel in docs/style-board/ and write three rules under
   them (wood, paper, dusk light). Check every screen against the board
   before tagging.

Keep Segment 19's rules: one shape per place, one accent per place,
only applicable facts. Ledger labels stay frozen. Never touch
docs/index.* or web/.

Done when: the title, accounts, crop card and forecast are
screenshotted before and after at 390x844, no screen shows three
stacked cream surfaces, and the full suite passes (tools/run_tests.sh,
plus test_epilogue and test_tuning_bot standalone). Tag
v2.0.0-underdevelopment-l and report what changed, with the
screenshots, and anything left undone with the reason.
```

The pinned [style board](style-board/README.md), [twenty voice edits](style-board/VOICE.md)
and [screen review](style-board/REVIEW.md) document this pass. Use the finished
tag-l build for the three new-player baseline reports in [PLAYTEST_22.md](PLAYTEST_22.md).
The preceding tag-k follow-up's real-phone measurement remains awaiting the owner.

Title refinement requested during this pass: start close to the gate and pull
back over eight seconds before the slow drift. Use a 15-degree warm sun, cool
fill, a peach dusk sky and calm water. Hide all world lettering except TATERLAND,
plus lease boards and crop markers, until entry. Make Walk to the farm the large
ink action and Continue the smaller text action, keeping phone-sized tap targets.
Restore the camera, sky, markers and saved farm's actual lighting on entry; the
title must not advance or save the farm.

### Segment 22: The fun pass (after Segment 21c)

```
Why: with Segments 1 to 21 done the game is honest, legible and simple,
and the owner's verdict is that it is boring. The plan under-invested in
the two things that make farming games fun minute to minute: chores that
feel good under pressure, and a farm that visibly grows. Honesty stays
in the ledger. It never required a farm that stays the same size.

Step 0, before any build: put the current build in front of three
people who have not seen it. Note the minute each would have quit and
on which screen. Use that to order the items below; the guess is that
the first ten minutes and the middle years matter most.

A. Rush. Working seasons 100 s. Grow times cut a quarter (Russet 45,
   Golden 70, Giant 85, Sunburst 120, Icecap 150). Home Field starts with
   all 24 beds open. The aim is to always have one more job than time.
   Re-run the tuning bot and re-tune fixed costs or prices to the
   recorded survival numbers.
B. Build. The island fills over ten years, each item visible on the map
   and a line on the ledger: a greenhouse (grows one variety through
   Winter, costs upkeep), a second barn (capacity and a safer store), an
   orchard (a small steady income with Autumn labour), a hired farmhand
   (Tess does one chore type for you each season for a wage). Unlock
   order by year; nothing multiplies prices.
C. Timed moments inside seasons, one or two per season, never more:
   - a buyer at the gate for 60 s offering a premium for what you hold
     now;
   - a storm warning that gives 45 s to pull ripe beds before it lands
     (already exists; make it louder and give sprint a reason);
   - pests that spread to neighbouring beds every 20 s if unsprayed;
   - a price rush: the market pays +20% for 30 s, announced by Mara.
D. Skill in the hands. A perfect-ripeness window (the first 10 s after
   ripe) that guarantees Table grade; hoeing adjacent beds in rhythm
   speeds up; the watering can covers a row when swept along a path.
   All visible, all learnable in the guided year.
E. Things going wrong, with a choice. Ten handwritten yearly incidents,
   one per year in Summer, each with two options and a ledger cost:
   the tractor is too big, the ducks got out, a TV crew wants to film,
   the well runs dry, a neighbour offers to buy the Low Field, and so
   on. This is where the humour lives. No incident repeats in a run.
F. The hook (kept from the earlier draft): a break-even target card
   every Spring with live progress; one dilemma per season said out
   loud; a comeback cap after a two-disaster year; Nell marks the first
   profitable year and the best year yet; the epilogue adds one
   sentence drawn from the run's largest avoidable loss; region choice
   at new run (Valley, Shores, Frosthollow) and one rare event per run.
G. Not allowed: login rewards, offline timers, anything bought with
   money, price multipliers that compound.

Tests: bot re-run per change in A; incidents never repeat and always
post to the ledger; timed moments at most two per season; the perfect
window grants Table exactly; region curves differ; target card
arithmetic matches the ledger.

Acceptance: the three testers from step 0 play again and each wants a
second run without being asked. If not, repeat step 0 and this segment.
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
