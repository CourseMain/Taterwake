# Browser playthrough · underdevelopment j

2026-10-03. Chrome on Apple M4, phone emulation at 390×844 CSS pixels, DPR 3 and touch enabled. The user requested emulation in place of a physical phone. This is an automation-assisted walkthrough with direct screen inspection, not a human newcomer or real-device usability claim. The observation fixture starts the actual fresh farm, guide and annual front pages, without gifts, forced weather or calendar jumps. Later repetitive farming uses actual browser touch inputs. Harness repair and implementation work also allow ordinary game time to pass; ending cash is not a controlled balance measurement.

## Observations and final-fix candidates

The initial walkthrough completed the tutorial and ended in year-four foreclosure with unsold crops. Its actions and final farm are preserved as `j-first-run-actions.json` and `j-first-run-snapshot.json`. A second pass uses the learned Menu → Sell Potatoes route; it skips the already-reviewed guide through its ordinary control. Neither run is a controlled measure of strategy cash. Two Tab-key probes investigated the seed carousel; farming and purchases use touch inputs.

| Season / screen | Observed confusion or boredom | Final-fix candidate |
| --- | --- | --- |
| Year 1 Spring / front page | “Skip → Return to farm” appears before the welcome guide. Its scope can be confused with skipping the tutorial. | Name the action “Start the year” or explain what is skipped. |
| Year 1 Spring / guide, seed shop | “Open Seeds [B]” gives a desktop shortcut. Menu is blocked, Tools → Crop only selects owned seeds, and Mara is a tiny world target at overview zoom. Several attempted taps missed the shop. | Give the guide a direct touch action or a prominent shop target. |
| Year 1 Spring / guide, seed shop | The farm already owns twelve Russet seeds, yet the guide requires buying another. Other planted starter crops are not introduced. | Explain starting stock and the reason for the purchase. |
| Year 1 Spring / guide | Trying a blocked action temporarily replaces the instruction with “Finish this step…” without retaining how to complete it. | Keep the step instruction visible alongside refusal feedback. |
| Year 1 Summer / guided storm | One bed is already ripe while the guide waits for the boundary and warning. Hurry is disabled. The HUD calls the deliberately mild disclosed storm “SEVERE STORM”. | Shorten the guide's calendar staging and use severity-appropriate wording. Crop grow-time cuts do not remove this wait. |
| Year 1 Autumn / guide | “Calendar running…” leaves the player watching the farm until Winter, with farming and hurry locked. | Give this guided transition a clear progress indicator or a brief narrated transition. |
| Year 1 Winter / first accounts | Four other starter beds die to Autumn Cold while the guide only permits the highlighted bed. The ledger lists those losses without explaining that the guide blocked their harvest. | Allow starter crops to be harvested or avoid placing unmanageable starter crops in the guided farm. |
| Year 1 Winter / accounts and next front page | The filed net initially reads −109,070; equipment bought after closing the accounts changes next year's “last year” net to −205,070. | Explain that Winter purchases still post to the same year, or distinguish the settlement statement from final annual totals. |
| Year 1 Winter / jobs and Sleep until Spring | The jobs card shows stored tonnes and changing quotes. Sleep confirmation names the two unsold tonnes and late-Winter total. It returns to Spring with those sacks still unsold. | No Winter-length cut indicated by this step. |
| Year 2 Spring / shop | Cards extend horizontally with a thin scrollbar and no obvious next-card action. The ordinary clock continues during shopping. | Make horizontal browsing and the running clock more obvious. |
| Year 4 Summer–Autumn / farm and sales | Quick Sell disappears for the entire weather phase, including recovery. Unsold Golden remained in the barn; the run foreclosed before those crops were sold. Menu → Sell Potatoes remains available. | Keep sales discoverable during weather and show an unsold-crop warning before the Winter bill. |
| Year 2 Summer / farm | Upgraded hoe, can and scythe materially reduce repeated work. Hold to hurry shows 3× and makes ordinary growth waits manageable. | Keep current grow times pending a human feel pass. |

Evidence: `artifacts/j-play-actions.json`, `artifacts/j-play-routine.log`, and `artifacts/j-play-*.png`. These local artifacts accompany the release review bundle.

## Tutorial follow-up

The user independently reported a Summer step-six stall and missing Iris, and requested 10× instead of 5×. This build now uses 10× guided waits, an eight-second warning at 1×, Iris's portrait and radio cue, and countdowns. A mid-Summer resume regression checks that a started calm outlook still starts the lesson storm and reaches the real cause card. These changes address the warning and progress observations above; seed-shop access and starter-crop losses remain final-fix candidates.

## Upload handoff

The learned second run reached year-five Summer and is preserved in `j-second-run-year5-save.json`; it did not complete ten years or measure the epilogue wait. The user requested an immediate upload for the next reviewer, so those remain open checks. This pass also found the weather card’s invisible scroll area intercepting farm and Winter Sleep taps. The uploaded fix sizes that area to its visible contents and keeps quick Sell visible during weather. The touch suite verifies that a real GUI click reaches the Sleep confirmation during a blizzard warning. Seed-shop access, unmanageable starter crops and the known cold accounts stall remain review candidates.
