extends RefCounted
## Saved, deterministic quarter-second field hazards and player-operated reserves.
const CropTable = preload("res://scripts/crop_table.gd")
const ZONES: Array[String] = ["Far beds", "Middle beds", "Near beds"]

static func fresh() -> Dictionary:
	return {"supply": {"can": 16.0, "refilled": false, "water": 36.0, "spray": 18.0, "zone": 0, "mode": 0, "gates": false, "shelter": 0}, "tick": 0.0, "ice": {}, "stress": {}, "wet": {}, "scars": {}, "rescued": {}, "damaged": {}, "loss_groups": {}, "strike_row": -1, "strike_in": 5.0, "flash": 0.0, "pulse": 0.0}

static func local(farm) -> Dictionary:
	return farm.climate.data.operations.supply

static func capacity(farm) -> float:
	return 36.0 + 36.0 * int(farm.climate.data.projects.get("rainwater", 0))

static func zone(index: int) -> int:
	return mini(2, (index / 6) * 3 / 4)

static func scarce(farm) -> bool:
	return (not farm.tutorial_active or farm.guided_first_year()) and farm.climate.data.phase == "active"

static func spend(farm, resource: String, amount: float) -> bool:
	if resource != "water" and not scarce(farm): return true
	var supply: Dictionary = local(farm)
	if float(supply[resource]) + 0.000001 < amount: return false
	supply[resource] = maxf(0.0, float(supply[resource]) - amount)
	return true

static func can_capacity(farm) -> float:
	return 16.0 + 16.0 * int(farm.tools.water)

static func pour(farm) -> bool:
	var supply: Dictionary = local(farm)
	if float(supply.can) < 1.0: return false
	supply.can -= 1.0
	return true

static func refill(farm) -> String:
	var supply: Dictionary = local(farm)
	var amount: float = floorf(minf(can_capacity(farm) - float(supply.can), float(supply.water)))
	if amount <= 0.0: return farm._finish("Can is full." if float(supply.can) >= can_capacity(farm) else "Tank needs more water; rain refills it outside dry spells.")
	supply.water -= amount
	supply.can += amount
	supply.refilled = true
	farm.climate_changed.emit("refill")
	return farm._finish("Can refilled · %d / %d water" % [floori(supply.can), int(can_capacity(farm))])

static func relieve(farm, index: int, amount: float) -> void:
	var op: Dictionary = farm.climate.data.operations
	var key: String = str(index)
	var before: float = float(op.stress.get(key, 0.0))
	if before >= 0.35: op.rescued[key] = true
	op.stress[key] = maxf(0.0, before - amount)

static func frozen(farm, index: int) -> bool:
	return bool(farm.plots[index].get("winter_ice", false)) or farm.climate.data.operations.ice.has(str(index))

static func crop_frozen(farm, index: int) -> bool:
	return farm.climate.data.operations.ice.has(str(index)) or (bool(farm.plots[index].get("winter_ice", false)) and farm.plots[index].crop != "icecap")

static func tool(farm, index: int, action: String) -> bool:
	if frozen(farm, index):
		if action != "hoe": return false
		farm.plots[index].winter_ice = false
		farm.climate.data.operations.ice.erase(str(index))
		farm.climate.data.operations.rescued[str(index)] = true
		relieve(farm, index, 1.0)
		farm.climate.data.operations.pulse = 1.0
		return true
	if not scarce(farm) or int(farm.plots[index].stage) == 0: return false
	var op: Dictionary = farm.climate.data.operations
	var event: String = farm.climate.data.event
	if action == "water" and event == "drought" and float(op.stress.get(str(index), 0.0)) > 0.02:
		if not pour(farm): return false
		relieve(farm, index, 0.65)
		op.wet[str(index)] = 5.0
		if int(farm.plots[index].stage) == 1:
			farm.plots[index].watered = true
			farm.plots[index].stage = 2
			farm.farm_help.observe_plot(farm, index, "water")
		return true
	if action == "hoe" and event == "flood" and float(op.stress.get(str(index), 0.0)) > 0.02:
		relieve(farm, index, 0.6)
		return true
	return false

static func water_cost(farm) -> float:
	return 8.0 - 2.0 * int(farm.climate.data.projects.get("irrigation", 0))

static func needs_water(farm, index: int) -> bool:
	var plot: Dictionary = farm.plots[index]
	if not plot.unlocked or int(plot.stage) == 0 or crop_frozen(farm, index): return false
	if int(plot.stage) == 1 or not plot.watered: return true
	return scarce(farm) and farm.climate.data.event == "drought" and (float(farm.climate.data.operations.stress.get(str(index), 0)) > 0.02 or float(farm.climate.data.operations.wet.get(str(index), 0)) < 1)

static func target(farm, index: int, action: String) -> String:
	if index < 0 or index >= farm.plots.size(): return farm._finish("Choose beds on the farm.")
	if farm.climate.Lesson.active(farm):
		if action == "water" and farm.climate.data.lesson.stage == "area": return farm.climate.Lesson.area(farm, index)
		return farm._finish("Water the glowing practice bed first [3].")
	if farm.run_over:
		return farm._finish("These controls are for the affected farm.")
	var supply: Dictionary = local(farm)
	var projects: Dictionary = farm.climate.data.projects
	var chosen: int = zone(index)
	if action == "shelter":
		if int(projects.get("windbreaks", 0)) == 0: return farm._finish("Build living windbreaks first.")
		return farm._finish("Windbreaks reduce storm losses across the field.")
	elif action == "water":
		if int(projects.get("irrigation", 0)) == 0:
			return farm._finish("Build a sprinkler first.")
		var planted: bool = false
		for i in range(farm.plots.size()):
			if zone(i) == chosen and needs_water(farm, i): planted = true
		if not planted: return farm._finish("These beds do not need water yet; none spent.")
		if not spend(farm, "water", water_cost(farm)): return farm._finish("Not enough tank water. Rain refills it after the dry spell.")
		supply.zone = chosen
		supply.mode = 0
		for i in range(farm.plots.size()):
			if zone(i) == chosen and needs_water(farm, i):
				if scarce(farm) and farm.climate.data.event == "drought":
					relieve(farm, i, 0.8)
					farm.climate.data.operations.wet[str(i)] = 6.0
				elif not scarce(farm):
					relieve(farm, i, 1.0)
				if int(farm.plots[i].stage) == 1:
					farm.plots[i].stage = 2
					farm.plots[i].watered = true
					farm.farm_help.observe_plot(farm, i, "water")
	else: return "Unknown field action."
	farm.climate_changed.emit("controls")
	return farm._finish("Connected beds watered · %d tank water used." % int(water_cost(farm)))

static func operate(farm, action: String) -> String:
	if farm.run_over or farm.tutorial_active: return "Finish the farm tour before using these controls."
	var supply: Dictionary = local(farm)
	var projects: Dictionary = farm.climate.data.projects
	if action == "gates":
		if int(projects.get("drainage", 0)) == 0: return farm._finish("Build drainage first. Hoe [1] can drain individual beds.")
		supply.gates = true
		farm.climate_changed.emit("controls")
		return farm._finish("Drain open · Water flows through the channel to the sea.")
	if action == "shelter": return farm._finish("Windbreaks protect automatically.")
	return farm._finish("Click equipment on the farm to use it.")

static func begin(farm) -> void:
	var old: Dictionary = farm.climate.data.operations.supply
	farm.climate.data.operations = fresh()
	farm.climate.data.operations.supply = old

static func update(farm, delta: float) -> bool:
	var c = farm.climate
	var op: Dictionary = c.data.operations
	op.tick += delta
	var dirty: bool = false
	while float(op.tick) >= 0.25 - 0.000001:
		op.tick = maxf(0.0, float(op.tick) - 0.25)
		_tick(farm, 0.25)
		dirty = true
	return dirty

static func _tick(farm, dt: float) -> void:
	var c = farm.climate
	var op: Dictionary = c.data.operations
	for key in op.wet.keys():
		op.wet[key] = maxf(0.0, float(op.wet[key]) - dt)
	op.flash = maxf(0.0, float(op.flash) - dt)
	op.pulse = maxf(0.0, float(op.pulse) - dt)
	if c.data.phase != "active" or c.data.event != "drought":
		op.supply.water = minf(capacity(farm), float(op.supply.water) + dt * 6.0 * (0.5 if c.data.outlook.signal == "drought" else 1.0) * (0.25 if farm.season_clock.season == 3 else 1.0))
	if c.data.phase != "active": op.supply.spray = minf(18.0, float(op.supply.spray) + dt * 3.0)
	var field: Array = farm.plots
	var supply: Dictionary = op.supply
	var projects: Dictionary = c.data.projects
	var event: String = c.data.event if c.data.phase == "active" else ""
	var strength: float = c.data.severity
	if event == "storm":
		op.strike_in -= dt
		if int(op.strike_row) < 0 and float(op.strike_in) <= 2.5:
			op.strike_row = farm.rng.randi_range(0, 3)
		if float(op.strike_in) <= 0.0:
			var columns: int = 6
			for index in range(int(op.strike_row) * columns, (int(op.strike_row) + 1) * columns):
				if int(field[index].stage) == 0: continue
				farm.Quality.deduct(farm, index, "storm", 25, true)
				# Storm losses use the same protection formula for wind and strikes.
				op.stress[str(index)] = minf(1.0, float(op.stress.get(str(index), 0.0)) + 0.85 * strength)
				op.scars[str(index)] = true
			op.flash = 0.75
			op.strike_in = 7.5
			farm.climate_changed.emit("strike")
		# Keep the struck row briefly so the visible bolt hits the actual damaged line.
		elif float(op.strike_in) < 6.5 and float(op.strike_in) > 2.5:
			op.strike_row = -1
	for index in range(field.size()):
		var key: String = str(index)
		if int(field[index].stage) == 0:
			op.ice.erase(key)
			op.stress.erase(key)
			op.wet.erase(key)
			continue
		if not event.is_empty() and op.damaged.has(key): continue
		var crop: String = str(field[index].crop)
		var water_need: float = float(CropTable.CROPS[crop].water_need)
		var stress: float = float(op.stress.get(key, 0.0))
		if not field[index].watered: stress += dt * 0.0025 * water_need
		var wet: float = maxf(0.0, float(op.wet.get(key, 0.0)))
		op.wet[key] = wet
		var exposure: float = 0.75 + float((index * 7) % 11) / 20.0
		if event == "drought":
			if wet <= 0.0: stress += dt * 0.052 * strength * exposure * (0.5 + 0.5 * water_need) * CropTable.heat_factor(crop)
		elif event == "freeze":
			if op.ice.has(key): stress += dt * 0.037 * strength * exposure * CropTable.cold_factor(crop)
		elif event == "flood":
			stress += dt * 0.055 * strength * exposure
			if supply.gates and int(projects.get("drainage", 0)) > 0:
				stress = maxf(0.0, stress - dt * 0.075 * int(projects.drainage))
		elif event == "storm":
			stress += dt * 0.009 * strength
		op.stress[key] = minf(1.0, stress)
		if stress >= 1.0:
			c.Protection.damage(farm, index, event)
			if not event.is_empty(): op.damaged[key] = true
			op.scars[key] = true
			op.stress[key] = 0.0
			if int(field[index].stage) == 0: op.ice.erase(key)

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or not raw.get("supply") is Dictionary: return false
	var s: Variant = raw.supply
	if not s is Dictionary: return false
	if not _number(s.get("can"), 0, 64): return false
	if not s.get("refilled") is bool: return false
	for key in ["water", "spray", "zone", "mode", "shelter"]:
		var limit: float = 108.0 if key == "water" else (18.0 if key == "spray" else 2.0)
		if not _number(s.get(key), 0.0, limit): return false
		if key in ["zone", "mode", "shelter"] and float(s[key]) != floor(float(s[key])): return false
	for key in ["gates"]:
		if not s.get(key) is bool: return false
	if raw.has("ice"):
		if not raw.ice is Dictionary or raw.ice.size() > 24: return false
		for index in raw.ice:
			if not str(index).is_valid_int() or int(index) < 0 or int(index) >= 24 or raw.ice[index] != true: return false
	if not raw.get("loss_groups") is Dictionary or raw.loss_groups.size() > 120: return false
	for key in raw.loss_groups:
		var group: Variant = raw.loss_groups[key]
		if not key is String or key.length() > 80 or not group is Dictionary or group.size() != 2: return false
		if not _number(group.get("exposed"), 1, 100000) or float(group.exposed) != floorf(float(group.exposed)): return false
		if not _number(group.get("card"), -1, 99999) or float(group.card) != floorf(float(group.card)): return false
	for key in ["tick", "strike_in", "flash", "pulse"]:
		if not _number(raw.get(key), 0.0, 0.25 if key == "tick" else 8.0): return false
	if not _number(raw.get("strike_row"), -1, 3) or float(raw.strike_row) != floor(float(raw.strike_row)): return false
	for key in ["stress", "wet", "scars", "rescued", "damaged"]:
		if not raw.get(key) is Dictionary or raw[key].size() > 24: return false
		for index in raw[key]:
			if not str(index).is_valid_int() or int(index) < 0 or int(index) >= 24: return false
			if key in ["scars", "rescued", "damaged"]:
				if not raw[key][index] is bool: return false
			elif not _number(raw[key][index], 0, 6.0 if key == "wet" else 1.0): return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and float(value) >= low and float(value) <= high
