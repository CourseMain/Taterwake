# Segment 22 V1 · v2.1.0 review

Fennick's Pedlar cart, three exact Spring packs, their reveal, the collection and Blue Pearl are implemented. The updated plan branch was merged into `redesign` first. The owner's rename, hook overflow, tuning gates and starter gifts are recorded verbatim in [DEVELOPMENT.md](../../DEVELOPMENT.md) and the V1 notes. Only V1 is included; the public docs-root build remains v2.0.5.

## What changed

- First Spring: an untappable twenty-second passing cart, one bell and Fennick's wave. From second Spring: a parked cart beside the gate, greeting first, one tap into the service, departure at the season change.
- One copper-tinted page contains three face-down packs with their exact prices and odds. Purchases use cash only. A refused pack shakes beneath the unchanged instruction. The card rises and flips through a 0.70-second drumroll; the two-note cue follows, then the contents land at 1.12 seconds with a stamp and rarity edge. Rare results briefly flame. Bought slots remain Sold and unbought backs remain on the cart.
- Superstitions fill five gate hooks; further wins enter the Superstitions tab as “Not hung yet”. Full hooks never refuse a pack. Owning every card in the rolled rarity returns exactly 2,000. All superstitions stay inert until J; hanging and swapping are absent.
- Fresh farms and old saves receive Second Sowing on hook one and a Standard Russet Twin once, without purchase entries or new guide cards. The first second-Spring greeting mentions the endowed hook once. Owned collection cards show their drawings, quiet rarity edges and effect; unknowns stay silhouettes without revealed names.
- Blue Pearl uses the exact new balance.gd values, validates and grows Spring–Autumn. Mara never sells it; a price row appears only after it is held. Pack oddities sell for grade price plus 500, using existing sale labels and the existing Undo.
- “Pedlar's pack” and “Pedlar's refund” are the only added ledger labels. The natural climate curve begins in year three; year one's guided storm remains. Farm name is saved with the appearance and appears on the gate and epilogue.

## Browser captures

All captures are unedited Chrome Web-export fixture images at **390×844**. The fixture uses actual cart geometry and model purchases, pauses deterministic card phases, and does not open normal player saves.

| View | Screenshot |
| --- | --- |
| Passing cart · Spring, Year 1 | [passing-390.png](passing-390.png) |
| Parked cart · Spring, Year 2 | [parked-390.png](parked-390.png) |
| Fennick's three packs | [page-390.png](page-390.png) |
| Pack backs and printed fractions | [odds-390.png](odds-390.png) |
| Flip during wind-up | [windup-390.png](windup-390.png) |
| Landed result | [result-390.png](result-390.png) |
| Named gate and filled hooks | [gate-390.png](gate-390.png) |
| Collection and “Not hung yet” | [collection-390.png](collection-390.png) |
| Farmer and farm-name line | [farmer-390.png](farmer-390.png) |
| Refused purchase | [refused-390.png](refused-390.png) |
| Held Blue Pearl price row | [blue_sell-390.png](blue_sell-390.png) |

The [browser report](browser-report.json) confirms year-one interaction layer zero, year-two interaction layer one, hidden contents during wind-up, result visibility after landing, and Second Sowing on hook one. All eleven views have no browser/script errors. Minimum page label size is **14.3 rendered pixels**. No desktop captures are requested by V1.

## Validation

The final **tools/run_tests.sh -j 2** run passes **109 / 109 suites**, **27,820 reported checks**, with **0 failures, timeouts or errors**. It includes standalone epilogue **537 checks**, farm audio **145**, season clock **127**, and tuning bot **2,266**. The separate required epilogue rerun also passes **537 checks**; the additional tuning-bot rerun also passes **2,266 checks**. Both are recorded in [standalone results](standalone-results.json). The [full suite results](full-suite.json) retain every suite summary; the [bot output](tuning-bot.log) records the table and deferred-gate lines. The new Pedlar suite passes **932 checks**, including 10,000 fixed-seed rolls per pack, exact refunds, cash-only purchases, persistence, starter gifts, held Blue Pearl, quiet collection cards and exact oddity Undo. No test was skipped, disabled or deleted to obtain green results.

The 390×844 Web fixture passes **39 real button taps**, **0 failures or browser errors**, across the three packs and refusals, collection tabs, farmer controls, Fennick's greeting and the five tool tiles. Slowest visible feedback is **66.90 ms** (limit 100); sound is **18.00 ms** (limit 300). The analyser observes the complete Web Audio mix after engine initialization; transparent pack targets are measured by their drawing, including refusal rotation. See [latency results](latency.json) and [the browser run](latency.log). The merged working copy also imports and boots in integration-test mode without script errors; local owner edits remain uncommitted and preserved.

## v2.1.0 table

Fixed seeds 1–30; survived, median end year, mean end cash, maximum end cash and mean sales. The endowed Twin is excluded from simulation stock and never sold; honest policies retain their prior decisions. The survival baselines remain v2.0.6's 0/30/30/28/29.

| Strategy | Survived | Median year | Mean cash | Max cash | Mean sales |
| --- | --- | --- | --- | --- | --- |
| naive | 0/30 | 5.0 | −245,254.65 | −204,288.99 | 483,638.69 |
| cautious | 30/30 | 10.0 | 60.75 | 95,596.63 | 1,402,986.83 |
| tidy | 30/30 | 10.0 | 293,755.95 | 350,722.25 | 1,785,475.63 |
| diversifier | 30/30 | 10.0 | 82,793.67 | 183,550.81 | 1,369,195.49 |
| expander | 30/30 | 10.0 | 152,848.09 | 260,278.61 | 2,136,596.57 |
| gambler | 30/30 | 10.0 | −33,917.73 | 7,696.63 | 1,385,359.37 |

Gambler: **min −79,688.57 / mean −33,917.73 / max 7,696.63**; above tidy's mean **0/30 (gate lands in part J)**; foreclosed **0/30 (gate lands in part J)**. Its mean and survival satisfy the owner's V1 gates; no seed exceeds 640,000. The three-seed upside/foreclosure gates resume in J and are rechecked at V2 and V4. The gambler plants won ordinary seeds (Russet, Giant, Golden, Sunburst, Icecap) in free beds, sells won oddities with ordinary stock, and never plants Blue Pearl. Tidy's sales advantage is **27.26%**; mean **293,755.95** is below the unchanged 320,000 gate.

## Left undone

The non-gamer five-second review was not performed. The owner said “nah just do it” and authorized finishing without waiting; [PLAYTEST_22.md](../../PLAYTEST_22.md) records the unperformed check without claiming a human pass. The three full fresh-player sessions remain scheduled after V3. All requested V1 implementation is complete; later parts and public docs-root publication are outside this release.
