extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE = "user://pest_schedule_test_only.json"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 9182
	farm.coins = 1e12
	farm.farm_help.data.enabled = false
	var bins: Array[int] = [0, 0, 0, 0, 0]
	for i in range(10000):
		var plot := {"pest_delay": 0.0}
		farm._schedule_pest(plot)
		check(plot.pest_delay >= 15 and plot.pest_delay <= 90, "uniform draw stays within 15–90 seconds")
		bins[mini(4, int((plot.pest_delay - 15) / 15))] += 1
	for count in bins: check(count > 1800 and count < 2200, "equal-width delay buckets have equal odds")
	for plot in farm.plots:
		if not plot.unlocked: continue
		plot.stage = 3
		plot.tilled = true
		plot.elapsed = farm.CROPS[plot.crop].grow
		plot.watered = true
		plot.plant_age = 40.0
		farm._schedule_pest(plot)
	var first: float = 90
	var last: float = 15
	for plot in farm.plots:
		if plot.stage == 3:
			first = minf(first, plot.pest_delay)
			last = maxf(last, plot.pest_delay)
	check(last - first > 30, "simultaneously ripe beds have staggered independent timers")
	farm.update(first - 0.01)
	check(farm.plots.all(func(p): return not p.pests), "no infestation before its own timer")
	farm.update(0.01)
	check(farm.plots.filter(func(p): return p.pests).size() == 1, "only earliest bed spawns, not entire farm")
	check(farm.save_game(SAVE), "scheduled timers save")
	var snapshot: Array = farm.plots.duplicate(true)
	check(farm.load_game(SAVE), "scheduled farm reloads")
	for index in range(snapshot.size()):
		check(is_equal_approx(farm.plots[index].pest_delay, snapshot[index].pest_delay) and is_equal_approx(farm.plots[index].plant_age, snapshot[index].plant_age) and is_equal_approx(farm.plots[index].ripe_age, snapshot[index].ripe_age), "reload preserves every deadline")
	var legacy: Dictionary = farm._save_data().duplicate(true)
	legacy.mechanics_revision = 14
	for field in legacy.island_plots.values():
		for plot in field:
			plot.erase("plant_age")
			plot.erase("pest_delay")
	legacy.plots = legacy.island_plots["1"]
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(farm.load_game(SAVE), "previous saves migrate without losing crops")
	check(farm.plots[0].plant_age == 0 and farm.plots[0].pest_delay == 0, "legacy crop gets a fresh timer rather than instant infestation")
	var invalid: Dictionary = farm._save_data().duplicate(true)
	invalid.island_plots["1"][0].pest_delay = -1
	check(not farm._valid_save(invalid), "negative pest deadlines are rejected")
	farm.reset_game()
	farm.farm_help.data.enabled = false
	var p: Dictionary = farm.plots[0]
	p.stage = 3; p.pest_delay = 15.0
	farm.update(39.99)
	check(not p.pests, "40-second minimum protects younger crops")
	farm.update(0.01)
	check(p.pests, "pests can appear after both age and ready timer pass")
	farm.interact_plot(0, "pest")
	check(not p.pests and p.pest_delay == 0, "spraying grants a fresh independently drawn countdown")
	farm.update(0.01)
	check(p.pest_delay >= 15 and p.pest_delay <= 90, "sprayed bed receives a new random timer")
	farm._clear_crop(p)
	check(p.plant_age == 0 and p.pest_delay == 0, "harvesting resets the crop schedule")
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	await process_frame
	print("PEST SCHEDULE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
