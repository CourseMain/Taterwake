extends Node
## Persistent, selectable farming specializations. Processing needs a loaded batch.
const IDS: Array[String] = ["farmer", "gambler", "investor", "scientist", "industrialist"]
const MAX_LEVEL: int = 30
const CRATE_DROP_CHANCE: float = 0.10
const XP_SOURCES: Dictionary = {
	"farmer": "Harvest a patch: +4 XP",
	"industrialist": "Finish a batch: +1 XP per crop",
	"scientist": "Discover: +80 XP · Harvest a discovered variety: +4 XP",
	"investor": "Deliver a shipment: +2 XP per crop",
	"gambler": "Claim a harvest stake: +20 XP, any result",
}
const DESCRIPTIONS: Dictionary = {
	"farmer": "Grow a giant potato with compost, then harvest three times as much.",
	"gambler": "Stake a chosen harvest for an extraordinary win.",
	"investor": "Reserve a price. Prepare a major shipment.",
	"scientist": "Breed named varieties you can grow again.",
	"industrialist": "Turn harvests into F–SSS export batches."
}
var state
var professions = preload("res://scripts/build_professions.gd").new(self)
var active: String = "farmer"
var levels: Dictionary = {"farmer": 1, "gambler": 0, "investor": 0, "scientist": 0, "industrialist": 0}
var xp: Dictionary = {"farmer": 0, "gambler": 0, "investor": 0, "scientist": 0, "industrialist": 0}
var build_crates: int = 0
var _crate_opening: bool = false
var research: int = 0
var cooldown: float = 0.0
var fertilizer: float = 0.0
var next_roll_charge: float = 0.0
var processing: Dictionary = {}
var processed: Dictionary = {}

func reset_builds() -> void:
	active = "farmer"
	levels = {"farmer": 1, "gambler": 0, "investor": 0, "scientist": 0, "industrialist": 0}
	for id in IDS: xp[id] = 0
	build_crates = 0
	_crate_opening = false
	research = 0
	cooldown = 0.0
	fertilizer = 0.0
	next_roll_charge = 0.0
	processing = {}
	processed = {}
	professions.reset()

func level() -> int:
	return int(levels[active])

static func xp_required(rank: int) -> int:
	return 40 + 10 * (rank - 1) if rank > 0 and rank < MAX_LEVEL else 0

func progression(id: String) -> Dictionary:
	var rank: int = int(levels[id])
	return {"level": rank, "xp": int(xp[id]), "required": xp_required(rank), "maxed": rank >= MAX_LEVEL, "source": XP_SOURCES[id]}

func award_xp(id: String, amount: int) -> int:
	# Called only after work commits. The enclosing transaction emits changed;
	# don't expose half-finished harvests or deliveries through a nested signal.
	if state.run_over or id not in IDS or amount <= 0 or int(levels[id]) < 1 or int(levels[id]) >= MAX_LEVEL: return 0
	var before: int = int(levels[id])
	xp[id] = int(xp[id]) + mini(amount, 10000)
	while int(levels[id]) < MAX_LEVEL and int(xp[id]) >= xp_required(int(levels[id])):
		xp[id] -= xp_required(int(levels[id]))
		levels[id] += 1
	if int(levels[id]) == MAX_LEVEL: xp[id] = 0
	return int(levels[id]) - before

func yield_bonus() -> float:
	return (0.05 * level() + (0.25 if fertilizer > 0.0 else 0.0)) if active == "farmer" else 0.0

func growth_factor() -> float:
	return (1.0 + 0.025 * maxf(0, level() - 1) + (0.2 if fertilizer > 0 else 0.0)) if active == "farmer" else 1.0

func area_bonus() -> int:
	return (3 if level() >= 20 else (2 if level() >= 10 else (1 if level() >= 3 else 0))) if active == "farmer" else 0

func mutation_factor() -> float:
	if active == "scientist":
		return 1.0 + level() * 0.15 + minf(0.5, research * 0.005)
	return 1.0

func roll_quality_factor() -> float:
	return 1.0 + level() * 0.08 + next_roll_charge if active == "gambler" else 1.0

func event_chance_bonus() -> float:
	return level() * 0.012 if active == "investor" else 0.0

func experiment_chance() -> float:
	var gear_factor: float = state.equipment_mutation_factor() if state.has_method("equipment_mutation_factor") else 1.0
	return minf(0.55, (0.18 + level() * 0.025 + research * 0.0005) * gear_factor)

func seed_factor() -> float:
	return 1.0 - level() * 0.015 if active == "investor" else 1.0

func select_build(id: String) -> String:
	if state.run_over:
		return "Run over. Start a new farm."
	if not levels.has(id) or int(levels[id]) < 1:
		return state._finish("Open a Build Crate to unlock this build.")
	active = id
	state._refresh_market(false)
	return state._finish("%s build equipped, level %d." % [active.capitalize(), level()])

func build_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in IDS:
		var rank: int = int(levels[id])
		var benefits: String = "Open a Build Crate to find a build card."
		match id:
			"farmer": benefits = "+%d%% yield · +%.1f%% growth speed%s" % [rank * 5, maxf(0, rank - 1) * 2.5, " · wider tools" if rank >= 3 else " · wider tools at level 3"]
			"gambler": benefits = "+%d%% Roll House reward quality · a rechargeable harvest-stake charm" % [rank * 8]
			"investor": benefits = "+%.1f points positive-event chance · reserved-price deliveries" % [rank * 1.2]
			"scientist": benefits = "+%d%% mutation chance · %d research completed" % [rank * 15 + mini(50, research / 2), research]
			"industrialist": benefits = "Machine grade improves at levels 3, 10 and 20 · larger levels process faster"
		entries.append({"id": id, "name": id.capitalize(), "level": rank, "unlocked": rank > 0, "active": active == id, "description": DESCRIPTIONS[id], "bonuses": benefits})
	return entries

func activity_info() -> Dictionary:
	var title: String = {"farmer": "GIANT POTATOES", "industrialist": "BATCH GRADING", "scientist": "SEED BANK", "investor": "RESERVED BUYER", "gambler": "HARVEST STAKES"}[active]
	return {"title": title, "description": DESCRIPTIONS[active], "action_label": "Open " + active.capitalize(), "can_use": true, "cooldown": cooldown,
		"processing": not processing.is_empty(), "progress": float(processing.get("elapsed", 0)) / float(processing.get("duration", 1)), "processed_value": processed_value(), "fertilizer": fertilizer}

func use_ability() -> String:
	if state.run_over: return "Run over. Start a new farm."
	match active:
		"industrialist": return professions.load_batch()
		"scientist": return professions.breed()
		"investor": return professions.reserve()
		"gambler": return professions.stake_harvest()
	return state._finish("Choose Grow a giant potato in Builds, then spend 1 compost on a planted, still-growing crop patch.")

func update(delta: float, processing_step: float = -1.0) -> void:
	if state.run_over or not is_finite(delta) or delta <= 0: return
	cooldown = maxf(0, cooldown - delta)
	fertilizer = maxf(0, fertilizer - delta)
	professions.update(delta)
	var work: float = delta if processing_step < 0 or not is_finite(processing_step) else processing_step
	if state.has_method("equipment_processing_factor"): work *= state.equipment_processing_factor()
	while work > 0 and not processing.is_empty():
		var step: float = minf(work, float(processing.duration) - float(processing.elapsed))
		processing.elapsed += step
		work -= step
		if float(processing.elapsed) + 0.000001 < float(processing.duration): break
		var crop: String = processing.crop
		var quantity: int = processing.quantity
		var old: Dictionary = processed.get(crop, {"count": 0, "multiplier": 1.0})
		var total: int = int(old.count) + quantity
		var factor: float = (float(old.count) * float(old.multiplier) + quantity * float(processing.multiplier)) / total
		processed[crop] = {"count": total, "multiplier": factor}
		var grade: String = str(processing.get("grade", "A"))
		professions.data.last_grade = grade
		processing = {} if professions.data.queue.is_empty() else professions.data.queue.pop_front()
		award_xp("industrialist", quantity)
		professions.emit_result("industrialist", grade + " · batch ready", "%s stamped · %d %s ready in the barn. Sell your graded shipment when the market suits you." % [grade, quantity, crop])

func processed_value() -> float:
	var total: float = 0.0
	for crop in processed:
		total += float(processed[crop].count) * float(processed[crop].multiplier) * float(state.market[crop].sell)
	return minf(1.0e300, total)

func sell_processed() -> String:
	if state.run_over:
		return "Run over. Start a new farm."
	var value: float = processed_value()
	if value <= 0:
		return state._finish("No processed batches to sell yet.")
	state.coins = minf(1.0e300, float(state.coins) + value)
	state.lifetime_sales = minf(1.0e300, float(state.lifetime_sales) + value)
	var island: String = str(state.current_island)
	state.island_sales[island] = minf(1.0e300, float(state.island_sales[island]) + value)
	for crop: String in processed:
		state.farm_help.observe_sale(state, crop)
	processed.clear()
	return state._finish("Sold processed batches for %s at the live crop prices." % state.money(value))

func stored_count() -> int:
	var total: int = int(processing.get("quantity", 0)) + int(professions.data.wager.get("quantity", 0))
	for batch in processed.values(): total += int(batch.count)
	for job in professions.data.queue: total += int(job.quantity)
	return total

func saved_storage_count(data: Dictionary) -> int:
	var total: int = int(data.get("processing", {}).get("quantity", 0))
	for batch in data.get("processed", {}).values():
		total += int(batch.get("count", 0))
	var professional: Dictionary = data.get("professions", {})
	for job in professional.get("queue", []): total += int(job.quantity)
	total += int(professional.get("wager", {}).get("quantity", 0))
	return total

func inventory_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if build_crates > 0:
		entries.append({"id": "build_crate", "kind": "build_crate", "name": "Build Crate", "count": build_crates, "rarity": "relic", "description": "A sealed collection of farming styles. Drops on 10% of paid rolls.", "effect": "Open for a build-only reward reel", "active": false, "action": "build:open_crate"})
	for id in IDS:
		if int(levels[id]) > 0:
			entries.append({"id": "build:" + id, "kind": "build", "name": id.capitalize() + " Build", "count": int(levels[id]), "rarity": "build", "description": DESCRIPTIONS[id], "effect": "Level %d / 30%s" % [int(levels[id]), " · equipped" if active == id else ""], "active": active == id, "action": "build:select:" + id})
	for crop in processed:
		entries.append({"id": "processed:" + crop, "kind": "processed", "name": "Graded " + str(state.CROPS[crop].name), "count": int(processed[crop].count), "rarity": "processed", "description": "Processed crop batch, valued at the live market.", "effect": "x%.2f sale value" % float(processed[crop].multiplier), "active": true, "sell_value": float(processed[crop].count) * float(processed[crop].multiplier) * float(state.market[crop].sell), "action": "build:sell_processed"})
	if not processing.is_empty():
		entries.append({"id": "processing", "kind": "processed", "name": "Batch in the processor", "count": int(processing.quantity), "rarity": "processed", "description": "The loaded batch still occupies barn space.", "effect": "%.0f%% complete" % (float(processing.elapsed) / float(processing.duration) * 100.0), "active": true, "action": "build:inspect:industrialist"})
	for index in range(professions.data.queue.size()):
		var job: Dictionary = professions.data.queue[index]
		entries.append({"id": "queued:" + str(index), "kind": "processed", "name": "Queued " + job.crop, "count": job.quantity, "rarity": "processed", "description": "Loaded at the workshop. Still occupies barn space.", "effect": "Grade " + job.grade, "active": true, "action": "build:inspect:industrialist"})
	if not professions.data.wager.is_empty():
		var wager: Dictionary = professions.data.wager
		entries.append({"id":"harvest_stake", "kind":"processed", "name":"Harvest stake at the Roll House", "count":wager.quantity, "rarity":"processed", "description":"Reserved until you claim the result in Gambler details.", "effect":"Claim " + state.money(wager.quantity * wager.quote * wager.factor), "active":true, "action":"build:inspect:gambler"})
	return entries

func grant_roll_build(_tier: String) -> String:
	# A paid roll may award the sealed item, never an unowned build reward.
	next_roll_charge = 0.0
	if state.rng.randf() < CRATE_DROP_CHANCE and build_crates < 1000000:
		build_crates = maxi(0, build_crates) + 1
		return "BUILD CRATE! Open it in Inventory [I] for a build-only roll."
	return ""

func open_crate() -> Dictionary:
	if state.run_over:
		return {}
	# Ownership and the in-flight guard live in the simulation, not in the button.
	# Rejecting a request must not advance RNG or mutate any build level.
	if _crate_opening:
		return {}
	if build_crates <= 0:
		build_crates = 0
		state._finish("You need a Build Crate.")
		return {}
	var available: Array[String] = []
	for id in IDS:
		if int(levels[id]) < 30:
			available.append(id)
	if available.is_empty():
		state._finish("All builds are level 30. Your Build Crate stays in inventory.")
		return {}
	_crate_opening = true
	build_crates -= 1
	var id: String = available[state.rng.randi_range(0, available.size() - 1)]
	levels[id] = int(levels[id]) + 1
	if int(levels[id]) >= MAX_LEVEL: xp[id] = 0
	var result: Dictionary = {"tier": "build", "build_id": id, "title": id.capitalize() + " BUILD", "detail": "Level %d / 30. Equip this build in Builds [C]." % int(levels[id]), "bet": 0.0}
	state.changed.emit()
	return result

func finish_crate_reveal() -> void:
	_crate_opening = false

func save_data() -> Dictionary:
	return {"version": 4, "xp": xp.duplicate(), "professions": professions.data.duplicate(true), "build_crates": build_crates, "active": active, "levels": levels.duplicate(), "research": research, "cooldown": cooldown, "fertilizer": fertilizer, "next_roll_charge": next_roll_charge, "processing": processing.duplicate(true), "processed": processed.duplicate(true)}

func valid_data(data: Variant) -> bool:
	if not data is Dictionary or not _number(data.get("version"), 1, 4, true) or not data.get("active") is String or not data.active in IDS:
		return false
	if int(data.version) >= 2 and not professions.valid(data.get("professions"), int(data.version)): return false
	if not _number(data.get("build_crates", 0), 0, 1000000, true):
		return false
	if not data.get("levels") is Dictionary or data.levels.size() != IDS.size():
		return false
	for id in IDS:
		if not _number(data.levels.get(id), 1 if id == "farmer" else 0, 30, true):
			return false
	if int(data.version) >= 4:
		if not data.get("xp") is Dictionary or data.xp.size() != IDS.size(): return false
		for id in IDS:
			if not _number(data.xp.get(id), 0, maxi(0, xp_required(int(data.levels[id])) - 1), true): return false
	if int(data.levels[data.active]) == 0:
		return false
	for key in {"research": 10000, "cooldown": 60, "fertilizer": 30, "next_roll_charge": 0.5}:
		if not _number(data.get(key), 0, {"research": 10000, "cooldown": 60, "fertilizer": 30, "next_roll_charge": 0.5}[key], key == "research"):
			return false
	if not data.get("processing") is Dictionary or not data.get("processed") is Dictionary or data.processed.size() > state.CROP_IDS.size():
		return false
	if int(data.version) >= 2:
		var jobs: int = data.professions.queue.size() + (0 if data.processing.is_empty() else 1)
		if jobs > 1 + mini(2, int(data.levels.industrialist) / 10): return false
		if not data.professions.queue.is_empty() and data.processing.is_empty(): return false
	if not data.processing.is_empty():
		var job: Dictionary = data.processing
		if not valid_job(job, int(data.version) == 1): return false
	for crop in data.processed:
		if not is_crop(crop) or not data.processed[crop] is Dictionary or not _number(data.processed[crop].get("count"), 1, 1.0e15, true) or not _number(data.processed[crop].get("multiplier"), 1.05, 8.0):
			return false
	return true

func load_data(data: Dictionary) -> bool:
	if not valid_data(data):
		return false
	_crate_opening = false
	build_crates = int(data.get("build_crates", 0))
	active = str(data.active)
	levels = data.levels.duplicate()
	for id in IDS: xp[id] = int(data.xp[id]) if int(data.version) >= 4 else 0
	research = int(data.research)
	cooldown = float(data.cooldown)
	fertilizer = float(data.fertilizer)
	next_roll_charge = float(data.next_roll_charge)
	processing = data.processing.duplicate(true)
	processed = data.processed.duplicate(true)
	professions.reset()
	if int(data.version) >= 2: professions.restore(data.professions, int(data.version))
	return true

func _number(value: Variant, minimum: float, maximum: float, integer_only: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and (not integer_only or float(value) == floor(float(value)))

func is_crop(value: Variant) -> bool:
	return value is String and state.CROP_IDS.has(value)

func valid_job(job: Variant, legacy: bool = false) -> bool:
	if not job is Dictionary: return false
	# A storm can damage a loaded batch before it finishes. The remaining
	# potatoes and locked grade are legitimate saved progress.
	if not is_crop(job.get("crop")) or not _number(job.get("quantity"), 1, 100, true): return false
	if not _number(job.get("duration"), 3, 10) or not _number(job.get("elapsed"), 0, float(job.get("duration", 0))) or not _number(job.get("multiplier"), 1.05, 8): return false
	return legacy or (job.get("grade", "A") in professions.GRADES)
