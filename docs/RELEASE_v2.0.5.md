# Taterland v2.0.5

This development playtest brings Segment 21i's phone and loading fixes to the public game, with the replacement Filmic colour pass.

- Fresh and Continue phone entry fit the island width and centre the farm. The guided year zooms to Home and the gate.
- HUD labels meet the 14 px floor at 390 wide, checked by the suite.
- Six nature beds and wind use 96 kbps OGG Vorbis, preserving durations and wind loop points. The pack is **5.03 MB**. Uncached phone-fixture first load fell from **48.273 to 39.264 seconds** at 10 Mbps and 40 ms latency.
- Grade layout checks count passes. Audio and season-clock suites run standalone, and scene teardown waits for audio playback to release.
- Second-pass Filmic lighting preserves shade and the title's dusk light. All four browser gates pass: **0%** blown white, **0.5443** island saturation, **61.37–62.62%** shade brightness and title lettering maximum RGB **234 / 211 / 206**.

The full suite passes **103 / 103 suites**, **23,762 reported checks**, with **0 failures, timeouts or errors**. Fresh and Continue production entry pass at **390×844** and **1440×900**. The full run includes standalone epilogue **534 checks** and tuning bot **1,679 checks**. The owner waived an extra bot rerun; no suite or assertion was removed or disabled.

The grade stamp palette remains unchanged while the plan-versus-kit choice awaits the owner. Balance, ledger labels and the tuning bot's table are unchanged. Part C, Deferred work and Segment 22 are untouched.

[Play Taterland v2.0.5](https://coursemain.github.io/Taterwake/) · [Browser download](https://github.com/CourseMain/Taterwake/releases/tag/v2.0.5) · [All requested before/after screenshots](style-board/v2.0.5/RELEASE.md)

Classic v1.0.3.1 remains at [the classic game](https://coursemain.github.io/Taterwake/classic/).
