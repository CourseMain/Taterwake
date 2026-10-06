extends RefCounted
## Dialogue is flavour and guidance. Choices never spend money or change odds.
const YEAR_ONE_ACCOUNTS: String = preload("res://scripts/farm_advice.gd").YEAR_ONE
const GUIDED_CREDIT_LINE: String = "Dad's harvest paid this year. Next year: yours."
const PEOPLE := {
	"mara": {"name":"Mara", "role":"Seed seller", "service":"market", "service_label":"Browse seeds", "color":"6f9a4a", "skin":"dbab78", "shape":Vector3(1.0,1.0,1.0), "hat":"straw", "detail":"flower",
		"first":"Golden's fussy but it pays.",
		"daily":["Twelve in the pouch. Start with one.", "Fresh seed. I stitched the bags myself."],
		"topic":"You mend all these bags?", "story":"Blue stitches hold. These bags know their work.",
		"reply":"I'll bring the empties back.", "answer":"Lovely. Bring them back dry, won't you?",
		"help":"Any planting advice?", "advice":"Plant one. Water well. Keep another seed.",
		"thanks":"My bag-returner! Come see the fresh seed.", "weather":"Get yours in. I'll mind the seed."},
	"bram": {"name":"Oda", "role":"Toolsmith", "service":"tools", "service_label":"See tool upgrades", "color":"6b6b70", "skin":"b78458", "shape":Vector3(1.12,.96,1.05), "hat":"", "detail":"brows",
		"first":"Hoe's fine. Use it.",
		"daily":["Twelve more beds. Forty-eight.", "Mud off. Hang it."],
		"topic":"Do you make everything here?", "story":"Father's hammer. Still sound.",
		"reply":"Sounds like it means a lot.", "answer":"Fits my hand. Enough.",
		"help":"Which upgrade helps?", "advice":"Wider hoe. More beds.",
		"thanks":"Handle tight? Good.", "weather":"Tools wait. Crops don't."},
	"nell": {"name":"Nell", "role":"Accountant", "service":"accounts", "service_label":"Read the accounts", "color":"5e7a86", "skin":"edc797", "shape":Vector3(1.08,.94,1.0), "hat":"", "detail":"glasses",
		"first":"The bills don't care about the weather.",
		"daily":["Unsold potatoes aren't income.", "Storage costs. So does spoilage."],
		"topic":"Who left the muddy boots?", "story":"Every tonne sold goes in these books.",
		"reply":"I'll wipe mine next time.", "answer":"Bring receipts. I count money.",
		"help":"What goes in the accounts?", "advice":"The year's bills are 104,000.",
		"thanks":"Your receipts. On the desk.", "weather":"Same bills. Less stock."},
	"tess": {"name":"Tess", "role":"Quest keeper", "service":"quests", "service_label":"Visit Tess’s board", "color":"b5523c", "skin":"c68c61", "shape":Vector3(.92,1.05,.96), "hat":"", "detail":"scarf",
		"first":"Beds first. Weather damage next.",
		"daily":["Ice on six beds. Hoe.", "Three jobs left. None of them fun."],
		"topic":"Do you ever take a break?", "story":"Drain backed up. Lunch waited. Fixed the drain.",
		"reply":"You should still take that break.", "answer":"One more row. Then a break.",
		"help":"How can I help out?", "advice":"Count the damage. Clear it. Plant again.",
		"thanks":"You helped. Now get the next row.", "weather":"Get them in. Count the losses after."},
	"pip": {"name":"Pip", "role":"Duck caretaker", "service":"duck_patrol", "service_label":"Visit Duck Patrol", "color":"e1b550", "skin":"eac291", "shape":Vector3(.93,.88,.94), "hat":"cap", "detail":"duck",
		"first":"That one's Button. Mind your toes.",
		"daily":["Six ducks. Seven shadows. One was mine.", "Button owns this path. We go round."],
		"topic":"What's Button been doing?", "story":"Button walks through Nell's sweeping. Every time.",
		"reply":"He sounds like a handful.", "answer":"A handful. Wouldn't swap him.",
		"help":"How do patrol ducks help?", "advice":"They eat pests. Give them room.",
		"thanks":"Button remembers you. Usually that's good.", "weather":"Counted them twice. Button hid again."},


	"iris": {"name":"Iris", "role":"Weather forecaster", "service":"climate", "service_label":"See weather & protection", "color":"5f9fd6", "skin":"b9825c", "shape":Vector3(.94,1.02,.98), "hat":"", "detail":"headset",
		"first":"Clear, I think. Don't quote me.",
		"daily":["Probably a storm. Probably.", "Clear for now. The next reading's uncertain."],
		"topic":"What do the readings show?", "story":"The gaps between storms seem shorter. Maybe.",
		"reply":"Thanks for keeping watch.", "answer":"Thanks for listening. I'm watching, I think.",
		"help":"How do I protect the farm?", "advice":"A forecast's a chance. Keep some protection.",
		"thanks":"You're back. Clear skies, I hope.", "weather":"Probably a storm. Probably."},

	"edwin": {"name":"Edwin", "role":"Bank manager", "service":"accounts", "service_label":"Review the overdraft", "color":"78847a", "skin":"ddbb91", "shape":Vector3(.94,1.07,.98), "hat":"visor", "detail":"spectacles",
		"first":"Afternoon. I've brought the overdraft figures.",
		"daily":["Nell lent me this dry folder.", "Let's check your balance before Winter."],
		"topic":"Do people mind you visiting?", "story":"Mother says ask about your day first.",
		"reply":"Well, how was your day?", "answer":"Quite nice. Saw ducklings by the pier.",
		"help":"What does the limit mean?", "advice":"Below the limit, the farm is foreclosed.",
		"thanks":"Afternoon. How's your day been?", "weather":"Less stock. Let's check the remaining balance."}
}

static func for_station(station: String) -> String:
	for id: String in PEOPLE:
		if PEOPLE[id].service == station: return id
	return ""

static func available(id: String, state = null) -> bool:
	return PEOPLE.has(id) and (id != "edwin" or state == null or state.coins < state.bankruptcy_limit() * 0.5)

static func ledger_lines(state) -> String:
	if state.ledger.guided_credit(state.season_clock.year) > 0: return GUIDED_CREDIT_LINE
	return "Net: %s. Purse: %s." % [state.money(state.ledger.total(state.season_clock.year)), state.money(state.coins)]
static func weather_cost(state) -> String:
	return "Same bills. Less stock." if not state.climate.data.protection.losses.is_empty() else "No losses. Same bills."
static func bank_line(state) -> String:
	return "Overdraft %s. Limit %s." % [state.money(maxf(0, -state.coins)), state.money(-state.bankruptcy_limit())]
static func forecast_line(state) -> String:
	return "A small storm is coming." if state.guided_first_year() else "Probably a storm. Probably."
static func advice(id: String, state) -> String:
	if id == "nell" and state.season_clock.season == 3: return ledger_lines(state)
	if id == "edwin": return bank_line(state)
	return PEOPLE[id].advice
static func greeting(id: String, state, record: bool = false) -> String:
	var p: Dictionary = PEOPLE[id]
	var memory: Dictionary = state.npc_history.get(id, {})
	var visits: int = int(memory.get("visits", 0))
	var line: String = p.first if visits == 0 else str(p.daily[visits % p.daily.size()])
	if bool(memory.get("kind", false)): line = p.thanks
	if state.climate.data.phase in ["warning", "active", "recovery"]: line = p.weather
	if line == str(memory.get("last", "")): line = str(p.daily[visits % p.daily.size()])
	if id == "nell" and state.season_clock.season == 3: line = ledger_lines(state)
	if id == "edwin": line = bank_line(state)
	if record: state.npc_history[id] = {"visits":mini(visits + 1, 100000), "last":line, "kind":bool(memory.get("kind", false))}
	return line
static func weather_line(id: String, state) -> String:
	if id == "bram" and state.climate.data.event == "freeze": return "Use hoe. Then clear ice."
	if id == "nell": return weather_cost(state)
	if id == "edwin": return bank_line(state)
	if id == "iris" and state.guided_first_year(): return "A small storm is coming."
	return str(PEOPLE[id].weather) if state.climate.data.phase != "calm" else str(PEOPLE[id].daily[0])
static func expression(id: String, state, line: String = "") -> String:
	if id == "nell":
		if line == "A profit. Write the date down.": return "pleased"
		return "concerned" if state.ledger.total(state.season_clock.year) < 0 else "exact"
	if id == "mara": return "beaming"
	if id in ["tess", "bram"]: return "practical"
	return "uncertain" if id == "iris" else "warm"

static func valid_history(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() > PEOPLE.size(): return false
	for id in raw:
		if not PEOPLE.has(id) or not raw[id] is Dictionary: return false
		var m: Dictionary = raw[id]
		var visits: Variant = m.get("visits")
		if not (visits is int or visits is float) or not is_finite(float(visits)) or visits < 0 or visits > 100000 or float(visits) != floorf(float(visits)): return false
		if not m.get("kind") is bool or not m.get("last") is String or m.last.length() > 600: return false
	return true

const SEASON_GREETINGS := {
	"mara": ["Fresh seeds, {name}. Start with one.", "Golden's fussy but it pays, {name}.", "Lovely harvest, {name}. Mind the bags.", "Spring's seed is ready, {name}."],
	"nell": ["{name}, the bills don't care about weather.", "Unsold potatoes aren't income, {name}.", "Bring the receipts, {name}.", "Same bills, {name}. Let's count."],
	"tess": ["{name}, one bed. Then the next.", "Get them in, {name}.", "Count the damage, {name}. Then clear it.", "Ice first, {name}. Hoe."],
	"iris": ["Clear, {name}, I think. Don't quote me.", "Probably a storm, {name}. Probably.", "Get them in, {name}. Probably.", "Snow, {name}. That one seems certain."],
	"bram": ["{name}. Hoe's fine. Use it.", "{name}. Handle tight? Good.", "{name}. Mud off. Hang it.", "{name}. Twelve beds. Forty-eight."],
	"pip": ["Button's watching, {name}.", "Mind your toes, {name}.", "Six ducks, {name}. Count again.", "They're tucked up, {name}."],
	"edwin": ["Your figures, {name}.", "Let's check the balance, {name}.", "Winter bills soon, {name}.", "The limit still applies, {name}."],
}
static func service_greeting(id: String, state) -> String:
	var farmer: String = str(state.farmer_appearance.get("name", "Farmer")).split(" ")[0]
	return str(SEASON_GREETINGS[id][state.season_clock.season]).replace("{name}", farmer)
