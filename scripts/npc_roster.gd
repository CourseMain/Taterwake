extends RefCounted
## Dialogue is flavour and guidance. Choices never spend money or change odds.
const PEOPLE := {
	"mara": {"name":"Mara", "role":"Seed seller", "service":"market", "service_label":"Browse seeds", "color":"769751", "skin":"dbab78", "shape":Vector3(1.0,1.0,1.0), "hat":"straw_hat", "detail":"flower",
		"first":"Mara. Seeds are in the sacks; the blue stitches are mine. Mind that crate. One leg is a potato and I'd rather not discuss it.",
		"daily":["That sack's on its third patch. Seeds inside are fresh. I make the distinction because Bram asked.", "I've moved the good sacks out of the drip. The roof and I are still negotiating."],
		"topic":"You mend all these sacks?", "story":"Nell brings me the torn ones. Blue thread for a split seam, red for a mouse hole. That big patch? Giant seed delivery. Bram said the crate was sound. The crate disagreed.",
		"reply":"I'll bring the empties back.", "answer":"Good. Fold them dry. Anyone can sell you a new sack; these have learned where to bend.",
		"help":"Any planting advice?", "advice":"Buy a seed you can afford to replace. Till the bed, plant it, water it. When the top goes full and leafy, pull. If it's a giant, plant your feet first.",
		"thanks":"There's my sack-returner. Blue stitching held, then? Knew it would.", "weather":"I've double-stitched the sacks. Can't do much for the clouds. Get your ripe crops in."},
	"bram": {"name":"Bram", "role":"Toolsmith", "service":"tools", "service_label":"See tool upgrades", "color":"926448", "skin":"b78458", "shape":Vector3(1.12,.96,1.05), "hat":"prospectors_hat", "detail":"brows",
		"first":"Bram. Let me see that hoe. Handle's loose. Here—hold it now.",
		"daily":["Handle still tight? Good. Mud off before you hang it up.", "Nearly done. Hear that? No rattle. That's the test."],
		"topic":"Do you make everything here?", "story":"Most of it. My father made that old hammer. Changed the handle twice. Still reach for it before the new ones.",
		"reply":"Sounds like it means a lot.", "answer":"Fits my hand. That's enough. Pass me your hoe.",
		"help":"Which upgrade helps?", "advice":"Wider head. More beds per swing. Pick the tool you wear out fastest. Test it on one small patch before the whole field.",
		"thanks":"Hammer's sound again. Yours next.", "weather":"Tools can wait. Ripe crops can't. Go."},
	"nell": {"name":"Nell", "role":"Barn keeper", "service":"barn", "service_label":"Open the barn", "color":"658c86", "skin":"edc797", "shape":Vector3(1.08,.94,1.0), "hat":"", "detail":"glasses",
		"first":"Nell. I keep the barn in order. If you leave something on the floor, I'll find a shelf for it.",
		"daily":["Someone's been putting muddy boots on my clean sacks. I have my suspicions.", "I like it in here before everyone arrives. Nice and quiet."],
		"topic":"Who left the muddy boots?", "story":"Ada claims the footprints are too small to be hers. Pip blames the ducks. I've never seen a duck wear a size six.",
		"reply":"I'll wipe mine next time.", "answer":"You're already my favourite visitor. Don't tell the others.",
		"help":"Can we make more room?", "advice":"Of course. There's a barn upgrade right above your stored crops. You can check the cost and extra space before buying.",
		"thanks":"Look who's remembered to wipe their boots. Come in.", "weather":"I'm checking the stored crops. Have a look at our barn protection at the weather station."},
	"tess": {"name":"Tess", "role":"Quest keeper", "service":"quests", "service_label":"Check local quests", "color":"bd766b", "skin":"c68c61", "shape":Vector3(.92,1.05,.96), "hat":"", "detail":"scarf",
		"first":"You're the farmer everyone's talking about. I'm Tess. Sorry—let me put these notices down.",
		"daily":["I came here to pin up one notice. That was an hour ago.", "Someone's asked me to organise a meeting about how many meetings we have."],
		"topic":"Do you ever take a break?", "story":"I was going to have lunch with Pip. Then the board needed sorting. Pip brought my lunch here instead. It had a duck feather in it.",
		"reply":"You should still take that break.", "answer":"I should. Thank you. I'll finish this page, then go. Hold me to it.",
		"help":"How can I help out?", "advice":"Have a look at the local quests. Pick one that fits what you're already growing, then come back to claim its reward.",
		"thanks":"I took that break. Pip says you deserve the credit.", "weather":"I'm checking who needs help. Some farms got hit harder than ours."},
	"pip": {"name":"Pip", "role":"Duck caretaker", "service":"duck_patrol", "service_label":"Visit Duck Patrol", "color":"e1b550", "skin":"eac291", "shape":Vector3(.93,.88,.94), "hat":"patchwork_cap", "detail":"duck",
		"first":"I'm Pip. That one's Button. Don't let the name fool you.",
		"daily":["I counted six ducks and seven shadows. Took me a minute to realise one was mine.", "Button's decided that's his path. We all go round now."],
		"topic":"What's Button been doing?", "story":"Following Nell into the barn. He waits until she's swept, then walks straight through the pile. I think he likes the attention.",
		"reply":"He sounds like a handful.", "answer":"He is. Wouldn't swap him, though. He found more beetles than the rest yesterday.",
		"help":"How do patrol ducks help?", "advice":"They clear pests from planted beds on the island you're visiting. Hire them here, then give them room to work.",
		"thanks":"Button remembers you. That's a good thing. Usually.", "weather":"I've counted them three times. Button keeps walking behind me."},
	"ada": {"name":"Ada", "role":"Workshop mechanic", "service":"builds", "service_label":"Open Builds", "color":"ce914d", "skin":"c99567", "shape":Vector3(1.02,1.02,1.0), "hat":"", "detail":"goggles",
		"first":"Ada. Watch your sleeve near that gear. There—now we can talk.",
		"daily":["Hear that rattle? Neither do I. Finally.", "I meant to fix one thing. Somehow there are three things on the bench now."],
		"topic":"What are you working on?", "story":"The sorter. It works perfectly until someone watches it. Bram says machines can't get nervous. I'd like him to explain this one.",
		"reply":"I'll give you some space.", "answer":"Stay, actually. If it jams again, I need a witness.",
		"help":"Explain Builds to me.", "advice":"Each Build supports a different way to farm. All Builds are available. Check their abilities before choosing what to work towards.",
		"thanks":"My witness returns! The sorter behaved as soon as you left.", "weather":"Water got into everything last time. I'm getting the tools off the floor."},
	"hollis": {"name":"Captain Hollis", "role":"Ferry captain", "service":"island", "service_label":"Plan a crossing", "color":"52798c", "skin":"d5aa7b", "shape":Vector3(1.03,1.04,1.0), "hat":"", "detail":"captain",
		"first":"Hollis. First crossing? Sit where you can see the horizon. Helps with the swell.",
		"daily":["There you are. How's the farm holding up?", "Left my tea on the pier again. It'll be cold by now."],
		"topic":"Have you sailed here long?", "story":"Long enough to know every sound this boat makes. Used to know the weather that well, too. Lately I check the readings before each crossing.",
		"reply":"That must feel strange.", "answer":"It does. No shame in checking what you thought you knew. Especially with passengers aboard.",
		"help":"Tell me about the islands.", "advice":"Spud Valley's home. Golden Shores has Sunburst crops and a weather station. Frosthollow has Icecaps—and a furnace you'll be glad to see.",
		"thanks":"Welcome back. I've checked the readings. Old habits can change.", "weather":"I don't like those clouds. Check the forecast before you settle into your fields."},
	"iris": {"name":"Iris", "role":"Weather observer · radio link", "service":"climate", "service_label":"See weather & protection", "color":"6b9daa", "skin":"b9825c", "shape":Vector3(.94,1.02,.98), "hat":"", "detail":"headset",
		"first":"Can you hear me? Good. I'm Iris. This station sends me your local weather readings.",
		"daily":["Clear for now. I'm checking the next reading.", "Hollis called twice this morning. He says he's only checking the radio works."],
		"topic":"What do the readings show?", "story":"The changes used to be gradual enough to plan around. Now the gaps between bad spells are harder to predict. I check twice before sending a warning.",
		"reply":"Thanks for keeping watch.", "answer":"Thanks for listening. A warning only helps if someone has time to act on it.",
		"help":"How do I protect the farm?", "advice":"The station shows your protection stats and sells upgrades. Sprinklers and irrigation are one purchase that carries across islands. You'll still need water in the tank.",
		"thanks":"Good to hear your voice again. I've got the latest readings here.", "weather":"The readings are changing quickly. Check your protection while there's time."},
	"oren": {"name":"Oren", "role":"Frosthollow furnace keeper", "service":"activities", "service_label":"Open the furnace", "color":"967061", "skin":"c58e62", "shape":Vector3(1.15,1.0,1.10), "hat":"", "detail":"beanie",
		"first":"Come closer. You're letting all that warmth go to waste. Oren, by the way.",
		"daily":["Cold hands? Don't pretend they aren't. I can hear your teeth.", "Bram sent another box of handles. Good wood. He always picks good wood."],
		"topic":"Do you ever leave the furnace?", "story":"For supper. Sometimes. I used to shut it down earlier, but the cold's been catching people out. I'd rather someone found a light on.",
		"reply":"I'm glad you're here.", "answer":"Well. Someone has to be. Warm yourself up before you go.",
		"help":"How do I thaw frozen crops?", "advice":"Open the furnace and heat your hoe. Then use the Hoe on frozen beds before its heat runs out. I'll heat it again for free if you need another trip.",
		"thanks":"Saved you a spot by the fire. Don't make a fuss about it.", "weather":"Beds iced over? Heat your hoe here, then get back to them before it cools."},
	"edwin": {"name":"Edwin", "role":"Tax collector", "service":"taxes", "service_label":"Review the tax bill", "color":"78847a", "skin":"ddbb91", "shape":Vector3(.94,1.07,.98), "hat":"traders_visor", "detail":"spectacles",
		"first":"Afternoon. Edwin. I've brought the figures. Shall we go through them?",
		"daily":["I hope I'm not catching you at a bad time. I do seem to have a talent for it.", "Nell lent me a dry folder. I'd like to return it in the same condition."],
		"topic":"Do people mind you visiting?", "story":"Some do. I understand. I try to explain the figures properly. My mother says I should ask about people's day before mentioning the bill.",
		"reply":"Well, how was your day?", "answer":"Oh. Quite nice, actually. Thank you for asking. I saw ducklings by the pier.",
		"help":"How do these bills work?", "advice":"The tax panel shows your next bill and the time left. Check the forecast before spending a big harvest. Any recovery relief appears in your figures.",
		"thanks":"Afternoon. How's your day been? See—I'm learning.", "weather":"I saw the damage coming in. I'm sorry. Let's check what recovery relief applies."}
}

static func for_station(station: String, island: int) -> String:
	if station == "activities": return "oren" if island == 3 else "tess" if island == 2 else "pip"
	if station == "blinds": return "edwin"
	for id: String in PEOPLE:
		if PEOPLE[id].service == station: return id
	return ""

static func available(id: String, island: int) -> bool:
	return PEOPLE.has(id) and (id != "iris" or island >= 2) and (id != "oren" or island == 3)

static func greeting(id: String, state, record: bool = false) -> String:
	var p: Dictionary = PEOPLE[id]
	var memory: Dictionary = state.npc_history.get(id, {})
	var visits: int = int(memory.get("visits", 0))
	var pool: Array = p.daily.duplicate()
	var weather: bool = state.current_island == int(state.climate.data.island) and state.climate.data.phase in ["warning", "active", "recovery"]
	var line: String = p.first if visits == 0 else str(pool[visits % pool.size()])
	if bool(memory.get("kind", false)): line = p.thanks
	if id == "nell" and state.barn_level == 0 and visits > 0 and not bool(memory.get("kind", false)): line = "Getting tight in here. We can expand the barn whenever you're ready."
	if weather: line = p.weather
	if line == str(memory.get("last", "")): line = str(pool[visits % pool.size()])
	if record:
		state.npc_history[id] = {"visits":mini(visits + 1, 1000000), "last":line, "kind":bool(memory.get("kind", false))}
	return line

static func weather_line(id: String, state) -> String:
	var event: String = str(state.climate.data.event)
	var local: bool = state.current_island == int(state.climate.data.island)
	if local and state.climate.data.phase in ["warning", "active"]:
		var advice: String = {"freeze":"Frozen beds need a heated hoe. Oren can heat yours at the furnace.", "drought":"Fill the tank and keep the beds watered. The weather station shows your protection.", "flood":"Check the drains and open the gates before the water builds up.", "storm":"Get ripe crops in before lightning hits. Check your protection at the station."}.get(event, "Check the latest forecast at the weather station.")
		if id == "oren" and event == "freeze": advice = "I can heat it again for free if it cools. Save as many beds as you can, then come back and warm your hands."
		return str(PEOPLE[id].weather) + "\n\n" + advice
	if local and state.climate.data.phase == "recovery": return "It's easing off. There's still a bit of clearing up to do. How did your farm get through it?"
	if state.current_island == 1: return "Quiet here today. Hollis says the weather over Golden Shores has been less settled. Ask at the station when you get there."
	return "It's calm for now. I wouldn't leave everything until the next warning, though. The weather station has the latest forecast."

static func valid_history(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() > PEOPLE.size(): return false
	for id in raw:
		if not PEOPLE.has(id) or not raw[id] is Dictionary: return false
		var m: Dictionary = raw[id]
		var visits: Variant = m.get("visits")
		if not (visits is int or visits is float) or not is_finite(float(visits)) or visits < 0 or visits > 1000000 or float(visits) != floorf(float(visits)): return false
		if not m.get("kind") is bool or not m.get("last") is String or m.last.length() > 600: return false
	return true
