extends SceneTree

const State = preload("res://scripts/game_state.gd")
const SAVE := "user://spud_debug_trophies_test_only.json"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func tier_seed(state, tier: String, kind: String = "normal", first_seed: int = 1) -> int:
	var lower: float = 0.0
	var upper: float = 100.0
	for entry in state.roll_odds(kind):
		upper = lower + float(entry.chance)
		if str(entry.tier) == tier:
			break
		lower = upper
	var predictor := RandomNumberGenerator.new()
	for candidate in range(first_seed, first_seed + 200000):
		predictor.seed = candidate
		var draw: float = predictor.randf() * 100.0
		if draw >= lower and draw < upper:
			return candidate
	push_error("No seed found for " + tier)
	return 1

func two_empty_seed(state, kind: String = "normal") -> int:
	var common_chance: float = float(state.roll_odds(kind)[0].chance) / 100.0
	var predictor := RandomNumberGenerator.new()
	for candidate in range(1, 200000):
		predictor.seed = candidate
		if predictor.randf() < common_chance and predictor.randf() < 0.70 and predictor.randf() < common_chance and predictor.randf() < 0.70:
			return candidate
	return 1

func expected_probability(result: Dictionary) -> float:
	for entry in result.odds:
		if entry.tier == result.tier:
			return float(entry.chance)
	return -1.0

func winter(state) -> void:
	state.island2_unlocked = true
	state.island3_unlocked = true
	for id in ["2", "3"]:
		for plot in state.island_plots[id]:
			plot.unlocked = true
	state.travel_to(3)

func ready_plot(state, index: int = 0) -> Dictionary:
	var plot: Dictionary = state.plots[index]
	state._clear_crop(plot)
	plot.stage = 3
	plot.crop = "russet"
	plot.watered = true
	plot.elapsed = 10.0
	plot.tilled = true
	state.combo_count = 0
	state.combo_multiplier = 1
	state.combo_time = 0.0
	state.mastery.russet = 0
	return plot

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	check(state.debug_info().luck_multiplier == 1.0 and not state.debug_info().active, "debug defaults leave ordinary gameplay untouched")
	state.coins = 100.0
	state.apply_debug(10.0, 5.0)
	check(state.coins == 1000.0 and state.debug_luck_multiplier == 5.0 and state.effective_luck() == 5.0, "debug multiplies current purse once and applies persistent luck factor")
	state.update(1.0)
	check(state.coins == 1000.0, "debug money does not compound over time")
	state.reset_debug()
	check(state.coins == 1000.0 and state.effective_luck() == 1.0 and state.debug_money_modified, "resetting debug luck never rewinds coins or erases debug coin provenance")
	for invalid in [[-0.1, 2.0], [1000001.0, 2.0], [2.0, 1001.0], [INF, 2.0], [2.0, NAN]]:
		var before: float = state.coins
		state.apply_debug(float(invalid[0]), float(invalid[1]))
		check(state.coins == before and state.debug_luck_multiplier == 1.0, "invalid debug input rejects both changes atomically")
	state.reset_game()
	state.luck = 10.0
	var ordinary_common: float = state.roll_odds()[0].chance
	state.apply_debug(1.0, 1000.0)
	check(state.normal_luck() == 10.0 and state.effective_luck() == 10000.0 and state.roll_odds()[0].chance < ordinary_common, "explicit debug luck multiplies the ordinarily capped value and changes real odds")
	var total_chance: float = 0.0
	for entry in state.roll_odds():
		total_chance += float(entry.chance)
	check(is_equal_approx(total_chance, 100.0), "extreme debug luck still produces normalized finite odds")
	state.reset_debug()
	check(state.effective_luck() == 10.0 and not state.debug_info().active, "reset restores normal cap when no coin edit was made")
	state.coins = state.MAX_MONEY
	state.apply_debug(1000000.0, 1.0)
	check(is_finite(state.coins) and state.coins == state.MAX_MONEY, "debug money cannot overflow the finite purse limit")
	state.reset_game()
	state._grant_item("aurora_crown")
	check(state.crown_bonus_active() and state.normal_luck() == 2.0, "equipped Crown retains its luck bonus and enables a free pull")
	state.coins = 1000.0
	state.rng.seed = two_empty_seed(state, "all_in")
	var all_in_bonus: float = state.stake_luck_bonus("all_in")
	state.roll("all_in")
	check(state.roll_count == 2 and state.last_roll_results.size() == 2 and state.coins == 0.0, "single all-in purchases one stake and grants exactly one uncharged Crown pull")
	check(not state.last_roll_results[0].bonus_roll and state.last_roll_results[1].bonus_roll and state.last_roll_results[1].paid_count == 1, "transaction results clearly distinguish paid and Crown bonus pulls")
	check(state.last_roll_results[1].bet == 1000.0 and is_equal_approx(state.last_roll_results[1].stake_bonus, all_in_bonus), "free all-in pull retains purchased stake and quality after purse is spent")
	check(state.last_roll_results[0].tier == "common" and state.last_roll_results[1].tier == "common" and state.trophies.is_empty(), "empty sacks never clutter the rare trophy cabinet")
	state.roll("normal")
	check(state.last_roll_results.is_empty() and state.roll_count == 2, "failed purchases clear stale animation results without granting a free pull")
	state.reset_game()
	state.coins = 10000.0
	state.rng.seed = tier_seed(state, "mythic")
	state.roll("normal")
	check(state.last_roll_results.size() == 1 and state.last_roll_results[0].item_id == "aurora_crown" and state.crown_bonus_active(), "Crown won in this purchase equips but cannot recursively grant a pull now")
	state.rng.seed = tier_seed(state, "mythic")
	var previous_count: int = state.roll_count
	state.roll("normal")
	check(state.last_roll_results.size() == 2 and state.roll_count == previous_count + 2, "already worn Crown grants just one bonus even when another Crown is won")
	state.unequip_gear("head")
	previous_count = state.roll_count
	state.roll("normal")
	check(state.last_roll_results.size() == 1 and state.roll_count == previous_count + 1, "stored Crown grants no bonus rolls")
	state.equip_gear("aurora_crown")
	winter(state)
	state.coins = 1.0e18
	for amount in [3, 5]:
		previous_count = state.roll_count
		var batch: Array[Dictionary] = state.roll_batch("normal", amount)
		var bonuses: int = 0
		for result in batch:
			bonuses += 1 if bool(result.bonus_roll) else 0
		check(batch.size() == amount + 1 and state.roll_count == previous_count + amount + 1 and bonuses == 1, "Crown grants one bonus per batch transaction, not per paid pull: " + str(amount))
	state.coins = state.roll_cost("normal") * 2.0
	previous_count = state.roll_count
	var before_rng: int = state.rng.state
	check(state.roll_batch("normal", 3).is_empty() and state.last_roll_results.is_empty() and state.roll_count == previous_count and state.rng.state == before_rng, "Crown cannot make an unaffordable batch payable")
	state.reset_game()
	state._grant_item("sunstone")
	state._grant_roll_reward("relic", 200.0)
	check(state.trophies.is_empty() and state.roll_count == 0, "direct inventory grants and reward fixtures do not fabricate trophy history")
	state.coins = 1000000.0
	var actual_counts: Dictionary = {}
	var actual_best: Dictionary = {}
	for _index in range(40):
		state.rng.seed = tier_seed(state, "rare", "normal", _index * 47 + 1)
		state.roll("normal")
		var result: Dictionary = state.last_roll_results[0]
		var key: String = state._trophy_key(result)
		actual_counts[key] = int(actual_counts.get(key, 0)) + 1
		actual_best[key] = minf(float(actual_best.get(key, 100.0)), expected_probability(result))
	for trophy in state.trophy_info():
		check(trophy.count == actual_counts[trophy.key] and is_equal_approx(trophy.best_probability, float(actual_best[trophy.key])), "trophy aggregates real duplicate counts and best actual tier probability")
		check(trophy.roll_number <= state.roll_count and trophy.island == 1 and not trophy.debug, "earned trophy retains its actual roll number and island")
	for _index in range(100):
		state.rng.seed = tier_seed(state, "epic", "normal", _index * 31 + 1)
		state.roll("normal")
	state.rng.seed = tier_seed(state, "relic")
	state.roll("normal")
	state.rng.seed = tier_seed(state, "mystery")
	state.roll("normal")
	check(state.trophies.size() == State.TROPHY_LIMIT and state.trophies[0].tier == "mystery" and state.trophies[1].tier == "relic", "overfilled cabinet retains16 unique results and sorts highest rarity first")
	for index in range(1, state.trophies.size()):
		check(not state._trophy_precedes(state.trophies[index], state.trophies[index - 1]), "trophies remain ordered by rarity and actual tier chance")
	var cabinet_copy: Array[Dictionary] = state.trophy_info()
	cabinet_copy.clear()
	check(not state.trophies.is_empty(), "gallery receives an independent trophy snapshot")
	state.apply_debug(2.0, 10.0)
	state.rng.seed = tier_seed(state, "mystery")
	state.roll("normal")
	check(state.last_roll.debug and is_equal_approx(state.last_roll.tier_probability, expected_probability(state.last_roll)), "debug pulls are tagged and show their actual boosted tier odds")
	var debug_found: bool = false
	for trophy in state.trophies:
		debug_found = debug_found or (bool(trophy.debug) and trophy.tier == "mystery")
	check(debug_found, "debug trophy is visibly separate from an earned trophy of the same tier")
	check(state.save_game(SAVE), "debug settings and trophy cabinet save successfully")
	var saved: Dictionary = state._save_data().duplicate(true)
	state.reset_game()
	check(state.load_game(SAVE) and state.debug_luck_multiplier == 10.0 and state.debug_money_modified and state.trophies.size() == saved.trophies.size(), "trophies, transaction results and debug settings survive save/load")
	for error_kind in ["luck_nan", "luck_high", "bad_probability", "duplicate_trophy", "unearned_roll", "wrong_bonus_count", "bad_fraction"]:
		var malformed: Dictionary = saved.duplicate(true)
		match error_kind:
			"luck_nan": malformed.debug_luck_multiplier = NAN
			"luck_high": malformed.debug_luck_multiplier = 1001.0
			"bad_probability": malformed.trophies[0].best_probability = 101.0
			"duplicate_trophy": malformed.trophies.append(malformed.trophies[0].duplicate(true))
			"unearned_roll": malformed.trophies[0].roll_number = state.roll_count + 1
			"wrong_bonus_count": malformed.last_roll_results[0].crown_bonus = true
			"bad_fraction": malformed.harvest_fraction.russet = 1.0
		check(not state._valid_save(malformed), "new save data rejects " + error_kind)
	state.reset_game()
	state._grant_item("straw_hat")
	var grown: int = 0
	for _index in range(25):
		grown += state._harvest_plot(ready_plot(state))
	check(grown == 81, "eight percent hat yield produces81 instead of75 Russets across25 small harvests")
	check(is_zero_approx(float(state.harvest_fraction.russet)), "fractional yield carries accurately across whole extra potatoes")
	state.reset_game()
	state._grant_item("straw_hat")
	state.storage.russet = 199
	var plot: Dictionary = ready_plot(state)
	state._harvest_plot(plot)
	var fraction_after_first: float = state.harvest_fraction.russet
	check(is_equal_approx(fraction_after_first, 0.24) and plot.pending == 2, "partial harvesting fixes total yield and carry once")
	state.storage.russet = 0
	state._harvest_plot(plot)
	check(is_equal_approx(state.harvest_fraction.russet, fraction_after_first), "finishing a partial harvest cannot create extra fractional yield")
	check(state.save_game(SAVE) and state.load_game(SAVE) and is_equal_approx(state.harvest_fraction.russet, 0.24), "fractional gains persist so reloading cannot lose small gear bonuses")
	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.mechanics_revision = 6
	for key in ["debug_luck_multiplier", "debug_money_modified", "trophies", "harvest_fraction", "last_roll_results"]:
		legacy.erase(key)
	write_save(legacy)
	check(state.load_game(SAVE) and state.debug_luck_multiplier == 1.0 and state.trophies.is_empty() and state.harvest_fraction.russet == 0.0, "old saves receive clean debug defaults and no fabricated past trophies")
	legacy.mechanics_revision = 3
	legacy.erase("equipment")
	for id in State.ITEM_CATALOG:
		if State.ITEM_CATALOG[id].has("kind"):
			legacy.inventory_items.erase(id)
	write_save(legacy)
	check(state.load_game(SAVE) and state.equipment.head == "" and state.debug_luck_multiplier == 1.0, "pre-QoL saves migrate through every later equipment and debug stage")
	state.reset_game()
	check(state.trophies.is_empty() and state.last_roll_results.is_empty() and state.debug_luck_multiplier == 1.0 and not state.debug_money_modified, "new farm resets debug flags and history")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("SPUD DEBUG + TROPHIES + CROWN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
