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

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	check(state.money(0.0) == "\uE000 0" and state.money(0.24) == "\uE000 0.24", "zero and ordinary decimal money retain their familiar display")
	check(state.money(1e-20) == "\uE000 1e-20" and state.money(1e-200) == "\uE000 1e-200", "tiny positive balances remain visibly nonzero in HUD and toast money strings")
	check(state.money(200.0) == "\uE000 200" and state.money(4200000.0) == "\uE000 4.2M", "small-balance display change preserves ordinary prices and magnitude suffixes")
	check(state.debug_info().money_min == 0.0 and state.valid_debug_settings(0.1) and state.valid_debug_settings(1e-3) and state.valid_debug_settings(0.0), "debug API accepts decimal, scientific and zero money multipliers")
	state.coins = 1e20
	state.apply_debug(0.1)
	check(is_equal_approx(state.coins, 1e19) and state.debug_money_modified, "fractional debug multiplier reduces purse once and records debug provenance")
	state.apply_debug(1e-3)
	check(is_equal_approx(state.coins, 1e16), "scientific fractional multiplier keeps the intended fraction of current coins")
	state.reset_debug()
	check(is_equal_approx(state.coins, 1e16) and state.debug_money_modified, "debug reset preserves a decreased purse and its provenance")
	state.apply_debug(0.0)
	check(state.coins == 0.0 and state.debug_money_modified, "explicit zero multiplier clears the purse")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.coins == 0.0 and state.debug_money_modified, "zeroed debug purse saves and loads normally")
	for tiny_balance in [1e-20, 1e-200, 1.2345678901234567e-200]:
		state.coins = tiny_balance
		check(state.save_game(SAVE) and state.load_game(SAVE) and state.coins > 0.0 and state.coins == tiny_balance, "tiny positive debug balance survives the JSON round trip exactly: " + String.num_scientific(tiny_balance))
	state.coins = 8.4e71
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.coins == 8.4e71, "ordinary huge numeric balance survives a one-ULP scientific-parser difference unchanged")
	state.coins = 1e-200
	state.apply_debug(1e-200)
	check(state.coins == 1e-200 and not state.valid_debug_settings(1e-200), "positive multiplication that would underflow cannot silently wipe the purse")
	var precision_save: Dictionary = state._save_data().duplicate(true)
	for invalid_precision in ["nan", "inf", "-1e-20", "1e301", "1e20", 200.0]:
		var malformed_precision: Dictionary = precision_save.duplicate(true)
		malformed_precision.coins_scientific = invalid_precision
		check(not state._valid_save(malformed_precision), "invalid or mismatched exact-money field cannot override numeric save value")
	state.reset_game()
	state.coins = 0.0
	state.apply_debug(0.0)
	check(not state.debug_money_modified, "no actual money change leaves a fresh zero purse unmarked")
	for invalid in [-0.001, -INF, INF, NAN, 1000001.0]:
		state.coins = 1000.0
		state.apply_debug(float(invalid))
		check(state.coins == 1000.0 and not state.debug_money_modified, "invalid money multiplier rejects the complete debug edit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("SPUD DECIMAL DEBUG: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
