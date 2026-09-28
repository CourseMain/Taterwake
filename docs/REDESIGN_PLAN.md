# Taterwake redirect: the honest potato farm

Design plan for turning Taterland from a big-number market game into a hard,
legible farming survival game where climate change is the antagonist. Written
as a handoff for implementation.

## 0. Locked decisions

- **Real-time seasons.** Each working season is a short real-time phase with
  the avatar and tools; winter is a menu phase.
- **Ten-year run.** Foreclosure is game over. The run ends with the ten-year
  ledger and then the **fifty-year epilogue** (§4b).
- **One farm.** The climate shifts in place on a single farm. Other islands
  may return later as selectable regions at new-run time, not as progression.
- **Professions are cut.** The five builds, their activities, levels, XP and
  bonuses are removed. A mild run-start "farming style" with ±10–25% tilts
  may be revisited after the core is tuned. The Gambler does not return.

## 1. The pitch

**A farming game where you lose money.** You inherit a small potato farm and a
mortgage. Every year you decide what to plant, when to sell and what to protect.
Every year the weather gets a little worse. At the end of every year the
accountant shows you the ledger. Most years the number is small or negative.
Surviving ten years is the win.

The moment that makes people say "oh, that's different" is the **annual
accounts screen**: a plain ledger, line by line, ending in a net figure like
`−1,340` or `+212`. That screen is the scoreboard, the story and the thing
players screenshot. Everything else in the game exists to make that number
honest and to make the player feel they earned it or could have avoided it.

Tone: keep the potato humour, the round farmer, the NPC voices. The numbers are
the harsh part. Clarkson's Farm is funny and still says "we made £144".

## 2. What changes and what stays

### Keep (already built, reusable)
- 3D world, procedural islands, farmer avatar, five manual tools, beds, day and
  night cycle, touch and desktop controls, camera.
- Climate system skeleton: warning → active → recovery phases, drought, flood,
  storm, freeze, stress accrual per bed, protection projects with levels.
- Water loop: rain → tank → can → crop, sprinklers, drainage.
- Weather station, furnace, ducks and pests, NPC roster and conversation
  system, market price chart, tutorial framework, save and migration
  framework, headless test harness.

### Remove
- Scheduled stock booms, natural spikes, the Stock Rocket and its cutscene.
- Roll House, Spudions jackpots, all-in, luck, crates, trophies, mutation gear,
  clothing bonuses, the Gambler build, the mythic crate.
- Exponential island economies (millions → quadrillions), large-number
  suffixes (Qa, Qi, Sx…), the "tax after every third boom" collector.
- Combo multipliers up to 16×, mastery yield bonuses up to +1000%.

### Rescale
- Money becomes small and legible: hundreds and low thousands. A sack of
  potatoes sells for roughly 15–30. A year's fixed costs are a few thousand.
- Any bonus that survives (tool rank, a build perk) is worth ±10–25%, never a
  multiplier.
- Time moves from 60-second days to **seasons**. A year is four seasons; a
  season is a short real-time work phase. See §4.

## 3. The player's three decisions

The player never needs farming theory. Every choice is one of these:

1. **What to plant.** Each variety is a card with three visible dials: water
   need, heat and cold tolerance, price and price volatility. Better price
   means more fragile. Seed cost is shown. Four to six varieties total.
2. **When to sell.** Sell at harvest (glut, low price) or store (storage fee,
   spoilage, price climbs through winter). Contracts offer a fixed price now
   with a penalty per sack short. Nothing else about the market exists.
3. **What to protect.** Money is scarce, so each protection is a bet on which
   disaster comes: rainwater tank (drought), drainage (flood), windbreak
   (storm), frost cover (freeze), plus insurance (premium, partial payout).
   The forecast gives probabilities with error bars. Better weather station
   means narrower error.

A fourth, mid-game decision gives the game its strategic spine:

4. **Diversify or double down.** From year three, income beyond crops unlocks:
   a farm shop (steady, weather-proof, eats labour), contract growing (steady,
   penalties), lodging for tourists (needs the farm to look good). Spending on
   these means not spending on protection. This is the real-world story and
   most farming games skip it.

Every loss shows a cause card so difficulty is legible:
`Drought, Season 3. Lost 38% of Russet. The tank was empty. A full tank would
have saved about 60%.` Hard is fine. Unexplained is not.

## 4. Structure of a run

- **Year** = Spring (plant), Summer (tend, first disasters), Autumn (harvest,
  sell or store), Winter (accounts, plan, buy protection, repairs).
- Each working season is a real-time phase of about **2 to 3 minutes**. The
  season length is the labour budget: you cannot water, hoe and harvest every
  bed if the farm is big. Hiring a hand costs money and buys time. Sprint stays.
- **Winter** is a menu phase: the ledger, the forecast for next year, the shop.
- A run is **ten years**, roughly 90 minutes of play across sessions, saved
  every season. Foreclosure is game over.
- Foreclosure happens when the overdraft passes the bank's limit. The bank is
  the second antagonist and is polite about it.
- End of run: a ten-year ledger, the climate record, a title for how you
  farmed (Adapter, Shopkeeper, Stubborn, Sold Up), then the epilogue.

Islands: one farm whose climate shifts in place over the ten years, because
"the villain is coming to your farm" is the story. Later, the other two islands
can become selectable **regions** at new-run time (Shores = heat and flood,
Frosthollow = cold and storm) with their own climate curve.

## 4b. The fifty-year epilogue

After the ten-year ledger, the game fast-forwards forty more years with no
player input and shows what the farm became. This is the villain's ending and
the reason the run mattered.

How it is decided. The epilogue runs the same simulation the player just
played, on the player's final state, with the climate curve continuing to
climb, and with a simple caretaker policy: keep doing what the player was doing
(same crops, same protections, same diversification, repairs when affordable).
The player never sees a dice roll; the outcome is earned by the final state.
Four axes decide the picture:

- **Solvency**: cash and debt at year 10, and the caretaker's net trend.
- **Adaptation**: which protections exist and at what level versus the
  disasters the curve will bring.
- **Diversification**: how much income does not depend on the weather.
- **Land health**: soil stress carried over from repeated disasters, tank and
  drainage condition, tree cover.

Possible futures, rendered on the same 3D map with new visual states:

- **Dust**: cracked pale soil, dead furrows, empty tank, collapsed roof, the
  sea pulled back. Drought-heavy curve, no water protection.
- **Drowned**: beds under standing water, silted paths, the ferry jetty gone.
  Flood-heavy curve, no drainage.
- **Deserted**: sound farm, nobody home, sign reads "For sale". Solvent but
  no diversification and the caretaker went under around year 25.
- **Sold to the estate**: beds replaced by one giant monoculture field, the
  village buildings turned into storage, potatoes gone. Foreclosed early with
  land still healthy.
- **Holding on**: smaller farm, windbreaks grown tall, tanks and drains
  everywhere, a few beds, a modest ledger. Adapted, not rich.
- **The shop village**: farm shop, lodgings, a market square, fields half
  wild. Diversified, weather nearly irrelevant to income.
- **Thriving**: rare. Every axis strong. Full fields under cover, the NPCs
  older, a plaque with the player's name.

Presentation: the ten-year climate strip extends to fifty with the front-page
headlines of the intervening decades, then the camera fades up on the future
farm and slowly pans. A final ledger line: `Farm value, 50 years on`. Reuse the
existing flood, ice, snowbank and sand visuals; add dust, standing water,
overgrowth, abandoned and estate variants for buildings and beds. One
screenshot button on this screen.

## 5. Climate as the villain

Climate is a **trend, not a dice roll**. The player can see it coming and can
only adapt, never stop it.

- Disaster chance per working season starts around 15% in year 1 and rises
  about 4 points per year; mean severity rises too. By year 10 expect about two
  disasters a year. Exact curve is a tuning constant.
- The villain has a face: the year-start forecast is a newspaper front page or
  an NPC weather report that gets grimmer every year, with a visible ten-year
  climate strip showing past years' disasters.
- Foreshadowing beats randomness: a drought year is preceded by a dry spring
  (tank fills slower), a flood year by a wet one. Reading the farm is a skill.
- Protection is a **treadmill**: to keep net income near zero by year six the
  player must have invested a few thousand, which only a good early year plus
  restraint affords. That is the honest message, delivered by the ledger rather
  than by text.

## 6. Economy model (starting numbers, to be tuned by simulation)

| Line | Per year |
| --- | ---: |
| Mortgage interest + principal | 2,000 |
| Land tax and rent | 500 |
| Living costs | 1,500 |
| Equipment upkeep | 500 |
| Seed (24 beds) | ~1,200 |
| Water, fuel | ~300 |
| **Costs, total** | **~6,000** |
| Gross sales, good year, no disaster | ~6,500 |
| Gross sales, one moderate disaster | ~4,900 |
| Gross sales, two disasters | ~3,200 |

So a clean year nets about +500, an average year about −1,100, a bad year about
−2,800. Start with 2,000 cash and a −5,000 overdraft limit. Naive play should
foreclose around year 4 to 5; careful play should survive year 10 with a total
ten-year net somewhere near zero and one or two proud years. Storage: +40%
spring price, 10% spoilage, 200 fee. Contract: fixed 22 per sack, penalty 5 per
sack short. Protections: 1,500 to 2,500 each, 100 per year upkeep, each cuts
its disaster's loss by 50 to 60%. Insurance: 400 premium, pays 40% of loss.

## 7. Phases for implementation

**Phase 0: Safety rails first** (before touching gameplay)
- Move the save to a new file (`v4`) and stop the current behaviour where a
  save that fails validation is replaced by a fresh farm and overwritten by the
  10-second autosave. Keep one rolling backup. Old v3 farms are not carried
  over; say so on first launch.
- Repair the stale test fixtures (four suites fail at HEAD after the field
  expansion validator change) and add a run-all test script so the suite can
  gate releases.

**Phase 1: Strip**
- Delete booms, rocket, Roll House, luck, mutations, gear bonuses, crates,
  trophies, combo multipliers, large-number formatting, the boom-count tax.
- Replace the three island economies with one small-number price table.
- Remove the professions system. Result: the game still runs, you can
  farm and sell, money is small.

**Phase 2: Year and ledger skeleton**
- Season clock replacing the 60-second day. Season phase, year counter,
  winter menu phase.
- Ledger object: every coin in or out is a categorised line. Annual accounts
  screen. Fixed costs charged in winter. Overdraft and foreclosure.
- Ten-year end screen.

**Phase 3: The decision layer**
- Crop cards with the three dials, wired to existing growth and stress rules.
- Storage with fee and spoilage; spring price rise; contracts with penalties.
- Protection purchases mapped onto the existing climate projects; insurance.
- Forecast with error bars from the existing weather station.
- Cause cards on every loss.

**Phase 4: Climate escalation**
- Year-indexed disaster probability and severity curves.
- Foreshadowing signals in the season before a disaster.
- Villain presentation: yearly forecast page, ten-year climate strip.

**Phase 5: Tuning by simulation** (this is the logic check)
- Write a headless bot that plays full ten-year runs using three fixed
  strategies: naive (plant the pricey crop, never protect), cautious (protect
  first, cheap crops), diversifier (shop by year three).
- Assert in the test harness: naive forecloses by year 6 on the median seed;
  cautious survives year 10 on most seeds; no strategy ends with more than a
  few thousand; every year's ledger sums to the cash delta exactly.
- Tune the constants in §6 until those assertions hold, then freeze them.

**Phase 6: Diversification and endings**
- Farm shop, contract growing, lodging, each with labour cost and steady
  income. Run titles.
- Epilogue simulation: caretaker policy, forty-year headless run on the final
  state, the four axes, the outcome table. Add it to the Phase 5 bot: each
  strategy should land in a distinct, explainable future, and no run should
  reach "Thriving" without all four axes strong.
- Epilogue visuals: future states for beds, buildings and water; the fifty-year
  strip; the pan and final ledger line.

**Phase 7: Presentation and onboarding**
- Rewrite NPC dialogue for the new cast roles: the accountant who reads the
  ledger, the farmhand who says what the weather did, the bank.
- First-year guided tutorial that ends at the first annual accounts.
- Store page copy built around the ledger screenshot.

## 8. Logic checks on the original plan

- **Hard versus unfair.** "Barely any money" only works if every loss is
  attributable to a decision the player could have made differently. Cause
  cards and foreshadowing are not polish; they are what makes the difficulty
  acceptable.
- **Villain versus RNG.** A random disaster is bad luck. A trend the player
  watched climb for five years is a villain. The ten-year strip is essential.
- **Simple versus trade-offs.** These only coexist when the dials are few:
  three per crop, five protections, three diversifications. Resist adding.
- **Big numbers out means multipliers out.** Every existing 3×, 8×, 16× and
  luck system is meaningless in a small-number economy. Cut rather than
  rescale; rescaled versions still push players to chase one lever.
- **Real-time days versus annual pacing.** The current 60-second day cannot
  carry a year structure. Seasons must come before any economy tuning.
- **Browser sessions are short.** A season of two to three minutes with a
  save at every season boundary fits phone play. A year should never require
  one sitting.
- **Do not tune by hand.** The economy in §6 is a guess. Phase 5's bot is how
  the numbers get proven, and it reuses the existing headless test harness.
