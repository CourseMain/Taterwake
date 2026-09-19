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
	state.coins = 1499.0
	activities.buy_duck()
	check(activities.duck_level == 0 and state.coins == 1499.0, "unaffordable patrol cannot be hired")
	state.coins = 1000000.0
	activities.buy_duck()
	check(activities.duck_level == 1 and state.coins == 998500.0, "first patrol charges exactly the displayed price")
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
	plot.pests = true
	state.current_island = 2
	activities.update(10)
	check(plot.pests and activities.duck_clears == 1, "unvisited first-island patrol stays paused")
	activities.buy_duck()
	check(state.coins == balance, "fully trained flock cannot be charged again on other islands")
	state.island2_unlocked = true
	state.selected_crop = "sunburst"
	state.market.sunburst.sell = 90000.0
	activities.choose_contract("bulk")
	check(activities.contract.kind == "bulk" and activities.contract.target == 400, "bulk contract asks for a real large harvest")
	check(activities.contract.crop == "sunburst", "buyer targets the player's selected crop")
	activities.choose_contract("mutation")
	check(activities.contract.kind == "bulk", "active order cannot be overwritten to discard committed shipments")
	state.storage.sunburst = 100
	activities.deliver_contract()
	check(state.storage.sunburst == 0 and activities.contract.delivered == 100, "partial shipment removes only delivered ordinary crops")
	check(state.coins == balance and activities.contract.credit == 11250000.0, "partial credit includes25percent bonus without premature cash")
	state.market.sunburst.sell = 180000.0
	state.storage.sunburst = 500
	activities.deliver_contract()
	check(activities.contract.is_empty() and state.storage.sunburst == 200, "completion consumes exact remaining quantity and retains surplus")
	check(is_equal_approx(state.coins - balance, 78750000.0), "each shipment uses its own real quote and pays the accumulated sum once")
	check(is_equal_approx(state.lifetime_sales, 78750000.0) and is_equal_approx(state.island_sales["2"], 78750000.0), "contract earnings count toward actual island sales")
	balance = state.coins
	activities.deliver_contract()
	check(state.coins == balance, "completed order cannot be paid twice")
	activities.choose_contract("mutation")
	check(activities.contract.is_empty(), "buyer cooldown prevents instant repeated contracts")
	activities.update(25.0)
	activities.choose_contract("mutation")
	check(activities.contract.target == 1 and activities.contract.kind == "mutation", "mutation build gets a separate small valuable order")
	state.mutations.clear()
	state.mutations.append({"id": "golden", "crop": "sunburst", "name": "Golden Sunburst Potato", "count": 3, "multiplier": 25.0})
	state.mutations.append({"id": "crystal", "crop": "golden", "name": "Crystal Golden Potato", "count": 2, "multiplier": 75.0})
	activities.deliver_contract()
	check(state.mutations.size() == 2 and state.mutations[0].count == 2 and state.mutations[1].count == 2, "mutation delivery consumes exact matching quantity and preserves unrelated crates")
	check(is_equal_approx(state.coins - balance, 6750000.0), "mutation reward includes live crop quote and actual rarity multiplier plus50percent")
	check(state.storage.sunburst == 200, "mutation delivery never consumes or fabricates ordinary crops")
	state.current_island = 1
	activities.update(25.0)
	activities.choose_contract("bulk")
	check(activities.contract.is_empty(), "buyer contracts only start on Island2")
	state.current_island = 3
	state.island3_unlocked = true
	state.storage.icecap = 24
	activities.charge_furnace()
	check(activities.furnace_remaining == 0 and state.storage.icecap == 24, "insufficient furnace fuel cannot start a burst")
	state.storage.icecap = 100
	state.storage.russet = 100
	activities.charge_furnace("russet")
	check(activities.furnace_remaining == 0 and state.storage.russet == 100, "cheap previous-island crops cannot fuel the winter furnace")
	activities.charge_furnace()
	check(state.storage.icecap == 75 and activities.furnace_remaining == 20, "furnace consumes exactly25 held Icecaps and starts20seconds")
	check(activities.growth_speed_multiplier() == 2.5 and activities.processing_speed_multiplier() == 3.0, "furnace exposes real crop and processing boosts")
	activities.charge_furnace()
	check(state.storage.icecap == 75 and activities.furnace_remaining == 20, "active furnace cannot be stacked or charged twice")
	check(is_equal_approx(activities.processing_time(25), 65.0), "processing integrates only the actual20 boosted seconds across expiry")
	check(activities.next_boundary() <= 20.0, "simulation cannot step across furnace expiration")
	activities.update(10)
	var saved: Dictionary = activities.save_data()
	check(activities.valid_data(saved), "in-flight furnace and patrol data validate")
	activities.reset()
	check(activities.duck_level == 0 and activities.furnace_remaining == 0, "reset clears purchased activities and running boosts")
	check(activities.load_data(saved) and activities.furnace_remaining == 10 and activities.furnace_cooldown == 50 and activities.duck_speeds["1"] == 2 and activities.duck_counts["1"] == 1 and activities.duck_count() == 0, "saved activity state resumes timers and separate island purchases")
	state.current_island = 2
	check(activities.growth_speed_multiplier() == 1 and activities.processing_speed_multiplier() == 1, "winter heat never buffs other islands")
	activities.update(10)
	state.current_island = 3
	check(activities.furnace_remaining == 0 and activities.growth_speed_multiplier() == 1 and activities.furnace_cooldown == 40, "furnace heat expires while traveling without retaining boost")
	activities.charge_furnace()
	check(state.storage.icecap == 75, "furnace cooling period cannot be bypassed after heat expires")
	activities.update(40)
	activities.charge_furnace()
	check(state.storage.icecap == 50 and activities.furnace_remaining == 20, "furnace can fire again after its real cooldown")
	for key in ["duck_level", "furnace_remaining", "contract_completed"]:
		var bad: Dictionary = saved.duplicate(true)
		bad[key] = -1
		check(not activities.valid_data(bad), "invalid negative %s rejected" % key)
	var bad: Dictionary = saved.duplicate(true)
	bad.furnace_remaining = 21
	check(not activities.load_data(bad) and activities.furnace_remaining == 20, "invalid loaded duration leaves the live activity unchanged")
	state.current_island = 2
	activities.contract_cooldown = 0.0
	activities.choose_contract("bulk")
	state.storage.sunburst = 80
	activities.deliver_contract()
	saved = JSON.parse_string(JSON.stringify(activities.save_data()))
	activities.reset()
	check(activities.load_data(saved) and activities.contract.delivered == 80 and activities.contract.credit > 0, "partial contract survives JSON roundtrip with locked credit")
	bad = saved.duplicate(true)
	bad.contract.delivered = 0
	check(not activities.valid_data(bad), "unearned contract credit is rejected")
	bad = saved.duplicate(true)
	bad.contract.credit = INF
	check(not activities.valid_data(bad), "nonfinite contract payout is rejected")
	# Exercise the real state's chronological growth hook and atomic farm save.
	state.activity_system = activities
	state.reset_game()
	state.coins = 10000000000000.0
	state.mastery.russet = 30000
	state.unlock_island2()
	state.unlock_island3()
	state.travel_to(3)
	state.selected_crop = "icecap"
	state.seed_inventory.icecap = 1
	state.storage.icecap = 50
	state.interact_plot(0, "hoe")
	state.interact_plot(0, "plant")
	state.interact_plot(0, "water")
	var distant: Dictionary = state.island_plots["1"][8]
	distant.stage = 2
	distant.tilled = true
	distant.watered = true
	distant.elapsed = 0.0
	distant.crop = "golden"
	activities.charge_furnace()
	check(is_equal_approx(state.crop_grow_time("icecap"), 24.0), "crop's displayed growth time includes the actual furnace multiplier")
	state.update(10.0)
	check(is_equal_approx(state.plots[0].elapsed, 25.0) and activities.furnace_remaining == 10.0, "real state simulation advances crop and furnace on the same clock")
	check(is_equal_approx(distant.elapsed, 10.0), "furnace does not boost unvisited first-island fields")
	check(state.save_game(SAVE), "activities save alongside the real farm")
	state.reset_game()
	check(activities.furnace_remaining == 0 and activities.contract.is_empty(), "farm reset clears activity state through its composition hook")
	check(state.load_game(SAVE), "farm with furnace data reloads successfully")
	check(activities.furnace_remaining == 10 and activities.furnace_cooldown == 50 and state.storage.icecap == 25, "farm loading restores exact consumed fuel and remaining heat without offline progress")
	state.update(10.5)
	check(is_equal_approx(state.plots[0].elapsed, 50.5) and activities.furnace_remaining == 0, "long frame across expiry applies25 boosted growth plus0.5 ordinary growth")
	check(is_equal_approx(state.crop_grow_time("icecap"), 60.0), "growth speed returns to baseline when furnace stops")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	payload.activities.furnace_remaining = 200.0
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	check(not state.load_game(SAVE) and is_equal_approx(state.plots[0].elapsed, 50.5), "corrupt activity data rejects the whole save before replacing the live farm")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_test_flocks()
	activities.free()
	state.free()
	print("ISLAND ACTIVITIES TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_flocks() -> void:
	state.reset_game()
	state.coins = 10000000000000.0
	state.mastery.russet = 30000
	state.unlock_island2()
	state.unlock_island3()
	state.pest_timer = 100.0
	for field in state.island_plots.values():
		for plot in field:
			state._clear_crop(plot)
	for island in [1, 2, 3]:
		state.travel_to(island)
		var data: Dictionary = activities.info()
		check(data.duck_count == 0 and data.duck_capacity == island and data.ducks.size() == island, "island%d starts with empty patrol slots and the correct capacity" % island)
		check(not data.ducks[0].trained, "untrained island%d flock is marked as idle for coop visuals" % island)
	state.travel_to(2)
	for index in [3, 8]:
		_infest(index)
	activities.update(8.0)
	check(state.plots[3].pests and state.plots[8].pests and activities.duck_clears == 0, "idle untrained ducks cannot secretly remove pests")
	var balance: float = state.coins
	activities.hire_duck()
	check(activities.duck_count() == 1 and is_equal_approx(balance - state.coins, 25000000.0), "first Shores duck charges its own island price")
	activities.hire_duck()
	check(activities.duck_count() == 2 and is_equal_approx(balance - state.coins, 75000000.0), "second duck is a separate purchase")
	var full_balance: float = state.coins
	activities.hire_duck()
	check(activities.duck_count() == 2 and state.coins == full_balance, "Shores capacity blocks a third duck without charge")
	state.update(1.0)
	var flock: Array = activities.info().ducks
	check(flock[0].target != flock[1].target and [3, 8].has(int(flock[0].target)) and [3, 8].has(int(flock[1].target)), "two ducks reserve distinct infested targets")
	check(flock[0].elapsed == 1 and flock[1].elapsed == 1, "each island2 duck owns an independent travel clock")
	var shores: Array = activities.duck_patrols["2"].duplicate(true)
	state.travel_to(3)
	for index in [3, 5, 7]:
		_infest(index)
	activities.train_ducks()
	check(activities.duck_count() == 0 and activities.duck_speed() == 0, "cannot train an empty winter flock")
	for _duck: int in range(3):
		activities.hire_duck()
	check(activities.duck_count() == 3 and activities.duck_capacity() == 3, "winter can hire three ducks")
	state.plots[3].pest_ticks = 1
	state.plots[3].pest_damage = 1.0 / 3.0
	state.update(1.0)
	flock = activities.info().ducks
	var targets: Dictionary = {}
	for duck in flock:
		targets[int(duck.target)] = true
	check(targets.size() == 3 and targets.has(3) and targets.has(5) and targets.has(7), "three winter ducks split three simultaneous outbreaks without pileups")
	check(flock[0].target == 3, "available duck prioritizes the crop with existing pest damage")
	check(activities.duck_patrols["2"] == shores, "travel leaves the other island's saved patrol paths and timers unchanged")
	state.update(3.0)
	check(not state.plots[3].pests and not state.plots[5].pests and not state.plots[7].pests, "winter flock clears three different beds on the same arrival boundary")
	check(activities.duck_clears == 3 and activities.info().ducks[0].clears == 1 and activities.info().ducks[1].clears == 1 and activities.info().ducks[2].clears == 1, "each duck records exactly its own successful clear")
	check(state.plots[3].pest_ticks == 1 and is_equal_approx(state.plots[3].pest_damage, 1.0 / 3.0), "multi-duck patrol never heals earlier damage")
	state.travel_to(2)
	check(activities.info().ducks[0].elapsed == 1 and activities.info().ducks[1].elapsed == 1, "returning to an island resumes each duck's saved route")
	state.update(3.0)
	check(not state.plots[3].pests and not state.plots[8].pests and activities.duck_clears == 5, "two shores ducks finish their individual interrupted chases")
	state.update(4.0)
	check(activities.duck_clears == 5, "patrolling already clean beds cannot count or clear an outbreak twice")
	activities.update(1.0)
	var previous_progress: float = activities.info().ducks[0].progress
	state.travel_to(3)
	state.coins = 1e16
	activities.train_ducks()
	check(activities.duck_speed() == 1 and activities.duck_interval() == 3.0 and activities.duck_count() == 3, "speed upgrade improves only winter speed without adding a duck")
	state.travel_to(2)
	check(activities.duck_interval() == 4.0 and is_equal_approx(activities.info().ducks[0].progress, previous_progress), "winter training leaves Shores speed and route progress untouched")
	var snapshot: Dictionary = activities.save_data()
	check(int(snapshot.version) == 3 and snapshot.duck_patrols.size() == 3 and activities.valid_data(snapshot), "version3 save contains ownership, speed and all patrol paths")
	check(state.save_game(SAVE), "multi-island patrols serialize with the farm")
	state.reset_game()
	check(state.load_game(SAVE) and activities.save_data().duck_patrols == snapshot.duck_patrols, "farm reload restores every duck path, clock and clear count")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt.duck_patrols["3"][0].target = 80
	check(not activities.valid_data(corrupt), "out-of-range winter duck targets are rejected")
	corrupt = snapshot.duplicate(true)
	corrupt.duck_patrols["3"][1].target = corrupt.duck_patrols["3"][0].target
	check(not activities.valid_data(corrupt), "saved ducks cannot share a reserved target")
	corrupt = snapshot.duplicate(true)
	corrupt.duck_patrols["3"].pop_back()
	check(not activities.valid_data(corrupt), "save cannot silently drop the third winter duck")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 1
	legacy.erase("duck_patrols")
	legacy.duck_level = 1
	legacy.duck_clears = 9
	legacy.duck_from = 7
	legacy.duck_target = 8
	legacy.duck_elapsed = 1.25
	legacy = JSON.parse_string(JSON.stringify(legacy))
	check(activities.valid_data(legacy) and activities.load_data(legacy), "original version1 singleton saves remain valid and migrate")
	check(activities.duck_level == 1 and activities.duck_clears == 9 and activities.duck_patrols["1"][0]["from"] == 7 and activities.duck_patrols["1"][0].target == 8 and activities.duck_patrols["1"][0].elapsed == 1.25, "migration preserves paid training and the original duck's exact route")
	check(activities.duck_patrols["2"].size() == 2 and activities.duck_patrols["3"].size() == 3 and activities.valid_data(activities.save_data()), "migration adds new island flocks without charging again")
	# The flock rule derives from island numbers rather than a hard-coded list.
	state.island_plots["4"] = state._empty_winter(true)
	state.current_island = 4
	check(activities.info().duck_count == 0 and activities.info().duck_capacity == 4 and activities.info().ducks.size() == 4, "future island4 has four hire slots")
	state.current_island = 2
	state.island_plots.erase("4")

func _infest(index: int) -> void:
	var plot: Dictionary = state.plots[index]
	plot.merge({"stage": 2, "crop": "radioactive", "watered": true, "tilled": true, "elapsed": 0.0, "pests": true, "pest_elapsed": 0.0, "pest_ticks": 0, "pest_damage": 0.0}, true)
