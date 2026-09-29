extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Ops = preload("res://scripts/climate_operations.gd")
var farm
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh() -> void:
	farm.reset_game()
	# Fully expanded fields also match the pre-revision-21 migration fixture.
	for id in ["farm"]:
		farm.expansion = 1
		for plot in farm.plots: plot.unlocked = true
	farm.coins = 1e18
	farm.rng.seed = 32451
	for plot in farm.plots:
		farm._clear_crop(plot)
		plot.unlocked = true
		plot.tilled = true
		plot.crop = "russet"
		plot.stage = 1
func weather(event: String) -> void:
	farm.climate.begin_warning(farm, event, 1.0)
	farm.update(45)
func run() -> void:
	farm = State.new()
	root.add_child(farm)
	fresh()
	var supply: Dictionary = Ops.local(farm)
	check(not Ops.spend(farm, "water", 10000), "ordinary equipment cannot overdraw tank")
	check(supply.water == 36, "ordinary tools do not drain reserves")
	weather("drought")
	check(farm.climate.data.field_lost == 0, "onset leaves time to rescue every planted bed")
	farm.update(10)
	check(farm.climate.data.field_lost == 0 and float(farm.climate.data.operations.stress["0"]) > 0.3, "visible danger builds before loss")
	var stress: float = farm.climate.data.operations.stress["0"]
	farm.interact_plot(0, "water")
	check(float(farm.climate.data.operations.stress["0"]) < stress and supply.can == 15 and supply.water == 36, "watering tool spends carried water and rescues stressed bed")
	check(farm.climate.data.operations.rescued.size() > 0, "successful rescue receipt recorded")
	farm.update(20)
	check(farm.climate.data.field_lost > 0 and farm.climate.data.phase == "recovery", "unattended danger causes actual losses over time")
	farm.update(8)
	check(supply.water == 36, "recovery refills reserves")
	fresh()
	farm.climate.data.projects.rainwater = 1 # Completed infrastructure fixture; construction is covered in test_protection.
	farm.climate.fund(farm, "irrigation")
	weather("drought")
	farm.update(10)
	var before_irrigation: float = Ops.local(farm).water
	Ops.target(farm, 0, "water")
	check(float(farm.climate.data.operations.stress["0"]) < 0.05 and float(farm.climate.data.operations.stress["20"]) > 0.3, "sprinkler rescue only protects its fixed patch")
	check(Ops.local(farm).water == before_irrigation - Ops.water_cost(farm), "sprinkler uses its exact saved reserve cost")
	check(Ops.capacity(farm) == 72, "tank upgrade increases capacity")
	Ops.local(farm).water = 0.0
	Ops.operate(farm, "hand")
	check(Ops.local(farm).water == 0, "retired invisible well cannot create water")
	Ops.operate(farm, "mode")
	check(Ops.local(farm).mode == 0, "legacy mode cannot start hidden consumption")
	var path: String = "user://climate_operations_test_only.json"
	check(farm.save_game(path) and farm.load_game(path), "active hazard, controls and reserve round-trip")
	var data: Dictionary = farm._save_data()
	data.climate.operations.supply.water = -1
	check(not farm._valid_save(data), "negative saved water rejected atomically")
	data = farm._save_data()
	data.climate.operations.strike_row = 7
	check(not farm._valid_save(data), "out-of-bounds lightning row rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	fresh()
	weather("flood")
	farm.update(10)
	stress = farm.climate.data.operations.stress["0"]
	farm.interact_plot(0, "hoe")
	check(float(farm.climate.data.operations.stress["0"]) < stress and farm.plots[0].stage == 1, "hoe drains living flooded beds without destroying crop")
	fresh()
	farm.climate.data.projects.drainage = 1 # Completed infrastructure fixture; construction is covered in test_protection.
	Ops.operate(farm, "gates")
	weather("flood")
	farm.update(30)
	check(farm.climate.data.field_lost == 0, "opened purchased drainage prevents severe flood loss")
	fresh()
	weather("storm")
	farm.update(2.5)
	check(farm.climate.data.operations.strike_row >= 0 and farm.climate.data.operations.scars.is_empty(), "lightning reveals exact row before damage")
	var row: int = farm.climate.data.operations.strike_row
	farm.update(2.5)
	check(farm.climate.data.operations.scars.has(str(row * 6)) and farm.climate.data.operations.flash > 0, "bolt hits warned row and leaves saved scorch marks")
	farm.update(0.5)
	farm.plots[0].pests = true
	Ops.local(farm).spray = 0.0
	farm.interact_plot(0, "pest")
	check(farm.plots[0].pests, "empty sprayer cannot clear pests during disaster")
	farm.update(5)
	farm.queue_free()
	print("CLIMATE OPERATIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
