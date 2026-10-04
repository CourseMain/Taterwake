# Tag n: light, play HUD and title choices

Reviewed against the [wood, paper and dusk rules](README.md), 4 October 2026.
These unedited Chrome captures use Godot 4.7.2 Compatibility, Balanced graphics,
2048 shadows on touch and 4096 on desktop. The visual runtime is `7fbb309`; title persistence is checked at `4236fb9`.
The benchmark reports the actual phone shadow size.
Exact sizes are **390×844** and **1440×900**, DPR 1. Performance uses DPR 3.
The existing [21c four-screen comparison](COMPARISON.md) and [complete screen
review](REVIEW.md) remain the review of the accounts, crop packets and forecast.
Ledger wording remains frozen.

| View | Phone | Desktop | Reading against the board |
| --- | --- | --- | --- |
| Spring noon | [390×844](tag-n-play_spring-390.png) | [1440×900](tag-n-play_spring-1440.png) | Green terrace tops, cool shaded risers, grounded beds and long shadows. |
| Summer noon | [390×844](tag-n-play_summer-390.png) | [1440×900](tag-n-play_summer-1440.png) | Straw-green tops and olive shade; leafy growing potatoes differ from ripe potato tops. |
| Autumn dusk | [390×844](tag-n-play_autumn-390.png) | [1440×900](tag-n-play_autumn-1440.png) | Orange trees, long low light, inset soil and quiet coastal highlights. |
| Fresh title | [390×844](tag-n-title-fresh-390.png) | — | The gate is the name. One large ink Walk action; no secondary line or HUD. |
| Saved title | [390×844](tag-n-title-returning-390.png) | — | Continue is the large action. Start a new farm is a small line beneath it. |
| Replacement | [390×844](tag-n-title-replace-390.png) | — | An ink card names the farm; Keep my farm has focus. Farm remains live behind it. |

The play top band, weather pill, tool tray and Sell control use ink or wood.
Season tabs are wooden, with the current tab lit. Cream highlights facts rather
than forming three stacked panels. On phones the live price joins the purse;
Sell moves beside the stick and the season row has its full width. Text stays
readable when tools are hovered or disabled.

The first rendered Web frame is recorded by a disposable wrapper around the
**unmodified production Main launch path**. A fresh browser context shows the
title without HUD, guide, panel or annual page; Walk finishes its 1.2-second
walk-in before the welcome guide. A real persisted save survives relaunch and
puts Continue on the first rendered frame. The replacement card uses no pause
panel or reset flag. Native launch tests cover the same initialization and a
saved Winter resume without automatic accounts.

The earlier tag-m production export already showed the title in this local
fresh-profile reproduction. The owner's missing-title symptom was therefore
not reproduced here. The farm picture and resolution are now installed
synchronously before the first render, and launch/frame regressions are covered
in the exported browser test. These tests do not establish behavior on the
owner's browser/device.

[Development validation and frame comparison](../DEVELOPMENT.md#segment-21d--light-play-hud-and-title-third-pass--tag-n)
records the full suite and the open real-phone measurement. No Segment 22
mechanics are part of this release.
