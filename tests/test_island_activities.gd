extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Activities = preload("res://scripts/island_activities.gd")
const SAVE: String = "user://spud_island_activities_test_only.json"
var checks: int = 0
var failures: int = 0
var state
var activities

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	state = State.new()
	activities = Activities.new()
	activities.setup(state)
	root.add_child(state)
	root.add_child(activities)
	state.rng.seed = 4092
	check(activities.valid_data(activities.save_data()), "default activity data validates")
	state.coins = state.bankruptcy_limit() + activities.duck_hire_cost() - 1
	activities.buy_duck()
	check(activities.duck_level == 0 and state.coins == state.bankruptcy_limit() + activities.duck_hire_cost() - 1, "unaffordable patrol cannot be hired")
	state.coins = 50000.0
	activities.buy_duck()
	check(activities.duck_level == 1 and state.coins == 49500.0, "first patrol charges exactly the displayed price")
	var plot: Dictionary = state.plots[2]
	plot.stage = 3
	plot.pests = true
	plot.pest_ticks = 1
	plot.pest_damage = 1.0 / 3.0
	plot.pest_elapsed = 0.0
	plot.ripe_age = 28.0
	plot.yield_total = 12
	plot.yield_taken = 2
	plot.pending = 6
	activities.update(3.5)
	check(plot.pests and activities.duck_target == 2, "duck moves toward a pest before clearing it")
	check(activities.info().duck_progress > 0.8, "world receives useful interpolated patrol progress")
	activities.update(0.5)
	check(not plot.pests and activities.duck_clears == 1, "duck clears an infested patch after its travel interval")
	check(plot.pest_ticks == 1 and is_equal_approx(plot.pest_damage, 1.0 / 3.0) and plot.pending == 6 and plot.yield_taken == 2, "duck never restores lost or harvested yield")
	check(plot.ripe_age == 0 and plot.pest_elapsed == 0, "duck restarts the ripe pest grace period")
	activities.buy_duck()
	activities.buy_duck()
	var balance: float = state.coins
	activities.buy_duck()
	check(activities.duck_level == 3 and activities.duck_interval() == 2 and state.coins == balance, "patrol training caps at three paid levels")
	_test_flocks()
	activities.free()
	state.free()
	print("FARM DUCKS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_flocks() -> void:
	state.activity_system = activities
	state.reset_game()
	state.coins = 10000
	for plot in state.plots: state._clear_crop(plot)
	check(activities.duck_count() == 0 and activities.duck_capacity() == 2 and activities.info().ducks.size() == 2, "one flock has two hire slots")
	for index in [3, 8]: _infest(index)
	activities.update(8)
	check(state.plots[3].pests and state.plots[8].pests, "unhired ducks never clear pests")
	activities.hire_duck()
	activities.hire_duck()
	check(state.coins == 8500 and activities.duck_count() == 2, "second duck is a separate purchase")
	activities.hire_duck()
	check(state.coins == 8500 and activities.duck_count() == 2, "third duck is refused without charge")
	state.update(1)
	var flock: Array = activities.info().ducks
	check(flock[0].target != flock[1].target and [3, 8].has(int(flock[0].target)) and [3, 8].has(int(flock[1].target)), "ducks reserve distinct infested targets")
	check(flock[0].elapsed == 1 and flock[1].elapsed == 1, "ducks retain independent patrol clocks")
	var progress: float = flock[0].progress
	activities.train_ducks()
	check(activities.duck_interval() == 3 and is_equal_approx(activities.info().ducks[0].progress, progress), "training preserves fraction of journey travelled")
	var snapshot: Dictionary = activities.save_data()
	check(activities.valid_data(snapshot) and state.save_game(SAVE), "patrols serialize with farm")
	state.reset_game()
	check(activities.duck_count() == 0 and state.load_game(SAVE), "reset clears flock; saved farm reloads")
	check(activities.save_data().duck_patrols == snapshot.duck_patrols and activities.duck_count() == 2, "reload restores routes and ownership exactly")
	state.update(2.25)
	check(not state.plots[3].pests and not state.plots[8].pests and activities.duck_clears == 2, "both ducks clear on the saved arrival boundary")
	state.update(3)
	check(activities.duck_clears == 2, "clean patrols never count a second clear")
	for defect in ["target", "duplicate", "missing", "count", "speed"]:
		var bad: Dictionary = snapshot.duplicate(true)
		match defect:
			"target": bad.duck_patrols[0].target = 24
			"duplicate": bad.duck_patrols[1].target = bad.duck_patrols[0].target
			"missing": bad.duck_patrols.pop_back()
			"count": bad.owned_ducks = 3
			"speed": bad.patrol_speed = -1
		check(not activities.valid_data(bad), "reject corrupt flock " + defect)
	for suffix in ["", ".bak", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)

func _infest(index: int) -> void:
	var plot: Dictionary = state.plots[index]
	plot.merge({"stage": 2, "crop": "radioactive", "watered": true, "tilled": true, "elapsed": 0.0, "pests": true, "pest_elapsed": 0.0, "pest_ticks": 0, "pest_damage": 0.0}, true)
