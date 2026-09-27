# Changelog

## 1.0.2.75

- Removed the extra price strip while planting. Seed packets now show separate, ruled Seeds and In barn counts on desktop and touch controls.
- Replaced shop gradients with solid canvas, navy/copper and barn-red palettes, dark inventory labels, small corners and framed price tags.

- Fixed NPC portraits disappearing behind the conversation background.
- Restricted buying on account to existing tax debt, with confirmation near bankruptcy and blocked purchases beyond the limit.
- Added separate paid land expansions on every island. Existing planted beds remain accessible when older saves receive the new land locks.
- Softened Seeds, Tools and Barn with distinct lighting, rounded surfaces and gentle opening transitions; fixed mobile equipment text and shop layout overflow.

- Compost opens Farmer’s compost controls directly, with its perk, cost and 3× harvest benefit shown together.
- Added short, varied “potato” voices for all 11 NPCs. Each villager has a distinct pitch and rhythm; revealing text or leaving a conversation stops speech.

- Kept held camera drags active through motion events with missing button masks; release, focus loss and menus still end the gesture.
- Removed extra Builds guide cards, repeated usage instructions and optional coaching links. Replaced the long Help page with compact controls.

- Added drag-to-pan directly on the island with mouse or one finger; retained angled view, zoom, WASD, joystick and bed/shop taps. Blank-ground taps no longer walk.
- Fixed narrow, vertically stretched Weather Station buttons. Added the navy/cyan radar dashboard and tech station exterior.
- Rebuilt the potato furnace as a warm brick-and-copper hearth, with glowing embers and a matching compact UI. Bellows remain free; fuel and boost timings are unchanged.
- Gave each island its own relic and mystery artifact pool, strengthened artifact effects, restored a useful Trader Token bonus, and scaled completed-collection payouts to 2×/5× the stake. Quest cash scales with each island economy; longer challenges award an Almanac, Tideglass Lens or Aurora Heart. Existing quest claims remain claimed.
- Reworked seed buying, selling, Tools, Barn and build pages; added casino colours and lights throughout the Roll House and a cuter duck pond panel. Removed repeated slogans, tutorial filler and automatic reminder banners.
- Added harvest pull/pop/landing feedback and original tool/harvest sounds, unified crop growth with the intro model, varied NPC facing, and added repaired sacks, crates and purposeful village details.
- Added bounded farm purchase credit and crop-based debt repayment. Barn-full and blocked expansion alerts use clear red warnings.
- Added textured snowbanks, sandy shores with shells, and transparent compact fullscreen controls.

## 1.0.2.5

- Added eleven named NPCs with distinct 3D appearances, animated close-up conversations, optional dialogue choices and contextual weather advice. Friendly replies and introductions persist in saves.
- Staffed shops now begin with a conversation, followed by a choice to access their service. Stallholders stand at their shops, with a shallow seed awning that keeps Mara visible. White, black-outlined E keycaps sit above nearby characters; dialogue uses outlined speech bubbles, coloured name tags and golden service choices.
- Conversations pause farm clocks, hide touch movement controls and suspend background farm rendering. Portraits and choices adapt to phone, tablet and laptop screens. Browser fullscreen restores keyboard focus to the game, and rotating a phone keeps the canvas correctly proportioned.

- Added a first-arrival Island 2 sky cinematic with subtitles and skip controls; farm clocks pause during it.
- Added animated weather stations on Islands 2 and 3, with forecasts, visible protection stats and equipment purchases outside the tax menu.
- Sprinklers and irrigation now require a purchase and carry across all islands. Existing saves retain their highest owned level; water practice no longer grants free equipment.
- Added an Island 3 Deep Freeze disaster: crops freeze, stop growing and build cold stress. Heat the hoe at the furnace, then thaw them with Hoe [1]. Emergency bellows need no crop fuel; Frostgold resists freezing.
- Separated compost from sprinklers, the tank from the workshop, and the buyer board from ducks. Cleared station sightlines and reduced desktop HUD obstruction with a compact tax row and a bottom stock countdown.

- Added a small, tappable E badge for the nearest NPC or shop, with keyboard interaction across all islands. Crop beds keep their existing tool actions.
- Moved barn upgrades above the inventory tabs, with a beginner tip, added-space preview and a clear maximum-level state.
- Moved fullscreen to a compact × in the top-left corner and adjusted nearby HUD elements to leave it clear.

## 1.0.2

### Touch controls and fullscreen

- Added a movement stick with sprint at the outer edge, a nearby action button, quick selling and compact tool/seed drawers. All activities, builds, inventory, upgrades, quests, travel, saves and settings remain available through Menu.
- Added two-finger pinch zoom on the farm. Pinches never plant, harvest or walk by accident. Small +/− zoom buttons live inside Tools.
- Added large touch targets, scrolling menus, portrait/landscape layouts and scrollable equipment cards for phones and iPads. Controls clear while menus, climate introductions and the rocket film are open; losing focus clears held movement.
- Added browser/native fullscreen buttons and F11. Unsupported mobile browsers explain the Home Screen option. Browser layout follows rotation, fullscreen changes and screen safe areas.

### Five farming professions

- Farmer cultivates a planted crop with compost, then waters and harvests a giant potato with 3× yield. Targeting persists until used or cancelled.
- Industrialist loads production batches, matches processing methods and sells F–SSS graded harvests.
- Scientist crosses harvested crops into a permanent seed bank; Investor reserves a buyer's price and delivers shipments; Gambler stakes harvested crops with explicit costs and possible losses.
- Illustrated profession pages show readiness, costs, equipment and ongoing jobs. Optional drawers explain bonuses without crowding the main action.

### Climate, water and taxes

- Island 1 introduces the visible rain → tank → watering can → crop loop. Island 2 introduces connected sprinklers and optional safe water practice.
- Drought, flood and storms start on Island 2. Central warnings, animated clouds, rain, wind, original weather audio and bounded camera shake make the danger visible.
- Operate tanks, sprinklers and drainage; rescue stressed beds and fund reserves, reinforced barns and windbreaks. Disasters can damage crops and stored harvests, raise seed costs and crash sale prices during recovery.
- A tax collector visits after every third major stock and its full selling window. Forecasts show weather recovery pressure, the next bill and the bankruptcy boundary. Debt remains playable until that boundary is crossed.

### Quality of life

- A shorter first-harvest tutorial ends at the first sale; NPC tours and later farming help are optional.
- Islands have 50% more land area, connected ferry paths, continuous animated seas and icy Frosthollow water. Shift and touch sprint speed up travel; carried tools move more smoothly.
- Crop growth spans 10–60 seconds. Added clearer luck totals, an illustrated PotatoDex, debug island unlocks and explicit debt recovery tools.
- Simpler menus, clearer shop signs, quiet farming feedback and stable profession buttons improve readability. Fixed the tutorial guide overlapping the wider Roll House panel.
- Retains existing farm saves and the independent 3D graphics settings introduced in v1.0.1.75.

## 1.0.1.75

- Decoupled the 3D farm from the Retina-resolution UI. Smooth no longer blurs menu text or icons.
- Added Crisp mode with a larger farm render budget and 4× antialiasing; Balanced and Smooth retain 2×.
- Compiled immutable sibling geometry into shared vertex-colour surfaces and reused identical crop meshes. Animated roots, individual plants, colliders and gameplay references remain intact.
- Preserved map proportions and precise clicks across window sizes and all three islands.
- Stopped drawing the hidden farm during the rocket film; its 10-second selling window still starts after playback.
- Removed per-sample script work while audio is silent. Existing booms, sound effects, saves and economy rules are unchanged.
- Documented Safari alternatives and Low Power Mode troubleshooting.

## 1.0.1.5

- Rebuilt the Stock Rocket show around a glass potato cargo cabin, bright yellow/blue/red/orange/pink accents, money trails and a new original launch score.
- Boom magnitude now follows a smooth falling probability curve: higher percentages are progressively rarer. Stock gear improves scheduled/rocket roll strength without multiplying results into the ceiling; natural spikes remain independent of luck and gear.
- Removed large ocean-edge shadow artifacts, stabilized daylight shadow direction and reduced shadow rendering work. Day/night colours and lighting continue cycling.
- Added **Graphics → Balanced / Smooth**, saved separately on each device. Smooth removes cast shadows and lowers browser pixel load while preserving gameplay and the full rocket show.
- Preserved 10-second booms, the 1.5% natural spike trigger, all island ranges, saved farms and the code-locked debug controls.

## 1.0.1

- Stock booms last 10 seconds. Natural spikes have a flat 1.5% chance per fresh quote; their odds and strength ignore luck bonuses.
- Island 1–2 booms reach +500–2,999%; winter booms reach +3,000–10,000%. Higher scheduled booms remain rarer.
- Spend 30 minutes in winter to launch a Stock Rocket: a cinematic followed by a full 10-second +15,000–50,000% selling window. Clocks and farming pause for the film.
- Four stock-effect levels add island-coloured mist, pulses, music, coins and a rocket launch. Large balances now extend through Qa, Qi, Sx, Sp, Oc, No and Dc.
- Debug controls require an access code each session. Added 1×/2×/5×/10×/30× simulation speeds, a reset and a relock control.
- Reduced world draw calls by sharing and batching static meshes. Capped high-density browser rendering, used lighter web antialiasing and prebaked the rocket soundtrack.
- Clearer tutorial arrows and short instructions, with separate Next and End tutorial controls. Added walkable ferry routes on every island.
- Duck Patrol separates flock size and speed upgrades, retaining island caps of 1/2/3 ducks. Buyer contracts show bulk/mutation choices and partial shipment progress.
- Preserved existing saves, including active windows saved before their duration increased. Fixed rocket-boundary timer consistency and blocked inputs during the launch film.
