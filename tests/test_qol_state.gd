extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE = "user://spud_valley_qol_test_only.json"
var checks: int = 0
var failures: int = 0
var farm

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func clean_farm() -> void:
	farm.reset_game()
	farm.rng.seed = 61622
	farm.pest_timer = 100.0
	for plot in farm.plots:
		farm._clear_crop(plot)

func ready_crop(index: int, crop: String = "russet") -> void:
	farm._clear_crop(farm.plots[index])
	farm.plots[index].merge({"stage": 3, "watered": true, "elapsed": float(farm.CROPS[crop].grow), "crop": crop, "tilled": true}, true)

func write_snapshot(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	farm = State.new()
	root.add_child(farm)
	clean_farm()
	ready_crop(0)
	farm.plots[0].pests = true
	farm.update(4.999)
	check(farm.plots[0].pest_ticks == 0 and farm.plots[0].pest_damage == 0.0, "no damage before first five-second boundary")
	farm.update(0.001)
	check(farm.plots[0].pest_ticks == 1 and is_equal_approx(farm.plots[0].pest_damage, 1.0 / 3.0), "five seconds leaves two-thirds of original yield")
	farm.update(4.999)
	check(farm.plots[0].pest_ticks == 1, "no continuous damage between ticks")
	farm.update(0.001)
	check(farm.plots[0].pest_ticks == 2 and is_equal_approx(farm.plots[0].pest_damage, 2.0 / 3.0), "ten seconds leaves one-third of original yield")
	farm.update(5.0)
	check(farm.plots[0].stage == 0 and farm.plots[0].pest_ticks == 3 and farm.plots[0].pest_destroyed and not farm.plots[0].pests, "fifteen seconds destroys the crop with a visible marker")
	farm.interact_plot(0, "harvest")
	check(farm.storage.russet == 0 and farm.mastery.russet == 0, "destroyed crops give zero potatoes and mastery")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.plots[0].pest_destroyed, "destroyed-crop marker survives save and load")
	farm.interact_plot(0, "plant")
	check(farm.plots[0].stage == 1 and farm.plots[0].pest_ticks == 0 and not farm.plots[0].pest_destroyed, "replanting clears all previous pest damage")
	for ticks in [0, 1, 2]:
		clean_farm()
		ready_crop(0)
		farm.plots[0].pests = true
		farm.update(float(ticks) * 5.0)
		farm.interact_plot(0, "harvest")
		check(farm.mastery.russet == 3 - ticks, "harvest correctly pays remaining thirds at tick %d" % ticks)
	clean_farm()
	ready_crop(0, "giant")
	farm.storage.russet = 199
	farm.interact_plot(0, "harvest")
	check(farm.plots[0].yield_total == 8 and farm.plots[0].yield_taken == 1 and farm.plots[0].pending == 7, "partial harvest captures original maximum yield")
	farm.plots[0].pests = true
	farm.update(5.0)
	check(farm.plots[0].pending == 4, "damage removes a third of original eight rather than a third of remaining seven")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.plots[0].pending == 4, "partial harvested pest damage persists without resetting original total")
	farm.update(5.0)
	check(farm.plots[0].pending == 1, "second tick applies two-thirds loss against original yield and subtracts potatoes already harvested")
	farm.update(5.0)
	check(farm.plots[0].stage == 0 and farm.plots[0].pending == 0 and farm.mastery.giant == 1, "third tick destroys pending leftovers without negative inventory")
	clean_farm()
	ready_crop(0)
	farm.plots[0].pests = true
	farm.update(5.0)
	farm.interact_plot(0, "pest")
	farm.update(20.0)
	check(not farm.plots[0].pests and farm.plots[0].pest_ticks == 1, "brush stops damage but cannot restore lost yield")
	farm.interact_plot(0, "harvest")
	check(farm.mastery.russet == 2, "brushing preserves exactly the remaining two potatoes")
	clean_farm()
	ready_crop(0)
	farm.plots[0].pests = true
	farm.update(15.0)
	check(farm.plots[0].stage == 0, "one long frame processes all three damage ticks")
	clean_farm()
	farm.interact_plot(4)
	farm.interact_plot(4)
	check(farm.plots[4].stage == 0 and farm.seed_inventory.russet == 12, "repeated default action stays Hoe and never auto-plants")
	var inventory_tools: int = 0
	for entry in farm.inventory_info():
		if entry.kind == "tool": inventory_tools += 1
	check(inventory_tools == 5, "inventory includes all five usable farming tools")

	clean_farm()
	ready_crop(0)
	farm.plots[0].pests = true
	farm.update(4.25)
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and is_equal_approx(farm.plots[0].pest_elapsed, 4.25), "saving an infestation retains its fractional damage timer")
	farm.update(0.749)
	check(farm.plots[0].pest_ticks == 0, "loading does not round a pest timer up into early damage")
	farm.update(0.001)
	check(farm.plots[0].pest_ticks == 1, "loading cannot restart or delay the next pest damage tick")

	clean_farm()
	ready_crop(0, "giant")
	ready_crop(1)
	farm.storage.giant = 1
	farm.mastery.giant = 1
	farm.coins = 8.4e71
	farm.pest_timer = 37.25
	var old_state: Dictionary = farm._save_data().duplicate(true)
	old_state.mechanics_revision = 3
	old_state.market_clock = 4.25
	for key in ["tracked_seeds", "surge_timer", "surge_remaining", "surge_crop", "surge_factor"]:
		old_state.erase(key)
	for field in old_state.island_plots.values():
		for plot in field:
			# Revision 3 used the original growth durations. A current ripe Giant
			# at 40s is not a valid ripe crop in that old 45s save format.
			if int(plot.stage) == 3: plot.elapsed = float(farm.OLD_GROW_TIMES[plot.crop])
			for key in ["pest_ticks", "pest_elapsed", "pest_destroyed", "yield_total", "yield_taken"]:
				plot.erase(key)
	old_state.island_plots["1"][0].merge({"pests": true, "pest_damage": 0.5, "ripe_age": 11.0, "pending": 6}, true)
	old_state.island_plots["1"][1].merge({"pests": true, "pest_damage": 0.8, "ripe_age": 13.0}, true)
	old_state.plots = old_state.island_plots["1"]
	write_snapshot(old_state)
	check(farm.load_game(SAVE), "revision-three saves with continuous pest damage and partially harvested crops migrate")
	check(farm.coins == 8.4e71 and farm.storage.giant == 1 and farm.mastery.giant == 1 and farm.pest_timer == 37.25 and str(farm.rng.state) == old_state.rng_state, "migration preserves wealth, collected yield, mastery, next outbreak and RNG state")
	check(farm.plots[0].pending == 6 and farm.plots[0].yield_total == 9 and farm.plots[0].pest_ticks == 1 and farm.plots[1].pest_ticks == 2, "migration keeps exact pending potatoes and rounds old damage down to completed thirds")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "migration initializes new preferences and surge timer into a valid repeatable save")
	farm.update(5.0)
	check(farm.plots[0].pending == 3 and farm.plots[0].pest_ticks == 2 and farm.plots[1].pest_destroyed, "migrated pending yields continue decaying without duplicate harvested potatoes")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	await process_frame
	print("QOL STATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
