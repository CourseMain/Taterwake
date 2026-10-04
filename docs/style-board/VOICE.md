# Twenty everyday lines — Segment 21c

These are the shipped copy edits, compared with tag k. The twenty lines total **435 → 217 words** (50% of the previous length). Counts split on whitespace after treating the literal `\n` as a line break; numbers and placeholders count as words. Short instructions keep the facts needed to act even when that takes more than half their old words.

Tess gives the job first and keeps the weather plain. Nell gives the number, then the dry aside. This pass changes no ledger label, transaction, action, timer, crop amount or accounting rule. Dynamic `%d` / `%s` placeholders retain their order.

## 1. Guide welcome — 26 → 17 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). Every new guided run; Tess gives the work, controls and pause promise.

Before:

```text
Plant, water, weather, harvest. Then Nell reads the bills.
This guided year has one small Summer storm. Decisions pause time.
WASD to walk; drag to look.
```

After:

```text
Plant, water, harvest. Nell counts bills.
One small Summer storm; decisions pause time.
WASD walks; drag looks.
```

## 2. Starter seed card — 23 → 10 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first shop visit; keeps the free starter supply explicit.

Before:

```text
Tap Mara’s whole stall or press B to read Russet’s card. You already have twelve starter seeds; use one for your first bed.
```

After:

```text
Tap Mara’s stall [B]: Russet card. Twelve seeds; plant one.
```

## 3. Hoe instruction — 12 → 5 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first tool action; selected tool and destination stay visible.

Before:

```text
Hoe selected. Click the gold bed to walk over and till it.
```

After:

```text
Hoe ready. Tap gold bed.
```

## 4. Plant instruction — 11 → 6 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first seed planted; identifies the bed and variety.

Before:

```text
Seeds selected. Click the same gold bed to plant a Russet.
```

After:

```text
Seeds ready. Tap gold bed: Russet.
```

## 5. Water instruction — 11 → 6 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first watering; explains why the player is doing the chore.

Before:

```text
Watering can selected. Click the gold bed to start it growing.
```

After:

```text
Can ready. Water the gold bed.
```

## 6. Growing step — 32 → 14 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The guided weather lesson; both speeds and the special storm remain disclosed.

Before:

```text
The calendar runs at 10× while you wait, then at 1× from the storm warning. One mild Summer storm will show what a loss costs. Later years use the changing climate forecast.
```

After:

```text
10× waits; 1× warnings. One mild Summer storm teaches loss. Later forecasts follow climate.
```

## 7. Cause card instruction — 16 → 8 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first loss; Tess counts the actual remaining crop without extra reassurance.

Before:

```text
Read the cause card. One tonne lost; two left to harvest. Continue when you are ready.
```

After:

```text
Cause card: one tonne lost; two to harvest.
```

## 8. Harvest instruction — 14 → 7 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first harvest; connects the action to stored potatoes.

Before:

```text
Harvest tool selected. Click the gold bed to put your potatoes in the barn.
```

After:

```text
Harvest ready. Tap gold bed; fill barn.
```

## 9. Sell or store — 29 → 15 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The first financial choice; preserves the costs and equal treatment of either decision.

Before:

```text
Sell your Russet in the barn [F] for cash now. Or keep it: Winter charges storage and spoilage, while prices rise. Either choice leads to the same honest accounts.
```

After:

```text
Barn [F]: sell Russet or store. Winter: higher prices, storage charges, spoilage. Nell counts both.
```

## 10. Winter approach — 27 → 12 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). The final guide step; preserves harvest access, boundary timing and retained stock.

Before:

```text
Harvest the remaining starter beds before Winter. You can work the other beds now; Nell opens the accounts as Winter begins. Unsold crops stay in the barn.
```

After:

```text
Harvest starters; tend others. Winter brings Nell’s books. Unsold crops stay stored.
```

## 11. Spring countdown — 30 → 17 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). Refreshed throughout the first wait; leads with remaining time and useful work.

Before:

```text
Spring is passing at 10×. Summer in %ds.
Iris will warn us before one small storm. Harvest the other ripe starter beds with tool 4 while Iris watches the sky.
```

After:

```text
Summer in %ds · 10×.
Iris warns before one small storm. Tool 4: harvest other ripe starters.
```

## 12. Storm countdown — 38 → 18 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). Refreshed during the first warning; retains the actual warning speed and demonstration bed.

Before:

```text
Iris, on the radio: a small storm is coming in %ds. Watch the sky and your gold bed.
The warning runs at 1×. Harvest the other starter beds now; Tess will show the loss on the gold bed.
```

After:

```text
Iris: small storm in %ds · 1×.
Tool 4: harvest other starters. Watch gold bed; Tess counts loss.
```

## 13. Harvest-paused countdown — 28 → 15 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). Shown whenever starter crops remain ripe; the action and protection from cold stay explicit.

Before:

```text
Harvest %d remaining ripe bed%s with tool 4. The calendar pauses so the guide cannot leave them to die in the cold. Unsold sacks stay in the barn.
```

After:

```text
Tool 4: harvest %d remaining ripe bed%s. Time paused; cold waits. Unsold sacks stay stored.
```

## 14. Tour action guard — 10 → 7 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). Repeated when a tour visitor tries a working action; tells them how to get back.

Before:

```text
This tour only previews shops. Resume farming to use them.
```

After:

```text
Shop tour only. Return to farming first.
```

## 15. Guide action guard — 17 → 7 words

Source: [`scripts/first_island_tutorial.gd`](../../scripts/first_island_tutorial.gd). Repeated on blocked guide actions; keeps the escape route without replacing the instruction.

Before:

```text
That action is not part of this step. You can skip the guided year to farm freely.
```

After:

```text
Later. Skip guided year to farm freely.
```

## 16. Nell first greeting — 19 → 8 words

Source: [`scripts/npc_roster.gd`](../../scripts/npc_roster.gd). First barn conversation; Nell remains practical and dry.

Before:

```text
Nell. I keep the accounts and the barn. Both are easier if you bring things in before they rot.
```

After:

```text
Nell. Barn and books. Crops in before rot.
```

## 17. Nell accounts advice — 26 → 15 words

Source: [`scripts/npc_roster.gd`](../../scripts/npc_roster.gd). Recurring barn help; retains every named cost and the unsold-stock distinction.

Before:

```text
Everything paid in and out. Seeds, sales, storage, mortgage, rent, living costs. Unsold potatoes are not income. I read the totals in Winter. Bring a chair.
```

After:

```text
Payments: seeds, sales, storage, mortgage, rent, living. Unsold potatoes aren’t income. Winter totals—bring a chair.
```

## 18. Tess first greeting — 17 → 6 words

Source: [`scripts/npc_roster.gd`](../../scripts/npc_roster.gd). First Tess conversation; work and weather are still her concerns.

Before:

```text
Tess. I work the beds and count what the weather leaves. Those are two different jobs, lately.
```

After:

```text
Tess. Beds first. Weather damage next.
```

## 19. Tess loss advice — 27 → 10 words

Source: [`scripts/npc_roster.gd`](../../scripts/npc_roster.gd). Recurring loss help; retains the cause, physical loss and protection comparison.

Before:

```text
Read the cause card after a loss. It says what hit, what we lost and what protection would have saved. I count tonnes. Nell does the wincing.
```

After:

```text
Cause card: what hit, tonnes lost, protection’s savings. Nell winces.
```

## 20. Tess weather report — 22 → 14 words

Source: [`scripts/npc_roster.gd`](../../scripts/npc_roster.gd). Used by the guided cause card and subsequent weather reports; all numeric placeholders and the non-cash distinction remain.

Before:

```text
%s took %d t of %s. That's %s at base prices, not a cash charge. The field is shorter; the bills aren't.
```

After:

```text
%s: %d t of %s lost, %s base value. No cash charge. Same bills.
```
