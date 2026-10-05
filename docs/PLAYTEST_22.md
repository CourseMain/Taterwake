# Segment 22 · fresh-player playtest

The first human sheet is recorded below. Segment 21f responds to this player's blockers and confusion. Three more fresh testers play **after Segment 21f**, before the Segment 22 fun pass. Browser checks and the tuning bot do not replace these human observations.

## Current build

The first sheet concerns the public v2.0.0 build. Part A shipped as v2.0.1. Parts B–M and the owner’s NPC-first and no-Hurry changes remain in the local v2.0.3 build, which also includes Segment 21g's visible sun and illustrated controls. Publishing remains paused. Each subsequent tester starts a fresh farm in a separate browser profile or clears existing farm data through the normal controls.

Ask each person to play as they normally would and say what they are thinking. Start the timer when they begin the game. Let the guide explain the controls; avoid coaching or describing planned features. Record every confusion or idle stretch with elapsed time, year, season and screen. If someone stops, record why. If they continue, ask afterward where they would have stopped when playing alone. Do not assume a completed run means they enjoyed it.

## Step 0 reports

Use tester IDs rather than names. All blank rows are pending, not successful tests.

| Tester | Device / browser | Minute they would quit | Year / season | Screen | Their reason, in their words |
| --- | --- | --- | --- | --- | --- |
| 1 | Phone; browser not supplied | 1 | Year 1 / Spring | First screen | “too much text, too small, too fast, too loud”; “I didn't understand Table and Standard”; “what do I do while I wait?” |
| 2 | Pending | Pending | Pending | Pending | Pending |
| 3 | Pending | Pending | Pending | Pending | Pending |
| 4 | Pending | Pending | Pending | Pending | Pending |

Tester 1 never plays games. Asked whether she would open the game again: **“No motivation, only pain. Who would play that?”** The owner reports that she read the first screen for five seconds; the requested sheet records the quit point within minute 1.

Additional observations:

| Tester | Elapsed minute | Year / season / screen | Confusion, boredom or enjoyable moment | What the player tried |
| --- | --- | --- | --- | --- |
| 1 | Within minute 1 | Fresh launch / after “Walk to the farm” | Island missing; restart required | Walked to the farm and restarted |

## Implementation order

The first sheet sets the Segment 22 brief: the hook items—a reason to come back, the Spring target, Nell's milestones and the first thing the player can afford—come before anything else in the fun pass. Collect three more fresh sheets after Segment 21f. Tie each later priority to those observations and quit risks. Keep the potato farmer, villagers, hand-built island and the wood, paper and ink surfaces established in Segment 21c. Do not add the prohibited rewards, offline timers, real-money purchases or compounding prices.

## Balance baseline for A

Tag l retains tag k’s 150-second seasons, crop times Russet 60 / Golden 90 / Giant 110 / Sunburst 160 / Icecap 200 seconds, and twelve open Home Field beds. The following fixed seeds 1–30 table was recorded at tag k; Segment 21c changes presentation only. Tag-l standalone tuning confirmation is part of its release validation:

| Strategy | Ten-year survivors | Mean ending cash, scaled | Maximum ending cash, scaled |
| --- | --- | --- | --- |
| Naive | 0/30 | −245,170.12 | −201,127.63 |
| Cautious | 30/30 | −26,996.95 | 56,594.15 |
| Tidy | 30/30 | 271,118.27 | 319,021.66 |
| Diversifier | 28/30 | 28,661.22 | 143,980.64 |
| Expander | 29/30 | 87,956.58 | 215,971.19 |

Retune against these recorded survival numbers after each change in A, and retain the bot's cash ceiling, strategy ordering and diversification checks. Record each changed constant and resulting cohort table; do not weaken tests to make retuning pass.

## Replay acceptance

After implementation, invite the same three testers to play the changed build. Record their reactions without asking whether they want another run. Acceptance requires all three to want a second run unprompted; otherwise repeat Step 0 and the segment.

| Tester | Changed build | Minute / screen they would quit | Unprompted request or action showing they want another run | Outcome |
| --- | --- | --- | --- | --- |
| 1 | Pending | Pending | Pending | Awaiting replay |
| 2 | Pending | Pending | Pending | Awaiting replay |
| 3 | Pending | Pending | Pending | Awaiting replay |
