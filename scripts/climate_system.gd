extends RefCounted
const Balance = preload("res://scripts/balance.gd")
## Discrete warned disasters and physical field-crop damage.
const Lesson = preload("res://scripts/climate_lesson.gd")
const Operations = preload("res://scripts/climate_operations.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const Rules = preload("res://scripts/save_validation.gd")
## The farm calendar owns seasonal boundaries; this clock times weather phases.
const SEASON_SECONDS: float = preload("res://scripts/season_clock.gd").SEASON_SECONDS
const BASE_CHANCE: float = Balance.CLIMATE_BASE_CHANCE
const CHANCE_STEP: float = Balance.CLIMATE_CHANCE_STEP
const MAX_CHANCE: float = Balance.CLIMATE_MAX_CHANCE
const BASE_SEVERITY: float = Balance.CLIMATE_BASE_SEVERITY
const SEVERITY_STEP: float = Balance.CLIMATE_SEVERITY_STEP
const SEVERITY_SPREAD: float = Balance.CLIMATE_SEVERITY_SPREAD
const SIGNAL_CHANCE: float = Balance.CLIMATE_SIGNAL_CHANCE
const FALSE_ALARM_CHANCE: float = Balance.CLIMATE_FALSE_ALARM_CHANCE
const ANNUAL_CAP: int = Balance.CLIMATE_ANNUAL_CAP
const SEASON_EVENTS: Array = [["flood", "freeze"], ["drought", "storm"], ["storm", "flood"], ["deep_freeze", "blizzard"]]
const WINTER_LOSS: Dictionary = Balance.CLIMATE_WINTER_LOSS
const WARNING_SECONDS: float = 45.0
const ACTIVE_SECONDS: float = 30.0
const RECOVERY_SECONDS: float = 75.0
const EVENTS: Dictionary = {
	"deep_freeze": {"name": "WINTER DEEP FREEZE", "growth": 0.5, "prepare": "Sell stored tonnes and harvest ripe Icecap before impact. Annual insurance covers Winter weather losses."},
	"blizzard": {"name": "BLIZZARD", "growth": 0.4, "prepare": "Stored tonnes and living Icecap are exposed. Sell or harvest before impact; insurance pays 40% of losses."},
	"freeze": {"name": "DEEP FREEZE", "growth": 0.5, "prepare": "Hoe [1] clears ice from frozen crops."},
	"drought": {"name": "DROUGHT", "growth": 0.6, "prepare": "Route stored water to thirsty beds. Water [3] rescues crops; tanks refill after the drought."},
	"flood": {"name": "FLOOD", "growth": 0.7, "prepare": "Open drainage gates. Hoe [1] drains flooded beds. Build drainage during Winter."},
	"storm": {"name": "SEVERE STORM", "growth": 0.75, "prepare": "Harvest the gold lightning row. Winter-built windbreaks reduce storm field losses."},
}
const PROJECTS: Dictionary = {
	"irrigation": {"name": "Sprinklers & Irrigation", "cost": Balance.IRRIGATION_COST, "event": "", "detail": "Manual watering: 6 tank water per patch, 4 at level 2."},
	"rainwater": {"name": Protection.NAMES["rainwater"], "cost": Protection.COSTS["rainwater"], "event": "drought", "detail": "Drought field loss −50% / −75%. Adds 36 water capacity per level. Winter construction."},
	"drainage": {"name": Protection.NAMES["drainage"], "cost": Protection.COSTS["drainage"], "event": "flood", "detail": "Flood field loss −50% / −75%. Open gates to drain stress. Winter construction."},
	"windbreaks": {"name": Protection.NAMES["windbreaks"], "cost": Protection.COSTS["windbreaks"], "event": "storm", "detail": "Storm field loss −50% / −75%. Winter construction."},
	"frost": {"name": Protection.NAMES["frost"], "cost": Protection.COSTS["frost"], "event": "freeze", "detail": "Spring freeze field loss −50% / −75% on covered beds. Build, then cover cleared Winter beds from this page or the bed context action."},
}
const MAX_PROJECT_LEVEL: int = 2
const EDUCATION: String = "For real farming communities, extreme weather can destroy harvests, damage infrastructure and disrupt markets. Preparing together can protect livelihoods."
const EDUCATION_SOURCE: String = "https://www.fao.org/publications/fao-flagship-publications/the-impact-of-disasters-on-agriculture-and-food-security/"
var data: Dictionary = fresh_data()

static func fresh_data() -> Dictionary:
	return {"lesson": Lesson.fresh(), "operations": Operations.fresh(), "phase": "calm", "timer": SEASON_SECONDS, "event": "",
		"severity": 0.0, "projects": {}, "protection": Protection.fresh(),
		"last": {}, "history": [], "field_lost": 0, "collapse": {}, "outlook": {"started": -1, "next": {}, "signal": "", "records": [], "seen_year": 0}}

func reset() -> void:
	data = fresh_data()

func clock_running(farm) -> bool:
	return (not farm.tutorial_active or farm.guided_first_year()) and not Lesson.active(farm) and not farm.run_over

func protection(event: String) -> float:
	return Protection.REDUCTION[int(data.projects.get(Protection.PROJECT_FOR.get(event, ""), 0))]

func factor(kind: String) -> float:
	if data.phase not in ["active", "recovery"]:
		return 1.0
	var weight: float = float(data.severity) * (float(data.timer) / RECOVERY_SECONDS if data.phase == "recovery" else 1.0)
	return lerpf(1.0, float(EVENTS[data.event][kind]), weight)

func begin_warning(farm, event: String = "", severity: float = -1.0) -> bool:
	if farm.run_over or (farm.tutorial_active and not farm.guided_first_year()) or Lesson.active(farm) or data.phase != "calm":
		return false
	var ids: Array = SEASON_EVENTS[farm.season_clock.season]
	if event.is_empty():
		event = str(ids[farm.rng.randi_range(0, ids.size() - 1)])
	if not EVENTS.has(event) or (WINTER_LOSS.has(event) != (farm.season_clock.season == 3)): return false
	if data.lesson.stage == "offer": data.lesson.stage = "done"
	Operations.begin(farm)
	data.event = event
	data.severity = clampf(severity, 0.0, 1.0) if severity >= 0.0 else draw_severity(farm.rng, farm.season_clock.year)
	data.phase = "warning"
	data.timer = WARNING_SECONDS
	data.outlook.records.append({"year": farm.season_clock.year, "season": farm.season_clock.season, "event": event, "severity": data.severity})
	farm.climate_changed.emit("warning")
	return true

func update(farm, delta: float) -> bool:
	if not clock_running(farm): return false
	var operated: bool = Operations.update(farm, delta)
	if data.phase != "calm": data.timer = maxf(0.0, float(data.timer) - delta)
	# Resolve existing weather before starting the next season's saved outlook.
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

static func chance(year: int) -> float:
	return minf(MAX_CHANCE, BASE_CHANCE + CHANCE_STEP * (maxi(1, year) - 1))

static func severity_mean(year: int) -> float:
	return BASE_SEVERITY + SEVERITY_STEP * (maxi(1, year) - 1)

static func draw_severity(rng: RandomNumberGenerator, year: int) -> float:
	return clampf(rng.randf_range(severity_mean(year) - SEVERITY_SPREAD, severity_mean(year) + SEVERITY_SPREAD), 0.0, 1.0)

func year_count(year: int) -> int:
	var count: int = 0
	for record in data.outlook.records:
		if int(record.year) == year: count += 1
	return count

func prime_next(farm) -> void:
	var season: int = (farm.season_clock.season + 1) % 4
	var year: int = farm.season_clock.year + (1 if season == 0 else 0)
	var event: String = SEASON_EVENTS[season][farm.rng.randi_range(0, 1)]
	var fires: bool = farm.rng.randf() < chance(year)
	data.outlook.next = {"year": year, "season": season, "event": event, "fires": fires}
	data.outlook.signal = event if event in ["drought", "flood", "storm"] and farm.rng.randf() < (SIGNAL_CHANCE if fires else FALSE_ALARM_CHANCE) else ""

func start_season(farm) -> void:
	if not clock_running(farm): return
	var ordinal: int = (farm.season_clock.year - 1) * 4 + farm.season_clock.season
	if int(data.outlook.started) == ordinal: return
	data.outlook.started = ordinal
	# The guided year has one disclosed, mild Summer storm. All later years
	# use the ordinary saved outlook and climate curve.
	if farm.guided_first_year():
		if farm.season_clock.season == 1 and year_count(1) == 0: begin_warning(farm, "storm", 0.2)
		prime_next(farm)
		return
	var event: String = ""
	var next: Dictionary = data.outlook.next
	var fires: bool
	if int(next.get("year", 0)) == farm.season_clock.year and int(next.get("season", -1)) == farm.season_clock.season:
		event = str(next.event)
		fires = bool(next.fires)
	else:
		# The first Spring has no preceding season to prime its outlook.
		fires = farm.rng.randf() < chance(farm.season_clock.year)
	# A scripted/debug warning can already occupy this season.
	var occupied: bool = false
	for record in data.outlook.records:
		if int(record.year) == farm.season_clock.year and int(record.season) == farm.season_clock.season: occupied = true
	if not occupied and year_count(farm.season_clock.year) < ANNUAL_CAP and data.phase == "calm" and fires: begin_warning(farm, event)
	prime_next(farm)

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
			farm.Quality.deduct(farm, index, "freeze", 15, true)
	# Field damage accumulates during active weather; players can rescue beds.
	var record: Dictionary = {"event": event, "field_lost": 0,
		"field_total": eligible.size(),
		"at": farm.elapsed, "severity": data.severity}
	data.last = record
	data.history.append(record.duplicate(true))
	if data.history.size() > 8: data.history.pop_front()
	if farm.guided_first_year() and event == "storm" and farm.tutorial_loss().is_empty():
		# One gust exposes two tonnes on the lesson bed; the same loss and
		# counterfactual arithmetic as every other field cause card applies.
		Protection.damage(farm, int(farm.tutorial_progress.plot), event, 2)
	if WINTER_LOSS.has(event): _winter_impact(farm)
	farm.climate_changed.emit("impact")

func _winter_impact(farm) -> void:
	var rate: float = float(WINTER_LOSS[data.event]) * float(data.severity)
	for crop in farm.storage:
		var lost: int = roundi(farm.Stock.count(farm.trading.held, crop) * rate)
		var lots: Array = farm.Stock.take(farm.trading.held, crop, lost)
		farm.Stock.remove_lots(farm.storage, crop, lots)
		Protection.record(farm, data.event, crop, lost, 0.0, 1.0, "Stored tonnes exposed; sell before impact", "barn")
	farm.trading.clamp_stock(farm)
	for index in range(farm.plots.size()):
		var plot: Dictionary = farm.plots[index]
		if int(plot.stage) == 0 or plot.crop != "icecap": continue
		var lost: int = roundi(Protection.remaining(plot) * rate)
		Protection.record(farm, data.event, "icecap", lost, 0.0, 1.0, "Icecap in the ground; harvest before impact", "field")
		plot.weather_lost += lost
		if int(plot.yield_total) > 0: plot.pending = Protection.remaining(plot)
		if Protection.remaining(plot) == 0:
			farm._clear_crop(plot)
			data.field_lost += 1
			data.last.field_lost += 1
	data.history[-1] = data.last.duplicate(true)

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
	result.year = farm.season_clock.year
	result.season = farm.season_clock.season
	result.signal = data.outlook.signal
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
		"elapsed": farm.elapsed, "total_field_lost": data.field_lost,
		"projects": data.projects.duplicate(true), "history": data.history.duplicate(true)}

static func valid(raw: Variant, maximum: float) -> bool:
	if not raw is Dictionary or not valid_outlook(raw.get("outlook")): return false
	if not Lesson.valid(raw.get("lesson")) or not Operations.valid(raw.get("operations")): return false
	if not raw is Dictionary or raw.get("phase") not in ["calm", "warning", "active", "recovery"]: return false
	if not Rules.number(raw.get("timer"), 0.000001, SEASON_SECONDS): return false
	if raw.get("event") not in ([""] + EVENTS.keys()) or not Rules.number(raw.get("severity"), 0.0, 1.0): return false
	if raw.has("operations") and not raw.operations.get("ice", {}).is_empty() and (raw.event != "freeze" or raw.phase not in ["active", "recovery"]): return false
	if (raw.phase == "calm") != (raw.event == ""): return false
	var timer_max: float = {"calm": SEASON_SECONDS, "warning": WARNING_SECONDS, "active": ACTIVE_SECONDS, "recovery": RECOVERY_SECONDS}[raw.phase]
	if float(raw.timer) > timer_max or (raw.phase == "calm" and float(raw.severity) != 0.0) or (raw.phase != "calm" and float(raw.severity) <= 0.0): return false
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
	for key in ["field_lost"]:
		if not Rules.number(raw.get(key), 0, maximum): return false
	if not raw.get("collapse") is Dictionary: return false
	if not raw.collapse.is_empty():
		for key in ["event", "phase", "cause"]:
			if not raw.collapse.get(key) is String or raw.collapse[key].length() > 256: return false
		for key in ["balance"]:
			if not Rules.number(raw.collapse.get(key), -INF, INF): return false
		for key in ["field_lost", "field_total", "elapsed", "total_field_lost"]:
			if not Rules.number(raw.collapse.get(key), 0, 1e15 if key == "elapsed" else maximum): return false
		if not raw.collapse.get("history") is Array or not raw.collapse.get("projects") is Dictionary: return false
	return true

static func valid_loss(raw: Dictionary, maximum: float) -> bool:
	if raw.get("event") not in EVENTS: return false
	for key in ["field_lost", "field_total", "at", "severity"]:
		if not Rules.number(raw.get(key), 0, 1e15 if key == "at" else maximum): return false
	for key in ["field_lost", "field_total"]:
		if float(raw[key]) != floor(float(raw[key])): return false
	if not Rules.number(raw.severity, 0.0, 1.0): return false
	return float(raw.field_lost) <= float(raw.field_total)

static func valid_outlook(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != 5: return false
	if not Rules.number(raw.get("started"), -1, 39, true) or not Rules.number(raw.get("seen_year"), 0, 10, true): return false
	if raw.get("signal") not in ["", "drought", "flood", "storm"] or not raw.get("records") is Array or raw.records.size() > 40: return false
	if not raw.get("next") is Dictionary: return false
	if not raw.next.is_empty():
		if raw.next.size() != 4 or not raw.next.get("fires") is bool: return false
		if not Rules.number(raw.next.get("year"), 1, 11, true) or not Rules.number(raw.next.get("season"), 0, 3, true): return false
		if raw.next.get("event") not in SEASON_EVENTS[int(raw.next.season)]: return false
		if raw.signal != "" and raw.signal != raw.next.event: return false
	elif raw.signal != "": return false
	for record in raw.records:
		if not record is Dictionary or record.size() != 4 or record.get("event") not in EVENTS: return false
		if not Rules.number(record.get("year"), 1, 10, true) or not Rules.number(record.get("season"), 0, 3, true) or not Rules.number(record.get("severity"), 0, 1): return false
	return true
