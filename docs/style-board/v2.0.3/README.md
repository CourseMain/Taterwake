# Local v2.0.3 · sun and icons review

Segment 21g adds a visible moving sun, stronger directional shade, reflective water and steel, illustrated controls and the filled Spudion. The cream UI, potato farmer and villagers remain. NPC-first service entry and the owner's Hurry removal are retained. Publishing is paused.

These are Godot 4.7.2 GL Compatibility Web captures in Chromium at **1440×900** and **390×844 CSS pixels**, DPR 1. The disposable surfaces fixture freezes crop/calendar simulation for repeatable views while world and UI animation continue. It supplies 24 planted Home beds and an example Year 3 ledger; it does not access a player's save. Browser emulation does not establish physical-device performance.

| Play view | Desktop | Phone |
| --- | --- | --- |
| Spring noon | [1440×900](spring-1440.png) | [390×844](spring-390.png) |
| Summer noon | [1440×900](summer-1440.png) | [390×844](summer-390.png) |
| Autumn dusk | [1440×900](autumn-1440.png) | [390×844](autumn-390.png) |

Each frame shows the soft sun disc and halo, directional shadows, Weather and Menu drawings above their captions, fullscreen in the top-left corner, and a solid gold potato before the red negative balance. Spring's three rows use the same filled money glyph. Roofs, rails, mill sails and sign posts show distinct lit and shaded faces; Autumn's lower warm light produces longer shadows. The sea and tank catch highlights from the same sun direction.

An additional [640×360 Winter check](winter-640.png) shows the illustrated first job fully visible between its header and Sleep footer, beside Weather and clear of Sell and the movement controls.

The Web test also samples paired lit/shaded pixels on one temporary test surface. Only the shadow-casting post changes; the terrain material, camera and sampled point stay identical. No test geometry appears in the six play screenshots.

| Material / moment | Shade as a percentage of lit brightness, at both sizes |
| --- | --- |
| Spring noon ground | 59.9% |
| Summer noon ground | 59.9% |
| Autumn dusk ground | 65.9% |
| Winter noon snow | 68.6% |

The six captures and eight shade pairs pass with no browser errors. Reproduce with `tools/export_browser_benchmark.py --fixture surfaces --label v203-sun --godot PATH`, serve `artifacts/browser-benchmark-v203-sun-web`, then run `tests/capture_sun_icons_browser.cjs URL artifacts/v2.0.3-sun-review` with Playwright available through `NODE_PATH`. The structured report is `artifacts/v2.0.3-sun-review/report.json`.

The five-layout browser interaction check covers keeper entry, seed-shop entry, fullscreen, tool selection, movement and rotation. The title regression repeats three fresh launches at each requested size, including an immediate Walk, a delayed Walk and a resize before Walk. Separate uninstrumented production checks cover both sizes and farmer Skip. Final suite and boot results are recorded in [DEVELOPMENT.md](../../DEVELOPMENT.md).

Tester 1's supplied sheet remains in [PLAYTEST_22.md](../../PLAYTEST_22.md). Three later human reports are still pending. Segment 22 has not started. The public build and `web/` source are unchanged.
