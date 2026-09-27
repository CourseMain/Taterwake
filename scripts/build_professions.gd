extends RefCounted
## Transactions are owned by the farm simulation, never by an animation or menu.
const GRADES: Array[String] = ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
const VALUES: Array[float] = [1.05, 1.10, 1.20, 1.35, 1.6, 2.0, 2.8, 4.5, 8.0]
const MAX_FRESH_LOTS: int = 288
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
		"queue": [], "last_grade": "", "fresh_crop": "", "fresh_left": 0.0, "fresh_count": 0, "fresh_lots": [], "contract": {}, "deliveries": 0,
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
	if owner_build.state.run_over or not is_finite(delta) or delta <= 0: return
	for key in ["charm_left", "shipping"]: data[key] = maxf(0, float(data[key]) - delta)
	for index in range(data.fresh_lots.size() - 1, -1, -1):
		data.fresh_lots[index].remaining = maxf(0, float(data.fresh_lots[index].remaining) - delta)
		if data.fresh_lots[index].remaining <= 0: data.fresh_lots.remove_at(index)
	_sync_fresh_display()
	if not data.charm and data.charm_left <= 0: data.charm = true
	if not data.contract.is_empty(): data.contract.remaining = maxf(0, float(data.contract.remaining) - delta)
	if not data.contract.is_empty() and data.contract.remaining <= 0:
		data.contract = {}
		emit_result("investor", "Offer expired", "The reserved buyer has left. Your crops are still yours.")

func crop_name(crop: String) -> String:
	return str(owner_build.state.CROPS[crop].name).trim_suffix(" Potato")

func fresh_info(crop: String = "") -> Dictionary:
	if crop.is_empty(): crop = owner_build.state.selected_crop
	var count: int = 0
	var remaining: float = 0.0
	for lot in data.fresh_lots:
		if lot.crop != crop or float(lot.remaining) <= 0: continue
		count += int(lot.quantity)
		remaining = float(lot.remaining) if remaining == 0 else minf(remaining, float(lot.remaining))
	count = mini(count, int(owner_build.state.storage.get(crop, 0)))
	return {"count": count, "remaining": remaining if count > 0 else 0.0}

func _sync_fresh_display() -> void:
	var info: Dictionary = fresh_info(str(data.fresh_crop))
	data.fresh_count = info.count
	data.fresh_left = info.remaining

func mark_fresh(crop: String, quantity: int) -> void:
	if quantity <= 0 or crop not in owner_build.state.CROP_IDS: return
	var tracked: int = 0
	for lot in data.fresh_lots:
		if lot.crop == crop: tracked += int(lot.quantity)
	quantity = mini(quantity, maxi(0, 1000000000 - tracked))
	if quantity <= 0: return
	# Harvests less than a second apart share the older deadline. This bounds
	# bookkeeping without ever making an old potato fresh again.
	var merged: bool = false
	for lot in data.fresh_lots:
		if lot.crop == crop and float(lot.remaining) >= 44.0:
			lot.quantity = mini(1000000000, int(lot.quantity) + quantity)
			merged = true
			break
	if not merged: data.fresh_lots.append({"crop": crop, "quantity": quantity, "remaining": 45.0})
	if data.fresh_lots.size() > MAX_FRESH_LOTS:
		# Also bound imported checkpoints containing many tiny cohorts.
		var first: Dictionary = {}
		for index in range(data.fresh_lots.size()):
			var lot: Dictionary = data.fresh_lots[index]
			if first.has(lot.crop):
				var prior: Dictionary = data.fresh_lots[first[lot.crop]]
				prior.quantity += int(lot.quantity)
				prior.remaining = minf(float(prior.remaining), float(lot.remaining))
				data.fresh_lots.remove_at(index)
				break
			first[lot.crop] = index
	data.fresh_crop = crop
	_sync_fresh_display()

func consumed(crop: String, quantity: int) -> void:
	# Raw crop transactions consume the freshest tracked inventory first. Sold,
	# bred or staked potatoes cannot lend their freshness to an old batch.
	var left: int = maxi(0, quantity)
	for index in range(data.fresh_lots.size() - 1, -1, -1):
		var lot: Dictionary = data.fresh_lots[index]
		if lot.crop != crop: continue
		var used: int = mini(left, int(lot.quantity))
		lot.quantity -= used
		left -= used
		if int(lot.quantity) <= 0: data.fresh_lots.remove_at(index)
		if left <= 0: break
	_sync_fresh_display()

func cultivation_info(index: int = -1) -> Dictionary:
	var farm = owner_build.state
	var eligible: Array[int] = []
	for i in range(farm.plots.size()):
		var plot: Dictionary = farm.plots[i]
		if plot.unlocked and int(plot.stage) in [1, 2] and not bool(plot.get("frozen", false)) and not bool(plot.get("cultivated", false)): eligible.append(i)
	var reason: String = ""
	if farm.run_over: reason = "Run over. Start a new farm."
	elif owner_build.active != "farmer": reason = "Equip Farmer to grow a giant potato."
	elif int(data.compost) < 1: reason = "Harvest a crop patch to earn 1 compost."
	elif index >= farm.plots.size() or index < -1: reason = "Choose a planted, still-growing crop patch."
	elif index >= 0 and index not in eligible:
		var plot: Dictionary = farm.plots[index]
		if bool(plot.get("cultivated", false)): reason = "This patch is already growing a giant potato."
		elif bool(plot.get("frozen", false)): reason = "Clear this patch's ice with the hoe first."
		elif int(plot.stage) == 3: reason = "This crop is ripe. Plant a new crop before adding compost."
		else: reason = "Plant a seed in this patch before adding compost."
	elif eligible.is_empty(): reason = "Plant a seed first. Compost needs a planted, still-growing crop patch."
	return {"eligible": eligible, "ready": reason.is_empty(), "reason": reason if not reason.is_empty() else "Spend 1 compost on a highlighted growing crop · 3× harvest."}

func contract_preview() -> Dictionary:
	var farm = owner_build.state
	var crop: String = farm.selected_crop
	var quantity: int = 20 if int(owner_build.levels.investor) < 10 else 100
	var quote: float = minf(1.0e290, float(farm.market[crop].sell) * (1.20 + mini(10, int(data.deliveries)) * 0.03))
	return {"crop": crop, "quantity": quantity, "quote": quote, "total": quote * quantity}

func queue_slots() -> int:
	return 1 + mini(2, int(owner_build.levels.industrialist) / 10)

func readiness(verb: String) -> Dictionary:
	var farm = owner_build.state
	if verb == "giant": return cultivation_info()
	var reason: String = ""
	var required: String = {"load": "industrialist", "breed": "scientist", "reserve": "investor", "stake": "gambler"}.get(verb, "")
	if farm.run_over: reason = "Run over. Start a new farm."
	elif not required.is_empty() and (owner_build.active != required or int(owner_build.levels[required]) < 1): reason = "Equip %s to use this action." % required.capitalize()
	else:
		match verb:
			"load":
				if data.queue.size() + (0 if owner_build.processing.is_empty() else 1) >= queue_slots(): reason = "Queue full · wait for the current batch to finish."
				elif int(farm.storage[farm.selected_crop]) < int(data.batch_size): reason = "Need %d more %s in the barn." % [int(data.batch_size) - int(farm.storage[farm.selected_crop]), crop_name(farm.selected_crop)]
			"breed":
				var recipe: Dictionary = RECIPES[data.recipe]
				if data.recipe in data.seedbank: reason = "Already discovered · select this variety for your next planting."
				else:
					var missing: Array[String] = []
					for crop: String in [recipe.a, recipe.b]:
						if int(farm.storage[crop]) < 10: missing.append("%d %s" % [10 - int(farm.storage[crop]), crop_name(crop)])
					if not missing.is_empty(): reason = "Need " + " + ".join(missing) + " more in the barn."
			"reserve":
				if not data.contract.is_empty(): reason = "Deliver your current shipment before reserving another buyer."
			"deliver":
				if data.contract.is_empty(): reason = "Reserve a buyer first."
				elif float(data.contract.remaining) <= 0: reason = "This buyer's offer has expired."
				elif farm.current_island != int(data.contract.island): reason = "Return to %s to deliver this shipment." % {1: "Spud Valley", 2: "Golden Shores", 3: "Frosthollow"}[int(data.contract.island)]
				elif int(farm.storage[data.contract.crop]) < int(data.contract.quantity): reason = "Need %d more %s for this shipment." % [int(data.contract.quantity) - int(farm.storage[data.contract.crop]), crop_name(data.contract.crop)]
			"stake":
				if not data.wager.is_empty(): reason = "Claim the current stake before placing another."
				elif owner_build.cooldown > 0: reason = "Table ready in %ds." % ceili(owner_build.cooldown)
				elif int(farm.storage[farm.selected_crop]) < int(data.stake): reason = "Need %d more %s to place this stake." % [int(data.stake) - int(farm.storage[farm.selected_crop]), crop_name(farm.selected_crop)]
			"claim":
				if data.wager.is_empty(): reason = "Place a harvest stake first."
			"reroll":
				if data.wager.is_empty(): reason = "Place a harvest stake first."
				elif bool(data.wager.get("rerolled", false)): reason = "This stake has used its one reroll. Claim the result."
				elif not data.charm: reason = "Charm recharges in %ds." % ceili(data.charm_left)
			_: reason = "Choose a build action."
	return {"ready": reason.is_empty(), "reason": reason}

func grade_preview() -> Dictionary:
	var farm = owner_build.state
	var crop: String = farm.selected_crop
	var fresh_points: int = 2 if int(fresh_info(crop).count) >= int(data.batch_size) else 0
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
	var ready: Dictionary = readiness("load")
	if not ready.ready: return farm._finish(ready.reason)
	var crop: String = farm.selected_crop
	var quantity: int = int(data.batch_size)
	var grade: Dictionary = grade_preview()
	farm.storage[crop] -= quantity
	consumed(crop, quantity)
	var job := {"crop": crop, "quantity": quantity, "elapsed": 0.0, "duration": maxf(3.0, 10.0 / (1.0 + (owner_build.levels.industrialist - 1) * 0.08)), "multiplier": grade.multiplier, "grade": grade.grade}
	if owner_build.processing.is_empty(): owner_build.processing = job
	else: data.queue.append(job)
	return emit_result("industrialist", "Batch loaded", "%d %s → grade %s. The price follows the market until you sell." % [quantity, crop, grade.grade])

func cultivate(index: int) -> String:
	var farm = owner_build.state
	var ready: Dictionary = cultivation_info(index)
	if index < 0: return farm._finish("Choose a planted, still-growing crop patch.")
	if not ready.ready: return farm._finish(ready.reason)
	var plot: Dictionary = farm.plots[index]
	data.compost -= 1
	plot.cultivated = true
	return emit_result("farmer", "Growing a giant potato", "1 compost added · this patch grows a giant potato for 3× harvest. Water and harvest it normally.")

func planted(plot: Dictionary) -> void:
	if data.variety in data.seedbank: plot.variety = data.variety

func harvested(crop: String, first_cut: bool, quantity: int, variety: String = "") -> void:
	if quantity <= 0: return
	mark_fresh(crop, quantity)
	if first_cut:
		data.compost = mini(99, int(data.compost) + 1)
		if owner_build.active == "farmer": owner_build.award_xp("farmer", 4)
		elif owner_build.active == "scientist" and variety in data.seedbank: owner_build.award_xp("scientist", 4)

func breed() -> String:
	var farm = owner_build.state
	var ready: Dictionary = readiness("breed")
	if not ready.ready: return farm._finish(ready.reason)
	var recipe: Dictionary = RECIPES[data.recipe]
	farm.storage[recipe.a] -= 10
	farm.storage[recipe.b] -= 10
	consumed(recipe.a, 10)
	consumed(recipe.b, 10)
	data.seedbank.append(data.recipe)
	data.variety = data.recipe
	owner_build.research = mini(10000, owner_build.research + 1)
	owner_build.award_xp("scientist", 80)
	return emit_result("scientist", recipe.name + " discovered", "%s seeds saved · %s. Your next plantings inherit this trait, with any build." % [recipe.name, recipe.trait])

func reserve() -> String:
	var farm = owner_build.state
	var ready: Dictionary = readiness("reserve")
	if not ready.ready: return farm._finish(ready.reason)
	var offer: Dictionary = contract_preview()
	data.contract = {"crop": offer.crop, "quantity": offer.quantity, "quote": offer.quote, "remaining": 180.0, "island": farm.current_island}
	return emit_result("investor", "Price reserved", "Buyer reserved: %d %s for %s · deliver within 3 minutes. Price locked." % [offer.quantity, crop_name(offer.crop), farm.money(offer.total)])

func deliver() -> String:
	var farm = owner_build.state
	var ready: Dictionary = readiness("deliver")
	if not ready.ready: return farm._finish(ready.reason)
	var order: Dictionary = data.contract
	farm.storage[order.crop] -= order.quantity
	consumed(order.crop, int(order.quantity))
	var value: float = float(order.quantity) * float(order.quote)
	data.contract = {}
	data.deliveries = mini(10000, int(data.deliveries) + 1)
	data.shipping = 8.0
	pay(value, order.crop)
	owner_build.award_xp("investor", int(order.quantity) * 2)
	return emit_result("investor", "Shipment · " + farm.money(value), "Cargo loaded · %s paid at your reserved price." % farm.money(value))

func stake_harvest() -> String:
	var farm = owner_build.state
	var ready: Dictionary = readiness("stake")
	if not ready.ready: return farm._finish(ready.reason)
	var crop: String = farm.selected_crop
	var quantity: int = int(data.stake)
	farm.storage[crop] -= quantity
	consumed(crop, quantity)
	data.wager = {"crop": crop, "quantity": quantity, "quote": minf(1.0e290, float(farm.market[crop].sell)), "factor": draw_factor(), "rerolled": false}
	owner_build.cooldown = 30.0
	return wager_result()

func draw_factor() -> float:
	var roll: float = owner_build.state.rng.randf()
	return 3.0 if roll < 0.20 else (1.0 if roll < 0.75 else 0.5)

func wager_result() -> String:
	var amount: float = float(data.wager.quantity) * float(data.wager.quote) * float(data.wager.factor)
	var detail: String = "Claim this result." if bool(data.wager.get("rerolled", false)) else ("Claim it, or spend your charm for one reroll." if data.charm else "Claim it, or wait for your charm to recharge for one reroll.")
	return emit_result("gambler", "Harvest stake · ×%s" % data.wager.factor, "Result %s · %s" % [owner_build.state.money(amount), detail])

func reroll() -> String:
	var ready: Dictionary = readiness("reroll")
	if not ready.ready: return owner_build.state._finish(ready.reason)
	data.charm = false
	data.charm_left = 180.0
	data.wager.rerolled = true
	data.wager.factor = draw_factor()
	return wager_result()

func claim() -> String:
	var farm = owner_build.state
	var ready: Dictionary = readiness("claim")
	if not ready.ready: return farm._finish(ready.reason)
	var wager: Dictionary = data.wager
	data.wager = {}
	var value: float = wager.quantity * wager.quote * wager.factor
	pay(value, wager.crop)
	owner_build.award_xp("gambler", 20)
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

func valid(raw: Variant, version: int = 3) -> bool:
	if not raw is Dictionary or raw.size() != fresh().size() - (1 if version < 3 else 0): return false
	for key in fresh():
		if version < 3 and key == "fresh_lots": continue
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
		if not owner_build.is_crop(job.get("crop")) or not owner_build._number(job.get("quantity"), 5, 100, true) or not owner_build._number(job.get("quote"), 0.000001, 1.0e290): return false
	if not raw.contract.is_empty():
		if int(raw.contract.quantity) not in [20,100] or not owner_build._number(raw.contract.get("remaining"), 0, 180) or float(raw.contract.remaining) <= 0 or not owner_build._number(raw.contract.get("island"), 1, 3, true): return false
	if not raw.wager.is_empty():
		if int(raw.wager.quantity) not in [5,20,100] or raw.wager.get("factor") not in [0.5,1.0,3.0]: return false
		if version >= 3 and not raw.wager.get("rerolled") is bool: return false
	if version >= 3:
		if not raw.fresh_lots is Array or raw.fresh_lots.size() > MAX_FRESH_LOTS: return false
		var totals: Dictionary = {}
		for lot in raw.fresh_lots:
			if not lot is Dictionary or lot.size() != 3 or not owner_build.is_crop(lot.get("crop")): return false
			if not owner_build._number(lot.get("quantity"), 1, 1000000000, true) or not owner_build._number(lot.get("remaining"), 0, 45) or float(lot.remaining) <= 0: return false
			totals[lot.crop] = int(totals.get(lot.crop, 0)) + int(lot.quantity)
			if int(totals[lot.crop]) > 1000000000: return false
	return true

func restore(raw: Dictionary, version: int) -> void:
	data = raw.duplicate(true)
	if version < 3:
		data.fresh_lots = []
		var quantity: int = mini(int(data.fresh_count), int(owner_build.state.storage.get(data.fresh_crop, 0)))
		if quantity > 0 and float(data.fresh_left) > 0 and not str(data.fresh_crop).is_empty():
			data.fresh_lots.append({"crop": data.fresh_crop, "quantity": quantity, "remaining": minf(45, float(data.fresh_left))})
		if not data.wager.is_empty(): data.wager.rerolled = not bool(data.charm)
	_sync_fresh_display()
