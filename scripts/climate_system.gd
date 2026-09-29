extends RefCounted
## Discrete warned disasters, physical crop and barn damage.
const Lesson = preload("res://scripts/climate_lesson.gd")
const Operations = preload("res://scripts/climate_operations.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const Rules = preload("res://scripts/save_validation.gd")
## The farm calendar owns seasonal boundaries; this clock times weather phases.
const SEASON_SECONDS: float = preload("res://scripts/season_clock.gd").SEASON_SECONDS
const DISASTER_CHANCE: float = 0.15
const WARNING_SECONDS: float = 45.0
const ACTIVE_SECONDS: float = 30.0
const RECOVERY_SECONDS: float = 75.0
const EVENTS: Dictionary = {
	"freeze": {"name": "DEEP FREEZE", "barn": 0.12, "growth": 0.5, "prepare": "Hoe [1] clears ice from frozen crops."},
	"drought": {"name": "DROUGHT", "barn": 0.06, "growth": 0.6, "prepare": "Route stored water to thirsty beds. Water [3] rescues crops; tanks refill after the drought."},
	"flood": {"name": "FLOOD", "barn": 0.30, "growth": 0.7, "prepare": "Open drainage gates. Hoe [1] drains flooded beds. Build drainage during Winter."},
	"storm": {"name": "SEVERE STORM", "barn": 0.22, "growth": 0.75, "prepare": "Harvest the gold lightning row. Winter-built windbreaks reduce storm field losses."},
}
const PROJECTS: Dictionary = {
	"irrigation": {"name": "Sprinklers & Irrigation", "cost": 500.0, "event": "", "detail": "Manual watering: 6 tank water per patch, 4 at level 2."},
	"rainwater": {"name": Protection.NAMES["rainwater"], "cost": Protection.COSTS["rainwater"], "event": "drought", "detail": "Drought field loss −50% / −75%. Adds 36 water capacity per level. Winter construction; 100 yearly upkeep."},
	"drainage": {"name": Protection.NAMES["drainage"], "cost": Protection.COSTS["drainage"], "event": "flood", "detail": "Flood field loss −50% / −75%. Open gates to drain stress. Winter construction; 100 yearly upkeep."},
	"windbreaks": {"name": Protection.NAMES["windbreaks"], "cost": Protection.COSTS["windbreaks"], "event": "storm", "detail": "Storm field loss −50% / −75%. Winter construction; 100 yearly upkeep."},
	"frost": {"name": Protection.NAMES["frost"], "cost": Protection.COSTS["frost"], "event": "freeze", "detail": "Spring freeze field loss −50% / −75% on covered beds. Build, then place with Hoe on cleared Winter beds. 100 yearly upkeep."},
}
const MAX_PROJECT_LEVEL: int = 2
const EDUCATION: String = "For real farming communities, extreme weather can destroy harvests, damage infrastructure and disrupt markets. Preparing together can protect livelihoods."
const EDUCATION_SOURCE: String = "https://www.fao.org/publications/fao-flagship-publications/the-impact-of-disasters-on-agriculture-and-food-security/"
var data: Dictionary = fresh_data()

static func fresh_data() -> Dictionary:
	return {"lesson": Lesson.fresh(), "operations": Operations.fresh(), "phase": "calm", "timer": SEASON_SECONDS, "event": "",
		"severity": 0.0, "projects": {}, "protection": Protection.fresh(),
		"last": {}, "history": [], "field_lost": 0, "barn_lost": 0, "collapse": {}}

func reset() -> void:
	data = fresh_data()

func clock_running(farm) -> bool:
	return not farm.tutorial_active and not Lesson.active(farm) and not farm.run_over

func protection(event: String) -> float:
	return Protection.REDUCTION[int(data.projects.get(Protection.PROJECT_FOR.get(event, ""), 0))]

func factor(kind: String) -> float:
	if data.phase not in ["active", "recovery"]:
		return 1.0
	var weight: float = float(data.severity) * (float(data.timer) / RECOVERY_SECONDS if data.phase == "recovery" else 1.0)
	return lerpf(1.0, float(EVENTS[data.event][kind]), weight)

func begin_warning(farm, event: String = "", severity: float = -1.0) -> bool:
	if farm.run_over or farm.season_clock.season == 3 or farm.tutorial_active or Lesson.active(farm) or data.phase != "calm":
		return false
	var ids: Array = EVENTS.keys()
	if event.is_empty():
		event = str(ids[farm.rng.randi_range(0, ids.size() - 1)])
	if not EVENTS.has(event): return false
	if data.lesson.stage == "offer": data.lesson.stage = "done"
	Operations.begin(farm)
	data.event = event
	data.severity = clampf(severity, 0.5, 1.0) if severity >= 0.0 else farm.rng.randf_range(0.5, 1.0)
	data.phase = "warning"
	data.timer = WARNING_SECONDS
	farm.climate_changed.emit("warning")
	return true

func update(farm, delta: float) -> bool:
	if not clock_running(farm): return false
	var operated: bool = Operations.update(farm, delta)
	if data.phase != "calm": data.timer = maxf(0.0, float(data.timer) - delta)
	# Resolve existing weather before the next season's single probability draw.
	if float(data.timer) <= 0.000001:
		match str(data.phase):
			"warning": _impact(farm)
			"active":
				data.phase = "recovery"
				data.timer = RECOVERY_SECONDS
				farm.climate_changed.emit("recovery")
			"recovery":
				data.operations.ice.clear()
				data.phase = "calm"
				data.event = ""
				data.severity = 0.0
				data.timer = SEASON_SECONDS
				farm.climate_changed.emit("calm")
		operated = true
	return operated

func start_season(farm) -> void:
	if farm.season_clock.season != 3 and data.phase == "calm" and farm.rng.randf() < DISASTER_CHANCE: begin_warning(farm)

func end_working_year() -> void:
	data.phase = "calm"
	data.event = ""
	data.timer = SEASON_SECONDS
	data.severity = 0.0
	for key in ["ice", "stress", "wet", "scars", "rescued", "damaged", "loss_groups"]: data.operations[key].clear()
	data.operations.flash = 0.0
	data.operations.strike_row = -1


func next_boundary() -> float:
	return float(data.timer) if data.phase != "calm" else SEASON_SECONDS

func _impact(farm) -> void:
	data.phase = "active"
	data.timer = ACTIVE_SECONDS
	var event: String = data.event
	var eligible: Array[int] = []
	var field: Array = farm.plots
	for index in range(field.size()):
		if int(field[index].stage) > 0: eligible.append(index)
	if event == "freeze":
		for index in eligible:
			data.operations.ice[str(index)] = true
	# Field damage accumulates during active weather; players can rescue beds.
	var destroyed: int = 0
	var held: int = farm.storage_used()
	var barn_rate: float = float(EVENTS[event].barn) * float(data.severity)
	for crop in farm.storage:
		var lost: int = lost_units(int(farm.storage[crop]), barn_rate)
		Protection.record(farm, event, crop, lost, 0.0, 1.0, "Sell barn crops before impact", "barn")
		farm.storage[crop] = int(farm.storage[crop]) - lost
	farm.trading.clamp_stock(farm)
	var barn_lost: int = held - farm.storage_used()
	data.field_lost = mini(100000, int(data.field_lost) + destroyed)
	data.barn_lost = mini(farm.MAX_INVENTORY, int(data.barn_lost) + barn_lost)
	var record: Dictionary = {"event": event, "field_lost": destroyed,
		"field_total": eligible.size() + destroyed, "barn_lost": barn_lost, "barn_total": held,
		"at": farm.elapsed, "severity": data.severity}
	data.last = record
	data.history.append(record.duplicate(true))
	if data.history.size() > 8: data.history.pop_front()
	farm.climate_changed.emit("impact")

static func lost_units(quantity: int, rate: float) -> int:
	# Avoid a floating-point 59.999999999 loss when the intended count is 60.
	return mini(quantity, int(floor(float(quantity) * rate + 0.000001)))

func fund(farm, id: String) -> String:
	if farm.run_over or farm.tutorial_active or not PROJECTS.has(id): return "Finish the farm tour before funding protection."
	var levels: Dictionary = data.projects
	var level: int = int(levels.get(id, 0))
	if level >= MAX_PROJECT_LEVEL: return farm._finish("This project is fully built.")
	if id != "irrigation":
		if farm.accounts_open or farm.season_clock.season != 3: return farm._finish("Reserve and build protection during Winter.")
		if data.protection.pending.has(id): return farm._finish("Already paid. Finish the work at its marked site.")
	var cost: float = float(PROJECTS[id].cost) * float(level + 1)
	if not farm.can_purchase(cost): return farm._reject_purchase(farm.purchase_refusal(cost))
	farm.post_money("protection", str(PROJECTS[id].name), -cost)
	if id == "irrigation": levels[id] = level + 1
	else: data.protection.pending[id] = 0
	return farm._complete_purchase({"kind": "climate" if id == "irrigation" else "construction", "id": id, "name": PROJECTS[id].name, "quantity": 1, "cost": cost}, "Sprinklers installed on the farm." if id == "irrigation" else "Reserved. Walk to the marked site and work three times during Winter.")

func info(farm) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result.supply = Operations.local(farm).duplicate(true)
	result.can_capacity = Operations.can_capacity(farm)
	result.water_capacity = Operations.capacity(farm)
	result.rescued = data.operations.rescued.size()
	result.available = true
	result.forecast = Protection.forecast(farm)
	result.name = str(EVENTS.get(data.event, {}).get("name", "CALM WEATHER"))
	for index in range(farm.plots.size()):
		if bool(farm.plots[index].get("winter_ice", false)): result.operations.ice[str(index)] = true
	result.frozen_crops = result.operations.ice.size()
	result.prepare = str(EVENTS.get(data.event, {}).get("prepare", "Fund local protection before the next warning."))
	Lesson.present(farm, result)
	return result

func capture_collapse(farm) -> void:
	var last: Dictionary = data.last
	data.collapse = {"balance": farm.coins, "event": str(data.event),
		"last_event": str(last.get("event", "")),
		"phase": data.phase,
		"cause": "Winter fixed costs left the farm below its overdraft limit.",
		"year": farm.season_clock.year, "year_net": farm.ledger.total(farm.season_clock.year), "categories": farm.ledger.category_totals(farm.season_clock.year),
		"field_lost": int(last.get("field_lost", 0)), "field_total": int(last.get("field_total", 0)),
		"barn_lost": int(last.get("barn_lost", 0)), "barn_total": int(last.get("barn_total", 0)),
		"elapsed": farm.elapsed, "total_field_lost": data.field_lost, "total_barn_lost": data.barn_lost,
		"projects": data.projects.duplicate(true), "history": data.history.duplicate(true)}

static func valid(raw: Variant, maximum: float) -> bool:
	if not raw is Dictionary: return false
	if not Lesson.valid(raw.get("lesson")) or not Operations.valid(raw.get("operations")): return false
	if not raw is Dictionary or raw.get("phase") not in ["calm", "warning", "active", "recovery"]: return false
	if not Rules.number(raw.get("timer"), 0.000001, SEASON_SECONDS): return false
	if raw.get("event") not in ["", "drought", "flood", "storm", "freeze"] or not Rules.number(raw.get("severity"), 0.0, 1.0): return false
	if raw.has("operations") and not raw.operations.get("ice", {}).is_empty() and (raw.event != "freeze" or raw.phase not in ["active", "recovery"]): return false
	if (raw.phase == "calm") != (raw.event == ""): return false
	var timer_max: float = {"calm": SEASON_SECONDS, "warning": WARNING_SECONDS, "active": ACTIVE_SECONDS, "recovery": RECOVERY_SECONDS}[raw.phase]
	if float(raw.timer) > timer_max or (raw.phase == "calm" and float(raw.severity) != 0.0) or (raw.phase != "calm" and float(raw.severity) < 0.5): return false
	if not raw.get("projects") is Dictionary: return false
	for id in raw.projects:
		if not PROJECTS.has(id) or not Rules.number(raw.projects[id], 0, MAX_PROJECT_LEVEL, true): return false
	if raw.has("lesson") and raw.lesson.stage in ["water", "area", "success"] and raw.phase != "calm": return false
	if raw.has("operations"):
		var limit: int = 24
		if int(raw.operations.strike_row) >= 4: return false
		for key in ["stress", "wet", "scars", "rescued"]:
			for index in raw.operations[key]:
				if int(index) >= limit: return false
		if float(raw.operations.supply.water) > 36.0 + 36.0 * int(raw.projects.get("rainwater", 0)): return false
	for key in ["history"]:
		if not raw.get(key) is Array or raw[key].size() > 8: return false
		for entry in raw[key]:
			if not entry is Dictionary or entry.get("event") not in EVENTS: return false
			if key == "history" and not valid_loss(entry, maximum): return false
	if not raw.get("last") is Dictionary or (not raw.last.is_empty() and not valid_loss(raw.last, maximum)): return false
	for key in ["field_lost", "barn_lost"]:
		if not Rules.number(raw.get(key), 0, maximum): return false
	if not raw.get("collapse") is Dictionary: return false
	if not raw.collapse.is_empty():
		for key in ["event", "phase", "cause"]:
			if not raw.collapse.get(key) is String or raw.collapse[key].length() > 256: return false
		for key in ["balance"]:
			if not Rules.number(raw.collapse.get(key), -INF, INF): return false
		for key in ["field_lost", "field_total", "barn_lost", "barn_total", "elapsed", "total_field_lost", "total_barn_lost"]:
			if not Rules.number(raw.collapse.get(key), 0, 1e15 if key == "elapsed" else maximum): return false
		if not raw.collapse.get("history") is Array or not raw.collapse.get("projects") is Dictionary: return false
	return true

static func valid_loss(raw: Dictionary, maximum: float) -> bool:
	if raw.get("event") not in EVENTS: return false
	for key in ["field_lost", "field_total", "barn_lost", "barn_total", "at", "severity"]:
		if not Rules.number(raw.get(key), 0, 1e15 if key == "at" else maximum): return false
	for key in ["field_lost", "field_total", "barn_lost", "barn_total"]:
		if float(raw[key]) != floor(float(raw[key])): return false
	if not Rules.number(raw.severity, 0.5, 1.0): return false
	return float(raw.field_lost) <= float(raw.field_total) and float(raw.barn_lost) <= float(raw.barn_total)
