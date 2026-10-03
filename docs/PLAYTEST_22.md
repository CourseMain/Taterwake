# Segment 22 · fresh-player playtest

Step 0 is awaiting three people who have never played Taterland. These are human observations; the tag-k browser walkthrough and tuning bot do not substitute for them. Implementation order will be chosen after the three baseline reports arrive.

## Current build

Use [v2.0.0-underdevelopment-k](https://github.com/CourseMain/Taterwake/releases/tag/v2.0.0-underdevelopment-k), source commit `ea69a35`. Download `Taterland-Web.zip` for a computer or `Taterland-Phone-Test.zip` for the local HTTPS phone preview. The phone ZIP includes `README-PHONE.txt`; [DEVELOPMENT.md](DEVELOPMENT.md#segment-21-follow-up--tag-k) also has the launch steps. Each person starts a fresh farm in a separate browser profile or with existing farm data cleared through the game's normal controls.

Ask each person to play as they normally would and say what they are thinking. Start the timer when they begin the game. Let the guide explain the controls; avoid coaching or describing planned features. Record every confusion or idle stretch with elapsed time, year, season and screen. If someone stops, record why. If they continue, ask afterward where they would have stopped when playing alone. Do not assume a completed run means they enjoyed it.

## Step 0 reports

Use tester IDs rather than names. All blank rows are pending, not successful tests.

| Tester | Device / browser | Minute they would quit | Year / season | Screen | Their reason, in their words |
| --- | --- | --- | --- | --- | --- |
| 1 | Pending | Pending | Pending | Pending | Pending |
| 2 | Pending | Pending | Pending | Pending | Pending |
| 3 | Pending | Pending | Pending | Pending | Pending |

Additional observations:

| Tester | Elapsed minute | Year / season / screen | Confusion, boredom or enjoyable moment | What the player tried |
| --- | --- | --- | --- | --- |
| Pending | Pending | Pending | Pending | Pending |

## Implementation order

Pending the three reports. Tie each priority to a recorded observation and its quit risk before changing A–F. Keep the potato farmer, villagers, hand-built island and cream UI. Do not add the prohibited rewards, offline timers, real-money purchases or compounding prices.

## Balance baseline for A

Tag k uses 150-second seasons, crop times Russet 60 / Golden 90 / Giant 110 / Sunburst 160 / Icecap 200 seconds, and twelve open Home Field beds. The fixed seeds 1–30 tuning cohort records:

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
