extends RefCounted
## Dialogue is flavour and guidance. Choices never spend money or change odds.
const GUIDED_CREDIT_LINE: String = "Dad's last harvest paid this year. From now on it's yours."
const PEOPLE := {
	"mara": {"name":"Mara", "role":"Seed seller", "service":"market", "service_label":"Browse seeds", "color":"769751", "skin":"dbab78", "shape":Vector3(1.0,1.0,1.0), "hat":"straw", "detail":"flower",
		"first":"Mara. Seeds are in the bags; the blue stitches are mine. Mind that crate. One leg is a potato and I'd rather not discuss it.",
		"daily":["That bag's on its third patch. Seeds inside are fresh. I make the distinction because Bram asked.", "I've moved the good bags out of the drip. The roof and I are still negotiating."],
		"topic":"You mend all these bags?", "story":"Nell brings me the torn ones. Blue thread for a split seam, red for a mouse hole. That big patch? Giant seed delivery. Bram said the crate was sound. The crate disagreed.",
		"reply":"I'll bring the empties back.", "answer":"Good. Fold them dry. Anyone can sell you a new bag; these have learned where to bend.",
		"help":"Any planting advice?", "advice":"Buy a seed you can afford to replace. Till the bed, plant it, water it. When the top goes full and leafy, pull. If it's a giant, plant your feet first.",
		"thanks":"There's my bag-returner. Blue stitching held, then? Knew it would.", "weather":"I've double-stitched the bags. Can't do much for the clouds. Get your ripe crops in."},
	"bram": {"name":"Bram", "role":"Toolsmith", "service":"tools", "service_label":"See tool upgrades", "color":"926448", "skin":"b78458", "shape":Vector3(1.12,.96,1.05), "hat":"worklamp", "detail":"brows",
		"first":"Bram. Let me see that hoe. Handle's loose. Here—hold it now.",
		"daily":["Handle still tight? Good. Mud off before you hang it up.", "Nearly done. Hear that? No rattle. That's the test."],
		"topic":"Do you make everything here?", "story":"Most of it. My father made that old hammer. Changed the handle twice. Still reach for it before the new ones.",
		"reply":"Sounds like it means a lot.", "answer":"Fits my hand. That's enough. Pass me your hoe.",
		"help":"Which upgrade helps?", "advice":"Wider head. More beds per swing. Pick the tool you wear out fastest. Test it on one small patch before the whole field.",
		"thanks":"Hammer's sound again. Yours next.", "weather":"Tools can wait. Ripe crops can't. Go."},
	"nell": {"name":"Nell", "role":"Accountant", "service":"barn", "service_label":"Open the barn", "color":"658c86", "skin":"edc797", "shape":Vector3(1.08,.94,1.0), "hat":"", "detail":"glasses",
		"first":"Nell. Barn and books. Crops in before rot.",
		"daily":["Someone's been putting muddy boots on my clean bags. I have my suspicions.", "I like it in here before everyone arrives. Nice and quiet."],
		"topic":"Who left the muddy boots?", "story":"Ada claims the footprints are too small to be hers. Pip blames the ducks. I've never seen a duck wear a size six.",
		"reply":"I'll wipe mine next time.", "answer":"You're already my favourite visitor. Don't tell the others.",
		"help":"What goes in the accounts?", "advice":"Payments: seeds, sales, storage, mortgage, rent, living. Unsold potatoes aren’t income. Winter totals—bring a chair.",
		"thanks":"Look who's remembered to wipe their boots. Come in.", "weather":"I'm checking the stored crops."},
	"tess": {"name":"Tess", "role":"Quest keeper", "service":"quests", "service_label":"Visit Tess’s board", "color":"bd766b", "skin":"c68c61", "shape":Vector3(.92,1.05,.96), "hat":"", "detail":"scarf",
		"first":"Tess. Beds first. Weather damage next.",
		"daily":["Mud in both boots. That is the complete morning report.", "I sharpened the hoe. The clouds remain unimpressed."],
		"topic":"Do you ever take a break?", "story":"I was going to have lunch with Pip. Then the drains backed up. Pip brought my lunch to the field instead. It had a duck feather in it.",
		"reply":"You should still take that break.", "answer":"I should. Thank you. One more row, then I go. Hold me to it.",
		"help":"How can I help out?", "advice":"Cause card: what hit, tonnes lost, protection’s savings. Nell winces.",
		"thanks":"I took that break. Pip says you deserve the credit.", "weather":"I'm checking who needs help. Some farms got hit harder than ours."},
	"pip": {"name":"Pip", "role":"Duck caretaker", "service":"duck_patrol", "service_label":"Visit Duck Patrol", "color":"e1b550", "skin":"eac291", "shape":Vector3(.93,.88,.94), "hat":"cap", "detail":"duck",
		"first":"I'm Pip. That one's Button. Don't let the name fool you.",
		"daily":["I counted six ducks and seven shadows. Took me a minute to realise one was mine.", "Button's decided that's his path. We all go round now."],
		"topic":"What's Button been doing?", "story":"Following Nell into the barn. He waits until she's swept, then walks straight through the pile. I think he likes the attention.",
		"reply":"He sounds like a handful.", "answer":"He is. Wouldn't swap him, though. He found more beetles than the rest yesterday.",
		"help":"How do patrol ducks help?", "advice":"They clear pests from planted beds on your farm. Hire them here, then give them room to work.",
		"thanks":"Button remembers you. That's a good thing. Usually.", "weather":"I've counted them three times. Button keeps walking behind me."},


	"iris": {"name":"Iris", "role":"Weather forecaster", "service":"climate", "service_label":"See weather & protection", "color":"6b9daa", "skin":"b9825c", "shape":Vector3(.94,1.02,.98), "hat":"", "detail":"headset",
		"first":"Can you hear me? Good. I'm Iris. This station sends me your local weather readings.",
		"daily":["Clear for now. I'm checking the next reading.", "Bram called twice this morning. He says he's only checking the radio works."],
		"topic":"What do the readings show?", "story":"The changes used to be gradual enough to plan around. Now the gaps between bad spells are harder to predict. I check twice before sending a warning.",
		"reply":"Thanks for keeping watch.", "answer":"Thanks for listening. A warning only helps if someone has time to act on it.",
		"help":"How do I protect the farm?", "advice":"The forecast is a probability, not a promise. A better station narrows its uncertainty. Budget for tanks, drains, windbreaks or Spring frost covers in Winter. None protects against everything.",
		"thanks":"Good to hear your voice again. I've got the latest readings here.", "weather":"The readings are changing quickly. Check your protection while there's time."},

	"edwin": {"name":"Edwin", "role":"Bank manager", "service":"bank", "service_label":"Review the overdraft", "color":"78847a", "skin":"ddbb91", "shape":Vector3(.94,1.07,.98), "hat":"visor", "detail":"spectacles",
		"first":"Afternoon. Edwin. I've brought the figures. Shall we go through them?",
		"daily":["I hope I'm not catching you at a bad time. I do seem to have a talent for it.", "Nell lent me a dry folder. I'd like to return it in the same condition."],
		"topic":"Do people mind you visiting?", "story":"Some do. I understand. I try to explain the figures properly. My mother says I should ask about people's day before mentioning the paperwork.",
		"reply":"Well, how was your day?", "answer":"Oh. Quite nice, actually. Thank you for asking. I saw ducklings by the pier.",
		"help":"What does the limit mean?", "advice":"You can use the overdraft to keep farming. If Winter settlement takes you below the limit, the farm is foreclosed. Seeds, repairs and the next Winter bills all draw on the same balance. I would much rather leave with an empty folder.",
		"thanks":"Afternoon. How's your day been? See—I'm learning.", "weather":"I saw the damage coming in. I'm sorry. Let's see who needs help."}
}

static func for_station(station: String) -> String:
	if station == "activities": return "pip"
	for id: String in PEOPLE:
		if PEOPLE[id].service == station: return id
	return ""

static func available(id: String, state = null) -> bool:
	return PEOPLE.has(id) and (id != "edwin" or state == null or state.coins < state.bankruptcy_limit() * 0.5)

static func ledger_lines(state) -> String:
	var line: String = "Year %d net: %s.\nPurse: %s. Unsold potatoes do not pay the mortgage." % [state.season_clock.year, state.money(state.ledger.total(state.season_clock.year)), state.money(state.coins)]
	if state.ledger.guided_credit(state.season_clock.year) > 0: line = GUIDED_CREDIT_LINE + "\n" + line
	return line

static func weather_cost(state) -> String:
	var losses: Array = state.climate.data.protection.losses
	for i in range(losses.size() - 1, -1, -1):
		var entry: Dictionary = losses[i]
		if int(entry.year) != state.season_clock.year or entry.event in ["pests", "spoilage"]: continue
		var value: float = int(entry.sacks) * float(state.CropTable.CROPS[entry.crop].base)
		return "%s: %d t of %s lost, %s base value. No cash charge. Same bills." % [str(entry.event).replace("_", " ").capitalize(), int(entry.sacks), state.CropTable.CROPS[entry.crop].name, state.money(value)]
	return "No weather loss recorded this year. I'll take an empty page. The bills will still arrive."

static func bank_line(state) -> String:
	return "Your overdraft is %s of %s. More than half used. The next Winter bills still have to fit. I have brought a pencil, not more money." % [state.money(maxf(0, -state.coins)), state.money(-state.bankruptcy_limit())]

static func forecast_line(state) -> String:
	if not state.tutorial_progress.completed and state.season_clock.year == 1:
		return "Iris, on the radio. This guided first year has one small Summer storm. After your first accounts, the forecasts are probabilities. The weather won't wait for us."
	return "Iris, on the radio. Year %d: %d%% disaster chance each season. These are odds, not appointments. Read the sky, leave room in the budget." % [state.season_clock.year, roundi(state.ClimateSystem.chance(state.season_clock.year) * 100)]

static func advice(id: String, state) -> String:
	if id == "nell" and state.season_clock.season == 3: return ledger_lines(state)
	if id == "edwin": return bank_line(state)
	return PEOPLE[id].advice

static func greeting(id: String, state, record: bool = false) -> String:
	var p: Dictionary = PEOPLE[id]
	var memory: Dictionary = state.npc_history.get(id, {})
	var visits: int = int(memory.get("visits", 0))
	var pool: Array = p.daily.duplicate()
	var weather: bool = state.climate.data.phase in ["warning", "active", "recovery"]
	var line: String = p.first if visits == 0 else str(pool[visits % pool.size()])
	if bool(memory.get("kind", false)): line = p.thanks
	if weather: line = p.weather
	if line == str(memory.get("last", "")): line = str(pool[visits % pool.size()])
	# Reports keep their figures even on repeated visits; flavour never replaces
	# an unfavourable balance or turns a physical loss into fictional spending.
	if id == "nell" and state.season_clock.season == 3: line = ledger_lines(state)
	if id == "edwin": line = bank_line(state)
	if record:
		state.npc_history[id] = {"visits":mini(visits + 1, 100000), "last":line, "kind":bool(memory.get("kind", false))}
	return line

static func weather_line(id: String, state) -> String:
	var event: String = str(state.climate.data.event)
	if state.climate.data.phase in ["warning", "active"]:
		var advice: String = {"freeze":"Use your hoe to clear ice from frozen beds.", "drought":"Fill the tank and keep the beds watered. The weather station shows your protection.", "flood":"Check the drains and open the gates before the water builds up.", "storm":"Get ripe crops in before lightning hits. Check your protection at the station."}.get(event, "Check the latest forecast at the weather station.")
		return str(PEOPLE[id].weather) + "\n\n" + advice
	if state.climate.data.phase == "recovery": return "It's easing off. There's still a bit of clearing up to do. How did your farm get through it?"
	return "It's calm for now. I wouldn't leave everything until the next warning, though. The weather station has the latest forecast."

static func valid_history(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() > PEOPLE.size(): return false
	for id in raw:
		if not PEOPLE.has(id) or not raw[id] is Dictionary: return false
		var m: Dictionary = raw[id]
		var visits: Variant = m.get("visits")
		if not (visits is int or visits is float) or not is_finite(float(visits)) or visits < 0 or visits > 100000 or float(visits) != floorf(float(visits)): return false
		if not m.get("kind") is bool or not m.get("last") is String or m.last.length() > 600: return false
	return true
