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
	check(inventory_tools == 0, "main inventory excludes every tool")
	check(farm.tracked_seed_ids().size() == 4, "starter price tracking defaults to four available seeds")
	farm.set_tracked_seed("golden", false)
	farm.set_tracked_seed("giant", false)
	farm.set_tracked_seed("radioactive", false)
	check(farm.tracked_seed_ids() == ["russet"], "tracking preferences can show exactly one chosen seed")
	check(not farm.set_tracked_seed("invalid", true) and not farm.set_tracked_seed("icecap", true), "invalid and locked tracking choices are rejected")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.tracked_seed_ids() == ["russet"], "tracked seed choices survive persistence")
	farm.set_tracked_seed("russet", false)
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.tracked_seed_ids().is_empty(), "player may hide all tracked seed prices")
	clean_farm()
	var quote: float = farm.market.russet.sell
	farm.update(2.999)
	check(farm.market.russet.sell == quote, "Island 1 does not quote early")
	farm.update(0.001)
	check(farm.market.russet.sell != quote and farm.market_tick_seconds() == 3.0, "Island 1 quotes every three seconds")
	var up: int = 0
	var down: int = 0
	farm.rng.seed = 93939
	for _tick in range(2000):
		# The underlying walk continues while temporary stock quotes are pinned.
		quote = farm._market_core.russet.sell
		farm._market_tick()
		if farm._market_core.russet.sell > quote: up += 1
		elif farm._market_core.russet.sell < quote: down += 1
	check(up > down and down > 500, "starter market has more upward ticks while retaining substantial downward movement")
	clean_farm()
	farm.select_crop("golden")
	farm.update(179.999)
	check(farm.surge_remaining == 0.0 and farm.surge_timer < 0.01, "guaranteed surge never starts before three minutes")
	farm.update(0.001)
	check(farm.surge_remaining == 10.0 and farm.surge_timer == 180.0 and farm.surge_crop == "golden", "three-minute boundary starts a ten-second surge in selected crop")
	check(farm.market.golden.change >= 500.0 and farm.market.golden.change <= 2999.0, "guaranteed final quote is within plus five-hundred to 2999 percent")
	quote = farm.market.golden.sell
	farm._start_event("crash")
	farm.boost_remaining = 5.0
	farm.boost_factor = 3.0
	farm._refresh_market()
	check(farm.market.golden.sell == quote, "stacked crash and roll effects cannot reduce or compound guaranteed surge")
	check(is_equal_approx(farm.market.golden.seed, quote * farm.CROPS.golden.yield * farm.SEED_YIELD_RATIO), "surge seeds stay linked to increased crop value")
	farm.select_crop("russet")
	check(farm.surge_crop == "golden" and farm.market.golden.sell == quote, "changing selected seed cannot transfer or duplicate active surge")
	var saved_ok: bool = farm.save_game(SAVE)
	var loaded_ok: bool = farm.load_game(SAVE)
	check(saved_ok and loaded_ok and farm.surge_remaining == 10.0 and is_equal_approx(farm.market.golden.sell, quote), "active surge and exact countdown persist through save/load")
	farm.update(10.0)
	check(farm.surge_remaining == 0.0 and farm.surge_factor == 1.0 and is_equal_approx(farm.surge_timer, 170.0), "surge ends after ten seconds while next start stays three minutes apart")
	check(farm.market.golden.sell < farm.CROPS.golden.base * 6.0, "surge quote returns to bounded underlying price after expiry")
	farm.update(170.0)
	check(farm.surge_crop == "russet" and farm.surge_remaining == 10.0, "next surge starts exactly three minutes after the previous one")
	farm.coins = 2.0e11
	farm.mastery.russet = 30000
	farm.unlock_island2()
	var timer: float = farm.surge_timer
	farm.travel_to(2)
	check(farm.market_tick_seconds() == 5.0 and farm.surge_timer == timer, "later-island five-second quotes and traveling never reset the surge countdown")
	farm.unlock_island3()
	farm.travel_to(3)
	farm.select_crop("icecap")
	farm.surge_timer = 0.1
	farm.update(0.1)
	check(farm.surge_crop == "icecap" and farm.market.icecap.change >= 3000.0 and farm.market.icecap.change <= 10000.0, "winter selected crop receives its larger bounded guaranteed surge")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "combined winter travel, settings and surge state remains a valid save")
	farm.set_tracked_seed("icecap", true)
	farm.travel_to(1)
	check(not farm.tracked_seed_ids().has("icecap") and farm.tracked_seeds.has("icecap"), "travel hides unavailable tracked crops without deleting their preference")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "off-island tracking preference and active winter surge remain valid")
	farm.travel_to(3)
	check(farm.tracked_seed_ids().has("icecap"), "returning to winter restores the previously selected Icecap ticker")

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
			for key in ["pest_ticks", "pest_elapsed", "pest_destroyed", "yield_total", "yield_taken"]:
				plot.erase(key)
	old_state.island_plots["1"][0].merge({"pests": true, "pest_damage": 0.5, "ripe_age": 11.0, "pending": 6}, true)
	old_state.island_plots["1"][1].merge({"pests": true, "pest_damage": 0.8, "ripe_age": 13.0}, true)
	old_state.plots = old_state.island_plots["1"]
	write_snapshot(old_state)
	check(farm.load_game(SAVE), "revision-three saves with continuous pest damage and partially harvested crops migrate")
	check(farm.coins == 8.4e71 and farm.storage.giant == 1 and farm.mastery.giant == 1 and farm.pest_timer == 37.25 and str(farm.rng.state) == old_state.rng_state, "migration preserves wealth, collected yield, mastery, next outbreak and RNG state")
	check(farm.plots[0].pending == 6 and farm.plots[0].yield_total == 9 and farm.plots[0].pest_ticks == 1 and farm.plots[1].pest_ticks == 2, "migration keeps exact pending potatoes and rounds old damage down to completed thirds")
	check(farm.surge_timer == 180.0 and farm.tracked_seed_ids().size() == 4 and farm.save_game(SAVE) and farm.load_game(SAVE), "migration initializes new preferences and surge timer into a valid repeatable save")
	farm.update(5.0)
	check(farm.plots[0].pending == 3 and farm.plots[0].pest_ticks == 2 and farm.plots[1].pest_destroyed, "migrated pending yields continue decaying without duplicate harvested potatoes")

	clean_farm()
	var safe_state: Dictionary = farm._save_data().duplicate(true)
	var invalid_state: Dictionary = safe_state.duplicate(true)
	invalid_state.tracked_seeds = ["russet", "russet"]
	write_snapshot(invalid_state)
	check(not farm.load_game(SAVE) and farm.tracked_seed_ids().size() == 4, "duplicate tracked settings are rejected without modifying the live farm")
	invalid_state = safe_state.duplicate(true)
	invalid_state.surge_remaining = 5.0
	invalid_state.surge_factor = farm.stock_cap() + 0.01
	write_snapshot(invalid_state)
	check(not farm.load_game(SAVE) and farm.surge_remaining == 0.0, "over-cap saved surges are rejected without activating any price effect")
	invalid_state = safe_state.duplicate(true)
	invalid_state.surge_factor = 8.0
	write_snapshot(invalid_state)
	check(not farm.load_game(SAVE), "expired saves cannot retain a stale surge multiplier")

	var surge_messages: Array[String] = []
	farm.notified.connect(func(message: String) -> void:
		if message.begins_with("STOCK SURGE!"): surge_messages.append(message)
	)
	farm.update(3600.0)
	check(surge_messages.size() == 20 and farm.surge_remaining == 10.0 and farm.surge_timer == 180.0, "one long update produces exactly one surge every three minutes with no overlapping starts")
	var bounded: bool = true
	for id in farm.CROP_IDS:
		bounded = bounded and is_finite(farm.market[id].sell) and farm.market[id].sell > 0.0 and farm.market[id].sell <= farm.CROPS[id].base * farm.stock_cap()
	check(bounded and farm.coins == 240.0 and farm.roll_count == 0, "an hour of overlapping market events keeps finite capped quotes and awards no money or rolls automatically")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	await process_frame
	print("QOL STATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
