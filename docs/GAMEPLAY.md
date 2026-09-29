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

Purchases show a short dark-and-gold confirmation card. Seed receipts show how many you bought, the actual price paid with the Spudion symbol and your new seed total. Repeated purchases of the same seed combine in one card instead of piling up. Tool, barn, field and duck upgrades also get confirmations; rejected purchases explain the problem without showing a success card.

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

The run lasts **ten years**. Spring, Summer, Autumn and Winter each last **150 seconds** of working time; owning a farm shop reduces Summer to **120 seconds**. The top strip shows the season and year; the sun moves from dawn to dusk through each season, so the sky shows how much working time remains. The calendar and sun resume their saved position after loading.

**Annual accounts open at Winter start**, after buyer collection, storage charges, spoilage, business income, fixed costs and the foreclosure check have been saved. The accounts pause the simulation while open and show every category, crop sales split by grade with sacks and totals, the year’s net and a running ten-year table on plain cream paper. **Return to farm** or Escape closes them and resumes Winter. The farm menu’s **Annual accounts** button reopens them throughout Winter. Winter ends automatically and Spring begins immediately; there is no next-year button.

The run finishes at the **end of year 10’s Winter**. The ten-year summary then shows total net, years in profit, best and worst year, final purse and remaining loan, with **New Run** to start over. The epilogue is still to come. Every season boundary saves before its screen opens, including the final Winter boundary. Calendar and accounts presentation stay synchronized at accelerated debug speed.

Watered crops grow in real time. Base growth times are Russet **75s**, Golden **105s**, Giant **135s**, Sunburst **195s** and Icecap **225s**. Russet ripens in half a season; Icecap needs a season and a half. Weather can slow growth up to 450 seconds of active growing time; dry crops wait for water, and disaster-frozen crops wait for thawing. Icecap grows through ordinary Winter bed ice.

Till in **Spring and Summer**. All five varieties can be planted then; **Icecap can also be planted in Autumn**, into beds prepared earlier. At the end of Autumn, other unharvested crops are lost and their prepared beds are cleared. Living Icecap remains, with its growth progress and water. The accounts report the cold losses and surviving Icecap. Potatoes already in the barn survive field clearing, then incur Winter storage spoilage. Every bed then ices over. Use **Hoe [1]** to clear it during Winter; this removes ice without tilling. Cleared beds can be tilled as soon as Spring starts. Uncleared beds retain their ice and need a separate clearing action before tilling in Spring, even after other weather comes and goes.

Ordinary shop and menu panels keep working time running. Annual accounts, the year-start front page, conversations, weather practice and the collapse page pause it. The first-harvest lesson protects the calendar while its crops grow; the optional tour pauses all farming. Winter remains playable: prices and tank replenishment advance, while Icecap keeps growing on its iced bed. It can be harvested through the ice in Winter or early Spring; planting at Autumn’s start leaves time for a Winter harvest. Snow refills the tank at **one quarter** the normal rain rate. Icecap still needs water, from the can or connected sprinklers; seasonal bed ice does not block it. An empty iced bed must be cleared before planting again in Spring. Snow cover and roof snow last all Winter, and a lower, paler sun still moves from dawn to dusk. Closing the game adds no offline farming.

Manual tool upgrades increase the area of a single action. Each healthy bed yields **3–5 sacks**. A full barn leaves the uncollected part on the bed; harvesting the remainder never creates extra sacks.

Pests use independent timers for each bed, rather than farm-wide waves. Each crop is protected for its first 40 seconds after planting. On becoming harvest-ready, it receives a uniformly random 15–90-second pest delay; pests appear only after both the crop-age protection and that delay have elapsed. Sprayers and ducks reset the bed’s delay, and saved games preserve the timers. Each 5-second attack removes one third of the crop’s original maximum yield: 3/3 → 2/3 → 1/3 → destroyed at 15 seconds. Spraying cannot restore eaten potatoes. Visible insects, bite particles, shaking crops, yield labels and warning sounds make attacks clear. Use the bug sprayer on the affected bed to stop further damage; clearing pests gives a fresh grace period. A separate three-chirp alarm warns about pests, repeats every six seconds while they remain, and stops when you clear them. Simultaneous attacks share one alarm; crop loss has its own descending sound. Tool audio cannot cut these warnings off. Insects remain clickable through the same bed target. A destroyed crop shows a brief “Crop lost” notice, then clears its label completely; reloading does not resurrect old notices.

## Annual accounts

Your purse is **2,000 starting Spudions plus every ledger entry**. Sales, seeds, upgrades, protection, ducks, quest payments and Debug adjustments all enter that same journal. The accounts show cash flow, including mortgage principal; net means income minus every payment that year. Opening cash is not income.

Every Winter posts these fixed costs once:

| Cost | Spudions per year |
| --- | ---: |
| Mortgage interest | 600 |
| Mortgage principal | 600 |
| Rent and land tax | 300 |
| Living costs | 800 |
| Equipment upkeep | 300 |
| **Total** | **2,600** |

The mortgage starts at **12,000**. Each Winter’s principal payment reduces it by 600; the ten-year model keeps interest at 600 per year. Reloading the accounts never charges the bill again. Winter purchases still appear in that year’s accounts. Categories for later systems remain visible with zero totals until used.

Current saves use mechanics revision **40**. Earlier saves, including revision 39, are incompatible and are set aside with the existing rejected-save protection; they are not migrated.

## Diversification and run titles

From **year three**, annual accounts offer three permanent businesses. Purchases work while accounts are paused and appear under their own labels. Construction and annual business income use Other; contract-grower collections and shortfalls use Contracts.

| Business | Cost | Return and tradeoff |
| --- | ---: | --- |
| Farm shop | 3,000 | 800 each Winter; Summer has 30 fewer seconds for farming. |
| Contract grower | Free enrolment | Two simultaneous Spring orders, each at 1.2× the ordinary contract price; normal shortfall penalties apply. |
| Lodging | 2,500 | 150 each Winter per completed protection type, up to 600. |

Benefits start the following year: construction Winter pays no retroactive income. Lodging counts the tank, drainage, windbreak and frost cover separately, regardless of level; sprinklers do not count. With no protections, lodging earns nothing. Annual income settles before the Winter foreclosure check and cannot repeat on reload.

Completed runs receive **Shopkeeper** when more than half of gross crop, contract and business receipts came from diversification, otherwise **Adapter** for at least three protection types, or **Stubborn** for none. One or two protections earn **Survivor**. Insurance and other payments do not count toward the income comparison. Foreclosure always gives **Sold Up**, including before year ten.

## The live crop market

| Variety | Seed cost | Base price / sack | Water need | Heat tolerance | Cold tolerance | Grow seasons | Sacks / bed | Price swings |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Russet | 6.75 | 9 | 1 | 3 | 3 | 1 | 3 | Low |
| Giant | 9.00 | 12 | 1 | 3 | 2 | 1 | 5 | Low |
| Golden | 12.60 | 16.80 | 1 | 2 | 2 | 1 | 4 | Mid |
| Sunburst | 17.10 | 22.80 | 2 | 3 | 1 | 2 | 3 | High |
| Icecap | 30.00 | 30 | 3 | 1 | 3 | 2 | 2 | High |

More water bars mean a thirstier crop; more heat or cold bars mean better tolerance. Higher prices come with lower combined resilience. An unwatered bed builds stress faster when water need is high. Water need and heat tolerance affect drought damage; cold tolerance affects deep-freeze damage. Icecap is cold-tolerant but thirsty and vulnerable to heat. Its 30-Spudion seed buys only two potential sacks; the highest sack price does not mean the highest profit.

Tool upgrades cost **300–1,500 Spudions**. Opening the remaining beds costs **1,200** once. The barn has three upgrades costing **300, 800 and 2,000**, for capacities of **400, 1,200 and 4,400 sacks**.

Each variety has a fixed base price. Its live selling price follows a slow, deterministic ten-minute seasonal cycle with a range determined by volatility: **±5%** for Low, **±10%** for Mid and **±15%** for High. This is the Standard-grade quote; Table earns 1.2× and Feed earns 0.5× it. Weather does not change it; stored Winter sacks use the separate price below.

Press **2** or click the Seeds hotbar slot to show crop choices. Selecting another tool hides the seed tray.

**Buy Seeds** has five variety cards in a desktop row, stacking vertically on a phone. Each shows three bar dials, growth time, yield, seed cost, the live sack price and owned quantities. Selecting a card selects that variety and the seed tool without spending money. **Last year avg** is blank in year one; later it shows the previous full cycle’s average, currently the base price under the temporary price model. Seed prices stay fixed throughout the cycle: **75% of base for Russet, Giant, Golden and Sunburst; 100% for Icecap**. Money displays as rounded integers with thousands separators and the Spudion glyph; transactions retain their exact fractional value. Choose **Buy 1** or **Buy 5** to confirm a purchase.

**Sell Potatoes** shows one variety at a time, with selectable **Table, Standard and Feed** rows showing their sacks and current prices. Select a grade, then swipe left/right or use the arrows; use **− / +**, edit the amount, or choose **Max**, then press the green **Sell** button. The amount stays within your selected grade’s available stock, and the payout follows the current quote while the page is open. Invalid amounts disable selling. A short receipt confirms the actual payout. Sacks left in the barn when Winter begins are stored automatically; the sell page states the fee, spoilage and dashed late-Winter price in one line. Inventory sales and **F** sell ordinary stock; in Winter, stored sacks must be sold through **Barn stores**. Switching Buy/Sell tabs keeps the market session; completed Mara introductions stay remembered. Visit Mara's stall to talk again.

Every Buy Seeds and Sell Potatoes card includes a small, unanimated sparkline of up to **12 recent sale quotes**. Beside the live sale price, a signed percentage compares it with the variety’s base price: green above base, red below, neutral at base. The top bar shows the same comparison for the selected crop. Seed costs stay fixed; their cards show the sale-price history to help choose what to plant.

Both pages order varieties by their fixed base selling price: **Russet → Giant → Golden → Sunburst → Icecap**. Buy Seeds offers all five varieties; Sell Potatoes includes known varieties and crops held in the barn. Live prices never reorder the pages.

## Crop quality and saved seed

Every planted bed starts at **100 quality**. Its current score determines its grade at harvest: **Table 80–100 (1.2× price)**, **Standard 40–79 (1×)**, **Feed 0–39 (0.5×)**. “Table” means the best eating quality. Hovering a growing bed or standing beside it shows a small “Grade: Table” (or Standard/Feed) tag and a steady grade hint alongside the growth time; a downgraded bed also names its largest deduction, such as “Pests took it to Standard.” The harvest pop shows the grade. Different harvest qualities remain separate in the barn.

Before variety and protection adjustments, deductions are:

- Each pest bite: **6 points**.
- Active drought or flood stress: **4 per 10 seconds** exposed.
- Disaster ice on the bed: **15 once**, then **4 per 10 seconds** until cleared or thawed.
- A lightning row hit: **25 once per disaster** on that bed.
- Growing without water: **2 per 10 seconds**.
- Left ripe: the first **30 seconds** are free, then **5 per 10 seconds**. Spraying and duck patrol do not reset this deadline.

Deductions scale by **9 ÷ combined resilience**, using the same variety dials as the crop cards: Russet’s multiplier is 1, Icecap’s is 1.8. The scaled points are rounded, then matching protection cuts them by **50% / 75%** using the field-loss formula. Frost covers apply to Spring disaster ice; ordinary Winter bed ice still permits Icecap. Watering, timely spraying, ice clearing and prompt harvest avoid continued deductions. Quality never falls below zero, and a partial harvest leaves the remaining crop’s quality intact.

At **Barn → Barn stores**, choose **Keep 1 Standard/Table sack as seed**. It leaves saleable storage immediately and avoids spoilage, storage ageing and Winter barn disasters. Each kept sack becomes **one seed of the same variety next Spring**. Feed cannot be kept. A barn holding only seed sacks has no storage fee. Kept seeds and their Spring conversion survive saves without duplication.

## Storing or selling

Keeping any sacks in the barn at **Winter start** costs **120 Spudions once** and loses **5% of the whole barn, rounded to the nearest whole sack**, taken from the largest variety pile first (catalogue order breaks ties; lower-quality sacks go first within it). A lone sack does not spoil. Buyer collection happens first, so only the remaining sacks count. An empty barn has no storage bill. Annual accounts show the charge and spoilage; the journal records spoiled sacks as a zero-cash note, so the loss is not charged twice. These charges happen before foreclosure is checked. Reloading does not repeat them.

Surviving sacks lose **10 quality points each Winter** and are regraded before becoming **Winter stores**. A Table sack at 85 becomes Standard at 75; a Table sack at 100 remains Table at 90. Seed sacks are excluded. Open **Barn → Barn stores** (also linked from Sell Potatoes) and sell during the working Winter. Prices rise steadily from base at Winter start toward **1.2× base for Low volatility, 1.4× for Mid and 1.6× for High** at Winter’s end, multiplied by the sack’s current grade. The Sell Potatoes sparkline includes a dashed line for that expected late-Winter price; the signed live-market percentage remains beside the ordinary quote. Waiting can pay more, but the fee and spoilage can outweigh the gain on a small harvest.

**Spring resets the storage premium.** Unsold stores become ordinary stock again. New Icecap harvests during Winter sell at the ordinary market quote and do not immediately earn the stored-crop premium. Fresh harvests and Winter stores share the same barn capacity: **200 initially**, then **400, 1,200 and 4,400** with upgrades. Excess harvest stays on the plant until room is available.

## Buyer contracts

The **Contracts** board beside the northern shops opens a buyer’s order; it is also reachable from the farm menu. Each Spring offers **20 sacks of one variety at 1.1× its base price**. The variety rotates through the five crops by year. Accepting commits to that order; ordinary farms can accept one per year, and contract growers can accept two distinct orders at **1.2× the ordinary quote** (base × 1.32). There is no cancellation.

At the **end of Autumn**, as Winter begins, the buyer automatically collects **Standard or Table sacks, never Feed**, from the barn before spoilage and the storage fee. Autumn harvests can fill the order. Delivered sacks earn the agreed price; each missing sack costs **5 Spudions**. Both payment and penalty post under **Contracts** in the ledger. The board keeps the year’s result, and saving/reloading preserves the order without settling it twice.

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

Press **P** for **Crop varieties**, an illustrated reference for all five potatoes with base growth times and yield per bed.

## Graphics

Open **☰ → Graphics**, or use **⚙** on the tutorial card. **Balanced** keeps a clear farm with gentle shadows. **Smooth** draws a lighter farm without shadows. **Crisp** gives the sharpest farm and smoother edges, using more graphics power. Text, menus and icons stay sharp in every mode. Your choice is saved on this device separately from the farm.

If movement in Safari seems capped at 30 FPS, check **System Settings → Battery → Low Power Mode** and use Automatic/Never instead of Low Power while playing. Low Power Mode can also be enabled while plugged in. Try Chrome/Firefox or run the native Godot project if browser performance is still poor. The Web ZIP is still a browser build, not a native app. [Godot's browser guidance](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [Apple's power mode guide](https://support.apple.com/en-nz/101613).

To load a newly published version, close all Taterland tabs and reopen the play link; keep the same browser profile to retain your farm.

## Debug controls

Open **☰ → Debug** and enter the access code to unlock the controls for this session. Wrong codes leave the controls locked. Starting a new session or a new farm locks them again.

After foreclosure, **Debug access** still accepts the session code. Before year 10, **Recover test farm** posts a balance adjustment, keeps the journal and paid Winter bills, and returns to the Winter accounts at 1× time. Close the accounts to resume the timed Winter. Year-10 foreclosures still require a new farm. **Try Again** starts a new farm with an empty journal.

### Climate action and bankruptcy

Weather can threaten Spud Valley from the first season. Disaster chance is **15% + 4 percentage points per year after year one**, capped at **60%**: 15% in year one, 35% in year six and 51% in year ten. Mean severity rises from **50% by 3 points per year**, reaching 77% in year ten. Each event gives **45 seconds of warning**, **30 seconds of danger**, then **75 seconds of recovery**. There is at most **one disaster per season and three per year**, including Winter. Open **Weather & protection** to reserve Winter protection, buy manual sprinklers, insure crops and read next season’s forecast.

Spring brings **flood or freeze**, Summer **drought or storm**, Autumn **storm or flood**, and Winter **deep freeze or blizzard**, equally likely within each pair. Winter events damage stored sacks and living Icecap; empty beds and fresh Winter harvests in the barn are untouched. At impact, deep freeze loses **20% × severity**, blizzard **30% × severity**, rounded to whole sacks per stored variety or Icecap bed. Sell stores or harvest ripe Icecap during the warning to reduce exposure. Winter claims are insurable; ordinary storage spoilage is not.

The preceding season may hint at the next disaster: drought dries the grass and halves tank replenishment, flood brings frequent rain, and storm brings wind ribbons. The next season’s occurrence and type are decided together in advance. For these three event types, a signal appears **70% of the time when a disaster is coming**, but only **10% when the season will be calm**. Signals are useful evidence, with false alarms and missed warnings; freeze and Winter events have no precursor signal. The annual three-disaster cap still applies when the season begins. The weather station shows the probability curve, never the hidden outcome.

Each year opens with a cream newspaper front page, a grimmer headline and a **ten-year strip of recorded disasters**. It pauses farming, closes after twelve seconds, and can be skipped with the button, Space or Escape. The same strip appears in Winter accounts. Spring has fresh grass, orchard blossom and verge flowers; Summer has warmer grass and faint field haze; Autumn has orange and brown canopies, path leaves and a longer dusk. Winter keeps its snow. Grass and sky blend over **one second** at a boundary. By year six, even calm Summers have drier grass and stronger haze. The tank’s visible water level remains part of reading the farm.

The bank lets purchases take the purse down to **−5,000 Spudions**. A purchase that would cross that limit is refused. At the end of Autumn, buyer collection, storage, insurance payouts, protection upkeep, business income and the complete fixed Winter bill are settled first; a resulting balance **strictly below −5,000** forecloses the farm. Exactly −5,000 survives. Foreclosure is checked at that annual boundary, not on each midyear balance change.

The Weather Station keeps its scanning sensor tower and uses a cream page with live tank levels, protection, construction progress and the **next season’s disaster probability range**. Station levels **0 / 1 / 2** give **±20 / ±10 / ±5 percentage points**, clipped to 0–100%. Sensor upgrades cost 500, then 1,000. The overall chance follows the next season’s year; each of its two possible disasters has half that probability. Both overall and per-disaster ranges are shown. After three disasters, remaining seasons that year have zero risk. Better instruments narrow uncertainty; they do not change the weather.

### Winter protection work

| Protection | Disaster | Level 1 | Level 2 |
| --- | --- | ---: | ---: |
| Rainwater tank | Drought | 900 | 1,800 |
| Drainage | Flood | 1,200 | 2,400 |
| Windbreak | Storm | 1,500 | 3,000 |
| Frost cover | Spring freeze, covered beds only | 900 | 1,800 |

**Reserve during Winter**, after closing accounts. Payment buys materials; protection begins only when the work is finished. Use **Walk to construction site**, or click the marked materials in the world, for one walked, 0.6-second hoe action. **Three actions finish each level.** Unfinished paid work keeps its progress through Spring and can resume next Winter. An upgrade keeps the completed lower level working meanwhile. Each completed protection costs **60 upkeep per year at Winter start**, regardless of level; work completed later that Winter is first billed the following Winter. Sprinklers remain a separate manual-water purchase at 500 / 1,000.

Completed level 1 reduces the matching disaster’s field sack loss by **50%**, level 2 by **75%**, rounded to the nearest whole sack across affected beds of the same variety and protection level. At a bed’s danger threshold, surviving sacks remain on the crop and can be harvested. One disaster cannot repeatedly charge that same bed’s loss. Watering, opening drains and clearing ice can prevent the danger threshold from being reached. Drought, flood, storm and freeze do not damage barn stock in Spring, Summer or Autumn. Winter-start storage spoilage still applies.

After finishing the frost-cover project, use **Hoe [1]** to clear Winter ice. Then choose **Cover all cleared beds** on the weather page, or stand beside a cleared bed and use its **Cover bed** context action (E, the bed’s E badge, or the touch action button). Only unlocked, cleared beds receive covers. Hoe in Winter only clears ice; it never places covers. Repeating either cover action does not charge or duplicate covers. The cover protects that bed against freeze during the **following Spring**, and expires in Summer. Covers must be placed again each Winter. They do not save crops left unharvested at Autumn’s end; Icecap keeps its existing Winter exception.

### Insurance and loss notices

Buy **240-Spudion annual insurance in Spring**. It covers subsequent field crop losses and Winter weather losses in stored sacks, paying **40% of lost sacks × the crop’s fixed base price**. Spring–Autumn claims settle at Winter start before foreclosure; new Winter claims pay when the loss happens. Losses before purchase and storage spoilage are excluded. The premium and payouts post under Insurance without repeating on reload. Renewal is a new Spring decision.

Every field crop loss, Winter stored-sack loss and storage-spoilage loss records a **cause card**: year, season, event, variety, sacks lost, missing protection or action, and how many sacks that alternative would have saved. Open **This season’s loss notices** at the weather station; the list updates while open. Winter accounts retain all that year’s cards, including drought, flood, storm, freeze, dry beds, pests, Autumn cold, Winter deep freeze, blizzard and storage spoilage. Climate cards compare the same exposed sacks with the next protection level; at maximum protection there is no further project saving. Where prevention is manual, the card names watering, spraying, harvesting, selling or ice clearing instead.

The foreclosure page shows the accounting year, cause, year net, Winter bill, debt limit, weather losses and final balance. **View Run Summary** reveals that year’s category totals and climate context; **Try Again** starts a fresh farm. Authenticated **Debug access** can recover an isolated test farm while retaining its progress. Tutorials are protected from weather pressure.


### Connected equipment and isolated testing

The water loop is **rain → tank → can or pipes → crops**. A starter can waters 16 beds; upgrades increase its capacity. Click the tank, then **Refill watering can** to walk over and transfer water. Sprinklers and the can share the same reserve. Sprinklers water their fixed connected patch, while drought stops rain replenishment. Select equipment to see its source, pipes and affected beds.

After purchasing irrigation, optional water practice is available at the weather station. It pauses the real farm and uses temporary crop visuals; it does not give free irrigation.

**Deep Freeze** stops affected crops from growing, being watered or harvested. Use **Hoe [1]** to clear crop ice directly. Rescue prevents cold-stress losses; remaining ice melts after recovery.

- **Drought:** water dry crops; the shared tank reserve now matters.
- **Flood:** open purchased drains to send water through channels toward the sea; Hoe [1] drains individual planted beds.
- **Storm:** completed windbreaks reduce field losses across the whole farm. Harvest the warned lightning row or rely on the built protection to preserve part of its crop.

Double-click **Play Climate Lab.command** for disposable water practice, ordinary farming, upgrades and weather scenarios. It never reads or writes your saved farm. Hold **Shift** to sprint.

## NPC conversations

Interact with a staffed shop or station to greet its keeper in a close-up conversation, then choose their service to open it. Shop shortcuts follow the same order; the guided first-harvest tutorial keeps its direct steps. Mara, Bram, Nell, Tess, Pip, Iris and Edwin have different outfits, features and personalities. Stallholders stand at their counters or entrances and share their portrait appearances; Iris speaks through the weather station's radio link.

Choose a personal topic, ask about the weather, or open the shop. Replies lead to different lines, and NPCs remember introductions and friendly exchanges across saves. Conversations do not spend coins or grant gameplay bonuses. Weather advice reflects the current weather event.

Characters blink, gesture and move their mouths as text appears in an outlined speech bubble. Coloured name tags and golden service choices make the conversation easier to scan. Nearby interactions use a small white E keycap with a black outline. Tap the text or press **Space** to reveal the whole line; tap a choice, press **1–3**, or use **Tab / Enter**. **Leave × / Escape** ends the conversation. Farm, market and weather timers pause while talking, then resume when you leave. The portrait stops rendering when closed.
