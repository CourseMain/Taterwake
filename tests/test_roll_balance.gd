extends SceneTree

const State = preload("res://scripts/game_state.gd")
const SAVE := "user://spud_roll_balance_test_only.json"
const SAMPLE_SIZE: int = 20000
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func enter_island(state, island: int) -> void:
	if island >= 2:
		state.island2_unlocked = true
		for plot in state.island_plots["2"]:
			plot.unlocked = true
	if island == 3:
		state.island3_unlocked = true
		for plot in state.island_plots["3"]:
			plot.unlocked = true
	state.travel_to(island)

func tail(odds: Array, first: int) -> float:
	var total: float = 0.0
	for index in range(first, odds.size()):
		total += float(odds[index].chance)
	return total

func paid_sample(state, base_luck: float, debug_factor: float) -> Dictionary:
	state.reset_game()
	state.luck = base_luck
	state.apply_debug(1.0, debug_factor)
	state.coins = 1.0e12
	state.rng.seed = 77733019
	var shown: Array[Dictionary] = state.roll_odds("normal")
	var counts: Dictionary = {}
	for tier in State.ROLL_TIERS:
		counts[tier] = 0
	var exact_odds: bool = true
	for _index in range(SAMPLE_SIZE):
		# Hold the tested luck/loadout fixed between actual purchases. Every
		# transaction still spends coins, selects a real reward, and logs it.
		state.luck = base_luck
		state.equipment = state._empty_equipment()
		state.roll("normal")
		var result: Dictionary = state.last_roll_results[0]
		counts[result.tier] = int(counts[result.tier]) + 1
		for index in range(shown.size()):
			exact_odds = exact_odds and is_equal_approx(float(result.odds[index].chance), float(shown[index].chance))
			exact_odds = exact_odds and (result.tier != shown[index].tier or is_equal_approx(float(result.tier_probability), float(shown[index].chance)))
	check(exact_odds and state.roll_count == SAMPLE_SIZE, "paid sampling uses precisely the displayed distribution at effective luck %.0fx" % (base_luck * debug_factor))
	for entry in shown:
		var observed: float = float(counts[entry.tier]) / SAMPLE_SIZE * 100.0
		check(absf(observed - float(entry.chance)) < 0.8, "seeded observed frequency matches shown odds for %s at %.0fx" % [entry.tier, base_luck * debug_factor])
	print("ROLL DISTRIBUTION ", base_luck * debug_factor, "x / ", SAMPLE_SIZE, " paid pulls: ", counts)
	return {"counts": counts, "odds": shown}

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	for island in [1, 2, 3]:
		state.reset_game()
		enter_island(state, island)
		var base: float = [200.0, 2000000.0, 20000000000000.0][island - 1]
		var floor_value: float = [200.0, 2000000.0, 60000000000000.0][island - 1]
		check(state.roll_minimum_stake() == base and state.roll_minimum_stake("all_in") == floor_value, "island %d has the intended ordinary and all-in floor" % island)
		for balance in [0.0, floor_value - 1.0, floor_value]:
			state.coins = balance
			var rng_before: int = state.rng.state
			var count_before: int = state.roll_count
			var trophies_before: Array[Dictionary] = state.trophy_info()
			check(not state.can_roll("all_in"), "all-in button is unavailable at or below island %d floor" % island)
			state.roll("all_in")
			check(state.coins == balance and state.rng.state == rng_before and state.roll_count == count_before and state.last_roll_results.is_empty() and state.trophies == trophies_before, "rejected all-in is atomic at island %d balance %s" % [island, str(balance)])
		state.coins = floor_value + 1.0
		check(state.can_roll("all_in"), "all-in becomes available strictly above island %d floor" % island)
		var chosen_stake: float = state.coins
		var chosen_quality: float = state.stake_luck_bonus("all_in")
		state.roll("all_in")
		check(state.roll_count == 1 and state.last_roll.bet == chosen_stake and is_equal_approx(state.last_roll.stake_bonus, chosen_quality), "all-in spends the complete eligible stake and snapshots its odds before payment")
		state.coins = base
		check(state.can_roll("normal"), "ordinary roll remains affordable exactly at its existing price")
	state.reset_game()
	enter_island(state, 3)
	state.coins = 60000000000000.0
	check(not state.can_roll("all_in") and state.can_roll("normal") and state.roll_batch_cost("normal", 3) == state.coins, "winter60T funds a three-pack but is not enough for strictly-above60T all-in")
	check(state.roll_batch("normal", 3).size() == 3, "strict all-in floor does not change winter batch pricing")
	state.reset_game()
	state.coins = INF
	var invalid_rng: int = state.rng.state
	state.roll("all_in")
	check(not state.can_roll("all_in") and state.rng.state == invalid_rng and state.roll_count == 0, "nonfinite all-in cannot advance RNG or create rewards")
	state.coins = 10000.0
	check(not state.can_roll("missing") and state.roll_minimum_stake("missing") < 0.0, "unknown stakes never become affordable")
	state.reset_game()
	enter_island(state, 3)
	state._grant_item("aurora_crown")
	state.coins = 60000000000001.0
	var crown_bet: float = state.coins
	state.roll("all_in")
	check(state.roll_count == 2 and state.last_roll_results.size() == 2 and state.last_roll_results[1].bonus_roll and state.last_roll_results[1].bet == crown_bet, "eligible all-in still grants exactly one same-stake Crown bonus")
	state.coins = 60000000000000.0
	var crown_count: int = state.roll_count
	state.roll("all_in")
	check(state.roll_count == crown_count and state.last_roll_results.is_empty(), "Crown cannot bypass strict all-in threshold")
	state.reset_game()
	var baseline: Array[Dictionary] = state.roll_odds()
	check(is_equal_approx(baseline[0].chance, 55.0) and is_equal_approx(baseline[7].chance, 0.01), "luck1 retains the original base rarity table")
	state.coins = 1.0e50
	for kind in ["normal", "big", "stupid", "all_in"]:
		state.luck = 1.0
		var low: Array[Dictionary] = state.roll_odds(kind)
		state.luck = 10.0
		var high: Array[Dictionary] = state.roll_odds(kind)
		check(is_equal_approx(tail(high, 0), 100.0) and high[5].chance <= 2.25, "ordinary luck remains normalized with bounded cash jackpots at " + kind)
		for first in range(1, State.ROLL_TIERS.size()):
			check(tail(high, first) >= tail(low, first) - 0.000001, "more ordinary luck improves cumulative %s-or-better odds at %s" % [State.ROLL_TIERS[first], kind])
	state.luck = 3.0
	state.apply_debug(1.0, 1000.0)
	var debug_odds: Array[Dictionary] = state.roll_odds("normal")
	check(state.effective_luck() == 3000.0 and debug_odds[0].chance < 0.2 and tail(debug_odds, 3) > 60.0 and tail(debug_odds, 6) > 14.0, "3000x debug luck visibly shifts the actual reward ladder into high rarity")
	check(float(debug_odds[7].chance) / float(debug_odds[1].chance) > float(baseline[7].chance) / float(baseline[1].chance) * 100.0, "high luck improves top rarity relative to Rare, not merely suppressing Common")
	var normal_sample: Dictionary = paid_sample(state, 1.0, 1.0)
	var debug_sample: Dictionary = paid_sample(state, 3.0, 1000.0)
	check(int(normal_sample.counts.common) > 10000 and int(debug_sample.counts.common) < 100, "empirical3000x purchases practically eliminate Common compared with baseline")
	check(int(debug_sample.counts.relic) + int(debug_sample.counts.mystery) > 2500 and int(debug_sample.counts.mystery) > 1000, "empirical3000x purchases produce genuinely rarer items in quantity")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.debug_luck_multiplier == 1000.0, "new actual odds and trophy metadata remain save-compatible")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("SPUD ROLL BALANCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
