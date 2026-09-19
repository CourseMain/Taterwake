# Changelog

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
