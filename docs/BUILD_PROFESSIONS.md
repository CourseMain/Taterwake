# Build activities, visiting taxes and open sea

This is a local, unpublished source update. The large-number economy, island progression, existing equipment and climate rules remain in place. Each build now gives the player a different action that produces those numbers. Open Builds with **C**, or click its equipment in the world. The overview is five short cards; each detail page has an animated three-picture explanation, three benefits and its controls. Exact passive bonuses are expandable.

## Try it without touching your farm

Double-click **Play Builds Lab.command** on macOS. Keep its terminal open. It exports a separate test-mode project and opens `http://127.0.0.1:8110/index.html`. No player save is loaded or written. Reload to start again. The test farm supplies crops, coins and level-20 builds; these are test resources, not changes to normal progression.

Expand **Builds & sea lab · scenarios**:

1. **Try Farmer:** choose a prize bed, click a growing crop, then water and harvest normally. A single large potato grows inside that bed. Escape or selecting another tool cancels targeting.
2. **Try Industrialist:** choose a crop and a matching process, load a batch, and sell the finished shipment. **Prepare an SSS batch** supplies the necessary freshness and discoveries; load it within 45 seconds. Close the page to see the machine's grade stamp and brief gold celebration. Try queueing three batches and switching builds while they run.
3. **Try Scientist:** crossbreed Honeyheart, then select it in the seed bank. Switch to Farmer, plant an ordinary seed and see its inherited golden trait. Try Sundew on Island 2 and Frostgold on Island 3.
4. **Try Investor:** reserve a buyer and load the shipment. The price remains the reserved quote even if the market changes. Close the page to watch the cargo cart follow the path to the ferry.
5. **Try Gambler:** select the crop and stake size, read the odds, then stake. The illustration shows the actual result. Claim once, or spend the charm to replace it; replacement can be worse. Other held crops are untouched.
6. **Send tax collector:** watch the visitor arrive from the pier, collect after ten seconds, show the receipt and leave. No extra click is needed to pay.
7. **Island 1 / 2 / 3:** inspect the continuous animated ocean at different zoom levels. Frosthollow retains icy blue water and ice floes. **Mature field** supplies a heavier rendering scene. Choose Balanced or Smooth, then **Measure 8 seconds** to show FPS, median and p95 frame times.

**Play Climate Lab.command** remains separate, on port 8093, for the tank/can/sprinkler practice and drought, flood and storm scenarios. Normal farming can be tested with **Play Taterland.command** or the rebuilt `dist/web/` export; those normal launchers use the normal save.

## Activity rules and tradeoffs

| Build | Player action | Persistent result |
| --- | --- | --- |
| Farmer | Spend one compost on a growing bed; starts with three | Triple that bed's ordinary yield. Each first harvest makes one compost, capped at 99. |
| Industrialist | Load 20 or 100 crops; Polish fits Golden/Icecap/Radioactive, Cure fits Russet/Giant/Sunburst | Locked batch grade; one queue slot initially, two at level 10, three at level 20. Finished goods wait for sale. |
| Scientist | Spend ten of each parent crop once per recipe | Honeyheart (Russet + Golden): more yield; Sundew (Giant + Sunburst): drought tolerance; Frostgold (Golden + Icecap): ordinary frost protection. |
| Investor | Reserve a quote for 180 seconds and deliver from the same island | A shipment receipt, cargo animation and buyer reputation. An expired offer consumes no crops. |
| Gambler | Stake 5, 20 or 100 ordinary held crops | One locked-price result: 20% pays 3×, 55% pays 1×, 25% pays half. One charm recharges in 180 seconds; tables recover in 30 seconds. |

Industrialist grades use visible, deterministic causes: freshness contributes two points, matching process two, machine level zero to three, and two seed discoveries contribute one at machine level 20. Scores 0–8 produce F, E, D, C, B, A, S, SS, SSS. Shipment multipliers are 1.05, 1.10, 1.20, 1.35, 1.60, 2, 2.8, 4.5 and 8. A harvest has a 45-second freshness bonus; ordinary stored crops do not lose their base value. A fresh count is consumed when loaded. SSS is a prepared endgame outcome, not an additional random roll. Market prices still change until graded goods are sold.

Honeyheart yields 50% more; Sundew halves drought stress; Frostgold avoids the existing winter frost selection (it does not prevent every climate disaster). Traits stay selected until changed and apply to future plantings with any profession. They still consume normal seeds. Their colours and seed-bank jars make discoveries visible.

Investor shipments start at 20 crops and become 100 at level 10. The initial quote includes a 20% premium, rising three percentage points per delivery for the first ten deliveries. A contract locks crop, quantity, price, expiry and island. Gambler stakes lock the selected market quote when placed. No animation grants money: the simulation commits each transaction once, then the world displays it.

This first version keeps the saved bed grid intact instead of merging four beds, and uses short deterministic recipes rather than a breeding minigame. Switching stays free and finished work remains claimable. Existing passive progression is preserved except Gambler's additional mutation chance and Industrialist's old flat sale bonus: these become an explicit sale stake and a readable batch grade respectively. Build-caused disasters, harvest-chain gestures and heat management are not included in this slice. Current climate consequences continue normally.

## Rendering and saves

The sea is one opaque, low-poly mesh covering the camera's full zoom range. A single unshaded shader draws curved ribbons, broken wave crests and near-shore foam. It does not use screen/depth textures, transparency, reflections or physics. Existing Arctic ice meshes remain batched. World props are created and batched once; celebrations reuse ten small gems and a label. Build illustrations use vector drawing at 20 updates per second only while visible.

Local Safari measurements on this Apple M4 Mac (eight-second samples after warm-up):

| Scene | Quality / 3D resolution | Average FPS | Median / p95 frame time |
| --- | --- | --- | --- |
| Valley, supplied growing/ripe field | Balanced / 1919 × 1200 | 59.9 | 16.7 / 16.7 ms |
| Arctic, 80 mature beds | Smooth / 1599 × 1000 | 60.0 | 16.7 / 16.7 ms |
| Arctic, 80 mature beds | Balanced / 1919 × 1200 | 59.3 | 16.7 / 18.1 ms |

These are short local measurements, not a promise for every Safari device. An earlier sample during concurrent test activity averaged about 50 FPS. The lab includes the same measurement controls so performance can be checked on other hardware. Loading, processing and selling an SSS batch were also exercised through the Safari canvas.

Build save schema 2 accepts schema 1, retaining levels, crates, legacy research, running production and processed inventory. New profession data is validated before it is loaded. Plot traits and prize flags travel with each island's saved fields. New data gets safe defaults in old farms. The main save filename and native application-data location are unchanged. Tax collection still uses the existing simulation and amount; the visitor is a presentation of that event.

## Automated verification

Use Godot 4.7.2 with the Compatibility renderer:

```sh
godot --headless --path . --script tests/test_build_professions.gd
godot --headless --path . --script tests/test_build_professions_game.gd -- --integration-test
godot --headless --path . --script tests/test_builds.gd
godot --headless --path . --script tests/test_climate_projects.gd -- --integration-test
```

The state checks cover queue conservation, coarse time steps, exact payouts, price locks, stake escrow, save round trips, legacy migration, all nine attainable grades, full-farm trait persistence and actual drought/frost behaviour. The scene checks exercise clicks held across HUD refreshes, prize targeting/cancellation and visitor arrival/collection/departure. Run the scene test without `--headless`, adding `--capture`, for screenshots in `artifacts/profession-*.png`.

Additional regression suites cover the water loop, climate operations, winter, tax cycles, ordinary farm interactions, ferry access, responsive layout and optional help. The export tools fail on Godot parse/compile errors. Public GitHub Pages files are not replaced by these local exports.
