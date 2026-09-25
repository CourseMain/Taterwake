# Weather stations and the connected water loop

Island 2 begins with a skippable 12-second sky cinematic. It pauses simulation and introduces changing weather before opening the weather station. The scanning dishes on Islands 2 and 3 open forecasts, current protection percentages and equipment purchases; the desktop Weather & protection shortcut and Menu reach the same page.

Buy Sprinklers & Irrigation to install three fixed patches. The purchase and level-2 efficiency upgrade apply to all islands, including the Valley. Arrival and water practice never grant equipment. Revision-18 saves retain their highest owned irrigation level across all islands. Other protection projects remain local.

Deep Freeze is exclusive to Island 3. Its 45-second warning leads to a 30-second freeze and 75-second recovery. Frozen crops cannot grow, be watered or harvested; cold stress can destroy unrescued crops during impact. Frostgold crops resist ice. Open the furnace and use **Heat thawing hoe** for 60 seconds of rescue heat, then use **Hoe [1]** on frozen beds. Bellows are free to prevent a fuel shortage from blocking rescue. The separate 25-Icecap growth boost remains optional. Ice and heat persist in saves; ice clears when recovery ends. The older Frostbreak challenge pauses during disasters.

# Connected water and weather — v1.0.2

Released in v1.0.2. The lab below remains an isolated developer preview. Double-click **Play Climate Lab.command** in the repository to build and open a disposable browser farm. The lab never reads or saves your real farm. Its **Climate Lab · scenarios** button switches between seven fresh scenarios; selecting a scenario closes the lab controls so you can see the farm.

## Try it

Hold **Shift** while using WASD/arrows or click-to-walk to sprint (1.65× speed, no stamina meter). Scroll/pinch still zooms. Every island now has **1.5× the land area**: width and depth each grow by about 22.5%, while equipment and crop beds retain their size. Selected shops and workshops are now 10–16% larger for more natural proportions. This creates space around the farm without stretching the models or changing saved plots.

1. **Island 1 · tank, can, crops:** select Water [3] and click beds. The starter can carries 16 water, one per bed. The Water button and farmer show the remaining count. After 16 beds, click the highlighted tank. The farmer walks to its tap, the can fills, and the prompt disappears. Watch roof rain replenish the tank. **Empty can · test first refill** skips straight to this check.
2. **Island 2 · ordinary sprinklers:** click one of the three gold sprinkler heads along the field's left edge. Follow its highlighted source, pipe and fixed patch; click **Water these beds · 6 water**. Soil darkens and crops grow. The tank supplies the sprinkler directly; the carried can stays unchanged. Repeating the action on hydrated beds spends nothing.
3. **Island 2 · optional practice:** after buying sprinklers, choose safe practice at the weather station, water the bed marked **Water this bed [3]**, then click the near sprinkler and use its action. Real crops, bills and market clocks pause. Skip at any time; the first natural disaster is a dry spell after preparation time.
4. **Dry spell:** use the familiar can and sprinklers on drooping crops. Water lowers danger rings. The tank stops replenishing during the 30-second drought, so harvest ripe crops and choose which patches to rescue. Rain returns afterward.
5. **Flood:** click the gate at the front-left field corner, or **Show drain gate**. **Open drain** raises the gate, lowers flood danger and sends water through the channel to the sea. Hoe [1] still drains individual planted beds.
6. **Storm:** trees automatically shelter the far patch immediately behind them. Click trees to see the shelter area; protected crops sway less. Reinforced barn shutters slide closed automatically. The gold lightning row remains vulnerable: harvest it before the strike.

7. **Island 3 · expanded snowy farm:** inspect the larger shore, visit the forge/ferry, and try sprinting along the wider paths. Existing frost and crop rules apply.

**Open upgrades · plenty of lab coins** lets you test purchases. A purchase changes the equipment and briefly opens its illustrated use card. Successful use closes the prompt; × or Escape dismisses it. The lab's controls also include quality choices and an eight-second frame timing sample.

## Balance and design choices

| Equipment | Capacity or effect |
| --- | --- |
| Carried can | 16 / 32 / 48 / 64 water across four ranks; 1 per bed actually watered |
| Tank | 36 / 72 / 108 stored water; +36 per purchased level |
| Sprinkler | Same fixed patch for 6 water, or 4 after upgrading |
| Ordinary replenishment | 6 tank water per second, visibly collected from roof rain |
| Drought | Replenishment stops on the affected island for 30 seconds |
| Tree shelter | Far patch only; 30% / 60% less wind stress; no lightning protection |

Rain collection is deliberately dependable, even in otherwise ordinary weather. This makes Island 1 a place to learn refilling without waiting for a random rain event. Refill transfers only available tank water; a partially filled can can be topped up again. Island tanks are separate; the carried can travels with the farmer.

Existing wider tool areas remain as upgrade benefits. Larger can capacity means more **beds** watered between refills, even when one upgraded click works several beds. Only useful watering spends water; frozen beds and already hydrated, unthreatened patches do not consume it.

Irrigation uses three fixed patches instead of freely moving a zone. The permanent pipes make reach and cost predictable. Trees likewise shelter a fixed patch, with no movable screens. Hidden automatic irrigation modes and the invisible emergency well are retired.

Purchased tanks retain their existing passive drought and recovery-tax benefits so established purchases keep value. Barn and tree tax/storage benefits also remain. Current reductions are visible near the top of the weather station. Its optional details explain market rules; ordinary action cards show the relevant resource and result.

## Saves and verification

The earlier mechanics revision **18** preserved crops, coins, islands, equipment, tutorial progress and existing reserves. Older saves receive a full can at their saved tool rank. Existing tank owners receive a basic connected sprinkler if needed to preserve their previous area-watering ability. Legacy automatic flow is disabled and movable shelter becomes fixed. Invalid can capacities and malformed resource structures are rejected before changing the farm.

Targeted checks cover state conservation, migration/corruption, tool upgrades, partial area watering, travel, drought/flood/storm interactions, actual walk-to-refill, practice/save-resume, equipment geometry reuse and every crop ray target. Run with your Godot executable:

```sh
godot --headless --path . --script tests/test_farm_interaction.gd -- --integration-test
godot --headless --path . --script tests/test_ferry_access.gd -- --integration-test
godot --headless --path . --script tests/test_water_loop_state.gd
godot --headless --path . --script tests/test_water_loop_game.gd -- --integration-test
godot --headless --path . --script tests/test_climate_lesson.gd -- --integration-test
godot --headless --path . --script tests/test_climate_operations.gd
godot --headless --path . --script tests/test_climate_projects.gd -- --integration-test
```

For native screenshots, run `test_water_loop_game.gd` without `--headless`, with `-- --integration-test --capture`. Images go to ignored `artifacts/water-loop-*.png`.

The regular local Web ZIP and the isolated lab use single-threaded WebGL Compatibility. Native and browser visuals were inspected. On this Apple M4, Balanced mode: Safari's ordinary Island 1 sample measured 59.9 FPS at a 1919×1200 farm render size; Chrome's Island 2 ordinary/drought/flood samples measured 94.8 / 95.4 / 91.6 FPS at 1920×1200. These are different scenes and browsers, not a controlled before/after benchmark or a performance guarantee.

Broader regression runs also identified existing failures in old font, pest-timing, QoL migration-fixture and simulation seed-budget assertions. They were reproduced on the unchanged `a5dd41c` baseline; they are separate from the passing connected-water and climate suites.

## Pretest fixes: guide input, space and movement

The field console previously hid and re-showed its buttons on every refresh. A press spanning a refresh lost its release, explaining the intermittent invitation and sprinkler controls. It now updates visibility only to the final state and resizes only when its contents change. The new interaction regression sends actual mouse press/release events through the viewport, deliberately refreshing the HUD repeatedly while held; it fails on the prior implementation and passes with this fix. Chrome mouse QA also completed both invitation choices and the full practice.

Sprint eases between walking and running, works with keyboard and click routes, and preserves exact arrivals and menu input blocking. The persistent can follows the farmer's carrying hand, tilts for watering, and eases under the tank tap and back. Other tools ease into/out of their work stroke. Water fill animates during the transfer; upgrades keep their existing capacities. The practice destination gets a small world label and arrow only during its relevant step.

The earlier village expansion preserved crop coordinates, resources, equipment ranks and progression. Revision 19 now migrates shared irrigation and adds saved freeze/hoe-heat state. Village geometry, targets, camera limits, paths, shoreline drain outlets and ferry destinations use the expanded layout consistently. The lab includes all three islands and still forces isolated test mode.

Additional checks passed for mouse input, sprint/animation continuity, ferry access, camera zoom, tutorial scene/world, winter farming, equipment and responsive layouts. An older `test_tutorial_hud.gd` assertion about the Roll House panel overlapping the first-island guide also fails with the unchanged pretest HUD; it is separate from the fixed climate console input. Previous baseline issues listed above remain outside this change.

Expanded Island 1 browser sample during pretest QA: Chrome, Balanced, 1920×1200 farm render, 114.8 FPS (8.3 ms median, 10.0 ms p95). This is one local sample, not a controlled comparison. Browser window automation became unavailable after the full practice click-through, so final destination-pointer and scenery touch-ups were checked with native captures and release-export validation; no new flood/storm browser timing sample was obtained.


## Connected harbours and animated coasts

Every island now has a moored, clickable ferry, a short gangway and a continuous path to the boarding point. Click the ship or pier to walk over before opening travel; WASD and E work too. The little offshore destination islands are removed. The regular travel menu and unlock requirements are unchanged. On Golden Shores the small export boat remains separate from the passenger ferry.

Selected shops, the windmill and workshops are 10–16% larger. Their targets follow their size, while shopkeepers retain their human scale. Barns retain their size so the physical roof-gutter-tank connection remains aligned. Saved crop coordinates and progression are unchanged; this scenery change needs no save migration.

Water has moving shoreline foam, soft ripples and small glints. Each island has its own palette; Frosthollow has slower blue Arctic water and 36 softly bobbing ice floes, with a clear channel beside the ferry. Moored ferries rock gently. The water uses one opaque surface (1,152 triangles) and ice uses one instanced draw. There are no reflection passes, screen/depth texture reads, water physics, per-wave nodes or animation-time geometry rebuilds. This keeps the effect modest in WebGL/Safari.

### Test the local preview

1. Double-click **Play Climate Lab.command**. Choose each island in **Climate Lab · scenarios**.
2. Click the ship, or choose **Walk the path to the ferry**. Follow the farmer to the pier, close travel and walk back. Shift still sprints. Try E at the boarding point.
3. Inspect Island 3's ice and the clear ferry channel; watch the foam, glints and gentle boat motion on all three islands.
4. Choose **Mature farm · performance test**, then measure eight seconds in Balanced or Smooth. Toggle **Coastal water & ice** to compare the same scene. For a meaningful 60 FPS check, use Safari in the foreground with other GPU-heavy apps idle. This comparison never changes your saved farm.

Ferry regression checks cover clickable boats/piers, keyboard and click routes, return walks, unlock gating, tutorial guidance and the bounded/reused water geometry. The final native capture run passed 103 checks, including rendered frames and immediate sky/coast color synchronization. Climate lesson, farming input, climate equipment, tutorial world and winter farming regressions passed during this pass. Both the regular Web export and isolated lab remain local; no GitHub Pages files were published.

Safari on this M4 rendered all three coasts and completed Arctic ferry travel. Under concurrent GPU-heavy app load, observed eight-second samples were 48.9 FPS for Balanced Valley with coast on and 51.7 with coast off; Smooth mature Valley reached 55.1 FPS and Smooth Arctic reached 53.0 FPS. Scene time and background load varied, so these are **not** a controlled comparison. A sustained 60 FPS result is not verified under that load; the lab now provides the direct comparison for a quieter-machine check. Existing quality options are preserved rather than silently lowering everyone's graphics.
