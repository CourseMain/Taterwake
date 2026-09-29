# Taterland gameplay guide

This guide describes **v2.0.0 (in development)**, the redesign source prerelease. The [published browser game](https://coursemain.github.io/Taterwake/) still runs the previous v1.0.3.1 rules.

## Your first farm

Spud Valley is the only playable farm: **12 open beds and 12 locked beds** in one six-by-four field. New farms start with **2,000 Spudions** and one short, saved harvest lesson: buy a Russet seed, hoe, plant, water, harvest and sell. **Your first sale ends the lesson.** All tools and shops then open, so you can grow and sell another crop independently.

Plant Mara’s Russet seed, water it and pull the ripe crop into your barn. Harvests tug, pop and scatter soil; the ordinary Giant variety lands with a heavier thump.

Mara's seed counter has patched sacks and mismatched crates. Sell Potatoes uses the exchange's chalk buying board, with price, quantity and a sale confirmation. Help is Nell’s pinned barn notes.

The lesson selects each tool for you and points at the bed. Click the gold bed to walk over and work it; choosing another empty bed at the hoe step moves the lesson there. Shops open by **clicking their building or sign** or using their shortcut. A small rounded E badge appears beside the nearest NPC or shop: press E or tap it to interact. Fields keep their normal tool action without a badge. Blocked or unsuccessful actions explain what to do. Use **× → End tutorial** to leave early.

Afterwards, help stays in **H → Help** instead of floating over the farm. The first naturally appearing pest group cannot damage crops until cleared; press **5**, then click an infested bed. Later pests deal normal damage.

Automatic reminders to upgrade tools, hire ducks or recover debt no longer appear over the field. Open **H** for controls, farming instructions and current task help. Brief action feedback and red warnings still explain blocked actions, full storage or unavailable supplies.

The first lesson pauses random pests and weather; finishing starts fresh countdowns. **H → Optional Valley tour** lets you meet the NPCs whenever you choose. You may skip any stop or leave at any time. This informational tour pauses and preserves your existing farm, including pests and weather.


Return to the [project README](../README.md) for downloads and setup. Spud Valley is your farm.

## Farming and controls

The three-line menu opens the market, inventory, quests, upgrades, collection, settings and Debug. The farm view keeps only essential farming controls and live information on screen. All keyboard shortcuts still work. The movement reminder and floating island/field titles have been removed from the farm view; the controls remain in How to play.

Farming is manual. Select a tool, then click a bed to walk over and work it, or press E beside it. Tools never choose the next task automatically.

Spud Valley’s **Tool Upgrades** shop sits between the barn and market. Click Bram, his shop or its sign, or press **U**. All three upgrade ranks are available on the farm.

Handwritten signs use short names: **Seeds**, **Barn**, **Tools**, **Quests**, **Ducks** and **Weather**.

Purchases show a short dark-and-gold confirmation card. Seed receipts show how many you bought, the actual price paid and your new seed total. Repeated purchases of the same seed combine in one card instead of piling up. Tool, barn, field and duck upgrades also get confirmations; rejected purchases explain the problem without showing a success card.

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| 1 | Hoe / clear crop ice |
| 2 | Select seeds and open seed choices |
| 3 | Water |
| 4 | Harvest |
| 5 | Bug sprayer |
| E / Space | Interact with nearby NPC/shop, use selected tool beside a bed |
| B | Buy Seeds |
| I / V | Illustrated inventory |
| U | Equipment upgrades |
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

New farms use `user://taterland_save_v4.json`. Older farms are not loaded or migrated, and the original v2/v3 files stay untouched. Saving keeps one previous v4 farm in `.bak`. Damaged or incompatible candidates are set aside as `.rejected`; a fresh farm’s autosave leaves that rejected file intact. Each later rejected load replaces the older rejected file.

The farm keeps its angled orthographic 3D view. Drag anywhere on the island to smoothly pan the view; two-finger trackpad scrolling pans too. On touch screens, drag one finger to pan, or use two fingers to pan and pinch. Blank-ground taps do not move the farmer. Mouse wheels and native pinch gestures zoom. Camera movement stays within the island bounds, and Home or **Tools → Recenter** restores the starting view. Menus keep their own scrolling and block camera movement.

The run lasts **ten years**. Spring, Summer and Autumn each last **150 seconds** of working time. The top strip shows the season and year; the sun moves from dawn to dusk through each season, so the sky shows how much working time remains. The calendar and sun resume their saved position after loading.

**Winter pauses the farm** and opens the annual accounts: every income and spending category, the year’s net and a running ten-year table on a plain cream page. Press **Start next year** to return to Spring. Escape still closes the panel, and the farm menu always offers a route back to Winter. After year 10’s accounts, **Ten-year summary** shows the total net, years in profit, best and worst year, final purse and remaining loan. The epilogue is still to come; **New Run** starts over. Every season boundary saves before its menu opens, including the Winter bill and any foreclosure. The year strip and Winter panel follow the current calendar even at accelerated debug speed; dismissing Winter keeps it closed until you reopen it.

Watered crops grow in real time. Base growth times are Russet **75s**, Golden **105s**, Giant **135s**, Radioactive **165s**, Sunburst **195s** and Icecap **225s**. Russet ripens in half a season; Icecap needs a season and a half. Weather can slow growth up to 450 seconds of active growing time; dry or frozen crops wait for water or thawing.

Till and plant only in **Spring and Summer**. Autumn is for tending and harvesting. At the end of Autumn, every unharvested crop is lost and prepared beds are cleared. The Winter panel reports how many beds were lost to the cold. Potatoes already in the barn are safe from this seasonal clearing.

Ordinary shop and menu panels keep working time running. Conversations, weather practice and the collapse page pause it. The first-harvest lesson protects the calendar while its crops grow; the optional tour pauses all farming. Winter pauses crops, pests, weather and prices. Closing the game adds no offline farming.

Manual tool upgrades increase the area of a single action. Each healthy bed yields **3–5 sacks**. A full barn leaves the uncollected part on the bed; harvesting the remainder never creates extra sacks.

Pests use independent timers for each bed, rather than farm-wide waves. Each crop is protected for its first 40 seconds after planting. On becoming harvest-ready, it receives a uniformly random 15–90-second pest delay; pests appear only after both the crop-age protection and that delay have elapsed. Sprayers and ducks reset the bed’s delay, and saved games preserve the timers. Each 5-second attack removes one third of the crop’s original maximum yield: 3/3 → 2/3 → 1/3 → destroyed at 15 seconds. Spraying cannot restore eaten potatoes. Visible insects, bite particles, shaking crops, yield labels and warning sounds make attacks clear. Use the bug sprayer on the affected bed to stop further damage; clearing pests gives a fresh grace period. A separate three-chirp alarm warns about pests, repeats every six seconds while they remain, and stops when you clear them. Simultaneous attacks share one alarm; crop loss has its own descending sound. Tool audio cannot cut these warnings off. Insects remain clickable through the same bed target. A destroyed crop shows a brief “Crop lost” notice, then clears its label completely; reloading does not resurrect old notices.

## Annual accounts

Your purse is **2,000 starting Spudions plus every ledger entry**. Sales, seeds, upgrades, protection, ducks, quest payments and Debug adjustments all enter that same journal. The accounts show cash flow, including mortgage principal; net means income minus every payment that year. Opening cash is not income.

Every Winter posts these fixed costs once:

| Cost | Spudions per year |
| --- | ---: |
| Mortgage interest | 1,000 |
| Mortgage principal | 1,000 |
| Rent and land tax | 500 |
| Living costs | 1,500 |
| Equipment upkeep | 500 |
| **Total** | **4,500** |

The mortgage starts at **20,000**. Each Winter’s principal payment reduces it by 1,000; the ten-year model keeps interest at 1,000 per year. Reloading the accounts never charges the bill again. Winter purchases still appear in that year’s accounts. Categories for later systems remain visible with zero totals until used.

Ledger saves use mechanics revision **29**. Pre-ledger saves, including revision 28, are incompatible and are set aside with the existing rejected-save protection; they are not converted into invented transaction histories.

## The live crop market

| Variety | Base Spudions per sack | Sacks per healthy bed |
| --- | ---: | ---: |
| Russet | 15 | 3 |
| Giant | 18 | 5 |
| Golden | 21 | 4 |
| Radioactive | 24 | 4 |
| Sunburst | 27 | 3 |
| Icecap | 30 | 3 |

Tool upgrades cost **300–1,500 Spudions**. Opening the remaining beds costs **1,200** once. The barn has three upgrades costing **300, 800 and 2,000**, for capacities of **400, 1,200 and 4,400 sacks**.

Each variety has a fixed base price. Its live selling price follows a slow, deterministic ten-minute seasonal cycle between **85% and 115% of base**. This is a placeholder until the later sell/store redesign. Weather does not change these prices.

Press **2** or click the Seeds hotbar slot to show crop choices. Selecting another tool hides the seed tray.

**Buy Seeds** shows each seed price, the sale price per potato and owned quantities. Seeds cost **75% of the variety’s base price**, calculated to cents, throughout the cycle. Money displays as rounded integers with thousands separators and the Spudion glyph; transactions retain their exact fractional value. Choose **Buy 1** or **Buy 5** to confirm a purchase.

**Sell Potatoes** shows one variety at a time. Swipe left/right or use the arrows; use **− / +**, edit the amount, or choose **Max**, then press the green **Sell** button. The amount stays within your available stock, and the payout follows the current quote while the page is open. Invalid amounts disable selling. A short receipt confirms the actual payout. Inventory sales and the existing **F** shortcut still work. Switching Buy/Sell tabs keeps the market session; completed Mara introductions stay remembered. Visit Mara's stall to talk again.

Every Buy Seeds and Sell Potatoes card includes a small, unanimated sparkline of up to **12 recent sale quotes**. Beside the live sale price, a signed percentage compares it with the variety’s base price: green above base, red below, neutral at base. The top bar shows the same comparison for the selected crop. Seed costs stay fixed; their cards show the sale-price history to help choose what to plant.

Both pages order varieties by their fixed base selling price: **Russet → Giant → Golden → Radioactive → Sunburst → Icecap**. Buy Seeds offers all six varieties; Sell Potatoes includes known varieties and crops held in the barn. Live prices never reorder the pages.

## The Valley farm

A single **1,200-Spudion expansion** opens the twelve locked beds. Coins, crops, tools, water supplies and protection belong to this one farm. Sunburst and Icecap are ordinary varieties available at the seed counter.

Visit Pip’s **Duck patrol** to hire up to **two ducks**. The first costs **500 Spudions**, the second **1,000**. Train the flock for **800** and **1,500** to reduce time per bed from **4s → 3s → 2s**. Ducks patrol distinct infested beds; their routes survive saving and loading.

The quest board rewards buying ten seeds, selling ten potatoes and harvesting twelve beds. Claim each completed task once.

## Inventory

The bottom-center five-slot hotbar contains usable tools only. Click a slot or press 1–5 to equip it. Inventory [I] has **Crops** and **Tools** tabs: illustrated seeds and harvested potatoes, plus the five usable farm tools. Raw potatoes stay held until you sell them.

## Quests and the farmer

Each of the three quest-board tasks pays a flat **100 Spudions**. Each reward can be claimed once, including after reloading. Harvest-bed quests count cumulative manual harvests without a timing requirement.

The round potato farmer keeps a soft oval body, stubby limbs, blinking eyes and smoothly blended walking and turning. Villagers retain their fixed outfits and animated conversation portraits.

## PotatoDex

Press **P** for **Crop varieties**, an illustrated reference for all six potatoes with base growth times and yield per bed. Golden and Radioactive remain ordinary crop varieties.

## Graphics

Open **☰ → Graphics**, or use **⚙** on the tutorial card. **Balanced** keeps a clear farm with gentle shadows. **Smooth** draws a lighter farm without shadows. **Crisp** gives the sharpest farm and smoother edges, using more graphics power. Text, menus and icons stay sharp in every mode. Your choice is saved on this device separately from the farm.

If movement in Safari seems capped at 30 FPS, check **System Settings → Battery → Low Power Mode** and use Automatic/Never instead of Low Power while playing. Low Power Mode can also be enabled while plugged in. Try Chrome/Firefox or run the native Godot project if browser performance is still poor. The Web ZIP is still a browser build, not a native app. [Godot's browser guidance](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [Apple's power mode guide](https://support.apple.com/en-nz/101613).

To load a newly published version, close all Taterland tabs and reopen the play link; keep the same browser profile to retain your farm.

## Debug controls

Open **☰ → Debug** and enter the access code to unlock the controls for this session. Wrong codes leave the controls locked. Starting a new session or a new farm locks them again.

After foreclosure, **Debug access** still accepts the session code. Before year 10, **Recover test farm** posts a balance adjustment, keeps the journal and paid Winter bills, and returns to the Winter accounts at 1× time. Press **Start next year** to resume farming. Year 10 remains finished. **Try Again** starts a new farm with an empty journal.

### Climate action and bankruptcy

Weather can threaten Spud Valley from the first season. For now, each working season has a **15% chance** of starting a disaster when weather is calm. Winter ends active weather and has no disaster draw. Drought, flood, severe storm and deep freeze can all occur here. Each gives **45 seconds of warning**, **30 seconds of danger**, then **75 seconds of recovery**. Open the **Weather & protection** station or menu page to buy irrigation, a larger tank, drainage, barn reinforcement and windbreaks. Protection reduces losses; each project has two levels.

The bank lets purchases take the purse down to **−5,000 Spudions**. A purchase that would cross that limit is refused. At the end of Autumn, the complete Winter bill is posted first; a resulting balance **strictly below −5,000** forecloses the farm. Exactly −5,000 survives. Foreclosure is checked at that annual boundary, not on each midyear balance change.

The Weather Station has a scanning sensor tower and a navy/cyan console with live tank levels and a compact protection table. Equipment modules show their effect and purchase action; extra timing data is folded away.

The foreclosure page shows the accounting year, cause, year net, Winter bill, debt limit, weather losses and final balance. **View Run Summary** reveals that year’s category totals and climate context; **Try Again** starts a fresh farm. Authenticated **Debug access** can recover an isolated test farm while retaining its progress. Tutorials are protected from weather pressure.


### Connected equipment and isolated testing

The water loop is **rain → tank → can or pipes → crops**. A starter can waters 16 beds; upgrades increase its capacity. Click the tank, then **Refill watering can** to walk over and transfer water. Sprinklers and the can share the same reserve. Sprinklers water their fixed connected patch, while drought stops rain replenishment. Select equipment to see its source, pipes and affected beds.

After purchasing irrigation, optional water practice is available at the weather station. It pauses the real farm and uses temporary crop visuals; it does not give free irrigation.

**Deep Freeze** stops affected crops from growing, being watered or harvested. Use **Hoe [1]** to clear crop ice directly. Rescue prevents cold-stress losses; remaining ice melts after recovery.

- **Drought:** water dry crops; the shared tank reserve now matters.
- **Flood:** open purchased drains to send water through channels toward the sea; Hoe [1] drains individual planted beds.
- **Storm:** fixed trees shelter their highlighted patch from wind. A warned lightning row remains dangerous. Reinforced barn shutters close automatically.

Double-click **Play Climate Lab.command** for disposable water practice, ordinary farming, upgrades and weather scenarios. It never reads or writes your saved farm. Hold **Shift** to sprint.

## NPC conversations

Interact with a staffed shop or station to greet its keeper in a close-up conversation, then choose their service to open it. Shop shortcuts follow the same order; the guided first-harvest tutorial keeps its direct steps. Mara, Bram, Nell, Tess, Pip, Iris and Edwin have different outfits, features and personalities. Stallholders stand at their counters or entrances and share their portrait appearances; Iris speaks through the weather station's radio link.

Choose a personal topic, ask about the weather, or open the shop. Replies lead to different lines, and NPCs remember introductions and friendly exchanges across saves. Conversations do not spend coins or grant gameplay bonuses. Weather advice reflects the current weather event.

Characters blink, gesture and move their mouths as text appears in an outlined speech bubble. Coloured name tags and golden service choices make the conversation easier to scan. Nearby interactions use a small white E keycap with a black outline. Tap the text or press **Space** to reveal the whole line; tap a choice, press **1–3**, or use **Tab / Enter**. **Leave × / Escape** ends the conversation. Farm, market and weather timers pause while talking, then resume when you leave. The portrait stops rendering when closed.
