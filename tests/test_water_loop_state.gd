extends SceneTree
## Resource conservation, useful actions, weather, and save compatibility.
## Every save is disposable; the player's default save is never opened.
const State = preload("res://scripts/game_state.gd")
const Ops = preload("res://scripts/climate_operations.gd")
const SAVE: String = "user://connected_water_test_only.json"
var farm
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)

func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not same(a[i], b[i]): return false
		return true
	return a == b

func fresh(with_irrigation: bool = false) -> void:
	farm.reset_game()
	farm.rng.seed = 38172
	farm.coins = 1e18
	farm.expansion = 1
	for plot in farm.plots: plot.unlocked = true
	if with_irrigation: farm.climate.fund(farm, "irrigation")
	for plot in farm.plots: farm._clear_crop(plot)

func planted(index: int, watered: bool = false) -> void:
	var plot: Dictionary = farm.plots[index]
	farm._clear_crop(plot)
	plot.unlocked = true
	plot.tilled = true
	plot.stage = 2 if watered else 1
	plot.watered = watered
	plot.crop = "russet"

func start_weather(event: String) -> void:
	check(farm.climate.begin_warning(farm, event, 1.0), "warn before " + event)
	farm.update(45.0)
	check(farm.climate.data.phase == "active", event + " begins after its preparation window")

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func test_can_and_farming() -> void:
	fresh()
	var supply: Dictionary = Ops.local(farm)
	var capacity: float = Ops.can_capacity(farm)
	check(capacity >= 12 and supply.can == capacity, "starter can carries a full starter field without repeated trips")
	planted(0)
	var tank: float = supply.water
	farm.interact_plot(0, "water")
	check(supply.can == capacity - 1 and supply.water == tank and farm.plots[0].stage == 2, "a watered crop consumes one carried water, not remote tank water")
	farm.interact_plot(0, "water")
	farm.interact_plot(1, "water")
	check(supply.can == capacity - 1, "already-watered and empty beds do not waste carried water")
	supply.can = 1.0
	planted(2)
	planted(3)
	farm.interact_plot(2, "water")
	var notice: String = farm.interact_plot(3, "water")
	check(supply.can == 0 and not farm.plots[3].watered and notice.to_lower().contains("tank"), "empty can stops watering and gives an actionable tank instruction")
	Ops.refill(farm)
	check(supply.can == capacity and supply.water == tank - capacity and supply.refilled, "refilling transfers an equal amount from tank to can")
	tank = supply.water
	Ops.refill(farm)
	check(supply.water == tank and supply.can == capacity, "refilling a full can spends nothing")
	supply.can = 0.0
	supply.water = 3.0
	Ops.refill(farm)
	check(supply.can == 3 and supply.water == 0, "a partial reserve transfers only available water")
	Ops.refill(farm)
	check(supply.can == 3 and supply.water == 0, "empty reserve cannot invent water or make counts negative")
	farm.update(6.0)
	check(supply.water == Ops.capacity(farm) and supply.can == 3, "Island 1 tank replenishes quickly while carried water remains finite")
	farm.climate.update(farm, 1000)
	farm.set_tutorial_active(true)
	supply.water = 0.0
	farm.update(6.0)
	check(supply.water > 0, "starter tutorial still replenishes its teaching tank")
	farm._clear_crop(farm.plots[5])
	farm.plots[5].tilled = false
	var seeds: int = farm.seed_inventory.russet
	farm.interact_plot(5, "hoe")
	farm.interact_plot(5, "plant")
	farm.interact_plot(5, "water")
	farm.update(float(farm.CropTable.CROPS.russet.grow) + 0.1)
	check(farm.plots[5].stage == 3 and farm.seed_inventory.russet == seeds - 1, "ordinary hoe, plant, finite water and growth loop remains playable")
	farm.interact_plot(5, "harvest")
	check(farm.storage.russet > 0 and farm.plots[5].stage == 0, "ordinary watered crops reach the barn")
	farm.set_tutorial_active(false)

func test_upgrades_and_irrigation() -> void:
	fresh()
	var supply: Dictionary = Ops.local(farm)
	var capacity: float = Ops.can_capacity(farm)
	var carried: float = supply.can
	var tank: float = supply.water
	farm.upgrade_tool("water")
	check(Ops.can_capacity(farm) > capacity and supply.can == carried and supply.water == tank, "bigger can adds carrying space without secretly creating water")
	Ops.refill(farm)
	check(supply.can > carried and is_equal_approx(supply.can + supply.water, carried + tank), "filling a bigger can still conserves shared water")
	for rank in [1, 2, 3]:
		fresh(true)
		farm.tools.water = rank
		for index in range(farm.plots.size()): planted(index)
		supply = Ops.local(farm)
		supply.can = 5
		tank = supply.water
		farm.interact_plot(14, "water")
		var watered_count: int = 0
		for plot in farm.plots:
			if plot.watered: watered_count += 1
		check(watered_count == 5 and supply.can == 0 and supply.water == tank, "rank %d area watering stops exactly at the carried reserve, preserving legacy area coverage" % rank)
	fresh(true)
	supply = Ops.local(farm)
	check(int(farm.climate.data.projects.get("irrigation", 0)) >= 1, "purchased sprinkler is available before the first dry spell")
	capacity = Ops.capacity(farm)
	tank = supply.water
	farm.climate.fund(farm, "rainwater")
	check(Ops.capacity(farm) > capacity and supply.water == tank, "bigger tank increases storage without an invisible refill")
	planted(0)
	planted(1)
	planted(12)
	var cost: float = Ops.water_cost(farm)
	carried = supply.can
	Ops.target(farm, 0, "water")
	check(supply.water == tank - cost and supply.can == carried, "ordinary-weather irrigation spends its displayed tank cost and leaves the can alone")
	check(farm.plots[0].watered and farm.plots[1].watered and not farm.plots[12].watered, "sprinkler waters only its connected patch")
	check(farm.plots[0].stage == 2 and farm.plots[0].watered, "ordinary irrigation provides the same wet-soil and growth state as can watering")
	tank = supply.water
	Ops.target(farm, 0, "water")
	Ops.target(farm, 40, "water")
	Ops.target(farm, -1, "water")
	check(supply.water == tank, "already-watered, empty and invalid patches never consume irrigation water")
	planted(0)
	supply.water = cost - 1
	Ops.target(farm, 0, "water")
	check(supply.water == cost - 1 and not farm.plots[0].watered, "insufficient tank reserve rejects a whole sprinkler action atomically")
	supply.water = 36
	farm.climate.fund(farm, "irrigation")
	check(Ops.water_cost(farm) < cost, "better irrigation reduces the cost of the same patch")
	tank = supply.water
	Ops.target(farm, 0, "water")
	check(farm.plots[0].watered and supply.water == tank - Ops.water_cost(farm), "upgraded sprinkler applies its actual discounted cost")
	check(supply.mode == 0, "clicking a sprinkler never starts hidden continuous consumption")
	farm.climate.data.projects.irrigation = 0
	planted(0)
	tank = supply.water
	Ops.target(farm, 0, "water")
	check(supply.water == tank and not farm.plots[0].watered, "unbuilt irrigation cannot remotely water crops")
	fresh(true)
	farm.climate.data.projects.irrigation = 1
	planted(0)
	farm.climate.begin_warning(farm, "freeze", 1.0)
	farm.climate._impact(farm)
	supply = Ops.local(farm)
	tank = supply.water
	carried = supply.can
	farm.interact_plot(0, "water")
	Ops.target(farm, 0, "water")
	check(supply.water == tank and supply.can == carried and not farm.plots[0].watered, "frozen crops cannot consume irrigation or can water before thawing")

func test_drought_and_shared_reserve() -> void:
	fresh(true)
	for index in [0, 1, 12, 20]: planted(index)
	start_weather("drought")
	var supply: Dictionary = Ops.local(farm)
	var tank: float = supply.water
	farm.update(5.0)
	check(supply.water == tank and farm.climate.data.field_lost == 0, "dry spell stops rain refill but leaves an understandable rescue window")
	var stress: float = farm.climate.data.operations.stress["0"]
	var carried: float = supply.can
	farm.interact_plot(0, "water")
	check(supply.can == carried - 1 and supply.water == tank and farm.climate.data.operations.stress["0"] < stress, "familiar can watering spends carried water and reduces drought danger")
	supply.can = 0.0
	Ops.refill(farm)
	check(supply.water == tank - Ops.can_capacity(farm), "drought refill draws from the same limited tank")
	tank = supply.water
	stress = farm.climate.data.operations.stress["20"]
	Ops.target(farm, 12, "water")
	check(supply.water == tank - Ops.water_cost(farm) and farm.climate.data.operations.stress["12"] == 0 and farm.climate.data.operations.stress["20"] == stress, "drought sprinkler spends tank water and rescues only connected beds")
	supply.water = 0.0
	farm.update(1.0)
	check(supply.water == 0, "depleted drought reserve cannot silently regenerate")
	var local_tank: Dictionary = Ops.local(farm)
	local_tank.water = 0.0
	farm.update(1.0)
	farm.update(30)
	check(farm.climate.data.phase == "recovery" and supply.water > 0, "rain supply returns when the dry spell clears")

func test_weather_equipment() -> void:
	fresh(true)
	farm.climate.fund(farm, "drainage")
	planted(0)
	start_weather("flood")
	farm.climate.data.operations.stress["0"] = 0.5
	var tank: float = Ops.local(farm).water
	Ops.operate(farm, "gates")
	Ops.update(farm, 1.0)
	check(Ops.local(farm).gates and farm.climate.data.operations.stress["0"] < 0.5, "opening a bought drain reduces actual flood danger")
	check(Ops.local(farm).water >= tank, "draining floodwater does not spend freshwater")
	Ops.operate(farm, "gates")
	check(Ops.local(farm).gates, "repeated Open drain clicks cannot silently close protection")
	var stress: float = farm.climate.data.operations.stress["0"]
	Ops.target(farm, 0, "water")
	check(farm.climate.data.operations.stress["0"] == stress, "sprinkler watering cannot cure flood danger")
	fresh(true)
	farm.climate.fund(farm, "windbreaks")
	planted(0, true)
	planted(20, true)
	Ops.local(farm).shelter = 2
	start_weather("storm")
	Ops.update(farm, 2.0)
	check(float(farm.climate.data.operations.stress["0"]) < float(farm.climate.data.operations.stress["20"]) * 0.8, "trees shelter the fixed far patch regardless of a legacy movable-screen setting")
	fresh(true)
	farm.barn_level = 2
	farm._recompute_capacity()
	farm.storage.russet = 1000
	farm.climate.fund(farm, "barn")
	Ops.local(farm).sealed = false
	start_weather("flood")
	check(farm.climate.data.barn_lost > 0 and farm.climate.data.barn_lost < 150, "reinforced barn automatically protects stock without a shutter control")
	fresh(true)
	planted(0)
	start_weather("drought")
	farm.update(3.0)
	var controls: Dictionary = Ops.local(farm).duplicate(true)
	for old_action in ["mode", "shelter", "sealed", "burst", "hand"]: Ops.operate(farm, old_action)
	check(same(Ops.local(farm), controls), "obsolete invisible controls cannot create reserves or activate movable and continuous modes")

func test_save_validation() -> void:
	fresh(true)
	farm.tools.water = 3
	farm.coins = 12345
	farm.storage.russet = 21
	farm.seed_inventory.icecap = 9
	farm.climate.data.projects.rainwater = 1
	planted(7)
	Ops.local(farm).water = 51
	Ops.local(farm).can = 37
	var before: Dictionary = farm._save_data()
	check(farm._valid_save(before), "connected water checkpoint is valid before writing")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "can, tank and equipment round-trip through a disposable save")
	check(same(farm.climate.data, before.climate) and same(farm.plots, before.plots), "round-trip preserves all resource levels and planted crops")
	for invalid in [-1.0, 65.0, NAN, INF, "16"]:
		var corrupt: Dictionary = farm._save_data()
		corrupt.climate.operations.supply.can = invalid
		check(not farm._valid_save(corrupt), "invalid can value rejects: " + str(invalid))
	var corrupt: Dictionary = farm._save_data()
	corrupt.climate.operations.supply.erase("can")
	check(not farm._valid_save(corrupt), "new revision cannot silently omit carried water")
	corrupt = farm._save_data()
	corrupt.climate.operations.supply.refilled = 1
	check(not farm._valid_save(corrupt), "refill guidance flag has strict boolean validation")
	corrupt = farm._save_data()
	corrupt.tools.water = 0
	for supply in [corrupt.climate.operations.supply]: supply.can = 16
	corrupt.climate.operations.supply.can = 17
	check(not farm._valid_save(corrupt), "saved can cannot exceed its purchased carrying capacity")
	corrupt = farm._save_data()
	corrupt.climate.operations.supply.water = -1
	write_save(corrupt)
	var untouched: Dictionary = farm._save_data()
	check(not farm.load_game(SAVE) and same(farm._save_data(), untouched), "rejected corrupt save leaves the current farm unchanged atomically")
	for invalid in [null, [], "broken", {"islands": []}, {"islands": {"1": [], "2": {}, "3": {}}}]:
		corrupt = farm._save_data()
		corrupt.climate.operations = invalid
		check(not farm._valid_save(corrupt), "malformed water structure safely rejects: " + str(invalid))

func test_practice_isolation() -> void:
	fresh(true)
	planted(18)
	var real_crops: Array = farm.plots.duplicate(true)
	var money: float = farm.coins
	var clock: float = farm.elapsed
	farm.climate.Lesson.start(farm)
	farm.update(200)
	check(farm.elapsed == clock and farm.coins == money and same(farm.plots, real_crops), "safe practice freezes clocks and bills without changing real crops")
	var supply: Dictionary = Ops.local(farm)
	supply.can = 0
	farm.interact_plot(18, "water")
	check(farm.climate.data.lesson.stage == "water" and supply.can == 0, "an empty practice can cannot bypass the real resource rule")
	Ops.refill(farm)
	var carried: float = supply.can
	farm.interact_plot(0, "water")
	check(farm.climate.data.lesson.stage == "water" and supply.can == carried, "wrong practice bed preserves both instruction and carried water")
	farm.interact_plot(18, "water")
	check(farm.climate.data.lesson.stage == "area" and supply.can == carried - 1, "practice can uses the same finite resource as ordinary farming")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.climate.data.lesson.stage == "area", "practice resumes its saved step with real crops untouched")
	supply = Ops.local(farm)
	var tank: float = supply.water
	Ops.target(farm, 0, "water")
	check(farm.climate.data.lesson.stage == "area" and supply.water == tank, "wrong practice sprinkler preserves tank water")
	Ops.target(farm, 19, "water")
	check(farm.climate.data.lesson.stage == "success" and supply.water == tank - Ops.water_cost(farm), "practice sprinkler spends its shown shared-tank cost")
	farm.climate.Lesson.tick(farm, 3.1)
	check(farm.climate.data.lesson.stage == "done" and same(farm.plots, real_crops), "practice completion restores the exact saved crop view")
	farm.climate.Lesson.start(farm)
	farm.climate.Lesson.finish(farm)
	check(same(farm.plots, real_crops), "skipping practice cannot overwrite a real crop")

func run() -> void:
	farm = State.new()
	root.add_child(farm)
	test_can_and_farming()
	test_upgrades_and_irrigation()
	test_drought_and_shared_reserve()
	test_weather_equipment()
	test_save_validation()
	test_practice_isolation()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	print("CONNECTED WATER STATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
