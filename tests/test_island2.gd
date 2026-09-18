extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE: String = "user://spud_shores_test_only.json"
var checks: int = 0
var failures: int = 0
var farm
var warnings_seen: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func enter_shores() -> void:
	farm.coins = State.ISLAND2_UNLOCK_COST
	farm.mastery.russet = State.ISLAND2_UNLOCK_HARVEST
	farm.unlock_island2()
	farm.travel_to(2)

func ready_crop(index: int, crop: String = "russet") -> void:
	farm.plots[index].merge({"stage": 3, "watered": true, "elapsed": float(farm.CROPS[crop].grow), "crop": crop, "tilled": true, "pending": 0, "pests": false, "pest_damage": 0.0, "pest_ticks": 0, "pest_elapsed": 0.0, "pest_destroyed": false, "ripe_age": 0.0, "yield_total": 0, "yield_taken": 0}, true)

func write_save(data: Variant) -> void:
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func mutation_seed(chance: float) -> int:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value in range(1, 100000):
		probe.seed = seed_value
		if probe.randf() < chance:
			return seed_value
	return 1

func legacy_data(schema: int = 3) -> Dictionary:
	var data: Dictionary = farm._save_data().duplicate(true)
	for key in ["economy_revision", "mechanics_revision", "export_cycle_sold", "export_qualified_cycles", "export_factor", "event_strength", "lifetime_sales", "island_sales", "pending_roll_boost", "island3_unlocked", "frost_timer", "frost_active", "frost_cleared", "frost_target_count", "thaw_remaining", "inventory_items"]: data.erase(key)
	for key in ["seed_inventory", "storage", "mastery", "market", "market_core"]: data[key].erase("icecap")
	data.island_plots.erase("3")
	for field in data.island_plots.values():
		for plot in field: plot.erase("frozen")
	data.plots = data.island_plots[str(int(data.current_island))]
	for id in ["winter_ground", "winter_harvest", "winter_frost", "starter_crash", "starter_spike", "starter_combo"]: data.quest_progress.erase(id)
	data.schema_version = schema
	data.export_timer = 25.0 if data.export_active else 75.0
	data.luck = 100.0
	data.market_clock = 2.5
	data.event_in = 45.0
	var old_targets: Dictionary = {"ground": 12.0, "sunburst": 40.0, "combo": 16.0, "export": 1000000.0, "mutation": 1.0}
	for id in old_targets: data.quest_progress[id] = float(old_targets[id]) if data.quest_claimed.has(id) else minf(float(data.quest_progress[id]), float(old_targets[id]))
	if schema == 2:
		for key in ["seed_inventory", "storage", "mastery", "market", "market_core"]: data[key].erase("sunburst")
		for key in ["current_island", "island2_unlocked", "island_plots", "shores_first_mutation", "export_timer", "export_active", "export_cycles", "quest_progress", "quest_claimed", "golden_hat"]: data.erase(key)
	return data

func _run() -> void:
	farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 4481
	farm.notified.connect(func(message: String):
		if message.contains("IN 15 SECONDS"): warnings_seen += 1)
	check(farm.current_island == 1 and farm.field_columns() == 6 and farm.field_rows() == 4, "starter island dimensions preserved")
	check(farm.plots.size() == 24 and farm.island_plots["2"].size() == 48 and not farm.island2_unlocked, "only second island adds a forty-eight-bed field")
	check(farm.CROP_IDS.size() == 6 and farm.available_crops().size() == 4, "Sunburst excluded from first-island market")
	farm.update(100.0)
	check(farm.export_timer == 120.0 and not farm.export_active, "locked islands cannot begin export countdown")
	farm.travel_to(2)
	check(farm.current_island == 1, "locked ferry cannot be bypassed")
	farm.coins = 1000000.0
	farm.mastery.russet = 499
	farm.unlock_island2()
	check(not farm.island2_unlocked and farm.coins == 1000000.0, "ferry needs five hundred potatoes actually harvested")
	farm.mastery.russet = 500
	farm.coins = 999999.0
	farm.unlock_island2()
	check(not farm.island2_unlocked and farm.coins == 999999.0, "second island starts after reaching the million-coin gate")
	farm.coins = 1100000.0
	farm.unlock_island2()
	check(farm.island2_unlocked and farm.coins == 100000.0, "unlock charges one million exactly once")
	farm.unlock_island2()
	check(farm.coins == 100000.0, "repeated unlock does not charge twice")
	check(farm.export_timer >= 75.0 and farm.export_timer <= 180.0, "first export delay is a randomized seventy-five to one-hundred-eighty seconds")
	var old_market: Dictionary = farm.market.duplicate(true)
	var old_field: Array = farm.plots.duplicate(true)
	farm.travel_to(2)
	check(farm.field_columns() == 8 and farm.field_rows() == 6 and farm.plots.size() == 48, "travel switches field geometry")
	check(farm.market == old_market and farm.island_plots["1"] == old_field, "travel never rerolls quotes or discards the old farm")
	farm.travel_to(3)
	check(farm.current_island == 2 and farm.plots[47].unlocked, "all Shores plots available and no third island")
	farm.reset_game()
	enter_shores()
	# This scenario isolates simultaneous growth. Random infestations have
	# separate coverage and must not destroy a crop before its growth check.
	farm.pest_timer = 100.0
	farm.coins = 1000000.0
	var seed_price: float = farm.market.sunburst.seed
	farm.buy_seeds("sunburst", 1)
	check(is_equal_approx(seed_price, 121500.0) and farm.seed_inventory.sunburst == 1 and is_equal_approx(farm.coins, 1000000.0 - seed_price), "Sunburst seeds are meaningfully priced against ninety-thousand crop quotes")
	farm.select_crop("sunburst")
	farm.interact_plot(0, "hoe")
	farm.interact_plot(0, "plant")
	farm.interact_plot(0, "water")
	farm.update(10.0)
	farm.travel_to(1)
	check(farm.selected_crop == "russet", "return travel selects an available crop")
	farm.seed_inventory.sunburst = 1
	farm.buy_seeds("sunburst", 1)
	farm.select_crop("sunburst")
	check(farm.seed_inventory.sunburst == 1 and farm.selected_crop == "russet", "Sunburst purchase and selection stay exclusive to Shores")
	farm.selected_crop = "sunburst"
	farm.plots[4].tilled = true
	farm.interact_plot(4, "plant")
	check(farm.plots[4].stage == 0 and farm.seed_inventory.sunburst == 1, "planting cannot bypass Sunburst island restriction")
	farm.selected_crop = "russet"
	farm.interact_plot(4, "plant")
	farm.interact_plot(4, "water")
	farm.update(10.0)
	check(farm.plots[4].stage == 3 and farm.island_plots["2"][0].elapsed == 20.0, "both farms grow simultaneously in real time")
	farm.travel_to(2)
	farm.update(25.0)
	check(farm.plots[0].stage == 3 and farm.island_plots["1"][4].stage == 3, "both ripe crops await manual harvest")
	farm.tools.hoe = 1
	farm.tools.water = 1
	farm.tools.harvest = 1
	check(farm.affected_tiles(9, "hoe").size() == 3 and farm.affected_tiles(9, "water").size() == 9 and farm.affected_tiles(9, "harvest").size() == 8, "rank-one area tools respect eight-column field")
	farm.tools.hoe = 2
	farm.tools.water = 2
	farm.tools.harvest = 2
	check(farm.affected_tiles(26, "hoe").size() == 9 and farm.affected_tiles(26, "water").size() == 25 and farm.affected_tiles(26, "harvest").size() == 24, "fully upgraded tools scale across the larger field")
	check(farm.affected_tiles(0, "harvest").size() == 16, "scythe clips safely at field edge")
	farm.reset_game()
	enter_shores()
	ready_crop(0, "sunburst")
	farm.interact_plot(0, "harvest")
	check(farm.storage_used() == 6 and farm.mastery.sunburst == 6, "Shores soil doubles base manual harvest yield")
	check(farm.shores_first_mutation and farm.mutations.size() == 1 and farm.mutations[0].id == "golden", "first Sunburst harvest still introduces one guaranteed Golden mutation")
	check(farm.quest_progress.mutation == 1 and not farm.quest_info()[4].complete, "first mutation advances but does not complete the three-mutation quest")
	farm.update(3.51)
	farm.rng.seed = 88
	ready_crop(1, "sunburst")
	farm.interact_plot(1, "harvest")
	check(farm.mutations[0].count == 1, "introductory mutation does not repeat each harvest")
	farm.travel_to(1)
	check(farm.combo_count == 0 and farm.combo_time == 0.0, "travel breaks combo instead of carrying starter harvest into Shores quest")
	var balance: float = farm.coins
	farm.sell_crop("sunburst")
	check(farm.storage.sunburst == 0 and farm.coins > balance and farm.lifetime_sales > 0.0 and farm.island_sales["1"] > 0.0, "held Sunburst sells anywhere and lifetime sale progress records the selling island")
	farm.reset_game()
	enter_shores()
	farm.storage.russet = 199
	ready_crop(0, "sunburst")
	farm.interact_plot(0, "harvest")
	check(farm.plots[0].pending == 5 and farm.storage_used() == 200, "partial harvest preserves uncollected crop at barn capacity")
	farm.travel_to(1)
	farm.sell_crop("russet")
	farm.travel_to(2)
	farm.interact_plot(0, "harvest")
	check(farm.plots[0].pending == 0 and farm.combo_count == 0 and farm.mutations[0].count == 1 and farm.mastery.sunburst == 6, "partial harvest after travel cannot duplicate yield, mutation, or chain bonus")
	farm.reset_game()
	enter_shores()
	farm.export_timer = 15.1
	warnings_seen = 0
	farm.update(0.1)
	check(warnings_seen == 1 and is_equal_approx(farm.export_timer, 15.0), "one actionable fifteen-second export warning")
	farm.travel_to(1)
	check(is_equal_approx(farm.export_timer, 15.0), "travel cannot reset or delay incoming ship")
	farm.update(15.0)
	check(farm.export_active and farm.export_timer > 1.0 and farm.export_timer <= 5.0 and farm.export_factor >= 2.0 and farm.export_factor <= 6.0, "export is a short randomized two-to-six-times offer")
	farm._end_event()
	var factor: float = farm.export_factor
	check(is_equal_approx(farm.market.golden.sell, farm._market_core.golden.sell * factor) and is_equal_approx(farm.market.sunburst.sell, farm._market_core.sunburst.sell * factor), "export boosts only eligible commodity quotes")
	check(farm.market.russet.sell == farm._market_core.russet.sell, "ordinary crops do not receive export multiplier")
	check(is_equal_approx(farm.market.sunburst.seed, farm.market.sunburst.sell * 3.0 * 0.45), "export seeds rise with their sale quote rather than staying implausibly cheap")
	farm._start_event("golden_craze")
	check(is_equal_approx(farm.market.golden.sell, minf(farm.CROPS.golden.base * State.MAX_PRICE_MULTIPLIER, farm._market_core.golden.sell * factor * farm.event_strength)), "brief export can combine with an independent brief event")
	farm.update(5.01)
	check(not farm.export_active and farm.export_factor == 1.0 and farm.export_timer >= 75.0 - 0.02 and farm.export_timer <= 180.0, "export removes its multiplier within five seconds and randomizes next delivery")
	check(farm.market.golden.sell == farm._market_core.golden.sell, "expired export and event restore the ordinary quote")
	var delays: Array[int] = []
	var factors: Array[float] = []
	for _index in range(8):
		farm._toggle_export()
		factors.append(farm.export_factor)
		farm._toggle_export()
		delays.append(int(farm.export_timer))
	check(delays.min() != delays.max() and factors.min() != factors.max(), "export cadence and multiplier are not a fixed exploitable schedule")
	farm.reset_game()
	var initial_quote: float = farm.market.russet.sell
	farm.update(2.99)
	check(farm.market.russet.sell == initial_quote, "starter quotes wait for their three-second tick")
	farm.update(0.02)
	check(farm.market.russet.sell != initial_quote, "starter quotes update every three seconds")
	var linked_and_bounded: bool = true
	for _index in range(600):
		farm.update(1.0)
		for id in farm.CROP_IDS:
			var multiplier: float = farm.event_strength if farm.current_event in ["seed_fair", "seed_panic"] else 1.0
			linked_and_bounded = linked_and_bounded and is_equal_approx(farm.market[id].seed, farm.market[id].sell * farm.CROPS[id].yield * 0.45 * multiplier)
			linked_and_bounded = linked_and_bounded and farm._market_core[id].sell >= farm.CROPS[id].base * 0.35 - 0.001 and farm._market_core[id].sell <= farm.CROPS[id].base * 3.0 + 0.001
	check(linked_and_bounded, "ten simulated minutes keep seed/crop prices linked and core quotes bounded")
	farm.reset_game()
	farm.rng.seed = 781
	farm._market_core.sunburst.sell = 270000.0
	for _index in range(100): farm._market_tick()
	check(farm._market_core.sunburst.sell < 180000.0, "high underlying prices revert toward value instead of compounding forever")
	var odds_sum: float = 0.0
	var baseline_common: float = farm.roll_odds()[0].chance
	farm.luck = 10.0
	for entry in farm.roll_odds(): odds_sum += entry.chance
	check(is_equal_approx(odds_sum, 100.0) and farm.roll_odds()[0].chance < baseline_common and farm.roll_odds()[5].chance > 1.0 and farm.roll_odds()[5].chance < 2.5, "displayed luck-adjusted roll probabilities total one hundred percent")
	check(is_equal_approx(farm.luck_stock_chance(), 0.87), "maximum luck increases beneficial market-event odds to eighty-seven percent")
	var lucky_mutation: float = farm.mutation_chance("russet")
	farm.luck = 1.0
	check(is_equal_approx(lucky_mutation, farm.mutation_chance("russet") * 10.0), "luck has its displayed real effect on mutation chance")
	var favorable: Array[String] = ["shortage", "golden_craze", "mystery_buyer", "supply_collapse", "seed_fair", "festival"]
	var positive_counts: Array[int] = [0, 0]
	for luck_index in range(2):
		farm.luck = 1.0 if luck_index == 0 else 10.0
		farm.rng.seed = 9125
		for _index in range(600):
			farm._start_event()
			if favorable.has(farm.current_event): positive_counts[luck_index] += 1
	check(positive_counts[1] > positive_counts[0] + 90, "high luck produces more positive events in a deterministic independent sample")
	farm._end_event()
	farm.luck = 10.0
	for _index in range(100): farm._grant_roll_reward("epic", 1.0e8)
	check(farm.luck == 10.0 and farm.permanent_yield <= 2.0, "earned luck and new yield bonuses cannot exceed their progression caps")
	farm.reset_game()
	for stake in [200.0, 2000.0, 20000.0]:
		farm.mutations.clear()
		farm._grant_roll_reward("mythic", stake)
		check(farm.barn_value() <= stake * 0.75 + 0.001, "mythic liquid reward cannot create an expected-profit roll/sell loop at stake " + str(stake))
	farm.reset_game()
	farm.tools = {"hoe": 2, "water": 2, "harvest": 2}
	farm._grant_roll_reward("legendary", 20000.0)
	check(farm.pending_roll_boost > 1.0 and farm.boost_remaining == 0.0, "legendary market bonus waits for roll animation reveal")
	farm.update(3.5)
	check(farm.pending_roll_boost > 1.0 and farm.boost_remaining == 0.0, "spinning reel cannot spend the short market bonus")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.pending_roll_boost > 1.0, "pending reveal bonus survives saving and loading")
	farm.activate_roll_boost()
	check(farm.pending_roll_boost == 0.0 and farm.boost_remaining == 5.0 and farm.market.russet.sell > farm._market_core.russet.sell, "reveal starts the promised five-second market bonus")
	farm.update(5.01)
	check(farm.boost_remaining == 0.0 and farm.boost_factor == 1.0, "roll market bonus expires completely after five seconds")
	farm.reset_game()
	enter_shores()
	for index in range(48): farm.interact_plot(index, "hoe")
	check(farm.quest_progress.ground == 48 and farm.quest_claimed.is_empty(), "ground quest covers the whole island and requires a deliberate claim")
	farm.claim_quest("ground")
	check(farm.coins == 100000.0 and farm.seed_inventory.sunburst == 5, "ground quest provides a modest starting fund and five Sunburst seeds")
	farm.claim_quest("ground")
	check(farm.coins == 100000.0 and farm.seed_inventory.sunburst == 5, "quest rewards cannot be collected twice")
	farm.coins = 1.0e9
	for _index in range(6): farm.upgrade_barn()
	for _field in range(3):
		for index in range(48):
			ready_crop(index, "sunburst")
			farm.interact_plot(index, "harvest")
	check(farm.quest_progress.sunburst == 10000 and farm.quest_progress.combo == 48, "several complete manual fields finish ten-thousand-potato and full-field chain challenges")
	farm.luck = 10.0
	for index in range(2):
		farm.rng.seed = mutation_seed(farm.mutation_chance("sunburst"))
		ready_crop(index, "sunburst")
		farm.interact_plot(index, "harvest")
	check(farm.quest_progress.mutation == 3, "three discoveries must come from actual harvest actions")
	farm.claim_quest("sunburst")
	farm.claim_quest("combo")
	farm.claim_quest("mutation")
	check(farm.golden_hat and farm.quest_claimed.has("mutation"), "completing mutation journey grants Golden Hat")
	farm.storage.sunburst = 50000
	farm._toggle_export()
	farm.export_factor = 6.0
	farm._refresh_market()
	farm.sell_crop("sunburst", 100)
	check(farm.quest_progress.export == 1, "one shipment needs a real hundred-potato sale")
	farm.sell_crop("sunburst", 100)
	check(farm.quest_progress.export == 1, "repeated sales in one ship cycle cannot complete distinct-shipment challenge")
	for _cycle in range(2):
		farm._toggle_export()
		farm._toggle_export()
		farm.sell_crop("sunburst", 100)
	check(farm.quest_progress.export == 3 and farm.export_qualified_cycles.size() == 3, "shipment challenge requires three distinct export cycles")
	balance = farm.coins
	farm.claim_quest("export")
	check(farm.coins == balance + 5.0e9 and farm.quest_claimed.size() == 5, "completed shipment activity quest pays five billion exactly once")
	farm.export_factor = 6.0
	farm._refresh_market()
	check(farm.save_game(SAVE), "complete current economy and both farms save")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	farm.reset_game()
	check(farm.load_game(SAVE), "new save passes strict economy and island validation")
	check(farm.current_island == 2 and farm.island_plots["1"].size() == 24 and farm.plots.size() == 48 and farm.golden_hat, "save restores both farms and owned cosmetic")
	check(farm.export_factor == 6.0 and farm.export_active and farm.export_timer == snapshot.export_timer and farm.lifetime_sales == snapshot.lifetime_sales, "export factor, countdown and earned-sales history persist exactly")
	balance = farm.coins
	farm.claim_quest("export")
	check(farm.coins == balance, "save/reload cannot pay completed quest twice")
	for key in ["island_plots", "current_island", "quest_progress", "quest_claimed", "economy_revision", "export_factor", "event_strength", "lifetime_sales", "pending_roll_boost"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.erase(key)
		write_save(bad)
		check(not farm.load_game(SAVE) and farm.coins == balance, "missing save field safely rejected: " + key)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.quest_claimed.append("export")
	write_save(bad)
	check(not farm.load_game(SAVE), "duplicate quest claims rejected")
	bad = snapshot.duplicate(true)
	bad.luck = 10.01
	write_save(bad)
	check(not farm.load_game(SAVE), "new saves cannot exceed ten-times luck")
	bad = snapshot.duplicate(true)
	bad.export_timer = 6.0
	write_save(bad)
	check(not farm.load_game(SAVE), "new saves cannot retain export peaks beyond five seconds")
	bad = snapshot.duplicate(true)
	bad.island_plots["1"][4].stage = 4
	write_save(bad)
	check(not farm.load_game(SAVE), "corrupted inactive island is checked too")
	write_save(snapshot)
	farm.load_game(SAVE)
	var old_v3: Dictionary = legacy_data()
	old_v3.market_core.sunburst.sell = 9.0e16
	write_save(old_v3)
	check(farm.load_game(SAVE), "old version-three island saves migrate without deleting player progress")
	check(farm.coins == balance and farm.luck == 10.0 and farm.golden_hat and farm.quest_claimed.size() == 5, "rebalance preserves existing coins and claimed rewards while applying luck cap")
	check(farm.export_timer <= 5.0 and farm.export_factor == 4.0 and farm._market_core.sunburst.sell == 270000.0 and is_equal_approx(farm.market.sunburst.seed, farm.market.sunburst.sell * 1.35), "old long peaks and disconnected prices normalize to the bounded linked economy")
	farm.claim_quest("export")
	check(farm.coins == balance and farm.save_game(SAVE) and farm.load_game(SAVE), "migrated claimed quests stay claimed and round-trip through current saves")
	farm.reset_game()
	farm.interact_plot(4, "hoe")
	farm.interact_plot(4, "plant")
	farm.interact_plot(4, "water")
	farm.update(4.0)
	farm.coins = 8.4e71
	var old_v2: Dictionary = legacy_data(2)
	write_save(old_v2)
	farm.reset_game()
	check(farm.load_game(SAVE), "old four-crop version-two farm also migrates")
	check(farm.coins == 8.4e71 and farm.plots[4].elapsed == 4.0 and str(farm.rng.state) == old_v2.rng_state, "migration preserves old wealth, precise crop growth, and RNG state")
	check(farm.current_island == 1 and not farm.island2_unlocked and farm.seed_inventory.sunburst == 0 and farm.export_timer == 120.0, "old farm receives locked new content without resets")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "migrated version-two save remains valid after resaving")
	check(not farm.save_game(State.LEGACY_SAVE_PATH), "original save backup cannot be overwritten")
	farm.reset_game()
	enter_shores()
	farm._grant_roll_reward("mythic", 20000.0)
	check(farm.quest_progress.mutation == 0 and not farm.shores_first_mutation, "roll rewards never count as farming discoveries")
	farm.travel_to(1)
	farm.interact_plot(4, "hoe")
	ready_crop(0, "golden")
	farm.interact_plot(0, "harvest")
	farm._toggle_export()
	farm.sell_crop("golden")
	check(farm.quest_progress.ground == 0 and farm.quest_progress.combo == 0 and farm.quest_progress.export == 0, "first-island farming and sales do not count toward Shores challenges")
	farm.reset_game()
	enter_shores()
	var fine = State.new()
	root.add_child(fine)
	check(farm.save_game(SAVE) and fine.load_game(SAVE), "identical test states can share the same saved randomized initial timers")
	farm.rng.seed = 7181
	fine.rng.seed = 7181
	farm.update(600.0)
	for _index in range(600): fine.update(1.0)
	check(farm.export_active == fine.export_active and farm.export_cycles == fine.export_cycles and is_equal_approx(farm.export_timer, fine.export_timer), "long frames preserve every random export phase")
	check(is_equal_approx(farm.market.sunburst.sell, fine.market.sunburst.sell) and is_equal_approx(farm.elapsed, fine.elapsed), "one long frame and many short frames produce the same market economy")
	farm.reset_game()
	enter_shores()
	farm._market_core.sunburst.sell = farm.CROPS.sunburst.base * 3.0
	farm._start_event("supply_collapse")
	farm.event_crop = "sunburst"
	farm.event_strength = 16.0
	farm.boost_remaining = 5.0
	farm.boost_factor = 3.0
	farm._toggle_export()
	farm.export_factor = 6.0
	farm._refresh_market()
	check(farm.market.sunburst.sell == farm.CROPS.sunburst.base * State.MAX_PRICE_MULTIPLIER and is_equal_approx(farm.market.sunburst.change, 3000.0), "all stacked offers respect the hard plus-three-thousand-percent price ceiling")
	check(is_equal_approx(farm.market.sunburst.seed, farm.market.sunburst.sell * 1.35), "seed quote follows the capped effective sale quote")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "maximum capped market stack remains a valid save")
	farm.reset_game()
	farm.coins = 1.0e50
	check(farm.stake_luck_bonus("all_in") > 500.0, "higher stakes keep increasing quality beyond the former five-hundred-percent cap")
	for kind in ["normal", "big", "stupid", "all_in"]:
		farm.luck = 1.0
		var low_odds: Array = farm.roll_odds(kind)
		farm.luck = 10.0
		var high_odds: Array = farm.roll_odds(kind)
		var total_probability: float = 0.0
		var monotonic: bool = true
		var low_tail: float = 0.0
		var high_tail: float = 0.0
		for index in range(high_odds.size()):
			total_probability += float(high_odds[index].chance)
		# Luck can replace a Rare with a Relic. Compare the chance of meeting
		# each rarity threshold, rather than requiring Rare itself to increase.
		for index in range(high_odds.size() - 1, 0, -1):
			low_tail += float(low_odds[index].chance)
			high_tail += float(high_odds[index].chance)
			monotonic = monotonic and high_tail + 0.000001 >= low_tail
		check(monotonic and is_equal_approx(total_probability, 100.0) and high_odds[5].chance < 2.5, "luck improves every rarity threshold while cash odds remain bounded at " + kind)
	var expected_bonus: float = farm.stake_luck_bonus("all_in")
	farm.roll("all_in")
	check(is_equal_approx(farm.last_roll.stake_bonus, expected_bonus), "All-In snapshots its increased quality before charging the balance")
	farm.reset_game()
	enter_shores()
	check(farm.roll_cost("normal") == 2000000.0 and farm.roll_available(), "Shores Roll House uses progression-scaled million-coin stakes")
	farm.travel_to(1)
	balance = farm.coins
	var before_rolls: int = farm.roll_count
	farm.roll("normal")
	check(not farm.roll_available() and farm.roll_count == before_rolls and farm.coins == balance, "unlocking the next island retires older cheap Roll Houses")
	farm.reset_game()
	farm._grant_item("sunstone")
	farm._grant_item("almanac")
	farm._grant_item("lens")
	farm._grant_item("winter_weave")
	farm._grant_item("trader_token")
	farm._grant_item("aurora")
	farm._grant_item("compass")
	farm._grant_item("bottomless_sack")
	check(farm.inventory_items.size() == farm.ITEM_CATALOG.size() and is_equal_approx(farm.item_yield_bonus(), 0.12) and farm.capacity == 250, "original eight collectibles retain their real modest yield and barn effects alongside new gear")
	check(is_equal_approx(farm.item_mastery_bonus(), 0.05) and is_equal_approx(farm.item_mutation_factor(), 1.35) and is_equal_approx(farm.item_seed_factor(), 0.98), "collectibles also improve mastery, mutation chance and seed efficiency")
	var relic_rows: int = 0
	for entry in farm.inventory_info():
		if entry.kind == "relic" and entry.active: relic_rows += 1
	check(relic_rows == 8, "inventory exposes all permanent items as active alongside held farming supplies")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.capacity == 250 and farm.inventory_items.aurora == 1, "collectibles and their effective storage capacity persist safely")
	farm.reset_game()
	farm.coins = 10000.0
	farm._start_event("crash")
	farm.buy_seeds("russet", 10)
	check(farm.quest_progress.starter_crash == 10, "starter crash-buy quest rewards actual market timing")
	farm._end_event()
	farm._start_event("shortage")
	farm.event_strength = 3.0
	farm._refresh_market()
	farm.storage.russet = 10
	farm.sell_crop("russet")
	check(farm.quest_progress.starter_spike == 10, "starter sell-spike quest advances from real crop sales")
	farm.coins = 100000.0
	farm.upgrade_barn()
	farm.upgrade_barn()
	for index in range(12):
		ready_crop(index)
		farm.interact_plot(index, "harvest")
	check(farm.quest_progress.starter_combo == 12, "starter combo quest needs twelve linked manual harvests")
	farm.claim_quest("starter_crash")
	farm.claim_quest("starter_spike")
	farm.claim_quest("starter_combo")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.quest_claimed.size() == 3 and not farm.island2_unlocked, "starter quest claims save before any further island is unlocked")
	farm.reset_game()
	enter_shores()
	ready_crop(0, "sunburst")
	farm.interact_plot(0, "harvest")
	var revision_two: Dictionary = farm._save_data().duplicate(true)
	revision_two.economy_revision = 2
	for key in ["mechanics_revision", "export_cycle_sold", "export_qualified_cycles", "inventory_items", "island3_unlocked", "frost_timer", "frost_active", "frost_cleared", "frost_target_count", "thaw_remaining"]: revision_two.erase(key)
	for key in ["seed_inventory", "storage", "mastery", "market", "market_core"]: revision_two[key].erase("icecap")
	revision_two.island_plots.erase("3")
	revision_two.island_sales.erase("3")
	for field in revision_two.island_plots.values():
		for plot in field: plot.erase("frozen")
	revision_two.plots = revision_two.island_plots["2"]
	for id in ["winter_ground", "winter_harvest", "winter_frost", "starter_crash", "starter_spike", "starter_combo"]: revision_two.quest_progress.erase(id)
	write_save(revision_two)
	check(farm.load_game(SAVE) and farm.mastery.sunburst == 6 and farm.shores_first_mutation and not farm.island3_unlocked, "economy-revision-two saves migrate to winter without resetting harvested crops or discoveries")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "migrated revision-two economy round-trips through current strict validation")
	farm._grant_item("aurora")
	var pre_activity: Dictionary = farm._save_data().duplicate(true)
	for key in ["mechanics_revision", "export_cycle_sold", "export_qualified_cycles"]: pre_activity.erase(key)
	for id in ["starter_crash", "starter_spike", "starter_combo"]: pre_activity.quest_progress.erase(id)
	pre_activity.quest_progress.export = 50000000000.0
	pre_activity.quest_claimed.append("export")
	write_save(pre_activity)
	check(farm.load_game(SAVE) and farm.inventory_items.aurora == 1 and farm.quest_claimed.has("export") and farm.quest_progress.export == 3, "pre-activity winter saves preserve collectibles and already claimed export rewards")
	balance = farm.coins
	farm.claim_quest("export")
	check(farm.coins == balance and farm.save_game(SAVE) and farm.load_game(SAVE), "grandfathered export claim cannot pay again after migration")
	farm.reset_game()
	check(farm.pest_timer >= 25.0 and farm.pest_timer <= 100.0, "random pest arrival starts within the twenty-five to hundred second range")
	farm.pest_timer = 100.0
	farm.update(24.99)
	check(not farm.plots[0].pests, "ripe crops do not auto-infest before twenty-five seconds")
	farm.update(0.01)
	check(farm.plots[0].pests and is_equal_approx(farm.plots[0].pest_damage, 0.0), "ripe infestation starts at twenty-five seconds without retroactive damage")
	farm.update(5.0)
	check(is_equal_approx(farm.plots[0].pest_damage, 1.0 / 3.0), "pests remove exactly one third of original yield after five seconds")
	farm.interact_plot(0, "pest")
	check(not farm.plots[0].pests and farm.plots[0].ripe_age == 0.0 and is_equal_approx(farm.plots[0].pest_damage, 1.0 / 3.0), "manual brush clears pests and age but cannot restore prior crop damage")
	farm.update(10.0)
	check(is_equal_approx(farm.plots[0].pest_damage, 1.0 / 3.0), "cleared infestation stops accumulating yield loss")
	farm.reset_game()
	farm.pest_timer = 100.0
	farm.interact_plot(4, "hoe")
	farm.interact_plot(4, "plant")
	farm.interact_plot(4, "water")
	farm.update(10.0)
	check(farm.plots[4].stage == 3 and is_equal_approx(farm.plots[4].ripe_age, 0.0), "ripe age begins when growth actually finishes, not at the beginning of that frame")
	farm.update(24.99)
	check(not farm.plots[4].pests, "newly ripe crops receive the whole twenty-five-second harvest window")
	farm.update(0.01)
	check(farm.plots[4].pests, "newly ripe crop eventually needs the manual pest brush")
	farm.update(50.0)
	check(farm.plots[4].stage == 0 and farm.plots[4].pest_destroyed and farm.plots[4].pest_ticks == 3, "unattended pests destroy crops rather than leaving permanent leftovers")
	farm.reset_game()
	ready_crop(4, "giant")
	farm.plots[4].pests = true
	farm.plots[4].pest_damage = 1.0 / 3.0
	farm.plots[4].pest_ticks = 1
	farm.interact_plot(4, "pest")
	farm.interact_plot(4, "harvest")
	check(farm.mastery.giant == 5 and farm.plots[4].pest_damage == 0.0 and not farm.plots[4].pests, "harvest applies existing damage once then clears pest state for the next crop")
	farm.reset_game()
	farm.pest_timer = 0.01
	farm.update(0.01)
	var infested: int = 0
	for plot in farm.plots:
		if plot.pests: infested += 1
	check(infested >= 1 and infested <= 3 and farm.pest_timer >= 25.0 and farm.pest_timer <= 100.0, "random outbreak chooses one to three existing crop patches and resets its randomized timer")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "pest flags, damage, ripe age and next arrival timer persist")
	var pest_snapshot: Dictionary = farm._save_data().duplicate(true)
	pest_snapshot.plots[0].pest_damage = 0.81
	write_save(pest_snapshot)
	check(not farm.load_game(SAVE), "invalid saved crop damage cannot disagree with exact thirds")
	var before_pests: Dictionary = farm._save_data().duplicate(true)
	before_pests.mechanics_revision = 2
	before_pests.erase("pest_timer")
	for field in before_pests.island_plots.values():
		for plot in field:
			plot.erase("pests")
			plot.erase("pest_damage")
			plot.erase("ripe_age")
	before_pests.plots = before_pests.island_plots[str(farm.current_island)]
	write_save(before_pests)
	check(farm.load_game(SAVE) and farm.pest_timer == 60.0 and not farm.plots[0].pests, "pre-pest saves migrate to healthy crops without resetting the farm")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "migrated pest state remains valid after resaving")
	fine.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	await process_frame
	print("GOLDEN SHORES ECONOMY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
