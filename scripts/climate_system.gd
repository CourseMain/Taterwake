extends RefCounted
## Discrete warned disasters, temporary markets, persistent recovery costs.
const Lesson = preload("res://scripts/climate_lesson.gd")
const Operations = preload("res://scripts/climate_operations.gd")
const Rules = preload("res://scripts/blind_rules.gd")
const FIRST_ISLAND: int = 2
const FIRST_WARNING: float = 90.0
const WAIT_MIN: float = 210.0
const WAIT_MAX: float = 330.0
const WARNING_SECONDS: float = 45.0
const ACTIVE_SECONDS: float = 30.0
const RECOVERY_SECONDS: float = 75.0
const EVENTS: Dictionary = {
	"freeze": {"name": "DEEP FREEZE", "field": 0.4, "barn": 0.12, "growth": 0.5, "tax": 1.0, "prepare": "Visit the furnace and heat your thawing hoe. Hoe [1] melts frozen crops while the tool is hot. Frostgold resists ice."},
	"drought": {"name": "DROUGHT", "field": 0.45, "barn": 0.06, "growth": 0.6, "tax": 0.8, "prepare": "Route stored water to thirsty beds. Water [3] rescues crops; tanks refill after the drought."},
	"flood": {"name": "FLOOD", "field": 0.40, "barn": 0.30, "growth": 0.7, "tax": 1.1, "prepare": "Open drainage gates. Hoe [1] drains flooded beds. Reinforced barn shutters close automatically."},
	"storm": {"name": "SEVERE STORM", "field": 0.55, "barn": 0.22, "growth": 0.75, "tax": 1.5, "prepare": "Harvest the gold lightning row. Trees shelter the far beds from wind; trees do not stop lightning."},
}
const PROJECTS: Dictionary = {
	"irrigation": {"name": "Sprinklers & Irrigation", "cost": 0.01, "event": "drought", "field": 0.0, "barn": 0.0, "tax": 0.0, "detail": "Buy once for all islands. Three sprinklers and connected pipes cost 6 water per patch, or 4 at level 2."},
	"rainwater": {"name": "Rainwater Reserve", "cost": 0.01, "event": "drought", "field": 0.3, "barn": 0.0, "tax": 0.20, "detail": "Adds 36 water capacity per level. The can and sprinklers share this reserve. −30% drought stress and −20% recovery tax per level."},
	"drainage": {"name": "Drainage Network", "cost": 0.015, "event": "flood", "field": 0.3, "barn": 0.10, "tax": 0.20, "detail": "Open the gates to actively drain beds. −30% flood stress, −10% barn losses and −20% recovery tax per level."},
	"barn": {"name": "Reinforced Barn", "cost": 0.02, "event": "all", "field": 0.0, "barn": 0.35, "tax": 0.15, "detail": "Shutters close automatically before impact and halve remaining barn damage. −35% barn losses and −15% recovery tax per level."},
	"windbreaks": {"name": "Living Windbreaks", "cost": 0.012, "event": "storm", "field": 0.3, "barn": 0.1, "tax": 0.2, "detail": "Trees automatically shelter the fixed far patch from wind. −30% wind stress, −10% barn losses and −20% recovery tax per level. Trees do not block lightning."},
}
const MAX_PROJECT_LEVEL: int = 2
const MAX_PROTECTION: float = 0.8
const EDUCATION: String = "For real farming communities, extreme weather can destroy harvests, damage infrastructure and disrupt markets. Preparing together can protect livelihoods."
const EDUCATION_SOURCE: String = "https://www.fao.org/publications/fao-flagship-publications/the-impact-of-disasters-on-agriculture-and-food-security/"
var data: Dictionary = fresh_data()

static func fresh_data() -> Dictionary:
	return {"lesson": Lesson.fresh(), "operations": Operations.fresh(), "phase": "calm", "timer": FIRST_WARNING, "event": "", "island": 2,
		"introduced": false, "intro_pending": false,
		"severity": 0.0, "projects": {"1": {}, "2": {}, "3": {}}, "tax_events": [],
		"last": {}, "history": [], "field_lost": 0, "barn_lost": 0, "tax_paid": 0.0, "collapse": {}}

func reset() -> void:
	data = fresh_data()

func on_arrival(farm) -> void:
	if farm.current_island < FIRST_ISLAND or farm.run_over or data.introduced: return
	data.introduced = true
	data.intro_pending = farm.current_island == 2
	if farm.current_island == 2:
		data.lesson.stage = "off"
	else:
		data.lesson.stage = "done"
	farm.climate_changed.emit("introduction" if data.intro_pending else "lesson")

func acknowledge(farm) -> void:
	Lesson.finish(farm)

func clock_running(farm) -> bool:
	return not data.intro_pending and not Lesson.active(farm) and (data.lesson.stage != "offer" or farm.current_island != 2) and (data.phase != "calm" or farm.current_island >= FIRST_ISLAND)

func protection(event: String, island: int, kind: String) -> float:
	var reduction: float = 0.0
	for id in PROJECTS:
		if id == "windbreaks" and kind == "field": continue
		if PROJECTS[id].event in ["all", event]:
			reduction += float(PROJECTS[id][kind]) * int(data.projects[str(island)].get(id, 0))
	return minf(MAX_PROTECTION, reduction)

func tax_pressure() -> float:
	var pressure: float = 0.0
	for entry in data.tax_events:
		pressure += float(entry.pressure) * (1.0 - protection(str(entry.event), int(entry.island), "tax"))
	return minf(Rules.TAX_BOOM_MAX - 1.0, pressure)

func factor(kind: String, island: int) -> float:
	if data.phase not in ["active", "recovery"] or data.island != island:
		return 1.0
	var weight: float = float(data.severity) * (float(data.timer) / RECOVERY_SECONDS if data.phase == "recovery" else 1.0)
	if kind == "growth":
		weight *= 1.0 - protection(str(data.event), island, "field")
	return lerpf(1.0, float(EVENTS[data.event][kind]), weight)

func begin_warning(farm, event: String = "", severity: float = -1.0) -> bool:
	if farm.current_island < FIRST_ISLAND or data.intro_pending or farm.run_over or farm.tutorial_active or Lesson.active(farm) or data.phase != "calm":
		return false
	var ids: Array = EVENTS.keys()
	if farm.current_island != 3: ids.erase("freeze")
	if event.is_empty():
		event = "freeze" if farm.current_island == 3 and not data.history.any(func(record): return record.event == "freeze") else ("drought" if data.history.is_empty() else str(ids[farm.rng.randi_range(0, ids.size() - 1)]))
	if not EVENTS.has(event) or (event == "freeze" and farm.current_island != 3): return false
	if farm.frost_active: farm._end_frost(false)
	if data.lesson.stage == "offer": data.lesson.stage = "done"
	Operations.begin(farm)
	data.event = event
	data.island = farm.current_island
	data.severity = clampf(severity, 0.5, 1.0) if severity >= 0.0 else farm.rng.randf_range(0.5, 1.0)
	data.phase = "warning"
	data.timer = WARNING_SECONDS
	farm.climate_changed.emit("warning")
	return true

func update(farm, delta: float) -> bool:
	if farm.run_over or Lesson.active(farm): return false
	var operated: bool = Operations.update(farm, delta)
	if farm.tutorial_active or not clock_running(farm): return operated
	data.timer = maxf(0.0, float(data.timer) - delta)
	if float(data.timer) > 0.000001: return operated
	match str(data.phase):
		"calm": begin_warning(farm)
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
			data.timer = farm.rng.randf_range(WAIT_MIN, WAIT_MAX)
			farm.climate_changed.emit("calm")
	return true

func _impact(farm) -> void:
	data.phase = "active"
	data.timer = ACTIVE_SECONDS
	var event: String = data.event
	var island: int = data.island
	var eligible: Array[int] = []
	var field: Array = farm.island_plots[str(island)]
	for index in range(field.size()):
		if int(field[index].stage) > 0: eligible.append(index)
	if event == "freeze":
		for index in eligible:
			if str(field[index].get("variety", "")) != "frost": data.operations.ice[str(index)] = true
	# Field damage accumulates during active weather; players can rescue beds.
	var destroyed: int = 0
	var held: int = farm.storage_used()
	var shutter: float = 0.5 if int(data.projects[str(island)].get("barn", 0)) > 0 else 1.0
	var barn_rate: float = shutter * float(EVENTS[event].barn) * float(data.severity) * (1.0 - protection(event, island, "barn"))
	for crop in farm.storage:
		var lost: int = lost_units(int(farm.storage[crop]), barn_rate)
		farm.storage[crop] = int(farm.storage[crop]) - lost
		if is_instance_valid(farm.build_system): farm.build_system.professions.consumed(crop, lost)
	# Processing is still barn inventory: no hiding stock in a machine.
	if is_instance_valid(farm.build_system):
		for crop in farm.build_system.processed.keys():
			var batch: Dictionary = farm.build_system.processed[crop]
			batch.count = int(batch.count) - lost_units(int(batch.count), barn_rate)
			if batch.count <= 0: farm.build_system.processed.erase(crop)
		if not farm.build_system.processing.is_empty():
			var batch: Dictionary = farm.build_system.processing
			batch.quantity = int(batch.quantity) - lost_units(int(batch.quantity), barn_rate)
			if batch.quantity <= 0: farm.build_system.processing = {}
		var queue: Array = farm.build_system.professions.data.queue
		for index in range(queue.size()-1, -1, -1):
			queue[index].quantity = int(queue[index].quantity) - lost_units(int(queue[index].quantity), barn_rate)
			if queue[index].quantity <= 0: queue.remove_at(index)
		if farm.build_system.processing.is_empty() and not queue.is_empty(): farm.build_system.processing = queue.pop_front()
	var barn_lost: int = held - farm.storage_used()
	data.field_lost = mini(1000000000, int(data.field_lost) + destroyed)
	data.barn_lost = mini(farm.MAX_INVENTORY, int(data.barn_lost) + barn_lost)
	var record: Dictionary = {"event": event, "island": island, "field_lost": destroyed,
		"field_total": eligible.size() + destroyed, "barn_lost": barn_lost, "barn_total": held,
		"at": farm.elapsed, "severity": data.severity}
	data.last = record
	data.history.append(record.duplicate(true))
	if data.history.size() > 8: data.history.pop_front()
	data.tax_events.append({"event": event, "island": island, "pressure": float(EVENTS[event].tax) * float(data.severity)})
	if data.tax_events.size() > 8: data.tax_events.pop_front()
	farm.climate_changed.emit("impact")

static func lost_units(quantity: int, rate: float) -> int:
	# Avoid a floating-point 59.999999999 loss when the intended count is 60.
	return mini(quantity, int(floor(float(quantity) * rate + 0.000001)))

func fund(farm, id: String) -> String:
	if farm.current_island < FIRST_ISLAND or data.intro_pending or farm.run_over or farm.tutorial_active or not PROJECTS.has(id): return "Climate action begins on Golden Shores."
	var levels: Dictionary = data.projects[str(farm.current_island)]
	var level: int = int(levels.get(id, 0))
	if level >= MAX_PROJECT_LEVEL: return farm._finish("This initiative is fully funded.")
	var cost: float = float(Rules.PROGRESSION_BASELINES[2 if id == "irrigation" else farm.current_island]) * float(PROJECTS[id].cost) * float(level + 1)
	if not farm.can_purchase(cost): return farm._reject_purchase(farm.credit_refusal(cost))
	farm.coins -= cost
	levels[id] = level + 1
	if id == "irrigation":
		for island: String in data.projects: data.projects[island].irrigation = level + 1
	return farm._complete_purchase({"kind": "climate", "id": id, "name": PROJECTS[id].name, "quantity": 1, "cost": cost}, "Sprinklers installed on all islands." if id == "irrigation" else "Climate protection improved.")

func info(farm) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result.supply = Operations.local(farm).duplicate(true)
	result.can_capacity = Operations.can_capacity(farm)
	result.water_capacity = Operations.capacity(farm, farm.current_island)
	result.rescued = data.operations.rescued.size()
	result.available = farm.current_island >= FIRST_ISLAND
	result.name = str(EVENTS.get(data.event, {}).get("name", "CALM WEATHER"))
	result.pressure = tax_pressure()
	result.frozen_crops = data.operations.get("ice", {}).size() if int(data.island) == farm.current_island else 0
	result.prepare = str(EVENTS.get(data.event, {}).get("prepare", "Fund local protection before the next warning."))
	result.warning_tax = 0.0
	if data.phase == "warning":
		var upcoming: float = float(EVENTS[data.event].tax) * float(data.severity) * (1.0 - protection(data.event, data.island, "tax"))
		result.warning_tax = Rules.estimated_tax(farm.blind_cycle) + Rules.target(farm.blind_cycle) * Rules.TAX_RATE * (tax_pressure() + upcoming)
		result.warning_tax = minf(result.warning_tax, Rules.target(farm.blind_cycle) * Rules.TAX_RATE * Rules.TAX_BOOM_MAX)
	Lesson.present(farm, result)
	return result

func capture_collapse(farm) -> void:
	var info: Dictionary = farm.blind_info()
	var last: Dictionary = data.last
	var build: String = str(farm.build_system.active).capitalize() if is_instance_valid(farm.build_system) else "Farmer"
	var receipt: Dictionary = farm.blind_cycle.last_result
	var tax_caused: bool = not receipt.is_empty() and float(receipt.after) == farm.coins and float(receipt.tax) > 0.0
	data.collapse = {"balance": farm.coins, "event": str(data.event),
		"last_event": str(last.get("event", "")),
		"phase": data.phase, "island": farm.current_island, "build": build,
		"cause": "Recovery taxes exceeded the farm's reserves." if tax_caused and tax_pressure() > 0.0 else ("The tax bill pushed debt beyond bankruptcy." if tax_caused else "Debt exceeded the farm's bankruptcy limit."),
		"field_lost": int(last.get("field_lost", 0)), "field_total": int(last.get("field_total", 0)),
		"barn_lost": int(last.get("barn_lost", 0)), "barn_total": int(last.get("barn_total", 0)),
		"tax": float(receipt.tax) if tax_caused else float(info.tax),
		"elapsed": farm.elapsed, "total_field_lost": data.field_lost, "total_barn_lost": data.barn_lost,
		"tax_paid": data.tax_paid, "projects": data.projects.duplicate(true), "history": data.history.duplicate(true)}

static func valid(raw: Variant, maximum: float) -> bool:
	if raw is Dictionary and raw.has("lesson") and not Lesson.valid(raw.lesson): return false
	if raw is Dictionary and raw.has("operations") and not Operations.valid(raw.operations): return false
	if not raw is Dictionary or raw.get("phase") not in ["calm", "warning", "active", "recovery"]: return false
	if not raw.get("introduced") is bool or not raw.get("intro_pending") is bool: return false
	if raw.intro_pending and not raw.introduced: return false
	if not Rules.number(raw.get("timer"), 0.000001, WAIT_MAX) or not Rules.number(raw.get("island"), 1, 3, true): return false
	if raw.get("event") not in ["", "drought", "flood", "storm", "freeze"] or not Rules.number(raw.get("severity"), 0.0, 1.0): return false
	if raw.event == "freeze" and int(raw.island) != 3: return false
	if raw.has("operations") and not raw.operations.get("ice", {}).is_empty() and (raw.event != "freeze" or raw.phase not in ["active", "recovery"]): return false
	if (raw.phase == "calm") != (raw.event == ""): return false
	var timer_max: float = {"calm": WAIT_MAX, "warning": WARNING_SECONDS, "active": ACTIVE_SECONDS, "recovery": RECOVERY_SECONDS}[raw.phase]
	if float(raw.timer) > timer_max or (raw.phase == "calm" and float(raw.severity) != 0.0) or (raw.phase != "calm" and float(raw.severity) < 0.5): return false
	if not raw.get("projects") is Dictionary or raw.projects.size() != 3: return false
	for island in ["1", "2", "3"]:
		if not raw.projects.get(island) is Dictionary: return false
		for id in raw.projects[island]:
			if not PROJECTS.has(id) or not Rules.number(raw.projects[island][id], 0, MAX_PROJECT_LEVEL, true): return false
	if raw.has("lesson") and raw.lesson.stage in ["water", "area", "success"] and raw.phase != "calm": return false
	if raw.has("operations"):
		var limit: int = 80 if int(raw.island) == 3 else 48
		if int(raw.operations.strike_row) >= (8 if int(raw.island) == 3 else 6): return false
		for key in ["stress", "wet", "scars", "rescued"]:
			for index in raw.operations[key]:
				if int(index) >= limit: return false
		for id in ["1", "2", "3"]:
			if float(raw.operations.islands[id].water) > 36.0 + 36.0 * int(raw.projects[id].get("rainwater", 0)): return false
	for key in ["history", "tax_events"]:
		if not raw.get(key) is Array or raw[key].size() > 8: return false
		for entry in raw[key]:
			if not entry is Dictionary or entry.get("event") not in EVENTS or not Rules.number(entry.get("island"), 1, 3, true): return false
			if key == "tax_events" and not Rules.number(entry.get("pressure"), 0, 1.5): return false
			if key == "history" and not valid_loss(entry, maximum): return false
	if not raw.get("last") is Dictionary or (not raw.last.is_empty() and not valid_loss(raw.last, maximum)): return false
	for key in ["field_lost", "barn_lost", "tax_paid"]:
		if not Rules.number(raw.get(key), 0, maximum): return false
	if not raw.get("collapse") is Dictionary: return false
	if not raw.collapse.is_empty():
		for key in ["event", "phase", "build", "cause"]:
			if not raw.collapse.get(key) is String or raw.collapse[key].length() > 256: return false
		for key in ["balance"]:
			if not Rules.number(raw.collapse.get(key), -maximum, maximum): return false
		for key in ["island", "field_lost", "field_total", "barn_lost", "barn_total", "tax", "elapsed", "total_field_lost", "total_barn_lost", "tax_paid"]:
			if not Rules.number(raw.collapse.get(key), 0, maximum): return false
		if not raw.collapse.get("history") is Array or not raw.collapse.get("projects") is Dictionary: return false
	return true

static func valid_loss(raw: Dictionary, maximum: float) -> bool:
	if raw.get("event") not in EVENTS or not Rules.number(raw.get("island"), 1, 3, true): return false
	for key in ["field_lost", "field_total", "barn_lost", "barn_total", "at", "severity"]:
		if not Rules.number(raw.get(key), 0, maximum): return false
	for key in ["field_lost", "field_total", "barn_lost", "barn_total"]:
		if float(raw[key]) != floor(float(raw[key])): return false
	if not Rules.number(raw.severity, 0.5, 1.0): return false
	return float(raw.field_lost) <= float(raw.field_total) and float(raw.barn_lost) <= float(raw.barn_total)
