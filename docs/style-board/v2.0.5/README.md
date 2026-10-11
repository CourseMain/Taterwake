# Segment 21i · v2.0.5 review

The current A/B/D/E/F work and its captures are recorded in [the 11 October review](RELEASE.md). The material below is the earlier review against the superseded plan.

Godot 4.7.2 stable, GL Compatibility, Chromium with Metal ANGLE. Phone captures are **390×844 CSS pixels**; desktop captures are **1440×900**. These are browser fixtures, not a physical phone. PNGs are unedited captures.

A, B, D, E and F are implemented, in order, with the owner’s closed-C greeting rule. Mara retains Buy/Sell tabs. The public v2.0.4 game is unchanged; this segment does not authorize publication. The v2.0.5 tag awaits the colour decision below.

## Captures

| Surface | Phone · 390×844 | Desktop · 1440×900 |
| --- | --- | --- |
| Fresh · first frame after farmer card | [View](farm-390.png) | [View](farm-1440.png) |
| Continue · guided farm | [View](returning-farm-390.png) | [View](returning-farm-1440.png) |
| Continue · complete guide | [View](returning-overview-390.png) | [View](returning-overview-1440.png) |
| Station · noon | [View](station_noon-390.png) | [View](station_noon-1440.png) |
| Station · dusk | [View](station_dusk-390.png) | [View](station_dusk-1440.png) |
| Tools shed | [View](tools-390.png) | [View](tools-1440.png) |
| Decorations · first tiles | [View](decorations-390.png) | [View](decorations-1440.png) |
| Decorations · last tiles | [View](decorations-end-390.png) | [View](decorations-end-1440.png) |
| Grades | [View](grades-390.png) | [View](grades-1440.png) |
| Accounts | [View](accounts-390.png) | [View](accounts-1440.png) |
| Mara’s seeds | [View](market-390.png) | [View](market-1440.png) |
| Winter HUD | [View](play_winter-390.png) | [View](play_winter-1440.png) |
| Spring · noon | [View](play_spring-390.png) | [View](play_spring-1440.png) |
| Summer · noon | [View](play_summer-390.png) | [View](play_summer-1440.png) |
| Autumn · dusk | [View](play_autumn-390.png) | [View](play_autumn-1440.png) |
| First guide | [View](guide_welcome-390.png) | [View](guide_welcome-1440.png) |

Fresh and Continue are observed on their **first rendered play frame**, with production startup and persistence. The fixture holds that framing for the capture. Home and the gate occupy **92.6% of portrait width** during the guide. After the guide, island width is **100%**, its vertical centre is **49.5%**, and the depth slice clips no island geometry. The [entry report](entry-report.json) includes three fresh launches at each of 390×844, 1440×900 and 2888×1804, plus guided and complete-guide Continue at each size: **15 cases, no browser errors**.

The [surface report](surface-report.json) verifies phone card bounds, one row of three drawn account tiles, content-fitted grades, singular seed season text, 14 px traits and hidden guide icons. Final Accounts and decoration captures replace their earlier captures after the whole-word and wood-selector fixes. Noon and dusk use the ordinary play-camera angle, centred on the station for inspection. The sun retains 21g’s seasonal elevations; only Spring/Summer haze density is halved.

## Pack and first load

| Measurement | Before audio conversion | After audio conversion |
| --- | ---: | ---: |
| Production pack | 15,853,772 bytes | 5,370,180 bytes |
| Median phone first load, three runs | 47.751 s | 39.467 s |
| Engine WASM | 39,514,754 bytes | 39,514,754 bytes |

The [before](first-load-before.json) and [after](first-load-after.json) reports use an uncached phone browser, blocked service workers, **10 Mbps and 40 ms latency**. The reduction is **8.283 s / 17.35%**. All seven converted files identify nominal **96 kbps Vorbis**; short cues remain WAV. The final local v2.0.5 pack, including the visual follow-up, is **5,372,340 bytes**, below the **6,000,000-byte** target.

## Owner decision still required

The [fixed kit](../ui-kit.html) gives Oda **iron #6b6b70**, while the session rule rejects grey and requires one colour per keeper. Tools currently retains the kit’s iron header; the new Decorations header uses timber. This mismatch is **not accepted as done**. The owner must choose either an explicit iron exception or timber **#79553d** for both headers. The question is pending; no answer has been inferred and no v2.0.5 tag is created before it is resolved.

Other observed style issues are preserved: the existing interaction **E** badge is pure white, guide body copy still uses Slackey, and the retained **Go to the barn** control has no drawing (as in the fixed kit). The segment does not name the first two changes and explicitly keeps the barn control. These need a later owner instruction; they have not been changed. `docs/index.*`, `docs/classic/` and `web/` are unchanged. The owner’s pre-existing local shadow-setting edits and generated classic import files are preserved.

## Validation

On final runtime `7e636f9`, Godot **4.7.2 stable**, GL Compatibility, `tools/run_tests.sh -j 2` passes **103 / 103 suites**, with **23,700 reported checks**, **0 failures, 0 timeouts and 0 errors**. The [full-suite results](full-suite-results.json) retain each suite's result. This includes the **44-check** boot, **534-check** epilogue and unchanged **1,679-check** tuning bot. All tests remain enabled.

The entry browser test passes **15 cases** and the surface browser checks pass **26 captures**, with **0 browser errors**. The affected final tile recapture passes at both sizes. The full suite was rerun after those final changes.

The additionally requested standalone run, `tools/run_tests.sh -j 1 test_epilogue test_tuning_bot`, passes **2 / 2 suites**: epilogue **534 checks** and tuning bot **1,679 checks**, with **0 failures, 0 timeouts and 0 errors**. All five strategy JSON records are identical to the full run. The [standalone results](standalone-results.json) retain the outcome. Stable local logs are `artifacts/v2.0.5-standalone/` and `artifacts/v2.0.5-standalone.log`. Validation completed **2026-10-07**.
