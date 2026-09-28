extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE: String = "user://spud_builds_test_only.json"
var checks: int = 0
var failures: int = 0
var state
var builds

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	state = State.new()
	builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(state)
	root.add_child(builds)
	state.rng.seed = 87923
	check(builds.active == "farmer" and builds.levels.farmer == 1, "every new farm starts with the Farmer build")
	builds.select_build("scientist")
	check(builds.active == "scientist", "builds are available without random unlocks")
	for id in builds.IDS:
		builds.levels[id] = 3
	builds.select_build("farmer")
	check(state.crop_grow_time("russet") < 10.0 and state.affected_tiles(7, "hoe").size() > 1, "Farmer upgrades change real growth speed and manual tool area")
	builds.select_build("scientist")
	builds.select_build("farmer")
	var regular_seed: float = state.market.russet.seed
	builds.select_build("investor")
	check(state.market.russet.seed == regular_seed, "Investor preserves the fixed 75% seed rate")
	state.coins = 1000000.0
	var before: float = state.coins
	builds.use_ability()
	check(state.coins == before and not builds.professions.data.contract.is_empty(), "Investor reserves a real locked-price contract")
	builds.cooldown = 0.0
	builds.select_build("gambler")
	state.storage.russet = 30
	builds.use_ability()
	check(builds.professions.data.wager.quantity == 20 and state.storage.russet == 10, "Gambler stakes exactly the selected harvest")
	builds.professions.claim()
	builds.cooldown = 0.0
	builds.select_build("scientist")
	state.storage.russet = 40
	state.storage.golden = 20
	builds.use_ability()
	check(builds.research == 1 and state.storage.russet == 30 and state.storage.golden == 10, "research consumes held crops and records actual progress")
	builds.cooldown = 0.0
	builds.select_build("industrialist")
	state.upgrade_barn()
	state.storage.russet = 200
	builds.professions.action("batch", "100")
	before = state.coins
	var used_before: int = state.storage_used()
	builds.use_ability()
	check(builds.processing.quantity == 100 and state.storage.russet == 100, "processor accepts one manually loaded batch")
	check(state.storage_used() == used_before, "loaded potatoes continue to occupy barn capacity")
	builds.select_build("farmer")
	check(builds.active == "farmer", "loaded machinery keeps working after changing specializations")
	builds.update(10.1)
	check(builds.processing.is_empty() and int(builds.processed.russet.count) == 100, "loaded processing job finishes into held inventory")
	check(state.coins == before and state.storage_used() == used_before, "finished processing never sells itself or frees occupied storage")
	var value: float = builds.processed_value()
	check(value > 100.0 * state.market.russet.sell, "processed crop batch is worth more at the live quote")
	builds.sell_processed()
	check(is_equal_approx(state.coins, before + value) and builds.processed.is_empty(), "processed sale pays exactly once when requested")
	# Save and reload an unfinished batch and build levels.
	builds.select_build("industrialist")
	builds.use_ability()
	builds.update(2.0)
	var saved_processing_work: float = float(builds.processing.elapsed)
	builds.levels.farmer = 30
	check(state.save_game(SAVE), "state saves builds and processing with the same farm snapshot")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	state.reset_game()
	check(builds.levels.farmer == 1, "reset restores the default build without retaining old rewards")
	check(state.load_game(SAVE), "build-bearing farm save reloads")
	check(builds.active == "industrialist" and builds.levels.farmer == 30, "equipped role and level thirty persist")
	check(is_equal_approx(builds.processing.elapsed, saved_processing_work), "processing resumes from exact saved progress, including equipped speed, without offline production")
	var bad: Dictionary = saved.duplicate(true)
	bad.builds.levels.scientist = 31
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	check(not state.load_game(SAVE) and builds.levels.farmer == 30, "invalid build data is rejected without mutating the farm")
	state.reset_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	builds.queue_free()
	state.queue_free()
	await process_frame
	print("PLAYER BUILDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
