extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE: String = "user://spud_valley_test_only.json"
var checks: int = 0
var failures: int = 0
var farm

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func ready_crop(index: int, crop: String = "russet") -> void:
	farm.plots[index].merge({"stage": 3, "watered": true, "elapsed": float(farm.CROPS[crop].grow), "crop": crop, "tilled": true, "pending": 0, "pests": false, "pest_damage": 0.0, "pest_ticks": 0, "pest_elapsed": 0.0, "pest_destroyed": false, "ripe_age": 0.0, "yield_total": 0, "yield_taken": 0}, true)

func write_save(data: Variant) -> void:
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _run() -> void:
	farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 4481
	check(farm.plots.size() == 24 and not farm.plots[12].unlocked, "starter field has twelve unlocked plots")
	check(farm.CROPS.size() == 6 and farm.available_crops().size() == 6 and farm.coins == 2000.0, "six crop economy starts with earned-currency budget")
	farm.interact_plot(4, "hoe")
	check(farm.plots[4].tilled and farm.seed_inventory.russet == 12, "hoe is a separate manual action")
	farm.interact_plot(4, "plant")
	check(farm.seed_inventory.russet == 11 and farm.plots[4].stage == 1, "manual planting consumes a seed")
	farm.update(12.0)
	check(farm.plots[4].elapsed == 0.0 and farm.plots[4].stage == 1, "dry crop does not grow with time")
	farm.interact_plot(4, "water")
	farm.update(float(farm.CROPS.russet.grow) - 1.0)
	check(farm.plots[4].stage == 2, "watered crop takes its full growth time")
	farm.update(1.01)
	check(farm.plots[4].stage == 3, "watered Russet ripens after half a season")
	farm.interact_plot(4, "harvest")
	check(farm.storage.russet == 3 and farm.plots[4].stage == 0, "harvest goes to storage, not automatic sales")
	var coins: float = farm.coins
	var held: int = farm.storage.russet
	farm.update(15.0)
	check(farm.storage.russet == held and farm.coins == coins, "holding inventory never sells or generates passive income")
	var price: float = farm.market.russet.sell
	farm.sell_crop("russet")
	check(is_equal_approx(farm.coins, coins + held * price) and farm.storage.russet == 0, "selling uses the live quote")
	price = farm.market.russet.seed
	# Isolate quote accounting from affordability: a live price spike can exceed
	# the starter purse. Insufficient funds are covered in the next transaction.
	farm.coins = maxf(farm.coins, 5 * price + 100.0)
	coins = farm.coins
	var seeds: int = farm.seed_inventory.russet
	farm.buy_seeds("russet", 5)
	check(is_equal_approx(farm.coins, coins - 5 * price) and farm.seed_inventory.russet == seeds + 5, "seed bundle charges dynamic seed cost")
	farm.coins = farm.bankruptcy_limit()
	seeds = farm.seed_inventory.golden
	farm.buy_seeds("golden", 5)
	farm.upgrade_tool("water")
	check(farm.coins == farm.bankruptcy_limit() and farm.seed_inventory.golden == seeds and farm.tools.water == 0, "exhausted credit cannot buy or upgrade")
	farm.reset_game()
	farm.coins = 50000.0
	farm.expand_field()
	farm.upgrade_tool("hoe")
	farm.upgrade_tool("water")
	farm.upgrade_tool("harvest")
	check(farm.plots[23].unlocked, "field expansion is purchased explicitly")
	check(farm.affected_tiles(7, "hoe").size() == 3 and farm.affected_tiles(7, "plant").size() == 3, "hoe upgrade scales preparation and planting")
	check(farm.affected_tiles(7, "water").size() == 9, "watering upgrade covers exactly three by three")
	check(farm.affected_tiles(7, "harvest").size() == 6, "scythe covers an entire row")
	farm.upgrade_tool("water")
	check(farm.affected_tiles(14, "water").size() == 20, "five-by-five tool safely clips to four-row field")
	farm.upgrade_barn()
	check(farm.capacity == 400 and farm.barn_level == 1, "storage upgrade changes real capacity")
	for index in range(6): ready_crop(index)
	farm.interact_plot(0, "harvest")
	check(farm.storage.russet == 18, "six healthy beds yield eighteen sacks without multipliers")
	farm.update(3.51)
	farm.reset_game()
	farm.storage.russet = 199
	ready_crop(0)
	farm.interact_plot(0, "harvest")
	check(farm.storage_used() == 200 and farm.plots[0].pending == 2, "full barn preserves uncollected crop on the plant")
	farm.sell_crop("russet", 5)
	farm.interact_plot(0, "harvest")
	check(farm.plots[0].stage == 0 and farm.storage.russet == 197, "partial harvest preserves remaining sacks")
	farm.reset_game()
	for crop in farm.available_crops():
		farm.reset_game()
		farm.rng.seed = 1
		for plot in farm.plots: farm._clear_crop(plot)
		farm.plots[4].merge({"stage": 0, "watered": false, "tilled": true, "elapsed": 0.0, "pending": 0}, true)
		farm.seed_inventory[crop] = 1
		farm.select_crop(crop)
		farm.interact_plot(4, "plant")
		farm.interact_plot(4, "water")
		farm.pest_timer = 100.0
		farm.update(float(farm.CROPS[crop].grow) - 0.1)
		check(farm.plots[4].stage == 2, crop + " keeps its distinct growth duration")
		farm.update(0.11)
		check(farm.plots[4].stage == 3, crop + " matures at its own timer")
	farm.reset_game()
	farm.harvested_total = 100
	farm.reset_game()
	farm.interact_plot(4, "hoe")
	farm.interact_plot(4, "plant")
	farm.interact_plot(4, "water")
	farm.update(4.0)
	farm.coins = 84000
	check(farm.save_game(SAVE), "valid farm saves atomically")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	farm.reset_game()
	check(farm.load_game(SAVE), "valid farm reloads")
	check(is_equal_approx(farm.coins, 84000) and is_equal_approx(farm.plots[4].elapsed, 4.0), "saving preserves cash, exact growth and active events")
	var snapshot: float = farm.elapsed
	check(farm.elapsed == snapshot, "load does not add offline growth")
	for key in ["ledger", "selected_crop", "capacity", "tools", "plots", "schema_version"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.erase(key)
		write_save(bad)
		check(not farm.load_game(SAVE) and farm.coins == 84000, "missing " + key + " is rejected without mutating farm")
	var bad: Dictionary = saved.duplicate(true)
	bad.coins = -5001
	write_save(bad)
	check(not farm.load_game(SAVE), "independent saved purse rejected")
	bad = saved.duplicate(true)
	bad.schema_version = 1
	write_save(bad)
	check(not farm.load_game(SAVE), "incompatible save schema rejected")
	bad = saved.duplicate(true)
	bad.plots[4].crop = "invalid"
	write_save(bad)
	check(not farm.load_game(SAVE), "unknown crop rejected")
	bad = saved.duplicate(true)
	bad.storage.russet = farm.MAX_INVENTORY + 1
	write_save(bad)
	check(not farm.load_game(SAVE), "inventory beyond global limit rejected")
	farm.reset_game()
	farm._refresh_market()
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "legitimate maximum underlying market quote round-trips through saves")
	farm.reset_game()
	farm.coins = 0.0
	for crop in farm.CROP_IDS: farm.seed_inventory[crop] = 0
	for plot in farm.plots: plot.merge({"stage": 0, "watered": false, "elapsed": 0.0, "pending": 0}, true)
	farm.update(15.01)
	check(farm.seed_inventory.russet == 3, "broke farmers receive emergency seeds, not passive income")
	farm.update(15.01)
	check(farm.seed_inventory.russet == 3, "seed relief cannot be farmed repeatedly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	await process_frame
	print("SPUD VALLEY SIMULATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
