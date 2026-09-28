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
	state.notified.connect(func(message: String): notices.append(message))
	check(not state.tutorial_active and not state.tutorial_progress.completed, "new farm waits for scene controller to start tutorial")
	state._infest_random_plots()
	state.set_tutorial_active(true)
	check(state.tutorial_active, "controller can enable tutorial")
	check(state.pest_timer >= 25.0 and state.pest_timer <= 100.0, "tutorial has fresh background countdowns")
	for crop in State.CROP_IDS:
		check(state.market[crop].sell == State.CROPS[crop].base, crop + " market and chart return to calm baseline")
	var pest_wait: float = state.pest_timer
	notices.clear()
	state.update(600.0)
	check(state.plots[2].stage == 3 and state.plots[3].stage == 3, "watered starter crops still ripen during lesson")
	check(state.plots[0].stage == 3 and not state.plots[0].pests and state.plots[0].ripe_age == 0.0, "unharvested ripe potatoes stay safe throughout a long lesson")
	check(state.pest_timer == pest_wait, "background clocks do not approach an ambush")
	check(notices.is_empty(), "long tutorial wait has no market or pest announcements")
	check(state._infest_random_plots() == 0, "direct random infestation cannot bypass lesson safety")
	state._refresh_market()
	state.interact_plot(5, "hoe")
	state.interact_plot(5, "plant")
	state.interact_plot(5, "water")
	state.update(float(state.CROPS.russet.grow))
	check(state.plots[5].stage == 3, "hoe, plant, water and real crop growth remain playable")
	check(not state.spawn_tutorial_pest(-1) and not state.spawn_tutorial_pest(24) and not state.spawn_tutorial_pest(6), "lesson pest rejects invalid, locked and empty patches")
	check(state.spawn_tutorial_pest(5) and state.plots[5].pests, "controller can introduce the single demonstration pest")
	check(state.spawn_tutorial_pest(0) and not state.plots[5].pests and state.plots[0].pests, "repeated introduction never multiplies lesson pests")
	state.spawn_tutorial_pest(5)
	var activities = Activities.new()
	activities.setup(state)
	root.add_child(activities)
	state.activity_system = activities
	activities.duck_level = 1
	state.update(3600.0)
	state._pest_damage_tick(state.plots[5])
	check(state.plots[5].stage == 3 and state.plots[5].pests and state.plots[5].pest_ticks == 0 and state.plots[5].pest_damage == 0.0, "lesson pest never damages crop or vanishes to automatic ducks")
	state.interact_plot(5, "pest")
	check(not state.plots[5].pests, "manual sprayer removes the demonstration pest")
	state.interact_plot(5, "harvest")
	check(state.storage_used() > 0 and state.plots[5].stage == 0, "lesson harvest reaches inventory")
	var old_coins: float = state.coins
	state.sell_crop("russet")
	check(state.coins > old_coins, "lesson potatoes sell for genuine money")
	var old_seeds: int = state.seed_inventory.russet
	state.buy_seeds("russet", 1)
	check(state.seed_inventory.russet == old_seeds + 1, "lesson seed purchase is a normal transaction")
	# Timers at zero used to be dangerous if a frozen timer entered the event loop.
	state.pest_timer = 0.0
	var before: int = Time.get_ticks_msec()
	state.update(3600.0)
	check(Time.get_ticks_msec() - before < 1000, "frozen expired timers cannot create a million-iteration update stall")
	state.set_tutorial_active(false)
	state.rng.seed = 0
	check(not state.tutorial_active and state.pest_timer >= 25.0, "finishing restarts full surge and safe pest/event countdowns")
	check(state.plots[0].ripe_age == 0.0 and not state.plots[0].pests, "lesson duration never carries into ripe pest age")
	check(not state.spawn_tutorial_pest(0), "demo infestation cannot be used in ordinary play")
	state.update(24.0)
	check(not state.plots[0].pests, "full ripe-crop grace period follows completion")
	state.update(maxf(40.0 - float(state.plots[0].plant_age), float(state.plots[0].pest_delay) - float(state.plots[0].ripe_age)) + 0.01)
	check(state.plots[0].pests, "ordinary ripe-crop pests resume after their actual grace period")
	state.set_tutorial_active(true)
	state.tutorial_progress = {"version": 2, "step": 6, "completed": false, "plot": 5, "visited": ["market"]}
	var path: String = "user://tutorial_state_test_%d.json" % OS.get_process_id()
	check(state.save_game(path), "active lesson progress saves successfully")
	var restored = State.new()
	root.add_child(restored)
	check(restored.load_game(path), "active lesson save reloads")
	check(restored.tutorial_progress == state.tutorial_progress and not restored.tutorial_active, "progress persists while scene retains control of transient active flag")
	restored.set_tutorial_active(true)
	check(restored.tutorial_active, "resumed lesson re-enters calm mode")
	var data: Dictionary = state._save_data()
	for invalid in [{}, {"version": 2, "step": -1, "completed": false, "plot": 5}, {"version": 2, "step": 2, "completed": "false", "plot": 5}, {"version": 2, "step": 2, "completed": false, "plot": 99}]:
		data["tutorial_progress"] = invalid
		check(not state._valid_save(data), "malformed lesson state is rejected")
	restored.reset_game()
	check(not restored.tutorial_active and not restored.tutorial_progress.completed and restored.tutorial_progress.step == 0 and restored.tutorial_progress.plot == 5, "fresh start resets saved lesson independently of main controller")
	check(restored._valid_save(restored._save_data()), "reset farm remains a valid save")
	# Repeat tours pause an established farm instead of cleansing pests or
	# farming free crops while stock and decay clocks stand still.
	restored.coins = 1.0e12
	restored.harvested_total = 100000
	restored._infest_random_plots()
	restored._refresh_market()
	restored.tutorial_progress = {"version": 2, "step": 14, "completed": false, "plot": 5, "tour_only": true, "pest_plot": 1}
	var replay_before: Dictionary = restored._save_data().duplicate(true)
	restored.set_tutorial_active(true)
	check(restored._save_data() == replay_before, "replay entry preserves all active quotes, timers, crops, frost and infestations")
	restored.update(3600.0)
	check(restored._save_data() == replay_before, "replay freezes growth and elapsed time as well as hazards")
	check(not restored.spawn_tutorial_pest(0) and restored._save_data() == replay_before, "replay cannot replace existing pests with a harmless practice pest")
	check(restored.save_game(path), "informational replay saves with original hazards intact")
	var replay = State.new()
	root.add_child(replay)
	check(replay.load_game(path), "informational replay save is valid")
	check(bool(replay.tutorial_progress.get("tour_only", false)) and int(replay.tutorial_progress.get("pest_plot", -1)) == 1, "tour_only and pest_plot both survive save validation and loading")
	var loaded_before: Dictionary = replay._save_data().duplicate(true)
	replay.set_tutorial_active(true)
	replay.update(1000.0)
	replay.set_tutorial_active(false)
	check(replay._save_data() == loaded_before, "resumed informational replay preserves saved timers and hazards through exit")
	restored.set_tutorial_active(false)
	check(restored._save_data() == replay_before, "replay exit does not cleanse pests, reset clocks, or cancel buffs")
	var initial_time: float = replay.elapsed
	replay.update(0.1)
	check(is_equal_approx(replay.elapsed, initial_time + 0.1), "original active surge resumes rather than restarting after replay")
	replay.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	activities.free()
	state.free()
	restored.free()
	print("Tutorial state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
