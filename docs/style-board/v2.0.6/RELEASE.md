# Segment 21j · v2.0.6 review

This review covers the nine requested quality-of-life fixes and the owner's added Sell page, purchase feedback, a centred player camera, hotbar alignment and Winter footprints. The plan branch was merged into `redesign` before implementation. The scope additions are recorded as owner's decisions dated 2026-10-12 in [DEVELOPMENT.md](../../DEVELOPMENT.md). No palette, price, balance, ledger-label or tuning-table change is included. The public docs-root build remains v2.0.5.

## Visible changes

1. Home and Low path-side fence posts sit on their field edges. One orchard tree formerly covering the Quests board is removed; the board's entire face is visible in all four seasons.
2. Rental boards say “For rent” with a drawn key. Low and Hill locked-bed directions retain the exact 55,000 and 9,000 annual rents. Winter leases say “For rent”.
3. The existing phone season and money rows are retained and verified at Winter, year 3. The full season and year remain visible.
4. Grades fits one row of three stamps, the three glosses and its close button. Feed's existing gloss is inline below its stamp.
5. Accounts keeps the full-width wood “Go to the barn” button and presents Records, Leases and Businesses as three drawn tiles. Expanded business headings wrap within the phone.
6. Existing “1 season” singular and 14 px Thirst, Heat and Cold rows with drawings are retained and verified.
7. The first guide has one title, one instruction and one button. Its close/skip control is hidden at that step. Fullscreen, smiley, gear and eye stay hidden until the guided year ends.
8. Refused taps shake only their control for 200 ms. A caption of at most eight words gives the reason and remedy beneath the instruction. Sales post immediately; the pressed sale button shows Undo for three seconds. Undo restores the sale's stock and journal entries, including the first guided sale.
9. Card buttons and the five tool tiles answer on press with a small drawing change and the existing authored sound. The browser fixture measures real pointer input, rendered feedback and the audio output.

The added Sell page shows five full-width rows on phone and desktop. Every row has its crop drawing, price, horizontal graph, existing grade choices and “1 tonne” / “5 tonnes” buttons. There is no crop drill-down or page scrolling at either review size. Purchases briefly animate their seed card. The camera keeps the farmer's body exactly in the middle during farm play. Wheel, vertical trackpad scrolling and pinch change the view size around the farmer; dragging cannot move the view away. The title and open page cameras retain their existing behavior. Desktop tool tiles share equal sizes and caption baselines; their redundant hover tooltip no longer covers neighboring tools. Winter walking now leaves the existing footprints on open ground and fields as well as roads. Tracks sit above raised field surfaces and keep the same 96-print pool, spacing and sixty-second fade.

## Before and after

These are unedited browser captures from the frozen merged baseline `fba0f95` and the revised game. Phone images are 390×844; desktop images are 1440×900. The fixture supplies the same seeded farm and noon camera targets in both builds and never reads or writes a normal player save. The refused-tap comparison actually attempts watering with an empty can. The Undo comparison actually sells one Table Russet tonne. The hotbar comparison hovers Harvest.

| View | Size | Before | After |
| --- | --- | --- | --- |
| Home field edge | 1440×900 | [Before](before-qol_home-1440.png) | [After](after-qol_home-1440.png) |
| Low field edge | 1440×900 | [Before](before-qol_low-1440.png) | [After](after-qol_low-1440.png) |
| Quests · Spring | 1440×900 | [Before](before-qol_quests-0-1440.png) | [After](after-qol_quests-0-1440.png) |
| Quests · Summer | 1440×900 | [Before](before-qol_quests-1-1440.png) | [After](after-qol_quests-1-1440.png) |
| Quests · Autumn | 1440×900 | [Before](before-qol_quests-2-1440.png) | [After](after-qol_quests-2-1440.png) |
| Quests · Winter | 1440×900 | [Before](before-qol_quests-3-1440.png) | [After](after-qol_quests-3-1440.png) |
| For rent board | 390×844 | [Before](before-qol_rent-390.png) | [After](after-qol_rent-390.png) |
| Locked Low field | 390×844 | [Before](before-qol_locked-390.png) | [After](after-qol_locked-390.png) |
| Winter · Year 3 | 390×844 | [Before](before-qol_winter-390.png) | [After](after-qol_winter-390.png) |
| Grades | 390×844 | [Before](before-qol_grades-390.png) | [After](after-qol_grades-390.png) |
| Accounts buttons | 390×844 | [Before](before-qol_accounts-390.png) | [After](after-qol_accounts-390.png) |
| Mara's seed card | 390×844 | [Before](before-qol_seed-390.png) | [After](after-qol_seed-390.png) |
| First guide | 390×844 | [Before](before-qol_guide-390.png) | [After](after-qol_guide-390.png) |
| Refused watering | 390×844 | [Before](before-qol_refused-390.png) | [After](after-qol_refused-390.png) |
| Sale / Undo | 390×844 | [Before](before-qol_undo-390.png) | [After](after-qol_undo-390.png) |
| Five tool tiles | 390×844 | [Before](before-tool-tiles-390.png) | [After](after-tool-tiles-390.png) |
| All sales and graphs | 390×844 | [Before](before-qol_sell-390.png) | [After](after-qol_sell-390.png) |
| All sales and graphs | 1440×900 | [Before](before-qol_sell-1440.png) | [After](after-qol_sell-1440.png) |
| Purchase feedback | 390×844 | [Before](before-qol_buyfeedback-390.png) | [After](after-qol_buyfeedback-390.png) |
| Aligned hotbar | 1440×900 | [Before](before-qol_hotbar-1440.png) | [After](after-qol_hotbar-1440.png) |
| Winter tracks | 390×844 | [Before](before-qol_tracks-390.png) | [After](after-qol_tracks-390.png) |
| Winter tracks | 1440×900 | [Before](before-qol_tracks-1440.png) | [After](after-qol_tracks-1440.png) |

The locked camera is also checked with real keyboard movement, wheel scrolling and pointer dragging at both sizes: [phone walking](player-walk-390.png), [phone zoom](player-zoom-390.png), [desktop walking](player-walk-1440.png), [desktop zoom](player-zoom-1440.png). All eight measured states keep the farmer within 0.02 rendered pixels of the viewport centre; the [measurements](camera.json) record the positions and zoom.

## Validation

The browser checks pass **393 real button taps across 64 views**. The slowest visible response is **57.7 ms** and the slowest sound is **101.1 ms**, both on the Quests close button; the limits remain 100 ms and 300 ms. The [complete measurements](tap-latency.json) cover the five tools, every enumerated card button, ten guided steps, and title and guided-year confirmation controls.

The sweep is saved in batches. Two earlier attempts are retained in the linked source data: a selected tab needed its native pressed drawing state measured, and a dropdown opened on press before the first feedback frame. The tab measurement now follows drawing/focus changes while excluding pre-tap hover; dropdowns answer on press and open on release. The complete affected Quests and Decorations views were rerun successfully. No failing result is counted as a passing measurement.

These are Chrome browser-fixture measurements at 390×844 on this computer, rather than physical-phone measurements. The GDScript fixture observes rendered button state after frame draw; the browser observes pointer input and audio output.

All four existing [colour gates](vibrancy-gates.json) also pass: zero blown-white Spring pixels, mean island saturation **0.5447**, shade ratios **0.614–0.626**, and title lettering maximum RGB **234 / 211 / 206**. No palette values changed.

The final **tools/run_tests.sh -j 2** run passes **108 / 108 suites**, **24,068 checks**, with **0 failures, timeouts or errors**. The full run includes standalone epilogue **534** and tuning bot **1,679** checks. The additional epilogue rerun also passes **534 checks**. The owner subsequently requested a quick finish and waived further thorough testing; the extra tuning-bot rerun was stopped at that request and is recorded as incomplete in [standalone results](standalone-results.json). No incomplete run is counted as passing. No test was skipped, disabled or deleted to obtain the green full result.

## Local work preserved

The release was built and tested in a clean checkout. The owner's thirteen tracked local UI/style edits remain uncommitted in the working `redesign` checkout. The existing untracked draft `test_ui_visual_fit.gd` now checks the new one-tonne and five-tonne buttons in place of the removed Max control; its 283 checks pass against those local edits. Its original contents are backed up outside the repository. The working main scene also completes a headless boot without script errors.

The local Grades dim layer is still 0.35, while the release retains the kit's 0.30. That local style override remains outside this segment and can fail the release kit audit. Existing white interaction E badges and the Slackey guide body also remain outside the named changes. The separate stamp-colour decision recorded during v2.0.5 remains unchanged. No Segment 22 work or docs-root publication is included.

## Completion

The nine items and the named owner additions are complete. The release is tagged **v2.0.6**. **Not completed:** the extra standalone tuning-bot rerun, stopped under the owner's 2026-10-12 testing waiver. No requested implementation remains undone. There is no docs-root publication in this segment; public v2.0.5 remains unchanged.
