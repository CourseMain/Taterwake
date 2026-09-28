extends Node
## Persistent, selectable farming specializations. Processing needs a loaded batch.
const IDS: Array[String] = ["farmer", "gambler", "investor", "scientist", "industrialist"]
const MAX_LEVEL: int = 30
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
var levels: Dictionary = {"farmer": 1, "gambler": 1, "investor": 1, "scientist": 1, "industrialist": 1}
var xp: Dictionary = {"farmer": 0, "gambler": 0, "investor": 0, "scientist": 0, "industrialist": 0}
var research: int = 0
var cooldown: float = 0.0
var fertilizer: float = 0.0
var processing: Dictionary = {}
var processed: Dictionary = {}

func reset_builds() -> void:
	active = "farmer"
	levels = {"farmer": 1, "gambler": 1, "investor": 1, "scientist": 1, "industrialist": 1}
	for id in IDS: xp[id] = 0
	research = 0
	cooldown = 0.0
	fertilizer = 0.0
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

func select_build(id: String) -> String:
	if state.run_over:
		return "Run over. Start a new farm."
	if not levels.has(id) or int(levels[id]) < 1:
		return state._finish("Choose an available build.")
	active = id
	state._refresh_market()
	return state._finish("%s build equipped, level %d." % [active.capitalize(), level()])

func build_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in IDS:
		var rank: int = int(levels[id])
		var benefits: String = "Choose a build to begin."
		match id:
			"farmer": benefits = "+%d%% yield · +%.1f%% growth speed%s" % [rank * 5, maxf(0, rank - 1) * 2.5, " · wider tools" if rank >= 3 else " · wider tools at level 3"]
			"gambler": benefits = "A rechargeable harvest-stake charm"
			"investor": benefits = "+%.1f points positive-event chance · reserved-price deliveries" % [rank * 1.2]
			"scientist": benefits = "Permanent seed-bank varieties"
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

func save_data() -> Dictionary:
	return {"version": 5, "xp": xp.duplicate(), "professions": professions.data.duplicate(true), "active": active, "levels": levels.duplicate(), "research": research, "cooldown": cooldown, "fertilizer": fertilizer, "processing": processing.duplicate(true), "processed": processed.duplicate(true)}

func valid_data(data: Variant) -> bool:
	if not data is Dictionary or not _number(data.get("version"), 1, 5, true) or not data.get("active") is String or not data.active in IDS:
		return false
	if int(data.version) >= 2 and not professions.valid(data.get("professions"), int(data.version)): return false
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
	for key in {"research": 10000, "cooldown": 60, "fertilizer": 30, }:
		if not _number(data.get(key), 0, {"research": 10000, "cooldown": 60, "fertilizer": 30, }[key], key == "research"):
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
	active = str(data.active)
	levels = data.levels.duplicate()
	for id in IDS: levels[id] = maxi(1, int(levels[id]))
	for id in IDS: xp[id] = int(data.xp[id]) if int(data.version) >= 4 else 0
	research = int(data.research)
	cooldown = float(data.cooldown)
	fertilizer = float(data.fertilizer)
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
