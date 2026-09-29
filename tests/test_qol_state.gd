extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
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

	for plot in farm.plots:
		farm._clear_crop(plot)

func ready_crop(index: int, crop: String = "russet") -> void:
	farm._clear_crop(farm.plots[index])
	farm.plots[index].merge({"stage": 3, "watered": true, "elapsed": float(farm.CropTable.CROPS[crop].grow), "crop": crop, "tilled": true}, true)

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
	check(Stock.count(farm.storage, "russet") == 0 and farm.harvested_total == 0, "destroyed crops give zero potatoes and mastery")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.plots[0].pest_destroyed, "destroyed-crop marker survives save and load")
	farm.interact_plot(0, "plant")
	check(farm.plots[0].stage == 1 and farm.plots[0].pest_ticks == 0 and not farm.plots[0].pest_destroyed, "replanting clears all previous pest damage")
	for ticks in [0, 1, 2]:
		clean_farm()
		ready_crop(0)
		farm.plots[0].pests = true
		farm.update(float(ticks) * 5.0)
		farm.interact_plot(0, "harvest")
		check(farm.harvested_total == 3 - ticks, "harvest correctly pays remaining thirds at tick %d" % ticks)
	clean_farm()
	ready_crop(0, "giant")
	farm.storage["russet"] = Stock.pile(199)
	farm.interact_plot(0, "harvest")
	check(farm.plots[0].yield_total == 5 and farm.plots[0].yield_taken == 1 and farm.plots[0].pending == 4, "partial harvest captures original maximum yield")
	farm.plots[0].pests = true
	farm.update(5.0)
	check(farm.plots[0].pending == 2, "damage removes a third of original five rather than remaining four")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.plots[0].pending == 2, "partial harvested pest damage persists without resetting original total")
	farm.update(5.0)
	check(farm.plots[0].pending == 0, "second tick applies two-thirds loss against original yield and subtracts potatoes already harvested")
	farm.update(5.0)
	check(farm.plots[0].stage == 0 and farm.plots[0].pending == 0 and farm.harvested_total == 1, "third tick destroys pending leftovers without negative inventory")
	clean_farm()
	ready_crop(0)
	farm.plots[0].pests = true
	farm.update(5.0)
	farm.interact_plot(0, "pest")
	farm.update(20.0)
	check(not farm.plots[0].pests and farm.plots[0].pest_ticks == 1, "brush stops damage but cannot restore lost yield")
	farm.interact_plot(0, "harvest")
	check(farm.harvested_total == 2, "brushing preserves exactly the remaining two potatoes")
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
	farm.storage["giant"] = Stock.pile(1)
	farm.harvested_total = 1
	farm.coins = 3360000

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	await process_frame
	print("QOL STATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
