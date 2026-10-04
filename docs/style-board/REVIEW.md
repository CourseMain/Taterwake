# Segment 21c screen review

Reviewed against the [wood, paper and dusk board](README.md), 4 October 2026. The [four before-and-after comparisons](COMPARISON.md) use unedited **390×844** Chrome screenshots from a disposable Godot 4.7.2 Compatibility fixture. The fixture does not read or write a player's farm. The final production source is `4ae84f8`; complete provenance is in [the capture manifest](capture-manifest.json).

## Phone browser review

All twenty pages in [the browser report](taterland-after/capture-report.json) have a 390×844 backing size and fit the available width. The report contains no browser errors. Each image below was inspected, including the separate end-of-scroll captures where the actions or final text matter.

| Screen | Reading against the board and result |
| --- | --- |
| [Title](taterland-after/title.png) and [eight-second pullback](taterland-after/title-pullback.png) | The real wooden gate carries the only world lettering. Warm low sunlight, a peach horizon and quiet water support the round farmer. One large ink action and a smaller Continue fit without a modal box. |
| [Annual accounts](taterland-after/accounts.png) and [lower page](taterland-after/accounts-end.png) | Ink holds the grouped paper ledger leaves, Nell's portrait and ledger drawing. Fixed bottom actions stay visible while leases, businesses and the cause card scroll. Labels and amounts fit. |
| [Crop card](taterland-after/crop-card.png) | Illustrated seed packets sit on a wooden tray inside an ink frame. The swipe caption and partial next packet explain the horizontal list. Arrow, crop pips, price, levels and both Buy actions render correctly. |
| [Forecast](taterland-after/forecast.png) | A weather drawing and interval line lead the paper forecast; protection entries use wood. All field summaries, level circles and visible costs read clearly. |
| [Farm menu](taterland-after/menu.png) | Dark text and small drawings read on cream action buttons within an ink frame. The final farm action fits on screen. |
| [Barn](taterland-after/barn.png) | A barn drawing anchors the capacity tally. Stored crop drawings and quantities sit directly on wood; Sell and inventory tabs remain prominent. |
| [Workbench](taterland-after/tools.png) | Drawn tools occupy paper inserts inside wooden slots. Upgrade costs and actions fit, with the next item visibly continuing below. |
| [Quests](taterland-after/quests.png) | Pinned paper slips, progress strips and small pins give Tess's wooden board a different shape from the market and ledger. All three jobs fit. |
| [Loss notice](taterland-after/loss_notices.png) | Event, lost tonnes, value and avoided-loss explanation fit on a single pinned slip. |
| [Buyer order](taterland-after/contracts.png) | The crop picture and large quantity lead the order; due date, penalty and action remain together on paper inside ink. |
| [Selling](taterland-after/sell_potatoes.png) | Crop drawings, price traces and grade actions identify a selling sheet. Paper occupies more of this screen than the forecast, but its base and gutters remain ink; the partial next crop is within the scroll. |
| [Annual front page](taterland-after/front_page.png) | The first browser layout is now a single newspaper column. The headline, Iris's portrait and forecast, climate record, small accounts leaf and bottom action all fit. |
| [Nell conversation](taterland-after/npc-nell.png) | A large portrait, wooden dialogue area and separate paper speech/action shapes keep the keeper recognizable. Text, role and actions read clearly; the farm surrounds the panel. |
| [Run summary](taterland-after/run_summary.png) and [lower page](taterland-after/run_summary-end.png) | Ink separates the frozen ledger rows and season record. The concluding paragraph scrolls above four fixed actions; amounts, labels and actions fit. |
| [Foreclosure](taterland-after/foreclosure.png) and [lower page](taterland-after/foreclosure-end.png) | The final notice has readable light labels on ink and one grouped paper ledger leaf. The explanation scrolls; its three actions remain visible. |
| [Graphics](taterland-after/graphics.png) | The current 2048 shadow setting and both size choices are visible. Cream controls read against the ink base. |
| [Debug](taterland-after/debug.png) | The existing one-tap year recorder is a small paper insert in the ink panel; its action and explanation fit. |
| [Controls](taterland-after/help.png) | A compact two-column note leaves much of the farm in view. All six controls fit without a full-height card. |
| [Duck patrol](taterland-after/activities.png) | The pond illustration and offers sit on wood. The refreshed capture confirms light headings and readable muted labels; action and lock text also fit. This resolves the contrast issue found in the first review. |
| [Crop catalogue](taterland-after/dex.png) | Large crop drawings and concise variety facts sit on wood, with small paper yield strips. Three varieties and the beginning of the fourth make the scroll evident. |

No hard clipping or third stacked cream surface was found in the inspected pages. Deliberately partial packets and lower rows stay inside their scroll areas. A separate runtime audit of 24 modal kinds also found at most two cream layers and no large flat `Panel` / `PanelContainer` backgrounds. The latter checks panel styles, not the pixels drawn inside illustrations. Local audit evidence is in `artifacts/surface-audit-extra.log`; the browser report records visible surface types and colors.

The material rule is expressed through several distinct forms: seed packets on a tray, ledger leaves, a forecast strip over wooden equipment, pinned quest slips, a newspaper and a portrait conversation. The market selling sheet and run summary contain more paper because their figures fill the page; neither uses cream as the outer frame. This is a visual review, not a claim that every individual screen has exactly one-third cream pixels.

## Validation and remaining work

| Item | Status |
| --- | --- |
| Title, accounts, crop card and forecast before / after at 390×844 | Captured and reviewed; see [comparison](COMPARISON.md). |
| Other browser pages, including first front-page layout and end-of-scroll states | Reviewed, including the corrected Duck patrol text on wood. |
| Shared material structure | Runtime audit: 24 modal kinds, at most two cream layers, no large flat panel backgrounds. |
| Short everyday voice | [Twenty edits](VOICE.md), 435 words reduced to 217; seven focused suites passed. |
| Motion from the place, with the farm alive behind it | Focused panel-motion suite passed 133 checks at desktop and phone sizes, including projected building origins, bounded entrance timing, input protection and a live farm during conversations while the farm calendar stays paused. |
| Full suite and standalone epilogue / tuning bot | **96/96 suites PASS**; standalone epilogue **534** and tuning bot **1,679** checks pass. Exact boot **45** checks passes. Zero failures, errors or skipped tests; final results are recorded in [DEVELOPMENT.md](../DEVELOPMENT.md). |
| Physical-phone year measurement | Awaiting owner measurement using Debug → Measure a year, as recorded in DEVELOPMENT.md. Browser emulation supplies no physical-phone performance result. |
| Segment 22 stranger playtests | Not started in this segment. Three new players' quit-risk notes and replay acceptance remain human work. |

## Guided-year bills follow-up · tag m

The [fresh guided Winter accounts](tag-m-guided-accounts.png) were captured at 390×844 through touch input. All ordinary bill rows remain on paper; the one signed 104,000 credit wraps inside its row, and Nell's exact explanation sits on ink. Other does not repeat the credit. There is no additional cream layer. The title, crop and forecast surfaces are unchanged from the twenty-page tag-l review above. This is desktop phone emulation; physical-phone frame time remains awaiting the owner.


The later [tag-n light, HUD and title review](TAG_N.md) supersedes the opening choices and play masthead shown in this historical tag-l review. Accounts, crop cards and forecast retain their 21c surfaces and frozen ledger labels.
