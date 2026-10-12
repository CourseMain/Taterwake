# The attention budget

Tester 1, who does not play games, put the design problem in one sentence:
"think of it as limited attention." This page turns that into rules Codex can
build to and tests the suite can check. Each technique has four parts: what
the effect is, how Taterland currently breaks it, the rule, and the check.
The simplicity contract in REDESIGN_PLAN.md Segment 22 still applies on top.

## Part 1 · Understanding: spend as little attention as possible

### 1. Working memory holds about four things
People can hold three or four new items in mind at once. A screen with eight
controls is not read; it is skimmed and abandoned. Tester 1 looked at the
first screen for five seconds and quit.
- Breaks: the v2.0.0 first screen showed the top band, the Weather pill,
  Sell, the money strip, the market price, hurry and a guide card, all at once.
- Rule: at most three tappable things on the play screen at any moment, and
  at most three choices on any card.
- Check: a suite test counts visible buttons on the play screen in every
  guided step and every season; more than three fails.

### 2. Choice takes time in proportion to the number of options (Hick's law)
Every extra option slows the decision and raises the chance of no decision.
- Breaks: 24 routes into selling; four stacked buttons under the accounts.
- Rule: one way to do each thing (ENTRANCE_MAP.md); one big button per
  card, and the others small.
- Check: the entrance audit in test_ui_audit.gd fails on any new route.

### 3. One call to action
At any moment one control should be the obvious next tap: bigger, warmer,
the only thing that moves. A new player should be able to say what to tap
within two seconds without reading.
- Breaks: the Spring plan card, Weather, Sell and the tool tray all compete
  with the same weight.
- Rule: exactly one "next" control on screen, 1.3x the size of any other,
  with a slow pulse. Nothing else pulses.
- Check: a suite test asserts one and only one control carries the "next"
  style per state.

### 4. Progressive disclosure
Show a thing the first time it matters and not before. Everything shown
early is a cost paid before the player has any reason to pay it.
- Breaks: the Weather pill and Sell button exist from the first second.
- Rule: Weather appears at the first warning. Sell appears at the first
  harvest. The Pub appears in the second Summer. The Pedlar in the second
  Spring. The accounts' Records, Leases and Businesses appear in year two.
  Each new control arrives with a one-line card ("New: Weather") once.
- Check: the guided-year screenshots at 390x844 show each control absent
  before its moment and present after.

### 5. Recognition beats recall
People recognise a place or a picture far more easily than they remember a
label. "The stall with the orange roof" is remembered; "the Market tab" is
not.
- Breaks: word pills for hats; "Menu" as a word; labels like "Store quotes ·
  now → late Winter / t".
- Rule: every control has a drawing above its word; every service is a
  place on the island with a shape and a colour that never changes.
- Check: the kit's "sent back" list; a word in a box with no drawing fails.

### 6. Feedback within a second
Every tap must produce something seen and something heard before the player
wonders whether it worked. Silence after a tap is read as "broken".
- Breaks: planting with no cue; a guide button that does not respond for
  half a second.
- Rule: under 100 ms to a visible change, under 300 ms to a sound, for
  every tap. A refused action still answers: a short shake and one line.
- Check: the browser fixture measures tap-to-change latency for the five
  tools and all card buttons.

### 7. Chunking and grouping
Things that belong together sit together, look alike and are counted in
threes. Things that do not belong together are separated by space, not by
lines.
- Breaks: the Winter card mixing jobs and facts; the top band mixing name,
  season, money and market.
- Rule: one kind of thing per block; three items per block before a
  heading; related items share one colour (the connection colour rule).
- Check: no card with more than three items under one heading.

### 8. Plain words, short sentences, one idea each
Reading is the most expensive thing a screen can ask for. Each sentence
costs a second and a decision to keep reading.
- Breaks: "10x waits; 1x warnings. One mild Summer storm teaches loss."
- Rule: twelve words per instruction, eight per keeper line, no semicolons,
  no key codes on phone, no jargon ("Table" gets its gloss the first three
  times).
- Check: a suite test fails any guide or keeper string over the limit.

### 9. Consistency and mapping
The same thing looks and behaves the same way everywhere. A tap that opens
a page from the left should close to the left. A keeper's colour on the
Winter card is the colour of their page.
- Breaks: pages entering from nowhere; stamps in different styles on the
  bed, the barn and the sell row.
- Rule: one panel entry motion per source; one stamp component; one keeper
  header component; the kit page is the reference.
- Check: side-by-side screenshots against the kit per screen.

### 10. Errors that teach, undo that forgives
A refused action should say why in one line, and a mistaken action should
be reversible for a moment. Fear of mistakes is attention spent not playing.
- Breaks: blocked-action text replacing the instruction; no way to take
  back a sale.
- Rule: refusal shows the reason under the instruction, never instead of
  it. A sale or a bet shows "Undo" for three seconds.
- Check: the blocked-action screenshot shows both lines.

## Part 2 · Hooking: give the attention somewhere to go

### 11. Anticipation is the reward
Dopamine responds to the expectation of a reward more than to the reward.
The drumroll before the pack flip matters more than the pack's contents.
- Rule: every reveal has a wind-up of 0.6 to 1.2 s (drumroll, card rising,
  a pause) before the result. Never instant.
- Check: the Pedlar flip, the Pub settlement and the sale reveal each have
  a measured wind-up in that range.

### 12. Variable reward
Rewards that sometimes do not come are what bring people back; rewards
that always come are wages. Balatro's shop might sell garbage.
- Rule: packs, rumours and oddities have printed odds, and the odds include
  real duds (the lucky stone that does nothing).
- Check: odds printed on every pack and bet; a dud outcome exists for each.

### 13. Open loops (the Zeigarnik effect)
Unfinished things stay in mind. A bet placed, a pack unopened, a rumour on
the board: each is a reason to come back next season.
- Rule: one open loop visible at the end of every season, drawn on the
  play screen, never as text.
- Check: the end-of-season screenshot for each season shows exactly one
  open-loop marker.

### 14. Goal gradient
Effort rises as the goal gets close. People finish what they can see the
end of.
- Rule: the Winter bill is a bar that fills with every sale; the last tonne
  before break-even gets the biggest pop and a bell. Nell's "Write the
  date down" plays once, at the first profitable year.
- Check: the break-even moment has its own cue and card.

### 15. Endowed progress
A card with one stamp on it is a set to complete; an empty card is a
chore.
- Rule: new players start with twelve seeds, one filled superstition slot and one
  oddity already in the collection. Every collection page has at least one
  entry before the player has done anything.
- Check: a fresh save shows no empty collection page.

### 16. Small wins early
The first five minutes decide everything. A win is something the player
did, not something they read.
- Rule: first harvest within three minutes of play, first pack flip within
  five, first Table stamp in year one, first Fair rosette by year two.
- Check: the guided-year timeline in the browser fixture hits those marks.

### 17. Peak and end
People remember the best moment and the last moment of a session, not the
average. End on the high.
- Rule: every year ends on the sale reveal, never on the bill. The Fair is
  the peak of the year and gets confetti and a trumpet. Foreclosure is one
  drawing and one sentence, then "Start again" in the same breath.
- Check: the Winter sequence order is settlement, bill, reveal, Nell's
  line, in that order.

### 18. Flow: challenge just above skill
Too easy is boring; too hard is quitting. The guided year is too easy and
year two is a cliff.
- Rule: year one guided, year two with the Pedlar and no disasters, year
  three onward the full climate; bills rise with the curve so the wall is
  always just above last year's best.
- Check: the bot's cautious strategy survives year two in 30 of 30 seeds.

### 19. Investment and ownership
People value what they have shaped. The farmer they dressed, the superstition
they chose, the oddity they named.
- Rule: the player names the farmer and the farm; the farm name is on the
  gate sign; the epilogue uses both.
- Check: the gate sign shows the player's farm name after the first card.

### 20. Social proof and a watching world
A village that reacts makes a choice feel seen. The newspaper's gossip
line about you, the Pub cheering, Nell's one smile.
- Rule: every season, one line somewhere in the village refers to
  something the player actually did.
- Check: the newspaper gossip line is generated from the ledger, not from
  a fixed list.

### 21. Curiosity gaps
A face-down card, a locked tile with a silhouette, a superstition name with no
description until owned.
- Rule: the collection shows silhouettes of unfound oddities and superstitions,
  never a blank slot and never a full reveal.
- Check: the "What I've grown" page shows silhouettes for unknowns.

### 22. Loss aversion, used gently
Losing hurts about twice as much as winning feels good. Used hard it is
cruelty; used gently it is tension.
- Rule: losses are always small and legible (one tonne, one bet) and never
  compound; the comeback cap after a two-disaster year stays.
- Check: no single event can take more than a fifth of the purse.

### 23. Cue, routine, reward
Habits form around a cue. The season change is the cue; the routine is the
three things to do; the reward is the reveal.
- Rule: every season opens with one card naming the three things to do
  this season, and closes with one reveal.
- Check: four season-open cards, four season-close reveals, no more.

## Banned
Streak guilt, timers that punish absence, fake scarcity, hidden odds, login
rewards, real money, compounding. These hook people too, and they are why
tester 1's "only pain" would become "only pain, but I can't stop".
