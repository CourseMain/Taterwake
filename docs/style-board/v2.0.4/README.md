# Taterland v2.0.4 review

The owner’s follow-up makes the computer the primary layout and requests smaller display headings. These captures retain the kit’s ink, paper, wood, crop and keeper colours while using wide computer pages. Whole pages stay still under the mouse; individual seed cards retain their hover motion.

| Screen | Computer, 1440×900 | Phone kit comparison, 390×844 |
| --- | --- | --- |
| Your farmer | [Built](farmer-desktop.png) · [Beside kit](farmer-desktop-comparison.png) | [Reference beside game](farmer-comparison.png) |
| Menu board | [Built](menu-desktop.png) · [Beside kit](menu-desktop-comparison.png) | [Reference beside game](menu-comparison.png) |
| Nell’s accounts | [Built](accounts-desktop.png) · [Beside kit](accounts-desktop-comparison.png) | [Reference beside game](accounts-comparison.png) |
| Mara’s Buy page | [Built](market-desktop.png) · [Beside kit](market-desktop-comparison.png) | [Keeper primitives beside game](market-comparison.png) |
| Winter jobs and Stores | [Built](kit_winter-desktop.png) · [Beside kit](kit_winter-desktop-comparison.png) | [Reference beside game](kit_winter-comparison.png) |
| Grade stamps | [Built](grades-desktop.png) · [Beside kit](grades-desktop-comparison.png) | [Reference beside game](grades-comparison.png) |
| Practice tiles | [Built](practice-desktop.png) · [Beside kit](practice-desktop-comparison.png) | [Reference beside game](practice-comparison.png) |
| Sale reveal | [Built](sale_reveal-desktop.png) · [Beside kit](sale_reveal-desktop-comparison.png) | [Reference beside game](sale_reveal-comparison.png) |

Additional computer views: [Mara’s Sell page](market_sell-desktop.png), [barn orders and deals](barn-desktop.png), [Tools without decorations](tools-desktop.png), and [New Farm confirmation](new-farm-desktop.png).

The supplied HTML has no separate Mara mockup: her comparison uses its keeper header and paper primitives and is labelled accordingly. Reference captures load the bundled fonts, enforce the requested 14 px caption floor and omit rarity words as required by the kit’s rejection list. Farmer and Menu retain picture choices without scrollbars. The real 3D farmer and keeper faces replace the mockup’s schematic drawings.

Mara owns Buy and Sell. Sell presents one selected crop and one amount control; held Winter sacks and fresh harvest remain correctly priced in one current stock. Barn owns the existing premium buyer orders. Every service begins with its keeper. Menu → Save → Plant a new farm offers cancel and confirm; a new run keeps earned clothing.

The practice tiles and sale reveal are supplied-data presentation components for Segment 22. No practices, offers, new varieties or gameplay multipliers are activated here. The first three cosmetic rewards are the flower hat, scarf and glasses. These affect no farm numbers.

Slackey’s official licence is Apache 2.0, bundled as [Slackey-LICENSE.txt](../../../assets/fonts/Slackey-LICENSE.txt). Atkinson Hyperlegible includes its [OFL licence](../../../assets/fonts/AtkinsonHyperlegible-OFL.txt). The original potato and arrow glyphs supply symbols rather than a third text face.

Browser checks cover 960×600, 1440×900 and 2888×1804 computer windows, actual Buy/Sell and New Farm clicks, stationary modal geometry, and all five seed cards fitting. Production entry and fullscreen checks cover desktop and phone. Five interaction layouts cover phone, phone landscape, tablet, tablet landscape and laptop. These are Chromium viewport checks, not physical-device performance measurements.

The sea-only entry was reproduced by losing window focus during the returning title. The title camera became a 101-unit farm pan. That offset is now kept separate, and Continue restores both camera and navigation. The launch suite retains a farmer's existing pan without moving Home and follows sixty gameplay frames after focus and resize events. Nine fresh Web entries and three saved growing-guide entries pass across 1440×900, 390×844 and 2888×1804. Inspected entry captures: [desktop Web](returning-farm-web-1440.png), [large Web](returning-farm-web-2888.png), [phone Web](returning-farm-web-390.png), and [native Compatibility](returning-farm-native.png). The native window is limited by the available display; its large capture is 2742×1714. The growing hint clears Weather.

Reproduce with the disposable `surfaces` export, `tests/test_kit_browser.cjs`, then `tools/capture_ui_kit.cjs`. Set `TATER_KIT_QA_URL` to its local server and `TATER_KIT_REFERENCE_URL` to the repository’s served kit page. Both scripts use Playwright; `CHROME_EXECUTABLE` can select Chromium.

The full suite passes **102 / 102 suites**, with **zero failures, timeouts or errors**. The required boot passes **44 checks**, kit **604**, responsive layout **1,307**, title launch **75**, and the unchanged 150-run bot **1,679**. No test is skipped or disabled. Validation records are local in `artifacts/v2.0.4-final-full-suite.log`, `artifacts/v2.0.4-final-full-suite-results.json`, `artifacts/v2.0.4-final-boot.log`, `artifacts/v204-desktop-review.json`, `artifacts/v204-kit-browser-report.json`, `artifacts/v204-final-production/report.json`, `artifacts/v204-final-mobile-browser.log`, and `artifacts/v204-final-title-browser/report.json`. Native launch assertions pass all 75 checks; that repeated fixture run reports four GL texture allocations at shutdown in `artifacts/v204-final-native-launch.log`. Browser runs report no errors.

The production export is `dist/web/`, with a self-contained `dist/Taterland-Web.zip`. Publishing remains paused; the published game and classic build are unchanged.
