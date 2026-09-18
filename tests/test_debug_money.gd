extends SceneTree

const State = preload("res://scripts/game_state.gd")
const SAVE := "user://spud_debug_money_test_only.json"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func winter(state) -> void:
	state.island2_unlocked = true
	state.island3_unlocked = true
	for id in ["2", "3"]:
		for plot in state.island_plots[id]:
			plot.unlocked = true
	state.travel_to(3)

func draw_tier(draw: float, odds: Array) -> String:
	var cumulative: float = 0.0
	for entry in odds:
		cumulative += float(entry.chance)
		if draw * 100.0 < cumulative:
			return str(entry.tier)
	return "mystery"

func pattern_seed(state, first: String, first_refund: bool = false, second: String = "", second_refund: bool = false) -> int:
	var odds: Array = state.roll_odds("all_in")
	var predictor := RandomNumberGenerator.new()
	for candidate in range(1, 1000000):
		predictor.seed = candidate
		if draw_tier(predictor.randf(), odds) != first:
			continue
		if first == "common" and (predictor.randf() >= 0.70) != first_refund:
			continue
		if not second.is_empty():
			if draw_tier(predictor.randf(), odds) != second:
				continue
			if second == "common" and (predictor.randf() >= 0.70) != second_refund:
				continue
		return candidate
	push_error("Unable to find seeded reward pattern")
	return 1

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	check(state.money(0.0) == "$0" and state.money(0.24) == "$0.24", "zero and ordinary decimal money retain their familiar display")
	check(state.money(1e-20) == "$1e-20" and state.money(1e-200) == "$1e-200", "tiny positive balances remain visibly nonzero in HUD and toast money strings")
	check(state.money(200.0) == "$200" and state.money(4200000.0) == "$4.2M", "small-balance display change preserves ordinary prices and magnitude suffixes")
	check(state.debug_info().money_min == 0.0 and state.valid_debug_settings(0.1, 1.0) and state.valid_debug_settings(1e-3, 1.0) and state.valid_debug_settings(0.0, 1.0), "debug API accepts decimal, scientific and zero money multipliers")
	state.coins = 1e20
	state.apply_debug(0.1, 2.0)
	check(is_equal_approx(state.coins, 1e19) and state.debug_money_modified and state.debug_luck_multiplier == 2.0, "fractional debug multiplier reduces purse once and records debug provenance")
	state.apply_debug(1e-3, 1.0)
	check(is_equal_approx(state.coins, 1e16), "scientific fractional multiplier keeps the intended fraction of current coins")
	state.reset_debug()
	check(is_equal_approx(state.coins, 1e16) and state.debug_money_modified, "luck reset preserves a decreased purse and its provenance")
	state.apply_debug(0.0, 1.0)
	check(state.coins == 0.0 and state.debug_money_modified, "explicit zero multiplier clears the purse")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.coins == 0.0 and state.debug_money_modified, "zeroed debug purse saves and loads normally")
	for tiny_balance in [1e-20, 1e-200, 1.2345678901234567e-200]:
		state.coins = tiny_balance
		check(state.save_game(SAVE) and state.load_game(SAVE) and state.coins > 0.0 and state.coins == tiny_balance, "tiny positive debug balance survives the JSON round trip exactly: " + String.num_scientific(tiny_balance))
	state.coins = 8.4e71
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.coins == 8.4e71, "ordinary huge numeric balance survives a one-ULP scientific-parser difference unchanged")
	state.coins = 1e-200
	state.apply_debug(1e-200, 2.0)
	check(state.coins == 1e-200 and state.debug_luck_multiplier == 1.0 and not state.valid_debug_settings(1e-200, 1.0), "positive multiplication that would underflow cannot silently wipe the purse")
	var precision_save: Dictionary = state._save_data().duplicate(true)
	for invalid_precision in ["nan", "inf", "-1e-20", "1e301", "1e20", 200.0]:
		var malformed_precision: Dictionary = precision_save.duplicate(true)
		malformed_precision.coins_scientific = invalid_precision
		check(not state._valid_save(malformed_precision), "invalid or mismatched exact-money field cannot override numeric save value")
	state.reset_game()
	state.coins = 0.0
	state.apply_debug(0.0, 1.0)
	check(not state.debug_money_modified, "no actual money change leaves a fresh zero purse unmarked")
	for invalid in [-0.001, -INF, INF, NAN, 1000001.0]:
		state.coins = 1000.0
		state.apply_debug(float(invalid), 2.0)
		check(state.coins == 1000.0 and state.debug_luck_multiplier == 1.0 and not state.debug_money_modified, "invalid money multiplier rejects the complete debug edit")
	state.reset_game()
	winter(state)
	state.coins = 1e20
	state.rng.seed = pattern_seed(state, "common")
	state.roll("all_in")
	var receipt: Dictionary = state.roll_accounting_info()
	check(receipt.balance_before == 1e20 and receipt.paid_total == 1e20 and receipt.balance_after_charge == 0.0, "all-in deducts the full1e20 purse before any reward")
	check(state.coins == 0.0 and receipt.cash_returned == 0.0 and receipt.net_change == -1e20, "empty all-in outcome leaves zero coins, with no precision remainder")
	state.coins = 1e20
	state.rng.seed = pattern_seed(state, "common", true)
	state.roll("all_in")
	receipt = state.roll_accounting_info()
	check(receipt.paid_total == 1e20 and receipt.balance_after_charge == 0.0 and is_equal_approx(state.coins, 1e19), "the observed1e20 to1e19 case is full payment followed by the existing10percent reward")
	check(is_equal_approx(receipt.cash_returned, 1e19) and is_equal_approx(receipt.refunds, 1e19) and is_equal_approx(receipt.net_change, -9e19), "receipt separates nominal stake, returned coins and net result")
	check(state.last_roll.cash_kind == "refund" and is_equal_approx(state.last_roll.cash_awarded, 1e19), "individual reward exposes the actual10percent credited amount")
	state._grant_item("aurora_crown")
	state.coins = 1e20
	state.rng.seed = pattern_seed(state, "common", true, "common", true)
	state.roll("all_in")
	receipt = state.roll_accounting_info()
	check(state.last_roll_results.size() == 2 and receipt.paid_count == 1 and receipt.bonus_count == 1 and receipt.paid_total == 1e20, "Crown bonus does not add another all-in payment")
	check(is_equal_approx(receipt.refunds, 2e19) and is_equal_approx(state.coins, 2e19), "paid and free Crown refund rewards are both visible in returned coins")
	for id in State.ITEM_CATALOG:
		if State.ITEM_CATALOG[id].rarity == "rare":
			state.inventory_items[id] = int(State.ITEM_CATALOG[id].max_count)
	state.coins = 1e20
	state.rng.seed = pattern_seed(state, "common", true, "rare")
	state.roll("all_in")
	receipt = state.roll_accounting_info()
	check(is_equal_approx(receipt.refunds, 1e19) and is_equal_approx(receipt.duplicate_returns, 2e19) and is_equal_approx(state.coins, 3e19), "Crown duplicate salvage and paid consolation are separate reward returns")
	check(state.last_roll_results[1].bonus_roll and state.last_roll_results[1].cash_kind == "duplicate", "free duplicate receipt is attributed to the bonus pull")
	state.unequip_gear("head")
	state.coins = 1e20
	state.rng.seed = pattern_seed(state, "rare")
	state.roll("all_in")
	receipt = state.roll_accounting_info()
	check(receipt.paid_total == 1e20 and is_equal_approx(receipt.duplicate_returns, 2e19) and is_equal_approx(receipt.balance_after, 2e19), "single capped gear refund preserves its existing20percent amount")
	state.coins = 1e20
	state.rng.seed = pattern_seed(state, "jackpot")
	state.roll("all_in")
	receipt = state.roll_accounting_info()
	check(is_equal_approx(receipt.jackpot_returns, 2e21) and is_equal_approx(receipt.balance_after, 2e21) and is_equal_approx(receipt.net_change, 1.9e21), "jackpot receipt reports full charge and20times-stake payout separately")
	check(state.last_roll.cash_kind == "jackpot" and is_equal_approx(state.last_roll.cash_awarded, 2e21), "jackpot result carries the actual credited amount")
	var copy: Dictionary = state.roll_accounting_info()
	copy.paid_total = 0.0
	check(state.last_roll_accounting.paid_total == 1e20, "UI receipt snapshot cannot mutate transaction accounting")
	check(state.save_game(SAVE) and state.load_game(SAVE) and is_equal_approx(state.roll_accounting_info().jackpot_returns, 2e21), "receipt survives save/load as historical transaction data")
	var saved: Dictionary = state._save_data().duplicate(true)
	for error_kind in ["negative_payment", "bad_return_sum", "bad_net", "bad_kind", "bad_credit"]:
		var malformed: Dictionary = saved.duplicate(true)
		match error_kind:
			"negative_payment": malformed.last_roll_accounting.paid_total = -1.0
			"bad_return_sum": malformed.last_roll_accounting.refunds = 1e21
			"bad_net": malformed.last_roll_accounting.net_change = -1e20
			"bad_kind": malformed.last_roll_results[0].cash_kind = "unknown"
			"bad_credit": malformed.last_roll_results[0].cash_awarded = NAN
		check(not state._valid_save(malformed), "save rejects malformed transaction accounting: " + error_kind)
	var old_data: Dictionary = saved.duplicate(true)
	old_data.erase("last_roll_accounting")
	for result in old_data.last_roll_results:
		result.erase("cash_awarded")
		result.erase("cash_kind")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	check(state.load_game(SAVE) and state.roll_accounting_info().is_empty(), "old saves load without inventing unknown historical receipts")
	state.coins = 1e200
	state.rng.seed = pattern_seed(state, "common")
	state.roll("all_in")
	check(state.coins == 0.0 and state.last_roll_accounting.balance_after_charge == 0.0 and state.last_roll_accounting.paid_total == 1e200, "much larger finite all-ins also fully clear the purse before rewards")
	state.coins = 6e13
	var before: int = state.roll_count
	state.roll("all_in")
	check(state.coins == 6e13 and state.roll_count == before and state.roll_accounting_info().is_empty(), "rejected60T all-in clears stale receipt without charging anything")
	state.reset_game()
	check(state.roll_accounting_info().is_empty(), "new farm clears prior transaction receipts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("SPUD DECIMAL DEBUG + ALL-IN ACCOUNTING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
