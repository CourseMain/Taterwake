extends RefCounted
## Cash-only Spring packs. Presentation never chooses or changes an outcome.
const Balance = preload("res://scripts/balance.gd")
const Table = preload("res://scripts/crop_table.gd")
const Stock = preload("res://scripts/graded_stock.gd")
const Quality = preload("res://scripts/crop_quality.gd")
const Rules = preload("res://scripts/save_validation.gd")
const PACK_IDS: Array[String] = ["seed", "superstition", "mystery"]
const SUPERSTITIONS := {
	"common":["Second Sowing", "Early Riser", "Windbreak Rows", "Oda's Spare Hoe", "Nell's Cat"],
	"uncommon":["Lucky Boot", "Cold Store", "Seed Saver", "Iris's Mug", "Fennick's Thumb"],
	"rare":["Haunted Scarecrow", "The Cursed One"],
}
const ODDITIES := ["the Twin", "the Heart", "the Glow Spud"]
const PASS_SECONDS: float = 20.0
var data: Dictionary = fresh()

static func fresh() -> Dictionary:
	return {"endowed":false, "gate_greeted":false, "spring":0, "bought":[], "superstitions":[], "hooks":[], "oddities":[], "stone":false, "discovered":[], "last_result":{}, "revealed":true, "rng_seed":"", "rng_state":"", "passing_seconds":0.0}

func endow(stock: Dictionary) -> void:
	if data.endowed: return
	data.endowed = true
	if "Second Sowing" not in data.superstitions: data.superstitions.append("Second Sowing")
	if "Second Sowing" not in data.hooks: data.hooks.push_front("Second Sowing")
	Stock.add(stock,"russet",1,60)
	data.oddities.append({"name":"the Twin","crop":"russet","score":60,"held":true,"starter":true})

func begin_spring(year: int) -> void:
	if int(data.spring) == year: return
	data.spring = year; data.bought = []; data.last_result = {}; data.revealed = true

func presence(farm) -> String:
	if farm.run_over or farm.season_clock.season != 0: return "absent"
	if farm.season_clock.year >= 2: return "parked"
	return "passing" if float(data.passing_seconds) < PASS_SECONDS else "absent"

func tick_pass(farm, delta: float) -> bool:
	if presence(farm) != "passing": return false
	var before: float = float(data.passing_seconds)
	data.passing_seconds = minf(PASS_SECONDS, before + maxf(0, delta))
	return before < PASS_SECONDS * .5 and float(data.passing_seconds) >= PASS_SECONDS * .5

func unbought(farm, pack: String) -> bool:
	return presence(farm) == "parked" and (int(data.spring) != farm.season_clock.year or pack not in data.bought)

static func choose(pack: String, rng: RandomNumberGenerator) -> Array:
	var table: Dictionary = Balance.PEDLAR_PACKS[pack]
	var ticket: int = rng.randi_range(0, int(table.tickets) - 1)
	for row: Array in table.outcomes:
		ticket -= int(row[1])
		if ticket < 0: return row
	return []

func buy(farm, pack: String) -> Dictionary:
	if pack not in PACK_IDS or not unbought(farm, pack): return {}
	var price: float = float(Balance.PEDLAR_PACKS[pack].price)
	if farm.coins < price: return {"error":"Not enough in the purse."}
	var rng := RandomNumberGenerator.new()
	if str(data.rng_seed).is_empty(): rng.seed = farm.rng.seed ^ 0x5f3a71
	else: rng.seed = int(data.rng_seed); rng.state = int(data.rng_state)
	var row: Array = choose(pack, rng)
	var result: Dictionary = {"pack":pack, "kind":"seeds", "id":str(row[0]), "name":"", "cause":"Found it in a ditch.", "effect":"", "odds":str(row[2]), "rarity":"common"}
	var amount: int = 0
	if pack == "seed":
		amount = Balance.PEDLAR_SEED_COUNT
		result.name = str(Table.CROPS[result.id].name).trim_suffix(" Potato")
		result.effect = "Five %s seeds in your pouch." % result.name
	elif pack == "superstition":
		result.kind = "superstition"; result.rarity = str(row[0])
		var available: Array = SUPERSTITIONS[result.rarity].filter(func(id): return id not in data.superstitions)
		if available.is_empty():
			result.kind = "refund"; result.id = "owned"; result.name = "2,000 back"
			result.effect = "All of these are yours. Here's 2,000."
		else:
			result.id = str(available[rng.randi_range(0, available.size() - 1)])
			result.name = result.id; result.effect = "Takes effect next Winter"
	else:
		match str(row[0]):
			"russet_seeds":
				result.id = "russet"; amount = Balance.PEDLAR_MYSTERY_SEEDS
				result.name = "Russet seeds"; result.effect = "Ten Russet seeds in your pouch."
			"blue_pearl":
				amount = 1; result.name = "Blue Pearl"; result.rarity = "found"
				result.effect = "A Blue Pearl seed in your pouch."
			"oddity":
				result.kind = "oddity"; result.rarity = "uncommon"
				result.id = Table.IDS[rng.randi_range(0, Table.IDS.size() - 1)]
				result.name = ODDITIES[rng.randi_range(0, ODDITIES.size() - 1)]
				result.effect = "One Standard %s potato, worth 500 more." % str(Table.CROPS[result.id].name).trim_suffix(" Potato")
			"refund":
				result.kind = "refund"; result.name = "500 back"; result.effect = "500 back in your purse."
			"stone":
				result.kind = "stone"; result.name = "Lucky stone"; result.effect = "It does nothing. Keep it."
	if amount > 0 and int(farm.seed_inventory[result.id]) + int(farm.trading.kept_seed[result.id]) + amount > farm.MAX_INVENTORY:
		return {"error":"Your seed shed is full for this crop."}
	if result.kind == "oddity" and farm.storage_used() >= farm.MAX_INVENTORY: return {"error":"Your barn is full."}
	begin_spring(farm.season_clock.year)
	if not farm.post_money("other", "Pedlar's pack", -price): return {}
	data.bought.append(pack)
	if amount > 0: farm.seed_inventory[result.id] += amount
	elif result.kind == "superstition":
		data.superstitions.append(result.id)
		if data.hooks.size() < 5: data.hooks.append(result.id)
	elif result.kind == "refund": farm.post_money("other", "Pedlar's refund", Balance.PEDLAR_OWNED_REFUND if result.id == "owned" else Balance.PEDLAR_REFUND)
	elif result.kind == "stone": data.stone = true
	elif result.kind == "oddity":
		Stock.add(farm.storage, result.id, 1, 60)
		data.oddities.append({"name":result.name, "crop":result.id, "score":60, "held":true, "starter":false})
	if result.kind in ["seeds", "oddity"] and result.id not in data.discovered: data.discovered.append(result.id)
	data.rng_seed = str(rng.seed); data.rng_state = str(rng.state)
	data.last_result = result.duplicate(true); data.revealed = false
	farm.changed.emit()
	return result

func consume_oddities(crop: String, lots: Array) -> Dictionary:
	var bonuses: Dictionary = {}
	for lot in lots:
		var remaining: int = int(lot.quantity)
		for item: Dictionary in data.oddities:
			if remaining <= 0: break
			if not item.held or item.crop != crop or int(item.score) != int(lot.score): continue
			item.held = false; remaining -= 1
			bonuses[lot.grade] = float(bonuses.get(lot.grade, 0.0)) + Balance.ODDITY_BONUS
	return bonuses

func age_oddities() -> void:
	for item: Dictionary in data.oddities:
		if item.held: item.score = maxi(0, int(item.score) - 10)

static func valid(raw: Variant, year: int) -> bool:
	if not raw is Dictionary or raw.size() != fresh().size(): return false
	if not raw.get("endowed") is bool or not raw.get("gate_greeted") is bool: return false
	if not Rules.number(raw.get("spring"), 0, year, true) or not Rules.number(raw.get("passing_seconds"), 0, PASS_SECONDS): return false
	if not raw.get("bought") is Array or raw.bought.size() > 3: return false
	var seen: Array = []
	for pack in raw.bought:
		if pack not in PACK_IDS or pack in seen or int(raw.spring) < 2: return false
		seen.append(pack)
	if not raw.get("superstitions") is Array or raw.superstitions.size() > 12: return false
	seen.clear()
	var all_superstitions: Array = SUPERSTITIONS.common + SUPERSTITIONS.uncommon + SUPERSTITIONS.rare
	for id in raw.superstitions:
		if id not in all_superstitions or id in seen: return false
		seen.append(id)
	if not raw.get("hooks") is Array or raw.hooks.size() > 5: return false
	seen.clear()
	for id in raw.hooks:
		if id not in raw.superstitions or id in seen: return false
		seen.append(id)
	if not raw.get("oddities") is Array or raw.oddities.size() > 30 or not raw.get("stone") is bool: return false
	if not raw.get("discovered") is Array or raw.discovered.size() > Table.IDS.size(): return false
	seen.clear()
	for crop in raw.discovered:
		if crop not in Table.IDS or crop in seen: return false
		seen.append(crop)
	for item in raw.oddities:
		if not item is Dictionary or item.size() != 5 or item.get("name") not in ODDITIES or item.get("crop") not in Table.IDS or not Rules.number(item.get("score"), 0, 60, true) or not item.get("held") is bool or not item.get("starter") is bool: return false
	for key in ["rng_seed", "rng_state"]:
		if not raw.get(key) is String or raw[key].length() > 21 or (not raw[key].is_empty() and not raw[key].is_valid_int()): return false
	if raw.rng_seed.is_empty() != raw.rng_state.is_empty(): return false
	if not raw.get("revealed") is bool: return false
	if not raw.get("last_result") is Dictionary: return false
	var last: Dictionary = raw.last_result
	if not last.is_empty():
		if last.size() != 8 or last.get("pack") not in raw.bought or last.get("kind") not in ["seeds", "superstition", "refund", "stone", "oddity"] or last.get("rarity") not in ["common", "uncommon", "rare", "found"]: return false
		for key in ["id", "name", "cause", "effect", "odds"]:
			if not last.get(key) is String or last[key].length() > 120: return false
		var odds: Array = []
		for row: Array in Balance.PEDLAR_PACKS[last.pack].outcomes: odds.append(row[2])
		if last.odds not in odds: return false
	return true
