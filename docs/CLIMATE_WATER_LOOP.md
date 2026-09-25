# Connected water and weather — local preview

This build is local and unpublished. Double-click **Play Climate Lab.command** in the repository to build and open a disposable browser farm. The lab never reads or saves your real farm. Its **Climate Lab · scenarios** button switches between six fresh scenarios; selecting a scenario closes the lab controls so you can see the farm.

## Try it

1. **Island 1 · tank, can, crops:** select Water [3] and click beds. The starter can carries 16 water, one per bed. The Water button and farmer show the remaining count. After 16 beds, click the highlighted tank. The farmer walks to its tap, the can fills, and the prompt disappears. Watch roof rain replenish the tank. **Empty can · test first refill** skips straight to this check.
2. **Island 2 · ordinary sprinklers:** click one of the three gold sprinkler heads along the field's left edge. Follow its highlighted source, pipe and fixed patch; click **Water these beds · 6 water**. Soil darkens and crops grow. The tank supplies the sprinkler directly; the carried can stays unchanged. Repeating the action on hydrated beds spends nothing.
3. **Island 2 · optional practice:** accept the short invitation, water the glowing bed, then click the near sprinkler and use its action. Real crops, bills and market clocks pause. Skip at any time; the first natural disaster is a dry spell after preparation time.
4. **Dry spell:** use the familiar can and sprinklers on drooping crops. Water lowers danger rings. The tank stops replenishing during the 30-second drought, so harvest ripe crops and choose which patches to rescue. Rain returns afterward.
5. **Flood:** click the gate at the front-left field corner, or **Show drain gate**. **Open drain** raises the gate, lowers flood danger and sends water through the channel to the sea. Hoe [1] still drains individual planted beds.
6. **Storm:** trees automatically shelter the far patch immediately behind them. Click trees to see the shelter area; protected crops sway less. Reinforced barn shutters slide closed automatically. The gold lightning row remains vulnerable: harvest it before the strike.

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

Purchased tanks retain their existing passive drought and recovery-tax benefits so established purchases keep value. Barn and tree tax/storage benefits also remain. Exact reductions and market rules are available in the shop's optional details; ordinary action cards show just the relevant resource and result.

## Saves and verification

Mechanics revision **18** preserves crops, coins, islands, equipment, tutorial progress and existing reserves. Older saves receive a full can at their saved tool rank. Existing tank owners receive a basic connected sprinkler if needed to preserve their previous area-watering ability. Legacy automatic flow is disabled and movable shelter becomes fixed. Invalid can capacities and malformed resource structures are rejected before changing the farm.

Targeted checks cover state conservation, migration/corruption, tool upgrades, partial area watering, travel, drought/flood/storm interactions, actual walk-to-refill, practice/save-resume, equipment geometry reuse and every crop ray target. Run with your Godot executable:

```sh
godot --headless --path . --script tests/test_water_loop_state.gd
godot --headless --path . --script tests/test_water_loop_game.gd -- --integration-test
godot --headless --path . --script tests/test_climate_lesson.gd -- --integration-test
godot --headless --path . --script tests/test_climate_operations.gd
godot --headless --path . --script tests/test_climate_projects.gd -- --integration-test
```

For native screenshots, run `test_water_loop_game.gd` without `--headless`, with `-- --integration-test --capture`. Images go to ignored `artifacts/water-loop-*.png`.

The regular local Web ZIP and the isolated lab use single-threaded WebGL Compatibility. Native and browser visuals were inspected. On this Apple M4, Balanced mode: Safari's ordinary Island 1 sample measured 59.9 FPS at a 1919×1200 farm render size; Chrome's Island 2 ordinary/drought/flood samples measured 94.8 / 95.4 / 91.6 FPS at 1920×1200. These are different scenes and browsers, not a controlled before/after benchmark or a performance guarantee.

Broader regression runs also identified existing failures in old font, pest-timing, QoL migration-fixture and simulation seed-budget assertions. They were reproduced on the unchanged `a5dd41c` baseline; they are separate from the passing connected-water and climate suites.
