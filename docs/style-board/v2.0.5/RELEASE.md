# Segment 21i · 11 October 2026

Scope: A, B, D, E and the new F from `61dc5c0`. The branch `claude/modest-hopper-yh83b7` was merged into `redesign` before implementation. C is closed; the Deferred list and Segment 22 have no changes in this work. Earlier review captures remain historical evidence.

Godot **4.7.2 stable**, GL Compatibility, GDScript. Chromium uses Metal ANGLE. Phone captures are **390×844 CSS pixels**, desktop **1440×900**. PNGs are unedited browser captures; timings use a browser fixture rather than physical phone hardware.

A · Portrait entry measures the island silhouette in camera space and centres it vertically. The guided year fits Home and the gate; fresh entry and saved guided Continue use the same framing. Completed-guide Continue fits the whole island width. The browser check now uses touch on the phone and mouse on desktop, and verifies the input mode. It captures the first farm frame immediately after the farmer card closes and the first Continue frame.

B · HUD labels use the 14 px floor. The suite checks source declarations and actual rendered phone labels across the HUD and pages. The focused typography run passes **596 reported checks** across two suites.

D · All six nature beds and wind are Vorbis with nominal **96,000 bits/second**, 44,100 Hz. Their durations match the public v2.0.4 WAV sources, including the authored three-second cicada burst. Wind keeps its zero-to-48-second loop; nature gaps and crossfades remain. Short cues stay WAV.

| Phone first load | Public v2.0.4 | Rebuilt v2.0.5 |
| --- | ---: | ---: |
| Pack | 15,846,160 bytes | 5,029,100 bytes |
| Median of three uncached loads | 48.273 s | 40.378 s |
| Engine WASM | 39,514,754 bytes | 39,514,754 bytes |

The fixture uses **10 Mbps, 40 ms latency**, cache disabled and service workers blocked. The reduction is **7.895 seconds / 16.36%**. See the [before](release-first-load-before.json), [after](release-first-load-after.json) and [codec/loop report](release-audio-report.json).

E · Unchanged grade hints count layout passes instead of elapsed time. The runner includes season clock and audio as standalone suites, alongside epilogue and bot. An additional intermittent UI-audit resource leak was fixed by stopping audio and waiting for the actual playback references to release before freeing the scene. Three focused audit runs pass **795 checks each**, with no resource error.

F · The world uses ACES, exposure **1.15**, saturation **1.25**, contrast **1.05**, brightness **1.0**, ambient **0.32 / c8dcf0**, and shadow opacity **0.7**. Seasonal grass tops, 15% darker risers, canopies, shore/deep water, white foam and noon sky use the exact plan values. Spring/Summer haze is halved again from the previous setting and all calm noon haze clears. Dusk stays warm and the sun disc remains. Interface tokens match the updated kit. Keeper headers, crop colours and rarity edges use the tokens directly. Weather and Menu drawings use chromatic tokens. Page and ending overlays preserve at least 70% of farm light.

**Pending owner decision:** The new F rule requires full-chroma stamps and chips, while the reference kit still specifies the older dark stamp inks and pale fills. The owner has been asked whether Table, Standard and Feed should use money `f0b429`, common `7fc47a` and wood `8a5a3c`. No answer has been inferred, and stamp colours have not been changed. Tagging and publication remain pending this decision and final validation.

## Requested before and after captures

| View | Phone before | Phone after | Desktop before | Desktop after |
| --- | --- | --- | --- | --- |
| Spring noon | [390](release-spring-noon-before-390.png) | [390](release-spring-noon-after-390.png) | [1440](release-spring-noon-before-1440.png) | [1440](release-spring-noon-after-1440.png) |
| Summer noon | [390](release-summer-noon-before-390.png) | [390](release-summer-noon-after-390.png) | [1440](release-summer-noon-before-1440.png) | [1440](release-summer-noon-after-1440.png) |
| Mara's page | [390](release-mara-before-390.png) | [390](release-mara-after-390.png) | [1440](release-mara-before-1440.png) | [1440](release-mara-after-1440.png) |

The after captures show a clear blue sky, bright fields and water, and a visible farm behind Mara's page. [Before report](release-vibrancy-before-report.json) / [after report](release-vibrancy-after-report.json).

## Entry captures

| Entry | Phone | Desktop |
| --- | --- | --- |
| Fresh, first frame after farmer card | [390](release-farm-390.png) | [1440](release-farm-1440.png) |
| Guided Continue, first frame | [390](release-returning-farm-390.png) | [1440](release-returning-farm-1440.png) |
| Completed-guide Continue | [390](release-returning-overview-390.png) | [1440](release-returning-overview-1440.png) |
| Production fresh, settled guide | [390](release-production-fresh-farm-390.png) | [1440](release-production-fresh-farm-1440.png) |
| Production Continue, settled guide | [390](release-production-continue-farm-390.png) | [1440](release-production-continue-farm-1440.png) |

The production smoke uses the actual export without QA bridges and passes fresh/Continue at both sizes. [Entry report](release-entry-report.json) / [production report](release-production-report.json).

## Validation and remaining work

The full `tools/run_tests.sh -j 2` run and additional standalone epilogue/bot run are in progress. Their final results will be recorded here. All tests remain enabled.

Balance, crop economics, ledger labels and bot tuning are unchanged. The requested latest Oda token `7a7f8c` supersedes the older pending iron-token question. The earlier recorded white E badge and Slackey guide body are outside this segment's named changes. Owner-local layout and shadow-setting edits are excluded from the release checkout and preserved in the working checkout.

Not yet done: grade stamp colour decision, v2.0.5 tag and publication to the docs root. The production export is prepared in `dist/web/` and `dist/Taterland-Web.zip`; public docs still contain v2.0.4.
