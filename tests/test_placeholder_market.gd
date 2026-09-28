extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://placeholder_market_test_only.json"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	for moment: float in [0.0, 150.0, 300.0, 450.0, 600.0, 1200.0, 1e15]:
		farm.elapsed = moment
		farm._refresh_market()
		for crop: String in State.CROP_IDS:
			var base: float = State.CROPS[crop].base
			check(farm.market[crop].sell >= base * 0.85 - 0.000001 and farm.market[crop].sell <= base * 1.15 + 0.000001, crop + " bounded drift")
			check(farm.market[crop].seed == base * 0.75, crop + " fixed seed cost")
	farm.reset_game()
	farm.update(1.0)
	check(absf(farm.market.russet.sell / State.CROPS.russet.base - 1.0) < 0.002, "one second changes prices by less than 0.2 percent")
	farm.elapsed = 150.0
	farm._refresh_market()
	check(is_equal_approx(farm.market.russet.sell, 43.7), "quarter-cycle reaches upper bound")
	farm.elapsed = 450.0
	farm._refresh_market()
	check(is_equal_approx(farm.market.russet.sell, 32.3), "three-quarter-cycle reaches lower bound")
	var expected: Dictionary = farm.market.duplicate(true)
	farm.rng.seed = 54321
	farm._refresh_market()
	check(farm.market == expected, "pricing does not depend on random state")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.market == expected, "save restores derived prices exactly")
	var retired: Dictionary = {"market": {"bad": true}, "market_core": {}, "surge_timer": -1, "surge_remaining": 10, "surge_crop": "russet", "surge_factor": 1000, "surge_kind": "rocket", "rocket_pending": true, "rocket_timer": 1, "rocket_factor": 1000, "rocket_crop": "icecap", "natural_remaining": 5, "natural_factor": 50, "natural_crop": "russet", "current_event": "seed_panic", "event_name": "boom", "event_crop": "russet", "event_strength": 10, "event_remaining": 5, "event_in": 2, "market_clock": 3, "tracked_seeds": ["russet"], "export_factor": 6, "thaw_remaining": 5}
	farm.climate.capture_collapse(farm)
	var old: Dictionary = farm._save_data()
	old.climate.collapse.merge({"market_crop": "russet", "market_change": 1000, "seed_factor": 2, "sell_factor": 0.05}, true)
	old.mechanics_revision = 23
	old.merge(retired, true)
	old.farm_help.merge({"practice_remaining": 5, "practice_crop": "russet", "practice_tried": true}, true)
	old.farm_help.dismissed.append("stocks")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(farm.load_game(SAVE) and farm.market == expected, "old market data is discarded without affecting elapsed time")
	check(farm.save_game(SAVE), "migrated farm saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	for key: String in retired:
		check(not saved.has(key), "retired field dropped: " + key)
	check(not saved.climate.collapse.has("market_crop") and not saved.climate.collapse.has("market_change") and not saved.climate.collapse.has("seed_factor") and not saved.climate.collapse.has("sell_factor"), "retired market context dropped from saved collapse report")
	check(not saved.farm_help.has("practice_remaining") and "stocks" not in saved.farm_help.dismissed, "retired practice help dropped")
	farm.reset_game()
	farm.coins = 1000000.0
	farm.update(3600.0)
	check(farm.elapsed == 3600.0 and farm.blind_cycle.booms == 0 and farm.coins == 1000000.0, "ordinary time no longer creates market tax events")
	for path: String in [SAVE, farm.backup_path(SAVE), farm.rejected_path(SAVE)]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	farm.free()
	print("PLACEHOLDER MARKET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
