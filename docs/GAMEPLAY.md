# Taterland gameplay guide

[Play in your browser](https://coursemain.github.io/Taterwake/) — no download needed.

## Your first farm

New farms start a saved, step-by-step Valley tutorial: move around, buy one Russet seed, hoe a marked bed, plant, water, harvest and sell. Then meet the inventory, toolsmith, Wash & Sort workshop, challenge keeper, Roll House, Duck Patrol and dock. Tools and interface elements appear as they are introduced, with gentle sound cues. The guided tour leaves the rest of Island 1 for you to discover.

Follow the gold trail and highlighted buttons. Each lesson shows one short action, a tool icon and progress. The large gold button advances the tour when ready. The small **×** opens **Keep learning / End tutorial**, so one accidental click cannot skip the guide.

Every island has a connected path to its ferry. Click the ferry or its sign to walk to the boarding area, or walk there with WASD and press **E**. The Valley path goes around the Roll House and through an opening in the fence. You can visit the dock during the tutorial; sailing still requires the normal island unlocks.

Random pests and stock surges pause during the guide. One practice pest appears only after its introduction and cannot damage your crops. On completion or skip, normal hazards resume with fresh countdowns; the first scheduled stock surge is three minutes away. You can skip or resume the saved guide. Established farms can use **☰ → First island guided tour** in the Valley for an informational replay that pauses and preserves their existing farm.


Return to the [project README](../README.md) for downloads and setup. Spud Valley is the name of your first island.

## Farming and controls

The three-line menu opens the market, inventory, builds, quests, upgrades, Roll House, travel, collection, price tracking, settings and Debug. The farm view keeps only essential farming controls and live information on screen. All keyboard shortcuts still work. The movement reminder and floating island/field titles have been removed from the farm view; the controls remain in How to play.

Farming is manual. Select a tool, then click a bed to walk over and work it, or press E beside it. Tools never choose the next task automatically.

Each island has a **Tool Upgrades** shop with a potato toolsmith. On Spud Valley and Golden Shores, look between the barn and market; Frosthollow's toolsmith works at the winter forge. Click the NPC, shop or sign to buy the same upgrades available through **U** or the menu. Rank 3 tools still require Frosthollow.

Purchases show a short dark-and-gold confirmation card, matching the harvest-chain style. Seed receipts show how many you bought, the actual price paid and your new seed total. Repeated purchases of the same seed combine in one card instead of piling up. Tool, barn, field and duck upgrades also get confirmations; rejected purchases explain the problem without showing a success card.

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| 1 | Hoe / break winter ice |
| 2 | Equip seeds and open seed choices / tracked prices |
| 3 | Water |
| 4 | Harvest |
| 5 | Bug sprayer |
| E / Space | Use selected tool on nearby bed / board nearby ferry |
| B | Market |
| I / V | Illustrated inventory |
| U | Equipment upgrades |
| R | Roll House |
| C | Player builds and abilities |
| Q | Local challenges |
| P | PotatoDex |
| F | Sell held raw potatoes of the selected crop |
| H / F1 | Guide |
| Two-finger scroll / trackpad pinch / mouse wheel | Smooth map zoom |
| Escape | Close panel / open main menu |
| F5 / F9 | Save / load |

Two-finger vertical scrolling, native pinch gestures and mouse wheels zoom smoothly. Fine trackpad scroll amounts are preserved, and a wider zoom range exposes the surrounding buildings. Scrolling inside a menu stays within that menu.

A smooth **60-second day–night–day cycle** changes the sky, sunlight and ambient light on all three islands. Nights stay readable for farming. It follows saved play time, keeps its phase when travelling, and does not alter crop growth or stock timing.

Watered crops grow in real time. Growth times are unchanged by the slower market clock: Russet 10s, Golden 30s, Giant 45s, Radioactive 90s, Sunburst 45s and Icecap 60s. Earned build bonuses can improve growth speed. Menus do not pause crops or quotes; closing the game adds no offline farming.

Manual equipment upgrades increase the area of a single action. Fast harvests build ×1, ×2, ×4, ×8 and ×16 chains, with a 3.5-second grace period. A full barn leaves the uncollected part of a harvest on the bed without granting its combo twice.

Pests appear on planted fields at random 25–100-second intervals and when ripe crops are unattended for 25 seconds. Each 5-second attack removes one third of the crop’s original maximum yield: 3/3 → 2/3 → 1/3 → destroyed at 15 seconds. Spraying cannot restore eaten potatoes. Visible insects, bite particles, shaking crops, yield labels and warning sounds make attacks clear. Use the bug sprayer on the affected bed to stop further damage; clearing pests gives a fresh grace period. A separate three-chirp alarm warns about pests, repeats every six seconds while they remain, and stops when you clear them. Simultaneous attacks share one alarm; crop loss has its own descending sound. Tool and gambling audio cannot cut these warnings off. Insects remain clickable through the same bed target. A destroyed crop shows a brief “Crop lost” notice, then clears its label completely; revisiting the island does not resurrect old notices.

## The live crop market

Quotes refresh every **three seconds on Island 1**, with slightly more upward movement, and every **five seconds on Islands 2 and 3**. Brief market events vary their target and strength, then expire. Normal quotes cap at **+2,999%** in the Valley and Shores, **+10,000%** in Frosthollow.

Every **3 minutes**, the selected crop gets a **10-second stock boom**: **+500–2,999%** in the Valley and Shores, **+3,000–10,000%** in Frosthollow. Higher percentages become smoothly rarer all the way to the ceiling. Without bonuses, the four equal quarters of any boom range have approximately **57.8% / 29.7% / 10.9% / 1.6%** of rolls, from lowest to highest. Luck and equipped stock gear modestly improve scheduled and rocket rolls while preserving that downward trend. These are magnitude odds after a boom triggers, not trigger chances. The timer flashes in the final 10 seconds. Outside active booms and spikes, each eligible fresh quote has a **1.5% chance** of a ten-second selected-crop spike: **+2,000–2,999%** early, **+7,000–10,000%** in winter. Natural spike chance and strength do not depend on luck, gear, builds or debug luck. Sampled boom quotes are final: export, thaw, roll and flash-offer multipliers do not stack onto them. Seeds track the final sell quote, and every temporary boost expires. Timers and active quotes survive saving.

Press **2** or click the Seeds hotbar slot to show crop choices and tracked seed quotes. Selecting another tool hides both strips. Use **Tracked Seed Prices** in the menu to choose which seed quotes appear in this tray. Your choices are saved; price changes show old → new values with green/up or red/down feedback.

Seeds normally cost **45% of the live crop quote × base plant yield**, before discounts or seed premiums. A huge crop quote therefore also makes its seeds expensive. Combos, mastery, mutations and build choices reward actual farming.

The selected crop at the top of the screen controls the market feedback. Mist begins above **+300%**, bigger rhythmic effects at **+500%**, and a musical jackpot at **+3,000%**. Green belongs to Spud Valley, gold to Golden Shores, and icy blue to Frosthollow. The center stays readable for farming and trading.

## Three islands

| Island | Field | Progression |
| --- | --- | --- |
| Spud Valley | 24 beds; 12 initially open | Original farm. Learn manual tools and market timing; grow toward millions. |
| Golden Shores | 48 beds | Unlock with $1M and 500 harvested potatoes. Double harvest yields and Sunburst potatoes; build toward hundreds of billions. |
| Frosthollow | 80 beds | Unlock with $100B and 25K harvested potatoes. Snow, Icecap potatoes, triple yields and expensive manual tools; pursue trillion and quadrillion harvests. |

Your fields persist independently. Coins, crops, tools, collectibles and builds travel with you.

Golden Shores has randomly arriving export ships, with a warning before a five-second buying window. Prices return to ordinary quotes when the ship leaves. Its shipment challenge rewards supplying separate ships, rather than repeatedly clicking one sale.

Frosthollow's **Frostbreak** freezes 12 beds for 20 seconds. Hoe all of them before time runs out to earn an Icecap seed and a five-second ×8 Thaw Auction. Waiting awards nothing; remaining ice melts without destroying crops. Winter challenges pause while you are away. Rank 3 tools cost $250B/$400B/$600B and work 5×5hoe areas, 7×7watering areas and five full harvest rows, before build bonuses.

Each island has local challenges around its farming and economic events. Claim completed rewards at its board.

Open the three-line menu or visit the new island station for these activities:

- **Every island — Duck patrol.** Two controls: **Flock size** hires one duck; **Patrol speed** trains that island's flock from **4s → 3s → 2s** per bed. Caps are **1 / 2 / 3 ducks** in the Valley / Shores / Frosthollow. First-duck costs are **$1.5K / $25M / $750B**; each additional duck costs another multiple of that base. Speed costs scale with the island too. Ducks chase separate pests while you visit and resume their routes when you return. Older saves keep every previously trained duck.
- **Golden Shores — Buyer contracts.** Pick a crop, then compare two buyer cards: **bulk +25%** or **mutations +50%**. Each shows the quantity needed and how much you hold. Accepting opens a shipment progress bar and a button showing the exact amount to deliver. Each shipment locks its live quote; finish the order to collect payment. No deadline. New buyer after 25 seconds.
- **Frosthollow — Potato furnace.** Burn **25 Icecaps** to get **2.5× winter growth and 3× processing for 20 seconds**. Heat affects watered winter crops and a loaded processor while you are on the winter island; it does not plant, harvest or shorten ability cooldowns. The furnace can fire once per minute. Time it against the stock countdown; heat cannot be stacked or refreshed early.

## Inventory and builds

The bottom-center five-slot hotbar contains usable tools only. Click a slot or press 1–5 to equip it. Inventory [I] contains illustrated seeds, raw crops, mutation crates, permanent items, build cards, build crates and processed batches, each with distinct artwork. Raw and processed potatoes stay held until you choose to sell them.

You begin as **Farmer**. Opening owned Build Crates can unlock and develop five specializations, each with **30 levels**. Paid rolls only award sealed crates, never build levels directly. Select one in Builds [C].

| Build | Focus and active ability |
| --- | --- |
| Farmer | Yield, faster growth and wider manual tool areas. Spend held crops on temporary field dressing. |
| Gambler | Reward quality and mutations. Pay to scout the next roll's odds. |
| Investor | Seed discounts and positive-market opportunities. Pay to call a temporary crop buyer. |
| Scientist | Mutation chances and research. Experiment using 20 held potatoes. |
| Industrialist | Load 100 potatoes into a batch processor. The machine grades that batch while you farm; sell the finished goods when you choose. |

Processing jobs and finished batches still occupy storage. Machines never plant, water or harvest the field for you.

Every paid roll also has an independent **5% chance of a Build Crate**. Open it from Inventory for a separate, build-only illustrated reward reel. Ownership is checked by the game simulation before RNG runs. The crate is consumed before its single reward is granted, overlapping requests are blocked, and its result is saved immediately. Requests without a crate show “You need a Build Crate.” Fully developed builds preserve unused crates.

## Roll House

Only earned fictional coins are used. There are no purchases, deposits, cash-outs or real-money connections.

| Newest unlocked island | Normal | Big | Stupid |
| --- | ---: | ---: | ---: |
| Spud Valley | $200 | $2K | $20K |
| Golden Shores | $2M | $20M | $200M |
| Frosthollow | $20T | $200T | $2Qa |

All-in uses your current purse and needs two deliberate presses. It requires **more than $200 on Spud Valley, more than $2M on Golden Shores, and more than $60T on Frosthollow**. Exactly $60T still buys three normal winter rolls, but cannot be used for All In. The button and the game simulation enforce the same minimum, including the confirmation press. Unlocking a new island retires the previous Roll Houses. Larger wagers increase reward quality by a displayed logarithmic percentage with no fixed cap. Permanent luck is capped at 10× outside explicit debug controls.

After the reveal, a receipt shows **Spent, Returned and Balance**, including consolation refunds, duplicate trade-ins and jackpots. All In charges the entire purse before rewards: a `$1e20` wager followed by the 10% consolation refund leaves `$1e19`. Free Crown pulls can also return coins; the receipt includes every result in that purchase.

Luck shifts probability toward higher rarity tiers, rather than increasing every non-common tier equally. The displayed odds, actual reward selection and reel previews use the same current tier probabilities. Decorative cards do not grant rewards: the reel lands on the actual single result, or the best result in a batch whose full results appear below. Ordinary cash-jackpot odds stay capped at 2.25%, with excess probability going to rare collectibles; explicit debug luck can bypass that cap. For example, 3000× effective debug luck at a normal stake gives approximately **0.11% Common and 63% Legendary-or-better** odds. High luck makes rare results more likely, not guaranteed.

Eight reward tiers include collectible gear, tools, farming bonuses, mutations, jackpots, **Relic items with a 0.1% starting chance**, and a mysterious rarer tier. **Gacha never awards seeds**, including when a collection is full. Starter supplies, emergency help and quest seed rewards still work.

Inventory [I] has a **Gear** tab with a draggable 3D preview of the same round potato farmer you see in the field. The farmer has a soft oval body, stubby limbs, blinking eyes and smoothly blended walking and turning. Clothing fits that body and follows its moving limbs. Wear **one item in each of six slots: hat, shirt, pants, shoes, gloves and charm**. Equip another item to swap that slot, or click an occupied slot to remove it. Removed gear stays in your collection. Only equipped clothing provides its bonuses, and extra copies do not stack. A first drop equips itself if that slot is empty. Existing saves retain their collected gear and start with their highest-rarity owned item in each slot equipped if they have not used the wardrobe before.

The wardrobe preview follows dragging smoothly and eases to a stop after release. Adaptive resolution and 4× antialiasing sharpen the farmer and clothing edges. Hidden previews stop rendering, and releasing the mouse outside the portrait ends the drag normally.

Gacha now contains **23 wearable items**, including the previous hats, gloves and charms plus **15 new shirts, pants and shoes**. Mix pieces freely to shape your build. A garment matching your active player build has **25% stronger item bonuses**:

| Clothing family | Bonuses |
| --- | --- |
| Farmer | Harvest quantity and crop growth speed |
| Gambler | Luck and mutation chances |
| Investor | Better live stock sale prices |
| Scientist | Mutation chances and crop growth |
| Industrialist | Faster processing and a little extra harvest yield |

The original eight keepsakes remain passive collectibles. Normal effective luck stays capped at 10×, stock gear improves ordinary sale quotes and the strength odds of scheduled/rocket booms within their caps, and seeds follow actual sale prices. Equipping gear during a boom cannot inflate its preselected quote. The inventory shows equipment, owned counts and the combined active bonuses. Small yield bonuses accumulate between harvests of the same crop instead of being rounded away. Mutation clothing improves Scientist experiments as well as field mutations; the experiment panel shows its actual chance. Clothing processing bonuses also work with furnace heat, without speeding up ability cooldowns.

An equipped **Aurora Crown grants one free extra roll per paid purchase**, at the same stake value, in addition to its +1 luck. A single purchase gives two results; a winter ×3 or ×5 purchase gives four or six. The Crown must be equipped before buying, so winning one activates its bonus for your next purchase. Free rolls cannot trigger more free rolls, and the result cards identify the **AURORA BONUS**.

Frosthollow also offers **×3 and ×5 multi-rolls** at normal, big or stupid stakes. The full price is required and charged upfront; all-in stays a single roll. One reel reveals the best actual pull, then cards show every result. Rewards are granted once and saved before the reveal, and overlapping roll requests are blocked.

The illustrated horizontal reel lands on the actual reward. Common, Rare and build results use a short confirmation tone with no reward flash, screen mist or world celebration. Epic and higher tiers keep the big effects; Relic and mysterious discoveries get a longer reveal. A market reward starts after the reel ends so its window is usable.

The Roll House's collapsible **Trophy cabinet** records your 16 rarest distinct Rare-or-better discoveries, including free Crown rolls. Each trophy shows its artwork, tier, repeat count, island, roll number and the actual chance of that tier on its recorded roll. These are tier odds, not the odds of a particular item. History starts with rolls made after this update; past results are not invented. Debug-assisted discoveries are marked **DEBUG** and recorded separately from normal discoveries.

## Graphics

Open **☰ → Graphics**, or use **⚙** on the tutorial card. **Balanced** keeps a sharper picture with short, gentle shadows. **Smooth** removes cast shadows and reduces browser rendering resolution, useful if moving or zooming still stutters. Both keep the complete map, the day/night colours and the full rocket show. Your choice is saved on this device separately from the farm.

If Smooth still struggles, try a smaller browser window or the native Godot version. Performance varies with the device and browser. To load a newly published version, close all Taterland tabs and reopen the play link; keep the same browser profile to retain your farm.

## Debug controls

Open **☰ → Debug: money, luck & time** and enter the access code to unlock the controls for this session. Wrong codes leave the controls locked. Starting a new session or a new farm locks them again.

Applying money multiplies your current purse **once** (×0–×1,000,000); the money control then returns to ×1. Decimals and scientific notation work: `0.1` keeps 10%, `0.01` keeps 1%, and `1e-20` turns a `$1e20` purse into `$1`. Explicit `0` clears your coins. The preview shows the resulting balance before applying; invalid input or a positive multiplier that would underflow to zero is rejected. Debug luck is a persistent ×1–×1,000 multiplier on normal effective luck, so it can deliberately exceed the normal 10× cap. The panel shows normal luck, debug luck and the resulting value separately. Money changes and debug luck are saved with the farm.

Choose **1×, 2×, 5×, 10× or 30×** simulation speed to test crops, markets, pests, abilities and processing. Movement, interface animations, sounds, reward reels and the rocket film stay at normal speed. The simulation advances at most one second per rendered frame, so the highest setting depends on frame rate. Time speed starts at **1×** each session and is not saved.

**Reset luck + time** returns both to ×1 and keeps your current coins. **Lock debug · restore 1× time** closes access and restores normal time while preserving money and luck. Changing money, including reducing it, marks subsequent trophies as DEBUG even after luck is reset. Debug settings do not unlock islands or remove stock price limits.

### Stock Rocket

Every **30 minutes spent on Island 3**, a rocket packed with potato passengers blasts into the night sky, with yellow, blue, red, orange and pink money trails and an original rising jackpot score. Its countdown pauses on earlier islands and during the tutorial. Farming, pests, processing, and stock clocks pause during the launch cinematic. After liftoff, the selected crop gets **ten full seconds at +15,000–50,000%**. A rocket replaces a simultaneous normal boom, and its clock, pending launch reward, and active selling window survive saving. Leaving winter ends its active premium.

Stock feedback has four levels: small mist above +300%; stronger pulses from +500%; a musical jackpot with floating coins, music notes, island colour and gentle camera shake from +3,000%; and the rocket launch followed by the strongest celebration from +15,000%. The farm remains readable during selling. Colours stay green / gold / blue by island. Big balances use **Qa, Qi, Sx, Sp, Oc, No, Dc** before falling back to scientific notation.
