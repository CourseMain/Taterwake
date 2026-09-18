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
	check(farm.CROPS.size() == 6 and farm.available_crops().size() == 4 and farm.coins == 240.0, "four crop economy starts with earned-currency budget")
	farm.interact_plot(4, "hoe")
	check(farm.plots[4].tilled and farm.seed_inventory.russet == 12, "hoe is a separate manual action")
	farm.interact_plot(4, "plant")
	check(farm.seed_inventory.russet == 11 and farm.plots[4].stage == 1, "manual planting consumes a seed")
	farm.update(12.0)
	check(farm.plots[4].elapsed == 0.0 and farm.plots[4].stage == 1, "dry crop does not grow with time")
	farm.interact_plot(4, "water")
	farm.update(9.0)
	check(farm.plots[4].stage == 2, "watered crop takes its full growth time")
	farm.update(1.01)
	check(farm.plots[4].stage == 3, "watered Russet ripens after ten seconds")
	farm.interact_plot(4, "harvest")
	check(farm.storage.russet == 3 and farm.plots[4].stage == 0, "harvest goes to storage, not automatic sales")
	var coins: float = farm.coins
	var held: int = farm.storage.russet
	farm.update(15.0)
	check(farm.storage.russet == held and farm.coins == coins, "holding inventory never sells or generates passive income")
	check(farm.market.russet.history.size() > 5 and farm.market.russet.seed != 12.0, "crop and seed prices move continuously")
	var price: float = farm.market.russet.sell
	farm.sell_crop("russet")
	check(is_equal_approx(farm.coins, coins + held * price) and farm.storage.russet == 0, "selling uses the live quote")
	coins = farm.coins
	price = farm.market.russet.seed
	var seeds: int = farm.seed_inventory.russet
	farm.buy_seeds("russet", 5)
	check(is_equal_approx(farm.coins, coins - 5 * price) and farm.seed_inventory.russet == seeds + 5, "seed bundle charges dynamic seed cost")
	farm.coins = 0.0
	seeds = farm.seed_inventory.golden
	farm.buy_seeds("golden", 5)
	farm.upgrade_tool("water")
	farm.roll("all_in")
	check(farm.coins == 0.0 and farm.seed_inventory.golden == seeds and farm.tools.water == 0, "insufficient balances cannot buy, upgrade or roll")
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
	check(farm.combo_count == 6 and farm.combo_multiplier == 16, "manual row harvest builds a capped x16 chain")
	# The first four beds yield 45; mastery adds 0.96 to each of the two
	# x16 harvests. Those fractions now combine into one extra potato.
	check(farm.storage.russet == 142 and is_equal_approx(farm.harvest_fraction.russet, 0.92), "combo x1 x2 x4 x8 x16 x16 retains small mastery yield bonuses")
	farm.update(3.51)
	check(farm.combo_count == 0 and farm.combo_multiplier == 1, "combo bonus expires in real time")
	farm.reset_game()
	farm.storage.russet = 199
	ready_crop(0)
	farm.interact_plot(0, "harvest")
	check(farm.storage_used() == 200 and farm.plots[0].pending == 2, "full barn preserves uncollected crop on the plant")
	var combo: int = farm.combo_count
	farm.sell_crop("russet", 5)
	farm.interact_plot(0, "harvest")
	check(farm.combo_count == combo and farm.plots[0].stage == 0 and farm.storage.russet == 197, "remaining harvest cannot multiply its bonus a second time")
	farm.reset_game()
	for crop in farm.available_crops():
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
	farm._start_event("shortage")
	check(farm.event_strength >= 1.5 and farm.event_strength <= 3.0 and is_equal_approx(farm.market.russet.sell, 38.0 * farm.event_strength), "shortage creates a randomized visible buying spike")
	farm.update(5.01)
	check(farm.current_event == "" and farm.event_remaining == 0.0, "price spike fully expires within five seconds")
	check(is_equal_approx(farm.market.russet.sell, farm._market_core.russet.sell), "temporary spike returns to ordinary underlying quote")
	farm.reset_game()
	price = farm.market.russet.seed
	farm._start_event("crash")
	check(is_equal_approx(farm.market.russet.seed, price * farm.event_strength) and is_equal_approx(farm.market.russet.sell, 38.0 * farm.event_strength), "crash discounts linked seeds as well as crops")
	farm._end_event()
	farm._start_event("seed_panic")
	check(is_equal_approx(farm.market.russet.seed, price * farm.event_strength) and farm.market.russet.sell == 38.0, "seed panic briefly adds a seed-only premium")
	farm._end_event()
	farm._start_event("golden_craze")
	check(is_equal_approx(farm.market.golden.sell, 900.0 * farm.event_strength) and is_equal_approx(farm.market.russet.sell, 38.0), "Golden craze targets only Golden crops")
	farm._end_event()
	farm._start_event("chaos")
	check(farm.event_remaining > 0.0 and farm.event_remaining <= 5.0, "chaos quote burst lasts about five seconds")
	var event_words: Dictionary = {"shortage": "shortage", "crash": "crashes", "golden_craze": "golden", "seed_panic": "seed", "chaos": "normal", "mystery_buyer": "mystery", "supply_collapse": "collapsed", "seed_fair": "seed fair", "festival": "festival"}
	for event_id in farm.EVENT_IDS:
		farm._start_event(event_id)
		check(farm.news.to_lower().contains(event_words[event_id]) and farm.event_remaining > 0.0 and farm.event_remaining <= 5.0, "varied event announcement and brief timer: " + event_id)
		farm._end_event()
	farm.reset_game()
	farm.storage.russet = 1
	farm._try_mutation("russet", true)
	check(farm.mutations.size() == 1 and farm.dex.size() == 1 and farm.storage_used() == 1, "mutation replaces a crop without exceeding barn capacity")
	check(farm.barn_value() > 38.0, "mutation storage values its multiplier at the live price")
	coins = farm.coins
	price = farm.barn_value()
	farm.sell_mutations()
	check(farm.mutations.is_empty() and farm.dex.size() == 1 and is_equal_approx(farm.coins, coins + price), "rare sale pays correctly and keeps discovery")
	farm.mastery.russet = 100
	check(farm.mastery_level("russet") == 2 and farm.mutation_chance("russet") > 1.0 / 2500.0, "mastery grows from farming and improves mutation chances")
	var odds: float = 0.0
	for entry in farm.roll_odds(): odds += float(entry.chance)
	check(is_equal_approx(odds, 100.0), "eight disjoint roll tiers total one hundred percent")
	for tier in ["common", "rare", "epic", "legendary", "mythic", "jackpot"]:
		var result: Dictionary = farm._grant_roll_reward(tier, 200.0)
		check(result.tier == tier and not str(result.detail).is_empty(), "implemented reward outcome: " + tier)
	farm.reset_game()
	farm.coins = 199.0
	farm.roll("all_in")
	check(farm.roll_count == 0 and farm.coins == 199.0, "All-in has a real minimum stake")
	farm.coins = 2000.0
	farm.roll("all_in")
	check(farm.roll_count == 1 and farm.coins >= 0.0, "All-in resolves without negative balance")
	farm.reset_game()
	farm.interact_plot(4, "hoe")
	farm.interact_plot(4, "plant")
	farm.interact_plot(4, "water")
	farm.update(4.0)
	farm._start_event("shortage")
	farm.coins = 8.4e71
	check(farm.money(farm.coins) == "$8.4e71" and farm.money(4200000.0) == "$4.2M", "large balances use magnitude suffixes and scientific notation")
	check(farm.save_game(SAVE), "valid farm saves atomically")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	farm.reset_game()
	check(farm.load_game(SAVE), "valid farm reloads")
	check(is_equal_approx(farm.coins, 8.4e71) and is_equal_approx(farm.plots[4].elapsed, 4.0) and farm.current_event == "shortage", "saving preserves huge coins, exact growth and active events")
	var snapshot: float = farm.elapsed
	check(farm.elapsed == snapshot, "load does not add offline growth")
	for key in ["coins", "selected_crop", "capacity", "tools", "market", "plots", "schema_version"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.erase(key)
		write_save(bad)
		check(not farm.load_game(SAVE) and farm.coins == 8.4e71, "missing " + key + " is rejected without mutating farm")
	var bad: Dictionary = saved.duplicate(true)
	bad.coins = -1
	write_save(bad)
	check(not farm.load_game(SAVE), "negative balance rejected")
	bad = saved.duplicate(true)
	bad.schema_version = 1
	write_save(bad)
	check(not farm.load_game(SAVE), "incompatible save schema rejected")
	bad = saved.duplicate(true)
	bad.plots[4].crop = "invalid"
	write_save(bad)
	check(not farm.load_game(SAVE), "unknown crop rejected")
	bad = saved.duplicate(true)
	bad.storage.russet = 99999
	write_save(bad)
	check(not farm.load_game(SAVE), "overfull barn rejected")
	farm.reset_game()
	farm._market_core.russet.sell = farm.CROPS.russet.base * 3.0
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
