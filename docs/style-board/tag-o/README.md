# Segment 21e phone review

Godot 4.7.2 Compatibility, disposable browser fixture, 390×844 CSS pixels,
DPR 1. Screens are captured from the running exported game; no player save
is read or written. This verifies phone layout, not phone hardware performance.

| Screen | Review |
| --- | --- |
| [Harvest pop](harvest.png) | Gold Table stamp on paper, 16 px rendered type; it holds 1.2 s after popping and fades. The canvas ignores taps. |
| [Barn chips](barn.png) | Table gold, Standard ink, Feed brown. 22 logical pixels render at 14.3 px on this viewport. |
| [Sell rows](sell_potatoes.png) | Same three inks and paper chips; grades sit below the price and chart. |
| [Spring estimate](spring_target.png) | Bills, two-sowing estimate and shortfall, with assumptions stated below. |
| [Year 1 accounts](year1_accounts.png) | Nell’s full arithmetic and all three tappable directions appear before the ledger rows; land costs have one line. |
| [Winter card](winter_jobs.png) | Work count excludes crop prices and seed. Stores has its own heading, key and explicit now/late-Winter prices. The last seed line is reached by scrolling. |
| [Seed choices](winter_seed_choices.png) | Each crop has its own keep-up-to limit; no farm-wide tonne total. |

Capture: `tests/capture_surfaces_browser.cjs --advice`, using the surfaces
fixture exported with `tools/export_browser_benchmark.py --fixture surfaces`.
The report at `artifacts/segment-o-phone/capture-report.json` contains no browser
errors and records the 390×844 backing size on every screen.
