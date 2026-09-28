# Taterland gameplay guide

[Play in your browser](https://coursemain.github.io/Taterwake/) — no download needed.

## Your first farm

New farms start with one short, saved harvest lesson: buy a Russet seed, hoe, plant, water, harvest and sell. **Your first sale ends the lesson.** All tools and shops then open, so you can grow and sell another crop independently.

Mara adds one of your three starter compost to that first planted Russet. Water it and watch a giant potato push out of the soil, then pull it up for the Farmer's real **3× harvest**. This uses the ordinary compost ability; reloading the lesson never spends it twice. Later giants use **Builds → Farmer → Grow a giant potato**. Harvests now tug, pop and scatter soil; giants land with a heavier thump.

Mara's seed counter has patched sacks and mismatched crates. Sell Potatoes uses the exchange's chalk buying board, with price, quantity and a sale confirmation. Builds opens the village field guide; Help is Nell's pinned barn notes. Loaded workshop batches appear in crates beside Ada, and reserved buyers walk in from the ferry and leave after delivery or expiry.

The lesson selects each tool for you and points at the bed. Click the gold bed to walk over and work it; choosing another empty bed at the hoe step moves the lesson there. Shops open by **clicking their building or sign** or using their shortcut. A small rounded E badge appears beside the nearest NPC or shop: press E or tap it to interact. Fields keep their normal tool action without a badge. E also works at the ferry. Blocked or unsuccessful actions explain what to do. Use **× → End tutorial** to leave early.

Afterwards, help stays in **H → Help** instead of floating over the farm. The first naturally appearing pest group cannot damage crops until cleared; press **5**, then click an infested bed. Later pests deal normal damage.

Automatic reminders to upgrade tools, hire ducks or recover debt no longer appear over the field. Open **H** for controls, farming instructions and current task help. Recovery orders remain available through **Repay debt** in shops and the Taxes page. Brief action feedback and red warnings still explain blocked actions, full storage or unavailable supplies.

Every island has a connected path to its ferry. Click the ferry or its sign to walk to the boarding area, or walk there with WASD and press **E**. Sailing requires the normal island unlocks.

The first lesson pauses random pests, taxes and weather; finishing starts fresh countdowns. **H → Optional Valley tour** lets you meet the NPCs whenever you choose. You may skip any stop or leave at any time. This informational tour pauses and preserves your existing farm, including pests and weather.


Return to the [project README](../README.md) for downloads and setup. Spud Valley is the name of your first island.

## Farming and controls

The three-line menu opens the market, inventory, builds, quests, upgrades, travel, collection, settings and Debug. The farm view keeps only essential farming controls and live information on screen. All keyboard shortcuts still work. The movement reminder and floating island/field titles have been removed from the farm view; the controls remain in How to play.

Farming is manual. Select a tool, then click a bed to walk over and work it, or press E beside it. Tools never choose the next task automatically.

Each island has a **Tool Upgrades** shop with a potato toolsmith. On Spud Valley and Golden Shores, look between the barn and market; Frosthollow's toolsmith works at the winter forge. Click the NPC, shop or sign to buy the same upgrades available through **U** or the menu. Rank 3 tools still require Frosthollow.

Handwritten signs use short names: **Seeds**, **Barn**, **Tools**, **Builds**, **Quests**, **Ducks** and **Ferry**. The tax card shows any pending tax bill; click it for your full forecast and bankruptcy limit.

Purchases show a short dark-and-gold confirmation card, matching the harvest-chain style. Seed receipts show how many you bought, the actual price paid and your new seed total. Repeated purchases of the same seed combine in one card instead of piling up. Tool, barn, field and duck upgrades also get confirmations; rejected purchases explain the problem without showing a success card.

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| 1 | Hoe / break winter ice |
| 2 | Equip seeds and open seed choices / tracked prices |
| 3 | Water |
| 4 | Harvest |
| 5 | Bug sprayer |
| E / Space | Interact with nearby NPC/shop, use selected tool beside a bed, or board the ferry |
| B | Buy Seeds |
| I / V | Illustrated inventory |
| U | Equipment upgrades |
| C | Player builds and abilities |
| Q | Local challenges |
| P | PotatoDex |
| F | Sell held raw potatoes of the selected crop |
| H / F1 | Guide |
| Mouse drag / two-finger trackpad scroll | Pan the map |
| One- or two-finger touch drag | Pan the map |
| Pinch / mouse wheel | Smooth map zoom |
| Home / Touch Tools → Recenter | Restore the camera |
| Escape | Close panel / open main menu |
| F5 / F9 | Save / load |

Saving keeps one previous farm in a `.bak` file. If a save is damaged or incompatible, the game sets it aside as `.rejected` and tells you; starting and saving a fresh farm leaves that rejected file intact. Each later rejected load replaces the older rejected file. The original legacy farm file remains untouched.

The farm keeps its angled orthographic 3D view. Drag anywhere on the island to smoothly pan the view; two-finger trackpad scrolling pans too. On touch screens, drag one finger to pan, or use two fingers to pan and pinch. Blank-ground taps do not move the farmer. Mouse wheels and native pinch gestures zoom. Camera movement stays within the island bounds, and Home or **Tools → Recenter** restores the starting view. Menus keep their own scrolling and block camera movement.

A smooth **60-second day–night–day cycle** changes the sky, sunlight and ambient light on all three islands. Nights stay readable for farming. It follows saved play time, keeps its phase when travelling, and does not alter crop growth.

Watered crops grow in real time. Base growth times are Russet **10s**, Golden **25s**, Giant **40s**, Radioactive **50s**, Sunburst **55s** and Icecap **60s**. Weather cannot push active growth beyond 60 seconds; dry or frozen crops still wait for water or thawing. Builds and furnace heat can make growth faster. Existing crops retain their percentage of growth when loading an older farm. Menus do not pause crops or quotes; closing the game adds no offline farming.

Manual equipment upgrades increase the area of a single action. Fast harvests build ×1, ×2, ×4, ×8 and ×16 chains, with a 3.5-second grace period. A full barn leaves the uncollected part of a harvest on the bed without granting its combo twice.

Pests use independent timers for each bed, rather than farm-wide waves. Each crop is protected for its first 40 seconds after planting. On becoming harvest-ready, it receives a uniformly random 15–90-second pest delay; pests appear only after both the crop-age protection and that delay have elapsed. Sprayers and ducks reset the bed’s delay, and saved games preserve the timers. Each 5-second attack removes one third of the crop’s original maximum yield: 3/3 → 2/3 → 1/3 → destroyed at 15 seconds. Spraying cannot restore eaten potatoes. Visible insects, bite particles, shaking crops, yield labels and warning sounds make attacks clear. Use the bug sprayer on the affected bed to stop further damage; clearing pests gives a fresh grace period. A separate three-chirp alarm warns about pests, repeats every six seconds while they remain, and stops when you clear them. Simultaneous attacks share one alarm; crop loss has its own descending sound. Tool audio cannot cut these warnings off. Insects remain clickable through the same bed target. A destroyed crop shows a brief “Crop lost” notice, then clears its label completely; revisiting the island does not resurrect old notices.

## The live crop market

Each variety has a fixed base price. Its live selling price follows a slow, deterministic ten-minute seasonal cycle between **85% and 115% of base**. This is a placeholder until the later sell/store redesign. Weather, export ships and Frostbreak rewards do not change these prices.

Press **2** or click the Seeds hotbar slot to show crop choices. Selecting another tool hides the seed tray.

**Buy Seeds** shows each seed price, the sale price per potato and owned quantities. Seeds cost **75% of the variety’s base price**, rounded to cents, throughout the cycle. Choose **Buy 1** or **Buy 5** to confirm a purchase.

**Sell Potatoes** shows one variety at a time. Swipe left/right or use the arrows; use **− / +**, edit the amount, or choose **Max**, then press the green **Sell** button. The amount stays within your available stock, and the payout follows the current quote while the page is open. Invalid amounts disable selling. A short receipt confirms the actual payout. Inventory sales and the existing **F** shortcut still work. Switching Buy/Sell tabs keeps the market session; completed Mara introductions stay remembered. Visit Mara's stall to talk again.

Both pages order varieties by their fixed base selling price: **Russet → Giant → Golden → Radioactive → Sunburst → Icecap**. Buy Seeds retains each island’s available seeds; Sell Potatoes includes known varieties and crops held in the barn. Live prices never reorder the pages.

## Three islands

| Island | Field | Progression |
| --- | --- | --- |
| Spud Valley | 24 beds; 12 initially open | Original farm. Learn manual tools and crop sales; grow toward millions. |
| Golden Shores | 48 beds | Unlock with $1M and 500 harvested potatoes. Double harvest yields and Sunburst potatoes; build toward hundreds of billions. |
| Frosthollow | 80 beds | Unlock with $100B and 25K harvested potatoes. Snow, Icecap potatoes, triple yields and expensive manual tools; pursue trillion and quadrillion harvests. |

Your fields persist independently. Coins, crops, tools and builds travel with you.

Golden Shores has randomly arriving export ships, with a warning before a five-second buying window. Ships use the ordinary selling price. Its shipment challenge rewards supplying separate ships, rather than repeatedly clicking one sale.

Frosthollow's **Frostbreak** freezes 12 beds for 20 seconds. Hoe all of them before time runs out to earn an Icecap seed. Waiting awards nothing; remaining ice melts without destroying crops. Winter challenges pause while you are away. Rank 3 tools cost $250B/$400B/$600B and work 5×5hoe areas, 7×7watering areas and five full harvest rows, before build bonuses.

Each island has local challenges around its farming and economic events. Claim completed rewards at its board.

Open the three-line menu or visit the new island station for these activities:

- **Every island — Duck patrol.** Two controls: **Flock size** hires one duck; **Patrol speed** trains that island's flock from **4s → 3s → 2s** per bed. Caps are **1 / 2 / 3 ducks** in the Valley / Shores / Frosthollow. First-duck costs are **$1.5K / $25M / $750B**; each additional duck costs another multiple of that base. Speed costs scale with the island too. Ducks chase separate pests while you visit and resume their routes when you return. Older saves keep every previously trained duck.
- **Golden Shores — Buyer contracts.** Pick a crop for a **bulk +25%** order. The offer shows the quantity needed and how much you hold. Accepting opens a shipment progress bar and a button showing the exact amount to deliver. Each shipment locks its live quote; finish the order to collect payment. No deadline. New buyer after 25 seconds.
- **Frosthollow — Potato furnace.** Burn **25 Icecaps** to get **2.5× winter growth and 3× processing for 20 seconds**. Heat affects watered winter crops and a loaded processor while you are on the winter island; it does not plant, harvest or shorten ability cooldowns. The furnace can fire once per minute. Heat cannot be stacked or refreshed early.

## Inventory and builds

The bottom-center five-slot hotbar contains usable tools only. Click a slot or press 1–5 to equip it. Inventory [I] has **Crops** and **Tools** tabs: illustrated seeds and harvested potatoes, plus the five usable farm tools. Raw potatoes stay held until you sell them. Production queues and processed batches remain on the Builds pages.

You begin as **Farmer**. All five specializations are available at level one and develop through **30 levels**. Select one in Builds [C]. Equipped harvest professions and completed build activities earn XP toward the next level. The Builds pages show XP progress; see [XP amounts](BUILD_PROFESSIONS.md#activity-rules-and-tradeoffs).

| Build | Focus and active ability |
| --- | --- |
| Farmer | Choose a growing bed and spend compost to grow one giant prize crop. Harvests replenish compost. |
| Gambler | Stake 5, 20 or 100 held crops at printed odds. Claim the result or spend a rechargeable charm to replace it. |
| Investor | Reserve a buyer's price for three minutes, then deliver the requested cargo. Repeat deliveries build reputation. |
| Scientist | Cross two crops into Honeyheart, Sundew or Frostgold. Keep discovered seed traits for every build. |
| Industrialist | Load 20 or 100 crops, match their process and stamp F–SSS export batches. Larger machines unlock queue slots. |

Builds opens an illustrated overview of all five paths, with your current build marked **Selected** and every build available. Click **Explore** to preview its appearance, controls, benefits and tradeoffs; browsing never changes your saved build. **Select build · Free** explicitly changes the active build. The introduction's **Meet the five builds** guide explains each path and switching. Exact passive bonuses and progression are folded into optional details. Switching is free; loaded production, reserved buyers and discovered varieties stay with you. Processing jobs, finished batches and unclaimed harvest stakes still occupy storage. Machines never plant, water or harvest the field for you.

Prize crops, seed-bank jars, machine additions, shipment carts and the carved charm appear on the farm. If an existing save has a tax bill already due, the collector walks from the ferry, collects after the remaining deadline, then leaves with a receipt. Clicking the visitor opens your tax information.

For disposable scenarios, open **Play Builds Lab.command**. See the [build activities and testing guide](BUILD_PROFESSIONS.md) for recipes, grades, save compatibility and test steps.

## Quests and the farmer

Quest rewards scale with the island economy: Valley pays $5K–$30K, Shores $200M–$5B, and Frosthollow $10T–$250T. Rewards are cash and, for the ground-breaking quests, seeds. Each can be claimed once, including after loading an older save.

The round potato farmer keeps a soft oval body, stubby limbs, blinking eyes and smoothly blended walking and turning. Villagers retain their fixed outfits and animated conversation portraits.

## PotatoDex

Press **P** for **Crop varieties**, an illustrated reference for all six potatoes with base growth times, home islands and mastery progress. Golden and Radioactive remain ordinary crop varieties.

## Graphics

Open **☰ → Graphics**, or use **⚙** on the tutorial card. **Balanced** keeps a clear farm with gentle shadows. **Smooth** draws a lighter farm without shadows. **Crisp** gives the sharpest farm and smoother edges, using more graphics power. Text, menus and icons stay sharp in every mode. Your choice is saved on this device separately from the farm.

If movement in Safari seems capped at 30 FPS, check **System Settings → Battery → Low Power Mode** and use Automatic/Never instead of Low Power while playing. Low Power Mode can also be enabled while plugged in. Try Chrome/Firefox or run the native Godot project if browser performance is still poor. The Web ZIP is still a browser build, not a native app. [Godot's browser guidance](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [Apple's power mode guide](https://support.apple.com/en-nz/101613).

To load a newly published version, close all Taterland tabs and reopen the play link; keep the same browser profile to retain your farm.

## Debug controls

Open **☰ → Debug** and enter the access code to unlock the controls for this session. Wrong codes leave the controls locked. Starting a new session or a new farm locks them again.

After bankruptcy, **Debug access** still accepts the session code. **Recover test farm** restores the chosen positive balance, keeps crops, inventory, builds and progression, and clears pending tax collection at 1× time. It preserves the previous receipt. **Try Again** instead starts a new farm.

### Climate action and taxes (v1.0.2)

Climate disasters begin on **Island 2**, introduced by a skippable changing-sky cutscene. Open the scanning **Weather & protection** station, the desktop weather shortcut, or **☰ → Weather & protection** for forecasts, visible protection stats and purchases. Buy sprinklers and irrigation once to carry them across all islands. Other protection purchases appear on their own island: a large rainwater tank, drainage around the beds, steel barn reinforcements and a living tree windbreak. Level two visibly improves each project. Every disaster gives **45 seconds of warning**, with a central alert and gathering clouds. Rain, wind and storm shake show the danger. Harvest exposed beds, protect storage and check the recovery-tax estimate. Droughts, floods, severe storms and Island 3 deep freezes damage crops and stored potatoes. The disaster lasts **30 seconds**, followed by **75 seconds of recovery** before calm weather. Protection reduces crop losses and the recovery bill.

The old tax rules remain temporarily for existing saves. Already-due bills finish collecting; removed market events no longer advance the tax counter. Base tax is 5% of the island progression baseline, with saved tax multipliers and weather pressure capped at 2.5× base. The annual ledger will replace this system in Segment 6.

| Island | Base tax | Maximum tax | Bankruptcy below |
| --- | --- | --- | --- |
| 1 | $50K | $125K | −$50K |
| 2 | $5B | $12.5B | −$5B |
| 3 | $250T | $625T | −$250T |

Seeds, tools, barn space, extra beds, ducks and weather equipment can be bought on **credit**, even with a negative balance. Buttons mark eligible tax-debt purchases with **On account**. Purchases cannot cross the current bankruptcy limit; new-island passage still requires cash.

Use **Repay debt** in a shop, or **Taxes → Recovery orders**, to exchange ordinary potatoes for debt repayment. Each potato repays 1% of your current debt limit, so 100 clear a fully used credit line. Deliveries start with Russets, keep surplus potatoes, and stop at zero debt. Market sales also repay debt normally. If you have no seeds, ordinary stored crops or growing crops, collect three free recovery seeds from the order page. Taxes and bankruptcy still apply.

The Weather Station has a scanning sensor tower and a navy/cyan console with live tank levels, recovery tax and a compact protection table. Equipment modules show their effect and purchase action; extra timing data is folded away.

Cash below the bill turns red. Unpaid taxes become debt; **only crossing bankruptcy ends the run**. Having 2× the bill earns OVERKILL, then larger reserves reach ULTRA KILL, GODLIKE, OMNIPOTENT and RULER. **☰ → Taxes** shows your forecast, projected balance and latest receipt. Returning to an easier island keeps the highest tax tier you have visited.

A collapse shows the cause, debt limit, losses and exact tax subtraction when tax caused the bankruptcy. **View Run Summary** reveals the run totals and climate context; **Try Again** starts a fresh farm. Authenticated **Debug access** can recover an isolated test farm while retaining its progress. Tutorials are protected from weather and tax pressure.


### Connected equipment and isolated testing

The water loop is **rain → tank → can or pipes → crops**. A starter can waters 16 beds; can upgrades carry more between trips. Click the tank, then **Refill watering can** to walk over and transfer water. Island 1 refills its reserve quickly and has no disasters. The tank and sprinklers share the same reserve. On Island 2, sprinklers water a fixed connected patch in ordinary weather; drought stops the tank replenishing. Select equipment to see its source, pipes and affected beds. See [the water-loop guide](CLIMATE_WATER_LOOP.md) for exact capacities and costs.

First arrival at Island 2 plays a 12-second changing-sky cutscene with subtitles; skip it at any time. After purchasing irrigation, optional water practice is available at the weather station. Practice pauses the real farm and uses temporary crops. It never grants free sprinklers.

On Island 3, **Deep Freeze** stops affected crops from growing, being watered or harvested. Open the furnace, choose **Heat thawing hoe**, then use **Hoe [1]** to melt crop ice. The bellows provide 60 seconds of heat without needing potatoes as fuel. Frostgold crops resist ice. Rescuing frozen crops prevents cold-stress losses; remaining ice melts after recovery. The separate Frostbreak challenge pauses during disasters.

- **Drought:** water dry crops; the shared tank reserve now matters.
- **Flood:** open purchased drains to send water through channels toward the sea; Hoe [1] drains individual planted beds.
- **Storm:** fixed trees shelter their highlighted patch from wind. A warned lightning row remains dangerous. Reinforced barn shutters close automatically.

Each build has one compact action page, with bonuses and progression behind a drawer. Farmer uses **1 compost on a planted, growing crop**. Click its action, then a glowing crop; water, grow and harvest normally for three times its usual yield. Ripe and frozen crops explain what to do instead. Escape or the visible Cancel button exits selection without spending compost. See [the profession guide](BUILD_PROFESSIONS.md) for the other four builds and their tradeoffs.

Double-click **Play Builds Lab.command** for a disposable farm with all five builds, supplied crops, an SSS batch preset, all three oceans, a tax collector scenario, a debt/bankruptcy scenario and an already-authenticated Debug workshop. Reload resets the lab. Double-click **Play Climate Lab.command** for water practice, ordinary farming, upgrades and weather scenarios. Neither lab reads or writes your saved farm. Hold **Shift** to sprint; use the lab's Balanced/Smooth controls and eight-second measurement for browser performance checks.

## NPC conversations

Interact with a staffed shop or station to greet its keeper in a close-up conversation, then choose their service to open it. Shop shortcuts follow the same order; the guided first-harvest tutorial keeps its direct steps. Mara, Bram, Nell, Tess, Pip, Ada, Captain Hollis, Iris, Oren and Edwin have different outfits, features and personalities. Stallholders stand at their counters or entrances and share their portrait appearances; Iris speaks through the weather station's radio link, and Oren is available at Frosthollow's furnace.

Choose a personal topic, ask about the weather, or open the shop. Replies lead to different lines, and NPCs remember introductions and friendly exchanges across saves. Conversations do not spend coins or grant gameplay bonuses. Weather advice reflects the current island and event.

Characters blink, gesture and move their mouths as text appears in an outlined speech bubble. Coloured name tags and golden service choices make the conversation easier to scan. Nearby interactions use a small white E keycap with a black outline. Tap the text or press **Space** to reveal the whole line; tap a choice, press **1–3**, or use **Tab / Enter**. **Leave × / Escape** ends the conversation. Farm, market, tax, weather and furnace timers pause while talking, then resume when you leave. The portrait stops rendering when closed.


Mechanics revision 23 removes wearable items, passive collectibles and special mutations. Old stored mutation potatoes become ordinary potatoes of the same variety and quantity. Existing money and surviving quest/build progress remain. Barn capacity comes from barn upgrades alone; an older overfull barn keeps every potato but cannot accept another harvest until there is room. Unfinished mutation contracts become ordinary crop orders, keeping completed deliveries and earned credit.
