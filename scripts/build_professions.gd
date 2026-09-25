extends RefCounted
## Transactions are owned by the farm simulation, never by an animation or menu.
const GRADES: Array[String] = ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
const VALUES: Array[float] = [1.05, 1.10, 1.20, 1.35, 1.6, 2.0, 2.8, 4.5, 8.0]
const RECIPES: Dictionary = {
	"hearty": {"name": "Honeyheart", "a": "russet", "b": "golden", "trait": "Generous harvest", "color": "f3cb69"},
	"dry": {"name": "Sundew", "a": "giant", "b": "sunburst", "trait": "Drought tolerant", "color": "a7cb78"},
	"frost": {"name": "Frostgold", "a": "golden", "b": "icecap", "trait": "Frost hardy", "color": "a6e6eb"},
}
var owner_build
var data: Dictionary
var event_serial: int = 0
var event: Dictionary = {}

func _init(build) -> void:
	owner_build = build
	reset()

static func fresh() -> Dictionary:
	return {"compost": 3, "recipe": "hearty", "seedbank": [], "variety": "", "method": "polish", "batch_size": 20,
		"queue": [], "last_grade": "", "fresh_crop": "", "fresh_left": 0.0, "fresh_count": 0, "contract": {}, "deliveries": 0,
		"wager": {}, "charm": true, "charm_left": 0.0, "stake": 20, "shipping": 0.0}

func reset() -> void:
	data = fresh()
	event = {}
	event_serial = 0

func emit_result(kind: String, title: String, detail: String) -> String:
	event_serial += 1
	event = {"kind": kind, "title": title, "detail": detail}
	return owner_build.state._finish(detail)

func update(delta: float) -> void:
	for key in ["fresh_left", "charm_left", "shipping"]: data[key] = maxf(0, float(data[key]) - delta)
	if not data.charm and data.charm_left <= 0: data.charm = true
	if not data.contract.is_empty(): data.contract.remaining = maxf(0, float(data.contract.remaining) - delta)
	if not data.contract.is_empty() and data.contract.remaining <= 0:
		data.contract = {}
		emit_result("investor", "Offer expired", "The reserved buyer has left. Your crops are still yours.")

func grade_preview() -> Dictionary:
	var farm = owner_build.state
	var crop: String = farm.selected_crop
	var fresh_points: int = 2 if data.fresh_crop == crop and data.fresh_left > 0 and data.fresh_count >= data.batch_size else 0
	var rank: int = int(owner_build.levels.industrialist)
	var tier: int = 0 if rank < 3 else (1 if rank < 10 else (2 if rank < 20 else 3))
	var desired: String = "polish" if crop in ["golden", "icecap", "radioactive"] else "cure"
	var fit: int = 2 if data.method == desired else 0
	var discovery: int = 1 if data.seedbank.size() >= 2 and int(owner_build.levels.industrialist) >= 20 else 0
	var score: int = mini(8, fresh_points + tier + fit + discovery)
	return {"grade": GRADES[score], "score": score, "multiplier": VALUES[score], "fresh": fresh_points,
		"tier": tier, "fit": fit, "discovery": discovery, "desired": desired}

func load_batch() -> String:
	var farm = owner_build.state
	if owner_build.active != "industrialist": return farm._finish("Equip Industrialist to start a batch.")
	var crop: String = farm.selected_crop
	var quantity: int = int(data.batch_size)
	var slots: int = 1 + mini(2, int(owner_build.levels.industrialist) / 10)
	if data.queue.size() + (0 if owner_build.processing.is_empty() else 1) >= slots: return farm._finish("Production queue full. This batch will finish soon.")
	if int(farm.storage[crop]) < quantity: return farm._finish("Harvest %d %s before loading." % [quantity, crop])
	var grade: Dictionary = grade_preview()
	farm.storage[crop] -= quantity
	if data.fresh_crop == crop: data.fresh_count = maxi(0, int(data.fresh_count) - quantity)
	var job := {"crop": crop, "quantity": quantity, "elapsed": 0.0, "duration": maxf(3.0, 10.0 / (1.0 + (owner_build.levels.industrialist - 1) * 0.08)), "multiplier": grade.multiplier, "grade": grade.grade}
	if owner_build.processing.is_empty(): owner_build.processing = job
	else: data.queue.append(job)
	return emit_result("industrialist", "Batch loaded", "%d %s → grade %s. The price follows the market until you sell." % [quantity, crop, grade.grade])

func cultivate(index: int) -> String:
	var farm = owner_build.state
	if farm.run_over or owner_build.active != "farmer" or index < 0 or index >= farm.plots.size(): return "Choose a growing bed as Farmer."
	var plot: Dictionary = farm.plots[index]
	if not plot.unlocked or int(plot.stage) not in [1, 2] or plot.get("cultivated", false): return farm._finish("Choose a growing bed that is not already a prize crop.")
	if data.compost < 1: return farm._finish("Harvest crops to make more compost.")
	data.compost -= 1
	plot.cultivated = true
	return emit_result("farmer", "Prize crop", "Compost spread. This bed will grow a giant harvest; water and harvest it normally.")

func planted(plot: Dictionary) -> void:
	if data.variety in data.seedbank: plot.variety = data.variety

func harvested(crop: String, first_cut: bool, quantity: int) -> void:
	data.fresh_count = mini(1000000000, int(data.fresh_count) + quantity) if data.fresh_crop == crop and data.fresh_left > 0 else quantity
	data.fresh_crop = crop
	data.fresh_left = 45.0
	if first_cut: data.compost = mini(99, int(data.compost) + 1)

func breed() -> String:
	var farm = owner_build.state
	if owner_build.active != "scientist": return farm._finish("Equip Scientist to crossbreed seeds.")
	var recipe: Dictionary = RECIPES[data.recipe]
	if data.recipe in data.seedbank: return farm._finish("This variety is already in your seed bank. Select it for your next planting.")
	if farm.storage[recipe.a] < 10 or farm.storage[recipe.b] < 10: return farm._finish("Bring 10 %s and 10 %s to the seed bench." % [recipe.a, recipe.b])
	farm.storage[recipe.a] -= 10
	farm.storage[recipe.b] -= 10
	data.seedbank.append(data.recipe)
	data.variety = data.recipe
	owner_build.research = mini(10000, owner_build.research + 1)
	return emit_result("scientist", recipe.name + " discovered", "%s seeds saved · %s. Your next plantings inherit this trait, with any build." % [recipe.name, recipe.trait])

func reserve() -> String:
	var farm = owner_build.state
	if owner_build.active != "investor" or not data.contract.is_empty(): return farm._finish("Finish the current contract before reserving another.")
	var crop: String = farm.selected_crop
	var quantity: int = 20 if int(owner_build.levels.investor) < 10 else 100
	var quote: float = minf(1.0e290, float(farm.market[crop].sell) * (1.20 + mini(10, int(data.deliveries)) * 0.03))
	data.contract = {"crop": crop, "quantity": quantity, "quote": quote, "remaining": 180.0, "island": farm.current_island}
	return emit_result("investor", "Price reserved", "Buyer reserved: %d %s for %s · deliver within 3 minutes. Price locked." % [quantity, crop, farm.money(quote * quantity)])

func deliver() -> String:
	var farm = owner_build.state
	if data.contract.is_empty(): return farm._finish("Reserve a buyer first.")
	var order: Dictionary = data.contract
	if farm.current_island != int(order.island): return farm._finish("Deliver this shipment from the island where you reserved it.")
	if farm.storage[order.crop] < order.quantity: return farm._finish("Need %d %s for this shipment." % [order.quantity, order.crop])
	farm.storage[order.crop] -= order.quantity
	var value: float = float(order.quantity) * float(order.quote)
	data.contract = {}
	data.deliveries = mini(10000, int(data.deliveries) + 1)
	data.shipping = 8.0
	pay(value, order.crop)
	return emit_result("investor", "Shipment · " + farm.money(value), "Cargo loaded · %s paid at your reserved price." % farm.money(value))

func stake_harvest() -> String:
	var farm = owner_build.state
	if owner_build.active != "gambler" or not data.wager.is_empty() or owner_build.cooldown > 0: return farm._finish("Finish your current wager or wait for the next table.")
	var crop: String = farm.selected_crop
	var quantity: int = int(data.stake)
	if farm.storage[crop] < quantity: return farm._finish("Harvest %d %s to place this stake." % [quantity, crop])
	farm.storage[crop] -= quantity
	data.wager = {"crop": crop, "quantity": quantity, "quote": minf(1.0e290, float(farm.market[crop].sell)), "factor": draw_factor()}
	owner_build.cooldown = 30.0
	return wager_result()

func draw_factor() -> float:
	var roll: float = owner_build.state.rng.randf()
	return 3.0 if roll < 0.20 else (1.0 if roll < 0.75 else 0.5)

func wager_result() -> String:
	var amount: float = float(data.wager.quantity) * float(data.wager.quote) * float(data.wager.factor)
	return emit_result("gambler", "Harvest stake · ×%s" % data.wager.factor, "Result %s · claim it, or spend your charm to replace this result once." % owner_build.state.money(amount))

func reroll() -> String:
	if data.wager.is_empty() or not data.charm: return owner_build.state._finish("No charm available for this wager.")
	data.charm = false
	data.charm_left = 180.0
	data.wager.factor = draw_factor()
	return wager_result()

func claim() -> String:
	var farm = owner_build.state
	if data.wager.is_empty(): return farm._finish("No harvest stake to claim.")
	var wager: Dictionary = data.wager
	data.wager = {}
	var value: float = wager.quantity * wager.quote * wager.factor
	pay(value, wager.crop)
	return emit_result("gambler", "Claimed · " + farm.money(value), "Harvest stake paid %s. Everything else in your farm stayed untouched." % farm.money(value))

func pay(value: float, crop: String) -> void:
	var farm = owner_build.state
	farm.coins = minf(farm.MAX_MONEY, farm.coins + value)
	farm.lifetime_sales = minf(farm.MAX_MONEY, farm.lifetime_sales + value)
	var island: String = str(farm.current_island)
	farm.island_sales[island] = minf(farm.MAX_MONEY, farm.island_sales[island] + value)
	farm.farm_help.observe_sale(farm, crop)

func action(verb: String, arg: String = "") -> String:
	var farm = owner_build.state
	if farm.run_over: return "Run over. Start a new farm."
	match verb:
		"load": return load_batch()
		"breed": return breed()
		"reserve": return reserve()
		"deliver": return deliver()
		"stake": return stake_harvest()
		"reroll": return reroll()
		"claim": return claim()
		"method":
			if arg in ["polish", "cure"]: data.method = arg
		"batch":
			if arg in ["20", "100"]: data.batch_size = int(arg)
		"stake_size":
			if arg in ["5", "20", "100"]: data.stake = int(arg)
		"recipe":
			if RECIPES.has(arg): data.recipe = arg
		"variety":
			if arg == "" or arg in data.seedbank: data.variety = arg
	farm.changed.emit()
	return ""

func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != fresh().size(): return false
	for key in fresh():
		if not raw.has(key): return false
	for key in {"compost": 99, "batch_size": 100, "deliveries": 10000, "stake": 100, "fresh_count": 1000000000}:
		if not owner_build._number(raw[key], 0, {"compost": 99, "batch_size": 100, "deliveries": 10000, "stake": 100, "fresh_count": 1000000000}[key], true): return false
	if int(raw.batch_size) not in [20,100] or int(raw.stake) not in [5,20,100]: return false
	for key in ["fresh_left", "charm_left", "shipping"]:
		if not owner_build._number(raw[key], 0, 180): return false
	if not raw.charm is bool or raw.method not in ["polish", "cure"] or not RECIPES.has(raw.recipe): return false
	if raw.last_grade not in GRADES + [""] or raw.fresh_crop not in owner_build.state.CROP_IDS + [""]: return false
	if not raw.seedbank is Array or raw.seedbank.size() > 3: return false
	var seen: Array = []
	for id in raw.seedbank:
		if not RECIPES.has(id) or id in seen: return false
		seen.append(id)
	if raw.variety != "" and raw.variety not in raw.seedbank: return false
	if not raw.queue is Array or raw.queue.size() > 2: return false
	for job in raw.queue:
		if not owner_build.valid_job(job, false): return false
	if not raw.contract is Dictionary or not raw.wager is Dictionary: return false
	for job in [raw.contract, raw.wager]:
		if job.is_empty(): continue
		if not owner_build.state.CROP_IDS.has(job.get("crop")) or not owner_build._number(job.get("quantity"), 5, 100, true) or not owner_build._number(job.get("quote"), 0.000001, 1.0e290): return false
	if not raw.contract.is_empty():
		if not owner_build._number(raw.contract.get("remaining"), 0.000001, 180) or not owner_build._number(raw.contract.get("island"), 1, 3, true): return false
	if not raw.wager.is_empty() and raw.wager.get("factor") not in [0.5,1.0,3.0]: return false
	return true
