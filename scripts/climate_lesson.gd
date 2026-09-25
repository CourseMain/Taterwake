extends RefCounted
## Optional practice uses visual crop copies: real crops and clocks stay untouched.
const SOURCE: String = "https://www.ipcc.ch/report/ar6/syr/longer-report/"
const BEDS: Array[int] = [34, 35, 36]
static func fresh(stage: String = "off") -> Dictionary:
	return {"stage": stage, "remaining": 0.0}
static func active(farm) -> bool:
	return farm.current_island == 2 and farm.climate.data.lesson.stage in ["water", "area", "success"]
static func start(farm) -> String:
	if farm.current_island != 2: return farm._finish("Try the water lesson on Golden Shores.")
	if farm.climate.data.phase != "calm" or farm.run_over or farm.rocket_pending or farm.tutorial_active:
		return farm._finish("Try the water lesson when the farm is calm.")
	if int(farm.climate.data.projects["2"].get("irrigation", 0)) == 0: return farm._finish("Buy Sprinklers & Irrigation at the weather station before sprinkler practice.")
	farm.climate.data.introduced = true
	farm.climate.data.intro_pending = false

	farm.climate.data.operations.islands["2"].water = farm.climate.Operations.capacity(farm, 2)
	farm.climate.data.operations.islands["2"].can = farm.climate.Operations.can_capacity(farm)
	farm.climate.data.lesson = fresh("water")
	farm.climate_changed.emit("lesson")
	return farm._finish("Practice is safe: your crops, markets and bills are paused.")
static func finish(farm) -> void:
	farm.climate.data.lesson = fresh("done")
	farm.climate.data.intro_pending = false
	farm.climate.data.timer = maxf(90.0, float(farm.climate.data.timer)) if farm.climate.data.phase == "calm" else farm.climate.data.timer
	farm.climate_changed.emit("lesson")
	farm.changed.emit()
static func water(farm, index: int, tool: String) -> String:
	if farm.climate.data.lesson.stage != "water": return farm._finish("Click the near sprinkler to water its connected beds.")
	if tool != "water" or index != BEDS[0]:
		return farm._finish("Select Water [3], then click the glowing practice bed.")
	if not farm.climate.Operations.pour(farm): return farm._finish("Can empty · Click the tank to refill.")
	farm.climate.data.lesson.stage = "area"
	farm.climate_changed.emit("lesson")
	return farm._finish("One bed rescued · 1 can water used. Now click the near sprinkler.")
static func area(farm, index: int) -> String:
	if farm.climate.Operations.zone(index, 2) != farm.climate.Operations.zone(BEDS[1], 2):
		return farm._finish("Choose the highlighted practice beds near the front fence.")
	var cost: float = farm.climate.Operations.water_cost(farm)
	if not farm.climate.Operations.spend(farm, "water", cost): return farm._finish("Not enough tank water for these beds.")
	farm.climate.data.lesson = {"stage": "success", "remaining": 3.0}
	farm.climate_changed.emit("lesson")
	return farm._finish("Area rescued · %d water used" % int(cost))
static func preview(farm) -> Array:
	var plots: Array = farm.plots.duplicate(true)
	if not active(farm): return plots
	for index: int in BEDS:
		var hydrated: bool = farm.climate.data.lesson.stage == "success" or (index == BEDS[0] and farm.climate.data.lesson.stage == "area")
		plots[index].merge({"unlocked": true, "stage": 2, "watered": hydrated, "tilled": true, "crop": "sunburst", "pests": false, "frozen": false}, true)
	return plots
static func present(farm, info: Dictionary) -> void:
	info.lesson = farm.climate.data.lesson.duplicate()
	info.lesson.cost = int(farm.climate.Operations.water_cost(farm))
	if not active(farm): return
	info.event = "drought"
	info.phase = "active"
	info.name = "WATER PRACTICE"
	info.island = 2
	info.severity = 0.55
	info.timer = 30.0
	info.operations.stress = {}
	for index: int in BEDS:
		if info.lesson.stage == "success" or (index == BEDS[0] and info.lesson.stage == "area"): continue
		info.operations.stress[str(index)] = 0.6
static func tick(farm, delta: float) -> void:
	if not active(farm) or farm.climate.data.lesson.stage != "success": return
	farm.climate.data.lesson.remaining = maxf(0.0, float(farm.climate.data.lesson.remaining) - delta)
	if float(farm.climate.data.lesson.remaining) <= 0.0: finish(farm)
static func valid(raw: Variant) -> bool:
	return raw is Dictionary and raw.get("stage") in ["off", "offer", "water", "area", "success", "done"] and (raw.get("remaining") is float or raw.get("remaining") is int) and is_finite(raw.remaining) and float(raw.remaining) >= 0.0 and float(raw.remaining) <= 3.0 and (raw.stage == "success" or float(raw.remaining) == 0.0)
