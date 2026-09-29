extends SceneTree
## Tutorial simulation, save migration, and completion grace periods.
## Uses only disposable saves; the player's farm is never opened.
const State = preload("res://scripts/game_state.gd")
const Activities = preload("res://scripts/island_activities.gd")
var checks: int = 0
var failures: int = 0
var notices: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	state.rng.seed = 70523
	check(not state.tutorial_active and state.tutorial_progress.version == 3, "controller starts the guided year")
	state.set_tutorial_active(true)
	var before: Dictionary = state._save_data().duplicate(true)
	state.update(3600)
	check(state._save_data() == before, "welcome pauses all simulation")
	state.buy_seeds("russet", 1)
	for action: String in ["hoe", "plant", "water"]: state.interact_plot(5, action)
	state.tutorial_progress.step = 5
	state.update(3600)
	check(state.season_clock.season == 1 and is_equal_approx(state.season_clock.seconds, 45), "calendar advances through Spring to Summer warning impact")
	check(state.tutorial_loss().sacks == 2 and state.climate.year_count(1) == 1, "one small scripted disaster")
	check(state.plots[5].stage == 3 and state.ClimateSystem.Protection.remaining(state.plots[5]) == 1, "normal growth survives partial storm loss")
	check(state.ledger.total(1, "seeds") == -270, "seed cost is real")
	state.tutorial_progress.step = 6
	before = state._save_data().duplicate(true)
	state.update(3600)
	check(state._save_data() == before, "cause card pauses clocks")
	var path: String = "user://tutorial-state-%d.json" % OS.get_process_id()
	check(state.save_game(path), "guided Summer saves")
	var restored = State.new(); root.add_child(restored)
	check(restored.load_game(path), "guided Summer loads")
	check(restored.tutorial_progress == state.tutorial_progress and not restored.tutorial_active, "progress restored with controller-owned transient lock")
	restored.set_tutorial_active(true)
	before = restored._save_data().duplicate(true)
	restored.update(3600)
	check(restored._save_data() == before, "resumed cause card cannot double-charge damage")
	restored.interact_plot(5, "harvest")
	restored.tutorial_progress.step = 9
	restored.tutorial_progress.choice = "store"
	restored.update(3600)
	check(restored.season_clock.season == 3 and restored.ledger.is_closed(1), "state alone reaches settled first accounts")
	check(restored.stock_count("russet") == 1 and restored.ledger.total(1, "storage") < 0, "storage keeps crop and charges fee")
	check(restored.climate.year_count(1) == 1, "no second guided disaster")
	check(restored._valid_save(restored._save_data()), "Winter guide state valid before controller completes")
	for invalid in [{}, {"version": 3, "step": -1, "completed": false, "plot": 5}, {"version": 3, "step": 2, "completed": "false", "plot": 5}, {"version": 3, "step": 2, "completed": false, "plot": 99}]:
		var data: Dictionary = state._save_data(); data.tutorial_progress = invalid
		check(not state._valid_save(data), "reject malformed progress")
	# Entry/exit never cleanses a genuine farm or rolls its RNG.
	state.set_tutorial_active(false)
	state.plots[0].pests = true
	state.plots[0].pest_elapsed = 2.0
	before = state._save_data().duplicate(true)
	state.set_tutorial_active(true)
	state.set_tutorial_active(false)
	check(state._save_data() == before, "skip preserves hazards, crop age, money and RNG")
	state.tutorial_progress.tour_only = true
	state.set_tutorial_active(true)
	before = state._save_data().duplicate(true)
	state.update(3600)
	state.set_tutorial_active(false)
	check(state._save_data() == before, "optional tour preserves all farm state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.free(); restored.free()
	print("Tutorial state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
