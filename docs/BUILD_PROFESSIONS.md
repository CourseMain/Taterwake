# Build activities, visiting taxes and open sea

Released in v1.0.2. Open Builds with **C**, or click its equipment in the world. Each of the five detail pages connects the required resources, a short illustrated explanation, the action and its result. Buttons use the simulation's readiness rules and explain missing crops, compost, equipment or waiting time. Exact passive bonuses remain expandable. Switching builds is free; discoveries, growing giant potatoes, loaded jobs and pending payouts stay with the farm.

## Try it without touching your farm

Double-click **Play Builds Lab.command** on macOS. Keep its terminal open. It exports a separate test-mode project and opens `http://127.0.0.1:8110/index.html`. No player save is loaded or written. Reload to start again. The test farm supplies crops, coins and level-20 builds; these are test resources, not changes to normal progression.

Expand **Builds & sea lab · scenarios**:

1. **Try Farmer:** click **Grow a giant potato · 1 compost**, then a highlighted planted, still-growing crop patch. The lab supplies growing crops for this test. One compost changes that patch into a giant potato with **3× harvest**; water and harvest normally. Empty, ripe, frozen and already-enlarged crops cannot spend compost. Escape or selecting another tool cancels targeting. If there is no eligible crop, the page explains how to prepare one.
2. **Try Industrialist:** choose a crop and a matching process, load a batch, and sell the finished shipment. **Prepare an SSS batch** supplies the necessary freshness and discoveries; load it within 45 seconds. Close the page to see the machine's grade stamp and brief gold celebration. Try queueing three batches and switching builds while they run.
3. **Try Scientist:** crossbreed Honeyheart, then select it in the seed bank. Switch to Farmer, plant an ordinary seed and see its inherited golden trait. Try Sundew on Island 2 and Frostgold on Island 3.
4. **Try Investor:** check the crop, quantity and total price, reserve a buyer, then click **Deliver crops** when the required stock is in the barn. The price stays locked if the market changes. Delivery must happen on the island where the buyer was reserved; the page names that island if you travel away. Close the page to watch the cargo cart follow the path to the ferry.
5. **Try Gambler:** select the crop and stake size, read the odds, then stake. The illustration shows the committed result. Claim it, or spend one charm for **one replacement per wager**; replacement can be worse. Waiting for another charm or reloading cannot grant a second replacement on that wager. Other held crops are untouched.
6. **Send tax collector:** watch the visitor arrive from the pier, collect after ten seconds, show the receipt and leave. No extra click is needed to pay.
7. **Island 1 / 2 / 3:** inspect the continuous animated ocean at different zoom levels. Frosthollow retains icy blue water and ice floes. **Mature field** supplies a heavier rendering scene. Choose Balanced or Smooth, then **Measure 8 seconds** to show FPS, median and p95 frame times.

**Play Climate Lab.command** remains separate, on port 8093, for the tank/can/sprinkler practice and drought, flood and storm scenarios. Normal farming can be tested with **Play Taterland.command** or the rebuilt `dist/web/` export; those normal launchers use the normal save.

## Activity rules and tradeoffs

Builds earn activity XP as well as levels from crates. Open **Builds [C]**
to see the level, XP bar and next target. Level 1 needs 40 XP; each following
level needs 10 more XP, up to the level-30 cap. Crates still unlock builds or
add one level; they preserve earned XP unless that level reaches the cap.

| Build | XP earned |
| --- | --- |
| Farmer | 4 per successfully harvested patch while equipped. A partial harvest counts once. |
| Industrialist | 1 per surviving crop in a finished batch; loading or selling adds none. |
| Scientist | 80 per new variety discovered, then 4 per patch of a discovered variety harvested while equipped. |
| Investor | 2 per crop in a completed reserved-price shipment; expired offers give none. |
| Gambler | 20 per claimed harvest stake, regardless of stake size or outcome. Rerolls add none. |

Committed batches, shipments and stakes credit their owning build even after
switching. Failed actions, full-barn clicks and repeated claims award no XP.
Build Crates have an independent 10% chance on each paid Roll House roll;
free Crown bonus rewards add no crate attempt.

| Build | Player action | Persistent result |
| --- | --- | --- |
| Farmer | Spend **1 compost** on one planted, still-growing crop; starts with three compost | That patch grows a giant potato with **3× ordinary harvest**. Each crop patch's first successful harvest earns one compost, capped at 99. Partial follow-up harvests earn no extra compost. |
| Industrialist | Load 20 or 100 crops; Polish fits Golden/Icecap/Radioactive, Cure fits Russet/Giant/Sunburst | Grade locks when loaded. Capacity is one running batch initially, two total jobs at level 10 and three at level 20, including queued jobs. Finished goods wait for sale. |
| Scientist | Spend **10 + 10 harvested parent crops**, once per recipe | Honeyheart (Russet + Golden), Sundew (Giant + Sunburst) and Frostgold (Golden + Icecap) become permanent planting traits. Select a discovered trait, then plant normal seeds with any build. |
| Investor | Reserve a quote for 180 seconds and deliver from the same island | A shipment receipt, cargo animation and buyer reputation. An expired offer consumes no crops. |
| Gambler | Stake 5, 20 or 100 ordinary held crops | One locked-price result: 20% pays 3×, 55% pays 1×, 25% pays half. A charm permits one reroll per wager and recharges in 180 seconds; tables recover in 30 seconds. Claiming pays once. |

Industrialist grades use visible, deterministic causes: enough fresh crops for the entire chosen batch contributes two points, a matching process two, machine level zero to three, and two seed discoveries contribute one at machine level 20. Scores 0–8 produce F, E, D, C, B, A, S, SS, SSS. Shipment multipliers are 1.05, 1.10, 1.20, 1.35, 1.60, 2, 2.8, 4.5 and 8. The page separates the next batch's preview from already-loaded work; changing the crop or process cannot change a job's locked grade. SSS is a prepared endgame outcome. Market prices still change until graded goods are sold.

Freshness lasts up to 45 seconds from harvest and is tracked independently for each crop and harvest group. Harvesting one new potato cannot make an old batch fresh again. Selling, crossbreeding, staking, delivering or loading crops consumes their tracked freshness; losses remove it too. These transactions use fresh stock first so sold potatoes cannot improve the grade of older stock left behind. Expired freshness never removes crops or reduces their ordinary base value. For bounded bookkeeping, harvests less than one second apart share the older expiry time, with at most 288 saved groups.

Running and queued batches still occupy barn space and suffer normal barn disaster losses. A damaged batch keeps its locked grade and finishes only the surviving quantity. Switching builds neither cancels production nor sells goods automatically.

Honeyheart yields 50% more; Sundew halves drought stress; Frostgold avoids the existing winter frost selection (it does not prevent every climate disaster). Traits stay selected until changed and apply to future plantings with any profession. They still consume normal seeds. Their colours and seed-bank jars make discoveries visible.

Investor shipments start at 20 crops and become 100 at level 10. The initial quote includes a 20% premium, rising three percentage points per delivery for the first ten deliveries. A contract locks crop, quantity, price, expiry and island. Gambler stakes lock the selected market quote when placed. No animation grants money: the simulation commits each transaction once, then the world displays it.

Giant potatoes occupy the existing crop patch, preserving field layouts and saves. Breeding uses short deterministic recipes. Existing passive progression is preserved except Gambler's additional mutation chance and Industrialist's old flat sale bonus, which became an explicit harvest stake and a readable batch grade. Current climate consequences continue normally.

## Rendering and saves

The sea is one opaque, low-poly mesh covering the camera's full zoom range. A single unshaded shader draws curved ribbons, broken wave crests and near-shore foam. It does not use screen/depth textures, transparency, reflections or physics. Existing Arctic ice meshes remain batched. World props are created and batched once; celebrations reuse ten small gems and a label. Build illustrations use vector drawing at 20 updates per second only while visible.

Prior local Safari measurements on this Apple M4 Mac (eight-second samples after warm-up; rerun the lab to measure the latest changes):

| Scene | Quality / 3D resolution | Average FPS | Median / p95 frame time |
| --- | --- | --- | --- |
| Valley, supplied growing/ripe field | Balanced / 1919 × 1200 | 59.9 | 16.7 / 16.7 ms |
| Arctic, 80 mature beds | Smooth / 1599 × 1000 | 60.0 | 16.7 / 16.7 ms |
| Arctic, 80 mature beds | Balanced / 1919 × 1200 | 59.3 | 16.7 / 18.1 ms |

These are short local measurements, not a promise for every Safari device. An earlier sample during concurrent test activity averaged about 50 FPS. The lab includes the same measurement controls so performance can be checked on other hardware. Loading, processing and selling an SSS batch were also exercised through the Safari canvas.

Build save schema **4** stores XP for each profession and accepts schemas **1, 2 and 3**. Older farms retain their levels and start with zero XP toward their next level. Levels, crates, research, discoveries, contracts, committed wagers, running production and processed inventory remain intact. Schema 1 receives safe profession defaults; legacy jobs without a letter grade keep their original multiplier through resaving and completion. Schema 2's old freshness marker becomes one timed group, capped to the actual raw crop stock in the barn. Existing timers continue from their saved values. Pending wagers receive a saved reroll flag; an already-spent charm is treated as used for that wager.

Schema 3 saves each crop's timed freshness groups and the per-wager reroll flag. Validation accepts legitimate partially damaged production batches and rejects malformed data before mutating the farm. Growing giant-potato flags and inherited traits stay with each island's fields. The main save filename and native application-data location are unchanged. Tax collection still uses the existing simulation and amount; the visitor presents that event.

## Automated verification

Use Godot 4.7.2 with the Compatibility renderer:

```sh
godot --headless --path . --script tests/test_build_professions.gd
godot --headless --path . --script tests/test_build_transactions.gd
godot --headless --path . --script tests/test_build_professions_game.gd -- --integration-test
godot --headless --path . --script tests/test_profession_clarity_ui.gd -- --integration-test
godot --headless --path . --script tests/test_builds.gd
godot --headless --path . --script tests/test_climate_projects.gd -- --integration-test
```

The state pass completed **92 transaction checks, 28 profession checks and 35 build ownership checks**, with no failures. Coverage includes invalid Farmer targets, partial giant harvests, compost earned once, all three recipes, independent freshness expiry and consumption, bounded rapid-harvest bookkeeping, every queue size, switching with work in progress, exact payouts, contract expiry and delivery islands, all stake sizes, one reroll across recharge and reload, atomic rejection of corrupt saves, schema 1/2 migration and ordinary build unlocks. A real flood damages active and queued batches; their surviving quantities are saved, reloaded and finished. Additional checks cover all nine attainable grades and actual drought/frost traits.

Scene checks exercise held clicks across HUD refreshes, giant-potato targeting/cancellation, disabled-action explanations, layout and visitor arrival/collection/departure. Run the profession game scene test without `--headless`, adding `--capture`, for screenshots in `artifacts/profession-*.png`.

Additional regression suites cover the water loop, climate operations, winter, tax cycles, ordinary farm interactions, ferry access, responsive layout and optional help. The export tools fail on Godot parse/compile errors. Public GitHub Pages files are not replaced by these local exports.
