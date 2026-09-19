extends Node
## Persistent, selectable farming specializations. Processing needs a loaded batch.
const IDS: Array[String] = ["farmer", "gambler", "investor", "scientist", "industrialist"]
const DESCRIPTIONS: Dictionary = {
	"farmer": "Grow more. Harvest bigger.",
	"gambler": "Better rolls. Rarer spuds.",
	"investor": "Cheaper seeds. Better deals.",
	"scientist": "Turn harvests into experiments.",
	"industrialist": "Process crops for extra profit."
}
var state
var active: String = "farmer"
var levels: Dictionary = {"farmer": 1, "gambler": 0, "investor": 0, "scientist": 0, "industrialist": 0}
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
	build_crates = 0
	_crate_opening = false
	research = 0
	cooldown = 0.0
	fertilizer = 0.0
	next_roll_charge = 0.0
	processing = {}
	processed = {}

func level() -> int:
	return int(levels[active])

func yield_bonus() -> float:
	return (0.05 * level() + (0.25 if fertilizer > 0.0 else 0.0)) if active == "farmer" else 0.0

func growth_factor() -> float:
	return (1.0 + 0.025 * maxf(0, level() - 1) + (0.2 if fertilizer > 0 else 0.0)) if active == "farmer" else 1.0

func area_bonus() -> int:
	return (3 if level() >= 20 else (2 if level() >= 10 else (1 if level() >= 3 else 0))) if active == "farmer" else 0

func mutation_factor() -> float:
	if active == "scientist":
		return 1.0 + level() * 0.15 + minf(0.5, research * 0.005)
	return 1.0 + level() * 0.08 if active == "gambler" else 1.0

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
	if not levels.has(id) or int(levels[id]) < 1:
		return state._finish("Open a Build Crate to unlock this build.")
	if not processing.is_empty() and id != active:
		return state._finish("Finish the loaded batch before changing your build.")
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
			"gambler": benefits = "+%d%% reward quality · +%d%% mutation chance" % [rank * 8, rank * 8]
			"investor": benefits = "%.1f%% seed discount · +%.1f points positive-event chance" % [rank * 1.5, rank * 1.2]
			"scientist": benefits = "+%d%% mutation chance · %d research completed" % [rank * 15 + mini(50, research / 2), research]
			"industrialist": benefits = "Processed crops worth +%d%% · larger levels process faster" % [20 + rank * 5]
		entries.append({"id": id, "name": id.capitalize(), "level": rank, "unlocked": rank > 0, "active": active == id, "description": DESCRIPTIONS[id], "bonuses": benefits})
	return entries

func activity_info() -> Dictionary:
	var crop: String = str(state.selected_crop)
	var held: int = int(state.storage[crop])
	var ready: bool = cooldown <= 0.0
	var title: String = ""
	var description: String = ""
	var action_label: String = ""
	match active:
		"farmer":
			title = "FIELD DRESSING"
			description = "10 potatoes → 30s of bigger, faster crops."
			action_label = "Dress the field · 10 potatoes"
			ready = ready and held >= 10
		"gambler":
			title = "READ THE TABLE"
			var cost: float = state.roll_cost("normal") * 0.5
			description = "%s → +50%% quality on your next roll." % state.money(cost)
			action_label = "Scout next roll · " + state.money(cost)
			ready = ready and state.roll_available() and state.coins >= cost and next_roll_charge == 0.0
		"investor":
			title = "CALL A BUYER"
			var cost: float = float(state.market[crop].seed) * 10.0
			description = "%s → a 5-second buying offer. Have crops ready!" % state.money(cost)
			action_label = "Call buyer · " + state.money(cost)
			ready = ready and state.coins >= cost
		"scientist":
			title = "MUTATION EXPERIMENT"
			description = "20 potatoes → %.1f%% mutation chance + research." % (experiment_chance() * 100.0)
			action_label = "Experiment · 20 potatoes"
			ready = ready and held >= 20
		"industrialist":
			title = "BATCH PROCESSOR"
			description = "100 potatoes → a premium batch. Sell when ready."
			action_label = "Load processor · 100 potatoes"
			ready = ready and held >= 100 and processing.is_empty()
	var progress: float = float(processing.get("elapsed", 0.0)) / float(processing.get("duration", 1.0))
	return {"title": title, "description": description, "action_label": action_label, "can_use": ready, "cooldown": cooldown,
		"processing": not processing.is_empty(), "progress": clampf(progress, 0, 1), "processed_value": processed_value(), "fertilizer": fertilizer}

func use_ability() -> String:
	if not bool(activity_info().can_use):
		if active in ["gambler", "investor"]:
			return state._reject_purchase("This ability needs more coins or time to recover.")
		return state._finish("This ability needs more potatoes, coins, or time to recover.")
	var crop: String = str(state.selected_crop)
	match active:
		"farmer":
			state.storage[crop] -= 10
			fertilizer = 30.0
			cooldown = 60.0
			return state._finish("Field dressed! +25% harvest yield and faster growth for 30 seconds.")
		"gambler":
			var cost: float = state.roll_cost("normal") * 0.5
			state.coins -= cost
			next_roll_charge = 0.5
			cooldown = 30.0
			return state._complete_purchase({"kind": "service", "id": "scout", "name": "Roll scouting", "quantity": 1, "cost": cost}, "Table scouted. The next roll has +50% reward quality; its displayed odds update now.")
		"investor":
			var cost: float = float(state.market[crop].seed) * 10.0
			state.coins -= cost
			cooldown = 45.0
			state._start_event("shortage")
			return state._complete_purchase({"kind": "service", "id": "market_call", "name": "Market call", "quantity": 1, "cost": cost}, "The buyer answered. Your five-second trading window is open!")
		"scientist":
			state.storage[crop] -= 20
			var chance: float = experiment_chance()
			research = mini(10000, research + 1)
			cooldown = 15.0
			if state.rng.randf() < chance:
				var kind: String = "crystal" if state.rng.randf() < 0.25 else "golden"
				state._add_mutation(crop, 1, kind, false)
				return state._finish("Experiment succeeded! A mutation is stored in your inventory.")
			return state._finish("Research recorded. This experiment produced no mutation; your future mutation chance improved.")
		"industrialist":
			state.storage[crop] -= 100
			processing = {"crop": crop, "quantity": 100, "elapsed": 0.0, "duration": 10.0 / (1.0 + maxf(0, level() - 1) * 0.08), "multiplier": 1.2 + level() * 0.05}
			return state._finish("100 potatoes loaded. Your processor is running; crops in the field still need your tools.")
	return ""

func update(delta: float, processing_step: float = -1.0) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	fertilizer = maxf(0.0, fertilizer - delta)
	if processing.is_empty():
		return
	# Furnace heat speeds the loaded job, never ability cooldowns. The controller
	# captures this work before the simulation consumes the heat timer.
	var work: float = delta if processing_step < 0.0 or not is_finite(processing_step) else processing_step
	if state.has_method("equipment_processing_factor"):
		work *= state.equipment_processing_factor()
	processing.elapsed = minf(float(processing.duration), float(processing.elapsed) + work)
	if float(processing.elapsed) < float(processing.duration):
		return
	var crop: String = str(processing.crop)
	var quantity: int = int(processing.quantity)
	var old: Dictionary = processed.get(crop, {"count": 0, "multiplier": 1.0})
	var total: int = int(old.count) + quantity
	var factor: float = (float(old.count) * float(old.multiplier) + float(quantity) * float(processing.multiplier)) / float(total)
	processed[crop] = {"count": total, "multiplier": factor}
	processing = {}
	state._finish("Processing complete. Your graded batch is stored until you choose to sell.")

func processed_value() -> float:
	var total: float = 0.0
	for crop in processed:
		total += float(processed[crop].count) * float(processed[crop].multiplier) * float(state.market[crop].sell)
	return minf(1.0e300, total)

func sell_processed() -> String:
	var value: float = processed_value()
	if value <= 0:
		return state._finish("No processed batches to sell yet.")
	state.coins = minf(1.0e300, float(state.coins) + value)
	state.lifetime_sales = minf(1.0e300, float(state.lifetime_sales) + value)
	var island: String = str(state.current_island)
	state.island_sales[island] = minf(1.0e300, float(state.island_sales[island]) + value)
	processed.clear()
	return state._finish("Sold processed batches for %s at the live crop prices." % state.money(value))

func stored_count() -> int:
	return saved_storage_count(save_data())

func saved_storage_count(data: Dictionary) -> int:
	var total: int = int(data.get("processing", {}).get("quantity", 0))
	for batch in data.get("processed", {}).values():
		total += int(batch.get("count", 0))
	return total

func inventory_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if build_crates > 0:
		entries.append({"id": "build_crate", "kind": "build_crate", "name": "Build Crate", "count": build_crates, "rarity": "relic", "description": "A sealed collection of farming styles. Drops on 5% of paid rolls.", "effect": "Open for a build-only reward reel", "active": false, "action": "build:open_crate"})
	for id in IDS:
		if int(levels[id]) > 0:
			entries.append({"id": "build:" + id, "kind": "build", "name": id.capitalize() + " Build", "count": int(levels[id]), "rarity": "build", "description": DESCRIPTIONS[id], "effect": "Level %d / 30%s" % [int(levels[id]), " · equipped" if active == id else ""], "active": active == id, "action": "build:select:" + id})
	for crop in processed:
		entries.append({"id": "processed:" + crop, "kind": "processed", "name": "Graded " + str(state.CROPS[crop].name), "count": int(processed[crop].count), "rarity": "processed", "description": "Processed crop batch, valued at the live market.", "effect": "x%.2f sale value" % float(processed[crop].multiplier), "active": true, "sell_value": float(processed[crop].count) * float(processed[crop].multiplier) * float(state.market[crop].sell), "action": "build:sell_processed"})
	if not processing.is_empty():
		entries.append({"id": "processing", "kind": "processed", "name": "Batch in the processor", "count": int(processing.quantity), "rarity": "processed", "description": "The loaded batch still occupies barn space.", "effect": "%.0f%% complete" % (float(processing.elapsed) / float(processing.duration) * 100.0), "active": true, "action": "builds"})
	return entries

func grant_roll_build(_tier: String) -> String:
	# A paid roll may award the sealed item, never an unowned build reward.
	next_roll_charge = 0.0
	if state.rng.randf() < 0.05 and build_crates < 1000000:
		build_crates = maxi(0, build_crates) + 1
		return "BUILD CRATE! Open it in Inventory [I] for a build-only roll."
	return ""

func open_crate() -> Dictionary:
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
	var result: Dictionary = {"tier": "build", "build_id": id, "title": id.capitalize() + " BUILD", "detail": "Level %d / 30. Equip this build in Builds [C]." % int(levels[id]), "bet": 0.0}
	state.changed.emit()
	return result

func finish_crate_reveal() -> void:
	_crate_opening = false

func save_data() -> Dictionary:
	return {"version": 1, "build_crates": build_crates, "active": active, "levels": levels.duplicate(), "research": research, "cooldown": cooldown, "fertilizer": fertilizer, "next_roll_charge": next_roll_charge, "processing": processing.duplicate(true), "processed": processed.duplicate(true)}

func valid_data(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("active") in IDS:
		return false
	if not _number(data.get("build_crates", 0), 0, 1000000, true):
		return false
	if not data.get("levels") is Dictionary or data.levels.size() != IDS.size():
		return false
	for id in IDS:
		if not _number(data.levels.get(id), 1 if id == "farmer" else 0, 30, true):
			return false
	if int(data.levels[data.active]) == 0:
		return false
	for key in {"research": 10000, "cooldown": 60, "fertilizer": 30, "next_roll_charge": 0.5}:
		if not _number(data.get(key), 0, {"research": 10000, "cooldown": 60, "fertilizer": 30, "next_roll_charge": 0.5}[key], key == "research"):
			return false
	if not data.get("processing") is Dictionary or not data.get("processed") is Dictionary or data.processed.size() > state.CROP_IDS.size():
		return false
	if not data.processing.is_empty():
		var job: Dictionary = data.processing
		if not state.CROP_IDS.has(job.get("crop")) or not _number(job.get("quantity"), 100, 100, true) or not _number(job.get("duration"), 3, 10) or not _number(job.get("elapsed"), 0, float(job.get("duration", 0))) or not _number(job.get("multiplier"), 1.25, 2.7):
			return false
	for crop in data.processed:
		if not state.CROP_IDS.has(crop) or not data.processed[crop] is Dictionary or not _number(data.processed[crop].get("count"), 1, 1.0e15, true) or not _number(data.processed[crop].get("multiplier"), 1.25, 2.7):
			return false
	return true

func load_data(data: Dictionary) -> bool:
	if not valid_data(data):
		return false
	_crate_opening = false
	build_crates = int(data.get("build_crates", 0))
	active = str(data.active)
	levels = data.levels.duplicate()
	research = int(data.research)
	cooldown = float(data.cooldown)
	fertilizer = float(data.fertilizer)
	next_roll_charge = float(data.next_roll_charge)
	processing = data.processing.duplicate(true)
	processed = data.processed.duplicate(true)
	return true

func _number(value: Variant, minimum: float, maximum: float, integer_only: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and (not integer_only or float(value) == floor(float(value)))
