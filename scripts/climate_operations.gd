extends RefCounted
## Saved, deterministic quarter-second field hazards and player-operated reserves.
const ZONES: Array[String] = ["Far beds", "Middle beds", "Near beds"]

static func fresh() -> Dictionary:
	var islands: Dictionary = {}
	for id in ["1", "2", "3"]:
		islands[id] = {"water": 36.0, "spray": 18.0, "zone": 0, "mode": 0, "gates": false, "shelter": 0, "sealed": false}
	return {"islands": islands, "tick": 0.0, "stress": {}, "wet": {}, "scars": {}, "rescued": {}, "strike_row": -1, "strike_in": 5.0, "flash": 0.0, "pulse": 0.0}

static func local(farm) -> Dictionary:
	return farm.climate.data.operations.islands[str(farm.current_island)]

static func capacity(farm, island: int) -> float:
	return 36.0 + 36.0 * int(farm.climate.data.projects[str(island)].get("rainwater", 0))

static func zone(index: int, island: int) -> int:
	return mini(2, int(float(index / (10 if island == 3 else 8)) * 3.0 / (8.0 if island == 3 else 6.0)))

static func scarce(farm) -> bool:
	return not farm.tutorial_active and farm.climate.data.phase == "active" and farm.climate.data.island == farm.current_island

static func spend(farm, resource: String, amount: float) -> bool:
	if not scarce(farm): return true
	var supply: Dictionary = local(farm)
	if float(supply[resource]) + 0.000001 < amount: return false
	supply[resource] = maxf(0.0, float(supply[resource]) - amount)
	return true

static func relieve(farm, index: int, amount: float) -> void:
	var op: Dictionary = farm.climate.data.operations
	var key: String = str(index)
	var before: float = float(op.stress.get(key, 0.0))
	if before >= 0.35: op.rescued[key] = true
	op.stress[key] = maxf(0.0, before - amount)

static func tool(farm, index: int, action: String) -> bool:
	if not scarce(farm) or int(farm.plots[index].stage) == 0 or bool(farm.plots[index].get("frozen", false)): return false
	var op: Dictionary = farm.climate.data.operations
	var event: String = farm.climate.data.event
	if action == "water" and event == "drought" and float(op.stress.get(str(index), 0.0)) > 0.02:
		if not spend(farm, "water", 1.0 / (1.0 + float(farm.tools.water) * 0.3)): return false
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
	return 8.0 - 2.0 * int(farm.climate.data.projects[str(farm.current_island)].get("irrigation", 0))

static func target(farm, index: int, action: String) -> String:
	if index < 0 or index >= farm.plots.size(): return farm._finish("Choose beds on the farm.")
	if farm.climate.Lesson.active(farm):
		if action == "water" and farm.climate.data.lesson.stage == "area": return farm.climate.Lesson.area(farm, index)
		return farm._finish("Water the glowing practice bed first [3].")
	if farm.run_over or farm.current_island < 2 or farm.climate.data.island != farm.current_island:
		return farm._finish("These controls are for the affected farm.")
	var supply: Dictionary = local(farm)
	var projects: Dictionary = farm.climate.data.projects[str(farm.current_island)]
	var chosen: int = zone(index, farm.current_island)
	if action == "shelter":
		if int(projects.get("windbreaks", 0)) == 0: return farm._finish("Build living windbreaks first.")
		supply.shelter = chosen
	elif action == "water":
		if not scarce(farm) or farm.climate.data.event != "drought" or int(projects.get("rainwater", 0)) == 0:
			return farm._finish("Use the tank during a drought.")
		var planted: bool = false
		for i in range(farm.plots.size()):
			if zone(i, farm.current_island) == chosen and int(farm.plots[i].stage) > 0: planted = true
		if not planted: return farm._finish("Choose an area with growing crops; no water spent.")
		if not spend(farm, "water", water_cost(farm)): return farm._finish("Not enough stored water. Draw emergency water first.")
		supply.zone = chosen
		supply.mode = 0
		for i in range(farm.plots.size()):
			if zone(i, farm.current_island) == chosen and int(farm.plots[i].stage) > 0:
				relieve(farm, i, 0.8)
				farm.climate.data.operations.wet[str(i)] = 6.0
				if int(farm.plots[i].stage) == 1:
					farm.plots[i].stage = 2
					farm.plots[i].watered = true
	else: return "Unknown field action."
	farm.climate_changed.emit("controls")
	return farm._finish("Area watered. Watch its danger rings fall." if action == "water" else "Screens moved. They reduce wind damage, not lightning.")

static func operate(farm, action: String) -> String:
	if farm.current_island < 2 or farm.run_over or farm.tutorial_active or farm.climate.data.intro_pending: return "Farm controls become available on Golden Shores."
	var supply: Dictionary = local(farm)
	var projects: Dictionary = farm.climate.data.projects[str(farm.current_island)]
	match action:
		"zone": supply.zone = (int(supply.zone) + 1) % 3
		"mode":
			if int(projects.get("irrigation", 0)) == 0: return farm._finish("Build irrigation to route water to a zone.")
			supply.mode = (int(supply.mode) + 1) % 3
		"gates":
			if int(projects.get("drainage", 0)) == 0: return farm._finish("Build drainage first. Your hoe can drain individual flooded beds.")
			supply.gates = not supply.gates
		"shelter":
			if int(projects.get("windbreaks", 0)) == 0: return farm._finish("Build living windbreaks to deploy their shelter screens.")
			supply.shelter = (int(supply.shelter) + 1) % 3
		"sealed":
			if int(projects.get("barn", 0)) == 0: return farm._finish("Reinforce the barn before securing its shutters.")
			supply.sealed = not supply.sealed
		"burst":
			if int(projects.get("rainwater", 0)) == 0: return farm._finish("Build a rainwater reserve for emergency releases.")
			if not scarce(farm) or farm.climate.data.event != "drought": return farm._finish("Save emergency releases for an active drought.")
			if not spend(farm, "water", 8.0): return farm._finish("Need 8 water for an emergency release. Ration the remaining supply.")
			for index in range(farm.plots.size()):
				if zone(index, farm.current_island) == int(supply.zone) and int(farm.plots[index].stage) > 0:
					relieve(farm, index, 0.8)
					farm.climate.data.operations.wet[str(index)] = 6.0
					if int(farm.plots[index].stage) == 1:
						farm.plots[index].stage = 2
						farm.plots[index].watered = true
			farm.climate.data.operations.pulse = 1.0
		"hand":
			if not scarce(farm) or float(supply.water) >= capacity(farm, farm.current_island): return farm._finish("Water replenishes automatically outside disasters.")
			# A slow emergency well: finite yield recovered over simulation time.
			if float(farm.climate.data.operations.pulse) > 0.0: return farm._finish("Let the emergency well recover before drawing again.")
			supply.water = minf(capacity(farm, farm.current_island), float(supply.water) + 4.0)
			farm.climate.data.operations.pulse = 8.0
		_: return "Unknown farm control."
	farm.climate_changed.emit("controls")
	return farm._finish("Farm controls updated. " + ZONES[int(supply.zone)] + " selected.")

static func begin(farm) -> void:
	var old: Dictionary = farm.climate.data.operations.islands
	farm.climate.data.operations = fresh()
	farm.climate.data.operations.islands = old

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
	op.flash = maxf(0.0, float(op.flash) - dt)
	op.pulse = maxf(0.0, float(op.pulse) - dt)
	for id: String in op.islands:
		if c.data.phase != "active" or int(id) != int(c.data.island):
			op.islands[id].water = minf(capacity(farm, int(id)), float(op.islands[id].water) + dt * 6.0)
			op.islands[id].spray = minf(18.0, float(op.islands[id].spray) + dt * 3.0)
	if c.data.phase != "active": return
	var island: int = c.data.island
	var field: Array = farm.island_plots[str(island)]
	var supply: Dictionary = op.islands[str(island)]
	var projects: Dictionary = c.data.projects[str(island)]
	var event: String = c.data.event
	var strength: float = c.data.severity
	if event == "storm":
		op.strike_in -= dt
		if int(op.strike_row) < 0 and float(op.strike_in) <= 2.5:
			op.strike_row = farm.rng.randi_range(0, 7 if island == 3 else 5)
		if float(op.strike_in) <= 0.0:
			var columns: int = 10 if island == 3 else 8
			for index in range(int(op.strike_row) * columns, (int(op.strike_row) + 1) * columns):
				if int(field[index].stage) == 0: continue
				# Trees/screens reduce wind stress, never shield crops from lightning.
				op.stress[str(index)] = float(op.stress.get(str(index), 0.0)) + 0.85 * strength
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
			op.stress.erase(key)
			op.wet.erase(key)
			continue
		var stress: float = float(op.stress.get(key, 0.0))
		var wet: float = maxf(0.0, float(op.wet.get(key, 0.0)) - dt)
		op.wet[key] = wet
		var exposure: float = 0.75 + float((index * 7) % 11) / 20.0
		var protection: float = 1.0 - c.protection(event, island, "field")
		if event == "drought":
			var irrigated: bool = int(projects.get("irrigation", 0)) > 0 and int(supply.mode) > 0 and zone(index, island) == int(supply.zone)
			var consumption: float = dt * (0.09 if int(supply.mode) == 1 else 0.24) / (1.0 + 0.4 * int(projects.get("irrigation", 0)))
			if irrigated and float(supply.water) >= consumption:
				supply.water -= consumption
				if int(field[index].stage) == 1:
					field[index].stage = 2
					field[index].watered = true
				stress = maxf(0.0, stress - dt * (0.025 if int(supply.mode) == 1 else 0.13))
				if int(supply.mode) == 2: wet = 1.0
			if wet <= 0.0: stress += dt * 0.052 * strength * exposure * protection
		elif event == "flood":
			stress += dt * 0.055 * strength * exposure * protection
			if supply.gates and int(projects.get("drainage", 0)) > 0:
				stress = maxf(0.0, stress - dt * 0.035 * int(projects.drainage))
		else:
			var sheltered: bool = int(projects.get("windbreaks", 0)) > 0 and zone(index, island) == int(supply.shelter)
			stress += dt * (0.002 if sheltered else 0.009) * strength * protection
		op.stress[key] = minf(1.0, stress)
		if stress >= 1.0:
			farm._clear_crop(field[index])
			if event == "flood": field[index].tilled = false
			op.scars[key] = true
			op.stress.erase(key)
			c.data.field_lost += 1
			c.data.last.field_lost += 1
			c.data.last.field_total = maxi(int(c.data.last.field_total), int(c.data.last.field_lost))
			if not c.data.history.is_empty(): c.data.history[-1] = c.data.last.duplicate(true)

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or not raw.get("islands") is Dictionary or raw.islands.size() != 3: return false
	for id in ["1", "2", "3"]:
		var s: Variant = raw.islands.get(id)
		if not s is Dictionary: return false
		for key in ["water", "spray", "zone", "mode", "shelter"]:
			var limit: float = 108.0 if key == "water" else (18.0 if key == "spray" else 2.0)
			if not _number(s.get(key), 0.0, limit): return false
			if key in ["zone", "mode", "shelter"] and float(s[key]) != floor(float(s[key])): return false
		for key in ["gates", "sealed"]:
			if not s.get(key) is bool: return false
	for key in ["tick", "strike_in", "flash", "pulse"]:
		if not _number(raw.get(key), 0.0, 0.25 if key == "tick" else 8.0): return false
	if not _number(raw.get("strike_row"), -1, 7) or float(raw.strike_row) != floor(float(raw.strike_row)): return false
	for key in ["stress", "wet", "scars", "rescued"]:
		if not raw.get(key) is Dictionary or raw[key].size() > 80: return false
		for index in raw[key]:
			if not str(index).is_valid_int() or int(index) < 0 or int(index) >= 80: return false
			if key in ["scars", "rescued"]:
				if not raw[key][index] is bool: return false
			elif not _number(raw[key][index], 0, 6.0 if key == "wet" else 1.0): return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and float(value) >= low and float(value) <= high
